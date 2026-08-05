# Security Review Report — SoulTalk 第二阶段 P0/P1（第二轮复审）

审查对象：本分支未提交变更中的安全修复（相对第一轮 security_review 之后的最新 mutation）。
审查方式：security_review 子代理（sa_20260805_163736_000000000_9c9d65e243de），逐项核验 + grep 消费方确认。
审查时间：实施完成后的最终复审轮。

## 结论

**minor concerns（无阻断性问题）**。5 个修复点核验通过；发现 2 项 MEDIUM（其中 1 项为本轮修复引入的回归）、2 项 LOW，全部已修复或登记。

## 修复点核验

| # | 修复点 | 核验结果 |
|---|---|---|
| ① | 敏感 key 黑名单（`backup_service.dart:102-114`、`auto_backup_service.dart:42-53`） | ✅ 两处集合一致且全覆盖；导出（204 行）与恢复（655 行）均应用过滤 |
| ② | API key 不再明文双写（`api_config_dao.dart:108-147`） | ⚠️ 方向正确，但引入 1 个数据丢失回归（见下，已修复）；无其他明文泄露路径（api_config_sender 剥离 / sync_exporter 白名单不含 / push_validator 拒绝 api_key） |
| ③ | websocket new_message push 门禁 + sync limit 钳制 | ✅ 实现正确（484-491、446-447 行） |
| ④ | deleteAttachment canonical containment | ✅ `resolveSymbolicLinks` + `isWithin` 含 rootPath 边界正确；词法回退安全 |
| ⑤ | manifest 校验移除 v1.0 跳过 | ✅ 无 version 分支，调用点直接校验 |

## 发现的问题与处置

### MEDIUM（已修复）
- **`api_config_dao.dart:86-93` — 迁移回归（本轮引入）**：`_withResolvedApiKey` 忽略 `_secureStore.write` 返回值并无条件清空 SQLite `api_key`，安全存储写失败时旧 key 被永久清空。→ 已修复：`write` 返回成功才清空 SQLite（与 insert/update 的 fallback 语义一致）。
- **`websocket_server.dart` — sync/manifest 读入口无 pull 权限门禁**：设备被撤销或无 pull 权限后，已连接会话仍可经 sync 拉取。→ 已修复：`_handleSync`/`_handleSyncCheck` 接入 `_deviceHasPermission('pull')`（`_handleManifestRequest` 确认由 pull 门禁覆盖的路径管理）。

### LOW（已修复 / 登记）
- **`attachment_service.dart` — 先删索引再校验删文件**：越界路径时索引已删文件未删，且存在 TOCTOU 窗口。→ 已修复：先 canonical 校验通过再删索引与文件。
- **`backup_service.dart:495-505, 823-833` — 恢复遍历 `archive.files` 而非仅 manifest 白名单**：恶意备份可夹带未列入 manifest 的文件（行数据有列名白名单、路径有 containment，无注入，属完整性缺口）。→ 登记为未解决问题（下轮按 manifest 白名单过滤恢复文件列表）。

## 负面声明依据

- `grep 'api_configs' lib/`：读取方仅 api_config_dao、api_config_sender（剥离）、backup_service（剥离）、database_service（建表）
- `sync_exporter._allowedTables` 不含 `api_configs`
- `pairing_store.verify` 检查 revoked（第 75 行）

## 附：第一轮审查（sa_20260805_163139_000000000_fb8d505d82f1）处置记录

8 项告警 → 6 项已修复（黑名单补漏、api_key 双写、new_message 门禁、deleteAttachment containment、sync limit 钳制、v1.0 manifest 强制校验）+ 2 项登记（扫码即配对的产品决策、错误信息脱敏）。
