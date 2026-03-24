open Passage

let test_config_lines content =
  let tmpfile = Filename.temp_file "config_lines_test" ".txt" in
  Fun.protect
    (fun () ->
      Out_channel.with_open_text tmpfile (fun oc -> output_string oc content);
      let result = Storage.config_lines tmpfile in
      List.iter (fun line -> Printf.printf "%S\n" line) result)
    ~finally:(fun () -> Sys.remove tmpfile)

let%expect_test "empty lines are stripped" =
  test_config_lines "alice\n\nbob\n\n\ncharlie\n";
  [%expect {|
    "alice"
    "bob"
    "charlie" |}]

let%expect_test "full-line comments are stripped" =
  test_config_lines "alice\n# this is a comment\nbob\n  # indented comment\ncharlie\n";
  [%expect {|
    "alice"
    "bob"
    "charlie" |}]

let%expect_test "inline comments are stripped" =
  test_config_lines "alice # team lead\nbob#backup\ncharlie  #  ops\n";
  [%expect {|
    "alice"
    "bob"
    "charlie" |}]

let%expect_test "leading and trailing whitespace is trimmed" =
  test_config_lines "  alice  \n\tbob\t\n  charlie  \n";
  [%expect {|
    "alice"
    "bob"
    "charlie" |}]

let%expect_test "whitespace + inline comments combined" =
  test_config_lines "  alice # lead  \n  bob  # backup  \n";
  [%expect {|
    "alice"
    "bob" |}]

let%expect_test "line that is only a comment after stripping" =
  test_config_lines "# full comment\n  # indented full comment\nalice\n";
  [%expect {| "alice" |}]

let%expect_test "nonexistent file returns empty list" =
  let result = Storage.config_lines "/nonexistent/path/file.txt" in
  List.iter (fun line -> Printf.printf "%S\n" line) result;
  [%expect {| |}]

let%expect_test "empty file returns empty list" =
  test_config_lines "";
  [%expect {| |}]

let%expect_test "file with only comments and whitespace" =
  test_config_lines "# comment\n  \n\n  # another\n";
  [%expect {| |}]

let%expect_test "mixed: all features together" =
  test_config_lines {|# header comment
alice # admin
  bob
  # separator

charlie  # ops
|};
  [%expect {|
    "alice"
    "bob"
    "charlie" |}]
