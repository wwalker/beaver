require "./beaver"

def main
  filename = ARGV[0]
  line_limit = ARGV[1].to_i
  file_size_limit = ARGV[2].to_i
  file_age_limit = ARGV[3].to_i # in seconds
  beaver = Beaver.new(filename, line_limit, file_size_limit, file_age_limit)
  beaver.run
end # def main

main
