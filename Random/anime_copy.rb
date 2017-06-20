require 'fileutils'
require 'tty-cursor'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

ActiveSupport::Deprecation.silenced = true

CURSOR = TTY::Cursor
DEFRAG_COMMAND = '"C:\Program Files (x86)\Auslogics\Disk Defrag\cdefrag" -o F:'
PATH = '\anime'
DEST = 'F:' + PATH
SRC = 'D:' + PATH
OPTS = {encoding: 'UTF-8'}

def size(numb)
  ActiveSupport::NumberHelper.number_to_human_size(numb, {precision: 4, strip_insignificant_zeros: false})
end

def directory_size(path, string=true)
  # path << '/' unless path.end_with?('/')

  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  entries = Dir.entries path, OPTS
  entries.each do |f|
    next if f == '.' || f == '..' || f == 'zWatched' || f == 'desktop.ini'
    f = "#{path}\\#{f}"
    total_size += File.size(f) if File.file?(f) && File.size?(f)
    total_size += directory_size f, false if File.directory? f
  end
  string ? size(total_size) : total_size
end

def main
  shows = Dir.entries SRC, OPTS

  count = 0
  @start_time = Time.now
  @start_dest_size = directory_size DEST, false
  @total_src_size = directory_size SRC, false

  shows.each do |show|
    next if show == '.' || show == '..' || show == 'zWatched' || show == 'desktop.ini'
    # next if show == 'Attack On Titan' || show == 'Boku no Hero Academia' || show == 'DanMachi' || show == 'Saekano; How to Raise a Boring Girlfriend' || show.include?('(In Progress)')
    # count += 1 and next if count < 4
    next if already_copied show
    copy_show show
    count += 1
    # break if count > 5
  end
end

def copy_show(show)
  puts "start  copying #{show.cyan} at #{time}"
  thread = print_progress show
  FileUtils.cp_r("#{SRC}/#{show}", "#{DEST}")
  thread.exit
  print CURSOR.clear_line
  puts "finish copying #{show.cyan} at #{time}"
  optimize show
end

def print_progress(show)
  max = directory_size "#{SRC}/#{show}"
  Thread.new do
    while true
      sleep 0.2
      # dest = Filesystem.stat("#{DEST}/#{show}")
      # current = dest.blocks * dest.block_size
      current = directory_size "#{DEST}/#{show}"
      print "\r#{current} / #{size max}"
    end
  end
end

def already_copied(show)
  File.directory? "#{DEST}/#{show}"
end

def time
  Time.now.strftime("%l:%M:%S %P").green
end

def optimize(show)
  puts "start  optimizing #{show.cyan} at #{time}"
  system "#{DEFRAG_COMMAND}", out: STDOUT, err: :out
  print CURSOR.clear_lines(7, :up)
  # 6.times do
  #   print CURSOR.clear_line
  #   print CURSOR.up
  # end
  # print CURSOR.clear_line
  # print "\033[6A\r"
  # STDOUT.flush
  # print "\n\033[K \n\033[K \n\033[K \n\033[K \n\033[K \n\033[K "
  # STDOUT.flush
  # print "\033[6A"
  # STDOUT.flush
  eta, size_left = calc_eta
  puts "finish optimizing #{show.cyan} at #{time}. ETA: #{eta} size left: #{size_left}"
end

def calc_eta
  dest_size = directory_size DEST, false
  size_done = dest_size - @start_dest_size
  size_left = @total_src_size - dest_size

  duration = (Time.now - @start_time).to_f
  speed = size_done / duration
  time_left = size_left / speed
  eta = Time.now + time_left
  # puts "size_done #{size_done}, duration: #{duration}, size_left: #{size_left}, speed: #{speed}, time_left #{time_left}, eta: #{eta.strftime("%l:%M:%S %P")}"
  return eta.strftime("%l:%M:%S %P").green, size(size_left).cyan
end

# puts directory_size "#{DEST}\\ERASED"
main
# puts String.colors
# optimize 'DanMachi'
# puts String.methods
