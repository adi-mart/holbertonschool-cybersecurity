import argparse
import re

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--file', required=True)
    parser.add_argument('--output', default=None)
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()
    print(args.file)
    print(args.output)
    print(args.verbose)

    content = clean_data(read_file(args.file))
    print(content)
    for line in content:
      if validate_line(line):
          print(f"[PASS] : {line}")
      else:
          print(f"[FAIL]: {line}")

def read_file(filename: str) -> list:
    path = filename
    
    try:
        with open(filename, "r") as file:
            return file.readlines()

    except FileNotFoundError:
        print(f"[ERROR] File not found: {filename}")
        return []

    except PermissionError:
        print(f"[ERROR] Permission denied: {path}")
        return []

def clean_data(lines: list) -> list:
    cleaned_lines = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        cleaned_lines.append(line)
    return cleaned_lines

def validate_line(line: str) -> bool:

    if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+:([^:]+)", line):
        return True
    else:
        return False


if __name__ == "__main__":
    main()
