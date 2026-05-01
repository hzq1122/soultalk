# AI Talk 代码目录文档

## 项目概述

AI Talk 是一款基于 Flutter 开发的 AI 聊天应用，支持多 LLM 后端（OpenAI、Anthropic 等）、角色卡片系统、正则表达式处理、TTS 语音合成、朋友圈模拟等功能。

---

## 目录结构

```
lib/
├── main.dart                          # 应用入口，初始化 Provider 和路由
├── router.dart                        # GoRouter 路由配置
│
├── models/                            # 数据模型层
│   ├── api_config.dart                # API 配置模型（Freezed）
│   ├── cart_item.dart                 # 购物车条目模型
│   ├── character_card.dart            # 角色卡片模型（V1/V2/V3 兼容）
│   ├── chat_preset.dart               # 对话补全预设模型
│   ├── contact.dart                   # 联系人/角色模型（Freezed）
│   ├── memory_entry.dart              # 记忆条目模型
│   ├── message.dart                   # 消息模型（Freezed）
│   ├── moment.dart                    # 朋友圈动态模型（Freezed）
│   ├── prompt_system.dart             # 提示词系统模型（PromptEntry/WorldInfoEntry/ContextTemplate/PromptPreset）
│   ├── regex_script.dart              # 正则脚本模型
│   ├── voice_config.dart              # 语音配置模型（TtsConfig/SttConfig/VoiceMapping/CustomVoice）
│   └── wallet_transaction.dart        # 钱包交易记录模型
│
├── providers/                         # Riverpod 状态管理层
│   ├── api_config_provider.dart       # API 配置 CRUD 状态
│   ├── backup_provider.dart           # 备份/恢复状态（StateNotifier）
│   ├── cart_provider.dart             # 购物车状态
│   ├── contacts_provider.dart         # 联系人 CRUD + 搜索/过滤状态
│   ├── memory_provider.dart           # 记忆条目状态
│   ├── messages_provider.dart         # 消息分页加载状态
│   ├── moments_provider.dart          # 朋友圈状态
│   ├── preset_provider.dart           # 对话预设状态
│   ├── regex_script_provider.dart     # 正则脚本状态
│   ├── settings_provider.dart         # 全局应用设置状态
│   ├── update_provider.dart           # 应用更新状态（StateNotifier）
│   └── wallet_provider.dart           # 钱包余额/交易状态
│
├── services/                          # 业务逻辑层
│   ├── api/                           # LLM API 适配层
│   │   ├── anthropic_adapter.dart     # Anthropic Claude API 适配器
│   │   ├── context_manager.dart       # 上下文裁剪策略（滑动窗口/Token预算）
│   │   ├── llm_service.dart           # LLM 服务抽象接口
│   │   ├── openai_adapter.dart        # OpenAI 兼容 API 适配器
│   │   └── prompt_assembly_service.dart # 提示词管道组装服务
│   │
│   ├── backup/                        # 备份恢复模块
│   │   ├── auto_backup_service.dart   # 自动备份定时服务
│   │   ├── backup_encryption.dart     # 备份加密/解密
│   │   ├── backup_service.dart        # 备份导出/导入核心逻辑
│   │   └── cloud_storage.dart         # 云存储（WebDAV/S3）抽象
│   │
│   ├── character/                     # 角色卡导入模块
│   │   ├── character_card_service.dart # JSON 角色卡导入服务
│   │   └── character_png_service.dart  # PNG 嵌入角色卡解析服务
│   │
│   ├── chat/                          # 聊天核心模块
│   │   └── chat_service.dart          # 聊天服务（消息发送/接收/正则/记忆提取）
│   │
│   ├── database/                      # 数据库 DAO 层
│   │   ├── api_config_dao.dart        # API 配置表操作
│   │   ├── cart_dao.dart              # 购物车表操作
│   │   ├── contact_dao.dart           # 联系人表操作
│   │   ├── database_service.dart      # SQLite 数据库初始化与迁移
│   │   ├── memory_entry_dao.dart      # 记忆条目表操作
│   │   ├── message_dao.dart           # 消息表操作
│   │   ├── moment_dao.dart            # 朋友圈表操作
│   │   ├── preset_dao.dart            # 预设表操作
│   │   ├── regex_script_dao.dart      # 正则脚本表操作
│   │   └── wallet_transaction_dao.dart # 钱包交易表操作
│   │
│   ├── import/                        # 导入验证模块
│   │   └── import_service.dart        # 文件导入验证服务（角色卡/正则/预设）
│   │
│   ├── memory/                        # 记忆提取模块
│   │   └── memory_service.dart        # AI 记忆提取服务
│   │
│   ├── moments/                       # 朋友圈模块
│   │   └── moments_service.dart       # 朋友圈生成/交互服务
│   │
│   ├── proactive/                     # 主动消息模块
│   │   └── proactive_service.dart     # 定时主动消息/朋友圈生成服务
│   │
│   ├── regex/                         # 正则处理模块
│   │   └── regex_service.dart         # 正则表达式解析/执行/宏替换服务
│   │
│   └── update/                        # 应用更新模块
│       └── update_service.dart        # 版本检查/下载/安装服务
│
├── pages/                             # UI 页面层
│   ├── chat/                          # 聊天页面
│   │   ├── chat_page.dart             # 聊天主页面（消息列表+输入栏+流式显示）
│   │   └── widgets/                   # 聊天子组件
│   │       ├── input_bar.dart         # 消息输入栏（文本/图片/转账/外卖）
│   │       ├── message_bubble.dart    # 消息气泡（文本/系统/转账/外卖/图片）
│   │       └── typing_indicator.dart  # AI 打字动画指示器
│   │
│   ├── chat_list/                     # 会话列表
│   │   └── chat_list_page.dart        # 会话列表页面（滑动删除/未读标记）
│   │
│   ├── contacts/                      # 联系人管理
│   │   ├── contact_detail_page.dart   # 联系人详情页面
│   │   └── contacts_page.dart         # 联系人列表页面（搜索/导入/分组）
│   │
│   ├── delivery/                      # 外卖点餐
│   │   └── delivery_page.dart         # 外卖点餐页面（菜单/购物车/结账）
│   │
│   ├── discover/                      # 发现页
│   │   ├── discover_page.dart         # 发现入口页面
│   │   └── moments_page.dart          # 朋友圈页面（发布/评论/AI回复）
│   │
│   ├── main_scaffold.dart             # 主导航框架（底部TabBar）
│   │
│   ├── memory/                        # 记忆管理
│   │   └── memory_page.dart           # 记忆条目管理页面
│   │
│   ├── onboarding/                    # 引导页
│   │   └── onboarding_page.dart       # 首次使用引导（API配置/角色创建）
│   │
│   ├── profile/                       # 个人中心
│   │   └── profile_page.dart          # 个人中心页面（设置/关于/重启引导）
│   │
│   └── settings/                      # 设置页面
│       ├── api_settings_page.dart     # API 配置管理页面
│       ├── backup_page.dart           # 备份/恢复页面
│       ├── general_settings_page.dart # 通用设置页面（提示词/正则/TTS/钱包等）
│       └── update_page.dart           # 应用更新页面
│
├── theme/                             # 主题样式
│   └── wechat_colors.dart             # 微信风格颜色常量
│
└── widgets/                           # 通用组件
    └── avatar_widget.dart             # 头像组件（本地文件/首字母回退）

test/                                  # 测试目录
├── models/
│   ├── character_card_test.dart       # 角色卡片模型测试
│   └── models_test.dart               # 记忆/钱包/提示词模型测试
└── services/
    ├── import_service_test.dart       # 导入验证服务测试
    └── regex_service_test.dart        # 正则服务测试
```

