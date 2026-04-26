# Talk AI - AI驱动的微信风格社交应用

Talk AI 是一款基于 Flutter 开发的仿微信风格 AI 社交应用，让用户可以与自定义的 AI 角色进行自然对话，并体验类似微信的社交功能（聊天、通讯录、朋友圈等）。

## ✨ 功能特性

### 🤖 AI 聊天
- **多模型支持**：集成 OpenAI (GPT) 和 Anthropic (Claude) API，支持自定义 API 配置
- **流式响应**：实时显示 AI 回复，提供更自然的对话体验
- **角色定制**：支持 SillyTavern V2 角色卡导入，可自定义系统提示词
- **上下文管理**：智能上下文裁剪策略，保持对话连贯性

### 👥 社交功能
- **仿微信界面**：熟悉的底部导航栏（AI Chat、通讯录、发现、我）
- **联系人管理**：创建、编辑、删除 AI 联系人，支持头像、描述、标签
- **朋友圈动态**：AI 角色自动生成朋友圈内容，支持点赞、评论
- **主动互动**：AI 角色可主动发送消息，模拟真实社交体验

### 🚶 新手引导
- **引导向导**：首次启动自动弹出 4 步向导，配置 API → 创建角色 → 开始聊天
- **可跳过**：所有步骤均可跳过，后续可在设置中重新触发
- **模板角色**：内置 4 种预设角色模板（温柔女友、毒舌损友、专业顾问、动漫伙伴）
- **自定义角色**：支持手写系统提示词，完全定制 AI 性格

### 🔧 技术特性
- **本地数据库**：使用 SQLite 存储联系人、消息、动态等数据
- **状态管理**：Riverpod 提供响应式状态管理
- **路由系统**：Go Router 实现声明式路由
- **主题系统**：微信风格配色方案，支持亮色主题
- **代码生成**：Freezed + JSON Serializable 自动生成模型类
- **数据备份**：支持 ZIP 导出导入，可选板块，WebDAV / S3 云存储
- **自动备份**：定时检测数据变更，自动上传云端
- **更新检查**：GitHub Release 更新检测，应用内下载安装

## 📱 应用截图

> 截图待添加

## 🛠 技术栈

- **框架**: Flutter 3.11+
- **语言**: Dart
- **状态管理**: Riverpod 2.6+
- **数据库**: sqflite (SQLite)
- **网络请求**: Dio
- **路由**: Go Router
- **数据模型**: Freezed + JSON Serializable
- **文件操作**: file_picker, image_picker
- **工具**: uuid, crypto, path_provider, shared_preferences

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.11.4 或更高版本
- Dart 3.11.4 或更高版本
- Android Studio / VS Code（推荐）
- 有效的 OpenAI 或 Anthropic API 密钥

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/hzq1122/AI_talk.git
   cd AI_talk
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **代码生成**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **配置 API 密钥**
   - 运行应用
   - 进入"我" → "API 设置"
   - 添加 OpenAI 或 Anthropic API 配置
   - 或使用默认配置

5. **运行应用**
   ```bash
   # Android
   flutter run
   
   # 或指定设备
   flutter run -d <device_id>
   ```

### 平台支持
- ✅ Android（主要测试平台）
- ✅ Windows（支持）
- ⚠️ iOS（理论支持，需自行配置）
- ⚠️ macOS（理论支持，需自行配置）
- ⚠️ Web（未测试）

## 📖 使用指南

### 首次使用（新手引导）
1. 首次启动自动进入引导向导
2. **步骤 1**：了解应用功能
3. **步骤 2**：配置 API（OpenAI / Anthropic / 自定义），支持连接测试
4. **步骤 3**：创建第一个 AI 角色 — 可选预设模板或手写角色设定
5. **步骤 4**：确认设置，进入主页开始聊天
6. 所有步骤均可跳过，后续在"我 → 新手引导"重新触发

### 创建 AI 角色
1. 进入"我 → 角色管理"或"通讯录"
2. 点击 + 创建新角色
3. 填写角色名称和系统提示词（性格、说话方式、背景故事）
4. 可选：导入 SillyTavern V2 PNG 角色卡
5. 绑定 API 配置，启用主动消息

### 朋友圈功能
- AI 角色会定期自动生成朋友圈动态
- 用户可以查看所有 AI 角色的动态
- 支持点赞、评论互动
- AI 角色会自动回复评论

### 主动消息
- 开启"主动消息"开关后，AI 角色会随机发送消息
- 发送频率和内容基于角色设定和系统时间
- 模拟真实社交中的主动互动

## 🏗 项目结构

```
lib/
├── main.dart                    # 应用入口
├── router.dart                  # 路由配置
│
├── models/                      # 数据模型
│   ├── api_config.dart          # API 配置模型
│   ├── character_card.dart      # 角色卡模型
│   ├── contact.dart             # 联系人模型
│   ├── message.dart             # 消息模型
│   └── moment.dart              # 朋友圈动态模型
│
├── pages/                       # 页面组件
│   ├── main_scaffold.dart       # 主框架（底部导航）
│   ├── onboarding/              # 新手引导向导
│   ├── chat_list/               # 聊天列表页
│   ├── chat/                    # 聊天页
│   ├── contacts/                # 通讯录相关页
│   ├── discover/                # 发现页相关
│   ├── profile/                 # 个人资料页
│   └── settings/                # 设置页（API、通用、备份、更新）
│
├── services/                    # 业务逻辑
│   ├── api/                     # API 相关服务
│   ├── chat/                    # 聊天服务
│   ├── database/                # 数据库操作
│   ├── moments/                 # 朋友圈服务
│   └── proactive/               # 主动消息服务
│
├── providers/                   # Riverpod 提供者
│   ├── api_config_provider.dart
│   ├── contacts_provider.dart
│   ├── messages_provider.dart
│   └── moments_provider.dart
│
├── theme/                       # 主题配置
│   ├── wechat_colors.dart       # 颜色定义
│   └── wechat_theme.dart        # 主题定义
│
└── widgets/                     # 通用组件
    └── avatar_widget.dart       # 头像组件
```

