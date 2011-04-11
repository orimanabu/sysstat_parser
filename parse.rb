#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sar'

sar = Sysstat::LinuxSar.new
sar.parse(ARGV.shift)
sar.dump
sar.print_csv_header
