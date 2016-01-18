require 'net/http'
require 'json'
graves_id = 104

class Graves
  attr_accessor :base_stats
  attr_accessor :ad
  attr_accessor :armor
  attr_accessor :mr
  attr_accessor :hp
  attr_accessor :base_attack_speed
  attr_accessor :bonus_attack_speed
  attr_accessor :armor_pen
  attr_accessor :level

  def initialize
    api_key = File.read(File.dirname(__FILE__) << "/secret_api_key.txt")
    uri = URI('https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion/104?champData=stats&api_key=' << api_key)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)
    @base_stats = JSON.parse(response.body)["stats"]
    @ad = @base_stats["attackdamage"]
    @armor = @base_stats["armor"]
    @mr = @base_stats["spellblock"]
    @hp = @base_stats["hp"]
    @base_attack_speed = 0.625 / (1 + @base_stats["attackspeedoffset"]).to_f
    @bonus_attack_speed = 0
    @armor_pen = 5
    @level = 1
    @passive_table = [75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 92, 95, 97, 99, 102, 104, 107, 110]
  end

  def level=(new_level)
    diff = new_level - @level

    @ad += diff * @base_stats["attackdamageperlevel"]
    @armor += diff * @base_stats["armorperlevel"]
    @mr += diff * @base_stats["spellblockperlevel"]
    @hp += diff * @base_stats["hpperlevel"]
    @bonus_attack_speed -= @base_stats["attackspeedperlevel"] * (7 / 400.0 * (@level * @level - 1) + 267/400.0 * (@level - 1))
    @level = new_level
    @bonus_attack_speed += @base_stats["attackspeedperlevel"] * (7 / 400.0 * (@level * @level - 1) + 267/400.0 * (@level - 1))
    @armor_pen += diff * 0.5
  end

  def effective_health
    damage_multi = 100 / (100 + @armor).to_f
    @hp / damage_multi
  end

  def attack_speed
    @base_attack_speed + (@base_attack_speed * @bonus_attack_speed / 100.to_f)
  end

  def output_damage(pelts)
    first = @passive_table[@level-1]
    per_pelt = first / 3.0
    scaling = first + per_pelt * (pelts-1)
    @ad * scaling / 100.0
  end

  def damage(pelts)
    tar = @armor
    damage_multi = 100 / (100 + tar - @armor_pen).to_f
    output_damage(pelts) * damage_multi
  end

  def damages
    [damage(1), damage(2), damage(3), damage(4)]
  end

  def get_damage_diff(ad1, ad2, apen1, apen2, atksped1, atksped2)
    @ad += ad1
    @armor_pen += apen1
    @bonus_attack_speed += atksped1
    damages1 = damages

    @ad += ad2 - ad1
    @armor_pen += apen2 - apen1
    @bonus_attack_speed += atksped2 - atksped1
    damages2 = damages

    diffs = []
    damages1.zip(damages2).each do |d1, d2|
      diffs << d1-d2
    end
    @ad -= ad2
    @armor_pen -= apen2
    @bonus_attack_speed -= atksped2
    diffs
  end
end

graves = Graves.new
ad1 = 9.85
ad2 = [14.35, 9.85, 6.75, 0] #[6.75, 2.25, 0, 14.35, 7.6, 7.6, 0]
apen1 = 0
apen2 = [0, 7.68, 10.24, 17.92] #[10.24, 10.24, 10.24, 0, 0, 7.68, 7.68]
atksped1 = 9
atksped2 =[0, 0, 0, 0] #[0, 9, 13.5, 0, 13.5, 0 , 13.6]

# puts graves.armor_pen
# graves.level = 18
# puts graves.armor_pen
# graves.level = 1
# puts graves.armor_pen

# ad2.zip(apen2, atksped2).each do |ad2, apen2, atksped2|
#   diffs = graves.get_damage_diff ad1, ad2, apen1, apen2, atksped1, atksped2
#   print diffs[-1].round(2)
#   print " "
#
#   graves.level = 6
#   graves.armor_pen += 10
#   diffs = graves.get_damage_diff ad1, ad2, apen1, apen2, atksped1, atksped2
#   print diffs[-1].round(2)
#   print " "
#
#   graves.level = 15
#   graves.armor_pen += 20
#   diffs = graves.get_damage_diff ad1, ad2, apen1, apen2, atksped1, atksped2
#   print diffs[-1].round(2)
#   print " "
#   graves.armor_pen -= 30
#
#   puts ""
# end

graves1 = Graves.new
graves1.armor += 9
graves2 = Graves.new
graves2.hp += 72

(1..18).each do |numb|
  graves1.level = numb
  graves2.level = numb
  puts "#{numb}: #{graves1.effective_health.round(2) - graves2.effective_health.round(2)}"
end