require 'benchmark/ips'
require 'digest'

require 'active_support'
require 'active_support/number_helper'
require "active_support/core_ext/numeric/bytes"
require 'fileutils'
require 'optparse'
require 'securerandom'
require 'tempfile'

# PATHS = ["#{Dir.home}/file_test/", "/mnt/c/Users/Philip Ross/Downloads/file_test/", "/mnt/e/file_test/", "/mnt/d/file_test/", "/mnt/h/file_test/", "/mnt/i/file_test/", "/mnt/g/file_test/"]
# PATHS = ["#{Dir.home}/file_test/"]
PATHS = ["#{Dir.home}/file_test/", "/mnt/c/Users/Philip Ross/Downloads/file_test/"]
SIZES = [10.kilobytes, 10.megabytes, 300.megabytes, 1400.megabytes, 2.5.gigabytes, 5.gigabytes, 25.gigabytes].map(&:to_i)
# SIZES = [2.5.gigabytes, 5.gigabytes, 25.gigabytes].map(&:to_i)
# SIZES = [10.kilobytes, 10.megabytes].map(&:to_i)
# SIZES = [10.megabytes].map(&:to_i)
DIGEST_ALGOS = [Digest::MD5, Digest::RMD160, Digest::SHA1, Digest::SHA256, Digest::SHA384, Digest::SHA512]
# DIGEST_ALGOS = [Digest::MD5]
# CONSTANT = 3 * 10.kilobytes / 10.0
# CONSTANT = 100 * 10.kilobytes / 6.0
CONSTANT = 6.0 * 10.kilobytes
SOFT_THRESHOLD = 10 * 60 # minutes
SOFT_MULTIPLIER = 1.5
THRESHOLD = 15 * 60 # minutes
TIME_FORMAT = "%D %r"

BenchmarkData = Struct.new(:path, :size, :runtime, :warmup, :drive)

class GCSuite
  def warming(*)
    run_gc
  end

  def running(*)
    run_gc
  end

  def warmup_stats(*) end

  def add_report(*) end

  private

  def run_gc
    GC.enable
    GC.start
    GC.disable
  end
end

def main(dry_run)
  begin
    # clean_output
    paths = create_files(PATHS, SIZES, dry_run)
    puts "\ndone creating files\n\n"

    all_benchmarks = paths.flatten

    runtime_left = estimated_time_left(all_benchmarks)
    now = Time.now
    puts "total runtime left       : #{to_human_duration runtime_left}"
    puts "total ETA                : #{(now + runtime_left).strftime(TIME_FORMAT)}"
    if dry_run
      puts "\n*******************\n\n"
      return
    end

    i = 0
    reports = paths.flat_map do |sub_paths|
      reports = sub_paths.map do |benchmark_data|
        i += 1
        report = run_benchmark(benchmark_data, "#{i}/#{all_benchmarks.size}", all_benchmarks[(i - 1)..-1])
        write_output(report, benchmark_data.drive)
        report
      end
      reports
    end
    puts "\n*******************\n\n"
    puts "time is currently: #{Time.now.strftime(TIME_FORMAT)}"
    puts "\n*******************\n\n"
    reports.each do |report|
      report.run_comparison
    end

  ensure
    clean_up_files(PATHS)
  end
end

def write_output(report, drive)
  output = with_captured_stdout do
    report.run_comparison
  end
  print output
  File.open("benchmark_checksums.#{drive}.log", "a") do |f|
    f << output
  end
end

def clean_output
  puts "cleaning previous run data"
  Dir.glob("benchmark_checksums.*.log").each do |f|
    File.delete(f)
  end
end

