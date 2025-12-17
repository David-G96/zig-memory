const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultDeleter = @import("default_deleter.zig").DefaultDeleter;

fn AtomicInner(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        const Atomic = std.atomic.Value(usize);
        strong: Atomic,
        weak: Atomic,
        value: T,
        deleter: Deleter,

        pub fn init(value: T, _deleter: Deleter) Self {
            return .{
                .strong = Atomic.init(1),
                // Strong references collectively hold 1 weak reference count to keep the control block alive.
                .weak = Atomic.init(1),
                .value = value,
                .deleter = _deleter,
            };
        }
    };
}

pub fn AtomicSharedPtr(comptime T: type) type {
    return AtomicSharedPtrWithDeleter(T, DefaultDeleter(T));
}

pub fn AtomicSharedPtrWithDeleter(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        pub const ElementType = T;
        pub const WeakType = AtomicWeakPtrWithDeleter(T, Deleter);

        inner: *AtomicInner(T, Deleter),

        pub fn init(value: T, alloc: Allocator) Allocator.Error!Self {
            const inner = try alloc.create(AtomicInner(T, Deleter));
            inner.* = AtomicInner(T, Deleter).init(value, Deleter{});
            return .{
                .inner = inner,
            };
        }

        pub fn initWithDeleter(value: T, alloc: Allocator, _deleter: Deleter) Allocator.Error!Self {
            const inner = try alloc.create(AtomicInner(T, Deleter));
            inner.* = AtomicInner(T, Deleter).init(value, _deleter);
            return .{
                .inner = inner,
            };
        }

        pub fn deinit(self: *const Self, alloc: Allocator) void {
            // fetchSub returns the previous value. If it was 1, it is now 0.
            if (self.inner.strong.fetchSub(1, .acq_rel) == 1) {
                self.inner.deleter.delete(&self.inner.value, alloc);

                // Release the weak reference held by the strong count.
                if (self.inner.weak.fetchSub(1, .acq_rel) == 1) {
                    alloc.destroy(self.inner);
                }
            }
        }

        pub fn assign(self: *Self, other: Self, alloc: Allocator) void {
            if (self.inner == other.inner) return;
            _ = other.inner.strong.fetchAdd(1, .monotonic);
            self.deinit(alloc);
            self.inner = other.inner;
        }

        pub fn swap(self: *Self, other: *Self) void {
            const temp = self.*;
            self.inner = other.inner;
            other.inner = temp.inner;
        }

        pub fn get(self: *const Self) *T {
            return &self.inner.value;
        }

        pub fn useCount(self: *const Self) usize {
            return self.inner.strong.load(.monotonic);
        }
    };
}

pub fn AtomicWeakPtr(comptime T: type) type {
    return AtomicWeakPtrWithDeleter(T, DefaultDeleter(T));
}

pub fn AtomicWeakPtrWithDeleter(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        pub const ElementType = T;
        pub const StrongType = AtomicSharedPtrWithDeleter(T, Deleter);
        inner: ?*AtomicInner(T, Deleter),

        pub const empty = Self{
            .inner = null,
        };

        pub fn init(shared: StrongType) Self {
            _ = shared.inner.weak.fetchAdd(1, .monotonic);
            return .{ .inner = shared.inner };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            const inner = self.inner orelse return;
            if (inner.weak.fetchSub(1, .acq_rel) == 1) {
                alloc.destroy(inner);
            }
            self.inner = null;
        }

        pub fn lock(self: Self) ?StrongType {
            const inner = self.inner orelse return null;

            var s = inner.strong.load(.monotonic);
            while (true) {
                if (s == 0) return null;
                // Try to increment strong count from s to s + 1
                if (inner.strong.cmpxchgWeak(s, s + 1, .acquire, .monotonic)) |actual| {
                    s = actual; // CAS failed, retry with new value
                } else {
                    return StrongType{ .inner = inner };
                }
            }
        }

        pub fn expired(self: Self) bool {
            const inner = self.inner orelse return true;
            return inner.strong.load(.monotonic) == 0;
        }

        pub fn assign(self: *Self, other: Self, alloc: Allocator) void {
            if (self.inner == other.inner) return;
            if (other.inner) |i| {
                _ = i.weak.fetchAdd(1, .monotonic);
            }
            self.deinit(alloc);
            self.inner = other.inner;
        }
    };
}

test "AtomicSharedPtr basic usage" {
    const allocator = std.testing.allocator;
    var sp = try AtomicSharedPtr(i32).init(42, allocator);
    defer sp.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 42), sp.get().*);
    try std.testing.expectEqual(@as(usize, 1), sp.useCount());
}

test "AtomicSharedPtr assignment and ref counting" {
    const allocator = std.testing.allocator;
    var sp1 = try AtomicSharedPtr(i32).init(100, allocator);
    defer sp1.deinit(allocator);

    var sp2 = try AtomicSharedPtr(i32).init(200, allocator);
    defer sp2.deinit(allocator);

    sp2.assign(sp1, allocator);

    try std.testing.expectEqual(@as(i32, 100), sp2.get().*);
    try std.testing.expectEqual(@as(usize, 2), sp1.useCount());
    try std.testing.expectEqual(@as(usize, 2), sp2.useCount());
    try std.testing.expect(sp1.inner == sp2.inner);
}

test "AtomicWeakPtr basic usage" {
    const allocator = std.testing.allocator;
    var sp = try AtomicSharedPtr(i32).init(50, allocator);
    defer sp.deinit(allocator);

    var wp = AtomicWeakPtr(i32).init(sp);
    defer wp.deinit(allocator);

    try std.testing.expect(!wp.expired());

    if (wp.lock()) |*locked_sp| {
        defer locked_sp.deinit(allocator);
        try std.testing.expectEqual(@as(i32, 50), locked_sp.get().*);
        try std.testing.expectEqual(@as(usize, 2), locked_sp.useCount());
    } else {
        try std.testing.expect(false); // Should be able to lock
    }
}

test "AtomicWeakPtr expiration" {
    const allocator = std.testing.allocator;
    var wp = AtomicWeakPtr(i32).empty;
    defer wp.deinit(allocator);

    {
        var sp = try AtomicSharedPtr(i32).init(10, allocator);
        defer sp.deinit(allocator);
        var temp_wp = AtomicWeakPtr(i32).init(sp);
        defer temp_wp.deinit(allocator);
        wp.assign(temp_wp, allocator);
        try std.testing.expect(!wp.expired());
    }

    try std.testing.expect(wp.expired());
    try std.testing.expect(wp.lock() == null);
}

test "AtomicSharedPtr concurrency" {
    const allocator = std.testing.allocator;
    var sp = try AtomicSharedPtr(usize).init(0, allocator);
    defer sp.deinit(allocator);

    const ThreadFn = struct {
        fn run(ptr: AtomicSharedPtr(usize), alloc: Allocator) void {
            var local_sp = ptr;
            // Artificially increase ref count to simulate shared ownership in thread
            _ = local_sp.inner.strong.fetchAdd(1, .monotonic);
            defer local_sp.deinit(alloc);

            _ = local_sp.inner.value; // Access value
        }
    };

    const t1 = try std.Thread.spawn(.{}, ThreadFn.run, .{ sp, allocator });
    const t2 = try std.Thread.spawn(.{}, ThreadFn.run, .{ sp, allocator });
    const t3 = try std.Thread.spawn(.{}, ThreadFn.run, .{ sp, allocator });

    t1.join();
    t2.join();
    t3.join();

    try std.testing.expectEqual(@as(usize, 1), sp.useCount());
}
