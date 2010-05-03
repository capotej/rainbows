# -*- encoding: binary -*-
module Rainbows

# middleware used to enforce client_max_body_size for TeeInput users,
# there is no need to configure this middleware manually, it will
# automatically be configured for you based on the client_max_body_size
# setting
class MaxBody < Struct.new(:app)

  # this is meant to be included in Unicorn::TeeInput (and derived
  # classes) to limit body sizes
  module Limit
    Util = Unicorn::Util

    def initialize(socket, req, parser, buf)
      self.len = parser.content_length

      max = Rainbows.max_bytes # never nil, see MaxBody.setup
      if len && len > max
        socket.write(Const::ERROR_413_RESPONSE)
        socket.close
        raise IOError, "Content-Length too big: #{len} > #{max}", []
      end

      self.req = req
      self.parser = parser
      self.buf = buf
      self.socket = socket
      self.buf2 = ""
      if buf.size > 0
        parser.filter_body(buf2, buf) and finalize_input
        buf2.size > max and raise IOError, "chunked request body too big", []
      end
      self.tmp = len && len < Const::MAX_BODY ? StringIO.new("") : Util.tmpio
      if buf2.size > 0
        tmp.write(buf2)
        tmp.seek(0)
        max -= buf2.size
      end
      @max_body = max
    end

    def tee(length, dst)
      rv = _tee(length, dst)
      if rv && ((@max_body -= rv.size) < 0)
        $stderr.puts "#@max_body  TOO SMALL"
        # make HttpParser#keepalive? => false to force an immediate disconnect
        # after we write
        parser.reset
        throw :rainbows_EFBIG
      end
      rv
    end

  end

  # this is called after forking, so it won't ever affect the master
  # if it's reconfigured
  def self.setup
    Rainbows.max_bytes or return
    case G.server.use
    when :Rev, :EventMachine, :NeverBlock
      return
    when :Revactor
      Rainbows::Revactor::TeeInput
    else
      Unicorn::TeeInput
    end.class_eval do
      alias _tee tee # can't use super here :<
      remove_method :tee
      remove_method :initialize if G.server.use != :Revactor # FIXME CODE SMELL
      include Limit
    end

    # force ourselves to the outermost middleware layer
    G.server.app = MaxBody.new(G.server.app)
  end

  # Rack response returned when there's an error
  def err(env)
    [ 413, [ %w(Content-Length 0), %w(Content-Type text/plain) ], [] ]
  end

  # our main Rack middleware endpoint
  def call(env)
    catch(:rainbows_EFBIG) { app.call(env) } || err(env)
  end

end # class
end # module
