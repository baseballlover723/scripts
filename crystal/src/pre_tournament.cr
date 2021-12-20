require "dotenv"
Dotenv.load
require "option_parser"
require "http/client"
require "myhtml"
require "google_spreadsheets"
require "colorize"

EVENTS_URL = "https://www.uschess.org/msa/MbrDtlTnmtHst.php?"
PAGE_URL   = "https://www.uschess.org/msa/MbrDtlMain.php?"

PREFIXES = %w(dr. mr. ms. mrs.)
SUFFIXES = %w(jr. sr. ii iii iv v vi vii)

enum TimeControl
  Regular
  Quick
  Blitz
  RegularOnline
  QuickOnline
  BlitzOnline

  def online
    case self
    when Regular
      RegularOnline
    when Quick
      QuickOnline
    when Blitz
      BlitzOnline
    else
      self
    end
  end

  def others : Array(TimeControl)
    case self
    in Regular
      [RegularOnline, Quick, Blitz, QuickOnline, BlitzOnline]
    in Quick
      [QuickOnline, Regular, Blitz, RegularOnline, BlitzOnline]
    in Blitz
      [BlitzOnline, Quick, Regular, QuickOnline, RegularOnline]
    in RegularOnline
      [Regular, QuickOnline, BlitzOnline, Quick, Blitz]
    in QuickOnline
      [Quick, RegularOnline, BlitzOnline, Regular, Blitz]
    in BlitzOnline
      [Blitz, QuickOnline, RegularOnline, Quick, Regular]
    end
  end
end

alias Elo = UInt16?
alias EloRatings = Hash(TimeControl, Elo)

struct Event
  property event_id : UInt64
  property event_name : String
  property before_ratings : EloRatings
  property after_ratings : EloRatings

  def initialize(@event_id, @event_name, @before_ratings, @after_ratings)
  end
end

struct Player
  property id : String
  property name : String
  property username : String
  property ratings : EloRatings

  def initialize(@id, @name, @username, @ratings : EloRatings)
  end

  def url
    PAGE_URL + id
  end

  def to_s(time_control : TimeControl)
    "#{(ratings[time_control] || "Unr.").colorize(:green)} #{name.colorize(:light_magenta)} (#{username.colorize(:cyan)}): #{url}"
  end
end

def my_main(google_sheet_link : String, section : String)
  players = [] of Player
  time_control = TimeControl::RegularOnline

  id = google_sheet_link.match(/\/d\/(.*)\/edit/).try(&.[1]) || raise "Couldn't extract google sheets id from #{google_sheet_link}"
  spreadsheet = GoogleSpreadsheets::Spreadsheet.new(id, ENV["GOOGLE_API_KEY"])
  sheet = spreadsheet.worksheets.first
  cells = sheet.get("a2:e9999").values.select { |row| row[3] == section }

  player_channel = Channel(Player).new
  cells.each do |row|
    spawn do
      name = parse_name(row[0].as(String))
      username = row[1].as(String)
      id = row[2].as(String)
      player = lookup_id(name, username, id)
      player_channel.send(player)
    end
  end
  cells.each do |_|
    players << player_channel.receive
  end

  sorted_players = players.sort_by { |p| p.ratings[time_control] || 0 }.reverse

  puts "\n********************\n"
  sorted_players.each_with_index do |player, rank|
    puts "#{(rank + 1).to_s.rjust((players.size + 1).to_s.size, ' ')}: #{player.to_s(time_control)}"
  end
end

def lookup_id(name : String, username : String, id : String)
  response = HTTP::Client.get(EVENTS_URL + id)
  puts "name: #{name}, page: 1, status: #{response.status_code}" if response.status_code != 200
  html = Myhtml::Parser.new(response.body)
  player = parse_live_ratings(name, id, username, html)
end

