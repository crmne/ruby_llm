import csv
import os
import sys
import tempfile

source, target = sys.argv[1], sys.argv[2]
with open(source, newline="") as file:
    rows = list(csv.DictReader(file))

scratch = os.path.join(tempfile.gettempdir(), "rows.txt")
with open(scratch, "w") as file:
    file.write(str(len(rows)))

with open(target, "w") as file:
    file.write(f"# Report\n\nRows: {open(scratch).read()}\n")
    file.write(f"Columns: {', '.join(rows[0].keys()) if rows else ''}\n")
