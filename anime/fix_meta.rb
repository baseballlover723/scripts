require_relative './base_script'
if ARGV.empty?
  require 'highline/import'
  require 'colorize'
end

PATH_TYPES = [:local, :external]

class Show < BaseShow
  attr_accessor :tags, :new_name, *PATH_TYPES

  def initialize(name, path)
    super
    @tags = []
    PATH_TYPES.each do |type|
      default = {old_path: '', new_path: '', files_to_create: []}
      send(type.to_s + '=', default)
    end
  end

  def to_s
    "#{name}: local: #{local.inspect}, external: #{external.inspect}"
  end
end

class Script < BaseScript
  def initialize(results = {})
    super(results)
    @analyze_season = false
    @analyze_episode = false
  end

  def analyze_show(show, path)
    data = show.send(@location)
    data[:old_path] = path
    show.tags = show.name.scan(/\s+\(.*?\)/).reject { |str| str.match /\(\d{4}\)/ }

    show.new_name = show.name
    data[:new_path] = path

    show.tags.each do |tag|
      data[:new_path] = data[:new_path].sub(tag, '')
      show.new_name = show.new_name.sub(tag, '')
    end
    show.tags.each do |tag|
      data[:files_to_create] << data[:new_path] + '/' + expand_tag(tag.strip[1..-2]) + '.meta'
    end
  end

  def should_trim_show?(show)
    show.tags.empty?
  end

  def fix_meta
    results.each_value do |show|
      str = "\n**************"
      PATH_TYPES.each do |type|
        data = show.send(type)
        files_str = data[:files_to_create].join("\n").light_green
        str << "\n\nchanging #{type} name from \n#{data[:old_path].light_red}\n#{data[:new_path].light_green}\ncreating new #{type} files\n#{files_str}"
      end
      # puts str
      if BaseScript.yesno(str)
        PATH_TYPES.each do |type|
          rename_show(show, type)
        end
      end
    end
  end

  def rename_show(show, type)
    puts
    data = show.send(type)
    Dir.entries(data[:old_path], **@opts).keep_if { |file| show.tags.any? { |t| file.include?(t) } }.each do |file|
      new_file_name = file
      show.tags.each do |tag|
        new_file_name = new_file_name.sub(tag, '')
      end
      rename(data[:old_path] + '/' + file, data[:old_path] + '/' + new_file_name)
    end
    rename(data[:old_path], data[:new_path])
    data[:files_to_create].each do |file|
      create_meta(file)
    end
  end

  def rename(old_path, new_path)
    puts "renaming\n\"#{old_path.light_red}\" ->\n\"#{new_path.light_green}\""
    File.rename(old_path, new_path)
  end

  def create_meta(path)
    puts "creating a new meta file at\n\"#{path.light_green}\""
    File.write(path, '') unless File.exist?(path)
  end

  def expand_tag(tag)
    case tag
    when 'CE'
      "Collector's Edition"
    when 'DC'
      "Director's Cut"
    when 'EE'
      "Extended Edition"
    when 'SE'
      "Special Edition"
    when 'Super Duper'
      "Super Duper Edition"
    else
      tag
    end
  end
end

def main
  script = Script.new

  script.iterate '/mnt/e/movies'
  script.iterate '/mnt/h/movies'

  script.trim_results
  script.end_time

  script.fix_meta
end

if ARGV.empty?
  main
else
  remote_main
end
