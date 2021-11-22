require "digest"
require "option_parser"

module Runnable
  macro make_runnable(file, &block)
    ORIGINAL_ARGV = ARGV.dup
    OPTIONS = {:runtime_release => false}

    def binary_release? : Bool
      {{ flag?(:release) }}
    end

    def runtime_release? : Bool
      OPTIONS[:runtime_release]
    end
  
    def source_sha256 : String
      {{ system("crystal eval 'require \"digest\"; print Digest::SHA256.new().file(#{file}).final.to_slice.hexstring'").stringify }}
    end

    def script_file : String
      {{file}}
    end

    def recompile!(reasons) : Nil
      file_path = Path.new(script_file).relative_to(Path.new(PROGRAM_NAME).expand.parent().parent())
      puts "needs to build #{file_path} because #{reasons.join(" and ")}"
      name = File.basename(PROGRAM_NAME)

      build_args = ["build", Process.quote(name), runtime_release? ? "--release" : "", "--progress"].select{ |a| !a.empty?}
      Process.run("shards", build_args, output: STDOUT, error: STDERR)
      Process.exec("./bin/#{name}", ORIGINAL_ARGV)
    end

    %help_message = ""
    OptionParser.parse do |parser|
      parser.banner = "Usage: #{File.basename(PROGRAM_NAME)} [arguments]"
      parser.on("-h", "--help", "Show this help") do
        %help_message = parser.to_s
      end
      parser.on("--release", "run in release mode") { OPTIONS[:runtime_release] = true}
      {{yield}}
    end

    reasons = {"optimization is required" => (!binary_release? && runtime_release?), "the source file has changed" => (source_sha256 != Digest::SHA256.new().file(script_file).final.to_slice.hexstring)}
    reasons.reject! { |_, v| !v }
  
    recompile!(reasons.keys) unless reasons.empty?
    puts %help_message unless %help_message.empty?
  end
end
