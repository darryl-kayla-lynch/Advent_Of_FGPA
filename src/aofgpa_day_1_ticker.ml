open! Core
open! Hardcaml
open! Signal

let num_bits = 16

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; data_in : 'a [@bits num_bits]
    ; data_in_valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { eoz_out : 'a With_valid.t [@bits num_bits]
    ; loz_out : 'a With_valid.t [@bits num_bits]
    }
  [@@deriving hardcaml]
end

module States = struct
  type t =
    | Idle
    | Accepting_inputs
    | Ticking
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create scope ({ clock; clear; start; finish; data_in; data_in_valid } : _ I.t) : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let open Always in
  let sm =
    State_machine.create (module States) spec
  in

  (* Constants*)
  let left = 1 in
  let right = 0 in
  (* Registers *)
  let%hw_var combo = Variable.reg spec ~width:num_bits in
  let%hw_var ticks = Variable.reg spec ~width:num_bits in
  let%hw_var left_right = Variable.reg spec ~width:num_bits in
  let%hw_var landed_on_zero = Variable.reg spec ~width:num_bits in
  let%hw_var ended_on_zero = Variable.reg spec ~width:num_bits in
  let%hw_var ten = Variable.reg spec ~width:num_bits in
  (* Wires*)
  let eoz_out = Variable.wire ~default:(zero num_bits) () in
  let eoz_out_valid = Variable.wire ~default:gnd () in
  let loz_out = Variable.wire ~default:(zero num_bits) () in
  let loz_out_valid = Variable.wire ~default:gnd () in

  let%hw_var in_accepting_inputs = Variable.reg spec ~width:num_bits in
  compile
    [ sm.switch
        [ ( Idle
          , [ when_
                start
                [ combo <-- Signal.of_int_trunc ~width:num_bits 50
                ; ticks <-- Signal.of_int_trunc ~width:num_bits 0
                ; ten <-- Signal.of_int_trunc ~width:num_bits 10
                ; sm.set_next Accepting_inputs
                ]
            ] )
        ; ( Accepting_inputs
          , [ when_
                data_in_valid
                [ 

                (* Match against ASCII codes for 'L' and 'R' *)
                when_ (data_in ==+. 0x4C) [
                  left_right <--. left;
                ]; 

                when_ (data_in ==+. 0x52) [
                  left_right <--. right;
                ];

                (* When in the range of '0' and '9' we mutiply current ticks by 10 and add our new value *)
                when_ ((data_in >=+. 0x30) &: (data_in <=+. 0x39)) [
                  let mul = (ticks.value *: ten.value) in
                  let mul_narrowed = uresize mul ~width:num_bits in 
                  ticks <-- (mul_narrowed +: (data_in -:. 0x30))
                ];

                (* Use '\n' as a way to signal the end of the string, and set L movement to negative ticks *)
                when_ (data_in ==+. 0x0A) [

                  when_ (left_right.value ==+. left) 
                  [
                    ticks <-- (~:(ticks.value) +:. 1)
                  ; sm.set_next Ticking
                  ];

                 when_ (left_right.value ==+. right) 
                  [
                    ticks <-- ticks.value
                  ; sm.set_next Ticking
                  ]

                ]

                ]
            ; when_ finish 
              [ 
              in_accepting_inputs <-- zero num_bits
              ; sm.set_next Done
              ]
            ] )
          ; ( Ticking
          , [ 

                  (* Increment the combo and decrement the ticker (or vice versa) until there are no more ticks left *)
                  (* while also taking care of wrapping logic and tracking when the combo hits zero *)
                  when_ (ticks.value >+. 0) 
                  [ ticks <-- ticks.value -:. 1
                  ; when_ ((combo.value +:. 1) >=+. 100) [combo <--. 0; landed_on_zero <-- landed_on_zero.value +:. 1]
                  ; when_ ((combo.value +:. 1) <+. 100) [combo <-- combo.value +:. 1]
                  ; sm.set_next Ticking 
                  ]
                              
                ; when_ (ticks.value <+. 0) 
                  [ ticks <-- ticks.value +:. 1
                  ; when_ ((combo.value -:. 1) <+.  0) [combo <--. 99]
                  ; when_ ((combo.value -:. 1) ==+. 0) [combo <--. 0; landed_on_zero <-- landed_on_zero.value +:. 1 ]
                  ; when_ ((combo.value -:. 1) >+.  0) [combo <-- combo.value -:. 1]
                  ; sm.set_next Ticking 
                  ]

                ; when_ (ticks.value ==:. 0) 
                 [ when_ (combo.value ==+. 0) 
                    [ ended_on_zero <-- ended_on_zero.value +:. 1 ]
                 ; sm.set_next Accepting_inputs 
                 ] 
            ] )
        ; ( Done
          , [ eoz_out <-- ended_on_zero.value
            ; eoz_out_valid <-- vdd
            ; loz_out <-- landed_on_zero.value
            ; loz_out_valid <-- vdd
            ; when_ finish [ sm.set_next Accepting_inputs ]
            ] )
        ]
    ];

  { 
    eoz_out = { value = ended_on_zero.value; valid = eoz_out_valid.value }
  ; loz_out = { value = landed_on_zero.value; valid = loz_out_valid.value }
  }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"aofgpa_day_1_ticker" create
;;
