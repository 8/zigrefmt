//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const FormatType = enum {
  const Self = @This();

  tab,
  space,

  pub fn toChar(self: Self) u8 {
    return switch (self) {
      FormatType.tab => '\t',
      FormatType.space => ' ',
    };
  }
};

pub const Format = struct {
  type: FormatType,
  len: usize,

  pub const default: Format = Format { .type = .space, .len = 4 };
};

pub const FormatOptions = struct {
  input: Format = Format.default,
  output: Format = Format.default,

  pub fn toSpaces(len: u8) FormatOptions {
    return FormatOptions {
      .output = Format {
        .type = .space,
        .len = len,
      }
    };
  }

  pub fn toTabs(len: u8) FormatOptions {
    return FormatOptions {
      .output = Format {
        .type = .tab,
        .len = len,
      }
    };
  }
};

pub const FormatError = error {
  /// The supplied input text was not found to be indented according the supplied input format.
  /// Did you run `zig fmt` before?
  InputFormatError,

  /// As much as possible was written to the buffer, but it was too small to fit all the printed bytes.
  NoSpaceLeft
};

/// Formats the line into buf given the supplied options
pub fn formatLine(line: []const u8, buf: []u8, options: FormatOptions) FormatError![]u8 {

  // get the number of identations
  const indentations = try getIndentations(line, options.input);

  // print the output indentations
  const indent = options.output.type.toChar();
  var fbs = std.Io.fixedBufferStream(buf);
  var writer = fbs.writer();
  for (0..indentations) |_| {
    for (0..options.output.len) |_| {
      try writer.print("{c}", .{indent});
    }
  }

  // print the rest of the line
  const rest_start_index = indentations * options.input.len;
  try writer.print("{s}", .{line[rest_start_index..]});

  // return the slice
  return buf[0..indentations*options.output.len + line.len - rest_start_index];
}

test "formatLine() outputs line if no indentation is detected" {
  // arrange
  const line = "const std = @import(\"std\");";
  var buf: [line.len]u8 = undefined;

  // act
  const result = try formatLine(line, &buf, FormatOptions.toSpaces(2));

  // assert
  try std.testing.expectEqualSlices(u8, line, result);
}

test "formatLine() changes indent from 4 to 2 spaces" {
  // arrange
  const line = "    // Prints to stderr, ignoring potential errors.";
  const expected = "  // Prints to stderr, ignoring potential errors.";
  var buf: [line.len]u8 = undefined;

  // act
  const result = try formatLine(line, &buf, FormatOptions.toSpaces(2));

  // assert
  try std.testing.expectEqualSlices(u8, expected, result);
}

test "formatLine() changes indent from 8 to 4 spaces" {
  // arrange
  const line = "        // The root source file is the \"entry point\" of this module. Users of";
  const expected = "    // The root source file is the \"entry point\" of this module. Users of";
  var buf: [line.len]u8 = undefined;

  // act
  const result = try formatLine(line, &buf, FormatOptions.toSpaces(2));

  // assert
  try std.testing.expectEqualSlices(u8, expected, result);
}

test "formatLine() fails if line is not correctly formatted" {
  // arrange
  const line = "   // The root source file is the \"entry point\" of this module. Users of";
  const expected_error = FormatError.InputFormatError;
  var buf: [line.len]u8 = undefined;

  // act
  const result = formatLine(line, &buf, .{});

  // assert
  try std.testing.expectError(expected_error, result);
}

test "formatLine() fails if buf is not large enough" {
  // arrange
  const line = "    // The root source file is the \"entry point\" of this module. Users of";
  const expected_error = FormatError.NoSpaceLeft;
  var buf: [line.len]u8 = undefined;

  // act
  const result = formatLine(line, &buf, FormatOptions.toSpaces(8));

  // assert
  try std.testing.expectError(expected_error, result);
}

fn getIndentationCharLength(indent: u8, line: []const u8) usize {
  var indentation_level: usize = 0;
  for (line, 0..) |c,i| {
    if (c != indent) {
      indentation_level = i;
      break;
    }
  }
  return indentation_level;
}

pub fn getIndentations(line: []const u8, format: Format) FormatError!usize {
  const indent_char_len = getIndentationCharLength(format.type.toChar(), line);

  return if ((indent_char_len % format.len) == 0)
    indent_char_len / format.len
  else
    FormatError.InputFormatError;
}

test "getIndentation() 0" {
  // arrange
  const line = "const std = @import(\"std\");";
  const format = Format.default;

  // act
  const indentation = try getIndentations(line, format);

  // assert
  try std.testing.expectEqual(0, indentation);
}

test "getIndentation() 1" {
  // arrange
  const line = "    // Prints to stderr, ignoring potential errors.";
  const format = Format.default;

  // act
  const indentation = try getIndentations(line, format);

  // assert
  try std.testing.expectEqual(1, indentation);
}

test "getIndentation() 2" {
  // arrange
  const line = "        // The root source file is the \"entry point\" of this module. Users of";
  const format = Format.default;

  // act
  const indentation = try getIndentations(line, format);

  // assert
  try std.testing.expectEqual(2, indentation);
}
