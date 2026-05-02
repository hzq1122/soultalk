# soultalk 开发维护指南

## 基本约定

- 项目统一名称使用 `soultalk`。
- Android applicationId/namespace 统一使用 `com.talkai.soultalk`。
- 平台显示名、二进制名、发布包名应保持 `soultalk` 一致。
- Dart 包名以 `pubspec.yaml` 的 `name: soultalk` 为准。
- 新功能优先放入已有目录，不为一次性逻辑新增抽象层。

## 常用命令

```bash
flutter pub get
flutter test
flutter analyze
dart run build_runner build --delete-conflicting-outputs
```

修改 Freezed 或 json_serializable 模型后，需要重新运行代码生成命令。

## 分层维护规则

1. UI 页面放在 `lib/pages/`。
2. 跨页面复用组件放在 `lib/widgets/`。
3. 数据模型放在 `lib/models/`。
4. Riverpod 状态管理放在 `lib/providers/`。
5. 业务逻辑、外部 API、数据库访问放在 `lib/services/`。
6. 平台差异配置放在 `lib/platform/`。
7. 路由统一在 `lib/router.dart` 注册。
8. 应用入口初始化放在 `lib/main.dart`。

## 功能修改入口

| 需求 | 优先查看位置 |
|------|--------------|
| 修改主 Tab 或底部导航 | `lib/pages/main_scaffold.dart` |
| 新增页面或调整跳转 | `lib/router.dart`, `lib/pages/` |
| 修改聊天发送与回复流程 | `lib/pages/chat/`, `lib/services/chat/`, `lib/services/api/` |
| 修改联系人或角色管理 | `lib/pages/contacts/`, `lib/providers/contacts_provider.dart`, `lib/services/character/` |
| 修改角色卡/预设/正则导入 | `lib/services/import/import_service.dart` |
| 修改记忆提取、检索、审核 | `lib/services/memory/`, `lib/models/memory_*.dart` |
| 修改朋友圈 | `lib/pages/discover/`, `lib/services/moments/`, `lib/providers/moments_provider.dart` |
| 修改主动消息 | `lib/services/proactive/proactive_service.dart` |
| 修改备份恢复 | `lib/pages/settings/backup_page.dart`, `lib/services/backup/` |
| 修改应用更新 | `lib/pages/settings/update_page.dart`, `lib/services/update/update_service.dart` |
| 修改 API 配置 | `lib/pages/settings/api_settings_page.dart`, `lib/providers/api_config_provider.dart`, `lib/services/database/api_config_dao.dart` |
| 修改数据库结构 | `lib/services/database/database_service.dart` 和对应 DAO |
| 修改 Android 名称或包名 | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/` |
| 修改 Windows 应用名 | `windows/CMakeLists.txt`, `windows/runner/main.cpp`, `windows/runner/Runner.rc` |
| 修改 Linux 应用名 | `linux/CMakeLists.txt`, `linux/runner/my_application.cc` |
| 修改 CI 发布流程 | `.github/workflows/` |

## 测试规范

- 服务层逻辑测试放在 `test/services/`。
- 模型序列化和边界测试放在 `test/models/`。
- 应用 smoke test 放在 `test/widget_test.dart`。
- 涉及 onboarding 跳转的 widget test 需要设置 `SharedPreferences.setMockInitialValues({'onboarding_done': true})`。
- 修 bug 时优先补充或更新能复现问题的测试。

## 不应提交的文件

- `.dart_tool/`
- `build/`
- `android/.gradle/`
- `android/local.properties`
- `windows/flutter/ephemeral/`
- `.claude/settings.local.json`
- `.claude/worktrees/`
- 构建产物如 `*.zip`、`*.apk`、安装包和临时缓存

## 发布和版本

- GitHub Actions tag 发布会从 `v*` tag 写入 `pubspec.yaml` 的 `version`。
- 手动发布前应检查 `pubspec.yaml`、平台资源名、CI artifact 名称是否仍为 `soultalk`。
- Windows 发布包命名应保持 `soultalk-windows-x64-v<version>.zip`。
