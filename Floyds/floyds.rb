input_array = [
    [0, 2, false, 1, 8],
    [6, 0, 3, 2, false],
    [false, false, 0, 4, false],
    [false, false, 2, 0, 3],
    [3, false, false, false, 0]
]
class Floyds
  attr_accessor :d

  def initialize(array)
    self.d = [array]
  end

  def add_one
    last = d.last
    length = last.length
    k = d.length - 1
    new = []
    length.times do
      row = []
      length.times do
        row << false
      end
      new << row
    end

    (0...length).each do |x|
      (0...length).each do |y|
        # if x==1 && y==1
        #   puts last.to_s
        #   puts last[y][x]
        #   puts last[k][x]
        #   puts last[y][k]
        #   puts last[k][x] && last[y][k]
        #   puts "#{last[k][x]} && #{last[y][k]}"
        # end

        # puts "#{x} #{y}"
        if last[y][x] && last[k][x] && last[y][k]
          new[y][x] = [last[y][x], last[k][x] + last[y][k]].min
        else
          new[y][x] = last[y][x] if last[y][x]
          new[y][x] = last[k][x] + last[y][k] if (last[k][x] && last[y][k])
        end
      end
    end
# D(k)[i,j] =  min {D(k-1)[i,j],  D(k-1)[i,k]  + D(k-1)[k,j]}
    d << new
  end

  def to_s
    last = d.last.map do |row|
      row.map do |x|
        x = x ? x.to_s : "?"
      end
    end
    str = ""
    last.each do |row|
      str += "#{row.to_s}\n"
    end
    str
  end
end

floyd = Floyds.new(input_array)
puts floyd.d[0].length
floyd.d[0].length.times do
  floyd.add_one
  puts floyd.d.length - 1
  puts floyd.to_s
  puts "*****************"
end
puts floyd.to_s
