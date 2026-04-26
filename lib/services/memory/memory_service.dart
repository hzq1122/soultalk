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
      systemPrompt: '你是一个记忆提取助手。你的任务是从对话中提取关键信息并整理成JSON格式。'
          '仅使用以下标准类别：基本信息、偏好习惯、重要事件、人际关系、健康信息、工作学习、其他。'
          '只输出JSON数组，不要任何其他内容。',
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
    buffer.writeln('分析以下对话，提取关于"用户"的关键信息。');
    buffer.writeln();
    buffer.writeln('【信息类别】请使用以下标准类别之一：');
    buffer.writeln('  "基本信息" — 姓名、年龄、性别、职业、所在地等');
    buffer.writeln('  "偏好习惯" — 喜好、厌恶、习惯、饮食偏好等');
    buffer.writeln('  "重要事件" — 经历、计划、里程碑等');
    buffer.writeln('  "人际关系" — 与其他人物的关系动态');
    buffer.writeln('  "健康信息" — 身体状况、过敏、病史等');
    buffer.writeln('  "工作学习" — 工作、学校、技能等');
    buffer.writeln('  "其他" — 以上类别不适用的信息');
    buffer.writeln();
    buffer.writeln('【输出格式】严格输出以下JSON数组，每条记录3个固定字段：');
    buffer.writeln('[{"category":"基本信息","key":"姓名","value":"小明"},');
    buffer.writeln(' {"category":"偏好习惯","key":"喜欢的食物","value":"奶茶"},');
    buffer.writeln(' {"category":"重要事件","key":"下周计划","value":"去北京出差"}]');
    buffer.writeln();
    buffer.writeln('规则：');
    buffer.writeln('- key 描述属性名（如"年龄"），value 描述属性值（如"25岁"）');
    buffer.writeln('- 一条记录只包含一个事实，不要合并多项信息');
    buffer.writeln('- 只输出新增或已变化的信息，未变化的不输出');
    buffer.writeln('- 如果无新信息，输出空数组 []');
    buffer.writeln('- 只输出JSON，不要任何解释文字、markdown标记或代码围栏');
    buffer.writeln();
    if (existingMemory.isNotEmpty) {
      buffer.writeln('【已知信息（避免重复）】');
      buffer.writeln(existingMemory);
      buffer.writeln();
    }
    buffer.writeln('【待分析对话】');
    buffer.writeln(conversation);
    return buffer.toString();
  }

  Future<void> deleteMemory(String id) => _memoryDao.delete(id);

  Future<void> clearMemories(String contactId) =>
      _memoryDao.deleteByContact(contactId);
}
