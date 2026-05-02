import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../providers/backup_provider.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/cloud_storage.dart';
import '../../theme/wechat_colors.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);
  final _exportSections = <BackupSection>{...BackupSection.values};
  final _importSections = <BackupSection>{};
  String? _importPath;
  List<BackupSection>? _importSectionsAvailable;

  // Encryption
  final _exportPassCtrl = TextEditingController();
  final _importPassCtrl = TextEditingController();
  bool _exportEncrypt = false;
  bool _importIsEncrypted = false;

  // Cloud
  final _cloudPassCtrl = TextEditingController();
  bool _cloudLoading = false;
  String? _cloudStatus;

  @override
  void dispose() {
    _tabController.dispose();
    _exportPassCtrl.dispose();
    _importPassCtrl.dispose();
    _cloudPassCtrl.dispose();
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
          isScrollable: false,
          tabs: const [
            Tab(text: '导出'),
            Tab(text: '导入'),
            Tab(text: '云备份'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(backupState),
          _buildImportTab(backupState),
          _buildCloudTab(),
        ],
      ),
    );
  }

  // ─── Export Tab ───────────────────────────────────────────────────────

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
                subtitle: Text(section.folderName,
                    style: const TextStyle(
                        fontSize: 12, color: WeChatColors.textHint)),
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
        const SizedBox(height: 12),
        // Encryption toggle
        Container(
          color: Colors.white,
          child: SwitchListTile(
            title: const Text('加密备份'),
            subtitle: const Text('使用密码加密，防止隐私泄露'),
            value: _exportEncrypt,
            activeThumbColor: WeChatColors.primary,
            onChanged: (v) => setState(() => _exportEncrypt = v),
          ),
        ),
        if (_exportEncrypt)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _exportPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '加密密码',
                hintText: '请牢记密码，丢失无法恢复',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined),
              label: Text(state.isExporting ? '导出中...' : '导出'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: WeChatColors.primary,
                  foregroundColor: Colors.white),
              onPressed: _exportSections.isEmpty || state.isExporting
                  ? null
                  : () async {
                      if (_exportEncrypt &&
                          _exportPassCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请设置加密密码')),
                        );
                        return;
                      }
                      final dir =
                          await FilePicker.platform.getDirectoryPath(
                        dialogTitle: '选择导出目录',
                      );
                      if (dir == null) return;
                      final path = await ref
                          .read(backupProvider.notifier)
                          .exportData(
                            _exportSections,
                            dir,
                            password: _exportEncrypt
                                ? _exportPassCtrl.text.trim()
                                : null,
                          );
                      if (path != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '导出成功${_exportEncrypt ? "（已加密）" : ""}'),
                            action: SnackBarAction(
                                label: '分享',
                                onPressed: () => _shareFile(path)),
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
            child:
                Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '导出为 ZIP 压缩包。开启加密后使用 AES-256 加密，需密码才能恢复。',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  // ─── Import Tab ───────────────────────────────────────────────────────

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
              label: Text(_importPath != null
                  ? '${_importPath!.split('/').last}${_importIsEncrypted ? "（已加密）" : ""}'
                  : '点击选择 ZIP 或加密备份文件'),
              onPressed: state.isExporting ? null : () => _pickBackupFile(),
            ),
          ),
        ),
        if (_importIsEncrypted) ...[
          _buildSectionHeader('解密密码'),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _importPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '请输入备份密码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restore_outlined),
                label: Text(state.isExporting ? '导入中...' : '导入选中内容'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _importSections.isEmpty ? Colors.grey : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _importSections.isEmpty || state.isExporting
                    ? null
                    : () async {
                        final result = await ref
                            .read(backupProvider.notifier)
                            .importData(
                              _importPath!,
                              _importSections,
                              password: _importIsEncrypted
                                  ? _importPassCtrl.text.trim()
                                  : null,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    result ? '导入成功' : '导入失败，请检查密码是否正确')),
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
            child:
                Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  // ─── Cloud Tab ────────────────────────────────────────────────────────

  Widget _buildCloudTab() {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('云端存储'),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('支持 WebDAV 和 S3 兼容存储',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                '可连接自建存储（如 Alist、NextCloud）或云服务（如阿里云 OSS、AWS S3）',
                style:
                    TextStyle(fontSize: 12, color: WeChatColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('配置云存储'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WeChatColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showCloudConfigSheet(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSectionHeader('云端操作'),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined,
                    color: WeChatColors.primary),
                title: const Text('上传当前数据到云端'),
                subtitle: const Text('将所有数据压缩加密后上传'),
                trailing: _cloudLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right,
                        color: WeChatColors.textHint),
                onTap: _cloudLoading ? null : _uploadToCloud,
              ),
              const Divider(height: 0, indent: 16),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined,
                    color: Colors.blue),
                title: const Text('从云端下载备份'),
                subtitle: const Text('查看云端备份列表并下载恢复'),
                trailing: const Icon(Icons.chevron_right,
                    color: WeChatColors.textHint),
                onTap: _cloudLoading ? null : _downloadFromCloud,
              ),
            ],
          ),
        ),
        if (_cloudStatus != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_cloudStatus!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: _cloudStatus!.contains('成功')
                        ? WeChatColors.primary
                        : Colors.red)),
          ),
        ],
        const SizedBox(height: 8),
        _buildSectionHeader('自动备份'),
        Container(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.schedule,
                color: Colors.orange),
            title: const Text('自动备份设置'),
            subtitle: const Text('定时自动备份到云端'),
            trailing: const Icon(Icons.chevron_right,
                color: WeChatColors.textHint),
            onTap: () => context.push('/settings/general'),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '提示：云备份（含自动备份）使用通用设置中的云存储配置。支持自建 WebDAV（如 Alist、NextCloud）及 S3 兼容存储。',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  // ─── Common widgets ──────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              color: WeChatColors.textSecondary,
              fontWeight: FontWeight.w500)),
    );
  }

  // ─── File picker ──────────────────────────────────────────────────────

  Future<void> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'enc.zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final isEnc = path.endsWith('.enc.zip');
    setState(() {
      _importPath = path;
      _importIsEncrypted = isEnc;
      _importSectionsAvailable = null;
      _importSections.clear();
    });

    // For encrypted files, require password first
    if (isEnc) {
      // sections will be loaded after password is entered
      return;
    }

    final sections = await BackupService().listSections(path);
    setState(() {
      _importSectionsAvailable = sections;
      _importSections.clear();
      _importSections.addAll(sections);
    });
  }

  Future<void> _shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Talk AI 备份');
  }

  // ─── Cloud operations ────────────────────────────────────────────────

  Future<CloudStorage?> _getCloudStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final cloudType = prefs.getString('auto_backup_cloud_type');
    if (cloudType == 'webdav') {
      final url = prefs.getString('auto_backup_webdav_url') ?? '';
      final username = prefs.getString('auto_backup_webdav_username') ?? '';
      final password = prefs.getString('auto_backup_webdav_password') ?? '';
      if (url.isEmpty) return null;
      return WebDavStorage(
          WebDavConfig(url: url, username: username, password: password));
    } else if (cloudType == 's3') {
      return S3Storage(S3Config(
        endpoint: prefs.getString('auto_backup_s3_endpoint') ?? '',
        region: prefs.getString('auto_backup_s3_region') ?? 'us-east-1',
        accessKey: prefs.getString('auto_backup_s3_access_key') ?? '',
        secretKey: prefs.getString('auto_backup_s3_secret_key') ?? '',
        bucket: prefs.getString('auto_backup_s3_bucket') ?? '',
      ));
    }
    return null;
  }

  Future<void> _uploadToCloud() async {
    final storage = await _getCloudStorage();
    if (storage == null) {
      setState(() => _cloudStatus = '请先配置云存储');
      return;
    }

    // Ask for encryption password
    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => _PasswordDialog(),
    );
    if (!mounted) return;

    setState(() => _cloudLoading = true);
    _cloudStatus = '正在准备...';

    try {
      // Export to temp directory
      final tempDir = (await getTemporaryDirectory()).path;
      final path = await BackupService().exportToZip(
        sections: BackupSection.values.toSet(),
        targetDir: tempDir,
        password: password,
      );

      _cloudStatus = '正在上传...';
      final fileName = path.split('/').last;
      final success = await storage.upload(path, fileName);

      // Clean up temp file
      try {
        await File(path).delete();
      } catch (_) {}

      setState(() {
        _cloudLoading = false;
        _cloudStatus = success ? '上传成功' : '上传失败';
      });
    } catch (e) {
      setState(() {
        _cloudLoading = false;
        _cloudStatus = '失败: $e';
      });
    }
  }

  Future<void> _downloadFromCloud() async {
    final storage = await _getCloudStorage();
    if (storage == null) {
      setState(() => _cloudStatus = '请先配置云存储');
      return;
    }

    setState(() => _cloudLoading = true);
    _cloudStatus = '正在列出云端文件...';

    try {
      final files = await storage.listBackups();
      if (files.isEmpty) {
        setState(() {
          _cloudLoading = false;
          _cloudStatus = '云端没有备份文件';
        });
        return;
      }

      setState(() => _cloudLoading = false);
      _cloudStatus = null;

      if (!mounted) return;

      // Show file picker dialog
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择要下载的备份'),
          children: files.map((f) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(f),
              child: Text(f, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
        ),
      );

      if (selected == null || !mounted) return;

      // Download to user-selected directory
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存目录',
      );
      if (dir == null) return;

      setState(() => _cloudLoading = true);
      _cloudStatus = '正在下载...';

      final localPath = '$dir/$selected';
      final result = await storage.download(selected, localPath);

      setState(() {
        _cloudLoading = false;
        _cloudStatus = result != null ? '下载成功: $localPath' : '下载失败';
      });
    } catch (e) {
      setState(() {
        _cloudLoading = false;
        _cloudStatus = '失败: $e';
      });
    }
  }

  void _showCloudConfigSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final settings = _CloudSettings(
      autoBackupCloudType: prefs.getString('auto_backup_cloud_type') ?? '',
    );
    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      builder: (ctx) => _CloudConfigSheet(settings: settings),
    );
  }
}