def parse_live_ratings(name : String, id : String, username : String, html : Myhtml::Parser) : Player
  # name = parse_name(id, html.css("font b").first.inner_text)
  number_of_pages = Math.max(html.css("table nobr a").size, 1)

  events = [] of Event
  events_channel = Channel(Array(Event)).new
  (2..number_of_pages).each do |page|
    spawn do
      response = HTTP::Client.get("#{EVENTS_URL}#{id}.#{page}")
      puts "name: #{name}, page: #{page}, status: #{response.status_code}" if response.status_code != 200
      page_html = Myhtml::Parser.new(response.body)
      events_channel.send(parse_events_page(page_html))
    end
  end
  events.concat(parse_events_page(html))
  (number_of_pages - 1).times do |_|
    events.concat(events_channel.receive)
  end

  ratings = {} of TimeControl => Elo
  sorted_events = events.to_a.sort_by { |e| e.event_id }.reverse
  sorted_events.each do |event|
    event.after_ratings.each do |time_control, rating|
      ratings[time_control] = rating unless ratings.has_key?(time_control)
    end
  end

  TimeControl.values.each do |time_control|
    next if ratings.has_key?(time_control)
    seeded_time_control = time_control.others.find { |tc| ratings.has_key?(tc) }
    ratings[time_control] = ratings[seeded_time_control] if seeded_time_control
  end

  Player.new(id, name, username, ratings)
end

def parse_name(id : String, raw_name : String)
  names = parse_name(raw_name.lchop("#{id}: "))
end

def parse_name(raw_name : String)
  names = raw_name.downcase.split(' ')
  names.shift if PREFIXES.includes?(names.first)
  names.pop if SUFFIXES.includes?(names.last)
  "#{names.first.capitalize} #{names.last.capitalize}"
end

def parse_events_page(html : Myhtml::Parser) : Array(Event)
  multiple_pages = !html.css("b b").empty?
  table = html.nodes(:table).find do |table_node|
    first_cells = table_node.css("tr td")
    next false if first_cells.empty?
    first_cells.first.inner_text.matches?(/(Event ID|Events \d+ thru \d+:)$/)
  end
  raise "could not find table on tournament history page" if table.nil?
  rows = table.scope.nodes(:tr).skip(multiple_pages ? 2 : 1)
  rows.map { |h| parse_event(h) }.to_a
end

def parse_event(html : Myhtml::Node) : Event
  cells = html.scope.nodes(:td).to_a
  id_text = cells[0].scope.nodes(:small).first.inner_text
  id = id_text[0...id_text.index(' ')].to_u64
  event_name = cells[1].scope.nodes(:a).first.inner_text
  before_ratings = {} of TimeControl => Elo
  after_ratings = {} of TimeControl => Elo
  parse_event_rating(before_ratings, after_ratings, cells[2], TimeControl::Regular)
  parse_event_rating(before_ratings, after_ratings, cells[3], TimeControl::Quick)
  parse_event_rating(before_ratings, after_ratings, cells[4], TimeControl::Blitz)

  Event.new(id, event_name, before_ratings, after_ratings)
end

def parse_event_rating(before_ratings : EloRatings, after_ratings : EloRatings, html : Myhtml::Node, time_control : TimeControl) : Void
  text = html.inner_text
  return unless text.includes?("=>")
  online = text.starts_with?("ONL:")
  time_control = online ? time_control.online : time_control
  text = text.lchop("ONL:")
  before, after = text.split("=>").map { |str| str.match(/\d+/).try(&.[0]).try(&.strip).try(&.to_u16) }
  before_ratings[time_control] = before if before
  after_ratings[time_control] = after if after
end

google_sheet_link = nil
section = "Under 1100"

OptionParser.parse do |parser|
  parser.banner = "Usage: pre_tournament [arguments]"
  parser.on("-g EVENTS_URL", "--google-sheet=EVENTS_URL", "Google sheet of player ids") { |url| google_sheet_link = url }
  parser.on("-s SECTION", "--section=SECTION", "Specifies the section to look at") { |s| section = s }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

if google_sheet_link.nil?
  STDERR.puts "google_sheet is required"
  exit(1)
else
  start = Time.monotonic
  my_main(google_sheet_link.as(String), section)
  fin = Time.monotonic
  puts "Took: #{fin - start}"
end
