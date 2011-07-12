require 'support/project'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-watch' do
  include Project::RSpec

  project do |p|
    p.passing_stage 'first'
  end

  after_executing_async 'bt-watch' do
    it { should have_bt_ref('first', project.head).eventually }
  end
end

