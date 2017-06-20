#!/usr/bin/ruby
# ruby miestertask_time_parser.rb 'popular_media_time_tracking.csv' 2016-11-28
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'json'
  gem 'axlsx'
end

require 'csv'
require 'date'
require 'json'
require 'axlsx'

DATE_FORMAT = '%m/%d'
CHRISTMAS = Date.new(2016, 12, 25)
BREAK_START = Date.new(2017, 4, 8)
BREAK_END = Date.new(2017, 4, 16)

def parse(csv_path, start_date, end_date)
  start_date = start_date ? Date.parse(start_date) : Date.today.prev_year
  end_date = end_date ? Date.parse(end_date) : Date.today
  has_christmas = start_date < CHRISTMAS && CHRISTMAS < end_date

  first_sprint_start = start_date
  until first_sprint_start.wednesday?
    first_sprint_start = first_sprint_start.prev_day
  end
  weeks = Hash.new { |h, k| h[k] = Hash.new(0) }
  logged_time = Hash.new(0)
  skip_first = true
  CSV.foreach(csv_path) do |row|
    skip_first = false or next if skip_first
    dates = row[0].split('/')
    year = dates[2].to_i
    month = dates[0].to_i
    day = dates[1].to_i
    date = Date.new(year, month, day)
    next if date < start_date || date > end_date
    puts JSON.generate(row)
    hours = row[4].to_f
    person = row[5]

    logged_time[person] += hours
    sprint_num = ((date - first_sprint_start) / 7).to_i
    sprint_num = 4.5 if BREAK_START < date && date < BREAK_END
    puts sprint_num
    weeks[sprint_num][person] += hours

  end

  starting_sprint_num = weeks.keys.sort.first - 1

  puts "time logged from #{start_date} to #{end_date} in hours"
  puts logged_time
  weeks.keys.sort.each do |sprint_num|
    sprint_start = first_sprint_start
    sprint_num == 4.5 ? (sprint_start = BREAK_START) : (sprint_num*7).times { sprint_start = sprint_start.next_day }
    sprint_end = sprint_num == 4.5 ? BREAK_END : sprint_start
    7.times { sprint_end = sprint_end.next_day } unless sprint_num == 4.5
    puts "sprint #{sprint_num - starting_sprint_num - (BREAK_END < sprint_end ? 1 : 0)} (#{sprint_start.strftime(DATE_FORMAT)} - #{sprint_end.strftime(DATE_FORMAT)}): #{weeks[sprint_num]}"
  end
  puts weeks

  p = Axlsx::Package.new
  p.use_shared_strings = true

  p.workbook do |wb|
    styles = wb.styles
    title = styles.add_style :sz => 15, :b => true, :u => true
    default = styles.add_style :border => Axlsx::STYLE_THIN_BORDER

    wb.add_worksheet(name: 'time logged') do |ws|
      ws.add_row ['Time Logged in Hours Per Sprint', 'Andrew Ma', 'Luke Miller', 'Philip Ross', 'Jeremy Wright', 'Average'], style: title
      weeks.keys.sort.each do |sprint_num|
        sprint_start = first_sprint_start
        sprint_num == 4.5 ? (sprint_start = BREAK_START) : (sprint_num*7).times { sprint_start = sprint_start.next_day }
        sprint_end = sprint_num == 4.5 ? BREAK_END : sprint_start
        7.times { sprint_end = sprint_end.next_day } unless sprint_num == 4.5
        sprint_start = sprint_start.next_day while (BREAK_START < sprint_start && sprint_start < BREAK_END)
        andrew = weeks[sprint_num]['Andrew']
        luke = weeks[sprint_num]['Luke']
        philip = weeks[sprint_num]['Philip']
        jeremy = weeks[sprint_num]['Jeremy']
        avg = (andrew + luke + philip + jeremy) / 4
        ws.add_row ["Sprint #{sprint_num - starting_sprint_num - (BREAK_END < sprint_end ? 1 : 0)} #{"(Spring Break)" if sprint_num==4.5} (#{sprint_start.strftime(DATE_FORMAT)} - #{sprint_end.strftime(DATE_FORMAT)})", andrew, luke, philip, jeremy, avg]
      end

      ws.add_row

      andrew = logged_time['Andrew']
      luke = logged_time['Luke']
      philip = logged_time['Philip']
      jeremy = logged_time['Jeremy']
      avg = (andrew + luke + philip + jeremy) / 4
      ws.add_row ["Total Hours Logged (#{start_date.strftime(DATE_FORMAT)} - #{end_date.strftime(DATE_FORMAT)})", andrew, luke, philip, jeremy, avg]
      numb_sprints = weeks.keys.length

      ws.add_row ['Sprint Average', andrew / numb_sprints, luke / numb_sprints, philip / numb_sprints, jeremy / numb_sprints, avg / numb_sprints]
    end
  end
  p.serialize 'hours_logged.xlsx'

end

if __FILE__== $0
  unless ARGV[0]
    ARGV[0] = 'popular_media_time_tracking.csv'
    ARGV[1] = '2017-03-06'
  end
  parse(ARGV[0], ARGV[1], ARGV[2])
end
