const std = @import("std");
const Self = @This();

pub const headerAlignment = @alignOf(Self);
data: usize,

/// zig version of c `ALIGN_UP`
pub fn alignUp(x: usize, a: usize) usize {
    return (x + a - 1) & ~(a - 1);
}

pub fn ObjectAlignOf(bodyAlignment: usize) usize {
    const ObjectAlignment = @max(headerAlignment, bodyAlignment);
    return ObjectAlignment;
}

pub fn ObjectSizeOf(bodySize: usize, bodyAlignment: usize) usize {
    const headerSize: usize = @sizeOf(Self);

    const bodyOffset = alignUp(headerSize, bodyAlignment);
    const bodyEnd = bodyOffset + bodySize;
    const totalAlignment = ObjectAlignOf(bodyAlignment);
    return alignUp(bodyEnd, totalAlignment);
}

pub fn compactAlignOf() !void {}

test "align and size" {
    const A = struct { i32, u8 };
    const size = ObjectSizeOf(@sizeOf(A), @alignOf(A));
    const alignment = ObjectAlignOf(@alignOf(A));
    try std.testing.expectEqual(8, alignment);
    try std.testing.expectEqual(16, size);
}
