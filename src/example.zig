test "example" {
    const std = @import("std");
    const SharedPtr = @import("shared_ptr.zig").SharedPtr;
    const WeakPtr = @import("shared_ptr.zig").WeakPtr;

    var sp1 = try SharedPtr(u8).init(1, std.heap.page_allocator);
    defer sp1.deinit(std.heap.page_allocator);
    {
        var sp2 = try sp1.clone();
        defer sp2.deinit(std.heap.page_allocator);
        sp2.get_mut().* = 2;
    }

    std.debug.print("\nsp1 is {}\n", .{sp1.get().*});

    var wp1 = WeakPtr(u8).empty;
    defer wp1.deinit(std.heap.page_allocator);

    {
        var sp = try SharedPtr(u8).init(99, std.heap.page_allocator);
        defer sp.deinit(std.heap.page_allocator);
        wp1.assign(WeakPtr(u8).init(sp), std.heap.page_allocator);
        // ! 不要这么使用！！！这会导致upgraded无法被deinit，导致内存泄漏！
        // if (wp1.lock()) |upgraded| {
        //     std.debug.print("wp1 is {}\n", .{upgraded.get().*});
        // } else {
        //     std.debug.print("wp1 is not expired\n", .{});
        // }
        if (wp1.expired()) {
            std.debug.print("wp1 is expired\n", .{});
        } else {
            var upgraded = wp1.lock().?;
            defer upgraded.deinit(std.heap.page_allocator);
            std.debug.print("wp1 is {}\n", .{upgraded.get().*});
        }
    }

    if (wp1.expired()) {
        std.debug.print("wp1 is expired\n", .{});
    } else {
        var upgraded = wp1.lock().?;
        defer upgraded.deinit(std.heap.page_allocator);
        std.debug.print("wp1 is {}\n", .{upgraded.get().*});
    }
}
