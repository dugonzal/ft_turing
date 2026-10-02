let program_name: string = "ft_turing"
let error: string = "Error"

let read: string = "read"
let write: string = "write"
let to_state: string = "to_state"
let action: string = "action"
let transitions: string = "transitions"
let states: string = "states"
let alphabet: string = "alphabet"
let name: string = "name"
let blank: string = "blank"
let initial: string = "initial"
let finals: string = "finals"

let too_few_args: string = program_name ^ ": " ^ error ^ "; The program must have at least two arguments\n"
let too_many_args: string = program_name ^ ": " ^ error ^ "; Too many arguments\n"
let too_few_inputs: string = program_name ^ ": " ^ error ^ "; --complexity needs a JSON description and at least two inputs\n"
let unrecognized_opt: string = program_name ^ ": " ^ error ^ "; Unrecognized option\n"
let not_a_character: string = "must be a character"
let not_valid_alphabet: string = "value is not a valid alphabet character"
let must_not_be_blank: string = "value must not be the same as the blank character"
let not_valid_state: string = "value is not a valid state"
let not_valid_action: string = "action is not valid"
let undeclared_transition_state: string = "is not a declared state"
let duplicated_transition: string = "more than one rule for this state and read symbol"

let hasht_initial_size: int = 16

let decorator: string = "********************************************************************************
*                                                                              *
*                                 unary_sub                                    *
*                                                                              *
********************************************************************************
"

let help_text: string = "usage: " ^ program_name ^ " [-h] jsonfile input
       " ^ program_name ^ " --complexity jsonfile input1 input2 [input3 ...]

positional arguments:
  jsonfile            json description of the machine

  input               input of the machine

optional arguments:
  -h, --help          show this help message and exit
  --complexity        estimate time complexity based on a set of inputs\n"