### 核心服务说明

#### `LlmService` (lib/services/api/llm_service.dart)
- 统一的 LLM 服务接口
- 支持 OpenAI 和 Anthropic 适配器
- 提供流式和非流式两种调用方式

#### `ChatService` (lib/services/chat/chat_service.dart)
- 管理聊天相关的所有业务逻辑
- 处理消息发送、接收、存储
- 集成上下文管理和流式响应

#### `ProactiveService` (lib/services/proactive/proactive_service.dart)
- 负责 AI 角色的主动消息发送
- 基于时间、概率和角色设定决定发送时机
- 定期检查并发送消息

#### `MomentsService` (lib/services/moments/moments_service.dart)
- 管理朋友圈动态的生成和交互
- AI 角色自动生成动态内容
- 处理点赞、评论等社交互动

## ⚙️ API 配置

### 支持的提供商
1. **OpenAI**
   - 模型：gpt-4o-mini（默认）、gpt-4o、gpt-3.5-turbo 等
   - 基础 URL：`https://api.openai.com/v1`

2. **Anthropic**
   - 模型：claude-3-haiku、claude-3-sonnet、claude-3-opus 等
   - 基础 URL：`https://api.anthropic.com/v1`

3. **自定义**
   - 支持自定义基础 URL，兼容 OpenAI 格式的 API

### 配置参数
- **API 密钥**：必需的认证密钥
- **模型**：选择的 LLM 模型
- **最大令牌数**：单次请求的最大 token 数（默认 4096）
- **温度**：控制回复的随机性（0.0-1.0，默认 0.8）
- **流式启用**：是否启用流式响应（推荐开启）

## 🗄️ 数据模型

### Contact（联系人）
```dart
{
  id: String,           // 唯一标识
  name: String,         // 名称
  avatar: String?,      // 头像路径
  description: String,  // 描述
  apiConfigId: String?, // 绑定的 API 配置
  systemPrompt: String, // 系统提示词
  characterCardJson: String?, // 角色卡 JSON
  tags: List<String>,   // 标签
  pinned: bool,         // 是否置顶
  unreadCount: int,     // 未读消息数
  lastMessage: String?, // 最后一条消息
  lastMessageAt: DateTime?, // 最后消息时间
  proactiveEnabled: bool, // 是否启用主动消息
  ...
}
```

### Message（消息）
```dart
{
  id: String,
  contactId: String,
  role: MessageRole,    // user/assistant/system
  content: String,
  type: MessageType,    // text/image/transfer/delivery/system
  isStreaming: bool,    // 是否为流式消息
  tokenCount: int,      // token 数量
  ...
}
```

### ApiConfig（API 配置）
```dart
{
  id: String,
  name: String,
  provider: LlmProvider, // openai/anthropic/custom
  baseUrl: String,
  apiKey: String,
  model: String,
  maxTokens: int,
  temperature: double,
  streamEnabled: bool,
  ...
}
```

## 🔄 代码生成

项目使用 Freezed 和 JSON Serializable 自动生成模型类代码：

```bash
# 生成 Freezed 和 JSON 序列化代码
flutter pub run build_runner build --delete-conflicting-outputs

# 监视模式（开发时使用）
flutter pub run build_runner watch
```

生成的文件：
- `*.freezed.dart`：Freezed 生成的不可变类
- `*.g.dart`：JSON 序列化代码

## 🧪 开发说明

### 添加新功能
1. 在 `models/` 中定义数据模型（使用 `@freezed` 注解）
2. 在 `services/` 中实现业务逻辑
3. 在 `providers/` 中创建 Riverpod 提供者
4. 在 `pages/` 中创建页面组件
5. 在 `router.dart` 中添加路由配置

### 主题定制
- 颜色定义：`lib/theme/wechat_colors.dart`
- 主题配置：`lib/theme/wechat_theme.dart`
- 参考微信官方配色方案

### 数据库迁移
数据库结构在 `lib/services/database/database_service.dart` 中定义。
如需修改表结构，需要增加数据库版本并编写迁移脚本。

## 📝 注意事项

1. **API 成本**：使用 OpenAI/Anthropic API 会产生费用，请注意用量监控
2. **隐私安全**：API 密钥存储在本地数据库，请勿分享 `database.db` 文件
3. **角色卡兼容**：目前仅支持 SillyTavern V2 格式的 PNG 角色卡
4. **主动消息频率**：默认每 5 分钟检查一次，2-9 小时间隔随机发送
5. **朋友圈生成**：默认每 1 小时检查一次，40% 概率生成动态

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发规范
- 遵循 Flutter 官方代码风格
- 使用 Dart 空安全
- 重要功能添加注释
- 确保代码生成正常执行

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Flutter](https://flutter.dev) - 跨平台 UI 框架
- [Riverpod](https://riverpod.dev) - 状态管理库
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) - 角色卡格式参考
- 所有开源依赖项的开发者

---

**Talk AI** - 让 AI 社交更自然、更有趣！

> 如有问题或建议，请提交 Issue 或联系维护者。