import os
import subprocess
import sys
from pathlib import Path

from version import APP_NAME, APP_VERSION


def build():
    print(f"Starting PyInstaller build for {APP_NAME} {APP_VERSION}...")

    if os.path.exists(".env"):
        print("INFO: .env detected locally but will not be bundled into the build.")

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--windowed",
        "--icon",
        str((Path("assets") / "KerfCut.ico").resolve()),
        "--name",
        APP_NAME,
        "--distpath",
        "build",
        "--workpath",
        str(Path("build") / "_work"),
        "--specpath",
        str(Path("build") / "_spec"),
        "--add-data",
        f"{Path('assets').resolve()};assets",
        "main.py",
    ]

    print(f"Running command: {' '.join(cmd)}")
    result = subprocess.run(cmd)

    if result.returncode == 0:
        print("Build completed successfully!")
        print(f"Executable should be in build/{APP_NAME}/{APP_NAME}.exe")
    else:
        print(f"Build failed with exit code {result.returncode}")
        sys.exit(result.returncode)


if __name__ == "__main__":
    build()
