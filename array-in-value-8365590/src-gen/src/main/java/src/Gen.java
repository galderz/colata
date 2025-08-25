package src;

import com.squareup.javapoet.FieldSpec;
import com.squareup.javapoet.JavaFile;
import com.squareup.javapoet.MethodSpec;
import com.squareup.javapoet.TypeSpec;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import static javax.lang.model.element.Modifier.FINAL;
import static javax.lang.model.element.Modifier.PUBLIC;
import static javax.lang.model.element.Modifier.STATIC;
import static javax.lang.model.element.Modifier.VALUE;

public class Gen
{
    public static void main(String[] args) throws IOException
    {
        final ClassNames className = ClassNames.valueOf(args[0]);

        final Map<String, Object> data = new HashMap<>();
        data.put("fieldName", "v");
        data.put("fieldValue", "new int[]{16}");

        var boxCtor = MethodSpec.constructorBuilder()
            .addParameter(int[].class, data.get("fieldName").toString())
            .addNamedCode("this.$fieldName:L = $fieldName:L;", data)
            .build();

        var box = TypeSpec.classBuilder("Box")
            .addModifiers(STATIC, VALUE)
            .addField(int[].class, data.get("fieldName").toString(), FINAL)
            .addMethod(boxCtor)
            .build();

        data.put("type", box);

        var iter = FieldSpec.builder(int.class, "ITER", STATIC, FINAL)
            .initializer("10_000")
            .build();

        var testBuilder = MethodSpec.methodBuilder("test")
            .returns(int[].class)
            .addModifiers(STATIC);

        switch (className)
        {
            case Eliminated ->
                // Allocate Eliminated
                testBuilder.addNamedCode("""
                    var value = $fieldValue:L;
                    var obj = new $type:N(value);
                    return obj.$fieldName:L;
                    """
                    , data
                );
            case NotEliminated ->
                // Allocate NOT Eliminated
                testBuilder.addNamedCode("""
                    var obj = new $type:N($fieldValue:L);
                    return obj.$fieldName:L;
                    """
                , data
                );
        };

        var test = testBuilder.build();

        var blackhole = MethodSpec.methodBuilder("blackhole")
            .addModifiers(STATIC)
            .addParameter(Object.class, "obj")
            .beginControlFlow("if (obj.hashCode() == $T.nanoTime())", System.class)
            .addStatement("$T.out.println(obj)", System.class)
            .endControlFlow()
            .build();

        var validate = MethodSpec.methodBuilder("validate")
            .addModifiers(STATIC)
            .addParameter(int[].class, "expected")
            .addParameter(int[].class, "actual")
            .beginControlFlow("if($T.equals(expected, actual))", Arrays.class)
            .addStatement("$N(actual)", blackhole)
            .nextControlFlow("else")
            .addStatement("""
                throw new AssertionError(String.format(
                    "Failed, expected: %s, actual: %s"
                    , $T.toString(expected)
                    , $T.toString(actual)
                ))
                """, Arrays.class, Arrays.class)
            .endControlFlow()
            .build();

        var main = MethodSpec.methodBuilder("main")
            .addModifiers(PUBLIC, STATIC)
            .returns(void.class)
            .addParameter(String[].class, "args")
            .beginControlFlow("for (int i = 0; i < $N; i++)", iter)
            .addStatement("var result = $N()", test)
            .addNamedCode("validate($fieldValue:L, result);", data)
            .endControlFlow()
            .build();

        var type = TypeSpec.classBuilder(className.name())
            .addModifiers(PUBLIC, FINAL)
            .addField(iter)
            .addType(box)
            .addMethod(test)
            .addMethod(main)
            .addMethod(blackhole)
            .addMethod(validate)
            .build();

        var javaFile = JavaFile.builder("", type)
            .build();

        var target = Path
            .of(System.getProperty("user.dir"))
            .resolve("target")
            .toFile();

        if (!target.exists() && !target.mkdirs())
        {
            throw new RuntimeException("Couldn't create directory: " + target);
        }

        javaFile.writeTo(target);
    }

    private enum ClassNames
    {
        Eliminated,
        NotEliminated
    }
}
