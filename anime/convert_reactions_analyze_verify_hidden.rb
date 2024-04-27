require 'shellwords'
require 'pathname'
require 'colorize'
require 'parallel'

PATHS = [
]
SUBDIRS = [["/old", "/new"]]
HIDE_MISSING = true
SHOULD_SKIP = false
# SHOULD_SKIP = true
SKIP_THRESHOLD = 5.0
Thread.abort_on_exception = true

def main
  Parallel.map(PATHS, in_processes: 3) do |path|
    old, new = SUBDIRS.find { |old, new| File.exist?(path + old) && File.exist?(path + new) }

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

    arr = paths.map do |name, paths|
      [name, *paths]
    end.sort_by do |name, old_path, new_path, is_directory|
      number_sort_by(name.downcase)
    end
    Parallel.map(arr, in_processes: 8) do |name, old_path, new_path, is_directory|
      old_size = is_hidden?(old_path)
      new_size = is_hidden?(new_path)
      next nil if HIDE_MISSING && (new_size.nil? || old_size.nil?)
      str = diff_str(name, old_size, new_size, is_directory)
      # puts str if str
    end.compact
    # end
  end.each do |str|
    puts str
  end

  # puts
  # puts total_string
end

def diff_str(path, old_hidden, new_hidden, is_directory)
  return nil if old_hidden == new_hidden
  path_str = is_directory ? (path + "/").light_magenta : path
  old_hidden_str = old_hidden.to_s.send(old_hidden ? :light_cyan : :light_red)
  new_hidden_str = new_hidden.to_s.send(new_hidden ? :light_cyan : :light_red)
  "#{path_str}: #{old_hidden_str} -> #{new_hidden_str}"
end

def is_hidden?(path)
  return nil if path.nil? || !File.exist?(path)
  windows_path = path.sub(/\/mnt\/(.)/, '\1:').sub("/", "\\")
  windows_path[0] = windows_path[0].upcase

  hidden_cmd = "cmd.exe /c attrib \"#{windows_path}\""
  # puts "hidden_cmd: #{hidden_cmd}"
  `#{hidden_cmd}`[4] == 'H'
end

def number_sort_by(str)
  str.scan(/\D+|\d+/).map { |part| part.match?(/\d+/) ? part.to_i : part }
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
