const std = @import("std");

pub const ReadError = std.io.FixedBufferStream([]const u8).Reader.Error;
pub const WriteError = std.io.FixedBufferStream([]const u8).Writer.Error;
pub const Error = ReadError || WriteError || error{ EndOfStream, OutOfMemory };

/// the ordering of this enum is important because of() relies on more
/// restrictive cases coming before less restrictive ones. i've noticed that
/// 'capital' must be last or tests fail.
pub const Case = enum(u8) {
    camel,
    pascal,
    snake,
    constant,
    kebab,
    header,
    lower,
    upper,
    capital,
    unknown,

    /// principal case methods (upper, lower, capital) have an additional
    /// Options parameter.
    pub fn hasOptions(case: Case) bool {
        return case == .upper or case == .lower or case == .capital;
    }
};

const State = enum {
    whitespace,
    lower,
    upper,
    other,

    comptime {
        std.debug.assert(@typeInfo(State).@"enum".tag_type == u2);
    }

    pub fn int(a: State, b: State) u4 {
        return @as(u4, @intFromEnum(a)) << 2 | @intFromEnum(b);
    }

    pub fn classify(c: u8) State {
        return if (std.ascii.isLower(c) or std.ascii.isDigit(c))
            .lower
        else if (std.ascii.isUpper(c))
            .upper
        else if (std.ascii.isWhitespace(c))
            .whitespace
        else
            .other;
    }
};

pub const Options = struct {
    /// string to replace any non alpha numeric characters. default "".
    /// if empty, don't replace non alpha numeric characters.
    fill: []const u8 = "",
    /// whether or not to remove apostrophes. default keep.
    apostrophes: ApostropheMode = .keep,

    pub const ApostropheMode = enum { remove, keep };

    pub fn writeByte(opts: Options, c: u8, writer: anytype, mf: ?*const fn (u8) u8) !void {
        if (opts.fill.len != 0 and !std.ascii.isAlphanumeric(c)) {
            _ = try writer.write(opts.fill);
        } else if (opts.apostrophes == .remove and c == '\'') {
            // skip
        } else {
            try writer.writeByte(if (mf) |f| f(c) else c);
        }
    }
};

fn upperLowerImpl(
    reader: anytype,
    writer: anytype,
    opts: Options,
    comptime toCaseFn: fn (u8) u8,
) Error!void {
    var ring_buffer = std.fifo.LinearFifo(u8, .{ .Static = 2 }).init();
    const rbw = ring_buffer.writer();
    const rbr = ring_buffer.reader();
    var prevstate = State.whitespace;
    while (true) {
        if (reader.readByte()) |c| {
            try rbw.writeByte(c);
            if (ring_buffer.count != ring_buffer.buf.len) continue;
        } else |e| switch (e) {
            error.EndOfStream => {},
            else => return e,
        }

        const c = rbr.readByte() catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };
        if (c == '\'' and opts.apostrophes == .remove) continue;
        const cc = switch (State.classify(c)) {
            .other => ' ',
            else => c,
        };
        const state = State.classify(cc);
        switch (State.int(prevstate, state)) {
            // don't write 2 consecutive whitespaces
            State.int(.whitespace, .whitespace) => {},
            // for pascal/camel case conversion, add a space when
            // transitioning from lower to upper
            State.int(.lower, .upper) => {
                try opts.writeByte(' ', writer, null);
                try opts.writeByte(cc, writer, toCaseFn);
            },
            // don't write a final trailing whitespace
            else => if (state == .whitespace and ring_buffer.count == 0) {
                // skip
            } else try opts.writeByte(cc, writer, toCaseFn),
        }
        prevstate = state;
    }
}

// upper, lower, capital:
// accept an optional "fill" value that will replace any characters which are
// not letters and numbers. All three also accept a third optional boolean
// argument indicating if apostrophes are to be stripped out or left in.
pub fn upper(reader: anytype, writer: anytype, opts: Options) Error!void {
    return upperLowerImpl(reader, writer, opts, std.ascii.toUpper);
}

pub fn lower(reader: anytype, writer: anytype, opts: Options) Error!void {
    return upperLowerImpl(reader, writer, opts, std.ascii.toLower);
}

const CapitalCase = enum { capital, header };

