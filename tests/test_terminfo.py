import json
import os
import pty
import subprocess
import tempfile
import unittest


class TestTermInfoOutput(unittest.TestCase):
    def test_tty(self):
        with tempfile.TemporaryFile() as fp:

            def read(fd):
                data = os.read(fd, 1024)
                fp.write(data)
                return data

            pty.spawn("./zig-out/bin/terminfo", read)

            fp.seek(0)
            out = json.loads(fp.read())
            assert out["stdout_tty"] is True

    def test_empty(self):
        res = subprocess.run(["./zig-out/bin/terminfo"], capture_output=True, env={})
        assert res.returncode == 0
        assert res.stderr == b"", res.stderr

        out = json.loads(res.stdout)
        assert out == {
            "stdout_tty": False,  # subprocess has no tty
            "no_color": False,
            "force_color": None,
            "suggested_color_mode": "none",
        }


if __name__ == "__main__":
    unittest.main()
