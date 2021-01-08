# frozen_string_literal: true

require_relative 'test_helper'

# Test cases for the CssParser's loading functions.
class CssParserOffsetCaptureTests < Minitest::Test
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_capturing_offsets_for_local_file
    file_name = File.expand_path('fixtures/simple.css', __dir__)
    @cp.load_file!(file_name, capture_offsets: true)

    rules = @cp.find_rule_sets(['body', 'p'])

    # check that we found the body rule where we expected
    assert_equal 0, rules[0].offset.first
    assert_equal 43, rules[0].offset.last
    assert_equal file_name, rules[0].filename

    # and the p rule
    assert_equal 45, rules[1].offset.first
    assert_equal 63, rules[1].offset.last
    assert_equal file_name, rules[1].filename
  end

  # http://github.com/premailer/css_parser/issues#issue/4
  def test_capturing_offsets_from_remote_file
    # TODO: test SSL locally
    @cp.load_uri!("https://dialect.ca/inc/screen.css", capture_offsets: true)

    # there are a lot of rules in this file, but check some rule offsets
    rules = @cp.find_rule_sets(['#container', '#name_case_converter textarea'])
    assert_equal 2, rules.count

    assert_equal 2172, rules.first.offset.first
    assert_equal 2227, rules.first.offset.last
    assert_equal 'https://dialect.ca/inc/screen.css', rules.first.filename

    assert_equal 10_703, rules.last.offset.first
    assert_equal 10_752, rules.last.offset.last
    assert_equal 'https://dialect.ca/inc/screen.css', rules.last.filename
  end

  def test_capturing_offsets_from_string
    css = <<-CSS
      body { margin: 0px; }
      p { padding: 0px; }
      #content { font: 12px/normal sans-serif; }
      .content { color: red; }
    CSS
    @cp.load_string!(css, capture_offsets: true, filename: 'index.html')

    rules = @cp.find_rule_sets(['body', 'p', '#content', '.content'])
    assert_equal 4, rules.count

    assert_equal 6, rules[0].offset.first
    assert_equal 27, rules[0].offset.last
    assert_equal 'index.html', rules[0].filename

    assert_equal 34, rules[1].offset.first
    assert_equal 53, rules[1].offset.last
    assert_equal 'index.html', rules[1].filename

    assert_equal 60, rules[2].offset.first
    assert_equal 102, rules[2].offset.last
    assert_equal 'index.html', rules[2].filename

    assert_equal 109, rules[3].offset.first
    assert_equal 133, rules[3].offset.last
    assert_equal 'index.html', rules[3].filename
  end

  def test_capturing_offsets_with_imports
    base_dir = Pathname.new(__dir__).join('fixtures')
    @cp.load_file!('import1.css', base_dir: base_dir, capture_offsets: true)

    rules = @cp.find_rule_sets(['div', 'a', 'body', 'p'])

    # check that we found the div rule where we expected in the primary file
    assert_equal 'div', rules[0].selectors.join
    assert_equal 31, rules[0].offset.first
    assert_equal 51, rules[0].offset.last
    assert_equal base_dir.join('import1.css').to_s, rules[0].filename

    # check that the a rule in the first import is where we expect
    assert_equal 'a', rules[1].selectors.join
    assert_equal 26, rules[1].offset.first
    assert_equal 54, rules[1].offset.last
    assert_equal base_dir.join('subdir/import2.css').to_s, rules[1].filename

    # and the body rule in the second import
    assert_equal 'body', rules[2].selectors.join
    assert_equal 0, rules[2].offset.first
    assert_equal 43, rules[2].offset.last
    assert_equal base_dir.join('simple.css').to_s, rules[2].filename

    # as well as the p rule in the second import
    assert_equal 'p', rules[3].selectors.join
    assert_equal 45, rules[3].offset.first
    assert_equal 63, rules[3].offset.last
    assert_equal base_dir.join('simple.css').to_s, rules[3].filename
  end
end
