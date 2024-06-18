# frozen_string_literal: true

require_relative 'test_helper'

# Test cases for the CssParser's loading functions.
class CssParserLoadingTests < Minitest::Test
  include CssParser

  def setup
    @cp = Document.new
    @uri_base = 'http://localhost:12000'
  end

  def stub_request_file(file)
    stub_request(:get, "http://localhost:12000/#{file}")
      .to_return(status: 200, body: fixture(file), headers: {})
  end

  # Moved Permanently
  def test_loading_301_redirect
    stub_request_file("simple.css")
    stub_request(:get, "http://localhost:12000/redirect301")
      .to_return(
        status: 301, body: "",
        headers: {"Location" => 'http://localhost:12000/simple.css'}
      )

    @cp.load_uri!("#{@uri_base}/redirect301")
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  # Temporary Redirect
  def test_loading_307_redirect
    stub_request_file("simple.css")
    stub_request(:get, "http://localhost:12000/redirect307")
      .to_return(
        status: 307, body: "",
        headers: {"Location" => 'http://localhost:12000/simple.css'}
      )

    @cp.load_uri!("#{@uri_base}/redirect307")
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_loading_a_local_file
    file_name = File.expand_path('fixtures/simple.css', __dir__)
    @cp.load_file!(file_name)
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_loading_a_local_file_with_scheme
    file_name = "file://#{__dir__}/fixtures/simple.css"
    @cp.load_uri!(file_name)
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_loading_a_remote_file
    stub_request_file("simple.css")

    @cp.load_uri!("#{@uri_base}/simple.css")
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  # http://github.com/premailer/css_parser/issues#issue/4
  def test_loading_a_remote_file_over_ssl
    stub_request(:get, "https://dialect.ca/inc/screen.css")
      .to_return(status: 200, body: +"body{margin:0}")

    @cp.load_uri!("https://dialect.ca/inc/screen.css")
    assert_includes(@cp.find_by_selector('body').join(' '), "margin: 0;")
  end

  def test_loading_a_string
    @cp.load_string!("p{margin:0px}")
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_following_at_import_rules_local
    base_dir = File.expand_path('fixtures', __dir__)
    @cp.load_file!('import1.css', base_dir: base_dir)

    # from '/import1.css'
    assert_equal 'color: lime;', @cp.find_by_selector('div').join(' ')

    # from '/subdir/import2.css'
    assert_equal 'text-decoration: none;', @cp.find_by_selector('a').join(' ')

    # from '/subdir/../simple.css'
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_following_at_import_rules_remote
    stub_request_file("import1.css")
    stub_request_file("subdir/import2.css")
    stub_request_file("subdir/../simple.css")

    @cp.load_uri!("#{@uri_base}/import1.css")

    # from '/import1.css'
    assert_equal 'color: lime;', @cp.find_by_selector('div').join(' ')

    # from '/subdir/import2.css'
    assert_equal 'text-decoration: none;', @cp.find_by_selector('a').join(' ')

    # from '/subdir/../simple.css'
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_imports_disabled
    stub_request_file("import1.css")

    cp = Document.new(import: false)
    cp.load_uri!("#{@uri_base}/import1.css")

    # from '/import1.css'
    assert_equal 'color: lime;', cp.find_by_selector('div').join(' ')

    # from '/subdir/import2.css'
    assert_equal '', cp.find_by_selector('a').join(' ')

    # from '/subdir/../simple.css'
    assert_equal '', cp.find_by_selector('p').join(' ')
  end

  def test_following_remote_import_rules
    stub_request(:get, "http://example.com/css")
      .to_return(status: 500, body: "", headers: {})

    css_block = '@import "http://example.com/css";'

    assert_raises HTTPReadURL::RemoteFileError do
      @cp.add_block!(css_block, base_uri: "#{@uri_base}/subdir/")
    end
  end

  def test_following_badly_escaped_import_rules
    stub_request(:get, "http://example.com/css?family=Droid%20Sans:regular,bold%7CDroid%20Serif:regular,italic,bold,bolditalic&subset=latin")
      .to_return(status: 500, body: "", headers: {})

    css_block = '@import "http://example.com/css?family=Droid+Sans:regular,bold|Droid+Serif:regular,italic,bold,bolditalic&subset=latin";'

    assert_raises HTTPReadURL::RemoteFileError do
      @cp.add_block!(css_block, base_uri: "#{@uri_base}/subdir/")
    end
  end

  def test_loading_malformed_content_strings
    file_name = File.expand_path('fixtures/import-malformed.css', __dir__)
    @cp.load_file!(file_name)
    @cp.each_selector do |_sel, dec, _spec|
      assert_nil dec =~ /wellformed/
    end
  end

  def test_loading_malformed_css_brackets
    file_name = File.expand_path('fixtures/import-malformed.css', __dir__)
    @cp.load_file!(file_name)
    selector_count = 0
    @cp.each_selector do |_sel, _dec, _spec|
      selector_count += 1
    end

    assert_equal 8, selector_count
  end

  def test_following_at_import_rules_from_add_block
    stub_request_file("subdir/../simple.css")

    css_block = '@import "../simple.css";'

    @cp.add_block!(css_block, base_uri: "#{@uri_base}/subdir/")

    # from 'simple.css'
    assert_equal 'margin: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_importing_with_media_types
    stub_request_file("simple.css")
    stub_request_file("import-with-media-types.css")

    @cp.load_uri!("#{@uri_base}/import-with-media-types.css")

    # from simple.css with screen media type
    assert_equal 'margin: 0px;', @cp.find_by_selector('p', "screen").join(' ')
    assert_equal '', @cp.find_by_selector('p', "tty").join(' ')
  end

  def test_local_circular_reference_exception
    assert_raises FileResource::CircularReferenceError do
      @cp.load_file!(File.expand_path('fixtures/import-circular-reference.css', __dir__))
    end
  end

  def test_remote_circular_reference_exception
    stub_request_file("import-circular-reference.css")

    assert_raises HTTPReadURL::CircularReferenceError do
      @cp.load_uri!("#{@uri_base}/import-circular-reference.css")
    end
  end

  def test_suppressing_circular_reference_exceptions
    stub_request_file("import-circular-reference.css")

    cp_without_exceptions = Document.new(io_exceptions: false)

    cp_without_exceptions.load_uri!("#{@uri_base}/import-circular-reference.css")
  end

  def test_toggling_not_found_exceptions
    stub_request(:get, "http://localhost:12000/no-exist.xyz")
      .to_return(status: 404, body: "", headers: {})

    cp_with_exceptions = Document.new(io_exceptions: true)

    err = assert_raises HTTPReadURL::RemoteFileError do
      cp_with_exceptions.load_uri!("#{@uri_base}/no-exist.xyz")
    end

    assert_includes err.message, "#{@uri_base}/no-exist.xyz"

    cp_without_exceptions = Document.new(io_exceptions: false)

    cp_without_exceptions.load_uri!("#{@uri_base}/no-exist.xyz")
  end
end
