# Talk AI App Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish UI, fix wallet, expand shop, add GitHub release update check, settings export/import with ZIP, WebDAV/S3 cloud backup, auto-backup, cleanup unused code, configure release signing.

**Architecture:** Incremental improvements across existing Flutter app. New services for update check (GitHub Releases API), backup (ZIP archive + cloud storage abstraction), and auto-backup scheduler. UI additions for backup/restore settings page and update check integration.

**Tech Stack:** Flutter 3.11+, Dart, Riverpod, sqflite, Dio, archive (ZIP), package_info_plus, url_launcher, open_filex

**Key Constraint:** After each module completes, run `flutter build apk --debug` to verify compilation. Only the final step uses the release keystore.

---

## File Structure Map

### New Files
| File | Responsibility |
|------|---------------|
| `lib/services/update/update_service.dart` | GitHub Releases API check, APK download with progress |
| `lib/pages/settings/update_page.dart` | Update check UI (version display, check button, download progress) |
| `lib/providers/update_provider.dart` | Update state (checking, available, downloading, progress) |
| `lib/services/backup/backup_service.dart` | Export to ZIP, import from ZIP, section selection |
| `lib/services/backup/cloud_storage.dart` | Abstract interface + WebDAV + S3 implementations |
| `lib/services/backup/auto_backup_service.dart` | Periodic backup scheduler, change detection |
| `lib/pages/settings/backup_page.dart` | Backup/restore UI, cloud config, auto-backup settings |
| `lib/providers/backup_provider.dart` | Backup/restore state, cloud connection test |

### Modified Files
| File | Changes |
|------|---------|
| `pubspec.yaml` | Add `archive`, `package_info_plus`, `url_launcher`, `open_filex` |
| `lib/main.dart` | Add optional startup update check |
| `lib/router.dart` | Add routes for update and backup pages |
| `lib/pages/profile/profile_page.dart` | Add backup/restore and update check entries |
| `lib/pages/settings/general_settings_page.dart` | Add auto-backup and update check settings |
| `lib/pages/delivery/delivery_page.dart` | Fix wallet + expand menu items |
| `lib/providers/settings_provider.dart` | Add new setting keys (update check, backup config) |
| `lib/pages/chat/widgets/input_bar.dart` | Fix quick-order integration |
| `.gitignore` | Add backup exports, APK downloads, keystore refs |
| `android/app/build.gradle.kts` | Release signing config (final step only) |
| `android/key.properties` | Create with keystore path/alias/password (final step) |

---

## Phase 0: Cleanup & Dependencies

### Task 0.1: Remove unused code and files

**Files:**
- Delete: `test/widget_test.dart` (placeholder, only asserts true==true)
- Modify: `.gitignore`
- Check: all `.dart` files for unused imports

- [ ] **Step 1: Remove placeholder test**

```bash
rm test/widget_test.dart
```

- [ ] **Step 2: Update .gitignore to add new patterns**

Append to `.gitignore`:
```
# Backup exports
*.zip
backups/

# Downloaded APKs
*.apk
!app/build/**/*.apk

# Android signing config
android/key.properties

# Build artifacts
android/app/debug/
android/app/profile/
android/app/release/

# IDE
.idea/
*.iml
```

- [ ] **Step 3: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter pub get && flutter build apk --debug
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore: remove placeholder test, update .gitignore"
```

### Task 0.2: Add new dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add under `dependencies:` in `pubspec.yaml`:

```yaml
  # 压缩 / 解压
  archive: ^4.0.2

  # 应用信息
  package_info_plus: ^8.3.0

  # 打开 URL / 文件
  url_launcher: ^6.3.1
  open_filex: ^4.6.0
```

- [ ] **Step 2: Install and verify**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter pub get && flutter build apk --debug
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock && git commit -m "chore: add archive, package_info_plus, url_launcher, open_filex dependencies"
```

---

## Phase 1: Wallet Fix + Shop Expansion + UI Polish

### Task 1.1: Fix wallet — add recharge dialog, remove arbitrary balance

**Files:**
- Modify: `lib/pages/delivery/delivery_page.dart`

- [ ] **Step 1: Rewrite `_showWalletDialog` to only allow recharge (increase)**

Replace `_showWalletDialog` method in `delivery_page.dart`:

```dart
void _showWalletDialog(BuildContext context, WidgetRef ref, double balance) {
  final ctrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('钱包充值'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前余额: ¥${balance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          // Quick recharge amounts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50.0, 100.0, 200.0, 500.0].map((amount) {
              return ActionChip(
                label: Text('¥${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  ref.read(settingsProvider.notifier)
                      .setWalletBalance(balance + amount);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '自定义金额',
              prefixText: '¥ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(ctrl.text.trim());
            if (amount != null && amount > 0) {
              ref.read(settingsProvider.notifier)
                  .setWalletBalance(balance + amount);
              Navigator.of(ctx).pop();
            }
          },
          child: const Text('充值'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/delivery/delivery_page.dart && git commit -m "fix: wallet recharge only, remove arbitrary balance setting"
```

### Task 1.2: Expand shop items

**Files:**
- Modify: `lib/pages/delivery/delivery_page.dart` — replace `_menuItems` constant

- [ ] **Step 1: Replace `_menuItems` with expanded list**

Replace the `static const _menuItems` definition:

