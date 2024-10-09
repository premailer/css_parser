# frozen_string_literal: true

require_relative 'test_helper'
require "set"

# Test cases for parsing CSS blocks
class RuleSetTests < Minitest::Test
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_setting_property_values
    rs = RuleSet.new

    rs['background-color'] = 'red'
    assert_equal('red;', rs['background-color'])

    rs['background-color'] = 'blue !important;'
    assert_equal('blue !important;', rs['background-color'])
  end

  def test_getting_property_values
    rs = RuleSet.new(selectors: '#content p, a', block: 'color: #fff;')
    assert_equal('#fff;', rs['color'])
  end

  def test_getting_property_value_ignoring_case
    rs = RuleSet.new(selectors: '#content p, a', block: 'color: #fff;')
    assert_equal('#fff;', rs['  ColoR '])
  end

  def test_each_selector
    expected = [
      {selector: "#content p", declarations: "color: #fff;", specificity: 101},
      {selector: "a", declarations: "color: #fff;", specificity: 1}
    ]

    actual = []
    rs = RuleSet.new(selectors: '#content p, a', block: 'color: #fff;')
    rs.each_selector do |sel, decs, spec|
      actual << {selector: sel, declarations: decs, specificity: spec}
    end

    assert_equal(expected, actual)
  end

  def test_each_declaration
    expected = Set[
      {property: 'margin', value: '1px -0.25em', is_important: false},
      {property: 'background', value: 'white none no-repeat', is_important: true},
      {property: 'color', value: '#fff', is_important: false}
    ]

    actual = Set.new
    rs = RuleSet.new(block: 'color: #fff; Background: white none no-repeat !important; margin: 1px -0.25em;')
    rs.each_declaration do |prop, val, imp|
      actual << {property: prop, value: val, is_important: imp}
    end

    assert_equal(expected, actual)
  end

  def test_each_declaration_respects_order
    css_fragment = "margin: 0; padding: 20px; margin-bottom: 28px;"
    rs           = RuleSet.new(block: css_fragment)
    expected     = %w[margin padding margin-bottom]
    actual       = []
    rs.each_declaration { |prop, _val, _imp| actual << prop }
    assert_equal(expected, actual)
  end

  def test_each_declaration_containing_semicolons
    rs = RuleSet.new(block: "background-image: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAiCAMAAAB7);" \
                            "background-repeat: no-repeat")
    assert_equal('url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAiCAMAAAB7);', rs['background-image'])
    assert_equal('no-repeat;', rs['background-repeat'])
  end

  def test_each_declaration_with_newlines
    expected = Set[
      {property: 'background-image', value: 'url(foo;bar)', is_important: false},
      {property: 'font-weight', value: 'bold', is_important: true},
    ]
    rs = RuleSet.new(block: "background-image\n:\nurl(foo;bar);\n\n\n\n\n;;font-weight\n\n\n:bold\n\n\n!important")
    actual = Set.new
    rs.each_declaration do |prop, val, imp|
      actual << {property: prop, value: val, is_important: imp}
    end
    assert_equal(expected, actual)
  end

  def test_selector_sanitization
    selectors = "h1, h2,\nh3 "
    rs = RuleSet.new(selectors: selectors, block: "color: #fff;")
    assert rs.selectors.member?("h3")
  end

  def test_multiple_selectors_to_s
    selectors = "#content p, a"
    rs = RuleSet.new(selectors: selectors, block: "color: #fff;")
    assert_match(/^\s*#content p,\s*a\s*\{/, rs.to_s)
  end

  def test_declarations_to_s
    declarations = 'color: #fff; font-weight: bold;'
    rs = RuleSet.new(selectors: '#content p, a', block: declarations)
    assert_equal(declarations.split.sort, rs.declarations_to_s.split.sort)
  end

  def test_important_declarations_to_s
    declarations = 'color: #fff; font-weight: bold !important;'
    rs = RuleSet.new(selectors: '#content p, a', block: declarations)
    assert_equal(declarations.split.sort, rs.declarations_to_s.split.sort)
  end

  def test_overriding_specificity
    rs = RuleSet.new(selectors: '#content p, a', block: 'color: white', specificity: 1000)
    rs.each_selector do |_sel, _decs, spec|
      assert_equal 1000, spec
    end
  end

  def test_important_without_value
    declarations = 'color: !important; background-color: #fff'
    rs = RuleSet.new(selectors: '#content p, a', block: declarations)
    assert_equal('background-color: #fff;', rs.declarations_to_s)
  end

  def test_not_raised_issue68
    ok = true
    begin
      RuleSet.new(selectors: 'td', block: 'border-top: 5px solid; border-color: #fffff0;')
    rescue
      ok = false
    end
    assert_equal true, ok
  end
end
