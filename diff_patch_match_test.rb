require 'test/unit'
require_relative 'diff_patch_match'

class DiffTest < Test::Unit::TestCase
  def setup
    @dmp = DiffPatchMatch.new
  end

  def test_diff_commonPrefix
    # Detect any common prefix.
    # Null case.
    assert_equal(0, @dmp.diff_commonPrefix('abc', 'xyz'))

    # Non-null case.
    assert_equal(4, @dmp.diff_commonPrefix('1234abcdef', '1234xyz'))

    # Whole case.
    assert_equal(4, @dmp.diff_commonPrefix('1234', '1234xyz'))
  end

  def test_diff_commonSuffix
    # Detect any common suffix.
    # Null case.
    assert_equal(0, @dmp.diff_commonSuffix('abc', 'xyz'))

    # Non-null case.
    assert_equal(4, @dmp.diff_commonSuffix('abcdef1234', 'xyz1234'))

    # Whole case.
    assert_equal(4, @dmp.diff_commonSuffix('1234', 'xyz1234'))
  end

  def test_diff_commonOverlap
    # Detect any suffix/prefix overlap.
    # Null case.
    assert_equal(0, @dmp.diff_commonOverlap('', 'abcd'))

    # Whole case.
    assert_equal(3, @dmp.diff_commonOverlap('abc', 'abcd'))

    # No overlap.
    assert_equal(0, @dmp.diff_commonOverlap('123456', 'abcd'))

    # Overlap.
    assert_equal(3, @dmp.diff_commonOverlap('123456xxx', 'xxxabcd'))
  end

  def test_diff_halfMatch
    # Detect a halfmatch.
    @dmp.diff_timeout = 1
    # No match.
    assert_equal(nil, @dmp.diff_halfMatch('1234567890', 'abcdef'))

    assert_equal(nil, @dmp.diff_halfMatch('12345', '23'))

    # Single Match.
    assert_equal(['12', '90', 'a', 'z', '345678'],
                 @dmp.diff_halfMatch('1234567890', 'a345678z'))

    assert_equal(['a', 'z', '12', '90', '345678'],
                 @dmp.diff_halfMatch('a345678z', '1234567890'))

    assert_equal(['abc', 'z', '1234', '0', '56789'],
                 @dmp.diff_halfMatch('abc56789z', '1234567890'))

    assert_equal(['a', 'xyz', '1', '7890', '23456'],
                 @dmp.diff_halfMatch('a23456xyz', '1234567890'))

    # Multiple Matches.
    assert_equal(['12123', '123121', 'a', 'z', '1234123451234'],
                 @dmp.diff_halfMatch('121231234123451234123121', 'a1234123451234z'))

    assert_equal(['', '-=-=-=-=-=', 'x', '', 'x-=-=-=-=-=-=-='],
                 @dmp.diff_halfMatch('x-=-=-=-=-=-=-=-=-=-=-=-=', 'xx-=-=-=-=-=-=-='))

    assert_equal(['-=-=-=-=-=', '', '', 'y', '-=-=-=-=-=-=-=y'],
                 @dmp.diff_halfMatch('-=-=-=-=-=-=-=-=-=-=-=-=y', '-=-=-=-=-=-=-=yy'))

    # Non-optimal halfmatch.
    # Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
    assert_equal(['qHillo', 'w', 'x', 'Hulloy', 'HelloHe'],
                 @dmp.diff_halfMatch('qHilloHelloHew', 'xHelloHeHulloy'))

    # Optimal no halfmatch.
    @dmp.diff_timeout = 0
    assert_equal(nil, @dmp.diff_halfMatch('qHilloHelloHew', 'xHelloHeHulloy'))
  end

  def test_diff_linesToChars
    # Convert lines down to characters.
    assert_equal(["\x01\x02\x01", "\x02\x01\x02", ['', "alpha\n", "beta\n"]],
                 @dmp.diff_linesToChars("alpha\nbeta\nalpha\n", "beta\nalpha\nbeta\n"))

    assert_equal(['', "\x01\x02\x03\x03", ['', "alpha\r\n", "beta\r\n", "\r\n"]],
                 @dmp.diff_linesToChars('', "alpha\r\nbeta\r\n\r\n\r\n"))

    assert_equal(["\x01", "\x02", ['', 'a', 'b']], @dmp.diff_linesToChars('a', 'b'))

    # More than 256 to reveal any 8-bit limitations.
    n = 300
    line_list = (1..n).map {|x| x.to_s + "\n" }
    char_list = (1..n).map {|x| x.chr(Encoding::UTF_8) }
    assert_equal(n, line_list.length)
    lines = line_list.join
    chars = char_list.join
    assert_equal(n, chars.length)
    line_list.unshift('')
    assert_equal([chars, '', line_list], @dmp.diff_linesToChars(lines, ''))
  end

  def test_diff_charsToLines
    # Convert chars up to lines.
    diffs = [[:diff_equal, "\x01\x02\x01"], [:diff_insert, "\x02\x01\x02"]]
    @dmp.diff_charsToLines(diffs, ['', "alpha\n", "beta\n"])
    assert_equal([[:diff_equal, "alpha\nbeta\nalpha\n"],
                  [:diff_insert, "beta\nalpha\nbeta\n"]],
                 diffs)
    # More than 256 to reveal any 8-bit limitations.
    n = 300
    line_list = (1..n).map {|x| x.to_s + "\n" }
    char_list = (1..n).map {|x| x.chr(Encoding::UTF_8) }
    assert_equal(n, line_list.length)
    lines = line_list.join
    chars = char_list.join
    assert_equal(n, chars.length)
    line_list.unshift('')

    diffs = [[:diff_delete, chars]]
    @dmp.diff_charsToLines(diffs, line_list)
    assert_equal([[:diff_delete, lines]], diffs)
  end

  def test_diff_cleanupMerge
    # Cleanup a messy diff.
    # Null case.
    diffs = []
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([], diffs)

    # No change case.
    diffs = [[:diff_equal, 'a'], [:diff_delete, 'b'], [:diff_insert, 'c']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [[:diff_equal, 'a'], [:diff_delete, 'b'], [:diff_insert, 'c']],
      diffs
    )

    # Merge equalities.
    diffs = [[:diff_equal, 'a'], [:diff_equal, 'b'], [:diff_equal, 'c']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_equal, 'abc']], diffs)

    # Merge deletions.
    diffs = [[:diff_delete, 'a'], [:diff_delete, 'b'], [:diff_delete, 'c']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_delete, 'abc']], diffs)

    # Merge insertions.
    diffs = [[:diff_insert, 'a'], [:diff_insert, 'b'], [:diff_insert, 'c']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_insert, 'abc']], diffs)

    # Merge interweave.
    diffs = [
      [:diff_delete, 'a'], [:diff_insert, 'b'], [:diff_delete, 'c'],
      [:diff_insert, 'd'], [:diff_equal, 'e'], [:diff_equal, 'f']
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [[:diff_delete, 'ac'], [:diff_insert, 'bd'], [:diff_equal, 'ef']],
      diffs
    )

    # Prefix and suffix detection.
    diffs = [[:diff_delete, 'a'], [:diff_insert, 'abc'], [:diff_delete, 'dc']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [
        [:diff_equal, 'a'], [:diff_delete, 'd'], [:diff_insert, 'b'],
        [:diff_equal, 'c']
      ],
      diffs
    )

    # Prefix and suffix detection with equalities.
    diffs = [
      [:diff_equal, 'x'], [:diff_delete, 'a'], [:diff_insert, 'abc'],
      [:diff_delete, 'dc'], [:diff_equal, 'y']
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [
        [:diff_equal, 'xa'], [:diff_delete, 'd'], [:diff_insert, 'b'],
        [:diff_equal, 'cy']
      ],
      diffs
    )

    # Slide edit left.
    diffs = [[:diff_equal, 'a'], [:diff_insert, 'ba'], [:diff_equal, 'c']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_insert, 'ab'], [:diff_equal, 'ac']], diffs)

    # Slide edit right.
    diffs = [[:diff_equal, 'c'], [:diff_insert, 'ab'], [:diff_equal, 'a']]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_equal, 'ca'], [:diff_insert, 'ba']], diffs)

    # Slide edit left recursive.
    diffs = [
      [:diff_equal, 'a'], [:diff_delete, 'b'], [:diff_equal, 'c'],
      [:diff_delete, 'ac'], [:diff_equal, 'x']
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_delete, 'abc'], [:diff_equal, 'acx']], diffs)

    # Slide edit right recursive.
    diffs = [
      [:diff_equal, 'x'], [:diff_delete, 'ca'], [:diff_equal, 'c'],
      [:diff_delete, 'b'], [:diff_equal, 'a']
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([[:diff_equal, 'xca'], [:diff_delete, 'cba']], diffs)
  end

  def test_diff_cleanupSemanticLossless
    # Slide diffs to match logical boundaries.
    # Null case.
    diffs = []
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([], diffs)

    # Blank lines.
    diffs = [
      [:diff_equal, "AAA\r\n\r\nBBB"], [:diff_insert, "\r\nDDD\r\n\r\nBBB"],
      [:diff_equal, "\r\nEEE"]
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        [:diff_equal, "AAA\r\n\r\n"], [:diff_insert, "BBB\r\nDDD\r\n\r\n"],
        [:diff_equal, "BBB\r\nEEE"]
      ],
      diffs
    )

    # Line boundaries.
    diffs = [
      [:diff_equal, "AAA\r\nBBB"], [:diff_insert, " DDD\r\nBBB"],
      [:diff_equal, " EEE"]
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        [:diff_equal, "AAA\r\n"], [:diff_insert, "BBB DDD\r\n"],
        [:diff_equal, "BBB EEE"]
      ],
      diffs
    )

    # Word boundaries.
    diffs = [
      [:diff_equal, 'The c'], [:diff_insert, 'ow and the c'],
      [:diff_equal, 'at.']
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        [:diff_equal, 'The '], [:diff_insert, 'cow and the '],
        [:diff_equal, 'cat.']
      ],
      diffs
    )

    # Alphanumeric boundaries.
    diffs = [
      [:diff_equal, 'The-c'], [:diff_insert, 'ow-and-the-c'],
      [:diff_equal, 'at.']
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        [:diff_equal, 'The-'], [:diff_insert, 'cow-and-the-'],
        [:diff_equal, 'cat.']
      ],
      diffs
    )

    # Hitting the start.
    diffs = [[:diff_equal, 'a'], [:diff_delete, 'a'], [:diff_equal, 'ax']]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([[:diff_delete, 'a'], [:diff_equal, 'aax']], diffs)

    # Hitting the end.
    diffs = [[:diff_equal, 'xa'], [:diff_delete, 'a'], [:diff_equal, 'a']]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([[:diff_equal, 'xaa'], [:diff_delete, 'a']], diffs)
  end


  def test_diff_cleanupSemantic
    # Cleanup semantically trivial equalities.
    # Null case.
    diffs = []
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([], diffs)

    # No elimination #1.
    diffs = [
      [:diff_delete, 'ab'], [:diff_insert, 'cd'], [:diff_equal, '12'],
      [:diff_delete, 'e']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        [:diff_delete, 'ab'], [:diff_insert, 'cd'], [:diff_equal, '12'],
        [:diff_delete, 'e']
      ],
      diffs
    )

    # No elimination #2.
    diffs = [
      [:diff_delete, 'abc'], [:diff_insert, 'ABC'], [:diff_equal, '1234'],
      [:diff_delete, 'wxyz']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        [:diff_delete, 'abc'], [:diff_insert, 'ABC'], [:diff_equal, '1234'],
        [:diff_delete, 'wxyz']
      ],
      diffs
    )

    # Simple elimination.
    diffs = [[:diff_delete, 'a'], [:diff_equal, 'b'], [:diff_delete, 'c']]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([[:diff_delete, 'abc'], [:diff_insert, 'b']], diffs)

    # Backpass elimination.
    diffs = [
      [:diff_delete, 'ab'], [:diff_equal, 'cd'], [:diff_delete, 'e'],
      [:diff_equal, 'f'], [:diff_insert, 'g']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([[:diff_delete, 'abcdef'], [:diff_insert, 'cdfg']], diffs)

    # Multiple eliminations.
    diffs = [
      [:diff_insert, '1'], [:diff_equal, 'A'], [:diff_delete, 'B'],
      [:diff_insert, '2'], [:diff_equal, '_'], [:diff_insert, '1'],
      [:diff_equal, 'A'], [:diff_delete, 'B'], [:diff_insert, '2']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([[:diff_delete, 'AB_AB'], [:diff_insert, '1A2_1A2']], diffs)

    # Word boundaries.
    diffs = [
      [:diff_equal, 'The c'], [:diff_delete, 'ow and the c'],
      [:diff_equal, 'at.']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        [:diff_equal, 'The '], [:diff_delete, 'cow and the '],
        [:diff_equal, 'cat.']
      ],
      diffs
    )

    # No overlap elimination.
    # TODO: This test is in the JavaScript test suite, yet it should fail...!?
    #diffs = [[:diff_delete, 'abcxx'], [:diff_insert, 'xxdef']]
    #@dmp.diff_cleanupSemantic(diffs)
    #assert_equal([[:diff_delete, 'abcxx'], [:diff_insert, 'xxdef']], diffs)

    # Overlap elimination.
    diffs = [[:diff_delete, 'abcxxx'], [:diff_insert, 'xxxdef']]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [[:diff_delete, 'abc'], [:diff_equal, 'xxx'], [:diff_insert, 'def']],
      diffs
    )

    # Two overlap eliminations.
    diffs = [
      [:diff_delete, 'abcd1212'], [:diff_insert, '1212efghi'],
      [:diff_equal, '----'], [:diff_delete, 'A3'], [:diff_insert, '3BC']
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        [:diff_delete, 'abcd'], [:diff_equal, '1212'], [:diff_insert, 'efghi'],
        [:diff_equal, '----'], [:diff_delete, 'A'], [:diff_equal, '3'],
        [:diff_insert, 'BC']
      ],
      diffs
    )
  end

  def test_diff_cleanupEfficiency
    # Cleanup operationally trivial equalities.
    @dmp.diff_editCost = 4
    # Null case.
    diffs = []
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([], diffs)

    # No elimination.
    diffs = [[:diff_delete, 'ab'], [:diff_insert, '12'], [:diff_equal, 'wxyz'], [:diff_delete, 'cd'], [:diff_insert, '34']]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([[:diff_delete, 'ab'], [:diff_insert, '12'], [:diff_equal, 'wxyz'], [:diff_delete, 'cd'], [:diff_insert, '34']], diffs)

    # Four-edit elimination.
    diffs = [[:diff_delete, 'ab'], [:diff_insert, '12'], [:diff_equal, 'xyz'], [:diff_delete, 'cd'], [:diff_insert, '34']]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([[:diff_delete, 'abxyzcd'], [:diff_insert, '12xyz34']], diffs)

    # Three-edit elimination.
    diffs = [[:diff_insert, '12'], [:diff_equal, 'x'], [:diff_delete, 'cd'], [:diff_insert, '34']]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([[:diff_delete, 'xcd'], [:diff_insert, '12x34']], diffs)

    # Backpass elimination.
    diffs = [[:diff_delete, 'ab'], [:diff_insert, '12'], [:diff_equal, 'xy'], [:diff_insert, '34'], [:diff_equal, 'z'], [:diff_delete, 'cd'], [:diff_insert, '56']]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([[:diff_delete, 'abxyzcd'], [:diff_insert, '12xy34z56']], diffs)

    # High cost elimination.
    @dmp.diff_editCost = 5
    diffs = [[:diff_delete, 'ab'], [:diff_insert, '12'], [:diff_equal, 'wxyz'], [:diff_delete, 'cd'], [:diff_insert, '34']]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([[:diff_delete, 'abwxyzcd'], [:diff_insert, '12wxyz34']], diffs)
    @dmp.diff_editCost = 4
  end

end
