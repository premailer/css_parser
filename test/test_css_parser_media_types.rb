# frozen_string_literal: true

require_relative 'test_helper'

# Test cases for the handling of media types
class CssParserMediaTypesTests < Minitest::Test
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_that_media_types_dont_include_all
    @cp.add_block!(<<-CSS)
      @media handheld {
        body { color: blue; }
        p { color: grey; }
      }
      @media screen {
        body { color: red; }
      }
    CSS
    rules = @cp.rules_by_media_query
    assert_equal ["handheld", "screen"], rules.keys.map(&:to_s).sort
  end

  def test_finding_by_media_type
    # from http://www.w3.org/TR/CSS21/media.html#at-media-rule
    @cp.add_block!(<<-CSS)
      @media print {
        body { font-size: 10pt }
      }
      @media screen {
        body { font-size: 13px }
      }
      @media screen, print {
        body { line-height: 1.2 }
      }
      @media screen, 3d-glasses, print and resolution > 90dpi {
        body { color: blue; }
      }
    CSS

    assert_equal 'font-size: 10pt; line-height: 1.2;', @cp.find_by_selector('body', :print).join(' ')
    assert_equal 'font-size: 13px; line-height: 1.2; color: blue;', @cp.find_by_selector('body', :screen).join(' ')
    assert_equal 'color: blue;', @cp.find_by_selector('body', 'print and resolution > 90dpi'.to_sym).join(' ')
  end

  def test_finding_by_multiple_media_types
    @cp.add_block!(<<-CSS)
      @media print {
        body { font-size: 10pt }
      }
      @media handheld {
        body { font-size: 13px }
      }
      @media screen, print {
        body { line-height: 1.2 }
      }
    CSS

    assert_equal 'font-size: 13px; line-height: 1.2;', @cp.find_by_selector('body', %i[screen handheld]).join(' ')
  end

  def test_adding_block_with_media_types
    @cp.add_block!(<<-CSS, media_types: [:screen])
      body { font-size: 10pt }
    CSS

    assert_equal 'font-size: 10pt;', @cp.find_by_selector('body', :screen).join(' ')
    assert @cp.find_by_selector('body', :handheld).empty?
  end

  def test_adding_block_with_media_types_followed_by_general_rule
    @cp.add_block!(<<-CSS)
      @media print {
        body { font-size: 10pt }
      }

      body { color: black; }
    CSS

    assert_includes @cp.to_s, 'color: black;'
  end

  def test_adding_block_and_limiting_media_types1
    css = <<-CSS
      @import "import1.css", print
    CSS

    base_dir = Pathname.new(__dir__).join('fixtures')

    @cp.add_block!(css, only_media_types: :screen, base_dir: base_dir)
    assert @cp.find_by_selector('div').empty?
  end

  def test_adding_block_and_limiting_media_types2
    css = <<-CSS
      @import "import1.css", print and (color)
    CSS

    base_dir = Pathname.new(__dir__).join('fixtures')

    @cp.add_block!(css, only_media_types: 'print and (color)', base_dir: base_dir)
    assert_includes @cp.find_by_selector('div').join(' '), 'color: lime'
  end

  def test_adding_block_and_limiting_media_types
    css = <<-CSS
      @import "import1.css"
    CSS

    base_dir = Pathname.new(__dir__).join('fixtures')
    @cp.add_block!(css, only_media_types: :print, base_dir: base_dir)
    assert_equal '', @cp.find_by_selector('div').join(' ')
  end

  def test_adding_rule_set_with_media_type
    @cp.add_rule!('body', 'color: black;', %i[handheld tty])
    @cp.add_rule!('body', 'color: blue;', :screen)
    assert_equal 'color: black;', @cp.find_by_selector('body', :handheld).join(' ')
  end

  def test_adding_rule_set_with_media_query
    @cp.add_rule!('body', 'color: black;', 'aural and (device-aspect-ratio: 16/9)')
    assert_equal 'color: black;', @cp.find_by_selector('body', 'aural and (device-aspect-ratio: 16/9)').join(' ')
    assert_equal 'color: black;', @cp.find_by_selector('body', :all).join(' ')
  end

  def test_selecting_with_all_media_types
    @cp.add_rule!('body', 'color: black;', %i[handheld tty])
    assert_equal 'color: black;', @cp.find_by_selector('body', :all).join(' ')
  end

  def test_to_s_includes_media_queries
    @cp.add_rule!('body', 'color: black;', 'aural and (device-aspect-ratio: 16/9)')
    assert_equal "@media aural and (device-aspect-ratio: 16/9) {\n  body {\n    color: black;\n  }\n}\n", @cp.to_s
  end
end
