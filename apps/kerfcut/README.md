# KerfCut

**KerfCut v1.0.1 beta** is a rectangular sheet cut optimiser for workshops.

This is a beta release. It is stable enough for real workshop testing, but users should keep their original job data and verify cut plans before production use.

## Beta Access

KerfCut v1.0.1 beta is free to test for 90 days with a beta license key.

Beta keys are issued through the KerfSuite portal. To activate:

1. Install and launch KerfCut.
2. Copy the Machine ID shown on the activation screen.
3. Request a 90-day KerfCut beta key through the portal.
4. Paste the license key into KerfCut and click **Activate**.
5. Keep the key for reactivation on the same machine if needed.

The license is machine-bound. If a tester changes computers, issue a new beta key from the portal.

## User Data Folders

KerfCut stores user data in:

```text
Documents/KerfSuite/KerfCut/
```

Default subfolders:

```text
jobs/      Saved .kcut jobs
exports/   Suggested default location for PDF and CSV exports
logs/      Application logs
```

Users can still choose any folder when saving jobs, exporting PDFs, or exporting/importing CSV files.

## Run From Source

```bash
cd /d/Coding/Feed_Rate/KerfSuite/apps/kerfcut
python -m venv .venv
source .venv/Scripts/activate
python -m pip install -r requirements.txt -r requirements-dev.txt
python main.py
```

## Run Tests

```bash
python -m pytest
```

## Main Workflow

1. Add job/customer/material details.
2. Add stock sheets and quantities.
3. Add pieces and rotation settings.
4. Press **F5** or use **Optimise -> Run Optimisation**.
5. Review the cut plan and costs.
6. Export PDF or CSV if needed.

## File Formats

| Extension | Description |
|---|---|
| `.kcut` | KerfCut job file (JSON) |
| `.zcad` | Legacy KerfCut JSON file, still openable |
| `.ZAD` | Legacy Z-CAD 2.1d file, importable via File -> Import |
| `.csv` | Piece list import/export |
| `.pdf` | Cut plan export |

## Packaging

KerfCut is packaged with PyInstaller and Inno Setup. Install Inno Setup separately and make sure `iscc` is available on your PATH, or run it from the Inno Setup install folder.

```bash
python build.py
iscc installer.iss
```

The installer bundles `build/KerfCut`. It should not include local virtual environments, caches, `.env` files, logs, test artifacts, or user job files.
