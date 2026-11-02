const std = @import("std");
const zigrefmt = @import("zigrefmt");
const args = @import("args.zig");
const clap = @import("clap");

const Error = error{ ZigFormatError, ArgError };

pub fn main(init: std.process.Init) !void {
  const allocator = init.gpa;
  const io = init.io;

  // parse the arguments
  const res = try args.get(io, init.minimal.args, allocator);
  defer res.deinit();

  // todo: how can we combine commandline args with env vars and config files?
  if (res.args.help != 0) {
    try args.printUsage(io);
  } else {
    if (res.positionals[0]) |file_or_directory| {

      // parse the format from the commandline options
      const format =
        if (res.args.spaces) |spaces|
          zigrefmt.FormatOptions.toSpaces(spaces)
        else if (res.args.tabs) |tabs|
          zigrefmt.FormatOptions.toTabs(tabs)
        else {
          std.debug.print("error: expected --tabs or --spaces argument\n", .{});
          return error.ArgError;
        };

      try formatFiles(allocator, io, file_or_directory, format);
    } else {
      std.debug.print("error: expected at least one source file argument\n", .{});
      try args.printUsage(io);
      return error.ArgError;
    }
  }
}

fn formatFiles(
  allocator: std.mem.Allocator,
  io: std.Io,
  file_or_directory: []const u8,
  format: zigrefmt.FormatOptions) !void {

  // first call `zig fmt` to format all files
  try execZigFmt(allocator, io, file_or_directory);

  // then fix the identation
  const dir = std.Io.Dir.cwd();
  try fixIndentationForPath(io, dir, file_or_directory, format);
}

/// execute `zig fmt` with the provided file/directory
fn execZigFmt(
  allocator: std.mem.Allocator,
  io: std.Io,
  file: []const u8) anyerror!void {

  const argv = [_][]const u8{ "zig", "fmt", file };

  const result = try std.process.run(allocator, io, .{
    .argv = &argv,
  });
  defer {
    allocator.free(result.stdout);
    allocator.free(result.stderr);
  }

  if (!result.term.success()) {
    return Error.ZigFormatError;
  }
}

fn isZigFile(file: []const u8) bool {
  const extension = std.Io.Dir.path.extension(file);
  return std.mem.eql(u8, ".zig", extension) or
    std.mem.eql(u8, ".zon", extension);
}

fn fixIndentationForPath(
  io: std.Io,
  dir: std.Io.Dir,
  path: []const u8, format: zigrefmt.FormatOptions) anyerror!void {

  const file_or_directory = try dir.openFile(io, path, .{});
  defer file_or_directory.close(io);

  const stat = try file_or_directory.stat(io);

  return switch (stat.kind) {
    // if it's a directory instead of a file, use `Dir` instead of `File`
    .directory => fixIndentationForDirectory(io, .{ .handle = file_or_directory.handle }, format),
    .file => if (isZigFile(path)) {
      try fixIndentationForFile(io, file_or_directory, path, dir, format);
    },
    else => {},
  };
}

fn fixIndentationForDirectory(
  io: std.Io,
  directory: std.Io.Dir,
  format: zigrefmt.FormatOptions) anyerror!void {

  var iterator = directory.iterate();
  while (try iterator.next(io)) |entry| {
    try fixIndentationForPath(io, directory, entry.name, format);
  }
}

fn fixIndentationForFile(
  io: std.Io,
  input_file: std.Io.File,
  name: []const u8,
  dir: std.Io.Dir,
  format: zigrefmt.FormatOptions) !void {

  // todo: pass the buffers into the function?
  // todo: move the function to root.zig to make it reusable?
  const line_buf_len = 1024 * 8;

  var line_read_buffer: [line_buf_len]u8 = undefined;
  var reader = input_file.reader(io, &line_read_buffer);

  // create a new temp file for writing in the same directory
  var temp_file_name_buf: [1024]u8 = undefined;
  const temp_file_name = try std.fmt.bufPrint(&temp_file_name_buf, ".{s}.bak", .{name});
  const temp_file = try dir.createFile(io, temp_file_name, .{ .lock = .exclusive });
  defer temp_file.close(io);

  var line_write_buffer: [line_buf_len]u8 = undefined;
  var writer = temp_file.writer(io, &line_write_buffer);
  var format_line_buffer: [line_buf_len]u8 = undefined;

  // read the file line by line...
  while (reader.interface.takeDelimiterInclusive('\n')) |line| {
    // ...format it...
    const formatted_line = try zigrefmt.formatLine(line, &format_line_buffer, format);
    // ... and write it to the temp. file
    try writer.interface.writeAll(formatted_line);
  } else |err| {
    if (err != error.EndOfStream)
      return err;
  }
  try writer.interface.flush();

  // now replace the old file with the new file
  _ = try std.Io.Dir.updateFile(dir, io, temp_file_name, dir, name, .{});

  // and remove the temp file
  try dir.deleteFile(io, temp_file_name);
}
