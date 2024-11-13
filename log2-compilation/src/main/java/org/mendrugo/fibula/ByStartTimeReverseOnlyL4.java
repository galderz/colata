package org.mendrugo.fibula;

import com.sun.hotspot.tools.compiler.Compilation;
import com.sun.hotspot.tools.compiler.LogEvent;
import com.sun.hotspot.tools.compiler.LogParser;
import com.sun.hotspot.tools.compiler.NMethod;

import java.util.ArrayList;
import java.util.Comparator;

public class ByStartTimeReverseOnlyL4
{
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
                if (comp.getNMethod() != null &&
                    4 == comp.getNMethod().getLevel()
                )
                {
                    comp.print(System.out, printID, printInlining);
                }
            }
            else
            {
                // c.print(System.out, printID);
            }
        }
    }
}
