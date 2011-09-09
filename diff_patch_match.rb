require 'uri'

class DiffPatchMatch
  attr_accessor :diff_timeout
  attr_accessor :diff_editCost

  def initialize
    # Defaults.
    # Redefine these in your program to override the defaults.

    # Number of seconds to map a diff before giving up (0 for infinity).
    @diff_timeout = 1
    # Cost of an empty edit operation in terms of edit characters.
    @diff_editCost = 4
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
      text1 = text1[-text2_length..-1]
    else
      text2 = text2[0...text1_length]
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

  # Split two texts into an array of strings.  Reduce the texts to a string of
  # hashes where each Unicode character represents one line.
  def diff_linesToChars(text1, text2)
    line_array = ['']  # e.g. line_array[4] == "Hello\n"
    line_hash = {}     # e.g. line_hash["Hello\n"] == 4

    [text1, text2].map do |text|
      # Split text into an array of strings.  Reduce the text to a string of
      # hashes where each Unicode character represents one line.
      chars = ''
      text.each_line do |line|
        if line_hash[line]
          chars += line_hash[line].chr(Encoding::UTF_8)
        else
          chars += line_array.length.chr(Encoding::UTF_8)
          line_hash[line] = line_array.length
          line_array << line
        end
      end
      chars
    end << line_array
  end

  # Rehydrate the text in a diff from a string of line hashes to real lines of
  # text.
  def diff_charsToLines(diffs, line_array)
    diffs.each do |diff|
      diff[1] = diff[1].chars.map{|c| line_array[c.ord]}.join
    end
  end

  # Reorder and merge like edit sections.  Merge equalities.
  # Any edit section can move as long as it doesn't cross an equality.
  def diff_cleanupMerge(diffs)
    diffs << [:diff_equal, ''] # Add a dummy entry at the end.
    pointer = 0
    count_delete, count_insert = 0, 0
    text_delete, text_insert = '', ''
    while pointer < diffs.length
      case diffs[pointer][0]
        when :diff_insert
          count_insert += 1
          text_insert += diffs[pointer][1]
          pointer += 1
        when :diff_delete
          count_delete += 1
          text_delete += diffs[pointer][1]
          pointer += 1
        when :diff_equal
          # Upon reaching an equality, check for prior redundancies.
          if count_delete + count_insert > 1
            if count_delete != 0 && count_insert != 0
              # Factor out any common prefixies.
              common_length = diff_commonPrefix(text_insert, text_delete)
              if common_length != 0
                if (pointer - count_delete - count_insert) > 0 &&
                    diffs[pointer - count_delete - count_insert - 1][0] ==
                      :diff_equal
                  diffs[pointer - count_delete - count_insert - 1][1] +=
                    text_insert[0...common_length]
                else
                  diffs.unshift([:diff_equal, text_insert[0...common_length]])
                  pointer += 1
                end
                text_insert = text_insert[common_length..-1]
                text_delete = text_delete[common_length..-1]
              end
              # Factor out any common suffixies.
              common_length = diff_commonSuffix(text_insert, text_delete)
              if common_length != 0
                diffs[pointer][1] =
                  text_insert[-common_length..-1] +
                  diffs[pointer][1]
                text_insert = text_insert[0...-common_length]
                text_delete = text_delete[0...-common_length]
              end
            end
            # Delete the offending records and add the merged ones.
            if count_delete == 0
              diffs[
                pointer - count_delete - count_insert,
                count_delete + count_insert
              ] = [[:diff_insert, text_insert]]
            elsif count_insert == 0
              diffs[
                pointer - count_delete - count_insert,
                count_delete + count_insert
              ] = [[:diff_delete, text_delete]]
            else
              diffs[
                pointer - count_delete - count_insert,
                count_delete + count_insert
              ] = [[:diff_delete, text_delete], [:diff_insert, text_insert]]
            end
            pointer = pointer - count_delete - count_insert +
              (count_delete != 0 ? 1 : 0) + (count_insert != 0 ? 1 : 0) + 1
          elsif pointer != 0 && diffs[pointer - 1][0] == :diff_equal
            # Merge this equality with the previous one.
            diffs[pointer - 1][1] += diffs[pointer][1];
            diffs[pointer, 1] = []
          else
            pointer += 1
          end
          count_insert, count_delete = 0, 0
          text_delete, text_insert = '', ''
      end # case
    end # while

    if diffs[-1][1] == ''
      diffs.pop # Remove the dummy entry at the end.
    end

    # Second pass: look for single edits surrounded on both sides by equalities
    # which can be shifted sideways to eliminate an equality.
    # e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
    changes = false
    pointer = 1
    # Intentionally ignore the first and last element (don't need checking).
    while pointer < diffs.length - 1
      if diffs[pointer - 1][0] == :diff_equal &&
         diffs[pointer + 1][0] == :diff_equal
        # This is a single edit surrounded by equalities.
        if diffs[pointer][1][-diffs[pointer - 1][1].length..-1] ==
           diffs[pointer - 1][1]
          # Shift the edit over the previous equality.
          diffs[pointer][1] =
            diffs[pointer - 1][1] +
            diffs[pointer][1][0...-diffs[pointer - 1][1].length]
          diffs[pointer + 1][1] = diffs[pointer - 1][1] + diffs[pointer + 1][1]
          diffs[pointer - 1, 1] = []
          changes = true
        elsif diffs[pointer][1][0...diffs[pointer + 1][1].length] ==
              diffs[pointer + 1][1]
          # Shift the edit over the next equality.
          diffs[pointer - 1][1] += diffs[pointer + 1][1]
          diffs[pointer][1] =
            diffs[pointer][1][diffs[pointer + 1][1].length..-1] +
            diffs[pointer + 1][1]
          diffs[pointer + 1, 1] = []
          changes = true
        end
      end
      pointer += 1
    end # while
    # If shifts were made, the diff needs reordering and another shift sweep.
    if changes
      diff_cleanupMerge(diffs)
    end
  end


  # Given two strings, compute a score representing whether the internal
  # boundary falls on logical boundaries.
  # Scores range from 5 (best) to 0 (worst).
  def diff_cleanupSemanticScore(one, two)
    if one.empty? || two.empty?
      # Edges are the best
      return 5
    end

    # Define some regex patterns for matching boundaries.
    punctuation = /[^a-zA-Z0-9]/
    whitespace = /\s/
    linebreak = /[\r\n]/
    blanklineEnd = /\n\r?\n$/
    blanklineStart = /^\r?\n\r?\n/

    # Each port of this function behaves slightly differently due to
    # subtle differences in each language's definition of things like
    # 'whitespace'.  Since this function's purpose is largely cosmetic,
    # the choice has been made to use each language's native features
    # rather than force total conformity.
    score = 0
    # One point for non-alphanumeric.
    if one[-1].match(punctuation) || two[0].match(punctuation)
      score += 1
      # Two points for whitespace.
      if one[-1].match(whitespace) || two[0].match(whitespace)
        score += 1
        # Three points for line breaks.
        if one[-1].match(linebreak) || two[0].match(linebreak)
          score += 1
          # Four points for blank lines.
          if one.match(blanklineEnd) || two.match(blanklineStart)
            score += 1
          end
        end
      end
    end

    return score
  end

  # Look for single edits surrounded on both sides by equalities
  # which can be shifted sideways to align the edit to a word boundary.
  # e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
  def diff_cleanupSemanticLossless(diffs)
    pointer = 1
    # Intentionally ignore the first and last element (don't need checking).
    while pointer < diffs.length - 1
      if diffs[pointer - 1][0] == :diff_equal &&
         diffs[pointer + 1][0] == :diff_equal
        # This is a single edit surrounded by equalities.
        equality1 = diffs[pointer - 1][1]
        edit      = diffs[pointer][1]
        equality2 = diffs[pointer + 1][1]

        # First, shift the edit as far left as possible.
        common_offset = diff_commonSuffix(equality1, edit)
        if common_offset != 0
          common_string = edit[-common_offset..-1]
          equality1 = equality1[0...-common_offset]
          edit = common_string + edit[0...-common_offset]
          equality2 = common_string + equality2
        end

        # Second, step character by character right, looking for the best fit.
        bestEquality1 = equality1
        bestEdit = edit
        bestEquality2 = equality2
        bestScore =
          diff_cleanupSemanticScore(equality1, edit) +
          diff_cleanupSemanticScore(edit, equality2)
        while edit[0] == equality2[0]
          equality1 += edit[0]
          edit = edit[1..-1] + equality2[0];
          equality2 = equality2[1..-1]
          score =
            diff_cleanupSemanticScore(equality1, edit) +
            diff_cleanupSemanticScore(edit, equality2)
          # The >= encourages trailing rather than leading whitespace on edits.
          if score >= bestScore
            bestScore = score
            bestEquality1 = equality1
            bestEdit = edit
            bestEquality2 = equality2
          end
        end

        if diffs[pointer - 1][1] != bestEquality1
          # We have an improvement, save it back to the diff.
          if !bestEquality1.empty?
            diffs[pointer - 1][1] = bestEquality1
          else
            diffs[pointer - 1, 1] = []
            pointer -= 1
          end
          diffs[pointer][1] = bestEdit
          if !bestEquality2.empty?
            diffs[pointer + 1][1] = bestEquality2
          else
            diffs[pointer + 1, 1] = []
            pointer -= 1
          end
        end
      end
      pointer += 1
    end
  end

  # Reduce the number of edits by eliminating semantically trivial equalities.
  def diff_cleanupSemantic(diffs)
    changes = false
    equalities = []  # Stack of indices where equalities are found.
    last_equality = nil # Always equal to equalities[-1][1]
    pointer = 0 # Index of current position.
    # Number of characters that changed prior to the equality.
    length_insertions1, length_deletions1 = 0, 0
    # Number of characters that changed after the equality.
    length_insertions2, length_deletions2 = 0, 0

    while pointer < diffs.length
      if diffs[pointer][0] == :diff_equal # Equality found.
        equalities << pointer
        length_insertions1 = length_insertions2
        length_deletions1 = length_deletions2
        length_insertions2 = 0
        length_deletions2 = 0
        last_equality = diffs[pointer][1]
      else  # An insertion or deletion.
        if diffs[pointer][0] == :diff_insert
          length_insertions2 += diffs[pointer][1].length
        else
          length_deletions2 += diffs[pointer][1].length
        end

        if last_equality &&
           last_equality.length <= [length_insertions1, length_deletions1].max &&
           last_equality.length <= [length_insertions2, length_deletions2].max
          # Duplicate record.
          diffs[equalities[-1], 0] = [[:diff_delete, last_equality]]
          # Change second copy to insert.
          diffs[equalities[-1] + 1][0] = :diff_insert
          # Throw away the equality we just deleted.
          equalities.pop
          # Throw away the previous equality (it needs to be reevaluated).
          equalities.pop
          pointer = equalities.length > 0 ? equalities[-1] : -1
          length_insertions1, length_deletions1 = 0, 0  # Reset the counters.
          length_insertions2, length_deletions2 = 0, 0
          last_equality = nil
          changes = true
        end
      end
      pointer += 1
    end

    # Normalize the diff.
    if changes
      diff_cleanupMerge(diffs)
    end
    diff_cleanupSemanticLossless(diffs)

    # Find any overlaps between deletions and insertions.
    # e.g: <del>abcxx</del><ins>xxdef</ins>
    #   -> <del>abc</del>xx<ins>def</ins>
    pointer = 1
    while pointer < diffs.length
      if diffs[pointer - 1][0] == :diff_delete &&
         diffs[pointer][0] == :diff_insert
        deletion = diffs[pointer - 1][1]
        insertion = diffs[pointer][1]
        overlap_length = diff_commonOverlap(deletion, insertion)
        if overlap_length != 0
          # Overlap found.  Insert an equality and trim the surrounding edits.
          diffs[pointer, 0] = [[:diff_equal, insertion[0...overlap_length]]]
          diffs[pointer - 1][1] = deletion[0...-overlap_length]
          diffs[pointer + 1][1] = insertion[overlap_length..-1]
          pointer += 1
        end
        pointer += 1
      end
      pointer += 1
    end
  end

  # Reduce the number of edits by eliminating operationally trivial equalities.
  def diff_cleanupEfficiency(diffs)
    changes = false
    equalities = []  # Stack of indices where equalities are found.
    last_equality = ''  # Always equal to equalities[-1][1]
    pointer = 0  # Index of current position.
    # Is there an insertion operation before the last equality.
    pre_ins = false
    # Is there a deletion operation before the last equality.
    pre_del = false
    # Is there an insertion operation after the last equality.
    post_ins = false
    # Is there a deletion operation after the last equality.
    post_del = false
    while pointer < diffs.length
      if diffs[pointer][0] == :diff_equal # Equality found.
        if diffs[pointer][1].length < diff_editCost &&
           (post_ins || post_del)
          # Candidate found.
          equalities << pointer
          pre_ins = post_ins
          pre_del = post_del
          last_equality = diffs[pointer][1]
        else
          # Not a candidate, and can never become one.
          equalities.clear
          last_equality = ''
        end
        post_ins = post_del = false
      else # An insertion or deletion.
        if diffs[pointer][0] == :diff_delete
          post_del = true
        else
          post_ins = true
        end
        # Five types to be split:
        # <ins>A</ins><del>B</del>XY<ins>C</ins><del>D</del>
        # <ins>A</ins>X<ins>C</ins><del>D</del>
        # <ins>A</ins><del>B</del>X<ins>C</ins>
        # <ins>A</del>X<ins>C</ins><del>D</del>
        # <ins>A</ins><del>B</del>X<del>C</del>
        #/
        if !last_equality.empty? &&
           ((pre_ins && pre_del && post_ins && post_del) ||
            ((last_equality.length < diff_editCost / 2) &&
             [pre_ins, pre_del, post_ins, post_del].count(true) == 3))
          # Duplicate record.
          diffs[equalities[-1], 0] = [[:diff_delete, last_equality]]
          # Change second copy to insert.
          diffs[equalities[-1] + 1][0] = :diff_insert
          equalities.pop # Throw away the equality we just deleted
          last_equality = ''
          if pre_ins && pre_del
            # No changes made which could affect previous entry, keep going.
            post_ins = post_del = true
            equalities.clear
          else
            equalities.pop  # Throw away the previous equality.
            pointer = equalities[-1] || -1
            post_ins = post_del = false
          end
          changes = true
        end
      end
      pointer += 1
    end

    if changes
      diff_cleanupMerge(diffs)
    end
  end

  # Convert a diff array into a pretty HTML report.
  def diff_prettyHtml(diffs)
    diffs.map do |diff|
      op, data = diff
      text = data.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').
        gsub('\n', '&para;<br>')
      case op
        when :diff_insert
          "<ins style=\"background:#e6ffe6;\">#{text}</ins>"
        when :diff_delete
          "<del style=\"background:#ffe6e6;\">#{text}</del>"
        when :diff_equal
          "<span>#{text}</span>"
      end
    end.join
  end

  # Compute and return the source text (all equalities and deletions).
  #
  def diff_text1(diffs)
    diffs.map do |diff|
      if diff[0] == :diff_insert
        ''
      else
        diff[1]
      end
    end.join
  end

  # Compute and return the destination text (all equalities and insertions).
  def diff_text2(diffs)
    diffs.map do |diff|
      if diff[0] == :diff_delete
        ''
      else
        diff[1]
      end
    end.join
  end

  # Crush the diff into an encoded string which describes the operations
  # required to transform text1 into text2.
  # E.g. =3\t-2\t+ing  -> Keep 3 chars, delete 2 chars, insert 'ing'.
  # Operations are tab-separated.  Inserted text is escaped using %xx notation.
  def diff_toDelta(diffs)
    diffs.map do |diff|
      case diff[0]
        when :diff_insert
          '+' + URI.encode(diff[1])
        when :diff_delete
          '-' + diff[1].length.to_s
        when :diff_equal
          '=' + diff[1].length.to_s
      end
    end.join("\t").gsub('%20', ' ').gsub('%23', '#')
  end

  # Given the original text1, and an encoded string which describes the
  # operations required to transform text1 into text2, compute the full diff.
  def diff_fromDelta(text1, delta)
    diffs = []
    pointer = 0 # Cursor in text1
    delta.split("\t").each do |token|
      # Each token begins with a one character parameter which specifies the
      # operation of this token (delete, insert, equality).
      param = token[1..-1]
      case token[0]
        when '+'
          diffs << [
            :diff_insert,
            URI.decode(param.force_encoding(Encoding::UTF_8))
          ]
        when '-', '='
          begin
            n = Integer(param)
            raise if n < 0
            text = text1[pointer...(pointer += n)]
            if token[0] == '='
              diffs << [:diff_equal, text]
            else
              diffs << [:diff_delete, text]
            end
          rescue ArgumentError => e
            raise ArgumentError.new("Invalid number in diff_fromDelta: #{param.inspect}")
          end
        else
          # Blank tokens are ok (from a trailing \t).
          # Anything else is an error.
          if !token.empty?
            raise ArgumentError.new("Invalid diff operation in diff_fromDelta: #{token.inspect}")
          end
      end
    end
    if pointer != text1.length
      raise ArgumentError.new("Delta length (#{pointer}) does not equal source text length (#{text1.length})")
    end
    diffs
  end

end
