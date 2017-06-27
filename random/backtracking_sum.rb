array = [1,3,4,5]

def calc(so_far, sum, array, d)
  puts "#{so_far}, #{sum}, #{array}"
  return so_far if sum == d
  return false if array.empty?
  return calc(so_far.dup << array.first, sum + array.first, array.drop(1), d) || calc(so_far.dup, sum, array.drop(1), d)

end
puts calc([], 0, array, 11).to_s