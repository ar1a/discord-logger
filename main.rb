require 'discordrb'
require 'rubygems'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'sqlite:db.sqlite3')

class Server
  include DataMapper::Resource
  property :id, Serial
  property :uid, Integer
  property :name, String
  has n, :channels
end

class Channel
  include DataMapper::Resource
  property :id, Serial
  property :uid, Integer
  property :name, String
  has n, :messages
  belongs_to :server
end
class Message
  include DataMapper::Resource
  property :id, Serial
  property :uid, Integer, required: true
  property :author, String
  property :content, String
  property :posted_at, DateTime
  belongs_to :channel
end

DataMapper.finalize
DataMapper.auto_upgrade!

bot = Discordrb::Bot.new token: ENV['DISCORD_TOKEN'],
                         client_id: ENV['DISCORD_CLIENT_ID']

puts bot.invite_url

def get_logs(limit, channel)
  result = []
  before = nil
  loop do
    break unless limit > 0
    retrieve = limit < 100 ? limit : 100
    data = channel.history(retrieve, before)
    break if data.empty?
    limit -= retrieve
    result.concat data
    before = data.last.id
  end
  result
end

bot.ready do
  channel = ARGV[0]
  if channel.nil?
    puts 'Channel not found'
    exit
  end

  channel = bot.channel(channel)

  before = nil
  limit = 10_000 # CHANGE ME
  server = Server.first_or_create({ uid: channel.server.id },
                                  name: channel.server.name)
  ch = Channel.first_or_create({ uid: channel.id },
                               name: channel.name,
                               server: server)
  loop do
    break unless limit > 0
    retrieve = limit < 100 ? limit : 100
    data = channel.history(retrieve, before)
    break if data.empty?
    limit -= retrieve
    before = data.last.id
    data.each do |message|
      Message.first_or_create({ uid: message.id },
                              author: "#{message.author.username}##{message.author.discriminator}",
                              content: message.content,
                              posted_at: message.timestamp,
                              channel: ch)
    end
  end

  exit
end

bot.run
