#!/usr/bin/env python3
import socket


def scan_ports(ip: str, start_port: int, end_port: int) -> list:
    results = []

    print(f"Scanning {ip} from {start_port} to {end_port}...")

    for port in range(start_port, end_port + 1):
        if check_port(ip, port):
            banner = get_banner(ip, port)

            result = {
                "port": port,
                "service": banner
            }

            results.append(result)
            print(f"[+] Port {port} Open: {banner}")

    return results



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
    print(scan_ports("192.168.1.1", 20, 80))


if __name__ == "__main__":
    main()
