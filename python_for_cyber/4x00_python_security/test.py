#!/usr/bin/env python3

import unittest

from utils import validate_line, hash_password
from breach_check import check_policy


class TestValidateLine(unittest.TestCase):

    def test_valid_email_password(self):
        self.assertTrue(validate_line("test@gmail.com:Bonjour123"))

    def test_invalid_format(self):
        self.assertFalse(validate_line("not-an-email:password"))

    def test_missing_parts(self):
        self.assertFalse(validate_line("test@gmail.com"))
        self.assertFalse(validate_line(":password"))
        self.assertFalse(validate_line("test@gmail.com:"))


class TestCheckPolicy(unittest.TestCase):

    def test_short_password(self):
        self.assertEqual(check_policy("abc123", 8), "WEAK")

    def test_numeric_password(self):
        self.assertEqual(check_policy("123456", 8), "WEAK")

    def test_compliant_password(self):
        self.assertEqual(check_policy("Bonjour123", 8), "COMPLIANT")


class TestHashPassword(unittest.TestCase):

    def test_same_input_same_hash(self):
        password = "Bonjour123"
        salt = "my_secret_salt"

        hash1 = hash_password(password, salt)
        hash2 = hash_password(password, salt)

        self.assertEqual(hash1, hash2)


if __name__ == "__main__":
    unittest.main()
