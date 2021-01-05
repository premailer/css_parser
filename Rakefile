require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'bump/tasks'

Rake::TestTask.new do |test|
  test.verbose = true
end

RuboCop::RakeTask.new

desc 'Run a performance evaluation.'
task :benchmark do
  require 'benchmark'
  require 'css_parser'

  base_dir = File.dirname(__FILE__) + '/test/fixtures'

  # parse the import1 file to benchmark file loading
  time = Benchmark.measure do
    10000.times do
      parser = CssParser::Parser.new
      parser.load_file!('import1.css', base_dir)
    end
  end
  puts "Parsing 'import1.css' 10 000 times took #{time.real.round(4)} seconds"

  # parse the import1 file to benchmark rule parsing
  time = Benchmark.measure do
    1000.times do
      parser = CssParser::Parser.new
      parser.load_file!('complex.css', base_dir)
    end
  end
  puts "Parsing 'complex.css' 1 000 times took #{time.real.round(4)} seconds"
end

task default: %i[rubocop test]
