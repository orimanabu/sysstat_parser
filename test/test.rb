#!/usr/bin/ruby
# -*- coding: utf-8; ruby-indent-level: 4 -*- vi: set ts=4 sw=4 et sts=4:

require 'test/unit'
require 'sysstat/sar'

class SarMetricTest < Test::Unit::TestCase
    def setup
#         puts '==> test start'
        @obj = Sysstat::SarMetric.new(
               	'proc/s',
                'proc',
                '(-c) process creation activity',
                0
               )
        @input = Hash.new
        @input[:rhel5] = %q{
17:00:59       proc/s
17:01:09        11.89
17:01:19         0.00
17:01:29         0.00
17:01:39         0.00
17:01:49         0.00
17:01:59         3.10
}
    end

    def teardown
#         puts '==> test end'
    end

    def test_name
        puts "test_name"
        assert_equal('proc', @obj.name)
    end

    def test_data
        puts "test_data"
        @input[:rhel5].each_line do |line|
            puts line
        end
#         print @input[:rhel5], "\n"
    end
end

