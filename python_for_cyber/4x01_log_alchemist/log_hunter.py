#!/usr/bin/env python3
import argparse
import logging
import re


def main():

    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument('file')
    args = parser.parse_args()

    logging.info(f"[*] Reading: {args.file}")

    content = read_stream(args.file)
    count = 0

    for line in content:
        parsed = parse_apache_line(line)

        if parsed:
            count += 1
        return None

    logging.info(f"[*] Apache lines: {count}")


def read_stream(file_path: str):

    try:
        with open(file_path, "r") as file:
            for line in file:
                yield line

    except FileNotFoundError:
        print(f"File not found: {file_path}")


regex_apache = re.compile(
    r'(?P<ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) '
    r'- - '
    r'\[(?P<date>\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2}\s[+-]\d{4})\] '
    r'"(?P<method>GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH) '
    r'(?P<path>\S+) '
    r'HTTP/\d\.\d" '
    r'(?P<status>\d{3}) '
    r'(?P<size>\d+|-)'
)


def parse_apache_line(line: str) -> dict:

    match = regex_apache.search(line)

    if not match:
        return None

    return match.groupdict()


if __name__ == "__main__":
    main()
