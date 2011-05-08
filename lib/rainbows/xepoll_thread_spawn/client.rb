# -*- encoding: binary -*-
module Rainbows::XEpollThreadSpawn::Client
  HBUFSIZ = Rainbows.client_header_buffer_size
  N = Raindrops.new(1)
  max = Rainbows.server.worker_connections
  ACCEPTORS = Rainbows::HttpServer::LISTENERS.map do |sock|
    Thread.new do
      sleep
      buf = ""
      begin
        if io = sock.kgio_accept(Rainbows::Client)
          N.incr(0, 1)
          io.epoll_once(buf)
        end
        sleep while N[0] >= max
      rescue => e
        Rainbows::Error.listen_loop(e)
      end while Rainbows.alive
    end
  end

  ep = SleepyPenguin::Epoll
  EP = ep.new
  IN = ep::IN | ep::ET | ep::ONESHOT
  THRESH = max - 1
  KATO = {}
  KATO.compare_by_identity if KATO.respond_to?(:compare_by_identity)
  LOCK = Mutex.new
  @@last_expire = Time.now

  def kato_set
    LOCK.synchronize { KATO[self] = @@last_expire }
    EP.set(self, IN)
  end

  def kato_delete
    LOCK.synchronize { KATO.delete self }
  end

  def self.loop
    ACCEPTORS.each { |thr| thr.run }
    buf = ""
    begin
      EP.wait(nil, 1000) { |fl, obj| obj.epoll_run(buf) }
      expire
    rescue Errno::EINTR
    rescue => e
      Rainbows::Error.listen_loop(e)
    end while Rainbows.tick || N[0] > 0
    Rainbows::JoinThreads.acceptors(ACCEPTORS)
  end

  def self.expire
    return if ((now = Time.now) - @@last_expire) < 1.0
    if (ot = Rainbows.keepalive_timeout) >= 0
      ot = now - ot
      defer = []
      LOCK.synchronize do
        KATO.delete_if { |client, time| time < ot and defer << client }
      end
      defer.each { |io| io.closed? or io.close }
    end
    @@last_expire = now
  end

  def epoll_once(buf)
    @hp = Rainbows::HttpParser.new
    epoll_run(buf)
  end

  def close
    super
    kato_delete
    N.decr(0, 1) == THRESH and ACCEPTORS.each { |t| t.run }
    nil
  end

  def handle_error(e)
    super
    ensure
      closed? or close
  end

  def epoll_run(buf)
    case kgio_tryread(HBUFSIZ, buf)
    when :wait_readable
      return kato_set
    when String
      kato_delete
      @hp.buf << buf
      env = @hp.parse and return spawn(env, @hp)
    else
      return close
    end while true
    rescue => e
      handle_error(e)
  end

  def spawn(env, hp)
    Thread.new { process_pipeline(env, hp) }
  end

  def pipeline_ready(hp)
    hp.parse and return true
    case buf = kgio_tryread(HBUFSIZ)
    when :wait_readable
      kato_set
      return false
    when String
      hp.buf << buf
      hp.parse and return true
      # continue loop
    else
      return close
    end while true
  end
end
