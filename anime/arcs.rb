require 'active_support/core_ext/hash/indifferent_access'

class RangedHash
  def initialize(hash)
    @ranges = hash
  end

  def [](key)
    @ranges.each do |range, value|
      next unless range.is_a? Range
      return value if range.include?(key)
    end
    nil
  end

  def method_missing(meth, *args, &block)
    if @ranges.respond_to?(meth)
      @ranges.send(meth, *args, &block)
    else
      super
    end
  end

  def respond_to?(meth)
    @ranges.respond_to?(meth)
  end
end

ALL_ARCS = {
  Naruto: RangedHash.new(
    {
      1..19 => 'Prologue; Land of Waves',
      20..67 => 'Chūnin Exams',
      68..80 => 'Konoha Crush',
      81..100 => 'Search for Tsunade',
      101..101 => ' filler',
      'movie1' => 'Ninja Clash in the Land of Snow filler',
      102..106 => 'Land of Tea Escort Mission filler',
      107..135 => 'Sasuke Recovery Mission',
      136..141 => 'Land of Rice Fields Investigation Mission filler',
      142..147 => 'Mizuki Tracking Mission filler',
      148..151 => 'Bikōchū Search Mission filler',
      152..157 => 'Kurosuki Family Removal Mission filler',
      158..160 => 'Gosunkugi Capture Mission filler',
      'movie2' => 'Legend of the Stone of Gelel filler',
      161..167 => 'Cursed Warrior Extermination Mission filler',
      168..173 => 'Kaima Capture Mission filler',
      174..176 => 'Buried Gold Excavation Mission filler',
      177..183 => 'Star Guard Mission filler',
      184..186 => ' filler',
      187..191 => 'Peddlers Escort Mission filler',
      192..194 => ' filler',
      195..196 => 'Third Great Beast Arc filler',
      'movie3' => 'Guardians of the Crescent Moon Kingdom filler',
      197..201 => 'Konoha Plans Recapture Mission filler',
      202..207 => 'Yakumo Kurama Rescue Mission filler',
      208..212 => 'Gantetsu Escort Mission filler',
      213..215 => 'Menma Memory Search Mission filler',
      216..220 => 'Sunagakure Support Mission filler',
    }
  ),
  'Naruto; Shippūden': RangedHash.new(
    {
      1..32 => 'Kazekage Rescue Mission',
      33..53 => 'Tenchi Bridge Reconnaissance Mission',
      54..71 => 'Twelve Guardian Ninja',
      72..88 => 'Akatsuki Suppression Mission',
      89..112 => "Three-Tails' Appearance",
      113..118 => 'Itachi Pursuit Mission Pt 1',
      119..120 => ' filler',
      121..126 => 'Itachi Pursuit Mission Pt 2',
      127..133 => 'Tale of Jiraiya the Gallant',
      134..143 => 'Fated Battle Between Brothers',
      144..151 => 'Six-Tails Unleashed',
      152..175 => "Pain's Assault",
      176..196 => 'Past Arc; The Locus of Konoha',
      197..214 => 'Five Kage Summit',
      215..222 => 'Fourth Shinobi World War; Countdown Pt 1',
      223..242 => 'Paradise Life on a Boat',
      243..256 => 'Fourth Shinobi World War; Countdown Pt 2',
      257..260 => ' filler',
      261..289 => 'Fourth Shinobi World War; Confrontation Pt 1',
      290..295 => 'Power filler',
      296..321 => 'Fourth Shinobi World War; Confrontation Pt 2',
      322..348 => 'Fourth Shinobi World War; Climax Pt 1',
      349..361 => "Kakashi's Anbu Arc; The Shinobi That Lives in the Darkness filler",
      362..375 => 'Fourth Shinobi World War; Climax Pt 2',
      376..377 => ' filler',
      378..393 => "Birth of the Ten-Tails' Jinchūriki Pt 1",
      394..413 => "In Naruto's Footsteps; The Friends' Paths filler",
      414..427 => "Birth of the Ten-Tails' Jinchūriki Pt 2",
      428..431 => 'Kaguya Ōtsutsuki Strikes Pt 1',
      432..449 => 'Jiraiya Shinobi Handbook; The Tale of Naruto the Hero filler',
      450..451 => 'Kaguya Ōtsutsuki Strikes Pt 2',
      452..457 => 'Itachi Shinden Book; Light and Darkness filler',
      458..468 => 'Kaguya Ōtsutsuki Strikes Pt 3',
      469..479 => ' filler',
      480..483 => 'Childhood filler',
      484..488 => 'Sasuke Shinden; Book of Sunrise filler',
      489..493 => 'Shikamaru Hiden; A Cloud Drifting in Silent Darkness filler',
      494..500 => 'Konoha Hiden; The Perfect Day for a Wedding'
    }
  ),
  Bleach: RangedHash.new(
    {
      1..20 => 'Agent of the Shinigami',
      21..41 => 'The Sneak Entry',
      42..63 => 'Soul Society; The Rescue',
    }
  ),
  'Fairy Tail': RangedHash.new(
    {
      1..2 => 'Macao',
      3..4 => 'Daybreak',
      5..10 => 'Lullaby',
      11..20 => 'Galuna Island',
      21..29 => 'Phantom Lord',
      30..32 => 'Loke',
      33..40 => 'Tower of Heaven',
      41..51 => 'Battle of Fairy Tail',
      52..68 => 'Oración Seis',
      69..75 => 'Daphne filler',
      76..95 => 'Edolas',
      96..122 => 'Tenrou Island',
      123..124 => 'X791',
      'movie1' => 'The Phoenix Priestess',
      125..150 => 'Key of the Starry Sky filler',
      151..175 => 'Grand Magic Games'
    }
  )
}.with_indifferent_access


















































