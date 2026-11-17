open Sdl3

let go = function Ok value -> value | Error (`Msg message) -> failwith message
let check label condition =
  if not condition then failwith label;
  Printf.printf "PASS %s\n%!" label

let test_layout () =
  check "Uint64 is exactly 64 bits" (Ctypes.sizeof T.uint64 = 8);
  check "Sint64 is exactly 64 bits" (Ctypes.sizeof T.sint64 = 8);
  check "window flags are exactly 64 bits" (Ctypes.sizeof T.window_flags = 8);
  check "window timestamp offset" (Ctypes.offsetof T.WindowEvent.timestamp = 8);
  check "window ID offset" (Ctypes.offsetof T.WindowEvent.window_id = 16);
  check "SDL_Event ABI" (Ctypes.sizeof T.event_raw = 128);
  check "SDL_WindowEvent ABI" (Ctypes.sizeof T.window_event = 32);
  check "SDL_KeyboardEvent ABI" (Ctypes.sizeof T.keyboard_event = 40);
  check "SDL_MouseMotionEvent ABI" (Ctypes.sizeof T.mouse_motion_event = 48)

let test_window () =
  let window = Sdl.Window.create "Binding regression test" 96 64 Sdl.window_hidden |> go in
  Fun.protect ~finally:(fun () -> Sdl.Window.destroy window) (fun () ->
    check "logical window size" (go (Sdl.Window.get_size window) = (96, 64));
    check "inactive text input is a boolean" (not (Sdl.text_input_active window));
    Sdl.start_text_input window |> go;
    check "active text input is a boolean" (Sdl.text_input_active window);
    Sdl.set_text_input_area window (Some (T.Rect.create ~x:2 ~y:3 ~w:4 ~h:5 ())) 0 |> go;
    Sdl.stop_text_input window |> go;
    let renderer = Sdl.Renderer.create window "software" |> go in
    Fun.protect ~finally:(fun () -> Sdl.Renderer.destroy renderer) (fun () ->
      let texture = Sdl.Texture.create renderer Sdl.pixelformat_argb8888 Sdl.textureaccess_streaming 96 64 |> go in
      Fun.protect ~finally:(fun () -> Sdl.Texture.destroy texture) (fun () ->
        let pixels = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout (96 * 64 * 4) in
        Bigarray.Array1.fill pixels 255;
        Sdl.Texture.update texture None Ctypes.(to_voidp (bigarray_start array1 pixels)) (96 * 4) |> go;
        Sdl.render_texture renderer texture None None |> go;
        Sdl.Renderer.present renderer |> go;
        check "software texture present" true));
    Sdl.Event.flushs 0 65535;
    check "empty event queue is false" (not (Sdl.Event.has Sdl.event_quit));
    check "event timeout is false" (not (Sdl.Event.wait_timeout None 1));
    Sdl.Event.flushs 0 65535;
    let event = Sdl.Event.create () in
    let motion = Sdl.Event.(get event motion) in
    T.MouseMotionEvent.(set motion typ Sdl.event_mouse_motion);
    T.MouseMotionEvent.(set motion timestamp 0x100000001L);
    T.MouseMotionEvent.(set motion window_id (Sdl.Window.get_id window));
    T.MouseMotionEvent.(set motion x 12.25);
    T.MouseMotionEvent.(set motion yrel (-0.5));
    Sdl.Event.push event |> go;
    let received = Sdl.Event.create () in
    check "event poll" (Sdl.Event.poll (Some received));
    let motion = Sdl.Event.(get received motion) in
    check "fractional event coordinates" (T.MouseMotionEvent.(get motion x) = 12.25);
    check "fractional relative coordinates" (T.MouseMotionEvent.(get motion yrel) = -0.5);
    check "64-bit event timestamp" (T.MouseMotionEvent.(get motion timestamp) > 0xffffffffL))

let test_callbacks () =
  let seen = ref 0 in
  let watch = Sdl.Event.add_watch (fun _ _ -> incr seen; true) Ctypes.null |> go in
  Gc.full_major ();
  let event = Sdl.Event.create ~typ:Sdl.event_quit () in
  Sdl.Event.push event |> go;
  check "retained event callback" (!seen > 0);
  Sdl.Event.remove_watch watch;
  Sdl.Event.remove_watch watch;
  let count = !seen in
  Sdl.Event.push event |> go;
  check "event callback removed by stable identity" (!seen = count);
  let called = ref false in
  let callback _ _ _ = called := true; Unsigned.UInt.zero in
  let timer = Sdl.Timer.add 5 callback Ctypes.null in
  Sdl.delay 30;
  ignore (Sdl.Timer.remove timer);
  check "timer callback runtime lock and thread registration" !called;
  let called_ns = ref false in
  let callback_ns _ _ _ = called_ns := true; Unsigned.UInt64.zero in
  let timer_ns = Sdl.Timer.add_ns 5000000L callback_ns Ctypes.null in
  Sdl.delay 30;
  ignore (Sdl.Timer.remove timer_ns);
  check "nanosecond timer callback registration" !called_ns

let () =
  test_layout ();
  Sdl.init Sdl.init_video |> go;
  Fun.protect ~finally:Sdl.quit (fun () -> test_window (); test_callbacks ());
  check "clean shutdown" true
