package org.mendrugo.colata;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.SortedMap;
import java.util.SortedSet;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.stream.Stream;

public class BenchmarkCompare
{
    private enum Label
    {
        BASE
        , PATCH
    }

    private enum Mode
    {
        Throughput("thrpt", "Throughput, ops/time")
        , AverageTime("avgt", "Average time, time/op")
        , SampleTime("sample", "Sampling time")
        , SingleShotTime("ss", "Single shot invocation time")
        , All("all", "All benchmark modes")
        ;

        private final String shortLabel;
        private final String longLabel;

        Mode(String shortLabel, String longLabel)
        {
            this.shortLabel = shortLabel;
            this.longLabel = longLabel;
        }

        public String shortLabel()
        {
            return shortLabel;
        }

        public String longLabel()
        {
            return longLabel;
        }

        public static Mode deepValueOf(String name)
        {
            try
            {
                return Mode.valueOf(name);
            }
            catch (IllegalArgumentException iae)
            {
                Mode inferred = null;
                for (Mode type : values())
                {
                    if (type.shortLabel().startsWith(name))
                    {
                        if (inferred == null)
                        {
                            inferred = type;
                        }
                        else
                        {
                            throw new IllegalStateException("Unable to parse benchmark mode, ambiguous prefix given: \"" + name + "\"\n" +
                                "Known values are " + getKnown());
                        }
                    }
                }
                if (inferred != null)
                {
                    return inferred;
                }
                else
                {
                    throw new IllegalStateException("Unable to parse benchmark mode: \"" + name + "\"\n" +
                        "Known values are " + getKnown());
                }
            }
        }

        public static List<String> getKnown()
        {
            final List<String> res = new ArrayList<>();
            for (Mode type : Mode.values())
            {
                res.add(type.name() + "/" + type.shortLabel());
            }
            return res;
        }

    }

    record WorkloadParams(
        SortedMap<String, String> params
    )
    {
        Collection<String> keys()
        {
            return params.keySet();
        }

        String get(String name)
        {
            return params.get(name);
        }
    }

    record BenchmarkParams(
        String benchmark
        , Mode mode
        , WorkloadParams params
    )
    {
        Collection<String> paramsKeys()
        {
            return params.keys();
        }

        String param(String key)
        {
            if (params != null)
            {
                return params.get(key);
            }
            else
            {
                return null;
            }
        }
    }

    record Result(
        BenchmarkParams params
        , long sampleCount
        , double baseScore
        , double patchScore
        , long diff
        , String scoreUnit
    ) {}

    record RunResult(
        BenchmarkParams params
        , Result primaryResult
    )
    {
        public static final Comparator<RunResult> DEFAULT_SORT_COMPARATOR =
            Comparator.comparing(o -> o.params.benchmark);
    }

    public static void main(String[] args) throws IOException
    {
        if (args.length != 1)
        {
            System.err.println("Missing directory argument");
            System.exit(10);
        }

        final Path dir = Paths.get(args[0]);

        if (!Files.isDirectory(dir))
        {
            System.err.println("Not a directory: " + dir);
            System.exit(10);
        }

        try (Stream<Path> files = Files.list(dir))
        {
            final List<Path> csvPaths = files
                .filter(f -> f.getFileName().toString().endsWith(".csv"))
                .toList();

            final Collection<RunResult> runResults = readCsvFiles(csvPaths);
            writeOut(runResults, System.out);
//            for (Path p : csvFilePaths)
//            {
//                final String fileName = p.getFileName().toString();
//                final Label label = fileName.endsWith("-base.csv") ? Label.BASE : Label.PATCH;
//                readCsvInto(p, label, table);
//            }
        }
    }

    record CsvLine(Map<String, String> data) {}
    record CsvFile(Map<String, CsvLine> data) {}

