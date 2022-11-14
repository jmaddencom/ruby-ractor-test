#!/usr/bin/env ruby

# Finds the newest file in the given path

require "find"
require "etc"

set = Find.find(ARGV[0]).to_a # FIXME: single-threaded lstat of the whole tree here so there's a cache built up, minimizes the effect of parallelism
ractors = []
values = []

nprocs = Etc.nprocessors
#nprocs = 1
nprocs.times do |i|
  ractors << Ractor.new(i) do |p|
    newest_file = ""
    newest_mtime = 0
    my_work = receive
    my_work.each do |f|
      begin
        stat = File.stat(f)
        next unless stat.file?
        mtime = stat.mtime.to_i
        if mtime > newest_mtime
          newest_mtime = mtime
          newest_file = f
        end
      rescue SystemCallError # catches Errno::*
      end
    end
    [newest_file, newest_mtime]
  end
end

work_pools = set.each_slice((set.size/nprocs.to_f).round).to_a
ractors.each_with_index do |r, i|
  r.send(work_pools[i])
end

values = ractors.map(&:take)
newest = values.sort_by{|a| a.last}.last
puts "File #{newest[0]} is the newest with timestamp #{Time.at(newest[1])}"
