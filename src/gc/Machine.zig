const std = @import("std");
const Meta = @import("Meta.zig");
const ObjectHeader = @import("ObjectHeader.zig");

const Self = @This();

metaData: std.ArrayListUnmanaged(Meta),

pub fn init() Self {
    return Self{ .metaData = .empty };
}

pub fn deinit(self: *Self) void {
    self.metaData.deinit(std.heap.smp_allocator);
}

pub fn traverse_single(self: *Self, root: usize) void {
    const rootPtr: *anyopaque = @ptrCast(root);
    const header: *ObjectHeader = @ptrCast(rootPtr);
    const meta = self.metaData.items[header.data];
    var iter = meta.layout.iterator(.{});
    std.debug.print("\nvisiting data of `{s}`", .{meta.name});
    for (iter.next()) |it| {
        const nextRef = root + it;
        self.traverse_single(nextRef);
    }
}

test "machine traverse_single" {
    var machine = Self.init();
    defer machine.deinit();
}
