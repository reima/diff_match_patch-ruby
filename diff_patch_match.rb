require 'abbrev'

class DiffPatchMatch
  def initialize
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
end
