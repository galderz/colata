package jol.quarkus;

import org.jboss.resteasy.reactive.server.mapping.RequestMapper;
import org.openjdk.jol.info.ClassLayout;
import org.openjdk.jol.vm.VM;

import static java.lang.System.out;

public class RequestMatchJol
{
    public static void main(String[] args)
    {
        out.println(VM.current().details());
        out.println(ClassLayout.parseClass(RequestMapper.RequestMatch.class).toPrintable());
    }
}
