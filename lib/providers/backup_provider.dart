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

  Future<String?> exportData(
    Set<BackupSection> sections,
    String targetDir, {
    String? password,
  }) async {
    state = const ExportState(isExporting: true);
    try {
      final path = await _service.exportToZip(
        sections: sections,
        targetDir: targetDir,
        password: password,
      );
      state = ExportState(exportPath: path);
      return path;
    } catch (e) {
      state = ExportState(error: e.toString());
      return null;
    }
  }

  Future<bool> importData(
    String zipPath,
    Set<BackupSection> sections, {
    String? password,
  }) async {
    state = const ExportState(isExporting: true);
    try {
      final result = await _service.importFromZip(
        zipPath: zipPath,
        sections: sections,
        password: password,
      );
      state = const ExportState();
      return result;
    } catch (e) {
      state = ExportState(error: e.toString());
      return false;
    }
  }

  void reset() => state = const ExportState();
}

final backupProvider = StateNotifierProvider<BackupNotifier, ExportState>(
  (ref) => BackupNotifier(),
);
