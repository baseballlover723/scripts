SIGNS = [:+, :-, :*, :/, ://, :%, :**, :>>, :<<]
INTS = {Int8, Int16, Int32, Int64, Int128}
NAME = "bad_calc"
FILE = "./src/#{{{NAME}}}.cr"
BINARY = "./bin/#{{{NAME}}}"
BUILD = "time crystal build -o #{{{BINARY}}} #{{{flag?(:release) ? " --release" : ""}}} --stats #{{{FILE}}}"
TEST = "time #{{{BINARY}}} 1 + 2"

puts "build: #{BUILD}"
puts "run: #{BINARY}"

input = ARGV.shift

# macro add(n1, n2)
#   {% begin %}
#   if (n1 == 0 && n2 == 0)
#     puts "0 + 0 = 0"
#   elsif (n1 == {{n1}} && n2 == {{n2}})
#     puts "{{n1}} + {{n2}} = {{n1 + n2}}"
#   end
#   {% end %}
# end

# n1 = 1
# n2 = 2

# add(1, 2)

# str = :Int8
# mod = INT_MAP[str]
# puts "mod type: #{typeof(mod)}"

DIVISON = 1

macro generate(mod_str)
  puts "mod_str: #{{{mod_str}}}"
  {% for mod in INTS %}
    if ({{mod_str}} == {{mod.stringify}})
      puts "generating for mod: #{{{mod}}}"
      puts "max: #{{{mod}}::MAX}"
      File.open(FILE, "w") do |f|
        content = <<-CRYSTAL
        puts "Running bad calc"

        n1 = {{mod}}.new(ARGV.shift)
        sign = ARGV.shift
        n2 = {{mod}}.new(ARGV.shift)

        puts "n1: \#{n1}, n2: \#{n2}"
        
        {% for sign in SIGNS %}
        # {{sign.id}}
        # if (n1 == 0 && sign == {{sign.id.stringify}} && n2 == 0)
        #   puts "0 {{sign.id}} 0 = 0"
        #{
          ({{mod}}::MIN // DIVISON).upto({{mod}}::MAX // DIVISON).map do |i1| 
            ({{mod}}::MIN // DIVISON).upto({{mod}}::MAX // DIVISON).select do |i2|
              begin
                i1 {{sign.id}} i2
                true
              rescue
                false
              end
            end.map do |i2|
              # "elsif (n1 == #{i1} && sign == \"{{sign.id}}\" && n2 == #{i2})\n  puts(\"#{i1} {{sign.id}} #{i2} = #{i1 {{sign.id}} i2}\")"
              "if (n1 == #{i1} && sign == \"{{sign.id}}\" && n2 == #{i2})\n  puts(\"#{i1} {{sign.id}} #{i2} = #{i1 {{sign.id}} i2}\")\nend"
            end.join("\n")
          end.join("\n")
        }
        # end
        {% end %}
        CRYSTAL
        f.puts(content)
      end
    end
  {% end %}
end

generate(input)


system(BUILD)
system(TEST)

