# frozen_string_literal: true

require_relative 'test_helper'

class RuleSetExpandingShorthandTests < Minitest::Test
  include CssParser

  def setup
    @cp = Document.new
  end

  # Dimensions shorthand
  def test_expanding_border_shorthand
    declarations = expand_declarations('border: none')
    assert_equal 'none', declarations['border-right-style']

    declarations = expand_declarations('border: 1px solid red')
    assert_equal '1px', declarations['border-top-width']
    assert_equal 'solid', declarations['border-bottom-style']

    declarations = expand_declarations('border-color: red hsla(255, 0, 0, 5) rgb(2% ,2%,2%)')
    assert_equal 'red', declarations['border-top-color']
    assert_equal 'rgb(2%,2%,2%)', declarations['border-bottom-color']
    assert_equal 'hsla(255,0,0,5)', declarations['border-left-color']

    declarations = expand_declarations('border-color: #000000 #bada55 #ffffff #ff0000')

    assert_equal '#000000', declarations['border-top-color']
    assert_equal '#bada55', declarations['border-right-color']
    assert_equal '#ffffff', declarations['border-bottom-color']
    assert_equal '#ff0000', declarations['border-left-color']

    declarations = expand_declarations('border-color: #000000 #bada55 #ffffff')

    assert_equal '#000000', declarations['border-top-color']
    assert_equal '#bada55', declarations['border-right-color']
    assert_equal '#ffffff', declarations['border-bottom-color']
    assert_equal '#bada55', declarations['border-left-color']

    declarations = expand_declarations('border-color: #000000 #bada55')

    assert_equal '#000000', declarations['border-top-color']
    assert_equal '#bada55', declarations['border-right-color']
    assert_equal '#000000', declarations['border-bottom-color']
    assert_equal '#bada55', declarations['border-left-color']

    declarations = expand_declarations('border: thin dot-dot-dash')
    assert_equal 'dot-dot-dash', declarations['border-left-style']
    assert_equal 'thin', declarations['border-left-width']
    assert_nil declarations['border-left-color']
  end

  # Dimensions shorthand
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

  # Font shorthand
  def test_getting_font_size_from_shorthand
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "font: 300 italic 11.25#{unit}/14px verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal("11.25#{unit}", declarations['font-size'], shorthand)
    end

    ['smaller', 'small', 'medium', 'large', 'x-large'].each do |unit|
      shorthand = "font: 300 italic #{unit}/14px verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal(unit, declarations['font-size'], shorthand)
    end
  end

  def test_font_with_comments_and_spaces
    shorthand = "font: 300 /* HI */   italic  \t\t   12px  sans-serif;"
    declarations = expand_declarations(shorthand)
    assert_equal("12px", declarations['font-size'])
  end

  def test_getting_font_families_from_shorthand
    shorthand = "font: 300 italic 12px/14px \"Helvetica-Neue-Light 45\", 'verdana', helvetica, sans-serif;"
    declarations = expand_declarations(shorthand)
    assert_equal("\"Helvetica-Neue-Light 45\",'verdana',helvetica,sans-serif", declarations['font-family'])
  end

  def test_getting_font_weight_from_shorthand
    ['300', 'bold', 'bolder', 'lighter', 'normal'].each do |unit|
      shorthand = "font: #{unit} italic 12px sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal(unit, declarations['font-weight'])
    end

    # ensure normal is the default state
    ['font: normal italic 12px sans-serif;',
     'font: italic 12px sans-serif;',
     'font: small-caps normal 12px sans-serif;',
     'font: 12px/16px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['font-weight'], shorthand)
    end
  end

  def test_getting_font_variant_from_shorthand
    shorthand = "font: small-caps italic 12px sans-serif;"
    declarations = expand_declarations(shorthand)
    assert_equal('small-caps', declarations['font-variant'])
  end

  def test_getting_font_variant_from_shorthand_ensure_normal_is_the_default_state
    [
      'font: normal large sans-serif;',
      'font: normal italic 12px sans-serif;',
      'font: italic 12px sans-serif;',
      'font: normal 12px sans-serif;',
      'font: 12px/16px sans-serif;'
    ].each do |shorthand|
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
    ['font: normal bold 12px sans-serif;',
     'font: small-caps 12px sans-serif;',
     'font: normal 12px sans-serif;',
     'font: 12px/16px sans-serif;'].each do |shorthand|
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
    ['font: normal bold 12px sans-serif;',
     'font: small-caps 12px sans-serif;',
     'font: normal 12px sans-serif;',
     'font: 12px sans-serif;'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal('normal', declarations['line-height'], shorthand)
    end
  end

  def test_getting_line_height_from_shorthand_with_spaces
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "font: 300 italic 12px/ 0.25#{unit} verdana, helvetica, sans-serif;"
      declarations = expand_declarations(shorthand)
      assert_equal("0.25#{unit}", declarations['line-height'])
    end
  end

  def test_expands_nothing_using_system_fonts
    %w[caption icon menu message-box small-caption status-bar].each do |system_font|
      shorthand = "font: #{system_font}"
      declarations = expand_declarations(shorthand)
      assert_equal(["font"], declarations.keys)
      assert_equal(system_font, declarations['font'])
    end
  end

  # Background shorthand
  def test_getting_background_properties_from_shorthand
    expected = {
      "background-image" => "url('chess.png')", "background-color" => "gray", "background-repeat" => "repeat",
      "background-attachment" => "fixed", "background-position" => "50%"
    }

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

  def test_getting_background_size_from_shorthand
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "background: url('chess.png') gray 30% -0.20/-0.15#{unit} auto repeat fixed;"
      declarations = expand_declarations(shorthand)
      assert_equal("-0.15#{unit} auto", declarations['background-size'])
    end

    ['cover', 'contain', 'auto', 'initial', 'inherit'].each do |size|
      shorthand = "background: url('chess.png') #000fff 0% 50% / #{size} no-repeat fixed;"
      declarations = expand_declarations(shorthand)
      assert_equal(size, declarations['background-size'])
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

  def test_getting_background_gradient_from_shorthand
    ['linear-gradient(top, hsla(0, 0%, 0%, 0.00) 0%, hsla(0, 0%, 0%, 0.20) 100%)',
     '-webkit-gradient(linear, left top, left bottom, color-stop(0, hsla(0, 0%, 0%, 0.00)), color-stop(1, hsla(0, 0%, 0%, 0.20)))',
     '-moz-linear-gradient(bottom, blue, red)'].each do |image|
      shorthand = "background: #0f0f0f #{image} repeat ;"
      declarations = expand_declarations(shorthand)
      assert_equal(image, declarations['background-image'])
    end
  end

  # List-style shorthand
  def test_getting_list_style_properties_from_shorthand
    expected = {
      'list-style-image' => 'url(\'chess.png\')', 'list-style-type' => 'katakana',
      'list-style-position' => 'inside'
    }

    shorthand = "list-style: katakana inside url('chess.png');"
    declarations = expand_declarations(shorthand)
    assert_equal expected, declarations
  end

  def test_getting_list_style_position_from_shorthand
    ['inside', 'outside'].each do |position|
      shorthand = "list-style: katakana #{position} url('chess.png');"
      declarations = expand_declarations(shorthand)
      assert_equal(position, declarations['list-style-position'])
    end
  end

  def test_getting_list_style_type_from_shorthand
    ['disc', 'circle', 'square', 'decimal', 'decimal-leading-zero', 'lower-roman', 'upper-roman', 'lower-greek', 'lower-alpha', 'lower-latin', 'upper-alpha', 'upper-latin', 'hebrew', 'armenian', 'georgian', 'cjk-ideographic', 'hiragana', 'katakana', 'hira-gana-iroha', 'katakana-iroha', 'none'].each do |type|
      shorthand = "list-style: #{type} inside url('chess.png');"
      declarations = expand_declarations(shorthand)
      assert_equal(type, declarations['list-style-type'])
    end
  end

  def test_expanding_shorthand_with_replaced_properties_after
    shorthand = 'line-height: 0.25px !important; font-style: normal; font: small-caps italic 12px sans-serif; font-size: 12em;'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'line-height' => '0.25px',
      'font-style' => 'italic',
      'font-variant' => 'small-caps',
      'font-weight' => 'normal',
      'font-family' => 'sans-serif',
      'font-size' => '12em'
    }
    assert_equal expected_declarations, declarations
  end

  def test_expanding_important_shorthand_with_replaced_properties
    shorthand = 'line-height: 0.25px !important; font-style: normal; font: small-caps italic 12px sans-serif !important; font-size: 12em; font-family: emoji !important;'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'font-style' => 'italic',
      'font-variant' => 'small-caps',
      'font-weight' => 'normal',
      'line-height' => 'normal',
      'font-family' => 'emoji',
      'font-size' => '12px'
    }
    assert_equal expected_declarations, declarations
  end

  def test_functions_with_many_spaces
    shorthand = 'margin: calc(1em / 4 * var(--foo));'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'margin-top' => 'calc(1em / 4 * var(--foo))',
      'margin-bottom' => 'calc(1em / 4 * var(--foo))',
      'margin-left' => 'calc(1em / 4 * var(--foo))',
      'margin-right' => 'calc(1em / 4 * var(--foo))'
    }
    assert_equal expected_declarations, declarations
  end

  def test_functions_with_no_spaces
    shorthand = 'margin: calc(1em/4*4);'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'margin-top' => 'calc(1em/4*4)',
      'margin-bottom' => 'calc(1em/4*4)',
      'margin-left' => 'calc(1em/4*4)',
      'margin-right' => 'calc(1em/4*4)'
    }
    assert_equal expected_declarations, declarations
  end

  def test_functions_with_one_space
    shorthand = 'margin: calc(1em /4);'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'margin-top' => 'calc(1em /4)',
      'margin-bottom' => 'calc(1em /4)',
      'margin-left' => 'calc(1em /4)',
      'margin-right' => 'calc(1em /4)'
    }
    assert_equal expected_declarations, declarations
  end

  def test_functions_with_commas
    shorthand = 'margin: clamp(1rem, 2.5vw, 2rem)'
    declarations = expand_declarations(shorthand)
    expected_declarations = {
      'margin-top' => 'clamp(1rem, 2.5vw, 2rem)',
      'margin-bottom' => 'clamp(1rem, 2.5vw, 2rem)',
      'margin-left' => 'clamp(1rem, 2.5vw, 2rem)',
      'margin-right' => 'clamp(1rem, 2.5vw, 2rem)'
    }
    assert_equal expected_declarations, declarations
  end

protected

  def expand_declarations(declarations)
    ruleset = RuleSet.new(block: declarations)
    ruleset.expand_shorthand!

    collected = {}
    ruleset.each_declaration do |prop, val, _imp|
      collected[prop.to_s] = val.to_s
    end
    collected
  end
end
