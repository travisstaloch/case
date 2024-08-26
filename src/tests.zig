//! $ zig build test
//! $ valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes zig-out/bin/test

const std = @import("std");
const testing = std.testing;
const case = @import("case");
const c = @import("c_api.zig");

fn getExpected(_expected: []const u8, fromcase: case.Case, tocase: case.Case) []const u8 {
    return if (!fromcase.hasOptions() and tocase == .capital)
        expected_texts.capital_no_punct
    else
        _expected;
}

fn expectCase(
    comptime initial: []const u8,
    comptime _expected: []const u8,
    comptime fromcase: case.Case,
    comptime tocase: case.Case,
    comptime opts: case.Options,
) !void {
    @setEvalBranchQuota(155_000);
    var buf: [initial.len * 20]u8 = undefined;
    const actual = if (comptime tocase.hasOptions())
        try case.bufToExt(&buf, tocase, initial, opts)
    else
        try case.bufTo(&buf, tocase, initial);
    const expected = if (fromcase != .unknown)
        getExpected(_expected, fromcase, tocase)
    else
        _expected;

    if (!@inComptime()) {
        try testing.expectEqualStrings(expected, actual);
    } else if (!std.mem.eql(u8, expected, actual)) {
        @compileError(std.fmt.comptimePrint(
            "unexpected result. from {s} to {s} '{s}'. expected '{s}' got '{s}'",
            .{
                @tagName(fromcase),
                @tagName(tocase),
                initial,
                expected,
                actual,
            },
        ));
    }
}

// ensure all values correspond to the Case enum defined in src/case.h
test "check enum values" {
    const ch = @cImport({
        @cInclude("./case.h");
    });
    inline for (comptime std.meta.tags(case.Case)) |tag| {
        comptime {
            const tag_name = @tagName(tag);
            var const_tag: [tag_name.len]u8 = undefined;
            for (0..const_tag.len) |i| const_tag[i] = std.ascii.toUpper(tag_name[i]);
            const id = "CASE_" ++ const_tag;
            const cid = @field(ch, id);
            std.debug.assert(cid == @intFromEnum(tag));
        }
    }
}

test "basic cases" {
    try expectCase("foo_bar", "FOO BAR", .unknown, .upper, .{});
    try expectCase("fooBar", "foo bar", .unknown, .lower, .{});
    try expectCase("foo_v_bar", "Foo V Bar", .unknown, .capital, .{});

    try expectCaseCApi("foo_bar", "FOO BAR", .unknown, .upper, .{});
    try expectCaseCApi("fooBar", "foo bar", .unknown, .lower, .{});
    try expectCaseCApi("foo_v_bar", "Foo V Bar", .unknown, .capital, .{});
}

test "code cases" {
    try expectCase("Foo bar!", "foo_bar", .unknown, .snake, .{});
    try expectCase("foo.bar", "FooBar", .unknown, .pascal, .{});
    try expectCase("foo, bar", "fooBar", .unknown, .camel, .{});
    try expectCase("Foo? Bar.", "foo-bar", .unknown, .kebab, .{});
    try expectCase("fooBar=", "Foo-Bar", .unknown, .header, .{});
    try expectCase("Foo-Bar", "FOO_BAR", .unknown, .constant, .{});

    try expectCaseCApi("Foo bar!", "foo_bar", .unknown, .snake, .{});
    try expectCaseCApi("foo.bar", "FooBar", .unknown, .pascal, .{});
    try expectCaseCApi("foo, bar", "fooBar", .unknown, .camel, .{});
    try expectCaseCApi("Foo? Bar.", "foo-bar", .unknown, .kebab, .{});
    try expectCaseCApi("fooBar=", "Foo-Bar", .unknown, .header, .{});
    try expectCaseCApi("Foo-Bar", "FOO_BAR", .unknown, .constant, .{});
}

// test "title cases" {
//     try expectCase("foo v. bar", "Foo v. Bar", .title, .{});
//     try expectCase("foo V. bar", "Foo v. Bar", .title, .{});
// }

test "custom options" {
    try expectCase("FOO-BAR", "foo.bar", .unknown, .lower, .{ .fill = "." });
    try expectCase("Foo? Bar.", "FOO__BAR", .unknown, .upper, .{ .fill = "__" });
    try expectCase("fooBar", "Foo + Bar", .unknown, .capital, .{ .fill = " + " });
    try expectCase("Don't keep 'em!", "dont/keep/em", .unknown, .lower, .{
        .fill = "/",
        .apostrophes = .remove,
    });
    try expectCase("'ello, world.", "Ello, World.", .unknown, .capital, .{
        .apostrophes = .remove,
    });

    try expectCaseCApi("FOO-BAR", "foo.bar", .unknown, .lower, .{ .fill = "." });
    try expectCaseCApi("Foo? Bar.", "FOO__BAR", .unknown, .upper, .{ .fill = "__" });
    try expectCaseCApi("fooBar", "Foo + Bar", .unknown, .capital, .{ .fill = " + " });
    try expectCaseCApi("Don't keep 'em!", "dont/keep/em", .unknown, .lower, .{
        .fill = "/",
        .apostrophes = .remove,
    });
    try expectCaseCApi("'ello, world.", "Ello, World.", .unknown, .capital, .{
        .apostrophes = .remove,
    });
}

