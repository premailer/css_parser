$:.unshift File.expand_path('../lib', __FILE__)

require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'fileutils'
require 'css_parser'

class File
  # find a file in the load path or raise an exception if the file can
  # not be found.
  def File.find_file_in_path(filename)
    $:.each do |path|
      puts "Trying #{path}"
      file_with_path = path+'/'+filename
      return file_with_path if file?(file_with_path) 
    end
    raise ArgumentError, "Can't find file #{filename} in Ruby library path"
  end
end

include CssParser

task :default => [:test]

desc 'Run the unit tests.'
Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.libs << 'lib/test'
  t.test_files = FileList['test/test*.rb'].exclude('test_helper.rb')
  t.verbose = false
end

desc 'Generate documentation.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Ruby CSS Parser'
  rdoc.options << '--all' << '--inline-source' << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('LICENSE')
  rdoc.rdoc_files.include('lib/*.rb')
  rdoc.rdoc_files.include('lib/css_parser/*.rb')
end

desc 'Generate fancy documentation.'
Rake::RDocTask.new(:fancy) do |rdoc|
  rdoc.rdoc_dir = 'fdoc'
  rdoc.title    = 'Ruby CSS Parser'
  rdoc.options << '--all' << '--inline-source' << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('LICENSE')
  rdoc.rdoc_files.include('lib/*.rb')
  rdoc.rdoc_files.include('lib/css_parser/*.rb')
  rdoc.template = File.expand_path(File.dirname(__FILE__) + '/doc-template.rb')
end
