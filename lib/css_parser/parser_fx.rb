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

    # expect tokens from crass
    def self.split_media_query_by_or_condition(media_query_selector)
      media_query_selector
        .each_with_object([[]]) do |token, sum|
          # comma is the same as or
          # https://developer.mozilla.org/en-US/docs/Web/CSS/@media#logical_operators
          case token
          in node: :comma
            sum << []
          in node: :ident, value: 'or' # rubocop:disable Lint/DuplicateBranch
            sum << []
          else
            sum.last << token
          end
        end # rubocop:disable Style/MultilineBlockChain
        .map { Crass::Parser.stringify(_1).strip }
        .reject(&:empty?)
    end
  end
end
