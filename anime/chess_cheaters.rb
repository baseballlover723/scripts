require "date"
require "oj"
require "httparty"
require "active_support"
require "active_support/number_helper"
require "fileutils"

API_HOST = "https://api.chess.com/pub"
PROFILE_PATH = "#{API_HOST}/player/%{username}"
ARCHIVES_PATH = "#{API_HOST}/player/%{username}/games/archives"
# ARCHIVE_PATH = "#{API_HOST}/player/%{username}/games/archives"

CHEATER_STATUS = "closed:fair_play_violations"

# TODO make cache lifetime dependent on save file
LAST_RUN_FILE = "chess_cheaterss.last_run.fakecache.json"
RAND_TIME = 15 * 24 * 60 * 60 # seconds
CACHE_LIFETIME = 15 * 24 * 60 * 60 # seconds
$last_write_time = Time.now
$last_write_time2 = Time.now
UPDATE_DURATION = 30 # seconds
LAST_MODIFIED = "last_modified".freeze
ARCHIVE = "archive".freeze
PROFILE = "profile".freeze

# RULES = {"time_class" => ["daily"]}
RULES = {only_daily: ["time_class", ["daily"]], only_live: ["time_class", ["bullet", "blitz", "rapid"]], only_tournaments: ["tournament", :exists]}
ALL_GAMES_RULES = []
DAILY_GAMES_RULES = [:only_daily]
USCF_RULES = [:only_live, :only_tournaments]

def build_rules(usernames, ruleset)
  usernames.map do |username|
    rules = {}
    ruleset.each do |key|
      rule = RULES[key]
      rules[rule.first] = rule.last
    end
    [username, rules]
  end
end

# PRINT_GAME_DETAILS = true
PRINT_GAME_DETAILS = false

# FORCE_FUZZ_LAST_MODIFIED = true
FORCE_FUZZ_LAST_MODIFIED = false

ALL_ME = build_rules(["baseballlover723"], ALL_GAMES_RULES)
USCF_ME = build_rules(["baseballlover723"], USCF_RULES)
DAILY_ME = build_rules(["baseballlover723"], DAILY_GAMES_RULES)
ALL_ME_RUE = ALL_ME + build_rules(["Dotarue"], ALL_GAMES_RULES)
USCF_FRIENDS = build_rules(["baseballlover723", "infiniteiqwarrior", "jordanfiglioli", "thee_black_knight", "herooffallen"], USCF_RULES)
STREAMERS = build_rules(["Hikaru", "GothamChess", "danielnaroditsky"], ALL_GAMES_RULES)
MOST_GAMES = build_rules(["Gregorysteven", "pokerbloke99"], ALL_GAMES_RULES)
ALL_IN_PERSON = ALL_ME_RUE + build_rules(["herooffallen"], ALL_GAMES_RULES)
ALL_FRIENDS = ALL_IN_PERSON + build_rules(["infiniteiqwarrior", "jordanfiglioli", "thee_black_knight"], ALL_GAMES_RULES)

# USERNAMES = MOST_GAMES
# USERNAMES = ALL_FRIENDS + STREAMERS + MOST_GAMES
if defined?(USERNAMES) && !defined?(ARCHIVE_SAVE_FILE) && !defined?(PROFILE_SAVE_FILE)
  ARCHIVE_SAVE_FILE = "chess_cheaterss.archive.big.fakecache.json"
  PROFILE_SAVE_FILE = "chess_cheaterss.profile.big.fakecache.json"
end

# USERNAMES = ALL_IN_PERSON
# USERNAMES = ALL_FRIENDS
# USERNAMES = STREAMERS
# USERNAMES = ALL_FRIENDS + STREAMERS
if defined?(USERNAMES) && !defined?(ARCHIVE_SAVE_FILE) && !defined?(PROFILE_SAVE_FILE)
  ARCHIVE_SAVE_FILE = "chess_cheaterss.archive.medium.fakecache.json"
  PROFILE_SAVE_FILE = "chess_cheaterss.profile.medium.fakecache.json"
end

# USERNAMES = ALL_ME
# USERNAMES = USCF_ME
# USERNAMES = DAILY_ME
# USERNAMES = ALL_ME_RUE
# USERNAMES = USCF_FRIENDS
USERNAMES = ALL_ME_RUE + USCF_FRIENDS
if defined?(USERNAMES) && !defined?(ARCHIVE_SAVE_FILE) && !defined?(PROFILE_SAVE_FILE)
  ARCHIVE_SAVE_FILE = "chess_cheaterss.archive.small.fakecache.json"
  PROFILE_SAVE_FILE = "chess_cheaterss.profile.small.fakecache.json"
