require 'active_support/core_ext/string/indent'
require 'active_support/core_ext/string/inflections'

OUTPUT_PATH = './output.rb'
CLASSES = []

class Class
  attr_accessor :name
  attr_accessor :attributes
  attr_accessor :single_associations
  attr_accessor :array_associations
  attr_accessor :hash_associations

  # TODO convert assocations to class
  def initialize(name)
    self.name = name.to_s
    self.attributes = []
    self.single_associations = []
    self.array_associations = []
    self.hash_associations = []
    CLASSES << self
  end

  def debug
    {name: name, attributes: attributes, single_associations: single_associations, array_associations: array_associations, hash_associations: hash_associations}
  end
end

class HashAssociation
  attr_accessor :name
  attr_accessor :key
  attr_accessor :nested

  def initialize(name, key, nested)
    self.name = name.to_s
    self.key = key.to_s
    self.nested = nested
  end

  def debug
    {name: name, key: key, nested: nested}
  end
end

def main
  hash = ['key1',
          'key2',
          seasons: ['season_name'],
          named_seasons: {named_season_name:
                              ['named_season_name']
          }
  ]

  parse_hash hash, 'anime'
  CLASSES.each {|c| puts c.debug}
  write_file
end

def parse_hash(hash, root_name)
  klass = Class.new root_name

  hash.each do |object|
    parse_hash_recursive klass, nil, object
  end
end

def parse_hash_recursive(klass, super_class, object)
  if object.class == Array
    object.each do |obj|
      parse_hash_recursive klass, super_class, obj
    end
    puts object
  elsif object.class == Hash
    object.each do |sub_class_name, sub_class_stuff|
      new_class = Class.new(sub_class_name)
      klass.array_associations << new_class if sub_class_stuff.class == Array
      if sub_class_stuff.class == Hash
        assoc = HashAssociation.new(sub_class_name, sub_class_stuff.keys.first, sub_class_stuff.values.first)
        klass.hash_associations << assoc
      end
      parse_hash_recursive new_class, klass, sub_class_stuff

    end
  else
    klass.attributes << object
  end

end

def write_file
  File.open(OUTPUT_PATH, 'w') do |file|
    CLASSES.each do |klass|
      file.puts "class #{klass.name.camelize}"
      write_accessors(file, klass)

      write_initialize(file, klass)
      write_adders_and_removers(file, klass)
      file.puts 'end'
      file.puts ''
    end
  end
end

def write_accessors(file, klass)
  first = true
  # hash associations
  unless klass.hash_associations.empty?
    file.puts '' unless first
    file.puts '# hash associations'.indent 2
    klass.hash_associations.each do |assoc|
      file.puts "attr_accessor :#{assoc.name}".indent 2
      first = false
    end
  end

  # array associations
  unless klass.array_associations.empty?
    file.puts '' unless first
    file.puts '# array associations'.indent 2
    klass.array_associations.each do |assoc|
      file.puts "attr_accessor :#{assoc.name}".indent 2
      first = false
    end
  end

  # attributes
  unless klass.attributes.empty?
    file.puts '' unless first
    file.puts '# attributes'.indent 2
    klass.attributes.each do |attribute|
      file.puts "attr_accessor :#{attribute}".indent 2
      first = false
    end
  end

end

def write_initialize(file, klass)
  return if klass.hash_associations.size + klass.array_associations.size == 0
  file.puts ''
  file.puts 'def initialize'.indent 2
  klass.hash_associations.each do |assoc|
    file.puts "self.#{assoc.name} = {}".indent 4
  end
  klass.array_associations.each do |assoc|
    file.puts "self.#{assoc.name} = []".indent 4
  end

  file.puts 'end'.indent 2
end

def write_adders_and_removers(file, klass)
  file.puts '' if klass.hash_associations.size > 0
  file.puts '# hash assoications adders and removers'.indent 2 if klass.hash_associations.size > 0
  klass.hash_associations.each do |assoc|
    puts assoc.debug
    singular = assoc.name.singularize
    file.puts "def add_#{singular}(#{assoc.key}, #{singular})".indent 2
    puts assoc.debug
    file.puts "#{assoc.name}[#{assoc.key}] = #{singular}".indent 4
    file.puts 'end'.indent 2
  end

  file.puts '' if klass.array_associations.size > 0
  file.puts '# array associations adders and removers'.indent 2 if klass.array_associations.size > 0
  klass.array_associations.each do |assoc|
    singular = assoc.name.singularize
    file.puts "def add_#{singular}(#{singular})".indent 2
    file.puts "#{assoc.name} << #{singular}".indent 4
    file.puts 'end'.indent 2
  end
end

# TODO write removes

main