```dart
static const _menuItems = [
  _MenuItem('奶茶', [
    _FoodItem('珍珠奶茶', 12.0),
    _FoodItem('芋泥波波奶茶', 15.0),
    _FoodItem('椰椰拿铁', 18.0),
    _FoodItem('杨枝甘露', 16.0),
    _FoodItem('黑糖脏脏茶', 17.0),
    _FoodItem('芝士莓莓', 21.0),
    _FoodItem('多肉葡萄', 23.0),
    _FoodItem('手打柠檬茶', 11.0),
  ]),
  _MenuItem('咖啡', [
    _FoodItem('美式咖啡', 9.0),
    _FoodItem('生椰拿铁', 16.0),
    _FoodItem('摩卡', 18.0),
    _FoodItem('卡布奇诺', 15.0),
    _FoodItem('冰博克拿铁', 22.0),
    _FoodItem('冷萃咖啡', 19.0),
    _FoodItem('焦糖玛奇朵', 20.0),
  ]),
  _MenuItem('小吃', [
    _FoodItem('鸡排', 12.0),
    _FoodItem('烤肠', 5.0),
    _FoodItem('薯条', 8.0),
    _FoodItem('炸鸡翅', 15.0),
    _FoodItem('鸡米花', 10.0),
    _FoodItem('洋葱圈', 7.0),
    _FoodItem('烤鸡腿', 13.0),
    _FoodItem('玉米棒', 6.0),
  ]),
  _MenuItem('快餐', [
    _FoodItem('黄焖鸡米饭', 18.0),
    _FoodItem('蛋炒饭', 12.0),
    _FoodItem('牛肉面', 22.0),
    _FoodItem('麻辣烫', 20.0),
    _FoodItem('宫保鸡丁盖饭', 19.0),
    _FoodItem('红烧肉盖饭', 21.0),
    _FoodItem('鱼香肉丝饭', 17.0),
    _FoodItem('番茄牛腩面', 25.0),
  ]),
  _MenuItem('甜品', [
    _FoodItem('提拉米苏', 25.0),
    _FoodItem('芒果千层', 22.0),
    _FoodItem('冰淇淋', 8.0),
    _FoodItem('华夫饼', 15.0),
    _FoodItem('布丁', 10.0),
    _FoodItem('熔岩蛋糕', 28.0),
    _FoodItem('抹茶慕斯', 20.0),
  ]),
  _MenuItem('炸鸡汉堡', [
    _FoodItem('香辣鸡腿堡', 16.0),
    _FoodItem('劲脆鸡腿堡', 15.0),
    _FoodItem('新奥尔良烤堡', 19.0),
    _FoodItem('鸡米花(大)', 12.0),
    _FoodItem('吮指原味鸡', 11.0),
    _FoodItem('炸鸡全家桶', 59.0),
  ]),
  _MenuItem('中餐', [
    _FoodItem('酸菜鱼', 38.0),
    _FoodItem('回锅肉', 22.0),
    _FoodItem('麻婆豆腐', 15.0),
    _FoodItem('糖醋里脊', 25.0),
    _FoodItem('蒜蓉菜心', 12.0),
    _FoodItem('西红柿蛋汤', 8.0),
  ]),
];
```

- [ ] **Step 2: Update the quick-order dialog** in `input_bar.dart` `_showQuickOrderDialog` to include more items:

Replace the `foods` list:
```dart
final foods = [
  {'name': '珍珠奶茶', 'price': 12.0},
  {'name': '生椰拿铁', 'price': 16.0},
  {'name': '黄焖鸡米饭', 'price': 18.0},
  {'name': '蛋炒饭', 'price': 12.0},
  {'name': '炸鸡翅', 'price': 15.0},
  {'name': '薯条', 'price': 8.0},
  {'name': '提拉米苏', 'price': 25.0},
  {'name': '香辣鸡腿堡', 'price': 16.0},
  {'name': '酸菜鱼', 'price': 38.0},
  {'name': '麻婆豆腐', 'price': 15.0},
];
```

- [ ] **Step 3: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 4: Commit**

```bash
git add lib/pages/delivery/delivery_page.dart lib/pages/chat/widgets/input_bar.dart && git commit -m "feat: expand shop menu to 7 categories, 40+ items"
```

### Task 1.3: UI polish — add custom wallet balance setting

**Files:**
- Modify: `lib/pages/settings/general_settings_page.dart` — add wallet balance entry
- Modify: `lib/providers/settings_provider.dart` — already has wallet, no change needed

- [ ] **Step 1: Add wallet balance setting in general settings**

In `general_settings_page.dart`, after the "朋友圈" section, add:

```dart
const SizedBox(height: 8),
_SectionHeader(title: '钱包'),
Container(
  color: Colors.white,
  child: ListTile(
    title: const Text('钱包余额'),
    subtitle: Text(
      '¥${settings.walletBalance.toStringAsFixed(2)}',
      style: const TextStyle(fontSize: 13),
    ),
    trailing: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
    onTap: () => _editWalletBalance(context, ref, settings.walletBalance),
  ),
),
```

Add the `_editWalletBalance` method:
```dart
void _editWalletBalance(BuildContext context, WidgetRef ref, double current) {
  final ctrl = TextEditingController(text: current.toStringAsFixed(2));
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('自定义钱包余额'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('仅用于测试，实际使用中余额只能通过充值增加',
              style: TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '余额',
              prefixText: '¥ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(ctrl.text.trim());
            if (amount != null && amount >= 0) {
              ref.read(settingsProvider.notifier).setWalletBalance(amount);
              Navigator.of(ctx).pop();
            }
          },
          child: const Text('设置'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/settings/general_settings_page.dart && git commit -m "feat: add custom wallet balance setting in general settings"
```

---

## Phase 2: GitHub Release Update Check

### Task 2.1: Create UpdateService

