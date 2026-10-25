open! Base
open Hardcaml
open Hardcaml_waveterm

module Make_bench (Config : Knob_pwm.Quadrature.Config) = struct
  module Encoder = Knob_pwm.Quadrature.Make (Config)
  module Sim = Cyclesim.With_interface (Encoder.I) (Encoder.O)

  (* Pin states in the order they appear when turning forward. The knob rests
     at index 0 (A = B = 1). *)
  let sequence = [| 1, 1; 0, 1; 0, 0; 1, 0 |]

  (* A pin change reaches the outputs [debounce_cycles + 3] clocks later:
     two for the synchronizer, the debounce, one for the position register. *)
  let hold = Config.debounce_cycles + 3

  type t =
    { sim : (Bits.t ref Encoder.I.t, Bits.t ref Encoder.O.t) Cyclesim.t
    ; waves : Waveform.t
    ; mutable index : int
    ; mutable steps : int
    }

  let drive t (a, b) =
    let i : _ Encoder.I.t = Cyclesim.inputs t.sim in
    i.a := Bits.of_int ~width:1 a;
    i.b := Bits.of_int ~width:1 b
  ;;

  let run t n =
    for _ = 1 to n do
      Cyclesim.cycle t.sim
    done
  ;;

  let create () =
    let sim = Sim.create (Encoder.create (Scope.create ~flatten_design:true ())) in
    let waves, sim = Waveform.create sim in
    let t = { sim; waves; index = 0; steps = 0 } in
    drive t sequence.(0);
    t
  ;;

  (* Move one step. With [bounce], the pin that changes chatters back to its
     old level for one clock, [bounce] times, before it settles. *)
  let step ?(bounce = 0) t ~forward =
    let old_pins = sequence.(t.index) in
    t.index <- (t.index + if forward then 1 else 3) % 4;
    t.steps <- (t.steps + if forward then 1 else -1);
    let new_pins = sequence.(t.index) in
    for _ = 1 to bounce do
      drive t new_pins;
      run t 1;
      drive t old_pins;
      run t 1
    done;
    drive t new_pins;
    run t hold
  ;;

  let click ?bounce t ~forward =
    for _ = 1 to Config.steps_per_click do
      step ?bounce t ~forward
    done
  ;;

  let set_button ?(bounce = 0) t pressed =
    let i : _ Encoder.I.t = Cyclesim.inputs t.sim in
    let level = Bits.of_bool pressed in
    for _ = 1 to bounce do
      i.button := level;
      run t 1;
      i.button := Bits.( ~: ) level;
      run t 1
    done;
    i.button := level;
    run t (hold + 3)
  ;;

  let position t =
    let o : _ Encoder.O.t = Cyclesim.outputs t.sim in
    Bits.to_sint !(o.position)
  ;;
end

module Bench = Make_bench (struct
    let debounce_cycles = 2
    let steps_per_click = 4
    let position_width = 8
  end)

let display_rules =
  Display_rule.
    [ port_name_is "a" ~wave_format:Bit
    ; port_name_is "b" ~wave_format:Bit
    ; port_name_is "up" ~wave_format:Bit
    ; port_name_is "down" ~wave_format:Bit
    ; port_name_is "position" ~wave_format:Int
    ]
;;

let print (t : Bench.t) =
  Waveform.print
    t.waves
    ~display_rules
    ~display_width:116
    ~display_height:13
    ~signals_width:12
    ~wave_width:0
;;

