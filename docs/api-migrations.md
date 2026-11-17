# Fork API changes

## SDL3 binding hardening

The fork retains upstream's generated coverage and ISC license. Its generated
files are patched directly because upstream has not published the generator.
Changes must be preserved when importing new generated files.

- Opaque resources now have distinct pointer types. A window cannot be passed
  to renderer, cursor, GPU or audio-stream operations. Correctly typed calls
  are unchanged. Use `Ctypes.to_voidp` only at an actual native `void *`
  boundary; do not use casts to bypass resource checks.
- SDL fixed-width integers use `int64_t` and `uint64_t`, including event
  timestamps and window flags. Raw unsigned values use `Unsigned.UInt64`;
  raw signed values use `int64`. Standard C `long` operations retain their
  platform-dependent C semantics. Callers passing raw signed IO pointers must
  allocate `Ctypes.int64_t` instead of `Ctypes.long`.
- Predicate functions return `bool`: `Event.has`, `Event.hass`,
  `Event.get_filter`, `text_input_active`, `AudioDevice.paused`,
  `AudioStream.device_paused`, `Storage.ready`, and rectangle-intersection
  predicates. A normal false result no longer reads a stale SDL error.
  Replace `match Sdl.text_input_active window with Ok () -> ... | Error _ -> ...`
  with `if Sdl.text_input_active window then ... else ...`.
- `Event.wait_timeout` returns SDL's boolean result. A normal timeout is
  `false`, rather than an error containing an empty or stale SDL message.
- `Event.add_watch callback userdata` returns a retained, abstract `Event.watch`
  token. Remove it with `Event.remove_watch watch`; repeated removal is safe.
  The same native callback address is used for registration and removal, and
  the callback survives OCaml garbage collection until removal. Other raw
  asynchronous callbacks still require the documented caller-owned lifetime.
- Foreign calls release the OCaml runtime lock and callback trampolines
  consistently acquire it and register foreign threads. This includes event
  pumping and device shutdown; callbacks must not assume their calling thread.
- Library loading is silent by default. `SDL3_BINDING_DEBUG=1` enables failure
  diagnostics. An explicit `SDL3_LIBRARY` is authoritative and a missing
  runtime fails with a clear loading error. Platform-inapplicable functions
  remain deferred until called. Importing the library no longer changes SDL's
  application logging priority.
- Bundled runtimes are searched relative to the executable before system
  loader paths: macOS `../Frameworks/libSDL3.dylib`, Linux
  `../lib/libSDL3.so.0` or `libSDL3.so.0`, Windows `SDL3.dll`.
  End users do not need a system SDL3 installation when the application ships
  this runtime. Packaging must also include its non-system dependencies.

`dune runtest` now runs ABI, software-rendering, predicate, event and callback
regressions plus compile-failure checks for resource mismatches. CI builds and
tests on macOS, Linux and Windows with a checksum-pinned SDL3 runtime.
