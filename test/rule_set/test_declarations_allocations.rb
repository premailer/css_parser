# frozen_string_literal: true

require_relative '../test_helper'

class RuleSetDeclarationsAllocationsTest < Minitest::Test
  include CssParser
  include AllocationCounting

  PADDINGS = Array.new(20) { |i| "padding-#{%w[top right bottom left][i % 4]}: #{i}px" }.join('; ')
  BLOCK = "#{PADDINGS}; color: red !important".freeze

  def test_parsing_declarations_allocates_less_than_six_objects_per_declaration
    assert_operator allocations { RuleSet.new(block: BLOCK) }, :<, 6 * 21
  end

  def test_serializing_declarations_does_not_allocate_per_declaration
    rule_set = RuleSet.new(block: BLOCK)

    assert_operator allocations { rule_set.declarations_to_s }, :<, 10
  end

  def test_frozen_values_are_kept_without_copy
    value = '1px'

    assert_same value, RuleSet::Declarations::Value.new(value).value
  end

  def test_unfrozen_values_are_neither_frozen_nor_mutated
    value = +' 1px !important; '

    RuleSet::Declarations::Value.new(value)

    assert_equal [' 1px !important; ', false], [value, value.frozen?]
  end
end
