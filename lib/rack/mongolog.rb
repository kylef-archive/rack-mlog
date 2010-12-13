require 'mongo'
require 'uri'

module Rack
  class MongoLog
    def initialize(app, options={})
      @app = app
      
      @maps = default_map
      @collection = options[:collection] || 'mlog'

      @maps.update(options[:map]) if options.key?(:map)

      if not options.key?(:uri) and ENV.key?('MONGOHQ_URL')
        options[:uri] = ENV['MONGOHQ_URL']
      end

      # Setup the MongoDB Connection
      uri = URI.parse(options[:uri])
      conn = Mongo::Connection.from_uri(options[:uri])
      @db = conn.db(uri.path.gsub(/^\//, ''))
    end

    def default_map
      {
        :method => lambda { |env, status, headers, body| env['REQUEST_METHOD'] },
        :path => lambda { |env, status, headers, body| env['PATH_INFO'] },
        :status => lambda { |env, status, headers, body| status },
        :ip => lambda { |env, status, headers, body| env['REMOTE_ADDR'] },

        :user_agent => lambda { |env, status, headers, body| env['HTTP_USER_AGENT'] },
        :referer => lambda { |env, status, headers, body| env['HTTP_REFERER'] },
        :language => lambda { |env, status, headers, body| env['HTTP_ACCEPT_LANGUAGE'] },

        :redirect => lambda { |env, status, headers, body| ((status == 301) or (status == 302))? headers['Location'] : nil },

        :time => lambda { |env, status, headers, body| Time.now },

        :secure? => lambda { |env, status, headers, body| env['HTTPS'] == 'on' },
        :ajax? => lambda { |env, status, headers, body| env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest' }
      }
    end

    def call(env)
      status, header, body = @app.call(env)
      kwargs = {}

      @maps.each do |key, block|
        kwargs[key] = block.call(env, status, header, body)
      end

      @db[@collection].save(kwargs)

      [status, header, body]
    end
  end
end
