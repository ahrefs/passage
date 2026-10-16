open Passage

let long_factor = 100

let line_or_empty_gen =
  let open QCheck.Gen in
  oneof [ return ""; string ]

let plaintext_gen =
  let open QCheck.Gen in
  let+ lines = list_size (0 -- 10) line_or_empty_gen in
  String.concat "\n" lines

let secret_string_arb = QCheck.make ~shrink:QCheck.Shrink.string ~print:String.escaped plaintext_gen

let parse_exn_text_is_nonempty =
  QCheck.Test.make ~long_factor ~name:"parse_exn result has non-empty trimmed text" ~count:1000 secret_string_arb
    (fun s ->
    match Secret.Validation.parse_exn s with
    | t -> String.trim t.text <> ""
    | exception Failure _ -> true)

let parse_exn_comment_is_trimmed =
  QCheck.Test.make ~long_factor ~name:"parse_exn result has trimmed comments" ~count:1000 secret_string_arb (fun s ->
    match Secret.Validation.parse_exn s with
    | { comments = Some comments; _ } -> String.trim comments = comments
    | _ -> true
    | exception Failure _ -> true)

let result_of_parse_exn f s = try Ok (f s) with Failure msg -> Error msg

let show_result r =
  match r with
  | Ok { Secret.kind; text; comments } ->
    Printf.sprintf "Ok { kind=%s; text=%S; comments=%s }" (Secret.kind_to_string kind) text
      (match comments with
      | None -> "None"
      | Some c -> Printf.sprintf "Some %S" c)
  | Error msg -> Printf.sprintf "Error %S" msg

let eq_secret (a : Secret.t) (b : Secret.t) = a.kind = b.kind && a.text = b.text && a.comments = b.comments

let parse_exn_agrees =
  QCheck.Test.make ~long_factor ~name:"parse_exn fails iff parse_exn_old fails" ~count:10000 secret_string_arb (fun s ->
    let old_result = result_of_parse_exn Secret.Validation.parse_exn_old s in
    let new_result = result_of_parse_exn Secret.Validation.parse_exn s in
    match old_result, new_result with
    | Ok old_secret, Ok new_secret ->
      if eq_secret old_secret new_secret then true
      else
        QCheck.Test.fail_reportf "results differ:\n  input: %S\n  old: %s\n  new: %s" s (show_result old_result)
          (show_result new_result)
    | Error _, Error _ -> true
    | Ok _, Error _ ->
      QCheck.Test.fail_reportf "old succeeded but new failed:\n  input: %S\n  old: %s\n  new: %s" s
        (show_result old_result) (show_result new_result)
    | Error _, Ok _ ->
      QCheck.Test.fail_reportf "old failed but new succeeded:\n  input: %S\n  old: %s\n  new: %s" s
        (show_result old_result) (show_result new_result))

let () =
  QCheck_base_runner.run_tests_main [ parse_exn_text_is_nonempty; parse_exn_comment_is_trimmed; parse_exn_agrees ]
