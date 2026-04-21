open Passage

let test_parse_success s = print_endline (Template.dump (Template.parse s))
let test_parse_failure s =
  try
    let (_ : Template.t) = Template.parse s in
    ()
  with exn -> print_endline (Printexc.to_string exn)

let%expect_test "empty string" =
  test_parse_success "";
  [%expect {||}]

let%expect_test "triple open braces" =
  test_parse_success "{{{";
  [%expect {| Text("{{{")|}]

let%expect_test "triple closing braces" =
  test_parse_success "}}}";
  [%expect {| Text("}}}")|}]

let%expect_test "paired double braces" =
  test_parse_success "{{abcdefghi}}";
  [%expect {| Text("{{abcdefghi}}") |}]

let%expect_test "paired triple braces" =
  test_parse_success "{{{abcdefghi}}}";
  [%expect {| Iden("abcdefghi") |}]

let%expect_test "paired triple braces with special characters as identifier" =
  test_parse_success "{{{ab_cd-ef/ghi.123}}}";
  [%expect {| Iden("ab_cd-ef/ghi.123") |}]

let%expect_test "paired triple braces - empty" =
  test_parse_success "{{{}}}";
  [%expect {| Text("{{{}}}") |}]

let%expect_test "leading digits are ok" =
  test_parse_success "{{{00abc}}}";
  [%expect {| Iden("00abc") |}]

let%expect_test "paired triple braces with whitespace" =
  test_parse_success "{{{  abcdefghi    }}}";
  [%expect {| Text("{{{  abcdefghi    }}}") |}]

let%expect_test "paired triple braces with brace in iden" =
  test_parse_success "{{{abc{def}ghi}}}";
  [%expect {| Text("{{{abc{def}ghi}}}") |}]

let%expect_test "paired triple braces - 4 opening brace" =
  test_parse_success "{{{{abcdefghi}}}";
  [%expect {| Text("{{{{abcdefghi}}}") |}]

let%expect_test "paired triple braces - 4 closing braces" =
  test_parse_success "{{{abcdefghi}}}}";
  [%expect {| Iden("abcdefghi") Text("}") |}]

let%expect_test "paired triple braces - 6 opening brace" =
  test_parse_success "{{{{{{abcdefghi}}}";
  [%expect {| Text("{{{") Iden("abcdefghi") |}]

let%expect_test "paired triple braces - 6 closing brace" =
  test_parse_success "{{{abcdefghi}}}}}}";
  [%expect {| Iden("abcdefghi") Text("}}}") |}]

let%expect_test "unpaired triple braces - missing closing braces" =
  test_parse_success "{{{abcdefghi";
  [%expect {| Text("{{{abcdefghi") |}]

let%expect_test "unpaired triple braces - missing closing braces and with whitespace" =
  test_parse_success "{{{   \nabcdefghi";
  [%expect {| Text("{{{   \nabcdefghi") |}]

let%expect_test "unpaired triple braces - missing closing braces and with multiple words" =
  test_parse_success "{{{a  abcdefghi";
  [%expect {| Text("{{{a  abcdefghi") |}]

let%expect_test "unpaired triple braces - single closing brace" =
  test_parse_success "{{{abcdefghi}";
  [%expect {| Text("{{{abcdefghi}") |}]

let%expect_test "unpaired triple braces - missing opening braces" =
  test_parse_success "abcdefghi}}}";
  [%expect {| Text("abcdefghi}}}") |}]

let%expect_test "unpaired triple braces - missing opening braces and with whitespace" =
  test_parse_success "abcdefghi\n   }}}";
  [%expect {| Text("abcdefghi\n   }}}") |}]

let%expect_test "unpaired triple braces - missing opening braces and with multiple words" =
  test_parse_success "a  abcdefghi}}}";
  [%expect {| Text("a  abcdefghi}}}") |}]

let%expect_test "unpaired triple braces - single opening brace" =
  test_parse_success "{abcdefghi}}}";
  [%expect {| Text("{abcdefghi}}}") |}]

let%expect_test "consecutive valid identifiers" =
  test_parse_success "{{{abcdefghi}}}{{{zyx123456789}}}";
  [%expect {| Iden("abcdefghi") Iden("zyx123456789") |}]

let%expect_test "non-consecutive valid identifiers" =
  test_parse_success "{{{abcdefghi}}} separated by text and white space {{{zyx123456789}}}";
  [%expect {| Iden("abcdefghi") Text(" separated by text and white space ") Iden("zyx123456789") |}]

let%expect_test "multiple lines with text before and after identifier" =
  test_parse_success "hello\n{{{abcdefghi}}} world\n!";
  [%expect {| Text("hello\n") Iden("abcdefghi") Text(" world\n!") |}]

let%expect_test "substitute_all succeeds" =
  let t = Template.parse "hello {{{secret1}}} and {{{secret2}}}!" in
  let substitute = function
    | "secret1" -> Ok "VALUE1"
    | "secret2" -> Ok "VALUE2"
    | name -> Error (Printf.sprintf "unknown: %s" name)
  in
  (match Template.substitute_all ~substitute t with
  | Ok text -> print_endline text
  | Error _ -> print_endline "ERROR");
  [%expect {| hello VALUE1 and VALUE2! |}]

let%expect_test "substitute_all partial failure" =
  let t = Template.parse "{{{good}}} and {{{bad1}}} and {{{bad2}}}" in
  let substitute = function
    | "good" -> Ok "OK"
    | name -> Error (Printf.sprintf "fail: %s" name)
  in
  (match Template.substitute_all ~substitute t with
  | Ok _ -> print_endline "unexpected success"
  | Error failures -> List.iter (fun (name, msg) -> Printf.printf "%s: %s\n" name msg) failures);
  [%expect {|
    bad1: fail: bad1
    bad2: fail: bad2 |}]

let%expect_test "identifiers" =
  let t = Template.parse "text {{{a}}} more {{{b}}} text {{{a}}}" in
  List.iter print_endline (Template.secrets t);
  [%expect {|
    a
    b
    a |}]
