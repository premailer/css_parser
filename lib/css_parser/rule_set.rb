# frozen_string_literal: true

require 'forwardable'

module CssParser
  class RuleSet
    # Patterns for specificity calculations
    RE_ELEMENTS_AND_PSEUDO_ELEMENTS = /((^|[\s+>]+)\w+|:(first-line|first-letter|before|after))/i.freeze
    RE_NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES = /(\.\w+)|(\[\w+)|(:(link|first-child|lang))/i.freeze

    BACKGROUND_PROPERTIES = ['background-color', 'background-image', 'background-repeat', 'background-position', 'background-size', 'background-attachment'].freeze
    LIST_STYLE_PROPERTIES = ['list-style-type', 'list-style-position', 'list-style-image'].freeze
    FONT_STYLE_PROPERTIES = ['font-style', 'font-variant', 'font-weight', 'font-size', 'line-height', 'font-family'].freeze
    BORDER_STYLE_PROPERTIES = ['border-width', 'border-style', 'border-color'].freeze
    BORDER_PROPERTIES = ['border', 'border-left', 'border-right', 'border-top', 'border-bottom'].freeze

    NUMBER_OF_DIMENSIONS = 4

    DIMENSIONS = [
      ['margin', %w[margin-top margin-right margin-bottom margin-left]],
      ['padding', %w[padding-top padding-right padding-bottom padding-left]],
      ['border-color', %w[border-top-color border-right-color border-bottom-color border-left-color]],
      ['border-style', %w[border-top-style border-right-style border-bottom-style border-left-style]],
      ['border-width', %w[border-top-width border-right-width border-bottom-width border-left-width]]
    ].freeze

    class Declarations
      class Value
        attr_reader :value
        attr_accessor :important, :order

        def initialize(value, important: nil, order: 0)
          self.value = value
          @important = important.nil? ? !value.match(CssParser::IMPORTANT_IN_PROPERTY_RX).nil? : important
          @order = order
        end

        def value=(value)
          value = value.to_s.sub(/\s*;\s*\Z/, '').gsub(CssParser::IMPORTANT_IN_PROPERTY_RX, '').strip
          raise ArgumentError, 'value is empty' if value.empty?

          @value = value.freeze
        end

        def to_s
          return value unless important

          "#{value} !important"
        end
      end

      def initialize(declarations = {})
        @order = 0
        @declarations = {}
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
          return
        end

        if value.to_s.strip.empty?
          delete(property)
          return
        end

        declarations[property] = Value.new(value, order: @order += 1)
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

      def each(&block)
        declarations.sort_by { |_name, value| value.order }.each(&block)
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

    private

      attr_reader :declarations

      def normalize_property(property)
        property = property.downcase
        property.strip!
        property
      end
    end

    extend Forwardable

    # Array of selector strings.
    attr_reader :selectors

    # Integer with the specificity to use for this RuleSet.
    attr_accessor :specificity

    # @!method add_declaration!
    #   @see CssParser::RuleSet::Declarations#add_declaration!
    # @!method delete
    #   @see CssParser::RuleSet::Declarations#delete
    def_delegators :declarations, :add_declaration!, :delete
    alias []= add_declaration!
    alias remove_declaration! delete

    def initialize(selectors, block, specificity = nil)
      @selectors = []
      @specificity = specificity
      parse_selectors!(selectors) if selectors
      parse_declarations!(block)
    end

    # Get the value of a property
    def get_value(property)
      return '' unless declarations.key?(property)

      "#{declarations[property]};"
    end
    alias [] get_value

    # Iterate through selectors.
    #
    # Options
    # -  +force_important+ -- boolean
    #
    # ==== Example
    #   ruleset.each_selector do |sel, dec, spec|
    #     ...
    #   end
    def each_selector(options = {}) # :yields: selector, declarations, specificity
      decs = declarations.to_s(options)
      if @specificity
        @selectors.each { |sel| yield sel.strip, decs, @specificity }
      else
        @selectors.each { |sel| yield sel.strip, decs, CssParser.calculate_specificity(sel) }
      end
    end

    # Iterate through declarations.
    def each_declaration # :yields: property, value, is_important
      declarations.each do |property_name, value|
        yield property_name, value.value, value.important
      end
    end

    # Return all declarations as a string.
    def declarations_to_s(options = {})
      declarations.to_s(options)
    end

    # Return the CSS rule set as a string.
    def to_s
      "#{@selectors.join(',')} { #{declarations} }"
    end

    # Split shorthand declarations (e.g. +margin+ or +font+) into their constituent parts.
    def expand_shorthand!
      # border must be expanded before dimensions
      expand_border_shorthand!
      expand_dimensions_shorthand!
      expand_font_shorthand!
      expand_background_shorthand!
      expand_list_style_shorthand!
    end

    # Convert shorthand background declarations (e.g. <tt>background: url("chess.png") gray 50% repeat fixed;</tt>)
    # into their constituent parts.
    #
    # See http://www.w3.org/TR/CSS21/colors.html#propdef-background
    def expand_background_shorthand! # :nodoc:
      return unless declarations.key?('background')

      value = declarations['background'].value.dup

      if value =~ CssParser::RE_INHERIT
        BACKGROUND_PROPERTIES.each do |prop|
          split_declaration('background', prop, 'inherit')
        end
      end

      split_declaration('background', 'background-image', value.slice!(Regexp.union(CssParser::URI_RX, CssParser::RE_GRADIENT, /none/i)))
      split_declaration('background', 'background-attachment', value.slice!(CssParser::RE_SCROLL_FIXED))
      split_declaration('background', 'background-repeat', value.slice!(CssParser::RE_REPEAT))
      split_declaration('background', 'background-color', value.slice!(CssParser::RE_COLOUR))
      split_declaration('background', 'background-size', extract_background_size_from(value))
      split_declaration('background', 'background-position', value.slice(CssParser::RE_BACKGROUND_POSITION))

      declarations.delete('background')
    end

    def extract_background_size_from(value)
      size = value.slice!(CssParser::RE_BACKGROUND_SIZE)

      size.sub(%r{^\s*/\s*}, '') if size
    end

    # Split shorthand border declarations (e.g. <tt>border: 1px red;</tt>)
    # Additional splitting happens in expand_dimensions_shorthand!
    def expand_border_shorthand! # :nodoc:
      BORDER_PROPERTIES.each do |k|
        next unless declarations.key?(k)

        value = declarations[k].value.dup

        split_declaration(k, "#{k}-width", value.slice!(CssParser::RE_BORDER_UNITS))
        split_declaration(k, "#{k}-color", value.slice!(CssParser::RE_COLOUR))
        split_declaration(k, "#{k}-style", value.slice!(CssParser::RE_BORDER_STYLE))

        declarations.delete(k)
      end
    end

    # Split shorthand dimensional declarations (e.g. <tt>margin: 0px auto;</tt>)
    # into their constituent parts.  Handles margin, padding, border-color, border-style and border-width.
    def expand_dimensions_shorthand! # :nodoc:
      DIMENSIONS.each do |property, (top, right, bottom, left)|
        next unless declarations.key?(property)

        value = declarations[property].value.dup

        # RGB and HSL values in borders are the only units that can have spaces (within params).
        # We cheat a bit here by stripping spaces after commas in RGB and HSL values so that we
        # can split easily on spaces.
        #
        # TODO: rgba, hsl, hsla
        value.gsub!(RE_COLOUR) { |c| c.gsub(/(\s*,\s*)/, ',') }

        matches = value.strip.split(/\s+/)

        case matches.length
        when 1
          values = matches.to_a * 4
        when 2
          values = matches.to_a * 2
        when 3
          values = matches.to_a
          values << matches[1] # left = right
        when 4
          values = matches.to_a
        end

        t, r, b, l = values

        split_declaration(property, top, t)
        split_declaration(property, right, r)
        split_declaration(property, bottom, b)
        split_declaration(property, left, l)

        declarations.delete(property)
      end
    end

    # Convert shorthand font declarations (e.g. <tt>font: 300 italic 11px/14px verdana, helvetica, sans-serif;</tt>)
    # into their constituent parts.
    def expand_font_shorthand! # :nodoc:
      return unless declarations.key?('font')

      font_props = {}

      # reset properties to 'normal' per http://www.w3.org/TR/CSS21/fonts.html#font-shorthand
      ['font-style', 'font-variant', 'font-weight', 'font-size', 'line-height'].each do |prop|
        font_props[prop] = 'normal'
      end

      value = declarations['font'].value.dup
      value.gsub!(%r{/\s+}, '/') # handle spaces between font size and height shorthand (e.g. 14px/ 16px)
      is_important = declarations['font'].important
      order = declarations['font'].order

      in_fonts = false

      matches = value.scan(/("(.*[^"])"|'(.*[^'])'|(\w[^ ,]+))/)
      matches.each do |match|
        m = match[0].to_s.strip
        m.gsub!(/;$/, '')

        if in_fonts
          if font_props.key?('font-family')
            font_props['font-family'] += ", #{m}"
          else
            font_props['font-family'] = m
          end
        elsif m =~ /normal|inherit/i
          ['font-style', 'font-weight', 'font-variant'].each do |font_prop|
            font_props[font_prop] = m unless font_props.key?(font_prop)
          end
        elsif m =~ /italic|oblique/i
          font_props['font-style'] = m
        elsif m =~ /small-caps/i
          font_props['font-variant'] = m
        elsif m =~ /[1-9]00$|bold|bolder|lighter/i
          font_props['font-weight'] = m
        elsif m =~ CssParser::FONT_UNITS_RX
          if m =~ %r{/}
            font_props['font-size'], font_props['line-height'] = m.split('/')
          else
            font_props['font-size'] = m
          end
          in_fonts = true
        end
      end

      font_props.each { |font_prop, font_val| declarations[font_prop] = Declarations::Value.new(font_val, important: is_important, order: order) }

      declarations.delete('font')
    end

    # Convert shorthand list-style declarations (e.g. <tt>list-style: lower-alpha outside;</tt>)
    # into their constituent parts.
    #
    # See http://www.w3.org/TR/CSS21/generate.html#lists
    def expand_list_style_shorthand! # :nodoc:
      return unless declarations.key?('list-style')

      value = declarations['list-style'].value.dup

      if value =~ CssParser::RE_INHERIT
        LIST_STYLE_PROPERTIES.each do |prop|
          split_declaration('list-style', prop, 'inherit')
        end
      end

      split_declaration('list-style', 'list-style-type', value.slice!(CssParser::RE_LIST_STYLE_TYPE))
      split_declaration('list-style', 'list-style-position', value.slice!(CssParser::RE_INSIDE_OUTSIDE))
      split_declaration('list-style', 'list-style-image', value.slice!(Regexp.union(CssParser::URI_RX, /none/i)))

      declarations.delete('list-style')
    end

    # Create shorthand declarations (e.g. +margin+ or +font+) whenever possible.
    def create_shorthand!
      create_background_shorthand!
      create_dimensions_shorthand!
      # border must be shortened after dimensions
      create_border_shorthand!
      create_font_shorthand!
      create_list_style_shorthand!
    end

    # Combine several properties into a shorthand one
    def create_shorthand_properties!(properties, shorthand_property) # :nodoc:
      values = []
      properties_to_delete = []
      properties.each do |property|
        if declarations.key?(property) and not declarations[property].important
          values << declarations[property].value
          properties_to_delete << property
        end
      end

      return if values.length <= 1

      properties_to_delete.each do |property|
        declarations.delete(property)
      end

      declarations[shorthand_property] = values.join(' ')
    end

    # Looks for long format CSS background properties (e.g. <tt>background-color</tt>) and
    # converts them into a shorthand CSS <tt>background</tt> property.
    #
    # Leaves properties declared !important alone.
    def create_background_shorthand! # :nodoc:
      # When we have a background-size property we must separate it and distinguish it from
      # background-position by preceding it with a backslash. In this case we also need to
      # have a background-position property, so we set it if it's missing.
      # http://www.w3schools.com/cssref/css3_pr_background.asp
      if declarations.key?('background-size') and not declarations['background-size'].important
        unless declarations.key?('background-position')
          declarations['background-position'] = '0% 0%'
        end

        declarations['background-size'].value = "/ #{declarations['background-size'].value}"
      end

      create_shorthand_properties! BACKGROUND_PROPERTIES, 'background'
    end

    # Combine border-color, border-style and border-width into border
    # Should be run after create_dimensions_shorthand!
    #
    # TODO: this is extremely similar to create_background_shorthand! and should be combined
    def create_border_shorthand! # :nodoc:
      values = []

      BORDER_STYLE_PROPERTIES.each do |property|
        next unless declarations.key?(property) and not declarations[property].important
        # can't merge if any value contains a space (i.e. has multiple values)
        # we temporarily remove any spaces after commas for the check (inside rgba, etc...)
        return nil if declarations[property].value.gsub(/,\s/, ',').strip =~ /\s/

        values << declarations[property].value
        declarations.delete(property)
      end

      return if values.empty?

      declarations['border'] = values.join(' ')
    end

    # Looks for long format CSS dimensional properties (margin, padding, border-color, border-style and border-width)
    # and converts them into shorthand CSS properties.
    def create_dimensions_shorthand! # :nodoc:
      return if declarations.size < NUMBER_OF_DIMENSIONS

      DIMENSIONS.each do |property, dimensions|
        values = %i[top right bottom left].each_with_index.with_object({}) do |(side, index), result|
          next unless declarations.key?(dimensions[index])

          result[side] = declarations[dimensions[index]].value
        end

        # All four dimensions must be present
        next if values.size != dimensions.size

        new_value = values.values_at(*compute_dimensions_shorthand(values)).join(' ').strip
        declarations[property] = new_value unless new_value.empty?

        # Delete the longhand values
        dimensions.each { |d| declarations.delete(d) }
      end
    end

    # Looks for long format CSS font properties (e.g. <tt>font-weight</tt>) and
    # tries to convert them into a shorthand CSS <tt>font</tt> property.  All
    # font properties must be present in order to create a shorthand declaration.
    def create_font_shorthand! # :nodoc:
      return unless FONT_STYLE_PROPERTIES.all? { |prop| declarations.key?(prop) }

      new_value = String.new
      ['font-style', 'font-variant', 'font-weight'].each do |property|
        unless declarations[property].value == 'normal'
          new_value << declarations[property].value << ' '
        end
      end

      new_value << declarations['font-size'].value

      unless declarations['line-height'].value == 'normal'
        new_value << '/' << declarations['line-height'].value
      end

      new_value << ' ' << declarations['font-family'].value

      declarations['font'] = new_value.gsub(/\s+/, ' ')

      FONT_STYLE_PROPERTIES.each { |prop| declarations.delete(prop) }
    end

    # Looks for long format CSS list-style properties (e.g. <tt>list-style-type</tt>) and
    # converts them into a shorthand CSS <tt>list-style</tt> property.
    #
    # Leaves properties declared !important alone.
    def create_list_style_shorthand! # :nodoc:
      create_shorthand_properties! LIST_STYLE_PROPERTIES, 'list-style'
    end

  private

    attr_accessor :declarations

    def compute_dimensions_shorthand(values)
      # All four sides are equal, returning single value
      return %i[top] if values.values.uniq.count == 1

      # `/* top | right | bottom | left */`
      return %i[top right bottom left] if values[:left] != values[:right]

      # Vertical are the same & horizontal are the same, `/* vertical | horizontal */`
      return %i[top left] if values[:top] == values[:bottom]

      %i[top left bottom]
    end

    # utility method for re-assign shorthand elements to longhand versions
    def split_declaration(src, dest, value) # :nodoc:
      return unless value and not value.empty?

      return if declarations.key?(dest) && declarations[dest].order > declarations[src].order

      declarations[dest] = declarations[src].dup
      declarations[dest].value = value
    end

    def parse_declarations!(block) # :nodoc:
      self.declarations = Declarations.new

      return unless block

      continuation = nil
      block.split(/[;$]+/m).each do |decs|
        decs = continuation ? continuation + decs : decs
        if decs =~ /\([^)]*\Z/ # if it has an unmatched parenthesis
          continuation = "#{decs};"
        elsif (matches = decs.match(/\s*(.[^:]*)\s*:\s*(.+?)(;?\s*\Z)/i))
          # skip end_of_declaration
          property = matches[1]
          value = matches[2]
          add_declaration!(property, value)
          continuation = nil
        end
      end
    end

    #--
    # TODO: way too simplistic
    #++
    def parse_selectors!(selectors) # :nodoc:
      @selectors = selectors.split(',').map do |s|
        s.gsub!(/\s+/, ' ')
        s.strip!
        s
      end
    end
  end

  class OffsetAwareRuleSet < RuleSet
    # File offset range
    attr_reader :offset

    # the local or remote location
    attr_accessor :filename

    def initialize(filename, offset, selectors, block, specificity = nil)
      super(selectors, block, specificity)
      @offset = offset
      @filename = filename
    end
  end
end
