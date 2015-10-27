number_of_lines = 5
raw_input_1 = [
    "2 4 5",
    "8 1 1",
    "3 4 2",
    "4 1 6"
]
raw_input_2 = [
    "0 2 3",
    "2 3 4",
    "5 2 2"
]

raw_input_3 = [
    "1 2 3",
    "2 3 3",
    "1 5 3",
    "6 2 3",
    "6 1 3"
]
class Crowd_control
  attr_accessor :begin_time, :duration, :severity

  def initialize(begin_time, duration, severity)
    @begin_time = begin_time
    @duration = duration
    @severity = severity
  end

  def to_s
    return "[#{@begin_time}, #{@duration}, #{@severity}]"
  end
end

class Interval
  attr_accessor :begin, :end, :value

  def initialize(param_begin, param_end, value)
    @begin = param_begin
    @end = param_end
    @value = value
  end

  def combine(interval)
    # puts to_s
    # puts interval.to_s
    return false if @end <= interval.begin && @value != interval.value
    has_higher_severity = @value > interval.value
    intervals = []
    if @value == interval.value
      intervals << Interval.new(@begin, [@end, interval.end].max, @value)
      return intervals
    end
    if has_higher_severity
      if @end > interval.end
        intervals << self
      else
        intervals << Interval.new(@begin, @end, value)
        intervals << Interval.new(@end, interval.end, interval.value)
      end
    else
      intervals << Interval.new(@begin, interval.begin, @value)
      intervals << interval
      if @end > interval.end
        intervals << Interval.new(interval.end, @end, @value)
      end
    end
    intervals
  end

  def to_s
    return "[#{@begin} - #{@end} = #{@value}]"
  end
end

def sorted_insert(array, inserting_interval)
  index = (array.rindex { |interval| inserting_interval.begin > interval.begin } || -1) + 1
  array.insert(index, inserting_interval)
end

intervals = []
index = 0
number_of_lines.times do
  lines = raw_input_3[index]
  # puts lines
  lines = lines.split(" ")
  # intervals << Crowd_control.new(lines[0].to_i, lines[1].to_i, lines[2].to_i)
  intervals << Interval.new(lines[0].to_i, lines[0].to_i + lines[1].to_i, lines[2].to_i)
  index+=1
end
intervals.sort_by! { |cc| cc.begin }

# intervals.each do |cc|
#   puts cc.to_s
# end
# puts "*******"
index = 0
while intervals.length-1 != index
  interval = intervals[index]
  next_interval = intervals[index+1]
  # puts "!!!!!!!!!!!!!"
  combined_intervals = interval.combine(next_interval)
  # puts combined_intervals.to_s
  if combined_intervals
    intervals.delete_at index
    intervals.delete_at index
    combined_intervals.each do |new_interval|
      sorted_insert(intervals, new_interval)
    end
  end
  # puts "************"
  # intervals.each do |interval|
  #   puts interval.to_s
  # end
  index += 1 unless combined_intervals # can only move on if the intervals are disjoint
end

# puts "************"
# intervals.each do |interval|
#   puts interval.to_s
#   # puts "#{interval.begin} #{interval.value}"
# end

# fill in the intervals where there is no cc
intervals.each_with_index do |interval, index|
  next if index == 0
  previous_interval = intervals[index-1]
  intervals.insert(index, Interval.new(previous_interval.end, interval.begin, 0)) unless previous_interval.end == interval.begin
end
last_interval = intervals.last
intervals << Interval.new(last_interval.end, last_interval.end, 0)

# puts "********"
puts intervals.length
intervals.each do |interval|
  # puts interval.to_s
  puts "#{interval.begin} #{interval.value}"
end
