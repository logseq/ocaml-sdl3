(* Manually generated... *)

let debug = Sys.getenv_opt "SDL3_BINDING_DEBUG" = Some "1"
let _pre = if debug then print_endline else ignore


(* We try to load SDL3 dynamically - should work on Windows, macOS, Linux, and
   maybe more *)

let sdl3_candidates =
  let executable_directory = Filename.dirname Sys.executable_name in
  let bundled = List.map (Filename.concat executable_directory)
      [ "../Frameworks/libSDL3.dylib"; "../lib/libSDL3.so.0";
        "libSDL3.so.0"; "SDL3.dll" ] in
  bundled @
  match Sys.os_type with
  | "Win32" | "Cygwin" -> [ "SDL3.dll" ]
  | "Unix" -> [ (* Linux *)"libSDL3.so"; "libSDL3.so.0";(* MacOS *)"libSDL3.dylib"]
  | _ -> []

let lib_sdl3 =
  let candidates = match Sys.getenv_opt "SDL3_LIBRARY" with
    | Some filename -> [filename]
    | None -> sdl3_candidates in
  match Dynlib.load ~debug ~name:"SDL3" candidates with
  | Some library -> library
  | None -> failwith "sdl3: SDL3 could not be loaded; bundle the library beside the application or set SDL3_LIBRARY"

let stub = not debug
(* In debug mode, we fail as soon as a function is unbound; otherwise, we fail
   only when the function is called with an argument. *)
(* C callbacks reacquire the runtime lock, including callbacks made while
   polling events or shutting down a device. Ctypes owns argument storage. *)
let foreign ?(release_runtime_lock=true) name signature =
  Foreign.foreign ~from:lib_sdl3 ~stub ~release_runtime_lock name signature
