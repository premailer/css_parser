Gem::Specification.new do |s|
  s.name     = "css_parser"
  s.version  = "1.2.1"
  s.date     = "2011-09-07"
  s.summary  = "Ruby CSS parser."
  s.description  = "A set of classes for parsing CSS in Ruby."
  s.email    = "code@dunae.ca"
  s.homepage = "https://github.com/alexdunae/css_parser"
  s.has_rdoc = true
  s.author  = "Alex Dunae"
  s.add_dependency('addressable')
  s.platform = Gem::Platform::RUBY
  s.rdoc_options << '--all' << '--inline-source' << '--line-numbers' << '--charset' << 'utf-8'
  s.files = (Dir.glob('lib/*.rb') | Dir.glob('lib/**/*.rb') | Dir.glob('test/**/*'))
  s.test_files = Dir.glob('test/test_*.rb') 
end

