#!/usr/bin/env python3
import socket
from concurrent.futures import ThreadPoolExecutor
import time


def guess_service(port: int) -> str:
    common_services = {
        20: "ftp-data",
        21: "ftp",
        22: "ssh",
        23: "telnet",
        25: "smtp",
        53: "dns",
        67: "dhcp",
        68: "dhcp",
        80: "http",
        110: "pop3",
        123: "ntp",
        143: "imap",
        161: "snmp",
        389: "ldap",
        443: "https",
        445: "smb",
        3306: "mysql",
        3389: "rdp",
        5432: "postgresql",
        6379: "redis",
        8080: "http-alt",
    }
    return common_services.get(port, "unknown")


def scan_one(ip, port):
    if check_port(ip, port):
        banner = get_banner(ip, port)
        service = guess_service(port) if banner == "Unknown" else banner
        print(f"[+] Port {port} Open: {banner}")
        return {"port": port, "service": service}


def scan_ports(ip, start_port, end_port):
    print(f"Scanning {ip} from {start_port} to {end_port}...")
    with ThreadPoolExecutor(max_workers=50) as ex:
        results = ex.map(
            lambda p: scan_one(ip, p), range(start_port, end_port + 1)
        )
        return [r for r in results if r]


def get_banner(ip: str, port: int) -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)

    try:
        sock.connect((ip, port))
        sock.sendall(b"HEAD / HTTP/1.0\r\n\r\n")

        banner = sock.recv(1024).decode(errors="ignore").strip()

        if not banner:
            return "Unknown"

        return banner

    except OSError:
        return "Unknown"

    finally:
        sock.close()


def ping_sweep(subnet: str) -> list:
    live_hosts = []

    for i in range(1, 255):
        ip = f"{subnet}.{i}"

        if check_port(ip, 80):
            live_hosts.append(ip)

    return live_hosts


def check_port(ip: str, port: int) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)

    try:
        sock.connect((ip, port))
        return True
    except (ConnectionRefusedError, socket.timeout, socket.gaierror, OSError):
        return False
    finally:
        sock.close()


def main():
    print("NetProbe v1.0 initialized...")
    print(f"Port 80 is open: {check_port('google.com', 80)}")
    print(f"Port 81 is open: {check_port('google.com', 81)}")
    print(ping_sweep("192.168.1"))
    print(get_banner("scanme.nmap.org", 22))
    start = time.time()
    results = scan_ports("192.168.1.1", 1, 1024)
    end = time.time()
    print(f"Scan completed in {end - start:.2f} seconds")


if __name__ == "__main__":
    main()
