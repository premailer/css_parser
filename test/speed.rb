$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__), '../css_parser/'))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__), '../'))




require "benchmark"
require 'css_parser'

include Benchmark



css_block = {:declarations=>"color: #fff; background: #1c2815 none;", :selector=>"body", :specificity=>1}, 
            {:declarations=>"color: #fff; background: #1c2815 none;", :selector=>"#container", :specificity=>100}

n = 10000


bm(12) do |test|
  test.report("creating ruleset:") do
    @cp = CssParser.new
    n.times do |x|
      @cp.fold_declarations(css_block)
    end
  end
  test.report("parsing in block:") do
    @cp = CssParser.new
    n.times do |x|
      @cp.fold_declarations_old(css_block)
    end
  end
end

