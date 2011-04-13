#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sysstat'

module Sysstat
    class Iostat
        attr_writer :exclude_filter
        attr_reader :data, :labels, :devs
        def initialize(arg)
            @exclude_filter = nil
            @ignore_regexp = arg['ignore_regexp']
            @header_regexp = arg['header_regexp']
            @time_regexp = arg['time_regexp']
            @data = Hash.new
            @labels = Array.new
            @labels_initialized = false
            @devs = Hash.new
        end

        def init_labels(line)
            Sysstat.debug_print(DEBUG_ALL, "### init_labels ###\n")
            line.gsub!(/^\s*/, "")
            array = line.split(/\s+/)
            array.shift
            array.each { |x|
                labels.push(x)
            }
            @labels_initialized = true
        end

        def parse(path)
            Sysstat.debug_print(DEBUG_ALL, "### parse ###\n")
            file = File.open(path)
            nline = 0
            nentry = nil
            current_entry = nil
            time = nil
            file.each { |line|
                line.chomp!
                Sysstat.debug_print(DEBUG_PARSE, "#{nline}:\t#{line}\n")
                next if /^$/ =~ line
                next if @ignore_regexp =~ line
                if @header_regexp =~ line
                    nentry = 0 if nentry == nil
                    current_entry = nentry
                    nentry = nentry + 1
                    if !@labels_initialized
                        init_labels(line)
                    end
                    Sysstat.debug_print(DEBUG_PARSE, "header: current_entry=#{current_entry}, nentry=#{nentry}\n")
                elsif @time_regexp =~ line
                    time = Regexp.last_match(1)
                elsif @header_regexp =~ line
                    Sysstat.debug_print(DEBUG_PARSE, "header:\n")
                    if !@labels_initialized
                        init_labels(line)
                    end
                    next
                else
                    line.gsub!(/^\s*/, "")
                    array = line.split(/\s+/)
                    dev = array.shift
                    devs[dev] = 1 unless devs[dev]
                    key = time ? time : current_entry
                    data[key] = Hash.new unless data[key]
                    Sysstat.debug_print(DEBUG_PARSE, "rest: [#{key}][#{dev}], rest=#{array.inspect}\n")
                    data[key][dev] = array
                end
                nline = nline + 1
            }
        end

        def dump
            Sysstat.debug_print(DEBUG_ALL, "### dump ###\n")
            print "### labels:\n"
            print labels.inspect, "\n"
            print "### data:\n"
            data.keys.sort.each { |key|
                data[key].keys.sort.each { |dev|
                    print "#{key} - #{dev} - #{data[key][dev].inspect}\n"
                }
            }
        end

        def print_csv
            Sysstat.debug_print(DEBUG_ALL, "### print_csv ###\n")
            # labels
            print ", "
            devs.keys.sort.each { |dev|
                re = Regexp.new(@exclude_filter)
                next if re =~ dev
                print labels.map{|x| "#{dev}.#{x}"}.join(", ")
                print ", "
            }
            print "\n"
            # data
            data.keys.sort.each { |key|
                print "#{key}, "
                devs.keys.sort.each { |dev|
                    re = Regexp.new(@exclude_filter)
                    next if re =~ dev
                    array = data[key][dev]
                    print array.join(", ")
                    print ", "
                }
                print "\n"
            }
        end
    end

    class LinuxIostat < Iostat
        def initialize
            super({
                'ignore_regexp' => /^(avg-cpu|\s+\d|Linux )/,
                'header_regexp' => /^Device:/,
                'time_regexp' => /^Time: (.*)$/,
            })
        end
    end

#    class MacOSXIostat < Iostat
#        def initialize
#            super({
#                'ignore_regexp' => /^Mach Virtual Memory Statistics:/,
#                'header_regexp' => /\s*free active   spec inactive/
#            })
#        end
#    end
end
