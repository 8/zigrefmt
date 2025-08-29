const std = @import("std");
const postfmt = @import("postfmt");

const Error = postfmt.FormatError || std.process.Child.RunError || error { ZigFormatError };

pub fn main() !void {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  defer _ = gpa.deinit();

  // first call `zig fmt` to format all files
  try execZigFmt(allocator);
}

/// execute `zig fmt` in the current directory
fn execZigFmt(allocator: std.mem.Allocator) Error!void {

  const argv : [3][]const u8 = .{"bash", "-c", "pwd"};

  const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &argv,
  });
  defer allocator.free(result.stdout);
  defer allocator.free(result.stderr);

  if (result.term.Exited != 0) {
    return Error.ZigFormatError;
  }

  std.debug.print("exited: {}\nstdout: {s}\nstderr:{s}\n", .{
    result.term.Exited,
    result.stdout,
    result.stderr
  });

}
