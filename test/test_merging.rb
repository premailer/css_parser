# frozen_string_literal: true

require_relative 'test_helper'

class MergingTests < Minitest::Test
  include CssParser

  def setup
    @cp = CssParser::Parser.new
  end

  def test_simple_merge
    rs1 = RuleSet.new(block: 'color: black;')
    rs2 = RuleSet.new(block: 'margin: 0px;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal '0px;', merged['margin']
    assert_equal 'black;', merged['color']
  end

  def test_merging_array
    rs1 = RuleSet.new(block: 'color: black;')
    rs2 = RuleSet.new(block: 'margin: 0px;')
    merged = CssParser.merge([rs1, rs2])
    assert_equal '0px;', merged['margin']
    assert_equal 'black;', merged['color']
  end

  def test_merging_with_compound_selectors
    @cp.add_block! "body { margin: 0; }"
    @cp.add_block! "h2   { margin: 5px; }"

    rules = @cp.find_rule_sets(["body", "h2"])
    assert_equal "margin: 5px;", CssParser.merge(rules).declarations_to_s

    @cp = CssParser::Parser.new
    @cp.add_block! "body { margin: 0; }"
    @cp.add_block! "h2,h1 { margin: 5px; }"

    rules = @cp.find_rule_sets(["body", "h2"])
    assert_equal "margin: 5px;", CssParser.merge(rules).declarations_to_s
  end

  def test_merging_multiple
    rs1 = RuleSet.new(block: 'color: black;')
    rs2 = RuleSet.new(block: 'margin: 0px;')
    rs3 = RuleSet.new(block: 'margin: 5px;')
    merged = CssParser.merge(rs1, rs2, rs3)
    assert_equal '5px;', merged['margin']
  end

  def test_multiple_selectors_should_have_proper_specificity
    rs1 = RuleSet.new(selectors: 'p, a[rel="external"]', block: 'color: black;')
    rs2 = RuleSet.new(selectors: 'a', block: 'color: blue;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black;', merged['color']
  end

  def test_setting_specificity
    rs1 = RuleSet.new(block: 'color: red;', specificity: 20)
    rs2 = RuleSet.new(block: 'color: blue;', specificity: 10)
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'red;', merged['color']
  end

  def test_properties_should_be_case_insensitive
    rs1 = RuleSet.new(block: ' CoLor   : red  ;', specificity: 20)
    rs2 = RuleSet.new(block: 'color: blue;', specificity: 10)
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'red;', merged['color']
  end

  def test_merging_backgrounds
    rs1 = RuleSet.new(block: 'background-color: black;')
    rs2 = RuleSet.new(block: 'background-image: none;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black none;', merged['background']
  end

  def test_merging_dimensions
    rs1 = RuleSet.new(block: 'margin: 3em;')
    rs2 = RuleSet.new(block: 'margin-left: 1em;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal '3em 3em 3em 1em;', merged['margin']
  end

  def test_merging_fonts
    rs1 = RuleSet.new(block: 'font: 11px Arial;')
    rs2 = RuleSet.new(block: 'font-weight: bold;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'bold 11px Arial;', merged['font']
  end

  def test_raising_error_on_bad_type
    assert_raises ArgumentError do
      CssParser.merge([1, 2, 3])
    end
  end

  def test_returning_early_with_only_one_params
    rs = RuleSet.new(block: 'font-weight: bold;')
    merged = CssParser.merge(rs)
    assert_equal rs.object_id, merged.object_id
  end

  def test_merging_important
    rs1 = RuleSet.new(block: 'color: black !important;')
    rs2 = RuleSet.new(block: 'color: red;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black !important;', merged['color']
  end

  def test_prioritising_important_over_non_important_in_the_same_block
    rs1 = RuleSet.new(block: 'color: black !important; color: red;')
    merged = CssParser.merge(rs1)
    assert_equal 'black !important;', merged['color']
  end

  def test_prioritising_two_important_declarations_in_the_same_block
    rs1 = RuleSet.new(block: 'color: black !important; color: red !important;')
    merged = CssParser.merge(rs1)
    assert_equal 'red !important;', merged['color']
  end

  def test_merging_multiple_important
    rs1 = RuleSet.new(block: 'color: black !important;', specificity: 1000)
    rs2 = RuleSet.new(block: 'color: red !important;', specificity: 1)
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black !important;', merged['color']

    rs3 = RuleSet.new(block: 'color: blue !important;', specificity: 1000)
    merged = CssParser.merge(rs1, rs2, rs3)
    assert_equal 'blue !important;', merged['color']
  end

  def test_merging_shorthand_important
    rs1 = RuleSet.new(block: 'background: black none !important;')
    rs2 = RuleSet.new(block: 'background-color: red;')
    merged = CssParser.merge(rs1, rs2)
    assert_equal 'black !important;', merged['background-color']
  end
end
