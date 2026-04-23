import java.util.Arrays;
import java.util.stream.LongStream;
import java.util.concurrent.ThreadLocalRandom;

public class BranchProbability
{
    private static final long negativeZeroDoubleBits = Double.doubleToRawLongBits(-0.0d);

    @SuppressWarnings({"AssertWithSideEffects", "ConstantConditions"})
    public static void needEnabledAsserts()
    {
        boolean enabled = false;
        assert enabled = true;
        if (!enabled)
            throw new AssertionError("assert not enabled");
    }

    static void main() {
        needEnabledAsserts();
        longReductionSimpleMax(new LoopState().setup(10, 100), new Expects(0, 0, 100, 0, 0));
//        longReductionSimpleMax(new LoopState().setup(2048, 100), new Expects(0, 0, 100, 0));
//        doubleReductionSimpleMax(new LoopState().setup(10, 100), new Expects(0, 0, 100, 0));
//        doubleReductionSimpleMax(new LoopState().setup(2048, 100), new Expects(0, 0, 100, 0));
    }

    record Expects(
        int notANumber
        , int zeroZero
        , int above
        , int equals
        , int below
    ) {}

    static class Counts {
        int notANumber;
        int zeroZero;
        int above;
        int equals;
        int below;
    }

    public static long longReductionSimpleMax(LoopState state, Expects expects) {
        long result = 0;
        final Counts counts = new Counts();
        for (int i = 0; i < state.size; i++) {
            final long v = state.maxLongA[i];
            // result = myMax(result, v, counts);
            result = myMax(v, result, counts);
        }
        validate(expects, counts, state.size);
        return result;
    }

    public static long myMax(long a, long b, Counts counts) {
        if (a > b) {
            counts.above++;
            return a;
        }
        if (a == b) {
            counts.equals++;
            return a;
        }

        counts.below++;
        return b;
    }

//    public static double doubleReductionSimpleMax(LoopState state, Expects expects) {
//        double result = 0;
//        final Counts counts = new Counts();
//        for (int i = 0; i < state.size; i++) {
//            final double v = state.maxDoubleA[i];
//            result = myMax(result, v, counts);
//            // result = myMax(v, result, counts);
//        }
//        validate(expects, counts, state.size);
//        return result;
//    }
//
//    public static double myMax(double a, double b, Counts counts) {
//        if (a != a) {
//            counts.notANumber++;
//            return a;   // a is NaN
//        }
//        if ((a == 0.0d) &&
//            (b == 0.0d) &&
//            (Double.doubleToRawLongBits(a) == negativeZeroDoubleBits)) {
//            // Raw conversion ok since NaN can't map to -0.0.
//            counts.zeroZero++;
//            return b;
//        }
//        if (a >= b) {
//            counts.aboveEquals++;
//            return a;
//        }
//
//        counts.below++;
//        return b;
//    }

    static void validate(Expects expects, Counts counts, int numElements) {
        int aboveMaxPercentage = (counts.above * 100) / numElements;
        int belowMaxPercentage = 100 - aboveMaxPercentage;

        System.out.printf("Percentage above max value: %d%% from above %d and and array size %d%n", aboveMaxPercentage, counts.above, numElements);
        System.out.printf("Percentage equals max value: equals %d and and array size %d%n", counts.equals, numElements);
        System.out.printf("Percentage below to max value: %d%%%n", belowMaxPercentage);

        assert aboveMaxPercentage == expects.above : String.format("Expected %d%% above or equal max but got %d%%", expects.above, aboveMaxPercentage);
        assert belowMaxPercentage == expects.below : String.format("Expected %d%% below max but got %d%%", expects.below, belowMaxPercentage);
        assert counts.equals == expects.equals : String.format("Expected %d%% above or equal max but got %d%%", expects.equals, counts.equals);
        assert 0 == expects.zeroZero : String.format("Expected %d%% -0.0 but got %d%%", expects.zeroZero, counts.zeroZero);
        assert 0 == expects.notANumber : String.format("Expected %d%% NaN but got %d%%", expects.notANumber, counts.notANumber);
    }

    public static class LoopState {
        int size;

        /**
         * Probability of one of the min/max branches being taken.
         * For max, this value represents the percentage of branches in which
         * the value will be bigger or equal than the current max.
         * For min, this value represents the percentage of branches in which
         * the value will be smaller or equal than the current min.
         */
        int probability;

