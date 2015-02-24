{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE ParallelListComp #-}

module Data.YamlDir ( -- * Only YAML files
                      -- $yaml
                      decodeYamlPath
                    , decodeYamlPathEither
                      -- * Only Text files
                      -- $text
                    , decodeTextPath
                    , decodeTextPathEither
                      -- * Files Based On Extension
                      -- $extension
                    , decodeExtnPath
                    , decodeExtnPathEither
                    ) where

import           Data.Either (either)
import           Data.HashMap.Strict (fromList)
import           Data.List (isSuffixOf)
import           Data.Text (pack)
import qualified Data.Text.IO as T
import           Data.Yaml
import           System.Directory ( doesDirectoryExist
                                  , getDirectoryContents
                                  )
import           System.FilePath ((</>))

filterDir :: IO [String] -> IO [String]
filterDir = fmap (filter go)
  where go d = d /= "." && d /= ".."

toMaybe :: Either a b -> Maybe b
toMaybe (Left _)  = Nothing
toMaybe (Right x) = Just x

decodePath :: FromJSON t => FileFunc -> FilePath -> IO (Maybe t)
decodePath func path = fmap toMaybe (decodeEitherPath func path)

decodeEitherPath :: FromJSON t => FileFunc -> FilePath -> IO (Either String t)
decodeEitherPath func path = do
  val <- parsePath func path
  return (val >>= parseEither parseJSON)

-- as-yaml functions

{- $yaml

These functions read in a directory as a YAML object and assume that
each file within the directory itself contains a YAML value. For example,
if we create the directory

> $ mkdir mydir
> $ cat >mydir/foo <<EOF
> > [1,2,3]
> > EOF
> $ cat >mydir/bar <<EOF
> > baz: true
> > quux: false
> > EOF

then @decodeYamlPath "mydir"@ will return

> Just (Object (fromList [ ("foo", Array (fromList [ Number 1.0
>                                                  , Number 2.0
>                                                  , Number 3.0
>                                                  ]))
>                        , ("bar", Object (fromList [ ("baz", Bool True)
>                                                   , ("quux", Bool False)
>                                                   ]))
>                        ]))

-}

decodeYamlPath :: FromJSON t => FilePath -> IO (Maybe t)
decodeYamlPath = fmap toMaybe . decodeYamlPathEither

decodeYamlPathEither :: FromJSON t => FilePath -> IO (Either String t)
decodeYamlPathEither = decodeEitherPath go
  where go = fmap (either (Left . show) (Right)) . decodeFileEither

-- as-text functions

{- $text

These functions read in a directory as a YAML object and treat each
file in the directory as containing a YAML string value. For example,
if we create the directory

> $ mkdir mydir
> $ cat >mydir/foo <<EOF
> > [1,2,3]
> > EOF
> $ cat >mydir/bar <<EOF
> > baz: true
> > quux: false
> > EOF

then @decodeTextPath "mydir"@ will return

> Just (Object (fromList [ ("foo", String "[1,2,3]\n")
>                        , ("bar", String "baz: true\nquux: false\n")
>                        ]))

-}

decodeTextPath :: FromJSON t => FilePath -> IO (Maybe t)
decodeTextPath = fmap toMaybe . decodeTextPathEither

decodeTextPathEither :: FromJSON t => FilePath -> IO (Either String t)
decodeTextPathEither = decodeEitherPath go
  where go path = fmap (Right . String) (T.readFile path)

-- extension functions

{- $extension

These functions read in a directory as a YAML object and relies on
the extension of a file to determine whether it is YAML or non-YAML.
For example, if we create the directory

> $ mkdir mydir
> $ cat >mydir/foo.yaml <<EOF
> > [1,2,3]
> > EOF
> $ cat >mydir/bar.text <<EOF
> > baz: true
> > quux: false
> > EOF

then @decodeExtnPath "mydir"@ will return

> Just (Object (fromList [ ("foo.yaml", Array (fromList [ Number 1.0
>                                                       , Number 2.0
>                                                       , Number 3.0
>                                                       ]))
>                        , ("bar.text", String "baz: true\nquux: false\n")
>                        ]))

-}

decodeExtnPath :: FromJSON t => FilePath -> IO (Maybe t)
decodeExtnPath = fmap toMaybe . decodeExtnPathEither

decodeExtnPathEither :: FromJSON t => FilePath -> IO (Either String t)
decodeExtnPathEither = decodeEitherPath go
  where go p | ".yaml" `isSuffixOf` p
                 = fmap (either (Left . show) Right) (decodeFileEither p)
             | otherwise
                 = fmap (Right . String) (T.readFile p)

-- implementations

type FileFunc = FilePath -> IO (Either String Value)

parsePath :: FileFunc -> FilePath -> IO (Either String Value)
parsePath withFile path = do
  isDir  <- doesDirectoryExist path
  if | isDir     -> parseDir withFile path
     | otherwise -> withFile path

parseDir :: FileFunc -> FilePath -> IO (Either String Value)
parseDir withFile path = do
  ks <- filterDir (getDirectoryContents path)
  vs <- fmap sequence (mapM (parsePath withFile) [path </> k | k <- ks])
  case vs of
    Left s    -> return (Left s)
    Right vs' -> return (Right (Object (fromList [ (pack k, v)
                                                | k <- ks
                                                | v <- vs'
                                                ])))
