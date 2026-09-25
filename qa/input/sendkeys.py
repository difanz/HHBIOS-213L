#!/usr/bin/env python3
"""Send a keys.txt sequence into DOSBox-X over the COM1 nullmodem socket.

Stock DOSBox-X has no host API that pokes IRQ1. The suite uses the built-in
nullmodem: DOSBox listens on 127.0.0.1, and this script is the TCP client.
qa/input/keysock.c, resident in the guest, reads COM1 and writes the BIOS
keyboard buffer (0040:001E). Programs that read port 60h directly will not
see these keys. A later backend can replace this file without changing
keys.txt.

keys.txt lines:
  # comment
  <delay_ms> <payload>
  <delay_ms>                  pause only

payload is literal text, a token (enter esc tab bksp space up down left
right), or sc:SSAA (scan and ascii as four hex digits).

Wire format, one event after another, no extra framing: byte 0 is the
scancode, byte 1 is the ASCII value (0 for extended keys).
"""
import socket
import sys
import time

TOKENS = {
    "enter": (0x1C, 0x0D),
    "esc": (0x01, 0x1B),
    "tab": (0x0F, 0x09),
    "bksp": (0x0E, 0x08),
    "space": (0x39, 0x20),
    "up": (0x48, 0x00),
    "down": (0x50, 0x00),
    "left": (0x4B, 0x00),
    "right": (0x4D, 0x00),
}

# Unshifted set-1 make codes for keys the demo and later prompts need.
SCAN = {
    "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06,
    "6": 0x07, "7": 0x08, "8": 0x09, "9": 0x0A, "0": 0x0B,
    "-": 0x0C, "=": 0x0D, "[": 0x1A, "]": 0x1B, ";": 0x27,
    "'": 0x28, "`": 0x29, "\\": 0x2B, ",": 0x33, ".": 0x34,
    "/": 0x35, " ": 0x39,
    "a": 0x1E, "b": 0x30, "c": 0x2E, "d": 0x20, "e": 0x12,
    "f": 0x21, "g": 0x22, "h": 0x23, "i": 0x17, "j": 0x24,
    "k": 0x25, "l": 0x26, "m": 0x32, "n": 0x31, "o": 0x18,
    "p": 0x19, "q": 0x10, "r": 0x13, "s": 0x1F, "t": 0x14,
    "u": 0x16, "v": 0x2F, "w": 0x11, "x": 0x2D, "y": 0x15,
    "z": 0x2C,
}


def events_for_payload(payload):
    if payload in TOKENS:
        return [TOKENS[payload]]
    if payload.startswith("sc:") and len(payload) == 7:
        raw = payload[3:]
        scan = int(raw[0:2], 16)
        ascii_b = int(raw[2:4], 16)
        return [(scan, ascii_b)]
    out = []
    for ch in payload:
        key = ch.lower()
        if key not in SCAN or ord(ch) > 0x7E:
            raise SystemExit("sendkeys: unsupported character %r" % ch)
        out.append((SCAN[key], ord(ch)))
    return out


def load_events(path):
    events = []
    for lineno, raw in enumerate(open(path, "r", encoding="ascii"), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        try:
            delay_ms = int(parts[0])
        except ValueError:
            raise SystemExit("sendkeys: %s:%d delay is not an integer" % (path, lineno))
        payload = parts[1] if len(parts) > 1 else ""
        ev = events_for_payload(payload) if payload else []
        events.append((delay_ms, ev))
    return events


def connect(host, port):
    last = None
    for _ in range(50):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.settimeout(2.0)
            sock.connect((host, port))
            return sock
        except OSError as exc:
            last = exc
            sock.close()
            time.sleep(0.2)
    raise SystemExit("sendkeys: connect %s:%d failed: %s" % (host, port, last))


def main(argv):
    host = "127.0.0.1"
    port = None
    keys = None
    i = 1
    while i < len(argv):
        if argv[i] == "--host":
            host = argv[i + 1]
            i += 2
        elif argv[i] == "--port":
            port = int(argv[i + 1])
            i += 2
        elif argv[i] == "--keys":
            keys = argv[i + 1]
            i += 2
        else:
            raise SystemExit("usage: sendkeys.py --port N --keys keys.txt")
    if port is None or keys is None:
        raise SystemExit("usage: sendkeys.py --port N --keys keys.txt")
    events = load_events(keys)
    sock = connect(host, port)
    try:
        for delay_ms, ev in events:
            if delay_ms:
                time.sleep(delay_ms / 1000.0)
            buf = bytearray()
            for scan, ascii_b in ev:
                buf.append(scan & 0xFF)
                buf.append(ascii_b & 0xFF)
            if buf:
                sock.sendall(buf)
    finally:
        sock.close()


if __name__ == "__main__":
    main(sys.argv)
