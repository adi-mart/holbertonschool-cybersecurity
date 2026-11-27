#!/usr/bin/env python3
import argparse
import json
import logging
from collections import Counter, defaultdict, deque
from datetime import datetime
import multiprocessing
import re
from dataclasses import asdict, dataclass


@dataclass
class LogEntry:
    ip: str
    timestamp: str
    message: str
    raw_line: str
    service: str = ""
    source: str = ""

    method: str = None
    path: str = None
    status: int = None
    size: int = None
    user_agent: str = None
    country: str = "UNKNOWN"
    is_bot: bool = False
    alert_level: str = "LOW"
    attack_type: str = None


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
    r'(?: "(?P<referer>[^"]*)" "(?P<user_agent>[^"]*)")?'
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


BOT_SIGNATURES = ("sqlmap", "nikto", "curl", "python")
BLACKLIST = {'10.0.0.1', '192.168.1.66'}

SQLI_SIGNATURES = [
    re.compile(r"union\s+select", re.IGNORECASE),
    re.compile(r"('|%27)\s*or\s*1\s*=\s*1", re.IGNORECASE),
    re.compile(r"--"),
    re.compile(r"/\*|\*/"),
    re.compile(r"\bdrop\s+table\b", re.IGNORECASE),
]

XSS_SIGNATURES = [
    re.compile(r"<\s*script", re.IGNORECASE),
    re.compile(r"javascript\s*:", re.IGNORECASE),
    re.compile(r"onload\s*=", re.IGNORECASE),
    re.compile(r"onerror\s*=", re.IGNORECASE),
    re.compile(r"<\s*img[^>]+onerror\s*=", re.IGNORECASE),
]


def check_threat_intel(log_entry):
    if log_entry.ip in BLACKLIST:
        log_entry.alert_level = 'HIGH'
    else:
        log_entry.alert_level = 'LOW'


def analyze_user_agent(log_entry):
    log_entry.is_bot = False

    for field in ("user_agent", "message", "raw_line"):
        value = getattr(log_entry, field, None)
        if value and any(sig in value.lower() for sig in BOT_SIGNATURES):
            log_entry.is_bot = True
            break


def enrich_ip(log_entry):
    log_entry.country = GEOIP_DB.get(log_entry.ip, "UNKNOWN")
    return log_entry


def detect_sqli(log_entry):
    haystacks = [log_entry.path or "", log_entry.message or ""]

    if any(sig.search(hay) for hay in haystacks for sig in SQLI_SIGNATURES):
        log_entry.attack_type = 'SQLi'


def detect_xss(log_entry):
    if log_entry.attack_type == 'SQLi':
        return

    path = log_entry.path or ""
    if any(sig.search(path) for sig in XSS_SIGNATURES):
        log_entry.attack_type = 'XSS'


def detect_bruteforce(entries):
    failures_by_ip = Counter()

    for entry in entries:
        if not entry.ip:
            continue

        status_value = str(getattr(entry, 'status', '')).strip()
        message_value = (getattr(entry, 'message', '') or "").lower()

        http_fail = status_value == '401'
        ssh_fail = 'failed password' in message_value

        if http_fail or ssh_fail:
            failures_by_ip[entry.ip] += 1

    for ip, count in sorted(
        failures_by_ip.items(), key=lambda item: (-item[1], item[0])
    ):
        if count > 5:
            yield {'ip': ip, 'count': count, 'alert_type': 'BRUTE_FORCE'}


def parse_timestamp(timestamp):
    if not timestamp:
        return None

    try:
        return datetime.strptime(timestamp, "%d/%b/%Y:%H:%M:%S %z").timestamp()
    except ValueError:
        pass

    try:
        now = datetime.now()
        parsed = datetime.strptime(timestamp, "%b %d %H:%M:%S")
        parsed = parsed.replace(year=now.year)
        return parsed.timestamp()
    except ValueError:
        return None


def detect_burst(entries, window_seconds=60, threshold=10):
    per_ip_windows = defaultdict(deque)
    alerted_ips = set()

    stamped_entries = []
    for index, entry in enumerate(entries):
        ts = parse_timestamp(entry.timestamp)
        if ts is not None and entry.ip:
            stamped_entries.append((ts, index, entry))

    ordered_entries = sorted(
        stamped_entries,
        key=lambda item: (item[0], item[1])
    )

    for ts, _, entry in ordered_entries:
        window = per_ip_windows[entry.ip]
        window.append(ts)

        while window and ts - window[0] > window_seconds:
            window.popleft()

        if len(window) >= threshold and entry.ip not in alerted_ips:
            alerted_ips.add(entry.ip)
            yield {
                'ip': entry.ip,
                'count': len(window),
                'window': window_seconds,
                'alert_type': 'BURST'
            }


def correlate_events(entries):
    state_by_ip = defaultdict(set)

    for entry in entries:
        ip = getattr(entry, 'ip', '')
        if not ip:
            continue

        status_value = str(getattr(entry, 'status', '')).strip()
        if status_value == '404':
            state_by_ip[ip].add('scanner')

        attack_type = getattr(entry, 'attack_type', None)
        if attack_type is None:
            attack_type = getattr(entry, 'attacktype', None)

        attack_value = (str(attack_type).strip().lower() if attack_type
                        else "")
        if attack_value == 'sqli':
            state_by_ip[ip].add('sqli')

        if {'scanner', 'sqli'}.issubset(state_by_ip[ip]):
            yield {
                'ip': ip,
                'stages': ['scanner', 'sqli'],
                'alert_type': 'CRITICAL INCIDENT'
            }
            state_by_ip[ip].clear()


