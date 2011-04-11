#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

module Sysstat
    class SarData
        attr_reader :name, :time, :instance, :data
        def initialize(name, time, instance, data)
            @name = name
            @time = time
            if instance
                @instance = instance
            else
                @instance = "all"
            end
            @data = data
        end
    end

    class SarMetric
        attr_reader :name
        @@time_regexp = "\\d{2}:\\d{2}:\\d{2}|Average:"
        def initialize(label_regexp, name, skip, *flag)
            @label_regexp = label_regexp
            @name = name
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
        attr_reader :data, :metrics, :labels, :kernel_version, :hostname, :date_str
        def initialize(*metrics)
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
            @metrics.values.each {|item|
                print "#{item.name}: "
                if item.match(line)
                    print "o\n"
                    ret = item.parse(line)
                    return ret
                end
                print "x\n"
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
#                print "#{nline}:\t#{line}\n";
                if /^Linux\s+(\S+)\s+\((\S+)\)\s+(.*)/ =~ line
                    @kernel_version = $1
                    @hostname = $2
                    @date_str = $3
                else
                    if sd = self.match(line)
#                        print "\t=== block (#{sd.name}) start ===\n"
                        @data[sd.name] = Hash.new
                        current_metric = sd.name
                        @labels[sd.name] = sd.data
                    else
                        sd = self.metric(current_metric).parse(line)
#                        print "### instance: #{instance}\n"
                        @data[current_metric][sd.instance] = Hash.new unless @data[current_metric][sd.instance]
                        @data[current_metric][sd.instance][sd.time] = sd.data
                    end
                end
                nline = nline + 1
            }
        end

        def dump
            print "=== dump ===\n";
            print "kernel_version=", @kernel_version, "\n"
            print "hostname=", @hostname, "\n"
            print "date_str=", @date_str, "\n"
            print "\n"

            self.data.keys.sort.each { |metric|
                print "<#{metric}>\n"
                instances = data[metric].keys
                index_of_all = instances.index("all")
                instances.delete_at(index_of_all) if index_of_all
                instances.sort!{|a,b| a.to_i <=> b.to_i}
                instances.unshift("all") if index_of_all
                instances.each { |instance|
                    print "  <#{instance}>\n"
                    timedata = data[metric][instance]
                    timedata.keys.sort.each { |time|
                        print "    <#{time}>"
                        print "    ", timedata[time].inspect, "\n"
                    }
                }
            }
        end

        def print_csv_header
            print "=== csv header ===\n";
            self.labels.keys.sort.each { |metric|
                self.labels[metric].each { |column|
                    print "#{metric}:#{column}, "
                }
            }
            print "\n"
        end
    end

    class LinuxSar < Sar
        def initialize
            super(
                Sysstat::SarMetric.new(
                    'proc/s',
                    'proc_s',
                    0
                ),
                Sysstat::SarMetric.new(
                    'cswch/s',
                    'cswch_s',
                    0
                ),
                Sysstat::SarMetric.new(
                    'CPU     %user',
                    'cpu_prct',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'CPU  i0',
                    'cpu_intr',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'INTR',
                    'intr_s',
                    1
                ),
                Sysstat::SarMetric.new(
                    'pswpin/s',
                    'pswp_s',
                    0
                ),
                Sysstat::SarMetric.new(
                    'tps',
                    'tps',
                    0
                ),
                Sysstat::SarMetric.new(
                    'frmpg/s',
                    'frmpg_s',
                    0
                ),
                Sysstat::SarMetric.new(
                    'IFACE   rxpck/s',
                    'iface',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'IFACE   rxerr/s',
                    'iface_err',
                    0,
                    'have_instance'
                ),
                Sysstat::SarMetric.new(
                    'call/s',
                    'rpc',
                    0
                ),
                Sysstat::SarMetric.new(
                    'scall/s',
                    'rpc2',
                    0
                ),
                Sysstat::SarMetric.new(
                    'pgpgin',
                    'paging',
                    0
                ),
                Sysstat::SarMetric.new(
                    'kbmemfree',
                    'memory',
                    0
                ),
                Sysstat::SarMetric.new(
                    'dentunusd',
                    'inode',
                    0
                ),
                Sysstat::SarMetric.new(
                    'totsck',
                    'socket',
                    0
                ),
                Sysstat::SarMetric.new(
                    'runq-sz',
                    'runq',
                    0
                )
            )
        end
    end
end
