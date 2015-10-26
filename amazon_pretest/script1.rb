@array1 = [
    ["1", "2"],
    ["3", "4"]
]

@array2 = [
    ["1", "2", "3", "4"],
    ["5", "6", "7", "8"],
    ["9", "10", "11", "12"],
    ["13", "14", "15", "16"]
]

@array3 = [
    ["1", "2", "3", "4", "5", "6"],
    ["7", "8", "9", "10", "11", "12"],
    ["13", "14", "15", "16", "17", "18"],
    ["19", "20", "21", "22", "23", "24"],
    ["25", "26", "27", "28", "29", "30"],
    ["31", "32", "33", "34", "35", "36"]
]

@array4 = [
    ["1", "2", "3"],
    ["4", "5", "6"],
    ["7", "8", "9"],
    ["10", "11", "12"]
]

def gen_array(n)
  numb = 0
  n.times do
    print '['
    n.times do
      numb += 1
      print '"'
      print numb
      print '", '
    end
    print '],'
    print "\n"
  end
end

# gen_array(6)

@rows = 6
@array = @array3
@cols = @array[0].count

def rotate_down_left_side
  #left side, swapping down
  x=0
  starting_y = 0
  ending_y = @cols-1
  # to get the inner rotations
  while ending_y - starting_y > 0 do
    for y in starting_y...(ending_y)
      swap(x, y, x, y+1)
    end
    x+=1
    starting_y += 1
    ending_y -= 1
  end
end

def rotate_right_bottom_side
  #bottom side, swapping right
  y = @cols-1
  starting_x = 0
  ending_x = @rows - 1
  # to get the inner rotations
  while ending_x - starting_x > 0 do
    for x in starting_x...ending_x
      swap(x, y, x+1, y)
    end
    y-=1
    starting_x += 1
    ending_x -= 1
  end
end

def rotate_up_right_side
  # right side, swapping up
  x = @cols-1
  starting_y = @rows - 1
  ending_y = 1
  # to get the inner rotations
  # reversed since its going up the array (index going down)
  while starting_y - ending_y >= 0 do
    (starting_y).downto(ending_y).each do |y|
      swap(x, y, x, y-1)
    end
    x-=1
    starting_y -= 1
    ending_y += 1
  end
end

def rotate_left_top_side
  # top side, swapping left and 1 short
  y = 0
  starting_x = @cols - 1
  ending_x = 2
  # to get the inner rotations
  while starting_x - ending_x > 0 do
    (starting_x).downto(ending_x).each do |x|
      swap(x, y, x-1, y)
    end
    y+=1
    starting_x -= 1
    ending_x += 1
  end
end

def rotate_clock
  rotate_down_left_side
  rotate_right_bottom_side
  rotate_up_right_side
  rotate_left_top_side
end

def swap(x1, y1, x2, y2)
  tmp = @array[y1][x1]
  @array[y1][x1] = @array[y2][x2]
  @array[y2][x2] = tmp
end

def display_array
  @array.each do |row|
    row.each do |value|
      print "#{value.to_i} "
    end
    puts ""
  end
end

display_array
puts "\ndoing\n"

rotate_clock

display_array

