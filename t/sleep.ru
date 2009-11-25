use Rack::ContentLength

run lambda { |env|
  /\A100-continue\z/i =~ env['HTTP_EXPECT'] and return [ 100, {}, [] ]

  env['rack.input'].read
  nr = 1
  env["PATH_INFO"] =~ %r{/([\d\.]+)\z} and nr = $1.to_f

  (case env['rainbows.model']
  when :FiberPool, :FiberSpawn
    Rainbows::Fiber
  when :Revactor
    Actor
  else
    Kernel
  end).sleep(nr)

  [ 200, {'Content-Type' => 'text/plain'}, [ "Hello\n" ] ]
}
