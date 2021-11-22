require "csv"
require "./elo_calc"

ROUNDS = 9_u8
#ROUNDS = 20_u8
BYES = 1
# https://docs.google.com/spreadsheets/d/15lCTXj9Ld_5xwtiBL6ReyDTjywdSFrlsUL51uKz15WE/edit#gid=0
PLAYER_NAME = "Nelson Lopez"

TIME_FORMAT = "%D %r"
PROGRESS_FPS = 24
#PROGRESS_FPS = 1
RATE_FPS = 1
PROGRESS_REFRESH_TIME = Time::Span.new(nanoseconds: (1_000_000_000 / PROGRESS_FPS).to_i)
RATE_REFRESH_TIME = Time::Span.new(nanoseconds: (1_000_000_000 / RATE_FPS).to_i)

BUCKETS = { {"< 3", 2.75}, {"3 - 4", 4.25}, {"4.5 - 5.5", 5.75}, {"6 - 7", 7.25}, {"> 7", 999} }
BUCKET_PAD = BUCKETS.max_of {|name, _| name.size}

struct Player
  property name : String
  property uscf_elo : Int32
  property fide_elo : Int32
  property rating : Float64
  property byes : Array(UInt8)

  def initialize(@name, @uscf_elo, @fide_elo, @byes)
    @rating = (@uscf_elo + @fide_elo) / 2.0
  end

  def calc_prob(other : Player)
    Elo.calc_probs(rating, other.rating)
  end

  def simulate_result(other : Player) : UInt8
    return 0_u8 if self == BYE_PLAYER
    return 2_u8 if other == BYE_PLAYER
    probability = Elo.calc_probs(rating, other.rating)

    win_line = probability.win
    draw_line = win_line + probability.draw

    r = RANDOM[0].rand

    if r < win_line
      2_u8
    elsif r < draw_line
      1_u8
    else
      0_u8
    end
  end

  def self.build(row) : Player
    name = row[0]
    uscf = parse_uscf(row[1], row[2])
    fide = parse_fide(row[1], row[2])
    byes = row[5].split(",").map(&.to_u8)

    Player.new(name, uscf, fide, byes)
  end

  private def self.parse_uscf(uscf_raw, fide_raw)
    if uscf_raw[0].number?
      uscf_raw.to_i32
    else
      fide_raw.to_i32
    end
  end

  private def self.parse_fide(uscf_raw, fide_raw)
    if fide_raw[0].number?
      fide_raw.to_i32
    else
      uscf_raw.to_i32
    end
  end
end

struct Performance
  property player : Player
  property wins : UInt8
  property draws : UInt8
  property losses : UInt8

  def initialize(@player)
    @wins = 0_u8
    @draws = 0_u8
    @losses = 0_u8
  end

  def increment_win
    @wins += 1
    self
  end

  def increment_draw
    @draws += 1
    self
  end

  def increment_loss
    @losses += 1
    self
  end

  def games
    @wins + @draws + @losses
  end

  def score
    (@wins * 2 + @draws) / 2.0
  end

  def to_s(io)
    io << "#{player.name} (#{player.rating}) (#{wins}-#{draws}-#{losses}) (#{score})"
  end
end

BYE_PLAYER = Player.new("BYE", 0, 0, [] of UInt8)
BYE_PERFORMANCE = Performance.new(BYE_PLAYER)
RANDOM = StaticArray(Random, 1).new(Random.new)

def my_main(csv_path : String, tournaments_to_simulate : UInt128, random_seed : UInt32)
  puts "running with seed: #{random_seed}"
  RANDOM[0] = Random.new(random_seed)
  players = parse_csv(csv_path)
