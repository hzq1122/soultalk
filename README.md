# SoulTalk

AI 驱动的微信风格社交应用 — 三层记忆架构, 多平台 API 额度查询, 角色卡系统。

[![Build and Release APK](https://github.com/hzq1122/soultalk/actions/workflows/release.yml/badge.svg)](https://github.com/hzq1122/soultalk/actions/workflows/release.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.x-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.x-blue)](https://dart.dev)

---

## 功能特性

### 记忆系统（三层架构）
| 层级 | 职责 | 注入时机 |
|------|------|---------|
| **状态板** (Hot State) | 会话级实时状态（心情/话题/进度） | 每轮对话前 |
| **记忆卡片** (Warm Memory) | 经审核的长期记忆（评分/作用域/标签） | 检索门控按需触发 |
| **关键词检索** (Cold Retrieval) | 关键词匹配召回记忆卡片 | RetrievalGate 判定后 |

Pipeline: `StateRender → StateInject → RetrievalGate → CardRetrieve → CardInject → LLM → StateFiller → CardExtract → ReviewPolicy → Insert`

### API 管理
- **多平台余额查询**: DeepSeek / StepFun / SiliconFlow / OpenRouter / Novita AI / Anthropic
- **余额不足警告**: 剩余 < 20% 红色高亮提示
- **自动获取模型列表**: 输入 API Key 后一键拉取可用模型
- **多配置切换**: 支持多套 API 配置，角色可绑定不同后端

### 角色系统
- SillyTavern V2/V3 PNG/JSON 角色卡导入
- 自定义系统提示词 + 预设模板
- Handlebars 宏替换（`{{user}}` / `{{char}}` / `{{wiBefore}}` 等）
- 角色标签、置顶、未读计数

### 微信风格社交
- 底部导航：聊天 / 通讯录 / 发现 / 我
- 朋友圈：AI 角色自动发动态，点赞评论
- 外卖点餐 + 购物车 + 钱包交易记录
- 主动消息：AI 角色定时主动找你聊天

### 工程特性
- **平台差异化配置**: Android/Win/iOS 不同上下文窗口、批处理大小
- **条件编译**: `PlatformConfig.current` 运行时自适应
- **GitHub Release 更新**: 版本号比较 + 完整更新日志 + 用户决定是否下载
- **备份恢复**: ZIP 导出导入, AES 加密, WebDAV/S3 云同步, 自动定时备份
- **WAL 模式 SQLite**: 并发安全, busy_timeout 保护

---

## 快速开始

### 环境要求
- Flutter SDK 3.41.x
- Dart SDK 3.11.x
- Android Studio 或 VS Code
- 有效的 LLM API Key（OpenAI 兼容 / Anthropic）

### 安装

```bash
# 克隆仓库
git clone https://github.com/hzq1122/soultalk.git
cd soultalk

# 安装依赖
flutter pub get

# 生成代码
dart run build_runner build --delete-conflicting-outputs

# 运行（需要连接的 Android 设备或模拟器）
flutter run
```

### 配置 API

1. 启动应用 → 底部导航「我」→「API 设置」
2. 点击 `+` 添加配置
3. 选择 Provider（OpenAI / Anthropic / Custom）
4. 填入 Base URL、API Key、模型名
5. 点击 ☁️ 按钮自动获取可用模型列表
6. 点击 💰 按钮查询余额

### 平台差异化参数

| 参数 | Android | Windows |
|------|---------|---------|
| 状态板上限 | 600 chars | 1200 chars |
| 检索 Top-K | 3 张卡片 | 5 张卡片 |
| 检索间隔 | 每 8 轮 | 每 6 轮 |
| API 超时 | 15s | 10s |
| DB 批处理 | 100 条 | 500 条 |

---

## 项目结构

```
lib/
├── main.dart                          # 应用入口, ProviderScope, GoRouter
├── router.dart                        # 路由配置
│
├── models/                            # 数据模型
│   ├── api_config.dart                # API 配置（Freezed）
│   ├── balance_info.dart              # 余额快照模型
│   ├── character_card.dart            # 角色卡 V1/V2/V3
│   ├── contact.dart                   # 联系人/角色
│   ├── memory_card.dart               # 记忆卡片（Warm 层）
│   ├── memory_entry.dart              # 记忆条目（Legacy）
│   ├── memory_state.dart              # 状态板（Hot 层）
│   ├── message.dart                   # 消息
│   ├── moment.dart                    # 朋友圈动态
│   ├── prompt_system.dart             # PromptEntry/WorldInfo/ContextTemplate
│   ├── regex_script.dart              # 正则脚本
│   ├── voice_config.dart              # TTS/STT/VoiceMapping
│   └── wallet_transaction.dart        # 钱包交易
│
├── providers/                         # Riverpod 状态管理
│   ├── api_config_provider.dart
│   ├── balance_provider.dart          # 余额状态 + 自动定时刷新
│   ├── contacts_provider.dart
│   ├── memory_provider.dart           # 三层记忆统一 Provider
│   ├── messages_provider.dart
│   ├── moments_provider.dart
│   ├── preset_provider.dart
│   ├── settings_provider.dart
│   ├── update_provider.dart
│   └── wallet_provider.dart
│
├── services/
│   ├── api/
│   │   ├── anthropic_adapter.dart     # Claude API 适配器
│   │   ├── balance_service.dart       # 多平台余额查询
│   │   ├── context_manager.dart       # 上下文裁剪
│   │   ├── llm_service.dart           # LLM 抽象接口
│   │   ├── openai_adapter.dart        # OpenAI 兼容适配器
│   │   └── prompt_assembly_service.dart # Prompt 管道组装
│   │
│   ├── backup/                        # 备份模块
│   │   ├── auto_backup_service.dart
│   │   ├── backup_encryption.dart
│   │   ├── backup_service.dart
│   │   └── cloud_storage.dart         # WebDAV/S3
│   │
│   ├── character/
│   │   ├── character_card_service.dart
│   │   └── character_png_service.dart
│   │
│   ├── chat/
│   │   └── chat_service.dart          # 消息收发 + 记忆管线集成
│   │
│   ├── database/                      # SQLite DAO 层
│   │   ├── database_service.dart      # 初始化 + 迁移 (v6)
│   │   ├── memory_card_dao.dart
│   │   ├── memory_entry_dao.dart
│   │   ├── memory_state_dao.dart
│   │   └── ...（共 10 个 DAO）
│   │
│   ├── import/
│   │   └── import_service.dart        # 文件导入验证
│   │
│   ├── memory/                        # 三层记忆实现
│   │   ├── memory_service.dart        # 管线编排器
│   │   ├── state_renderer.dart        # 状态板渲染
│   │   ├── state_injector.dart        # 状态注入
│   │   ├── retrieval_gate.dart        # 检索门控
│   │   ├── card_retriever.dart        # 关键字检索 + 评分
│   │   ├── card_injector.dart         # 卡片注入
│   │   ├── state_filler.dart          # 状态填充
│   │   ├── card_extractor.dart        # 卡片提取
│   │   └── review_policy.dart         # 审核策略
│   │
│   ├── moments/                       # 朋友圈
│   ├── proactive/                     # 主动消息
│   ├── regex/                         # 正则引擎
│   └── update/                        # 版本检查 + 下载
│
├── platform/                          # 平台差异
│   ├── platform_config.dart           # 抽象类 + 工厂
│   ├── platform_config_mobile.dart    # Android/iOS
│   ├── platform_config_desktop.dart   # Win/Mac/Linux
│   └── platform_config_stub.dart      # 测试/Web
│
├── pages/                             # UI 层
│   ├── main_scaffold.dart             # 底部 TabBar
│   ├── onboarding/                    # 引导向导
│   ├── chat_list/                     # 会话列表
│   ├── chat/                          # 聊天页 + Widgets
│   ├── contacts/                      # 联系人管理
│   ├── discover/                      # 发现 + 朋友圈
│   ├── memory/                        # 记忆管理（三视图）
│   ├── profile/                       # 个人中心
│   └── settings/                      # API/通用/备份/更新
│
├── theme/                             # 微信配色
└── widgets/                           # 通用组件
```

---

## 记忆系统数据流

```
用户输入 → ChatService.sendMessage()
              │
              ├─ RegexService.applyScripts()    (userInput 阶段)
              ├─ MemoryService.beforeRequest()
              │    ├─ StateRenderer.render()     → 状态板文本
              │    ├─ StateInjector.inject()     → 注入 prompt
              │    ├─ RetrievalGate.decide()     → 判定是否检索
              │    ├─ CardRetriever.retrieve()   → 关键词 + 评分
              │    └─ CardInjector.inject()      → 注入 prompt
              │
              ├─ PromptAssemblyService.assemble()
              ├─ ContextManager.trim()
              ├─ LlmService.sendMessageStream()  → 流式调用
              │
              ├─ RegexService.applyScripts()    (aiOutput 阶段)
              └─ MemoryService.afterResponse()
                   ├─ StateFiller.fillFromResponse() → 更新状态板
                   ├─ CardExtractor.extractFromResponse() → 提取候选卡片
                   └─ ReviewPolicy.review()     → 审核入库
```

---

## API 余额查询

| 平台 | 检测方式 | 端点 | 单位 |
|------|---------|------|------|
| DeepSeek | `api.deepseek.com` | `/user/balance` | CNY |
| StepFun | `api.stepfun` | `/v1/accounts` | CNY |
| SiliconFlow CN | `api.siliconflow.cn` | `/v1/user/info` | CNY |
| SiliconFlow EN | `api.siliconflow.com` | `/v1/user/info` | USD |
| OpenRouter | `openrouter.ai` | `/api/v1/credits` | credits |
| Novita AI | `api.novita.ai` | `/v3/user/balance` | USD* |
| Anthropic | `api.anthropic.com` | — | usage-based |

\* Novita 余额需 ÷10000

---

## 更新流程

1. 用户打开「我 → 检查更新」
2. App 调用 GitHub Releases API (`hzq1122/soultalk`)
3. 比较当前版本与最新 Release
4. 有更新时展示：
   - 新版本号
   - 安装包大小
   - **完整更新日志**（所有中间版本）
5. 用户选择「立即下载更新」或「以后再说」
6. 下载完成后点击安装 APK

发布新版本：创建 `v*` 格式 Tag 并推送，CI 自动构建 APK + 创建 GitHub Release。

---

## 开发

```bash
# 代码生成
dart run build_runner build --delete-conflicting-outputs

# 静态分析
dart analyze lib/

# 运行测试
flutter test

# 构建 APK
flutter build apk --release
```

### 数据库迁移

版本号在 `database_service.dart` 中管理 (当前 v6):

| 版本 | 新增 |
|------|------|
| v1 | api_configs, contacts, messages |
| v2 | moments, proactive 字段 |
| v3 | chat_presets, cart_items |
| v4 | regex_scripts, memory_entries |
| v5 | wallet_transactions |
| v6 | memory_states, memory_cards, WAL 模式 |

---

## 架构决策

- **关键词匹配替代向量检索**: 避免 embedding API 开销，移动端更稳定
- **记忆卡片替代关系图**: 用 tags + scope 替代 jiyi1 的 8 种关系边
- **平铺状态板替代模板系统**: key-value 结构覆盖 14 种语义类别
- **平台差异化**: Android 保守参数（600 chars 上下文 / 3 张卡片），桌面宽松

---

## License

MIT

---

**SoulTalk** — AI 角色, 有记忆, 有温度。
