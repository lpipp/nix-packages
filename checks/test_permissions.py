"""Exercise the actual Nix helper against a temporary sysfs substitute."""
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).read_text()
assert "/nix/store/" in source
assert "/usr/bin" not in source and "/usr/lib" not in source
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    base = root / "hunter_light"
    helper = root / "permissions"
    helper.write_text(source.replace(
        "/sys/bus/platform/devices/huawei-wmi/hunter_light", str(base)))
    helper.chmod(0o755)
    run = lambda *args: subprocess.run([str(helper), *args], check=False)
    assert run().returncode == 0
    base.mkdir()
    sentinel = base / "raw_debug"
    sentinel.touch(mode=0o600)
    for cycle in range(3):
        for zone in ("logo", "wind", "keyboard"):
            node = base / zone
            node.unlink(missing_ok=True)
            node.touch(mode=0o200)
        assert run("extra").returncode == 2
        assert all(stat.S_IMODE((base / z).stat().st_mode) == 0o200
                   for z in ("logo", "wind", "keyboard"))
        assert run().returncode == 0
        assert all(stat.S_IMODE((base / z).stat().st_mode) == 0o222
                   for z in ("logo", "wind", "keyboard"))
        assert stat.S_IMODE(sentinel.stat().st_mode) == 0o600
    (base / "wind").unlink()
    assert run().returncode == 0
print("Nix helper scope, missing nodes and recreated nodes passed")
