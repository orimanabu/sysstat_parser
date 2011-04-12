#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/sar'

options = Hash.new
opts = OptionParser.new
opts.on("--exclude REGEXP") { |regexp|
    options['exclude_filter'] = regexp
}
opts.on("--help") {
    print <<END
Usage: parse_sar [--exclude REGEXP] SAR_OUTPUT
         parse SAR_OUTPUT and print in CSV format.
         SAR_OUTPUT is output of "sar -f SARDATA".
         You can exclude metrics using REGEXP.
END
    exit
}
opts.parse!(ARGV)

sar = Sysstat::LinuxSar.new
#sar = Sysstat::MacOSXSar.new
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
sar.print_csv_header
sar.print_csv_data
