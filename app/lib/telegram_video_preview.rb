require "open3"
require "timeout"

class TelegramVideoPreview

  class Error < StandardError; end

  Result = Struct.new(:metadata, :frames, :audio, keyword_init: true) do
    def close
      frames.each { |frame| frame.fetch(:tempfile).close! }
      audio&.close!
    end
  end

  MAX_FRAMES = 6
  MAX_EDGE = 1280
  COMMAND_TIMEOUT = 60.seconds
  STDERR_LIMIT = 2_000

  def initialize(path, message_id)
    @path = path
    @message_id = message_id
  end

  def call
    probe = probe_video
    duration = probe.dig("format", "duration").to_f
    video_stream = Array(probe["streams"]).find { |stream| stream["codec_type"] == "video" }
    audio_stream = Array(probe["streams"]).find { |stream| stream["codec_type"] == "audio" }
    raise Error, "No video stream found" unless video_stream

    metadata = {
      "duration" => duration,
      "width" => video_stream["width"],
      "height" => video_stream["height"],
      "video_codec" => video_stream["codec_name"],
      "audio_codec" => audio_stream&.dig("codec_name"),
      "has_audio" => audio_stream.present?
    }.compact

    frames = extract_frames_safely(frame_timestamps(duration), metadata)
    audio = extract_audio_safely(audio_stream, metadata)
    Result.new(metadata: metadata, frames: frames, audio: audio)
  rescue JSON::ParserError, Timeout::Error, Errno::ENOENT => e
    raise Error, e.message
  end

  private

  attr_reader :path, :message_id

  def probe_video
    stdout, = run_command(
      "ffprobe", "-v", "error", "-show_streams", "-show_format",
      "-of", "json", path
    )
    JSON.parse(stdout)
  end

  def frame_timestamps(duration)
    return [ 0.0 ] if duration <= 1

    count = [ MAX_FRAMES, [ duration.ceil, 1 ].max ].min
    Array.new(count) { |index| ((index + 1) * duration / (count + 1)).round(3) }
  end

  def extract_frames(timestamps)
    frames = []
    timestamps.each_with_index do |timestamp, index|
      tempfile = Tempfile.new([ "telegram-frame-#{message_id}-#{index + 1}-", ".jpg" ], binmode: true)
      tempfile.close
      run_command(
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", timestamp.to_s, "-i", path, "-frames:v", "1",
        "-vf", "scale=min(#{MAX_EDGE}\\,iw):min(#{MAX_EDGE}\\,ih):force_original_aspect_ratio=decrease",
        "-map_metadata", "-1", tempfile.path
      )
      tempfile.open
      tempfile.binmode
      frames << { tempfile: tempfile, timestamp_seconds: timestamp }
    end
    frames
  rescue StandardError
    tempfile&.close!
    frames.each { |frame| frame.fetch(:tempfile).close! }
    raise
  end

  def extract_audio
    tempfile = Tempfile.new([ "telegram-video-audio-#{message_id}-", ".wav" ], binmode: true)
    tempfile.close
    run_command(
      "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
      "-i", path, "-vn", "-ac", "1", "-ar", "16000", tempfile.path
    )
    tempfile.open
    tempfile.binmode
    tempfile
  rescue StandardError
    tempfile&.close!
    raise
  end

  def extract_audio_safely(audio_stream, metadata)
    return unless audio_stream

    extract_audio
  rescue Error => e
    metadata["audio_extraction_status"] = "failed"
    Rails.logger.warn("[TelegramMedia] audio extraction failed: #{e.class}")
    nil
  end

  def extract_frames_safely(timestamps, metadata)
    extract_frames(timestamps)
  rescue Error => e
    metadata["preview_status"] = "failed"
    Rails.logger.warn("[TelegramMedia] frame extraction failed: #{e.class}")
    []
  end

  def run_command(*command)
    stdout = stderr = status = nil
    Timeout.timeout(COMMAND_TIMEOUT) do
      stdout, stderr, status = Open3.capture3(*command)
    end
    raise Error, stderr.to_s.last(STDERR_LIMIT) unless status.success?

    [ stdout, stderr ]
  end

end
