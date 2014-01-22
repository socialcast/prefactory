require 'rubygems'
require 'bundler'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rspec/matchers'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'debugger'
require 'support/callback_matcher'
require 'active_record'
require 'database_setup'

unless ENV['NO_PREFACTORY']
  require 'prefactory'

  RSpec.configure do |config|
    config.include Prefactory
  end
end