const texts = .{
    .upper = @as([]const u8, "THIS IS NICE AND TIDY, NATHAN."),
    .lower = @as([]const u8, "this is nice and tidy, nathan."),
    .capital = @as([]const u8, "This Is Nice And Tidy, Nathan."),
    .camel = @as([]const u8, "thisIsNiceAndTidyNathan"),
    .pascal = @as([]const u8, "ThisIsNiceAndTidyNathan"),
    .snake = @as([]const u8, "this_is_nice_and_tidy_nathan"),
    .kebab = @as([]const u8, "this-is-nice-and-tidy-nathan"),
    .header = @as([]const u8, "This-Is-Nice-And-Tidy-Nathan"),
    .constant = @as([]const u8, "THIS_IS_NICE_AND_TIDY_NATHAN"),
    // .sentence = @as([]const u8, "This is nice and tidy, Nathan."),
    // .title = @as([]const u8, "This Is Nice and Tidy, Nathan."),
};

const expected_texts = .{
    .upper = @as([]const u8, "THIS IS NICE AND TIDY NATHAN"),
    .lower = @as([]const u8, "this is nice and tidy nathan"),
    .capital = @as([]const u8, "This Is Nice And Tidy, Nathan."),
    .capital_no_punct = @as([]const u8, "This Is Nice And Tidy Nathan"),
    .camel = @as([]const u8, "thisIsNiceAndTidyNathan"),
    .pascal = @as([]const u8, "ThisIsNiceAndTidyNathan"),
    .snake = @as([]const u8, "this_is_nice_and_tidy_nathan"),
    .kebab = @as([]const u8, "this-is-nice-and-tidy-nathan"),
    .header = @as([]const u8, "This-Is-Nice-And-Tidy-Nathan"),
    .constant = @as([]const u8, "THIS_IS_NICE_AND_TIDY_NATHAN"),
    // .sentence = @as([]const u8, "This is nice and tidy, Nathan."),
    // .title = @as([]const u8, "This Is Nice and Tidy, Nathan."),
};

const case_tags = std.meta.tags(case.Case);

test "conversions" {
    inline for (case_tags) |fromcase| {
        if (fromcase == .unknown) continue;
        inline for (case_tags) |tocase| {
            if (tocase == .unknown) continue;
            const from_text = @field(texts, @tagName(fromcase));
            const to_text = @field(expected_texts, @tagName(tocase));
            // std.debug.print("from {s: >10}:{s}\n", .{ @tagName(fromcase), from_text });
            // std.debug.print("to   {s: >10}:{s}\n", .{ @tagName(tocase), to_text });
            try expectCase(from_text, to_text, fromcase, tocase, .{});
            comptime expectCase(from_text, to_text, fromcase, tocase, .{}) catch |e| {
                const errmsg = std.fmt.comptimePrint(
                    "err={s} from_text={s} fromcase={s} to_text={s} tocase={s}",
                    .{ @errorName(e), from_text, @tagName(fromcase), to_text, @tagName(tocase) },
                );
                @compileError(errmsg);
            };
        }
    }
}

test "edge cases" {
    // digits
    try expectCase("one 2 three", "one_2_three", .unknown, .snake, .{});
    try expectCase("one2Three", "one2_three", .unknown, .snake, .{});
    try expectCase("one2Three4", "one2_three4", .unknown, .snake, .{});
}

test "fuzz" {
    const alphabet = "abcdefABCDEF-_ .,";
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();
    const len = 50;
    const buf = try std.testing.allocator.alloc(u8, len);
    const buf2 = try std.testing.allocator.alloc(u8, len * 2);
    defer std.testing.allocator.free(buf);
    defer std.testing.allocator.free(buf2);
    for (0..1_000) |_| {
        for (0..len) |i| {
            buf[i] = alphabet[rand.intRangeAtMost(u8, 0, alphabet.len)];
        }
        // std.debug.print("{s}\n", .{buf});
        inline for (case_tags) |tocase| {
            if (tocase == .unknown) continue;
            var rfbs = std.io.fixedBufferStream(buf);
            var wfbs = std.io.fixedBufferStream(buf2);
            const caseFn = @field(case, @tagName(tocase));
            if (comptime tocase.hasOptions())
                try caseFn(rfbs.reader(), wfbs.writer(), .{})
            else
                try caseFn(rfbs.reader(), wfbs.writer());
            // std.debug.print("to-{s} '{s}'\n", .{ @tagName(tocase), wfbs.getWritten() });
        }
    }
}