let%expect_test "contact bounce on every edge still gives one click" =
  let t = Bench.create () in
  Bench.run t 6;
  Bench.click t ~forward:true ~bounce:2;
  Bench.run t 4;
  print t;
  [%expect {|
    ┌Signals───┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────────┐
    │a         ││────────────┐ ┌─┐ ┌─┐                           ┌─┐ ┌─┐ ┌───────────────────────────────────          │
    │          ││            └─┘ └─┘ └───────────────────────────┘ └─┘ └─┘                                             │
    │b         ││──────────────────────────────┐ ┌─┐ ┌─┐                           ┌─┐ ┌─┐ ┌─────────────────          │
    │          ││                              └─┘ └─┘ └───────────────────────────┘ └─┘ └─┘                           │
    │up        ││                                                                                  ┌─┐                 │
    │          ││──────────────────────────────────────────────────────────────────────────────────┘ └───────          │
    │down      ││                                                                                                      │
    │          ││────────────────────────────────────────────────────────────────────────────────────────────          │
    │          ││────────────────────────────────────────────────────────────────────────────────────┬───────          │
    │position  ││ 0                                                                                  │1                │
    │          ││────────────────────────────────────────────────────────────────────────────────────┴───────          │
    └──────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "turning back part way gives no click; a full click back does" =
  let t = Bench.create () in
  Bench.run t 6;
  Bench.step t ~forward:true;
  Bench.step t ~forward:true;
  Bench.step t ~forward:false;
  Bench.step t ~forward:false;
  Bench.click t ~forward:false;
  Bench.run t 4;
  print t;
  [%expect {|
    ┌Signals───┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────────┐
    │a         ││────────────┐                             ┌───────────────────┐                   ┌─────────────────  │
    │          ││            └─────────────────────────────┘                   └───────────────────┘                   │
    │b         ││──────────────────────┐         ┌───────────────────┐                   ┌───────────────────────────  │
    │          ││                      └─────────┘                   └───────────────────┘                             │
    │up        ││                                                                                                      │
    │          ││────────────────────────────────────────────────────────────────────────────────────────────────────  │
    │down      ││                                                                                          ┌─┐         │
    │          ││──────────────────────────────────────────────────────────────────────────────────────────┘ └───────  │
    │          ││────────────────────────────────────────────────────────────────────────────────────────────┬───────  │
    │position  ││ 0                                                                                          │-1       │
    │          ││────────────────────────────────────────────────────────────────────────────────────────────┴───────  │
    └──────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "button: a bouncy press gives one pulse, a bouncy release none" =
  let t = Bench.create () in
  Bench.run t 2;
  Bench.set_button t true ~bounce:3;
  Bench.set_button t false ~bounce:3;
  Waveform.print
    t.waves
    ~display_rules:
      Display_rule.
        [ port_name_is "button" ~wave_format:Bit
        ; port_name_is "button_down" ~wave_format:Bit
        ; port_name_is "pressed" ~wave_format:Bit
        ]
    ~display_width:100
    ~display_height:8
    ~signals_width:13
    ~wave_width:0;
  [%expect {|
    ┌Signals────┐┌Waves────────────────────────────────────────────────────────────────────────────────┐
    │button     ││    ┌─┐ ┌─┐ ┌─┐ ┌───────────────┐ ┌─┐ ┌─┐ ┌─┐                                        │
    │           ││────┘ └─┘ └─┘ └─┘               └─┘ └─┘ └─┘ └───────────────                         │
    │button_down││                        ┌───────────────────────────┐                                │
    │           ││────────────────────────┘                           └───────                         │
    │pressed    ││                        ┌─┐                                                          │
    │           ││────────────────────────┘ └─────────────────────────────────                         │
    └───────────┘└─────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "a missed state does not push later clicks off the detents" =
  let t = Bench.create () in
  Bench.run t 6;
  (* Jump straight from the detent to the opposite state, as if the pins were
     sampled too slowly. Both change at once, so that move is not counted. *)
  t.index <- 2;
  t.steps <- 2;
  Bench.drive t Bench.sequence.(2);
  Bench.run t Bench.hold;
  Bench.step t ~forward:true;
  Bench.step t ~forward:true;
  Stdio.printf "after the jump and two steps, back on a detent: %d\n" (Bench.position t);
  Bench.click t ~forward:true;
  Stdio.printf "after one more normal click: %d\n" (Bench.position t);
  Bench.click t ~forward:false;
  Bench.click t ~forward:false;
  Bench.click t ~forward:false;
  Stdio.printf "after three clicks back: %d\n" (Bench.position t);
  [%expect {|
    after the jump and two steps, back on a detent: 1
    after one more normal click: 2
    after three clicks back: -1
    |}]
;;

let%expect_test "random turning with bounce: on every detent, position = steps / 4" =
  let t = Bench.create () in
  Bench.run t 6;
  let rand = Random.State.make [| 7 |] in
  let detents = ref 0 in
  let wrong = ref 0 in
  for _ = 1 to 2000 do
    (* A random walk, leaning forward. Some steps bounce; some are a jiggle
       (forward, back, forward), which is also what bounce longer than the
       debounce looks like after it. *)
    let forward = Random.State.int rand 10 < 6 in
    (match Random.State.int rand 8 with
     | 0 ->
       Bench.step t ~forward;
       Bench.step t ~forward:(not forward);
       Bench.step t ~forward
     | 1 -> Bench.step t ~forward ~bounce:(Random.State.int_incl rand 1 3)
     | _ -> Bench.step t ~forward);
    if t.index = 0
    then (
      Int.incr detents;
      if Bench.position t <> t.steps / 4 then Int.incr wrong)
  done;
  Stdio.printf "detents checked: %d, wrong: %d\n" !detents !wrong;
  [%expect {| detents checked: 496, wrong: 0 |}]
;;

let%expect_test "2 and 1 steps per click" =
  let one_turn steps_per_click =
    let module B =
      Make_bench (struct
        let debounce_cycles = 2
        let steps_per_click = steps_per_click
        let position_width = 8
      end)
    in
    let t = B.create () in
    B.run t 6;
    for _ = 1 to 4 do
      B.step t ~forward:true
    done;
    let after_forward = B.position t in
    for _ = 1 to 4 do
      B.step t ~forward:false
    done;
    Stdio.printf
      "%d steps per click: one full A/B cycle forward -> %d, and back -> %d\n"
      steps_per_click
      after_forward
      (B.position t)
  in
  one_turn 2;
  one_turn 1;
  [%expect {|
    2 steps per click: one full A/B cycle forward -> 2, and back -> 0
    1 steps per click: one full A/B cycle forward -> 4, and back -> 0
    |}]
;;
