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
