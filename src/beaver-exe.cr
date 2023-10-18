require "shard"
require "./beaver"

def usage(msg ="", exit_code = 0)
  STDERR.puts msg if msg != ""
  STDERR.puts "Usage: #{$0} [options] filename line_limit file_size_limit file_age_limit"
  exit 0
end

def version
  STDERR.puts "beaver version #{Shard.version}"
  exit 0
end

def version_full
  STDERR.puts "Git version #{Shard.git_version}"
  # STDERR.puts "Git branch #{Shard.git_branch}"
  STDERR.puts "Git description #{Shard.git_description}"

  STDERR.puts "Shard name #{Shard.name}"
  STDERR.puts "Shard version #{Shard.version}"
  STDERR.puts "Shard authors #{Shard.authors.join(", ")}"
  STDERR.puts "Shard program #{Shard.program}"
  # STDERR.puts "Shard time #{Shard.time}"

  license = Shard.license
  # year    = Shard.time.to_s("%Y")
  authors = Shard.authors.join(", ")

  STDERR.puts "The %s License (%s)" % [license, license]
  # STDERR.puts "Copyright (c) %s %s" % [year, author]

  exit 0
end

def main
  case ARGV[0]
  when "--help", "-h"
    usage
  when "--version", "-v"
    version
  when "--version-full", "-V"
    version_full
  end

  usage("Wrong argument count!", 1) if ARGV.size != 4

  filename = ARGV[0]
  line_limit = ARGV[1].to_i
  file_size_limit = ARGV[2].to_i
  file_age_limit = ARGV[3].to_i # in seconds
  beaver = Beaver.new(filename, line_limit, file_size_limit, file_age_limit)
  beaver.run
end # def main

main
