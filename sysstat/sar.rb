#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sysstat'

module Sysstat
    class SarData
        attr_reader :name, :time, :instance, :data
        def initialize(name, time, instance, data)
            @name = name
            @time = time
            if instance
                @instance = instance
            else
                @instance = "none"
            end
            @data = data
        end
    end

    class SarMetric
        attr_reader :name
        @@time_regexp = "\\d{2}:\\d{2}:\\d{2}|Average:"
        def initialize(label_regexp, name, description, skip, *flag)
            @label_regexp = label_regexp
            @name = name
            @description = description
            @skip = skip
            @flag = flag.shift
        end

        def match(line)
            re = Regexp.new("(#{@@time_regexp})\\s+(#{@label_regexp})")
            if line =~ re
                return true
            end
            return nil
        end

        def parse(line)
            line.gsub!(Regexp.new("(#{@@time_regexp})\\s+"), '')
            time = Regexp.last_match(1)
            array = line.split(/\s+/)[@skip .. -1]
            if @flag
                if @flag == "have_instance"
                    return SarData.new(@name, time, array.shift, array)
                end
            end
            return SarData.new(@name, time, nil, array)
        end
    end

    class Sar
        include Sysstat
        attr_writer :exclude_filter
        attr_reader :data, :metrics, :labels, :kernel_version, :hostname, :date_str

        def initialize(*metrics)
            @exclude_filter = nil
            @data = Hash.new
            @metrics = Hash.new
            metrics.each do |m|
                @metrics[m.name] = m
            end
            @labels = Hash.new
        end

        def metric(name)
            return @metrics[name]
        end

        def match(line)
            @metrics.values.each do |metric|
                if metric.match(line)
                    return metric.parse(line)
                end
            end
            return nil
        end

        def parse(path)
            debug_print(DEBUG_PARSE, "=== parse ===\n")
            file = File.open(path)
            nline = 0
            current_metric = nil
            file.each do |line|
                line.chomp!
                next if /^$/ =~ line
                next if /^Average:/ =~ line
                next if @ignore_regexp and @ignore_regexp =~ line
                debug_print(DEBUG_PARSE, "#{nline}:\t#{line}\n")
                if /^Linux\s+(\S+)\s+\((\S+)\)\s+(.*)/ =~ line
                    @kernel_version = $1
                    @hostname = $2
                    @date_str = $3
                else
                    if sd = match(line)
                        debug_print(DEBUG_PARSE, "\t=== block (#{sd.name}) start ===\n")
                        @data[sd.name] = Hash.new unless @data[sd.name]
                        current_metric = sd.name
                        @labels[sd.name] = sd.data
                    else
                        sd = metric(current_metric).parse(line)
                        debug_print(DEBUG_PARSE, "### data: #{sd.inspect}\n")
                        @data[current_metric][sd.instance] = Hash.new unless @data[current_metric][sd.instance]
                        @data[current_metric][sd.instance][sd.time] = sd.data
                    end
                end
                nline = nline + 1
            end
        end

        def sort_instances(metric)
            instances = data[metric].keys
            index_of_all = instances.index("all")
            index_of_sum = instances.index("sum")
            index_of_none = instances.index("none")
            instances.delete_at(index_of_all) if index_of_all
            instances.delete_at(index_of_sum) if index_of_sum
            instances.delete_at(index_of_none) if index_of_none
            instances.sort! { |a,b| a.to_i <=> b.to_i }
            instances.unshift("all") if index_of_all
            instances.unshift("sum") if index_of_sum
            instances.unshift("none") if index_of_none
            return instances
        end

        def get_times
            metric = data.keys[0]
            instance = data[metric].keys[0]
            times = data[metric][instance].keys
            return times.sort
        end

        def dump
            print "=== dump ===\n";
            print "kernel_version=", @kernel_version, "\n"
            print "hostname=", @hostname, "\n"
            print "date_str=", @date_str, "\n"
            print "\n"
            data.keys.sort.each do |metric|
                print "<#{metric}>\n"
                sort_instances(metric).each do |instance|
                    print "  <#{instance}>\n"
                    print "    <HH:MM:SS>\t#{labels[metric].inspect}\n"
                    timedata = data[metric][instance]
                    timedata.keys.sort.each do |time|
                        print "    <#{time}>\t#{timedata[time].inspect}\n"
                    end
                end
            end
        end

        def match_exclude_filter(metric, instance)
            return nil unless @exclude_filter
            re = Regexp.new(@exclude_filter)
            re =~ "#{metric}.#{instance}"
        end

        def print_csv_header
            debug_print(DEBUG_PARSE, "=== csv header ===\n")
            print "time, "
            ncolumn = 0
            debug_print(DEBUG_CSV, "[label] number of metrics: #{data.keys.length}\n")
