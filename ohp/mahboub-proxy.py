#!/usr/bin/env python3
"""
MAHBOUB PROXY PREMIUM
Python 3 HTTP proxy for local/OHP integration.

Default listener: 127.0.0.1:8484

Supports:
- HTTP absolute-form requests
- HTTP CONNECT tunnelling
- threaded clients
- connection/request timeouts
- optional destination allow-list

Security:
Do not expose an unrestricted CONNECT proxy to the public Internet.
Use --bind 127.0.0.1 unless remote access is intentionally required.
"""

import argparse
import ipaddress
import select
import socket
import socketserver
import sys
import time
from http.client import HTTPConnection
from urllib.parse import urlsplit

VERSION = "1.0.0"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8484
BUFFER = 64 * 1024
DEFAULT_TIMEOUT = 30
TUNNEL_TIMEOUT = 300

RESET = "\033[0m"
BOLD = "\033[1m"
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
MAGENTA = "\033[95m"
BLUE = "\033[94m"
RED = "\033[91m"

def banner():
    lines = [
        "╔══════════════════════════════════════════════════════════════╗",
        "║              MAHBOUB PROXY • PREMIUM                       ║",
        "║            Fast • Stable • HTTP / CONNECT                  ║",
        "╠══════════════════════════════════════════════════════════════╣",
        "║  [01] HTTP Proxy                                            ║",
        "║  [02] CONNECT Tunnel                                        ║",
        "║  [03] OHP-compatible upstream proxy                        ║",
        "║  [04] Python 3 • Threaded                                   ║",
        "╚══════════════════════════════════════════════════════════════╝",
    ]
    colors = [CYAN, MAGENTA, BLUE, GREEN, YELLOW, CYAN, MAGENTA, GREEN, BLUE, CYAN]
    for i, line in enumerate(lines):
        print(colors[i % len(colors)] + line + RESET)
    print()

def info(msg):
    print(f"{GREEN}[+]{RESET} {msg}")

def warn(msg):
    print(f"{YELLOW}[!]{RESET} {msg}")

def error(msg):
    print(f"{RED}[-]{RESET} {msg}")

class DestinationPolicy:
    def __init__(self, values=None):
        self.rules = []
        for raw in values or []:
            for item in raw.split(","):
                item = item.strip()
                if not item:
                    continue
                try:
                    self.rules.append(ipaddress.ip_network(item, strict=False))
                except ValueError:
                    self.rules.append(item.lower())

    def allowed(self, host):
        if not self.rules:
            return True
        host = host.lower().rstrip(".")
        try:
            ip = ipaddress.ip_address(host)
        except ValueError:
            return any(rule == host for rule in self.rules
                       if isinstance(rule, str))
        return any(ip in rule for rule in self.rules
                   if not isinstance(rule, str))