        int[] minIntA;
        int[] minIntB;
        long[] minLongA;
        long[] minLongB;
        float[] minFloatA;
        float[] minFloatB;
        double[] minDoubleA;
        double[] minDoubleB;
        int[] maxIntA;
        int[] maxIntB;
        long[] maxLongA;
        long[] maxLongB;
        float[] maxFloatA;
        float[] maxFloatB;
        double[] maxDoubleA;
        double[] maxDoubleB;
        int[] resultIntArray;
        long[] resultLongArray;
        float[] resultFloatArray;
        double[] resultDoubleArray;

        public LoopState setup(int size, int probability) {
            this.size = size;
            this.probability = probability;
            final long[][] longs = distributeLongRandomIncrement(size, probability);
            maxLongA = longs[0];
            maxLongB = longs[1];
            maxIntA = toInts(maxLongA);
            maxIntB = toInts(maxLongB);
            maxFloatA = toFloats(maxLongA);
            maxFloatB = toFloats(maxLongB);
            maxDoubleA = toDoubles(maxLongA);
            maxDoubleB = toDoubles(maxLongB);
            minLongA = negate(maxLongA);
            minLongB = negate(maxLongB);
            minIntA = toInts(minLongA);
            minIntB = toInts(minLongB);
            minFloatA = toFloats(minLongA);
            minFloatB = toFloats(minLongB);
            minDoubleA = toDoubles(minLongA);
            minDoubleB = toDoubles(minLongB);
            resultIntArray = new int[size];
            resultLongArray = new long[size];
            resultFloatArray = new float[size];
            resultDoubleArray = new double[size];
            return this;
        }

        static long[] negate(long[] nums) {
            return LongStream.of(nums).map(l -> -l).toArray();
        }

        static int[] toInts(long[] nums) {
            return Arrays.stream(nums).mapToInt(i -> (int) i).toArray();
        }

        static float[] toFloats(long[] nums) {
            final float[] floats = new float[nums.length];
            for (int i = 0; i < nums.length; i++) {
                floats[i] = (float) nums[i];
            }
            return floats;
        }

        static double[] toDoubles(long[] nums) {
            return Arrays.stream(nums).mapToDouble(i -> (double) i).toArray();
        }

        static long[][] distributeLongRandomIncrement(int size, int probability) {
            long[][] result;
            int aboveCount, abovePercent;

            // This algorithm generates 2 arrays of numbers.
            // The first array is created such that as the array is iterated,
            // there is P probability of finding a new min/max value,
            // and 100-P probability of not finding a new min/max value.
            // This first array is used on its own for tests that iterate an array to reduce it to a single value,
            // e.g. the min or max value in the array.
            // The second array is loaded with values relative to the first array,
            // such that when the values in the same index are compared for min/max,
            // the probability that a new min/max value is found has the probability P.
            do {
                long max = ThreadLocalRandom.current().nextLong(10);
                result = new long[2][size];
                result[0][0] = max;
                result[1][0] = max - 1;

                // Assume that the first value is above the current max
                aboveCount = 1;
                for (int i = 1; i < result[0].length; i++) {
                    long value;
                    if (ThreadLocalRandom.current().nextLong(101) <= probability) {
                        long increment = ThreadLocalRandom.current().nextLong(1, 10);
                        value = max + increment;
                        aboveCount++;
                    } else {
                        long diffToMax = ThreadLocalRandom.current().nextLong(1, 10);
                        value = max - diffToMax;
                    }
                    result[0][i] = value;
                    result[1][i] = max;
                    max = Math.max(max, value);
                }

                abovePercent = (aboveCount * 100) / size;
            } while (abovePercent != probability);

            return result;
        }
    }

    static long[][] distributeLongRandomIncrement(int size, int probability) {
        long[][] result;
        int aboveCount, abovePercent;

        // This algorithm generates 2 arrays of numbers.
        // The first array is created such that as the array is iterated,
        // there is P probability of finding a new min/max value,
        // and 100-P probability of not finding a new min/max value.
        // This first array is used on its own for tests that iterate an array to reduce it to a single value,
        // e.g. the min or max value in the array.
        // The second array is loaded with values relative to the first array,
        // such that when the values in the same index are compared for min/max,
        // the probability that a new min/max value is found has the probability P.
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
                    long diffToMax = ThreadLocalRandom.current().nextLong(10) + 1;
                    value = max - diffToMax;
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