import java.util.Arrays;
import java.util.stream.LongStream;
import java.util.concurrent.ThreadLocalRandom;

public class Test
{
    static void main() {
        for (int i = 0; i < 10_000; i++) {
            test(new LoopState().setup(10, 100));
        }
    }

    public static double test(LoopState state) {
        double result = 0;
        for (int i = 0; i < state.size; i++) {
            final double v = state.maxDoubleA[i];
            result = Math.max(result, v);
            // result = Math.max(v, result);
        }
        return result;
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
                long max = ThreadLocalRandom.current().nextLong(1, 10);
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