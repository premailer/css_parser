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


  #  css_blocks = [{:specificity => 10, :css_block => 'color: red; font: 300 italic 11px/14px verdana, helvetica, sans-serif;'},
  #                {:specificity => 1000, :css_block => 'font-weight: normal'}]
  #
  #  fold_styles(css_blocks).inspect
  #
  #  => "font-weight: normal; font-size: 11px; line-height: 14px; font-family: verdana, helvetica, sans-serif; 
  #      color: red; font-style: italic;"