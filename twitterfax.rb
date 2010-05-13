%w[rubygems twitter json prawn tempfile].each { |l| require l }

USERNAME     = 'screenname'
PASSWORD     = 'password'
DATA_FILE    = 'twitterfax.json'
PRINTER_NAME = 'HP_LaserJet_2420' # `lpstat -a`

data_string  = File.read(DATA_FILE) rescue "{}"
data         = JSON.parse(data_string)
http_auth    = Twitter::HTTPAuth.new(USERNAME, PASSWORD)
base         = Twitter::Base.new(http_auth)
mentions     = base.mentions#(data)

mentions.each do |tweet|
  temp = Tempfile.new('print_tweet_')
  time = Time.parse(tweet.created_at).strftime('%H:%M %B %d %Y')
  
  Prawn::Document.generate(temp.path, :margin => 59, :left_margin => 107, :right_margin => 55) do |pdf|
    # pdf.font 'LucidFaxEFRom.ttf'
    pdf.text "#{tweet.text}\n\nBy @#{tweet.user['screen_name']}\n#{time}", 
      :size => 42, :leading => 10, :kerning => true
  end
  
  # `open -a Preview #{temp.path}`
  `lp -d "#{PRINTER_NAME}" #{temp.path}`
end

if mentions.size > 0
  data["since_id"] = mentions.first.id
  File.open(DATA_FILE, 'w') { |f| f.write(data.to_json) }
end