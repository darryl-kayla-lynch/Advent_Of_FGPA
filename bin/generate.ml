open! Core
open! Hardcaml
open! Hardcaml_demo_project

let generate_aofgpa_day_1_ticker_rtl () =
  let module C = Circuit.With_interface (Aofgpa_day_1_ticker.I) (Aofgpa_day_1_ticker.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"aofgpa_day_1_ticker_top" (Aofgpa_day_1_ticker.hierarchical scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  let rtl = Rtl.full_hierarchy rtl_circuits |> Rope.to_string in
  print_endline rtl
;;

let aofgpa_day_1_ticker_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_aofgpa_day_1_ticker_rtl ()]
;;

let () =
  Command_unix.run
    (Command.group ~summary:"" [ "aofgpa_day_1_ticker", aofgpa_day_1_ticker_rtl_command ])
;;
