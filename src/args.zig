const std = @import("std");
const clap = @import("clap");

const params = clap.parseParamsComptime(
  \\-h, --help           Display this help and exit.
  \\-s, --spaces <int>   The number of spaces to use as the indent size.
  \\-t, --tabs <int>     The number of tabs to use as the indent size.
  \\<file>               The file or directory to format.
);

const parsers = .{
  .int = clap.parsers.int(usize, 10),
  .file = clap.parsers.string,
};

const Result = clap.Result(clap.Help, &params, parsers);

pub fn get(io: std.Io, arguments: std.process.Args, allocator: std.mem.Allocator) !Result {
  var diag = clap.Diagnostic{};
  const res = clap.parse(clap.Help, &params, parsers, arguments, .{
    .diagnostic = &diag,
    .allocator = allocator,
  }) catch |err| {
    try diag.reportToFile(io, .stderr(), err);
    return err;
  };
  return res;
}

pub fn printUsage(io: std.Io) !void {
  try std.Io.File.stderr().writeStreamingAll(io,
    \\Usage: zigrefmt [file]...
    \\
    \\    Formats the input files and modifies them in-place.
    \\    Arguments can be files or directories, which are searched
    \\    recursively.
    \\
    \\    Only formats .zig or .zon files.
    \\
    \\Example: zigrefmt . -s 2
    \\    Formats all files in the current folder and it's subfolders
    \\    using an indentation of 2 spaces.
    \\
    \\Options:
    \\
  );
  try clap.helpToFile(io, .stderr(), clap.Help, &params, .{});
}
