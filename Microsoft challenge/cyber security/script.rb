input = "6 6
Seahawks:Players;Coaching Staff;Owners;Paul Allen
Players:Russell Wilson;Marshawn Lynch (BEAST)
Coaching Staff:Pete Carroll
Owners:Paul Allen
Backup dancers:Left Shark;Right Shark
Halftime Show:Backup dancers;Katy Perry
Tom Brady;Seahawks
Left Shark;Halftime Show
Marshawn Lynch (BEAST);Seahawks
Pete Carroll;Coaching Staff
Katy Perry;Seahawks
Paul Allen;Seahawks"

def recurse(name, required_group)
  return false unless @groups[required_group]
  @groups[required_group].each do |sub_group|
    # puts sub_group
    if @groups[sub_group]
      puts "Yes (Indirect)" and return true if @groups[sub_group].include? name
      return recurse(name, @groups[sub_group])
    end
  end
end

def parse_groups(input)
  lines = input.split("\n")
  group_numb = lines[0].split(" ")[0].to_i
  statment_numb = lines[0].split(" ")[1].to_i
  groups_lines = lines[1..(group_numb)]
  statements_lines = lines[(group_numb+1)..lines.count]

  @groups = {}
  groups_lines.each do |line|
    group_name = line.split(":")[0]
    names = line.split(":")[1].split(";")
    # puts group_name
    # puts "*"
    # puts names.inspect
    @groups[group_name] = names
  end
  # groups.each do |key, val|
  #   puts "#{key}   CONTAINS   #{val}"
  # end


  statements_lines.each do |line|
    name = line.split(";")[0]
    required_group = line.split(";")[1]
    puts "*"
    if @groups[required_group].include? name
      puts "Yes (direct)" and next
    else
      unless recurse(name, required_group)
        puts "No"
      end
    end

  end
end
"Seahawks:Players;Coaching Staff;Owners;Paul Allen
Players:Russell Wilson;Marshawn Lynch (BEAST)
Coaching Staff:Pete Carroll
Owners:Paul Allen
Backup dancers:Left Shark;Right Shark
Halftime Show:Backup dancers;Katy Perry
Tom Brady;Seahawks
Left Shark;Halftime Show
Marshawn Lynch (BEAST);Seahawks
Pete Carroll;Coaching Staff
Katy Perry;Seahawks
Paul Allen;Seahawks"
parse_groups input
