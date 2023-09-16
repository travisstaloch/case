const std = @import("std");
const case = @import("case");
const allocZTo = case.allocZTo;
const Case = case.Case;

pub export fn case_upper(
    text: [*]const u8,
    text_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .upper, text[0..text_len], .{
        .fill = fill_text[0..fill_text_len],
        .apostrophes = if (keep_apostrophes) .keep else .remove,
    }) catch
        null;
}

pub export fn case_lower(
    text: [*]const u8,
    text_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .lower, text[0..text_len], .{
        .fill = fill_text[0..fill_text_len],
        .apostrophes = if (keep_apostrophes) .keep else .remove,
    }) catch
        null;
}

pub export fn case_capital(
    text: [*]const u8,
    text_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .capital, text[0..text_len], .{
        .fill = fill_text[0..fill_text_len],
        .apostrophes = if (keep_apostrophes) .keep else .remove,
    }) catch
        null;
}

pub export fn case_header(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .header, text[0..text_len], .{}) catch
        null;
}

pub export fn case_constant(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .constant, text[0..text_len], .{}) catch
        null;
}

pub export fn case_snake(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .snake, text[0..text_len], .{}) catch
        null;
}

pub export fn case_kebab(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .kebab, text[0..text_len], .{}) catch
        null;
}

pub export fn case_camel(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .camel, text[0..text_len], .{}) catch
        null;
}

pub export fn case_pascal(text: [*]const u8, text_len: usize) [*c]const u8 {
    return allocZTo(std.heap.c_allocator, .pascal, text[0..text_len], .{}) catch
        null;
}

pub export fn case_to_ext(
    case_id: u8,
    text: [*]const u8,
    text_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) [*c]const u8 {
    switch (@as(Case, @enumFromInt(case_id))) {
        .unknown => return null,
        inline else => |tag| return allocZTo(
            std.heap.c_allocator,
            tag,
            text[0..text_len],
            .{
                .fill = fill_text[0..fill_text_len],
                .apostrophes = if (keep_apostrophes) .keep else .remove,
            },
        ) catch
            null,
    }

    unreachable;
}

pub export fn case_to(
    case_id: u8,
    text: [*]const u8,
    text_len: usize,
) [*c]const u8 {
    switch (std.meta.intToEnum(Case, case_id) catch return null) {
        .unknown => return null,
        inline else => |tag| return allocZTo(
            std.heap.c_allocator,
            tag,
            text[0..text_len],
            .{},
        ) catch
            null,
    }
    unreachable;
}

pub export fn case_to_buf(
    case_id: u8,
    text: [*]const u8,
    text_len: usize,
    buf: [*]u8,
    buf_len: usize,
) [*c]const u8 {
    switch (std.meta.intToEnum(Case, case_id) catch return null) {
        .unknown => return null,
        inline else => |tag| {
            const result = case.bufTo(
                buf[0..buf_len],
                tag,
                text[0..text_len],
                .{},
            ) catch return null;
            buf[result.len] = 0;
            return result.ptr;
        },
    }
    unreachable;
}

pub export fn case_is_lower(text: [*]const u8, text_len: usize) bool {
    return case.isLower(text[0..text_len]);
}

pub export fn case_is_upper(text: [*]const u8, text_len: usize) bool {
    return case.isUpper(text[0..text_len]);
}

pub export fn case_is_capital(text: [*]const u8, text_len: usize) bool {
    return case.isCapital(text[0..text_len]);
}

pub export fn case_is_camel(text: [*]const u8, text_len: usize) bool {
    return case.isCamel(text[0..text_len]);
}

pub export fn case_is_pascal(text: [*]const u8, text_len: usize) bool {
    return case.isPascal(text[0..text_len]);
}

pub export fn case_is_snake(text: [*]const u8, text_len: usize) bool {
    return case.isSnake(text[0..text_len]);
}

pub export fn case_is_kebab(text: [*]const u8, text_len: usize) bool {
    return case.isKebab(text[0..text_len]);
}

pub export fn case_is_header(text: [*]const u8, text_len: usize) bool {
    return case.isHeader(text[0..text_len]);
}

pub export fn case_is_constant(text: [*]const u8, text_len: usize) bool {
    return case.isConstant(text[0..text_len]);
}

pub export fn case_of(text: [*]const u8, text_len: usize) Case {
    return case.of(text[0..text_len]);
}

pub export fn case_id_to_string(case_id: Case) [*:0]const u8 {
    return @tagName(case_id);
}
