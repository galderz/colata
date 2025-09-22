package org.mendrugo.colata;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import java.util.stream.Stream;

public class UopsLoop
{
    private static final Pattern ASM_PATTERN = Pattern
        .compile(
            "^\\s*0x[0-9a-fA-F]+:\\s*(.*?)\\s*(?:;.*)?$"
        );

    private static void asLoopAssembly(Path path) throws IOException
    {
        final String fileName = path.getFileName().toString();
        final int separator = fileName.lastIndexOf('.');
        final Path output = path.resolveSibling(fileName.substring(0, separator) + ".asm");

        try (Stream<String> reader = Files.lines(path);
             Writer writer = Files.newBufferedWriter(output))
        {
            writeLine("loop:", writer);
            reader.map(ASM_PATTERN::matcher)
                .map(m -> m.matches() ? m.group(1) : null)
                .filter(s -> s != null && !s.isBlank())
                .forEach(line -> writeLine(line, writer));
            writeLine("jnz loop", writer);

            System.out.printf("Converted %s into %s%n", path, output);
        }
    }

    static void writeLine(String str, Writer writer)
    {
        try
        {
            writer.write(str);
            writer.write("\n");
        }
        catch (IOException e)
        {
            throw new UncheckedIOException(e);
        }
    }

    public static void main(String[] args) throws IOException
    {
        final Path path = Path.of(
            System.getProperty("user.home")
            , "tmp/avoid-cmov-long-min-max/2209/xeon"
        );

        try(Stream<Path> file = Files.list(path))
        {
            file.filter(p -> p.toString().endsWith("dis"))
                .forEach(p -> {
                    try
                    {
                        UopsLoop.asLoopAssembly(p);
                    }
                    catch (IOException e)
                    {
                        throw new UncheckedIOException(e);
                    }
                });
        }
    }
}
