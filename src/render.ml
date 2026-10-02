(* El formato de salida lo exige el enunciado: aqui se pinta, el nucleo calcula. *)

let symbol_text symbol = String.make 1 symbol

let action_to_string = function
  | Type.Left -> "LEFT"
  | Type.Right -> "RIGHT"

let status_to_string = function
  | Executor.Accepted -> "ACCEPTED"
  | Executor.Blocked -> "BLOCKED"
  | Executor.Timed_out -> "TIMED_OUT"

let tape_to_string tape =
  let cells = Tape.to_list tape in
  let head = Tape.head_index tape in
  let mark index cell =
    if index = head then "<" ^ String.make 1 cell ^ ">" else String.make 1 cell
  in
  String.concat "" (List.mapi mark cells)

(* 20 celdas, cabezal marcado, rellenas con blancos: una llamada por paso. *)
let window ?(width = 20) tape =
  let left_cells = Tape.left_of (width - 1) tape in
  let head_position = List.length left_cells in
  let right_cells = Tape.right_of (width - 1 - head_position) tape in
  let cells = left_cells @ (Tape.read tape :: right_cells) in
  let padding = List.init (width - List.length cells) (fun _ -> Tape.blank tape) in
  let mark index cell =
    if index = head_position then "<" ^ String.make 1 cell ^ ">"
    else String.make 1 cell
  in
  "[" ^ String.concat "" (List.mapi mark (cells @ padding)) ^ "]"

let banner_width = 80
let box_width = banner_width - 2
let stars = String.make banner_width '*'

let centered width text =
  let space = width - String.length text in
  if space <= 0 then text
  else
    let left = (space + 1) / 2 in
    String.make left ' ' ^ text ^ String.make (space - left) ' '

let bracket_list items = "[ " ^ String.concat ", " items ^ " ]"

let print_banner name =
  let empty_line = "*" ^ String.make box_width ' ' ^ "*" in
  print_endline stars;
  print_endline empty_line;
  print_endline ("*" ^ centered box_width name ^ "*");
  print_endline empty_line;
  print_endline stars

let print_description (machine : Type.machine) =
  Printf.printf "Alphabet: %s\n"
    (bracket_list (List.map symbol_text machine.Type.alphabet));
  Printf.printf "States : %s\n" (bracket_list machine.Type.states);
  Printf.printf "Initial : %s\n" machine.Type.initial;
  Printf.printf "Finals : %s\n" (bracket_list machine.Type.finals)

let format_rule state read transition =
  Printf.sprintf "(%s, %c) -> (%s, %c, %s)" state read
    transition.Type.to_state transition.Type.write
    (action_to_string transition.Type.action)

(* El orden lo manda el enunciado: los estados como vienen en el fichero. El Map
   esta indexado por (estado, simbolo) y devolveria orden de clave. *)
let rules_in_dump_order (machine : Type.machine) =
  List.concat_map
    (fun state ->
      match List.assoc_opt state machine.Type.rules with
      | None -> []
      | Some transitions -> List.map (fun t -> (state, t)) transitions)
    machine.Type.states

let print_rules (machine : Type.machine) =
  List.iter
    (fun (state, transition) ->
      print_endline (format_rule state transition.Type.read transition))
    (rules_in_dump_order machine)

let print_header (machine : Type.machine) =
  print_banner machine.Type.name;
  print_description machine;
  print_rules machine;
  print_endline stars

let print_trace (trace : (Executor.configuration * Type.transition) list) =
  List.iter
    (fun (configuration, transition) ->
      let tape = Executor.tape configuration in
      Printf.printf "%s %s\n" (window tape)
        (format_rule (Executor.state configuration) (Tape.read tape) transition))
    trace

let print_outcome (status : Executor.status) (final : Executor.configuration) =
  let tape = Executor.tape final in
  Printf.printf "status: %s\n" (status_to_string status);
  Printf.printf "steps: %d\n" (Executor.steps final);
  Printf.printf "tape: %s\n" (tape_to_string tape);
  match status with
  | Executor.Blocked ->
      Printf.printf "blocked: no transition for (%s, %c)\n"
        (Executor.state final) (Tape.read tape)
  | Executor.Timed_out ->
      Printf.printf
        "timed out: the machine did not halt within its step budget\n"
  | Executor.Accepted -> ()

let print_table (rows: (int * int * Executor.status * float option) list): unit =
  Printf.printf "%-8s %-10s %-10s %s\n" "n" "steps" "status" "k";
  List.iter
    (fun (n, steps, status, k) ->
      let k_text =
        match status, k with
        | Executor.Accepted, Some k -> Printf.sprintf "%.2f" k
        | Executor.Accepted, None -> "-"
        | _ -> "excluded"
      in
      Printf.printf "%-8d %-10d %-10s %s\n" n steps (status_to_string status) k_text)
    rows

let print_complexity (rows: (int * int * Executor.status * float option) list): unit =
  let last_k = List.fold_left (fun last (_, _, _, k) -> match k with Some _ -> k | None -> last) None rows in
  match last_k with
    | None -> print_string "complexity: not enough accepted inputs\n"
    | Some k ->
      (match Float.to_int (Float.round k) with
       | 0 -> print_string "complexity: O(1)\n"
       | 1 -> print_string "complexity: O(n)\n"
       | d -> Printf.printf "complexity: O(n^%d)\n" d)
