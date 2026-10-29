#!/usr/bin/env python3
"""Stdio session for the Cwhip language server."""

import argparse
import json
from pathlib import Path
import subprocess
import unittest


class LanguageServerTests(unittest.TestCase):
    def session(self):
        return subprocess.Popen(
            [str(self.args.server)], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def send(self, process, message):
        body = json.dumps(message).encode()
        process.stdin.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
        process.stdin.flush()

    def read(self, process):
        header = b""
        while b"\r\n\r\n" not in header:
            chunk = process.stdout.read(1)
            if not chunk:
                self.fail(f"server closed stdout: {header!r}")
            header += chunk
        length = int(header.split(b"Content-Length:")[1].split(b"\r\n")[0].strip())
        return json.loads(process.stdout.read(length))

    def test_publishes_each_recovered_diagnostic(self):
        process = self.session()
        try:
            self.send(process, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
            started = self.read(process)
            self.assertEqual(started["id"], 1)
            self.assertEqual(started["result"]["capabilities"]["textDocumentSync"], 1)
            self.send(process, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
            text = "start {\n int64 a = \"no\"\n int64 b = missing\n}\n"
            self.send(process, {
                "jsonrpc": "2.0",
                "method": "textDocument/didOpen",
                "params": {"textDocument": {
                    "uri": "file:///tmp/sample.cw",
                    "languageId": "cwhip",
                    "version": 1,
                    "text": text,
                }},
            })
            published = self.read(process)
            messages = [item["message"] for item in published["params"]["diagnostics"]]
            self.assertEqual(len(messages), 2)
            self.assertIn("cannot initialize int64 variable with String", messages)
            self.assertIn("undefined variable 'missing' or field", messages)
            self.assertEqual(published["params"]["diagnostics"][0]["range"]["start"]["line"], 1)
            self.send(process, {"jsonrpc": "2.0", "id": 2, "method": "shutdown"})
            self.assertIsNone(self.read(process)["result"])
            self.send(process, {"jsonrpc": "2.0", "method": "exit"})
            process.stdin.close()
            self.assertEqual(process.wait(timeout=5), 0)
        finally:
            if process.poll() is None:
                process.kill()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    LanguageServerTests.args, remaining = parser.parse_known_args()
    unittest.main(argv=[__import__("sys").argv[0], *remaining])
