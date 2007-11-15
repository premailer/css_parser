require File.dirname(__FILE__) + '/test_helper'

class MergingTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
  end

  def test_simple_merge
    rs1 = RuleSet.new('p', 'color: black;')
    rs2 = RuleSet.new('p', 'margin: 0px;')
    CssParser.merge(rs1, rs2)
  end

  def test_merging_backgrounds
    rs1 = RuleSet.new('p', 'background-color: black;')
    rs2 = RuleSet.new('p', 'background-image: none;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black none;', merged['background']
  end

  def test_merging_dimensions
    rs1 = RuleSet.new('p', 'margin: 3em;')
    rs2 = RuleSet.new('p', 'margin-left: 1em;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal '3em 3em 3em 1em;', merged['margin']
  end

  def test_merging_fonts
    rs1 = RuleSet.new('p', 'font: 11px Arial;')
    rs2 = RuleSet.new('p', 'font-weight: bold;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'bold 11px Arial;', merged['font']
  end

  def test_raising_error_on_bad_type
    assert_raise ArgumentError do
      CssParser.merge([1,2,3])
    end
  end

end
