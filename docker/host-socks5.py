#!/usr/bin/env python3
"""Minimal SOCKS5 CONNECT proxy for local Docker -> Windows loopback."""
from __future__ import annotations

import select
import socket
import socketserver
import struct
import threading

HOST = "0.0.0.0"
PORT = 11080
BUF = 65536


def relay(a: socket.socket, b: socket.socket) -> None:
    sockets = [a, b]
    try:
        while True:
            r, _, x = select.select(sockets, [], sockets, 60)
            if x or not r:
                break
            for s in r:
                other = b if s is a else a
                data = s.recv(BUF)
                if not data:
                    return
                other.sendall(data)
    except OSError:
        return
    finally:
        for s in (a, b):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                s.close()
            except OSError:
                pass


class Socks5Handler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        sock = self.request
        try:
            header = sock.recv(2)
            if len(header) < 2 or header[0] != 5:
                return
            nmethods = header[1]
            sock.recv(nmethods)
            sock.sendall(b"\x05\x00")  # no auth

            req = sock.recv(4)
            if len(req) < 4 or req[0] != 5 or req[1] != 1:
                sock.sendall(b"\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00")
                return
            atyp = req[3]
            if atyp == 1:
                raw = sock.recv(4)
                if len(raw) < 4:
                    return
                host = socket.inet_ntoa(raw)
            elif atyp == 3:
                ln = sock.recv(1)
                if not ln:
                    return
                raw = sock.recv(ln[0])
                host = raw.decode("utf-8", "replace")
            elif atyp == 4:
                raw = sock.recv(16)
                if len(raw) < 16:
                    return
                host = socket.inet_ntop(socket.AF_INET6, raw)
            else:
                sock.sendall(b"\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00")
                return
            port_raw = sock.recv(2)
            if len(port_raw) < 2:
                return
            port = struct.unpack("!H", port_raw)[0]

            try:
                remote = socket.create_connection((host, port), timeout=10)
            except OSError:
                sock.sendall(b"\x05\x05\x00\x01\x00\x00\x00\x00\x00\x00")
                return

            sock.sendall(b"\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00")
            relay(sock, remote)
        except OSError:
            return


class ThreadedServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> None:
    with ThreadedServer((HOST, PORT), Socks5Handler) as server:
        print(f"[artex-host-socks5] listening on {HOST}:{PORT}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()