def run_benchmark(benchmark_data, iter_str, benchmarks_left)
  path = benchmark_data.path
  size = benchmark_data.size
  runtime = benchmark_data.runtime
  warmup = benchmark_data.warmup
  drive = benchmark_data.drive

  human_size = h_size(size)
  estimated_runs = estimate_runs(size, runtime)
  current_runtime = estimated_time_left([benchmarks_left.first])
  runtime_left = estimated_time_left(benchmarks_left)
  now = Time.now

  puts "running benchmark on #{path} with size: #{human_size} (#{iter_str})"
  puts "warmup: #{warmup} seconds, runtime: #{runtime / 60.0} minutes, estimate_runs: #{estimated_runs}"
  puts "time is currently        : #{now.strftime(TIME_FORMAT)}"
  puts "current benchmark runtime: #{to_human_duration current_runtime}"
  puts "current benchmark ETA    : #{(now + current_runtime).strftime(TIME_FORMAT)}"
  puts "total runtime left       : #{to_human_duration runtime_left}"
  puts "total ETA                : #{(now + runtime_left).strftime(TIME_FORMAT)}"

  # wake up drive
  File.open(path) do |file|
    until file.eof?
      file.read(1024 * 1024)
    end
  end

  Benchmark.ips do |x|
    x.config(suite: GCSuite.new)
    x.time = runtime
    x.warmup = warmup

    longest_algo = DIGEST_ALGOS.map { |algo| algo.to_s.split("::").last.size }.max

    DIGEST_ALGOS.each do |algo|
      x.report("#{drive.upcase}: #{human_size} #{algo.to_s.split("::").last.rjust(longest_algo)}") { algo.file(path) }
    end
    # Compare the iterations per second of the various reports!
    x.compare!
  end
end

def calc_runtime(size)
  raw_time = size / CONSTANT
  if raw_time < SOFT_THRESHOLD
    return raw_time.ceil
  else
    time = raw_time
    1.times do
      time = time / SOFT_MULTIPLIER
      return time.ceil if time < THRESHOLD
    end
    if time < THRESHOLD
      return time.ceil
    else
      return calc_runtime(size / SOFT_MULTIPLIER)
    end
  end
end

def estimate_runs(size, runtime)
  runtime * 60 * 10.megabytes / size
end

def estimated_time_left(paths)
  paths.map do |benchmark_data|
    benchmark_data.runtime * DIGEST_ALGOS.size + benchmark_data.warmup * DIGEST_ALGOS.size
  end.sum
end

def create_files(paths, sizes, dry_run)
  clean_up_files(paths)
  paths.each { |path| Dir.mkdir(path) }

  sizes.map do |size|
    tmp_file = write_master_file(size, dry_run)

    paths.map do |path|
      path = File.join(path, h_size(size) + '.data').freeze
      runtime = calc_runtime(size)
      warmup = (runtime / 60.0).ceil
      Thread.new(tmp_file, path, runtime, warmup) do |tmp_file, path|
        if !dry_run
          puts "copying master file (#{h_size(size)}) to path: #{path}"
          FileUtils.cp(tmp_file.path, path)
          puts "done copying #{path}"
        end
        drive = path.split("/")[2]
        drive = "wsl" if drive.size != 1
        BenchmarkData.new(path, size, runtime, warmup, drive)
      end
    end.map(&:value)
  end
end

def write_master_file(size, dry_run)
  tmp_file = Tempfile.new('master_bytes')
  return tmp_file if dry_run
  puts "writing to path: #{tmp_file.path} with #{h_size(size)} of random data"
  chunk = 1.megabyte
  times = size / chunk
  remainder = size % chunk
  times.times do
    tmp_file.write(SecureRandom.random_bytes(chunk))
  end
  tmp_file.write(SecureRandom.random_bytes(remainder))
  tmp_file
end

def clean_up_files(paths)
  paths.each do |path|
    if File.exist?(path)
      FileUtils.rm_rf(path)
      puts "deleted #{path}"
    end
  end
end

def with_captured_stdout
  original_stdout = $stdout # capture previous value of $stdout
  $stdout = StringIO.new # assign a string buffer to $stdout
  yield # perform the body of the user code
  $stdout.string # return the contents of the string buffer
ensure
  $stdout = original_stdout # restore $stdout to its previous value
end

def h_size(size)
  ActiveSupport::NumberHelper.number_to_human_size(size, {precision: 5})
end

def to_human_duration(time)
  mm, ss = time.divmod(60)
  hh, mm = mm.divmod(60)
  dd, hh = hh.divmod(24)
  str = ""
  str << "#{dd} days, " if dd > 0
  str << "#{hh} hours, " if hh > 0
  str << "#{mm} minutes, " if mm > 0
  str << "#{ss} seconds, " if ss > 0
  str = str[0..-3]
  str.reverse.sub(" ,", " and ".reverse).reverse
end

options = {dry_run: true}
OptionParser.new do |opts|
  opts.banner = 'Usage: example.rb [options] -f'

  opts.on('-f', '--force', 'Actually run the benchmarks') do |dry_run|
    options[:dry_run] = !dry_run
  end
end.parse!

main(options[:dry_run])
