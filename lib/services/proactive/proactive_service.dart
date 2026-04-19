import 'dart:async';
import 'dart:math';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../api/llm_service.dart';
import '../moments/moments_service.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';

class ProactiveService {
  static final ProactiveService _instance = ProactiveService._internal();
  factory ProactiveService() => _instance;
  ProactiveService._internal();

  Timer? _timer;
  final _random = Random();
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  bool _initialized = false;

  void Function()? onNewMessage;

  void init() {
    if (_initialized) return;
    _initialized = true;
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  int _checkCount = 0;

  Future<void> _check() async {
    final now = DateTime.now();
    if (now.hour >= 23 || now.hour < 7) return;

    _checkCount++;
    if (_checkCount % 12 == 0) {
      MomentsService().init();
      await MomentsService().generateMomentsForAllContacts();
    }

    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }

      final lastProactive = contact.lastProactiveAt;
      final minHours = 2 + _random.nextInt(7);
      if (lastProactive != null &&
          now.difference(lastProactive).inHours < minHours) {
        continue;
      }

      if (_random.nextDouble() > 0.3) continue;

      await _sendProactiveMessage(contact, configs);
    }
  }

  Future<void> _sendProactiveMessage(
      Contact contact, List<ApiConfig> configs) async {
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = configs.where((c) => c.id == contact.apiConfigId).firstOrNull;
    }
    config ??= configs.first;

    final proactiveTypes = [
      '发一条日常问候消息',
      '分享一件你最近经历的有趣的事',
      '随便聊聊最近的心情',
      '分享一个你的想法或感悟',
      '问候对方最近怎么样',
      '分享你正在做的事情',
    ];
    final selectedType = proactiveTypes[_random.nextInt(proactiveTypes.length)];

    final hour = DateTime.now().hour;
    String timeContext;
    if (hour < 9) {
      timeContext = '现在是早上';
    } else if (hour < 12) {
      timeContext = '现在是上午';
    } else if (hour < 14) {
      timeContext = '现在是中午';
    } else if (hour < 18) {
      timeContext = '现在是下午';
    } else {
      timeContext = '现在是晚上';
    }

    final systemPrompt = '''${contact.systemPrompt}

你现在要主动给对方发一条消息。$timeContext。
请你$selectedType。
要求：
- 像真人一样自然，不要太正式
- 简短，1-3句话
- 符合你的角色性格
- 不要用"亲爱的"等过于亲密的称呼（除非角色设定如此）
- 直接输出消息内容，不要加任何前缀''';

    final service = LlmService.fromConfig(config);
    try {
      final dummyMsg = Message(
        id: 'ctx',
        contactId: contact.id,
        role: MessageRole.user,
        content: '（用户暂时不在线）',
      );

      final reply = await service.sendMessage(
        config: config,
        messages: [dummyMsg],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isEmpty) return;

      await _messageDao.insert(Message(
        id: '',
        contactId: contact.id,
        role: MessageRole.assistant,
        content: reply.trim(),
        createdAt: DateTime.now(),
      ));

      await _contactDao.updateLastMessage(
        contact.id,
        reply.trim(),
        DateTime.now(),
      );
      await _contactDao.incrementUnread(contact.id);

      final db = await DatabaseService().database;
      await db.update(
        'contacts',
        {'last_proactive_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [contact.id],
      );

      onNewMessage?.call();
    } catch (_) {}
  }
}
