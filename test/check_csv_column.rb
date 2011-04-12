#!/usr/bin/ruby

require 'csv'
while line = gets
#    CSV.parse(line)
    array = line.chomp.split(/, */)
    p array.length
end
