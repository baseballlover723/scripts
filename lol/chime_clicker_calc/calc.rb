# gem 'actionview', '~> 4.2', '>= 4.2.5'
require 'action_view'
puts
NUMBER_HELPER = ActionView::Base.new
SCALE = 0.1

NAMES = ["Relic Shiled", "Ancient Coin", "SpellThiefs edge",
         "boots", "health", "damage", "attack speed"]
MEEPS = 3_400_000


ITEMS = [
    [25, 0, 0, 2, 100],
    [0, 5, 0, 2, 200],
    [0, 0, 100, 2, 100],
    [50, 50, 100, 5, 0],
    [340, 5, 0, 5, 0],
    [0, 5, 850, 5, 0],
    [50, 5, 150, 20, 0]
]
INITIAL_COST = [250, 250, 250, 750, 750, 3000, 3000]
ITEM_COUNT = [50, 40, 325, 5135, 4030, 1250, 3308]

GOLD = 1_535_000_000_000
BUY = {"Relic Shiled" => 0, "Ancient Coin" => 0, "SpellThiefs edge" => 0,
       "boots" => 0, "health" => 0, "damage" => 0, "attack speed" => 0}

def calc(index)
  item = ITEMS[index]
  gold = GOLD
  damage = 0
  speed = 0
  defense = 0
  move = 0
  ITEMS.zip(ITEM_COUNT).each do |item, count|
    damage += item[2] * count
    speed += item[3] * count
    defense += item[0] * count
    move += item[1] * count
  end
  damage += 2 * MEEPS
  cost = INITIAL_COST[index]
  ITEM_COUNT[index].times do |numb|
    cost += INITIAL_COST[index] * SCALE * (numb + 1)
  end
  numb = ITEM_COUNT[index]
  diff = 0
  dps = damage * speed
  cps = defense * move
  while true
    if gold < cost || diff > 999
      break
    end
    gold -= cost
    cost += INITIAL_COST[index] * SCALE * (numb + 1)
    numb += 1
    diff += 1
  end

  damage += item[2] * diff
  speed += item[3] * diff
  defense += item[0] * diff
  move += item[1] * diff

  return {dps_str: NUMBER_HELPER.number_to_human(damage * speed),
          cps_str: NUMBER_HELPER.number_to_human(defense * move),
          dcps_diff: ((damage*speed - dps) / dps.to_f + (defense*move - cps) / cps.to_f).round(3),
          dps_diff: ((damage*speed - dps) / dps.to_f).round(3),
          cps_diff: ((defense*move - cps) / cps.to_f).round(3),
          name: NAMES[index],
          ending_gold: gold,
          buy: diff, dps: damage * speed, cps: defense * move, index: index,

  }

end

while GOLD > 0
  dpss = [calc(0), calc(1), calc(2), calc(3), calc(4), calc(5), calc(6)]
  dpss.sort! { |x, y| y[:dcps_diff] <=> x[:dcps_diff] }
  unless dpss[0][:buy] > 0
    break;
  end
  BUY[dpss[0][:name]] += dpss[0][:buy]
  puts dpss[0].to_s
  index = dpss[0][:index]
  GOLD = dpss[0][:ending_gold]
  ITEM_COUNT[index] += dpss[0][:buy]
end
puts BUY
