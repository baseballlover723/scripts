# require 'colorize'
#
# class String
#   def uncolor
#     replace self.light_black
#   end
# end
#
# class LocalString < String
#   def paint
#     replace self.light_green
#   end
# end
#
# class RemoteString < String
#   def paint
#     replace self.light_red
#   end
# end
#
# class ExternalString < String
#   def paint
#     replace self.light_magenta
#   end
# end
#
# class LongExternalString < String
#   def paint
#     replace self.light_yellow
#   end
# end

class BaseShow
  attr_accessor :name, :path, :seasons

  def initialize(name, path)
    @name = name
    @path = path
    @seasons = {}
  end

  def add_season(season)
    @seasons[season.name] = season
  end

  def method_missing(method, *args)
    return super(method, *args) if @seasons.empty?
    return super(method, *args) unless @seasons.values.first.respond_to? method

    @seasons.values.map(&method).sum
  end

  def respond_to?(method, *args)
    return super(method, *args) if @seasons.empty?
    @seasons.values.first.respond_to? method
  end
end

class BaseSeason
  attr_accessor :show, :name, :path, :episodes

  def initialize(show, name, path)
    @show = show
    @name = name
    @path = path
    @episodes = {}
    show.add_season self
  end

  def add_episode(episode)
    @episodes[episode.name] = episode
  end

  def method_missing(method, *args)
    return super(method, *args) if @episodes.empty?
    return super(method, *args) unless @episodes.values.first.respond_to? method

    @episodes.values.map(&method).sum
  end

  def respond_to?(method, *args)
    return super(method, *args) if @episodes.empty?
    @episodes.values.first.respond_to? method
  end
end

class BaseEpisode
  attr_accessor :season, :name, :path

  def initialize(season, name, path)
    @season = season
    @name = name
    @path = path
    season.add_episode self
  end

  def to_s
    "Episode: #{name}"
  end
end

class Show < BaseShow
end

class Season < BaseSeason
end

class Episode < BaseEpisode
end
