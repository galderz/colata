# Latest JDK

This project can be used for building JDKs that support other efforts.

Here are a few examples:

Building latest GraalVM master depends on specific JDK tags.
So you can point to that specific tag and build graal builder image:

```bash
make configure build-graal-builder-image
```

# Introduction to C2

## VM flags to control compilation

By default, compilation happens in the background,
so program might finish before compilation has finished:

```bash
CLASS=First JVM_ARGS=-XX:CompileCommand=printcompilation,First::* make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
Done
1399 1838       2       First::test (4 bytes)
```

With `-Xbatch` you disable background compilation.
We explicitly wait for any compilation to finish before continuing the execution in that method.
We also see that the blocking behaviour has made the overall execution much slower.
This is because the VM now blocks the execution any time a compilation needs to be made -
and not just in our `First` class but also during the JVM startup:

```bash
CLASS=First JVM_ARGS="-Xbatch -XX:CompileCommand=printcompilation,First::*" make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -Xbatch -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
2734 1903    b  3       First::test (4 bytes)
2734 1904    b  4       First::test (4 bytes)
Done
```

We can stop tiered compilation at a certain tier,
for example to avoid any C2 compilations and only allow C1.
We also restrict compilation,
so that we don't have to wait for all classes and methods used from startup of the JVM to be compiled:

```bash
CLASS=First JVM_ARGS="-XX:TieredStopAtLevel=3 -XX:CompileCommand=compileonly,First::test -Xbatch -XX:CompileCommand=printcompilation,First::*" make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -XX:TieredStopAtLevel=3 -XX:CompileCommand=compileonly,First::test -Xbatch -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: compileonly First.test bool compileonly = true
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
1412  102    b  3       First::test (4 bytes)
Done
```

## C2 IR

With `-XX:+PrintIdeal`,
we can display the C2 machine independent IR (intermediate representation),
sometimes also called “ideal graph” or just “C2 IR”,
after most optimizations are done, and before code generation:

```bash
CLASS=First JVM_ARGS_APPEND=-XX:+PrintIdeal make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -Xbatch -XX:CompileCommand=compileonly,First::test -XX:CompileCommand=printcompilation,First::* -XX:-TieredCompilation -XX:+PrintIdeal \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: compileonly First.test bool compileonly = true
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
1693  102    b        First::test (4 bytes)
AFTER: PrintIdeal
  0  Root  === 0 24  [[ 0 1 3 ]] inner 
  1  Con  === 0  [[ ]]  #top
  3  Start  === 3 0  [[ 3 5 6 7 8 9 10 11 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address, 5:int, 6:int}
  5  Parm  === 3  [[ 24 ]] Control !jvms: First::test @ bci:-1 (line 21)
  6  Parm  === 3  [[ 24 ]] I_O !jvms: First::test @ bci:-1 (line 21)
  7  Parm  === 3  [[ 24 ]] Memory  Memory: @ptr:BotPTR+bot, idx=Bot; !jvms: First::test @ bci:-1 (line 21)
  8  Parm  === 3  [[ 24 ]] FramePtr !jvms: First::test @ bci:-1 (line 21)
  9  Parm  === 3  [[ 24 ]] ReturnAdr !jvms: First::test @ bci:-1 (line 21)
 10  Parm  === 3  [[ 23 ]] Parm0: int !jvms: First::test @ bci:-1 (line 21)
 11  Parm  === 3  [[ 23 ]] Parm1: int !jvms: First::test @ bci:-1 (line 21)
 23  AddI  === _ 10 11  [[ 24 ]]  !jvms: First::test @ bci:2 (line 21)
 24  Return  === 5 6 7 8 9 returns 23  [[ 0 ]] 
Done
```

## RR

First run with `rr` to record execution:

