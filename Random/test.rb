# ad = 100
# bloodthirst = 1.05
# ie = 2.5
# excitement = 1.3
# q = 1.75
#
# crit = ad * bloodthirst * ie * excitement + ad * bloodthirst * q
# puts crit

# def add(arrs, max, numb)
#   # puts arrs.inspect
#   new_arrs = []
#   arrs.each do |arr|
#     # puts arr.inspect
#     arr.each_with_index do |element, i|
#       if (!arr[i].nil?)
#         max.times do |numb|
#           numb += 1
#           if (element != numb || i==0)
#             new_arr = arr.clone
#             # puts "i: #{i} numb: #{numb}"
#             new_arr.insert(i, numb)
#             new_arrs << new_arr
#           end
#         end
#       end
#       max.times do |numb|
#         numb += 1
#         new_arr = arr.clone
#         # puts "append numb: #{numb}"
#         new_arr << numb
#         new_arrs << new_arr
#       end
#     end
#     # puts ""
#   end
#   numb < 2 ? new_arrs : add(new_arrs, max, numb - 1)
# end
#
# s = "50 48"
# size = s.split(" ")[0].to_i
# seq = s.split(" ")[1].to_i
# arr = []
#
# seq.times do |i|
#   arr << i+1
# end
#
# # temp = [[1, 1, 2], [2, 1, 2], [1, 2, 1], [1, 2, 2]]
# puts add([arr], seq, size - seq).uniq.length
class Integer
  # calculates binomial coefficient of self choose k
  # not recommended for large numbers as binomial coefficients get large quickly... e.g. 100 choose 50 is 100891344545564193334812497256
  def choose(k)
    return 0 if (k > self)
    n = self
    r = 1
    1.upto(k) do |d|
      r *= n
      r /= d
      n -= 1
    end
    return r
  end
end

def naive(s)
  count = 0
  (0..s.length - 4).each do |a|
    (a+1..s.length - 3).each do |b|
      (b+1..s.length - 2).each do |c|
        if (s[b] == s[c])
          (c+1..s.length - 1).each do |d|
            if s[a] == s[d]
              count += 1
            end
          end
        end
      end
    end
  end
  count
end

regex_diff = /(?x)
  (?=
    (?<str>
      (?=
        (?<first>.)
      )
      (?<first1>(\k<first>)+)
      (?<mid1>.*)
      (?=
        (?<sec>
          (?!
            (\k<first>)
          ).
        )
      )
      (?<sec1>(\k<sec>)+)
      (?<mid2>.*?)
      (?<sec2>
        (\k<sec>+)
      )
      (?<mid3>.*?)
      (?<first2>
        (\k<first>+)
      )
    )
  )
  /
regex_same = /(?x)
  (?=
    (?<str>
      (?=
        (?<first>.)
      )
      (?<first1>(\k<first>)+)
      (?<mid1>.*)
      (?=
        (?<sec>.)
      )
      (?<sec1>(\k<sec>)+)
      (?<mid2>.*?)
      (?<sec2>
        (\k<sec>+)
      )
      (?<mid3>.*?)
      (?<first2>
        (\k<first>+)
      )
    )
  )
  /
def count(match)
  if match[:first] == match[:sec]
    match[:first].length + match[:sec].length + match[:sec2].length + match[:first2].length
  else
    match[:first].length + match[:first2].length - 1
  end
end
# TODO if starts with a double, it shows up twice in regex
s = "kkkkkkzjhyukzkzzkkzkzkkkzz"
count = 0
s.enum_for(:scan, regex_diff).map do
  match = Regexp.last_match
  puts match.inspect
  count += count(match)
end
letters = []
s.enum_for(:scan, regex_same).map do
  match = Regexp.last_match
  if (!letters.include?(match[:first]))
    letters << match[:first]
    count += s.count(match[:first]).choose(4)
  end
end
# (0..s.length - 4).each do |a|
#   (a+1..s.length - 3).each do |b|
#     (b+1..s.length - 2).each do |c|
#       if (s[b] == s[c])
#         (c+1..s.length - 1).each do |d|
#           if s[a] == s[d]
#             count += 1
#           end
#         end
#       end
#     end
#   end
# end
puts count % (10**9 + 7)
puts naive s