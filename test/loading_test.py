"""Check quiet loading, authoritative overrides and bundled runtime lookup."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

executable = Path(sys.argv[1]).resolve()
environment = dict(os.environ, SDL_VIDEODRIVER="dummy")
environment.pop("SDL3_BINDING_DEBUG", None)
result = subprocess.run([executable], env=environment, text=True, capture_output=True)
assert result.returncode == 0, result.stderr
assert result.stdout == "Ok\n", result.stdout
print("PASS quiet library loading")
result = subprocess.run([executable], env=dict(environment, SDL3_LIBRARY="/missing/sdl3-runtime"),
                        text=True, capture_output=True)
assert result.returncode != 0
assert "SDL3 could not be loaded" in result.stderr, result.stderr
print("PASS explicit missing runtime fails clearly")
runtime = environment.get("SDL3_LIBRARY")
if runtime and Path(runtime).is_file():
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        if sys.platform == "darwin":
            binary = root / "Sample.app/Contents/MacOS/test"
            library = root / "Sample.app/Contents/Frameworks/libSDL3.dylib"
        elif sys.platform == "win32":
            binary = root / "bin/test.exe"
            library = root / "bin/SDL3.dll"
        else:
            binary = root / "bin/test"
            library = root / "lib/libSDL3.so.0"
        binary.parent.mkdir(parents=True)
        library.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(executable, binary)
        shutil.copy2(runtime, library)
        bundled_environment = environment.copy()
        bundled_environment.pop("SDL3_LIBRARY", None)
        result = subprocess.run([binary], env=bundled_environment, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        assert result.stdout == "Ok\n", result.stdout
        print("PASS bundled runtime without SDL3_LIBRARY")
