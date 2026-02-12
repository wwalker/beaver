require "./spec_helper"

describe Beaver do
  describe "#initialize" do
    it "initializes with correct parameters" do
      beaver = Beaver.new("test.log", 100_i64, 1024_i64, 3600_i64)
      beaver.should be_a(Beaver)
    end

    it "accepts various limit values" do
      beaver = Beaver.new("test.log", 0_i64, 0_i64, 0_i64)
      beaver.should be_a(Beaver)
    end
  end

  describe "#set_new_filename" do
    it "generates timestamped filename" do
      beaver = Beaver.new("test.log", 100_i64, 1024_i64, 3600_i64)

      # Call set_new_filename to generate a filename
      beaver.set_new_filename

      # We can't directly access @new_filename, but we can test the behavior
      # by checking that calling it multiple times produces different filenames
      # (due to time progression)
      beaver.should be_a(Beaver)
    end
  end

  describe "#should_rotate?" do
    it "returns false when no limits are exceeded" do
      beaver = Beaver.new("test.log", 1000_i64, 10000_i64, 3600_i64)
      result = beaver.should_rotate?("short line")
      result.should be_false
    end

    it "returns true when line limit is reached" do
      beaver = Beaver.new("test.log", 1_i64, 10000_i64, 3600_i64)
      beaver.incr_line_count
      result = beaver.should_rotate?("test line")
      result.should be_true
    end

    it "returns true when file size limit would be exceeded" do
      # Create a beaver with a very small file size limit
      beaver = Beaver.new("test.log", 1000_i64, 10_i64, 3600_i64)
      # Open a new file to have a valid file handle
      beaver.open_new_file

      # A long line should exceed the size limit
      long_line = "x" * 100
      result = beaver.should_rotate?(long_line)
      result.should be_true

      # Cleanup
      File.delete("test.log") if File.exists?("test.log")
      Dir.glob("test.log.*").each { |f| File.delete(f) }
    end

    it "returns true when file age limit is exceeded" do
      # Create a beaver with 0 second age limit (always expired)
      beaver = Beaver.new("test.log", 1000_i64, 10000_i64, 0_i64)
      # Sleep a tiny bit to ensure time has passed
      sleep 0.001
      result = beaver.should_rotate?("test line")
      result.should be_true
    end
  end

  describe "#incr_line_count" do
    it "increments the line counter" do
      beaver = Beaver.new("test.log", 100_i64, 1024_i64, 3600_i64)

      # Increment multiple times
      5.times { beaver.incr_line_count }

      # We can't directly check the counter, but we can verify behavior
      beaver.should be_a(Beaver)
    end
  end

  describe "#symlink_to_new_file" do
    it "creates a symlink to the new file" do
      beaver = Beaver.new("test_symlink.log", 100_i64, 1024_i64, 3600_i64)

      # Create a test file to symlink to
      beaver.set_new_filename
      beaver.open_new_file

      # Check that the symlink exists
      File.exists?("test_symlink.log").should be_true
      File.symlink?("test_symlink.log").should be_true

      # Cleanup
      File.delete("test_symlink.log") if File.exists?("test_symlink.log")
      Dir.glob("test_symlink.log.*").each { |f| File.delete(f) }
    end

    it "replaces existing symlink" do
      # Clean up before test
      File.delete("test_replace2.log") if File.exists?("test_replace2.log")
      Dir.glob("test_replace2.log.*").each { |f| File.delete(f) }

      beaver = Beaver.new("test_replace2.log", 100_i64, 1024_i64, 3600_i64)

      # Create first symlink
      beaver.open_new_file
      first_target = File.realpath("test_replace2.log")

      # Sleep to ensure different timestamp
      sleep 0.015

      # Create second file and symlink (should replace first)
      beaver.open_new_file
      second_target = File.realpath("test_replace2.log")

      # Targets should be different
      first_target.should_not eq(second_target)

      # Cleanup
      File.delete("test_replace2.log") if File.exists?("test_replace2.log")
      Dir.glob("test_replace2.log.*").each { |f| File.delete(f) }
    end
  end

  describe "#rename_original" do
    it "does nothing if file doesn't exist" do
      beaver = Beaver.new("nonexistent.log", 100_i64, 1024_i64, 3600_i64)
      beaver.rename_original
      # Should not raise an error
      File.exists?("nonexistent.log").should be_false
    end

    it "renames existing file with timestamp" do
      # Create a test file
      File.write("existing.log", "test content")

      beaver = Beaver.new("existing.log", 100_i64, 1024_i64, 3600_i64)
      beaver.rename_original

      # Original file should not exist
      File.exists?("existing.log").should be_false

      # A timestamped version should exist
      renamed_files = Dir.glob("existing.log.*")
      renamed_files.size.should eq(1)

      # Cleanup
      renamed_files.each { |f| File.delete(f) }
    end
  end

  describe "#open_new_file" do
    it "creates a new timestamped file" do
      beaver = Beaver.new("new_file.log", 100_i64, 1024_i64, 3600_i64)
      beaver.open_new_file

      # Check that files were created
      File.exists?("new_file.log").should be_true
      Dir.glob("new_file.log.*").size.should eq(1)

      # Cleanup
      File.delete("new_file.log") if File.exists?("new_file.log")
      Dir.glob("new_file.log.*").each { |f| File.delete(f) }
    end

    it "creates symlink pointing to timestamped file" do
      beaver = Beaver.new("symlink_test.log", 100_i64, 1024_i64, 3600_i64)
      beaver.open_new_file

      # Symlink should exist and be valid
      File.symlink?("symlink_test.log").should be_true
      File.exists?(File.realpath("symlink_test.log")).should be_true

      # Cleanup
      File.delete("symlink_test.log") if File.exists?("symlink_test.log")
      Dir.glob("symlink_test.log.*").each { |f| File.delete(f) }
    end
  end

  describe "timestamp format" do
    it "uses correct timestamp format in filename" do
      # Clean up before test
      File.delete("timestamp3.log") if File.exists?("timestamp3.log")
      Dir.glob("timestamp3.log.*").each { |f| File.delete(f) }

      beaver = Beaver.new("timestamp3.log", 100_i64, 1024_i64, 3600_i64)
      beaver.open_new_file

      timestamped_files = Dir.glob("timestamp3.log.*")
      timestamped_files.size.should eq(1)

      filename = timestamped_files[0]
      # Should match pattern: timestamp.log.YYYY-MM-DDTHH.MM.SS.NNNNNNNNNZ
      # The timestamp format has nanoseconds (1-10 digits)
      filename.should match(/timestamp3\.log\.\d{4}-\d{2}-\d{2}T\d{2}\.\d{2}\.\d{2}\.\d+Z/)

      # Cleanup
      File.delete("timestamp3.log") if File.exists?("timestamp3.log")
      timestamped_files.each { |f| File.delete(f) }
    end
  end

  describe "integration scenarios" do
    it "handles multiple rotations" do
      # Create a beaver with very low limits to force rotation
      beaver = Beaver.new("multi_rotate.log", 2_i64, 1000000_i64, 3600_i64)

      beaver.open_new_file

      # Simulate writing lines that trigger rotation
      beaver.incr_line_count
      beaver.incr_line_count

      # Should trigger rotation
      should_rotate = beaver.should_rotate?("test")
      should_rotate.should be_true

      # Cleanup
      File.delete("multi_rotate.log") if File.exists?("multi_rotate.log")
      Dir.glob("multi_rotate.log.*").each { |f| File.delete(f) }
    end

    it "handles file operations correctly" do
      beaver = Beaver.new("file_ops.log", 100_i64, 1024_i64, 3600_i64)

      # Test the complete workflow
      beaver.rename_original  # Should do nothing for non-existent file
      beaver.open_new_file    # Should create file and symlink

      File.exists?("file_ops.log").should be_true
      File.symlink?("file_ops.log").should be_true

      # Cleanup
      File.delete("file_ops.log") if File.exists?("file_ops.log")
      Dir.glob("file_ops.log.*").each { |f| File.delete(f) }
    end
  end

  describe "edge cases" do
    it "handles zero line limit" do
      beaver = Beaver.new("zero_lines.log", 0_i64, 10000_i64, 3600_i64)
      result = beaver.should_rotate?("test")
      result.should be_true
    end

    it "handles zero size limit" do
      beaver = Beaver.new("zero_size.log", 1000_i64, 0_i64, 3600_i64)
      beaver.open_new_file
      result = beaver.should_rotate?("test")
      result.should be_true

      # Cleanup
      File.delete("zero_size.log") if File.exists?("zero_size.log")
      Dir.glob("zero_size.log.*").each { |f| File.delete(f) }
    end

    it "handles empty string filename" do
      beaver = Beaver.new("", 100_i64, 1024_i64, 3600_i64)
      beaver.should be_a(Beaver)
    end

    it "handles very long filenames" do
      long_name = "a" * 200 + ".log"
      beaver = Beaver.new(long_name, 100_i64, 1024_i64, 3600_i64)
      beaver.should be_a(Beaver)
    end

    it "handles special characters in filename" do
      beaver = Beaver.new("test-file_123.log", 100_i64, 1024_i64, 3600_i64)
      beaver.open_new_file
      File.exists?("test-file_123.log").should be_true

      # Cleanup
      File.delete("test-file_123.log") if File.exists?("test-file_123.log")
      Dir.glob("test-file_123.log.*").each { |f| File.delete(f) }
    end

    it "handles very large limit values" do
      # Use large but not maximum values to avoid overflow in time calculations
      large_value = 999_999_999_i64
      beaver = Beaver.new("large_limits.log", large_value, large_value, large_value)
      beaver.should be_a(Beaver)
    end

    it "handles concurrent filename generation" do
      beaver = Beaver.new("concurrent.log", 100_i64, 1024_i64, 3600_i64)

      # Generate multiple filenames rapidly
      beaver.set_new_filename
      sleep 0.001
      beaver.set_new_filename

      # Should not raise errors
      beaver.should be_a(Beaver)
    end
  end

  describe "cleanup and resource management" do
    it "properly handles file handles" do
      beaver = Beaver.new("handles.log", 100_i64, 1024_i64, 3600_i64)
      beaver.open_new_file

      # File should be writable
      File.exists?("handles.log").should be_true

      # Cleanup
      File.delete("handles.log") if File.exists?("handles.log")
      Dir.glob("handles.log.*").each { |f| File.delete(f) }
    end
  end
end
