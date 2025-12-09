#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark for Range#include? optimization (Issue #9116)
#
# This benchmark tests the performance improvement from the Builtins
# fast-path system. Run with:
#
#   ruby benchmark_range_include.rb
#   jruby benchmark_range_include.rb
#
# Expected results after optimization:
#   - JRuby: ~0.080s (down from ~0.20s)
#   - CRuby: ~0.20s baseline
#   - JRuby 1.7.27 (no redef check): ~0.045s

require 'benchmark'

# Number of iterations
N = 10_000_000

# Test range
RANGE = (1..100)

puts "=" * 60
puts "Range#include? Benchmark"
puts "=" * 60
puts "Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts "System: #{`hostname`.chomp}"
puts "OS: #{`uname -s`.chomp} #{`uname -r`.chomp}"
puts "Architecture: #{`uname -m`.chomp}"
puts "CPU: #{`grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2`.chomp.strip rescue 'N/A'}"
puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Iterations: #{N.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')}"
puts "Range: #{RANGE}"
puts "-" * 60

# Warm up the JIT
puts "\nWarming up..."
100_000.times { RANGE.include?(50) }

puts "\n" + "=" * 60
puts "Baseline CPU Performance (for WSL overhead calculation)"
puts "=" * 60

# Baseline tests to measure WSL vs native Linux overhead
baseline_n = 100_000_000

Benchmark.bm(30) do |x|
  # Raw integer arithmetic
  x.report("integer arithmetic") do
    baseline_n.times { |i| i + 1 }
  end

  # Simple method call
  sum = 0
  x.report("method calls") do
    baseline_n.times { sum += 1 }
  end

  # Array access
  arr = [1, 2, 3, 4, 5]
  x.report("array access") do
    baseline_n.times { arr[2] }
  end
end

puts "\nNote: Compare these baseline times with native Linux to calculate WSL overhead factor"
puts "      Formula: native_time / wsl_time = performance_factor"
puts "      Apply factor to Range benchmarks: adjusted_time = range_time * performance_factor"

puts "\n" + "=" * 60
puts "Range#include? Benchmarks"
puts "=" * 60
puts "\nRunning benchmarks...\n\n"

Benchmark.bm(30) do |x|
  # Test include? with value in middle of range
  x.report("include?(50) - middle") do
    N.times { RANGE.include?(50) }
  end

  # Test include? with value at start
  x.report("include?(1) - start") do
    N.times { RANGE.include?(1) }
  end

  # Test include? with value at end
  x.report("include?(100) - end") do
    N.times { RANGE.include?(100) }
  end

  # Test include? with value outside range
  x.report("include?(0) - outside low") do
    N.times { RANGE.include?(0) }
  end

  x.report("include?(101) - outside high") do
    N.times { RANGE.include?(101) }
  end

  # Test cover? for comparison
  x.report("cover?(50)") do
    N.times { RANGE.cover?(50) }
  end

  # Test === for case statement usage
  x.report("===(50)") do
    N.times { RANGE === 50 }
  end
end

puts "\n" + "=" * 60
puts "Additional tests"
puts "=" * 60

# Test with larger range
LARGE_RANGE = (1..1_000_000)

Benchmark.bm(30) do |x|
  x.report("large range include?(500000)") do
    N.times { LARGE_RANGE.include?(500_000) }
  end
end

# Test exclusive range
EXCLUSIVE_RANGE = (1...100)

Benchmark.bm(30) do |x|
  x.report("exclusive include?(99)") do
    N.times { EXCLUSIVE_RANGE.include?(99) }
  end

  x.report("exclusive include?(100)") do
    N.times { EXCLUSIVE_RANGE.include?(100) }
  end
end

puts "\n" + "=" * 60
puts "Monkey-patch test (should use slow path)"
puts "=" * 60

# Save original method
ORIGINAL_INCLUDE = Range.instance_method(:include?)

# Monkey-patch Range#include?
class Range
  alias_method :original_include?, :include?
  
  def include?(obj)
    original_include?(obj)
  end
end

puts "\nAfter monkey-patching Range#include?:"

Benchmark.bm(30) do |x|
  x.report("patched include?(50)") do
    (N / 10).times { RANGE.include?(50) }  # Fewer iterations since slower
  end
end

# Restore original (if possible - for testing revert behavior)
class Range
  define_method(:include?, ORIGINAL_INCLUDE)
end

puts "\n" + "=" * 60
puts "Integer comparison baseline"
puts "=" * 60

# Raw integer comparison for reference
a = 50
b = 1
c = 100

Benchmark.bm(30) do |x|
  x.report("raw: a >= b && a <= c") do
    N.times { a >= b && a <= c }
  end
end

puts "\nDone!"
