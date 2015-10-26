@rows = 4
# @array = [
#     ["1", "2", "3", "4"],
#     ["5", "3", "7", "8"],
#     ["9", "10", "11", "12"],
#     ["13", "14", "15", "16"]
# ]

# @array = [
#     ["1", "2", "3"],
#     ["4", "5", "6"],
#     ["5", "8", "9"]
# ]

@array = [
    ["1", "2", "3"],
    ["4", "5", "6"],
    ["7", "8", "2"],
    ["10", "11", "12"]
]
@cols = @array[0].count
@distance = 2

def distance(x, y)
  x.abs + y.abs
end

def generate_offsets
  @offsets = []
  for x in -@distance..@distance do
    for y in -@distance..@distance do
      next if x == 0 && y == 0
      @offsets << {x: x, y: y} if distance(x, y) <= @distance
    end
  end
end

def valid_point?(x, y)
  x >= 0 && x < @rows && y >= 0 && y < @cols
end

def has_dup_within_distance(ori_x, ori_y)
  ori_value = @array[ori_y][ori_x]
  # puts "ori_value = #{ori_value}"
  @offsets.each do |point|
    check_x = ori_x + point[:x]
    check_y = ori_y + point[:y]
    next unless valid_point? check_x, check_y
    # print "(#{point[:x]}, #{point[:y]}) ->  "
    check_value = @array[check_y][check_x]
    # puts "(#{check_x}, #{check_y}) = #{check_value}"
    if ori_value == check_value
      return true
    end
  end
  false
end

def has_dups
  @array.each_with_index do |col, y|
    col.each_with_index do |value, x|
      if has_dup_within_distance x, y
        puts "YES"
        return
      end
    end
  end
  puts "NO"
end
generate_offsets
# @offsets.each do |x|
#   puts x
# end
# has_dup_within_distance 1, 1
has_dups
