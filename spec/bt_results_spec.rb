require 'support/project'
require 'json'

ENV['PATH'] = File.join(File.dirname(__FILE__), '/../bin') + ':' + ENV['PATH']

describe 'bt-results' do
  include Project::RSpec

  let(:first_result) { project.bt_ref('first', project.head).commit }
  let(:second_result) { project.bt_ref('second', project.head).commit }

  project do |p|
    p.stage :first, <<-eos
  run: echo \"blah\" > new_file
  results:
    - new_file
    eos

  p.stage :second, <<-eos
  run: echo \"blah blah\" >> new_file
  needs:
    - first
  results:
    - new_file
    eos
  end

  result_of_executing 'bt-results --format json' do
    should == [{
      project.head.sha => {
        'first' => {},
        'second' => {}
      }
    }].to_json
  end

  result_of_executing 'bt-results' do
    should == <<-eos
Results (#{project.head.sha}):

first: 
second: 
    eos
  end

  result_of_executing 'bt-results --format text' do
    should == <<-eos
Results (#{project.head.sha}):

first: 
second: 
    eos
  end


  after_executing 'bt-go --once' do
    result_of_executing 'bt-results --format json' do
      should == [{
        project.head.sha => {
          'first' => {
            'message' => 'PASS bt loves you',
            'sha' => first_result.sha
          },
          'second' => {}
        }
      }].to_json
    end

    result_of_executing 'bt-results' do
      should == <<-eos
Results (#{project.head.sha}):

first: PASS bt loves you (#{first_result.sha})
second: 
      eos
    end
  end

  after_executing 'bt-go' do
    result_of_executing 'bt-results' do
      should == <<-eos
Results (#{project.head.sha}):

first: PASS bt loves you (#{first_result.sha})
second: PASS bt loves you (#{second_result.sha})
      eos
    end

    result_of_executing 'bt-results --format json' do
      should == [{
        project.head.sha => {
          'first' => {
            'message' => 'PASS bt loves you',
            'sha' => first_result.sha
          },
          'second' => {
            'message' => 'PASS bt loves you',
            'sha' => second_result.sha
          }
        }
      }].to_json
    end
  end
end

describe 'bt-results' do
  include Project::RSpec

  project do |p|
    p.passing_stage :first
    p.passing_stage :second
  end

  after_executing 'bt-go' do
    result_of_executing 'bt-results --format short' do
      should == "#{project.head.sha}: PASS"
    end
  end

  after_executing 'bt-go --once' do
    result_of_executing 'bt-results --format short' do
      should == "#{project.head.sha}: IN PROGRESS"
    end
  end
end
