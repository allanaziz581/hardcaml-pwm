open! Base
open Hardcaml
open Hardcaml_waveterm

module Make_sim (Config : Knob_pwm.Pwm_interp.Config) = struct
  module Pwm = Knob_pwm.Pwm_interp.Make (Config)
  module Sim = Cyclesim.With_interface (Pwm.I) (Pwm.O)

  let period = (1 lsl Config.width) - 1

  let create () =
    let sim = Sim.create (Pwm.create (Scope.create ~flatten_design:true ())) in
    let waves, sim = Waveform.create sim in
    sim, waves
  ;;

  let run sim n =
    for _ = 1 to n do
      Cyclesim.cycle sim
    done
  ;;

  let set_target sim value =
    let i : _ Pwm.I.t = Cyclesim.inputs sim in
    i.target := Bits.of_int ~width:Config.width value;
    i.target_valid := Bits.vdd;
    Cyclesim.cycle sim;
    i.target_valid := Bits.gnd
  ;;

  let duty sim =
    let o : _ Pwm.O.t = Cyclesim.outputs sim in
    Bits.to_int !(o.duty)
  ;;

  (* Any [period] clocks in a row contain exactly [duty] high clocks, as long
     as the duty is not changing. *)
  let high_clocks sim =
    let o : _ Pwm.O.t = Cyclesim.outputs sim in
    let high = ref 0 in
    for _ = 1 to period do
      Cyclesim.cycle sim;
      if Bits.to_bool !(o.pwm) then Int.incr high
    done;
    !high
  ;;
end

(* 4-bit duty so a whole period (15 clocks) fits on screen, and a new target is
   reached over 4 periods. *)
module Small = Make_sim (struct
    let width = 4
    let interp_log2 = 2
  end)

let display_rules =
  Display_rule.
    [ port_name_is "target_valid" ~wave_format:Bit
    ; port_name_is "target" ~wave_format:Unsigned_int
    ; port_name_is "duty" ~wave_format:Unsigned_int
    ; port_name_is "ramping" ~wave_format:Bit
    ; port_name_is "pwm" ~wave_format:Bit
    ]
;;