#            labels.keys.sort.each do |metric|
            data.keys.sort.each do |metric|
                debug_print(DEBUG_CSV, "[label] number of instances: #{data[metric].keys.length}\n")
                debug_print(DEBUG_CSV, "[label] #{data[metric].keys.sort.inspect}\n")
                ncolumn = ncolumn + data[metric].keys.length
                sort_instances(metric).each do |instance|
                    next if match_exclude_filter(metric, instance)
                    labels[metric].each do |column|
                        if instance == "none"
                            label = "#{metric}:#{column}"
                        else
                            label = "#{metric}.#{instance}:#{column}"
                        end
                        print "#{label}, "
                    end
                end
            end
            debug_print(DEBUG_CSV, "[label] number of columns: #{ncolumn}\n")
            print "\n"
        end

        def print_csv_data
            debug_print(DEBUG_PARSE, "=== csv data ===\n")
            get_times.each do |time|
                next if time == "Average:"
                print "#{time}, "
                ncolumn = 0
                debug_print(DEBUG_CSV, "[data] number of metrics: #{data.keys.length}\n")
                data.keys.sort.each do |metric|
                    debug_print(DEBUG_CSV, "[data] number of instances: #{data[metric].keys.length}\n")
                    debug_print(DEBUG_CSV, "[data] #{data[metric].keys.inspect}\n")
                    ncolumn = ncolumn + data[metric].keys.length
                    sort_instances(metric).each do |instance|
                        timedata = data[metric][instance]
                        next if match_exclude_filter(metric, instance)
                        if timedata[time]
                            print timedata[time].join(", ")
                        else
                            # if devices appear/disappear during sar mesurement, fill with blank columns.
                            # e.g. disk2 dissappears at 07:39:33 and appears again at 07:39:34
                            #    07:39:32   device    r+w/s    blks/s
                            #    07:39:32   disk0        2         16
                            #    07:39:32   disk1        0          0
                            #    07:39:32   disk2        0          0
                            #    
                            #    07:39:33   device    r+w/s    blks/s
                            #    07:39:33   disk0        1          8
                            #    07:39:33   disk1        0          0
                            #    
                            #    07:39:34   device    r+w/s    blks/s
                            #    07:39:34   disk0        0          0
                            #    07:39:34   disk1        0          0
                            #    07:39:34   disk2        0          0
                            # then converted csv lines are like these
                            #    time, disk.disk0:r+w/s, disk.disk0:blks/s, disk.disk1:r+w/s, disk.disk1:blks/s, disk.disk2:r+w/s, disk.disk2:blks/s,
                            #    07:39:32, 2, 16, 0, 0, 0, 0,
                            #    07:39:33, 1, 8, 0, 0, , ,
                            #    07:39:34, 0, 0, 0, 0, 0, 0,
                            print labels[metric].map{}.join(", ")
                        end
                        print ", "
                    end
                end
                debug_print(DEBUG_CSV, "[data] number of columns: #{ncolumn}\n")
                print "\n"
            end
        end
    end

    class SarFactory
        def SarFactory.create(os)
            obj = nil
            case os.downcase
            when 'linux'
                obj = LinuxSar.new
            when /macosx|darwin/
                obj = MacOSXSar.new
            when /sunos/
                obj = SunOSSar.new
            else
                raise "Unknown OS: #{os}\n"
            end
            return obj
        end
    end

    class LinuxSar < Sar
        def initialize
            super(
                # Statistics covered with '-A' option:
                SarMetric.new(
                    'proc/s',
                    'proc',
                    '(-c) process creation activity',
                    0
                ),
                SarMetric.new(
                    'cswch/s',
                    'cswch',
                    '(-w) system switching activity',
                    0
                ),
                SarMetric.new(
                    'CPU\s+%user',
                    'cpu',
                    '(-u) CPU utilization',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'CPU\s+i0',
                    'intr_cpu',
                    '(-I SUM -P ALL) statistics for a given interrupt',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'INTR',
                    'intr_xall',
                    '(-I SUM|XALL) statistics for a given interrupt',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'pswpin/s',
                    'swap',
                    '(-W) swapping statistics',
                    0
                ),
                SarMetric.new(
                    'tps',
                    'tps',
                    '(-b) I/O and transfer rate statistics',
                    0
                ),
                SarMetric.new(
                    'frmpg/s',
                    'memory',
                    '(-R) memory statistics',
                    0
                ),
                SarMetric.new(
                    'IFACE\s+rxpck/s',
                    'net_dev',
                    '(-n DEV) network statistics',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'IFACE\s+rxerr/s',
                    'net_edev',
                    '(-n EDEV) network statistics',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'call/s',
                    'net_nfs',
                    '(-n NFS) network statistics',
                    0
                ),
                SarMetric.new(
                    'scall/s',
                    'net_nfsd',
                    '(-n NFSD) network statistics',
                    0
                ),
                SarMetric.new(
                    'totsck',
                    'net_sock',
                    '(-n SOCK) network statistics',
                    0
                ),
                SarMetric.new(
                    'pgpgin',
                    'paging',
                    '(-B) paging statistics',
                    0
                ),
                SarMetric.new(
                    'kbmemfree',
                    'memswap',
                    '(-r) memory and swap space utilization statistics',
                    0
                ),
                SarMetric.new(
                    'dentunusd',
                    'inode',
                    '(-v) status of inode, file and other kernel tables',
                    0
                ),
                SarMetric.new(
                    'runq-sz',
                    'runq',
                    '(-q) queue length and load averages',
                    0
                ),
                # Statistics not covered with '-A' option:
                # command: LANG=C sar -A -x ALL -X ALL -y -d 5 50 -o sample_extra2.sar
                SarMetric.new(
                    'DEV',
                    'blkdev',
                    '(-d) activity  for each block device',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'PID',
                    'pid',
                    '(-x pid|SELF|ALL) statistics for a given process',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'PPID',
                    'ppid',
                    '(-X pid|SELF|ALL) statistics for the child processes of the process',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'TTY',
                    'tty',
                    '(-y) TTY device activity',
                    0,
                    'have_instance'
                )
            )
        end
    end

    class MacOSXSar < Sar
        def initialize
