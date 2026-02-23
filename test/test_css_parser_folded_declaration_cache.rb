# frozen_string_literal: true

require_relative 'test_helper'

class CssParserFoldedDeclarationCacheTest < Minitest::Test
  include CssParser

  def test_folded_declaration_cache_is_per_instance
    cp1 = Parser.new
    cp2 = Parser.new

    cp1.add_block!('p { color: red; }')
    cp2.add_block!('p { color: blue; }')

    cache1 = cp1.send(:instance_variable_get, :@folded_declaration_cache)
    cache2 = cp2.send(:instance_variable_get, :@folded_declaration_cache)

    refute_same cache1, cache2
  end

  def test_folded_declaration_cache_does_not_persist_across_instances
    cp1 = Parser.new
    cp1.add_block!('p { color: red; }')

    cp2 = Parser.new
    cache = cp2.send(:instance_variable_get, :@folded_declaration_cache)

    assert_empty cache
  end

  def test_no_class_level_folded_declaration_cache
    refute Parser.respond_to?(:folded_declaration_cache),
           'Parser should not have a class-level folded_declaration_cache accessor'
  end

  def test_cache_is_reset_on_new_instance
    cp = Parser.new
    cache = cp.send(:instance_variable_get, :@folded_declaration_cache)
    assert_instance_of Hash, cache
    assert_empty cache
  end
end
