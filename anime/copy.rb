require 'fileutils'
require 'tty-cursor'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'
require 'set'
require 'io/console'

ActiveSupport::Deprecation.silenced = true
Thread.abort_on_exception = true

CURSOR = TTY::Cursor
PATH = '/anime'
DEST = '/mnt/d'
PRIMARY_SRC = '/mnt/e'
SECONDARY_SRC = '/mnt/g'
DEFRAG_COMMAND = '"/mnt/c/Program Files (x86)/Auslogics/Disk Defrag/cdefrag.exe" -o -f ' + DEST[-1].upcase + ':'
OPTS = {encoding: 'UTF-8'}

$quit = false

puts 'press ESC and then enter to stop'
Thread.new do
  Thread.current.priority = -1
  while true
    char = STDIN.read(1)
    break if char.ord == 27
  end
  $quit = true
  print "\nwill stop on next iteration. Press Control C to immediately quit\n"
end

def size(numb)
  ActiveSupport::NumberHelper.number_to_human_size(numb, {precision: 4, strip_insignificant_zeros: false})
end

def directory_size(path, string=true)
  # path << '/' unless path.end_with?('/')

  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, **OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'desktop.ini'
    f = "#{path}/#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f, false if File.directory? f
  end
  string ? size(total_size) : total_size
end

def main
  @start_time = Time.now
  @start_dest_size = directory_size DEST + PATH, false
  @total_src_size = directory_size SECONDARY_SRC + PATH, false
  iterate(PATH + '/zWatched')
  iterate(PATH)
end

def iterate(path)
  shows = Dir.entries SECONDARY_SRC + path, **OPTS
  count = 0

  shows.each do |show|
    break if $quit
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    next if show == 'Boku no Hero Academia' || show.include?('(In Progress)')
    # count += 1 and next if count < 4
    next if already_copied show, path
    copy_show show, path
    count += 1
    # break if count > 5
  end
end

def copy_show(show, path)
  print "start  copying #{show.cyan} at #{time}\r\n"
  src = File.directory?("#{PRIMARY_SRC}#{path}/#{show}") ? PRIMARY_SRC : SECONDARY_SRC
  original_verbosity = $VERBOSE
  $VERBOSE = nil

  # puts "rsync -rWh --no-compress --inplace --info=progress2 \"#{SRC}#{path}/#{show}\" \"#{DEST}#{path}\""
  system "rsync -rWh --no-compress --copy-links --inplace --info=progress2 \"#{src}#{path}/#{show}\" \"#{DEST}#{path}\"", out: STDOUT
  $VERBOSE = original_verbosity

  puts "finish copying #{show.cyan} at #{time}"
  optimize show
end

def already_copied(show, path)
  File.directory? "#{DEST}#{path}/#{show}"
end

def time
  Time.now.strftime("%l:%M:%S %P").green
end

def optimize(show)
  puts "start  optimizing #{show.cyan} at #{time}"
  original_verbosity = $VERBOSE
  $VERBOSE = nil
  IO.popen "#{DEFRAG_COMMAND}" do |io|
    while (line = io.gets)
    #   # line.gsub! /[\b]+/, "\r" if line.start_with?("\b")
    #   line.gsub!(/[^0-9A-Za-z ]/, '') if line.start_with?("\b")
    #   puts line
    end
  end
  $VERBOSE = original_verbosity
  # print CURSOR.clear_lines(6, :up)
  eta, size_left, speed = calc_eta
  puts "finish optimizing #{show.cyan} at #{time}. ETA: #{eta} size left: #{size_left}, speed: #{speed} Mbps"
end

def calc_eta
  dest_size = directory_size DEST + PATH, false
  size_done = dest_size - @start_dest_size
  size_done = 1 if size_done == 0
  size_left = @total_src_size - dest_size

  duration = (Time.now - @start_time).to_f
  speed = size_done / duration
  time_left = size_left / speed
  # puts "size_done #{size_done}, duration: #{duration}, size_left: #{size_left}, speed: #{speed}, time_left #{time_left}"#, eta: #{eta.strftime("%l:%M:%S %P")}"
  eta = Time.now + time_left
  mbps = speed * 8 / 1024 / 1024
  return eta.strftime("%l:%M:%S %P").green, size(size_left).cyan, mbps.to_s.cyan
end

# puts directory_size "#{DEST}\\ERASED"
main
print "\a"
# puts String.colors
# optimize 'DanMachi'
# puts String.methods
