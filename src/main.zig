const std = @import("std");
const zigrefmt = @import("zigrefmt");
const Error =  error { ZigFormatError, ArgError };

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

    // todo: parse the format from the commandline options
    const format = zigrefmt.FormatOptions.toSpaces(2);

    try fixIndentationForPath(dir, file, format);

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
fn execZigFmt(allocator: std.mem.Allocator, file: []const u8) anyerror!void {

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
}

fn isZigFile(file: []const u8) bool {
  const extension = std.fs.path.extension(file);
  return std.mem.eql(u8, ".zig", extension) or
         std.mem.eql(u8, ".zon", extension);
}

fn fixIndentationForPath(dir: std.fs.Dir, path: []const u8, format: zigrefmt.FormatOptions) anyerror!void {

  const file_or_directory = try dir.openFile(path, .{});
  defer file_or_directory.close();

  const stat = try file_or_directory.stat();

  return switch (stat.kind) {
    // if it's a directory instead of a file, use Dir instead of File
    .directory => fixIndentationForDirectory(std.fs.Dir { .fd = file_or_directory.handle }, format),
    .file => if (isZigFile(path)) { try fixIndentationForFile(file_or_directory, path, dir, format); },
    else => {},
  };
}

fn fixIndentationForDirectory(directory: std.fs.Dir, format: zigrefmt.FormatOptions) anyerror!void {

  var iterator = directory.iterate();
  while (iterator.next()) |maybe_entry| {
    if (maybe_entry) |entry| {
      try fixIndentationForPath(directory, entry.name, format);
    } else {
      return;
    }
  } else |err| {
    return err;
  }
}

fn fixIndentationForFile(input_file: std.fs.File, name: []const u8, dir: std.fs.Dir, format: zigrefmt.FormatOptions) !void {
  // todo: pass the buffers into the function
  // todo: move the function to root.zig to make it reusable
  const line_buf_len = 1024 * 8;

  var line_read_buffer: [line_buf_len] u8 = undefined;
  var reader = input_file.reader(&line_read_buffer);

  // create a new temp file for writing in the same directory
  var temp_file_name_buf: [1024]u8 = undefined;
  const temp_file_name = try std.fmt.bufPrint(&temp_file_name_buf, ".{s}.bak", .{ name });
  const temp_file = try dir.createFile(temp_file_name, .{.lock = .exclusive });
  defer temp_file.close();

  var line_write_buffer: [line_buf_len] u8 = undefined;
  var writer = temp_file.writer(&line_write_buffer);
  var format_line_buffer: [line_buf_len] u8 = undefined;

  // read the file line by line...
  while (reader.interface.takeDelimiterInclusive('\n')) |line| {
    // ...format it...
    const formatted_line = try zigrefmt.formatLine(line, &format_line_buffer, format);
    // ... and write it to the temp. file
    try writer.interface.writeAll(formatted_line);
  } else |err|{
    if (err != error.EndOfStream)
      return err;
  }
  try writer.interface.flush();

  // now replace the old file with the new file
  _ = try std.fs.Dir.updateFile(dir, temp_file_name, dir, name, .{});

  // and remove the temp file
  try dir.deleteFile(temp_file_name);
}
