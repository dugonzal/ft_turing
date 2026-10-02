(* Contrato del shell: en que se puede convertir argv y quien decide el codigo
   de salida. `action_of_arguments` sale a proposito: es la parte que se puede
   probar sin lanzar el ejecutable. *)
type action =
  | Help
  | Run of { description : string; input : string }
  | Complexity of { description: string; inputs: string list }

val action_of_arguments : string list -> (action, string) result

val main : string list -> int
