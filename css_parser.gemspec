Gem::Specification.new "css_parser", "1.2.6" do |s|
  s.summary  = "Ruby CSS parser."
  s.description  = "A set of classes for parsing CSS in Ruby."
  s.email    = "code@dunae.ca"
  s.homepage = "https://github.com/alexdunae/css_parser"
  s.author  = "Alex Dunae"
  s.add_runtime_dependency 'addressable'
  s.files = Dir.glob("lib/**/*")
  s.license = "MIT"
end
