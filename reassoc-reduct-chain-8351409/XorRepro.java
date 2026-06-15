import java.util.Random;

public class XorRepro {

    static final int SIZE = 2048;

    byte[] in1B = new byte[SIZE], in2B = new byte[SIZE], in3B = new byte[SIZE];
    short[] in1S = new short[SIZE], in2S = new short[SIZE], in3S = new short[SIZE];

    public static void main(String[] args) {
        XorRepro repro = new XorRepro();
        Random r = new Random(0);
        for (int i = 0; i < SIZE; i++) {
            repro.in1B[i] = (byte) r.nextInt();
            repro.in2B[i] = (byte) r.nextInt();
            repro.in3B[i] = (byte) r.nextInt();
            repro.in1S[i] = (short) r.nextInt();
            repro.in2S[i] = (short) r.nextInt();
            repro.in3S[i] = (short) r.nextInt();
        }

        for (int i = 0; i < 20_000; i++) {
            repro.byteXorBig();
            repro.shortXorBig();
        }

        int iters = 500_000;
        long t0, t1;

        t0 = System.nanoTime();
        for (int i = 0; i < iters; i++) repro.byteXorBig();
        t1 = System.nanoTime();
        System.out.println("byteXorBig:  " + (t1 - t0) / 1_000_000 + " ms for " + iters + " iters");

        t0 = System.nanoTime();
        for (int i = 0; i < iters; i++) repro.shortXorBig();
        t1 = System.nanoTime();
        System.out.println("shortXorBig: " + (t1 - t0) / 1_000_000 + " ms for " + iters + " iters");
    }

    byte byteXorBig() {
        byte acc = 0;
        for (int i = 0; i < SIZE; i++) {
            byte val = (byte)((in1B[i] * in2B[i]) + (in1B[i] * in3B[i]) + (in2B[i] * in3B[i]));
            acc ^= val;
        }
        return acc;
    }

    short shortXorBig() {
        short acc = 0;
        for (int i = 0; i < SIZE; i++) {
            short val = (short)((in1S[i] * in2S[i]) + (in1S[i] * in3S[i]) + (in2S[i] * in3S[i]));
            acc ^= val;
        }
        return acc;
    }
}
