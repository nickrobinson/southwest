require 'rubygems'
require 'mechanize'
require 'optparse'

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

options = {:departingAirport => nil, :destinationAirport => nil, :travelDate => nil}

parser = OptionParser.new do |opts|
    opts.banner = "Usage: southwest.rb [options]"
    
    opts.on('--orig n') do |originAirport|
	options[:departingAirport] = originAirport
    end

    opts.on('--dest n') do |destAirport|
        options[:destination] = destAirport
    end

    opts.on('--date n') do |date|
        options[:travelDate] = date
    end
end

parser.parse!

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
	flightNum1 = text.sub!(/2015.*\d+:\d+,/, "")
	flightNum1 = flightNum1.split(',')
	flight.addFlightNum(flightNum1[0])
	flight.addFlightNum(flightNum1[10])
	matchingFlights.push(flight)
    end
end

if matchingFlights.empty?
    puts "No Flight Results :("
else
    puts "Your flight results from " + options[:departingAirport] + " to " + options[:destination]
    matchingFlights.each do |flight|
    	flightNums = flight.getFlightNums()
        price = results.fields_with(:name => /#{flightNums[0]}\/#{flightNums[1]}OmnitureDataPointsOutbound/)[0].value
        price = price.split(':')
        price = price[2]
        flight.setFlightPrice(price)
        puts flightNums[0] + "/" + flightNums[1] + ": $" + price
    end
end
