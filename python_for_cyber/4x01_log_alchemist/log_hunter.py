#!/usr/bin/env python3
import argparse
import logging


def main():

    logging.basicConfig(level=logging.INFO)

    logging.info('[*]')
    logging.error('[ERROR]')
    logging.warning('[!]')

    parser = argparse.ArgumentParser()

    parser.add_argument('file')

    args = parser.parse_args()

    logging.info(args.file)

    content = read_stream(args.file)
    count = 0
    for line in content:
        count = count + 1
    logging.info(count)


def read_stream(file_path: str):

    try:
        with open(file_path, "r") as file:
            for line in file:
                yield line

    except FileNotFoundError:
        print(f"File not found: {file_path}")


if __name__ == "__main__":
    main()
