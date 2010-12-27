# -*- encoding: binary -*-
# :enddoc:

RUBY_VERSION =~ %r{\A1\.8} and
  warn "Rev and Threads do not mix well under Ruby 1.8"

class Rainbows::Rev::ThreadClient < Rainbows::Rev::Client
  def app_call
    KATO.delete(self)
    disable if enabled?
    @env[RACK_INPUT] = @input
    app_dispatch # must be implemented by subclass
  end

  # this is only called in the master thread
  def response_write(response)
    alive = @hp.next? && G.alive
    rev_write_response(response, alive)
    return quit unless alive && :close != @state

    @state = :headers
  end

  # fails-safe application dispatch, we absolutely cannot
  # afford to fail or raise an exception (killing the thread)
  # here because that could cause a deadlock and we'd leak FDs
  def app_response
    begin
      @env[REMOTE_ADDR] = @_io.kgio_addr
      APP.call(@env.update(RACK_DEFAULTS))
    rescue => e
      Rainbows::Error.app(e) # we guarantee this does not raise
      [ 500, {}, [] ]
    end
  end
end