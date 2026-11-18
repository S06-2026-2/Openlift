"""Validate minimum line coverage from an LCOV report."""

import argparse
import sys
from pathlib import Path


def calculate_coverage(path: Path) -> tuple[int, int]:
    if not path.is_file():
        raise FileNotFoundError(f"Coverage file not found: {path}")

    found_lines = {}
    current_file = None

    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("SF:"):
            current_file = line[3:]
            found_lines.setdefault(current_file, {})

        elif line.startswith("DA:") and current_file:
            parts = line[3:].split(",")
            line_number = int(parts[0])
            hits = int(parts[1])

            previous = found_lines[current_file].get(line_number, 0)
            found_lines[current_file][line_number] = max(
                previous, hits
            )

        elif line == "end_of_record":
            current_file = None

    total = sum(len(lines) for lines in found_lines.values())

    covered = sum(
        sum(hits > 0 for hits in lines.values())
        for lines in found_lines.values()
    )

    return covered, total


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("lcov_file", type=Path)
    parser.add_argument("--minimum", type=float, default=60.0)

    args = parser.parse_args()

    try:
        covered, total = calculate_coverage(args.lcov_file)
    except (OSError, ValueError) as error:
        print(f"Coverage error: {error}", file=sys.stderr)
        return 1

    if total == 0:
        print("Coverage error: no instrumented lines found.")
        return 1

    percentage = covered / total * 100

    print(f"Covered lines: {covered}/{total}")
    print(f"Line coverage: {percentage:.2f}%")
    print(f"Required coverage: {args.minimum:.2f}%")

    if percentage + 1e-9 < args.minimum:
        print("FAIL: Coverage below minimum.")
        return 1

    print("PASS: Coverage meets minimum.")
    return 0


if __name__ == "__main__":
    sys.exit(main())