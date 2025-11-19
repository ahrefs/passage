open Passage

let pp ast = List.map Template_ast.to_string ast |> String.concat " " |> print_endline

let test_parse_success s = pp (Template.parse s)
let test_parse_failure s =
  try
    let (_ : Template_ast.ast) = Template.parse s in
    ()
  with exn -> print_endline (Devkit.Exn.to_string exn)

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
