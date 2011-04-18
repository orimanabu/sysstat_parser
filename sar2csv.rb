#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/sar'

options = Hash.new
options['os'] = "linux"
opts = OptionParser.new
opts.on("--os OS") do |os|
    options['os'] = os.downcase
end
opts.on("--exclude REGEXP") do |regexp|
    options['exclude_filter'] = regexp
end
opts.on("--header-only") do |v|
    options['header_only'] = v
end
opts.on("--debug LEVEL") do |level|
    if level == "csv"
        options['debug'] = Sysstat::DEBUG_CSV
    elsif level == "parse"
        options['debug'] = Sysstat::DEBUG_PARSE
    elsif level == "all"
        options['debug'] = Sysstat::DEBUG_ALL
    else
        optoins['debug'] = Sysstat::DEBUG_NONE
    end
end
opts.on("--help") do
    print <<END
Usage: sar2csv [--os OS | --exclude REGEXP | --debug LEVEL | --header-only] SAR_OUTPUT
         parse SAR_OUTPUT and print in CSV format.
         OS is an operating system on which SAR_OUTPUT created.
           "linux" or "macosx" is supported.
         SAR_OUTPUT is output of "sar -f SARDATA".
         You can exclude metrics using REGEXP.
END
    exit
end
opts.parse!(ARGV)

sar = Sysstat::SarFactory.create(options['os'])
Sysstat.debug(options['debug']) if options['debug']
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
sar.print_csv_header
exit if options['header_only']
sar.print_csv_data
