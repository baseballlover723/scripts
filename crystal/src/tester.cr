require "./runner"

Runnable.make_runnable(__FILE__) do |parser|
  parser.on("-t", "--test", "Testing new option") {}
  parser.on("-b", "--berst", "eew option") {}
  parser.on("-c", "--cerst", "cccccccccc option") {}
end

def main
  puts "first string"
  puts "differntasdf"
  puts "asdf"
end

main
