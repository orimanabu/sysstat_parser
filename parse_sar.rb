#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/sar'

options = Hash.new
opts = OptionParser.new
opts.on("--exclude REGEXP") { |regexp|
    options['exclude_filter'] = regexp
}
opts.parse!(ARGV)

sar = Sysstat::LinuxSar.new
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
sar.print_csv_header
sar.print_csv_data
