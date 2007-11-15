require File.dirname(__FILE__) + '/test_helper'

# Test cases for the CssParser's downloading functions.
class CssParserDownloadingTests < Test::Unit::TestCase
  include CssParser
  include WEBrick

  def setup
    # from http://nullref.se/blog/2006/5/17/testing-with-webrick
    @cp = Parser.new
    @uri_base = 'http://localhost:12000'
    www_root = File.dirname(__FILE__) + '/fixtures/'

    @server_thread = Thread.new do
      s = WEBrick::HTTPServer.new(:Port => 12000, :DocumentRoot => www_root, :Logger => Log.new(nil, BasicLog::WARN), :AccessLog => [])
      @port = s.config[:Port]
      begin
        s.start
      ensure
        s.shutdown
      end
    end
    sleep 1 # ensure the server has time to load
  end

  def teardown
    @server_thread.kill
    @server_thread.join(5)
    @server_thread = nil
  end

  def test_loading_a_remote_file
    @cp.load_file!("#{@uri_base}/simple.css")
    assert_equal 'margin: 0px;', @cp.find('p').join(' ')
  end

  def test_following_at_import_rules
    @cp.load_file!("#{@uri_base}/import1.css")

    # from '/import1.css'
    assert_equal 'color: lime;', @cp.find('div').join(' ')

    # from '/subdir/import2.css'
    assert_equal 'text-decoration: none;', @cp.find('a').join(' ')
    
    # from '/subdir/../simple.css'
    assert_equal 'margin: 0px;', @cp.find('p').join(' ')
  end

  def test_importing_with_media_types
    @cp.load_file!("#{@uri_base}/import-with-media-types.css")
    
    # from simple.css with :screen media type
    assert_equal 'margin: 0px;', @cp.find('p', :screen).join(' ')
    assert_equal '', @cp.find('p', :tty).join(' ')
  end

  def test_throwing_circular_reference_exception
    assert_raise RuntimeError do
      @cp.load_file!("#{@uri_base}/import-circular-reference.css")
    end
  end

end
