#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

module Sysstat
    DEBUG_NONE  = 0x0
    DEBUG_PARSE = 0x1
    DEBUG_CSV   = 0x2
    DEBUG_ALL   = 0xFF
    @debug_level = DEBUG_NONE

    def Sysstat.debug(*arg)
        if arg
            @debug_level = arg.shift
        end
        return @debug_level
    end

    def Sysstat.debug_print(level, message)
        if (@debug_level & level) != 0
            STDOUT.print "<#{level}>", message
#            STDERR.print "<#{level}>", message
        end
    end
end
