const std = @import("std");
const clap = @import("clap");

const params = clap.parseParamsComptime(
  \\-h, --help
  \\        Display this help and exit.
  \\<file>...
);

const parsers = .{
  .file = clap.parsers.string,
};

const Result = clap.Result(clap.Help, &params, parsers);

pub fn get(allocator: std.mem.Allocator) !Result {

  var diag = clap.Diagnostic{};
  const res = clap.parse(clap.Help, &params, parsers, .{
    .diagnostic = &diag,
    .allocator = allocator,
  }) catch |err| {
    try diag.reportToFile(.stderr(), err);
    return err;
  };
  return res;
}

pub fn printUsage() !void {
  try std.fs.File.stderr().writeAll(
    \\Usage: zigrefmt [file]...
    \\
    \\    Formats the input files and modifies them in-place.
    \\    Arguments can be files or directories, which are searched
    \\    recursively.
    \\
    \\Options:
    \\
  );
  try clap.helpToFile(.stderr(), clap.Help, &params, .{});
}