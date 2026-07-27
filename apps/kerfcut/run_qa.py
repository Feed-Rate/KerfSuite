import subprocess
import sys
import os
from datetime import datetime

def run_command(cmd, description):
    print(f"--- Running {description} ---")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1

def main():
    report_lines = [
        "# Quality Assurance Report",
        f"Generated at: {datetime.now().isoformat()}",
        "",
        "## Summary",
    ]

    # 1. Tests & Coverage
    stdout, stderr, code = run_command("python -m pytest --cov=core --cov=ui --cov-report=term", "Pytest & Coverage")
    test_status = "✅ Pass" if code == 0 else "❌ Fail"
    report_lines.append(f"- **Tests**: {test_status}")

    # Extract coverage % from stdout if possible
    cov_line = [line for line in stdout.split('\n') if 'TOTAL' in line]
    if cov_line:
        report_lines.append(f"- **Coverage**: {cov_line[-1].split()[-1]}")

    # 2. Linting (Flake8)
    stdout, stderr, code = run_command("python -m flake8 core/ ui/ --count --select=E9,F63,F7,F82 --show-source --statistics", "Linting (Critical)")
    lint_status = "✅ Clean" if code == 0 else "⚠️ Issues found"
    report_lines.append(f"- **Linting (Critical)**: {lint_status}")

    # 3. Complexity (Radon)
    stdout, stderr, code = run_command("python -m radon cc core/ -s -n B", "Complexity Analysis")
    report_lines.append(f"- **Complexity (Grade B or better)**: {'✅ Pass' if not stdout else '⚠️ High complexity detected'}")
    if stdout:
        report_lines.append("  ```")
        report_lines.append(stdout)
        report_lines.append("  ```")

    # 4. Type Checking (Mypy)
    stdout, stderr, code = run_command("python -m mypy core/ --ignore-missing-imports", "Type Checking")
    report_lines.append(f"- **Static Analysis (Mypy)**: {'✅ Pass' if code == 0 else '⚠️ Issues found'}")

    # Output to Artifact
    artifact_path = ".artifacts/quality_report.artifact.md"
    os.makedirs(os.path.dirname(artifact_path), exist_ok=True)
    with open(artifact_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines))

    print(f"\nQA Report generated at {artifact_path}")

if __name__ == "__main__":
    main()
