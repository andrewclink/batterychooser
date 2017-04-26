#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'


class Battery
  attr_accessor :name
  attr_accessor :mah
  attr_accessor :amps
  attr_accessor :cost
  attr_accessor :pricebreak

  def initialize(&block)
    self.pricebreak = {}
    yield(self) if block_given?
  end
  
end

class Pack
  attr_accessor :cell
  attr_accessor :series
  attr_accessor :parallel
  attr_accessor :quantity # for price breaks, maybe we buy extra
  
  def initialize(&block)
    yield(self) if block_given?
  end
  
  def amps;  cell.amps * parallel rescue 0.1 end
  def mah;   cell.mah  * parallel rescue 10 end
  def volts; 4.2 * series rescue nil end
  def cost; 
    cell_count = parallel * series
    
    # Determine price breaks, sorted highest first
    breaks = cell.pricebreak.keys.sort.reverse rescue []
    
    # Check if we are within a few short of a price break
    breaks.each do |b|
      inc = b - cell_count
      if inc > 0 && inc < 3
        cell_count += inc
      end
    end
    
    pricequant = breaks.detect do |quantity|
      quantity <= cell_count
    end
    
    # Calculate the cell cost if we have price breaks, otherwise just use published cost
    cell_cost = if cell.pricebreak.has_key?(pricequant)
      cell.pricebreak[pricequant]
    else
      cell.cost
    end
    
    self.quantity = cell_count
    cell_count * cell_cost 
  end
end

batteries = []

def parse_cell_element(li)
  
  attrs = {}
  
  # Get Details except for price
  if elm = li.css(".details").first rescue false
    # puts "Details: #{elm.content}"
    
    # Get the href for the details page
    attrs[:href] = elm.css('h4[data-href]').first.attribute('data-href') rescue nil
    page_attrs = parse_cell_page(attrs[:href])
    attrs.merge!(page_attrs)
    
    # Remove details from name
    # Patchover missing details from product page
    d = elm.content
    d.gsub!(/flat/i, '')
    d.gsub!(/button/i, '')
    d.gsub! /top/i, ''
    d.gsub! /battery/i, ''
    d.gsub! /protected/i, ''
    
    # Find MAH
    mah_regex = /(\d+?)\ *mah/i
    if m = d.match(mah_regex)
      d.gsub! mah_regex, ''
      attrs[:mah] = m[1].to_i if attrs[:mah].nil?
    end
    
    # Find Amps
    amp_regex = /\s([\d\.]+?)\ *A/i
    if m = d.match(amp_regex)
      d.gsub! amp_regex, ''
      #attrs[:amp] = m[1].to_f if attrs[:amp].nil?
    end
    
    # Name is left over
    attrs[:name] = d.strip.gsub(/\s{2,}/, '')
        
  else 
    puts "- details not found -"
  end
  
  # Get Cell price
  if elm = li.css(".p-price").first rescue false
    # We might have a marked down price, in which case the last
    # text node is the valid price.
    attrs[:cost] = elm.children.last.content.gsub("$",'').to_f
  else
    "- price not found -"
  end
    
  return attrs
end

def parse_cell_page(href)
  Dir.mkdir("cache") unless File.exists?("cache")
  
  cache = File.join("cache", URI.parse(href).path.gsub(/\//, '') + ".html")
  
  attrs  = {}
  prices = {}
  
  # Do we have a cache?
  # Is it too old? (Don't pound the server and get shut down)
  doc = if File.exists?(cache)
    Nokogiri.HTML(open(cache))
  else
    puts "Cache miss"
    # Send to cache
    f = open(URI.parse(href), 'User-Agent'=> 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/602.4.8 (KHTML, like Gecko) Version/10.0.3 Safari/602.4.8')
    c = File.open(cache, "w") do |c|
      puts "-> Writing"
      c.write f.read
    end
    sleep(rand * 4)
    
    Nokogiri.HTML(open(cache))
  end

  if list = doc.css('.BulkDiscount ~ div ul').first
    list.css('li').each do |l|
      if m = l.content.match(/Buy (\d+).*\$([\d\.]+)/)
        prices[m[1].to_i] = m[2].to_f
      end
    end
  end
  attrs[:pricebreak] = prices

  # Correct Details if possible
  # This is really only neccessary because the discharge rating
  # sometimes isn't shown within the title. We could also
  # get the datasheet link here.
  #
  if details = doc.css(".ProductDescriptionContainer.prodAccordionContent li")
    content = details.inner_text
    m = content.match /Discharge\:\ *([\d\.]+)\s*A/i
    attrs[:amps] = m[1].to_i unless m.nil?
  end
  
  attrs
end

doc = Nokogiri.HTML(open("productlist.html"))
doc.css("li").each do |li|
  attrs = parse_cell_element(li)
  
  batteries << Battery.new do |b|
    %w|name cost mah amps pricebreak|.each do |a|
      b.send((a.to_s + '=').to_sym, attrs[a.to_sym]) if attrs.has_key? a.to_sym
    end
  end
end

# Custom cells
batteries << Battery.new do |b|
  b.name = "NCR20700"
  b.cost = 10
  b.pricebreak = {6 => 9.00,
                  12 => 8.00,
                  24 => 7.90,
                  36 => 7.75,
                  50 => 7.60,
                  100 => 7.35,
                  200 => 7.20,
                  400 => 7.00,
                  600 => 6.80,
                  1000 => 6.65}
  b.mah = 3100
  b.amps = 30
end



puts "Searching #{batteries.count} cells"

packs = []

spend = 150
min_s = 6
min_amps = 80
min_mah = 13000

batteries.each do |cell|
  # Figure out how many cells we can get for this price
  # Check price breaks, starting with the highest quantity first
  breaks = cell.pricebreak.keys.sort.reverse rescue {}
  cell_cost = 0
  count = 0
  breaks.each do |q|
    if q * cell.pricebreak[q] <= spend
      cell_cost = cell.pricebreak[q]
      break
    end
  end
  cell_cost = cell.cost if cell_cost == 0

  count = (spend / cell_cost).floor
  
  # We need a certain voltage
  next if (count < min_s)
  
  pack = Pack.new
  pack.cell = cell
  pack.series = min_s
  pack.parallel = (count / pack.series).floor
  
  next if pack.amps < min_amps rescue next
  next if pack.mah  < min_mah  rescue next
  
  packs << pack
end


# Sort first by amps
packs.sort! do |a, b|
  a.amps <=> b.amps
end 

# Sort by mah
packs.sort! do |a, b|
  a.mah <=> b.mah
end

packs.sort! do |a, b|
  a.cost <=> b.cost
end

# Display
packs.each do |pack|
  print "#{pack.cell.name.ljust(35)}: "
  print "#{pack.series}s#{pack.parallel}p "
  print "#{pack.amps.round.to_s.rjust(10)} A | "
  print "#{(pack.mah/1000.0).to_s.rjust(10)} Ah | "
  print "#{(pack.mah/1000.0 * 0.6).round(1).to_s.rjust(10)} Ah after 250 | "
  print "$#{pack.cost.round}"
  printf " | #{pack.quantity} x $%.2f", pack.cost/pack.quantity

  print "\n"
end

