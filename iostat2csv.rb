#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/iostat'

options = Hash.new
options['os'] = "linux"
opts = OptionParser.new
opts.on("--os OS") do |os|
    options['os'] = os.downcase
end
opts.on("--exclude REGEXP") do |regexp|
    options['exclude_filter'] = regexp
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
Usage: iostat2csv.rb [--os OS | --exclude REGEXP | --debug LEVEL] IOSTAT_OUTPUT
         parse VMSTAT_OUTPUT and print in CSV format.
         OS is an operating system on which IOSTAT_OUTPUT created.
           "linux" or "macosx" is supported.
         You can exclude devices using REGEXP.
END
    exit
end
opts.parse!(ARGV)

iostat = Sysstat::IostatFactory.create(options['os'])
iostat.debug(options['debug'])
iostat.parse(ARGV.shift)
iostat.exclude_filter = /#{options['exclude_filter']}/ if options['exclude_filter']
#iostat.dump
iostat.print_csv
