# README
The command `zig fmt` can be used to format zig source code files.
At the time of this writing, it uses 4 spaces for indentation which is hardcoded and not configurable and making it configurable is not planned.

This tool (`zigrefmt`) tries to reformats zig source code files from zigs default format (4 spaces) to the supplied formatting.

It is expected to be run after `zig fmt` was run, so that the source code was already formatted using zig's default indentation settings. This way, it does not need to parse zig source code in any way, it just needs to read in the files line by line, detect the indentation level and reformat it according to the supplied parameters.

## Build
Execute `zig build --release=small` to build the executable for your platform.

## Test
Execute `zig build test` to run the tests.
