require 'dotenv/load'
require 'httparty'
require 'parallel'

DEFAULT_OPTIONS = {reverse_numbs: false, gallery_dl: false}

NAME = ""
QUERY = ""
PAGE_URL = ""
LAST = ""

def main(page_url, query, name, last, options)
  page_uri = URI(page_url)

  videos = options[:gallery_dl] ? search_gallery_dl(query, name, last, options) : search(page_uri, query, name, last, options)
  urls = process_videos(page_uri, videos, name, query.gsub(/[^0-9A-Za-z\s]/, ''), last, options)

  puts "\n**************************\n\n"
  urls.each do |url|
    puts url
  end
  puts "\n**************************\n\n"
end

def search_gallery_dl(query, name, last, options)
  gallery_dl_dir = ENV["GALLERY_DL"]
  Dir.entries(gallery_dl_dir)
     .select { |info_filename| info_filename.end_with?('.m3u8') }
     .select { |info_filename| info_filename.downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) }
     .sort
     .reverse
     .map do |info_filename|
    infos = File.basename(info_filename, File.extname(info_filename)).split("$$")
    {"title" => infos[1], "file" => {"path" => File.join(gallery_dl_dir, info_filename)}}
  end
end

def search(page_uri, query, name, last, options)
  page_uri.path = "/api/v1" + page_uri.path

  videos = []
  offset = 0
  while true
    page = HTTParty.get(page_uri, query: {q: query, o: offset}).parsed_response
    videos.concat(page)
    break if page.size < 50 || compare(last, get_last_filename(name, page, query, options)) <= 0
    offset += 50
  end

  videos
end

def process_videos(page_uri, videos, name, query, last, options)
  videos = videos.reverse.drop_while do |video|
    extracted, filename = extract_filename(name, video["title"], options)
    puts "extracted: #{extracted}, filename: #{filename}, title: #{video["title"]}"
    !extracted || !video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) || compare(last, filename) <= 0 || video["title"].downcase.include?("code")
  end.select do |video|
    video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query) #&& !(!video["file"].empty? && video["embed"])
  end
  # Parallel.map(videos, in_threads: 8) do |video|
  Parallel.map(videos, in_threads: 4) do |video|
    # videos.map do |video|
    _, filename = extract_filename(name, video["title"], options)
    filename = filename.strip
    puts "video: #{video["title"]}, filename: #{filename}"
    extract_link(page_uri, video, filename)
  end
end

def extract_link(page_uri, video, filename)
  url, res = if !video["file"].empty?
               if video["file"]["path"].end_with?(".txt")
                 extract_k_link(page_uri, video["file"]["path"])
               elsif video["file"]["path"].end_with?(".m3u8")
                 extract_local_link(video["file"]["path"])
               end
             else
               if video["embed"]["url"].include?("google")
                 extract_g_link(video["embed"]["url"])
               else
                 extract_s_link(video["embed"]["url"])
               end
             end

  url += "#filename=#{filename}"
  if !res.include?("1080")
    url += " (#{res})"
  end
  url += ".mp4"

  url
end

def compare(last, filename)
  number = filename.split(' ')[-1]
  number <=> last
end

def get_last_filename(name, page, query, options)
  page.reverse_each do |video|
    extracted, filename = extract_filename(name, video["title"], options)
    next if !video["title"].downcase.gsub(/[^0-9A-Za-z\s]/, '').include?(query)
    return filename if extracted
  end
end

def extract_g_link(url)
  [url, "drive"]
end

def extract_local_link(path)
  extract_m3u8(File.read(path).split("\n"))
end

def extract_k_link(uri, path)
  uri = uri.clone
  uri.path = path
  res = HTTParty.get(uri)
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
  return [false, str] if str.downcase.include?("opening") || str.downcase.include?("ending")
  str.gsub!('\s+-\s+', '-')
  str.gsub!('\s+x\s+', 'x')
  numbs = str.split(" ").map do |s|
    s.match?(/\d/) ? s[/\d+/].to_i : nil
  end.compact
  if options[:reverse_numbs]
    numbs.unshift(numbs.pop)
  end

  if str.downcase.include?(" and ")
    numbs.unshift(1) if numbs.size == 2
  elsif str[/\d+-\d+/]
    numbs.unshift(1) if numbs.size == 1
    numbs << str[/\d+-\d+/].split("-").map(&:strip).map(&:to_i)[-1]
  elsif str[/\d+x\d+/]
    numbs << str[/\d+x\d+/].split("x").map(&:strip).map(&:to_i)[-1]
  else
    numbs.unshift(1) if numbs.size == 1
  end
  if numbs.size <= 1 || numbs.size >= 4 || numbs[0] >= 10
    puts "couldn't extract filename of \"#{str}\""
    return [false, str]
  end
  [true, "#{name} #{name(numbs)}"]
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
