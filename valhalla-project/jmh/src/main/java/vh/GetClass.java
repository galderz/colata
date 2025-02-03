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
public class GetClass
{
    Object objects[];

    @Setup
    public void shake()
    {
        objects = new Object[2];
        objects[0] = new Point(10.0, 20.0);
        objects[1] = new ValuePoint(50.0, 60.0);
    }

    @Benchmark
    public Class<?> getClassObject()
    {
        return objects[0].getClass();
    }

    @Benchmark
    public Class<?> getClassValueObject()
    {
        return objects[1].getClass();
    }

    static class Point
    {
        double x;
        double y;

        Point(double x, double y)
        {
            this.x = x;
            this.y = y;
        }
    }

    value record ValuePoint(double x, double y);
}
