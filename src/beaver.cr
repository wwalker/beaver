# TODO: Write documentation for `Beaver`
def main()
  filename = ARGV[0]
  lines = ARGV[1].to_i
  size = ARGV[2].to_i
  age = ARGV[3].to_i # in seconds
  channel_list = Array( Channel(Nil)).new

  time_fmt = "%FT%H.%M.%S.9%NZ"

  line_count = 0
  if File.exists?(filename)
    new_filename = filename + "." + Time.utc.to_s(time_fmt)
    File.rename(filename, new_filename)
  end
  fh = File.open(filename, "a+")
  rotation_time = Time.utc + age.seconds
  loop do
    line = STDIN.gets
    line_count += 1

    if line_count >= lines
      p "rotating for line count"
      nfh = rotate_log(fh, filename, time_fmt, channel_list)
      fh = nfh
      line_count = 0
      rotation_time = Time.utc + age.seconds
    end

    if line_count % 100 == 0
      if fh.size > size
        p "rotating for size #{fh.size} > #{size}"
        fh = rotate_log(fh, filename, time_fmt, channel_list)
        line_count = 0
        rotation_time = Time.utc + age.seconds
      end
      if Time.utc > rotation_time
        p "rotating for time #{Time.utc} > #{rotation_time}"
        fh = rotate_log(fh, filename, time_fmt, channel_list)
        rotation_time = Time.utc + age.seconds
        line_count = 0
      end
    end

    if line == nil
      # EOF, our client must have died - probably a falling log
      p "Dying from nil read"
      break
    end

    fh.puts line
  end
  p "Dying from EOF"
  p "about to rotate"
  rotate_log(fh, filename, time_fmt, channel_list)
  p "rotated"
  channel_list
end

def rotate_log(fh, fname, time_fmt, channel_list, new_file = true) : File
  fh.close
  channel = Channel(Nil).new
  channel_list << channel
  new_filename = fname + "." + Time.utc.to_s(time_fmt)
  File.rename(fname, new_filename)
  nfh = File.open(fname, "a+")
  # Spawn a fiber to compress the closed log file
  spawn name: "gzip" do
    #p "Start compressing #{new_filename}"
    system("gzip", ["-9", new_filename])
    #p "Done compressing #{new_filename}"
    channel.send(nil)
  end
  nfh
end

channel_list = main()
# Should we wait for the `gzip`s to finish?
#
# Wait for all `spawn`d Fibers to finish
STDERR.puts "Waiting for Fibers to finish..."
channel_list.each do |channel|
  STDERR.puts "Waiting for #{channel}"
  channel.receive
  STDERR.puts "Done waiting for #{channel}"
end
STDERR.puts "Done."