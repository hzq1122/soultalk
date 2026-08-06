import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_paths.dart';
import '../database/attachment_index_dao.dart';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../database/memory_card_dao.dart';
import '../database/memory_entry_dao.dart';
import '../database/memory_state_dao.dart';
import '../database/regex_script_dao.dart';
import '../api/llm_service.dart';
import '../api/openai_adapter.dart';
import '../api/anthropic_adapter.dart';
import '../api/context_manager.dart';
import '../api/prompt_assembly_service.dart';
import '../memory/memory_service.dart';
import '../regex/regex_service.dart';
import '../extensions/extension_event_bus.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../models/regex_script.dart';

class ChatService {
  final DatabaseService _dbService;
  final Future<AppPaths> Function() _createAppPaths;
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  late final MemoryEntryDao _memoryDao;
  late final MemoryStateDao _stateDao;
  late final MemoryCardDao _cardDao;
  late final MemoryService _memoryService;
  late final RegexScriptDao _regexScriptDao;
  final _uuid = const Uuid();
  final _contextManager = const ContextManager(
    strategy: ContextStrategy.slidingWindow,
    maxMessages: 20,
  );
  final _regexService = const RegexService();
  final _promptAssemblyService = PromptAssemblyService();

  /// [dbService]/[createAppPaths] 供测试注入；默认使用全局单例。
  ChatService({
    DatabaseService? dbService,
    Future<AppPaths> Function()? createAppPaths,
  }) : _dbService = dbService ?? DatabaseService(),
       _createAppPaths = createAppPaths ?? AppPaths.create {
    final db = _dbService;
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _memoryDao = MemoryEntryDao(db);
    _stateDao = MemoryStateDao(db);
    _cardDao = MemoryCardDao(db);
    _memoryService = MemoryService(_memoryDao, _stateDao, _cardDao);
    _memoryService.setMessageDao(_messageDao);
    _regexScriptDao = RegexScriptDao(db);
  }

  Future<List<Contact>> getContacts() => _contactDao.getAll();

  Future<Contact?> getContact(String id) => _contactDao.getById(id);

  Future<Contact> createContact(Contact contact) => _contactDao.insert(contact);

  Future<void> updateContact(Contact contact) => _contactDao.update(contact);

