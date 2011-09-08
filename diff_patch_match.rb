require 'abbrev'

class DiffPatchMatch
  attr_accessor :diff_timeout

  def initialize
    # Defaults.
    # Redefine these in your program to override the defaults.

    # Number of seconds to map a diff before giving up (0 for infinity).
    @diff_timeout = 1
  end

  # Determine the common prefix of two strings.
  def diff_commonPrefix(text1, text2)
    # Quick check for common null cases.
    return 0 if text1.empty? || text2.empty? || text1[0] != text2[0]

    # Binary search.
    pointer_min = 0
    pointer_max = [text1.length, text2.length].min
    pointer_mid = pointer_max
    pointer_start = 0
    while pointer_min < pointer_mid
      if text1[pointer_start...pointer_mid] == text2[pointer_start...pointer_mid]
        pointer_min = pointer_mid
        pointer_start = pointer_min
      else
        pointer_max = pointer_mid
      end
      pointer_mid = (pointer_max - pointer_min) / 2 + pointer_min
    end

    return pointer_mid
  end

  # Determine the common prefix of two strings.
  def diff_commonPrefix(text1, text2)
    # Quick check for common null cases.
    return 0 if text1.empty? || text2.empty? || text1[0] != text2[0]

    # Binary search.
    # Performance analysis: http://neil.fraser.name/news/2007/10/09/
    pointer_min = 0
    pointer_max = [text1.length, text2.length].min
    pointer_mid = pointer_max
    pointer_start = 0
    while pointer_min < pointer_mid
      if text1[pointer_start...pointer_mid] ==
         text2[pointer_start...pointer_mid]
        pointer_min = pointer_mid
        pointer_start = pointer_min
      else
        pointer_max = pointer_mid
      end
      pointer_mid = (pointer_max - pointer_min) / 2 + pointer_min
    end

    return pointer_mid
  end

  # Determine the common suffix of two strings.
  def diff_commonSuffix(text1, text2)
    # Quick check for common null cases.
    return 0 if text1.empty? || text2.empty? || text1[-1] != text2[-1]

    # Binary search.
    # Performance analysis: http://neil.fraser.name/news/2007/10/09/
    pointer_min = 0
    pointer_max = [text1.length, text2.length].min
    pointer_mid = pointer_max
    pointer_end = 0
    while pointer_min < pointer_mid
      if text1[-pointer_mid..(-pointer_end-1)] ==
         text2[-pointer_mid..(-pointer_end-1)]
        pointer_min = pointer_mid
        pointer_end = pointer_min
      else
        pointer_max = pointer_mid
      end
      pointer_mid = (pointer_max - pointer_min) / 2 + pointer_min
    end

    return pointer_mid
  end

  # Determine if the suffix of one string is the prefix of another.
  def diff_commonOverlap(text1, text2)
    # Cache the text lengths to prevent multiple calls.
    text1_length = text1.length
    text2_length = text2.length
    # Eliminate the null case.
    return 0 if text1_length == 0 || text2_length == 0

    # Truncate the longer string.
    if text1_length > text2_length
      text1.slice!(0...-text2_length)
    else
      text2.slice!(text1_length..-1)
    end
    text_length = [text1_length, text2_length].min
    # Quick check for the whole case.
    return text_length if text1 == text2

    # Start by looking for a single character match
    # and increase length until no match is found.
    # Performance analysis: http://neil.fraser.name/news/2010/11/04/
    best, length = 0, 1
    loop do
      pattern = text1[(text_length - length)..-1]
      found = text2.index(pattern)
      return best if found.nil?
      length += found
      if found == 0 || text1[(text_length - length)..-1] == text2[0..length]
        best = length
        length += 1
      end
    end
  end

  # Does a substring of shorttext exist within longtext such that the substring
  # is at least half the length of longtext?
  def diff_halfMatchI(longtext, shorttext, i)
    # Start with a 1/4 length Substring at position i as a seed.
    seed = longtext[i, longtext.length / 4]
    j = -1
    best_common = ''
    while j = shorttext.index(seed, j + 1)
      prefix_length = diff_commonPrefix(longtext[i..-1], shorttext[j..-1])
      suffix_length = diff_commonSuffix(longtext[0...i], shorttext[0...j])
      if best_common.length < suffix_length + prefix_length
        best_common = shorttext[(j - suffix_length)...j] +
                      shorttext[j...(j + prefix_length)]
        best_longtext_a = longtext[0...(i - suffix_length)]
        best_longtext_b = longtext[(i + prefix_length)..-1]
        best_shorttext_a = shorttext[0...(j - suffix_length)]
        best_shorttext_b = shorttext[(j + prefix_length)..-1]
      end
    end
    if best_common.length * 2 >= longtext.length
      [best_longtext_a, best_longtext_b,
       best_shorttext_a, best_shorttext_b, best_common]
    end
  end

  # Do the two texts share a substring which is at least half the length of the
  # longer text?
  # This speedup can produce non-minimal diffs.
  def diff_halfMatch(text1, text2)
    # Don't risk returning a non-optimal diff if we have unlimited time
    return nil if diff_timeout <= 0

    shorttext, longtext = [text1, text2].sort_by(&:length)
    if longtext.length < 4 || shorttext.length * 2 < longtext.length
      return nil # Pointless.
    end

    # First check if the second quarter is the seed for a half-match.
    hm1 = diff_halfMatchI(longtext, shorttext, (longtext.length / 4.0).ceil)
    # Check again based on the third quarter.
    hm2 = diff_halfMatchI(longtext, shorttext, (longtext.length / 2.0).ceil)

    if hm1.nil? && hm2.nil?
      return nil
    elsif hm2.nil?
      hm = hm1
    elsif hm1.nil?
      hm = hm2
    else
      # Both matched.  Select the longest.
      hm = hm1[4].length > hm2[4].length ? hm1 : hm2;
    end

    # A half-match was found, sort out the return data.
    if text1.length > text2.length
      text1_a, text1_b, text2_a, text2_b = hm
    else
      text2_a, text2_b, text1_a, text1_b = hm
    end
    mid_common = hm[4]
    return [text1_a, text1_b, text2_a, text2_b, mid_common]
  end

end
