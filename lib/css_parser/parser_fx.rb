# frozen_string_literal: true

module CssParser
  # We have a Parser class which you create and instance of but we have some
  # functions which is nice to have outside of this instance
  #
  # Intended as private helpers for lib. Breaking changed with no warning
  module ParserFx
    # Receives properties from a style_rule node from crass.
    def self.create_declaration_from_properties(properties)
      declarations = RuleSet::Declarations.new

      properties.each do |child|
        case child
        in node: :property, value: '' # nothing, happen for { color:green; color: }
        in node: :property
          declarations.add_declaration!(
            child[:name],
            RuleSet::Declarations::Value.new(child[:value], important: child[:important])
          )
        in node: :whitespace # nothing
        in node: :semicolon # nothing
        in node: :error # nothing
        end
      end

      declarations
    end

    # it is expecting the selector tokens from node: :style_rule, not just
    # from Crass::Tokenizer.tokenize(input)
    def self.split_selectors(tokens)
      tokens
        .each_with_object([[]]) do |token, sum|
          case token
          in node: :comma
            sum << []
          else
            sum.last << token
          end
        end
    end
  end
end
