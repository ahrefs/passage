open Passage

let pp_secret { Secret.kind; text; comments } =
  Printf.sprintf "{ kind=%s; text=%S; comments=%s }" (Secret.kind_to_string kind) text
    (match comments with
    | None -> "None"
    | Some c -> Printf.sprintf "Some %S" c)

let parse s =
  print_endline (try "Ok " ^ pp_secret (Secret.Validation.parse_exn s) with exn -> "Error: " ^ Printexc.to_string exn)

let%expect_test "empty string or whitespace string" =
  parse {||};
  [%expect {|Error: Failure("empty secrets are not allowed")|}];
  parse {| |};
  [%expect {|Error: Failure("empty secrets are not allowed")|}]

let%expect_test "multi-line without comments" =
  parse {|

secret
secret|};
  [%expect {|Ok { kind=multi-line; text="secret\nsecret"; comments=None }|}]

let%expect_test "multi-line with comments" =
  parse {|
comment1
comment2

secret
secret|};
  [%expect {|Ok { kind=multi-line; text="secret\nsecret"; comments=Some "comment1\ncomment2" }|}]

let%expect_test "broken format multi-line" =
  parse {|
comment1|};
  [%expect {|Error: Failure("broken format multi-line secret (empty secret text). Please fix secret.")|}];
  parse {|
comment1
comment2

|};
  [%expect {| Error: Failure("broken format multi-line secret (empty secret text). Please fix secret.") |}]

let%expect_test "single-line without comments" =
  parse {|secret secret|};
  [%expect {|Ok { kind=single-line; text="secret secret"; comments=None }|}]

let%expect_test "single-line with comments" =
  parse {|secret secret

comment1
comment2|};
  [%expect {|Ok { kind=single-line; text="secret secret"; comments=Some "comment1\ncomment2" }|}]

let%expect_test "single-line with comments legacy" =
  parse {|secret secret
comment1
comment2|};
  [%expect {|Ok { kind=single-line; text="secret secret"; comments=Some "comment1\ncomment2" }|}]

let%expect_test "multi-line with whitespace-only comment line" =
  parse "\n \n\naaa";
  [%expect {|
    Ok { kind=multi-line; text="aaa"; comments=Some "" } |}]

let%expect_test "single-line with trailing carriage return in comments (comments are trimmed)" =
  parse "a\n\r";
  [%expect {|
    Ok { kind=single-line; text="a"; comments=Some "" } |}]

let%expect_test "single-line with leading space (single-line comments are not trimmed)" =
  parse " a\n";
  [%expect {|
    Ok { kind=single-line; text=" a"; comments=None } |}]

let%expect_test "single-line with empty lines in comments (only beginning, end of comments are trimmed)" =
  parse "a\n\na\n\na";
  [%expect {|
    Ok { kind=single-line; text="a"; comments=Some "a\n\na" } |}]

let%expect_test "single-line with trailing carriage return (single-line comments are not trimmed)" =
  parse "a\r";
  [%expect {|
    Ok { kind=single-line; text="a\r"; comments=None } |}]

let%expect_test "multi-line with extra leading empty lines (beginning, end of multiline secret/comments are trimmed)" =
  parse "\n\n\na";
  [%expect {|
    Ok { kind=multi-line; text="a"; comments=None } |}]

let%expect_test
  "multi-line secret with trailing carriage return (beginning, end of multiline secret/comments are trimmed)" =
  parse "\n\na\r";
  [%expect {|
    Ok { kind=multi-line; text="a"; comments=None } |}]

let%expect_test "single-line with trailing newline" =
  parse "a\n";
  [%expect {|
    Ok { kind=single-line; text="a"; comments=None } |}]

let%expect_test "empty single-line secret" =
  parse "";
  [%expect {|Error: Failure("empty secrets are not allowed")|}];
  parse "\t";
  [%expect {|Error: Failure("empty secrets are not allowed")|}];
  parse "\t\n";
  [%expect {|Error: Failure("empty secrets are not allowed")|}];
  parse "\t\n\n";
  [%expect {|Error: Failure("empty secrets are not allowed")|}];
  parse " \n\ncomment1\ncomment2";
  [%expect {|Error: Failure("empty secrets are not allowed")|}]
