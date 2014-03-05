require 'hipchat'
require 'json'

module ExceptionsToHipchat
  class Notifier
    def initialize(app, options = {}, client = nil)
      @app = app
      token=options[:api_token] rescue raise("HipChat API token is required")
      @format=options[:message_format]||='text'
      @client = client || HipChat::Client.new(token)
      @room = options[:room] || raise("HipChat room is required")
      @color = options[:color] || :red
      @notify = options[:notify]
      @user = (options[:user] || "Notifier")[0...14]
      @ignore = options[:ignore]
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      user=env['rack.session']["warden.user.user.key"][0][0] rescue nil
      important_stuff={:hostname=> `hostname`,
                       :uri=> env['REQUEST_URI'],
                       :server=> env['SERVER_NAME'],
                       :host=> env['HTTP_HOST']}
      send_to_hipchat("#{Time.now} #{user} @ #{important_stuff.to_json} \n\n#{exception}\n #{exception.backtrace.first(3)}") unless @ignore && @ignore.match(exception.to_s)
      raise exception
    end

    def send_to_hipchat(exception)
      begin

        @client[@room].send(@user, "\n#{message_for(exception).to_s}", :color => @color, :notify => @notify,:message_format=>@format)
      rescue => hipchat_exception
        $stderr.puts "\nWARN: Unable to send message to HipChat: #{hipchat_exception}\n"
      end
    end

    def message_for(exception)
      "[#{exception.class}] #{exception}"
    end
  end
end
