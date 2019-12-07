require 'colorize'
require 'httparty'
require 'nokogiri'
require 'highline/import'
require 'pry'
require 'resolv-replace'
# URL = "https://en.wikipedia.org/wiki/List_of_Game_of_Thrones_episodes"
# URL = "https://en.wikipedia.org/wiki/The_Planets_(2019_TV_series)"
URL = "https://en.wikipedia.org/wiki/List_of_Fresh_Off_the_Boat_episodes"
# URL = "https://en.wikipedia.org/wiki/List_of_South_Park_episodes"
# URL = "https://en.wikipedia.org/wiki/Mars_(2016_TV_series)#Episodes"
PATH = "/mnt/c/Users/Philip Ross/Downloads/f"
# PATH = "/mnt/c/Users/Philip Ross/Downloads/gen;LOCK [1080p] {x265}/"
# PATH = "/mnt/h/tv/Star Wars; The Clone Wars [1080p] {x265}/"
# PATH = "/entertainment/tv/South Park [1080p] {x265}/"
PATH << '/' unless PATH.end_with? '/'
OPTS = {encoding: 'UTF-8'}
REMOVE_PREFIX = "[snahp.it]"
# make an array
REMOVE_SUFFIX_PREFIX = /\d{3,4}p/

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

def main
  episodes_by_season = get_episode_names
  add_episode_names PATH, episodes_by_season
end

def get_episode_names
  html = HTTParty.get(URL)
  parsed = Nokogiri::HTML html

  episodes_by_season = {}
  tables = parsed.css('.wikiepisodetable')[0..23]
  # tables = parsed.css('.wikitable')[0..1]
  # tables = parsed.css('.plainrowheaders')[0..2]
  tables.each do |table|
    number_of_previous = 5
    season_header = table
    number_of_previous.times do
      season_header = season_header.previous_sibling#.previous_sibling
      break if season_header.text.match? /Season \d+/i
    end
    puts season_header.text
    next if season_header.text.strip.empty? && tables.size != 1 # skip if doesn't match season regex and is not the only table
    season_number = (season_header.text[/Season \d+/i] || '1')[/\d+/].to_i
    puts season_number
    season_number += 2 if episodes_by_season.size >= 2 && URL.include?('DreamWorks_Dragons')
    # season_number = 1
    season = {}

    table.css('.summary').each do |summary|
      # episode_title = summary.text.gsub('"', '')
      next if summary.previous_sibling.nil?
      episode_title = summary.text.scan(/"(.*)"/)&.first&.first || summary.text
      episode_title = episode_title[0...episode_title.index('"')] if episode_title.include? '"'
      episode_number = summary.previous_sibling.text[/\d+/].to_i
      # episode_number = summary.previous_sibling.previous_sibling.previous_sibling.previous_sibling.text[/\d+/].to_i

      season[episode_number] = episode_title

    end
    episodes_by_season[season_number] = season unless season.empty?
  end
  puts('No Episodes found on wiki') || exit if episodes_by_season.empty?
  puts episodes_by_season.pretty_inspect
  episodes_by_season
end

def add_episode_names(path, episodes_by_season)
  puts path
  has_seasons = false
  seasons = Dir.entries path, OPTS
  seasons.each do |season_str|
    next if season_str == '.' || season_str == '..' || season_str == 'desktop.ini' || season_str.end_with?('.enc')
    next unless File.directory? path + '/' + season_str
    next unless season_str.include? 'Season'
    season_number = season_str[/\d+/].to_i
    next unless episodes_by_season[season_number]
    has_seasons = true
    # next if season_number == 1

    puts "Renaming files for #{path + season_str + '/'}"
    default = add_episode_names_to_season(path + season_str + '/', episodes_by_season[season_number].dup, false)
    if yesno default
      add_episode_names_to_season(path + season_str + '/', episodes_by_season[season_number].dup, true)
      puts "Renaming complete.".light_green
    else
      puts "Renaming aborted.".light_red
    end
  end
  puts "No Seasons found at #{path}" || exit unless has_seasons
end

