require 'test/unit'
require_relative 'diff_match_patch'

class DiffTest < Test::Unit::TestCase
  def setup
    @dmp = DiffPatchMatch.new
  end

  # Diff tests

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
    diffs = [Diff.new(:equal, "\x01\x02\x01"), Diff.new(:insert, "\x02\x01\x02")]
    @dmp.diff_charsToLines(diffs, ['', "alpha\n", "beta\n"])
    assert_equal([Diff.new(:equal, "alpha\nbeta\nalpha\n"),
                  Diff.new(:insert, "beta\nalpha\nbeta\n")],
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

    diffs = [Diff.new(:delete, chars)]
    @dmp.diff_charsToLines(diffs, line_list)
    assert_equal([Diff.new(:delete, lines)], diffs)
  end

  def test_diff_cleanupMerge
    # Cleanup a messy diff.
    # Null case.
    diffs = []
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([], diffs)

    # No change case.
    diffs = [Diff.new(:equal, 'a'), Diff.new(:delete, 'b'), Diff.new(:insert, 'c')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [Diff.new(:equal, 'a'), Diff.new(:delete, 'b'), Diff.new(:insert, 'c')],
      diffs
    )

    # Merge equalities.
    diffs = [Diff.new(:equal, 'a'), Diff.new(:equal, 'b'), Diff.new(:equal, 'c')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:equal, 'abc')], diffs)

    # Merge deletions.
    diffs = [Diff.new(:delete, 'a'), Diff.new(:delete, 'b'), Diff.new(:delete, 'c')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:delete, 'abc')], diffs)

    # Merge insertions.
    diffs = [Diff.new(:insert, 'a'), Diff.new(:insert, 'b'), Diff.new(:insert, 'c')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:insert, 'abc')], diffs)

    # Merge interweave.
    diffs = [
      Diff.new(:delete, 'a'), Diff.new(:insert, 'b'), Diff.new(:delete, 'c'),
      Diff.new(:insert, 'd'), Diff.new(:equal, 'e'), Diff.new(:equal, 'f')
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [Diff.new(:delete, 'ac'), Diff.new(:insert, 'bd'), Diff.new(:equal, 'ef')],
      diffs
    )

    # Prefix and suffix detection.
    diffs = [Diff.new(:delete, 'a'), Diff.new(:insert, 'abc'), Diff.new(:delete, 'dc')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [
        Diff.new(:equal, 'a'), Diff.new(:delete, 'd'), Diff.new(:insert, 'b'),
        Diff.new(:equal, 'c')
      ],
      diffs
    )

    # Prefix and suffix detection with equalities.
    diffs = [
      Diff.new(:equal, 'x'), Diff.new(:delete, 'a'), Diff.new(:insert, 'abc'),
      Diff.new(:delete, 'dc'), Diff.new(:equal, 'y')
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal(
      [
        Diff.new(:equal, 'xa'), Diff.new(:delete, 'd'), Diff.new(:insert, 'b'),
        Diff.new(:equal, 'cy')
      ],
      diffs
    )

    # Slide edit left.
    diffs = [Diff.new(:equal, 'a'), Diff.new(:insert, 'ba'), Diff.new(:equal, 'c')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:insert, 'ab'), Diff.new(:equal, 'ac')], diffs)

    # Slide edit right.
    diffs = [Diff.new(:equal, 'c'), Diff.new(:insert, 'ab'), Diff.new(:equal, 'a')]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:equal, 'ca'), Diff.new(:insert, 'ba')], diffs)

    # Slide edit left recursive.
    diffs = [
      Diff.new(:equal, 'a'), Diff.new(:delete, 'b'), Diff.new(:equal, 'c'),
      Diff.new(:delete, 'ac'), Diff.new(:equal, 'x')
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:delete, 'abc'), Diff.new(:equal, 'acx')], diffs)

    # Slide edit right recursive.
    diffs = [
      Diff.new(:equal, 'x'), Diff.new(:delete, 'ca'), Diff.new(:equal, 'c'),
      Diff.new(:delete, 'b'), Diff.new(:equal, 'a')
    ]
    @dmp.diff_cleanupMerge(diffs)
    assert_equal([Diff.new(:equal, 'xca'), Diff.new(:delete, 'cba')], diffs)
  end

  def test_diff_cleanupSemanticLossless
    # Slide diffs to match logical boundaries.
    # Null case.
    diffs = []
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([], diffs)

    # Blank lines.
    diffs = [
      Diff.new(:equal, "AAA\r\n\r\nBBB"), Diff.new(:insert, "\r\nDDD\r\n\r\nBBB"),
      Diff.new(:equal, "\r\nEEE")
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        Diff.new(:equal, "AAA\r\n\r\n"), Diff.new(:insert, "BBB\r\nDDD\r\n\r\n"),
        Diff.new(:equal, "BBB\r\nEEE")
      ],
      diffs
    )

    # Line boundaries.
    diffs = [
      Diff.new(:equal, "AAA\r\nBBB"), Diff.new(:insert, " DDD\r\nBBB"),
      Diff.new(:equal, " EEE")
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        Diff.new(:equal, "AAA\r\n"), Diff.new(:insert, "BBB DDD\r\n"),
        Diff.new(:equal, "BBB EEE")
      ],
      diffs
    )

    # Word boundaries.
    diffs = [
      Diff.new(:equal, 'The c'), Diff.new(:insert, 'ow and the c'),
      Diff.new(:equal, 'at.')
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        Diff.new(:equal, 'The '), Diff.new(:insert, 'cow and the '),
        Diff.new(:equal, 'cat.')
      ],
      diffs
    )

    # Alphanumeric boundaries.
    diffs = [
      Diff.new(:equal, 'The-c'), Diff.new(:insert, 'ow-and-the-c'),
      Diff.new(:equal, 'at.')
    ]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal(
      [
        Diff.new(:equal, 'The-'), Diff.new(:insert, 'cow-and-the-'),
        Diff.new(:equal, 'cat.')
      ],
      diffs
    )

    # Hitting the start.
    diffs = [Diff.new(:equal, 'a'), Diff.new(:delete, 'a'), Diff.new(:equal, 'ax')]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(:delete, 'a'), Diff.new(:equal, 'aax')], diffs)

    # Hitting the end.
    diffs = [Diff.new(:equal, 'xa'), Diff.new(:delete, 'a'), Diff.new(:equal, 'a')]
    @dmp.diff_cleanupSemanticLossless(diffs)
    assert_equal([Diff.new(:equal, 'xaa'), Diff.new(:delete, 'a')], diffs)
  end


  def test_diff_cleanupSemantic
    # Cleanup semantically trivial equalities.
    # Null case.
    diffs = []
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([], diffs)

    # No elimination #1.
    diffs = [
      Diff.new(:delete, 'ab'), Diff.new(:insert, 'cd'), Diff.new(:equal, '12'),
      Diff.new(:delete, 'e')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        Diff.new(:delete, 'ab'), Diff.new(:insert, 'cd'), Diff.new(:equal, '12'),
        Diff.new(:delete, 'e')
      ],
      diffs
    )

    # No elimination #2.
    diffs = [
      Diff.new(:delete, 'abc'), Diff.new(:insert, 'ABC'), Diff.new(:equal, '1234'),
      Diff.new(:delete, 'wxyz')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        Diff.new(:delete, 'abc'), Diff.new(:insert, 'ABC'), Diff.new(:equal, '1234'),
        Diff.new(:delete, 'wxyz')
      ],
      diffs
    )

    # Simple elimination.
    diffs = [Diff.new(:delete, 'a'), Diff.new(:equal, 'b'), Diff.new(:delete, 'c')]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([Diff.new(:delete, 'abc'), Diff.new(:insert, 'b')], diffs)

    # Backpass elimination.
    diffs = [
      Diff.new(:delete, 'ab'), Diff.new(:equal, 'cd'), Diff.new(:delete, 'e'),
      Diff.new(:equal, 'f'), Diff.new(:insert, 'g')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([Diff.new(:delete, 'abcdef'), Diff.new(:insert, 'cdfg')], diffs)

    # Multiple eliminations.
    diffs = [
      Diff.new(:insert, '1'), Diff.new(:equal, 'A'), Diff.new(:delete, 'B'),
      Diff.new(:insert, '2'), Diff.new(:equal, '_'), Diff.new(:insert, '1'),
      Diff.new(:equal, 'A'), Diff.new(:delete, 'B'), Diff.new(:insert, '2')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal([Diff.new(:delete, 'AB_AB'), Diff.new(:insert, '1A2_1A2')], diffs)

    # Word boundaries.
    diffs = [
      Diff.new(:equal, 'The c'), Diff.new(:delete, 'ow and the c'),
      Diff.new(:equal, 'at.')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        Diff.new(:equal, 'The '), Diff.new(:delete, 'cow and the '),
        Diff.new(:equal, 'cat.')
      ],
      diffs
    )

    # No overlap elimination.
    # TODO: This test is in the JavaScript test suite, yet it should fail...!?
    #diffs = [Diff.new(:delete, 'abcxx'), Diff.new(:insert, 'xxdef')]
    #@dmp.diff_cleanupSemantic(diffs)
    #assert_equal([Diff.new(:delete, 'abcxx'), Diff.new(:insert, 'xxdef')], diffs)

    # Overlap elimination.
    diffs = [Diff.new(:delete, 'abcxxx'), Diff.new(:insert, 'xxxdef')]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [Diff.new(:delete, 'abc'), Diff.new(:equal, 'xxx'), Diff.new(:insert, 'def')],
      diffs
    )

    # Two overlap eliminations.
    diffs = [
      Diff.new(:delete, 'abcd1212'), Diff.new(:insert, '1212efghi'),
      Diff.new(:equal, '----'), Diff.new(:delete, 'A3'), Diff.new(:insert, '3BC')
    ]
    @dmp.diff_cleanupSemantic(diffs)
    assert_equal(
      [
        Diff.new(:delete, 'abcd'), Diff.new(:equal, '1212'), Diff.new(:insert, 'efghi'),
        Diff.new(:equal, '----'), Diff.new(:delete, 'A'), Diff.new(:equal, '3'),
        Diff.new(:insert, 'BC')
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
    diffs = [Diff.new(:delete, 'ab'), Diff.new(:insert, '12'), Diff.new(:equal, 'wxyz'), Diff.new(:delete, 'cd'), Diff.new(:insert, '34')]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(:delete, 'ab'), Diff.new(:insert, '12'), Diff.new(:equal, 'wxyz'), Diff.new(:delete, 'cd'), Diff.new(:insert, '34')], diffs)

    # Four-edit elimination.
    diffs = [Diff.new(:delete, 'ab'), Diff.new(:insert, '12'), Diff.new(:equal, 'xyz'), Diff.new(:delete, 'cd'), Diff.new(:insert, '34')]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(:delete, 'abxyzcd'), Diff.new(:insert, '12xyz34')], diffs)

    # Three-edit elimination.
    diffs = [Diff.new(:insert, '12'), Diff.new(:equal, 'x'), Diff.new(:delete, 'cd'), Diff.new(:insert, '34')]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(:delete, 'xcd'), Diff.new(:insert, '12x34')], diffs)

    # Backpass elimination.
    diffs = [Diff.new(:delete, 'ab'), Diff.new(:insert, '12'), Diff.new(:equal, 'xy'), Diff.new(:insert, '34'), Diff.new(:equal, 'z'), Diff.new(:delete, 'cd'), Diff.new(:insert, '56')]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(:delete, 'abxyzcd'), Diff.new(:insert, '12xy34z56')], diffs)

    # High cost elimination.
    @dmp.diff_editCost = 5
    diffs = [Diff.new(:delete, 'ab'), Diff.new(:insert, '12'), Diff.new(:equal, 'wxyz'), Diff.new(:delete, 'cd'), Diff.new(:insert, '34')]
    @dmp.diff_cleanupEfficiency(diffs)
    assert_equal([Diff.new(:delete, 'abwxyzcd'), Diff.new(:insert, '12wxyz34')], diffs)
    @dmp.diff_editCost = 4
  end

  def test_diff_prettyHtml
    # Pretty print.
    diffs = [Diff.new(:equal, 'a\n'), Diff.new(:delete, '<B>b</B>'), Diff.new(:insert, 'c&d')]
    assert_equal(
      '<span>a&para;<br></span><del style="background:#ffe6e6;">&lt;B&gt;b&lt;/B&gt;</del><ins style="background:#e6ffe6;">c&amp;d</ins>',
      @dmp.diff_prettyHtml(diffs)
    )
  end

  def test_diff_text
    # Compute the source and destination texts.
    diffs = [
      Diff.new(:equal, 'jump'), Diff.new(:delete, 's'), Diff.new(:insert, 'ed'),
      Diff.new(:equal, ' over '), Diff.new(:delete, 'the'), Diff.new(:insert, 'a'),
      Diff.new(:equal, ' lazy')
    ]
    assert_equal('jumps over the lazy', @dmp.diff_text1(diffs))
    assert_equal('jumped over a lazy', @dmp.diff_text2(diffs))
  end

  def test_diff_delta
    # Convert a diff into delta string.
    diffs = [
      Diff.new(:equal, 'jump'), Diff.new(:delete, 's'), Diff.new(:insert, 'ed'),
      Diff.new(:equal, ' over '), Diff.new(:delete, 'the'), Diff.new(:insert, 'a'),
      Diff.new(:equal, ' lazy'), Diff.new(:insert, 'old dog')
    ]
    text1 = @dmp.diff_text1(diffs)
    assert_equal('jumps over the lazy', text1)

    delta = @dmp.diff_toDelta(diffs)
    assert_equal("=4\t-1\t+ed\t=6\t-3\t+a\t=5\t+old dog", delta)

    # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta(text1, delta))

    # Generates error (19 != 20).
    assert_raise ArgumentError do
      @dmp.diff_fromDelta(text1 + 'x', delta)
    end

    # Generates error (19 != 18).
    assert_raise ArgumentError do
      @dmp.diff_fromDelta(text1[1..-1], delta)
    end

    # Generates error (%c3%xy invalid Unicode).
    #assert_raise ArgumentError do
    #  @dmp.diff_fromDelta('', '+%c3%xy')
    #end

    # Test deltas with special characters.
    diffs = [
      Diff.new(:equal, "\u0680 \x00 \t %"), Diff.new(:delete, "\u0681 \x01 \n ^"),
      Diff.new(:insert, "\u0682 \x02 \\ |")
    ]
    text1 = @dmp.diff_text1(diffs)
    assert_equal("\u0680 \x00 \t %\u0681 \x01 \n ^", text1)

    delta = @dmp.diff_toDelta(diffs)
    assert_equal("=7\t-7\t+%DA%82 %02 %5C %7C", delta)

    # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta(text1, delta))

    # Verify pool of unchanged characters.
    diffs = [Diff.new(:insert, "A-Z a-z 0-9 - _ . ! ~ * \' ( )  / ? : @ & = + $ , # ")]
    text2 = @dmp.diff_text2(diffs)
    assert_equal("A-Z a-z 0-9 - _ . ! ~ * \' ( )  / ? : @ & = + $ , # ", text2)

    delta = @dmp.diff_toDelta(diffs)
    assert_equal("+A-Z a-z 0-9 - _ . ! ~ * \' ( )  / ? : @ & = + $ , # ", delta)

    # Convert delta string into a diff.
    assert_equal(diffs, @dmp.diff_fromDelta('', delta))
  end

  def test_diff_xIndex
    # Translate a location in text1 to text2.
    # Translation on equality.
    diffs = [Diff.new(:delete, 'a'), Diff.new(:insert, '1234'), Diff.new(:equal, 'xyz')]
    assert_equal(5, @dmp.diff_xIndex(diffs, 2))

    # Translation on deletion.
    diffs = [Diff.new(:equal, 'a'), Diff.new(:delete, '1234'), Diff.new(:equal, 'xyz')]
    assert_equal(1, @dmp.diff_xIndex(diffs, 3))
  end

  def test_diff_levenshtein
    # Levenshtein with trailing equality.
    diffs = [Diff.new(:delete, 'abc'), Diff.new(:insert, '1234'), Diff.new(:equal, 'xyz')]
    assert_equal(4, @dmp.diff_levenshtein(diffs))
    # Levenshtein with leading equality.
    diffs = [Diff.new(:equal, 'xyz'), Diff.new(:delete, 'abc'), Diff.new(:insert, '1234')]
    assert_equal(4, @dmp.diff_levenshtein(diffs))
    # Levenshtein with middle equality.
    diffs = [Diff.new(:delete, 'abc'), Diff.new(:equal, 'xyz'), Diff.new(:insert, '1234')]
    assert_equal(7, @dmp.diff_levenshtein(diffs))
  end

  def test_diff_bisect
    # Normal.
    a = 'cat'
    b = 'map'
    # Since the resulting diff hasn't been normalized, it would be ok if
    # the insertion and deletion pairs are swapped.
    # If the order changes, tweak this test as required.
    diffs = [
      Diff.new(:delete, 'c'), Diff.new(:insert, 'm'), Diff.new(:equal, 'a'),
      Diff.new(:delete, 't'), Diff.new(:insert, 'p')
    ]
    assert_equal(diffs, @dmp.diff_bisect(a, b, nil))

    # Timeout.
    assert_equal(
      [Diff.new(:delete, 'cat'), Diff.new(:insert, 'map')],
      @dmp.diff_bisect(a, b, Time.now - 1)
    )
  end

  def test_diff_main
    # Perform a trivial diff.
    # Null case.
    assert_equal([], @dmp.diff_main('', '', false))

    # Equality.
    assert_equal([Diff.new(:equal, 'abc')], @dmp.diff_main('abc', 'abc', false))

    # Simple insertion.
    assert_equal(
      [Diff.new(:equal, 'ab'), Diff.new(:insert, '123'), Diff.new(:equal, 'c')],
      @dmp.diff_main('abc', 'ab123c', false)
    )

    # Simple deletion.
    assert_equal(
      [Diff.new(:equal, 'a'), Diff.new(:delete, '123'), Diff.new(:equal, 'bc')],
      @dmp.diff_main('a123bc', 'abc', false)
    )

    # Two insertions.
    assert_equal(
      [
        Diff.new(:equal, 'a'), Diff.new(:insert, '123'), Diff.new(:equal, 'b'),
        Diff.new(:insert, '456'), Diff.new(:equal, 'c')
      ],
      @dmp.diff_main('abc', 'a123b456c', false)
    )

    # Two deletions.
    assert_equal(
      [
        Diff.new(:equal, 'a'), Diff.new(:delete, '123'), Diff.new(:equal, 'b'),
        Diff.new(:delete, '456'), Diff.new(:equal, 'c')
      ],
      @dmp.diff_main('a123b456c', 'abc', false)
    )

    # Perform a real diff.
    # Switch off the timeout.
    @dmp.diff_timeout = 0
    # Simple cases.
    assert_equal(
      [Diff.new(:delete, 'a'), Diff.new(:insert, 'b')],
      @dmp.diff_main('a', 'b', false)
    )

    assert_equal(
      [
        Diff.new(:delete, 'Apple'), Diff.new(:insert, 'Banana'),
        Diff.new(:equal, 's are a'), Diff.new(:insert, 'lso'),
        Diff.new(:equal, ' fruit.')
      ],
      @dmp.diff_main('Apples are a fruit.', 'Bananas are also fruit.', false)
    )

    assert_equal(
      [
        Diff.new(:delete, 'a'), Diff.new(:insert, "\u0680"), Diff.new(:equal, 'x'),
        Diff.new(:delete, "\t"), Diff.new(:insert, "\0")
      ],
      @dmp.diff_main("ax\t", "\u0680x\0", false)
    )

    # Overlaps.
    assert_equal(
      [
        Diff.new(:delete, '1'), Diff.new(:equal, 'a'), Diff.new(:delete, 'y'),
        Diff.new(:equal, 'b'), Diff.new(:delete, '2'), Diff.new(:insert, 'xab')
      ],
      @dmp.diff_main('1ayb2', 'abxab', false)
    )

    assert_equal(
      [Diff.new(:insert, 'xaxcx'), Diff.new(:equal, 'abc'), Diff.new(:delete, 'y')],
      @dmp.diff_main('abcy', 'xaxcxabc', false)
    )

    assert_equal(
      [
        Diff.new(:delete, 'ABCD'), Diff.new(:equal, 'a'), Diff.new(:delete, '='),
        Diff.new(:insert, '-'), Diff.new(:equal, 'bcd'), Diff.new(:delete, '='),
        Diff.new(:insert, '-'), Diff.new(:equal, 'efghijklmnopqrs'),
        Diff.new(:delete, 'EFGHIJKLMNOefg')
      ],
      @dmp.diff_main(
        'ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg',
        'a-bcd-efghijklmnopqrs',
        false
      )
    )

    # Large equality.
    assert_equal(
      [
        Diff.new(:insert, ' '), Diff.new(:equal, 'a'), Diff.new(:insert, 'nd'),
        Diff.new(:equal, ' [[Pennsylvania]]'), Diff.new(:delete, ' and [[New')
      ],
      @dmp.diff_main(
        'a [[Pennsylvania]] and [[New', ' and [[Pennsylvania]]', false
      )
    )

    # Timeout.
    @dmp.diff_timeout = 0.1;  # 100ms
    a = "`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n"
    b = "I am the very model of a modern major general,\nI\'ve information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n"
    # Increase the text lengths by 1024 times to ensure a timeout.
    a = a * 1024
    b = b * 1024
    start_time = Time.now
    @dmp.diff_main(a, b)
    end_time = Time.now
    # Test that we took at least the timeout period.
    assert(@dmp.diff_timeout <= end_time - start_time, "not timed out")
    # Test that we didn't take forever (be forgiving).
    # Theoretically this test could fail very occasionally if the
    # OS task swaps or locks up for a second at the wrong moment.
    assert(@dmp.diff_timeout * 1000 * 2 > end_time - start_time, "took too long")
    @dmp.diff_timeout = 0

    # Test the linemode speedup.
    # Must be long to pass the 100 char cutoff.
    # Simple line-mode.
    a = "1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n"
    b = "abcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\nabcdefghij\n"
    assert_equal(@dmp.diff_main(a, b, false), @dmp.diff_main(a, b, true))

    # Single line-mode.
    a = '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'
    b = 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij'
    assert_equal(@dmp.diff_main(a, b, false), @dmp.diff_main(a, b, true))

    # Overlap line-mode.
    a = "1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n1234567890\n"
    b = "abcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n1234567890\n1234567890\n1234567890\nabcdefghij\n"

    diffs_linemode = @dmp.diff_main(a, b, true)
    diffs_textmode = @dmp.diff_main(a, b, false)
    assert_equal(@dmp.diff_text1(diffs_linemode), @dmp.diff_text1(diffs_textmode))
    assert_equal(@dmp.diff_text2(diffs_linemode), @dmp.diff_text2(diffs_textmode))

    # Test null inputs.
    assert_raise ArgumentError do
      @dmp.diff_main(nil, nil)
    end
  end

  # Match tests

  def test_match_alphabet
    # Initialise the bitmasks for Bitap.
    # Unique.
    assert_equal({'a'=>4, 'b'=>2, 'c'=>1}, @dmp.match_alphabet('abc'))

    # Duplicates.
    assert_equal({'a'=>37, 'b'=>18, 'c'=>8}, @dmp.match_alphabet('abcaba'))
  end

end
