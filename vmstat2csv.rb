#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/vmstat'

options = Hash.new
options['os'] = "linux"
opts = OptionParser.new
opts.on("--os OS") { |os| options['os'] = os.downcase }
opts.on("--debug LEVEL") do |level|
    case level
    when "csv";     options['debug'] = Sysstat::DEBUG_CSV
    when "parse";   options['debug'] = Sysstat::DEBUG_PARSE
    when "all";     options['debug'] = Sysstat::DEBUG_ALL
    else;           optoins['debug'] = Sysstat::DEBUG_NONE
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
vmstat.debug(options['debug'])
vmstat.parse(ARGV.shift)
#vmstat.dump
vmstat.print_csv
