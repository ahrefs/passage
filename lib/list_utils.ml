(** General list utilities *)

(** takes two sorted lists and returns three lists:
    first is items unique to l1, second is items unique to l2, third is items in both l1 and l2.

    Preserves the order in the outputs *)
let diff_intersect_lists l1 r1 =
  let rec diff accl accr accb left right =
    match left, right with
    | [], [] -> List.rev accl, List.rev accr, List.rev accb
    | [], rh :: rt -> diff accl (rh :: accr) accb [] rt
    | lh :: lt, [] -> diff (lh :: accl) accr accb lt []
    | lh :: lt, rh :: rt ->
      let comp = compare lh rh in
      if comp < 0 then diff (lh :: accl) accr accb lt right
      else if comp > 0 then diff accl (rh :: accr) accb left rt
      else diff accl accr (lh :: accb) lt rt
  in
  diff [] [] [] l1 r1
