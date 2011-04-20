#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'optparse'
require 'sysstat/iostat'

options = Hash.new
options['os'] = open('|uname -s') {|file| file.gets.chomp.downcase}
opts = OptionParser.new
opts.on("--os OS") { |os| options['os'] = os.downcase }
opts.on("--exclude REGEXP") { |regexp| options['exclude_filter'] = regexp }
opts.on("--dump") { |v| options['dump'] = v }
opts.on("--debug LEVEL") do |level|
    case level
    when "csv"      then options['debug'] = Sysstat::DEBUG_CSV
    when "parse"    then options['debug'] = Sysstat::DEBUG_PARSE
    when "all"      then options['debug'] = Sysstat::DEBUG_ALL
    else                 optoins['debug'] = Sysstat::DEBUG_NONE
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
(iostat.dump; exit) if options['dump']
iostat.print_csv
