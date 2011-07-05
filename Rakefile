$:.unshift(File.dirname(__FILE__) + '/../../lib')

require 'bundler'
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

desc 'Run specs'
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = %w{--color --format progress}
end

task :default => :spec
