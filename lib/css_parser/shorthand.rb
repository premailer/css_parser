module CssParser
  module Shorthand
    # Looks for long format CSS properties (e.g. <tt>margin-top</tt>) and tries to replace
    # them with shorthand CSS properties.
    #
    # See combine_dimensions_into_shorthand, combine_background_into_shorthand and combine_font_into_shorthand.
    #--
    # TODO: border
    #++
    def combine_into_shorthand(properties)
      properties = combine_dimensions_into_shorthand(properties)
      properties = combine_background_into_shorthand(properties)
      #properties = combine_font_into_shorthand(properties)
      return properties
    end


    # Looks for long format CSS font properties (e.g. <tt>font-weight</tt>) and 
    # tries to convert them into a shorthand CSS <tt>font</tt> property.  All 
    # font properties must be present in order to create a shorthand declaration.
    #
    # ==== Example
    #  properties = {"font-weight" => {:value => "300"}, "font-size" => {:value => "12pt"}, 
    #                "font-family" => {:value => "sans-serif"}}
    #
    #  combine_font_into_shorthand(properties).inspect
    #
    #  => {"font" => {:value => "300 12pt sans-serif"}}
    #--
    # TODO: handle repeating normal and inherit values
    #++
    def combine_font_into_shorthand(properties)
      # font-size is the only required property
      ['font-style', 'font-variant', 'font-weight', 'font-size',
       'line-height', 'font-family'].each do |prop|
        return properties unless properties.has_key?(prop)
      end

      new_value = ''
      ['font-style', 'font-variant', 'font-weight'].each do |property|
        if properties.has_key?(property)
          new_value += properties[property][:value] + ' '
          properties.delete(property)
        end
      end

      #new_value = 'inherit ' if new_value.strip.empty?

      new_value += properties['font-size'][:value]
      properties.delete('font-size')

      if properties.has_key?('line-height')
        new_value += '/' + properties['line-height'][:value]
        properties.delete('line-height')
      end

      if properties.has_key?('font-family')
        new_value += ' ' + properties['font-family'][:value]
        properties.delete('font-family')
      end

      properties['font'] = {:value => new_value.gsub(/[\s]+/, ' ').strip}
      properties
    end

    # Looks for long format CSS background properties (e.g. <tt>background-color</tt>) and 
    # converts them into a shorthand CSS <tt>background</tt> property.
    #
    # ==== Example
    #  properties = {"background-image" => {:value => "url('chess.png')"}, "background-color" => {:value => "gray"}, 
    #                "background-position" => {:value => "center -10.2%"}}
    #
    #  combine_background_into_shorthand(properties).inspect
    #
    #  => {"background" => {:value => "gray url('chess.png') center -10.2%"}}
    def combine_background_into_shorthand(properties)
      #puts 'bg ' +properties['background-color'][:value] if properties.has_key?('background-color')
      #puts 'bg ' +properties['background-image'][:value] if properties.has_key?('background-image')

      new_value = ''
      ['background-color', 'background-image', 'background-repeat', 
       'background-position', 'background-attachment'].each do |property|
        if properties.has_key?(property)
          new_value += properties[property][:value] + ' '
          properties.delete(property)
        end
      end

      unless new_value.strip.empty?
        properties['background'] = {:value => new_value.gsub(/[\s]+/, ' ').strip}
      end
      properties
    end

    # Looks for long format CSS dimensional properties (i.e. <tt>margin</tt> and <tt>padding</tt>) and 
    # converts them into shorthand CSS properties.
    #
    # ==== Example
    #  properties = {"margin-top" => {:value => "10px"}, "margin-bottom" => {:value => "-10px"}, 
    #                "margin-left" => {:value => "auto"}, "margin-right" => {:value => "30.2%"}}
    #
    #  combine_dimensions_into_shorthand(properties).inspect
    #
    #  => {"margin" => {:value => "10px 30.2% -10px auto"}}
    def combine_dimensions_into_shorthand(properties)
      # geometric
      directions = ['top', 'right', 'bottom', 'left']
      ['margin', 'padding'].each do |property|
        values = {}      

        foldable = properties.select { |dim, val| dim == "#{property}-top" or dim == "#{property}-right" or dim == "#{property}-bottom" or dim == "#{property}-left" }
        # All four dimensions must be present
        if foldable.length == 4
          values = {}

          directions.each { |d| values[d.to_sym] = properties["#{property}-#{d}"][:value].downcase.strip }

          if values[:left] == values[:right]
            if values[:top] == values[:bottom] 
              if values[:top] == values[:left] # All four sides are equal
                new_value = values[:top]
              else # Top and bottom are equal, left and right are equal
                new_value = values[:top] + ' ' + values[:left]
              end
            else # Only left and right are equal
              new_value = values[:top] + ' ' + values[:left] + ' ' + values[:bottom]
            end
          else # No sides are equal
            new_value = values[:top] + ' ' + values[:right] + ' ' + values[:bottom] + ' ' + values[:left]
          end # done creating 'new_value'

          # Save the new value
          unless new_value.strip.empty?
            properties[property] = {:value => new_value.gsub(/[\s]+/, ' ').strip}
          end

          # Delete the shorthand values
          directions.each { |d| properties.delete("#{property}-#{d}") }
        end
      end # done iterating through margin and padding
      properties
    end
  end
end
