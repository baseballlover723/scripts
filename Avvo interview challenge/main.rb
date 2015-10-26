directory_name = 'Avvo interview challenge/'
load directory_name + 'card.rb'
load directory_name + 'deck.rb'
load directory_name + 'set.rb'


card1 = Card.new(:red, :squiggle, :solid, 2)
card2 = Card.new(:green, :diamond, :solid, 1)
card3 = Card.new(:purple, :oval, :solid, 3)
card2_not_set = Card.new(:green, :squiggle, :solid, 1)

puts card1.inspect
puts Set.is_a_set?(card1, card2, card3)