/// 冲突解决器 - 处理手机端和 PC 端消息冲突
class ConflictResolver {
  /// 检测冲突
  List<MessageConflict> detectConflicts(
    List<Map<String, dynamic>> mobileMessages,
    List<Map<String, dynamic>> pcMessages,
  ) {
    final conflicts = <MessageConflict>[];

    for (final pcMsg in pcMessages) {
      final contactId = pcMsg['contactId'] as String?;
      final timestamp = pcMsg['timestamp'] as String?;

      if (contactId == null || timestamp == null) continue;

      // 查找同一角色、相近时间的消息
      final conflictingMobile = mobileMessages.where((m) {
        if (m['contactId'] != contactId) return false;

        final mobileTime = DateTime.tryParse(m['timestamp'] as String? ?? '');
        final pcTime = DateTime.tryParse(timestamp);
        if (mobileTime == null || pcTime == null) return false;

        // 5 分钟内的消息视为潜在冲突
        final diff = mobileTime.difference(pcTime).abs();
        return diff.inMinutes <= 5;
      }).toList();

      if (conflictingMobile.isNotEmpty) {
        conflicts.add(
          MessageConflict(
            contactId: contactId,
            mobileMessage: conflictingMobile.first,
            pcMessage: pcMsg,
            timestamp: timestamp,
          ),
        );
      }
    }

    return conflicts;
  }

  /// 应用解决方案
  List<Map<String, dynamic>> resolve(
    List<MessageConflict> conflicts,
    List<ConflictResolution> resolutions,
  ) {
    final results = <Map<String, dynamic>>[];

    for (var i = 0; i < conflicts.length; i++) {
      final conflict = conflicts[i];
      final resolution = i < resolutions.length
          ? resolutions[i]
          : ConflictResolution.keepMobile;

      switch (resolution) {
        case ConflictResolution.keepMobile:
          results.add({
            'action': 'keep_mobile',
            'messageId': conflict.mobileMessage['id'],
          });
          break;
        case ConflictResolution.keepPC:
          results.add({
            'action': 'keep_pc',
            'messageId': conflict.mobileMessage['id'],
            'content': conflict.pcMessage['content'],
          });
          break;
        case ConflictResolution.manualEdit:
          // 手动编辑的结果由 UI 层传入
          results.add({
            'action': 'manual_edit',
            'messageId': conflict.mobileMessage['id'],
            'content': conflict.pcMessage['content'], // 临时值
          });
          break;
      }
    }

    return results;
  }
}

/// 消息冲突
class MessageConflict {
  final String contactId;
  final Map<String, dynamic> mobileMessage;
  final Map<String, dynamic> pcMessage;
  final String timestamp;

  const MessageConflict({
    required this.contactId,
    required this.mobileMessage,
    required this.pcMessage,
    required this.timestamp,
  });
}

/// 冲突解决方案
enum ConflictResolution { keepMobile, keepPC, manualEdit }
