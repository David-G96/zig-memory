pub const DefaultDeleter = @import("deleter.zig").DefaultDeleter;

pub const SharedPtr = @import("shared_ptr.zig").SharedPtr;
pub const SharePtrWithDeleter = @import("shared_ptr.zig").SharedPtrWithDeleter;
pub const WeakPtr = @import("shared_ptr.zig").WeakPtr;
pub const WeakPtrWithDeleter = @import("shared_ptr.zig").WeakPtrWithDeleter;

pub const AtomicSharedPtr = @import("atomic_shared_ptr.zig").AtomicSharedPtr;
pub const AtomicSharedPtrWithDeleter = @import("atomic_shared_ptr.zig").AtomicSharedPtrWithDeleter;
pub const AtomicWeakPtr = @import("shared_ptr.zig").WeakPtr;
pub const AtomicWeakPtrWithDeleter = @import("shared_ptr.zig").WeakPtrWithDeleter;
