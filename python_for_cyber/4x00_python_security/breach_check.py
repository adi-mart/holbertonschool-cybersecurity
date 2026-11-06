import argparse


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--file', required=True)
    parser.add_argument('--output', default=None)
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()
    print(args.file)
    print(args.output)
    print(args.verbose)

    content = read_file(args.file)
    print(content)


def read_file(filename: str) -> list:
    path = filename
    try:
        with open(filename, "r") as file:
            return file.readlines()
    except FileNotFoundError:
        print(f"[ERROR] File not found: {filename}")

    try:
        with open("/etc/host", mode="w") as file:
            return []
    except PermissionError:
        print(f"[ERROR] Permission denied: {path}")


if __name__ == "__main__":
    main()
