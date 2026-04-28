pub const DefaultDeleter = @import("deleter.zig").DefaultDeleter;

pub const SharedPtr = @import("shared_ptr.zig").SharedPtr;
pub const SharedPtrWithDeleter = @import("shared_ptr.zig").SharedPtrWithDeleter;
pub const WeakPtr = @import("shared_ptr.zig").WeakPtr;
pub const WeakPtrWithDeleter = @import("shared_ptr.zig").WeakPtrWithDeleter;

pub const AtomicSharedPtr = @import("atomic_shared_ptr.zig").AtomicSharedPtr;
pub const AtomicSharedPtrWithDeleter = @import("atomic_shared_ptr.zig").AtomicSharedPtrWithDeleter;
pub const AtomicWeakPtr = @import("atomic_shared_ptr.zig").AtomicWeakPtr;
pub const AtomicWeakPtrWithDeleter = @import("atomic_shared_ptr.zig").AtomicWeakPtrWithDeleter;

test "atomic weak exports use atomic implementation" {
    try @import("std").testing.expect(AtomicSharedPtr(u8).WeakType == AtomicWeakPtr(u8));
}