**Files:**
- Create: `lib/services/update/update_service.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final int fileSize;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileSize,
  });
}

enum UpdateCheckStatus { idle, checking, updateAvailable, noUpdate, downloading, downloadComplete, error }

class UpdateService {
  static const _repoOwner = 'hzq1122';
  static const _repoName = 'AI_talk';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  UpdateInfo? _latestRelease;

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final data = response.data as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '') ?? '0.0.0';
      final assets = data['assets'] as List? ?? [];
      String? apkUrl;
      int fileSize = 0;
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          fileSize = (asset['size'] as int?) ?? 0;
          break;
        }
      }
      if (apkUrl == null) return null;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_compareVersions(tagName, currentVersion) > 0) {
        _latestRelease = UpdateInfo(
          version: tagName,
          downloadUrl: apkUrl,
          releaseNotes: (data['body'] as String?) ?? '',
          fileSize: fileSize,
        );
        return _latestRelease;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> downloadApk(UpdateInfo info, void Function(double progress) onProgress) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/update_${info.version}.apk';

    await _dio.download(
      info.downloadUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    return filePath;
  }

  Future<void> deleteApk(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal - bVal;
    }
    return 0;
  }
}
```

- [ ] **Step 2: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

### Task 2.2: Create UpdatePage UI

**Files:**
- Create: `lib/pages/settings/update_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/update_provider.dart';
import '../../theme/wechat_colors.dart';

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('检查更新'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: Icon(Icons.system_update, size: 64,
                color: state.status == UpdateStatus.updateAvailable
                    ? WeChatColors.primary
                    : WeChatColors.textHint),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Talk AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('版本 ${state.currentVersion}',
                style: const TextStyle(color: WeChatColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          _buildStatusArea(state),
        ],
      ),
    );
  }

  Widget _buildStatusArea(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return const Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在检查更新...', style: TextStyle(color: WeChatColors.textSecondary)),
          ]),
        ));
      case UpdateStatus.noUpdate:
        return Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.check_circle, color: WeChatColors.primary, size: 48),
            SizedBox(height: 12),
            Text('已是最新版本', style: TextStyle(color: WeChatColors.textSecondary)),
            SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.read(updateProvider.notifier).checkUpdate(),
              child: const Text('重新检查'),
            ),
          ]),
        ));
      case UpdateStatus.updateAvailable:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(state.updateInfo != null ? 'v${state.updateInfo!.version}' : '',
                    style: TextStyle(fontSize: 16, color: WeChatColors.primary, fontWeight: FontWeight.w500)),
                if (state.updateInfo?.releaseNotes.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(state.updateInfo!.releaseNotes,
                      style: const TextStyle(fontSize: 13, color: WeChatColors.textSecondary)),
                ],
                if (state.updateInfo?.fileSize != null) ...[
                  const SizedBox(height: 8),
                  Text('大小: ${(state.updateInfo!.fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 12, color: WeChatColors.textHint)),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: state.status == UpdateStatus.downloading
                    ? null
                    : () => ref.read(updateProvider.notifier).startDownload(),
                style: ElevatedButton.styleFrom(backgroundColor: WeChatColors.primary, foregroundColor: Colors.white),
                child: Text(state.status == UpdateStatus.downloading ? '下载中...' : '立即更新'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(updateProvider.notifier).checkUpdate(),
              child: const Text('重新检查'),
            ),
          ]),
        );
      case UpdateStatus.downloading:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            LinearProgressIndicator(value: state.downloadProgress,
                backgroundColor: const Color(0xFFE0E0E0), valueColor: const AlwaysStoppedAnimation(WeChatColors.primary)),
            const SizedBox(height: 12),
            Text('${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: WeChatColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(updateProvider.notifier).cancelDownload(),
              child: const Text('取消下载', style: TextStyle(color: Colors.red)),
            ),
          ]),
        );
      case UpdateStatus.downloadComplete:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Icon(Icons.check_circle, color: WeChatColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text('下载完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (state.downloadPath != null) {
                    await OpenFilex.open(state.downloadPath!);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: WeChatColors.primary, foregroundColor: Colors.white),
                child: const Text('安装更新'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(updateProvider.notifier).deleteDownloadedApk();
              },
              child: const Text('稍后安装'),
            ),
          ]),
        );
      case UpdateStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? '检查更新失败',
                style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () => ref.read(updateProvider.notifier).checkUpdate(),
                style: ElevatedButton.styleFrom(backgroundColor: WeChatColors.primary, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://github.com/hzq1122/AI_talk/releases'),
                  mode: LaunchMode.externalApplication),
              child: const Text('前往 GitHub 下载'),
            ),
          ]),
        );
    }
  }
}
```

- [ ] **Step 2: Create UpdateProvider**

Create: `lib/providers/update_provider.dart`

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update/update_service.dart';

enum UpdateStatus { idle, checking, noUpdate, updateAvailable, downloading, downloadComplete, error }

