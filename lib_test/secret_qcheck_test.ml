open Passage

let long_factor = 100

let line_or_empty_gen =
  let open QCheck.Gen in
  oneof [ return ""; string ]

let plaintext_gen =
  let open QCheck.Gen in
  let+ lines = list_size (0 -- 10) line_or_empty_gen in
  String.concat "\n" lines

let plaintext_arb = QCheck.make ~shrink:QCheck.Shrink.string ~print:String.escaped plaintext_gen

let parse_exn_text_is_nonempty =
  QCheck.Test.make ~long_factor ~name:"parse_exn result has non-empty trimmed text" ~count:1000 plaintext_arb (fun s ->
    match Secret.Validation.parse_exn s with
    | t -> String.trim t.text <> ""
    | exception Failure _ -> true)

let () = QCheck_base_runner.run_tests_main [ parse_exn_text_is_nonempty ]