end

# FUTURE PLANS
# cache profile gets
# make a website
# server in elixir
# frontend in some simple js
# frontend is basically a search box -> profile page
# profile page is live updated (live view?)
# has update button to grab latest games
# can't update if already in progress
# server sends messages to the front end about progress (do I need to limit / batch some of these to save network)
# server should ideally use gen servers to parallelize and caching to avoid slamming chess.com
# post on reddit
# support lichess?  whats the difference between disabled and tos_violation?
# with tos_violation I can still see things about the account
# with disabled I only see its disabled
# can I treat disabled as a cheater?
# is tos_violation only mean they were punished (and have served it) in the past, and not currently?
# ask on lichess forum somewhere
def main(username, rules)
  puts "\nchecking #{username} for cheater opponents with rules: #{rules}"
  obsolete_archives = Set.new
  # loop so that we can retry any archive links that contain obsolete usernames
  loop do
    $profiles ||= load_profiles(PROFILE_SAVE_FILE)
    $archives ||= load_archives(ARCHIVE_SAVE_FILE)
    invalidate_obsolete_archives(obsolete_archives, ARCHIVE_SAVE_FILE)
    obsolete_archives.clear

    archives = get_archives(username)
    # archives = archives.drop(6) # DEBUG first cheater
    # archives = archives.take(1) # DEBUG
    # archives = archives.take(9) # DEBUG
    # puts "archives: #{archives.inspect}"

    total_game_count = 0
    analyzed_games_count = 0
    games_by_username = archives.map.with_index { |archive_link, index|
      get_games(username, archive_link, index + 1, archives.size).
        map do |game|
        game["archive_link"] = archive_link
        game
      end
      # .take(1) # DEBUG
    }.map { |games| total_game_count += games.size; games }.
      flat_map { |games| games }.
      filter { |game| filter_game(game, rules) }.
      map { |game| analyzed_games_count += 1; game }.
      # map { |game| add_opponent(username, game) }.
      # map { |game| pp game; game }.# DEBUG
      group_by { |game| game["opponent"]["username"] }
    save_archives(ARCHIVE_SAVE_FILE)

    unique_opponents = games_by_username.size
    thread = Thread.new do
      sleep 30
      $archives = nil
      GC.start
    end
    numb_cheaters, cheated_games = games_by_username.
      filter.with_index { |(human_username, games), index| check_cheater(username, games.first["opponent"], index + 1, unique_opponents, obsolete_archives, games.map { |g| g["archive_link"] }) }.
      reduce([0, []]) { |array, (username, games)|
        array[0] += 1
        array[1].concat(games)
        array
      }.map { |games|
      games.is_a?(Enumerable) ? games.sort_by { |game| game["end_time"] } : games
    }
    thread.kill
    save_profiles(PROFILE_SAVE_FILE)
    GC.start
    next unless obsolete_archives.empty?

    print_games(username, cheated_games, total_game_count, analyzed_games_count, unique_opponents, numb_cheaters)
    break
  end
end

def check_archive_cache(link)
  if $archives[link]
    cached_archive = $archives[link]
    last_modified = cached_archive[LAST_MODIFIED]
    if Time.now - last_modified > CACHE_LIFETIME
      $archives.delete(link)
      return false
    end
    return cached_archive[ARCHIVE]
  end
  false
end

def update_archive_cache(link, archive, path)
  return archive if link.end_with?(Time.now.strftime("%Y/%m"))
  if archive
    $archives[link] = {LAST_MODIFIED => Time.now, ARCHIVE => archive}
  else
    $archives.delete(link)
  end
  if Time.now - $last_write_time2 > UPDATE_DURATION
    save_archives(path)
    $last_write_time2 = Time.now
  end
  archive
end

def load_archives(path)
  return {} unless File.exist?(path)
  Oj.load_file(path)
end

def save_archives(path)
  cache = $archives
  sorted_cache = cache.sort_by { |path, _obj| path }.to_h
  File.write(path, Oj.dump(sorted_cache))
end

def invalidate_obsolete_archives(obsolete_archives, path)
  obsolete_archives.each do |obsolete_archive|
    update_archive_cache(obsolete_archive, nil, path)
  end
  save_archives(path) if !obsolete_archives.empty?