class ProxyHandler(socketserver.StreamRequestHandler):
    timeout = DEFAULT_TIMEOUT
    policy = DestinationPolicy()

    def setup(self):
        super().setup()
        self.connection.settimeout(self.timeout)

    def handle(self):
        try:
            while True:
                request_line = self.rfile.readline(65536)
                if not request_line:
                    return
                if request_line in (b"\r\n", b"\n"):
                    continue

                try:
                    method, target, version = request_line.decode(
                        "iso-8859-1").strip().split(None, 2)
                except ValueError:
                    self.send_error(400, "Bad request line")
                    return

                headers = self.read_headers()
                if headers is None:
                    return

                if method.upper() == "CONNECT":
                    self.handle_connect(target)
                    return

                self.handle_http(method.upper(), target, headers)
                if headers.get("connection", "").lower() == "close":
                    return

        except (socket.timeout, ConnectionError, BrokenPipeError):
            return
        except Exception as exc:
            error(f"client {self.client_address[0]}: {exc}")

    def read_headers(self):
        headers = {}
        total = 0
        while True:
            line = self.rfile.readline(65536)
            if not line:
                return None
            total += len(line)
            if total > 128 * 1024:
                self.send_error(431, "Request headers too large")
                return None
            if line in (b"\r\n", b"\n"):
                break
            try:
                text = line.decode("iso-8859-1")
            except UnicodeDecodeError:
                self.send_error(400, "Invalid headers")
                return None
            if ":" not in text:
                self.send_error(400, "Malformed header")
                return None
            key, value = text.split(":", 1)
            headers[key.strip().lower()] = value.strip()
        return headers

    def send_error(self, code, message):
        body = f"{code} {message}\r\n".encode()
        response = (
            f"HTTP/1.1 {code} {message}\r\n"
            f"Content-Length: {len(body)}\r\n"
            "Connection: close\r\n"
            "Content-Type: text/plain; charset=utf-8\r\n"
            "\r\n"
        ).encode() + body
        try:
            self.wfile.write(response)
            self.wfile.flush()
        except OSError:
            pass

    def parse_destination(self, target, default_port):
        if "://" in target:
            u = urlsplit(target)
            if not u.hostname:
                raise ValueError("missing host")
            return u.hostname, u.port or default_port, u

        if target.startswith("["):
            end = target.find("]")
            if end < 0:
                raise ValueError("invalid IPv6 address")
            host = target[1:end]
            rest = target[end + 1:]
            port = int(rest[1:]) if rest.startswith(":") else default_port
            return host, port, None

        if ":" in target:
            host, port_s = target.rsplit(":", 1)
            return host, int(port_s), None

        return target, default_port, None

    def check_destination(self, host):
        if not self.policy.allowed(host):
            raise PermissionError(f"destination not allowed: {host}")

    def handle_connect(self, target):
        try:
            host, port, _ = self.parse_destination(target, 443)
            self.check_destination(host)
            upstream = socket.create_connection((host, port),
                                                timeout=self.timeout)
            upstream.settimeout(self.timeout)
        except PermissionError as exc:
            self.send_error(403, str(exc))
            return
        except (OSError, ValueError) as exc:
            self.send_error(502, f"CONNECT failed: {exc}")
            return

        try:
            self.wfile.write(
                b"HTTP/1.1 200 Connection Established\r\n"
                b"Connection: close\r\n\r\n")
            self.wfile.flush()

            peer = self.connection
            sockets = [peer, upstream]
            deadline = time.monotonic() + TUNNEL_TIMEOUT

            while time.monotonic() < deadline:
                readable, _, exceptional = select.select(
                    sockets, [], sockets, 5)
                if exceptional:
                    break
                for source in readable:
                    destination = upstream if source is peer else peer
                    data = source.recv(BUFFER)
                    if not data:
                        return
                    destination.sendall(data)
        finally:
            try:
                upstream.close()
            except OSError:
                pass

    def handle_http(self, method, target, headers):
        try:
            host, port, uri = self.parse_destination(target, 80)

            if uri is None:
                host_header = headers.get("host")
                if not host_header:
                    self.send_error(400, "Host header required")
                    return
                host, port, _ = self.parse_destination(host_header, 80)
                path = target or "/"
            else:
                if uri.scheme.lower() != "http":
                    self.send_error(400, "Use CONNECT for HTTPS")
                    return
                path = uri.path or "/"
                if uri.query:
                    path += "?" + uri.query

            self.check_destination(host)

            body = b""
            content_length = int(headers.get("content-length", "0") or "0")
            if content_length:
                if content_length > 16 * 1024 * 1024:
                    self.send_error(413, "Request body too large")
                    return
                body = self.rfile.read(content_length)

            hop = {
                "proxy-connection", "proxy-authorization",
                "proxy-authenticate", "connection", "keep-alive",
                "te", "trailer", "transfer-encoding", "upgrade"
            }
            upstream_headers = {
                k: v for k, v in headers.items() if k not in hop
            }
            upstream_headers["Host"] = host if port == 80 else f"{host}:{port}"
            upstream_headers["Connection"] = "close"

            conn = HTTPConnection(host, port, timeout=self.timeout)
            conn.request(method, path, body=body or None,
                         headers=upstream_headers)
            response = conn.getresponse()
            data = response.read()

            self.wfile.write(
                f"HTTP/1.1 {response.status} {response.reason}\r\n"
                .encode("iso-8859-1"))

            for key, value in response.getheaders():
                if key.lower() in hop:
                    continue
                self.wfile.write(
                    f"{key}: {value}\r\n".encode("iso-8859-1"))

            self.wfile.write(
                f"Content-Length: {len(data)}\r\n"
                "Connection: close\r\n\r\n".encode())

            if method != "HEAD":
                self.wfile.write(data)
            self.wfile.flush()
            conn.close()

        except PermissionError as exc:
            self.send_error(403, str(exc))
        except (OSError, ValueError) as exc:
            self.send_error(502, f"Upstream request failed: {exc}")

class ThreadedProxyServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

def main():
    parser = argparse.ArgumentParser(
        description="MAHBOUB PROXY - Python 3 HTTP/CONNECT proxy")
    parser.add_argument("--bind", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--allow", action="append",
        help="optional destination allow-list; repeat or use comma-separated values")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    args = parser.parse_args()

    ProxyHandler.timeout = max(1, args.timeout)
    ProxyHandler.policy = DestinationPolicy(args.allow)

    banner()

    try:
        server = ThreadedProxyServer((args.bind, args.port), ProxyHandler)
    except OSError as exc:
        error(f"cannot bind {args.bind}:{args.port}: {exc}")
        sys.exit(1)

    info(f"Listening on {args.bind}:{args.port}")
    info("HTTP + CONNECT support enabled")

    if args.allow:
        info("Destination allow-list enabled")
    else:
        warn("No destination allow-list: keep the proxy private")

    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        print()
        warn("Stopping proxy...")
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
