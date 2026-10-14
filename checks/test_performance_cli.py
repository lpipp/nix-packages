"""Test installed query CLIs against files; no host sysfs or firmware access."""
import pathlib
import subprocess
import sys
import tempfile


package, shell, cat = sys.argv[1:]
base = "/sys/bus/platform/devices/huawei-wmi/hunter"
cases = {"hunter-mode": [b"0\n", b"1\n", b"2\n"],
         "hunter-fans": [b"0 0\n", b"1962 1969\n"]}

with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    for command, values in cases.items():
        installed = pathlib.Path(package, "bin", command)
        text = installed.read_text()
        node = command.removeprefix("hunter-")
        assert text.startswith(f"#!{shell}\n"), text
        assert f"exec {cat} {base}/{node}\n" in text, text
        assert installed.stat().st_mode & 0o111
        # Only replace the fixed sysfs path in a test copy of the installed CLI.
        script = root / command
        script.write_text(text.replace(base, str(root)))
        script.chmod(0o755)
        fixture = root / node

        def run(*args):
            return subprocess.run([str(script), *args], capture_output=True,
                                  env={"PATH": "/no-such-path", "LC_ALL": "C"})

        for value in values:
            fixture.write_bytes(value)
            result = run()
            assert (result.returncode, result.stdout, result.stderr) == (0, value, b""), result
        fixture.unlink()
        result = run()
        assert result.returncode == 1 and result.stdout == b"" and result.stderr, result
        for args in [("1",), ("--help",), ("on",), ("1", "2")]:
            result = run(*args)
            assert (result.returncode, result.stdout, result.stderr) == (
                2, b"", f"Usage: {command}\n".encode()), result

print("Installed performance CLIs: mode/fans output, store paths, missing nodes and arguments passed")
