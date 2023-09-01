# TODO: Write documentation for `Beaver`
def main
  filename = ARGV[0]
  lines = ARGV[1].to_i
  size = ARGV[2].to_i
  age = ARGV[3].to_i # in seconds
  channel_list = Array(Channel(Nil)).new

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
      STDERR.puts "rotating for line count"
      nfh = rotate_log(fh, filename, time_fmt, channel_list)
      fh = nfh
      line_count = 0
      rotation_time = Time.utc + age.seconds
    end

    if line_count % 100 == 0
      if fh.size > size
        STDERR.puts "rotating for size #{fh.size} > #{size}"
        fh = rotate_log(fh, filename, time_fmt, channel_list)
        line_count = 0
        rotation_time = Time.utc + age.seconds
      end
      if Time.utc > rotation_time
        STDERR.puts "rotating for time #{Time.utc} > #{rotation_time}"
        fh = rotate_log(fh, filename, time_fmt, channel_list)
        rotation_time = Time.utc + age.seconds
        line_count = 0
      end
    end

    if line == nil
      # EOF, our client must have died - probably a falling log
      STDERR.puts "Dying from nil read"
      break
    end

    fh.puts line
  end
  STDERR.puts "Dying from EOF"
  STDERR.puts "about to rotate"
  rotate_log(fh, filename, time_fmt, channel_list)
  STDERR.puts "rotated"
  channel_list
end

def rotate_log(fh, fname, time_fmt, channel_list, new_file = true) : File
  fh.close
  safetynet = fname + "-safetynet"
  channel = Channel(Nil).new
  channel_list << channel
  new_filename = fname + "." + Time.utc.to_s(time_fmt)
  if File.exists?(fname)
    STDERR.puts "Renaming #{fname} to #{new_filename}"
    File.rename(fname, new_filename)
  else
    STDERR.puts "Kernel bug - file #{fname} disappeared"
    if File.exists?(safetynet)
      STDERR.puts "Renaming #{safetynet} to #{new_filename}"
      File.rename(safetynet, new_filename)
    else
      STDERR.puts "Kernel bug - file #{safetynet} disappeared"
    end
  end
  sleep 1 # Workaround a bug in the kernel
  nfh = File.open(fname, "a+")
  File.delete(safetynet) if File.exists?(safetynet)
  File.link(new_filename, safetynet)
  # Spawn a fiber to compress the closed log file
  spawn name: "gzip" do
    # STDERR.puts "Start compressing #{new_filename}"
    system("gzip", ["-9", new_filename])
    # STDERR.puts "Done compressing #{new_filename}"
    channel.send(nil)
  end
  Fiber.yield
  nfh
end

channel_list = main()

# Should we wait for the `gzip`s to finish?  This keeps the client we are
# logging for from knowing we died.  Which *should* only happen if the
# client dies.

# Wait for all `spawn`d Fibers to finish
STDERR.puts "Waiting for Fibers to finish..."
channel_list.each do |channel|
  STDERR.puts "Waiting for #{channel}"
  channel.receive
  STDERR.puts "Done waiting for #{channel}"
end
STDERR.puts "Done."