// ─── Cloud Config Sheet (独立版本，不依赖 general_settings) ────────────

class _CloudSettings {
  final String autoBackupCloudType;
  const _CloudSettings({required this.autoBackupCloudType});
}

class _CloudConfigSheet extends StatefulWidget {
  final _CloudSettings settings;
  const _CloudConfigSheet({required this.settings});

  @override
  State<_CloudConfigSheet> createState() => _CloudConfigSheetState();
}

class _CloudConfigSheetState extends State<_CloudConfigSheet> {
  late String _cloudType;
  bool _testing = false;
  String? _testResult;

  final _webdavUrlCtrl = TextEditingController();
  final _webdavUserCtrl = TextEditingController();
  final _webdavPassCtrl = TextEditingController();
  final _s3EndpointCtrl = TextEditingController();
  final _s3RegionCtrl = TextEditingController(text: 'us-east-1');
  final _s3AccessKeyCtrl = TextEditingController();
  final _s3SecretKeyCtrl = TextEditingController();
  final _s3BucketCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cloudType = widget.settings.autoBackupCloudType.isEmpty
        ? 'webdav'
        : widget.settings.autoBackupCloudType;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _webdavUrlCtrl.text = prefs.getString('auto_backup_webdav_url') ?? '';
    _webdavUserCtrl.text =
        prefs.getString('auto_backup_webdav_username') ?? '';
    _webdavPassCtrl.text =
        prefs.getString('auto_backup_webdav_password') ?? '';
    _s3EndpointCtrl.text = prefs.getString('auto_backup_s3_endpoint') ?? '';
    _s3AccessKeyCtrl.text = prefs.getString('auto_backup_s3_access_key') ?? '';
    _s3SecretKeyCtrl.text = prefs.getString('auto_backup_s3_secret_key') ?? '';
    _s3BucketCtrl.text = prefs.getString('auto_backup_s3_bucket') ?? '';
  }

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPassCtrl.dispose();
    _s3EndpointCtrl.dispose();
    _s3RegionCtrl.dispose();
    _s3AccessKeyCtrl.dispose();
    _s3SecretKeyCtrl.dispose();
    _s3BucketCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('云存储配置',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                      onPressed: _save,
                      child: const Text('保存配置',
                          style: TextStyle(
                              color: WeChatColors.primary,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('存储类型',
                      style: TextStyle(
                          fontSize: 13,
                          color: WeChatColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('支持自建 Alist、NextCloud（WebDAV）及 S3 兼容（阿里云 OSS 等）',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'webdav', label: Text('WebDAV')),
                      ButtonSegment(value: 's3', label: Text('S3')),
                    ],
                    selected: {_cloudType},
                    onSelectionChanged: (v) =>
                        setState(() => _cloudType = v.first),
                  ),
                  const SizedBox(height: 16),
                  if (_cloudType == 'webdav') ...[
                    _buildField('服务器地址', _webdavUrlCtrl,
                        hint: 'https://your-alist.com/dav'),
                    const SizedBox(height: 12),
                    _buildField('用户名', _webdavUserCtrl, hint: 'admin'),
                    const SizedBox(height: 12),
                    _buildField('密码', _webdavPassCtrl,
                        hint: '••••••••', obscure: true),
                  ],
                  if (_cloudType == 's3') ...[
                    _buildField('Endpoint', _s3EndpointCtrl,
                        hint: 'https://oss-cn-hangzhou.aliyuncs.com'),
                    const SizedBox(height: 12),
                    _buildField('Region', _s3RegionCtrl, hint: 'cn-hangzhou'),
                    const SizedBox(height: 12),
                    _buildField('Access Key', _s3AccessKeyCtrl,
                        hint: 'LTAI...'),
                    const SizedBox(height: 12),
                    _buildField('Secret Key', _s3SecretKeyCtrl,
                        hint: '••••••••', obscure: true),
                    const SizedBox(height: 12),
                    _buildField('Bucket', _s3BucketCtrl,
                        hint: 'my-backups'),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.wifi_find, size: 18),
                      label: Text(_testing ? '测试中...' : '测试连接'),
                      onPressed: _testing ? null : _testConnection,
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _testResult!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _testResult!.contains('成功')
                            ? WeChatColors.primary
                            : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {String? hint, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_cloud_type', _cloudType);
    if (_cloudType == 'webdav') {
      await prefs.setString('auto_backup_webdav_url', _webdavUrlCtrl.text);
      await prefs.setString(
          'auto_backup_webdav_username', _webdavUserCtrl.text);
      await prefs.setString(
          'auto_backup_webdav_password', _webdavPassCtrl.text);
    } else {
      await prefs.setString(
          'auto_backup_s3_endpoint', _s3EndpointCtrl.text);
      await prefs.setString('auto_backup_s3_region', _s3RegionCtrl.text);
      await prefs.setString(
          'auto_backup_s3_access_key', _s3AccessKeyCtrl.text);
      await prefs.setString(
          'auto_backup_s3_secret_key', _s3SecretKeyCtrl.text);
      await prefs.setString('auto_backup_s3_bucket', _s3BucketCtrl.text);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final storage = _cloudType == 'webdav'
          ? WebDavStorage(WebDavConfig(
              url: _webdavUrlCtrl.text,
              username: _webdavUserCtrl.text,
              password: _webdavPassCtrl.text,
            ))
          : S3Storage(S3Config(
              endpoint: _s3EndpointCtrl.text,
              region: _s3RegionCtrl.text,
              accessKey: _s3AccessKeyCtrl.text,
              secretKey: _s3SecretKeyCtrl.text,
              bucket: _s3BucketCtrl.text,
            ));

      final ok = await storage.testConnection();
      setState(() {
        _testing = false;
        _testResult = ok ? '连接成功' : '连接失败，请检查配置';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = '连接失败: $e';
      });
    }
  }
}

// ─── Password Dialog ──────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _encrypt = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('云端备份加密'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('加密上传'),
            value: _encrypt,
            onChanged: (v) => setState(() => _encrypt = v),
          ),
          if (_encrypt) ...[
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认密码',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_encrypt) {
              final p = _passCtrl.text.trim();
              if (p.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入密码')));
                return;
              }
              if (p != _confirmCtrl.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              Navigator.of(context).pop(p);
            } else {
              Navigator.of(context).pop(null);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
