#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sar'

sar = Sysstat::LinuxSar.new
sar.parse(ARGV.shift)
#sar.dump
sar.exclude_filter = /intr_cpu|intr_xall.\d|net_e?dev\.(lo|sit|usb)/
sar.print_csv_header
sar.print_csv_data