def export_report(alerts, filename, format='json'):
    if format.lower() != 'json':
        raise ValueError("Only JSON export is supported")

    serializable = []
    for alert in alerts:
        if isinstance(alert, LogEntry):
            serializable.append(asdict(alert))
        elif isinstance(alert, dict):
            serializable.append(alert)
        else:
            serializable.append({'value': str(alert)})

    with open(filename, 'w') as handle:
        json.dump(serializable, handle, indent=2)


def process_line(line):
    parsed = parse_apache_line(line)

    if parsed:
        normalized = normalize_entry(parsed, "apache", line)
        return normalized

    parsed = parse_syslog_line(line)

    if parsed:
        normalized = normalize_entry(parsed, "syslog", line)
        return normalized

    return None


def process_chunk(lines):
    results = []

    for line in lines:
        entry = process_line(line)
        if not entry:
            continue

        enrich_ip(entry)
        analyze_user_agent(entry)
        check_threat_intel(entry)
        detect_sqli(entry)
        detect_xss(entry)
        results.append(entry)

    return results


def parallel_analyze(file_path, num_workers, chunk_size):
    chunks = []
    current_chunk = []

    for line in read_stream(file_path):
        current_chunk.append(line)

        if len(current_chunk) >= chunk_size:
            chunks.append(current_chunk)
            current_chunk = []

    if current_chunk:
        chunks.append(current_chunk)

    if not chunks:
        return []

    with multiprocessing.Pool(processes=num_workers) as pool:
        mapped = pool.map(process_chunk, chunks)

    return [entry for chunk_entries in mapped for entry in chunk_entries]


def normalize_entry(parsed_dict, log_type, raw_line='') -> LogEntry:

    if log_type == "apache":
        return LogEntry(
            ip=parsed_dict["ip"],
            timestamp=parsed_dict["date"],
            service="http",
            source="apache",
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
            source="syslog",
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
    parser.add_argument('--report')
    parser.add_argument('--workers', type=int, default=0)
    parser.add_argument('--chunk-size', type=int, default=1000)
    args = parser.parse_args()

    logging.info("[*] LogHunter - Log Analysis Engine")
    if args.workers > 0:
        logging.info(
            f"[*] Reading: {args.file} "
            f"(parallel: {args.workers} workers)"
        )
        entries = parallel_analyze(args.file, args.workers, args.chunk_size)
    else:
        logging.info(f"[*] Reading: {args.file}")
        lines = list(read_stream(args.file))
        entries = process_chunk(lines)

    apache_count = sum(1 for entry in entries if entry.source == 'apache')
    sys_count = sum(1 for entry in entries if entry.source == 'syslog')
    total_count = len(entries)

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
    known_ip_count = sum(1 for entry in entries if entry.country != "UNKNOWN")
    bot_count = sum(1 for entry in entries if entry.is_bot)

    logging.info("--- Enrichment ---")
    logging.info(
        f"[*] GeoIP: {len(entries)} entries enriched "
        f"({known_ip_count} known IPs)"
    )
    logging.info(f"[*] Bots detected: {bot_count}")

    # Threat Intelligence
    high_count = sum(1 for entry in entries if entry.alert_level == 'HIGH')

    logging.info("--- Threat Intelligence ---")
    logging.info(
        f"[*] HIGH alerts: {high_count} entries from blacklisted IPs"
    )

    # Attack Detection
    sqli_count = 0
    xss_count = 0

    for entry in entries:
        if entry.attack_type == 'SQLi':
            sqli_count += 1
        elif entry.attack_type == 'XSS':
            xss_count += 1

    logging.info("--- Attack Detection ---")
    logging.info(f"[*] SQLi attempts: {sqli_count}")
    logging.info(f"[*] XSS attempts:  {xss_count}")

    # Brute Force
    brute_force_alerts = list(detect_bruteforce(entries))

    logging.info("--- Brute Force ---")
    logging.info(f"[*] BRUTE_FORCE alerts: {len(brute_force_alerts)}")
    for alert in brute_force_alerts:
        logging.info(f"    {alert['ip']}: {alert['count']} failures")

    # Burst Detection
    burst_alerts = list(detect_burst(entries, window_seconds=60, threshold=10))

    logging.info("--- Burst Detection ---")
    logging.info(f"[*] BURST alerts: {len(burst_alerts)}")
    for alert in burst_alerts:
        logging.info(
            f"    {alert['ip']}: {alert['count']} requests in "
            f"{alert['window']}s window"
        )

    # Correlation
    correlation_alerts = list(correlate_events(entries))

    logging.info("--- Correlation ---")
    if correlation_alerts:
        logging.info("[*] CRITICAL INCIDENTS:")
        for alert in correlation_alerts:
            logging.info(
                f"    {alert['ip']}: "
                f"{' -> '.join(alert['stages'])}"
            )
    else:
        logging.info("[*] CRITICAL INCIDENTS: none")

    all_alerts = brute_force_alerts + burst_alerts + correlation_alerts

    if args.report:
        export_report(all_alerts, args.report, format='json')
        logging.info(
            f"[*] Report exported: {args.report} ({len(all_alerts)} alerts)"
        )
    else:
        logging.info(f"[*] Total alerts: {len(all_alerts)}")
        logging.info("[*] Use --report <file> to export.")


if __name__ == "__main__":
    main()
