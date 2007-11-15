require File.dirname(__FILE__) + '/test_helper'

# Test cases for the handling of media types
class CssParserMediaTypesTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_finding_by_media_type
    # from http://www.w3.org/TR/CSS21/media.html#at-media-rule
    css = <<-EOT
      @media print {
        body { font-size: 10pt }
      }
      @media screen {
        body { font-size: 13px }
      }
      @media screen, print {
        body { line-height: 1.2 }
      }
    EOT

    @cp.add_block!(css)
    assert_equal 'font-size: 10pt; line-height: 1.2;', @cp.find('body', :print).join(' ')
    assert_equal 'font-size: 13px; line-height: 1.2;', @cp.find('body', :screen).join(' ')
  end

  def test_finding_by_multiple_media_types
    css = <<-EOT
      @media print {
        body { font-size: 10pt }
      }
      @media handheld {
        body { font-size: 13px }
      }
      @media screen, print {
        body { line-height: 1.2 }
      }
    EOT
    @cp.add_block!(css)

    assert_equal 'font-size: 13px; line-height: 1.2;', @cp.find('body', [:screen,:handheld]).join(' ')
  end

  def test_adding_rule_set_with_media_type
    @cp.add_rule!('body', 'color: black;', [:handheld,:tty])
    @cp.add_rule!('body', 'color: blue;', :screen)
    assert_equal 'color: black;', @cp.find('body', :handheld).join(' ')
  end

  def test_selecting_with_all_meda_type
    @cp.add_rule!('body', 'color: black;', [:handheld,:tty])
    assert_equal 'color: black;', @cp.find('body', :all).join(' ')
  end


end
