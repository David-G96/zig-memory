const std = @import("std");

/// # Default Deleter
/// ## Support
/// * POD/Trivial date types. e.g. u8, bool
/// * RAII date types.
///
/// ***Requirement:***
/// 1. `deinit` is declared as a member function.
/// 2. `deinit` must have 1 or 2 arguments.
///
/// Valid forms are:
/// 1. `deinit(*T)`
/// 2. `deinit(T)`
/// 3. `deinit(*T, Allocator)`
/// 4. `deinit(T, Allocator)`
pub fn DefaultDeleter(comptime T: type) type {
    return struct {
        const type_info = @typeInfo(T);
        const Self = @This();
        pub fn init() Self {
            return .{};
        }

        pub fn delete(_: *Self, value: *T, alloc: std.mem.Allocator) void {
            switch (type_info) {
                .@"struct", .@"enum", .@"union", .@"opaque" => {
                    if (@hasDecl(T, "deinit")) {
                        const deinit_type_info = @typeInfo(@TypeOf(T.deinit));
                        switch (deinit_type_info) {
                            .@"fn" => |deinit_func| {
                                if (deinit_func.params.len == 1) {
                                    if (@typeInfo(deinit_func.params[0].type.?) == .pointer) {
                                        T.deinit(value);
                                    } else {
                                        T.deinit(value.*);
                                    }
                                } else if (deinit_func.params.len == 2) {
                                    if (@typeInfo(deinit_func.params[0].type.?) == .pointer) {
                                        T.deinit(value, alloc);
                                    } else {
                                        T.deinit(value.*, alloc);
                                    }
                                }
                            },
                            else => {
                                @compileError("`deinit` is expected as a function");
                            },
                        }
                    }
                },
                else => {},
            }
        }
    };
}

// TODO: Add customize StatefulDeleter & StatelessDeleter

test "size of DefaultDeleter" {
    try std.testing.expectEqual(0, @sizeOf(DefaultDeleter(u8)));
}
