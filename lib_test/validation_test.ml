open Passage

let string_of_kind = function
  | Secret.Singleline -> "single-line"
  | Multiline -> "multi-line"

let test_validate s =
  print_endline
    (match Secret.Validation.validate s with
    | Ok kind -> "OK: " ^ string_of_kind kind
    | Error (e, _typ) -> "Error: " ^ e)

let%expect_test "empty string or whitespace" =
  test_validate {||};
  [%expect {| Error: empty secrets are not allowed |}];
  test_validate {| |};
  [%expect {| Error: empty secrets are not allowed |}]

let%expect_test "multi-line without secret" =
  test_validate {|
comment|};
  [%expect {| Error: multiline: empty secret |}];
  test_validate {|
comment


  |};
  [%expect {| Error: multiline: empty secret |}]

let%expect_test "multi-line with comments" =
  test_validate {|
comment
comment

secret
secret|};
  [%expect {| OK: multi-line |}]

let%expect_test "multi-line without comments" =
  test_validate {|

secret

still secret|};
  [%expect {| OK: multi-line |}]

let%expect_test "single-line with comments" =
  test_validate {|secret

comment
comment|};
  [%expect {| OK: single-line |}]

let%expect_test "legacy single-line with comments" =
  test_validate {|secret
comment
comment|};
  [%expect {| Error: single-line secrets with comments should have an empty line between the secret and the comments. |}]

let%expect_test "single-line without comments" =
  test_validate {|secret|};
  [%expect {| OK: single-line |}]