fn capitalImpl(
    reader: anytype,
    writer: anytype,
    opts: Options,
    case: CapitalCase,
) Error!void {
    var ring_buffer = std.fifo.LinearFifo(u8, .{ .Static = 2 }).init();
    const rbw = ring_buffer.writer();
    const rbr = ring_buffer.reader();

    var prevstate = State.whitespace;
    while (true) {
        if (reader.readByte()) |c| {
            try rbw.writeByte(c);
            if (ring_buffer.count != ring_buffer.buf.len) continue;
        } else |e| switch (e) {
            error.EndOfStream => {},
            else => return e,
        }
        const c = rbr.readByte() catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };

        const state = State.classify(c);
        switch (State.int(prevstate, state)) {
            State.int(.upper, .upper) => try writer.writeByte(std.ascii.toLower(c)),
            State.int(.other, .lower),
            State.int(.whitespace, .lower),
            => try opts.writeByte(c, writer, std.ascii.toUpper),

            State.int(.whitespace, .upper),
            State.int(.other, .upper),
            => try opts.writeByte(c, writer, null),

            // for pascal/camel case conversion, add a space when
            // transitioning from lower to upper
            State.int(.lower, .upper) => {
                try opts.writeByte(' ', writer, null);
                try opts.writeByte(c, writer, null);
            },

            // capital - special case '_' and '-'
            State.int(.upper, .other),
            State.int(.lower, .other),
            => if (case == .capital)
                if (c == '_' or c == '-')
                    try opts.writeByte(' ', writer, null)
                else
                    try opts.writeByte(c, writer, null)
            else if (ring_buffer.count != 0)
                try opts.writeByte('-', writer, null),

            State.int(.upper, .whitespace),
            State.int(.lower, .whitespace),
            => if (case == .capital)
                try opts.writeByte(c, writer, null)
            else if (ring_buffer.count != 0)
                try opts.writeByte('-', writer, null),

            State.int(.whitespace, .whitespace),
            State.int(.other, .other),
            State.int(.other, .whitespace),
            State.int(.whitespace, .other),
            => if (case == .capital) try opts.writeByte(c, writer, null),

            State.int(.lower, .lower),
            State.int(.upper, .lower),
            => try opts.writeByte(c, writer, null),
        }
        prevstate = state;
    }
}

pub fn capital(reader: anytype, writer: anytype, opts: Options) Error!void {
    return capitalImpl(reader, writer, opts, .capital);
}

pub fn header(reader: anytype, writer: anytype) Error!void {
    return capitalImpl(reader, writer, .{ .fill = "-" }, .header);
}

fn constantImpl(
    reader: anytype,
    writer: anytype,
    opts: Options,
    comptime f: fn (u8) u8,
) Error!void {
    var ring_buffer = std.fifo.LinearFifo(u8, .{ .Static = 2 }).init();
    const rbw = ring_buffer.writer();
    const rbr = ring_buffer.reader();
    var prevstate = State.whitespace;
    while (true) {
        if (reader.readByte()) |c| {
            try rbw.writeByte(c);
            if (ring_buffer.count != ring_buffer.buf.len) continue;
        } else |e| switch (e) {
            error.EndOfStream => {},
            else => return e,
        }
        const c = rbr.readByte() catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };

        const state = State.classify(c);
        switch (State.int(prevstate, state)) {
            State.int(.upper, .whitespace),
            State.int(.lower, .whitespace),
            State.int(.upper, .other),
            State.int(.lower, .other),
            => if (ring_buffer.count != 0) try opts.writeByte(c, writer, null),

            State.int(.whitespace, .whitespace),
            State.int(.whitespace, .other),
            State.int(.other, .whitespace),
            State.int(.other, .other),
            => {},

            // for pascal/camel case conversion, add a space when
            // transitioning from lower to upper
            State.int(.lower, .upper) => {
                try opts.writeByte(' ', writer, null);
                try opts.writeByte(c, writer, f);
            },

            State.int(.whitespace, .lower),
            State.int(.other, .lower),
            State.int(.lower, .lower),
            State.int(.upper, .lower),
            State.int(.other, .upper),
            State.int(.upper, .upper),
            State.int(.whitespace, .upper),
            => try opts.writeByte(c, writer, f),
        }
        prevstate = state;
    }
}

pub fn constant(reader: anytype, writer: anytype) Error!void {
    return constantImpl(reader, writer, .{ .fill = "_" }, std.ascii.toUpper);
}

pub fn snake(reader: anytype, writer: anytype) Error!void {
    return constantImpl(reader, writer, .{ .fill = "_" }, std.ascii.toLower);
}

