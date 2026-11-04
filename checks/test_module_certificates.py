"""Check same-name replacement certificates without a kernel build or hardware."""
from pathlib import Path
import subprocess
import sys
import tempfile

helper, shell = sys.argv[1:]


def run_case(name, order, dependencies, certificates, expected, success=True):
    with tempfile.TemporaryDirectory(prefix="hunter-certificates-") as directory:
        root = Path(directory)
        (root / "modules.order").write_text("".join(p + "\n" for p in order))
        (root / "modules.dep").write_text("".join(p + ":\n" for p in dependencies))
        original = b"builtin-certificate-bundle\x00"
        (root / "modules.cer").write_bytes(original)
        for module, certificate in certificates.items():
            path = root / (module + ".cer")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(certificate)
        result = subprocess.run([shell, helper, str(root)], capture_output=True)
        assert (result.returncode == 0) == success, (name, result)
        if success:
            assert (root / "modules.cer").read_bytes() == original + expected, name
        else:
            assert result.stderr, name
        print(name + ": passed")


base = ["kernel/led.ko", "kernel/huawei-wmi.ko"]
hunter = "updates/hunter/huawei-wmi.ko"
certificate = b"hunter-certificate\x00\xff"
run_case("same-name replacement with equal line counts", base,
         ["kernel/led.ko.xz", hunter], {hunter: certificate}, certificate)
run_case("replacement before built-in modules", base,
         [hunter, "kernel/led.ko.xz"], {hunter: certificate}, certificate)
for suffix in ("", ".gz", ".xz", ".zst"):
    run_case("external module compression " + repr(suffix), base,
             [p + ".xz" for p in base] + [hunter + suffix],
             {hunter: certificate}, certificate)
run_case("built-in modules only", base, [p + ".xz" for p in base], {}, b"")
run_case("missing external certificate", base, [hunter], {}, b"", success=False)
run_case("empty external certificate", base, [hunter], {hunter: b""}, b"", success=False)
