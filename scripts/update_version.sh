#!/usr/bin/env bash
# ── 从当前 git tag 更新 pubspec.yaml 版本号 ──────────────────────────────
# 用法:
#   ./scripts/update_version.sh
#
# 说明：
#   读取 `git describe --tags --abbrev=0` 获取最近一个 tag（如 v1.2.3），
#   去掉前缀 "v"，写入 pubspec.yaml 的 version 字段。
#
# 如果当前没有 tag（首个版本），则保持 pubspec.yaml 中的版本不变。
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)

if [ -z "$TAG" ]; then
  echo "[update_version] No git tag found — keeping current version."
  exit 0
fi

VERSION="${TAG#v}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "[update_version] Tag '$TAG' does not look like a valid semver — skipping."
  exit 1
fi

sed -i.bak "s/^version: .*/version: $VERSION/" pubspec.yaml
rm -f pubspec.yaml.bak
echo "[update_version] pubspec.yaml version → $VERSION (from tag $TAG)"
