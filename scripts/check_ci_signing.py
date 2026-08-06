"""CI/Gradle 配置静态校验：ci.yml YAML 可解析、关键分支逻辑存在。"""
import sys
import yaml


def main() -> int:
    with open(".github/workflows/ci.yml", encoding="utf-8") as f:
        workflow = yaml.safe_load(f)

    build_android = workflow["jobs"]["build-android"]
    keystore_step = None
    for step in build_android["steps"]:
        if "Set up release keystore" in step.get("name", ""):
            keystore_step = step
            break
    if keystore_step is None:
        print("FAIL: keystore step not found")
        return 1
    run = keystore_step["run"]
    checks = {
        "tag 无 Secrets 时 exit 1（拒绝 debug 发布）":
            "exit 1" in run and "ANDROID_KEYSTORE_BASE64" in run,
        "main 分支允许 debug 回退":
            "refs/heads/main" in run,
        "tag 触发限定 v 前缀":
            "startsWith(github.ref, 'refs/tags/v')" in build_android["if"],
        "Gradle storeFile 相对 android/ 解析":
            "rootProject.file" in open("android/app/build.gradle.kts", encoding="utf-8").read(),
    }
    ok = True
    for name, passed in checks.items():
        print(("PASS" if passed else "FAIL") + ": " + name)
        ok = ok and passed
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
