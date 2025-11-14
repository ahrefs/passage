open Printf
open Util.Show
module Make (Config : Types.Config) = struct
  include Lib.Make (Config)

  module Get = struct
    let get_secret ?expected_kind ?line_number ~with_comments ?(trim_new_line = false) secret_name =
      let secret_exists =
        try Storage.Secrets.secret_exists secret_name with exn -> Shell.die ~exn "E: %s" (show_name secret_name)
      in
      (match secret_exists with
      | false ->
        if Path.is_directory Storage.Secrets.(to_path secret_name |> Path.abs) then
          Shell.die "E: %s is a directory" (show_name secret_name)
        else Shell.die "E: no such secret: %s" (show_name secret_name)
      | true -> ());
      let get_line_exn secret line_number =
        if line_number < 1 then Shell.die "Line number should be greater than 0";
        let lines = String.split_on_char '\n' secret in
        (* user specified line number is 1-indexed *)
        match List.nth_opt lines (line_number - 1) with
        | None -> Shell.die "There is no secret at line %d" line_number
        | Some l -> l
      in
      let plaintext =
        try Storage.Secrets.decrypt_exn secret_name
        with exn -> Shell.die ~exn "E: failed to decrypt %s" (show_name secret_name)
      in
      let secret =
        match with_comments, line_number with
        | true, None -> plaintext
        | true, Some ln -> get_line_exn plaintext ln
        | false, _ ->
          let secret =
            try Secret.Validation.parse_exn plaintext
            with exn -> Shell.die ~exn "E: failed to parse %s" (show_name secret_name)
          in
          let kind = secret.kind in
          (* we can have this validation only here because we don't have expected kinds when using the cat command
              (the with_comments = true branch) *)
          (match Option.is_some expected_kind && Option.get expected_kind <> kind with
          | true ->
            Shell.die "E: %s is expected to be a %s secret but it is a %s secret" (show_name secret_name)
              (Secret.kind_to_string @@ Option.get expected_kind)
              (Secret.kind_to_string kind)
          | false -> ());
          (match line_number with
          | None -> secret.text
          | Some ln -> get_line_exn secret.text ln)
      in
      let secret =
        match trim_new_line, String.ends_with ~suffix:"\n" secret with
        (* some of the older secrets were not trimmed before storing, so they have trailing new lines *)
        | true, true -> String.sub secret 0 (String.length secret - 1)
        | false, false -> sprintf "%s\n" secret
        | true, false | false, true -> secret
      in
      secret
  end
end
