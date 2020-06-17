require 'csv'
require 'money'
require 'monetize'

Money.default_currency = Money::Currency.new("USD")
Money.locale_backend = :currency
Money.infinite_precision = true
Money.rounding_mode = BigDecimal::ROUND_HALF_UP
PAY_PER_DAY = Hash.new(Money.new(0))

CSV::Converters[:mydate] = -> (value) do
  begin
    Date.strptime(value, "%m/%d/%y")
  rescue
    value
  end
end

count = 0

CSV::Converters[:money] = -> (value) do
  count +=1
  # puts value.inspect if count < 15
  begin
    Monetize.parse!(value)
  rescue
    value
  end
end

def count_days(start, fin)
  ((fin - start) + 1).to_i
end

def add_row(row)
  start = row["Period Start Date"]
  fin = row["Period End Date"]
  amount = row["Gross Amount"]
  numb_days = count_days(start, fin)
  avg_amount = amount / numb_days
  # puts "period: #{start} - #{fin} (#{numb_days} days) for #{amount.format} (#{avg_amount.format} per day)"
  (start..fin).each do |date|
    PAY_PER_DAY[date] += avg_amount
  end
end

def calc_money_paid(start, fin)
  start = Date.strptime(start, "%m/%d/%y")
  fin = Date.strptime(fin, "%m/%d/%y")
  amount = Money.new(0)

  (start..fin).each do |date|
    amount += PAY_PER_DAY[date]
  end

  puts "was paid #{amount.round(Money.rounding_mode, 1).format} from #{start} - #{fin}"
end

rows = CSV.read("Philip_Ross Pay Slips.csv", headers: true, converters: [:mydate, :money])

rows.each do |row|
  add_row(row)
  # break
end


PAY_PER_DAY.each do |date, money|
  # puts "Paid #{money.format} on #{date}"
end

puts ''
puts "*************************************"
puts ''

calc_money_paid("04/01/20", "06/30/20")
calc_money_paid("01/01/20", "03/31/20")
calc_money_paid("10/01/19", "12/31/19")
calc_money_paid("07/01/19", "09/30/19")
calc_money_paid("04/01/19", "06/30/19")
calc_money_paid("01/01/19", "03/31/19")

puts ''
calc_money_paid("01/01/19", "12/31/19")




