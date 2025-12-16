You are running on a Fedora 40 machine.

Think how to achieve the following objective:
You want to run a java program within a Fedora 40 x86/64 VM that has `avx512_fp16` CPU features.

The CPU of the host system chip doesn't have those specific CPU features,
so you need to use CPU emulation instead of hardware acceleration.

You don't need access to the graphical interface in the VM,
you only need terminal access.

Use a Fedora Linux 40 version as OS for the VM. The size of the VM should be 50 GB.

You need to explain how the VM will be created.

You need to be able to start a terminal in the VM and show it in the current terminal window.

To speed up things, the JDK that contains the java binary will be built outside the VM.
The VM should be configured to share a folder with the host,
where the JDK will be placed.

You will also provide tips on how to build the JDK outside the VM in a portable way,
such that the VM can run the JDK without any issues.

Within the VM terminal, explain how would achieve this:

1. Run a basic java program (e.g. "hello world") with JDK in the shared folder.
2. Verify that the JDK built has the CPU features required.
