package org.mendrugo.fibula;

import com.sun.hotspot.tools.compiler.Compilation;
import com.sun.hotspot.tools.compiler.LogEvent;
import com.sun.hotspot.tools.compiler.LogParser;
import com.sun.hotspot.tools.compiler.NMethod;

import java.util.ArrayList;
import java.util.Comparator;

public class ByStartTimeAll
{
    /**
     * Sort log events by start time.
     */
    static Comparator<LogEvent> sortByStart = new Comparator<>()
    {

        public int compare(LogEvent a, LogEvent b)
        {
            double difference = (a.getStart() - b.getStart());
            if (difference < 0)
            {
                return -1;
            }
            if (difference > 0)
            {
                return 1;
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
        final ArrayList<LogEvent> events = LogParser.parse(args[0], false);
        final Comparator<LogEvent> sort = sortByStart;
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
            if (c instanceof Compilation)
            {
                Compilation comp = (Compilation) c;
                comp.print(System.out, printID, printInlining);
            }
            else
            {
                c.print(System.out, printID);
            }
        }
    }
}