---

## 核心功能模块映射

| 功能 | 入口页面 | 核心服务 | Provider | 数据模型 |
|------|---------|---------|----------|---------|
| AI 聊天 | chat_page.dart | chat_service.dart | messages_provider.dart | message.dart |
| 提示词管道 | — | prompt_assembly_service.dart | preset_provider.dart | prompt_system.dart, chat_preset.dart |
| 正则处理 | — | regex_service.dart | regex_script_provider.dart | regex_script.dart |
| 角色管理 | contacts_page.dart | — | contacts_provider.dart | contact.dart, character_card.dart |
| 角色卡导入 | contacts_page.dart | import_service.dart, character_png_service.dart | — | character_card.dart |
| TTS/STT | general_settings_page.dart | — | — | voice_config.dart |
| 记忆提取 | memory_page.dart | memory_service.dart | memory_provider.dart | memory_entry.dart |
| 朋友圈 | moments_page.dart | moments_service.dart | moments_provider.dart | moment.dart |
| 主动消息 | — | proactive_service.dart | — | — |
| API 配置 | api_settings_page.dart | — | api_config_provider.dart | api_config.dart |
| 备份恢复 | backup_page.dart | backup_service.dart | backup_provider.dart | — |
| 应用更新 | update_page.dart | update_service.dart | update_provider.dart | — |
| 钱包系统 | delivery_page.dart | — | wallet_provider.dart | wallet_transaction.dart |
| 全局设置 | general_settings_page.dart | — | settings_provider.dart | — |

