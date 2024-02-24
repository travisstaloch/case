const std = @import("std");
const case = @import("case");
const allocToZ = case.allocToZ;
const Case = case.Case;

pub export fn case_id_to_string(case_id: Case) [*:0]const u8 {
    return @tagName(case_id);
}

pub export fn case_id_has_options(case_id: Case) bool {
    return case_id.hasOptions();
}

pub export fn case_to(
    case_id: Case,
    text: [*]const u8,
    text_len: usize,
) ?[*:0]u8 {
    return switch (case_id) {
        inline .upper,
        .lower,
        .capital,
        => |tag| case.allocToZExt(
            std.heap.c_allocator,
            tag,
            text[0..text_len],
            .{},
        ) catch
            null,
        .unknown => null,
        inline else => |tag| allocToZ(
            std.heap.c_allocator,
            tag,
            text[0..text_len],
        ) catch
            null,
    };
}

pub export fn case_to_ext(
    case_id: Case,
    text: [*]const u8,
    text_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) ?[*:0]u8 {
    switch (case_id) {
        else => |tag| std.debug.panic(
            "case_to_ext(): case '{s}' doesn't accept options.",
            .{@tagName(tag)},
        ),
        .unknown => return null,
        inline .upper,
        .lower,
        .capital,
        => |tag| {
            return case.allocToZExt(
                std.heap.c_allocator,
                tag,
                text[0..text_len],
                .{
                    .fill = fill_text[0..fill_text_len],
                    .apostrophes = if (keep_apostrophes) .keep else .remove,
                },
            ) catch
                null;
        },
    }

    unreachable;
}

pub export fn case_buf_to(
    case_id: Case,
    text: [*]const u8,
    text_len: usize,
    buf: [*]u8,
    buf_len: usize,
) ?[*:0]u8 {
    switch (case_id) {
        inline .upper,
        .lower,
        .capital,
        => |tag| {
            const result = case.bufToExt(
                buf[0..buf_len],
                tag,
                text[0..text_len],
                .{},
            ) catch return null;
            buf[result.len] = 0;
            return @ptrCast(result.ptr);
        },
        .unknown => return null,
        inline else => |tag| {
            const result = case.bufTo(
                buf[0..buf_len],
                tag,
                text[0..text_len],
            ) catch return null;
            buf[result.len] = 0;
            return @ptrCast(result.ptr);
        },
    }
    unreachable;
}

pub export fn case_buf_to_ext(
    case_id: Case,
    text: [*]const u8,
    text_len: usize,
    buf: [*]u8,
    buf_len: usize,
    fill_text: [*]const u8,
    fill_text_len: usize,
    keep_apostrophes: bool,
) ?[*:0]u8 {
    return switch (case_id) {
        else => |tag| std.debug.panic(
            "case_buf_to_ext(): case '{s}' doesn't accept options.",
            .{@tagName(tag)},
        ),
        .unknown => null,
        inline .upper,
        .lower,
        .capital,
        => |tag| blk: {
            const result = case.bufToExt(
                buf[0..buf_len],
                tag,
                text[0..text_len],
                .{
                    .fill = fill_text[0..fill_text_len],
                    .apostrophes = if (keep_apostrophes) .keep else .remove,
                },
            ) catch return null;
            buf[result.len] = 0;
            break :blk @ptrCast(result.ptr);
        },
    };
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
    return case.of(text[0..text_len], .{});
}
