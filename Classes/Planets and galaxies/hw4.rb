pi = Math::PI
AU = 1.496 * 10 ** 11
MASS_EARTH = 5.9736 * 10 **24
MASS_SUN = 1.9891*10**30
SECONDS_IN_YEAR = 31557600


while true
  puts "start"
puts "mass in Earth Masses"
mass = gets.to_f
puts "a in AU"
a = gets.to_f
puts "period in years"
period = gets.to_f

answer = 2 * pi * a * AU * mass * MASS_EARTH / (period * SECONDS_IN_YEAR * MASS_SUN)

puts "%E" % answer
end