class UpdateState {
  final UpdateStatus status;
  final String currentVersion;
  final UpdateInfo? updateInfo;
  final double downloadProgress;
  final String? downloadPath;
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.currentVersion = '',
    this.updateInfo,
    this.downloadProgress = 0,
    this.downloadPath,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    UpdateInfo? updateInfo,
    double? downloadProgress,
    String? downloadPath,
    String? errorMessage,
  }) => UpdateState(
    status: status ?? this.status,
    currentVersion: currentVersion ?? this.currentVersion,
    updateInfo: updateInfo ?? this.updateInfo,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    downloadPath: downloadPath ?? this.downloadPath,
    errorMessage: errorMessage,
  );
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service = UpdateService();

  UpdateNotifier() : super(const UpdateState()) {
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(currentVersion: info.version);
  }

  Future<void> checkUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    await _loadVersion();
    try {
      final info = await _service.checkUpdate();
      if (info != null) {
        state = state.copyWith(status: UpdateStatus.updateAvailable, updateInfo: info);
      } else {
        state = state.copyWith(status: UpdateStatus.noUpdate);
      }
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> startDownload() async {
    if (state.updateInfo == null) return;
    state = state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0);

    try {
      final path = await _service.downloadApk(state.updateInfo!, (progress) {
        state = state.copyWith(downloadProgress: progress);
      });
      state = state.copyWith(status: UpdateStatus.downloadComplete, downloadPath: path);
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, errorMessage: '下载失败: $e');
    }
  }

  void cancelDownload() {
    state = state.copyWith(status: UpdateStatus.updateAvailable, downloadProgress: 0);
  }

  Future<void> deleteDownloadedApk() async {
    if (state.downloadPath != null) {
      await _service.deleteApk(state.downloadPath!);
    }
    state = state.copyWith(status: UpdateStatus.updateAvailable, downloadPath: null);
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) => UpdateNotifier());
```

- [ ] **Step 3: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

### Task 2.3: Wire up update check to router and profile

**Files:**
- Modify: `lib/router.dart` — add route
- Modify: `lib/pages/profile/profile_page.dart` — add entry
- Modify: `lib/pages/settings/general_settings_page.dart` — add startup check toggle
- Modify: `lib/main.dart` — optional startup check

- [ ] **Step 1: Add route in router.dart**

After the `/delivery` route, add:
```dart
GoRoute(
  path: '/settings/update',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) => const UpdatePage(),
),
```

Add import:
```dart
import '../pages/settings/update_page.dart';
```

- [ ] **Step 2: Add entry in profile page**

In `profile_page.dart`, add after the "通用设置" ListTile:
```dart
const Divider(height: 0, indent: 56),
ListTile(
  leading: const Icon(Icons.backup_outlined, color: WeChatColors.primary),
  title: const Text('备份与恢复'),
  trailing: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
  onTap: () => context.push('/settings/backup'),
),
const Divider(height: 0, indent: 56),
ListTile(
  leading: const Icon(Icons.system_update, color: WeChatColors.primary),
  title: const Text('检查更新'),
  trailing: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
  onTap: () => context.push('/settings/update'),
),
```

- [ ] **Step 3: Add startup check toggle in general settings**

In `general_settings_page.dart`, add before the wallet section:
```dart
const SizedBox(height: 8),
_SectionHeader(title: '更新'),
Container(
  color: Colors.white,
  child: SwitchListTile(
    title: const Text('启动时检查更新'),
    subtitle: const Text('打开应用时自动检查新版本'),
    value: settings.checkUpdateOnStartup,
    activeColor: WeChatColors.primary,
    onChanged: (v) => ref.read(settingsProvider.notifier).setCheckUpdateOnStartup(v),
  ),
),
```

- [ ] **Step 4: Add startup check in main.dart**

Modify `main()`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'services/update/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final proactive = ProactiveService();
  proactive.init();
  proactive.checkOnAppOpen();

  // Optional startup update check
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('check_update_on_startup') ?? false) {
    UpdateService().checkUpdate(); // fire-and-forget
  }

  runApp(const ProviderScope(child: TalkAiApp()));
}
```

- [ ] **Step 5: Add new setting to SettingsProvider**

In `lib/providers/settings_provider.dart`, add:
```dart
const _kCheckUpdateOnStartup = 'check_update_on_startup';
```

In `AppSettings` class:
```dart
final bool checkUpdateOnStartup;
// default: false
```

In `copyWith`:
```dart
bool? checkUpdateOnStartup,
```

In `build()`:
```dart
checkUpdateOnStartup: prefs.getBool(_kCheckUpdateOnStartup) ?? false,
```

Add method:
```dart
Future<void> setCheckUpdateOnStartup(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kCheckUpdateOnStartup, enabled);
  state = AsyncData(state.value!.copyWith(checkUpdateOnStartup: enabled));
}
```

- [ ] **Step 6: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 7: Commit**

```bash
git add lib/services/update/ lib/pages/settings/update_page.dart lib/providers/update_provider.dart lib/router.dart lib/pages/profile/profile_page.dart lib/pages/settings/general_settings_page.dart lib/providers/settings_provider.dart lib/main.dart && git commit -m "feat: add GitHub release update check with download, retry, and install"
```

---

## Phase 3: Settings Export/Import (ZIP)

### Task 3.1: Create BackupService

