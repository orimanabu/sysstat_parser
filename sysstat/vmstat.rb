#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'sysstat/sysstat'
module Sysstat
    class Vmstat
        include Sysstat
        attr_reader :data, :labels
        def initialize(arg)
            @ignore_regexp = arg['ignore_regexp']
            @header_regexp = arg['header_regexp']
            @data = Hash.new
            @labels = Array.new
            @labels_initialized = false
        end

        def init_labels(line)
            debug_print(DEBUG_ALL, "### init_labels ###\n")
            line.gsub!(/^\s*/, "")
            array = line.split(/\s+/)
            array.each do |x|
                labels.push(x)
            end
            @labels_initialized = true
        end

        def parse(path)
            debug_print(DEBUG_ALL, "### parse ###\n")
            file = File.open(path)
            nline = 0
            current_metric = nil
            file.each do |line|
                line.chomp!
                next if /^$/ =~ line
                next if @ignore_regexp =~ line
                if @header_regexp =~ line
                    if !@labels_initialized
                        init_labels(line)
                    end
                    next
                end
                debug_print(DEBUG_PARSE, "#{nline}:\t#{line}\n")
                line.gsub!(/^\s*/, "")
                data[nline] = line.split(/\s+/)
                nline = nline + 1
            end
        end

        def dump
            debug_print(DEBUG_ALL, "### dump ###\n")
            data.keys.sort.each do |key|
                print "#{key} - #{data[key].inspect}\n"
            end
        end

        def print_csv
            debug_print(DEBUG_ALL, "### print_csv ###\n")
            print ", "
            print labels.join(", ")
            print "\n"
            data.keys.sort.each do |key|
                print "#{key}, "
                print data[key].join(", ")
                print "\n"
            end
        end
    end

    class VmstatFactory
        def VmstatFactory.create(os)
            obj = nil
            case os.downcase
            when 'linux'
                obj = LinuxVmstat.new
            when /macosx|darwin/
                obj = MacOSXVmstat.new
            when /sunos/
                obj = SunOSVmstat.new
            else
                raise "Unknown OS: #{os}\n"
            end
            return obj
        end
    end

    class LinuxVmstat < Vmstat
        def initialize
            super({
                'ignore_regexp' => /^procs /,
                'header_regexp' => /\s*r\s+b\s+/
            })
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
        end

        def init_labels(line)
            debug_print(DEBUG_ALL, "### init_labels ###\n")
            line.gsub!(/^\s*/, "")
            array = line.split(/\s+/)
            array.each do |x|
                labels.push(@header2label[x])
            end
            @labels_initialized = true
        end
    end

    class MacOSXVmstat < Vmstat
        def initialize
            super({
                'ignore_regexp' => /^Mach Virtual Memory Statistics:/,
                'header_regexp' => /\s*free active   spec inactive/
            })
        end
    end

#    class SunOSVmstat < Vmstat
#        def initialize
#            super()
#        end
#    end
end

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

