require 'rubygems'
require 'mechanize'
require 'optparse'
require 'json'
require 'aws-sdk-v1'

class FlightInfo
    def initialize()
	@flightNums = Array.new
	@flightPrice = nil
    end

    def addFlightNum(flightNum)
	@flightNums.push(flightNum)
    end

    def getFlightNums()
	return @flightNums
    end

    def setFlightPrice(price)
	@flightPrice = price
    end

    def getFlightPrice()
	return @flightPrice
    end
end

options = {:departingAirport => nil, :destinationAirport => nil, :destFile => nil, :travelDate => nil}

parser = OptionParser.new do |opts|
    opts.banner = "Usage: southwest.rb [options]"
    
    opts.on('--orig n') do |originAirport|
	options[:departingAirport] = originAirport
    end

    opts.on('--dest n') do |destAirport|
        options[:destination] = destAirport
    end

    opts.on('--destFile file') do |destFile|
	options[:destFile] = destFile
    end

    opts.on('--date n') do |date|
        options[:travelDate] = date
    end
end

parser.parse!

#Setip DynamoDB
dynamo_db = AWS::DynamoDB.new
table = dynamo_db.tables['sbsw']
table.hash_key = [:airport_combo, :string]
table.range_key = [:date, :string]

airport_combo = options[:departingAirport] + "/BHM"
item = table.items.create('airport_combo' => airport_combo, 'date' => options[:travelDate])

agent = Mechanize.new

# Get the flickr sign in page
page = agent.get 'https://www.southwest.com/flight/search-flight.html'

#Fill out the search form
form = page.form('buildItineraryForm')
form.originAirport = options[:departingAirport]
form.radiobuttons_with(:name => 'twoWayTrip')[1].check
form.destinationAirport = options[:destination]
form.outboundDateString = options[:travelDate]
page = form.submit


results = page.form('searchResults')
matchingFlights = Array.new

results.radiobuttons_with(:name => 'outboundTrip').each_with_index do |entry, index|
    text = entry.value
    if text.include? "BHM"
	flight = FlightInfo.new
	flightNum = text.sub!(/2015.*\d+:\d+,/, "")
	flightNum = flightNum.split(',')
	flight.addFlightNum(flightNum[0])
	unless flightNum[10] == nil
	    flight.addFlightNum(flightNum[10])
	end
	matchingFlights.push(flight)
    end
end

if matchingFlights.empty?
    puts "No Flight Results :("
else
    puts "Your flight results from " + options[:departingAirport] + " to " + options[:destination]
    matchingFlights.each do |flight|
    	flightNums = flight.getFlightNums()
	combinedNum = ""
	if flightNums.length < 2
	    combinedNum = flightNums[0]
	else
	    combinedNum += flightNums[0]
	    combinedNum += "/"
	    combinedNum += flightNums[1]
        end
	price = results.fields_with(:name => /#{combinedNum}OmnitureDataPointsOutbound/)[0].value
        price = price.split(':')
        price = price[2]
        flight.setFlightPrice(price)
        puts flightNums[0] + "/" + ": $" + price
	item.attributes.set 'price' => price
	item.attributes.set 'flight_num' => combinedNum
    end
end
