import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'websocket_client.dart';
import 'sync/pull_sync_service.dart';
import 'sync/push_sync_service.dart';
import 'services/database/pc_mirror_dao.dart';

/// 同步管理器 - 处理与手机端的消息同步
class SyncManager {
  final WebSocketClient _client;
  late final PullSyncService _pullSyncService;
  late final PushSyncService _pushSyncService;
  final PcMirrorDao _mirrorDao;
  final List<Map<String, dynamic>> _messages = [];
  String? _lastSyncTime;

  final StreamController<List<Map<String, dynamic>>> _messagesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  /// 最近一次同步失败的原因（供 UI 展示与重试提示）。
  String? _lastError;
  String? get lastError => _lastError;

  Stream<List<Map<String, dynamic>>> get messagesStream =>
      _messagesController.stream;
  Stream<SyncState> get stateStream => _stateController.stream;

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  String? get lastSyncTime => _lastSyncTime;

  SyncManager(this._client, {PcMirrorDao? mirrorDao})
    : _mirrorDao = mirrorDao ?? PcMirrorDao() {
    _pullSyncService = PullSyncService(client: _client, mirrorDao: _mirrorDao);
    _pushSyncService = PushSyncService(client: _client);
    _eventsSubscription = _client.events.listen(_handleEvent);
  }

  /// 请求同步
  void requestSync() {
    _stateController.add(SyncState.syncing);
    _pullSyncService.requestManifest();
    _pullSyncService.requestTable('messages');
    // 删除同步：拉取 tombstone 记录，清理 mirror 中已删除的行
    _pullSyncService.requestTable('pc_deletions');
  }

  /// 检查同步状态
  void checkSync() {
    if (_lastSyncTime != null) {
      _client.sendSyncCheck(_lastSyncTime!);
    }
  }

