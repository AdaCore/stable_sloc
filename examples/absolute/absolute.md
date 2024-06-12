This matcher kind is the simplest possible, and only meant to be used either to
test the library, or on frozen code bases as there are no mechanisms to preserve
the designated code regions across content modification.

The matcher only needs to know the absolute source location range that it needs
to return:

```toml
[simple_absolute]
file = "content.txt"
kind = "absolute"
[[simple_absolute.annotations]]
message = "This will always match the following regions"
[simple_absolute.matcher]
start_line = 1
start_col = 1
end_line = 10
end_col = 13
```

```sh
stable_sloc_cli --spec simple_absolute.toml ../content.txt
simple_absolute: match SUCCESS
   content.txt:1:1 - 10:13
   Annotation:
      {"message":"This will always match the following regions"}
```

The backend still checks that there are actually enough lines and/or columns in
the file before returning a match success:

```toml
[overly_long_line]
file = "content.txt"
kind = "absolute"
[[overly_long_line.annotations]]
message = "This entry will fail to match because there are not enough character in line 1"
[overly_long_line.matcher]
start_line = 1
start_col = 100
end_line = 10
end_col = 13

[non_existent_line]
file = "content.txt"
kind = "absolute"
[[non_existent_line.annotations]]
message = "This entry will fail to match because there is not enough lines in the file"
[non_existent_line.matcher]
start_line = 1
start_col = 1
end_line = 100
end_col = 13
```

```sh
stable_sloc_cli --spec invalid.toml ../content.txt
overly_long_line: match FAILED
   content.txt
   Reason: Line 1 of content.txt is not long enough. Required 100 characters but got 75.
   Annotation:
      {"message":"This entry will fail to match because there are not enough character in line 1"}
non_existent_line: match FAILED
   content.txt
   Reason: Not enough lines in content.txt to contain the sloc range 1:1 - 100:13
   Annotation:
      {"message":"This entry will fail to match because there is not enough lines in the file"}
```
