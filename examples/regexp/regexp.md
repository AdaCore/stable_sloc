This matcher kind relies on regular expressions to locate the designated region
to be located.

This works well to annotate multiple of regions which are easily identified by a
regular expression, without needing some form of semantic context to make the
entry precise enough. For instance, it can be used to match basic defensive
code (and in this case, exempt it in GNATcoverage):

`defensive.toml`
```toml
[defensive_ada]
file = "*.adb"
kind = "regexp"
[[defensive_ada.annotations]]
purpose = "xcov.exempt"
justification = "Defensive code, never to be reached"
[defensive_ada.matcher]
regexp = 'if [^;]* then( |\n)*raise [a-z]*_error;( |\n)*end if;'
case_insensitive = true
```

```sh
stable_sloc_cli --spec=defensive.toml ../*.ad*
ada_defensive: match SUCCESS
   ../pkg.adb:5:7 - 7:14
   Annotation:
      {"justification":"defensive code, never to be executed"}
ada_defensive: match SUCCESS
   ../pkg.adb:13:7 - 15:14
   Annotation:
      {"justification":"defensive code, never to be executed"}
ada_defensive: match SUCCESS
   ../pkg-child.adb:5:7 - 7:14
   Annotation:
      {"justification":"defensive code, never to be executed"}

```

The matcher is thus stable to any modification outside the matched regions, but
there is no guarantee that the matched regions are the ones intended.
