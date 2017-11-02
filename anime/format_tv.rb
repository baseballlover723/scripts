require 'colorize'
require 'highline/import'


class String
  def title_case
    title = self.split
    excluded = ['of', 'the', 'to', 'in', 'a', 'and', 'or', 'for', 'vs']
    title.map do |word|
      unless excluded.include?(word) && (title.first != "the")
        word.capitalize
      else
        word
      end
    end.join(" ")
  end
end

BASE_PATH = "/mnt/c/Users/Philip Ross/Downloads/"
# Marvels Agent Carter 2015 S02 1080p BluRay x265 HEVC 10bit AAC 5 1-Vyndros/"
PATHES = [
    'The Walking Dead [1080p] {x265}/Season 1',
    'The Walking Dead [1080p] {x265}/Season 2',
    'The Walking Dead [1080p] {x265}/Season 3',
    'The Walking Dead [1080p] {x265}/Season 4',
    'The Walking Dead [1080p] {x265}/Season 5',
    'The Walking Dead [1080p] {x265}/Season 6',
    'The Walking Dead [1080p] {x265}/Season 7',
]
PATHES.each {|path| path << '/' unless path.end_with? '/'}
PATHES.each {|path| path.prepend BASE_PATH}
REMOVE_PREFIX = "[snahp.it]"
REMOVE_SUFFIX_PREFIX = ".1080p"

def main
  PATHES.each do |path|
    puts "Renaming files for #{path}"
    rename(path, false)
    if yesno
      rename(path, true)
      puts "Renaming complete.".light_green
    else
      puts "Renaming aborted.".light_red
    end
  end
end

def rename(path, rename)
  Dir.glob(escape_glob(path) + "*").sort.each do |f|
    filename = File.basename(f, File.extname(f))
    puts '' unless rename
    puts filename.inspect.light_red unless rename
    
    if filename.start_with?(REMOVE_PREFIX)
      filename = filename[REMOVE_PREFIX.size..-1]
    end
    if index = filename.index(REMOVE_SUFFIX_PREFIX)
      filename = filename[0...index]
    end
    # new_name = filename.gsub('.', ' ').title_case
    filename = filename.split('.').join(' ').title_case

    filename = filename.gsub(/s(\d\d)/, 'S\1')
    filename = filename.gsub(/e(\d\d)/, 'E\1')

    puts filename.inspect.light_green unless rename

    File.rename(f, path + filename + File.extname(f)) if rename
  end
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) {|x| "\\"+x}
end

def yesno(prompt = 'Continue?', default = true)
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

main
# Stranger.Things.S01E08.Chapter.Eight.The.Upside.Down.(2160p.x265.10bit.Joy) snahp.it
