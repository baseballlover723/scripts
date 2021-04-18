require 'fileutils'
require 'json'
require 'time'

DEFAULT_TIME = Time.at(0).freeze

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

  attr_accessor :cache, :path, :update_duration, :last_write_time, :modified_cache, :update_semaphore, :write_semaphore

  def initialize(cache, path, update_duration = -1)
    @cache = cache
    @path = path
    @update_duration = update_duration
    @modified_cache = false
    @last_write_time = Time.now
    @update_semaphore = Mutex.new
    @write_semaphore = Mutex.new
  end

  def self.load(path, update_duration = -1)
    return self.new({}, path, update_duration) unless File.exist?(path)
    json = JSON.parse(File.read(path))
    cache = {}

    json.each do |path, payload|
      last_modified = Time.parse(payload[LAST_MODIFIED_KEY])
      cache[path] = load_episode(path, last_modified, payload)
    end

    self.new(cache, path, update_duration)
  end

  def write
    if @modified_cache
      @write_semaphore.synchronize do
        @modified_cache = false
        sorted_cache = cache.sort_by { |path, _obj| path }.to_h
        File.write(@path, JSON.generate(sorted_cache))
      end
    end
    @last_write_time = Time.now
  end

  def self.load_episode(_path, _last_modified, _payload)
    raise 'not_implemented'
  end

  def get(path, &block)
    new_modified_time = File.mtime(path)
    if new_modified_time <= DEFAULT_TIME
      FileUtils.touch(path, nocreate: true)
      new_modified_time = File.mtime(path)
    end
    cached = @cache[path]
    cached = @cache[path] = self.class.load_episode(path, Time.at(DEFAULT_TIME), {}) unless cached
    return cached.payload, true if cached && new_modified_time.to_i == cached.last_modified.to_i && cached.last_modified != DEFAULT_TIME && cached.payload

    new_payload = block.call()
    cached.payload = new_payload
    cached.last_modified = new_modified_time
    @modified_cache = true
    if @update_duration != -1 && Time.now - @last_write_time > @update_duration
      @update_semaphore.synchronize { write if Time.now - @last_write_time > @update_duration }
    end

    [new_payload, false]
  end
end

class BaseCachePayload
  attr_accessor :path, :last_modified, :payload

  def initialize(path, last_modified, payload)
    @path = path
    @last_modified = last_modified
    @payload = payload
  end

  def as_json(options = {})
    {last_modified: last_modified}
  end

  def to_json(options)
    as_json(*options).to_json(*options)
  end
end
