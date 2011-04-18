#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/vmstat'

options = Hash.new
options['os'] = "linux"
opts = OptionParser.new
opts.on("--os OS") do |os|
    options['os'] = os.downcase
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
Usage: vmstat2csv.rb [--os OS | --debug LEVEL] VMSTAT_OUTPUT
         parse VMSTAT_OUTPUT and print in CSV format.
         OS is an operating system on which VMSTAT_OUTPUT created.
           "linux" or "macosx" is supported.
END
    exit
end
opts.parse!(ARGV)

vmstat = Sysstat::VmstatFactory.create(options['os'])
Sysstat.debug(options['debug']) if options['debug']
vmstat.parse(ARGV.shift)
#vmstat.dump
vmstat.print_csv
