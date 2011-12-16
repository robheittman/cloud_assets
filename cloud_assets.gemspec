# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cloud_assets/version"

Gem::Specification.new do |s|
  s.name        = "cloud_assets"
  s.version     = CloudAssets::VERSION
  s.authors     = ["Rob Heittman"]
  s.email       = ["heittman.rob@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "cloud_assets"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
