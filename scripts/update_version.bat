@echo off
REM ── 从当前 git tag 更新 pubspec.yaml 版本号（Windows） ──────────────
REM 用法:
REM   scripts\update_version.bat
REM
REM 依赖:
REM   - git (须在 PATH 中)
REM   - GNU sed 或直接使用 powershell
REM ─────────────────────────────────────────────────────────────────────

for /f "usebackq delims=" %%t in (`git describe --tags --abbrev=0 2^>nul`) do set TAG=%%t

if "%TAG%"=="" (
  echo [update_version] No git tag found. Keeping current version.
  exit /b 0
)

set VERSION=%TAG:~1%

powershell -Command "(Get-Content pubspec.yaml) -replace '^version: .+', 'version: %VERSION%' | Set-Content pubspec.yaml"
echo [update_version] pubspec.yaml version set to %VERSION% (from tag %TAG%)
