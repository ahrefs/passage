module Fresh (T : sig
  type t
  val compare : t -> t -> int
end) =
struct
  type t = T.t
  let id = Fun.id
  let inject = id
  let project = id
  let inject_list = id
  let project_list = id
  let compare = T.compare
  let equal a b = T.compare a b = 0
  let map f x = inject (f (project x))
  let map2 f x y = inject (f (project x) (project y))
end
