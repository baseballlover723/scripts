require 'colorize'
require 'httparty'
require 'nokogiri'
require 'highline/import'
require 'pry'

URL = "https://en.wikipedia.org/wiki/List_of_The_Walking_Dead_episodes"
PATH = "/mnt/c/Users/Philip Ross/Downloads/The Walking Dead [1080p] {x265}"
PATH << '/' unless PATH.end_with? '/'
OPTS = {encoding: 'UTF-8'}

def main
  episodes_by_season = get_episode_names
  add_episode_names PATH, episodes_by_season
end

def get_episode_names
  html = HTTParty.get(URL)
  parsed = Nokogiri::HTML html

  episodes_by_season = {}
  tables = parsed.css('.wikiepisodetable')[0...7]
  tables.each do |table|
    season_header = table.previous_sibling.previous_sibling.previous_sibling.previous_sibling
    season_number = season_header.text[/\d+/].to_i
    season = {}
    episodes_by_season[season_number] = season

    table.css('.summary').each do |summary|
      episode_title = summary.text.gsub('"', '')
      episode_number = summary.previous_sibling.previous_sibling.text[/\d+/].to_i

      season[episode_number] = episode_title

    end
  end
  episodes_by_season
end

def add_episode_names(path, episodes_by_season)
  seasons = Dir.entries path, OPTS
  seasons.each do |season_str|
    next if season_str == '.' || season_str == '..' || season_str == 'desktop.ini'
    next unless File.directory? path + '/' + season_str
    season_number = season_str[/\d+/].to_i

    puts "Renaming files for #{path + season_str + '/'}"
    default = add_episode_names_to_season(path + season_str + '/', episodes_by_season[season_number].dup, false)
    if yesno default
      add_episode_names_to_season(path + season_str + '/', episodes_by_season[season_number].dup, true)
      puts "Renaming complete.".light_green
    else
      puts "Renaming aborted.".light_red
    end
  end
end

def add_episode_names_to_season(path, episodes, rename)
  Dir.glob(escape_glob(path) + "*").sort.each do |f|
    filename = File.basename(f, File.extname(f))
    puts '' unless rename
    puts filename.inspect.light_red unless rename

    episode_number = filename[/E\d+/][/\d+/].to_i
    episode_title = episodes.delete episode_number
    filename = filename[0...-filename.match(/S\d+E\d+/).post_match.length] # removes everything after S##E##
    filename << " #{episode_title}"

    puts filename.inspect.light_green unless rename

    File.rename(f, path + filename + File.extname(f)) if rename
  end
  unless rename
    if episodes.empty?
      puts "All episodes renamed".light_green
    else
      puts "remaining episodes: #{episodes}".light_red
    end
  end
  episodes.empty?
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) {|x| "\\"+x}
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

main
