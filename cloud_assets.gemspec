# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cloud_assets/version"

Gem::Specification.new do |s|
  s.name        = "cloud_assets"
  s.version     = CloudAssets::VERSION
  s.authors     = ["Rob Heittman"]
  s.email       = ["heittman.rob@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{
    Enables a Rails app to make transparent use of
    assets on a remote server in an alternative technology.
  }
  s.description = %q{
    This isn't meant for general purpose use yet, but
    rather to recycle some frequently used code among
    my projects.
  }

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "typhoeus"
  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "dalli"
end
