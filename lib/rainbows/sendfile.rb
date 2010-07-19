# -*- encoding: binary -*-
# This middleware handles X-\Sendfile headers generated by applications
# or middlewares down the stack.  It should be placed at the top
# (outermost layer) of the middleware stack to avoid having its
# +to_path+ method clobbered by another middleware.
#
# This converts X-\Sendfile responses to bodies which respond to the
# +to_path+ method which allows certain concurrency models to serve
# efficiently using sendfile() or similar.  With multithreaded models
# under Ruby 1.9, IO.copy_stream will be used.
#
# This middleware is the opposite of Rack::Sendfile as it
# reverses the effect of Rack:::Sendfile.  Unlike many Ruby
# web servers, some configurations of \Rainbows! are capable of
# serving static files efficiently.
#
# === Compatibility (via IO.copy_stream in Ruby 1.9):
# * ThreadSpawn
# * ThreadPool
# * WriterThreadPool
# * WriterThreadSpawn
#
# === Compatibility (Ruby 1.8 and 1.9)
# * EventMachine
# * NeverBlock (using EventMachine)
#
# DO NOT use this middleware if you're proxying to \Rainbows! with a
# server that understands X-\Sendfile (e.g. Apache, Lighttpd) natively.
#
# This does NOT understand X-Accel-Redirect headers intended for nginx.
# X-Accel-Redirect requires the application to be highly coupled with
# the corresponding nginx configuration, and is thus too complicated to
# be worth supporting.
#
# Example config.ru:
#
#    use Rainbows::Sendfile
#    run lambda { |env|
#      path = "#{Dir.pwd}/random_blob"
#      [ 200,
#        {
#          'X-Sendfile' => path,
#          'Content-Type' => 'application/octet-stream'
#        },
#        []
#      ]
#    }

class Rainbows::Sendfile < Struct.new(:app)

  # Body wrapper, this allows us to fall back gracefully to
  # +each+ in case a given concurrency model does not optimize
  # +to_path+ calls.
  class Body < Struct.new(:to_path) # :nodoc: all
    CONTENT_LENGTH = 'Content-Length'.freeze

    def self.new(path, headers)
      unless headers[CONTENT_LENGTH]
        stat = File.stat(path)
        headers[CONTENT_LENGTH] = stat.size.to_s if stat.file?
      end
      super(path)
    end

    # fallback in case our +to_path+ doesn't get handled for whatever reason
    def each(&block)
      buf = ''
      File.open(to_path, 'rb') do |fp|
        yield buf while fp.read(0x4000, buf)
      end
    end
  end

  # :stopdoc:
  HH = Rack::Utils::HeaderHash
  X_SENDFILE = 'X-Sendfile'
  # :startdoc:

  def call(env) # :nodoc:
    status, headers, body = app.call(env)
    headers = HH.new(headers)
    if path = headers.delete(X_SENDFILE)
      body = Body.new(path, headers) unless body.respond_to?(:to_path)
    end
    [ status, headers, body ]
  end
end
