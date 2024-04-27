require 'fileutils'
require 'shellwords'
require 'pathname'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

PATH = ""
FFMPEG = ""
NEW_FOLDER = "new"

# TODO make a wrapper that can only be run once (Maybe just call with cli arg)
# and call from JDownloader
#   should create a new terminal window, cd to this folder, call this program with a cli arg
#   jdownloader should write paths to go through in a text file in video convert
#   program should read this file and iterate in order (deleting line once done)
#   at end program should read file again and if can do stuff restart, else finish (print)

# TODO figure out how to make writing to file safe
# Maybe just leave it unsafe and sort by File create time (only for jdownloader triggered, cli triggered should still use cannonical sorting)
def main
  start = Time.now
  Dir.glob(PATH + "old/**/*").sort_by{|p| number_sort_by(p.downcase) }.each do |fpath_abs|
    next unless File.file?(fpath_abs)
    fpath = "./" + Pathname.new(fpath_abs).relative_path_from(__dir__).to_s
    ext = File.extname(fpath)
    final_fpath = fpath.sub("old", NEW_FOLDER).sub(ext, ".mkv")
    next if File.exist?(final_fpath)
    # puts "fpath: #{fpath}"
    # new_fpath = final_fpath.gsub(".mp4", ".part.mp4")
    new_fpath = final_fpath.gsub(".mkv", ".part.mkv")
    # puts "new_fpath :#{new_fpath}"
    FileUtils.mkdir_p(File.dirname(new_fpath))

    cmd = "#{FFMPEG.shellescape} -i #{fpath.shellescape} -y -c:v libx265 -crf 24 -preset superfast -vtag hvc1 -c:a copy #{new_fpath.shellescape}"

    # puts "cmd: #{cmd}"
    `#{cmd}`
    if File.size(new_fpath) != 0
      FileUtils.mv(new_fpath, final_fpath)
      dir_path = fpath
      while dir_path.include?("old/")
        # puts "dir_path: #{dir_path}"
        mark_hidden(dir_path)
        dir_path = File.dirname(dir_path)
      end
      puts diff_str(fpath_abs)
    end
  end

  puts "\n***********************\n\n"
  end_time = Time.now

  Dir.glob(PATH + "old/**/*").sort_by { |p| number_sort_by(p.downcase) }.each do |fpath_abs|
    str = diff_str(fpath_abs)
    puts str if str
  end

  puts "took #{to_human_duration(end_time - start)} (#{NEW_FOLDER})"

  print "\a"
end

def diff_str(fpath_abs)
  fpath = Pathname.new(fpath_abs).relative_path_from(PATH + "old").to_s
  final_fpath = fpath_abs.sub("old", NEW_FOLDER).sub(File.extname(fpath_abs), ".mkv")
  return nil unless File.exist?(final_fpath)
  old_size = dir_size(fpath_abs)
  new_size = dir_size(final_fpath)
  perc = (100 * old_size / new_size.to_f - 100).round(3)
  "#{fpath}: #{to_human_size(old_size).light_cyan} -> #{to_human_size(new_size).light_green} (#{perc}%)"
end

def dir_size(path)
  return File.size(path) if File.file?(path)
  Dir[path + "/**/*"].select { |f| File.file?(f) }.select { |f| File.exist?(f.sub("old", NEW_FOLDER).sub(File.extname(f), ".mkv")) }.sum { |f| File.size(f) }
end

def mark_hidden(path)
  hidden_cmd = "cmd.exe /c attrib \"#{path}\""
  # puts "hidden_cmd: #{hidden_cmd}"
  is_hidden = `#{hidden_cmd}`[4] == 'H'
  # puts "#{path} is_hidden: #{is_hidden}"
  if is_hidden
    new_path = path.sub("old", NEW_FOLDER)
    new_path = new_path.sub(File.extname(path), ".mkv") if File.file?(path)
    hide_cmd = "cmd.exe /c attrib +h \"#{new_path}\""
    # puts "hide_cmd: #{hide_cmd}"
    `#{hide_cmd}`
  end
end

def number_sort_by(str)
  str.scan(/\D+|\d+/).map { |part| part.match?(/\d+/) ? part.to_i : part }
end

def to_human_size(size)
  ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5, strip_insignificant_zeros: false})
end

def to_human_duration(time)
  mm, ss = time.divmod(60)
  hh, mm = mm.divmod(60)
  dd, hh = hh.divmod(24)
  str = ""
  str << "#{dd} days, " if dd > 0
  str << "#{hh} hours, " if hh > 0
  str << "#{mm} minutes, " if mm > 0
  str << "#{ss} seconds, " if ss > 0
  str = str[0..-3]
  str.reverse.sub(" ,", " and ".reverse).reverse
end

main
