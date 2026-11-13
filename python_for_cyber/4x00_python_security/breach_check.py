import argparse
import re
import logging

console_handler = logging.StreamHandler()
file_handler = logging.FileHandler("breach_check.log")

console_handler.setLevel(logging.INFO)
file_handler.setLevel(logging.DEBUG)

formatter = logging.Formatter(
    "%(asctime)s - %(levelname)s - %(message)s"
)

console_handler.setFormatter(formatter)
file_handler.setFormatter(formatter)

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

logger.addHandler(console_handler)
logger.addHandler(file_handler)


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--file', required=True)
    parser.add_argument('--output', default=None)
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()

    logging.info(args.file)
    logging.info(args.output)
    logging.info(args.verbose)

    content = clean_data(read_file(args.file))
    logging.debug(content)
    for line in content:
        if validate_line(line):
            logging.info(f"[PASS] : {line}")
        else:
            logging.warning(f"[FAIL]: {line}")


def read_file(filename: str) -> list:
    path = filename

    try:
        with open(filename, "r") as file:
            return file.readlines()

    except FileNotFoundError:
        logging.error(f"File not found: {filename}")
        return []

    except PermissionError:
        logging.error(f"Permission denied: {path}")
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
