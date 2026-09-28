"""LAN discovery handshake: how the Flutter app finds the backend with no setup.

The backend always serves on BACKEND_PORT (TCP, HTTPS in the packaged build). It also
listens for UDP on that same port number: a client broadcasts DISCOVERY_REQUEST, and every
backend that hears it replies directly to the sender with the details needed to connect —
the pairing token and TLS certificate fingerprint. The client takes the host from the
reply's source address, so nothing about the host, port, token or certificate is ever typed
or scanned.

This deliberately trusts the whole LAN: any device that sends the request gets the token.
"""

from __future__ import annotations

import json
import socket
import threading

BACKEND_PORT = 8765
DISCOVERY_REQUEST = b"MSR-DISCOVER-1"
SERVICE_NAME = "medical-staff-review"


def build_discovery_reply(token: str | None, cert_fingerprint: str | None) -> bytes:
    """The UDP payload sent back to a discovering client. Both fields are None for a dev
    backend, which serves plain HTTP with no pairing token."""
    return json.dumps(
        {"service": SERVICE_NAME, "token": token, "cert_fingerprint": cert_fingerprint}
    ).encode("utf-8")


def handle_datagram(data: bytes, reply: bytes) -> bytes | None:
    """Returns the reply to send for an incoming datagram, or None to ignore it."""
    if data.strip() == DISCOVERY_REQUEST:
        return reply
    return None


def serve_discovery(sock: socket.socket, reply: bytes) -> None:
    """Answers discovery requests on an already-bound UDP socket until it's closed."""
    while True:
        try:
            data, sender = sock.recvfrom(1024)
        except ConnectionResetError:
            # Windows surfaces an ICMP "port unreachable" for an earlier reply (the client
            # had already gone) as an error on the next recvfrom — not fatal, keep serving.
            continue
        except OSError:
            return  # socket closed
        response = handle_datagram(data, reply)
        if response is not None:
            try:
                sock.sendto(response, sender)
            except OSError:
                continue


def start_discovery_responder(
    token: str | None, cert_fingerprint: str | None, port: int = BACKEND_PORT
) -> socket.socket:
    """Binds the UDP responder and serves it on a daemon thread; returns the socket so the
    caller (or a test) can close it to stop the thread."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", port))  # noqa: S104  — must hear LAN broadcasts, not just loopback
    reply = build_discovery_reply(token, cert_fingerprint)
    threading.Thread(target=serve_discovery, args=(sock, reply), daemon=True).start()
    return sock
