require 'test/unit'
require_relative 'diff_patch_match'

class DiffTest < Test::Unit::TestCase
  def setup
    @dmp = DiffPatchMatch.new
  end

  def test_diff_commonPrefix
    # Detect any common prefix
    # Null case.
    assert_equal(0, @dmp.diff_commonPrefix('abc', 'xyz'))

    # Non-null case.
    assert_equal(4, @dmp.diff_commonPrefix('1234abcdef', '1234xyz'))

    # Whole case.
    assert_equal(4, @dmp.diff_commonPrefix('1234', '1234xyz'))
  end
end
