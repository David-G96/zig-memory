const std = @import("std");

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
                                    T.deinit(value, alloc);
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

test "size of DefaultDeleter" {
    try std.testing.expectEqual(0, @sizeOf(DefaultDeleter(u8)));
}
