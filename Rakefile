$:.unshift(File.dirname(__FILE__) + '/../../lib')

require 'bundler'
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = %w{--format progress} + %w{--format html --out spec/spec.html}
end

task :default => :spec
