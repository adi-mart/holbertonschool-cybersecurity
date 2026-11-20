#!/usr/bin/env python3
import argparse
import logging
import re
from dataclasses import dataclass


@dataclass
class LogEntry:
    ip: str
    timestamp: str
    service: str
    message: str
    raw_line: str

    method: str = None
    path: str = None
    status: int = None
    user_agent: str = None
    country: str = "UNKNOWN"


regex_ip = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')

regex_apache = re.compile(
    r'(?P<ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) '
    r'\S+ \S+ '
    r'\[(?P<date>\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2}\s[+-]\d{4})\] '
    r'"(?P<method>[A-Z]+) '
    r'(?P<path>\S+) '
    r'HTTP/\d\.\d" '
    r'(?P<status>\d{3}) '
    r'(?P<size>\d+|-)'
)

regex_syslog = re.compile(
    r'(?P<date>[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}) '
    r'(?P<host>\S+) '
    r'(?P<process>\S+): '
    r'(?P<message>.*)'
)

GEOIP_DB = {
    '1.2.3.4': 'US',
    '5.6.7.8': 'RU'
}


def enrich_ip(log_entry):
    log_entry.country = GEOIP_DB.get(log_entry.ip, "UNKNOWN")
    return log_entry


def normalize_entry(parsed_dict, log_type, raw_line='') -> LogEntry:

    if log_type == "apache":
        return LogEntry(
            ip=parsed_dict["ip"],
            timestamp=parsed_dict["date"],
            service="http",
            message=(
                f'{parsed_dict["method"]} {parsed_dict["path"]} '
                f'-> {parsed_dict["status"]}'
            ),
            raw_line=raw_line.strip(),
            method=parsed_dict["method"],
            path=parsed_dict["path"],
            status=int(parsed_dict["status"]),
            user_agent=parsed_dict.get("user_agent")
        )

    elif log_type == "syslog":
        ip_match = regex_ip.search(parsed_dict["message"])
        ip = ip_match.group() if ip_match else ""

        return LogEntry(
            ip=ip,
            timestamp=parsed_dict["date"],
            service="ssh",
            message=parsed_dict["message"],
            raw_line=raw_line.strip()
        )

    return None


def filter_logs(stream, status_codes=[404, 500]):

    for entry in stream:
        status = getattr(entry, 'status', None)

        if status in status_codes:
            yield entry


def read_stream(file_path: str):

    try:
        with open(file_path, "r") as file:
            for line in file:
                yield line

    except FileNotFoundError:
        print(f"File not found: {file_path}")


def parse_apache_line(line: str) -> dict:

    match = regex_apache.search(line)

    if not match:
        return None

    return match.groupdict()


def parse_syslog_line(line: str) -> dict:

    match = regex_syslog.search(line)

    if not match:
        return None

    return match.groupdict()


def main():

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    parser = argparse.ArgumentParser()
    parser.add_argument('file')
    args = parser.parse_args()

    logging.info("[*] LogHunter - Log Analysis Engine")
    logging.info(f"[*] Reading: {args.file}")

    content = read_stream(args.file)

    apache_count = 0
    sys_count = 0
    total_count = 0
    entries = []

    for line in content:
        parsed = parse_apache_line(line)

        if parsed:
            normalized = normalize_entry(parsed, "apache", line)

            if normalized:
                entries.append(normalized)
                apache_count += 1
                total_count += 1

        else:
            parsed = parse_syslog_line(line)

            if parsed:
                normalized = normalize_entry(parsed, "syslog", line)

                if normalized:
                    entries.append(normalized)
                    sys_count += 1
                    total_count += 1

    logging.info("--- Parsing ---")
    logging.info(f"[*] Apache lines:  {apache_count}")
    logging.info(f"[*] Syslog lines:  {sys_count}")
    logging.info(f"[*] Total parsed:  {total_count}")

    # Filtering
    filtered_entries = list(filter_logs(entries))

    logging.info("--- Filtering ---")
    logging.info(
        f"[*] Suspicious (404, 500): {len(filtered_entries)}"
    )

    # Enrichment
    known_ip_count = 0

    for entry in entries:
        enrich_ip(entry)

        if entry.country != "UNKNOWN":
            known_ip_count += 1

    logging.info("--- Enrichment ---")
    logging.info(
        f"[*] GeoIP: {len(entries)} entries enriched "
        f"({known_ip_count} known IPs)"
    )

if __name__ == "__main__":
    main()
