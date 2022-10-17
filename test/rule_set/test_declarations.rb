# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'

class RuleSetDeclarationsTest < Minitest::Test
  describe '.new' do
    describe 'when initial declarations is not given' do
      it 'initialized empty' do
        assert_equal 0, CssParser::RuleSet::Declarations.new.size
      end
    end

    describe 'when initial declarations is given' do
      it 'initialized with given declarations' do
        baz_property = CssParser::RuleSet::Declarations::Value.new('baz value', important: true)
        declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value', bar: 'bar value', baz: baz_property})

        assert_equal 3, declarations.size

        assert_equal CssParser::RuleSet::Declarations::Value.new('foo value'), declarations['foo']
        assert_equal CssParser::RuleSet::Declarations::Value.new('bar value'), declarations[:bar]
        assert_equal baz_property, declarations['baz']
      end
    end
  end

  describe '#[]=' do
    it 'normalizes property name' do
      declarations = CssParser::RuleSet::Declarations.new

      declarations[:'  fOo'] = 'foo value'

      assert_equal true, declarations.key?('foo')
      assert_equal 1, declarations.size
      assert_equal 'foo value', declarations['foo'].value
    end

    it 'assigns proper value if Declarations::Value is given' do
      declarations = CssParser::RuleSet::Declarations.new
      property = CssParser::RuleSet::Declarations::Value.new('value', important: true)

      declarations['foo'] = property

      assert_equal property, declarations['foo']
    end

    it 'deletes property if given value is empty' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value', bar: 'bar value'})
      assert_equal 2, declarations.size

      declarations['foo'] = nil

      assert_equal 1, declarations.size
      assert_equal true, declarations.key?('bar')
    end

    it 'creates Declarations::Value with proper value if string is given' do
      declarations = CssParser::RuleSet::Declarations.new
      declarations['foo'] = 'foo value'

      assert_instance_of CssParser::RuleSet::Declarations::Value, declarations['foo']
      assert_equal 'foo value', declarations['foo'].value
    end

    it 'has alias #add_declaration!' do
      declarations = CssParser::RuleSet::Declarations.new

      assert_equal declarations.method(:[]=), declarations.method(:add_declaration!)
    end

    it 'raises an exception including the property when the value is empty' do
      declarations = CssParser::RuleSet::Declarations.new

      assert_raises ArgumentError, 'foo value is empty' do
        declarations['foo'] = '!important'
      end
    end
  end

  describe '#[]' do
    it 'returns property if exists' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true)
      declarations = CssParser::RuleSet::Declarations.new({foo: foo_value})

      assert_equal foo_value, declarations['foo']
    end

    it 'returns nil if not exists' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true)
      declarations = CssParser::RuleSet::Declarations.new({foo: foo_value})

      assert_nil declarations['bar']
    end

    it 'normalizes property name' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true)
      declarations = CssParser::RuleSet::Declarations.new({foo: foo_value})

      assert_equal foo_value, declarations[:'Foo ']
    end

    it 'has alias #get_value' do
      declarations = CssParser::RuleSet::Declarations.new

      assert_equal declarations.method(:[]), declarations.method(:get_value)
    end
  end

  describe '#key?' do
    it 'return true if key exists' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})

      assert_equal true, declarations.key?('foo')
    end

    it 'return false if key does not exists' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})

      assert_equal false, declarations.key?('bar')
    end

    it 'normalizes property name' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})

      assert_equal true, declarations.key?(:'foO ')
    end
  end

  describe '#size' do
    it 'returns declarations size' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})

      assert_equal 1, declarations.size

      declarations['bar'] = 'bar value'

      assert_equal 2, declarations.size

      declarations['foo'] = nil

      assert_equal 1, declarations.size
    end
  end

  describe '#delete' do
    it 'removes declaration if exists' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})
      assert_equal 1, declarations.size

      declarations.remove_declaration!('foo')

      assert_equal 0, declarations.size
    end

    it 'does nothing if declarations does not exist' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})

      assert_equal 1, declarations.size

      declarations.remove_declaration!('bar')

      assert_equal 1, declarations.size
    end

    it 'normalizes property name' do
      declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value'})
      assert_equal 1, declarations.size

      declarations.remove_declaration!(:fOo)

      assert_equal 0, declarations.size
    end

    it 'has alias #remove_declaration!' do
      declarations = CssParser::RuleSet::Declarations.new

      assert_equal declarations.method(:delete), declarations.method(:remove_declaration!)
    end
  end

  describe '#replace_declaration!' do
    it 'raises an error when replaced property does not exist' do
      declarations = CssParser::RuleSet::Declarations.new

      exception = assert_raises(ArgumentError) { declarations.replace_declaration!('property_name', {}) }
      assert_equal 'property property_name does not exist', exception.message
    end

    it 'replaces declaration with normalized property name in place' do
      declarations = CssParser::RuleSet::Declarations.new('foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value')

      declarations.replace_declaration!("   bAr\t\n", {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'})

      expected = CssParser::RuleSet::Declarations.new(
        'foo' => 'foo_value', 'bar1' => 'bar1_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
      )
      assert_equal expected, declarations
    end

    describe 'when `preserve_importance: false`' do
      it 'does not set importance when replaced property is important' do
        declarations = CssParser::RuleSet::Declarations.new('foo' => 'foo_value !important')

        declarations.replace_declaration!('foo', {'bar' => 'bar_value', 'baz' => 'baz_value !important'})
        expected = CssParser::RuleSet::Declarations.new({'bar' => 'bar_value', 'baz' => 'baz_value !important'})

        assert_equal expected, declarations
      end

      it 'does not unset importance when replaced property is not important' do
        declarations = CssParser::RuleSet::Declarations.new('foo' => 'foo_value')

        declarations.replace_declaration!('foo', {'bar' => 'bar_value', 'baz' => 'baz_value !important'})
        expected = CssParser::RuleSet::Declarations.new({'bar' => 'bar_value', 'baz' => 'baz_value !important'})

        assert_equal expected, declarations
      end
    end

    describe 'when `preserve_importance: true`' do
      it 'sets importance when replaced property is important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value !important', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'}, preserve_importance: true)
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar2' => 'bar2_value !important', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        assert_equal expected, declarations
      end

      it 'unsets importance when replaced property is not important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value'
        )

        declarations.replace_declaration!(
          'bar',
          {'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value !important'},
          preserve_importance: true
        )
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value'
        )

        assert_equal expected, declarations
      end
    end

    describe 'when subsequent declarations for the replacement declarations exist' do
      it 'does not replace declarations when both are not important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value'
        )

        assert_equal expected, declarations
      end

      it 'does not replace declarations when both are important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        assert_equal expected, declarations
      end

      it 'does not replace declaration when only replaced is important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value !important'
        )

        assert_equal expected, declarations
      end

      it 'replaces declarations when only replacement is important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value', 'bar1' => 'old_bar1_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
        )

        assert_equal expected, declarations
      end
    end

    describe 'when prior declarations for the replacement declarations exist' do
      it 'replaces declarations when both are not important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'bar1' => 'old_bar1_value', 'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'bar1' => 'bar1_value', 'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
        )

        assert_equal expected, declarations
      end

      it 'replaces declarations when both are important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'bar1' => 'old_bar1_value !important', 'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'bar1' => 'bar1_value !important', 'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
        )

        assert_equal expected, declarations
      end

      it 'does not replace declaration when only replaced is important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'bar1' => 'old_bar1_value !important', 'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'bar1' => 'old_bar1_value !important', 'foo' => 'foo_value', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
        )

        assert_equal expected, declarations
      end

      it 'replaces declarations when only replacement is important' do
        declarations = CssParser::RuleSet::Declarations.new(
          'bar1' => 'old_bar1_value', 'foo' => 'foo_value', 'bar' => 'bar_value', 'baz' => 'baz_value'
        )

        declarations.replace_declaration!('bar', {'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value'})
        expected = CssParser::RuleSet::Declarations.new(
          'foo' => 'foo_value', 'bar1' => 'bar1_value !important', 'bar2' => 'bar2_value', 'baz' => 'baz_value'
        )

        assert_equal expected, declarations
      end
    end
  end

  describe '#each' do
    describe 'when block is not given' do
      it 'returns enumerator with properties in order' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value')
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value')
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value')

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        assert_instance_of Enumerator, declarations.each
        assert_equal 3, declarations.each.size
        assert_equal [['foo', foo_value], ['bar', bar_value], ['baz', baz_value]], declarations.each.to_a
      end
    end

    describe 'when block is given' do
      it 'yields properties in order' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value')
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value')
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value')

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        mock = Minitest::Mock.new
        mock.expect :call, true, ['foo', foo_value]
        mock.expect :call, true, ['bar', bar_value]
        mock.expect :call, true, ['baz', baz_value]

        declarations.each { |name, value| mock.call(name, value) }

        assert_mock mock
      end
    end
  end

  describe '#to_s' do
    context 'when `force_important` is not passed' do
      it 'returns declarations with declared importance' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true)
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value', important: false)
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value', important: true)

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        assert_equal 'foo: foo value !important; bar: bar value; baz: baz value !important;', declarations.to_s
      end
    end

    context 'when `force_important` is passed' do
      it 'returns declarations with important annotations' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: false)
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value', important: false)
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value', important: false)

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        assert_equal 'foo: foo value !important; bar: bar value !important; baz: baz value !important;',
          declarations.to_s({force_important: true})
      end
    end
  end

  describe '#==' do
    it 'returns true if declarations & their order are the same' do
      declarations_hash = {'foo' => 'foo_value', 'bar' => 'bar_value'}
      declarations = CssParser::RuleSet::Declarations.new(declarations_hash)
      other = CssParser::RuleSet::Declarations.new(declarations_hash)

      assert_equal declarations, other
    end

    it 'returns false if other is not a Declarations' do
      declarations_hash = {'foo' => 'foo_value', 'bar' => 'bar_value'}
      declarations = CssParser::RuleSet::Declarations.new(declarations_hash)
      other = OpenStruct.new(declarations: declarations_hash)

      refute_equal declarations, other
    end

    it 'returns true if value is a Declarations subclass and declarations are equal' do
      declarations_hash = {'foo' => 'foo_value', 'bar' => 'bar_value'}
      declarations = CssParser::RuleSet::Declarations.new(declarations_hash)
      other_class = Class.new(CssParser::RuleSet::Declarations)
      other = other_class.new(declarations_hash)

      assert_equal declarations, other
    end

    it 'returns false if value is a Declarations subclass and value are not equal' do
      declarations = CssParser::RuleSet::Declarations.new({'foo' => 'foo_value', 'bar' => 'bar_value'})
      other_class = Class.new(CssParser::RuleSet::Declarations)
      other = other_class.new({'bar' => 'bar_value', 'foo' => 'foo_value'})

      refute_equal declarations, other
    end

    it 'returns false if declarations values are different' do
      declarations = CssParser::RuleSet::Declarations.new({'foo' => 'foo_value', 'bar' => 'bar_value'})
      other = CssParser::RuleSet::Declarations.new({'bar' => 'bar_value', 'foo' => 'other_foo_value'})

      refute_equal declarations, other
    end

    it 'returns false if declarations are the same and their order is different' do
      declarations = CssParser::RuleSet::Declarations.new({'foo' => 'foo_value', 'bar' => 'bar_value'})
      other = CssParser::RuleSet::Declarations.new({'bar' => 'bar_value', 'foo' => 'foo_value'})

      refute_equal declarations, other
    end
  end
end
