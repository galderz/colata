package src;

import com.squareup.javapoet.FieldSpec;
import com.squareup.javapoet.JavaFile;
import com.squareup.javapoet.MethodSpec;
import com.squareup.javapoet.TypeSpec;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Map;

import static javax.lang.model.element.Modifier.FINAL;
import static javax.lang.model.element.Modifier.PUBLIC;
import static javax.lang.model.element.Modifier.STATIC;
import static javax.lang.model.element.Modifier.VALUE;

public class Gen
{
    public static void main(String[] args) throws IOException
    {
        var boxCtor = MethodSpec.constructorBuilder()
            .addParameter(int[].class, "v")
            .addStatement("this.v = v")
            .build();

        var box = TypeSpec.classBuilder("Box")
            .addModifiers(STATIC, VALUE)
            .addField(int[].class, "v", FINAL)
            .addMethod(boxCtor)
            .build();

        var iter = FieldSpec.builder(int.class, "ITER", STATIC, FINAL)
            .initializer("10_000")
            .build();

        var value = "new int[]{16}";

        var test = MethodSpec.methodBuilder("test")
            .returns(int[].class)
            .addModifiers(STATIC)
            .addStatement("var box = new $N($L)", box, value)
            .addStatement("return box.v")
            .build();

        var validate = MethodSpec.methodBuilder("validate")
            .addModifiers(STATIC)
            .addParameter(int[].class, "expected")
            .addParameter(int[].class, "actual")
            .beginControlFlow("if($T.equals(expected, actual))", Arrays.class)
            .addStatement("System.out.print(\".\")")
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
            .addStatement("validate($L, result)", value)
            .endControlFlow()
            .build();

        var type = TypeSpec.classBuilder("Test")
            .addModifiers(PUBLIC, FINAL)
            .addField(iter)
            .addType(box)
            .addMethod(test)
            .addMethod(main)
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
}
