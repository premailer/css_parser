# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'

class RuleSetProperyTest < Minitest::Test
  describe '.new' do
    describe 'with invalid value' do
      it 'raises an error when empty' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::DeclarationValue.new('  ') }
        assert_equal 'value is empty', exception.message
      end

      it 'raises an error when nil' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::DeclarationValue.new(nil) }
        assert_equal 'value is empty', exception.message
      end

      it 'raises an error when contains only important declaration' do
        exception = assert_raises(ArgumentError) { CssParser::RuleSet::DeclarationValue.new(' !important; ') }
        assert_equal 'value is empty', exception.message
      end
    end

    describe 'with valid value' do
      it 'remove semicolon at the end' do
        assert_equal 'value', CssParser::RuleSet::DeclarationValue.new('value;').value
      end

      it 'removes important declarations' do
        assert_equal 'value', CssParser::RuleSet::DeclarationValue.new('value !important').value
      end

      it 'strips value' do
        assert_equal 'value', CssParser::RuleSet::DeclarationValue.new('  value ').value
      end

      it 'does everything above' do
        assert_equal "value\t another one",
          CssParser::RuleSet::DeclarationValue.new("  \tvalue\t another one  \t!important  \t  ;  ").value
      end

      it 'freezes the string' do
        assert_equal true, CssParser::RuleSet::DeclarationValue.new('value').value.frozen?
      end
    end

    describe 'important' do
      describe 'when not set' do
        it 'is not important if value is not important' do
          assert_equal false, CssParser::RuleSet::DeclarationValue.new('value').important
        end

        it 'is important if value is not important' do
          assert_equal true, CssParser::RuleSet::DeclarationValue.new('value !important;').important
        end
      end

      describe 'when set' do
        it 'overrides value importance' do
          assert_equal false, CssParser::RuleSet::DeclarationValue.new('value !important;', important: false).important
          assert_equal true, CssParser::RuleSet::DeclarationValue.new('value', important: true).important
        end
      end
    end

    describe 'order' do
      it 'zero when not set' do
        assert_equal 0, CssParser::RuleSet::DeclarationValue.new('value').order
      end

      it 'returns proper value if set' do
        assert_equal 42, CssParser::RuleSet::DeclarationValue.new('value', order: 42).order
      end
    end
  end

  describe 'order=' do
    it 'sets order' do
      property = CssParser::RuleSet::DeclarationValue.new('value')
      assert_equal 0, property.order

      property.order = 42
      assert_equal 42, property.order
    end
  end

  describe 'important=' do
    it 'sets importance' do
      property = CssParser::RuleSet::DeclarationValue.new('value')
      assert_equal false, property.important

      property.important = true
      assert_equal true, property.important
    end
  end

  describe 'value=' do
    it 'sets normalized value' do
      property = CssParser::RuleSet::DeclarationValue.new('foo')
      assert_equal 'foo', property.value

      property.value = "  \tvalue\t another one  \t!important  \t  ;  "
      assert_equal "value\t another one", property.value
    end

    it 'freezes the string' do
      property = CssParser::RuleSet::DeclarationValue.new('foo')
      property.value = 'bar'

      assert_equal true, CssParser::RuleSet::DeclarationValue.new('value').value.frozen?
    end
  end

  describe '#to_s' do
    it 'returns value if not important' do
      assert_equal 'value', CssParser::RuleSet::DeclarationValue.new('value').to_s
    end

    it 'returns value with important annotation if important' do
      assert_equal 'value !important', CssParser::RuleSet::DeclarationValue.new('value', important: true).to_s
    end
  end
end