end

def check_profile_cache(username)
  if $profiles[username]
    cached_profile = $profiles[username]
    last_modified = cached_profile[LAST_MODIFIED]
    if Time.now - last_modified > CACHE_LIFETIME
      $profiles.delete(username)
      return false
    end
    cached_profile[LAST_MODIFIED] = Time.now - rand(RAND_TIME) if FORCE_FUZZ_LAST_MODIFIED # randomize refresh time
    return cached_profile[PROFILE]
  end
  false
end

def update_cache(username, profile, path)
  now = Time.now
  fuzzed_last_modified = now - rand(now - $last_run[path])
  if profile
    $profiles[username] = {LAST_MODIFIED => fuzzed_last_modified, PROFILE => profile}
  else
    $profiles.delete(username)
  end
  if Time.now - $last_write_time > UPDATE_DURATION
    save_profiles(path)
    $last_write_time = Time.now
  end
  profile
end

def load_profiles(path)
  return {} unless File.exist?(path)
  Oj.load_file(path)
end

def save_profiles(path)
  cache = $profiles
  sorted_cache = cache.sort_by { |path, _obj| path }.to_h
  File.write(path, Oj.dump(sorted_cache))
end

def get_archives(username)
  response = HTTParty.get(ARCHIVES_PATH % {username: username})
  puts "archives response status: #{response.code}"
  if !response.ok?
    puts response
    raise "Error getting archive for \"#{username}\""
  end
  response.parsed_response["archives"].reverse
end

def get_games(username, archive_link, index, total_links)
  cached_games = check_archive_cache(archive_link)
  return cached_games if cached_games
  puts "getting archive from: #{archive_link}"
  begin
    response = HTTParty.get(archive_link)
  rescue StandardError => e
    puts e.full_message
    sleep 5
    puts "retrying request"
    response = HTTParty.get(archive_link)
  end
  puts "games (#{index} / #{total_links}) response status: #{response.code}"
  if !response.ok?
    puts response
    raise "Error getting archive for \"#{username}\""
  end
  update_archive_cache(archive_link, trim_games(username, response.parsed_response["games"]), ARCHIVE_SAVE_FILE)
end

def trim_games(username, games)
  games.map do |game|
    game.delete("pgn")
    game.delete("accuracies")
    game.delete("tcn")
    game.delete("uuid")
    game.delete("fen")
    game["white"].delete("uuid")
    game["black"].delete("uuid")
    add_opponent(username, game)
    game.delete("white")
    game.delete("black")
    game
  end
  # games
end

# TODO separate getting profile info and filtering cheaters
def get_profile(username, obsolete_archives, archive_links, message)
  cached_profile = check_profile_cache(username)
  return cached_profile if cached_profile
  puts message
  begin
    response = HTTParty.get(PROFILE_PATH % {username: username})
  rescue StandardError => e
    puts e.full_message
    puts "retrying request"
    response = HTTParty.get(PROFILE_PATH % {username: username})
  end
  if response.not_found?
    puts "#{username} has changed their name, marking #{archive_links} as obsolete"
    obsolete_archives.merge(archive_links)
    return update_cache(username, nil, PROFILE_SAVE_FILE)
    # exit(0)
  elsif !response.ok?
    puts response
    raise "Error getting profile for \"#{username}\" (#{response.code})"
  end
  update_cache(username, response.parsed_response, PROFILE_SAVE_FILE)
end

def check_cheater(username, player, index, total_links, obsolete_archives, archive_links)
  opponent_username = player["username"]
  profile = get_profile(opponent_username, obsolete_archives, archive_links, "(#{username}) checking #{opponent_username} (#{human_number(index)} / #{human_number(total_links)}) for cheating")
  return false if profile.nil? # profile is nil if they changed their username and we're checking the old one
  profile["status"] == CHEATER_STATUS
  # true # DEBUG
end

def filter_game(game, rules)
  # puts "checking for filter game with rules: #{rules}"
  # pp game
  rules.all? do |key, values|
    case values
    when :exists
      game.has_key?(key)
    when Array
      values.include?(game[key])
    else
      raise "Invalid option for filtering game key: \"#{key}\", value: \"#{values}\""
    end
  end
end

def add_opponent(username, game)
  opponent_key = game["white"]["@id"].end_with?(username) ? "black" : "white"
  your_key = game["white"]["@id"].end_with?(username) ? "white" : "black"
  game["you"] = game[your_key]
  game["you"]["color"] = your_key
  game["opponent"] = game[opponent_key]
  game["opponent"]["color"] = opponent_key
  game
