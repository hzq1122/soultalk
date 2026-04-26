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

class UpdateService {
  static const _repoOwner = 'hzq1122';
  static const _repoName = 'AI_talk';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options:
            Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
      final data = response.data as Map<String, dynamic>;
      final tagName =
          (data['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '') ??
              '0.0.0';
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
        return UpdateInfo(
          version: tagName,
          downloadUrl: apkUrl,
          releaseNotes: (data['body'] as String?) ?? '',
          fileSize: fileSize,
        );
      }
      return null;
    } catch (_) {
      return null;
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
