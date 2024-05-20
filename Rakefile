# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'bump/tasks'

task default: [:rubocop, :test]

Rake::TestTask.new do |test|
  test.pattern = 'test/**/test*.rb'
  test.verbose = true
end

RuboCop::RakeTask.new do |t|
  # allow you to run "$ rake rubocop -a" to autofix
  t.options << '-a' if ARGV.include?('-a')
  t.options << '-A' if ARGV.include?('-A')
end

desc 'Run a performance evaluation.'
task :benchmark do
  require 'css_parser'

  require 'benchmark/ips'
  require 'memory_profiler'

  fixtures_dir = Pathname.new(__dir__).join('test/fixtures')
  import_css_path = fixtures_dir.join('import1.css').to_s.freeze
  complex_css_path = fixtures_dir.join('complex.css').to_s.freeze

  Benchmark.ips do |x|
    x.report('import1.css loading') { CssParser::Parser.new.load_file!(import_css_path) }
    x.report('complex.css loading') { CssParser::Parser.new.load_file!(complex_css_path) }
  end

  puts

  report = MemoryProfiler.report { CssParser::Parser.new.load_file!(import_css_path) }
  puts "Loading `import1.css` allocated #{report.total_allocated} objects, #{report.total_allocated_memsize / 1024} KiB"

  report = MemoryProfiler.report { CssParser::Parser.new.load_file!(complex_css_path) }
  puts "Loading `complex.css` allocated #{report.total_allocated} objects, #{report.total_allocated_memsize / 1024} KiB"
end
