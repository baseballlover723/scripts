require 'dotenv/load'
require 'httparty'
require 'parallel'
require 'json'
require 'time'

# DEFAULT_OPTIONS = {reverse_numbs: false, allowed:[], password_lambda: nil, gallery_dl: true, after: nil}
DEFAULT_OPTIONS = {reverse_numbs: false, allowed: [], password_lambda: nil, after: nil}

NAME = ""
QUERY = ""
PAGE_URL = ""
LAST = ""

def main(page_url, query, name, last, options)
  queries = query.is_a?(Array) ? query : [query]
  page_uri = URI(page_url)

  videos = options[:gallery_dl] ? search_gallery_dl(queries, name, last, options) : search(page_uri, queries, name, last, options)
  urls = process_videos(page_uri, videos, name, queries.map { |q| q.gsub(/[^0-9A-Za-z\s]/, '') }, last, options)

  puts "\n**************************\n\n"
  urls.each do |url|
    puts url
  end
  puts "\n**************************\n\n"
end

def search_gallery_dl(queries, name, last, options)
  gallery_dl_dir = ENV["GALLERY_DL"]
  Dir.entries(gallery_dl_dir)
     .select { |info_filename| info_filename.end_with?('.m3u8') }
     .select { |info_filename| queries.all? { |query| info_filename.downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) } }
     .sort
     .reverse
     .map do |info_filename|
    infos = File.basename(info_filename, File.extname(info_filename)).split("$$")
    {"title" => infos[1], "file" => {"path" => File.join(gallery_dl_dir, info_filename)}}
  end
end

def search(page_uri, queries, name, last, options)
  # page_uri.path = "/api/v1" + page_uri.path
  page_uri.path = "/api/v1" + page_uri.path + "/posts"

  videos = []
  offset = 0
  while true
    # page = HTTParty.get(page_uri, query: {q: queries[0], o: offset}).parsed_response
    page = JSON.parse(HTTParty.get(page_uri, query: {q: queries[0], o: offset}, headers: {Accept: 'text/css'}).parsed_response)
    puts page_uri
    # puts "page (#{page.class}): #{page}"
    videos.concat(page)
    break if page.size < 50 || compare(last, get_last_filename(name, page, queries.map { |q| q.gsub(/[^0-9A-Za-z\s]/, '') }, options)) <= 0
    offset += 50
  end

  videos
end

def process_videos(page_uri, videos, name, queries, last, options)
  videos = videos.reverse.drop_while do |video|
    if options[:after] && options[:after] > Time.parse(video["published"])
      puts "dropping #{video["title"]} @ #{video["published"]}"
      next true
    end

    extracted, filename = extract_filename(name, video["title"], options)
    puts "extracted: #{extracted}, filename: #{filename}, title: #{video["title"]}"
    !extracted || !queries.all? { |query| video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) } || compare(last, filename) <= 0 || video["title"].downcase.include?("code")
  end.select do |video|
    # puts "#{video["title"]}: include query: #{video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query)}, 2nd: #{!(video["file"].empty? && video["embed"])}"
    queries.all? { |query| video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) } && !video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?("fate")
  end
  # Parallel.map(videos, in_threads: 8) do |video|
  Parallel.map(videos, in_threads: 4) do |video|
    # videos.map do |video|
    _, filename = extract_filename(name, video["title"], options)
    filename = filename.strip
    puts "video: #{video["title"]}, filename: #{filename}"
    extract_link(page_uri, video, filename, options)
  end.compact
end

def extract_link(page_uri, video, filename, options)
  url, res = if !video["file"].empty?
    if video["file"]["path"].end_with?(".txt")
      extract_k_link(page_uri, video["file"]["path"])
    elsif video["file"]["path"].end_with?(".m3u8")
      extract_local_link(video["file"]["path"])
    elsif video["file"]["path"].end_with?(".mp4")
      extract_mp4_link(video["file"]["path"])
    else
      extract_url(video["embed"]["url"], options) || extract_url(video["content"], options)
    end
  else
    extract_url(video["embed"]["url"], options) || extract_url(video["content"], options)
  end

  return if url.nil?
  url += "#filename=#{filename}"
  if !res.nil? && !res.include?("1080")
    url += " (#{res})"
  end
  url += ".mp4"

  if options[:gallery_dl]
    url += "#forced_referer=aHR0cHM6Ly93d3cucGF0cmVvbi5jb20v"
  end

  url = "\"#{url}\"," if options[:allowed].include?("yt-dlp") || options[:allowed].include?("vimeo_protected")

  return url unless options[:password_lambda] && filename[/S\d\dE\d\d/]

  season_number = filename[/S\d\d/][/\d\d/].to_i
  episode_numbers_str = filename[/E.+$/]
  episode_numbers = episode_numbers_str.scan(/\d+/).map(&:to_i)
  episode_range = (episode_numbers.min)..(episode_numbers.max)
  url += "#password=#{options[:password_lambda].call(season_number, episode_range)}"

  url
end

def extract_url(url, options)
  return nil if url.nil?
  if url.include?("google")
    extract_g_link(url, options)
  elsif url.include?("streamable")
    extract_s_link(url)
  elsif url.include?("dropbox")
    extract_d_link(url, options)
  elsif url.include?("vimeo")
    extract_v_link(url, options)
  elsif url.include?("mediadelivery")
    extract_dlp_link(url, options)
  elsif url.include?("youtube") || url.include?("youtu.be")
    extract_y_link(url, options)
  else
    nil
  end
end

def compare(last, filename)
  puts "filename: #{filename}"
  number = filename.split(' ')[-1]
  number <=> last
end

