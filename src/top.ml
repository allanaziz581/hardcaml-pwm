open! Base
open Hardcaml
open Signal

module type Config = sig
  val width : int
  val interp_log2 : int
  val debounce_cycles : int
  val steps_per_click : int

  (** How far one click moves the target. The push button toggles between the
      two. *)
  val fine_step : int

  val coarse_step : int
end

module Make (Config : Config) = struct
  open Config

  module Encoder = Quadrature.Make (struct
      let debounce_cycles = debounce_cycles
      let steps_per_click = steps_per_click
      let position_width = 16
    end)

  module Pwm = Pwm_interp.Make (struct
      let width = width
      let interp_log2 = interp_log2
    end)

  module I = struct
    type 'a t =
      { clock : 'a
      ; clear : 'a
      ; enc_a : 'a
      ; enc_b : 'a
      ; enc_button : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { pwm : 'a
      ; coarse : 'a
      ; target : 'a [@bits width]
      ; duty : 'a [@bits width]
      }
    [@@deriving hardcaml]
  end

  let create scope (i : _ I.t) =
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    let encoder =
      Encoder.hierarchical
        scope
        { Encoder.I.clock = i.clock
        ; clear = i.clear
        ; a = i.enc_a
        ; b = i.enc_b
        ; button = i.enc_button
        }
    in
    let ( -- ) = Scope.naming scope in
    let coarse = reg_fb spec ~width:1 ~enable:encoder.pressed ~f:( ~: ) in
    let amount = mux2 coarse (of_int ~width coarse_step) (of_int ~width fine_step) in
    (* One extra bit catches the carry or borrow, so the target sticks at 0 and
       at full scale instead of wrapping. *)
    let target =
      reg_fb spec ~width ~f:(fun t ->
        let raised = ue t +: ue amount in
        let lowered = ue t -: ue amount in
        let raised = mux2 (msb raised) (ones width) (lsbs raised) in
        let lowered = mux2 (msb lowered) (zero width) (lsbs lowered) in
        mux2 encoder.up raised (mux2 encoder.down lowered t))
      -- "target_reg"
    in
    (* The target register changes one clock after the click, so delay the
       strobe by one clock to line it up. *)
    let target_valid = reg spec (encoder.up |: encoder.down) -- "target_valid" in
    let pwm =
      Pwm.hierarchical scope { Pwm.I.clock = i.clock; clear = i.clear; target; target_valid }
    in
    { O.pwm = pwm.pwm; coarse; target; duty = pwm.duty }
  ;;
end

(** The configuration used for the generated Verilog: 12-bit duty, a new target
    reached over 16 PWM periods, and a 2^16 clock debounce (about 1.3 ms at
    50 MHz). *)
module Default_config = struct
  let width = 12
  let interp_log2 = 4
  let debounce_cycles = 1 lsl 16
  let steps_per_click = 4
  let fine_step = 16
  let coarse_step = 256
end

module Default = Make (Default_config)