---

## 数据流架构

```
用户输入 → input_bar.dart → ChatService.sendMessage()
                              ├─ RegexService.applyScripts() (userInput 阶段)
                              ├─ PromptAssemblyService.assemble() (构建完整提示词)
                              │   ├─ 加载 PromptPreset (主提示词/辅助提示词/历史后指令)
                              │   ├─ 加载 WorldInfo (关键词匹配 → wiBefore/wiAfter)
                              │   ├─ ContextTemplate.render() (Handlebars 宏替换)
                              │   └─ RegexService.applyMacros() ({{user}}/{{char}})
                              ├─ ContextManager.trim() (上下文裁剪)
                              ├─ LlmService.sendMessageStream() (流式API调用)
                              ├─ RegexService.applyScripts() (aiOutput 阶段)
                              └─ MemoryService.extractMemories() (异步记忆提取)
```

---

## 已修复问题清单

| 编号 | 严重性 | 问题描述 | 修复文件 |
|------|--------|---------|---------|
| 1 | 致命 | chat_service.dart 变量 `history` 重复声明导致编译失败 | chat_service.dart |
| 2 | 高 | memory_entry fromDbMap 无空值保护，NULL 字段崩溃 | memory_entry.dart |
| 3 | 高 | wallet_transaction fromDbMap 无空值保护 | wallet_transaction.dart |
| 4 | 高 | prompt_system 枚举索引越界导致 RangeError | prompt_system.dart |
| 5 | 高 | regex_script fromDbMap `as int` 强转 NULL 崩溃 | regex_script.dart |
| 6 | 高 | regex_script copyWith minDepth/maxDepth 错误置 null | regex_script.dart |
| 7 | 高 | CharacterCard V3 alternateGreetings/extensions 被 toString() 损坏 | character_card.dart |
| 8 | 高 | CharacterCard buildSystemPrompt 未替换 {{user}}/{{char}} | character_card.dart |
| 9 | 高 | memory_entry toJson 丢失 id/contactId/updatedAt | memory_entry.dart |
| 10 | 高 | settings_provider state.value! 强制解包崩溃 | settings_provider.dart |
| 11 | 高 | preset_provider firstWhere 无 orElse 崩溃 | preset_provider.dart |
| 12 | 高 | update_provider copyWith errorMessage 意外清空 | update_provider.dart |
| 13 | 高 | openai/anthropic adapter API 响应无 null 保护 | openai_adapter.dart, anthropic_adapter.dart |
| 14 | 高 | 正则脚本被重复应用（chat_service + prompt_assembly_service） | chat_service.dart, prompt_assembly_service.dart |
| 15 | 中 | prompt_assembly_service 使用 fromV2Json 而非 fromAutoDetectJson | prompt_assembly_service.dart |
| 16 | 中 | memory_entry 运算符优先级歧义 | memory_entry.dart |
| 17 | 中 | wallet_transaction 缺少 copyWith/toJson/fromJson | wallet_transaction.dart |
| 18 | 中 | settings_provider darkMode key 未使用常量 | settings_provider.dart |
| 19 | 中 | Dio 每次请求创建新实例，不复用连接池 | openai_adapter.dart, anthropic_adapter.dart |
