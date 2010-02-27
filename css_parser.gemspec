require 'rake'

Gem::Specification.new do |s|
  s.name     = "css_parser"
  s.version  = "1.1.0"
  s.date     = "2010-02-26"
  s.summary  = "Ruby CSS parser."
  s.description  = "A set of classes for parsing CSS in Ruby."
  s.email    = "code@dunae.ca"
  s.homepage = "http://github.com/alexdunae/css_parser"
  s.has_rdoc = true
  s.author  = "Alex Dunae"
  s.platform = Gem::Platform::RUBY
  s.rdoc_options << '--all' << '--inline-source' << '--line-numbers' << '--charset' << 'utf-8'
  s.files = FileList['lib/*.rb', 'lib/**/*.rb', 'test/**/*'].to_a
  s.test_files = Dir.glob('test/test_*.rb') 
end