let%expect_test "ramp up, then a new target arrives mid-ramp" =
  let sim, waves = Small.create () in
  Small.run sim 2;
  Small.set_target sim 12;
  (* Two periods in, the duty has gone 0 -> 3 -> 6. Ask for 0: it turns round
     from 6 instead of jumping. *)
  Small.run sim ((2 * Small.period) - 1);
  Small.set_target sim 0;
  Small.run sim ((4 * Small.period) + 4);
  Waveform.print
    waves
    ~display_rules
    ~display_width:116
    ~display_height:14
    ~signals_width:14
    ~wave_width:(-1);
  [%expect {|
    ┌Signals─────┐┌Waves───────────────────────────────────────────────────────────────────────────────────────────────┐
    │target_valid││  ┌┐                            ┌┐                                                                  │
    │            ││──┘└────────────────────────────┘└───────────────────────────────────────────────────────────────   │
    │            ││──┬─────────────────────────────┬────────────────────────────────────────────────────────────────   │
    │target      ││ 0│12                           │0                                                                  │
    │            ││──┴─────────────────────────────┴────────────────────────────────────────────────────────────────   │
    │            ││───────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────   │
    │duty        ││ 0             │3             │6             │4             │3             │1             │0        │
    │            ││───────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────   │
    │ramping     ││   ┌──────────────────────────────────────────────────────────────────────────────────────┐         │
    │            ││───┘                                                                                      └──────   │
    │pwm         ││                ┌──┐           ┌─────┐        ┌───┐          ┌──┐           ┌┐                      │
    │            ││────────────────┘  └───────────┘     └────────┘   └──────────┘  └───────────┘└───────────────────   │
    └────────────┘└────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "duty 0 is always low and full scale is always high" =
  let sim, waves = Small.create () in
  let print_from start_cycle =
    Waveform.print
      waves
      ~display_rules
      ~display_width:84
      ~display_height:14
      ~signals_width:14
      ~wave_width:0
      ~start_cycle
  in
  (* Each ramp is over after 1 + 4 periods; then show one period and a bit. *)
  let settle = 1 + (5 * Small.period) in
  let shown = Small.period + 5 in
  Small.set_target sim 15;
  Small.run sim (settle + shown - 1);
  Small.set_target sim 0;
  Small.run sim (settle + shown - 1);
  let full = settle in
  let zero = settle + shown + settle in
  print_from full;
  print_from zero;
  [%expect {|
    ┌Signals─────┐┌Waves───────────────────────────────────────────────────────────────┐
    │target_valid││                                        ┌─┐                         │
    │            ││────────────────────────────────────────┘ └─────────────────────────│
    │            ││────────────────────────────────────────┬───────────────────────────│
    │target      ││ 15                                     │0                          │
    │            ││────────────────────────────────────────┴───────────────────────────│
    │            ││──────────────────────────────────────────────────────────┬─────────│
    │duty        ││ 15                                                       │11       │
    │            ││──────────────────────────────────────────────────────────┴─────────│
    │ramping     ││                                          ┌─────────────────────────│
    │            ││──────────────────────────────────────────┘                         │
    │pwm         ││────────────────────────────────────────────────────────────────────│
    │            ││                                                                    │
    └────────────┘└────────────────────────────────────────────────────────────────────┘
    ┌Signals─────┐┌Waves───────────────────────────────────────────────────────────────┐
    │target_valid││                                                                    │
    │            ││────────────────────────────────────────                            │
    │            ││────────────────────────────────────────                            │
    │target      ││ 0                                                                  │
    │            ││────────────────────────────────────────                            │
    │            ││────────────────────────────────────────                            │
    │duty        ││ 0                                                                  │
    │            ││────────────────────────────────────────                            │
    │ramping     ││                                                                    │
    │            ││────────────────────────────────────────                            │
    │pwm         ││                                                                    │
    │            ││────────────────────────────────────────                            │
    └────────────┘└────────────────────────────────────────────────────────────────────┘
    |}]
;;

(* The rest print numbers instead of waveforms. *)

let%expect_test "12-bit: a full-scale step is spread over 16 periods" =
  let module T =
    Make_sim (struct
      let width = 12
      let interp_log2 = 4
    end)
  in
  let sim, _ = T.create () in
  (* Sample once per period; each sample sees exactly one more step. *)
  let show target =
    T.set_target sim target;
    let duties = Queue.create () in
    for _ = 1 to 17 do
      Queue.enqueue duties (T.duty sim);
      T.run sim T.period
    done;
    let duties = Queue.to_list duties in
    let biggest =
      List.zip_exn (List.drop_last_exn duties) (List.tl_exn duties)
      |> List.map ~f:(fun (a, b) -> abs (b - a))
      |> List.max_elt ~compare
      |> Option.value_exn
    in
    Stdio.printf
      "%s\nlargest change between periods: %d\n"
      (List.map duties ~f:Int.to_string |> String.concat ~sep:" ")
      biggest
  in
  show 4095;
  show 0;
  [%expect {|
    0 255 511 767 1023 1279 1535 1791 2047 2303 2559 2815 3071 3327 3583 3839 4095
    largest change between periods: 256
    4095 3839 3583 3327 3071 2815 2559 2303 2047 1791 1535 1279 1023 767 511 255 0
    largest change between periods: 256
    |}]
;;

let%expect_test "8-bit: high clocks per period equal the duty, for every duty" =
  let module T =
    Make_sim (struct
      let width = 8
      let interp_log2 = 0
    end)
  in
  let sim, _ = T.create () in
  let mismatches =
    List.filter (List.range 0 256) ~f:(fun d ->
      T.set_target sim d;
      (* Let the new duty take effect and the registered pin catch up. *)
      T.run sim (2 * T.period);
      T.duty sim <> d || T.high_clocks sim <> d)
  in
  Stdio.printf "duties checked: 256, mismatches: %d\n" (List.length mismatches);
  [%expect {| duties checked: 256, mismatches: 0 |}]
;;

let%expect_test "random targets at random times, often mid-ramp" =
  let module T =
    Make_sim (struct
      let width = 8
      let interp_log2 = 3
    end)
  in
  let steps = 8 in
  let sim, _ = T.create () in
  let rand = Random.State.make [| 1 |] in
  let mid_ramp = ref 0 in
  let failures = ref 0 in
  for _ = 1 to 300 do
    let o : _ T.Pwm.O.t = Cyclesim.outputs sim in
    if Bits.to_bool !(o.ramping) then Int.incr mid_ramp;
    let start = T.duty sim in
    let target = Random.State.int rand 256 in
    T.set_target sim target;
    (* Each period the duty may move by at most 1/8 of the distance (rounded
       up), must stay between where it started and the target, and must sit on
       the target after 8 periods. *)
    let limit = (abs (target - start) + steps - 1) / steps in
    let prev = ref start in
    for p = 1 to Random.State.int_incl rand 0 (steps + 2) do
      T.run sim T.period;
      let d = T.duty sim in
      if abs (d - !prev) > limit
         || d < Int.min start target
         || d > Int.max start target
         || (p >= steps && d <> target)
      then Int.incr failures;
      prev := d
    done
  done;
  Stdio.printf
    "updates: 300, arrived mid-ramp: %d, failures: %d\n"
    !mid_ramp
    !failures;
  [%expect {| updates: 300, arrived mid-ramp: 227, failures: 0 |}]
;;
