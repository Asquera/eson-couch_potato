# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
#require "./lib/elsearch"

Gem::Specification.new do |s|
  s.name        = "eson-couch_potato"
  s.version     = "0.7.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Florian Gilcher"]
  s.email       = ["florian.gilcher@asquera.de"]
  s.homepage    = ""
  s.summary     = %q{Integrates the Eson ElasticSearch client with CouchPotato}
  s.description = %q{Integrates the Eson ElasticSearch client with CouchPotato.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  #s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "multi_json"
  s.add_development_dependency "elasticsearch-node"
end
