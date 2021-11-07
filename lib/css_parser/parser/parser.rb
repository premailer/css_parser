module CssParser
  class Parser
    module Parser
      def self.parse(css)
        puts css

        rules = []
        scanner = StringScanner.new(css)

        while !scanner.eos?
          rule = {
            selector: "",
            properties: "",
          }
          scanner.skip(/\s*/)
          rule[:selector] = parse_selector(scanner).strip

          properties = scanner.scan_until(/}/)
          pp properties
          rule[:properties] += properties[0..-2].strip

          rules << rule
          puts "pushing rule #{rule.inspect}"
          scanner.skip(/\s*/)
        end

        css
        return rules
      end

      def self.parse_string(scanner, quote)
        quoted_string = ""
        string_ended = false

        until string_ended
          selector = scanner.scan_until(/#{quote}/)
          quoted_string += selector
          backslashes = /\\*\z/.match(selector[0..-2])[0].length
          puts "backslashes #{backslashes} even? #{backslashes.even?}"
          string_ended = backslashes.even?
        end
        puts "quoted_string"
        puts quoted_string
        puts quoted_string.gsub(/\\{2}/, "5")

        quoted_string.gsub(/\\{2}/, "\\")
      end

      def self.parse_selector(scanner)
        new_selector = ""

        got_to_properties = false
        while !got_to_properties
          puts "=" * 60

          selector = scanner.scan_until(/'|"|{|\\{2}/)
          case scanner[0]
          when "\\\\" # maybe this can be replaced with a gsub at the end .tr("\\\\", "\\")
            puts scanner[0].length
            puts selector
            puts selector[0..(-1-scanner[0].length)]
            new_selector += selector[0..(- 1 - scanner[0].length)]
            # if you have two backslashes the selector should have one
            new_selector += "\\"

            puts "the selector is now "
            puts new_selector
          when "\"", "'"
            backslashes = /\\*\z/.match(selector[0..-2])[0].length
            case backslashes
            when 0
              new_selector += selector
              new_selector += parse_string(scanner, scanner[0])
            when 1
              new_selector += selector[0..-3]
              new_selector += "\""
            else
              raise "should only be 0 or 1 backslash at this location"
            end

          when "{"
            # check if it is escaped
            # should only be 0 or 1 backslash before { since we scan until will we find an escaped backslash or curly
            backslashes = /\\*\z/
              .match(selector[0..-2])
              .tap { |a| puts "found #{a.inspect} #{a[0].inspect} length #{a[0].length}" }
              .yield_self { |match| match[0].length }

            case backslashes
            when 0
              new_selector += selector[0..-2]
            when 1
              puts "curly was escaped"
              puts selector[0..-3]
              new_selector += selector[0..-3] # "remove last \ and {  and append { to selector"
              new_selector += "{"
            else
              raise "should only be 0 or 1 backslash at this location"
            end

            puts "the selector is now "
            puts new_selector

            # If these is an odd number of backslashes it is expected
            got_to_properties = backslashes.even?
          else
            puts "got something unexpected #{scanner.values_at(0).inspect}"
            raise "got something unexpected #{scanner.values_at(0).inspect}"
          end
        end

        new_selector
      end
    end
  end
end


