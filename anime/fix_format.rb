require 'colorize'
require 'mediainfo'
require 'highline/import'
require 'pry'
require 'set'
require 'mime/types'
require 'differ'
require 'parallel'

Differ.format = :color
PATH = "/mnt/e/movies/"
# PATH = "/raided/tv/The Mighty Boosh (2003) [720p] {x265}/"
PATH << '/' unless PATH.end_with? '/'
OPTS = {encoding: 'UTF-8'}
NAMES = {} # {old: new}
NUMBER_OF_THREADS = 8

# TODO
# check if there is a year
# check if there is a resolution
# forkpool
# create a queue, create in - out pipe
# fork n times
# fork asks for next file
# fork executes
# repeat
# if end exit

def main
  start = Time.now
  files = []
  count = 0
  Dir.glob(PATH + '**/*').each do |f|
    next if File.directory? f
    parent_dir_path = File.dirname f
    next if parent_dir_path.include?('Featurettes')
    next unless is_video?(File.extname(f))
    count += 1
    files << f
    # break if count == 5
  end

  completed = 0
  number_pad = files.size.to_s.size
  new_file_names = Parallel.map(files, in_processes: NUMBER_OF_THREADS, finish: -> (_item, _i, _result) do
    completed += 1
    print "\r                               \r" +
            "#{completed.to_s.rjust(number_pad, '0')} / #{files.size} done"
  end) do |f|
    analyze_file f
  end

  NAMES.replace Hash[files.zip(new_file_names)]

  trim_names
  print_names

  fin = Time.now

  puts ''
  puts "took #{fin - start} seconds to analyze"

  rename

end

def analyze_file(f)
  grandparent_dir = File.dirname File.dirname f
  parent_dir = File.basename File.dirname f
  filename = File.basename f

  # match up until first instance of ( or [ or {
  match_year = /(\(\d{4}\))/
  match_res = /(\[\d{3,4}p\])/
  match_codex = /(\{x\d{3}\})/
  video_name = parent_dir[/(^.*?) \s? (#{match_year} | #{match_res} | #{match_codex} | $)/x, 1]
  filename = video_name + File.extname(f)

  parent_dir = parent_dir.gsub ' - ', '; '
  filename = filename.gsub ' - ', '; '

  video_format = `mediainfo --ReadByHuman=0 --ParseSpeed=0 --Inform="Video;%InternetMediaType%" #{Shellwords.escape(f)}`
  video_format = video_format[/H\d\d\d/].sub('H', 'x')
  # BA << video_format
  parent_dir = parent_dir.gsub(/{x(\d\d\d)}/, "{#{video_format}}")
  if !parent_dir[/{x\d\d\d}/]
    parent_dir += " {#{video_format}}"
  end

  grandparent_dir + '/' + parent_dir + '/' + filename
end

def rename
  puts ''
  puts '*******'
  base_path = PATH[0..-2]
  NAMES.each do |old, new|
    puts ''
    puts Differ.diff new, old, /\b/
    puts old.light_red
    puts new.light_green
    if yesno
      while old != base_path && old != '/'
        rename_last old, new
        old = File.dirname old
        new = File.dirname new
      end

    end
  end
end

def rename_last(old, new)
  old_parent = File.dirname old
  last_old = File.basename old
  last_new = File.basename new

  if last_old != last_new
    File.rename(old, File.join(old_parent, last_new))
  end
end

def trim_names
  NAMES.delete_if {|k, v| k == v}
end

def print_names
  puts ''
  puts ''
  NAMES.each do |old, new|
    # puts Differ.diff new, old, /([ |\/])/
    puts Differ.diff new, old, /\b/
  end
end

def is_video?(ext)
  MIME::Types.type_for(ext).any? {|mt| mt.media_type == 'video'}
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?\(\) ]/) {|x| "\\" + x}
end

def yesno(default = true, prompt = 'Continue?')
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") {|q| q.limit = 1; q.case = :downcase}
    $VERBOSE = original_verbosity
    a = d if a.length == 0
  end
  a == 'y'
end

module Differ
  module Format
    module Color
      class << self
        def as_insert(change)
          change.insert.gsub(' ', ' '.colorize(background: :light_green)).light_green
        end

        def as_delete(change)
          change.delete.gsub(' ', ' '.colorize(background: :light_red)).light_red
        end
      end
    end
  end
end

main

# puts NAMES.pretty_inspect

# puts BA.pretty_inspect
# took: 172.5462688 media info
# took: 154.4053961 inform video codec
# took: 35.730315 with parse speed = 0
