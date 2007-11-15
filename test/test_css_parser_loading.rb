require File.dirname(__FILE__) + '/test_helper'

# Test cases for loading CSS files
class CssParserLoadingTests < Test::Unit::TestCase
  include CssParser
  def setup
    @cp = Parser.new
  end

  def test_truth
    assert true
  end
end