    private static Collection<RunResult> readCsvFiles(List<Path> csvPaths) throws IOException
    {
        final Map<Label, Path> labelCsvPaths = new HashMap<>();
        for (Path path : csvPaths)
        {
            final String fileName = path.getFileName().toString();
            final Label label = fileName.endsWith("-base.csv") ? Label.BASE : Label.PATCH;
            labelCsvPaths.put(label, path);
        }

        final CsvFile baseCsvFile = readCsv(labelCsvPaths.get(Label.BASE));
        final CsvFile patchCsvFile = readCsv(labelCsvPaths.get(Label.PATCH));
        final Collection<RunResult> results = new TreeSet<>(RunResult.DEFAULT_SORT_COMPARATOR);
        for (Map.Entry<String, CsvLine> lineEntry : baseCsvFile.data.entrySet())
        {
            final String benchmark = lineEntry.getKey();
            final CsvLine baseValues = lineEntry.getValue();
            final CsvLine patchValues = patchCsvFile.data.get(benchmark);

            final SortedMap<String, String> workloadParams = new TreeMap<>();
            for (Map.Entry<String, String> entry : baseValues.data.entrySet())
            {
                final String name = entry.getKey();
                final String value = entry.getKey();
                if (name.startsWith("Param:"))
                {
                    final String trimmedName = name.split(":")[1].trim();
                    workloadParams.put(trimmedName, value);
                }
            }

            final BenchmarkParams params = new BenchmarkParams(
                benchmark
                , Mode.deepValueOf(baseValues.data.get("Mode"))
                , new WorkloadParams(workloadParams)
            );
            final double baseScore = Double.parseDouble(baseValues.data.get("Score"));
            final double patchScore = Double.parseDouble(patchValues.data.get("Score"));
            final Result result = new Result(
                params
                , Long.parseLong(baseValues.data.get("Samples"))
                , baseScore
                , patchScore
                , Math.round((patchScore - baseScore) / baseScore * 100.0)
                , baseValues.data.get("Unit")
            );
            final RunResult runResult = new RunResult(params, result);
            results.add(runResult);
        }
        return results;
    }

    private static String calculateDiff(double base, double patch) {
        long percentage = Math.round((patch - base) / base * 100.0);
        return String.format("%+d%%", percentage);
    }

    private static CsvFile readCsv(Path path) throws IOException
    {
        final Map<String, CsvLine> fileData = new HashMap<>();
        try (BufferedReader br = Files.newBufferedReader(path))
        {
            final String header = br.readLine();
            if (header == null)
            {
                throw new IllegalStateException("CSV file is empty: " + path);
            }
            final List<String> headerNames = parseCsvLine(header);

            String line;
            while ((line = br.readLine()) != null)
            {
                if (line.isBlank())
                {
                    continue;
                }
                final List<String> values = parseCsvLine(line);
                final Map<String, String> lineData = new HashMap<>();
                for (int i = 0; i < headerNames.size(); i++)
                {
                    final String name = headerNames.get(i);
                    final String value = values.get(i);
                    lineData.put(name, value);
                }

                final CsvLine csvLine = new CsvLine(lineData);
                final String benchmark = lineData.get("Benchmark");
                fileData.put(benchmark, csvLine);
            }
        }
        return new CsvFile(fileData);
    }

