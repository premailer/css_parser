# frozen_string_literal: true

module CssParser
  class Parser
    module Parser
      def self.parse(css)
        puts css

        rules = []
        scanner = StringScanner.new(css)

        until scanner.eos?
          rule = {
            selector: '',
            properties: ''
          }
          scanner.skip(/\s*/)
          rule[:selector] = parse_selector(scanner).strip
          rule[:properties] = parse_proppertied(scanner).strip

          rules << rule
          puts "pushing rule #{rule.inspect}"
          scanner.skip(/\s*/)
        end

        rules
      end

      def self.parse_string(scanner, quote)
        quoted_string = ''
        string_ended = false

        until string_ended
          selector = scanner.scan_until(/#{quote}/)
          quoted_string += selector
          backslashes = /\\*\z/.match(selector[0..-2])[0].length
          string_ended = backslashes.even?
        end

        quoted_string.gsub(/\\{2}/, '\\')
      end

      def self.parse_selector(scanner)
        new_selector = ''
        got_to_properties = false

        until got_to_properties
          selector = scanner.scan_until(/'|"|{|\\{2}/)
          case scanner[0]
          when nil
            raise 'CSS invalid stylesheet, could not find end of selector'
          when '\\\\' # maybe this can be replaced with a gsub at the end .tr("\\\\", "\\")
            new_selector += selector[0..(- 1 - scanner[0].length)]
            # if you have two backslashes the selector should have one
            new_selector += '\\'

          when '"', "'"
            backslashes = /\\*\z/.match(selector[0..-2])[0].length
            case backslashes
            when 0
              new_selector += selector
              new_selector += parse_string(scanner, scanner[0])
            when 1
              new_selector += selector[0..-3]
              new_selector += '"'
            else
              raise 'should only be 0 or 1 backslash at this location'
            end

          when '{'
            # check if it is escaped
            # should only be 0 or 1 backslash before { since we scan until will we find an escaped backslash or curly
            backslashes = /\\*\z/
                          .match(selector[0..-2])
                          .yield_self { |match| match[0].length }

            case backslashes
            when 0
              new_selector += selector[0..-2]
            when 1
              new_selector += selector[0..-3] # "remove last \ and {  and append { to selector"
              new_selector += '{'
            else
              raise 'should only be 0 or 1 backslash at this location'
            end

            # If these is an odd number of backslashes it is expected
            got_to_properties = backslashes.even?
          else
            raise "got something unexpected #{scanner.values_at(0).inspect}"
          end
        end

        new_selector
      end

      def self.parse_proppertied(scanner)
        properties = ''
        end_of_propertied = false

        until end_of_propertied
          selector = scanner.scan_until(/'|"|}/)
          case scanner[0]
          when nil
            raise 'CSS invalid stylesheet, could not find end of properties'
          when '"', "'"
            backslashes = /\\*\z/.match(selector[0..-2])[0].length
            raise 'Dont think you can have any escaped quates here' unless backslashes == 0

            properties += selector
            properties += parse_string(scanner, scanner[0])
          when '}'
            properties += selector[0..-2]
            end_of_propertied = true
          else
            raise "got something unexpected #{scanner.values_at(0).inspect}"
          end
        end

        properties.strip
      end
    end
  end
end
