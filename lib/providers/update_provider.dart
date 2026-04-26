import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update/update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  noUpdate,
  updateAvailable,
  downloading,
  downloadComplete,
  error,
}

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
  }) =>
      UpdateState(
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
        state = state.copyWith(
            status: UpdateStatus.updateAvailable, updateInfo: info);
      } else {
        state = state.copyWith(status: UpdateStatus.noUpdate);
      }
    } catch (e) {
      state = state.copyWith(
          status: UpdateStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> startDownload() async {
    if (state.updateInfo == null) return;
    state = state.copyWith(
        status: UpdateStatus.downloading, downloadProgress: 0);
    try {
      final path = await _service.downloadApk(state.updateInfo!, (progress) {
        state = state.copyWith(downloadProgress: progress);
      });
      state = state.copyWith(
          status: UpdateStatus.downloadComplete, downloadPath: path);
    } catch (e) {
      state = state.copyWith(
          status: UpdateStatus.error, errorMessage: '下载失败: $e');
    }
  }

  void cancelDownload() {
    state = state.copyWith(
        status: UpdateStatus.updateAvailable, downloadProgress: 0);
  }

  Future<void> deleteDownloadedApk() async {
    if (state.downloadPath != null) {
      await _service.deleteApk(state.downloadPath!);
    }
    state = state.copyWith(
        status: UpdateStatus.updateAvailable, downloadPath: null);
  }
}

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) => UpdateNotifier());
