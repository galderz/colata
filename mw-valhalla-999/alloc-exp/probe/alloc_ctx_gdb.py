# gdb stand-in for alloc_ctx.bt.in, for environments where BPF is not available (e.g. unprivileged
# containers). Same probe point (InstanceKlass::allocate_instance), same struct offsets, same output
# format; the entry point is found by unwinding the native caller instead of uprobe/uretprobe pairs.
# Slow (a few thousand allocations per second): use small runs. Driven by scripts/probe-gdb.sh.
import gdb, collections, os

OFF = {k: int(v) for k, v in (l.strip().split("=") for l in open(os.environ["PROBE_OFFSETS"]) if "=" in l)}
OUT = os.environ["PROBE_OUT"]
CTX = [  # (function name prefix, context label) -- labels match alloc_ctx.bt.in
    ("OptoRuntime::new_instance_C", "C2  OptoRuntime::new_instance_C"),
    ("OptoRuntime::load_unknown_value_C", "C2  OptoRuntime::load_unknown_value_C"),
    ("Runtime1::new_instance", "C1  Runtime1::new_instance"),
    ("InterpreterRuntime::_new", "INT InterpreterRuntime::_new"),
    ("InterpreterRuntime::read_flat_field", "INT InterpreterRuntime::read_flat_field"),
    ("InterpreterRuntime::flat_array_load", "INT InterpreterRuntime::flat_array_load"),
    ("SharedRuntime::store_value_type_fields_to_buf", "ANY SharedRuntime::store_value_type_fields_to_buf"),
    ("SharedRuntime::allocate_value_types", "ANY SharedRuntime::allocate_value_types"),
    ("Deoptimization::realloc_objects", "C2  Deoptimization::realloc_objects"),
    ("Deoptimization::realloc_value_type_result", "C2  Deoptimization::realloc_value_type_result"),
]
alloc = collections.Counter()
sites = collections.Counter()
state = {"pid": 0}

def rd(addr, n):
    return int.from_bytes(bytes(gdb.selected_inferior().read_memory(addr, n)), "little")

class AllocateInstance(gdb.Breakpoint):
    def stop(self):
        state["pid"] = gdb.selected_inferior().pid
        f = gdb.selected_frame()
        klass = int(f.read_register("rdi")); thread = int(f.read_register("rsi"))
        sym = rd(klass + OFF["KLASS_NAME"], 8)
        name = bytes(gdb.selected_inferior().read_memory(sym + OFF["SYMBOL_BODY"], rd(sym + OFF["SYMBOL_LENGTH"], 2))).decode()
        ctx = "VM  other runtime path"
        caller = f.older()
        for _ in range(6):  # skip wrappers, e.g. ValueKlass::allocate_instance <- FlatValuePayload::allocate_instance <- FlatValuePayload::read <- InterpreterRuntime::read_flat_field
            cname = caller.name() if caller else None
            if not cname: break
            hit = next((label for fn, label in CTX if cname.startswith(fn)), None)
            if hit: ctx = hit; break
            caller = caller.older()
        alloc[(ctx, name)] += 1
        if ctx.startswith("C2  OptoRuntime::new_instance_C"):
            sites[(name, rd(rd(thread + OFF["THREAD_LAST_JAVA_SP"], 8) + 8, 8))] += 1
        return False

AllocateInstance("InstanceKlass::allocate_instance(JavaThread*)", internal=True)

def on_exit(ev):
    with open(OUT, "w") as o:
        for (c, k), n in alloc.items(): o.write("@alloc[%s, %s]: %d\n" % (c, k, n))
        for (k, pc), n in sites.items(): o.write("@c2_site[%s, %d]: %d\n" % (k, pc, n))
        o.write("cpid=%d\n" % state["pid"])
gdb.events.exited.connect(on_exit)
