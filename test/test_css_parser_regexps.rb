# coding: iso-8859-1
# frozen_string_literal: true

require_relative 'test_helper'

# Test cases for CSS regular expressions
#
# see http://www.w3.org/TR/CSS21/syndata.html and
# http://www.w3.org/TR/CSS21/grammar.html
class CssParserRegexpTests < Minitest::Test
  def test_strings
    # complete matches
    [
      '"abcd"', '" A sd sédrcv \'dsf\' asd rfg asd"', '"A\ d??ef 123!"',
      "\"this is\\\n a test\"", '"back\67round"', '"r\000065 ed"',
      "'abcd'", "' A sd sedrcv \"dsf\" asd rf—&23$%#%$g asd'", "'A\\\n def 123!'",
      "'this is\\\n a test'", "'back\\67round'", "'r\\000065 ed'"
    ].each do |str|
      assert_equal str, str.match(CssParser::RE_STRING).to_s
    end

    test_string = "p { background: red url(\"url\\.'p'ng\"); }"
    assert_equal "\"url\\.'p'ng\"", test_string.match(CssParser::RE_STRING).to_s
  end

  def test_box_model_units
    %w[auto inherit 80px 90pt 80pc 80rem 80vh 70vm 60vw 1vmin 2vmax 0 2em 3ex 1cm 100mm 2in 120%].each do |str|
      assert_match(CssParser::BOX_MODEL_UNITS_RX, str)
    end
  end

  def test_unicode
    ['back\67round', 'r\000065 ed', '\00006C'].each do |str|
      assert_match(Regexp.new(CssParser::RE_UNICODE), str)
    end
  end

  def test_colour
    [
      'color: #fff', 'color:#f0a09c;', 'color: #04A', 'color: #04a9CE',
      'color: rgb(100, -10%, 300);', 'color: rgb(10,10,10)', 'color:rgb(12.7253%, -12%,0)',
      'color: hsla(-15, -77%, 19%, 5%);',
      'color: black', 'color:Red;', 'color: AqUa;', 'color: blue   ', 'color: transparent',
      'color: darkslategray'
    ].each do |colour|
      assert_match(CssParser::RE_COLOUR, colour)
    end

    [
      'color: #fa', 'color:#f009c;', 'color: #04G', 'color: #04a9Cq',
      'color: rgb 100, -10%, 300;', 'color: rgb 10,10,10', 'color:rgb(12px, -12%,0)',
      'color:fuscia;', 'color: thick',
      'color:  alice_blue'
    ].each do |colour|
      refute_match(CssParser::RE_COLOUR, colour)
    end
  end

  def test_gradients
    [
      'linear-gradient(bottom, rgb(197,112,191) 7%, rgb(237,146,230) 54%, rgb(255,176,255) 77%)',
      'linear-gradient(top, hsla(0, 0%, 0%, 0.00) 0%, hsla(0, 0%, 0%, 0.20) 100%)',
      '-o-linear-gradient(bottom, rgb(197,112,191) 7%, rgb(237,146,230) 54%, rgb(255,176,255) 77%)',
      '-moz-linear-gradient(bottom, rgb(197,112,191) 7%, rgb(237,146,230) 54%, rgb(255,176,255) 77%)',
      '-webkit-linear-gradient(bottom, rgb(197,112,191) 7%, rgb(237,146,230) 54%, rgb(255,176,255) 77%)',
      '-webkit-gradient(linear, left top, left bottom, color-stop(0, hsla(0, 0%, 0%, 0.00)), color-stop(1, hsla(0, 0%, 0%, 0.20)))',
      '-ms-linear-gradient(bottom, rgb(197,112,191) 7%, rgb(237,146,230) 54%, rgb(255,176,255) 77%)'
    ].each do |grad|
      assert_match(CssParser::RE_GRADIENT, grad)
    end
  end

  def test_uris
    crazy_uri = 'http://www.example.com:80/~/redb%20all.png?test=test&test;test+test#test!'

    assert_equal "url('#{crazy_uri}')",
      "li { list-style: url('#{crazy_uri}') disc }".match(CssParser::RE_URI).to_s

    assert_equal "url(#{crazy_uri})",
      "li { list-style: url(#{crazy_uri}) disc }".match(CssParser::RE_URI).to_s

    assert_equal "url(\"#{crazy_uri}\")",
      "li { list-style: url(\"#{crazy_uri}\") disc }".match(CssParser::RE_URI).to_s
  end

  def test_important
    assert_match(CssParser::IMPORTANT_IN_PROPERTY_RX, "color: #f00 !important   ;")
    refute_match(CssParser::IMPORTANT_IN_PROPERTY_RX, "color: #f00 !importantish;")
  end

protected

  def load_test_file(filename)
    fh = File.new("fixtures/#{filename}", 'r')
    test_file = fh.read
    fh.close

    test_file
  end
end
