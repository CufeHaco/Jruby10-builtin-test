/*
 * Supporting Changes for Builtins Fast-Path System
 *
 * These are the modifications needed to Ruby.java, ThreadContext.java,
 * and RubyModule.java to wire up the Builtins system.
 *
 * Based on headius's prototype at commit f8c31fc
 */

// =============================================================================
// FILE: core/src/main/java/org/jruby/Ruby.java
// =============================================================================

// ADD import:
import org.jruby.runtime.Builtins;

// ADD field (near other runtime fields):

    /** Bit flags tracking which builtin methods have been redefined */
    private final short[] builtinBits = Builtins.allocate();

// ADD methods:

    /**
     * Get the builtin bits array for fast-path checks.
     * This is shared across all ThreadContexts in this runtime.
     *
     * @return the builtin bits array
     */
    public short[] getBuiltinBits() {
        return builtinBits;
    }

    /**
     * Called when a method is defined on a class that might invalidate
     * builtin optimizations.
     *
     * @param module the module/class where the method was defined
     * @param method the method name
     */
    void invalidateBuiltin(RubyModule module, String method) {
        // Don't invalidate during initial core boot (we're defining builtins!)
        if (!isBootingCore()) {
            Builtins.invalidateBuiltin(builtinBits, module.getClassIndex(), method);
        }
    }


// =============================================================================
// FILE: core/src/main/java/org/jruby/runtime/ThreadContext.java
// =============================================================================

// ADD field (make it public final for fastest access):

    /**
     * Thread-local reference to runtime's builtin bits.
     * Public final for direct field access (fastest possible).
     *
     * Usage: Builtins.checkIntegerPlus(context) reads context.builtinBits[0]
     */
    public final short[] builtinBits;

// MODIFY constructor to initialize the field:

    private ThreadContext(Ruby runtime) {
        // ... existing initialization ...

        this.runtimeCache = runtime.getRuntimeCache();
        this.sites = runtime.sites;
        this.traceEvents = runtime.getTraceEvents();

        // ADD THIS LINE:
        this.builtinBits = runtime.getBuiltinBits();

        // ... rest of constructor ...
    }


// =============================================================================
// FILE: core/src/main/java/org/jruby/RubyModule.java
// =============================================================================

// MODIFY putMethod to trigger invalidation:

    public DynamicMethod putMethod(ThreadContext context, String id, DynamicMethod method) {
        // ... existing code up to profiling ...

        context.runtime.addProfiledMethod(id, method);

        // ADD THESE LINES:
        // Invalidate builtin optimization if this class/method combo is tracked
        context.runtime.invalidateBuiltin(methodLocation, id);

        return method;
    }


// =============================================================================
// FILE: core/src/main/java/org/jruby/RubyObject.java
// =============================================================================

// MODIFY fastNumEqualInternal to use new system:

    private static boolean fastNumEqualInternal(final ThreadContext context, 
                                                 final IRubyObject a, 
                                                 final IRubyObject b) {
        if (a instanceof RubyFixnum fixnumA) {
            if (b instanceof RubyFixnum fixnumB) {
                // CHANGE FROM:
                // if (!context.sites.Fixnum.op_eqq.isBuiltin(a)) {
                // TO:
                if (!Builtins.checkIntegerEquals(context)) {
                    return context.sites.Fixnum.op_eqq.call(context, a, a, b).isTrue();
                }
                return fixnumA.fastEqual(fixnumB);
            }
        } else if (a instanceof RubyFloat floatA) {
            if (b instanceof RubyFloat floatB) {
                // CHANGE FROM:
                // if (!context.sites.Float.op_eqq.isBuiltin(a)) {
                // TO:
                if (!Builtins.checkFloatEquals(context)) {
                    return context.sites.Float.op_eqq.call(context, a, a, b).isTrue();
                }
                return floatA.fastEqual(floatB);
            }
        }
        return false;
    }