def add_episode_names_to_season(path, episodes, rename)
  Dir.glob(escape_glob(path) + "*").sort.each do |f|
    next if File.extname(f) == '.enc'
    filename = File.basename(f, File.extname(f))
    next unless filename[/\d+/]
    puts '' unless rename
    puts filename.inspect.light_red unless rename
    if filename.start_with?(REMOVE_PREFIX)
      filename = filename[REMOVE_PREFIX.size..-1]
    end
    if index = filename.index(REMOVE_SUFFIX_PREFIX)
      filename = filename[0...index]
    end

    # new_name = filename.gsub('.', ' ').title_case
    # filename = filename.split('.').join(' ')#.title_case
    filename = filename.split('.').join(' ').title_case
    if filename.match /- S\d\dE\d\d/i
      filename = filename.gsub /- (S\d\dE\d\d)/i, '\1'
    end

    if filename.match /\d\dx\d\d/
      filename.insert filename.index(/\d\d/), 'S'
      filename.insert filename.index(/x\d\d/), 'E'
      filename = filename.gsub /x(\d\d)/, '\1'
    end
    # if filename.match /\d\d .\d\d/
    #   filename = filename.gsub /(\d\d) (.\d\d)/, '\1\2'
    # end
    if filename.match /\(\d\d\d\d\) /
      filename = filename.gsub /\(\d\d\d\d\) /, ''
    end

    filename = filename.gsub(/s(\d\d)/, 'S\1')
    filename = filename.gsub(/e(\d\d)/, 'E\1')

    filename = filename.gsub(/E(\d\d)/) do |match|
      episode_n = match[/\d+/].to_i
      # [23].keep_if do |num|
      #   episode_n >= num
      # end.each do
      #   episode_n += 1
      # end

      # [2].keep_if do |num|
      #   episode_n >= num
      # end.each do
      #   episode_n -= 1
      # end

      "E#{episode_n.to_s.rjust(2, '0')}"
    end
    # puts '****************'
    # puts filename
    # puts filename[/E\d$/]
    filename[/E\d$/] = 'E0' + filename[/E\d/][/\d/] if filename[/E\d$/]
    filename[/S\d\d E\d\d/] = filename[/S\d\d/] + filename[/E\d\d/] if filename[/S\d\d E\d\d/]

    filename = filename.gsub('Marvels', "Marvel's")
    filename = filename.gsub('S H I E L D', 'S.H.I.E.L.D.')
    filename = filename.gsub('The Office Us', 'The Office')
    filename = filename.gsub('The Office (us)', 'The Office')
    filename = filename.gsub('Izombie', 'iZombie')
    filename = filename.gsub('The_mentalist_', 'The Mentalist ')
    filename = filename.gsub('Star Wars The Clone Wars', 'Star Wars; The Clone Wars')
    filename = filename.gsub('(us) ', '')
    # filename = "Doctor Who " + filename[filename.index(/S\d\dE\d\d/)..-1]

    episode_number = filename[/E\d+/][/\d+/].to_i

    # episode_number = filename[/\d+/].to_i
    episode_title = episodes.delete episode_number
    # episode_title = episode_title.split("\n").last
    # episode_title = episode_title[0...episode_title.index('[')] if episode_title.include? '['

    # filename = filename[0..(-filename.match(/S\d+.*E\d+/).post_match.length - 1)] # removes everything after S##E##
    filename = filename[0..(-filename.match(/E\d+/).post_match.length - 1)] # removes everything after S##E##
    filename << " #{episode_title}"
    gsub_windows(filename)

    filename = filename.gsub 'Blue Planet Ii', 'Blue Planet II'
    filename = filename.gsub 'Mr Robot', 'Mr. Robot'
    # filename.gsub! 'S0', 'Longmire S0'

    puts filename.inspect.light_green unless rename

    begin
      File.rename(f, path + filename + File.extname(f)) if rename
    rescue
      puts "Error renaming \n#{File.basename(f)} to \n#{File.basename(path + filename + File.extname(f))}\n".light_red
    end
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

# because windows
def gsub_windows(str)
  str.gsub! ':', ';'
  str.gsub! /[\/\\]/, '-'
  str.gsub! '?', ','
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
