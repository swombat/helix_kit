require "open3"
require "zip"

module Message::Attachable

  extend ActiveSupport::Concern

  WORD_DOCUMENT_TYPES = %w[
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ].freeze
  DOCX_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  MAX_EXTRACTED_DOCUMENT_TEXT = 200_000

  ACCEPTABLE_FILE_TYPES = {
    images: %w[image/png image/jpeg image/jpg image/gif image/webp image/bmp],
    audio: %w[audio/mpeg audio/wav audio/m4a audio/ogg audio/flac audio/webm],
    video: %w[video/mp4 video/quicktime video/x-msvideo video/webm],
    documents: %w[
      application/pdf
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain text/markdown text/csv text/html text/css text/xml
      application/json application/xml
      text/x-python application/x-python
      text/x-ruby application/x-ruby
      application/javascript text/javascript
      application/x-yaml text/yaml text/x-yaml
    ]
  }.freeze

  ACCEPTABLE_EXTENSIONS = %w[
    .md .markdown .txt .csv .json .xml .html .htm .css .js .ts .jsx .tsx
    .py .rb .yaml .yml .toml .ini .log .rst .tex .sh .bash .zsh
    .c .h .cpp .hpp .java .go .rs .swift .kt .scala .r .sql
  ].freeze

  MAX_FILE_SIZE = 50.megabytes

  included do
    has_many_attached :attachments do |attachable|
      attachable.variant :thumb,
        resize_to_limit: [ 200, 200 ],
        format: :jpeg,
        saver: { quality: 70, strip: true }

      attachable.variant :preview,
        resize_to_limit: [ 1200, 1200 ],
        format: :jpeg,
        saver: { quality: 80, strip: true }
    end

    has_one_attached :audio_recording
    has_one_attached :voice_audio

    validate :acceptable_files
  end

  def files_json
    return [] unless attachments.attached?

    url_helpers = Rails.application.routes.url_helpers

    attachments.map do |file|
      file_data = {
        id: file.id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size
      }

      begin
        file_data[:url] = url_helpers.rails_blob_url(file, only_path: true)

        if file.content_type&.start_with?("image/")
          file_data[:thumb_url] = url_helpers.rails_representation_url(file.variant(:thumb), only_path: true)
          file_data[:preview_url] = url_helpers.rails_representation_url(file.variant(:preview), only_path: true)
        end
      rescue ArgumentError
        file_data[:url] = "/files/#{file.id}"
      end

      file_data
    end
  end

  def audio_url = blob_url_for(audio_recording)
  def voice_audio_url = blob_url_for(voice_audio)

  def file_paths_for_llm(include_audio: true, include_pdf: true)
    return [] unless attachments.attached?

    files = attachments.to_a
    files.reject! { |f| WORD_DOCUMENT_TYPES.include?(f.content_type) }
    files.reject! { |f| f.content_type&.start_with?("audio/") } unless include_audio
    files.reject! { |f| f.content_type == "application/pdf" } unless include_pdf
    files.filter_map { |file| resolve_attachment_path(file) }
  end

  def content_with_documents_for_llm(text_content = content, include_audio: true, include_pdf: true)
    text = text_content.to_s
    document_text = word_document_text_for_llm
    text = [ text, document_text ].select(&:present?).join("\n\n")

    file_paths = file_paths_for_llm(include_audio: include_audio, include_pdf: include_pdf)
    file_paths.present? ? RubyLLM::Content.new(text, file_paths) : text
  end

  def word_documents_attached?
    attachments.any? { |attachment| WORD_DOCUMENT_TYPES.include?(attachment.content_type) }
  end

  def word_document_text_for_llm
    return nil unless attachments.attached?

    attachments.filter_map do |attachment|
      next unless WORD_DOCUMENT_TYPES.include?(attachment.content_type)

      text = if attachment.content_type == DOCX_CONTENT_TYPE
        extract_docx_text(attachment)
      end

      text = if text.present?
        text.truncate(MAX_EXTRACTED_DOCUMENT_TEXT)
      else
        "[The document could not be converted to text. Ask the user to upload it as DOCX, PDF, or plain text.]"
      end

      "<file name='#{attachment.filename}'>\n#{text}\n</file>"
    end.join("\n\n").presence
  end

  def pdf_text_for_llm
    return nil unless attachments.attached?

    pdf_attachments = attachments.select { |f| f.content_type == "application/pdf" }
    return nil if pdf_attachments.empty?

    pdf_attachments.filter_map { |attachment|
      path = resolve_attachment_path(attachment)
      next unless path

      text = extract_pdf_text(path)
      next if text.blank?

      "<file name='#{attachment.filename}'>\n#{text}\n</file>"
    }.join("\n\n").presence
  end

  def audio_path_for_llm
    resolve_attachment_path(audio_recording)
  end

  private

  def blob_url_for(attachment)
    return unless attachment.attached?
    Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)
  rescue ArgumentError
    nil
  end

  def acceptable_files
    return unless attachments.attached?

    attachments.each do |file|
      unless acceptable_file_type?(file)
        errors.add(:attachments, "#{file.filename}: file type not supported")
      end

      if file.byte_size > MAX_FILE_SIZE
        errors.add(:attachments, "#{file.filename}: must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
      end
    end
  end

  def acceptable_file_type?(file)
    return true if ACCEPTABLE_FILE_TYPES.values.flatten.include?(file.content_type)

    extension = File.extname(file.filename.to_s).downcase
    ACCEPTABLE_EXTENSIONS.include?(extension)
  end

  def resolve_attachment_path(attachment)
    return unless !attachment.respond_to?(:attached?) || attachment.attached?

    blob = attachment.blob
    return unless blob.service.exist?(attachment.key)

    if blob.service.respond_to?(:path_for)
      blob.service.path_for(attachment.key)
    else
      tempfile = Tempfile.new([ "attachment", File.extname(attachment.filename.to_s) ])
      tempfile.binmode
      attachment.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      tempfile.path
    end
  rescue Errno::ENOENT, ActiveStorage::FileNotFoundError
    nil
  end

  def extract_pdf_text(path)
    stdout, status = Open3.capture2("pdftotext", "-layout", path.to_s, "-")
    return nil unless status.success?

    stdout.strip.truncate(100_000)
  rescue Errno::ENOENT
    nil
  end

  def extract_docx_text(attachment)
    Tempfile.create([ "attachment", ".docx" ]) do |tempfile|
      tempfile.binmode
      attachment.download { |chunk| tempfile.write(chunk) }
      tempfile.flush

      Zip::File.open(tempfile.path) do |archive|
        extract_docx_parts(archive).presence
      end
    end
  rescue ActiveStorage::FileNotFoundError, Errno::ENOENT, Zip::Error
    nil
  end

  def extract_docx_parts(archive)
    parts = {
      "word/document.xml" => nil,
      "word/footnotes.xml" => "Footnotes",
      "word/endnotes.xml" => "Endnotes"
    }

    parts.filter_map do |path, heading|
      entry = archive.find_entry(path)
      next unless entry

      text = extract_wordprocessing_xml(entry.get_input_stream.read)
      next if text.blank?

      heading ? "#{heading}\n\n#{text}" : text
    end.join("\n\n")
  end

  def extract_wordprocessing_xml(xml)
    document = Nokogiri::XML(xml)
    namespaces = { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }

    document.xpath("//w:p", namespaces).filter_map do |paragraph|
      text = paragraph.xpath(".//w:t | .//w:tab | .//w:br", namespaces).map do |node|
        case node.name
        when "t" then node.text
        when "tab" then "\t"
        else "\n"
        end
      end.join

      text.presence
    end.join("\n\n")
  end

end
