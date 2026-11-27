#!/usr/bin/env python3
import socket


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


if __name__ == "__main__":
    main()
