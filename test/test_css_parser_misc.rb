require File.dirname(__FILE__) + '/test_helper'

# Test cases for the CssParser.
class CssParserTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_should_ignore_comments
    # see http://www.w3.org/Style/CSS/Test/CSS2.1/current/html4/t040109-c17-comments-00-b.htm
    css =<<-EOT
      /* This is a CSS comment. */
      .one {color: green;} /* Another comment */
      /* The following should not be used:
      .one {color: red;} */
      .two {color: green; /* color: yellow; */}
      /**
      .three {color: red;} */
      .three {color: green;}
      /**/
      .four {color: green;}
      /*********/
      .five {color: green;}
      /* a comment **/
      .six {color: green;}
    EOT

    @cp.add_block!(css)
    @cp.each_selector do |sel, decs, spec|
      assert_equal 'color: green;', decs
    end
  end

  def test_calculating_specificity
    # from http://www.w3.org/TR/CSS21/cascade.html#specificity
    assert_equal 0,   Parser.calculate_specificity('*')
    assert_equal 1,   Parser.calculate_specificity('li')
    assert_equal 2,   Parser.calculate_specificity('li:first-line')
    assert_equal 2,   Parser.calculate_specificity('ul li')
    assert_equal 3,   Parser.calculate_specificity('ul ol+li')
    assert_equal 11,  Parser.calculate_specificity('h1 + *[rel=up]')
    assert_equal 13,  Parser.calculate_specificity('ul ol li.red')
    assert_equal 21,  Parser.calculate_specificity('li.red.level')
    assert_equal 100, Parser.calculate_specificity('#x34y')
  
    # from http://www.hixie.ch/tests/adhoc/css/cascade/specificity/003.html
    assert_equal Parser.calculate_specificity('div *'), Parser.calculate_specificity('p')
    assert Parser.calculate_specificity('body div *') > Parser.calculate_specificity('div *')

    # other tests
    assert_equal 11, Parser.calculate_specificity('h1[id|=123]')
  end

  def test_converting_uris
    base_uri = 'http://www.example.org/style/basic.css'
    ["body { background: url(yellow) };", "body { background: url('yellow') };", 
     "body { background: url('/style/yellow') };", 
     "body { background: url(\"../style/yellow\") };",
     "body { background: url(\"lib/../../style/yellow\") };"].each do |css|
      converted_css = Parser.convert_uris(css, base_uri)
      assert_equal "body { background: url('http://www.example.org/style/yellow') };", converted_css
    end

    converted_css = Parser.convert_uris("body { background: url(../style/yellow-dot_symbol$.png?abc=123&amp;def=456&ghi=789#1011) };", base_uri)
    assert_equal "body { background: url('http://www.example.org/style/yellow-dot_symbol$.png?abc=123&amp;def=456&ghi=789#1011') };", converted_css
  
    # taken from error log: 2007-10-23 04:37:41#2399
    converted_css = Parser.convert_uris('.specs {font-family:Helvetica;font-weight:bold;font-style:italic;color:#008CA8;font-size:1.4em;list-style-image:url("images/bullet.gif");}', 'http://www.example.org/directory/file.html')
    assert_equal ".specs {font-family:Helvetica;font-weight:bold;font-style:italic;color:#008CA8;font-size:1.4em;list-style-image:url('http://www.example.org/directory/images/bullet.gif');}", converted_css
  end

  def test_escaping_strings
    flunk
    # CssRuleSet.escape_declarations!
    CssParser.escape_string_for_style_attributes('"test test"')
  end
end
