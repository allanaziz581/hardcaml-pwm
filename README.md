# hardcaml-pwm

A rotary encoder knob that sets the duty cycle of a PWM output, written in
[Hardcaml](https://github.com/janestreet/hardcaml). When the knob moves, the
duty slides to the new value over a few PWM periods instead of jumping there.

This is a learning project. It has been simulated and tested, and the
Verilog is generated, but it has not been synthesized, timed or run on an
FPGA board.

## The blocks

### PWM with interpolation (`src/pwm_interp.ml`)

Takes a duty target and drives a PWM pin. The period is `2^width - 1`
clocks, so duty 0 is a pin held low and full scale is a pin held high, with
no one-clock spike at either end.

A new target doesn't apply at once. The block works out
`step = target - duty` and adds it to an accumulator once per period. The
accumulator has `interp_log2` extra fraction bits, so after
`2^interp_log2` periods the duty has moved by exactly `step` and sits on the
target with no rounding error. The duty is the accumulator rounded down, so
when the step doesn't divide evenly the moves come out uneven: 1 to 6 over 4
periods goes 2, 3, 4, 6. If a new target arrives in the middle of a ramp, it
starts a fresh ramp from wherever the duty is at that moment. The duty only
changes on the last clock of a period, so every period is clean.

Parameters: `width` (duty bits) and `interp_log2` (log2 of the number of
periods a ramp takes).

4-bit duty (15-clock period), 4 periods per ramp, one clock per column. The
target goes to 12, and two periods later (duty at 6) it changes to 0. The
duty turns round from 6 without a jump:

```
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
```

### Quadrature decoder (`src/quadrature.ml`)

For an EC11-style encoder: A, B and a push button.

- Each pin goes through a two flip-flop synchronizer, then a debouncer that
  only accepts a new level after it has been stable for `debounce_cycles`
  clocks.
- A step is when exactly one of A and B changes. The new A compared with the
  old B gives the direction. If both change at once a state was missed, so
  that move is ignored.
- Steps are counted since the last detent, and a click is reported only when
  the knob lands on a detent having moved at least half way there in one
  direction. Turning back part way never clicks, and a missed state can't
  shift later clicks off the detents.
- Clicks drive a signed position counter. The button gives a debounced level
  and a one-clock `pressed` pulse.

Parameters: `debounce_cycles`, `steps_per_click` (1, 2 or 4) and
`position_width`.

One click forward, two columns per clock. Each edge bounces twice before
it settles; the debouncer (2 clocks here) passes one clean edge each time,
and `up` fires once, when the knob lands on the next detent:

```
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
```

### Top level (`src/top.ml`)

Each click moves the PWM target up or down by a fixed amount, stopping at 0
and full scale rather than wrapping. The push button switches between a fine
and a coarse amount (`coarse` output, for an LED). The target goes straight
to the PWM block, which does the smoothing.

4-bit duty, steps of 1 and 4, two clocks per column (a `╥` is a change
partway through a column). Two fine clicks, a button press, then one coarse
click. Each click lands before the last ramp has finished, so the duty never
catches the target until the end, and it never jumps:

```
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
```

## Tests

`dune test` runs Hardcaml expect-tests. They print waveforms with
`hardcaml_waveterm`, so a change in behaviour shows up as a diff.

- PWM: a new target in the middle of a ramp; duty 0 and full scale hold the
  pin low and high for a whole period; a 12-bit full-scale step moves at most
  256 per period and lands on the target; for every 8-bit duty, the pin is
  high for exactly `duty` clocks per period; 300 random targets at random
  times, checking each period moves at most 1/8 of the way, stays between
  the start and the target, and lands on the target.
- Decoder: bounce on every edge still gives one click; turning back part way
  gives none; a bouncy button gives one press; a missed state doesn't shift
  later clicks; 2000 random steps (with reversals and bounce) where, on every
  detent, the position equals steps / 4; 2 and 1 steps per click.
- Top level: target saturates at 0 and full scale; the exact 12-bit
  configuration used for the Verilog.

## Verilog

`rtl/knob_pwm.v` is generated by `bin/generate.ml` on every `dune build`,
with one Verilog module per block. It uses a 12-bit duty, 16 periods per
ramp, a 2^16 clock debounce and steps of 16 and 256. Inputs are `clock`,
`clear` (synchronous reset), `enc_a`, `enc_b` and `enc_button`; outputs are
`pwm`, `coarse`, and `target` and `duty` for debugging.

## Building

Needs OCaml 5.3 and opam (Hardcaml v0.17.1):

```
opam install hardcaml ppx_hardcaml hardcaml_waveterm ppx_jane dune
dune build
dune test
```

On macOS, if `dune` crashes with a segfault: an Xcode SDK newer than the
running OS can make the OCaml compiler think `pipe2` and `dup3` exist. Build
the compiler with `ac_cv_func_pipe2=no ac_cv_func_dup3=no` set in the
environment.
