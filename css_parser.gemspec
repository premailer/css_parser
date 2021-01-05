# frozen_string_literal: true

name = 'css_parser'
require "./lib/#{name}/version"

Gem::Specification.new name, CssParser::VERSION do |s|
  s.summary = 'Ruby CSS parser.'
  s.description = 'A set of classes for parsing CSS in Ruby.'
  s.email    = 'code@dunae.ca'
  s.homepage = "https://github.com/premailer/#{name}"
  s.author = 'Alex Dunae'
  s.files = Dir.glob('lib/**/*') + ['MIT-LICENSE']
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.4'

  s.metadata['changelog_uri'] = 'https://github.com/premailer/css_parser/blob/master/CHANGELOG.md'
  s.metadata['source_code_uri'] = 'https://github.com/premailer/css_parser'
  s.metadata['bug_tracker_uri'] = 'https://github.com/premailer/css_parser/issues'

  s.add_runtime_dependency 'addressable'

  s.add_development_dependency 'bump'
  s.add_development_dependency 'maxitest'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubocop', '~> 1.8'
  s.add_development_dependency 'rubocop-rake'
  s.add_development_dependency 'webrick'
end
