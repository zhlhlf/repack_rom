#!/usr/bin/env python3

import sys
from pathlib import Path

from apk_info import APK


def get_apk_meta(path: str | Path) -> tuple[str, str]:
    apk = APK(path)
    package_name = apk.get_package_name() or ""
    app_name = apk.get_application_label() or ""
    return " ".join(package_name.split()), " ".join(app_name.split())


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <apk>", file=sys.stderr)
        return 2

    try:
        package_name, app_name = get_apk_meta(sys.argv[1])
    except Exception as exc:
        print(f"{sys.argv[1]}: {exc}", file=sys.stderr)
        return 1

    print(package_name)
    print(app_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
