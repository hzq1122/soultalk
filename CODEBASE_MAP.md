# soultalk 代码目录文档

## 项目概述

soultalk 是一个 Flutter AI 聊天应用，包含多 LLM 后端适配、角色卡、提示词预设、正则脚本、长期记忆、朋友圈、备份恢复、应用更新等功能。

## 顶层目录

| 目录/文件 | 用途 |
|-----------|------|
| `lib/` | Flutter 应用源码 |
| `test/` | 单元测试、服务测试、widget smoke test |
| `assets/` | 静态资源 |
| `android/` | Android 平台工程和包名配置 |
| `windows/` | Windows runner、资源信息、二进制名配置 |
| `linux/` | Linux runner、application id 和窗口标题配置 |
| `.github/workflows/` | CI 和 release 构建流程 |
| `docs/` | 计划、设计或维护文档 |
| `pubspec.yaml` | Dart 包名、依赖、版本、资源声明 |
| `DEVELOPMENT.md` | 维护规范和修改入口 |
| `CODEBASE_MAP.md` | 功能目录地图 |

## lib 目录结构

| 目录/文件 | 职责 |
|-----------|------|
| `lib/main.dart` | 应用入口，初始化 Flutter、数据库、Provider、主动消息、备份和更新检查 |
| `lib/router.dart` | GoRouter 路由表和 onboarding redirect |
| `lib/theme/` | 主题、颜色、明暗模式样式 |
| `lib/widgets/` | 跨页面复用 Widget |
| `lib/models/` | 数据模型、JSON 序列化、Freezed 生成入口 |
| `lib/providers/` | Riverpod 状态管理和页面数据装配 |
| `lib/pages/` | UI 页面和页面局部组件 |
| `lib/services/` | 业务服务、数据库 DAO、外部 API、导入导出、记忆等核心逻辑 |
| `lib/platform/` | 桌面、移动和 stub 平台差异配置 |

## pages 功能归属

| 功能 | 目录/文件 |
|------|-----------|
| 主导航框架 | `lib/pages/main_scaffold.dart` |
| 聊天页 | `lib/pages/chat/chat_page.dart` |
| 聊天输入栏 | `lib/pages/chat/widgets/input_bar.dart` |
| 消息气泡 | `lib/pages/chat/widgets/message_bubble.dart` |
| 输入状态动画 | `lib/pages/chat/widgets/typing_indicator.dart` |
| 会话列表 | `lib/pages/chat_list/chat_list_page.dart` |
| 联系人列表 | `lib/pages/contacts/contacts_page.dart` |
| 联系人详情 | `lib/pages/contacts/contact_detail_page.dart` |
| 发现入口 | `lib/pages/discover/discover_page.dart` |
| 朋友圈 | `lib/pages/discover/moments_page.dart` |
| 外卖/配送 | `lib/pages/delivery/delivery_page.dart` |
| 记忆管理页 | `lib/pages/memory/memory_page.dart` |
| 首次使用引导 | `lib/pages/onboarding/onboarding_page.dart` |
| 个人中心 | `lib/pages/profile/profile_page.dart` |
| API 设置 | `lib/pages/settings/api_settings_page.dart` |
| 通用设置 | `lib/pages/settings/general_settings_page.dart` |
| 备份恢复 | `lib/pages/settings/backup_page.dart` |
| 应用更新 | `lib/pages/settings/update_page.dart` |

## services 功能归属