**Files:**
- Create: `lib/services/backup/backup_service.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';

enum BackupSection {
  apiConfigs,
  contacts,
  messages,
  moments,
  settings,
  presets,
  regexScripts,
  memoryEntries,
}

extension BackupSectionLabel on BackupSection {
  String get label => switch (this) {
    BackupSection.apiConfigs => 'API 配置',
    BackupSection.contacts => '联系人',
    BackupSection.messages => '聊天记录',
    BackupSection.moments => '朋友圈',
    BackupSection.settings => '应用设置',
    BackupSection.presets => '对话预设',
    BackupSection.regexScripts => '正则脚本',
    BackupSection.memoryEntries => '记忆表格',
  };

  String get folderName => switch (this) {
    BackupSection.apiConfigs => 'api',
    BackupSection.contacts => 'contacts',
    BackupSection.messages => 'messages',
    BackupSection.moments => 'moments',
    BackupSection.settings => 'settings',
    BackupSection.presets => 'presets',
    BackupSection.regexScripts => 'regex',
    BackupSection.memoryEntries => 'memory',
  };
}

class BackupService {
  final DatabaseService _dbService = DatabaseService();

  Future<String> exportToZip({
    required Set<BackupSection> sections,
  }) async {
    final db = await _dbService.database;
    final archive = Archive();

    for (final section in sections) {
      final folder = section.folderName;
      switch (section) {
        case BackupSection.apiConfigs:
          final rows = await db.query('api_configs');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/api_configs.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
        case BackupSection.contacts:
          final rows = await db.query('contacts');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/contacts.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
        case BackupSection.messages:
          // Export as multiple files per contact to avoid huge files
          final contacts = await db.query('contacts');
          for (final c in contacts) {
            final rows = await db.query('messages',
                where: 'contact_id = ?', whereArgs: [c['id']]);
            if (rows.isNotEmpty) {
              final data = jsonEncode(rows);
              archive.addFile(ArchiveFile(
                  '$folder/${c['id']}.json', data.length, data.codeUnits));
            }
          }
        case BackupSection.moments:
          final rows = await db.query('moments');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/moments.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
        case BackupSection.settings:
          final prefs = await SharedPreferences.getInstance();
          final keys = prefs.getKeys();
          final settings = <String, dynamic>{};
          for (final key in keys) {
            settings[key] = prefs.get(key);
          }
          final data = jsonEncode(settings);
          archive.addFile(ArchiveFile('$folder/settings.json', data.length, data.codeUnits));
        case BackupSection.presets:
          final rows = await db.query('chat_presets');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/presets.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
        case BackupSection.regexScripts:
          final rows = await db.query('regex_scripts');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/regex_scripts.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
        case BackupSection.memoryEntries:
          final rows = await db.query('memory_entries');
          if (rows.isNotEmpty) {
            archive.addFile(
              ArchiveFile('$folder/memory_entries.json', rows.length, jsonEncode(rows).codeUnits),
            );
          }
      }
    }

    // Add manifest
    final manifest = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'sections': sections.map((s) => s.folderName).toList(),
    };
    final manifestData = jsonEncode(manifest);
    archive.addFile(ArchiveFile('manifest.json', manifestData.length, manifestData.codeUnits));

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath = '${dir.path}/talk_ai_backup_$timestamp.zip';

    final encoder = ZipEncoder();
    await File(zipPath).writeAsBytes(encoder.encode(archive)!);
    return zipPath;
  }

  Future<bool> importFromZip({
    required String zipPath,
    required Set<BackupSection> sections,
  }) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      // Verify manifest
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return false;

      final db = await _dbService.database;

      for (final section in sections) {
        final folder = section.folderName;
        switch (section) {
          case BackupSection.apiConfigs:
            final file = archive.findFile('$folder/api_configs.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('api_configs', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.contacts:
            final file = archive.findFile('$folder/contacts.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('contacts', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.messages:
            for (final f in archive) {
              if (f.name.startsWith('$folder/') && f.name.endsWith('.json')) {
                try {
                  final rows = jsonDecode(utf8.decode(f.content)) as List;
                  for (final row in rows) {
                    await db.insert('messages', row as Map<String, dynamic>,
                        conflictAlgorithm: ConflictAlgorithm.replace);
                  }
                } catch (_) {}
              }
            }
          case BackupSection.moments:
            final file = archive.findFile('$folder/moments.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('moments', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.settings:
            final file = archive.findFile('$folder/settings.json');
            if (file != null) {
              final settings = jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
              final prefs = await SharedPreferences.getInstance();
              for (final entry in settings.entries) {
                final v = entry.value;
                if (v is int) {
                  await prefs.setInt(entry.key, v);
                } else if (v is double) {
                  await prefs.setDouble(entry.key, v);
                } else if (v is bool) {
                  await prefs.setBool(entry.key, v);
                } else if (v is String) {
                  await prefs.setString(entry.key, v);
                }
              }
            }
          case BackupSection.presets:
            final file = archive.findFile('$folder/presets.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('chat_presets', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.regexScripts:
            final file = archive.findFile('$folder/regex_scripts.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('regex_scripts', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.memoryEntries:
            final file = archive.findFile('$folder/memory_entries.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('memory_entries', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// List sections available in a backup ZIP
  Future<List<BackupSection>> listSections(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return [];

      final manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
      final sectionNames = (manifest['sections'] as List?)?.cast<String>() ?? [];

      return sectionNames.map((name) => BackupSection.values.firstWhere(
        (s) => s.folderName == name,
      )).toList();
    } catch (_) {
      return [];
    }
  }
}
```

- [ ] **Step 2: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

### Task 3.2: Create BackupPage UI

**Files:**
- Create: `lib/pages/settings/backup_page.dart`
- Create: `lib/providers/backup_provider.dart`

- [ ] **Step 1: Create BackupProvider**

Create `lib/providers/backup_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backup/backup_service.dart';

class ExportState {
  final bool isExporting;
  final String? exportPath;
  final String? error;

  const ExportState({this.isExporting = false, this.exportPath, this.error});
}

class BackupNotifier extends StateNotifier<ExportState> {
  final BackupService _service = BackupService();

  BackupNotifier() : super(const ExportState());

  Future<String?> exportData(Set<BackupSection> sections) async {
    state = const ExportState(isExporting: true);
    try {
      final path = await _service.exportToZip(sections: sections);
      state = ExportState(exportPath: path);
      return path;
    } catch (e) {
      state = ExportState(error: e.toString());
      return null;
    }
  }

  Future<bool> importData(String zipPath, Set<BackupSection> sections) async {
    state = const ExportState(isExporting: true);
    try {
      final result = await _service.importFromZip(zipPath: zipPath, sections: sections);
      state = const ExportState();
      return result;
    } catch (e) {
      state = ExportState(error: e.toString());
      return false;
    }
  }

  void reset() => state = const ExportState();
}

final backupProvider = StateNotifierProvider<BackupNotifier, ExportState>((ref) => BackupNotifier());
```

