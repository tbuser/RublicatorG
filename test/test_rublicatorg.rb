require 'test/unit'
require 'rublicatorg'

class RublicatorgTest < Test::Unit::TestCase
  def test_derp
    # uhm, I need like a mock makerbot to do automated tests?
    assert_equal 0xd5, RublicatorG::START_BYTE
  end
end