end

def print_games(username, games, total_game_count, analyzed_games_count, unique_opponents, numb_cheaters)
  puts "\nanalyzed #{human_number(analyzed_games_count)} (#{human_number(total_game_count)} total) games against #{human_number(unique_opponents)} unique opponents for #{username} and found #{human_number(games.size)} games with #{human_number(numb_cheaters)} unique cheaters"
  puts ""

  if PRINT_GAME_DETAILS
    games.each.with_index do |game, index|
      print_game(game, index + 1, games.size)
    end
  end
end

def print_game(game, index, total_games)
  cheater_profile = check_profile_cache(game["opponent"]["username"])
  puts "#{human_number(index)}: (#{human_date(game["end_time"])}) (#{human_time_control(game["time_class"], game["time_control"])}): #{player_string(game["you"])} vs #{player_string(game["opponent"])} (Banned: #{human_date(cheater_profile["last_online"])}): #{game["url"]}"
end

def player_string(player)
  "#{player["username"]} (#{player["rating"]}) (#{player["color"]}) (#{player["result"]})"
end

def human_number(number)
  ActiveSupport::NumberHelper.number_to_delimited(number)
end

def human_date(number)
  Time.at(number, in: "+00:00").getlocal.strftime("%D %I:%M %p %Z")
end

def human_time_control(time_class, time_control)
  if (time_class == "daily")
    "#{time_control.split("/").last.to_i / 60 / 60 / 24} days"
  else
    initial, increment = time_control.split("+").map(&:to_i)
    # TODO handle hyper bullet?
    string = "#{initial / 60}"
    if (increment)
      string += "|#{increment}"
    else
      string += " min"
    end
    string
  end
end

def load_last_run(path)
  return {PROFILE_SAVE_FILE => Time.now} unless File.exist?(path)
  json = Oj.load_file(path)
  cache = {}

  json.each do |profile_path, last_modified|
    cache[profile_path] = Time.parse(last_modified)
  end
  cache[PROFILE_SAVE_FILE] = Time.now unless cache[PROFILE_SAVE_FILE]
  cache
end

def save_last_run(path)
  cache = $last_run
  sorted_cache = cache.sort_by { |path, _obj| path }.to_h
  Oj::Rails.mimic_JSON
  File.write(path, Oj.generate(sorted_cache))
end

start = Time.now
$last_run = load_last_run(LAST_RUN_FILE)
if defined? USERNAMES
  USERNAMES.each do |username, rules|
    start1 = Time.now
    main(username, rules)
    puts "#{username} Took #{Time.now - start1} seconds"
  end
else
  main(USERNAME, ALL_GAMES_RULES)
end
$last_run[PROFILE_SAVE_FILE] = Time.now
save_last_run(LAST_RUN_FILE)

# l1 = Time.now
# $profiles = load_profiles(PROFILE_SAVE_FILE)
# l2 = Time.now
# puts "load (#{Time.now}) took: #{l2 - l1}"
#
# t1 = Time.now
# profile = get_profile(USERNAME)
# t2 = Time.now
# puts "1 (#{Time.now}) took: #{t2 - t1}"
# puts
#
# t3 = Time.now
# profile = get_profile(USERNAME)
# t4 = Time.now
# puts "2 (#{Time.now}) took: #{t4 - t3}"
# puts
#
# sleep 5
#
# t5 = Time.now
# profile = get_profile(USERNAME)
# t6 = Time.now
# puts "3 (#{Time.now}) took: #{t6 - t5}"
# puts
#
# t7 = Time.now
# profile = get_profile(USERNAME)
# t8 = Time.now
# puts "4 (#{Time.now}) took: #{t8 - t7}"
# puts
#
# sleep 5
#
# t9 = Time.now
# profile = get_profile(USERNAME)
# t10 = Time.now
# puts "5 (#{Time.now}) took: #{t10 - t9}"
# puts
#
# t11 = Time.now
# profile = get_profile(USERNAME)
# t12 = Time.now
# puts "6 (#{Time.now}) took: #{t12 - t11}"
# puts
#
# s1 = Time.now
# save_profiles(PROFILE_SAVE_FILE)
# s2 = Time.now
# puts "save (#{Time.now}) took: #{s2 - s1}"

puts "Took #{Time.now - start} seconds"
