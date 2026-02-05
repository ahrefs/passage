val parse : string -> Template_ast.ast
val parse_file : Path.t -> Template_ast.ast
val substitute_all : ?use_sudo:bool -> Template_ast.ast -> (Template_ast.ast_node list, (string * string) list) result
val build_text_from_ast : Template_ast.ast_node list -> string
