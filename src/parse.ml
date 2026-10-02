open Yojson.Basic.Util

let to_symbol (s: string): char = 
  if String.length s <> 1 then
    failwith Constant.not_a_character
  else
    s.[0]

let to_action (s: string): Type.action =
  match s with
  | "LEFT" -> Type.Left
  | "RIGHT" -> Type.Right
  | s -> failwith (Constant.not_valid_action ^ s)

let parse_transition (states: Type.state list) (alphabet: Type.symbol list) (t: Yojson.Basic.t): Type.transition =
  {
    read = (
      let value = t |> member Constant.read |> to_string |> to_symbol in
      if not (List.mem value alphabet) then failwith ("[read] " ^ Constant.not_valid_alphabet)
      else value
    );
    write = (
      let value = t |> member Constant.write |> to_string |> to_symbol in
      if not (List.mem value alphabet) then failwith ("[write] " ^ Constant.not_valid_alphabet)
      else value
    );
    to_state = (
      let value = t |> member Constant.to_state |> to_string in
      if not (List.mem value states) then failwith ("[to_state] " ^ Constant.not_valid_state)
      else value
    );
    action = t |> member Constant.action |> to_string |> to_action;
  }

(* 
  For the sake of simplicity, I've decided to briefly explain what this function does in a visual way:

  1. Take the member "transitions" from the JSON and transform it to an object (to_assoc)
  2. use the List.fold_left which works as an accumulator function iterating all over the list, args are;
    1 - fun accumulator tuple
    2 - Initial accumulator value
    3 - the list to apply it to.

  The outer fold_left operates over the following args:
    1 - fun map (state_name(which is the name of the transition e.g. "scanright"), 
                 transitions_json(which is the content of each state e.g 
                  [
                    { "read" : "1", "to_state": "subone", "write": "=", "action": "LEFT"},
                    { "read" : "-", "to_state": "HALT" , "write": ".", "action": "LEFT"}
                  ]))
    2 - Type.StateMap.empty
    3 - the whole content of transitions as a list of tuples, e.g 
        [...
        ("eraseone", [
            { "read" : "1", "to_state": "subone", "write": "=", "action": "LEFT"},
            { "read" : "-", "to_state": "HALT" , "write": ".", "action": "LEFT"}
        ]);
        ("subone", [
            { "read" : "1", "to_state": "subone", "write": "1", "action": "LEFT"},
            { "read" : "-", "to_state": "skip" , "write": "-", "action": "LEFT"}
        ])
        ...]

    3. Then, it calls an inner fold_left to add the content of each state to the "transitions" map. 
       It works in the same way, but iterates over each inner transition (the content of each state_name)

    Dos cosas se rechazan aqui, y no se dejan para que las resuelva el mapa: un estado
    que aparece como clave y no esta declarado en "states", y una segunda regla para el
    mismo par (estado, simbolo). El motor es determinista, asi que un StateMap al que
    se le solapan claves solo haria que ganase la ultima en silencio.
*)
let parse_transitions (states: Type.state list) (alphabet: Type.symbol list) (json: Yojson.Basic.t): Type.transition Type.StateMap.t =
  json |> member Constant.transitions |> to_assoc
  |> List.fold_left
       (fun map (state_name, transitions_json) ->
          if not (List.mem state_name states) then
            failwith
              (Printf.sprintf "[transitions] %s %s" state_name
                 Constant.undeclared_transition_state);
          transitions_json |> to_list |> List.map (parse_transition states alphabet)
          |> List.fold_left
               (fun map (t : Type.transition) ->
                  let key = (state_name, t.read) in
                  if Type.StateMap.mem key map then
                    failwith
                      (Printf.sprintf "[transitions] (%s, %c) %s" state_name
                         t.read Constant.duplicated_transition);
                  Type.StateMap.add key t map)
               map)
       Type.StateMap.empty

let parse_rules (states: Type.state list) (alphabet: Type.symbol list) (json: Yojson.Basic.t): (Type.state * Type.transition list) list =
  json |> member Constant.transitions |> to_assoc
  |> List.map (fun (state_name, transitions_json) ->
         (state_name, transitions_json |> to_list |> List.map (parse_transition states alphabet)))

let rec check_list_dups (lst: Yojson.Basic.t list) =
  match lst with
  | [] | [_] -> false
  | x :: rest -> List.mem x rest || check_list_dups rest

(* Un objeto es una regla, no un simbolo: dos reglas identicas en campos son dos
   reglas legitimas (mismo comportamiento, distinto par leido), y el motor las
   distingue por la posicion. Repetir un simbolo, en cambio, si es un error, y
   para eso esta la comparacion estructural. *)
let has_object (lst: Yojson.Basic.t list) =
  List.exists (fun item -> match item with `Assoc _ | `List _ -> true | _ -> false) lst

(* I made this function recursive for it to check elements inside JSON objects aswell *)
let rec check_duplicate_keys (json: Yojson.Basic.t): unit =
  (try
      let fields = to_assoc json in
      let seen = Hashtbl.create Constant.hasht_initial_size in
      List.iter
        (fun (key, value) ->
          if Hashtbl.mem seen key then
            failwith ("duplicate key: " ^ key);
          Hashtbl.add seen key ();
          check_duplicate_keys value)
        fields
    with Type_error _ -> ());
  (try
      let items = to_list json in
      if (not (has_object items)) && check_list_dups items then
        failwith ("duplicate elements in list");
      List.iter check_duplicate_keys items
    with Type_error _ -> ())

let parse_file (fname: string) (input: string): Type.machine =
  let json = Yojson.Basic.from_file fname in
  check_duplicate_keys json;
  let states = json |> member Constant.states |> to_list |> List.map to_string in
  let alphabet = json |> member Constant.alphabet |> to_list |> List.map to_string |> List.map to_symbol in
  let machine : Type.machine = {
    name = json |> member Constant.name |> to_string;
    alphabet;
    blank = (
      let value = json |> member Constant.blank |> to_string |> to_symbol in
      if not (List.mem value alphabet) then failwith ("[blank] " ^ Constant.not_valid_alphabet)
      else value
    );
    states;
    initial = (
      let value = json |> member Constant.initial |> to_string in
      if not (List.mem value states) then failwith ("[initial] " ^ Constant.not_valid_state)
      else value
    );
    finals =  (
      let value = json |> member Constant.finals |> to_list |> List.map to_string in
      if not (List.for_all (fun elem -> List.mem elem states) value) then failwith ("[finals] " ^ Constant.not_valid_state)
      else value
    );
    transitions = parse_transitions states alphabet json;
    rules = parse_rules states alphabet json;
  } in
  String.iter
    (fun c ->
        if not (List.mem c machine.alphabet) then failwith ("[input] " ^ Constant.not_valid_alphabet);
        if (c = machine.blank) then failwith ("[input] " ^ Constant.must_not_be_blank)
    )
    input;
  machine