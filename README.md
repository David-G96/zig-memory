# zig-memory

Reference-counted pointer types for Zig.

`zig-memory` provides `SharedPtr`, `WeakPtr`, and atomic reference-counted variants inspired by C++ smart pointers. It is intended for cases where ownership is shared explicitly and deterministic cleanup is still preferred.

## Status

This package is early-stage. The API is small and may still change.

## Install

Add the package with Zig package manager:

```sh
zig fetch --save <package-url>
```

Then import the module from your `build.zig`:

```zig
const zig_memory = b.dependency("zig_memory", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zig_memory", zig_memory.module("zig_memory"));
```

## Exports

```zig
const zm = @import("zig_memory");

zm.SharedPtr(T)
zm.SharedPtrWithDeleter(T, Deleter)
zm.WeakPtr(T)
zm.WeakPtrWithDeleter(T, Deleter)

zm.AtomicSharedPtr(T)
zm.AtomicSharedPtrWithDeleter(T, Deleter)
zm.AtomicWeakPtr(T)
zm.AtomicWeakPtrWithDeleter(T, Deleter)

zm.DefaultDeleter(T)
```

## Basic Usage

```zig
const std = @import("std");
const zm = @import("zig_memory");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var first = try zm.SharedPtr(u8).init(1, allocator);
    defer first.deinit(allocator);

    var second = first.clone();
    defer second.deinit(allocator);

    second.get_mut().* = 2;

    std.debug.assert(first.get().* == 2);
    std.debug.assert(first.useCount() == 2);
}
```

`clone()` increments the strong reference count. Every owned `SharedPtr` returned by `init`, `clone`, `assign`, or `WeakPtr.lock()` must eventually be released with `deinit()` using the same allocator family used to create the control block.

## Weak Pointers

Use `WeakPtr` for non-owning references and for breaking ownership cycles.

```zig
const std = @import("std");
const zm = @import("zig_memory");

test "weak pointer" {
    const allocator = std.testing.allocator;

    var weak = zm.WeakPtr(u8).empty;
    defer weak.deinit(allocator);

    {
        var shared = try zm.SharedPtr(u8).init(99, allocator);
        defer shared.deinit(allocator);

        weak.assignFromShared(&shared, allocator);

        var locked = weak.lock().?;
        defer locked.deinit(allocator);

        try std.testing.expectEqual(@as(u8, 99), locked.get().*);
    }

    try std.testing.expect(weak.expired());
}
```

Prefer `assignFromShared(&shared, allocator)` when replacing a weak pointer from a shared pointer. Avoid constructing a temporary weak pointer just to assign it unless that temporary is also deinitialized.

## Atomic Variants

`AtomicSharedPtr` and `AtomicWeakPtr` use atomic reference counts, so cloning, releasing, and weak locking can be coordinated across threads.

The pointed-to value is not automatically synchronized. If multiple threads read and write `T`, protect the value with a lock, atomic fields, or another synchronization strategy.

## Custom Deleters

By default, `DefaultDeleter(T)` calls `T.deinit` when it exists. Supported forms are:

```zig
deinit(*T)
deinit(T)
deinit(*T, std.mem.Allocator)
deinit(T, std.mem.Allocator)
```

For other cleanup behavior, use `SharedPtrWithDeleter` or `AtomicSharedPtrWithDeleter`.

## Build And Test

```sh
zig build
zig build test
zig build test --summary all
```

`zig build test` runs tests for the public root module, shared pointer implementation, atomic implementation, deleter, and example usage.

## Notes

- `SharedPtr` and `WeakPtr` are not atomic and should not be shared across threads without external synchronization.
- `AtomicSharedPtr` makes the reference counts atomic, not the contained value.
- Avoid raw struct assignment as an ownership operation. Use `clone`, `assign`, `assignFromShared`, or `lock`.
- Reference cycles made only of strong references leak unless the cycle is broken manually or by using weak references.
