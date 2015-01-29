$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "css_parser"
require "#{name}/version"

Gem::Specification.new name, CssParser::VERSION.dup do |s|
  s.summary  = "Ruby CSS parser."
  s.description  = "A set of classes for parsing CSS in Ruby."
  s.email    = "code@dunae.ca"
  s.homepage = "https://github.com/premailer/#{name}"
  s.author  = "Alex Dunae"
  s.add_runtime_dependency 'addressable'
  s.files = Dir.glob("lib/**/*")
  s.license = "MIT"
end
