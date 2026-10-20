"""Run the workflow shell with the real gh CLI against a local paginated API.

Only API reads reach gh; reminder comments are captured locally. No credentials
or GitHub writes are needed. Run: python3 -m unittest discover -s tests -v
"""
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
from urllib.parse import urlsplit


WORKFLOW = Path(__file__).resolve().parents[1] / '.github/workflows/remind-news.yml'


def workflow_script():
    lines = WORKFLOW.read_text().splitlines()
    runs = [(i, len(m.group(1))) for i, line in enumerate(lines)
            if (m := re.fullmatch(r'( *)run: \|', line))]
    if len(runs) != 1:
        raise AssertionError('Expected exactly one workflow shell block')
    start, indent = runs[0]
    body = []
    for line in lines[start + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        body.append(line[indent + 2:] if line.strip() else '')
    return '\n'.join(body) + '\n'


@unittest.skipUnless(shutil.which('gh'), 'The actual GitHub CLI is required')
class NewsWorkflow(unittest.TestCase):
    def execute(self, pages, failed_page=None):
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                index = int(urlsplit(self.path).path.rsplit('/', 1)[1])
                requests.append(index)
                if index == failed_page:
                    self.send_response(403)
                    self.end_headers()
                    self.wfile.write(b'{"message":"fixture API failure"}')
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                if index + 1 < len(pages):
                    self.send_header('Link', '<http://127.0.0.1:%d/page/%d>; rel="next"'
                                     % (self.server.server_port, index + 1))
                self.end_headers()
                self.wfile.write(json.dumps(pages[index]).encode())

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                wrapper = root / 'gh'
                wrapper.write_text('''#!/usr/bin/python3
import json, os, pathlib, subprocess, sys
root = pathlib.Path(os.environ['NEWS_TEST_DIRECTORY'])
args = sys.argv[1:]
with (root / 'calls.jsonl').open('a') as output:
    output.write(json.dumps(args) + '\\n')
if args and args[0] == 'api':
    endpoints = [i for i, value in enumerate(args) if value.startswith('repos/')]
    assert len(endpoints) == 1
    assert args[endpoints[0]] == 'repos/fixture/module/pulls/443/files?per_page=100'
    args[endpoints[0]] = os.environ['NEWS_TEST_API'] + '/page/0'
    sys.exit(subprocess.run([os.environ['NEWS_TEST_REAL_GH'], *args]).returncode)
if args[:2] == ['pr', 'comment']:
    assert args[2:5] == ['443', '--repo', 'fixture/module']
    sys.exit(0)
raise AssertionError('Unexpected workflow command')
''')
                wrapper.chmod(0o755)
                env = {'PATH': str(root) + ':/usr/bin:/bin', 'LANG': 'C.UTF-8',
                       'GH_TOKEN': 'local-fixture-token', 'GH_CONFIG_DIR': str(root / 'config'),
                       'XDG_STATE_HOME': str(root / 'state'), 'XDG_CACHE_HOME': str(root / 'cache'),
                       'XDG_DATA_HOME': str(root / 'data'),
                       'GH_REPO': 'fixture/module', 'PR_NUMBER': '443',
                       'NEWS_TEST_DIRECTORY': directory,
                       'NEWS_TEST_API': 'http://127.0.0.1:' + str(server.server_port),
                       'NEWS_TEST_REAL_GH': shutil.which('gh')}
                # Match the runner's bash -e shell; API failure propagation must
                # not depend on pipefail or a mock that accepts invalid flags.
                result = subprocess.run(['bash', '--noprofile', '--norc', '-e', '-c', workflow_script()],
                                        cwd=root, env=env, capture_output=True, text=True, timeout=20)
                calls = [json.loads(line) for line in (root / 'calls.jsonl').read_text().splitlines()]
                return result, calls, requests
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_news_on_first_page_still_reads_every_page(self):
        result, calls, requests = self.execute([[{'filename': 'NEWS.md'}], [{'filename': 'R/a.R'}]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests, [0, 1])
        self.assertEqual(len(calls), 1)

    def test_news_on_later_page(self):
        result, calls, requests = self.execute([[{'filename': 'R/a.R'}], [{'filename': 'NEWS.md'}]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests, [0, 1])
        self.assertEqual(len(calls), 1)

    def test_absent_news_posts_one_reminder(self):
        result, calls, requests = self.execute([[{'filename': 'R/a.R'}], [{'filename': 'tests/test.R'}]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests, [0, 1])
        self.assertEqual(len(calls), 2)
        self.assertIn('Friendly reminder', calls[1][-1])

    def test_exact_filename_and_shell_data(self):
        result, calls, requests = self.execute([[{'filename': name} for name in
                                                ['folder/NEWS.md', 'NEWS.md\ntrue', '$(exit 99)', '`exit 98`']]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests, [0])
        self.assertEqual(len(calls), 2)

    def test_initial_api_failure_posts_nothing(self):
        result, calls, requests = self.execute([[]], failed_page=0)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(requests, [0])
        self.assertEqual(len(calls), 1)

    def test_later_api_failure_cannot_be_hidden_by_an_earlier_match(self):
        result, calls, requests = self.execute([[{'filename': 'NEWS.md'}], []], failed_page=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(requests, [0, 1])
        self.assertEqual(len(calls), 1)

    def test_empty_list_posts_one_reminder(self):
        result, calls, requests = self.execute([[]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests, [0])
        self.assertEqual(len(calls), 2)


if __name__ == '__main__':
    unittest.main()
