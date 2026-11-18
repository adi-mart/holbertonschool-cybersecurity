#!/usr/bin/env python3
import re
import hashlib


def clean_data(lines: list):
    cleaned_lines = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        yield line


def validate_line(line: str) -> bool:

    if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+:([^:]+)", line):
        return True
    else:
        return False


def hash_password(password: str, salt: str) -> str:
    password_bytes = password.encode()
    salt_bytes = salt.encode()

    hashed = hashlib.sha256(password_bytes + salt_bytes)

    return hashed.hexdigest()
