The `yaml-dir` package lets you read in directory structures as
though they were YAML objects, with file or subdirectory names as
keys and their contents as values. Three sets of functions are exposed:
one to treat all files as though they contain more YAML data, one
to treat all files as YAML strings, and one to choose between the
previous two based on file extension.

# Why YAML Directories?

The functions here don't care whether they're called on a file or
a directory. This means that there's a certain level of structure
that's lost to the application writer: there's no way of telling
whether a given YAML object corresponded a directory or not. This
is very much by design: to begin with, a configuration file like

~~~~
$ cat config
sites:
  home:
    url: www.example.com
    port: 7777
  blog:
    url: blog.example.com
    port: 7778
  wiki:
    url: wiki.example.com
    port: 7779
~~~~

isn't so bad, but if it gets larger, it becomes unwieldy. This
allows a user to transparently use a directory structure instead,
and pretend that directory structure is itself a YAML object:

~~~~
$ ls config/sites
blog
home
wiki
$ for f in config/sites/*; do echo $f; cat $f; echo; done
config/sites/blog
url: blog.example.com
port: 7778

config/sites/home
url: www.example.com
port: 7777

config/sites/wiki
url: wiki.example.com
port: 7779

~~~~

Both of the above will parse to the exact same YAML representation
when using the `decodeYamlPath` or `decodeYamlPathEither` functions.

# Why The Three Variations

Each one does a slightly different thing:

- `decodeYamlPath` and `decodeYamlPathEither` are for exactly the above
use-case: taking a typical YAML config and blowing it apart into
directories.
- `decodeTextPath` and `decodeTextPathEither` are better for certain
kind of data structuring: they treat every file as though it just
contained a YAML string.
- `decodeExtnPath` and `decodeExtnPathEither` are a compromise between
the two: they will understand a file as YAML if it has the extension
`.yaml`, as JSON if it has the extension `.json`, and as text otherwise.

# What If I Need To Emit A YAML Directory?

Don't do that. YAML is a nice input format, what with all kinds of
small conveniences for humans and special-cases to make common
things easy, but it's a _terrible_ intermediate format. There are
multiple stylistic variations allowed for an identical in-memory
representation, and this library only adds more.

If you have an application in which a machine needs to emit data,
there are various other formats which are better suited to that
purpose: if it needs to be human-readable, then
[JSON](http://hackage.haskell.org/package/aeson) or
[S-expressions](https://github.com/aisamanra/s-cargot)
might be better. If it doesn't, then a format
like [netstrings](https://en.wikipedia.org/wiki/Netstring) or
[bencode](http://hackage.haskell.org/package/AttoBencode) might be
preferable.
