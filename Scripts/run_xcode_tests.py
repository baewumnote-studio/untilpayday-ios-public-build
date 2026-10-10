#!/usr/bin/env python3
"""Preserve XCTest output and stop a stuck xcodebuild result finalizer honestly."""
import argparse
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument('--log', required=True)
parser.add_argument('--simulator', required=True)
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ['--'] else args.command
if not command or command[0] != 'xcodebuild':
    parser.error('An xcodebuild command is required')
log_path = Path(args.log)
events = queue.Queue()
started = time.monotonic()
completed_at = None
timed_out = False
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, bufsize=1, start_new_session=True)

def read_output():
    for line in process.stdout:
        events.put(line)
    events.put(None)

threading.Thread(target=read_output, daemon=True).start()
with log_path.open('w', encoding='utf-8') as log:
    while True:
        try:
            line = events.get(timeout=1)
        except queue.Empty:
            line = ''
        if line is None:
            break
        if line:
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)
            log.flush()
            if "Test Suite 'Selected tests'" in line and (' passed at ' in line or ' failed at ' in line):
                completed_at = time.monotonic()
        if process.poll() is not None and events.empty():
            break
        now = time.monotonic()
        if (completed_at is not None and now - completed_at > 120) or now - started > 1500:
            timed_out = True
            message = '\nVerification watchdog: xcodebuild did not finish; command result is TIMEOUT (124).\n'
            print(message, flush=True)
            log.write(message)
            log.flush()
            subprocess.run(['xcrun', 'simctl', 'io', args.simulator, 'screenshot',
                            str(log_path.with_name('simulator-after-ui-tests.png'))], timeout=30, check=False)
            for sig, grace in ((signal.SIGINT, 10), (signal.SIGTERM, 5), (signal.SIGKILL, 5)):
                try:
                    os.killpg(process.pid, sig)
                except ProcessLookupError:
                    break
                try:
                    process.wait(timeout=grace)
                    break
                except subprocess.TimeoutExpired:
                    continue
            break
status = 124 if timed_out else process.wait()
log_path.with_suffix('.command.json').write_text(json.dumps({
    'exit_code': status, 'timed_out': timed_out,
    'selected_suite_execution_completed': completed_at is not None,
    'elapsed_seconds': round(time.monotonic() - started, 1)
}, indent=2), encoding='utf-8')
raise SystemExit(status)
