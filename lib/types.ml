module type Config = sig
  val home_dir : string lazy_t
  val base_dir : string lazy_t
  val keys_dir : string lazy_t
  val secrets_dir : string lazy_t
  val identity_file : string lazy_t
  val x_selection : string
  val clip_time : int
end
