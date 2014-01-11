# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prefactory/version'

Gem::Specification.new do |spec|
  spec.name          = 'prefactory'
  spec.version       = Prefactory::VERSION
  spec.authors       = ['Mike Silvis']
  spec.email         = ['msilvis@socialcast.com']
  spec.summary       = %q{Ease of FactoryGirl, performance from fixutres}
  spec.description   = ''
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_dependency 'rspec_around_all'
  spec.add_development_dependency 'rake'
end
