# -*- encoding: binary -*-
# :enddoc:
module Rainbows::ProcessClient
  include Rainbows::Response
  include Rainbows::Const

  NULL_IO = Unicorn::HttpRequest::NULL_IO
  IC = Unicorn::HttpRequest.input_class
  Rainbows.config!(self, :client_header_buffer_size, :keepalive_timeout)

  def read_expire
    Rainbows.now + KEEPALIVE_TIMEOUT
  end

  # used for reading headers (respecting keepalive_timeout)
  def timed_read(buf)
    expire = nil
    begin
      case rv = kgio_tryread(CLIENT_HEADER_BUFFER_SIZE, buf)
      when :wait_readable
        return if expire && expire < Rainbows.now
        expire ||= read_expire
        kgio_wait_readable(KEEPALIVE_TIMEOUT)
      else
        return rv
      end
    end while true
  end

  def process_loop
    @hp = hp = Rainbows::HttpParser.new
    kgio_read!(CLIENT_HEADER_BUFFER_SIZE, buf = hp.buf) or return

    begin # loop
      until env = hp.parse
        timed_read(buf2 ||= "") or return
        buf << buf2
      end

      set_input(env, hp)
      env['REMOTE_ADDR'] = kgio_addr
      hp.hijack_setup(to_io)
      status, headers, body = APP.call(env.merge!(RACK_DEFAULTS))

      if 100 == status.to_i
        write("HTTP/1.1 100 Continue\r\n\r\n".freeze)
        env.delete('HTTP_EXPECT'.freeze)
        status, headers, body = APP.call(env)
      end
      return if hp.hijacked?
      write_response(status, headers, body, alive = hp.next?) or return
    end while alive
  # if we get any error, try to write something back to the client
  # assuming we haven't closed the socket, but don't get hung up
  # if the socket is already closed or broken.  We'll always ensure
  # the socket is closed at the end of this function
  rescue => e
    handle_error(e)
  ensure
    close unless closed? || hp.hijacked?
  end

  def handle_error(e)
    Rainbows::Error.write(self, e)
  end

  def set_input(env, hp)
    env['rack.input'] = 0 == hp.content_length ? NULL_IO : IC.new(self, hp)
  end

  def process_pipeline(env, hp)
    begin
      set_input(env, hp)
      env['REMOTE_ADDR'] = kgio_addr
      hp.hijack_setup(to_io)
      status, headers, body = APP.call(env.merge!(RACK_DEFAULTS))
      if 100 == status.to_i
        write("HTTP/1.1 100 Continue\r\n\r\n".freeze)
        env.delete('HTTP_EXPECT'.freeze)
        status, headers, body = APP.call(env)
      end
      return if hp.hijacked?
      write_response(status, headers, body, alive = hp.next?) or return
    end while alive && pipeline_ready(hp)
    alive or close
    rescue => e
      handle_error(e)
  end

  # override this in subclass/module
  def pipeline_ready(hp)
  end
end
