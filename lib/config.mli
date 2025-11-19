(** Home directory. Default: $HOME *)
val home_dir : string lazy_t ref

(** Base directory for passage configuration. Default: $PASSAGE_DIR or $HOME/.config/passage *)
val base_dir : string lazy_t ref

(** Directory containing public keys. Default: $PASSAGE_KEYS or <base_dir>/keys *)
val keys_dir : string lazy_t ref

(** Directory containing encrypted secrets. Default: $PASSAGE_SECRETS or <base_dir>/secrets *)
val secrets_dir : string lazy_t ref

(** Path to the identity key file. Default: $PASSAGE_IDENTITY or <base_dir>/identity.key *)
val identity_file : string lazy_t ref

(** Selection method for x-selection. Default: $PASSAGE_X_SELECTION or "clipboard" *)
val x_selection : string ref

(** Clipboard timeout. Default: $PASSAGE_CLIP_TIME or "45" *)
val clip_time : int ref
