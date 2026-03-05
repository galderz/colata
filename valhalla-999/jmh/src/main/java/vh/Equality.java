package org.sample.jmh.valhalla;

import org.openjdk.jmh.annotations.*;

import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

@Warmup(iterations = 5, time = 1, timeUnit = TimeUnit.SECONDS)
@Measurement(iterations = 5, time = 1, timeUnit = TimeUnit.SECONDS)
@Fork(1)
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Benchmark)
public class Equality
{
    Object objects[];
    Complex128 valueObjects[];

//    Object a;
//    Object copyOfA;
//    Object b;
//
//    Complex128 complexA;
//    Complex128 copyOfComplexA;
//    Complex128 complexB;

    @Setup
    public void shake()
    {
        objects = new Object[3];
        objects[0] = new Object();
        objects[1] = objects[0];
        objects[2] = new Object();

        valueObjects = new Complex128[3];
        valueObjects[0] = new Complex128(1.0, 2.0);
        valueObjects[1] = valueObjects[0];
        valueObjects[2] = new Complex128(10.0, 20.0);
    }

    @Benchmark
    public boolean areSameObject()
    {
        final Object a = objects[0];
        final Object copyOfA = objects[1];
        return copyOfA == a;
    }

    @Benchmark
    public boolean areNotSameObject()
    {
        final Object a = objects[0];
        final Object b = objects[2];
        return a != b;
    }

    @Benchmark
    public boolean areSameValueClass()
    {
        final Complex128 a = valueObjects[0];
        final Complex128 copyOfA = valueObjects[1];
        return copyOfA == a;
    }

    @Benchmark
    public boolean areNotSameValueClass()
    {
        final Complex128 a = valueObjects[0];
        final Complex128 b = valueObjects[2];
        return a != b;
    }

    @Benchmark
    public boolean areNotSameMix()
    {
        final Object a = objects[0];
        final Complex128 b = valueObjects[0];
        return a != b;
    }

    value class Complex128
    {
        double re, im;

        Complex128(double re, double im)
        {
            this.re = re;
            this.im = im;
        }
    }
}