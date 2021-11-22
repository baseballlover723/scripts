users = ["A", "B", "C", "D", "E", "F"]

n = users.size

n.times do |i|
  puts "\n#{i+1} users"
  users
  .first(i + 1)
  .each_combination(2, reuse: true)
  .each_with_index do |(white, black), i|
    puts "#{white} v #{black}"
  end
end


def any_loose_first(numb_users, index)
  i = 0
  return true if index == i

  (0...numb_users).reverse_each do |add|
    i += add
    return true if index == i
  end
  false
end

#  Array.each_product(Array.new(numb_matches, Result.values), reuse: true) do |results|

puts "\n\n**********************\n\n"
users
.each_combination(2, reuse: true)
.each_with_index do |(white, black), i|
  puts "#{white} v #{black}: #{any_loose_first(users.size, i)}"
end


