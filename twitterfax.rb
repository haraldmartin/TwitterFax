%w[rubygems twitter json prawn tempfile open-uri].each { |l| require l }

OAUTH_TOKEN  = "token"
OAUTH_SECRET = "secret"

DATA_FILE    = File.dirname(__FILE__) + "/twitterfax.json"
PRINTER_NAME = 'HP_LaserJet_2420' # `lpstat -a`

IMAGE_SERVICES = {
  %r{(\s*http://yfrog.com/(\w+)\s*)} => "http://yfrog.com/%s.th.jpg",
  %r{(\s*http://twitpic.com/(\w+)\s*)} => "http://twitpic.com/show/thumb/%s",
}

data_string  = File.read(DATA_FILE) rescue "{}"
data         = JSON.parse(data_string)
oauth        = Twitter::OAuth.new(OAUTH_TOKEN, OAUTH_SECRET)

unless data['atoken'] && data['asecret']
  %x(open #{oauth.request_token.authorize_url})
  
  puts "Please check your web browser and enter the PIN Code from Twitter"
  pin_code = gets.chop
  oauth.authorize_from_request(oauth.request_token.token, oauth.request_token.secret, pin_code)
  
  data.update({
    'atoken'  => oauth.access_token.token,
    'asecret' => oauth.access_token.secret,
  })
end

oauth.authorize_from_access(data['atoken'], data['asecret'])
twitter = Twitter::Base.new(oauth)
mentions = twitter.mentions({ "since_id" => data["since_id"] })

mentions.each do |tweet|
  temp = Tempfile.new('print_tweet_')
  time = Time.parse(tweet.created_at).strftime('%H:%M %B %d %Y')
  
  images = []
  
  Prawn::Document.generate(temp.path, :margin => 59, :left_margin => 107, :right_margin => 55) do |pdf|
    text = tweet.text

    IMAGE_SERVICES.each do |pattern, embed_url|
      text.scan(pattern).each do |url, id|
        images << sprintf(embed_url, id)
        text.gsub!(url, '')
      end
    end

    pdf.font File.dirname(__FILE__) + '/LucidFaxEFRom.ttf'
    pdf.font_size 42
    pdf.text text, :leading => 10
    
    images.each do |url|
      pdf.move_down 10
      pdf.image open(url), :scale => 2
    end
    
    pdf.move_down 20
    
    pdf.text "By @#{tweet.user['screen_name']}\n#{time}", :leading => 10
  end
  
  # `open -a Preview #{temp.path}`
  `lp -d "#{PRINTER_NAME}" #{temp.path}`
end

data["since_id"] = mentions.first.id if mentions.size > 0
File.open(DATA_FILE, 'w') { |f| f.write(data.to_json) }