#  players << BYE_PLAYER if players.size.odd?
  nelson = players.find { |player| player.name.includes?(PLAYER_NAME)}
  raise "Could not find Nelson" if nelson.nil?

  top_player = players.first
  top_med_player = players[players.size // 4]
  bottom_med_player = players[3 * players.size // 4]
  bottom_player = players.last
  pad = [top_player.name, top_med_player.name, nelson.name, bottom_med_player.name, bottom_player.name].max_of {|n| n.size}
  puts prob_str(nelson, top_player, pad, 1)
  puts prob_str(nelson, top_med_player, pad, players.index(top_med_player))
  puts prob_str(nelson, nelson, pad, players.index(nelson))
  puts prob_str(nelson, bottom_med_player, pad, players.index(bottom_med_player))
  puts prob_str(nelson, bottom_player, pad, players.size)

  start_time = last_rate_time = Time.local
  tournaments_simulated = last_tournaments_simulated = failed = 0_u128
  current_rate = Int32::MAX.to_f
  last_time = Time.local
  old_sync = STDERR.sync?
  STDERR.sync = true

  nelson_stats = Hash(Float64, UInt32).new(0_u32)
  total_time = Time.measure do
#  tournaments_to_simulate.times do |i|
  while (tournaments_simulated < tournaments_to_simulate)
    now = Time.local
    if now - last_time > PROGRESS_REFRESH_TIME
      if now - last_rate_time > RATE_REFRESH_TIME
        tournaments_simulated_since_last_rate = tournaments_simulated - last_tournaments_simulated
        current_rate = tournaments_simulated_since_last_rate / (now - last_rate_time).to_f
        last_tournaments_simulated = tournaments_simulated
        last_rate_time = now
      end

#      STDERR.print get_progress_str(i, tournaments_to_simulate, current_rate) # keep
      STDERR.print get_progress_str(tournaments_simulated, tournaments_to_simulate, current_rate) # keep
      last_time = now
    end

    begin
      results = simulate_tournament(players, nelson)
      nelson_stats[results[nelson].score] += 1
      tournaments_simulated += 1_u128
    rescue
      failed += 1_u128
    end
#    puts "nelson"s results: #{results[nelson]}"
  end
  puts "" # keep

  STDERR.sync = old_sync
  end
  rate = tournaments_to_simulate / total_time.to_f
  perc_str = "(#{rate.to_i.format} t/s)"
  puts "took #{total_time} seconds total to simulate #{tournaments_to_simulate.format} tournments #{perc_str}"
  puts "failed: #{failed.format} tournaments"

  puts "\n******************************\n"

  grouped_nelson_stats = Hash(String, UInt32).new
  BUCKETS.each do |name, _|
    grouped_nelson_stats[name] = 0_u32
  end
  total = 0_u32
  nelson_stats.keys.each do |score|
    total += nelson_stats[score]
    grouped_nelson_stats[map_to_bucket(score)] += nelson_stats[score]
  end

  nelson_stats.keys.sort.reverse.each do |score|
    perc_str = (nelson_stats[score] * 100 / total).round(2).format(decimal_places: 2)
    puts "#{score}: #{nelson_stats[score].format} (#{perc_str}%)"
  end
  puts
  BUCKETS.reverse.each do |name, _|
    perc_str = (grouped_nelson_stats[name] * 100 / total).round(2).format(decimal_places: 2)
    puts "#{name.ljust(BUCKET_PAD)}: #{grouped_nelson_stats[name].format} (#{perc_str}%)"
  end
  puts
  puts "Total: #{total.format}"
end

def parse_csv(csv_path : String) : Array(Player)
  players = [] of Player

  csv = CSV.new(File.read(csv_path))
  while true
    csv.next
    break if csv.row[0] == "Open Section"
  end

  while true
    csv.next
    break if csv.row[0] == "Player"
    players << Player.build(csv.row)
  end

  players.sort_by {|player| -player.rating}
end

def simulate_tournament(player_list : Array(Player), track_player : Player) : Hash(Player, Performance)
  players = Hash(Player, Performance).new
  player_list.each do |player|
    players[player] = Performance.new(player)
  end
  match_history = Hash(Player, Set(Player)).new { |hash, player| hash[player] = Set(Player).new }
  ROUNDS.times do |i|
    simulate_round(i + 1, players, match_history)
  end

#  puts "\n*******************\n\n"
#  puts "AFTER TOURNAMENT (#{ROUNDS} rounds)"
#  players.each do |_, performance|
#    puts performance
#  end

  players
end

def simulate_round(round_number : UInt8, players : Hash(Player, Performance), match_history : Hash(Player, Set(Player)))
#  puts "\n***************\n\n"
#  puts "simulating round ##{round_number}"

#  player_byes, playing_players = players.values.partition { |performance| performance.player.byes.includes?(round_number) }
#  puts player_byes

  pairings = [] of Tuple(Performance, Performance)
  groups = players.values.group_by { |performance| performance.score}
  sorted_scores = groups.keys.sort_by! { |score| -score }
  odd_players = [] of Performance
  sorted_scores.each do |score|
    bye_players, group_players = groups[score].partition { |performance| performance.player.byes.includes?(round_number) }
    bye_players.each do |performance|
      players[performance.player] = performance.increment_draw
    end
    group_players.sort_by! {|performance| -performance.player.rating }
    debug_odd_players = odd_players.dup # debug
    if !odd_players.empty?
      odd_players.each do |player|
        group_players.unshift(player)
      end
      odd_players.clear
    end
    mid = group_players.size // 2
#    puts "\nscore_group: #{score}, players #{group_players.size}, mid: #{mid}, odd_players: #{debug_odd_players.map(&.to_s).join(", ")}"
#    group_players.each do |player|
#      puts player
#    end
    upper_group_players = group_players[0...mid]
    lower_group_players = group_players[mid..-1]
#    puts "upper: #{upper_group_players.size}, lower: #{lower_group_players.size}"
#    puts "upper_last: #{upper_group_players.last}, lower_first: #{lower_group_players.first}" if !upper_group_players.empty? && !lower_group_players.empty?

    mid.times do |_|
      upper_player = upper_group_players.shift
      lower_index = 0
      while (lower_index < lower_group_players.size && match_history[upper_player.player].includes?(lower_group_players[lower_index].player))
        lower_index += 1
      end
      if lower_index < lower_group_players.size
        lower_player = lower_group_players.delete_at(lower_index)
#        puts "pairing #{upper_player} VS #{lower_player}"
        pairings << {upper_player, lower_player}
      else
        odd_players << upper_player
#        # TODO could not match with remaining
#        raise "TODO ran out of valid lower players"
      end
    end
#    puts "after pairing: upper: #{upper_group_players.size}, lower: #{lower_group_players.size}"
    if !lower_group_players.empty?
#      puts "odd players are: #{lower_group_players.map(&.to_s).join(", ")}"
      odd_players.concat(lower_group_players)
    end
  end

  if !odd_players.empty?
#    puts "odd_players isn't empty: #{odd_players.map(&.to_s).join(", ")}"
    raise "more then one odd player at the end of pairing, need to backtrack TODO" if odd_players.size > 1
    # TODO try something like, iterate backwards over the odd_players, trying to match any 2 of them together
    # Else, if still too many, generate an invalid pairing, try going through the pairings backwards, and seeing if any of them can be swapped (trade both lowers, trade paired lower, with odd upper)
    pairings << {odd_players.first, BYE_PERFORMANCE}
  end

#  puts "\n***************\n\n"
#  puts "Round ##{round_number} pairings: "
  pairings.each do |upper_player, lower_player|
#    print "#{upper_player} VS #{lower_player} "
    match_history[upper_player.player] << lower_player.player
    match_history[lower_player.player] << upper_player.player
    case upper_player.player.simulate_result(lower_player.player)
    when 0_u8
#      puts "loss"
      players[upper_player.player] = upper_player.increment_loss
      players[lower_player.player] = lower_player.increment_win
    when 1_u8
#      puts "draw"
      players[upper_player.player] = upper_player.increment_draw
      players[lower_player.player] = lower_player.increment_draw
    when 2_u8
#      puts "win"
      players[upper_player.player] = upper_player.increment_win
      players[lower_player.player] = lower_player.increment_loss
    end
  end
  players.delete(BYE_PLAYER)

#  puts "\n*******************\n\n"
#  puts "after round ##{round_number}"
#  players.each do |_, performance|
#    puts performance
#  end
end

def map_to_bucket(score : Float64)
  BUCKETS.each do |name, max_value|
    return name if score < max_value
  end
  return BUCKETS.last.first
end

def prob_str(player1, player2, pad, rank)
  prob = player1.calc_prob(player2)
  win = (prob.win * 100).round(2).format(decimal_places: 2)
  draw = (prob.draw * 100).round(2).format(decimal_places: 2)
  loss = (prob.loss * 100).round(2).format(decimal_places: 2)
  "#{player1.name} (#{player1.rating}) VS #{player2.name.ljust(pad)} (##{rank.to_s.ljust(2)}) (#{player2.rating}): win: #{win.rjust(5, ' ')}%, draw: #{draw.rjust(5, ' ')}%, loss: #{loss.rjust(5, ' ')}%"
end

def get_progress_str(tournaments_simulated, simulated_tournament_count, rate)
  st_size = tournaments_simulated.format
  t_st = simulated_tournament_count.format
  perc = (tournaments_simulated * 100 / simulated_tournament_count).round(2).format(decimal_places: 2)
  left = simulated_tournament_count - tournaments_simulated
  time_left = (left / rate).seconds
  end_time = time_left.from_now.to_s(TIME_FORMAT)
  rate_str = rate.to_i.format
  progress = "\u001b[0K\r#{st_size} / #{t_st} simmed (#{perc}%) #{time_left} left -> #{end_time} (#{rate_str} / s)"
end

total_time = Time.measure do
  path = ARGV.shift
  tournament_count = ARGV.shift.gsub(",", "").gsub("_", "").to_u128
  random_seed_str = ARGV.shift?
  random_seed = random_seed_str ? random_seed_str.to_u32 : Random.new.next_u
  my_main(path, tournament_count, random_seed)
end
puts "took #{total_time} seconds total"
