require 'benchmark'

def prefix_linear(text1, text2)
  # Linear search.
  text1.length.times do |i|
    if text1[i] != text2[i]
      return i
    end
  end
end

def prefix_binary(text1, text2)
  # Binary search.
  pointermin = 0
  pointermax = [text1.length, text2.length].min
  pointermid = pointermax
  pointerstart = 0
  while pointermin < pointermid
    if text1[pointerstart...pointermid] == text2[pointerstart...pointermid]
      pointermin = pointermid
      pointerstart = pointermin
    else
      pointermax = pointermid
    end
    pointermid = (pointermax - pointermin) / 2 + pointermin
  end
  return pointermid
end

def make_strings(n)
  # Create a random string of 'n' letters.
  chars = (32..127).map(&:chr)
  text1 = Array.new(n, '').collect{chars[rand(chars.size)]}.join

  # Create another random string which differs from the first by one letter
  # inserted.
  answer = rand(n)
  text2 = text1[0...answer] + '\t' + text1[answer..-1]

  [text1, text2, answer]
end

Benchmark.bm(20) do |bm|
  [1_000, 10_000, 100_000, 1_000_000, 10_000_000].each do |n|
    text1, text2, answer = make_strings(n)
    bm.report("linear (#{n})") { (prefix_linear(text1, text2) == answer) or raise }
    bm.report("binary (#{n})") { (prefix_binary(text1, text2) == answer) or raise }
  end
end
