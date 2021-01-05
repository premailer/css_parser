# frozen_string_literal: true

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

  fixtures_dir = Pathname.new(__dir__).join('/test/fixtures')

  # parse the import1 file to benchmark file loading
  time = Benchmark.measure do
    10_000.times do
      parser = CssParser::Parser.new
      parser.load_file!(fixtures_dir.join('import1.css'))
    end
  end
  puts "Parsing 'import1.css' 10 000 times took #{time.real.round(4)} seconds"

  # parse the import1 file to benchmark rule parsing
  time = Benchmark.measure do
    1000.times do
      parser = CssParser::Parser.new
      parser.load_file!(fixtures_dir.join('complex.css'))
    end
  end
  puts "Parsing 'complex.css' 1 000 times took #{time.real.round(4)} seconds"
end

task default: %i[rubocop test]
