let () =
  let failures = ref 0 in
  let test name f =
    Printf.printf "test %s: " name;
    match f () with
    | () -> Printf.printf "ok\n"
    | exception exn ->
      incr failures;
      Printf.printf "FAIL: %s\n" (Printexc.to_string exn)
  in
  let tmpdir = Filename.get_temp_dir_name () in

  test "writes to new regular file" (fun () ->
    let path = Filename.concat tmpdir "test_save_as_new.txt" in
    Fun.protect ~finally:(fun () -> try Sys.remove path with _ -> ()) @@ fun () ->
    Passage.Storage.save_as ~path (fun oc -> output_string oc "hello\n");
    let content = In_channel.with_open_text path In_channel.input_all in
    assert (content = "hello\n"));

  test "overwrites existing regular file" (fun () ->
    let path = Filename.concat tmpdir "test_save_as_overwrite.txt" in
    Fun.protect ~finally:(fun () -> try Sys.remove path with _ -> ()) @@ fun () ->
    Out_channel.with_open_text path (fun oc -> output_string oc "old\n");
    Passage.Storage.save_as ~path (fun oc -> output_string oc "new\n");
    let content = In_channel.with_open_text path In_channel.input_all in
    assert (content = "new\n"));

  test "no temp file left on success" (fun () ->
    let path = Filename.concat tmpdir "test_save_as_no_temp.txt" in
    Fun.protect ~finally:(fun () -> try Sys.remove path with _ -> ()) @@ fun () ->
    Passage.Storage.save_as ~path (fun oc -> output_string oc "data\n");
    let temp = Printf.sprintf "%s.save.%d.tmp" path (Unix.getpid ()) in
    assert (not (Sys.file_exists temp)));

  test "no temp file left on failure" (fun () ->
    let path = Filename.concat tmpdir "test_save_as_fail.txt" in
    (try Passage.Storage.save_as ~path (fun _oc -> failwith "boom") with Failure _ -> ());
    let temp = Printf.sprintf "%s.save.%d.tmp" path (Unix.getpid ()) in
    assert (not (Sys.file_exists temp));
    assert (not (Sys.file_exists path)));

  test "writes to /dev/null without error" (fun () ->
    Passage.Storage.save_as ~path:"/dev/null" (fun oc -> output_string oc "discarded\n");
    let temp = Printf.sprintf "/dev/null.save.%d.tmp" (Unix.getpid ()) in
    assert (not (Sys.file_exists temp));
    assert ((Unix.stat "/dev/null").st_kind = Unix.S_CHR));

  test "writes to named pipe (FIFO)" (fun () ->
    let fifo_path = Filename.concat tmpdir "test_save_as_fifo" in
    (try Sys.remove fifo_path with _ -> ());
    Fun.protect ~finally:(fun () -> try Sys.remove fifo_path with _ -> ()) @@ fun () ->
    Unix.mkfifo fifo_path 0o644;
    let received = ref "" in
    let reader = Thread.create (fun () -> received := In_channel.with_open_text fifo_path In_channel.input_all) () in
    Passage.Storage.save_as ~path:fifo_path (fun oc -> output_string oc "fifo data\n");
    Thread.join reader;
    assert (!received = "fifo data\n"));

  test "no temp file created for FIFO" (fun () ->
    let fifo_path = Filename.concat tmpdir "test_save_as_fifo2" in
    (try Sys.remove fifo_path with _ -> ());
    Fun.protect ~finally:(fun () -> try Sys.remove fifo_path with _ -> ()) @@ fun () ->
    Unix.mkfifo fifo_path 0o644;
    let reader = Thread.create (fun () -> ignore (In_channel.with_open_text fifo_path In_channel.input_all)) () in
    Passage.Storage.save_as ~path:fifo_path (fun oc -> output_string oc "data\n");
    Thread.join reader;
    let temp = Printf.sprintf "%s.save.%d.tmp" fifo_path (Unix.getpid ()) in
    assert (not (Sys.file_exists temp)));

  test "writes through symlink without clobbering it" (fun () ->
    let target = Filename.concat tmpdir "test_save_as_symlink_target.txt" in
    let link = Filename.concat tmpdir "test_save_as_symlink_link.txt" in
    Fun.protect ~finally:(fun () ->
      (try Sys.remove target with _ -> ());
      try Sys.remove link with _ -> ())
    @@ fun () ->
    Out_channel.with_open_text target (fun oc -> output_string oc "old\n");
    Unix.symlink target link;
    Passage.Storage.save_as ~path:link (fun oc -> output_string oc "new\n");
    assert ((Unix.lstat link).st_kind = Unix.S_LNK);
    let content = In_channel.with_open_text target In_channel.input_all in
    assert (content = "new\n"));

  if !failures > 0 then exit 1