- [ ] **Step 2: Create BackupPage**

Create `lib/pages/settings/backup_page.dart`:

This page contains two tabs: Export and Import. Export shows checkboxes for each section, a "Export" button that creates the ZIP and offers to share. Import uses file_picker to select ZIP, then shows available sections for selective import.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/backup_provider.dart';
import '../../services/backup/backup_service.dart';
import '../../theme/wechat_colors.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  final _exportSections = <BackupSection>{...BackupSection.values};
  final _importSections = <BackupSection>{};
  String? _importPath;
  List<BackupSection>? _importSectionsAvailable;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('备份与恢复'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: WeChatColors.primary,
          unselectedLabelColor: WeChatColors.textSecondary,
          tabs: const [Tab(text: '导出'), Tab(text: '导入')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(backupState),
          _buildImportTab(backupState),
        ],
      ),
    );
  }

  Widget _buildExportTab(ExportState state) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('选择导出内容'),
        Container(
          color: Colors.white,
          child: Column(
            children: BackupSection.values.map((section) {
              return CheckboxListTile(
                title: Text(section.label),
                subtitle: Text(section.folderName, style: const TextStyle(fontSize: 12, color: WeChatColors.textHint)),
                value: _exportSections.contains(section),
                activeColor: WeChatColors.primary,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _exportSections.add(section);
                    } else {
                      _exportSections.remove(section);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: state.isExporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined),
              label: Text(state.isExporting ? '导出中...' : '导出'),
              style: ElevatedButton.styleFrom(backgroundColor: WeChatColors.primary, foregroundColor: Colors.white),
              onPressed: _exportSections.isEmpty || state.isExporting ? null : () async {
                final path = await ref.read(backupProvider.notifier).exportData(_exportSections);
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('导出成功: $path'),
                      action: SnackBarAction(label: '分享', onPressed: () => _shareFile(path)),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '导出为 ZIP 压缩包，内部按板块分文件夹存储（api/、contacts/、messages/ 等），可直接手动编辑',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab(ExportState state) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('选择备份文件'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(_importPath != null ? '已选择备份文件' : '点击选择 ZIP 文件'),
              onPressed: state.isExporting ? null : () => _pickBackupFile(),
            ),
          ),
        ),
        if (_importSectionsAvailable != null) ...[
          _buildSectionHeader('选择导入内容'),
          Container(
            color: Colors.white,
            child: Column(
              children: _importSectionsAvailable!.map((section) {
                return CheckboxListTile(
                  title: Text(section.label),
                  value: _importSections.contains(section),
                  activeColor: WeChatColors.primary,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _importSections.add(section);
                      } else {
                        _importSections.remove(section);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: state.isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restore_outlined),
                label: Text(state.isExporting ? '导入中...' : '导入选中内容'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _importSections.isEmpty ? Colors.grey : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _importSections.isEmpty || state.isExporting ? null : () async {
                  final result = await ref.read(backupProvider.notifier).importData(_importPath!, _importSections);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result ? '导入成功' : '导入失败')),
                    );
                  }
                },
              ),
            ),
          ),
        ],
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: const TextStyle(fontSize: 13, color: WeChatColors.textSecondary, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final sections = await BackupService().listSections(path);
    setState(() {
      _importPath = path;
      _importSectionsAvailable = sections;
      _importSections = sections.toSet();
    });
  }

  Future<void> _shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Talk AI 备份');
  }
}
```

Wait — `share_plus` isn't in dependencies. Let me use a different approach for sharing. Instead, show the file path and let user share via system.

Actually, let me simplify — just show the file path, and add `share_plus` to the dependency list.

- [ ] **Step 3: Add share_plus to pubspec.yaml**

```yaml
  share_plus: ^10.1.4
```

Run `flutter pub get`.

- [ ] **Step 4: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

### Task 3.3: Add backup route

**Files:**
- Modify: `lib/router.dart`

Add import and route:
```dart
import '../pages/settings/backup_page.dart';

// Add route
GoRoute(
  path: '/settings/backup',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) => const BackupPage(),
),
```

- [ ] **Step 1: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/backup/ lib/pages/settings/backup_page.dart lib/providers/backup_provider.dart lib/router.dart pubspec.yaml pubspec.lock && git commit -m "feat: add settings export/import with ZIP archive and selective sections"
```

---

## Phase 4: Cloud Storage (WebDAV + S3)

### Task 4.1: Create CloudStorage abstraction + WebDAV + S3 implementations

