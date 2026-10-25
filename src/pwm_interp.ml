open! Base
open Hardcaml
open Signal

module type Config = sig
  (** Bits of duty resolution. The PWM period is [2^width - 1] clocks. *)
  val width : int

  (** A new target is reached over [2^interp_log2] PWM periods. *)
  val interp_log2 : int
end

module Make (Config : Config) = struct
  open Config

  let steps = 1 lsl interp_log2
  let max_count = (1 lsl width) - 2

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; target : 'a [@bits width]
      ; target_valid : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { pwm : 'a
      ; duty : 'a [@bits width]
      ; ramping : 'a
      }
    [@@deriving hardcaml]
  end

  let with_fraction x = if interp_log2 = 0 then x else x @: zero interp_log2

  let create scope (i : _ I.t) =
    let ( -- ) = Scope.naming scope in
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    (* The counter runs 0 .. 2^width - 2. With [pwm = counter < duty], duty 0 is
       always low and duty 2^width - 1 is always high. *)
    let counter =
      reg_fb spec ~width ~f:(fun c -> mux2 (c ==:. max_count) (zero width) (c +:. 1))
      -- "counter"
    in
    let period_end = (counter ==:. max_count) -- "period_end" in
    (* [acc] holds the duty with [interp_log2] fraction bits. A new target sets
       [step = target - duty]; adding [step] to [acc] once per period for
       [2^interp_log2] periods moves the duty by exactly [step]. *)
    let acc = Always.Variable.reg spec ~width:(width + interp_log2) in
    let step = Always.Variable.reg spec ~width:(width + 1) in
    let remaining = Always.Variable.reg spec ~width:(interp_log2 + 1) in
    ignore (acc.value -- "acc" : Signal.t);
    ignore (step.value -- "step" : Signal.t);
    ignore (remaining.value -- "remaining" : Signal.t);
    let duty = select acc.value (width + interp_log2 - 1) interp_log2 in
    Always.(
      compile
        [ if_
            i.target_valid
            [ (* Restart from the duty we are at now, dropping the fraction, so
                 the output does not move on this cycle. *)
              acc <-- with_fraction duty
            ; step <-- ue i.target -: ue duty
            ; remaining <--. steps
            ]
          @@ elif
               (period_end &: (remaining.value <>:. 0))
               [ acc <-- acc.value +: sresize step.value (width + interp_log2)
               ; remaining <-- remaining.value -:. 1
               ]
               []
        ]);
    (* [duty] only changes on the last clock of a period, so each period uses
       one duty value. *)
    { O.pwm = reg spec (counter <: duty); duty; ramping = remaining.value <>:. 0 }
  ;;

  let hierarchical scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"pwm_interp" create i
  ;;
end
