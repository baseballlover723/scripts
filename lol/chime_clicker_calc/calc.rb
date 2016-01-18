SCALE = 0.1

NAMES = ["Relic Shiled", "Ancient Coin", "SpellThiefs edge",
"boots", "health", "damage", "attack speed"]
MEEPS = 15_000


ITEMS = [
    [25,0,0,2,100],
    [0,5,0,2,200],
    [0,0,100,2,100],
    [0,15,0,5,0],
    [80,0,0,1,0],
    [0,2,200,1,0],
    [0,0,20,6,0]
]
INITIAL_COST = [250, 250, 250, 750, 750, 3000, 3000]
ITEM_COUNT = [50,40,125,135,30,100,108]

GOLD = 71_000_000
def calc(index)
  item = ITEMS[index]
  gold = GOLD
  damage = 0
  speed = 0
  ITEMS.zip(ITEM_COUNT).each do |item, count|
    damage += item[2] * count
    speed += item[3] * count
  end
  damage += 2 * MEEPS
  cost = INITIAL_COST[index]
  ITEM_COUNT[index].times do |numb|
    cost += INITIAL_COST[index] * SCALE * (numb + 1)
  end
  numb = ITEM_COUNT[index]
  diff = 0
  while true
    if gold < cost
      break
    end
    gold -= cost
    cost += INITIAL_COST[index] * SCALE * (numb + 1)
    numb += 1
    diff += 1
  end

  damage += item[2] * diff
  speed += item[3] * diff

  return {index: NAMES[index], dps: damage * speed ,buy: diff}

end

dpss = [calc(0), calc(1), calc(2), calc(3), calc(4), calc(5), calc(6) ]
dpss.sort! {|x,y| y[:dps] <=> x[:dps]}
puts dpss