  Future<void> deleteContact(String id) async {
    // 先清理附件（索引 + 文件），再删消息与联系人
    await _cleanupAttachmentsByChat(id);
    final db = await _dbService.database;
    await db.transaction((txn) async {
      // 删除同步 tombstone：记录被删除的消息，供 LanSync 同步到 PC
      await _recordDeletionTombstones(
        txn,
        'messages',
        where: 'contact_id = ?',
        whereArgs: [id],
      );
      await txn.delete('messages', where: 'contact_id = ?', whereArgs: [id]);
      await txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Contact>> searchContacts(String query) =>
      _contactDao.search(query);

  Future<List<Message>> getMessages(String contactId) =>
      _messageDao.getByContact(contactId);

  Future<List<Message>> getMessagePage(
    String contactId, {
    required int limit,
    required int offset,
  }) => _messageDao.getPageByContact(contactId, limit: limit, offset: offset);

  /// 游标分页：新消息插入不会造成重复/遗漏（created_at + id 双键）。
  Future<List<Message>> getMessagePageByCursor(
    String contactId, {
    required int limit,
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) => _messageDao.getPageByCursor(
    contactId,
    limit: limit,
    beforeCreatedAt: beforeCreatedAt,
    beforeId: beforeId,
  );

  Future<Message> saveMessage(Message message) async {
    final saved = await _messageDao.insert(message);
    await _contactDao.updateLastMessage(
      message.contactId,
      message.content,
      DateTime.now(),
    );
    return saved;
  }

  Future<void> deleteMessage(String messageId) async {
    await _cleanupAttachmentsByMessage(messageId);
    final db = await _dbService.database;
    String? contactId;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'messages',
        columns: ['contact_id'],
        where: 'id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (rows.isNotEmpty) contactId = rows.first['contact_id'] as String;
      await _recordDeletionTombstones(
        txn,
        'messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
      await txn.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    });
    // 删除后重算联系人最后一条消息（lastMessage/lastMessageAt/unread）
    final deletedContactId = contactId;
    if (deletedContactId != null) {
      await _contactDao.recomputeLastMessage(deletedContactId);
    }
  }

  Future<void> deleteMessages(String contactId) async {
    await _cleanupAttachmentsByChat(contactId);
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _recordDeletionTombstones(
        txn,
        'messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
      );
      await txn.delete(
        'messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
      );
    });
    // 清空聊天：同步清理联系人 lastMessage/lastMessageAt/unreadCount
    await _contactDao.recomputeLastMessage(contactId);
  }

  /// 删除同步 tombstone：删除前记录行 id 到 pc_deletions，
  /// PC 端同步后据此清理 mirror，避免手机删除的消息永久残留。
  Future<void> _recordDeletionTombstones(
    DatabaseExecutor txn,
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    try {
      final rows = await txn.query(
        table,
        columns: ['id'],
        where: where,
        whereArgs: whereArgs,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final row in rows) {
        final id = row['id'];
        if (id == null) continue;
        await txn.insert('pc_deletions', {
          'id': '${table}_$id',
          'table_name': table,
          'row_id': id.toString(),
          'deleted_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record deletion tombstone',
        name: 'ChatService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 删除消息关联的附件：attachment_index 记录 + 磁盘文件。
  /// 优先按 metadata['attachment'] 关联；旧消息缺少 metadata 时
  /// 回退按 content 中的相对路径（soultalk/attachments/...）解析。
  Future<void> _cleanupAttachmentsByMessage(String messageId) async {
    try {
      final message = await _messageDao.getById(messageId);
      if (message == null) return;
      final ids = <String>{};
      final metadata = message.metadata;
      final attachment = metadata?['attachment'];
      if (attachment is Map && attachment['id'] is String) {
        ids.add(attachment['id'] as String);
      }
      if (ids.isEmpty && message.content.startsWith('soultalk/attachments/')) {
        final dao = AttachmentIndexDao(_dbService);
        final record = await dao.getByRelativePath(message.content);
        if (record != null) ids.add(record.id);
      }
      if (ids.isNotEmpty) {
        await _cleanupAttachmentsByIds(ids);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to cleanup attachment for message $messageId',
        name: 'ChatService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _cleanupAttachmentsByChat(String chatId) async {
    try {
      final dao = AttachmentIndexDao(_dbService);
      final records = await dao.getByChatId(chatId);
      await _deleteAttachmentRecords(records);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to cleanup attachments for chat $chatId',
        name: 'ChatService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _cleanupAttachmentsByIds(Set<String> ids) async {
    final dao = AttachmentIndexDao(_dbService);
    final records = <AttachmentIndexRecord>[];
    for (final id in ids) {
      final record = await dao.getById(id);
      if (record != null) records.add(record);
    }
    await _deleteAttachmentRecords(records);
  }

  Future<void> _deleteAttachmentRecords(
    List<AttachmentIndexRecord> records,
  ) async {
    if (records.isEmpty) return;
    final dao = AttachmentIndexDao(_dbService);
    final paths = await _createAppPaths();
    final rootPath = p.normalize(p.absolute(paths.root.path));
    for (final record in records) {
      try {
        await dao.deleteById(record.id);
        // 纵深防御：文件路径必须位于应用根目录内（防止索引被污染时删除目录外文件）
        final file = File(p.join(paths.root.path, record.relativePath));
        final filePath = p.normalize(p.absolute(file.path));
        if (filePath == rootPath || !p.isWithin(rootPath, filePath)) continue;
        if (await file.exists()) await file.delete();
      } catch (error, stackTrace) {
        developer.log(
          'Failed to delete attachment ${record.id}',
          name: 'ChatService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> retractMessage(String messageId, String newContent) =>
      _messageDao.updateTypeAndContent(
        messageId,
        MessageType.system.name,
        newContent,
      );

  /// 更新消息文本（编辑用户消息；清除流式/失败标记）。
  Future<void> updateMessageContent(String messageId, String content) =>
      _messageDao.updateContent(messageId, content, isStreaming: false);

  /// 删除某条消息之后（created_at 更晚）的全部消息，用于「编辑后重发」。
  /// 同步清理这些消息关联的附件（attachment_index + 磁盘文件），
  /// 避免长期形成孤儿文件并让备份膨胀。
  Future<void> deleteMessagesAfter(String contactId, String messageId) async {
    final msg = await _messageDao.getById(messageId);
    if (msg == null || msg.createdAt == null) return;
    final db = await _dbService.database;
    // 事务内先收集将删除消息的快照（消息删除后无法再按 id 读取，
    // 附件清理需要其 metadata/content），附件清理在事务外执行，
    // 失败不影响主删除流程（与 deleteMessage 语义一致）。
    final doomed = <({String id, String content, String? metadataJson})>[];
    await db.transaction((txn) async {
      final rows = await txn.query(
        'messages',
        columns: ['id', 'content', 'metadata'],
        where: 'contact_id = ? AND created_at > ?',
        whereArgs: [contactId, msg.createdAt!.toIso8601String()],
      );
      for (final row in rows) {
        final id = row['id'];
        if (id is! String) continue;
        doomed.add((
          id: id,
          content: row['content'] as String? ?? '',
          metadataJson: row['metadata'] as String?,
        ));
      }
      await _recordDeletionTombstones(
        txn,
        'messages',
        where: 'contact_id = ? AND created_at > ?',
        whereArgs: [contactId, msg.createdAt!.toIso8601String()],
      );
      await txn.delete(
        'messages',
        where: 'contact_id = ? AND created_at > ?',
        whereArgs: [contactId, msg.createdAt!.toIso8601String()],
      );
    });
    for (final entry in doomed) {
      await _cleanupAttachmentRefs(
        messageId: entry.id,
        content: entry.content,
        metadataJson: entry.metadataJson,
      );
    }
    await _contactDao.recomputeLastMessage(contactId);
  }

  /// 按消息快照清理附件（消息行可能已删除，因此接收快照数据）。
  Future<void> _cleanupAttachmentRefs({
    required String messageId,
    required String content,
    required String? metadataJson,
  }) async {
    try {
      final ids = <String>{};
      if (metadataJson != null) {
        final metadata = jsonDecode(metadataJson) as Map<String, dynamic>?;
        final attachment = metadata?['attachment'];
        if (attachment is Map && attachment['id'] is String) {
          ids.add(attachment['id'] as String);
        }
      }
      if (ids.isEmpty && content.startsWith('soultalk/attachments/')) {
        final dao = AttachmentIndexDao(_dbService);
        final record = await dao.getByRelativePath(content);
        if (record != null) ids.add(record.id);
      }
      if (ids.isNotEmpty) {
        await _cleanupAttachmentsByIds(ids);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to cleanup attachment for message $messageId',
        name: 'ChatService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 最终 Prompt 预览：返回与真实发送一致的 system prompt 与请求消息列表
  /// （世界书、角色卡、persona、preset、post_history_instructions 均已注入；
  /// 记忆注入为可选增强，预览时省略）。
  Future<({String systemPrompt, List<Message> requestMessages})> previewPrompt(
    Contact contact,
  ) async {
    final config = await _resolveConfig(contact);
    if (config == null) {
      throw StateError('未配置 API，请先在设置中添加 API 配置');
    }
    final history = await _messageDao.getRecentByContact(contact.id, 40);
    final historyList = history.where((m) => !m.isStreaming).toList();
    final assembled = await _promptAssemblyService.assemble(
      contact: contact,
      history: historyList,
    );
    final contextMessages = _contextManager.trim(historyList, config);
    final postHistoryPrompt = assembled.postHistoryPrompt?.trim();
    final requestMessages = [
      ...contextMessages,
      if (postHistoryPrompt != null && postHistoryPrompt.isNotEmpty)
        Message(
          id: '',
          contactId: contact.id,
          role: MessageRole.system,
          content: postHistoryPrompt,
        ),
    ];
    return (
      systemPrompt: assembled.systemPrompt ?? '',
      requestMessages: requestMessages,
    );
  }

  /// 解析联系人绑定的 API 配置（无绑定或不存在时取第一个可用配置）。
  Future<ApiConfig?> _resolveConfig(Contact contact) async {
    if (contact.apiConfigId != null) {
      final config = await _apiConfigDao.getById(contact.apiConfigId!);
      if (config != null) return config;
    }
    final configs = await _apiConfigDao.getAll();
    return configs.isEmpty ? null : configs.first;
  }

  Future<List<ApiConfig>> getApiConfigs() => _apiConfigDao.getAll();

  Future<ApiConfig> createApiConfig(ApiConfig config) =>
      _apiConfigDao.insert(config);

  Future<void> updateApiConfig(ApiConfig config) =>
      _apiConfigDao.update(config);

  Future<void> deleteApiConfig(String id) => _apiConfigDao.delete(id);

  Future<void> sendMessage({
    required Contact contact,
    required String userText,
    required void Function(Message userMsg, Message aiMsg) onMessagesCreated,
    required void Function(String content, bool isDone) onAiChunk,
    void Function(String error)? onError,

    /// 重试时传入已存在的用户消息 ID：不再重复插入用户消息，
    /// 只重新发起 AI 请求（避免重试造成重复消息）。
    String? existingUserMessageId,

    /// 停止生成/页面销毁时取消进行中的请求（取消后保留已生成内容）。
    CancelToken? cancelToken,
  }) async {
    final config = await _resolveConfig(contact);
    if (config == null) {
      onError?.call('未配置 API，请先在设置中添加 API 配置');
      return;
    }

    final regexScripts = await _regexScriptDao.getEnabled();

    String processedUserText = _regexService.applyScripts(
      userText,
      regexScripts,
      RegexPlacement.userInput,
    );

    Message? existingUserMsg;
    if (existingUserMessageId != null && existingUserMessageId.isNotEmpty) {
      existingUserMsg = await _messageDao.getById(existingUserMessageId);
      if (existingUserMsg == null) {
        onError?.call('原始消息不存在，请重新发送');
        return;
      }
    }

    String? aiMsgId;
    final buffer = StringBuffer();
    final reasoningBuf = StringBuffer();
    try {
      final userMsg =
          existingUserMsg ??
          (await _messageDao.insert(
            Message(
              id: '',
              contactId: contact.id,
              role: MessageRole.user,
              content: processedUserText,
              createdAt: DateTime.now(),
            ),
          ));

      await _contactDao.updateLastMessage(
        contact.id,
        processedUserText,
        DateTime.now(),
      );

      aiMsgId = _uuid.v4();
      final aiMsgPlaceholder = await _messageDao.insert(
        Message(
          id: aiMsgId,
          contactId: contact.id,
          role: MessageRole.assistant,
          content: '',
          isStreaming: true,
          createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
        ),
      );

      // UI 回调与事件发布纳入 try：回调抛异常时走失败清理路径，
      // 不会残留已入库的用户消息与流式占位。
      onMessagesCreated(userMsg, aiMsgPlaceholder);
      ExtensionEventBus.instance.publishType(
        'message_sent',
        contactId: contact.id,
        messageId: userMsg.id,
        payload: {'content': processedUserText},
      );
      ExtensionEventBus.instance.publishType(
        'generation_started',
        contactId: contact.id,
        messageId: aiMsgPlaceholder.id,
      );

      // 流式 DB 持久化节流：UI 实时性依赖 onAiChunk 回调与事件总线，
      // DB 仅作持久化，按 200ms 窗口批量写入以减少磁盘 IO。
      var lastDbWrite = DateTime.now().subtract(
        const Duration(milliseconds: 200),
      );
      final history = await _messageDao.getRecentByContact(contact.id, 40);
      final historyList = history.where((m) => !m.isStreaming).toList();
      final contextMessages = _contextManager.trim(historyList, config);

      final assembled = await _promptAssemblyService.assemble(
        contact: contact,
        history: historyList,
      );
      final systemPrompt = assembled.systemPrompt;
      final postHistoryPrompt = assembled.postHistoryPrompt?.trim();
      // post_history_instructions 按 ST 语义插在历史之后：
      // 作为最后一条 system 角色消息追加，而不是并入 system prompt。
      final requestMessages = [
        ...contextMessages,
        if (postHistoryPrompt != null && postHistoryPrompt.isNotEmpty)
          Message(
            id: '',
            contactId: contact.id,
            role: MessageRole.system,
            content: postHistoryPrompt,
          ),
      ];

      // ── Memory pipeline: before request ──────────────────────────────
      var effectiveSystemPrompt = systemPrompt;
      try {
        final memoryResult = await _memoryService.beforeRequest(
          contactId: contact.id,
          userText: processedUserText,
          messages: contextMessages
              .map(
                (m) => {
                  'role': m.role == MessageRole.user ? 'user' : 'assistant',
                  'content': m.content,
                },
              )
              .toList(),
        );
        if (memoryResult.stateText != null || memoryResult.cardText != null) {
          final memoryContext = [
            if (memoryResult.stateText != null) memoryResult.stateText!,
            if (memoryResult.cardText != null) memoryResult.cardText!,
          ].join('\n\n');
          effectiveSystemPrompt = effectiveSystemPrompt != null
              ? '$effectiveSystemPrompt\n\n$memoryContext'
              : memoryContext;
        }
      } catch (_) {
        // Memory pipeline failure must not block chat
      }

      final LlmService service = config.provider == LlmProvider.anthropic
          ? AnthropicAdapterImpl()
          : OpenAiAdapterImpl();

      if (config.streamEnabled) {
        await for (final chunk in service.sendMessageStream(
          config: config,
          messages: requestMessages,
          systemPrompt: effectiveSystemPrompt,
          cancelToken: cancelToken,
        )) {
          if (chunk.startsWith('\x00__R__\x00')) {
            reasoningBuf.write(chunk.substring('\x00__R__\x00'.length));
            continue;
          }
          buffer.write(chunk);
          final now = DateTime.now();
          if (now.difference(lastDbWrite).inMilliseconds >= 200) {
            await _messageDao.updateContent(
              aiMsgId,
              buffer.toString(),
              isStreaming: true,
            );
            lastDbWrite = now;
          }
          ExtensionEventBus.instance.publishType(
            'message_stream_chunk',
            contactId: contact.id,
            messageId: aiMsgId,
            payload: {'content': buffer.toString(), 'delta': chunk},
          );
          onAiChunk(buffer.toString(), false);
        }
      } else {
        buffer.write(
          await service.sendMessage(
            config: config,
            messages: requestMessages,
            systemPrompt: effectiveSystemPrompt,
            cancelToken: cancelToken,
          ),
        );
      }

      String finalAiContent = buffer.toString();

      final stripped = MemoryService.stripMemoryMarkers(finalAiContent);
      String displayContent = stripped.displayText;
      displayContent = _regexService.applyScripts(
        displayContent,
        regexScripts,
        RegexPlacement.aiOutput,
        // ST 语义：按当前消息在上下文中的深度过滤 minDepth/maxDepth
        depth: historyList.length,
      );

      final reasoningText = reasoningBuf.toString();
      if (displayContent.isEmpty && reasoningText.isNotEmpty) {
        displayContent = '[思考完成，但模型未输出文本回复]';
      }

      await _messageDao.updateContent(
        aiMsgId,
        displayContent,
        isStreaming: false,
      );
      if (reasoningText.isNotEmpty) {
        await _messageDao.updateMetadata(
          aiMsgId,
          jsonEncode({'reasoning_content': reasoningText}),
        );
      }
      onAiChunk(displayContent, true);
      ExtensionEventBus.instance.publishType(
        'message_received',
        contactId: contact.id,
        messageId: aiMsgId,
        payload: {'content': displayContent},
      );
      ExtensionEventBus.instance.publishType(
        'generation_completed',
        contactId: contact.id,
        messageId: aiMsgId,
      );

      await _contactDao.updateLastMessage(
        contact.id,
        displayContent,
        DateTime.now(),
      );

      try {
        await _memoryService.afterResponse(
          contactId: contact.id,
          aiResponse: finalAiContent,
        );
      } catch (_) {}

      _tryExtractMemory(contact, config);
    } catch (e) {
      // 用户停止生成（CancelToken 取消）：保留已生成内容并标记完成，
      // 不当作失败、不删除占位消息。
      if (e is DioException && e.type == DioExceptionType.cancel) {
        if (aiMsgId != null) {
          try {
            await _messageDao.updateContent(
              aiMsgId,
              buffer.toString(),
              isStreaming: false,
            );
          } catch (_) {}
        }
        onAiChunk(buffer.toString(), true);
        ExtensionEventBus.instance.publishType(
          'generation_completed',
          contactId: contact.id,
          messageId: aiMsgId ?? '',
          payload: {'cancelled': true},
        );
        return;
      }
      // 失败：保留占位消息并标记 failed（持久化失败状态），
      // UI 据此显示失败样式与重试/重新生成入口；重试复用
      // existingUserMessageId，不重复插入用户消息。
      // 先通知 onError 再 onAiChunk(isDone)：UI 据此跳过 TTS 等成功动作。
      onError?.call(e.toString());
      if (aiMsgId != null) {
        try {
          await _messageDao.updateFailed(aiMsgId, true);
        } catch (_) {}
      }
      onAiChunk(buffer.toString(), true);
      ExtensionEventBus.instance.publishType(
        'generation_failed',
        contactId: contact.id,
        messageId: aiMsgId ?? '',
        payload: {'error': e.toString()},
      );
    } finally {
      // 兜底：任何异常/取消路径下，若占位仍以 isStreaming 存在则删除，
      // 避免数据库残留空流式消息（成功路径已置 isStreaming=false 或已删除）。
      if (aiMsgId != null) {
        try {
          final m = await _messageDao.getById(aiMsgId);
          if (m != null && m.isStreaming) {
            await _messageDao.delete(aiMsgId);
          }
        } catch (_) {}
      }
    }
  }

  /// 继续生成：在已有 AI 消息内容后追加续写（不插入新用户/占位消息）。
  /// 以一条 user 提示消息向模型请求从已有内容继续。
  Future<void> continueFromAiMessage({
    required Contact contact,
    required String aiMessageId,
    required void Function(String content, bool isDone) onAiChunk,
    void Function(String error)? onError,
    CancelToken? cancelToken,
  }) async {
    final config = await _resolveConfig(contact);
    if (config == null) {
      onError?.call('未配置 API，请先在设置中添加 API 配置');
      return;
    }
    final existing = await _messageDao.getById(aiMessageId);
    if (existing == null || existing.role != MessageRole.assistant) {
      onError?.call('消息不存在或不可继续生成');
      return;
    }

    final regexScripts = await _regexScriptDao.getEnabled();
    final buffer = StringBuffer(existing.content);
    var lastDbWrite = DateTime.now().subtract(
      const Duration(milliseconds: 200),
    );
    try {
      final history = await _messageDao.getRecentByContact(contact.id, 40);
      final historyList = history.where((m) => !m.isStreaming).toList();
      final contextMessages = _contextManager.trim(historyList, config);

      final assembled = await _promptAssemblyService.assemble(
        contact: contact,
        history: historyList,
      );
      final postHistoryPrompt = assembled.postHistoryPrompt?.trim();
      final requestMessages = [
        ...contextMessages,
        if (postHistoryPrompt != null && postHistoryPrompt.isNotEmpty)
          Message(
            id: '',
            contactId: contact.id,
            role: MessageRole.system,
            content: postHistoryPrompt,
          ),
        // 续写语义：提示模型从已有内容继续，不重复已有内容
        Message(
          id: '',
          contactId: contact.id,
          role: MessageRole.user,
          content: '[请从以上消息的末尾继续生成，不要重复已有内容]',
        ),
      ];

      final LlmService service = config.provider == LlmProvider.anthropic
          ? AnthropicAdapterImpl()
          : OpenAiAdapterImpl();

      if (config.streamEnabled) {
        await for (final chunk in service.sendMessageStream(
          config: config,
          messages: requestMessages,
          systemPrompt: assembled.systemPrompt,
          cancelToken: cancelToken,
        )) {
          buffer.write(chunk);
          final now = DateTime.now();
          if (now.difference(lastDbWrite).inMilliseconds >= 200) {
            await _messageDao.updateContent(
              aiMessageId,
              buffer.toString(),
              isStreaming: true,
            );
            lastDbWrite = now;
          }
          ExtensionEventBus.instance.publishType(
            'message_stream_chunk',
            contactId: contact.id,
            messageId: aiMessageId,
            payload: {'content': buffer.toString(), 'delta': chunk},
          );
          onAiChunk(buffer.toString(), false);
        }
      } else {
        buffer.write(
          await service.sendMessage(
            config: config,
            messages: requestMessages,
            systemPrompt: assembled.systemPrompt,
            cancelToken: cancelToken,
          ),
        );
      }

      var displayContent = MemoryService.stripMemoryMarkers(
        buffer.toString(),
      ).displayText;
      displayContent = _regexService.applyScripts(
        displayContent,
        regexScripts,
        RegexPlacement.aiOutput,
        // ST 语义：按当前消息在上下文中的深度过滤 minDepth/maxDepth
        depth: historyList.length,
      );
      await _messageDao.updateContent(
        aiMessageId,
        displayContent,
        isStreaming: false,
      );
      await _messageDao.updateFailed(aiMessageId, false);
      onAiChunk(displayContent, true);
      ExtensionEventBus.instance.publishType(
        'generation_completed',
        contactId: contact.id,
        messageId: aiMessageId,
      );
      await _contactDao.updateLastMessage(
        contact.id,
        displayContent,
        DateTime.now(),
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        try {
          await _messageDao.updateContent(
            aiMessageId,
            buffer.toString(),
            isStreaming: false,
          );
        } catch (_) {}
        onAiChunk(buffer.toString(), true);
        return;
      }
      try {
        await _messageDao.updateFailed(aiMessageId, true);
      } catch (_) {}
      onError?.call(e.toString());
    }
  }

  Future<void> clearUnread(String contactId) =>
      _contactDao.clearUnread(contactId);

  Future<void> _tryExtractMemory(Contact contact, ApiConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryEnabled = prefs.getBool('memory_enabled') ?? false;
      if (!memoryEnabled) return;

      final interval = prefs.getInt('memory_interval') ?? 10;
      final messages = await _messageDao.getRecentByContact(
        contact.id,
        interval * 2,
      );
      final userMsgCount = messages
          .where((m) => m.role == MessageRole.user)
          .length;
      if (userMsgCount < interval) return;

      final lastExtractKey = 'memory_last_extract_count_${contact.id}';
      final lastCount = prefs.getInt(lastExtractKey) ?? 0;
      final currentCount = await _messageDao.countByContact(contact.id);
      if (currentCount - lastCount < interval) return;

      await prefs.setInt(lastExtractKey, currentCount);

      final useMainApi = prefs.getBool('memory_use_main_api') ?? true;
      ApiConfig memoryConfig = config;
      if (!useMainApi) {
        final configs = await _apiConfigDao.getAll();
        if (configs.length >= 2) {
          memoryConfig = configs[1];
        }
      }

      await _memoryService.extractMemories(
        contactId: contact.id,
        apiConfig: memoryConfig,
      );
    } catch (_) {}
  }
}
