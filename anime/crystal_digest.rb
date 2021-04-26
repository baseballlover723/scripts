require 'ffi'
require 'digest'

module Crystal
  RELEASE = true
  SOURCE_FILE = 'digest.cr'.freeze
  BIN_FOLDER = './bin'.freeze
  LIB_NAME = 'crystal_digest'.freeze
  LIB_PATH = File.expand_path(LIB_NAME + '.' + FFI::Platform::LIBSUFFIX, File.join(__dir__, BIN_FOLDER))

  def self.ruby_checksum
    Digest::SHA256.file(SOURCE_FILE)
  end

  def self.build(reasons)
    puts "needs to build #{SOURCE_FILE} because #{reasons.join(" and ")}"
    start = Time.now
    compile(SOURCE_FILE, BIN_FOLDER, LIB_NAME, RELEASE)
    puts "Took #{Time.now - start} seconds to build"
  end

  def self.compile(src, bin, lib_name, release)
    lib_name = "#{bin}/#{lib_name}"
    Dir.mkdir(bin) unless Dir.exist?(bin)

    compile_cmd = `crystal build --cross-compile #{release ? '--release' : ''} #{src} -o #{lib_name}`
    compile_cmd.sub!('-rdynamic', '-rdynamic -shared')
    compile_cmd.sub!("-o #{lib_name}", "-o #{lib_name}.so")
    `#{compile_cmd}`
  end

  if !File.exist?(LIB_PATH)
    build(["it hasn't been built yet"])
  end

  module Test
    extend FFI::Library

    ffi_lib LIB_PATH

    attach_function :lib_init, [], :void
    attach_function :is_release, [], :bool
    attach_function :source_sha256, [], :string

  end

  Test.lib_init

  reasons = {"optimization is required": (RELEASE && !Test.is_release), "the source file has changed": (Crystal.ruby_checksum != Test.source_sha256)}
  reasons.reject! { |_, v| !v }

  if !reasons.empty?
    Crystal.build(reasons.keys)
  end

  # unload Test
  singleton_class.remove_method(:ruby_checksum)
  singleton_class.remove_method(:build)
  singleton_class.remove_method(:compile)
  Crystal.send(:remove_const, :Test)

  module Digest
    extend FFI::Library

    ffi_lib LIB_PATH

    attach_function :lib_init, [], :void
    attach_function :is_release, [], :bool
    attach_function :source_sha256, [], :string
    attach_function :sha256, [:string], :string

    attach_function :print_crystal, [:string, :int], :string
    attach_function :add, [:int, :int, :int], :int

    module SHA256
      def self.file(path)
        Crystal::Digest.sha256(path)
      end
    end
  end
end

Crystal::Digest.lib_init

if __FILE__ == $0
  puts "is release: #{Crystal::Digest.is_release}"
  puts Crystal::Digest.add(1, 2, 1).inspect
  puts Crystal::Digest.print_crystal("from ruby", 2).inspect

  puts
  puts "crystal  sha256: #{Crystal::Digest.sha256("digest.cr")}"
  puts "crystal::SHA256: #{Crystal::Digest::SHA256.file("digest.cr")}"
end
