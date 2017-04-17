puts 'start'
require 'active_support'
require 'active_support/number_helper'


ActiveSupport::Deprecation.silenced = true

def size(numb)
  ActiveSupport::NumberHelper.number_to_human_size(numb, {prefix: :si, precision: 4, strip_insignificant_zeros: false})
end

def numb(numb)
  ActiveSupport::NumberHelper.number_to_human(numb, {precision: 4, strip_insignificant_zeros: false, units: {unit: 'm', thousand: 'km'}})
end

def duration(numb)
  numb *= 1000
  ending = 'ms'
  # [[1000.0, 'sec  '], [60.0, 'min  '], [60.0, 'hours'], [24, 'days '], [365.25, 'years']].each do |limit, suffix|
  [[1000.0, 'sec'], [365.25*24 * 60 * 60, 'years']].each do |limit, suffix|
    break if numb < limit * 7 || (suffix == 'sec' && numb < limit)
    numb /= limit
    ending = suffix
  end
  # numb /= 1000.0 and ending = 'sec' if numb > 1000
  # numb /= 60.0 and ending = 'min' if numb > 60
  # numb /= 24.0 and ending = 'days' if numb > 24
  # numb /= 365.25 and ending = 'min' if numb > 365.25

  ActiveSupport::NumberHelper.number_to_rounded(numb, {strip_insignificant_zeros: false, delimiter: ','}) + ' ' + ending
end


radius = 6371_000
puts "radius of the earth = #{radius} m"

curved_distances = [1_000, 20_000, 2994_000]
names = ['Rob', 'Chuck', 'Andrew']
curved_distances.zip(names).each do |curved_distance, name|
  puts ''
  puts ''
  puts name + ' ***************************************************************************'
  θ = curved_distance / radius.to_f # radians
  deg = θ * 180 / Math::PI

  smoke_height = (radius / Math.cos(θ)) - radius
  smoke_speed = 0.5 # m/s
  smoke_rise_time = smoke_height / smoke_speed

  puts "curved distance = #{numb curved_distance}"
  # puts "θ = #{θ} rad"
  # puts "deg = #{deg}"
  puts "smoke height = #{numb smoke_height}"
  puts "smoke rise time = #{duration smoke_rise_time}"
  # puts ''

  bandwidth = 2

  running_speed = 3 # m/s
  resting_time = curved_distance / 10_000 * 15 * 60
  running_time = curved_distance / running_speed + resting_time

  # puts "bit transmit time = #{bit_transmit_time} s"
  # puts "bandwidth = #{bandwidth} b/s"
  puts "resting time = #{duration resting_time}"
  puts "running time = #{duration running_time}"
  puts ''

  file_sizes = [0.018, 44.4, 8_000] # KB
  file_sizes.each do |file_size|
    file_size *= 1_000
    print "file_size = #{size file_size}: "
    bits = file_size * 8
    transmition_time = bits / bandwidth
    print "transmition time = #{duration transmition_time} * "
    print "end to end time = #{duration smoke_rise_time + transmition_time}"
    puts ''

    encoded_size = bits / 4 * 5
    writing_bandwidth = 1 * 8
    transmition_time = encoded_size / writing_bandwidth
    print "runner               "
    print "transmition time = #{duration transmition_time} * "
    print "end to end time = #{duration running_time + transmition_time}"
    puts ''
  end

end
puts 5/4