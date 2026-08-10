require "test_helper"
require "open3"

class TelegramVideoPreviewTest < ActiveSupport::TestCase

  test "extracts bounded metadata, ordered frames, and mono audio" do
    Dir.mktmpdir do |directory|
      video_path = File.join(directory, "sample.mp4")
      generate_video(video_path)

      result = TelegramVideoPreview.new(video_path, 123).call
      paths = result.frames.map { |frame| frame.fetch(:tempfile).path }
      paths << result.audio.path

      assert_in_delta 2.0, result.metadata["duration"], 0.2
      assert_equal 160, result.metadata["width"]
      assert_equal 120, result.metadata["height"]
      assert result.metadata["has_audio"]
      assert_operator result.frames.length, :<=, TelegramVideoPreview::MAX_FRAMES
      assert_equal result.frames.map { |frame| frame[:timestamp_seconds] }.sort,
        result.frames.map { |frame| frame[:timestamp_seconds] }
      assert result.frames.all? { |frame| frame.fetch(:tempfile).read(2) == "\xFF\xD8".b }
      assert result.audio.size.positive?

      result.close
      paths.each { |path| assert_not File.exist?(path) }
    end
  end

  private

  def generate_video(path)
    _stdout, stderr, status = Open3.capture3(
      "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
      "-f", "lavfi", "-i", "testsrc=size=160x120:rate=2",
      "-f", "lavfi", "-i", "sine=frequency=1000:sample_rate=16000",
      "-t", "2", "-shortest", "-c:v", "mpeg4", "-c:a", "aac", path
    )
    assert status.success?, stderr
  end

end
