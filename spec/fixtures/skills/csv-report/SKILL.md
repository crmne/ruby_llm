---
name: csv-report
description: Summarizes a CSV file into a Markdown report. Use when someone asks for a report on a CSV file.
compatibility: Requires Python 3
---

# CSV reports

Run the script on the CSV file in ./attachments/ and return the report it writes:

    python3 skills/csv-report/scripts/report.py attachments/<file>.csv report.md

The script writes report.md to the working directory.