## ignore "New Disk" lines and some "Average" lines
# New Disk: [disk0] IODeviceTree:/PCI0@0/SATA@B/PRT0@0/PMP@0/@0:0   # <== ignore this line
# New Disk: [disk1] IOService:/IOResources/IOHDIXController/IOHDIXHDDriveOutKernel@0/IODiskImageBlockStorageDeviceOutKernel/IOBlockStorageDriver/Apple スパースバンドル・ディスクイメージ Media   # <== ignore this line
#
# (snip)
#
# Average:   device    r+w/s    blks/s
#            disk0    IODeviceTree:/PCI0@0/SATA@B/PRT0@0/PMP@0/@0:0
# Average:   disk0         2        41
#            disk1    IOService:/IOResources/IOHDIXController/IOHDIXHDDriveOutKernel@0/IODiskImageBlockStorageDeviceOutKernel/IOBlockStorageDriver/Apple スパースバンドル・ディスクイメージ Media   # <== ignore this line
# Average:   disk1         0         0
#            disk4    IOService:/IOResources/IOHDIXController/IOHDIXHDDriveOutKernel@7c/IODiskImageBlockStorageDeviceOutKernel/IOBlockStorageDriver/Apple スパースバンドル・ディスクイメージ Media   # <== ignore this line
# Average:   disk4        89      1339
            @ignore_regexp = /(^New Disk:|disk\d+\s+IO(Device|Service))/
            super(
                SarMetric.new(
                    '%usr',
                    'cpu',
                    'XXX',
                    0
                ),
                SarMetric.new(
                    'pgout/s',
                    'pageout',
                    'XXX',
                    0
                ),
                SarMetric.new(
                    'pgin/s',
                    'pagein',
                    'XXX',
                    0
                ),
                SarMetric.new(
                    'device',
                    'disk',
                    'XXX',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'IFACE\s+Ipkts/s',
                    'net_dev',
                    'XXX',
                    0,
                    'have_instance'
                ),
                SarMetric.new(
                    'IFACE\s+Ierrs/s',
                    'net_edev',
                    'XXX',
                    0,
                    'have_instance'
                )
            )
        end
    end

#    class SunOSSar < Sar
#        def initialize
#            super()
#        end
#    end
end
