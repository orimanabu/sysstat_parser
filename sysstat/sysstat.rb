#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

module Sysstat
    DEBUG_NONE  = 0x0
    DEBUG_PARSE = 0x1
    DEBUG_CSV   = 0x2
    DEBUG_ALL   = 0xFF

    module Sysstat
        @@debug_level = DEBUG_NONE

        def debug(*arg)
            if arg
                option = arg.shift
                option ? @@debug_level = option : DEBUG_NONE
            end
            return @@debug_level
        end

        def debug_print(level, message)
            if (@@debug_level & level) != 0
                STDOUT.print "<#{level}>", message
#                STDERR.sync
#                STDERR.print "<#{level}>", message
            end
        end
    end
end
