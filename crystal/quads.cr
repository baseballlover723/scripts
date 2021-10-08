{% if !flag?(:no_color) %}
require "colorize"
{% end %}
require "benchmark"

TIME_FORMAT = "%D %r"
PROGRESS_FPS = 24
#PROGRESS_FPS = 1
RATE_FPS = 1
PROGRESS_REFRESH_TIME = Time::Span.new(nanoseconds: (1_000_000_000 / PROGRESS_FPS).to_i)
RATE_REFRESH_TIME = Time::Span.new(nanoseconds: (1_000_000_000 / RATE_FPS).to_i)

struct Time::Span
  def inspect(io : IO) : Nil
    if to_i < 0 || nanoseconds < 0
      io << '-'
    end

    # We need to take absolute values of all components.
    # Can't handle negative timespans by negating the Time::Span
    # as a whole. This would lead to an overflow for the
    # degenerate case `Time::Span.MinValue`.
    if days != 0
      io << days.abs
      io << '.'
    end

    hours = self.hours.abs
    io << '0' if hours < 10
    io << hours

    io << ':'

    minutes = self.minutes.abs
    io << '0' if minutes < 10
    io << minutes

    io << ':'

    seconds = self.seconds.abs
    io << '0' if seconds < 10
    io << seconds

    nanoseconds = self.nanoseconds.abs
    if nanoseconds != 0
      io << '.'
      io << '0' if nanoseconds < 100000000
      io << '0' if nanoseconds < 10000000
      io << '0' if nanoseconds < 1000000
      io << milliseconds
    end
  end
end

module Iterable(T)
  def sorted?
    each_cons_pair { |a, b|
      return false if a < b
    }
    true
  end
end

class User
  property name : String
  property record : Record

  include Comparable(User)

  def initialize(@name : String)
    @record = Record.new
  end

  def clone
    User.new(name)
  end

  def to_s(io : IO) : Nil
    {% if flag?(:no_color) %}
    io << "#{name} (#{record.wins}-#{record.draws}-#{record.losses})"
    {% else %}
    io << "#{name} (#{record.wins.colorize(:green)}-#{record.draws}-#{record.losses.colorize(:red)})"
    {% end %}
  end

  def <=>(other : User)
    other.record <=> record
  end
end

enum Result
  WhiteWin
  Draw
  BlackWin
end

struct Pairing
  getter white : User
  getter black : User
  getter result : Result

  def initialize(@white : User, @black : User, @result : Result)
  end
end

class Record
  getter games : UInt8
  getter wins : UInt8
  getter draws : UInt8
  getter losses : UInt8

  include Comparable(Record)

  def initialize(@wins : UInt8 = 0, @draws : UInt8 = 0, @losses : UInt8 = 0)
    @games = @wins + @draws + @losses
  end

  def win
    @games += 1_u8
    @wins += 1_u8
  end

  def draw
    @games += 1_u8
    @draws += 1_u8
  end

  def loss
    @games += 1_u8
    @losses += 1_u8
  end

  def points : Float64
    @wins + @draws / 2
  end

  def to_tuple : {UInt8, UInt8, UInt8}
    {wins, draws, losses}
  end

  def <=>(other : Record)
    {points, wins, draws, losses} <=> {other.points, other.wins, other.draws, other.losses}
  end
end

struct Ranking
  property rank : UInt8
  property prize : Float64
  property users : Array(User)

  def initialize(@rank : UInt8, @prize : Float64, @users : Array(User))
  end
end

struct Tournament
  property users : Array(User)
  property ranking : Array(Ranking)
  property prize_format : Array(Float64)

  def initialize(@users : Array(User), @prize_format : Array(Float64))
    @ranking = Array(Ranking).new(@users.size)
    @users.sort!
    @users.each_with_index { |u, i| u.name = ('A' + i).to_s }

    rank = 1_u8
    user_arr = [@users.first]
    @users.each.skip(1).each do |user|
      if user.record.points == user_arr.first.record.points
        user_arr << user
      else
        @ranking << Ranking.new(rank, calc_prize_amount(rank, user_arr), user_arr)
        rank += user_arr.size
        user_arr = [user]
      end
    end
    @ranking << Ranking.new(rank, calc_prize_amount(rank, user_arr), user_arr)
  end

  def rankings
    rank_just = @users.size.to_s.size
    point_just = rank_just + 2
    prize_just = @prize_format.first.round(2).format(decimal_places: 2).size
    @ranking.join do |data|
      rank = data.rank.to_s.ljust(rank_just)
      points = data.users.first.record.points.to_s.ljust(point_just)
      prize = data.prize.round(2).format(decimal_places: 2).ljust(prize_just)
      users = data.users.join(", ")
      "Rank #{rank}: #{points} points, $#{prize} prize for #{users}\n"
    end
  end

  private def calc_prize_amount(rank : UInt8, users : Array(User)) : Float64
    total_prize = @prize_format[(rank-1)...(rank-1+users.size)].sum
    total_prize / users.size
  end
