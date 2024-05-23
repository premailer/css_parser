# frozen_string_literal: true

module CssParser
  class RuleSet
    class Declarations
      class Value
        attr_reader :value
        attr_accessor :important

        def initialize(value, important: nil)
          self.value = value
          @important = important unless important.nil?
        end

        def value=(value)
          value = value.to_s.sub(/\s*;\s*\Z/, '')
          self.important = !value.slice!(CssParser::IMPORTANT_IN_PROPERTY_RX).nil?
          value.strip!
          raise ArgumentError, 'value is empty' if value.empty?

          @value = value.freeze
        end

        def to_s
          important ? "#{value} !important" : value
        end

        def ==(other)
          return false unless other.is_a?(self.class)

          value == other.value && important == other.important
        end
      end

      extend Forwardable

      def_delegators :declarations, :each, :each_value

      def initialize(declarations = {})
        self.declarations = {}
        declarations.each { |property, value| add_declaration!(property, value) }
      end

      # Add a CSS declaration
      # @param [#to_s] property that should be added
      # @param [Value, #to_s] value of the property
      #
      # @example
      #   declarations['color'] = 'blue'
      #
      #   puts declarations['color']
      #   => #<CssParser::RuleSet::Declarations::Value:0x000000000305c730 @important=false, @order=1, @value="blue">
      #
      # @example
      #   declarations['margin'] = '0px auto !important'
      #
      #   puts declarations['margin']
      #   => #<CssParser::RuleSet::Declarations::Value:0x00000000030c1838 @important=true, @order=2, @value="0px auto">
      #
      # If the property already exists its value will be over-written.
      # If the value is empty - property will be deleted
      def []=(property, value)
        property = normalize_property(property)

        if value.is_a?(Value)
          declarations[property] = value
        elsif value.to_s.strip.empty?
          delete property
        else
          declarations[property] = Value.new(value)
        end
      rescue ArgumentError => e
        raise e.exception, "#{property} #{e.message}"
      end
      alias add_declaration! []=

      def [](property)
        declarations[normalize_property(property)]
      end
      alias get_value []

      def key?(property)
        declarations.key?(normalize_property(property))
      end

      def size
        declarations.size
      end

      # Remove CSS declaration
      # @param [#to_s] property property to be removed
      #
      # @example
      #   declarations.delete('color')
      def delete(property)
        declarations.delete(normalize_property(property))
      end
      alias remove_declaration! delete

      # Replace CSS property with multiple declarations
      # @param [#to_s] property property name to be replaces
      # @param [Hash<String => [String, Value]>] replacements hash with properties to replace with
      #
      # @example
      #  declarations = Declarations.new('line-height' => '0.25px', 'font' => 'small-caps', 'font-size' => '12em')
      #  declarations.replace_declaration!('font', {'line-height' => '1px', 'font-variant' => 'small-caps', 'font-size' => '24px'})
      #  declarations
      #  => #<CssParser::RuleSet::Declarations:0x00000000029c3018
      #  @declarations=
      #  {"line-height"=>#<CssParser::RuleSet::Declarations::Value:0x00000000038ac458 @important=false, @value="1px">,
      #   "font-variant"=>#<CssParser::RuleSet::Declarations::Value:0x00000000039b3ec8 @important=false, @value="small-caps">,
      #   "font-size"=>#<CssParser::RuleSet::Declarations::Value:0x00000000029c2c80 @important=false, @value="12em">}>
      def replace_declaration!(property, replacements, preserve_importance: false)
        property = normalize_property(property)
        raise ArgumentError, "property #{property} does not exist" unless key?(property)

        replacement_declarations = self.class.new(replacements)

        if preserve_importance
          importance = get_value(property).important
          replacement_declarations.each_value { |value| value.important = importance }
        end

        replacement_keys = declarations.keys
        replacement_values = declarations.values
        property_index = replacement_keys.index(property)

        # We should preserve subsequent declarations of the same properties
        # and prior important ones if replacement one is not important
        replacements = replacement_declarations.each.with_object({}) do |(key, replacement), result|
          existing = declarations[key]

          # No existing -> set
          unless existing
            result[key] = replacement
            next
          end

          # Replacement more important than existing -> replace
          if replacement.important && !existing.important
            result[key] = replacement
            replaced_index = replacement_keys.index(key)
            replacement_keys.delete_at(replaced_index)
            replacement_values.delete_at(replaced_index)
            property_index -= 1 if replaced_index < property_index
            next
          end

          # Existing is more important than replacement -> keep
          next if !replacement.important && existing.important

          # Existing and replacement importance are the same,
          # value which is declared later wins
          result[key] = replacement if property_index > replacement_keys.index(key)
        end

        return if replacements.empty?

        replacement_keys.delete_at(property_index)
        replacement_keys.insert(property_index, *replacements.keys)

        replacement_values.delete_at(property_index)
        replacement_values.insert(property_index, *replacements.values)

        self.declarations = replacement_keys.zip(replacement_values).to_h
      end

      def to_s(options = {})
        str = declarations.reduce(String.new) do |memo, (prop, value)|
          importance = options[:force_important] || value.important ? ' !important' : ''
          memo << "#{prop}: #{value.value}#{importance}; "
        end
        # TODO: Clean-up regexp doesn't seem to work
        str.gsub!(/^[\s^({)]+|[\n\r\f\t]*|\s+$/mx, '')
        str.strip!
        str
      end

      def ==(other)
        return false unless other.is_a?(self.class)

        declarations == other.declarations && declarations.keys == other.declarations.keys
      end

    protected

      attr_reader :declarations

    private

      attr_writer :declarations

      def normalize_property(property)
        property = property.to_s.downcase
        property.strip!
        property
      end
    end
  end
end
