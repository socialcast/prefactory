# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prefactory/version'

rspec_version = case ENV["RSPEC_VERSION"].to_s
                when ''
                  "~> 0"
                else
                  "~> #{ENV['RSPEC_VERSION']}"
                end

active_record_version = case ENV["ACTIVE_RECORD_VERSION"].to_s
                        when 'master'
                          { github: "rails/activerecord" }
                        when ''
                          "~> 4"
                        else
                          "~> #{ENV['ACTIVE_RECORD_VERSION']}"
                        end

Gem::Specification.new do |spec|
  spec.name          = 'prefactory'
  spec.version       = Prefactory::VERSION
  spec.authors       = ['developers@socialcast.com']
  spec.email         = ['developers@socialcast.com']
  spec.summary       = %q{Transaction-wrapped RSpec example groups with FactoryGirl integration}
  spec.description   = %q{Create factory objects in before-all blocks for fixture-like performance}
  spec.homepage      = 'https://github.socialcast.com/prefactory'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'rspec_around_all', '~> 0'
  spec.add_dependency 'rspec', rspec_version
  spec.add_dependency 'activerecord', active_record_version
  spec.add_dependency 'factory_girl_rails', '~> 4'

  spec.add_development_dependency 'mysql2', '~> 0.3'
  spec.add_development_dependency 'sqlite3', '~> 1'
  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'socialcast-git-extensions', '~> 3'
end
