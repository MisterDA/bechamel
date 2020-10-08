open Bechamel
open Toolkit

(* This is our /protected/ function which take an argument and return a simple
   function: [unit -> 'a]. The function must be wrapped into a [Staged.t].

   NOTE: [words] is __outside__ our [(unit -> 'a) Staged.t]*)

let make_list words =
  Staged.stage @@ fun () ->
  let rec go n acc = if n = 0 then acc else go (n - 1) (n :: acc) in
  ignore (go ((words / 3) + 1) [])

(* From our function [make_list], we make an indexed (by [args]) test. It's a list
  of tests which are applied with [args] such as:

   {[
     let test =
       [ make_list 0
       ; make_list 10
       ; make_list 100
       ; make_list 400
       ; make_list 1000 ]
   ]} *)
let test =
  Test.make_indexed ~name:"list" ~fmt:"%s %d" ~args:[ 0; 10; 100; 400; 1000 ]
    make_list

(* From our test, we can start to benchmark it!

   A benchmark is a /run/ of your test multiple times. From results given by
   [Benchmark.all], an analyse is needed to infer measures of one call of your
   test.

   [Bechamel] asks 3 things:
   - what you want to record (see [instances])
   - how you want to analyse (see [ols])
   - how you want to benchmark your test (see [cfg])

   The core of [Bechamel] (see [Bechamel.Toolkit]) has some possible measures
   such as the [monotonic-clock] to see time performances.

   The analyse can be OLS (Ordinary Least Square) or RANSAC. In this example, we
   use only one.

   Finally, to launch the benchmark, we need some others details such as:
   - should we stabilise the GC?
   - how many /run/ you want
   - the maximum of time allowed by the benchmark
   - etc.

   [raw_results] is what the benchmark produced. [results] is what the analyse
   can infer. The first one is used to show graphs or to let the user (with
   [Measurement_raw]) to infer something else than what [ols] did. The second is
   mostly what you want: a synthesis of /samples/. *)

let benchmark () =
  let ols =
    Analyze.ols ~bootstrap:0 ~r_square:true ~predictors:Measure.[| run |] in
  let instances =
    Instance.[ minor_allocated; major_allocated; monotonic_clock ] in
  let cfg =
    Benchmark.cfg ~limit:2000 ~quota:(Time.second 0.5) ~kde:(Some 1000) () in
  let raw_results = Benchmark.all cfg instances test in
  let results =
    List.map (fun instance -> Analyze.all ols instance raw_results) instances
  in
  let results = Analyze.merge ols instances results in
  (results, raw_results)

let () =
  List.iter
    (fun v -> Bechamel_notty.Unit.add v (Measure.unit v))
    Instance.[ minor_allocated; major_allocated; monotonic_clock ]

let img (window, results) =
  Bechamel_notty.Multiple.image_of_ols_results ~rect:window
    ~predictor:Measure.run results

open Notty_unix

let () =
  let window =
    match winsize Unix.stdout with
    | Some (w, h) -> { Bechamel_notty.w; h }
    | None -> { Bechamel_notty.w = 80; h = 1 } in
  let results, _ = benchmark () in
  img (window, results) |> eol |> output_image