```bash
$ RR=true CLASS=Inline JVM_ARGS_APPEND=-XX:CompileCommand=printinlining,Inline::test make
rm -f *.log
rr /home/g/src/jdk/build/fast-linux-x86_64/jdk/bin/java \
   -Xbatch -XX:CompileCommand=compileonly,Inline::test -XX:CompileCommand=printcompilation,Inline::* -XX:-TieredCompilation -XX:CompileCommand=printinlining,Inline::test \
   /home/g/src/colata/jdk-999/Inline.java
rr: Saving execution to trace directory `/home/g/.local/share/rr/java-1'.
CompileCommand: compileonly Inline.test bool compileonly = true
CompileCommand: PrintCompilation Inline.* bool PrintCompilation = true
CompileCommand: PrintInlining Inline.test bool PrintInlining = true
Run
8988  102    b        Inline::test (22 bytes)
                            @ 3   Inline::multiply (4 bytes)   inline (hot)
                            @ 10   Inline::multiply (4 bytes)   inline (hot)
                            @ 17   Inline::multiply (4 bytes)   inline (hot)
Done
```

Then with `rr replay`:

```bash
$ rr replay
GNU gdb (GDB) 16.2
Copyright (C) 2024 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "x86_64-unknown-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<https://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from /home/g/.local/share/rr/java-1/mmap_hardlink_4_java...
Remote debugging using 127.0.0.1:36544
Reading symbols from /nix/store/cg9s562sa33k78m63njfn1rw47dp9z0i-glibc-2.40-66/lib/ld-linux-x86-64.so.2...
(No debugging symbols found in /nix/store/cg9s562sa33k78m63njfn1rw47dp9z0i-glibc-2.40-66/lib/ld-linux-x86-64.so.2)
0x00007f9c89ed4780 in _start () from /nix/store/cg9s562sa33k78m63njfn1rw47dp9z0i-glibc-2.40-66/lib/ld-linux-x86-64.so.2
(rr) b Optimize
Function "Optimize" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (Optimize) pending.
(rr) c
Continuing.

Thread 2 received signal SIGSEGV, Segmentation fault.
CompileCommand: compileonly Inline.test bool compileonly = true
CompileCommand: PrintCompilation Inline.* bool PrintCompilation = true
CompileCommand: PrintInlining Inline.test bool PrintInlining = true
Run
8988  102    b        Inline::test (22 bytes)
[Switching to Thread 78821.78843]

