require File.dirname(__FILE__) + '/test_helper'

# Test cases for reading and generating CSS shorthand properties
class CssParserShorthandTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
  end

# dimensions shorthand
  def test_getting_dimensions_from_shorthand
    # test various shorthand forms
    ['margin: 0px auto', 'margin: 0px auto 0px', 'margin: 0px auto 0px'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal({"margin-right" => "auto", "margin-bottom" => "0px", "margin-left" => "auto", "margin-top" => "0px"}, declarations)
    end

    # test various units
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "margin: 0% -0.123#{unit} 9px -.9pc"
      declarations = expand_declarations(shorthand)
      assert_equal({"margin-right" => "-0.123#{unit}", "margin-bottom" => "9px", "margin-left" => "-.9pc", "margin-top" => "0%"}, declarations)    
    end
  end

  def test_combining_dimensions_into_shorthand
    properties = {'margin-right' => {:value => 'auto'}, 'margin-bottom' => {:value => '0px'}, 'margin-left' => {:value => 'auto'}, 'margin-top' => {:value => '0px'}, 
                  'padding-right' => {:value => '1.25em'}, 'padding-bottom' => {:value => '11%'}, 'padding-left' => {:value => '3pc'}, 'padding-top' => {:value => '11.25ex'}}
    
    combined = @cp.combine_into_shorthand(properties)
    
    assert_equal({'margin' => {:value => '0px auto'}, 'padding' => {:value => '11.25ex 1.25em 11% 3pc'}}, combined)
  end

  def test_combining_incomplete_dimensions_into_shorthand
    properties = {'margin-right' => {:value => 'auto'}, 'margin-bottom' => {:value => '0px'}, 'margin-left' => {:value => 'auto'},
                  'padding-right' => {:value => '1.25em'}, 'padding-bottom' => {:value => '11%'}, 'padding-left' => {:value => '3pc'}}
    
    combined = @cp.combine_into_shorthand(properties)
    
    assert_equal(properties, combined)
  end

# font shorthand
  def test_getting_font_size_from_shorthand
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "font: 300 italic 11.25#{unit}/14px verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal("11.25#{unit}", declarations['font-size'])
    end
    
    ['smaller', 'small', 'medium', 'large', 'x-large', 'auto'].each do |unit|
      shorthand = "font: 300 italic #{unit}/14px verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal(unit, declarations['font-size'])
    end
  end

  def test_getting_font_families_from_shorthand
    shorthand = "font: 300 italic 12px/14px \"Helvetica-Neue-Light 45\", 'verdana', helvetica, sans-serif;"
    declarations = expand_declarations(shorthand)
    assert_equal("\"Helvetica-Neue-Light 45\", 'verdana', helvetica, sans-serif", declarations['font-family'])
  end

  def test_getting_font_weight_from_shorthand
    ['300', 'bold', 'bolder', 'lighter', 'normal'].each do |unit|
      shorthand = "font: #{unit} italic 12px sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal(unit, declarations['font-weight'])
    end

    # ensure normal is the default state
    ['font: normal italic 12px sans-serif;', 'font: italic 12px sans-serif;',
     'font: small-caps normal 12px sans-serif;', 'font: 12px/16px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['font-weight'], shorthand)
    end
  end

  def test_getting_font_variant_from_shorthand
    shorthand = "font: small-caps italic 12px sans-serif;"
    declarations = expand_declarations(shorthand)
    assert_equal('small-caps', declarations['font-variant'])

    # ensure normal is the default state
    ['font: normal italic 12px sans-serif;', 'font: italic 12px sans-serif;',
     'font: normal 12px sans-serif;', 'font: 12px/16px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['font-variant'], shorthand)
    end
  end

  def test_getting_font_style_from_shorthand
    ['italic', 'oblique'].each do |unit|
      shorthand = "font: normal #{unit} bold 12px sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal(unit, declarations['font-style'])
    end

    # ensure normal is the default state
    ['font: normal bold 12px sans-serif;', 'font: small-caps 12px sans-serif;',
     'font: normal 12px sans-serif;', 'font: 12px/16px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['font-style'], shorthand)
    end
  end

  def test_getting_line_height_from_shorthand
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "font: 300 italic 12px/0.25#{unit} verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal("0.25#{unit}", declarations['line-height'])
    end

    # ensure normal is the default state
    ['font: normal bold 12px sans-serif;', 'font: small-caps 12px sans-serif;',
     'font: normal 12px sans-serif;', 'font: 12px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['line-height'], shorthand)
    end
  end

  def test_combining_font_into_shorthand
    # should combine if all font properties are present
    properties = {"font-weight" => {:value => "300"}, "font-size" => {:value => "12pt"}, 
                   "font-family" => {:value => "sans-serif"}, "line-height" => {:value => "18px"},
                   "font-style" => {:value => "oblique"}, "font-variant" => {:value => "small-caps"}}
    
    combined = @cp.combine_font_into_shorthand(properties)
    
    assert_equal({"font" => {:value => "oblique small-caps 300 12pt/18px sans-serif"}}, combined)

    # should not combine if any properties are missing
    properties.delete('font-weight')
    combined = @cp.combine_font_into_shorthand(properties)
    assert_equal(properties, combined)
  end

  def test_combining_incomplete_font_into_shorthand
    # font-size is required
    properties = {"font-weight" => {:value => "300"}, "font-family" => {:value => "sans-serif"}, 
                  "line-height" => {:value => "18px"}, "font-variant" => {:value => "small-caps"}}

    combined = @cp.combine_font_into_shorthand(properties)

    assert_equal properties, combined
  end


# background shorthand
  def test_getting_background_properties_from_shorthand
    expected = {"background-image" => "url('chess.png')", "background-color" => "gray", "background-repeat" => "repeat", 
              "background-attachment" => "fixed", "background-position" => "50%"}

    shorthand = "background: url('chess.png') gray 50% repeat fixed;"
    declarations = expand_declarations(shorthand)
    assert_equal expected, declarations
  end

  def test_getting_background_position_from_shorthand
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "background: url('chess.png') gray 30% -0.15#{unit} repeat fixed;"
      declarations = expand_declarations(shorthand)
      assert_equal("30% -0.15#{unit}", declarations['background-position'])
    end

    ['left', 'center', 'right', 'top', 'bottom', 'inherit'].each do |position|
      shorthand = "background: url('chess.png') #000fff #{position} no-repeat fixed;"
      declarations = expand_declarations(shorthand)
      assert_equal(position, declarations['background-position'])
    end
  end

  def test_getting_background_colour_from_shorthand
    ['blue', 'lime', 'rgb(10,10,10)', 'rgb (  -10%, 99, 300)', '#ffa0a0', '#03c', 'trAnsparEnt', 'inherit'].each do |colour|
      shorthand = "background:#{colour} url('chess.png') center repeat fixed ;"
      declarations = expand_declarations(shorthand)
      assert_equal(colour, declarations['background-color'])
    end
  end

  def test_getting_background_attachment_from_shorthand
    ['scroll', 'fixed', 'inherit'].each do |attachment|
      shorthand = "background:#0f0f0f url('chess.png') center repeat #{attachment};"
      declarations = expand_declarations(shorthand)
      assert_equal(attachment, declarations['background-attachment'])
    end
  end

  def test_getting_background_repeat_from_shorthand
    ['repeat-x', 'repeat-y', 'no-repeat', 'inherit'].each do |repeat|
      shorthand = "background:#0f0f0f none #{repeat};"
      declarations = expand_declarations(shorthand)
      assert_equal(repeat, declarations['background-repeat'])
    end
  end

  def test_getting_background_image_from_shorthand
    ['url("chess.png")', 'url("https://example.org:80/~files/chess.png?123=abc&test#5")', 
     'url(https://example.org:80/~files/chess.png?123=abc&test#5)',
     "url('https://example.org:80/~files/chess.png?123=abc&test#5')", 'none', 'inherit'].each do |image|
      
      shorthand = "background: #0f0f0f #{image} ;"
      declarations = expand_declarations(shorthand)
      assert_equal(image, declarations['background-image'])
    end
  end


  def test_combining_background_into_shorthand
    properties = {'background-image' => {:value => 'url(\'chess.png\')'}, 'background-color' => {:value => 'gray'}, 
                  'background-position' => {:value => 'center -10.2%'}, 'background-attachment' => {:value => 'fixed'},
                  'background-repeat' => {:value => 'no-repeat'}}
    
    combined = @cp.combine_into_shorthand(properties)
    
    assert_equal({'background' => {:value => 'gray url(\'chess.png\') no-repeat center -10.2% fixed'}}, combined)
  end

protected
  def expand_declarations(declarations)
    ruleset = RuleSet.new(nil, declarations)
    ruleset.expand_shorthand!

    collected = {}
    ruleset.each_declaration do |prop, val, imp|
      collected[prop.to_s] = val.to_s
    end
    collected  
  end
end
