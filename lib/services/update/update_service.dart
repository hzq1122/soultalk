import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class ReleaseEntry {
  final String version;
  final String title;
  final String body;
  final String publishedAt;

  const ReleaseEntry({
    required this.version,
    required this.title,
    required this.body,
    required this.publishedAt,
  });
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final int fileSize;
  final List<ReleaseEntry> changelog;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileSize,
    this.changelog = const [],
  });
}

class UpdateService {
  static const _repoOwner = 'hzq1122';
  static const _repoName = 'soultalk';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Check GitHub for a newer release. Returns [UpdateInfo] with full
  /// changelog (all releases between current and latest) if an update
  /// is available, or null if current is already the latest.
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      // Fetch latest release
      final latestResp = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final latest = latestResp.data as Map<String, dynamic>;
      final latestVersion =
          (latest['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '') ?? '0.0.0';

      if (_compareVersions(latestVersion, currentVersion) <= 0) {
        return null; // Already up to date
      }

      // Find APK asset
      String? apkUrl;
      int fileSize = 0;
      final assets = latest['assets'] as List? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          fileSize = (asset['size'] as int?) ?? 0;
          break;
        }
      }

      // Fetch changelog: all releases newer than current version
      final changelog = await _fetchChangelog(currentVersion);

      final latestNotes = latest['body'] as String? ?? '';

      return UpdateInfo(
        version: latestVersion,
        downloadUrl: apkUrl ?? '',
        releaseNotes: latestNotes,
        fileSize: fileSize,
        changelog: changelog,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch all releases between [currentVersion] and the latest.
  Future<List<ReleaseEntry>> _fetchChangelog(String currentVersion) async {
    try {
      final resp = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases?per_page=30',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final list = resp.data as List;
      final entries = <ReleaseEntry>[];

      for (final item in list) {
        final tag = (item['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '') ?? '0.0.0';
        // Stop once we reach releases <= current version
        if (_compareVersions(tag, currentVersion) <= 0) break;

        entries.add(ReleaseEntry(
          version: tag,
          title: (item['name'] as String?) ?? tag,
          body: (item['body'] as String?) ?? '',
          publishedAt: (item['published_at'] as String?) ?? '',
        ));
      }

      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<String> downloadApk(
      UpdateInfo info, void Function(double progress) onProgress) async {
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
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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
