"""Covers the LAN discovery handshake in app.discovery, including a real UDP round trip on
loopback (ephemeral port, so it never collides with a running backend on BACKEND_PORT)."""

import json
import socket
from collections.abc import Generator

import pytest

from app.discovery import (
    DISCOVERY_REQUEST,
    SERVICE_NAME,
    build_discovery_reply,
    handle_datagram,
    start_discovery_responder,
)


def test_reply_carries_service_token_and_fingerprint() -> None:
    reply = json.loads(build_discovery_reply("tok", "ab" * 32))

    assert reply == {"service": SERVICE_NAME, "token": "tok", "cert_fingerprint": "ab" * 32}


def test_dev_reply_has_no_token_or_fingerprint() -> None:
    reply = json.loads(build_discovery_reply(None, None))

    assert reply["token"] is None
    assert reply["cert_fingerprint"] is None


def test_handle_datagram_answers_only_the_discovery_request() -> None:
    assert handle_datagram(DISCOVERY_REQUEST, b"reply") == b"reply"
    assert handle_datagram(DISCOVERY_REQUEST + b"\n", b"reply") == b"reply"
    assert handle_datagram(b"something else", b"reply") is None


@pytest.fixture
def responder_port() -> Generator[int]:
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    probe.bind(("127.0.0.1", 0))
    port = int(probe.getsockname()[1])
    probe.close()
    sock = start_discovery_responder("tok", "cd" * 32, port=port)
    yield port
    sock.close()


def test_responder_replies_to_a_discovery_request_over_udp(responder_port: int) -> None:
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.settimeout(2)
    try:
        client.sendto(DISCOVERY_REQUEST, ("127.0.0.1", responder_port))
        data, _ = client.recvfrom(1024)
    finally:
        client.close()

    assert json.loads(data) == {
        "service": SERVICE_NAME,
        "token": "tok",
        "cert_fingerprint": "cd" * 32,
    }


def test_responder_ignores_unrelated_datagrams(responder_port: int) -> None:
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.settimeout(0.3)
    try:
        client.sendto(b"hello", ("127.0.0.1", responder_port))
        with pytest.raises(TimeoutError):
            client.recvfrom(1024)
    finally:
        client.close()
