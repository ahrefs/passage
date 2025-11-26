val validate_secret : string -> (string, string) result
val validate_comments : string -> (string, string) result
val validate_recipients_for_editing : string list -> (unit, string) result
val validate_recipients_for_commands : string list -> (unit, string) result
