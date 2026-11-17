"""Require resource mismatches to fail for the intended type error."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile

compiler, library = sys.argv[1:]
for filename in ("wrong_window.ml", "wrong_renderer.ml"):
    with tempfile.TemporaryDirectory() as temporary:
        result = subprocess.run(
            ["ocamlfind", "ocamlc", "-thread", "-package", "ctypes.foreign",
             "-I", library, "-c", filename, "-o", str(Path(temporary) / "rejected.cmo")],
            text=True, capture_output=True,
            env=dict(os.environ, OCAMLFIND_COMMANDS=f"ocamlc={compiler}"),
        )
        if result.returncode != 2 or not all(
            token in result.stderr for token in ("Error:", "window", "renderer")
        ):
            raise AssertionError(f"{filename}: unexpected compiler result\n{result.stderr}")
        print(f"PASS rejects {filename}")
