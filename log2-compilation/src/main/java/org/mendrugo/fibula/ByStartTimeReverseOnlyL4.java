package org.mendrugo.fibula;

import com.sun.hotspot.tools.compiler.Compilation;
import com.sun.hotspot.tools.compiler.LogEvent;
import com.sun.hotspot.tools.compiler.LogParser;
import com.sun.hotspot.tools.compiler.Method;
import com.sun.hotspot.tools.compiler.NMethod;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;

public class ByStartTimeReverseOnlyL4
{
    public static final long JVM_ACC_SYNCHRONIZED = 0x0020; /* wrap method call in monitor lock */

    /**
     * Sort log events by start time, reversed.
     */
    static Comparator<LogEvent> sortByStartReverse = new Comparator<>()
    {

        public int compare(LogEvent a, LogEvent b)
        {
            double difference = (a.getStart() - b.getStart());
            if (difference < 0)
            {
                return 1;
            }
            if (difference > 0)
            {
                return -1;
            }
            return 0;
        }

        @Override
        public boolean equals(Object other)
        {
            return false;
        }

        @Override
        public int hashCode()
        {
            return 7;
        }
    };

    public static void main(String[] args) throws Exception
    {
        System.out.println("ByEndTimeOnly4");

        final ArrayList<LogEvent> events = LogParser.parse(args[0], false);
        final Comparator<LogEvent> sort = sortByStartReverse;
        final boolean printID = true;
        final boolean printInlining = false;

        events.sort(sort);

        for (LogEvent c : events)
        {
            if (c instanceof NMethod)
            {
                // skip these
                continue;
            }
            if (c instanceof Compilation comp)
            {
                final NMethod nMethod = comp.getNMethod();
                if (nMethod != null &&
                    4 == nMethod.getLevel()
                )
                {
                    // Destructure the call below into its components
                    // comp.print(System.out, printID, printInlining);

                    System.out.print(comp.getId());
                    System.out.print(" " + nMethod.getLevel());

                    final long nMethodSize = nMethod.getInstSize();

                    String codeSize = "";
                    if (nMethodSize > 0)
                    {
                        codeSize = "(code size: " + nMethodSize + ")";
                    }

                    final int bc = comp.isOsr() ? comp.getBCI() : -1;
                    System.out.print(decodeFlags(bc, comp) + " " + comp.getCompiler() + " " + format(bc, comp.getMethod()) + codeSize);
                    System.out.println();
                }
            }
//            else
//            {
//                c.print(System.out, printID);
//            }
        }
    }

    static String decodeFlags(int osr_bci, Compilation comp)
    {
        int f = Integer.parseInt(comp.getMethod().getFlags());
        char[] c = new char[4];
        Arrays.fill(c, ' ');
        if (osr_bci >= 0)
        {
            c[0] = '%';
        }
        if ((f & JVM_ACC_SYNCHRONIZED) != 0)
        {
            c[1] = 's';
        }
        return new String(c);
    }

    static String format(int osr_bci, Method method)
    {
        return osr_bci >= 0 ? method.getHolder() + "::" + method.getName() + " @ " + osr_bci + " (" + method.getBytes() + " bytes)" : method.getHolder() + "::" + method.getName() + " (" + method.getBytes() + " bytes)";
    }
}
