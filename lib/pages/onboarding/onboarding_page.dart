import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_config.dart';
import '../../models/contact.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../theme/wechat_colors.dart';

const _kOnboardingDone = 'onboarding_done';

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

Future<void> setOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageCtrl = PageController();
  int _current = 0;
  static const _totalSteps = 4;

  // Step 2: API form
  late final _apiNameCtrl = TextEditingController(text: 'My API');
  late final _apiUrlCtrl = TextEditingController();
  late final _apiKeyCtrl = TextEditingController();
  late final _apiModelCtrl = TextEditingController(text: 'gpt-4o-mini');
  LlmProvider _apiProvider = LlmProvider.openai;
  bool _apiTesting = false;
  String? _apiTestResult;

  // Model list fetching
  List<String> _availableModels = [];
  bool _isFetchingModels = false;
  String? _fetchModelError;

  // Step 3: Character form
  final _charNameCtrl = TextEditingController();
  final _charPromptCtrl = TextEditingController();
  String? _selectedTemplate;

  static const _charTemplates = [
    {
      'name': '温柔女友',
      'prompt': '你是一个温柔体贴的女朋友。你关心对方的生活，会主动问候，分享日常小事，'
          '在对方难过时给予安慰。你的语气温柔、细腻，偶尔会撒娇但不做作。'
          '回答时自然、口语化，像普通聊天一样。'
    },
    {
      'name': '毒舌损友',
      'prompt': '你是一个毒舌但讲义气的损友。你说话直接、犀利，喜欢吐槽和开玩笑，'
          '但内心关心朋友。你的吐槽点到为止不会真的伤人，偶尔也会认真起来。'
          '回答时幽默风趣，不拘小节，偶尔用网络流行语。'
    },
    {
      'name': '专业顾问',
      'prompt': '你是一个知识渊博的专业顾问。你逻辑清晰，分析问题一针见血，'
          '善于从多个角度思考。你说话简洁有力，不废话，但会耐心解答问题。'
          '回答时条理分明，引用事实和数据，但不失人情味。'
    },
    {
      'name': '动漫伙伴',
      'prompt': '你是一个来自二次元的伙伴。你热情开朗，充满元气，喜欢用动漫梗和颜文字，'
          '但不会过度夸张。你对ACG文化了如指掌，能聊番剧、游戏、轻小说等各种话题。'
          '回答时活泼可爱，偶尔中二，让人感到轻松愉快。'
    },
  ];

  String get _defaultBaseUrl => switch (_apiProvider) {
        LlmProvider.openai => 'https://api.openai.com/v1',
        LlmProvider.anthropic => 'https://api.anthropic.com',
        LlmProvider.custom => '',
      };

  @override
  void dispose() {
    _pageCtrl.dispose();
    _apiNameCtrl.dispose();
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiModelCtrl.dispose();
    _charNameCtrl.dispose();
    _charPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _current = i),
                children: [
                  _buildWelcome(),
                  _buildApiConfig(),
                  _buildCharacter(),
                  _buildDone(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (_current > 0)
            TextButton(
              onPressed: () => _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
              child: const Text('上一步',
                  style: TextStyle(color: WeChatColors.textSecondary)),
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text('跳过全部',
                style: TextStyle(color: WeChatColors.textHint)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: _current < _totalSteps - 1
          ? SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WeChatColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (_current == 1) {
                    // Step 2: Save API config before proceeding if filled
                    _saveApiConfig();
                  } else if (_current == 2) {
                    _saveCharacter();
                  }
                  _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: const Text('下一步', style: TextStyle(fontSize: 16)),
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WeChatColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _finishOnboarding,
                child:
                    const Text('开始使用', style: TextStyle(fontSize: 16)),
              ),
            ),
    );
  }

  // ─── Step 1: Welcome ───────────────────────────────────────────────────

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: WeChatColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),
          const Text('欢迎使用 Talk AI',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text(
            'AI 驱动的虚拟社交世界',
            style: TextStyle(fontSize: 16, color: WeChatColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '在这里，每个 AI 都有独特的性格和故事',
            style: TextStyle(fontSize: 14, color: WeChatColors.textHint),
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.api, '配置 LLM API', '支持 OpenAI、Anthropic 及兼容服务'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.person_add, '创建 AI 角色', '定义性格、人设，打造专属聊天伙伴'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.auto_awesome, '沉浸式互动', 'AI 会主动联系你，像真人一样交流'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: WeChatColors.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: WeChatColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: API Config ────────────────────────────────────────────────

  Widget _buildApiConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('配置 API',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('连接 AI 服务以开始聊天',
              style:
                  TextStyle(fontSize: 14, color: WeChatColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: _apiNameCtrl,
            decoration:
                const InputDecoration(labelText: '配置名称', hintText: 'My API'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LlmProvider>(
            initialValue: _apiProvider,
            decoration: const InputDecoration(labelText: '提供商'),
            items: LlmProvider.values
                .map((p) => DropdownMenuItem(
                    value: p, child: Text(p.name.toUpperCase())))
                .toList(),
            onChanged: (p) {
              if (p == null) return;
              setState(() {
                _apiProvider = p;
                _availableModels = [];
                _fetchModelError = null;
                if (_apiUrlCtrl.text.isEmpty) {
                  _apiUrlCtrl.text = _defaultBaseUrl;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Base URL',
              hintText: _defaultBaseUrl,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _availableModels.isEmpty
                    ? TextField(
                        controller: _apiModelCtrl,
                        decoration: InputDecoration(
                          labelText: '模型',
                          hintText: 'gpt-4o-mini',
                          errorText: _fetchModelError,
                          errorMaxLines: 2,
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey(_availableModels.join(',')),
                        initialValue: _apiModelCtrl.text.isNotEmpty &&
                                _availableModels.contains(_apiModelCtrl.text)
                            ? _apiModelCtrl.text
                            : _availableModels.first,
                        decoration: const InputDecoration(labelText: '模型'),
                        isExpanded: true,
                        items: _availableModels
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _apiModelCtrl.text = v);
                        },
                      ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 48,
                child: _isFetchingModels
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _availableModels.isEmpty
                              ? Icons.cloud_download_outlined
                              : Icons.refresh,
                          color: WeChatColors.primary,
                        ),
                        tooltip: '从 API 获取模型列表',
                        onPressed: _fetchModels,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: _apiTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find, size: 18),
              label: Text(_apiTesting ? '测试中...' : '测试连接'),
              onPressed: _apiTesting ? null : _testApiConnection,
            ),
          ),
          if (_apiTestResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _apiTestResult!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _apiTestResult!.contains('成功')
                    ? WeChatColors.primary
                    : Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _testApiConnection() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _apiTestResult = '请先填写 API Key');
      return;
    }
    setState(() {
      _apiTesting = true;
      _apiTestResult = null;
    });
    try {
      final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10)));
      if (_apiProvider == LlmProvider.anthropic) {
        await dio.get(
          '${_apiUrlCtrl.text.trim().isEmpty ? _defaultBaseUrl : _apiUrlCtrl.text.trim()}/v1/models',
          options: Options(headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
          }),
        );
      } else {
        await dio.get(
          '${_apiUrlCtrl.text.trim().isEmpty ? _defaultBaseUrl : _apiUrlCtrl.text.trim()}/models',
          options: Options(headers: {'Authorization': 'Bearer $key'}),
        );
      }
      setState(() {
        _apiTesting = false;
        _apiTestResult = '连接成功';
      });
    } catch (e) {
      setState(() {
        _apiTesting = false;
        _apiTestResult = '连接失败: $e';
      });
    }
  }

  Future<void> _fetchModels() async {
    final baseUrl = _apiUrlCtrl.text.trim().isEmpty
        ? _defaultBaseUrl
        : _apiUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      setState(() => _fetchModelError = '请先填写 API Key');
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _fetchModelError = null;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      List<String> models;

      if (_apiProvider == LlmProvider.anthropic) {
        final resp = await dio.get(
          '$baseUrl/v1/models',
          options: Options(headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          }),
        );
        final list = (resp.data['data'] as List?) ?? [];
        models = list.map((m) => m['id'] as String).toList()..sort();
      } else {
        final resp = await dio.get(
          '$baseUrl/models',
          options: Options(headers: {
            'Authorization': 'Bearer $apiKey',
          }),
        );
        final list = (resp.data['data'] as List?) ?? [];
        models = list.map((m) => m['id'] as String).toList()..sort();
      }

      if (!mounted) return;
      setState(() {
        _availableModels = models;
        _isFetchingModels = false;
        if (models.isNotEmpty && !models.contains(_apiModelCtrl.text)) {
          _apiModelCtrl.text = models.first;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        msg = '连接超时，请检查 URL 是否正确';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = '无法连接到服务器，请检查 URL 和网络';
      } else if (e.response != null) {
        msg = 'HTTP ${e.response!.statusCode}：${e.response!.statusMessage}';
      } else {
        msg = '请求失败：${e.message}';
      }
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = e.toString();
      });
    }
  }

  Future<void> _saveApiConfig() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return; // User chose to skip

    final existing = ref.read(apiConfigProvider).value ?? [];
    final config = ApiConfig(
      id: '',
      name: _apiNameCtrl.text.trim().isEmpty ? 'My API' : _apiNameCtrl.text.trim(),
      provider: _apiProvider,
      baseUrl: _apiUrlCtrl.text.trim().isEmpty
          ? _defaultBaseUrl
          : _apiUrlCtrl.text.trim(),
      apiKey: key,
      model: _apiModelCtrl.text.trim().isEmpty
          ? 'gpt-4o-mini'
          : _apiModelCtrl.text.trim(),
    );

    // Don't duplicate if same key already exists
    if (existing.any((c) => c.apiKey == key && c.baseUrl == config.baseUrl)) {
      return;
    }
    await ref.read(apiConfigProvider.notifier).add(config);
  }

  // ─── Step 3: Character ─────────────────────────────────────────────────

  Widget _buildCharacter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('创建你的第一个 AI 角色',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('选择一个模板或自定义角色设定',
              style:
                  TextStyle(fontSize: 14, color: WeChatColors.textSecondary)),
          const SizedBox(height: 16),
          // Template chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _charTemplates.map((t) {
              final selected = _selectedTemplate == t['name'];
              return ChoiceChip(
                label: Text(t['name']!),
                selected: selected,
                selectedColor: WeChatColors.primary.withAlpha(51),
                backgroundColor: const Color(0xFFF5F5F5),
                onSelected: (v) {
                  setState(() {
                    _selectedTemplate = v ? t['name'] : null;
                    if (v) {
                      _charNameCtrl.text = t['name']!;
                      _charPromptCtrl.text = t['prompt']!;
                    } else {
                      _charNameCtrl.clear();
                      _charPromptCtrl.clear();
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _charNameCtrl,
            decoration:
                const InputDecoration(labelText: '角色名称', hintText: '给 AI 起个名字'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _charPromptCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '角色设定（系统提示词）',
              hintText: '描述 AI 的性格、说话方式、背景故事...\n\n'
                  '示例：你是一个温柔体贴的朋友，喜欢分享日常...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '角色设定决定了 AI 的说话风格和行为方式。写得越详细，AI 的表现越符合预期。'
            '可以随时在角色管理中修改。',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCharacter() async {
    final name = _charNameCtrl.text.trim();
    final prompt = _charPromptCtrl.text.trim();
    if (name.isEmpty || prompt.isEmpty) return; // User chose to skip

    final apiConfigs = ref.read(apiConfigProvider).value ?? [];
    final contact = Contact(
      id: const Uuid().v4(),
      name: name,
      systemPrompt: prompt,
      apiConfigId: apiConfigs.isNotEmpty ? apiConfigs.first.id : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(contactsProvider.notifier).add(contact);
  }

  // ─── Step 4: Done ──────────────────────────────────────────────────────

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: WeChatColors.primary, size: 80),
          const SizedBox(height: 24),
          const Text('一切就绪！',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            '你已经配置好了 API 和 AI 角色',
            style: TextStyle(fontSize: 16, color: WeChatColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            '现在可以开始和你的 AI 伙伴聊天了',
            style: TextStyle(fontSize: 14, color: WeChatColors.textHint),
          ),
          const SizedBox(height: 24),
          const Text(
            '提示：AI 会主动给你发消息哦，记得去聊天列表看看！',
            style: TextStyle(fontSize: 13, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    // Save current step data before finishing
    if (_current <= 1) await _saveApiConfig();
    if (_current <= 2) await _saveCharacter();
    await setOnboardingDone();
    if (mounted) context.go('/chats');
  }
}
