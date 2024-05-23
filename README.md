# Stable_Sloc

Identifying code regions in shifting tides.

Build using gprbuild.

## Building and dependencies

Stable_Sloc currently only depends on
[Ada-toml (master)](https://github.com/pmderodat/ada-toml) and GNATCOLL-core.

Build using gprbuild, Stable_Sloc is written in Ada 2022.

## Annotation format

Annotations are described in TOML files. Each element of the
root table is considered to be an entry, the key being its unique
identifier. Each entry consist of the following fields

- `purpose` (optional), a string defining the purpose of the entry.
  This allows grouping multiple entries, for various tools
  and purposes in a single file. It is optional, and if not present the
  entry will always be active.

- `annotations`, an array of tables. Used to provide context for the entry.
  Interpretation is left to the tool.

  Each table in the array may contain a `purpose` field, which can be used to
  filter which entry should be matched or not using the `purpose_prefix`
  parameter in the `Match_Entries` function, or the `--filter` switch on the
  CLI.

- `file`, a string containing a globing pattern of files on which this entry
  should be searched for.

- `at_most_once`, a boolean specifying wether the entry is expected to match
  more than once. If `True`, once the entry is loaded, it will return a failed
  Match_Result upon every match once a successful match has been found.

  This is optional and defaults to `False`

- `kind`, a string, defining which source location matcher will be used to
  interpret this entry.

- `matcher`, a table containing the required fields by the specific source
  location matcher.

Other fields will be ignored.

## Builtin matchers

There are currently two matchers built into the library.

### `absolute` matcher

It represents an absolute source location and will not try to compensate source
changes. It is provided as a simple last resort matcher, only suitable for
frozen code bases.

Entry fields:

- `kind="absolute"`
- `start_line`, required, integer.

  Line of the beginning of the location range.

- `start_col`, required, integer.

  Column of the beginning of the location range.

- `end_line`, required, integer.

  Line of the end of the location range.

- `end_col`, required, integer.

  Column of the end of the location range.

When matching an absolute entry, a check is made on each file to which the
matcher applies to ensure the lines/columns described in the entry fit in the
current content of the file.

This matcher supports updates (-u switch on the command line)

### `regexp` matcher

It matches a location range through a regular expression. The regular
expression is used to search through the whole content of a file, including
the newline characters, and not line by line.

Entry fields:

- `kind="regexp"`
- `regexp`, required, string.

  Regular expression to be matched. Uses the
  `GNAT.Regpat` package as a regular expression matching backend, see the
  specification of that package for the recognized grammar.

- `case_insensitive`, optional, boolean.

  If `true`, The automaton is optimized
  so that the matching is done in a case insensitive manner (upper case
  characters and lower case characters are all treated the same way).
  Default to `false` if not present.

- `single_line`, optional, boolean.

  If `true`, treat the file content as a single line.
  This means that `^` and `$` will ignore `\n` (unless `multi_line` is also `true`),
  and that `'.'` will match `\n`.
  Defaults to `false` if not present.

- `multi_line`, optional, boolean.

  If `true`, treat the file content as multiple lines.
  This means that `^` and `$` will also match on internal newlines (`ASCII.LF`),
  in addition to the beginning and end of the file.
  Defaults to `false` if not present.

### Libadalang-context matcher

This matcher recognizes the code region from a Libadalang node designating the
inner-most named declaration fully containing the designated location range, a
context hash ensuring the contents of the declaration has not changed, and a
relative source location to that declaration. It is thus stable to any
modification of the sources, provided the identified declaration does not change
package or nesting level, and that the local contents of the declaration do not
change (trivia included).

This matcher is not indented to be written by humans, but instead to be
generated using the library or cli.

Entry Fields:

- `kind=lal_context`

- `sem_parents`, required, array of strings.

  Contains the list of lower-cased named entities containing the declaration
  used as context, in increasing depth order. The last element is the defining
  name of the context declaration. Concatenated with '.' it would spell the
  context declaration's fully qualified name.

- `content_hash`, required, string.

  Hash of the text content of the context declaration node. It must be formatted
  It must be formatted as a 32 bit hexadecimal number, in Ada numerical syntax:
  `16#ABCDEF12#`

- The same fields as in an [absolute matcher](#absolute-matcher), which
  represent the relative location range to the beginning of the context
  declaration.

## Adding your own matcher

The library is extensible, you can write your own matcher and register it using
the API in `Stable_Sloc.Matchers`.

A Matcher must simply implement the `Stable_Sloc.Matchers.Sloc_Matcher`
interface, and you must provide a callback to parse a TOML entry to produce a
matcher object for that specific entry. The callback can be registered through
the `Stable_Sloc.Matchers.Register_Matcher` procedure, and proceed to use the
library as if your matcher was a builtin one.
