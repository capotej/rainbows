# -*- encoding: binary -*-
manifest = File.exist?('.manifest') ?
  IO.readlines('.manifest').map!(&:chomp!) : `git ls-files`.split("\n")
  
Gem::Specification.new do |s|
  s.name = %q{rainbows}
  s.version = (ENV["VERSION"] || '5.1.1').dup

  s.authors = ['Rainbows! hackers']
  s.description = File.read('README').split("\n\n")[1]
  s.email = %q{rainbows-public@bogomips.org}
  s.executables = %w(rainbows)
  s.extra_rdoc_files = IO.readlines('.document').map!(&:chomp!).keep_if do |f|
    File.exist?(f)
  end
  s.files = manifest
  s.homepage = 'https://bogomips.org/rainbows/'
  s.summary = 'Rack app server for sleepy apps and slow clients'

  # we want a newer Rack for a valid HeaderHash#each
  s.add_dependency(%q<rack>, ['>= 1.1', '< 3.0'])

  # kgio 2.5 has kgio_wait_* methods that take optional timeout args
  s.add_dependency(%q<kgio>, ['~> 2.5'])

  # we need unicorn for the HTTP parser and process management
  # we need unicorn 5.1+ to relax the Rack dependency.
  s.add_dependency(%q<unicorn>, ["~> 5.1"])

  s.add_development_dependency(%q<isolate>, "~> 3.1")
  s.add_development_dependency(%q<olddoc>, "~> 1.2")

  # optional runtime dependencies depending on configuration
  # see t/test_isolate.rb for the exact versions we've tested with
  #
  # Revactor >= 0.1.5 includes UNIX domain socket support
  # s.add_dependency(%q<revactor>, [">= 0.1.5"])
  #
  # Revactor depends on Rev, too, 0.3.0 got the ability to attach IOs
  # s.add_dependency(%q<rev>, [">= 0.3.2"])
  #
  # Cool.io is the new Rev, but it doesn't work with Revactor
  # s.add_dependency(%q<cool.io>, [">= 1.0"])
  #
  # Rev depends on IOBuffer, which got faster in 0.1.3
  # s.add_dependency(%q<iobuffer>, [">= 0.1.3"])
  #
  # We use the new EM::attach/watch API in 0.12.10
  # s.add_dependency(%q<eventmachine>, ["~> 0.12.10"])
  #
  # NeverBlock, currently only available on http://gems.github.com/
  # s.add_dependency(%q<espace-neverblock>, ["~> 0.1.6.1"])

  # Note: To avoid ambiguity, we intentionally avoid the SPDX-compatible
  # 'Ruby' here since Ruby 1.9.3 switched to BSD-2-Clause license while
  # we already inherited our license from Mongrel during Ruby 1.8.
  # We cannot automatically switch licenses when Ruby changes their license,
  # so we remain optionally-licensed under the terms of Ruby 1.8 despite
  # not having a good way to specify this in an SPDX-compatible way...
  s.licenses = ['GPL-2.0+', 'Nonstandard'] # Nonstandard = 'Ruby 1.8'
end
