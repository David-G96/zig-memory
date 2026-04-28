const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Layout = struct {
    const Self = @This();
    fields: std.bit_set.DynamicBitSetUnmanaged,

    pub const empty = Self{ .fields = .{} };

    pub fn init(size: usize, alloc: Allocator) Allocator.Error!Self {
        return .{ .fields = try .initEmpty(alloc, size) };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        self.fields.deinit(alloc);
    }
};

pub const Structure = struct {
    const Self = @This();
    size: u32,
    alignment: u32,

    pub fn init(size: u32, alignment: u32) Self {
        return .{
            .size = size,
            .alignment = alignment,
        };
    }

    /// zig version of c `ALIGN_UP`
    pub fn alignUp(x: u32, a: u32) u32 {
        return (x + a - 1) & ~(a - 1);
    }

    pub fn concat(s1: Structure, s2: Structure) Structure {
        const resAlignment: u32 = @max(s1.alignment, s2.alignment);
        const s2Offset = alignUp(s1.size, s2.alignment);
        const s2end = s2Offset + s2.size;
        return .init(s2end, resAlignment);
    }

    pub fn concatMany(xs: []const Structure) Structure {
        var res = Structure.init(0, 0);
        for (xs) |s| {
            res = concat(res, s);
        }
        return res;
    }
};
