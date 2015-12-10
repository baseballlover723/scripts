#naive way is O(n^2)
def hasAllUniqueChars(str)
  has_letter = []
  # for each letter in the alphabet, could be extended to 52 letter or 62 easily
  62.times {has_letter << false}
  str.each_char do |char|
    index = char.ord - 'A'.ord unless char.ord - 'A'.ord < 0 || char.ord - 'A'.ord > 25
    index = char.ord - '0'.ord + 26 unless char.ord - '0'.ord < 0 || char.ord - '0'.ord > 9
    index = char.ord - 'a'.ord + 36 unless char.ord - 'a'.ord < 0 || char.ord - 'a'.ord > 25
    return false if has_letter[index] # converts lowercase letters to their coorisponding index in the array
    has_letter[index] = true
  end
  return true
end
#testing in rubymine
#extending for upper/lower/numbers
# puts hasAllUniqueChars("Ced")
# puts hasAllUniqueChars("Zz")
# puts hasAllUniqueChars("234091")
# puts hasAllUniqueChars("rob4")
# puts hasAllUniqueChars("Bi3loy")
#
# puts ""
#
# puts hasAllUniqueChars("hello")
# puts hasAllUniqueChars("Billo3y")
# puts hasAllUniqueChars("ZZ")
# puts hasAllUniqueChars("zz")
# puts hasAllUniqueChars("99")



