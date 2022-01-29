module Sirdi.Core.Config

import Sirdi.Core
import Util.IOEither
import Language.TOML
import Language.TOML.Processing
import System.Path
import Data.List.Elem


public export
data ConfigError : Type where
    TOMLError : TOML.Error -> ConfigError
    ValidateError : TableError -> ConfigError


GitOpts : TableTy
GitOpts = MkFieldTy { name = "url", optional = False, ty = TString }
    `And` MkFieldTy { name = "commit", optional = False, ty = TString }
    `And` MkFieldTy { name = "path", optional = False, ty = TString }
    `And` Emp


LocalOpts : TableTy
LocalOpts = MkFieldTy { name = "path", optional = False, ty = TString } `And` Emp


DepTy : TableTy
DepTy = MkFieldTy { name = "type", optional = False, ty = TEnum ["git", "local"] }
  `Ext` \case
          ("git" ** Here)         => GitOpts
          ("local" ** There Here) => LocalOpts
          (x ** There (There y)) impossible


ConfigTy : TableTy
ConfigTy = MkFieldTy { name = "dependencies", optional = False, ty = TArray (TTable DepTy) }
     `And` MkFieldTy { name = "main", optional = True, ty = TString }
     `And` Emp


toGit : TableOf GitOpts -> Identifier
toGit [url, commit, path] = Git url commit (parse path)


toLocal : TableOf LocalOpts -> Identifier
toLocal [path] = Local (parse path) -- In future, parse into an either


toIdent : ValueOf (TTable DepTy) -> Identifier
toIdent (("git" ** Here)           :: opts) = toGit opts
toIdent (("local" ** (There Here)) :: opts) = toLocal opts
-- When this Idris bug has been fiexed, we can remove this.
toIdent _ = assert_total $ idris_crash "Impossible case toIdent" 


toDesc : TableOf ConfigTy -> Description
toDesc [dependencies, main] =
    MkDescription {
        main = main,
        dependencies = map toIdent dependencies
    }


export
parseDesc : String -> Either ConfigError Description
parseDesc s = do
    tbl <- bimap TOMLError id $ parseTOML s
    toDesc <$> (bimap ValidateError id $ processTable ConfigTy tbl)