  /// 发送新消息
  void sendMessage(String contactId, String content) {
    _pushSyncService.proposeMessage(contactId, content);

    // 本地添加消息
    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'contactId': contactId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'fromPC': true,
    };
    _messages.add(message);
    _messagesController.add(_messages);
  }

  /// 解决冲突
  void resolveConflicts(List<Map<String, dynamic>> resolutions) {
    _client.sendConflictResolution(resolutions);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'sync_data':
        _handleSyncData(event);
        break;
      case 'sync_check_result':
        _handleSyncCheckResult(event);
        break;
      case 'new_message':
        _handleNewMessage(event);
        break;
      case 'manifest.response':
        _stateController.add(SyncState.syncing);
        break;
      case 'pull.chunk':
        _handlePullChunk(event);
        break;
      case 'pull.error':
        // 同步失败：记录原因并进入 error 状态（UI 显示原因 + 重试入口）
        _lastError =
            '${(event['message'] as String?) ?? '拉取失败'}'
            '（table: ${(event['payload'] as Map?)?['table']}）';
        _stateController.add(SyncState.error);
        break;
      case 'pull.complete':
        _lastError = null;
        _stateController.add(SyncState.idle);
        break;
      case 'push.result':
        final payload = (event['payload'] as Map?);
        if (payload?['accepted'] == false) {
          _lastError = (payload?['reason'] as String?) ?? '推送被拒绝';
          _stateController.add(SyncState.error);
        }
        break;
    }
  }

  void _handleSyncData(Map<String, dynamic> event) {
    final data = event['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final messages = data['messages'] as List<dynamic>?;
    if (messages != null) {
      for (final msg in messages) {
        final msgMap = msg as Map<String, dynamic>;
        // 避免重复
        if (!_messages.any((m) => m['id'] == msgMap['id'])) {
          _messages.add(msgMap);
        }
      }
      // 按时间排序
      _messages.sort((a, b) {
        final aTime = a['timestamp'] as String? ?? '';
        final bTime = b['timestamp'] as String? ?? '';
        return aTime.compareTo(bTime);
      });
      _messagesController.add(_messages);
    }

    _lastSyncTime =
        data['serverTime'] as String? ?? DateTime.now().toIso8601String();
    _stateController.add(SyncState.idle);
  }

  Future<void> _handlePullChunk(Map<String, dynamic> event) async {
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
    final table = payload?['table'] as String?;
    final rows = (payload?['rows'] as List?)?.cast<Map>();

    if (table == null || rows == null) return;

    // 记录增量水位：本次拉取的最后一行时间戳（分页续拉也适用，
    // 最终一页会覆盖为最新值）
    if (rows.isNotEmpty) {
      _pullSyncService.recordWatermark(
        table,
        rows.last.cast<String, dynamic>(),
      );
    }

    if (table == 'pc_deletions') {
      // 应用删除 tombstone，不进入 mirror
      await _pullSyncService.handlePullChunk(event);
    } else {
      await _pullSyncService.handlePullChunk(event);
      if (table == 'messages') {
        final mirrorRows = await _mirrorDao.getRows('messages');
        _messages
          ..clear()
          ..addAll(mirrorRows);
        _messagesController.add(_messages);
      }
    }

    // 分页续拉：hasMore 为 true 时用最后一条的复合游标
    // （updated_at 水位 + id）继续请求，直到服务端下发 pull.complete
    // （避免超过一页的数据静默丢失；原地修改的行也能续拉）。
    if (payload?['hasMore'] == true && rows.isNotEmpty) {
      final lastRow = rows.last as Map<String, dynamic>;
      final lastId = lastRow['id']?.toString();
      final lastUpdatedAt = (lastRow['updated_at'] ?? lastRow['created_at'])
          ?.toString();
      if (lastId != null && lastId.isNotEmpty) {
        _pullSyncService.requestTable(
          table,
          limit: 500,
          after: lastId,
          afterUpdatedAt: lastUpdatedAt,
        );
      }
    }
  }

  Future<void> _handleSyncCheckResult(Map<String, dynamic> event) async {
    final serverMerkleRoot = event['merkleRoot'] as String?;
    final localMerkleRoot = await _calculateLocalMerkleRoot();

    if (serverMerkleRoot != localMerkleRoot) {
      // 数据不一致，需要同步
      requestSync();
    } else {
      _stateController.add(SyncState.idle);
    }
  }

  void _handleNewMessage(Map<String, dynamic> event) {
    final message = {
      'id':
          event['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'contactId': event['contactId'],
      'content': event['content'],
      'timestamp': event['timestamp'],
      'fromPC': event['fromPC'] ?? false,
    };

    if (!_messages.any((m) => m['id'] == message['id'])) {
      _messages.add(message);
      _messagesController.add(_messages);
    }
  }

  /// 本地 Merkle Root：基于 mirror 行（camelCase）计算，与手机端
  /// 规范化规则一致——每行按 key 排序后 JSON 编码，行哈希排序后
  /// 构建 Merkle。两端用同一规则，校验结果才一致。
  Future<String> _calculateLocalMerkleRoot() async {
    final rows = await _mirrorDao.getRows('messages');
    if (rows.isEmpty) {
      return sha256.convert(utf8.encode('empty')).toString();
    }

    final hashes = rows.map((m) {
      final sorted = <String, dynamic>{};
      final entries = m.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final e in entries) {
        sorted[e.key] = e.value;
      }
      return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
    }).toList()..sort();

    return _calculateMerkle(hashes);
  }

  String _calculateMerkle(List<String> hashes) {
    if (hashes.isEmpty) {
      return sha256.convert(utf8.encode('')).toString();
    }
    if (hashes.length == 1) return hashes.first;

    final nextLevel = <String>[];
    for (var i = 0; i < hashes.length; i += 2) {
      if (i + 1 < hashes.length) {
        final combined = hashes[i] + hashes[i + 1];
        nextLevel.add(sha256.convert(utf8.encode(combined)).toString());
      } else {
        nextLevel.add(hashes[i]);
      }
    }
    return _calculateMerkle(nextLevel);
  }

  void dispose() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _messagesController.close();
    _stateController.close();
  }
}

enum SyncState { idle, syncing, conflict, error }
