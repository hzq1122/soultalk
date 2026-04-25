import '../../models/memory_entry.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../database/memory_entry_dao.dart';
import '../database/message_dao.dart';
import '../api/llm_service.dart';

class MemoryService {
  final MemoryEntryDao _memoryDao;
  final MessageDao _messageDao;

  MemoryService(this._memoryDao, this._messageDao);

  Future<List<MemoryEntry>> getMemories(String contactId) {
    return _memoryDao.getByContact(contactId);
  }

  Future<String> getMemoryPrompt(String contactId) async {
    final entries = await _memoryDao.getByContact(contactId);
    return MemoryEntry.tableToPrompt(entries);
  }

  Future<void> extractMemories({
    required String contactId,
    required ApiConfig apiConfig,
  }) async {
    final messages = await _messageDao.getRecentByContact(contactId, 30);
    if (messages.isEmpty) return;

    final conversationText = _buildConversationText(messages);

    final existingEntries = await _memoryDao.getByContact(contactId);
    final existingPrompt = MemoryEntry.tableToPrompt(existingEntries);

    final extractionPrompt = _buildExtractionPrompt(conversationText, existingPrompt);

    final service = LlmService.fromConfig(apiConfig);
    final response = await service.sendMessage(
      config: apiConfig,
      messages: [
        Message(
          id: '',
          contactId: contactId,
          role: MessageRole.user,
          content: extractionPrompt,
          createdAt: DateTime.now(),
        ),
      ],
      systemPrompt: '你是一个记忆提取助手。你的任务是从对话中提取关键信息并整理成结构化的记忆表格。只输出JSON数组，不要输出其他内容。',
    );

    final newEntries = MemoryEntry.fromLlmResponse(contactId, response);
    if (newEntries.isNotEmpty) {
      await _memoryDao.upsertAll(newEntries);
    }
  }

  String _buildConversationText(List<Message> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role == MessageRole.user ? '用户' : 'AI';
      buffer.writeln('$role: ${msg.content}');
    }
    return buffer.toString();
  }

  String _buildExtractionPrompt(String conversation, String existingMemory) {
    final buffer = StringBuffer();
    buffer.writeln('请从以下对话中提取关键信息，更新记忆表格。');
    buffer.writeln('提取用户的个人信息、偏好、重要事件等。');
    buffer.writeln();
    if (existingMemory.isNotEmpty) {
      buffer.writeln('现有记忆：');
      buffer.writeln(existingMemory);
      buffer.writeln();
    }
    buffer.writeln('最近对话：');
    buffer.writeln(conversation);
    buffer.writeln();
    buffer.writeln('请以JSON数组格式输出，每项包含 category、key、value 字段：');
    buffer.writeln('[{"category": "分类名", "key": "属性名", "value": "属性值"}]');
    buffer.writeln('只输出需要新增或更新的条目，不要重复已有的未变化的记忆。');
    return buffer.toString();
  }

  Future<void> deleteMemory(String id) => _memoryDao.delete(id);

  Future<void> clearMemories(String contactId) =>
      _memoryDao.deleteByContact(contactId);
}
