require "./spec_helper"
require "file_utils"

# Integration tests for beaver
# These tests verify the complete workflow with actual file operations

# Helper to cleanup test files
def cleanup_test_files(base_name : String)
  File.delete(base_name) if File.exists?(base_name)
  Dir.glob("#{base_name}.*").each do |file|
    File.delete(file) if File.exists?(file)
  end
end

describe "Beaver Integration Tests" do
  describe "complete workflow" do
    it "creates files and symlinks correctly" do
      test_file = "integration_test.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      # Verify symlink was created
      File.symlink?(test_file).should be_true

      # Verify timestamped file exists
      real_file = File.realpath(test_file)
      File.exists?(real_file).should be_true

      # Verify filename format - includes nanoseconds (1-10 digits after the seconds)
      real_file.should match(/integration_test\.log\.\d{4}-\d{2}-\d{2}T\d{2}\.\d{2}\.\d{2}\.\d+Z/)

      cleanup_test_files(test_file)
    end

    it "preserves existing file content when renaming" do
      test_file = "preserve_test.log"
      cleanup_test_files(test_file)

      # Create a file with content
      test_content = "Important log data\nLine 2\nLine 3"
      File.write(test_file, test_content)

      # Initialize beaver and rename the original
      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.rename_original

      # Original file should be gone
      File.exists?(test_file).should be_false

      # Find the renamed file
      renamed_files = Dir.glob("#{test_file}.*")
      renamed_files.size.should eq(1)

      # Verify content was preserved
      File.read(renamed_files[0]).should eq(test_content)

      cleanup_test_files(test_file)
    end

    it "handles rotation workflow" do
      test_file = "rotation_test.log"
      cleanup_test_files(test_file)

      # Create beaver with low line limit to force rotation
      beaver = Beaver.new(test_file, 2_i64, 100000_i64, 3600_i64)
      beaver.open_new_file

      # Simulate line counting
      beaver.incr_line_count
      beaver.should_rotate?("test").should be_false

      beaver.incr_line_count
      beaver.should_rotate?("test").should be_true

      cleanup_test_files(test_file)
    end

    it "updates symlink on rotation" do
      test_file = "symlink_rotation2.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)

      # Create first file
      beaver.open_new_file
      first_target = File.realpath(test_file)

      # Sufficient delay to ensure different timestamp (15ms)
      sleep 0.02

      # Simulate rotation by opening new file again
      beaver.open_new_file
      second_target = File.realpath(test_file)

      # Symlink should point to different file
      first_target.should_not eq(second_target)

      # Both should be timestamped files
      first_target.should match(/symlink_rotation2\.log\.\d{4}-\d{2}-\d{2}T\d{2}\.\d{2}\.\d{2}\.\d+Z/)
      second_target.should match(/symlink_rotation2\.log\.\d{4}-\d{2}-\d{2}T\d{2}\.\d{2}\.\d{2}\.\d+Z/)

      cleanup_test_files(test_file)
    end

    it "handles multiple sequential operations" do
      test_file = "sequential_ops.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)

      # Sequence of operations
      beaver.rename_original  # Should do nothing
      beaver.open_new_file    # Creates file and symlink
      beaver.incr_line_count  # Increment counter
      beaver.set_new_filename # Generate new filename
      beaver.incr_line_count  # Increment again

      # Verify state
      File.exists?(test_file).should be_true
      File.symlink?(test_file).should be_true

      cleanup_test_files(test_file)
    end
  end

  describe "rotation criteria" do
    it "rotates based on line count" do
      test_file = "line_rotation.log"
      cleanup_test_files(test_file)

      # Set very low line limit
      beaver = Beaver.new(test_file, 3_i64, 1000000_i64, 3600_i64)
      beaver.open_new_file

      # Should not rotate initially
      beaver.should_rotate?("line 1").should be_false

      # After reaching line limit
      beaver.incr_line_count
      beaver.incr_line_count
      beaver.incr_line_count
      beaver.should_rotate?("line 4").should be_true

      cleanup_test_files(test_file)
    end

    it "rotates based on file size" do
      test_file = "size_rotation.log"
      cleanup_test_files(test_file)

      # Set very small size limit (50 bytes)
      beaver = Beaver.new(test_file, 10000_i64, 50_i64, 3600_i64)
      beaver.open_new_file

      # A line that would exceed the limit
      large_line = "x" * 100
      beaver.should_rotate?(large_line).should be_true

      # A small line should not trigger rotation
      small_line = "small"
      beaver2 = Beaver.new("size_rotation2.log", 10000_i64, 1000_i64, 3600_i64)
      beaver2.open_new_file
      beaver2.should_rotate?(small_line).should be_false

      cleanup_test_files(test_file)
      cleanup_test_files("size_rotation2.log")
    end

    it "rotates based on file age" do
      test_file = "age_rotation.log"
      cleanup_test_files(test_file)

      # Set very short age limit (0 seconds means immediate expiry)
      beaver = Beaver.new(test_file, 10000_i64, 1000000_i64, 0_i64)

      # Even a tiny delay should cause rotation
      sleep 0.01
      beaver.should_rotate?("test").should be_true

      cleanup_test_files(test_file)
    end

    it "rotates when any limit is reached" do
      test_file = "any_limit.log"
      cleanup_test_files(test_file)

      # Test that exceeding line limit triggers rotation
      beaver1 = Beaver.new(test_file, 1_i64, 1000000_i64, 3600_i64)
      beaver1.incr_line_count
      beaver1.should_rotate?("test").should be_true

      # Test that exceeding size limit triggers rotation
      beaver2 = Beaver.new(test_file, 10000_i64, 10_i64, 3600_i64)
      beaver2.open_new_file
      beaver2.should_rotate?("x" * 100).should be_true

      # Test that exceeding age limit triggers rotation
      beaver3 = Beaver.new(test_file, 10000_i64, 1000000_i64, 0_i64)
      sleep 0.01
      beaver3.should_rotate?("test").should be_true

      cleanup_test_files(test_file)
    end
  end

  describe "file naming and timestamps" do
    it "generates unique filenames for rapid rotations" do
      test_file = "rapid_rotation.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)

      # Generate multiple filenames
      filenames = [] of String
      5.times do
        beaver.set_new_filename
        beaver.open_new_file
        filenames << File.realpath(test_file)
        sleep 0.001 # Small delay to ensure different timestamps
      end

      # All filenames should be unique
      filenames.uniq.size.should eq(5)

      cleanup_test_files(test_file)
    end

    it "uses UTC timestamps" do
      test_file = "utc_test.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      real_file = File.realpath(test_file)

      # Filename should end with Z (UTC indicator)
      real_file.should match(/Z$/)

      cleanup_test_files(test_file)
    end

    it "formats timestamp with nanosecond precision" do
      test_file = "nanosecond_test.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      real_file = File.realpath(test_file)

      # Should have nanoseconds in the timestamp (at least 1 digit, up to 9)
      real_file.should match(/\.\d+Z$/)

      cleanup_test_files(test_file)
    end
  end

  describe "error handling and edge cases" do
    it "handles directories that don't exist" do
      # Note: This would fail in real usage, but we test the behavior
      test_file = "nonexistent_dir/test.log"

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.should be_a(Beaver)
    end

    it "handles filenames with dots" do
      test_file = "my.app.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      File.exists?(test_file).should be_true

      real_file = File.realpath(test_file)
      # Should append timestamp after the full filename
      real_file.should match(/my\.app\.log\.\d{4}-\d{2}-\d{2}T/)

      cleanup_test_files(test_file)
    end

    it "handles filenames with paths" do
      test_dir = "/tmp/beaver_test"
      Dir.mkdir_p(test_dir) unless Dir.exists?(test_dir)

      test_file = "#{test_dir}/path_test.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      File.exists?(test_file).should be_true
      File.symlink?(test_file).should be_true

      cleanup_test_files(test_file)
      Dir.delete(test_dir) if Dir.exists?(test_dir) && Dir.empty?(test_dir)
    end

    it "maintains file permissions" do
      test_file = "permissions_test.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.open_new_file

      real_file = File.realpath(test_file)
      info = File.info(real_file)

      # File should be readable and writable
      info.permissions.owner_read?.should be_true
      info.permissions.owner_write?.should be_true

      cleanup_test_files(test_file)
    end
  end

  describe "concurrent operations" do
    it "handles rapid open/close cycles" do
      test_file = "rapid_cycle.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)

      # Rapid operations
      10.times do
        beaver.set_new_filename
        sleep 0.001
      end

      # Should complete without errors
      beaver.should be_a(Beaver)

      cleanup_test_files(test_file)
    end
  end

  describe "symlink management" do
    it "removes old symlink before creating new one" do
      test_file = "symlink_replace2.log"
      cleanup_test_files(test_file)

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)

      # Create first symlink
      beaver.open_new_file
      File.symlink?(test_file).should be_true

      sleep 0.02

      # Create second symlink (should replace first)
      beaver.open_new_file

      # Should still be a valid symlink
      File.symlink?(test_file).should be_true
      File.exists?(File.realpath(test_file)).should be_true

      cleanup_test_files(test_file)
    end

    it "creates symlink even if regular file exists" do
      test_file = "replace_regular.log"
      cleanup_test_files(test_file)

      # Create a regular file first
      File.write(test_file, "regular file content")
      File.symlink?(test_file).should be_false

      beaver = Beaver.new(test_file, 100_i64, 10000_i64, 3600_i64)
      beaver.rename_original
      beaver.open_new_file

      # Should now be a symlink
      File.symlink?(test_file).should be_true

      cleanup_test_files(test_file)
    end
  end
end
