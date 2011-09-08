require 'rubygems'
require 'eaal'
require 'set'
require 'open-uri'

def build_audit(assets)
  quantities = {}
  assets.each do |asset|
    typeID = asset.typeID.to_i
    quantities[typeID] = (quantities[typeID] or 0) + 1
    contents = asset.container["contents"]
    if contents
      quantities.merge!(build_audit(contents)) do |typeID, q1, q2|
        q1 + q2
      end
    end
  end
  quantities
end


if ARGV.size < 2
  puts "Usage: #{__FILE__} keyID vCode"
  exit
end

api = EAAL::API.new(ARGV[0], ARGV[1])

typeIDs_to_fetch = Set.new
asset_data = {}
api.Characters.characters.each do |char|
  puts "Analysing #{char.name}"
  api.scope = "char"
  assets = api.AssetList(:characterID => char.characterID).assets
  quantities = build_audit(assets)
  asset_data[char.name] = quantities
  quantities.keys.each do |typeID|
    typeIDs_to_fetch.add(typeID)
  end
end

puts "Fetching #{typeIDs_to_fetch.size} prices"
max_requests_at_once = 100
prices = {}
base_url = "http://api.eve-central.com/api/marketstat?regionlimit=10000002&"

typeIDs_to_fetch.each_slice(max_requests_at_once) do |slice|
  req_url = base_url + slice.map do |typeID|
    "typeid=#{typeID}"
  end.join("&")

  data = open(req_url).read
  doc, status = Hpricot::XML(data)
  (doc/:evec_api/:marketstat/:type).each do |e|
    typeID = e["id"].to_i
    price = (e/:sell).at(:avg).inner_html.to_f
    prices[typeID] = price
  end
end

asset_data.each do |(char_name, assets)|
  sum = 0
  assets.each do |(typeID, quantity)|
    sum += prices[typeID] * quantity
  end
  
  puts "#{char_name} is worth #{sum}"
end

