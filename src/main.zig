const std = @import("std");
const postfmt = @import("postfmt");

const Error = postfmt.FormatError || std.process.Child.RunError || error { ZigFormatError, ArgError };

pub fn main() !void {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  defer _ = gpa.deinit();

  const maybe_file = try getFile(allocator);

  if (maybe_file) |file| {

    // first call `zig fmt` to format all files
    try execZigFmt(allocator, file);

    // then fix the identation
    try fixIndentation(file);

  } else {
    std.debug.print("error: expected at least one source file argument\n", .{});
    return error.ArgError;
  }
}

fn getFile(allocator: std.mem.Allocator) !?[]const u8 {
  var args = try std.process.argsWithAllocator(allocator);
  defer args.deinit();

  var i: usize = 0;
  while (args.next()) |arg| {
    if (i == 1) {
      return arg;
    }
    i=i+1;
  }

  return null;
}

/// execute `zig fmt` in the current directory
fn execZigFmt(allocator: std.mem.Allocator, file: []const u8) Error!void {

  const argv: [3][]const u8 = .{"zig", "fmt", file};

  const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &argv,
  });
  defer {
    allocator.free(result.stdout);
    allocator.free(result.stderr);
  }

  if (result.term.Exited != 0) {
    return Error.ZigFormatError;
  }

  // std.debug.print("exited: {}\nstdout: {s}\nstderr:{s}\n", .{
  //   result.term.Exited,
  //   result.stdout,
  //   result.stderr
  // });
}

fn fixIndentation(file: []const u8) !void{

  _ = file;
}