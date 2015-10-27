number_of_lines = 4
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

ccs = []
raw_input_1.each do |line|
  #puts lines
  lines = line.split(" ")
  ccs << Crowd_control.new(lines[0].to_i, lines[1].to_i, lines[2].to_i)
end
ccs.sort_by! { |cc| cc.begin_time }

# list of severity of cc at the given time
# this is not the optimal solution
# this is pretty horrid, runtime O(n*duration)
cc_severity = []
ccs.each_with_index do |cc, index|
  end_time = cc.begin_time + cc.duration
  (cc.begin_time...end_time).each do |index|
    exisiting_severity = cc_severity[index] || 0
    cc_severity[index] = cc.severity if cc.severity >= exisiting_severity
  end
end

cc_severity.map! {|severity| severity ? severity : 0} # make all ints for simplicty

outputs = []
outputs << [0, cc_severity[0]] unless cc_severity[0] == 0

cc_severity.each_with_index do |severity, index|
  next if index == 0 # skip the first element
  previous_severity = cc_severity[index - 1]
  outputs << [index, severity] unless previous_severity == severity
end
#puts "******"
outputs << [cc_severity.length, 0]
puts outputs.length
outputs.each do |output|
  puts "#{output[0]} #{output[1]}"
end

