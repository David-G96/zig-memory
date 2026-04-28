const std = @import("std");
const Layout = @import("mem.zig").Layout;
const Structure = @import("mem.zig").Structure;
const Allocator = std.mem.Allocator;

const Self = @This();

/// structure of the type, in bytes
structure: Structure,
/// layout of the type.
layout: Layout,

pub fn init(
    structure: Structure,
    alloc: Allocator,
) Allocator.Error!Self {
    return .{ .structure = structure, .layout = try Layout.init(structure.size, alloc) };
}

pub fn init_with_layout(name: []const u8, layout: Layout) Self {
    return Self{ .name = name, .size = layout.bit_length, .layout = layout };
}

pub fn mark_ref_at(self: *Self, idx: usize) void {
    self.layout.set(idx);
}

pub fn deinit(self: *Self, alloc: Allocator) void {
    self.layout.deinit(alloc);
}

/// 1-byte-type. e.g. bool
pub const Byte1 = Self{ .layout = .empty, .structure = .init(1, 1) };
pub const Byte2 = Self{ .layout = .empty, .structure = .init(2, 2) };
pub const Byte4 = Self{ .layout = .empty, .structure = .init(4, 4) };
pub const Byte8 = Self{ .layout = .empty, .structure = .init(8, 8) };
pub const Byte16 = Self{ .layout = .empty, .structure = .init(16, 16) };

/// alloc and create an object with specific memory structure
pub fn make(self: Self, alloc: Allocator) ?[]u8 {
    const alignment = std.mem.Alignment.fromByteUnits(self.structure.alignment);
    const res = alloc.rawAlloc(self.structure.size, alignment, 0);
    if (res) |notNull| {
        var ret: []u8 = undefined;
        ret.ptr = notNull;
        ret.len = self.structure.size;
        return ret;
    } else {
        return null;
    }
}

test "Meta data" {
    var A = try Self.init(Structure.concat(Byte1.structure, Byte8.structure), std.testing.allocator);
    defer A.deinit(std.testing.allocator);

    const maybePtr1 = A.make(std.testing.allocator);
    if (maybePtr1) |ptr1| {
        std.debug.print("\nsucceeds: {any}\n", .{ptr1.ptr});
        defer std.testing.allocator.rawFree(
            ptr1,
            std.mem.Alignment.fromByteUnits(A.structure.alignment),
            0,
        );
    } else {
        std.debug.print("\nfailed\n", .{});
    }
}
