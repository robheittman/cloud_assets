# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cloud_assets/version"

Gem::Specification.new do |s|
  s.name        = "cloud_assets"
  s.version     = CloudAssets::VERSION
  s.authors     = ["Rob Heittman"]
  s.email       = ["rob.heittman@solertium.com"]
  s.homepage    = "https://github.com/rfc2616/cloud_assets"
  s.summary     = %q{
    Enables a Rails app to make transparent use of
    assets on a remote server in an alternative technology.
  }
  s.description = %q{
    This gem is in use in some production sites to provide
    backing for a Rails app using content from WordPress and
    PostLaunch (a Java based CMS), and has specific
    dependencies on Typhoeus, Nokogiri, and dalli, favorites
    we use at Solertium. It's in the early stages of
    being made into a general purpose tool -- cleanup,
    generalized tests (our site-specific ones are stripped
    from the gem) documentation, performance, and decoupling
    from dependencies.
  }

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "typhoeus", "~>0.4.2"
  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "dalli"
end
