require File.dirname(__FILE__) + '/test_helper'

# Test cases for CSS cascading
class CssParserCascadingTests < Test::Unit::TestCase
  include CssParser
  
  def setup
    @cp = Parser.new
  end

  def test_higher_specificity_should_take_precedence
    css_blocks = [{:specificity => 20, :declarations => 'color: red;'},
                  {:specificity => 10, :declarations => 'color: blue'}]
    assert_equal 'color: red;', @cp.fold_declarations(css_blocks)
  end

  def test_properties_should_be_case_insensitive
    css_blocks = [{:specificity => 10, :declarations => 'color: red;'},
                  {:specificity => 10, :declarations => 'COLOR: blue'}]
    assert_equal 'color: blue;', @cp.fold_declarations(css_blocks)
  end
end