end


def my_main(numb_users : Int32, prize_format : Array(Float64))
  prize_format.concat(Array.new(numb_users - prize_format.size, 0.0)) if prize_format.size < numb_users

  users = Array.new(numb_users) { |i| User.new(('A' + i).to_s) }

  tournaments = [] of Tournament

  tournament_mem = 0
  simulated_tournament_count = Pointer(UInt128).malloc(1, 0)
  generate_time = Time.measure do
    tournament_mem = Benchmark.memory do
      tournaments = generate_tournaments(users, prize_format, simulated_tournament_count)
    end
  end

  puts "tournaments"
  unique_tournaments_size = 0
  tournaments
  .each_with_index do |tournament, i|
    unique_tournaments_size += 1
    puts "\nTournament ##{(i + 1).format}"
    puts tournament.rankings
  end

  puts "\ntook #{generate_time} to generate #{unique_tournaments_size.format} tournaments (#{simulated_tournament_count.value.format} tournaments simulated)"
  puts "Used #{tournament_mem.humanize_bytes(precision: 5)} of memory"
end

def generate_tournaments(users : Array(User), prize_format : Array(Float64), simulated_tournament_count : Pointer(UInt128)) : Array(Tournament)
  record_set = Set(Array(Tuple(UInt8, UInt8, UInt8))).new
  tournaments = [] of Tournament

  numb_matches = (users.size ** 2 - users.size) // 2
  simulated_tournament_count.value = 3_u128 ** numb_matches

  start_time = last_rate_time = Time.local
  tournaments_simulated = last_tournaments_simulated = 0_u128
  current_rate = 1.0
  last_time = Time.local
  old_sync = STDERR.sync?
  STDERR.sync = true
  puts "generating tournaments (#{simulated_tournament_count.value.format} to simulate)"
  Array.each_product(Array.new(numb_matches, Result.values), reuse: true) do |results|
    now = Time.local
    if now - last_time > PROGRESS_REFRESH_TIME
      if now - last_rate_time > RATE_REFRESH_TIME
        tournaments_simulated_since_last_rate = tournaments_simulated - last_tournaments_simulated
        current_rate = tournaments_simulated_since_last_rate / (now - last_rate_time).to_f
        last_tournaments_simulated = tournaments_simulated
        last_rate_time = now
      end

      STDERR.print get_progress_str(tournaments, tournaments_simulated, simulated_tournament_count, current_rate)
      last_time = now
    end
    tournaments_simulated += 1
    users = users.clone
    simulate_tournament(users, results)
    tournament = Tournament.new(users, prize_format)
    if record_set.add?(tournament.users.map(&.record.to_tuple))
      tournaments << tournament
    end
  end
  puts

  STDERR.sync = old_sync
  tournaments.sort_by! do |t|
    {
      t.ranking.map { |r| -r.users.first.record.points },
      t.ranking.map { |r| r.users.map { |u| UInt8::MAX - u.record.wins} },
      -t.ranking.size
    }
  end
end


def simulate_tournament(users, results)
  users
  .each_combination(2, reuse: true)
  .each_with_index do |(white, black), i|
    case results[i]
    when Result::WhiteWin
      white.record.win
      black.record.loss
    when Result::Draw
      white.record.draw
      black.record.draw
    when Result::BlackWin
      white.record.loss
      black.record.win
    end
  end
end

def get_progress_str(tournaments, tournaments_simulated, simulated_tournament_count, rate)
  ut_size = tournaments.size.format
  st_size = tournaments_simulated.format
  t_st = simulated_tournament_count.value.format
  perc = (tournaments_simulated * 100 / simulated_tournament_count.value).round(2).format(decimal_places: 2)
  left = simulated_tournament_count.value - tournaments_simulated
  time_left = (left / rate).seconds
  end_time = time_left.from_now.to_s(TIME_FORMAT)
  rate_str = (rate / 1_000).to_i.format
  progress = "\r#{ut_size} uniq tours #{st_size} / #{t_st} simulated (#{perc}%) #{time_left} left -> #{end_time} (#{rate_str}K / s)"
end

total_time = Time.measure do
  my_main(ARGV.shift.to_i32, ARGV.map(&.to_f64))
end
puts "took #{total_time} seconds total"
