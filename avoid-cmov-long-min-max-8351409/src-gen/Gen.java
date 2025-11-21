import com.squareup.javapoet.CodeBlock;
import com.squareup.javapoet.FieldSpec;
import com.squareup.javapoet.JavaFile;
import com.squareup.javapoet.MethodSpec;
import com.squareup.javapoet.TypeSpec;

import static javax.lang.model.element.Modifier.FINAL;
import static javax.lang.model.element.Modifier.PUBLIC;
import static javax.lang.model.element.Modifier.STATIC;

MethodSpec buildTest(Option option)
{
    var builder = MethodSpec.methodBuilder("test")
        .addModifiers(STATIC)
        .returns(long.class)
        .addParameter(long[].class, "array")
        .addStatement("$T result = Integer.MIN_VALUE", long.class)
    ;

    switch(option)
    {
        case Base ->
            builder
                .beginControlFlow("for (int i = 0; i < array.length; i++)")
                .addStatement("var v = array[i]")
                .addStatement("result = Math.max(v, result)")
                .endControlFlow()
            ;
        case Reassoc2, Reassoc4, Reassoc8, Reassoc16 ->
            builder.addCode(reassoc(option.size));
        case Unroll2, Unroll4, Unroll8, Unroll16 ->
            builder.addCode(unroll(option.size));
        case Reassoc4x4 ->
            builder.addCode(reassocBy(option.size, option.size));
        case Reassoc2x8 ->
            builder.addCode(reassocBy(option.size, option.size / 4));
        case Reassoc8x2 ->
            builder.addCode(reassocBy(option.size, option.size * 4));
        case ReTree4x4 ->
            builder.addCode(reTree(option.size, option.size));
        case ReTree8x2 ->
            builder.addCode(reTree(option.size, option.size * 4));
        case ReTree16x1 ->
            builder.addCode(reTree(option.size, option.size * 16));
    }

    return builder
        .addStatement("return result")
        .build();
}

MethodSpec buildExpect()
{
    return MethodSpec.methodBuilder("expect")
        .addModifiers(STATIC)
        .returns(long.class)
        .addParameter(long[].class, "array")
        .addStatement("$T result = Integer.MIN_VALUE", long.class)
        .beginControlFlow("for (int i = 0; i < array.length; i++)")
        .addStatement("var v = array[i]")
        .addStatement("var t = Math.max(v, result)")
        .addStatement("result = t")
        .endControlFlow()
        .addStatement("return result")
        .build();
}

CodeBlock reTree(int outer, int inner)
{
    var builder = CodeBlock.builder();
    builder
        .beginControlFlow(
            "for (int i = 0; i < array.length; i += $L)"
            , outer * inner
        );


    int nameIndex = 0;
    for (int i = 0; i < outer; i++)
    {
        final int index = i * inner;

        final Queue<String> names = new LinkedList<>();
        for (int j = 0; j < inner; j++)
        {
            var name = "v" + (index + j);
            builder.addStatement("var $L = array[i + $L]", name, index + j);
            names.offer(name);
        }

        while (names.size() > 1)
        {
            var name = "t" + nameIndex;
            nameIndex++;

            final String left = names.poll();
            final String right = names.poll();
            builder.addStatement("var $L = Math.max($L, $L)", name, left, right);
            names.offer(name);
        }

        builder.addStatement("result = Math.max(result, t$L)", nameIndex - 1);
    }

    return builder
        .endControlFlow()
        .build();
}

CodeBlock reassocBy(int outer, int inner)
{
    var builder = CodeBlock.builder();
    builder
        .beginControlFlow(
            "for (int i = 0; i < array.length; i += $L)"
            , outer * inner
        );

    for (int i = 0; i < outer; i++)
    {
        final int index = i * inner;

        for (int j = 0; j < inner; j++)
        {
            builder.addStatement("var v$L = array[i + $L]", index + j, index + j);
        }

        builder.addStatement("var t$L = Math.max(v$L, v$L)", index, index + 1, index);

        for (int j = 1; j < inner - 1; j++)
        {
            builder.addStatement("var t$L = Math.max(v$L, t$L)", index + j, index + j + 1, index + j - 1);
        }

        builder.addStatement("result = Math.max(result, t$L)", index + inner - 2);
    }

    return builder
        .endControlFlow()
        .build();
}