fn expectCaseId(comptime text: []const u8, comptime case_tag: case.Case) !void {
    const tag_name = @tagName(case_tag);
    const first_upper: []const u8 = &[_]u8{comptime std.ascii.toUpper(tag_name[0])};
    const case_fn_name = "is" ++ first_upper ++ tag_name[1..];
    // comptime try case.comptimeTo(.pascal, tag_name);
    const isCaseFn = &@field(case, case_fn_name);

    testing.expect(isCaseFn(text)) catch |e| {
        std.log.err("expectCaseId() failure. !{s}('{s}')", .{ case_fn_name, text });
        return e;
    };
    testing.expectEqual(case_tag, case.of(text, .{ .eval_branch_quota = 2000 })) catch |e| {
        std.log.err(
            "expectCaseId() failure. expected case.of('{s}') to be '{s}'. got '{s}'",
            .{ text, tag_name, @tagName(case.of(text, .{})) },
        );
        return e;
    };
}

fn expectCaseIdCApi(comptime text: []const u8, comptime case_tag: case.Case) !void {
    @setEvalBranchQuota(4000);
    const tag_name = @tagName(case_tag);
    const is_case_fn_name = "case_is_" ++ tag_name;
    const isCaseFn = &@field(c, is_case_fn_name);

    testing.expect(isCaseFn(text.ptr, text.len)) catch |e| {
        std.log.err("expectCaseId() failure. !{s}('{s}')", .{ is_case_fn_name, text });
        return e;
    };
    testing.expectEqual(case_tag, c.case_of(text.ptr, text.len)) catch |e| {
        std.log.err(
            "expectCaseId() failure. expected case.of('{s}') to be '{s}'. got '{s}'",
            .{ text, tag_name, @tagName(case.of(text, .{})) },
        );
        return e;
    };
}

test "identify" {
    inline for (case_tags) |case_tag| {
        if (case_tag == .unknown) return;
        const text = @field(expected_texts, @tagName(case_tag));
        try expectCaseId(text, case_tag);
        try comptime expectCaseId(text, case_tag);
        try expectCaseIdCApi(text, case_tag);
    }
}

fn expectToCaseAlloc(
    allocator: std.mem.Allocator,
    comptime initial: []const u8,
    comptime _expected: []const u8,
    comptime fromcase: case.Case,
    comptime tocase: case.Case,
    opts: case.Options,
) !void {
    const actual = if (comptime tocase.hasOptions())
        try case.allocToExt(allocator, tocase, initial, opts)
    else
        try case.allocTo(allocator, tocase, initial);
    defer allocator.free(actual);
    const expected = getExpected(_expected, fromcase, tocase);
    try testing.expectEqualStrings(expected, actual);
}

test "allocTo" {
    inline for (case_tags) |fromcase| {
        if (fromcase == .unknown) continue;
        inline for (case_tags) |tocase| {
            if (tocase == .unknown) continue;
            const from_text = @field(texts, @tagName(fromcase));
            const to_text = @field(expected_texts, @tagName(tocase));
            try expectToCaseAlloc(
                testing.allocator,
                from_text,
                to_text,
                fromcase,
                tocase,
                .{},
            );
        }
    }
}

fn expectCaseCApi(
    comptime initial: []const u8,
    comptime _expected: []const u8,
    comptime fromcase: case.Case,
    comptime tocase: case.Case,
    comptime opts: case.Options,
) !void {
    const actual = if (comptime tocase.hasOptions())
        c.case_to_ext(
            tocase,
            initial.ptr,
            initial.len,
            opts.fill.ptr,
            opts.fill.len,
            opts.apostrophes == .keep,
        )
    else
        c.case_to(tocase, initial.ptr, initial.len);
    defer std.heap.c_allocator.free(std.mem.span(actual.?));

    const expected = if (fromcase != .unknown)
        getExpected(_expected, fromcase, tocase)
    else
        _expected;
    try testing.expectEqualStrings(expected, std.mem.span(actual.?));
}

test "c api" {
    inline for (case_tags) |fromcase| {
        if (fromcase == .unknown) continue;
        inline for (case_tags) |tocase| {
            if (tocase == .unknown) continue;
            const from_text = @field(texts, @tagName(fromcase));
            const to_text = @field(expected_texts, @tagName(tocase));

            try expectCaseCApi(from_text, to_text, fromcase, tocase, .{});
        }
    }
}