Thread 3 hit Breakpoint 1, Compile::Optimize (this=this@entry=0x7f9c7b2fd5d0) at /home/g/src/jdk/src/hotspot/share/opto/compile.cpp:2303
2303	  TracePhase tp(_t_optimizer);
(rr) list
2298	}
2299	
2300	//------------------------------Optimize---------------------------------------
2301	// Given a graph, optimize it.
2302	void Compile::Optimize() {
2303	  TracePhase tp(_t_optimizer);
2304	
2305	#ifndef PRODUCT
2306	  if (env()->break_at_compile()) {
2307	    BREAKPOINT;
(rr) 
```

Or even better from Emacs with `M-x gud-gdb`.
To do that change the prompt to

```
rr replay -d gdb -- --fullname
```

Here are some examples of graph dump functionality that can be called from rr/gdb,
and an example on how to watch an address and see when it got changed:

```bash
(rr) p find_nodes_by_dump("")
  0  Root  === 0 66  [[ 0 1 3 52 50 ]] 
  1  Con  === 0  [[ ]]  #top
  3  Start  === 3 0  [[ 3 5 6 7 8 9 10 11 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address, 5:int, 6:int}
  5  Parm  === 3  [[ 66 ]] Control !jvms: Inline::test @ bci:-1 (line 21)
  6  Parm  === 3  [[ 66 ]] I_O !jvms: Inline::test @ bci:-1 (line 21)
  7  Parm  === 3  [[ 66 ]] Memory  Memory: @ptr:BotPTR+bot, idx=Bot; !jvms: Inline::test @ bci:-1 (line 21)
  8  Parm  === 3  [[ 66 ]] FramePtr !jvms: Inline::test @ bci:-1 (line 21)
  9  Parm  === 3  [[ 66 ]] ReturnAdr !jvms: Inline::test @ bci:-1 (line 21)
 10  Parm  === 3  [[ 51 ]] Parm0: int !jvms: Inline::test @ bci:-1 (line 21)
 11  Parm  === 3  [[ 64 ]] Parm1: int !jvms: Inline::test @ bci:-1 (line 21)
 50  ConI  === 0  [[ 51 ]]  #int:303
 51  MulI  === _ 10 50  [[ 65 ]]  !jvms: Inline::test @ bci:13 (line 21)
 52  ConI  === 0  [[ 64 ]]  #int:53
 64  MulI  === _ 11 52  [[ 65 ]]  !jvms: Inline::multiply @ bci:2 (line 26) Inline::test @ bci:17 (line 21)
 65  AddI  === _ 51 64  [[ 66 ]]  !jvms: Inline::test @ bci:20 (line 21)
 66  Return  === 5 6 7 8 9 returns 65  [[ 0 ]] 
$1 = void
(rr) p find_node(65)->dump_bfs(2, 0, "#")
dist dump
---------------------------------------------
   2  52  ConI  === 0  [[ 64 ]]  #int:53
   2  11  Parm  === 3  [[ 64 ]] Parm1: int !jvms: Inline::test @ bci:-1 (line 21)
   2  50  ConI  === 0  [[ 51 ]]  #int:303
   2  10  Parm  === 3  [[ 51 ]] Parm0: int !jvms: Inline::test @ bci:-1 (line 21)
   1  64  MulI  === _ 11 52  [[ 65 ]]  !jvms: Inline::multiply @ bci:2 (line 26) Inline::test @ bci:17 (line 21)
   1  51  MulI  === _ 10 50  [[ 65 ]]  !jvms: Inline::test @ bci:13 (line 21)
   0  65  AddI  === _ 51 64  [[ 66 ]]  !jvms: Inline::test @ bci:20 (line 21)
$2 = void
(rr) dump_bfs(0,0,"h")
Undefined command: "dump_bfs".  Try "help".
(rr) p dump_bfs(0,0,"h")
No symbol "dump_bfs" in current context.
(rr) p find_node(65)->dump_bfs(0, 0, "h")
Usage: node->dump_bfs(int max_distance, Node* target, char* options)

Use cases:
  BFS traversal: no target required
  shortest path: set target
  all paths: set target and put 'A' in options
  detect loop: subcase of all paths, have start==target

Arguments:
  this/start: staring point of BFS
  target:
    if null: simple BFS
    else: shortest path or all paths between this/start and target
  options:
    if null: same as "cdmox@B"
    else: use combination of following characters
      h: display this help info
      H: display this help info, with examples
      +: traverse in-edges (on if neither + nor -)
      -: traverse out-edges
      c: visit control nodes
      d: visit data nodes
      m: visit memory nodes
      o: visit other nodes
      x: visit mixed nodes
      C: boundary control nodes
      D: boundary data nodes
      M: boundary memory nodes
      O: boundary other nodes
      X: boundary mixed nodes
      #: display node category in color (not supported in all terminals)
      S: sort displayed nodes by node idx
      A: all paths (not just shortest path to target)
      @: print old nodes - before matching (if available)
      B: print scheduling blocks (if available)
      $: dump only, no header, no other columns
      !: show nodes on IGV (sent over network stream)
        (use preferably with dump_bfs(int, Node*, char*, void*, void*, void*)
         to produce a C2 stack trace along with the graph dump, see examples below)

recursively follow edges to nodes with permitted visit types,
on the boundary additionally display nodes allowed in boundary types
Note: the categories can be overlapping. For example a mixed node
      can contain control and memory output. Some from the other
      category are also control (Halt, Return, etc).

output columns:
  dist:  BFS distance to this/start
  apd:   all paths distance (d_outputart + d_target)
  block: block identifier, based on _pre_order
  head:  first node in block
  idom:  head node of idom block
  depth: depth of block (_dom_depth)
  old:   old IR node - before matching
  dump:  node->dump()

Note: if none of the "cmdxo" characters are in the options string
      then we set all of them.
      This allows for short strings like "#" for colored input traversal
      or "-#" for colored output traversal.
$3 = void
(rr) p find_node(50)->dump()
 50  ConI  === 0  [[ 51 ]]  #int:303
$4 = void
(rr) p find_node(50)->dump(1)
  0  Root  === 0 66  [[ 0 1 3 52 50 ]] 
 50  ConI  === 0  [[ 51 ]]  #int:303
$5 = void
(rr) p find_node(51)->dump(1)
 50  ConI  === 0  [[ 51 ]]  #int:303
 10  Parm  === 3  [[ 51 ]] Parm0: int !jvms: Inline::test @ bci:-1 (line 21)
 51  MulI  === _ 10 50  [[ 65 ]]  !jvms: Inline::test @ bci:13 (line 21)
$6 = void
(rr) set $n = find_node(51)
(rr) p $n
$1 = (Node *) 0x7f9c805eb6d8
(rr) p *$n
$2 = {_vptr.Node = 0x7f9c89ab8588 <vtable for MulINode+16>, _in = 0x7f9c805eb740, _out = 0x7f9c805eb778, _cnt = 3, _max = 3, 
  _outcnt = 1, _outmax = 4, _idx = 51, _parse_idx = 51, _igv_idx = 51, _class_id = 4096, _flags = 0, static NO_HASH = 0, 
  static NotAMachineReg = 4294901760, _debug_orig = 0x0, _debug_idx = 1020000000051, _hash_lock = 1, _last_del = 0x7f9c805eaab8, 
  _del_tick = 2}
(rr) p $n->dump()
 51  MulI  === _ 10 50  [[ 65 ]]  !jvms: Inline::test @ bci:13 (line 21)
$3 = void
(rr) p $n->_in
$4 = (Node **) 0x7f9c805eb740
(rr) p $n->_in[1]
$5 = (Node *) 0x7f9c805e9438
(rr) p $n->_in[2]
$6 = (Node *) 0x7f9c805eb660
(rr) p $n->_in[1]->dump()
 10  Parm  === 3  [[ 51 ]] Parm0: int !jvms: Inline::test @ bci:-1 (line 21)
$7 = void
(rr) p $n->_in[2]->dump()
 50  ConI  === 0  [[ 51 ]]  #int:303
$8 = void
(rr) p &$n->_in[2]
$9 = (Node **) 0x7f9c805eb750
(rr) watch *0x7f9c805eb750
Hardware watchpoint 2: *0x7f9c805eb750
(rr) rc
Continuing.

Thread 3 hit Hardware watchpoint 2: *0x7f9c805eb750

Old value = -2141276576
New value = -1414812757
0x00007f9c88bcbba0 in Node::Node (this=0x7f9c805eb6d8, n0=0x0, n1=0x7f9c805e9438, n2=0x7f9c805eb660)
    at /home/g/src/jdk/src/hotspot/share/opto/node.cpp:380
(rr) bt
#0  0x00007f9c88bcbba0 in Node::Node (this=0x7f9c805eb6d8, n0=0x0, n1=0x7f9c805e9438, n2=0x7f9c805eb660)
    at /home/g/src/jdk/src/hotspot/share/opto/node.cpp:380
#1  0x00007f9c88b88dc5 in MulNode::MulNode (this=0x7f9c805eb6d8, in1=0x7f9c805e9438, in2=0x7f9c805eb660)
    at /home/g/src/jdk/src/hotspot/share/opto/mulnode.hpp:44
#2  MulINode::MulINode (this=0x7f9c805eb6d8, in1=0x7f9c805e9438, in2=0x7f9c805eb660)
    at /home/g/src/jdk/src/hotspot/share/opto/mulnode.hpp:95
#3  MulNode::make (in1=0x7f9c805e9438, in2=0x7f9c805eb660, bt=<optimized out>) at /home/g/src/jdk/src/hotspot/share/opto/mulnode.cpp:212
#4  0x00007f9c88cf450a in PhaseGVN::apply_ideal (can_reshape=false, this=0x7f9c7b2fcac0, k=<optimized out>)
    at /home/g/src/jdk/src/hotspot/share/opto/phaseX.cpp:683
#5  PhaseGVN::transform (this=0x7f9c7b2fcac0, n=<optimized out>) at /home/g/src/jdk/src/hotspot/share/opto/phaseX.cpp:696
#6  0x00007f9c88cc4b55 in Parse::do_one_bytecode (this=this@entry=0x7f9c7b2fc6b0)
    at /home/g/src/jdk/src/hotspot/share/opto/parse2.cpp:2316
#7  0x00007f9c88cb0b07 in Parse::do_one_block (this=0x7f9c7b2fc6b0) at /home/g/src/jdk/src/hotspot/share/opto/parse1.cpp:1636
#8  0x00007f9c88cb1ca0 in Parse::do_all_blocks (this=this@entry=0x7f9c7b2fc6b0) at /home/g/src/jdk/src/hotspot/share/opto/parse1.cpp:747
#9  0x00007f9c88cb5521 in Parse::Parse (this=this@entry=0x7f9c7b2fc6b0, caller=caller@entry=0x7f9c8074a780, 
    parse_method=<optimized out>, expected_uses=<optimized out>) at /home/g/src/jdk/src/hotspot/share/opto/parse1.cpp:646
#10 0x00007f9c87df9e8b in ParseGenerator::generate (this=0x7f9c8074a768, jvms=0x7f9c8074a780)
    at /home/g/src/jdk/src/hotspot/share/opto/callGenerator.cpp:97
#11 0x00007f9c87fe2065 in Compile::Compile (this=this@entry=0x7f9c7b2fd5d0, ci_env=ci_env@entry=0x7f9c7b2fe6b0, 
    target=target@entry=0x7f9c805c7ca0, osr_bci=osr_bci@entry=-1, options=..., directive=directive@entry=0x7f9c806f5170)
    at /home/g/src/jdk/src/hotspot/share/opto/compile.cpp:813
#12 0x00007f9c87df8045 in C2Compiler::compile_method (this=<optimized out>, env=0x7f9c7b2fe6b0, target=0x7f9c805c7ca0, entry_bci=-1, 
    install_code=<optimized out>, directive=0x7f9c806f5170) at /home/g/src/jdk/src/hotspot/share/opto/c2compiler.cpp:147
