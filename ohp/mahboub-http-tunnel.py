#!/usr/bin/env python3
# MAHBOUB PROXY - HTTP TUNNEL
import argparse
import socket
import threading
import select
import sys
import time

BUFLEN = 16384
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:22'
DEFAULT_PORT = 80
PASS = ''

RESET = '\033[0m'
BOLD = '\033[1m'
CYAN = '\033[96m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
MAGENTA = '\033[95m'
BLUE = '\033[94m'
RED = '\033[91m'

def banner():
    print(CYAN + '╔══════════════════════════════════════════════════════════════╗' + RESET)
    print(MAGENTA + '║                    MAHBOUB PROXY                            ║' + RESET)
    print(BLUE    + '║                     HTTP TUNNEL                             ║' + RESET)
    print(GREEN   + '║              Fast • Stable • Secure                         ║' + RESET)
    print(CYAN + '╚══════════════════════════════════════════════════════════════╝' + RESET)
    print()

class Server(threading.Thread):
    def __init__(self, host, port):
        super().__init__(daemon=True)
        self.running = False
        self.host = host
        self.port = int(port)
        self.threads = []
        self.threads_lock = threading.Lock()
        self.log_lock = threading.Lock()
        self.soc = None

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(128)
        self.running = True
        self.print_log('Listening on %s:%s' % (self.host, self.port))
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.settimeout(TIMEOUT)
                except socket.timeout:
                    continue
                except OSError:
                    break
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.add_conn(conn)
        finally:
            self.running = False
            try:
                self.soc.close()
            except Exception:
                pass

    def print_log(self, log):
        with self.log_lock:
            print(log, flush=True)

    def add_conn(self, conn):
        with self.threads_lock:
            if self.running:
                self.threads.append(conn)

    def remove_conn(self, conn):
        with self.threads_lock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        try:
            self.soc.close()
        except Exception:
            pass
        with self.threads_lock:
            threads = list(self.threads)
        for c in threads:
            c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, soc_client, server, addr):
        super().__init__(daemon=True)
        self.client_closed = False
        self.target_closed = True
        self.client = soc_client
        self.server = server
        self.addr = addr
        self.target = None
        self.log = 'Connection: ' + str(addr)

    def close(self):
        try:
            if not self.client_closed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except Exception:
            pass
        self.client_closed = True
        try:
            if not self.target_closed and self.target:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except Exception:
            pass
        self.target_closed = True

    def run(self):
        try:
            data = self.client.recv(BUFLEN)
            if not data:
                return
            host_port = self.find_header(data, 'X-Real-Host') or DEFAULT_HOST
            split = self.find_header(data, 'X-Split')
            if split:
                try:
                    self.client.recv(BUFLEN)
                except Exception:
                    pass

            passwd = self.find_header(data, 'X-Pass')
            if PASS:
                if passwd != PASS:
                    self.client.sendall(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                    return
            elif not (host_port.startswith('127.0.0.1') or host_port.startswith('localhost')):
                self.client.sendall(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
                return

            self.method_connect(host_port)
        except Exception as exc:
            self.log += ' - error: ' + str(exc)
            self.server.print_log(self.log)
        finally:
            self.close()
            self.server.remove_conn(self)

    @staticmethod
    def find_header(head, header):
        try:
            text = head.decode('iso-8859-1', 'ignore')
        except AttributeError:
            text = head
        prefix = header.lower() + ':'
        for line in text.split('\r\n'):
            if line.lower().startswith(prefix):
                return line.split(':', 1)[1].strip()
        return ''

    def connect_target(self, host):
        if ':' in host:
            hostname, port_text = host.rsplit(':', 1)
            port = int(port_text)
        else:
            hostname, port = host, 22
        infos = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
        if not infos:
            raise OSError('Unable to resolve target')
        family, socktype, proto, _, address = infos[0]
        self.target = socket.socket(family, socktype, proto)
        self.target.settimeout(TIMEOUT)
        self.target.connect(address)
        self.target_closed = False

    def method_connect(self, path):
        self.log += ' - CONNECT ' + path
        self.connect_target(path)
        self.client.sendall(
            b'HTTP/1.1 200 Connection established\r\n'
            b'Content-length: 0\r\n\r\n'
        )
        self.server.print_log(self.log)
        self.do_connect()

    def do_connect(self):
        sockets = [self.client, self.target]
        idle = 0
        while True:
            readable, _, errors = select.select(sockets, [], sockets, 1)
            if errors:
                break
            if not readable:
                idle += 1
                if idle >= TIMEOUT:
                    break
                continue
            idle = 0
            for source in readable:
                data = source.recv(BUFLEN)
                if not data:
                    return
                destination = self.target if source is self.client else self.client
                destination.sendall(data)

def parse_args():
    parser = argparse.ArgumentParser(description='MAHBOUB PROXY HTTP TUNNEL')
    parser.add_argument('-b', '--bind', default='0.0.0.0')
    parser.add_argument('-p', '--port', type=int, default=DEFAULT_PORT)
    return parser.parse_args()

def main():
    args = parse_args()
    banner()
    print('%sListening addr:%s %s%s' % (CYAN, RESET, args.bind, RESET))
    print('%sListening port:%s %s%s' % (CYAN, RESET, args.port, RESET))
    server = Server(args.bind, args.port)
    server.start()
    try:
        while server.is_alive():
            time.sleep(2)
    except KeyboardInterrupt:
        print(YELLOW + 'Stopping...' + RESET)
        server.close()

if __name__ == '__main__':
    main()
