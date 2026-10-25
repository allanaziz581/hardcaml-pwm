open! Base
open Hardcaml
open Signal

(* Two flip-flops bring the asynchronous pin into the clock domain. After that a
   counter lets a new level through only once it has been stable for [cycles]
   clocks in a row; any bounce back to the old level restarts the count. *)
let create ~spec ~cycles ~name pin =
  if cycles < 1 then raise_s [%message "Debounce.create: cycles must be >= 1" (cycles : int)];
  let synced = pipeline spec ~n:2 pin -- (name ^ "_synced") in
  let count_width = Int.max 1 (num_bits_to_represent (cycles - 1)) in
  let out = wire 1 in
  let count = wire count_width in
  let differs = synced <>: out in
  let stable_long_enough = count ==:. cycles - 1 in
  count
  <== (reg spec (mux2 (differs &: ~:stable_long_enough) (count +:. 1) (zero count_width))
       -- (name ^ "_count"));
  out <== reg spec ~enable:(differs &: stable_long_enough) synced;
  out -- (name ^ "_clean")
;;
