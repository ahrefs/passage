module Default_config = Default_config

module Make (Config : Types.Config) = struct
  include Lib.Make (Config)
  module Commands = Commands.Make (Config)
end

include Make (Default_config)
