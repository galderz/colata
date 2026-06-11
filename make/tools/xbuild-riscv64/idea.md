You are an OpenJDK HotSpot engineer.

You have a riscv64 board but building a JDK there is very slow (takes approx 2h to build).

You want to explore cross building on the current platform for that target architecture,
with the aim of running the IR tests in the https://github.com/openjdk/jdk/pull/26823
in the riscv64 board.

There could be multiple ways to achieve this,
so explore them until we find a working solution.

You don't have access to the riscv64 board,
but create zip files for any prototypes that need copying over and we will take of that separately and provide feedback.

The IR test might have assertion failures in the riscv64 environment, but that is fine as this has been hinted by Manuel in the PR.
However, the built JDK should run fine otherwise in the target environment.
