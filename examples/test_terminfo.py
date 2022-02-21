import json
import subprocess
import unittest

import pexpect


class TestTermInfoOutput(unittest.TestCase):
    def run_subprocess(self, names, vals, result):
        if not isinstance(names, list):
            names = [names]
            vals = [vals]
        assert len(names) == len(vals)
        env = {k: v for k, v in zip(names, vals)}
        res = subprocess.run(["./zig-out/bin/terminfo"], capture_output=True, env=env)
        self.assertEqual(res.returncode, 0)
        self.assertEqual(res.stderr, b"", res.stderr)

        out = json.loads(res.stdout)
        self.assertEqual(out, result, res.stderr)

    def test_tty(self):
        resp = pexpect.run("./zig-out/bin/terminfo", timeout=5)

        out = json.loads(resp)
        self.assertTrue(out["stdout_tty"])

    def test_empty(self):
        self.run_subprocess(
            [],
            [],
            {
                "stdout_tty": False,  # subprocess has no tty
                "no_color": False,
                "force_color": None,
                "suggested_color_mode": "none",
            },
        )

    def test_no_color(self):
        for val in ["", "1", "0", "true"]:
            with self.subTest(msg="Check NO_COLOR=val", val=val):
                self.run_subprocess(
                    "NO_COLOR",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": True,
                        "force_color": None,
                        "suggested_color_mode": "none",
                    },
                )

    def test_force_color_off(self):
        for val in ["0", "FALSE", "None", "false"]:
            with self.subTest(msg="Check FORCE_COLOR=val", val=val):
                self.run_subprocess(
                    "FORCE_COLOR",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": False,
                        "suggested_color_mode": "none",
                    },
                )

    def test_force_color_no(self):
        for val in ["", "1", "2", "3", "TRUE", "xxx"]:
            with self.subTest(msg="Check FORCE_COLOR=val", val=val):
                self.run_subprocess(
                    "FORCE_COLOR",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": True,
                        "suggested_color_mode": "none",
                    },
                )

    def test_win_term(self):
        for val in ["83bab73e-89c9-4e65-a342-e3994203b7ce", "2", "3", "TRUE", "xxx"]:
            with self.subTest(msg="Check WT_SESSION=val", val=val):
                self.run_subprocess(
                    "WT_SESSION",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_dom_term(self):
        for val in [
            "",
            "83bab73e-89c9-4e65-a342-e3994203b7ce",
            "2",
            "3",
            "TRUE",
            "xxx",
        ]:
            with self.subTest(msg="Check DOMTERM=val", val=val):
                self.run_subprocess(
                    "DOMTERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_kitty_term(self):
        for val in [
            "",
            "83bab73e-89c9-4e65-a342-e3994203b7ce",
            "2",
            "3",
            "TRUE",
            "xxx",
        ]:
            with self.subTest(msg="Check KITTY_WINDOW_ID=val", val=val):
                self.run_subprocess(
                    "DOMTERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_colorterm(self):
        for val in ["TRUECOLOR", "dirECt", "24bit", "24BITS"]:
            with self.subTest(msg="Check COLORTERM=val", val=val):
                self.run_subprocess(
                    "COLORTERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_rgb_termprogram(self):
        for val in ["hyper", "wezterm", "vscode"]:
            with self.subTest(msg="Check TERM_PROGRAM=val", val=val):
                self.run_subprocess(
                    "TERM_PROGRAM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_lookup_termprogram(self):
        for val in ["apple_terminal"]:
            with self.subTest(msg="Check TERM_PROGRAM=val", val=val):
                self.run_subprocess(
                    "TERM_PROGRAM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "lookup",
                    },
                )

    def test_iterm_lookup(self):
        for val in ["iTerm.app", "iTerm.app"]:
            with self.subTest(msg="Check TERM_PROGRAM=val", val=val):
                self.run_subprocess(
                    "TERM_PROGRAM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "lookup",
                    },
                )

    def test_iterm_rgb(self):
        for val in ["iTerm.app", "iTerm.app"]:
            for version in ["3.0.0", "4.2.3"]:
                with self.subTest(
                    msg="Check TERM_PROGRAM=val, TERM_PROGRAM=version",
                    val=val,
                    version=version,
                ):
                    self.run_subprocess(
                        ["TERM_PROGRAM", "TERM_PROGRAM_VERSION"],
                        [val, version],
                        {
                            "stdout_tty": False,  # subprocess has no tty
                            "no_color": False,
                            "force_color": None,
                            "suggested_color_mode": "rgb",
                        },
                    )

    def test_term_level_rgb(self):
        for val in ["xxx-24bit", "xxx-24BITS", "xxx-direct", "xxx-trueCOLOR"]:
            with self.subTest(msg="Check TERM=val", val=val):
                self.run_subprocess(
                    "TERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_term_level_lookup(self):
        for val in ["xxx-256", "xxx-256color", "xx-256cOLOrs"]:
            with self.subTest(msg="Check TERM=val", val=val):
                self.run_subprocess(
                    "TERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "lookup",
                    },
                )

    def test_term_term_rgb(self):
        for val in ["alacritty", "Alacritty"]:
            with self.subTest(msg="Check TERM=val", val=val):
                self.run_subprocess(
                    "TERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "rgb",
                    },
                )

    def test_term_term_lookup(self):
        for val in ["cygwin"]:
            with self.subTest(msg="Check TERM=val", val=val):
                self.run_subprocess(
                    "TERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "lookup",
                    },
                )

    def test_term_term_names(self):
        for val in [
            "xterm",
            "vt100-xxx",
            "vt220",
            "screen",
            "COLOR",
            "linux",
            "aNSi",
            "rxvt",
            "konsole",
        ]:
            with self.subTest(msg="Check TERM=val", val=val):
                self.run_subprocess(
                    "TERM",
                    val,
                    {
                        "stdout_tty": False,  # subprocess has no tty
                        "no_color": False,
                        "force_color": None,
                        "suggested_color_mode": "names",
                    },
                )

    def test_term_empty(self):

        self.run_subprocess(
            "TERM",
            "",
            {
                "stdout_tty": False,  # subprocess has no tty
                "no_color": False,
                "force_color": None,
                "suggested_color_mode": "none",
            },
        )


if __name__ == "__main__":
    unittest.main()
