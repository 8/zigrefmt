const std = @import("std");
const postfmt = @import("postfmt");

const Error = postfmt.FormatError ||
                    std.process.Child.RunError ||
                    std.fs.File.OpenError ||
                    std.fs.Dir.StatError ||
                    std.io.Reader.DelimiterError ||
                    error { ZigFormatError, ArgError };

pub fn main() !void {

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  defer _ = gpa.deinit();

  const maybe_file = try getFile(allocator);

  if (maybe_file) |file| {

    // first call `zig fmt` to format all files
    try execZigFmt(allocator, file);

    // then fix the identation
    const dir = std.fs.cwd();
    try fixIndentationForPath(dir, file);

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

/// execute `zig fmt` with the provided file/directory
fn execZigFmt(allocator: std.mem.Allocator, file: []const u8) Error!void {

  // const argv: [3][]const u8 = .{"zig", "fmt", file};
  const argv = [_][]const u8{"zig", "fmt", file};

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

fn fixIndentationForPath(dir: std.fs.Dir, path: []const u8) Error!void {

  const file_or_directory = try dir.openFile(path, .{});
  defer file_or_directory.close();

  const stat = try file_or_directory.stat();

  return switch (stat.kind) {
    .directory => fixIndentationForDirectory(std.fs.Dir { .fd = file_or_directory.handle } ),
    .file => fixIndentationForFile(file_or_directory),
    else => {},
  };
}

fn fixIndentationForDirectory(directory: std.fs.Dir) Error!void {

  // std.debug.print("directory\n", .{});
  var iterator = directory.iterate();
  while (iterator.next()) |maybe_entry| {
    if (maybe_entry) |entry| {
      // std.debug.print("{s}\n", .{entry.name});
      try fixIndentationForPath(directory, entry.name);
    } else {
      return;
    }
  } else |err| {
    return err;
  }
}

fn fixIndentationForFile(input_file: std.fs.File) std.io.Reader.DelimiterError!void {

  var line_read_buffer: [1024*8] u8 = undefined;
  var reader = input_file.reader(&line_read_buffer);

  // create a new temp file for writing
  // std.fs.createFileAbsolute(absolute_path: []const u8, flags: CreateFlags)
  // const 
  // std.zip.
  // dir.createFile(, flags: CreateFlags)

  // read the file line by line
  while (reader.interface.takeDelimiterInclusive('\n')) |line| {
    std.debug.print("{s}", .{line});
  } else |err|{
    if (err != error.EndOfStream)
      return err;
  }
}
