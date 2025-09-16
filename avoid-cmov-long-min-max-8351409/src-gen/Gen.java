import com.squareup.javapoet.FieldSpec;
import com.squareup.javapoet.JavaFile;
import com.squareup.javapoet.MethodSpec;
import com.squareup.javapoet.TypeSpec;

import static javax.lang.model.element.Modifier.FINAL;
import static javax.lang.model.element.Modifier.PUBLIC;
import static javax.lang.model.element.Modifier.STATIC;

MethodSpec buildTest(Option option, MethodSpec.Builder builder)
{
    builder
        .addModifiers(STATIC)
        .returns(long.class)
        .addParameter(long[].class, "array");

    builder
        .addStatement("$T result = Integer.MIN_VALUE;", long.class);

    switch(option)
    {
        case Base ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i++)")
                .addStatement("var v = array[i]")
                .addStatement("result = Math.max(v, result)")
            ;
        case Reassoc2 ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i += 2)")
                .addStatement("var v0 = array[i + 0]")
                .addStatement("var v1 = array[i + 1]")
                // result = max(result, max(v1, v0))
                .addStatement("var t0 = Math.max(v1, v0)")
                .addStatement("result = Math.max(result, t0)")
            ;
        case Unroll2 ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i += 2)")
                .addStatement("var v0 = array[i + 0]")
                .addStatement("var v1 = array[i + 1]")
                // result = max(v1, max(v0, result))
                .addStatement("var t0 = Math.max(v0, result)")
                .addStatement("result = Math.max(v1, t0)")
            ;
        case Reassoc4 ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i += 4)")
                .addStatement("var v0 = array[i + 0]")
                .addStatement("var v1 = array[i + 1]")
                .addStatement("var v2 = array[i + 2]")
                .addStatement("var v3 = array[i + 3]")
                // result = max(result, max(v3, max(v2, max(v1, v0))))
                .addStatement("var t0 = Math.max(v1, v0)")
                .addStatement("var t1 = Math.max(v2, t0)")
                .addStatement("var t2 = Math.max(v3, t1)")
                .addStatement("var t3 = Math.max(result, t2)")
                .addStatement("result = t3")
            ;
        case Unroll4 ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i += 4)")
                .addStatement("var v0 = array[i + 0]")
                .addStatement("var v1 = array[i + 1]")
                .addStatement("var v2 = array[i + 2]")
                .addStatement("var v3 = array[i + 3]")
                // result = max(v3, max(v2, max(v1, max(v0, result))))
                .addStatement("var t0 = Math.max(v0, result)")
                .addStatement("var t1 = Math.max(v1, t0)")
                .addStatement("var t2 = Math.max(v2, t1)")
                .addStatement("var t3 = Math.max(v3, t2)")
                .addStatement("result = t3")
            ;
    }

    builder
        .endControlFlow()
        .addStatement("return result");

    return builder.build();
}

enum Option
{
    Base
    , Reassoc2
    , Unroll2
    , Reassoc4
    , Unroll4
}

void main(String[] args) throws IOException
{
    var option = Option.valueOf(args[0]);

    var iter = FieldSpec.builder(int.class, "ITER", STATIC, FINAL)
        .initializer("100_000")
        .build();

    var numRuns = FieldSpec.builder(int.class, "NUM_RUNS", STATIC, FINAL)
        .initializer("10")
        .build();

    var size = FieldSpec.builder(int.class, "SIZE", STATIC, FINAL)
        .initializer("10_000")
        .build();

    var rnd = FieldSpec.builder(Random.class, "RND", STATIC, FINAL)
        .initializer("new $T(42)", Random.class)
        .build();

    final var test = buildTest(option, MethodSpec.methodBuilder("test"));
    final var mirror = buildTest(option, MethodSpec.methodBuilder("mirror"));

    var blackhole = MethodSpec.methodBuilder("blackhole")
        .addModifiers(STATIC)
        .returns(void.class)
        .addParameter(long.class, "value")
        .beginControlFlow("if (value == nanoTime())")
        .addStatement("println(value)")
        .endControlFlow()
        .build();

    var validate = MethodSpec.methodBuilder("validate")
        .addModifiers(STATIC)
        .returns(void.class)
        .addParameter(long.class, "expected")
        .addParameter(long.class, "actual")
        .beginControlFlow("if(expected == actual)")
        .addStatement("$N(actual)", blackhole)
        .nextControlFlow("else")
        .addStatement(
            "throw new AssertionError($S.formatted(expected, actual))"
            , "Failed: expected: %d, actual: %d"
        )
        .endControlFlow()
        .build();

    var init = MethodSpec.methodBuilder("init")
        .addModifiers(STATIC)
        .returns(void.class)
        .addParameter(long[].class, "array")
        .beginControlFlow("for (int i = 0; i < array.length; i++)")
        .addStatement("array[i] = $N.nextLong() & 0xFFFF_FFFFL", rnd)
        .endControlFlow()
        .build();

    var main = MethodSpec.methodBuilder("main")
        .addModifiers(PUBLIC, STATIC)
        .returns(void.class)
        .addParameter(String[].class, "args")
        .addStatement("var array = new $T[$N]", long.class, size)
        .addStatement("$N(array)", init)
        .addStatement("println($S)", "Warmup")
        .beginControlFlow("for (int i = 0; i < $N; i++)", iter)
        .addStatement("$N(array)", test)
        .endControlFlow()
        .addStatement("println($S)", "Running")
        .beginControlFlow("for (int run = 1; run <= $N; run++)", numRuns)
        .addStatement("$N(array)", init)
        .addStatement("$T expected = 0", long.class)
        .beginControlFlow("if ($N == run)", numRuns)
        .addStatement("expected = $N(array)", mirror)
        .endControlFlow()
        .addStatement("var t0 = nanoTime()")
        .addStatement("$T operations = 0", long.class)
        .beginControlFlow("for (int i = 0; i < $N; i++)", iter)
        .addStatement("$N(array)", test)
        .addStatement("operations++")
        .endControlFlow()
        .addStatement("var t1 = nanoTime()")
        .addStatement("var durationNs = t1 - t0")
        .addStatement("var outputTimeUnit = MILLISECONDS")
        .addStatement("var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs")
        .addStatement(
            "println($S.formatted(throughput))"
            , "Throughput: %d ops/ms"
        )
        .beginControlFlow("if ($N == run)", numRuns)
        .addStatement("println($S)", "Validate")
        .addStatement("var value = $N(array)", test)
        .addStatement("$N(expected, value)", validate)
        .endControlFlow()
        .endControlFlow()
        .build();

    var type = TypeSpec.classBuilder("Test")
        .addModifiers(FINAL)
        .addField(iter)
        .addField(numRuns)
        .addField(size)
        .addField(rnd)
        .addMethod(test)
        .addMethod(main)
        .addMethod(init)
        .addMethod(mirror)
        .addMethod(blackhole)
        .addMethod(validate)
        .build();

    var javaFile = JavaFile.builder("", type)
        .addStaticImport(IO.class, "*")
        .addStaticImport(System.class, "nanoTime")
        .addStaticImport(TimeUnit.class, "*")
        .build();

    var target = Path
        .of(System.getProperty("user.dir"))
        .resolve("target")
        .resolve(args[0])
        .toFile();

    if (!target.exists())
    {
        if (!target.mkdirs())
        {
            throw new IOException("Couldn't make target directory: " + target);
        }
    }

    javaFile.writeTo(target);
}

