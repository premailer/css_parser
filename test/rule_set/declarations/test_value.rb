# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'

class RuleSetProperyTest < Minitest::Test
  describe '.new' do
    describe 'with invalid value' do
      it 'raises an error when empty' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::Declarations::Value.new('  ') }
        assert_equal 'value is empty', exception.message
      end

      it 'raises an error when nil' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::Declarations::Value.new(nil) }
        assert_equal 'value is empty', exception.message
      end

      it 'raises an error when contains only important declaration' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::Declarations::Value.new(' !important; ') }
        assert_equal 'value is empty', exception.message
      end
    end

    describe 'with valid value' do
      it 'remove semicolon at the end' do
        assert_equal 'value', CssParser::RuleSet::Declarations::Value.new('value;').value
      end

      it 'removes important declarations' do
        assert_equal 'value', CssParser::RuleSet::Declarations::Value.new('value !important').value
      end

      it 'strips value' do
        assert_equal 'value', CssParser::RuleSet::Declarations::Value.new('  value ').value
      end

      it 'does everything above' do
        assert_equal "value\t another one",
          CssParser::RuleSet::Declarations::Value.new("  \tvalue\t another one  \t!important  \t  ;  ").value
      end

      it 'freezes the string' do
        assert_equal true, CssParser::RuleSet::Declarations::Value.new('value').value.frozen?
      end
    end

    describe 'important' do
      describe 'when not set' do
        it 'is not important if value is not important' do
          assert_equal false, CssParser::RuleSet::Declarations::Value.new('value').important
        end

        it 'is important if value is not important' do
          assert_equal true, CssParser::RuleSet::Declarations::Value.new('value !important;').important
        end
      end

      describe 'when set' do
        it 'overrides value importance' do
          assert_equal false, CssParser::RuleSet::Declarations::Value.new('value !important;', important: false).important
          assert_equal true, CssParser::RuleSet::Declarations::Value.new('value', important: true).important
        end
      end
    end
  end

  describe 'important=' do
    it 'sets importance' do
      property = CssParser::RuleSet::Declarations::Value.new('value')
      assert_equal false, property.important

      property.important = true
      assert_equal true, property.important
    end
  end

  describe 'value=' do
    it 'sets normalized value' do
      property = CssParser::RuleSet::Declarations::Value.new('foo')
      assert_equal 'foo', property.value

      property.value = "  \tvalue\t another one  \t!important  \t  ;  "
      assert_equal "value\t another one", property.value
    end

    it 'sets importance' do
      property = CssParser::RuleSet::Declarations::Value.new('foo')
      assert_equal 'foo', property.value
      assert_equal false, property.important

      property.value = 'bar !important'

      assert_equal 'bar', property.value
      assert_equal true, property.important
    end

    it 'freezes the string' do
      property = CssParser::RuleSet::Declarations::Value.new('foo')
      property.value = 'bar'

      assert_equal true, CssParser::RuleSet::Declarations::Value.new('value').value.frozen?
    end
  end

  describe '#to_s' do
    it 'returns value if not important' do
      assert_equal 'value', CssParser::RuleSet::Declarations::Value.new('value').to_s
    end

    it 'returns value with important annotation if important' do
      assert_equal 'value !important', CssParser::RuleSet::Declarations::Value.new('value', important: true).to_s
    end
  end
end
