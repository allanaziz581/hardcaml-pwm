open! Base
open Hardcaml
open Signal

module type Config = sig
  (** A pin must hold a new level this many clocks before it is accepted. *)
  val debounce_cycles : int

  (** Quadrature steps per detent: 4 for encoders with one full A/B cycle per
      click, 2 or 1 for others. Detents are assumed to sit at A = B = 1 (common
      pin to ground, pull-ups on A and B); with 2 steps per click also at
      A = B = 0. *)
  val steps_per_click : int

  val position_width : int
end

module Make (Config : Config) = struct
  open Config

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; a : 'a
      ; b : 'a
      ; button : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { position : 'a [@bits position_width]
      ; up : 'a
      ; down : 'a
      ; button_down : 'a
      ; pressed : 'a
      }
    [@@deriving hardcaml]
  end

  let create scope (i : _ I.t) =
    let ( -- ) = Scope.naming scope in
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    let debounce = Debounce.create ~spec ~cycles:debounce_cycles in
    let a = debounce i.a ~name:"a" in
    let b = debounce i.b ~name:"b" in
    let button = debounce i.button ~name:"button" in
    let a_prev = reg spec a in
    let b_prev = reg spec b in
    let a_changed = a ^: a_prev in
    let b_changed = b ^: b_prev in
    (* Exactly one pin changed: one step, and the new A against the old B gives
       the direction. Both changed: a state was missed and the direction is
       unknown. *)
    let step = (a_changed ^: b_changed) -- "step" in
    let lost_track = (a_changed &: b_changed) -- "lost_track" in
    let forward = (a ^: b_prev) -- "forward" in
    let at_detent =
      match steps_per_click with
      | 1 -> vdd
      | 2 -> ~:(a ^: b)
      | 4 -> a &: b
      | _ -> raise_s [%message "steps_per_click must be 1, 2 or 4" (steps_per_click : int)]
    in
    (* [moved] counts steps since the last detent. A click is reported only on
       landing on a detent, and only if the knob got at least half way there in
       one direction, so turning back part way never clicks and a missed state
       cannot shift later clicks off the detents. *)
    let moved_width = num_bits_to_represent steps_per_click + 1 in
    let threshold = Int.max 1 (steps_per_click / 2) in
    let moved = Always.Variable.reg spec ~width:moved_width in
    ignore (moved.value -- "moved" : Signal.t);
    let up = Always.Variable.wire ~default:gnd in
    let down = Always.Variable.wire ~default:gnd in
    let next = mux2 forward (moved.value +:. 1) (moved.value -:. 1) in
    Always.(
      compile
        [ if_
            step
            [ if_
                at_detent
                [ moved <--. 0
                ; up <-- (next >=+. threshold)
                ; down <-- (next <=+. -threshold)
                ]
                [ moved <-- next ]
            ]
          @@ elif lost_track [ moved <--. 0 ] []
        ]);
    let position =
      reg_fb spec ~width:position_width ~f:(fun p ->
        mux2 up.value (p +:. 1) (mux2 down.value (p -:. 1) p))
    in
    { O.position
    ; up = up.value
    ; down = down.value
    ; button_down = button
    ; pressed = button &: ~:(reg spec button)
    }
  ;;

  let hierarchical scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"quadrature" create i
  ;;
end
