#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/sar'

options = Hash.new
options['os'] = "linux"
opts = OptionParser.new
opts.on("--os OS") { |os|
    options['os'] = os.downcase
}
opts.on("--exclude REGEXP") { |regexp|
    options['exclude_filter'] = regexp
}
opts.on("--header-only") { |v|
    options['header_only'] = v
}
opts.on("--debug LEVEL") { |level|
    if level == "csv"
        options['debug'] = Sysstat::DEBUG_CSV
    elsif level == "parse"
        options['debug'] = Sysstat::DEBUG_PARSE
    elsif level == "all"
        options['debug'] = Sysstat::DEBUG_ALL
    else
        optoins['debug'] = Sysstat::DEBUG_NONE
    end
}
opts.on("--help") {
    print <<END
Usage: sar2csv [--os OS | --exclude REGEXP | --debug LEVEL | --header-only] SAR_OUTPUT
         parse SAR_OUTPUT and print in CSV format.
         OS is an operating system on which SAR_OUTPUT created.
           "linux" or "macosx" is supported.
         SAR_OUTPUT is output of "sar -f SARDATA".
         You can exclude metrics using REGEXP.
END
    exit
}
opts.parse!(ARGV)

sar = nil
case options['os']
when "linux"
    sar = Sysstat::LinuxSar.new
when "macosx"
    sar = Sysstat::MacOSXSar.new
else
    abort "invalid OS: #{options['os']}\n"
end

Sysstat.debug(options['debug']) if options['debug']
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
sar.print_csv_header
exit if options['header_only']
sar.print_csv_data
