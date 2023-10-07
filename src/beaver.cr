require "build-info"

class Beaver
  @filename : String
  @line_limit : Int64
  @file_size_limit : Int64
  @file_age_limit : Int64

  def initialize(@filename, @line_limit, @file_size_limit, @file_age_limit)
    # @filename = filename
    # @line_limit = line_limit
    # @file_size_limit = file_size_limit
    # @file_age_limit = file_age_limit
    @old_filename = ""
    @new_filename = ""
    @channel_list = Array(Channel(Nil)).new
    @time_fmt = "%FT%H.%M.%S.9%NZ"
    @line_count = 0
    @rotation_time = Time.utc + @file_age_limit.seconds
    @fh = File.open "/dev/null", "rw"
  end # def initialize

  def self.usage
    STDERR.puts "Usage: beaver <filename> <line-limit> <file-size-limit> <file-age-limit>"
    STDERR.puts "  filename: The name of the file to write to"
    STDERR.puts "  line-limit: The number of lines to write to each file"
    STDERR.puts "  file-size-limit: The maximum size of each file in bytes"
    STDERR.puts "  file-age-limit: The maximum age of each file in seconds"
  end # def self.usage

  def rename_original
    if File.exists?(@filename)
      if File.symlink?(@filename)
        File.delete(@filename)
      else
        set_new_filename
        File.rename(@filename, @new_filename)
      end
    end
  end # def rename_original

  def start_compression_job
    # Spawn a fiber to compress the closed log file
    spawn name: "gzip" do
      channel = Channel(Nil).new
      @channel_list << channel
      # STDERR.puts "Start compressing #{new_filename}"
      system("gzip", ["-9", @old_filename])
      # STDERR.puts "Done compressing #{new_filename}"
      channel.send(nil)
    end
  end # def start_compression_job

  def rotate_log
    @fh.close
    open_new_file
    start_compression_job
    sleep 1 # Workaround a bug in the kernel
    Fiber.yield
  end # def rotate_log

  def set_new_filename
    @old_filename = @new_filename || ""
    @new_filename = @filename + "." + Time.utc.to_s(@time_fmt)
  end # def set_new_filename

  def link_to_new_file
    File.delete(@filename) if File.exists?(@filename)
    File.link(@new_filename, @filename)
  end # def link_to_new_file

  def open_new_file
    set_new_filename
    @fh = File.open(@new_filename, "a+")
    link_to_new_file
  end # def open_new_file

  def incr_line_count
    @line_count += 1
  end # def incr_line_count

  def should_rotate?(line : String) : Bool
    rotate = false
    if @line_count >= @line_limit
      @line_count -= @line_limit
      rotate = true
    end
    if @fh.size + line.size > @file_size_limit
      rotate = true
    end
    if Time.utc > @rotation_time
      @rotation_time = Time.utc + @file_age_limit.seconds
      rotate = true
    end
    rotate
  end # def should_rotate?

  def read_and_log
    STDIN.each_line do |line|
      incr_line_count
      rotate_log if should_rotate?(line)
      @fh.puts line
    end # STDIN.each_line do |line|
  end   # def read_and_log

  def wait_for_compression_jobs
    STDERR.puts "Waiting for Fibers to finish..."
    @channel_list.each do |channel|
      STDERR.puts "Waiting for #{channel}"
      channel.receive
      STDERR.puts "Done waiting for #{channel}"
    end # channel_list.each do |channel|
  end   # def wait_for_compression_jobs

  def run
    rename_original
    open_new_file
    read_and_log
    wait_for_compression_jobs
  end # def run
end   # class Beaver

def main
  filename = ARGV[0]
  line_limit = ARGV[1].to_i
  file_size_limit = ARGV[2].to_i
  file_age_limit = ARGV[3].to_i # in seconds
  beaver = Beaver.new(filename, line_limit, file_size_limit, file_age_limit)
  beaver.run
end # def main

main
