module Make (Config : Types.Config) = struct
  module Age = Age
  module Dirtree = Dirtree.With_config (Config)
  module Invariant = Invariant.With_config (Config)
  module Path = Path.With_config (Config)
  module Secret = Secret
  module Shell = Shell.With_config (Default_config)
  module Storage = Storage.With_config (Config)
  module Template = Template.With_config (Config)
  module Template_ast = Template_ast
  module Template_lexer = Template_lexer
  module Template_parser = Template_parser
  module Util = Util.With_config (Config)
  module Validation = Validation.With_config (Config)
  module Config = Config
end
