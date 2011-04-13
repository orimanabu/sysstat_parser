#!/usr/bin/ruby
# vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sysstat'

module Sysstat
    class Vmstat
        attr_writer :exclude_filter
        attr_reader :data, :metrics, :labels, :kernel_version, :hostname, :date_str
        def initialize
            @data = Hash.new
            @metrics = Hash.new
            @header2label = {
                'r' => 'procs.r',
                'b' => 'procs.b',
                'swpd' => 'memory.swpd',
                'free' => 'memory.free',
                'buff' => 'memory.buff',
                'cache' => 'memory.cache',
                'si' => 'swap.si',
                'so' => 'swap.so',
                'bi' => 'io.bi',
                'bo' => 'io.bo',
                'in' => 'system.in',
                'cs' => 'system.cs',
                'us' => 'cpu.us',
                'sy' => 'cpu.sy',
                'id' => 'cpu.id',
                'wa' => 'cpu.wa',
                'st' => 'cpu.st'
            }
            @labels = Array.new
            @labels_initialized = false
        end

        def init_labels(line)
            Sysstat.debug_print(DEBUG_ALL, "### init_labels: <#{line}>\n")
            line.gsub!(/^\s*/, "")
            array = line.split(/\s+/)
            p array
            array.each { |x|
                @labels.push(@header2label[x])
            }
            p @labels
            @labels_initialized = true
        end

        def parse(path)
            Sysstat.debug_print(DEBUG_ALL, "### parse ###\n")
            file = File.open(path)
            nline = 0
            nlinedata = 0
            current_metric = nil
            file.each { |line|
                line.chomp!
                next if /^$/ =~ line
                next if /^procs / =~ line
                if /\s*r\s+b\s+/ =~ line
                    if !@labels_initialized
                        init_labels(line)
                    end
                    next
                end
                print "#{nline}:\t#{line}\n";

## RHEL4
# procs -----------memory---------- ---swap-- -----io---- --system-- ----cpu----
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in    cs us sy id wa
#  0  0    160  18628   4832 1948548    0    0     0     2    3     2  4  0 95  0
#  0  0    160  18500   4872 1948508    0    0     0   224 1051   138  0  1 89  9
#  0  0    160  18500   4872 1948508    0    0     0     0 1019    63  0  0 100  0

## RHEL5
# procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
#  0  0      0 6281084 238444 1335860    0    0     1    21   67   45  3  0 96  1  0
#  0  0      0 6281084 238444 1335860    0    0     0     0 1021  102  0  0 100  0  0
#  0  1      0 6281084 238444 1335860    0    0     0    60  989  135  0  0 98  2  0

## RHEL6 with -t
# procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------ ---timestamp---
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
#  1  0      0 128901752 113436 504332    0    0     0     0    0    0  0  0 100  0  0    2011-04-11 22:15:11 JST
#  1  0      0 128901616 113436 504332    0    0     0     0  241  429  0  0 100  0  0    2011-04-11 22:15:12 JST

                line.gsub!(/^\s*/, "")
                linedata = line.split(/\s+/)
                Sysstat.debug_print(DEBUG_PARSE, "### labels.length = #{labels.length}, linedata.length = #{linedata.length}\n")
                key = ""
                if linedata.length == labels.length
                    key = nlinedata
                elsif linedata.length == labels.length + 3
#                    date, time, tz = linedata[-3 .. -1]
                    tz = linedata.pop
                    time = linedata.pop
                    date = linedata.pop
                    Sysstat.debug_print(DEBUG_PARSE, "### timestamp: #{date}_#{time}_#{tz}\n")
#                    key = "#{date} #{time}"
                    key = "#{time}"
                end
                p linedata

                data[key] = linedata

                nline = nline + 1
                nlinedata = nlinedata + 1
            }
        end

        def dump
            Sysstat.debug_print(DEBUG_ALL, "### dump ###\n")
            data.keys.sort.each { |key|
                print "#{key} - #{data[key].inspect}\n"
            }
        end
    end
end
