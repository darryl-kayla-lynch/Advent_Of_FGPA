open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Aofgpa_day_1_ticker = Hardcaml_demo_project.Aofgpa_day_1_ticker
module Harness = Cyclesim_harness.Make (Aofgpa_day_1_ticker.I) (Aofgpa_day_1_ticker.O)

(* Run the number of cycles required for the ticker to finish ticking *)
let rec tick_down combo sim =
  let cycle ?n () = Cyclesim.cycle ?n sim in
  if combo = 0 then (
    cycle(); 
  )
  else
    if combo < 0 then (
      cycle();
      tick_down (combo + 1) sim
    )
    else(
      cycle();
      tick_down (combo - 1) sim
    )

(* Feed an individual character to the input *)
let feed_char char (sim : Harness.Sim.t) = 
  let inputs = Cyclesim.inputs sim in
  let cycle ?n () = Cyclesim.cycle ?n sim in
  inputs.data_in := Bits.of_int_trunc ~width:16 (Char.to_int char);
  cycle()

let simple_testbench (sim : Harness.Sim.t) =
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let cycle ?n () = Cyclesim.cycle ?n sim in
  (* Feed one line to the input *)
  let feed_line str =
    (* Convert the line to a number so the simulator knows how many cycles the ticker will run for *)
    let first = str.[0] in
    let rest = String.sub str ~pos:1 ~len:(String.length str - 1) in
    let raw_n = Int.of_string rest in
    let n = 
      match first with
        | 'R' -> raw_n
        | 'L' -> raw_n - (2 * raw_n)
        | _ -> 0
    in
    inputs.data_in_valid := Bits.vdd;
    (* Feed every character of the line to the hardware individually *)
    String.iter str ~f:(fun c -> feed_char c sim);
    (* Feed a newline so the state machine knows the input has ended*)
    feed_char '\n' sim;
    cycle ();
    inputs.data_in_valid := Bits.gnd;
    cycle ();
    (* Now that the number of ticks has feed into the machine we let it run the ticker for n cycles *)
    tick_down (n) sim;
  in
  let filename = "./input.txt" in
  let lines = In_channel.read_lines filename in
  inputs.clear := Bits.vdd;
  cycle ();
  inputs.clear := Bits.gnd;
  cycle ();
  inputs.start := Bits.vdd;
  cycle ();
  inputs.start := Bits.gnd;
  List.iter lines ~f:(fun x -> feed_line x);
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  (* Wait for result to become valid *)
  while not (Bits.to_bool !(outputs.eoz_out.valid)) do
    cycle ()
  done;

  let eoz = Bits.to_unsigned_int !(outputs.eoz_out.value) in
  let loz = Bits.to_unsigned_int !(outputs.loz_out.value) in
  print_s [%message "Ended on zero (part 1 solution):  " (eoz : int)];
  print_s [%message "Landed on zero (part 2 solution): " (loz : int)];
;;
let waves_config = Waves_config.no_waves

let%expect_test "Simple test with no waves saved / printed" =
  Harness.run_advanced ~waves_config ~create:Aofgpa_day_1_ticker.hierarchical simple_testbench;
  [%expect {|
    ("Ended on zero (part 1 solution):  " (eoz 1081))
    ("Landed on zero (part 2 solution): " (loz 6689))
    |}]
;;

let%expect_test "Simple test with printing waveforms directly" =
  let display_rules =
    [ Display_rule.port_name_matches
        ~wave_format:(Bit_or Unsigned_int)
        (Re.Glob.glob "aofgpa_day_1_ticker*" |> Re.compile)
    ]
  in
  Harness.run_advanced
    ~create:Aofgpa_day_1_ticker.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:30
        ~display_width:92
        ~wave_width:1
        waves)
    simple_testbench;
  [%expect
    {|
    ("Ended on zero (part 1 solution):  " (eoz 1081))
    ("Landed on zero (part 2 solution): " (loz 6689))
    ┌Signals─────────────────────┐┌Waves───────────────────────────────────────────────────────┐
    │                            ││────────────┬───────────────────┬───┬───┬───┬───┬───┬───┬───│
    │aofgpa_day_1_ticker$combo   ││ 0          │50                 │51 │52 │53 │54 │55 │56 │57 │
    │                            ││────────────┴───────────────────┴───┴───┴───┴───┴───┴───┴───│
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$ended_on││ 0                                                          │
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$i$clear ││────┐                                                       │
    │                            ││    └───────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$i$clock ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ │
    │                            ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─│
    │                            ││────────────┬───┬───┬───┬───────────────────────────────────│
    │aofgpa_day_1_ticker$i$data_i││ 0          │82 │52 │56 │10                                 │
    │                            ││────────────┴───┴───┴───┴───────────────────────────────────│
    │aofgpa_day_1_ticker$i$data_i││            ┌───────────────────┐                           │
    │                            ││────────────┘                   └───────────────────────────│
    │aofgpa_day_1_ticker$i$finish││                                                            │
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$i$start ││        ┌───┐                                               │
    │                            ││────────┘   └───────────────────────────────────────────────│
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$landed_o││ 0                                                          │
    │                            ││────────────────────────────────────────────────────────────│
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$left_rig││ 0                                                          │
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$o$eoz_ou││                                                            │
    │                            ││────────────────────────────────────────────────────────────│
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$o$eoz_ou││ 0                                                          │
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$o$loz_ou││                                                            │
    │                            ││────────────────────────────────────────────────────────────│
    │                            ││────────────────────────────────────────────────────────────│
    │aofgpa_day_1_ticker$o$loz_ou││ 0                                                          │
    │                            ││────────────────────────────────────────────────────────────│
    │                            ││────────────┬───────────────────────────────────────────────│
    │aofgpa_day_1_ticker$ten     ││ 0          │10                                             │
    │                            ││────────────┴───────────────────────────────────────────────│
    │                            ││────────────────────┬───┬───────┬───┬───┬───┬───┬───┬───┬───│
    │aofgpa_day_1_ticker$ticks   ││ 0                  │4  │48     │47 │46 │45 │44 │43 │42 │41 │
    │                            ││────────────────────┴───┴───────┴───┴───┴───┴───┴───┴───┴───│
    └────────────────────────────┘└────────────────────────────────────────────────────────────┘
    |}]
;;