**Files:**
- Create: `lib/services/backup/cloud_storage.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

abstract class CloudStorageConfig {
  Map<String, dynamic> toJson();
}

class WebDavConfig extends CloudStorageConfig {
  final String url;
  final String username;
  final String password;

  const WebDavConfig({required this.url, required this.username, required this.password});

  @override
  Map<String, dynamic> toJson() => {'type': 'webdav', 'url': url, 'username': username, 'password': password};

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
    url: json['url'] as String,
    username: json['username'] as String,
    password: json['password'] as String,
  );
}

class S3Config extends CloudStorageConfig {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final String bucket;

  const S3Config({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
  });

  @override
  Map<String, dynamic> toJson() => {'type': 's3', 'endpoint': endpoint, 'region': region, 'accessKey': accessKey, 'secretKey': secretKey, 'bucket': bucket};

  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
    endpoint: json['endpoint'] as String,
    region: json['region'] as String,
    accessKey: json['accessKey'] as String,
    secretKey: json['secretKey'] as String,
    bucket: json['bucket'] as String,
  );
}

abstract class CloudStorage {
  Future<bool> testConnection();
  Future<bool> upload(String localPath, String remoteName);
  Future<String?> download(String remoteName, String localPath);
  Future<List<String>> listBackups();

  static CloudStorage fromConfig(CloudStorageConfig config) {
    if (config is WebDavConfig) return WebDavStorage(config);
    if (config is S3Config) return S3Storage(config);
    throw ArgumentError('Unknown config type');
  }
}

class WebDavStorage implements CloudStorage {
  final WebDavConfig config;
  final Dio _dio;

  WebDavStorage(this.config) : _dio = Dio(BaseOptions(
    baseUrl: config.url.endsWith('/') ? config.url : '${config.url}/',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
    },
  ));

  @override
  Future<bool> testConnection() async {
    try {
      final resp = await _dio.request('', options: Options(method: 'PROPFIND', headers: {'Depth': '0'}));
      return resp.statusCode != null && resp.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> upload(String localPath, String remoteName) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      await _dio.put(remoteName, data: bytes,
          options: Options(headers: {'Content-Type': 'application/octet-stream'}));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> download(String remoteName, String localPath) async {
    try {
      await _dio.download(remoteName, localPath);
      return localPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listBackups() async {
    try {
      final resp = await _dio.request('', options: Options(method: 'PROPFIND', headers: {'Depth': '1'}));
      // Simple XML parsing for file names
      final body = resp.data.toString();
      final regex = RegExp(r'<D:href>([^<]+)</D:href>');
      return regex.allMatches(body)
          .map((m) => m.group(1)!.split('/').last)
          .where((n) => n.endsWith('.zip'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class S3Storage implements CloudStorage {
  final S3Config config;
  final Dio _dio;

  S3Storage(this.config) : _dio = Dio(BaseOptions(
    baseUrl: config.endpoint.endsWith('/') ? config.endpoint : '${config.endpoint}/',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String _host() => Uri.parse(config.endpoint).host;

  Map<String, String> _signedHeaders(String method, String path, {String? body}) {
    // AWS Signature V4
    final now = DateTime.now().toUtc();
    final amzDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';
    final dateStamp = amzDate.substring(0, 8);

    final service = 's3';
    final algorithm = 'AWS4-HMAC-SHA256';

    final credentialScope = '$dateStamp/${config.region}/$service/aws4_request';

    final headers = <String, String>{
      'Host': _host(),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': sha256.convert(utf8.encode(body ?? '')).toString(),
    };

    final sortedHeaderKeys = headers.keys.toList()..sort();
    final signedHeaders = sortedHeaderKeys.join(';');
    final canonicalHeaders = sortedHeaderKeys.map((k) => '$k:${headers[k]}').join('\n');

    final canonicalRequest = [
      method,
      '/${config.bucket}$path',
      '',
      canonicalHeaders,
      '',
      signedHeaders,
      headers['x-amz-content-sha256'],
    ].join('\n');

    final stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final kDate = Hmac(sha256, utf8.encode('AWS4${config.secretKey}')).convert(utf8.encode(dateStamp));
    final kRegion = Hmac(sha256, kDate.bytes).convert(utf8.encode(config.region));
    final kService = Hmac(sha256, kRegion.bytes).convert(utf8.encode(service));
    final kSigning = Hmac(sha256, kService.bytes).convert(utf8.encode('aws4_request'));
    final signature = Hmac(sha256, kSigning.bytes).convert(utf8.encode(stringToSign)).toString();

    headers['Authorization'] = '$algorithm Credential=${config.accessKey}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return headers;
  }

  @override
  Future<bool> testConnection() async {
    try {
      final resp = await _dio.head('${config.bucket}',
          options: Options(headers: _signedHeaders('HEAD', '')));
      return resp.statusCode != null && resp.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> upload(String localPath, String remoteName) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final resp = await _dio.put('${config.bucket}/$remoteName', data: bytes,
          options: Options(headers: _signedHeaders('PUT', '/$remoteName')));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> download(String remoteName, String localPath) async {
    try {
      await _dio.download('${config.bucket}/$remoteName', localPath,
          options: Options(headers: _signedHeaders('GET', '/$remoteName')));
      return localPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listBackups() async {
    try {
      final resp = await _dio.get('${config.bucket}',
          options: Options(headers: _signedHeaders('GET', '')));
      final body = resp.data.toString();
      // Parse S3 ListObjects XML
      final regex = RegExp(r'<Key>([^<]+)</Key>');
      return regex.allMatches(body)
          .map((m) => m.group(1)!)
          .where((n) => n.endsWith('.zip'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
```

- [ ] **Step 2: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

---

## Phase 5: Auto Backup

### Task 5.1: Create AutoBackupService

**Files:**
- Create: `lib/services/backup/auto_backup_service.dart`

```dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import 'cloud_storage.dart';
import '../database/database_service.dart';

class AutoBackupService {
  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  Timer? _timer;
  bool _running = false;
  final BackupService _backupService = BackupService();

  void init() {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _scheduleNext() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    if (intervalMinutes <= 0) return;

    _timer?.cancel();
    _timer = Timer(Duration(minutes: intervalMinutes), _runBackup);
  }

  Future<void> _runBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_backup_enabled') ?? false;
      if (!enabled) return;

      // Check if there are changes since last backup
      final lastHash = prefs.getString('auto_backup_last_hash');
      final db = await DatabaseService().database;
      final tables = ['messages', 'moments', 'contacts'];
      final hashes = <String>[];
      for (final table in tables) {
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table'));
        hashes.add('$table:$count');
      }
      final currentHash = hashes.join('|');
      if (currentHash == lastHash) {
        _scheduleNext();
        return;
      }

      // Export and upload
      final cloudType = prefs.getString('auto_backup_cloud_type');
      if (cloudType == null) {
        _scheduleNext();
        return;
      }

      final path = await _backupService.exportToZip(
        sections: BackupSection.values.toSet(),
      );

      CloudStorage? storage;
      if (cloudType == 'webdav') {
        final url = prefs.getString('auto_backup_webdav_url') ?? '';
        final username = prefs.getString('auto_backup_webdav_username') ?? '';
        final password = prefs.getString('auto_backup_webdav_password') ?? '';
        storage = WebDavStorage(WebDavConfig(url: url, username: username, password: password));
      } else if (cloudType == 's3') {
        storage = S3Storage(S3Config(
          endpoint: prefs.getString('auto_backup_s3_endpoint') ?? '',
          region: prefs.getString('auto_backup_s3_region') ?? '',
          accessKey: prefs.getString('auto_backup_s3_access_key') ?? '',
          secretKey: prefs.getString('auto_backup_s3_secret_key') ?? '',
          bucket: prefs.getString('auto_backup_s3_bucket') ?? '',
        ));
      }

      if (storage != null) {
        final fileName = path.split('/').last;
        final success = await storage.upload(path, fileName);
        if (success) {
          await prefs.setString('auto_backup_last_hash', currentHash);
          await prefs.setString('auto_backup_last_time', DateTime.now().toIso8601String());
        }
      }
    } catch (_) {}
    _scheduleNext();
  }
}
```

Wait, `Sqflite.firstIntValue` requires importing sqflite. Let me fix:

```dart
import 'package:sqflite/sqflite.dart';
```

- [ ] **Step 2: Add auto-backup settings to general_settings_page.dart**

Add new section:
```dart
const SizedBox(height: 8),
_SectionHeader(title: '自动备份'),
Container(
  color: Colors.white,
  child: Column(
    children: [
      SwitchListTile(
        title: const Text('启用自动备份'),
        subtitle: const Text('定期备份数据到云端'),
        value: settings.autoBackupEnabled,
        activeColor: WeChatColors.primary,
        onChanged: (v) => ref.read(settingsProvider.notifier).setAutoBackupEnabled(v),
      ),
      if (settings.autoBackupEnabled) ...[
        const Divider(height: 0, indent: 16),
        ListTile(
          title: const Text('备份间隔'),
          subtitle: Text('${settings.autoBackupInterval} 分钟',
              style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
          onTap: () => _editAutoBackupInterval(context, ref, settings.autoBackupInterval),
        ),
        const Divider(height: 0, indent: 16),
        ListTile(
          title: const Text('云存储配置'),
          subtitle: Text(settings.autoBackupCloudType.isEmpty ? '未配置' : settings.autoBackupCloudType.toUpperCase(),
              style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
          onTap: () => _showCloudConfigSheet(context, ref, settings),
        ),
      ],
    ],
  ),
),
```

- [ ] **Step 3: Add auto-backup settings to SettingsProvider**

Add new keys and fields:
```dart
const _kAutoBackupEnabled = 'auto_backup_enabled';
const _kAutoBackupInterval = 'auto_backup_interval';
const _kAutoBackupCloudType = 'auto_backup_cloud_type';
// Plus WebDAV/S3 config keys...
```

Add to `AppSettings`:
```dart
final bool autoBackupEnabled;
final int autoBackupInterval;
final String autoBackupCloudType;
// Plus cloud config fields...
```

Add corresponding setter methods.

- [ ] **Step 4: Wire AutoBackupService into main.dart**

In `main.dart`:
```dart
final autoBackup = AutoBackupService();
autoBackup.init();
```

- [ ] **Step 5: Compile verification**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --debug
```

- [ ] **Step 6: Commit**

```bash
git add lib/services/backup/cloud_storage.dart lib/services/backup/auto_backup_service.dart lib/pages/settings/general_settings_page.dart lib/providers/settings_provider.dart lib/main.dart && git commit -m "feat: add cloud storage (WebDAV + S3) and auto backup"
```

---

## Phase 6: Final — Release Signing

### Task 6.1: Configure release signing with user keystore

**Files:**
- Create: `android/key.properties`
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: Create key.properties**

Create `android/key.properties`:
```
storePassword=<USER_MUST_FILL>
keyPassword=<USER_MUST_FILL>
keyAlias=<USER_MUST_FILL>
storeFile=C:/Users/Admin/Desktop/shuangyue-sfsy1124-10/shuangyue.keystore
```

- [ ] **Step 2: Modify build.gradle.kts for signing**

Replace the static `signingConfig` in `build.gradle.kts` with reading from key.properties:

Keep the current build.gradle.kts structure but add signing config loading.

The user should provide the keystore password, key password, and key alias. These MUST be filled in before the final release build.

- [ ] **Step 3: Final release build**

```bash
cd C:\Users\Admin\Desktop\AI_talk && flutter build apk --release
```

---

## Verification Checklist

After each phase, run:
```bash
flutter build apk --debug
```

Only Phase 6 uses `flutter build apk --release` with the user's keystore.
