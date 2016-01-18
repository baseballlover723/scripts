def calc(ad, apen, mpen, tar, tmr)
  target_physical_damage_multiplier = 100 / (100 + tar - apen).to_f
  target_magic_damage_multiplier = 100 / (100 + tmr - mpen).to_f
  p_damage = ad * 0.55 * target_physical_damage_multiplier
  m_damage = ad * 0.55 * target_magic_damage_multiplier
  return p_damage + m_damage
end
tar = 24
tmr = 30

ad = 56 + 14 + 8 + 100
apen = 0
mpen = 0
puts "attack no pen"
puts calc(ad, apen, mpen, tar, tmr)

ad = 56 + 6.8 + 8 + 100
apen = 8.1
mpen = 5.5
puts "hybraid pen"
puts calc(ad, apen, mpen, tar, tmr)

ad = 56 + 6.8 + 8 + 100
apen = 0
mpen = 7.83
puts "magic pen"
puts calc(ad, apen, mpen, tar, tmr)
