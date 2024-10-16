package org.sample;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Measurement;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.Warmup;
import org.openjdk.jol.info.GraphLayout;

import java.util.Arrays;
import java.util.HexFormat;
import java.util.IntSummaryStatistics;
import java.util.LongSummaryStatistics;
import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.stream.LongStream;

@Warmup(iterations = 3, time = 5)
@Measurement(iterations = 4, time = 5)
@Fork(2)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
@BenchmarkMode(Mode.Throughput)
public class MinMaxLoop
{
    @State(Scope.Thread)
    public static class LoopState {
        @Param({"1000"})
        int size;

        /**
         * Probability of one of the min/max branches being taken.
         * For max, this value represents the percentage of branches in which
         * the value will be bigger or equal than the current max.
         * For min, this value represents the percentage of branches in which
         * the value will be smaller or equal than the current min.
         */
        @Param({"50", "80", "100"})
        int probability;

        int[] minIntA;
        int[] minIntB;
        long[] minLongA;
        long[] minLongB;
        int[] maxIntA;
        int[] maxIntB;
        long[] maxLongA;
        long[] maxLongB;
        int[] resultIntArray;
        long[] resultLongArray;

        @Setup
        public void setup() {
            final long[][] longs = distributeLongRandomIncrement(size, probability);
            maxLongA = longs[0];
            maxLongB = longs[1];
            maxIntA = toInts(maxLongA);
            maxIntB = toInts(maxLongB);
            minLongA = negate(maxLongA);
            minLongB = negate(maxLongB);
            minIntA = toInts(minLongA);
            minIntB = toInts(minLongB);
            resultIntArray = new int[size];
            resultLongArray = new long[size];

            final HexFormat hex = HexFormat.of();
            System.out.println("maxLongA start address = " + printableStartAddress(maxLongA, hex));
            System.out.println("maxLongB start address = " + printableStartAddress(maxLongB, hex));
            System.out.println("resultLongArray start address = " + printableStartAddress(resultLongArray, hex));
        }

        private String printableStartAddress(Object obj, HexFormat hex) {
            return hex.toHexDigits(GraphLayout.parseInstance(obj).startAddress());
        }

        static long[] negate(long[] nums) {
            return LongStream.of(nums).map(l -> -l).toArray();
        }

        static int[] toInts(long[] nums) {
            return Arrays.stream(nums).mapToInt(i -> (int) i).toArray();
        }

        static long[][] distributeLongRandomIncrement(int size, int probability) {
            long[][] result;
            int aboveCount, abovePercent;

            // Iterate until you find a set that matches the requirement probability
            do {
                long max = ThreadLocalRandom.current().nextLong(10);
                result = new long[2][size];
                result[0][0] = max;
                result[1][0] = max - 1;

                aboveCount = 0;
                for (int i = 1; i < result[0].length; i++) {
                    long value;
                    if (ThreadLocalRandom.current().nextLong(101) <= probability) {
                        long increment = ThreadLocalRandom.current().nextLong(10);
                        value = max + increment;
                        aboveCount++;
                    } else {
                        // Decrement by at least 1
                        long decrement = ThreadLocalRandom.current().nextLong(10) + 1;
                        value = max - decrement;
                    }
                    result[0][i] = value;
                    result[1][i] = max;
                    max = Math.max(max, value);
                }

                abovePercent = ((aboveCount + 1) * 100) / size;
            } while (abovePercent != probability);

            return result;
        }
    }

    @State(Scope.Thread)
    public static class RangeState
    {
        @Param({"1000"})
        int size;

        /**
         * Define range of values to clip as a percentage.
         * For example, if value is 100, then all values are considered in the range,
         * and so the highest value would be the max value and the lowest value the min value in the array.
         * If the value is 90, then highest would be 10% lower than the max value,
         * and the min value would be 10% higher than the min value.
         */
        @Param({"90", "100"})
        int range;

        @Param("0")
        int seed;

        int[] ints;
        int[] resultInts;
        long[] longs;
        long[] resultLongs;
        int highestInt;
        int lowestInt;
        long highestLong;
        long lowestLong;
        Random r = new Random(seed);

        @Setup
        public void setup() {
            ints = new int[size];
            resultInts = new int[size];
            longs = new long[size];
            resultLongs = new long[size];

            for (int i = 0; i < size; i++) {
                ints[i] = r.nextInt();
                longs[i] = r.nextLong();
            }

            final IntSummaryStatistics intStats = Arrays.stream(ints).summaryStatistics();
            highestInt = (intStats.getMax() * range) / 100;
            lowestInt = intStats.getMin() + (intStats.getMax() - highestInt);

            final LongSummaryStatistics longStats = Arrays.stream(longs).summaryStatistics();
            highestLong = (longStats.getMax() * range) / 100;
            lowestLong = longStats.getMin() + (longStats.getMax() - highestLong);
        }
    }

    @Benchmark
    public int[] intClippingRange(RangeState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultInts[i] = Math.min(Math.max(state.ints[i], state.lowestInt), state.highestInt);
        }
        return state.resultInts;
    }

    @Benchmark
    public int[] intLoopMin(LoopState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultIntArray[i] = Math.min(state.minIntA[i], state.minIntB[i]);
        }
        return state.resultIntArray;
    }

    @Benchmark
    public int[] intLoopMax(LoopState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultIntArray[i] = Math.max(state.maxIntA[i], state.maxIntB[i]);
        }
        return state.resultIntArray;
    }

    @Benchmark
    public int intReductionMin(LoopState state) {
        int result = 0;
        for (int i = 0; i < state.size; i++) {
            final int v = 11 * state.minIntA[i];
            result = Math.min(result, v);
        }
        return result;
    }

    @Benchmark
    public int intReductionMax(LoopState state) {
        int result = 0;
        for (int i = 0; i < state.size; i++) {
            final int v = 11 * state.maxIntA[i];
            result = Math.max(result, v);
        }
        return result;
    }

    @Benchmark
    public long[] longClippingRange(RangeState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultLongs[i] = Math.min(Math.max(state.longs[i], state.lowestLong), state.highestLong);
        }
        return state.resultLongs;
    }

    @Benchmark
    public long[] longLoopMin(LoopState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultLongArray[i] = Math.min(state.minLongA[i], state.minLongB[i]);
        }
        return state.resultLongArray;
    }

    @Benchmark
    public long[] longLoopMax(LoopState state) {
        for (int i = 0; i < state.size; i++) {
            state.resultLongArray[i] = Math.max(state.maxLongA[i], state.maxLongB[i]);
        }
        return state.resultLongArray;
    }

    @Benchmark
    public long longReductionMin(LoopState state) {
        long result = 0;
        for (int i = 0; i < state.size; i++) {
            final long v = 11 * state.minLongA[i];
            result = Math.min(result, v);
        }
        return result;
    }

    @Benchmark
    public long longReductionMax(LoopState state) {
        long result = 0;
        for (int i = 0; i < state.size; i++) {
            final long v = 11 * state.maxLongA[i];
            result = Math.max(result, v);
        }
        return result;
    }
}