# -*- encoding: binary -*-
autoload :Gem, 'rubygems'
autoload :Tempfile, 'tempfile'
require 'wrongdoc'

cgit_url = Wrongdoc.config[:cgit_url]
git_url = Wrongdoc.config[:git_url]

desc "read news article from STDIN and post to rubyforge"
task :publish_news do
  require 'rubyforge'
  spec = Gem::Specification.load('rainbows.gemspec')
  tmp = Tempfile.new('rf-news')
  _, subject, body = `git cat-file tag v#{spec.version}`.split(/\n\n/, 3)
  tmp.puts subject
  tmp.puts
  tmp.puts spec.description.strip
  tmp.puts ""
  tmp.puts "* #{spec.homepage}"
  tmp.puts "* #{spec.email}"
  tmp.puts "* #{git_url}"
  tmp.print "\nChanges:\n\n"
  tmp.puts body
  tmp.flush
  system(ENV["VISUAL"], tmp.path) or abort "#{ENV["VISUAL"]} failed: #$?"
  msg = File.readlines(tmp.path)
  subject = msg.shift
  blank = msg.shift
  blank == "\n" or abort "no newline after subject!"
  subject.strip!
  body = msg.join("").strip!

  rf = RubyForge.new.configure
  rf.login
  rf.post_news('rainbows', subject, body)
end

desc "post to FM"
task :fm_update do
  require 'net/http'
  require 'net/netrc'
  require 'json'
  version = ENV['VERSION'] or abort "VERSION= needed"
  uri = URI.parse('https://freecode.com/projects/rainbows/releases.json')
  rc = Net::Netrc.locate('rainbows-fm') or abort "~/.netrc not found"
  api_token = rc.password
  _, subject, body = `git cat-file tag v#{version}`.split(/\n\n/, 3)
  tmp = Tempfile.new('fm-changelog')
  tmp.puts subject
  tmp.puts
  tmp.puts body
  tmp.flush
  system(ENV["VISUAL"], tmp.path) or abort "#{ENV["VISUAL"]} failed: #$?"
  changelog = File.read(tmp.path).strip

  req = {
    "auth_code" => api_token,
    "release" => {
      "tag_list" => "Stable",
      "version" => version,
      "changelog" => changelog,
    },
  }.to_json
  if ! changelog.strip.empty? && version =~ %r{\A[\d\.]+\d+\z}
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      p http.post(uri.path, req, {'Content-Type'=>'application/json'})
    end
  else
    warn "not updating freshmeat for v#{version}"
  end
end
