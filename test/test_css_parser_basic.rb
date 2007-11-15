require File.dirname(__FILE__) + '/test_helper'

# Test cases for reading and generating CSS shorthand properties
class CssParserBasicTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
    @css = <<-EOT
      html, body, p { margin: 0px; }
      p { padding: 0px; }
      #content { font: 12px/normal sans-serif; }
    EOT
  end

  def test_finding_by_selector
    @cp.add_block!(@css)
    assert_equal 'margin: 0px;', @cp.find('body').join(' ')
    assert_equal 'margin: 0px; padding: 0px;', @cp.find('p').join(' ')
  end

  def test_adding_block
    @cp.add_block!(@css)
    assert_equal 'margin: 0px;', @cp.find('body').join
  end

  def test_adding_a_rule
    @cp.add_rule!('div', 'color: blue;')
    assert_equal 'color: blue;', @cp.find('div').join(' ')
  end

  def test_adding_a_rule_set
    rs = CssParser::RuleSet.new('div', 'color: blue;')
    @cp.add_rule_set!(rs)
    assert_equal 'color: blue;', @cp.find('div').join(' ')
  end


end
