import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/scheduler_job_dao.dart';
import 'package:soultalk/services/proactive/proactive_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'proactive check handler schedules next fixed five minute run',
    () async {
      var runCount = 0;
      final handler = ProactiveCheckTaskHandler(
        runCheck: () async => runCount++,
      );
      final before = DateTime.now().add(const Duration(minutes: 5));

      final result = await handler.run(_job('proactive_check'));

      expect(runCount, 1);
      expect(result.success, isTrue);
      expect(result.summary, 'checked');
      expect(
        result.nextRunAfterMillis,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1000),
      );
    },
  );

  test('moments cycle handler uses configured interval for next run', () async {
    SharedPreferences.setMockInitialValues({'moments_interval_minutes': 15});
    var runCount = 0;
    final handler = MomentsCycleTaskHandler(runCycle: () async => runCount++);
    final before = DateTime.now().add(const Duration(minutes: 15));

    final result = await handler.run(_job('moments_cycle'));

    expect(runCount, 1);
    expect(result.success, isTrue);
    expect(result.summary, 'moments cycle completed');
    expect(
      result.nextRunAfterMillis,
      greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1000),
    );
  });

  test('fresh database creates all recurring jobs idempotently', () async {
    sqfliteFfiInit();
    final tempDir = await Directory.systemTemp.createTemp('sched_jobs_');
    databaseFactoryFfi.setDatabasesPath(tempDir.path);
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});

    try {
      final service = ProactiveService();
      await service.ensureRecurringJobs();
      // 重复调用不产生重复任务
      await service.ensureRecurringJobs();

      final dao = SchedulerJobDao(DatabaseService());
      final check = await dao.getByTypeTarget('proactive_check', 'global');
      final cycle = await dao.getByTypeTarget('moments_cycle', 'global');
      expect(check, isNotNull, reason: '全新数据库必须创建 proactive_check');
      expect(check!.status, 'pending');
      expect(cycle, isNotNull, reason: '全新数据库必须创建 moments_cycle');
      expect(cycle!.status, 'pending');

      final db = await DatabaseService().database;
      final rows = await db.query(
        'scheduler_jobs',
        where: "type IN ('proactive_check','moments_cycle')",
      );
      expect(rows.length, 2, reason: '重复 ensure 不得产生重复任务');
    } finally {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });
}

SchedulerJobRecord _job(String type) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return SchedulerJobRecord(
    id: '$type-global',
    type: type,
    targetId: 'global',
    runAfter: now,
    retryCount: 0,
    status: 'running',
    payload: '{}',
    lastError: null,
    createdAt: now,
    updatedAt: now,
  );
}