    private static List<String> parseCsvLine(String line)
    {
        final List<String> result = new ArrayList<>();
        final StringBuilder sb = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++)
        {
            char c = line.charAt(i);
            if (c == '"')
            {
                if (inQuotes && i + 1 < line.length() && line.charAt(i + 1) == '"')
                {
                    sb.append('"'); // escaped quote
                    i++;
                }
                else
                {
                    inQuotes = !inQuotes;
                }
            } else if (c == ',' && !inQuotes)
            {
                result.add(sb.toString());
                sb.setLength(0);
            }
            else
            {
                sb.append(c);
            }
        }
        result.add(sb.toString());
        return result;
    }

    private static void writeOut(Collection<RunResult> runResults, PrintStream out)
    {
        final int COLUMN_PAD = 2;

        final Collection<String> benchNames = new ArrayList<>();
        for (RunResult runResult : runResults) {
            benchNames.add(runResult.params().benchmark());
            // todo secondary results
            // for (String label : runResult.getSecondaryResults().keySet()) {
            //     benchNames.add(runResult.getParams().getBenchmark() + ":" + label);
            // }
        }

        final Map<String, String> benchPrefixes = denseClassNames(benchNames);

        // determine name column length
        int nameLen = "Benchmark".length();
        for (String prefix : benchPrefixes.values())
        {
            nameLen = Math.max(nameLen, prefix.length());
        }

        // determine param lengths
        final Map<String, Integer> paramLengths = new HashMap<>();
        final SortedSet<String> params = new TreeSet<>();
        for (RunResult runResult : runResults)
        {
            final BenchmarkParams bp = runResult.params();
            for (String k : bp.paramsKeys())
            {
                params.add(k);
                Integer len = paramLengths.get(k);
                if (len == null)
                {
                    len = ("(" + k + ")").length() + COLUMN_PAD;
                }
                paramLengths.put(k, Math.max(len, bp.param(k).length() + COLUMN_PAD));
            }
        }

        // determine column lengths for other columns
        int modeLen = "Mode".length();
        int samplesLen = "Cnt".length();
        int baseScoreLen = "Base".length();
        int patchScoreLen = "Patch".length();
        // todo score error
        // int scoreErrLen = "Error".length();
        int unitLen = "Units".length();
        int diffLen = "Diff".length();

        for (RunResult res : runResults)
        {
            final Result primRes = res.primaryResult();

            modeLen     = Math.max(modeLen, res.params().mode().shortLabel().length());
            samplesLen  = Math.max(samplesLen, String.format("%d", primRes.sampleCount()).length());
            baseScoreLen    = Math.max(baseScoreLen, ScoreFormatter.format(primRes.baseScore()).length());
            patchScoreLen    = Math.max(patchScoreLen, ScoreFormatter.format(primRes.patchScore()).length());
            // todo score error
            // scoreErrLen = Math.max(scoreErrLen, ScoreFormatter.format(primRes.scoreError()).length());
            unitLen     = Math.max(unitLen, primRes.scoreUnit().length());
            diffLen     = Math.max(diffLen, ScoreFormatter.format(primRes.diff()).length());

            // todo secondary results
            // for (Result subRes : res.getSecondaryResults().values()) {
            //     samplesLen  = Math.max(samplesLen,  String.format("%d",   subRes.getSampleCount()).length());
            //     scoreLen    = Math.max(scoreLen,    ScoreFormatter.format(subRes.getScore()).length());
            //     scoreErrLen = Math.max(scoreErrLen, ScoreFormatter.format(subRes.getScoreError()).length());
            //     unitLen     = Math.max(unitLen,     subRes.getScoreUnit().length());
            // }
        }
        modeLen += COLUMN_PAD;
        samplesLen += COLUMN_PAD;
        baseScoreLen += COLUMN_PAD;
        patchScoreLen += COLUMN_PAD;
        // todo score error
        // scoreErrLen += COLUMN_PAD - 1; // digest a single character for +- separator
        unitLen += COLUMN_PAD;
        diffLen += COLUMN_PAD - 1; // digest a single character for + or - separator

        out.printf("%-" + nameLen + "s", "Benchmark");
        for (String k : params) {
            out.printf("%" + paramLengths.get(k) + "s", "(" + k + ")");
        }

        out.printf("%" + modeLen + "s", "Mode");
        out.printf("%" + samplesLen + "s", "Cnt");
        out.printf("%" + baseScoreLen + "s", "Base");
        out.printf("%" + patchScoreLen + "s", "Patch");
        // todo score error
        // out.printf("%" + scoreErrLen + "s", "Error");
        out.printf("%" + unitLen + "s", "Units");
        out.print("  ");
        out.printf("%" + diffLen + "s", "diff");
        out.println();

        for (RunResult res : runResults)
        {
            out.printf("%-" + nameLen + "s", benchPrefixes.get(res.params().benchmark()));

            for (String k : params)
            {
                String v = res.params().param(k);
                out.printf("%" + paramLengths.get(k) + "s", (v == null) ? "N/A" : v);
            }

            final Result pRes = res.primaryResult();
            out.printf("%" + modeLen + "s", res.params().mode().shortLabel());

            if (pRes.sampleCount() > 1)
            {
                out.printf("%" + samplesLen + "d", pRes.sampleCount());
            }
            else
            {
                out.printf("%" + samplesLen + "s", "");
            }

            out.print(ScoreFormatter.format(baseScoreLen, pRes.baseScore()));
            out.print(ScoreFormatter.format(patchScoreLen, pRes.patchScore()));

            // todo score error
            // if (!Double.isNaN(pRes.getScoreError()) && !ScoreFormatter.isApproximate(pRes.getScore())) {
            //     out.print(" \u00B1");
            //     out.print(ScoreFormatter.formatError(scoreErrLen, pRes.getScoreError()));
            // } else {
            //     out.print("  ");
            //     out.printf("%" + scoreErrLen + "s", "");
            // }

            out.printf("%" + unitLen + "s", pRes.scoreUnit());
            if (pRes.diff() > 0)
            {
                out.print(" +");
            }
            else
            {
                out.print(" -");
            }
            out.printf("%" + diffLen + "s", pRes.diff());
            out.println();

            // todo secondary results
            // for (Map.Entry<String, Result> e : res.getSecondaryResults().entrySet()) {
            //     String label = e.getKey();
            //     Result subRes = e.getValue();
            //
            //     out.printf("%-" + nameLen + "s",
            //         benchPrefixes.get(res.getParams().getBenchmark() + ":" + label));
            //
            //     for (String k : params) {
            //         String v = res.getParams().getParam(k);
            //         out.printf("%" + paramLengths.get(k) + "s", (v == null) ? "N/A" : v);
            //     }
            //
            //     out.printf("%" + modeLen + "s", res.getParams().getMode().shortLabel());
            //
            //     if (subRes.getSampleCount() > 1) {
            //         out.printf("%" + samplesLen + "d", subRes.getSampleCount());
            //     } else {
            //         out.printf("%" + samplesLen + "s", "");
            //     }
            //
            //     out.print(ScoreFormatter.format(scoreLen, subRes.getScore()));
            //
            //     if (!Double.isNaN(subRes.getScoreError()) && !ScoreFormatter.isApproximate(subRes.getScore())) {
            //         out.print(" \u00B1");
            //         out.print(ScoreFormatter.formatError(scoreErrLen, subRes.getScoreError()));
            //     } else {
            //         out.print("  ");
            //         out.printf("%" + scoreErrLen + "s", "");
            //     }
            //
            //     out.printf("%" + unitLen + "s", subRes.getScoreUnit());
            //     out.println();
            // }
        }
    }

    private static Map<String, String> denseClassNames(Collection<String> src)
    {
        if (src.isEmpty())
        {
            return Collections.emptyMap();
        }

        int maxLen = Integer.MIN_VALUE;
        for (String s : src)
        {
            maxLen = Math.max(maxLen, s.length());
        }

        boolean first = true;

        boolean prefixCut = false;

        String[] prefix = new String[0];
        for (String s : src)
        {
            final String[] names = s.split("\\.");

            if (first)
            {
                prefix = new String[names.length];

                int c;
                for (c = 0; c < names.length; c++)
                {
                    if (names[c].toLowerCase().equals(names[c]))
                    {
                        prefix[c] = names[c];
                    }
                    else
                    {
                        break;
                    }
                }
                prefix = Arrays.copyOf(prefix, c);
                first = false;
                continue;
            }

            int c = 0;
            while (c < Math.min(prefix.length, names.length))
            {
                String n = names[c];
                String p = prefix[c];
                if (!n.equals(p) || !n.toLowerCase().equals(n))
                {
                    break;
                }
                c++;
            }

            if (prefix.length != c)
            {
                prefixCut = true;
            }
            prefix = Arrays.copyOf(prefix, c);
        }

        for (int c = 0; c < prefix.length; c++)
        {
            prefix[c] = prefixCut ? String.valueOf(prefix[c].charAt(0)) : "";
        }

        final Map<String, String> result = new HashMap<>();
        for (String s : src)
        {
            final int prefixLen = prefix.length;

            final String[] names = s.split("\\.");
            System.arraycopy(prefix, 0, names, 0, prefixLen);

            String dense = "";
            for (String n : names)
            {
                if (!n.isEmpty())
                {
                    dense += n + ".";
                }
            }

            if (dense.endsWith("."))
            {
                dense = dense.substring(0, dense.length() - 1);
            }

            result.put(s, dense);
        }

        return result;
    }

    static final class ScoreFormatter {
        private static final int PRECISION = Integer.getInteger("jmh.scorePrecision", 3);
        private static final double ULP = 1.0 / Math.pow(10, PRECISION);
        private static final double THRESHOLD = ULP / 2;

        public static boolean isApproximate(double score)
        {
            return (score < THRESHOLD);
        }

        public static String format(double score)
        {
            if (isApproximate(score))
            {
                int power = (int) Math.round(Math.log10(score));
                return "\u2248 " + ((power != 0) ? "10" + superscript("" + power) : "0");
            }
            else
            {
                return String.format("%." + PRECISION + "f", score);
            }
        }

        public static String format(int width, double score)
        {
            if (isApproximate(score))
            {
                int power = (int) Math.round(Math.log10(score));
                return String.format("%" + width + "s", "\u2248 " + ((power != 0) ? "10" + superscript("" + power) : "0"));
            }
            else
            {
                return String.format("%" + width + "." + PRECISION + "f", score);
            }
        }

        public static String superscript(String str)
        {
            str = str.replaceAll("-", "\u207b");
            str = str.replaceAll("0", "\u2070");
            str = str.replaceAll("1", "\u00b9");
            str = str.replaceAll("2", "\u00b2");
            str = str.replaceAll("3", "\u00b3");
            str = str.replaceAll("4", "\u2074");
            str = str.replaceAll("5", "\u2075");
            str = str.replaceAll("6", "\u2076");
            str = str.replaceAll("7", "\u2077");
            str = str.replaceAll("8", "\u2078");
            str = str.replaceAll("9", "\u2079");
            return str;
        }
    }
}
