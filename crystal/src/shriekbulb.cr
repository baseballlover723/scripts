require "big"

SIZE_X  = 6
SIZE_Y  = 6
SIZE_SQ = SIZE_X * SIZE_Y
DUKES_NEEDED = 4
# MAX_DUKE = 3
# MAX_DUKE = SIZE_SQ // 2 + 3
MAX_DUKE = SIZE_SQ
# TODO convert to tuples
GARDEN  = ->{ Array.new(SIZE_Y) { |i| Array.new(SIZE_X) { |j| false } } }


class Shriekbulb
  # TODO multithread
  # TODO have a different list for each number of dukes
  @@max_gardens = [] of Array(Array(Bool))
  @@max_possible_shriekbulbs = 0
  @@update_time = 0.25
  # @@update_time = 1
  @@last_time = Time.monotonic
  @@dukes = 0

  @[NoInline]
  def main
    start = Time.monotonic
    generate_gardens do |garden, dukes|
      possible_shriekbulbs = count_possible_shriekbulbs(garden)
      if possible_shriekbulbs > @@max_possible_shriekbulbs
        @@max_possible_shriekbulbs = possible_shriekbulbs
        @@dukes = dukes
        @@max_gardens.clear
      end
      if @@dukes == dukes && possible_shriekbulbs == @@max_possible_shriekbulbs
        @@max_gardens << garden
      end
    end

    duration = Time.monotonic - start
    puts "\ndone calculating max possible shriekbulbs orentiations"
    puts "Gardens*****************\n\n"
    @@max_gardens.reverse.each do |garden|
      print_garden garden
    end
    puts "max_possible_shriekbulbs: #{@@max_possible_shriekbulbs} using #{@@dukes} dukes, there are #{@@max_gardens.size.format('.', ',')} ways to do that"
    puts "took #{duration} seconds"
  end

  @[NoInline]
  def print_updates(number_of_dukes : Int, current_combination : BigInt, total_combinations : BigInt, force = false) : Nil
    duration = Time.monotonic - @@last_time
    return if (!force && duration.total_seconds < @@update_time)

    percent = 100 * current_combination / total_combinations
    str = String.build do |str|
      str << "\r                                                                                                    \r"
      str << "number_of_dukes: #{number_of_dukes} / #{MAX_DUKE}. combo: #{current_combination.format('.', ',')} / #{total_combinations.format('.', ',')} (#{percent.round(4)}%)"
    end
    print str
    STDOUT.flush
    @@last_time = Time.monotonic
  end

  @[NoInline]
  def generate_gardens(&block)
    (DUKES_NEEDED..MAX_DUKE).each do |dukes|
      combinations = SIZE_SQ.combination(dukes)
      print_updates(dukes, 0.to_big_i, combinations.to_big_i, true)
      (0...SIZE_SQ).to_a.each_combination(dukes).with_index do |combo, i|
        print_updates(dukes, i.to_big_i, combinations.to_big_i)
        yield generate_garden(combo), dukes
      end

      print_updates(dukes, combinations.to_big_i, combinations.to_big_i, true)
      break if @@dukes + @@max_possible_shriekbulbs >= SIZE_SQ
    end
  end

  @[NoInline]
  def generate_garden(indexes : Array(Int)) : Array(Array(Bool))
    garden = GARDEN.call
    # puts indexes
    indexes.each do |index|
      row = index // SIZE_X
      col = index % SIZE_X
      garden[row][col] = true
    end

    garden
  end

  @[NoInline]
  def count_possible_shriekbulbs(garden : Array(Array(Bool))) : Int
    count = 0
    garden.size.times do |y|
      garden[y].size.times do |x|
        next if garden[y][x]
        count += 1 if count_dukes(garden, x, y) >= DUKES_NEEDED
      end
    end

    count
  end

  @[NoInline]
  def count_dukes(garden : Array(Array(Bool)), x : Int, y : Int) : Int
    dukes = 0
    xs = {x - 1, x, x + 1}.select { |i| i >= 0 && i < SIZE_X }
    ys = {y - 1, y, y + 1}.select { |i| i >= 0 && i < SIZE_Y }
    xs.each do |x1|
      ys.each do |y1|
        next if x1 == x && y1 == y
        dukes += 1 if garden[y1][x1]
      end
    end

    dukes
  end

  @[NoInline]
  def print_garden(garden : Array(Array(Bool)))
    str = ""

    # str += get_indexes(garden).to_s
    str += "\n"

    garden.each do |row|
      row.each do |duke|
        str += duke ? "x" : "-"
      end
      str += "\n"
    end
    str += "\n"
    puts str
  end

  def get_indexes(garden : Array(Array(Bool)))
    indexes = [] of Int32

    i = 0
    garden.each do |row|
      row.each do |bool|
        indexes << i if bool
        i += 1
      end
    end

    indexes
  end
end

struct Int
  @[NoInline]
  def permutation(k)
    (self - k + 1..self).product(1.to_big_i).to_big_i
  end

  @[NoInline]
  def combination(k)
    (self.permutation(k) / (1..k).product(1.to_big_i)).to_big_i
  end
end

Shriekbulb.new.main
# ["a", "b", "c"].each.with_index do |o, i|
#   puts "object: #{o} index: #{i}"
# end
# puts "combinations size: #{(0...SIZE_SQ).to_a.combinations(6).size}"
# puts 1
# current_combination = 28_448_628.to_big_i
# puts 2
# total_combinations = SIZE_SQ.combination(10)
# puts 3
# puts typeof(current_combination)
# a = current_combination * 100
# puts 4
# percent = current_combination * 100 / total_combinations
# puts 5

# str = String.build do |str|
#   str << "\r                                                                                                    \r"
#   str << "number_of_dukes: #{10} / #{MAX_DUKE}. combo: #{current_combination.format('.', ',')} / #{total_combinations.format('.', ',')} (#{percent.round(4)}%)"
# end

# puts str

# 3x3 grid
# line:   [3,4,5]: [{0,1}, {1,1}, {2,1}]
# column: [1,4,7]: [{1,0}, {1,1}, {1,2}]
