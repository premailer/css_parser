# frozen_string_literal: true

require_relative "test_helper"

# Test cases for reading and parsing CSS
class CSSParserCoreTests < Minitest::Test
  include CssParser

  def test_empty_css
    rules = CssParser::Parser::Parser.parse <<~CSS
    CSS

    assert_equal rules, []
  end

  def test_simple_tag
    rules = CssParser::Parser::Parser.parse <<~CSS
      p { color: green; }
    CSS

    assert_equal rules, [{selector: "p", properties: "color: green;"}]
  end

  def test_multiple_simple_tag
    rules = CssParser::Parser::Parser.parse <<~CSS
      p { color: green; }
      span { color: green; }
    CSS

    assert_equal rules, [
      {selector: "p", properties: "color: green;"},
      {selector: "span", properties: "color: green;"}
    ]
  end

  def test_simple_any
    rules = CssParser::Parser::Parser.parse <<~CSS
      * { color: green; }
    CSS

    assert_equal rules, [{selector: "*", properties: "color: green;"}]
  end

  def test_simple_class
    rules = CssParser::Parser::Parser.parse <<~CSS
      .active { color: green; }
    CSS

    assert_equal rules, [{selector: ".active", properties: "color: green;"}]
  end

  def test_simple_id
    rules = CssParser::Parser::Parser.parse <<~CSS
      #active { color: green; }
    CSS

    assert_equal rules, [{selector: "#active", properties: "color: green;"}]
  end

  def test_simple_attribute
    rules = CssParser::Parser::Parser.parse <<~CSS
      [data-id] { color: green; }
    CSS

    assert_equal rules, [{selector: "[data-id]", properties: "color: green;"}]
  end

  def test_simple_attribute_value
    rules = CssParser::Parser::Parser.parse <<~CSS
      [data-id="five"] { color: green; }
      [data-id='five'] { color: green; }
    CSS

    assert_equal rules, [
      {selector: '[data-id="five"]', properties: "color: green;"},
      {selector: "[data-id='five']", properties: "color: green;"}
    ]
  end

  def test_escaped_double_quote_inside_double_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum="simon\\\"er\\\"kul"] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum="simon\"er\"kul"]), properties: "color: green;"}]
  end

  def test_single_qoute_inside_double_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum="simon'kul"] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum="simon'kul"]), properties: "color: green;"}]
  end

  def test_escaped_backslach_inside_double_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum="simon\\\\kul"] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum="simon\kul"]), properties: "color: green;"}]
  end

  def test_escaped_single_quote_inside_single_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum='simon\\\'er\\\'kul'] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum='simon\'er\'kul']), properties: "color: green;"}]
  end

  def test_double_qoute_inside_single_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum='simon"kul'] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum='simon"kul']), properties: "color: green;"}]
  end

  def test_escaped_backslach_inside_single_qoute_string
    rules = CssParser::Parser::Parser.parse <<~CSS
      [dum='simon\\\\kul'] {
        color: green;
      }
    CSS

    assert_equal rules, [{selector: %q([dum='simon\kul']), properties: "color: green;"}]
  end

  def test_double_quote_attribute_value_with_curly
    rules = CssParser::Parser::Parser.parse <<~CSS
      [data-id="fi{ve"] { color: green; }
    CSS

    assert_equal rules, [{selector: '[data-id="fi{ve"]', properties: "color: green;"}]
  end

  def test_single_quote_attribute_value_with_curly
    rules = CssParser::Parser::Parser.parse <<~CSS
      [data-id='fi{ve'] { color: green; }
    CSS

    assert_equal rules, [{selector: "[data-id='fi{ve']", properties: "color: green;"}]
  end

  def test_multiple_selectors
    rules = CssParser::Parser::Parser.parse <<~CSS
      .parent > .child { color: green; }
    CSS

    assert_equal rules, [{selector: '.parent > .child', properties: "color: green;"}]
  end

  def test_except_start_curly_in_name
    rules = CssParser::Parser::Parser.parse <<~CSS
      .sim\\\{on { color: green; }
    CSS

    assert_equal rules, [{selector: '.sim{on', properties: "color: green;"}]
  end

  def test_class_with_double_slash
    rules = CssParser::Parser::Parser.parse <<~INVAILD_CSS
      .sim\\on { color: green; }
      .ale\\ { color: green; }
    INVAILD_CSS

    assert_equal rules, [
      {selector: %q(.sim\on), properties: "color: green;"},
      {selector: '.ale\\', properties: "color: green;"}
    ]
  end

  # should I try to validate this?
  # def test_double_except_start_curly_in_name_is_invalid
  #   rules = CssParser::Parser::Parser.parse %q(
  #     .sim\\{on { color: green; }
  #   )
  #   assert_equal rules, [{selector: %q{blow up}, properties: "color: green;"}]
  # end

  def test_trible_escaped_start_curly_in_name
    rules = CssParser::Parser::Parser.parse <<~CSS
      .sim\\\\\\\\\\\\\\\{on { color: green; }
    CSS

    assert_equal rules, [{selector: %q(.sim\\\\\{on), properties: "color: green;"}]
  end

  def test_child_selector
    rules = CssParser::Parser::Parser.parse <<~CSS
      .parent > .child { color: green; }
    CSS

    assert_equal rules, [{selector: '.parent > .child', properties: "color: green;"}]
  end

  def test_content_with_quote
    rules = CssParser::Parser::Parser.parse <<~CSS
      .active {  content: "before"; }
    CSS

    assert_equal rules, [{selector: '.active', properties: "content: \"before\";"}]
  end

  def test_content_with_quoted_start_curly
    rules = CssParser::Parser::Parser.parse <<~CSS
      .active {  content: "a{b"; }
    CSS

    assert_equal rules, [{selector: '.active', properties: "content: \"a{b\";"}]
  end

  def test_content_with_quoted_end_curly
    rules = CssParser::Parser::Parser.parse <<~CSS
      .active {  content: "a}b"; }
    CSS

    assert_equal rules, [{selector: '.active', properties: "content: \"a}b\";"}]
  end

  def test_no_infinet_loop_incomplete_selector
    error = assert_raises(RuntimeError) do
      CssParser::Parser::Parser.parse <<~INCOMPLETE_CSS
        .active
      INCOMPLETE_CSS
    end

    assert_equal 'CSS invalid stylesheet, could not find end of selector', error.message
  end

  def test_no_infinet_loop_incomplete_properties
    error = assert_raises(RuntimeError) do
      CssParser::Parser::Parser.parse <<~INCOMPLETE_CSS
        .active {  content:
      INCOMPLETE_CSS
    end

    assert_equal 'CSS invalid stylesheet, could not find end of properties', error.message
  end

  def test_media_query
    <<~CSS
      @media only screen and (max-width: 600px) {
        body {
          background-color: lightblue;
        }
      }
    CSS

    # @font-face
    # @keyframe
  end
end
