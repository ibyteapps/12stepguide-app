#!/usr/bin/env python3
"""Runs a command with a time limit and, if it fails or runs out of time, repeats the last lines
of its output as a GitHub Actions error annotation.

Like run_logged.sh, but for steps that can hang (on-device tests): a hung step would otherwise
be killed by the job timeout with nothing to read, because CI logs can't be downloaded here and
annotations only come from a step that finishes.

    python3 tool/ci/run_logged.py --timeout 1200 "iOS smoke test" flutter test ...
"""
from __future__ import annotations

import argparse
import collections
import os
import signal
import subprocess
import sys
import threading
import time

TAIL_LINES = 80


def escape(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, required=True, help="seconds")
    parser.add_argument("title")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    tail: collections.deque[str] = collections.deque(maxlen=TAIL_LINES)
    started = time.monotonic()
    proc = subprocess.Popen(
        args.command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,  # its own process group, so a time-out stops the whole tree
        text=True,
        errors="replace",
        bufsize=1,
    )

    def pump() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            elapsed = int(time.monotonic() - started)
            sys.stdout.write(line)
            sys.stdout.flush()
            tail.append(f"[{elapsed // 60:02d}:{elapsed % 60:02d}] {line.rstrip()}")

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()

    timed_out = False
    try:
        status = proc.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(proc.pid, sig)
            except ProcessLookupError:
                break
            try:
                proc.wait(timeout=15)
                break
            except subprocess.TimeoutExpired:
                continue
        status = 124
    # A helper that left the process group may still hold the pipe; don't wait for it for long.
    reader.join(timeout=10)

    if status != 0:
        why = f"timed out after {args.timeout} s" if timed_out else f"exit {status}"
        print(f"::error title={args.title} failed ({why})::{escape(chr(10).join(tail))}", flush=True)
    return status


if __name__ == "__main__":
    sys.exit(main())
