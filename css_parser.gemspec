Gem::Specification.new do |s|
  s.name     = "kajabi-css_parser"
  s.version  = "1.2.7"
  s.date     = "2011-12-13"
  s.summary  = "Ruby CSS parser."
  s.description  = "A set of classes for parsing CSS in Ruby."
  s.email    = ["xternal1+github@gmail.com", "code@dunae.ca"]
  s.homepage = "https://github.com/kajabi/css_parser"
  s.has_rdoc = true
  s.authors  = ["Brendon Murphy",  "Alex Dunae"]
  s.add_dependency('addressable')
  s.add_dependency('rdoc')
  s.add_development_dependency('rake')
  s.platform = Gem::Platform::RUBY
  s.rdoc_options << '--all' << '--inline-source' << '--line-numbers' << '--charset' << 'utf-8'
  s.files = (Dir.glob('lib/*.rb') | Dir.glob('lib/**/*.rb') | Dir.glob('test/**/*'))
  s.test_files = Dir.glob('test/test_*.rb') 
end

