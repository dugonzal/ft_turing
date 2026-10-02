(* El shell del ejecutable: convierte argv en una ACCION, la ejecuta y decide el
   codigo de salida. El formato de lo que se imprime es cosa de Render; aqui solo
   se ordena y se traduce a un numero. *)

type action =
  | Help
  | Run of { description : string; input : string }
  | Complexity of { description: string; inputs: string list }

let is_help = function "-h" | "--help" -> true | _ -> false

(* Los dos usos validos: `--help` en cualquier posicion, o `descripcion entrada`.
   Todo lo demas es error de uso, con el texto de Constant. Se decide UNA vez, asi
   que el `-h` tiene un solo camino (antes habia dos y uno era inalcanzable). *)
let action_of_arguments (argv : string list) : (action, string) result =
  if List.exists is_help argv then Ok Help
  else
    match argv with
    | _ :: "--complexity" :: description :: (_ :: _ :: _ as inputs) ->
        Ok (Complexity { description; inputs })
    | _ :: "--complexity" :: _ -> Error Constant.too_few_inputs
    | [ _; description; input ] -> Ok (Run { description; input })
    | _ :: _ :: _ :: _ -> Error Constant.too_many_args
    | _ -> Error Constant.too_few_args

(* 0 = hubo veredicto (ACCEPTED o BLOCKED: el atasco es un desenlace normal que la
   letra pide informar). 1 = no lo hubo. La letra no pide ningun codigo. *)
let exit_code_of_status = function
  | Executor.Timed_out -> 1
  | Executor.Accepted | Executor.Blocked -> 0

let simulate (machine : Type.machine) (input : string) : int =
  Render.print_header machine;
  let initial = Executor.initial machine ~input in
  let status, final, trace = Executor.run_traced machine initial in
  Render.print_trace trace;
  Render.print_outcome status final;
  exit_code_of_status status

let calculate (description: string) (input: string) : int * int * Executor.status =
  let machine = Parse.parse_file description input in
  let status, final = Executor.run machine (Executor.initial machine ~input) in
  (String.length input, Executor.steps final, status)

let exponents (points: (int * int * Executor.status) list): (int * int * Executor.status * float option) list =
  let add_row (last, table) (n, steps, status) =
    match status, last with
    | Executor.Accepted, Some (last_n, last_steps) ->
      let k = log (float steps /. float last_steps) /. log (float n /. float last_n) in
      (Some (n, steps), (n, steps, status, Some k) :: table)
    | Executor.Accepted, None ->
      (Some (n, steps), (n, steps, status, None) :: table)
    | _ -> (last, (n, steps, status, None) :: table)
  in
  List.rev (snd (List.fold_left add_row (None, []) points))

let complexity (description: string) (inputs: string list) : int =
  let points = List.map (calculate description) inputs in
  let sorted =
    List.sort_uniq (fun (n1, _, s1) (n2, _, s2) -> compare (n1, s1) (n2, s2)) points
  in
  let rows = exponents sorted in
  Render.print_table rows;
  Render.print_complexity rows;
  0

(* La frontera de errores. El parser revienta (`failwith` y las excepciones de
   Yojson), y es aqui donde se convierte en un mensaje; nunca un backtrace. *)
let run (description : string) (input : unit -> int) : int =
  if not (Sys.file_exists description) then begin
    Printf.eprintf "%s: %s: no such file\n" Constant.program_name description;
    1
  end
  else if Sys.is_directory description then begin
    Printf.eprintf "%s: %s: is a directory, not a json file\n"
      Constant.program_name description;
    1
  end
  else
    try input() with
    | Yojson.Json_error message ->
        Printf.eprintf "%s: %s: invalid json (%s)\n" Constant.program_name
          description message;
        1
    | Yojson.Basic.Util.Type_error (message, _) | Failure message ->
        Printf.eprintf "%s: %s; %s\n" Constant.program_name Constant.error message;
        1

let main (argv : string list) : int =
  match action_of_arguments argv with
  | Error message ->
      Printf.eprintf "%s" message;
      1
  | Ok Help ->
      Print.print_help ();
      0
  | Ok (Run { description; input }) ->
      run description (fun () -> simulate (Parse.parse_file description input) input)
  | Ok (Complexity { description; inputs }) ->
      run description (fun () -> complexity description inputs)