pub fn kebab(reader: anytype, writer: anytype) Error!void {
    return constantImpl(reader, writer, .{ .fill = "-" }, std.ascii.toLower);
}

const CamelCase = enum { camel, pascal };

fn camelImpl(reader: anytype, writer: anytype, comptime case: CamelCase) Error!void {
    var prevstate = State.whitespace;
    var bytes_read: usize = 0;
    while (true) : (bytes_read += 1) {
        const c = reader.readByte() catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };
        const state = State.classify(c);

        switch (State.int(prevstate, state)) {
            State.int(.upper, .whitespace),
            State.int(.lower, .whitespace),
            State.int(.other, .whitespace),
            State.int(.whitespace, .whitespace),
            State.int(.upper, .other),
            State.int(.lower, .other),
            State.int(.other, .other),
            State.int(.whitespace, .other),
            => {},

            State.int(.upper, .upper) => try writer.writeByte(std.ascii.toLower(c)),

            State.int(.other, .lower) => try writer.writeByte(std.ascii.toUpper(c)),

            State.int(.whitespace, .upper) => if (bytes_read == 0)
                (if (case == .camel)
                    try writer.writeByte(std.ascii.toLower(c))
                else if (case == .pascal)
                    try writer.writeByte(c)
                else
                    unreachable)
            else
                try writer.writeByte(c),

            State.int(.whitespace, .lower) => if (bytes_read == 0)
                (if (case == .pascal)
                    try writer.writeByte(std.ascii.toUpper(c))
                else
                    try writer.writeByte(c))
            else
                try writer.writeByte(std.ascii.toUpper(c)),

            State.int(.lower, .upper),
            State.int(.other, .upper),
            State.int(.lower, .lower),
            State.int(.upper, .lower),
            => try writer.writeByte(c),
        }
        prevstate = state;
    }
}

pub fn camel(reader: anytype, writer: anytype) Error!void {
    return camelImpl(reader, writer, .camel);
}

pub fn pascal(reader: anytype, writer: anytype) Error!void {
    return camelImpl(reader, writer, .pascal);
}

// TODO consider adding title case. this implementation works ok but isn't well
// defined or implemented.
// pub fn title(reader: anytype, writer: anytype) Error!void {
//     // convert the following words (only at word boundaries) to lower case.
//     // to do this, use a ring buffer with last N = 3 + 2 chars.  3 is the
//     // length of the longest word.  and we need one char on either side to check
//     // for word boundaries.
//     const words: []const []const u8 = &.{
//         "And", "An", "A",   "As", "At",  "But", "By",  "En",
//         "For", "If", "In",  "Of", "On",  "Or",  "The", "To",
//         "V.",  "V",  "Vs.", "Vs", "Via",
//     };
//     const max_words_len = 3;
//     var ring_buffer = std.fifo.LinearFifo(u8, .{
//         .Static = max_words_len + 2,
//     }).init();

//     const rbw = ring_buffer.writer();
//     const rbr = ring_buffer.reader();
//     // const is_camel_or_pascal = fill == .camel_or_pascal;
//     var prevstate = State.whitespace;

//     while (true) {
//         if (reader.readByte()) |cx| {
//             try rbw.writeByte(cx);
//             if (ring_buffer.count != ring_buffer.buf.len) continue;
//         } else |e| switch (e) {
//             error.EndOfStream => {},
//             else => return e,
//         }

//         // ring buffer is full. check for words
//         if (ring_buffer.count == ring_buffer.buf.len) blk: {
//             // only match if at word boundary
//             {
//                 const byte = ring_buffer.peekItem(0);
//                 if (!std.ascii.isLower(byte) and
//                     std.ascii.isAlphanumeric(byte))
//                     break :blk;
//             }

//             // check all words. if we match at a word boundary, convert word to
//             // lowercase
//             for (words) |word| {
//                 const found_word = for (word, 1..) |wc, i| {
//                     if (std.ascii.toLower(ring_buffer.peekItem(i)) !=
//                         std.ascii.toLower(wc)) break false;
//                 } else true;
//                 if (!found_word) continue;

//                 // only match if at word boundary
//                 const next_byte = ring_buffer.peekItem(word.len + 1);
//                 // camel case is at boundary if next byte after word is an upper
//                 const is_upper_at_boundary = std.ascii.isUpper(next_byte);
//                 if (!is_upper_at_boundary and
//                     std.ascii.isAlphanumeric(next_byte))
//                     continue;