| 功能 | 目录/文件 |
|------|-----------|
| LLM 抽象接口 | `lib/services/api/llm_service.dart` |
| OpenAI 兼容接口 | `lib/services/api/openai_adapter.dart` |
| Anthropic 接口 | `lib/services/api/anthropic_adapter.dart` |
| 上下文裁剪 | `lib/services/api/context_manager.dart` |
| 提示词组装 | `lib/services/api/prompt_assembly_service.dart` |
| 余额查询 | `lib/services/api/balance_service.dart` |
| 聊天主流程 | `lib/services/chat/chat_service.dart` |
| 打字模拟 | `lib/services/chat/typing_simulator.dart` |
| SQLite 初始化和迁移 | `lib/services/database/database_service.dart` |
| DAO 数据访问 | `lib/services/database/*_dao.dart` |
| 角色卡 JSON 服务 | `lib/services/character/character_card_service.dart` |
| 角色卡 PNG 解析 | `lib/services/character/character_png_service.dart` |
| 导入验证 | `lib/services/import/import_service.dart` |
| 正则脚本执行 | `lib/services/regex/regex_service.dart` |
| 朋友圈服务 | `lib/services/moments/moments_service.dart` |
| 主动消息 | `lib/services/proactive/proactive_service.dart` |
| 备份导入导出 | `lib/services/backup/backup_service.dart` |
| 自动备份 | `lib/services/backup/auto_backup_service.dart` |
| 备份加密 | `lib/services/backup/backup_encryption.dart` |
| 云存储抽象 | `lib/services/backup/cloud_storage.dart` |
| 应用更新 | `lib/services/update/update_service.dart` |
| 记忆提取主服务 | `lib/services/memory/memory_service.dart` |
| 记忆卡提取 | `lib/services/memory/card_extractor.dart` |
| 记忆卡检索 | `lib/services/memory/card_retriever.dart` |
| 记忆卡注入 | `lib/services/memory/card_injector.dart` |
| 记忆状态填充 | `lib/services/memory/state_filler.dart` |
| 记忆状态渲染 | `lib/services/memory/state_renderer.dart` |
| 记忆状态注入 | `lib/services/memory/state_injector.dart` |
| 检索门控 | `lib/services/memory/retrieval_gate.dart` |
| 记忆审核策略 | `lib/services/memory/review_policy.dart` |

## providers 功能归属

| 功能 | 文件 |
|------|------|
| API 配置 | `lib/providers/api_config_provider.dart` |
| 备份恢复状态 | `lib/providers/backup_provider.dart` |
| 余额查询状态 | `lib/providers/balance_provider.dart` |
| 购物车 | `lib/providers/cart_provider.dart` |
| 联系人 | `lib/providers/contacts_provider.dart` |
| 记忆 | `lib/providers/memory_provider.dart` |
| 消息 | `lib/providers/messages_provider.dart` |
| 朋友圈 | `lib/providers/moments_provider.dart` |
| 预设 | `lib/providers/preset_provider.dart` |
| 正则脚本 | `lib/providers/regex_script_provider.dart` |
| 全局设置 | `lib/providers/settings_provider.dart` |
| 应用更新 | `lib/providers/update_provider.dart` |
| 钱包 | `lib/providers/wallet_provider.dart` |

## models 功能归属

| 功能 | 文件 |
|------|------|
| API 配置 | `lib/models/api_config.dart` |
| 余额 | `lib/models/balance_info.dart` |
| 购物车 | `lib/models/cart_item.dart` |
| 角色卡 | `lib/models/character_card.dart` |
| 对话预设 | `lib/models/chat_preset.dart` |
| 联系人 | `lib/models/contact.dart` |
| 记忆卡 | `lib/models/memory_card.dart` |
| 记忆条目 | `lib/models/memory_entry.dart` |
| 记忆状态 | `lib/models/memory_state.dart` |
| 消息 | `lib/models/message.dart` |
| 朋友圈动态 | `lib/models/moment.dart` |
| 提示词系统 | `lib/models/prompt_system.dart` |
| 正则脚本 | `lib/models/regex_script.dart` |
| 语音配置 | `lib/models/voice_config.dart` |
| 钱包交易 | `lib/models/wallet_transaction.dart` |

## 平台配置

| 平台 | 关键位置 |
|------|----------|
| Android | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/talkai/soultalk/MainActivity.kt` |
| Windows | `windows/CMakeLists.txt`, `windows/runner/main.cpp`, `windows/runner/Runner.rc` |
| Linux | `linux/CMakeLists.txt`, `linux/runner/my_application.cc` |
| 跨平台差异 | `lib/platform/platform_config.dart` 及 `platform_config_*` 文件 |

## 测试目录

| 测试类型 | 位置 |
|----------|------|
| 应用 smoke test | `test/widget_test.dart` |
| 模型测试 | `test/models/` |
| 服务测试 | `test/services/` |
| 角色卡测试 | `test/models/character_card_test.dart` |
| 正则测试 | `test/services/regex_service_test.dart` |
| 导入验证测试 | `test/services/import_service_test.dart` |
| 记忆检索/审核测试 | `test/services/retrieval_gate_test.dart`, `test/services/review_policy_test.dart`, `test/services/state_renderer_test.dart` |

## 代码生成文件

以下文件由工具生成，不应手工编辑：

- `*.freezed.dart`
- `*.g.dart`

修改对应主模型文件后运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```
