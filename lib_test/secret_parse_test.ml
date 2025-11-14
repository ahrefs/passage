open Passage.Make (Passage.Default_config)

let parse s =
  try
    let { Secret.kind; text; comments } = Secret.Validation.parse_exn s in
    print_endline
    @@ Printf.sprintf {|Kind: %s
Text:
%s
Comments:
%s|} (Validation_test.string_of_kind kind) text
         (Option.value ~default:"" comments)
  with exn -> print_endline ("Error: " ^ Devkit.Exn.to_string exn)

let%expect_test "empty string or whitespace string" =
  parse {||};
  [%expect {| Error: Failure("empty secrets are not allowed") |}];
  parse {| |};
  [%expect {| Error: Failure("empty secrets are not allowed") |}]

let%expect_test "multi-line without comments" =
  parse {|

secret
secret|};
  [%expect {|
         Kind: multi-line
         Text:
         secret
         secret
         Comments:
         |}]

let%expect_test "multi-line with comments" =
  parse {|
comment1
comment2

secret
secret|};
  [%expect
    {|
      Kind: multi-line
      Text:
      secret
      secret
      Comments:
      comment1
      comment2|}]

let%expect_test "broken format multi-line" =
  parse {|
comment1|};
  [%expect {| Error: Failure("broken format multi-line secret (empty secret text). Please fix secret.") |}];
  parse {|
comment1
comment2

|};
  [%expect {| Error: Failure("broken format multi-line secret (empty secret text). Please fix secret.") |}]

let%expect_test "single-line without comments" =
  parse {|secret secret|};
  [%expect {|
         Kind: single-line
         Text:
         secret secret
         Comments:
         |}]

let%expect_test "single-line with comments" =
  parse {|secret secret

comment1
comment2|};
  [%expect
    {|
         Kind: single-line
         Text:
         secret secret
         Comments:
         comment1
         comment2|}]

let%expect_test "single-line with comments legacy" =
  parse {|secret secret
comment1
comment2|};
  [%expect
    {|
         Kind: single-line
         Text:
         secret secret
         Comments:
         comment1
         comment2|}]