//                 // found word. write in lowercase
//                 const byte = try rbr.readByte();
//                 const class = State.classify(byte);
//                 try writer.writeByte(if (class == .other) ' ' else byte);
//                 if (is_upper_at_boundary) try writer.writeByte(' ');
//                 var i: u8 = 0;
//                 while (i < ring_buffer.count) : (i += 1) {
//                     try writer.writeByte(std.ascii.toLower(try rbr.readByte()));
//                 }
//                 break;
//             }
//         }

//         const c = rbr.readByte() catch |e| switch (e) {
//             error.EndOfStream => break,
//             else => return e,
//         };
//         const state = State.classify(c);
//         try capitalImpl(c, prevstate, state, writer, .{}, ring_buffer.count == 0);
//         prevstate = state;
//     }
// }

/// converts to case from reader into writer. if case is upper, lower or capital
/// use default Options.
pub fn to(
    comptime case: Case,
    reader: anytype,
    writer: anytype,
) !void {
    const caseFn = @field(@This(), @tagName(case));
    if (comptime case.hasOptions())
        try caseFn(reader, writer, .{})
    else
        try caseFn(reader, writer);
}

/// converts to case from reader into writer with Options
pub fn toExt(
    comptime case: Case,
    reader: anytype,
    writer: anytype,
    opts: Options,
) !void {
    if (!comptime case.hasOptions())
        @compileError(std.fmt.comptimePrint(
            "toExt() case '{s}' doesn't accept options.",
            .{@tagName(case)},
        ))
    else
        try @field(@This(), @tagName(case))(reader, writer, opts);
}

/// writes converted text to buf in specified case
pub fn bufTo(
    buf: []u8,
    comptime case: Case,
    text: []const u8,
) ![]u8 {
    var rfbs = std.io.fixedBufferStream(text);
    var wfbs = std.io.fixedBufferStream(buf);
    try to(case, rfbs.reader(), wfbs.writer());
    return wfbs.getWritten();
}

/// writes converted text to buf in specified case with Options
pub fn bufToExt(
    buf: []u8,
    comptime case: Case,
    text: []const u8,
    opts: Options,
) ![]u8 {
    var rfbs = std.io.fixedBufferStream(text);
    var wfbs = std.io.fixedBufferStream(buf);
    try toExt(case, rfbs.reader(), wfbs.writer(), opts);
    return wfbs.getWritten();
}

/// returns length needed to convert text to case
pub fn length(
    comptime case: Case,
    text: []const u8,
) !usize {
    var cw = std.io.countingWriter(std.io.null_writer);
    var fbs = std.io.fixedBufferStream(text);
    try to(case, fbs.reader(), cw.writer());
    return cw.bytes_written;
}

pub fn lengthExt(
    comptime case: Case,
    text: []const u8,
    opts: Options,
) !usize {
    var cw = std.io.countingWriter(std.io.null_writer);
    var fbs = std.io.fixedBufferStream(text);
    try toExt(case, fbs.reader(), cw.writer(), opts);
    return cw.bytes_written;
}

/// allocates a buffer and writes converted text to buffer in specified case
pub fn allocTo(
    allocator: std.mem.Allocator,
    comptime case: Case,
    text: []const u8,
) ![]const u8 {
    const buf = try allocator.alloc(u8, try length(case, text));
    return bufTo(buf, case, text);
}

/// allocates a buffer and writes converted text to buffer in specified case
/// with Options
pub fn allocToExt(
    allocator: std.mem.Allocator,
    comptime case: Case,
    text: []const u8,
    opts: Options,
) ![]const u8 {
    const buf = try allocator.alloc(u8, try lengthExt(case, text, opts));
    return bufToExt(buf, case, text, opts);
}

/// same as allocTo() but returns a null terminated string
pub fn allocToZ(
    allocator: std.mem.Allocator,
    comptime case: Case,
    text: []const u8,
) ![:0]u8 {
    const len = try length(case, text);
    const buf = try allocator.allocSentinel(u8, len, 0);
    _ = try bufTo(buf, case, text);
    return buf;
}

/// same as allocToExt() but returns a null terminated string
pub fn allocToZExt(
    allocator: std.mem.Allocator,
    comptime case: Case,
    text: []const u8,
    opts: Options,
) ![:0]u8 {
    const len = try lengthExt(case, text, opts);
    const buf = try allocator.allocSentinel(u8, len, 0);
    _ = try bufToExt(buf, case, text, opts);
    return buf;
}

