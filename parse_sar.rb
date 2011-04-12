#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/sar'

options = Hash.new
opts = OptionParser.new
opts.on("--exclude REGEXP") { |regexp|
    options['exclude_filter'] = regexp
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
Usage: parse_sar [--exclude REGEXP | --debug LEVEL] SAR_OUTPUT
         parse SAR_OUTPUT and print in CSV format.
         SAR_OUTPUT is output of "sar -f SARDATA".
         You can exclude metrics using REGEXP.
END
    exit
}
opts.parse!(ARGV)

sar = Sysstat::LinuxSar.new
#sar = Sysstat::MacOSXSar.new
Sysstat.debug(options['debug']) if options['debug']
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
sar.print_csv_header
sar.print_csv_data
