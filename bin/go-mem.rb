#!/usr/bin/env ruby

require 'open3'
require 'optparse'

# Default configuration
DEFAULT_MEMORY_PAGES = 128
PAGE_SIZE = 65536  # 64KB per page

# Parse arguments
options = { pages: DEFAULT_MEMORY_PAGES }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} <input.wasm> <output.wasm> [options]"
  opts.separator ""
  opts.separator "Options:"

  opts.on("-p", "--pages PAGES", Integer, "Memory pages (default: #{DEFAULT_MEMORY_PAGES})") do |p|
    options[:pages] = p
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end

  opts.separator ""
  opts.separator "Example:"
  opts.separator "  #{$0} component.wasm component.fix.wasm"
  opts.separator "  #{$0} component.wasm component.fix.wasm --pages 256"
end.parse!

# Check required arguments
if ARGV.length < 2
  STDERR.puts "Error: Missing required arguments"
  STDERR.puts "Usage: #{$0} <input.wasm> <output.wasm> [options]"
  STDERR.puts "Try '#{$0} --help' for more information"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]
memory_pages = options[:pages]
stack_pointer = memory_pages * PAGE_SIZE  # Stack at the end of allocated memory

# Read WAT from wasm-tools
wat, err, status = Open3.capture3('wasm-tools', 'print', input_file)
unless status.success?
  STDERR.puts "Error reading #{input_file}: #{err}"
  exit 1
end

# Apply transformations
wat_fixed = wat.lines.map do |line|
  case line
  when /^(\s*\(memory \(;0;\) )(\d+)(\).*)$/
    "#{$1}#{memory_pages}#{$3}\n"
  when /^(\s*\(global \$__stack_pointer \(;0;\) \(mut i32\) i32\.const )(\d+)(\).*)$/
    "#{$1}#{stack_pointer}#{$3}\n"
  else
    line
  end
end.join

# Write to wasm-tools parse
Open3.popen3('wasm-tools', 'parse', '-o', output_file) do |stdin, stdout, stderr, wait_thr|
  stdin.write(wat_fixed)
  stdin.close

  unless wait_thr.value.success?
    STDERR.puts "Error writing #{output_file}: #{stderr.read}"
    exit 1
  end
end

# Success - no output unless there's an error