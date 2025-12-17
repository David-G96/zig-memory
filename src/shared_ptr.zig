const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultDeleter = @import("default_deleter.zig").DefaultDeleter;

pub fn SharedPtr(comptime T: type) type {
    return SharedPtrWithDeleter(T, DefaultDeleter(T));
}

pub fn SharedPtrWithDeleter(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        pub const ElementType = T;
        pub const WeakType = WeakPtrWithDeleter(T, Deleter);

        inner: *Inner(T, Deleter),

        pub fn init(value: T, alloc: Allocator) Allocator.Error!Self {
            const inner = try alloc.create(Inner(T, Deleter));
            inner.* = Inner(T, Deleter).init(value, Deleter{});
            return .{
                .inner = inner,
            };
        }

        pub fn initWithDeleter(value: T, alloc: Allocator, _deleter: Deleter) Allocator.Error!Self {
            const inner = try alloc.create(Inner(T, Deleter));
            inner.* = Inner(T, Deleter).init(value, _deleter);
            return .{
                .inner = inner,
            };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            if (self.inner.strong == 1) {
                self.inner.deleter.delete(&self.inner.value, alloc);
                if (self.inner.weak == 0) {
                    alloc.destroy(self.inner);
                    return;
                }
            }
            self.inner.strong -= 1;
        }

        pub fn assign(self: *Self, other: Self, alloc: Allocator) void {
            if (self.inner == other.inner) return;
            other.inner.strong += 1;
            self.deinit(alloc);
            self.inner = other.inner;
        }

        pub fn swap(self: *Self, other: *Self) void {
            const temp = self.*;
            self.inner = other.inner;
            other.inner = temp.inner;
        }

        pub fn get(self: *Self) *T {
            return &self.inner.value;
        }

        pub fn useCount(self: *Self) usize {
            return self.inner.strong;
        }
    };
}

pub fn WeakPtr(comptime T: type) type {
    return WeakPtrWithDeleter(T, DefaultDeleter(T));
}

pub fn WeakPtrWithDeleter(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        pub const ElementType = T;
        pub const StrongType = SharedPtrWithDeleter(T, Deleter);
        inner: ?*Inner(T, Deleter),

        pub const empty = Self{
            .inner = null,
        };

        pub fn init(shared: StrongType) Self {
            shared.inner.weak += 1;
            return .{ .inner = shared.inner };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            const inner = self.inner orelse return;
            // 如果这是最后一个弱引用，且强引用已经归零（意味着值已被销毁），
            // 那么我们负责销毁控制块 Inner。
            if (inner.strong == 0 and inner.weak == 1) {
                alloc.destroy(inner);
            } else {
                inner.weak -= 1;
            }
            self.inner = null;
        }

        pub fn lock(self: Self) ?StrongType {
            const inner = self.inner orelse return null;
            if (inner.strong == 0) return null;
            inner.strong += 1;
            return StrongType{ .inner = inner };
        }

        pub fn expired(self: Self) bool {
            const inner = self.inner orelse return true;
            return inner.strong == 0;
        }

        pub fn assign(self: *Self, other: Self, alloc: Allocator) void {
            if (self.inner == other.inner) return;
            if (other.inner) |i| i.weak += 1;
            self.deinit(alloc);
            self.inner = other.inner;
        }
    };
}

fn Inner(comptime T: type, comptime Deleter: type) type {
    return struct {
        const Self = @This();
        strong: usize,
        weak: usize,
        value: T,
        deleter: Deleter,

        pub fn init(value: T, _deleter: Deleter) Self {
            return .{ .strong = 1, .weak = 0, .value = value, .deleter = _deleter };
        }
    };
}

test "size guarantees" {
    try std.testing.expectEqual(@sizeOf(usize), @sizeOf(SharedPtr(u8)));
    try std.testing.expectEqual(3 * @sizeOf(usize), @sizeOf(Inner(u8, DefaultDeleter(u8))));
}

test "Trivial SharedPtr" {
    var sp1 = try SharedPtr(u8).init(99, std.testing.allocator);
    defer sp1.deinit(std.testing.allocator);
    try std.testing.expectEqual(99, sp1.inner.value);

    var sp2 = try SharedPtr(u8).init(11, std.testing.allocator);
    defer sp2.deinit(std.testing.allocator);

    sp2.assign(sp1, std.testing.allocator);
}

test "RAII SharedPTr" {
    var sp1 = try SharedPtr(std.ArrayList(u8)).init(std.ArrayList(u8).empty, std.testing.allocator);
    defer sp1.deinit(std.testing.allocator);

    try sp1.inner.value.append(std.testing.allocator, 99);
    try std.testing.expectEqual(99, sp1.inner.value.getLastOrNull().?);

    var sp2 = try SharedPtr(std.ArrayList(u8)).init(std.ArrayList(u8).empty, std.testing.allocator);
    defer sp2.deinit(std.testing.allocator);

    sp2.assign(sp1, std.testing.allocator);

    try std.testing.expect(sp1.inner == sp2.inner);
}

test "cyclic reference" {
    const Node = struct { val: i32, next: ?SharedPtr(@This()) = null };

    var node1 = try SharedPtr(Node).init(.{ .val = 1 }, std.testing.allocator);
    defer node1.deinit(std.testing.allocator);

    var node2 = try SharedPtr(Node).init(.{ .val = 2 }, std.testing.allocator);
    defer node2.deinit(std.testing.allocator);

    // 构造循环引用: node1 -> node2
    node2.inner.strong += 1; // 手动增加引用计数（模拟拷贝）
    node1.inner.value.next = node2;

    // 构造循环引用: node2 -> node1
    node1.inner.strong += 1;
    node2.inner.value.next = node1;

    try std.testing.expectEqual(2, node1.useCount());
    try std.testing.expectEqual(2, node2.useCount());

    // 手动打破循环以避免内存泄漏测试失败
    // 在实际场景中，这通常需要 WeakPtr 来解决
    if (node1.inner.value.next) |*n| n.deinit(std.testing.allocator);
    if (node2.inner.value.next) |*n| n.deinit(std.testing.allocator);
}

test "arena cyclic reference" {
    const Node = struct { val: i32, next: ?SharedPtr(@This()) = null };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var node1 = try SharedPtr(Node).init(.{ .val = 1 }, alloc);
    defer node1.deinit(alloc);

    var node2 = try SharedPtr(Node).init(.{ .val = 2 }, alloc);
    defer node2.deinit(alloc);

    // 构造循环引用: node1 -> node2
    node2.inner.strong += 1; // 手动增加引用计数（模拟拷贝）
    node1.inner.value.next = node2;

    // 构造循环引用: node2 -> node1
    node1.inner.strong += 1;
    node2.inner.value.next = node1;

    try std.testing.expectEqual(2, node1.useCount());
    try std.testing.expectEqual(2, node2.useCount());
}
