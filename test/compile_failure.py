"""Require resource mismatches to fail for the intended type error."""

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ocamlfind, library = sys.argv[1:]
for filename in ("wrong_window.ml", "wrong_renderer.ml"):
    with tempfile.TemporaryDirectory() as temporary:
        result = subprocess.run(
            [ocamlfind, "ocamlc", "-thread", "-package", "ctypes.foreign",
             "-I", library, "-c", filename, "-o", str(Path(temporary) / "rejected.cmo")],
            text=True, capture_output=True,
        )
        diagnostic = re.sub(r"\x1b\[[0-9;]*m", "", result.stderr)
        if result.returncode != 2 or not all(
            token in diagnostic for token in ("Error:", "has type", "window_tag", "renderer_tag")
        ):
            raise AssertionError(f"{filename}: unexpected compiler result\n{result.stderr}")
        print(f"PASS rejects {filename}")
