# Talk AI 开发指南

## 项目架构概览

```
lib/
├── main.dart                    # 应用入口
├── router.dart                  # 路由定义（所有页面路径）
├── theme/                       # 主题常量（颜色、样式）
│   ├── wechat_colors.dart
│   └── wechat_theme.dart
├── models/                      # 数据模型（freezed + json_serializable）
├── providers/                   # Riverpod 状态管理
├── services/                    # 业务逻辑层
│   ├── api/                     # LLM API 适配器
│   ├── backup/                  # 备份/恢复/加密
│   ├── chat/                    # 聊天服务 + 打字模拟
│   ├── database/                # SQLite DAO 层
│   ├── memory/                  # 记忆提取服务
│   ├── character/               # 角色卡服务
│   ├── moments/                 # 朋友圈服务
│   ├── proactive/               # AI 主动发消息服务
│   ├── regex/                   # 正则脚本服务
│   └── update/                  # 应用更新检查
└── pages/                       # 页面 UI
    ├── onboarding/              # 新手引导
    ├── chat/                    # 聊天页
    ├── chat_list/               # 聊天列表（首页）
    ├── contacts/                # 通讯录
    ├── discover/                # 发现页（朋友圈）
    ├── memory/                  # 记忆表格
    ├── profile/                 # 我的
    ├── delivery/                # 配送/外卖
    └── settings/                # 设置页
```

## 页面 → 文件对照表

### 主框架
| 页面/功能 | 文件 |
|-----------|------|
| 底部 Tab 壳（微信风格4 Tab） | `lib/pages/main_scaffold.dart` |
| 路由定义（所有页面路径） | `lib/router.dart` |
| 全局主题 | `lib/theme/wechat_colors.dart` |

### Tab 1: 聊天
| 页面/功能 | 文件 |
|-----------|------|
| 聊天列表（首页） | `lib/pages/chat_list/chat_list_page.dart` |
| 单聊对话页 | `lib/pages/chat/chat_page.dart` |
| 消息气泡 | `lib/pages/chat/widgets/message_bubble.dart` |
| 输入栏 | `lib/pages/chat/widgets/input_bar.dart` |
| 正在输入指示器 | `lib/pages/chat/widgets/typing_indicator.dart` |
| 聊天消息模型 | `lib/models/message.dart` |
| 聊天消息状态 | `lib/providers/messages_provider.dart` |
| 聊天业务逻辑 | `lib/services/chat/chat_service.dart` |
| AI 消息生成 | `lib/services/api/llm_service.dart` |
| OpenAI 协议适配 | `lib/services/api/openai_adapter.dart` |
| Anthropic 协议适配 | `lib/services/api/anthropic_adapter.dart` |
| 上下文管理 | `lib/services/api/context_manager.dart` |
| AI 主动发消息 | `lib/services/proactive/proactive_service.dart` |

### Tab 2: 通讯录
| 页面/功能 | 文件 |
|-----------|------|
| 通讯录列表 | `lib/pages/contacts/contacts_page.dart` |
| 联系人详情 | `lib/pages/contacts/contact_detail_page.dart` |
| 联系人模型 | `lib/models/contact.dart` |
| 联系人状态 | `lib/providers/contacts_provider.dart` |
| 角色卡服务 | `lib/services/character/character_card_service.dart` |

### Tab 3: 发现
| 页面/功能 | 文件 |
|-----------|------|
| 发现页 | `lib/pages/discover/discover_page.dart` |
| 朋友圈 | `lib/pages/discover/moments_page.dart` |
| 朋友圈模型 | `lib/models/moment.dart` |
| 朋友圈状态 | `lib/providers/moments_provider.dart` |
| 朋友圈服务 | `lib/services/moments/moments_service.dart` |
| 配送/外卖 | `lib/pages/delivery/delivery_page.dart` |
| 购物车状态 | `lib/providers/cart_provider.dart` |
| 钱包模型 | `lib/models/wallet_transaction.dart` |
| 钱包状态 | `lib/providers/wallet_provider.dart` |

### Tab 4: 我的
| 页面/功能 | 文件 |
|-----------|------|
| 个人中心 | `lib/pages/profile/profile_page.dart` |
| 通用设置 | `lib/pages/settings/general_settings_page.dart` |
| API 配置 | `lib/pages/settings/api_settings_page.dart` |
| 备份设置 | `lib/pages/settings/backup_page.dart` |
| 应用更新 | `lib/pages/settings/update_page.dart` |
| 记忆表格页 | `lib/pages/memory/memory_page.dart` |
| 新手引导 | `lib/pages/onboarding/onboarding_page.dart` |

### API 配置相关
| 功能 | 文件 |
|------|------|
| API 配置模型 | `lib/models/api_config.dart` |
| API 配置状态 | `lib/providers/api_config_provider.dart` |
| API 配置数据层 | `lib/services/database/api_config_dao.dart` |
| API 设置页 | `lib/pages/settings/api_settings_page.dart` |

### 记忆表格相关
| 功能 | 文件 |
|------|------|
| 记忆条目模型 | `lib/models/memory_entry.dart` |
| 记忆状态 | `lib/providers/memory_provider.dart` |
| 记忆提取服务 | `lib/services/memory/memory_service.dart` |
| 记忆数据层 | `lib/services/database/memory_entry_dao.dart` |
| 记忆表格页 | `lib/pages/memory/memory_page.dart` |

### 设置/全局
| 功能 | 文件 |
|------|------|
| 应用设置模型 + 持久化 | `lib/providers/settings_provider.dart` |
| 数据库统一入口 | `lib/services/database/database_service.dart` |

## 如何修改某个功能

### 原则
1. **改 UI** → 找 `lib/pages/` 下对应的页面文件
2. **改数据** → 找 `lib/models/` 下对应的模型文件
3. **改逻辑** → 找 `lib/providers/` 下的状态管理 和 `lib/services/` 下的服务文件
4. **改数据库** → 找 `lib/services/database/` 下的 DAO 文件

### 典型修改路径

- **修改聊天发送逻辑** → `lib/pages/chat/widgets/input_bar.dart` (UI) + `lib/services/chat/chat_service.dart` (逻辑)
- **调整 AI 回复行为** → `lib/services/api/llm_service.dart` + 对应的 adapter
- **新增/修改 API 配置字段** → `lib/models/api_config.dart` (模型) → 运行 `dart run build_runner build` (重新生成 freezed/json) → 修改使用处
- **调整记忆提取策略** → `lib/services/memory/memory_service.dart` (提取逻辑 + prompt)
- **修改页面主题** → `lib/theme/wechat_colors.dart`
- **添加新页面** → 创建 `lib/pages/xxx/xxx_page.dart` → 在 `lib/router.dart` 中注册路由
- **新手引导流程** → `lib/pages/onboarding/onboarding_page.dart`
