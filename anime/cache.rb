require 'json'
require 'time'

class Module
  def alias_attr(new_attr, original)
    alias_method(new_attr, original) if method_defined? original
    new_writer = "#{new_attr}="
    original_writer = "#{original}="
    alias_method(new_writer, original_writer) if method_defined? original_writer
  end
end

class BaseCache
  LAST_MODIFIED_KEY = 'last_modified'.freeze

  attr_accessor :cache

  def initialize(cache)
    @cache = cache
  end

  def self.load(path)
    return self.new({}) unless File.exist?(path)
    json = JSON.parse(File.read(path))
    cache = {}

    json.each do |path, payload|
      last_modified = Time.parse(payload[LAST_MODIFIED_KEY])
      cache[path] = load_episode(path, last_modified, payload)
    end

    self.new(cache)
  end

  def write(path)
    sorted_cache = cache.sort_by {|path, _obj| path}.to_h
    File.write(path, JSON.generate(sorted_cache))
  end

  def self.load_episode(_path, _last_modified, _payload)
    raise 'not_implemented'
  end

  def get(path, &block)
    new_modified_time = File.mtime(path)
    cached = @cache[path]
    cached = @cache[path] = self.class.load_episode(path, Time.at(0), {}) unless cached
    return cached.payload if cached && new_modified_time.to_i <= cached.last_modified.to_i && cached.payload

    new_payload = block.call()
    cached.payload = new_payload
    cached.last_modified = new_modified_time

    new_payload
  end
end

class BaseCachePayload
  attr_accessor :path, :last_modified, :payload

  def initialize(path, last_modified, payload)
    @path = path
    @last_modified = last_modified
    @payload = payload
  end

  def as_json(options={})
    {last_modified: last_modified}
  end

  def to_json(options)
    as_json(*options).to_json(*options)
  end
end