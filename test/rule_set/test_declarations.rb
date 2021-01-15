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
        baz_property = CssParser::RuleSet::Declarations::Value.new('baz value', order: 42, important: true)
        declarations = CssParser::RuleSet::Declarations.new({foo: 'foo value', bar: 'bar value', baz: baz_property})

        assert_equal 3, declarations.size

        assert_equal CssParser::RuleSet::Declarations::Value.new('foo value', order: 1), declarations['foo']
        assert_equal CssParser::RuleSet::Declarations::Value.new('bar value', order: 2), declarations[:bar]
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
      property = CssParser::RuleSet::Declarations::Value.new('value', important: true, order: 42)

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
  end

  describe '#[]' do
    it 'returns property if exists' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true, order: 42)
      declarations = CssParser::RuleSet::Declarations.new({foo: foo_value})

      assert_equal foo_value, declarations['foo']
    end

    it 'returns nil if not exists' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true, order: 42)
      declarations = CssParser::RuleSet::Declarations.new({foo: foo_value})

      assert_nil declarations['bar']
    end

    it 'normalizes property name' do
      foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', important: true, order: 42)
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

  describe '#remove_declaration' do
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

      declarations.remove_declaration!('fOo'.to_sym)

      assert_equal 0, declarations.size
    end
  end

  describe '#each' do
    describe 'when block is not given' do
      it 'returns enumerator with properties order by order' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', order: 3)
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value', order: 1)
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value', order: 2)

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        assert_instance_of Enumerator, declarations.each
        assert_equal 3, declarations.each.size
        assert_equal [['bar', bar_value], ['baz', baz_value], ['foo', foo_value]], declarations.each.to_a
      end
    end

    describe 'when block is given' do
      it 'yields properties order by order' do
        foo_value = CssParser::RuleSet::Declarations::Value.new('foo value', order: 3)
        bar_value = CssParser::RuleSet::Declarations::Value.new('bar value', order: 1)
        baz_value = CssParser::RuleSet::Declarations::Value.new('baz value', order: 2)

        declarations = CssParser::RuleSet::Declarations.new({foo: foo_value, bar: bar_value, baz: baz_value})

        mock = Minitest::Mock.new
        mock.expect :call, true, ['bar', bar_value]
        mock.expect :call, true, ['baz', baz_value]
        mock.expect :call, true, ['foo', foo_value]

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
end
