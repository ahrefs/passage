%{
   open Template_ast

   let merge_consec_text_nodes ast =
     List.fold_left
       (fun acc node ->
         match acc, node with
         | Text prev :: tl, Text s -> Text (prev ^ s) :: tl
         | _ -> node :: acc)
       [] ast
     |> List.rev
 %}

 %token <string> IDEN
 %token <string> TEXT
 %token EOF

 %start <Template_ast.ast> template

 %%
 template:
   | ast = list(ast_nodes); EOF { merge_consec_text_nodes ast }

 ast_nodes:
   | i = IDEN                   { Iden i }
   | t = TEXT                   { Text t }
