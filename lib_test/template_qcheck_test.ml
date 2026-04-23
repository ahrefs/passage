open Passage

let long_factor = 100

(* Generator for a single valid UTF-8 character as a string *)
let utf8_char_gen =
  let open QCheck.Gen in
  let+ n = oneof [ 0 -- 0xD7FF; map (fun n -> n + 0xE000) (0 -- (0x10FFFF - 0xE000)) ] in
  let buf = Buffer.create 4 in
  Buffer.add_utf_8_uchar buf (Uchar.of_int n);
  Buffer.contents buf

(* Generator for a single template character, biased towards braces and identifier chars *)
let biased_char =
  let open QCheck.Gen in
  oneof_weighted
    [
      3, return "{";
      3, return "}";
      2, return " ";
      1, return "\n";
      5, return "a";
      3, return "b";
      2, return "/";
      2, return ".";
      2, return "-";
      2, return "_";
      2, return "0";
      1, return "!";
      4, utf8_char_gen;
    ]

(* Generator for valid UTF-8 template strings from random characters *)
let template_string_gen =
  let open QCheck.Gen in
  map (String.concat "") (list_size (0 -- 100) biased_char)

(* Generator for a valid identifier (matching the lexer's iden_letter) *)
let iden_char_gen =
  let open QCheck.Gen in
  oneof_weighted
    [
      5, map (fun n -> Char.chr (Char.code 'a' + n)) (0 -- 25);
      3, map (fun n -> Char.chr (Char.code 'A' + n)) (0 -- 25);
      2, map (fun n -> Char.chr (Char.code '0' + n)) (0 -- 9);
      1, return '_';
      1, return '-';
      1, return '/';
      1, return '.';
    ]

let iden_gen =
  let open QCheck.Gen in
  let+ chars = list_size (1 -- 20) iden_char_gen in
  String.init (List.length chars) (List.nth chars)

(* Generator that builds templates by interleaving text fragments and {{{secret}}} references *)
let template_with_secrets_gen =
  let open QCheck.Gen in
  let text_fragment =
    let+ chars = list_size (0 -- 30) biased_char in
    String.concat "" chars
  in
  let secret_fragment =
    let+ name = iden_gen in
    "{{{" ^ name ^ "}}}"
  in
  let segment = oneof [ text_fragment; secret_fragment ] in
  let+ segments = list_size (1 -- 10) segment in
  String.concat "" segments

(* Combined generator: mix purely random UTF-8 and structured templates *)
let combined_template_gen =
  let open QCheck.Gen in
  oneof [ template_string_gen; template_with_secrets_gen ]

(* UTF-8 aware shrinker: split into characters, then try removing each one *)
let utf8_chars_of_string s =
  let len = String.length s in
  let acc = ref [] in
  let i = ref 0 in
  while !i < len do
    let b = Char.code s.[!i] in
    let n = if b < 0x80 then 1 else if b < 0xE0 then 2 else if b < 0xF0 then 3 else 4 in
    let n = min n (len - !i) in
    acc := String.sub s !i n :: !acc;
    i := !i + n
  done;
  List.rev !acc

let shrink_utf8 s yield =
  let chars = utf8_chars_of_string s in
  let len = List.length chars in
  for i = 0 to len - 1 do
    let buf = Buffer.create (String.length s) in
    List.iteri (fun j c -> if i <> j then Buffer.add_string buf c) chars;
    yield (Buffer.contents buf)
  done

let template_string = QCheck.make ~print:Fun.id ~shrink:shrink_utf8 combined_template_gen

let substitute_identity name = Ok ("{{{" ^ name ^ "}}}")

(* generated template strings are valid UTF-8 *)
let generator_produces_valid_utf8 =
  QCheck.Test.make ~long_factor ~name:"generator produces valid UTF-8" ~count:1000 template_string (fun s ->
    String.is_valid_utf_8 s)

(* Substituting each secret back to its {{{...}}} form recovers the original string *)
let roundtrip_via_substitute =
  QCheck.Test.make ~long_factor ~name:"roundtrip: substitute with identity recovers original" ~count:1000
    template_string (fun s ->
    let t = Template.parse s in
    Template.substitute_all ~substitute:substitute_identity t = Ok s)

(* parse never raises on valid UTF-8 input *)
let parse_never_raises =
  QCheck.Test.make ~long_factor ~name:"parse never raises on valid UTF-8 input" ~count:1000 template_string (fun s ->
    let _ = Template.parse s in
    true)

(* templates with no secrets substitute without calling substitute *)
let no_secrets_means_pure_text =
  QCheck.Test.make ~long_factor ~name:"no secrets means substitute never called" ~count:1000 template_string (fun s ->
    let t = Template.parse s in
    match Template.secrets t with
    | [] ->
      let substitute _ = failwith "should not be called" in
      Template.substitute_all ~substitute t = Ok s
    | _ -> true)

(* every name passed to substitute is in secrets *)
let substitute_calls_match_secrets =
  QCheck.Test.make ~long_factor ~name:"substitute is called exactly for each secret occurrence" ~count:1000
    template_string (fun s ->
    let t = Template.parse s in
    let called = ref [] in
    let substitute name =
      called := name :: !called;
      Ok ""
    in
    let _ = Template.substitute_all ~substitute t in
    List.rev !called = Template.secrets t)

(* when substitute always fails, errors match secrets *)
let all_errors_match_secrets =
  QCheck.Test.make ~long_factor ~name:"all-error substitute reports every secret" ~count:1000 template_string (fun s ->
    let t = Template.parse s in
    let substitute name = Error ("err:" ^ name) in
    match Template.secrets t, Template.substitute_all ~substitute t with
    | [], Ok _ -> true
    | secrets, Error failures ->
      List.map fst failures = secrets && List.map snd failures = List.map (fun n -> "err:" ^ n) secrets
    | _ -> false)

(* substituting with constant produces result where secret count matches *)
let substitute_count =
  QCheck.Test.make ~long_factor ~name:"constant substitution produces correct count" ~count:1000 template_string
    (fun s ->
    let marker = "\x00\x01\x02" in
    let t = Template.parse s in
    let n_secrets = List.length (Template.secrets t) in
    match Template.substitute_all ~substitute:(fun _ -> Ok marker) t with
    | Error _ -> false
    | Ok result ->
      let count =
        let r = ref 0 in
        let len = String.length marker in
        let i = ref 0 in
        while !i <= String.length result - len do
          if String.sub result !i len = marker then (
            incr r;
            i := !i + len)
          else incr i
        done;
        !r
      in
      count = n_secrets)

(* Generator for strings containing at least one invalid UTF-8 sequence.
   We embed a known-invalid byte sequence into otherwise valid text. *)
let invalid_utf8_gen =
  let open QCheck.Gen in
  let invalid_sequence =
    oneof
      [
        (* lone continuation byte *)
        map (fun b -> String.make 1 (Char.chr (0x80 + (b mod 64)))) (0 -- 63);
        (* 2-byte leader missing continuation *)
        map (fun b -> String.make 1 (Char.chr (0xC2 + (b mod 30)))) (0 -- 29);
        (* 3-byte leader with only 1 continuation *)
        map
          (fun b ->
            let buf = Bytes.create 2 in
            Bytes.set buf 0 (Char.chr (0xE0 + (b mod 16)));
            Bytes.set buf 1 (Char.chr 0x80);
            Bytes.to_string buf)
          (0 -- 15);
        (* overlong 2-byte: 0xC0 or 0xC1 followed by continuation *)
        map
          (fun b ->
            let buf = Bytes.create 2 in
            Bytes.set buf 0 (Char.chr (0xC0 + (b mod 2)));
            Bytes.set buf 1 (Char.chr (0x80 + (b mod 64)));
            Bytes.to_string buf)
          (0 -- 1);
        (* 0xFE and 0xFF are never valid *)
        oneof_list [ "\xFE"; "\xFF" ];
      ]
  in
  let* prefix_len = 0 -- 20 in
  let* prefix = string_size ~gen:(return 'a') (return prefix_len) in
  let* bad = invalid_sequence in
  let* suffix_len = 0 -- 20 in
  let* suffix = string_size ~gen:(return 'b') (return suffix_len) in
  return (prefix ^ bad ^ suffix)

let invalid_utf8 = QCheck.make ~print:String.escaped invalid_utf8_gen

(* generated invalid UTF-8 strings are indeed invalid *)
let generator_produces_invalid_utf8 =
  QCheck.Test.make ~long_factor ~name:"invalid generator produces invalid UTF-8" ~count:1000 invalid_utf8 (fun s ->
    not (String.is_valid_utf_8 s))

(* parse raises on invalid UTF-8 input *)
let parse_rejects_invalid_utf8 =
  QCheck.Test.make ~long_factor ~name:"parse raises on invalid UTF-8 input" ~count:1000 invalid_utf8 (fun s ->
    try
      ignore (Template.parse s);
      false
    with _exn -> true)

let () =
  let suite =
    [
      generator_produces_valid_utf8;
      roundtrip_via_substitute;
      parse_never_raises;
      no_secrets_means_pure_text;
      substitute_calls_match_secrets;
      all_errors_match_secrets;
      substitute_count;
      generator_produces_invalid_utf8;
      parse_rejects_invalid_utf8;
    ]
  in
  QCheck_base_runner.run_tests_main suite
