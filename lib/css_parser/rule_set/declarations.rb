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
          raise EmptyValueError, 'value is empty' if value.empty?

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

      def_delegators :declarations, :each, :each_key, :each_value

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
          begin
            declarations[property] = Value.new(value)
          rescue EmptyValueError => e
            raise e.exception, "#{property} #{e.message}"
          end
        end
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
      # This function is used to expand and collapse css properties that has
      # short and syntax like `border: 1px solid` is short for `border-width:
      # 1p; border-type: solid;` or `border-width: 1p; border-top-style:
      # solid;border-right-style: solid;border-bottom-style:
      # solid;border-left-style: solid;`
      #
      # This function also respects the order the order the rules was written in. If we had the declaration like
      #   border-top-style:solid;
      #   border-right-style: solid;
      #   border-bottom-style: solid;
      #   border-left-style: solid;
      # and want to replace "border-bottom-style" with "border-left-style: dashed;" border-left-style will still be "solid" because the rule that is last take presidency. If you replace "border-bottom-style" with "border-right-style: dashed;", "border-right-style" with be dashed
      #
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
      def replace_declaration!(replacing_property, replacements, preserve_importance: false)
        replacing_property = normalize_property(replacing_property)
        raise ArgumentError, "property #{replacing_property} does not exist" unless key?(replacing_property)

        replacement_declarations = self.class.new(replacements)

        if preserve_importance
          importance = get_value(replacing_property).important
          replacement_declarations.each_value { |value| value.important = importance }
        end

        # remove declarations where replacement is important but not current
        each do |property, value|
          if replacement_declarations[property]&.important && !value.important
            delete(property)
          end
        end

        # remove replacement declarations where current is important but not replacement
        replacement_declarations.each do |property, value|
          if self[property]&.important && !value.important
            replacement_declarations.delete(property)
          end
        end

        propperties = declarations.keys
        property_index = propperties.index(replacing_property)
        property_with_higher_precidence =
          propperties[(property_index + 1)..].to_set
        replacement_declarations.each_key do |property|
          if property_with_higher_precidence.member?(property)
            replacement_declarations.delete(property)
          else
            delete(property)
          end
        end

        new_declaration = []
        declarations.each do |property, value|
          if property == replacing_property
            replacement_declarations.each do |property, value|
              new_declaration << [property, value]
            end
          else
            new_declaration << [property, value]
          end
        end

        self.declarations = new_declaration.to_h
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
