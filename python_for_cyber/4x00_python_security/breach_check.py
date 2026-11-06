import argparse


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--file', required=True)
    parser.add_argument('--output', default=None,)
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()
    print(args.file)
    print(args.output)
    print(args.verbose)


if __name__ == "__main__":
    main()
