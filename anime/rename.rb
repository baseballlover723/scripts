require 'set'
require 'colorize'

PATH = '/mnt/c/Users/Philip Ross/Downloads/Naruto'
OPTS = {encoding: 'UTF-8'}
RENAME = true
RESULTS = []

def main
  rename_show PATH, false
  has_missing = analyze_missing
  if RENAME && !has_missing
    rename_show PATH, true
    puts 'Done renaming'.light_green
  else
    puts 'Renaming not enabled'.light_yellow
  end
end

def rename_show(path, rename)
  entries = Dir.entries path, OPTS
  count = 0
  entries.each do |entry|
    next if entry == '.' || entry == '..' || entry == 'desktop.ini'
    if File.directory?("#{path}/#{entry}")
      rename_season path + '/' + entry, rename
    else
      rename_episode path, entry, rename
    end
    count += 1
    # break if count > 2
  end
end

def rename_season(path, rename)
  episodes = Dir.entries path, OPTS
  count = 0
  episodes.each do |episode_name|
    next if episode_name == '.' || episode_name == '..' || episode_name == 'desktop.ini'
    rename_episode path, episode_name, rename
    count += 1
    # break if count > 2
  end
end

def rename_episode(folder_path, name, rename)
  episode_number = extract_number name
  puts "Not renaming '#{name.light_yellow}'" or return unless episode_number
  if rename
    File.rename(folder_path + '/' + name, folder_path + '/' + episode_number.to_s + File.extname(name))
  else
    RESULTS << episode_number
  end
end

def extract_number(str)
  numb = str[/\d+/]
  return unless numb
  numb = numb.to_i
  numb if numb < 1900 # probably a movie
end

def analyze_missing
  puts ''
  missing_episodes_numbers = []
  set = Set.new
  duplicates = RESULTS.select {|e| !set.add?(e)}

  puts "duplicate episode numbers: #{duplicates.map(&:to_s).map(&:light_red).join(', ')}" unless duplicates.empty?
  RESULTS.min.upto(RESULTS.max).each do |numb|
    missing_episodes_numbers << numb unless set.include? numb
  end
  if missing_episodes_numbers.empty?
    puts 'no missing episodes'.light_green
  else
    puts "missing episodes: #{missing_episodes_numbers.map(&:to_s).map(&:light_red).join(', ')}"
  end
  return !missing_episodes_numbers.empty?
end

main
