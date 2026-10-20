"""Query headers and build packages the executable inventory cannot detect."""
import shutil
import subprocess

PACKAGES = ("gcc-c++", "zlib-devel", "python3-devel", "autoconf", "automake",
            "flex", "bison", "help2man", "perl-interpreter", "make")


def main():
    if not shutil.which("rpm"):
        print("BLOCKED: Fedora package inspection requires rpm")
        return 1
    missing = False
    for package in PACKAGES:
        result = subprocess.run(["rpm", "-q", "--whatprovides", package],
                                capture_output=True, text=True, timeout=20)
        print((result.stdout + result.stderr).strip())
        missing |= result.returncode != 0
    return int(missing)


if __name__ == "__main__":
    raise SystemExit(main())
