# frozen_string_literal: true

require_relative 'test_helper'

# Tests for `Parser#load_uri!`'s `:integrity` option, which verifies a
# fetched remote stylesheet against a Subresource Integrity value
# (https://www.w3.org/TR/SRI/) before it is parsed -- the same mechanism
# an HTML `<link integrity="...">` attribute describes.
class CssParserIntegrityTests < Minitest::Test
  include CssParser
  include WEBrick

  PORT = 12_011

  def setup
    @www_root = File.expand_path('fixtures', __dir__)
    @fixture_file = File.expand_path('fixtures/simple.css', __dir__)
    @fixture_body = File.binread(@fixture_file)
    @uri_base = "http://127.0.0.1:#{PORT}"

    # `:integrity` verification only applies on the remote-fetch path, so
    # these tests use `allow_local_network: true` against a loopback
    # fixture server rather than mocking the HTTP layer -- matching the
    # approach `test_allow_local_network_opt_in_permits_loopback` uses in
    # test_css_parser_ssrf.rb.
    @server_thread = Thread.new do
      s = WEBrick::HTTPServer.new(
        Port: PORT, BindAddress: '127.0.0.1', DocumentRoot: @www_root,
        Logger: Log.new(nil, BasicLog::FATAL), AccessLog: []
      )
      begin
        s.start
      ensure
        s.shutdown
      end
    end

    sleep 1
  end

  def teardown
    @server_thread.kill
    @server_thread.join(5)
    @server_thread = nil
  end

  def cp
    Parser.new(allow_local_network: true)
  end

  def sha(algorithm, body = @fixture_body)
    digest_class = {'sha256' => Digest::SHA256, 'sha384' => Digest::SHA384, 'sha512' => Digest::SHA512}.fetch(algorithm)
    "#{algorithm}-#{Base64.strict_encode64(digest_class.digest(body))}"
  end

  def test_load_uri_without_integrity_option_is_unaffected
    cp.load_uri!("#{@uri_base}/simple.css")
    # no-op: reaching here without an exception is the assertion.
  end

  def test_matching_sha384_integrity_loads_normally
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: sha('sha384'))
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_matching_sha256_integrity_loads_normally
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: sha('sha256'))
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_matching_sha512_integrity_loads_normally
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: sha('sha512'))
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_mismatched_integrity_is_refused
    tampered = "#{sha('sha384')[0, 15]}not-the-real-digest-at-all=="
    assert_raises(CssParser::IntegrityError) do
      cp.load_uri!("#{@uri_base}/simple.css", integrity: tampered)
    end
  end

  def test_mismatched_integrity_raises_a_subclass_of_remote_file_error
    # CssParser::IntegrityError must remain catchable by existing
    # `rescue RemoteFileError` callers.
    tampered = "#{sha('sha384')[0, 15]}not-the-real-digest-at-all=="
    assert_raises(CssParser::RemoteFileError) do
      cp.load_uri!("#{@uri_base}/simple.css", integrity: tampered)
    end
  end

  def test_mismatched_integrity_without_io_exceptions_loads_nothing
    parser = Parser.new(allow_local_network: true, io_exceptions: false)
    tampered = "#{sha('sha384')[0, 15]}not-the-real-digest-at-all=="
    parser.load_uri!("#{@uri_base}/simple.css", integrity: tampered)
    assert_empty parser.find_by_selector('p')
  end

  def test_strongest_algorithm_wins_when_multiple_present_and_it_fails
    # A correct sha256 paired with a wrong sha512 must fail -- the spec's
    # "agility" rule means only the strongest present algorithm (sha512
    # here) is authoritative, so a right-but-weaker value must not mask
    # a wrong-but-stronger one.
    value = "#{sha('sha256')} sha512-#{Base64.strict_encode64('not the real digest')}"
    assert_raises(CssParser::IntegrityError) do
      cp.load_uri!("#{@uri_base}/simple.css", integrity: value)
    end
  end

  def test_strongest_algorithm_wins_when_multiple_present_and_it_passes
    # Mirror of the above: a wrong sha256 paired with a correct sha512
    # must still pass, since sha512 is the one actually checked.
    wrong_sha256 = "sha256-#{Base64.strict_encode64('not the real digest')}"
    value = "#{wrong_sha256} #{sha('sha512')}"
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: value)
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_multiple_values_for_the_same_algorithm_accepts_any_match
    # The spec allows several acceptable digests for the same algorithm
    # (e.g. during a stylesheet rotation) -- any match should pass.
    other_value = "sha384-#{Base64.strict_encode64('some other build of the file')}"
    value = "#{other_value} #{sha('sha384')}"
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: value)
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_unrecognized_algorithm_only_value_is_unverifiable_and_passes
    # md5 is not in INTEGRITY_ALGORITHMS. A value naming only an
    # unsupported algorithm can't be checked either way, so it's treated
    # as unverifiable rather than failing every such fetch.
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: 'md5-deadbeef==')
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end

  def test_blank_integrity_option_is_unaffected
    parser = cp
    parser.load_uri!("#{@uri_base}/simple.css", integrity: '')
    assert_equal 'margin: 0px;', parser.find_by_selector('p').join(' ')
  end
end
