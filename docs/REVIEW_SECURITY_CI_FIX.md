# 安全审查报告：CI 修复 + 自动发布 Release（第三轮，2026-08-06）

审查范围：HEAD~2..HEAD（提交 8acdad6、76e360a）+ 前序 CI 改造（a97f6d8、52d2360、d427983）
审查方式：security_review 子代理（sa_20260806_051652_000000000_628701410fbf）

## 结论：无阻塞性安全问题（warn 级）

## 已核实为安全的部分

- **catchError/竞态修复**：`ApiConfigSender.sendConfig` 内部全量 try/catch + `developer.log`
  （api_config_sender.dart:32-41），外层 `catchError` 仅兜底且同样记录——错误未被静默吞掉；
  认证失败路径（`_rejectAuth`）在 sendConfig 之前、不受影响；
  `getConfigsForSync` 剥离 `api_key`（行 91），确认配置内容无凭据。
- **ci.yml 命令注入**：`::error` 输出经 `sed` 转义 `%25/%0D/%0A` 且顺序正确（先 `%` 后 CR/LF）；
  keystore secrets 步骤的 `echo | base64 -d` / `printf` 均重定向到文件，stdout 仅状态行。
- **fork PR** 不会触发 release（`github.ref` 为 `refs/pull/N/merge`，不匹配 main/v* 条件）；
  release-action 固定 commit SHA，GITHUB_TOKEN job 级最小权限。

## 发现（按严重度）

| 级别 | 位置 | 问题 | 处置 |
|---|---|---|---|
| MEDIUM | ci.yml release 触发 | 任意 `v*` tag push 即触发完整构建+发布，且 tag 固定取 pubspec 版本 + allowUpdates + makeLatest；push `v9.9.9` 会重建并覆盖现有 v1.3.0 release 及 latest 标记 | 记录待办：release job 增加「推送 tag 与 pubspec 版本一致性校验」；tag 推送属用户显式操作，当前不阻塞 |
| LOW | ci.yml 诊断 grep | `failed\|Failed` 启发式匹配的日志行会进入公开 annotation/summary；当前测试 secret 均为 fake 值（grep 确认），无实际泄露 | 记录待办：仅输出 `[E]`/`✗` 测试名行或清洗关键词 |
| LOW | api_config_sender.dart | 发送失败只记录、无重试，DB 未就绪时 PC 端静默缺失 api_config | 可靠性提示，非安全问题，暂不处理 |

## 说明

- 版本号 1.3.0 与 release workflow 为更早提交引入，无新增风险。
- 测试 tearDown 的 600ms 延迟属测试稳定性处理，非安全问题。
- 本轮验证：`git diff HEAD~1 --check` 退出码 0；CI run 51 全绿（analyze/test/format + 三平台构建 + release）；
  v1.3.0 Release 已发布（https://github.com/shuangyue1124/soultalk/releases/tag/v1.3.0）。
