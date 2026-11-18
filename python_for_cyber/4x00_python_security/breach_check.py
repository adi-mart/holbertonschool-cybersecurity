import argparse
import logging
import sys
import configparser

from utils import clean_data, validate_line, hash_password, read_file

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

    salt, min_length = load_config()

    parser = argparse.ArgumentParser()

    parser.add_argument('--file', required=True)
    parser.add_argument('--output', default=None)
    parser.add_argument('--verbose', action="store_true")

    args = parser.parse_args()

    logging.info(args.file)
    logging.info(args.output)
    logging.info(args.verbose)

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    content = clean_data(read_file(args.file))
    logging.debug(content)
    for line in content:
        if validate_line(line):
            email, password = line.split(":", 1)

            status = check_policy(password, min_length)

            if status == "WEAK":
                logging.warning(f"[WEAK] : {email}")
            else:
                logging.info(f"[COMPLIANT] : {email}")

            hashed_password = hash_password(password, salt)
            logging.debug(f"[HASH] : {email} -> {hashed_password}")

        else:
            logging.warning(f"[FAIL]: {line}")


def check_policy(password: str, min_length: int) -> str:
    common_passwords = ["password", "123456"]

    if len(password) < min_length:
        return "WEAK"

    if password.isalpha():
        return "WEAK"

    if password in common_passwords:
        return "WEAK"

    return "COMPLIANT"


def load_config():
    config = configparser.ConfigParser()

    if not config.read("config.ini"):
        logging.error("[ERROR] config file missing")
        sys.exit(1)

    salt = config.get("SECURITY", "Salt")
    min_length = config.getint("SECURITY", "MinLength")

    return salt, min_length


if __name__ == "__main__":
    main()
