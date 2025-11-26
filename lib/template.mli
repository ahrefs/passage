val parse : string -> Template_ast.ast
val parse_file : Path.t -> Template_ast.ast
val substitute_iden : ?use_sudo:bool -> Template_ast.ast_node -> Template_ast.ast_node
val build_text_from_ast : Template_ast.ast_node list -> string
