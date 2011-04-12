#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

module Sysstat
    DEBUG_NONE  = 0x0
    DEBUG_PARSE = 0x1
    DEBUG_CSV   = 0x2
    DEBUG_ALL   = 0xFF
    @debug_level = DEBUG_NONE

    def Sysstat.debug(*arg)
        if arg
            @debug_level = arg.shift
        end
        return @debug_level
    end

    def Sysstat.debug_print(level, message)
        if (@debug_level & level) != 0
            STDERR.print "<#{level}>", message
        end
    end

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
        attr_writer :exclude_filter
        attr_reader :data, :metrics, :labels, :kernel_version, :hostname, :date_str
        def initialize(*metrics)
            @exclude_filter = nil
            @data = Hash.new
            @metrics = Hash.new
            metrics.each { |m|
                @metrics[m.name] = m
            }
            @labels = Hash.new
        end

        def metric(name)
            return @metrics[name]
        end

        def match(line)
            @metrics.values.each {|metric|
                if metric.match(line)
                    return metric.parse(line)
                end
            }
            return nil
        end

        def parse(path)
            file = File.open(path)
            nline = 0
            current_metric = nil
            file.each { |line|
                line.chomp!
                next if /^$/ =~ line
                next if /^Average:/ =~ line
                next if @ignore_regexp and @@ignore_regexp =~ line
                Sysstat.debug_print DEBUG_PARSE, "#{nline}:\t#{line}\n";
                if /^Linux\s+(\S+)\s+\((\S+)\)\s+(.*)/ =~ line
                    @kernel_version = $1
                    @hostname = $2
                    @date_str = $3
                else
                    if sd = match(line)
#                        print "\t=== block (#{sd.name}) start ===\n"
                        @data[sd.name] = Hash.new unless @data[sd.name]
                        current_metric = sd.name
                        @labels[sd.name] = sd.data
                    else
                        sd = metric(current_metric).parse(line)
#                        print "### instance: #{instance}\n"
                        @data[current_metric][sd.instance] = Hash.new unless @data[current_metric][sd.instance]
                        @data[current_metric][sd.instance][sd.time] = sd.data
                    end
                end
                nline = nline + 1
            }
        end

        def sort_instances(metric)
            instances = data[metric].keys
            index_of_all = instances.index("all")
            index_of_sum = instances.index("sum")
            index_of_none = instances.index("none")
            instances.delete_at(index_of_all) if index_of_all
            instances.delete_at(index_of_sum) if index_of_sum
            instances.delete_at(index_of_none) if index_of_none
            instances.sort!{|a,b| a.to_i <=> b.to_i}
            instances.unshift("all") if index_of_all
            instances.unshift("sum") if index_of_sum
            instances.unshift("none") if index_of_none
            return instances
        end

        def get_times
#            print "=== times ===\n";
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
            data.keys.sort.each { |metric|
                print "<#{metric}>\n"
                sort_instances(metric).each { |instance|
                    print "  <#{instance}>\n"
                    print "    <HH:MM:SS>\t#{labels[metric].inspect}\n"
                    timedata = data[metric][instance]
                    timedata.keys.sort.each { |time|
                        print "    <#{time}>\t#{timedata[time].inspect}\n"
                    }
                }
            }
        end

        def match_exclude_filter(metric, instance)
            return nil unless @exclude_filter
            re = Regexp.new(@exclude_filter)
            re =~ "#{metric}.#{instance}"
        end

        def print_csv_header
#            print "=== csv header ===\n";
            print "time, "
#            labels.keys.sort.each { |metric|
            data.keys.sort.each { |metric|
                sort_instances(metric).each { |instance|
                    next if match_exclude_filter(metric, instance)
                    labels[metric].each { |column|
                        if instance == "none"
                            label = "#{metric}:#{column}"
                        else
                            label = "#{metric}.#{instance}:#{column}"
                        end
                        print "#{label}, "
                    }
                }
            }
            print "\n"
        end

        def print_csv_data
#            print "=== csv data ===\n";
            get_times.each { |time|
                next if time == "Average:"
                print "#{time}, "
                data.keys.sort.each { |metric|
                    sort_instances(metric).each { |instance|
                        next if match_exclude_filter(metric, instance)
                        timedata = data[metric][instance]
                        begin
                            print timedata[time].join(", ")
                        rescue
                            Sysstat.debug_print(DEBUG_CSV, "### time=#{time}, metric=#{metric}, instance=#{instance} ###\n")
                        end
                        print ", "
                    }
                }
                print "\n"
            }
        end
    end

    class LinuxSar < Sar
        def initialize
            super(
                # Statistics covered with '-A' option:
                Sysstat::SarMetric.new(
                    'proc/s',
                    'proc',
                    '(-c) process creation activity',
                    0
                ),
                Sysstat::SarMetric.new(
                    'cswch/s',
                    'cswch',
                    '(-w) system switching activity',
                    0
                ),
                Sysstat::SarMetric.new(
                    'CPU     %user',
                    'cpu',
                    '(-u) CPU utilization',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'CPU  i0',
                    'intr_cpu',
                    '(-I SUM -P ALL) statistics for a given interrupt',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'INTR',
                    'intr_xall',
                    '(-I SUM|XALL) statistics for a given interrupt',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'pswpin/s',
                    'swap',
                    '(-W) swapping statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'tps',
                    'tps',
                    '(-b) I/O and transfer rate statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'frmpg/s',
                    'memory',
                    '(-R) memory statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'IFACE   rxpck/s',
                    'net_dev',
                    '(-n DEV) network statistics',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'IFACE   rxerr/s',
                    'net_edev',
                    '(-n EDEV) network statistics',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'call/s',
                    'net_nfs',
                    '(-n NFS) network statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'scall/s',
                    'net_nfsd',
                    '(-n NFSD) network statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'totsck',
                    'net_sock',
                    '(-n SOCK) network statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'pgpgin',
                    'paging',
                    '(-B) paging statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'kbmemfree',
                    'memswap',
                    '(-r) memory and swap space utilization statistics',
                    0
                ),
                Sysstat::SarMetric.new(
                    'dentunusd',
                    'inode',
                    '(-v) status of inode, file and other kernel tables',
                    0
                ),
                Sysstat::SarMetric.new(
                    'runq-sz',
                    'runq',
                    '(-q) queue length and load averages',
                    0
                ),
                # Statistics not covered with '-A' option:
                # command: LANG=C sar -A -x ALL -X ALL -y -d 5 50 -o sample_extra2.sar
                Sysstat::SarMetric.new(
                    'DEV',
                    'blkdev',
                    '(-d) activity  for each block device',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'PID',
                    'pid',
                    '(-x pid|SELF|ALL) statistics for a given process',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'PPID',
                    'ppid',
                    '(-X pid|SELF|ALL) statistics for the child processes of the process',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
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
        @ignore_regexp = /^New Disk:/
        def initialize
            super(
                Sysstat::SarMetric.new(
                    '%usr',
                    'cpu',
                    'XXX',
                    0
                ),
                Sysstat::SarMetric.new(
                    'pgout/s',
                    'pageout',
                    'XXX',
                    0
                ),
                Sysstat::SarMetric.new(
                    'pgin/s',
                    'pagein',
                    'XXX',
                    0
                ),
                Sysstat::SarMetric.new(
                    'device',
                    'disk',
                    'XXX',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'IFACE    Ipkts/s',
                    'net_dev',
                    'XXX',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'IFACE    Ierrs/s',
                    'net_edev',
                    'XXX',
                    0,
                    'have_instance'
                )
            )
        end
    end
end
