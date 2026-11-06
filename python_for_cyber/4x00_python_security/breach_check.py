import argparse


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--filename')
    parser.add_argument('--output')
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()
    print(args.filename)
    print(args.output)
    print(args.verbose)


if __name__ == "__main__":
    main()
