(* Prints the Verilog for the default top level, one module per block. *)
open Hardcaml
module Top = Knob_pwm.Top.Default
module Circuit = Circuit.With_interface (Top.I) (Top.O)

let () =
  let scope = Scope.create ~flatten_design:false () in
  let circuit = Circuit.create_exn ~name:"knob_pwm" (Top.create scope) in
  Rtl.print ~database:(Scope.circuit_database scope) Verilog circuit
;;
