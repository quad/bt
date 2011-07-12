# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "bt/version"

Gem::Specification.new do |s| 
  s.name        = BT::NAME
  s.version     = BT::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Scott Robinson", "Andrew Kiellor"]
  s.email       = ["scott@quadhome.com", "akiellor@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{bt is to continuous integration as git is to version control.}
  s.description = %q{bt is to continuous integration as git is to version control.}

  s.rubyforge_project = BT::NAME

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_development_dependency('rspec')
  s.add_development_dependency('rake')
  s.add_dependency('dnssd')
  s.add_dependency('andand')
  s.add_dependency('grit')
  s.add_dependency('trollop')
  s.add_dependency('uuid')
  s.add_dependency('sinatra')
  s.add_dependency('thin')
  s.add_dependency('haml')
end