CodeBlock reassoc(int size)
{
    var builder = CodeBlock.builder();
    builder
        .beginControlFlow(
            "for (int i = 0; i < array.length; i += $L)"
            , size
        );

    int index = 0;
    for (int i = 0; i < size; i++)
    {
        builder.addStatement("var v$L = array[i + $L]", index, index);
        index++;
    }

    var comment = new ArrayDeque<String>();

    comment.addLast("max(v1, v0)");
    builder.addStatement("var t0 = Math.max(v1, v0)");

    index = 1;
    for (int i = index; i < size - 1; i++)
    {
        comment.addFirst("max(v%d, ".formatted(index + 1));
        comment.addLast(")");

        builder.addStatement("var t$L = Math.max(v$L, t$L)", index, index + 1, index - 1);
        index++;
    }

    comment.addFirst("result = max(result, ");
    comment.addLast(")");

    return builder
        .add("// %s%n".formatted(String.join("", comment)))
        .addStatement("result = Math.max(result, t$L)", index - 1)
        .endControlFlow()
        .build();
}

CodeBlock unroll(int size)
{
    var builder = CodeBlock.builder();
    builder
        .beginControlFlow(
            "for (int i = 0; i < array.length; i += $L)"
            , size
        );

    int index = 0;
    for (int i = 0; i < size; i++)
    {
        builder.addStatement("var v$L = array[i + $L]", index, index);
        index++;
    }

    var comment = new ArrayDeque<String>();

    comment.addLast("max(v0, result)");
    builder.addStatement("var t0 = Math.max(v0, result)");

    index = 1;
    for (int i = index; i < size; i++)
    {
        comment.addFirst("max(v%d, ".formatted(index));
        comment.addLast(")");

        builder.addStatement("var t$L = Math.max(v$L, t$L)", index, index, index - 1);
        index++;
    }

    comment.addFirst("result = ");

    return builder
        .add("// %s%n".formatted(String.join("", comment)))
        .addStatement("result = t$L", index - 1)
        .endControlFlow()
        .build();
}

enum Option
{
    Base(0)
    , Reassoc2(2)
    , Unroll2(2)
    , Reassoc4(4)
    , Unroll4(4)
    , Reassoc8(8)
    , Unroll8(8)
    , Reassoc16(16)
    , Unroll16(16)
    , Reassoc4x4(4)
    , Reassoc2x8(8)
    , Reassoc8x2(2)
    , ReTree4x4(4)
    , ReTree8x2(2)
    , ReTree16x1(1)
    ;

    final int size;

    Option(int size) {this.size = size;}
}

void gen(Option option) throws IOException
{
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

    final var test = buildTest(option);
    final var expect = buildExpect();

    var blackhole = MethodSpec.methodBuilder("blackhole")
        .addModifiers(STATIC)
        .returns(void.class)
        .addParameter(long.class, "value")
        .beginControlFlow("if (value == nanoTime())")
        .addStatement("println(value)")
        .endControlFlow()
        .build();

    var assertEquals = MethodSpec.methodBuilder("assertEquals")
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

    var validate = MethodSpec.methodBuilder("validate")
        .addModifiers(STATIC)
        .returns(void.class)
        .addParameter(long.class, "expected")
        .addParameter(long[].class, "array")
        .addStatement("println($S)", "Validate")
        .addStatement("var value = $N(array)", test)
        .addStatement("$N(expected, value)", assertEquals)
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
        .addStatement("var expected = $N(array)", expect)
        .addStatement("$N(expected, array)", validate)
        .addStatement("println($S)", "Warmup")
        .beginControlFlow("for (int i = 0; i < $N; i++)", iter)
        .addStatement("$N(array)", test)
        .endControlFlow()
        .addStatement("println($S)", "Running")
        .beginControlFlow("for (int run = 1; run <= $N; run++)", numRuns)
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
        .addStatement("$N(expected, array)", validate)
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
        .addMethod(expect)
        .addMethod(blackhole)
        .addMethod(validate)
        .addMethod(assertEquals)
        .build();

    var javaFile = JavaFile.builder("", type)
        .addStaticImport(IO.class, "*")
        .addStaticImport(System.class, "nanoTime")
        .addStaticImport(TimeUnit.class, "*")
        .build();

    var src = Path
        .of(System.getProperty("user.dir"))
        .resolve("src")
        .resolve(option.toString())
        .toFile();

    if (!src.exists())
    {
        if (!src.mkdirs())
        {
            throw new IOException("Couldn't make src directory: " + src);
        }
    }

    javaFile.writeTo(src);
}

void main(String[] args) throws IOException
{
    for (String arg : args)
    {
        gen(Option.valueOf(arg));
    }
}
