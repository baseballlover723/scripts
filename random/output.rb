class Anime
  # hash associations
  attr_accessor :named_seasons

  # array associations
  attr_accessor :seasons

  # attributes
  attr_accessor :key1
  attr_accessor :key2

  def initialize
    self.named_seasons = {}
    self.seasons = []
  end

  # hash assoications adders and removers
  def add_named_season(named_season_name, named_season)
    named_seasons[named_season_name] = named_season
  end

  # array associations adders and removers
  def add_season(season)
    seasons << season
  end
end

class Seasons
  # attributes
  attr_accessor :season_name
end

class NamedSeasons
  # array associations
  attr_accessor :named_season_name

  def initialize
    self.named_season_name = []
  end

  # array associations adders and removers
  def add_named_season_name(named_season_name)
    named_season_name << named_season_name
  end
end

class NamedSeasonName
  # attributes
  attr_accessor :named_season_name
end

