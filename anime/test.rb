require 'benchmark/ips'
require 'shell'
require 'mkv'

PATH = "/mnt/d/anime/zWatched/Sword Art Online/Season 2/1.mkv"


class MKV::Movie
  def initialize(path)
    unless File.exists?(path)
      raise Errno::ENOENT, "the file '#{path}' does not exist"
    end

    @path = path
  end
end


puts File.exist? PATH
puts 'system'
system("mkvinfo #{PATH} > /dev/null")
puts ''

puts 'shell'
shell = Shell.new
Shell.def_system_command :mkvinfo, shell.transact {find_system_command('mkvinfo')}
p = shell.transact do
  mkvinfo(PATH)
end
# puts p
puts ''
#
puts 'gem'
t = MKV::Movie.new(PATH).tracks.select {|t| t.type == 'audio' && t.language == 'jpn' && !t.name}.first
t.inspect


Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 5, :warmup => 2)

  # These parameters can also be configured this way
  x.time = 5
  x.warmup = 2

  # Typical mode, runs the block as many times as it can
  x.report('system') do |iter|
    iter.times.each do
      system("mkvinfo #{PATH} > /dev/null")
    end
  end

  x.report('shell') do |iter|
    shell = Shell.new
    iter.times do
      shell.transact do
         mkvinfo(PATH)
      end
      # puts p
    end
  end

  # x.report('gem') do |iter|
  #   iter.times.each do
  #     movie = MKV::Movie.new(PATH)
  #     track = movie.tracks.select {|t| t.type == 'audio' && t.language == 'jpn' && !t.name}.first
  #     track.inspect
  #   end
  # end

  # Compare the iterations per second of the various reports!
  x.compare!
end