def get_last_filename(name, page, queries, options)
  page.reverse_each do |video|
    extracted, filename = extract_filename(name, video["title"], options)
    next if !queries.all? { |query| video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) }
    return filename if extracted
    puts "cont"
  end
end

def extract_mp4_link(url)
  # ["https://kemono.cr/" + url, nil]
  ["https://pawchive.pw" + url, nil]
end

def extract_g_link(url, options)
  u = url[/(https:\/\/drive\.google\.com.*?)("|<\/a|$)/, 1]
  options[:allowed].include?("drive") ? [u, nil] : [u, "drive"]
end

def extract_d_link(url, options)
  options[:allowed].include?("dropbox") ? [url, nil] : [url, "dropbox"]
end

def extract_v_link(url, options)
  if options[:allowed].include?("vimeo_protected")
    u = url.gsub('vimeo.com', 'player.vimeo.com/video')
    options[:allowed].include?("vimeo") ? [u, nil] : [u, "vimeo"]
  else
    options[:allowed].include?("vimeo") ? [url, nil] : [url, "vimeo"]
  end
end

def extract_dlp_link(url, options)
  options[:allowed].include?("yt-dlp") ? [url, nil] : [url, "yt-dlp"]
end

def extract_y_link(url, options)
  options[:allowed].include?("youtube") ? [url, nil] : [url, "youtube"]
end

def extract_local_link(path)
  extract_m3u8(File.read(path).split("\n"))
end

def extract_k_link(uri, path)
  uri = uri.clone
  uri.path = path
  res = HTTParty.get(uri, headers: {Accept: 'text/css'})
  extract_m3u8(res.body.split("\n"))
end

def extract_m3u8(lines)
  lines = lines.drop_while do |line|
    !line.start_with?("#EXT-X-STREAM-INF")
  end

  header, url = lines.each_slice(2).max do |(header1, url1), (header2, url2)|
    extract_pixels(header1) <=> extract_pixels(header2)
  end
  res = header.split(',').find { |str| str.start_with?("RESOLUTION") }.split("=")[1]
  [url, res]
end

def extract_pixels(header)
  res = header.split(',').find { |str| str.start_with?("RESOLUTION") }
  res.scan(/\d+/).map(&:to_i).reduce(1) { |acc, v| acc * v }
end

def extract_s_link(url)
  uri = URI(url)
  uri.host = "api." + uri.host
  uri.path = "/videos" + uri.path
  resp = HTTParty.get(uri)
  json = resp.parsed_response
  # puts "s_json: #{json}"

  res = json["files"]["original"]["height"]
  url = json["files"].values.find do |file|
    file["height"] == res
  end["url"]
  if url.nil?
    highest_res = json["files"].values.max do |file1, file2|
      (file1["height"] == res ? 0 : file1["height"]) <=> (file2["height"] == res ? 0 : file2["height"])
    end
    res = highest_res["height"]
    url = highest_res["url"]
  end

  [url, res.to_s + "p"]
end

def extract_filename(name, str, options)
  return [true, str] if str.downcase.include?("opening") || str.downcase.include?("ending")
  numbs = str.split(" ").map do |s|
    s.match?(/\d/) ? s[/\d+/].to_i : nil
  end.compact
  if options[:reverse_numbs]
    numbs.unshift(numbs.pop)
  end

  if str.downcase[/\d+x\d+.*\d+x\d+/]
    numbs.pop
    numbs << str.downcase[/(\d+x\d+).*(\d+x\d+)/, 1].split("x").map(&:strip).map(&:to_i)[-1]
    numbs << str.downcase[/(\d+x\d+).*(\d+x\d+)/, 2].split("x").map(&:strip).map(&:to_i)[-1]
  elsif str.downcase.include?(" and ")
    numbs.unshift(1) if numbs.size == 2
  elsif str[/\d+x\d+-\d+/]
    numbs.concat(str[/\d+-\d+/].split("-").map(&:strip).map(&:to_i))
  elsif str[/\d+-\d+/]
    numbs.unshift(1) if numbs.size == 1
    numbs << str[/\d+-\d+/].split("-").map(&:strip).map(&:to_i)[-1]
  elsif str.downcase[/\d+x\d+/]
    numbs << str.downcase[/\d+x\d+/].split("x").map(&:strip).map(&:to_i)[-1]
  else
    numbs.unshift(1) if numbs.size == 1
  end
  # if str.downcase[/season\s+\d+/] && str.downcase[/episode\s+\d+/]
  #   numbs = [str.downcase[/season\s\d+/][/\d+/].to_i, str.downcase[/episode\s\d+/][/\d+/].to_i]
  # # elsif str.downcase[/episode\s+\d+/]
  # #   numbs = [1, str.downcase[/episode\s\d+/][/\d+/].to_i]
  # else
  #   puts "couldn't extract filename of \"#{str}\""
  #   return [false, str]
  # end
  if numbs.size <= 1 || numbs.size >= 4 || numbs[0] >= 10
    puts "couldn't extract filename of \"#{str}\""
    return [false, str]
  end
  break_time = ""
  break_time = " Break Time" if str.downcase.include?('break time') || str.downcase.include?('breaktime')
  [true, "#{name} #{name(numbs)}#{break_time}"]
end

def name(numbs)
  name = "S#{numbs[0].to_s.rjust(2, '0')}E#{numbs[1].to_s.rjust(2, '0')}"
  if numbs.size == 3
    if numbs[2] - numbs[1] == 1
      name += "E#{numbs[2].to_s.rjust(2, '0')}"
    else
      name += "-E#{numbs[2].to_s.rjust(2, '0')}"
    end
  end
  name
end

main(PAGE_URL, QUERY, NAME, LAST, DEFAULT_OPTIONS.merge(defined?(OPTIONS) ? OPTIONS : {}))
