open! Base
open Hardcaml
open Hardcaml_waveterm

module Make_bench (Config : Knob_pwm.Top.Config) = struct
  module Top = Knob_pwm.Top.Make (Config)
  module Sim = Cyclesim.With_interface (Top.I) (Top.O)

  let sequence = [| 1, 1; 0, 1; 0, 0; 1, 0 |]
  (* A pin change reaches the outputs [debounce_cycles + 3] clocks later. One
     spare clock keeps edges on even cycles, which draw cleanly at two clocks
     per column. *)
  let hold = Config.debounce_cycles + 4

  type t =
    { sim : (Bits.t ref Top.I.t, Bits.t ref Top.O.t) Cyclesim.t
    ; waves : Waveform.t
    ; mutable index : int
    }

  let run t n =
    for _ = 1 to n do
      Cyclesim.cycle t.sim
    done
  ;;

  let drive t =
    let i : _ Top.I.t = Cyclesim.inputs t.sim in
    let a, b = sequence.(t.index) in
    i.enc_a := Bits.of_int ~width:1 a;
    i.enc_b := Bits.of_int ~width:1 b
  ;;

  let create () =
    let sim = Sim.create (Top.create (Scope.create ~flatten_design:true ())) in
    let waves, sim = Waveform.create sim in
    let t = { sim; waves; index = 0 } in
    drive t;
    run t 6;
    t
  ;;

  let step ?(hold = hold) t ~forward =
    t.index <- (t.index + if forward then 1 else 3) % 4;
    drive t;
    run t hold
  ;;

  let click t ~forward =
    for _ = 1 to Config.steps_per_click do
      step t ~forward
    done
  ;;

  let press t =
    let i : _ Top.I.t = Cyclesim.inputs t.sim in
    i.enc_button := Bits.vdd;
    run t (2 * hold);
    i.enc_button := Bits.gnd;
    run t (2 * hold)
  ;;

  let target t =
    let o : _ Top.O.t = Cyclesim.outputs t.sim in
    Bits.to_int !(o.target)
  ;;

  let duty t =
    let o : _ Top.O.t = Cyclesim.outputs t.sim in
    Bits.to_int !(o.duty)
  ;;
end

(* 4-bit duty (period 15 clocks), 4 periods per ramp, steps of 1 or 4. *)
module Bench = Make_bench (struct
    let width = 4
    let interp_log2 = 2
    let debounce_cycles = 2
    let steps_per_click = 4
    let fine_step = 1
    let coarse_step = 4
  end)

let%expect_test "two fine clicks, a button press, a coarse click" =
  let t = Bench.create () in
  Bench.click t ~forward:true;
  Bench.click t ~forward:true;
  Bench.press t;
  Bench.click t ~forward:true;
  Bench.run t 70;
  Waveform.print
    t.waves
    ~display_rules:
      Display_rule.
        [ port_name_is_one_of [ "enc_a"; "enc_b"; "enc_button"; "coarse" ] ~wave_format:Bit
        ; port_name_is_one_of [ "target"; "duty" ] ~wave_format:Unsigned_int
        ]
    ~display_width:104
    ~display_height:16
    ~signals_width:12
    ~wave_width:(-2);
  [%expect {|
    ┌Signals───┐┌Waves─────────────────────────────────────────────────────────────────────────────────────┐
    │enc_a     ││───┐     ┌─────┐     ┌─────────────────┐     ┌────────────────────────────────────────    │
    │          ││   └─────┘     └─────┘                 └─────┘                                            │
    │enc_b     ││──────┐     ┌─────┐     ┌─────────────────┐     ┌─────────────────────────────────────    │
    │          ││      └─────┘     └─────┘                 └─────┘                                         │
    │enc_button││                           ┌─────┐                                                        │
    │          ││───────────────────────────┘     └────────────────────────────────────────────────────    │
    │coarse    ││                             ╥────────────────────────────────────────────────────────    │
    │          ││─────────────────────────────╨                                                            │
    │          ││─────────────────────────────────────╥──────────────╥───────┬──────╥───────┬──────────    │
    │duty      ││ 0                                   ║ 1            ║ 2     │3     ║ 4     │6             │
    │          ││─────────────────────────────────────╨──────────────╨───────┴──────╨───────┴──────────    │
    │          ││──────────────╥───────────╥───────────────────────╥───────────────────────────────────    │
    │target    ││ 0            ║ 1         ║ 2                     ║ 6                                     │
    │          ││──────────────╨───────────╨───────────────────────╨───────────────────────────────────    │
    └──────────┘└──────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "the target sticks at 0 and at full scale" =
  let t = Bench.create () in
  let show label = Stdio.printf "%-28s target %2d\n" label (Bench.target t) in
  Bench.click t ~forward:false;
  show "click down from 0";
  Bench.press t;
  for _ = 1 to 5 do
    Bench.click t ~forward:true;
    show "coarse click up"
  done;
  Bench.press t;
  Bench.click t ~forward:false;
  show "fine click down";
  Bench.run t 80;
  Stdio.printf "duty once settled: %d\n" (Bench.duty t);
  [%expect {|
    click down from 0            target  0
    coarse click up              target  4
    coarse click up              target  8
    coarse click up              target 12
    coarse click up              target 15
    coarse click up              target 15
    fine click down              target 14
    duty once settled: 14
    |}]
;;

let%expect_test "the configuration used for the Verilog: one click is +16" =
  let module B = Make_bench (Knob_pwm.Top.Default_config) in
  let t = B.create () in
  (* Let the debouncers settle on the resting pin levels first. *)
  B.run t (1 lsl 17);
  for _ = 1 to 3 do
    B.step t ~forward:true
  done;
  (* Last step of the click: stop as soon as the target moves. *)
  B.step t ~forward:true ~hold:0;
  while B.target t = 0 do
    B.run t 1
  done;
  let target = B.target t in
  let period = 4095 in
  let duties = Queue.create () in
  for _ = 1 to 17 do
    Queue.enqueue duties (B.duty t);
    B.run t period
  done;
  let duties = Queue.to_list duties in
  Stdio.printf
    "target %d\nduty once per period: %s\n"
    target
    (List.map duties ~f:Int.to_string |> String.concat ~sep:" ");
  [%expect {|
    target 16
    duty once per period: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
    |}]
;;