#13 0x00007f9c87ff287f in CompileBroker::invoke_compiler_on_method (task=task@entry=0x7f9c807cf9e0)
    at /home/g/src/jdk/src/hotspot/share/compiler/compileBroker.cpp:2345
#14 0x00007f9c87ff3ac0 in CompileBroker::compiler_thread_loop () at /home/g/src/jdk/src/hotspot/share/compiler/compileBroker.cpp:1989
#15 0x00007f9c8857181b in JavaThread::thread_main_inner (this=0x7f9c8026d3a0)
    at /home/g/src/jdk/src/hotspot/share/runtime/javaThread.hpp:613
#16 0x00007f9c891f4996 in Thread::call_run (this=this@entry=0x7f9c8026d3a0) at /home/g/src/jdk/src/hotspot/share/runtime/thread.cpp:243
#17 0x00007f9c88c61f28 in thread_native_entry (thread=0x7f9c8026d3a0) at /home/g/src/jdk/src/hotspot/os/linux/os_linux.cpp:931
#18 0x00007f9c89c97e63 in start_thread () from /nix/store/cg9s562sa33k78m63njfn1rw47dp9z0i-glibc-2.40-66/lib/libc.so.6
#19 0x00007f9c89d1bb94 in clone () from /nix/store/cg9s562sa33k78m63njfn1rw47dp9z0i-glibc-2.40-66/lib/libc.so.6
```
