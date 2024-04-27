require 'fileutils'
require 'shellwords'
require 'pathname'
require 'colorize'
require 'active_support'
require 'active_support/number_helper'

PATHS = [
]
SUBDIRS = [["/old", "/new"]]
HIDE_MISSING = ARGV.shift != "show_missing"
SHOULD_SKIP = false
# SHOULD_SKIP = true
SKIP_THRESHOLD = 5.0

def main
  total_old, total_new = PATHS.map do |path|
    old, new = SUBDIRS.find { |old, new| File.exist?(path + old) && File.exist?(path + new) }
    [dir_size(File.join(path, old), old, new), dir_size(File.join(path, new), old, new)]
  end.reduce([0, 0]) do |acc, (old, new)|
    new > 0 ? [acc[0] + old, acc[1] + new] : acc
  end

  total_string = diff_str("total", total_old, total_new, true)
  puts total_string

  PATHS.each do |path|
    old, new = SUBDIRS.find { |old, new| File.exist?(path + old) && File.exist?(path + new) }
    old_dir_size = dir_size(File.join(path, old), old, new)
    new_dir_size = dir_size(File.join(path, new), old, new)
    next if HIDE_MISSING && (new_dir_size.nil? || new_dir_size == 0 || old_dir_size.nil? || old_dir_size == 0)
    dir_string = diff_str(path, old_dir_size, new_dir_size, true)
    puts "\n#{dir_string}" if dir_string

    paths = Hash.new { |hsh, k| hsh[k] = [nil, nil, false] }
    [old, new].each.with_index do |section, path_i|
      Dir.glob(path + section + "/**/*").map do |true_path|
        relative_path = Pathname.new(true_path).relative_path_from(path + section).to_s
        is_directory = File.directory?(true_path)
        relative_path = relative_path.sub(File.extname(relative_path), "") unless is_directory
        paths[relative_path][path_i] = true_path
        paths[relative_path][-1] = is_directory
      end
    end

    paths.map do |name, paths|
      [name, *paths]
    end.sort_by do |name, old_path, new_path, is_directory|
      number_sort_by(name.downcase)
    end.each do |name, old_path, new_path, is_directory|
      old_size = dir_size(old_path, old, new)
      new_size = dir_size(new_path, old, new)
      next if HIDE_MISSING && (new_size.nil? || new_size == 0 || old_size.nil? || old_size == 0)
      str = diff_str(name, old_size, new_size, is_directory)
      puts str if str
    end
  end

  puts
  puts total_string
end

def diff_str(path, old_size, new_size, is_directory)
  path_str = is_directory ? (path + "/").light_magenta : path
  old_size_str = "missing".light_red
  new_size_str = "missing".light_red
  old_size_str = to_human_size(old_size).light_cyan if !old_size.nil? && old_size > 0
  new_size_str = "#{to_human_size(new_size)}".light_cyan if !new_size.nil? && new_size > 0

  if !old_size.nil? && old_size > 0 && !new_size.nil? && new_size > 0
    perc = (100 * old_size / new_size.to_f - 100).round(3)
    return nil if SHOULD_SKIP && perc >= SKIP_THRESHOLD
    color = case
            when perc > 0 then :light_green
            when perc < 0 then :light_red
            else :light_yellow
            end
    new_size_str = "#{new_size_str.send(color)} (#{(perc.to_s + "%").send(color)})"
  elsif SHOULD_SKIP
    return nil
  end
  "#{path_str}: #{old_size_str} -> #{new_size_str}"
end

def dir_size(path, old, nnew)
  return nil if path.nil? || !File.exist?(path)
  return File.size(path) if File.file?(path)
  Dir[path + "/**/*"].select { |f| !f.end_with?(".part.mkv") && File.file?(f) && (File.exist?(f.sub(old, nnew)) || File.exist?(f.sub(old, nnew).sub(File.extname(f), ".mkv"))) }.sum { |f| File.size(f) }
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

start = Time.now
main
puts "took #{Time.now - start} seconds"