/// uses a counting writer to compute the required buffer len and then calls
/// comptimeToLen()
pub fn comptimeTo(
    comptime case: Case,
    comptime text: []const u8,
) ![]const u8 {
    comptime {
        var fbs = std.io.fixedBufferStream(text);
        var cw = std.io.countingWriter(std.io.null_writer);
        try to(case, fbs.reader(), cw.writer());
        const len = cw.bytes_written;
        return comptimeToLen(case, text, len);

        // uses a comptime allocated buffer 20% bigger than text.len which should almost
        // always be large enough. incase its not big enough, use comptimeToLen().
        //
        // // This is the old limit
        // return comptimeToLen(case, text,
        // // http://www.macfreek.nl/memory/Letter_Distribution says that
        // // the letter frequency of spaces is aound 18%
        // //
        // // TODO better buffer length estimate w/out using too much comptime
        // // quota. calling length() here uses quite a bit.
        // text.len * 5 / 2);
    }
}

/// uses a comptime allocated buffer 20% bigger than text.len which should almost
/// always be large enough. incase its not big enought, use comptimeToLenExt().
pub fn comptimeToExt(
    comptime case: Case,
    comptime text: []const u8,
    comptime opts: Options,
) ![]const u8 {
    comptime {
        return comptimeToLenExt(case, text,
        // http://www.macfreek.nl/memory/Letter_Distribution says that
        // the letter frequency of spaces is aound 18%
        //
        // TODO better buffer length estimate w/out using too much comptime
        // quota. calling length() here uses quite a bit.
        text.len * 5 / 4, opts);
    }
}

/// same as comptimeTo() but allows user to specify buffer len incase
/// comptimeTo()'s buffer estimate is too small
pub fn comptimeToLen(
    comptime case: Case,
    comptime text: []const u8,
    comptime len: usize,
) ![]const u8 {
    comptime {
        var buf: [len]u8 = undefined;
        return bufTo(&buf, case, text);
    }
}

/// same as comptimeToLen() but with Options
pub fn comptimeToLenExt(
    comptime case: Case,
    comptime text: []const u8,
    comptime len: usize,
    comptime opts: Options,
) ![]const u8 {
    comptime {
        var buf: [len]u8 = undefined;
        return bufToExt(&buf, case, text, opts);
    }
}

pub fn isLower(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isLower(c) and
            !std.ascii.isWhitespace(c)) break false;
    } else true;
}

pub fn isUpper(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isUpper(c) and
            !std.ascii.isWhitespace(c)) break false;
    } else true;
}

pub fn isCapital(text: []const u8) bool {
    var prevstate = State.whitespace;
    for (text) |c| {
        const state = State.classify(c);
        switch (State.int(prevstate, state)) {
            State.int(.whitespace, .lower) => return false,
            State.int(.upper, .other),
            State.int(.lower, .other),
            => if (c == '_' or c == '-') return false,
            else => {},
        }
        prevstate = state;
    }
    return true;
}

fn isCamelImpl(text: []const u8) bool {
    return for (text[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c)) break false;
    } else true;
}

pub fn isCamel(text: []const u8) bool {
    return text.len != 0 and
        std.ascii.isLower(text[0]) and
        isCamelImpl(text);
}

pub fn isPascal(text: []const u8) bool {
    return text.len != 0 and
        std.ascii.isUpper(text[0]) and
        isCamelImpl(text);
}

pub fn isSnake(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isLower(c) and c != '_') break false;
    } else true;
}

pub fn isKebab(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isLower(c) and c != '-') break false;
    } else true;
}

pub fn isHeader(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isAlphabetic(c) and c != '-') break false;
    } else true;
}

pub fn isConstant(text: []const u8) bool {
    return for (text) |c| {
        if (!std.ascii.isUpper(c) and c != '_') break false;
    } else true;
}

/// return `Case` of text. may be 'unknown'.
pub fn of(text: []const u8, comptime options: struct { eval_branch_quota: u32 = 1000 }) Case {
    @setEvalBranchQuota(options.eval_branch_quota);
    inline for (comptime std.meta.tags(Case)) |tag| {
        if (tag == .unknown) continue;
        const tag_name = @tagName(tag);
        const first_upper: []const u8 = &[_]u8{comptime std.ascii.toUpper(tag_name[0])};
        const case_fn_name = comptime "is" ++ first_upper ++ tag_name[1..];
        const isCaseFn = @field(@This(), case_fn_name);
        if (isCaseFn(text)) return tag;
    }
    return .unknown;
}
