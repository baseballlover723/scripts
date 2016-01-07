require 'net/http'
class Graves
  def initialize
    uri = URI('http://example.com/index.html?count=10')
    Net::HTTP.get(uri) # => String
  end

end