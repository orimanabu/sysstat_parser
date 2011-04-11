#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sar'

sar = Sysstat::LinuxSar.new
sar.parse(ARGV.shift)
sar.exclude_filter = /intr_xall|net_e?dev\.(lo|sit|usb)/
#sar.dump
sar.print_csv_header
sar.print_csv_data
