test "example" {
    const std = @import("std");
    const SharedPtr = @import("shared_ptr.zig").SharedPtr;
    const WeakPtr = @import("shared_ptr.zig").WeakPtr;

    const alloc = std.testing.allocator;

    var sp1 = try SharedPtr(u8).init(1, alloc);
    defer sp1.deinit(alloc);
    {
        var sp2 = sp1.clone();
        defer sp2.deinit(alloc);
        sp2.get_mut().* = 2;
    }

    try std.testing.expectEqual(@as(u8, 2), sp1.get().*);

    var wp1 = WeakPtr(u8).empty;
    defer wp1.deinit(alloc);

    {
        var sp = try SharedPtr(u8).init(99, alloc);
        defer sp.deinit(alloc);
        wp1.assignFromShared(&sp, alloc);
        if (wp1.expired()) {
            try std.testing.expect(false);
        } else {
            var upgraded = wp1.lock().?;
            defer upgraded.deinit(alloc);
            try std.testing.expectEqual(@as(u8, 99), upgraded.get().*);
        }
    }

    if (wp1.expired()) {
        try std.testing.expect(true);
    } else {
        var upgraded = wp1.lock().?;
        defer upgraded.deinit(alloc);
        try std.testing.expect(false);
    }
}
