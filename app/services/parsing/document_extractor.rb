module Parsing
  class DocumentExtractor
    Result = Struct.new(:body_text, :title, :page_count, keyword_init: true)

    SUPPORTED_EXTENSIONS = %w[.pdf .docx .xlsx .csv].freeze
    PDF_EXTENSIONS = %w[.pdf].freeze
    DOCX_EXTENSIONS = %w[.docx].freeze
    SPREADSHEET_EXTENSIONS = %w[.xlsx .csv].freeze

    def self.document_url?(url)
      extension = File.extname(URI.parse(url).path).downcase
      SUPPORTED_EXTENSIONS.include?(extension)
    rescue URI::InvalidURIError
      false
    end

    def self.call(file_path:, url:)
      new(file_path:, url:).call
    end

    def initialize(file_path:, url:)
      @file_path = file_path
      @url = url
      @extension = File.extname(URI.parse(url).path).downcase
    rescue URI::InvalidURIError
      @extension = File.extname(file_path).downcase
    end

    def call
      case @extension
      when *PDF_EXTENSIONS
        extract_pdf
      when *DOCX_EXTENSIONS
        extract_docx
      when *SPREADSHEET_EXTENSIONS
        extract_spreadsheet
      else
        Result.new(body_text: "", title: File.basename(@url), page_count: 0)
      end
    end

    private

    def extract_pdf
      text = pdf_to_text
      title = text.lines.first&.strip.presence || File.basename(@url)
      Result.new(body_text: text, title: title, page_count: count_pdf_pages)
    end

    def extract_docx
      text = docx_to_text
      title = text.lines.first&.strip.presence || File.basename(@url)
      Result.new(body_text: text, title: title, page_count: 1)
    end

    def extract_spreadsheet
      text = spreadsheet_to_text
      title = File.basename(@url)
      Result.new(body_text: text, title: title, page_count: 1)
    end

    def pdf_to_text
      stdout, _stderr, status = Open3.capture3("pdftotext", "-layout", "-nopgbrk", @file_path, "-")
      return stdout.squish if status.success? && stdout.present?

      # Fallback: try extracting with strings for scanned PDFs
      stdout2, _, status2 = Open3.capture3("strings", @file_path)
      status2.success? ? stdout2.squish : ""
    rescue Errno::ENOENT
      Rails.logger.warn("pdftotext not available for PDF extraction")
      ""
    end

    def count_pdf_pages
      stdout, _, status = Open3.capture3("pdfinfo", @file_path)
      return 0 unless status.success?

      match = stdout.match(/Pages:\s+(\d+)/)
      match ? match[1].to_i : 0
    rescue Errno::ENOENT
      0
    end

    def docx_to_text
      # Use unzip to extract document.xml from docx, then strip XML tags
      stdout, _, status = Open3.capture3("unzip", "-p", @file_path, "word/document.xml")
      return "" unless status.success?

      # Strip XML tags to get plain text
      stdout.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
    rescue Errno::ENOENT
      Rails.logger.warn("unzip not available for DOCX extraction")
      ""
    end

    def spreadsheet_to_text
      if @extension == ".csv"
        File.read(@file_path, encoding: "UTF-8").scrub("")
      else
        # For xlsx, extract shared strings
        stdout, _, status = Open3.capture3("unzip", "-p", @file_path, "xl/sharedStrings.xml")
        return "" unless status.success?

        stdout.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
      end
    rescue Errno::ENOENT, Errno::EACCES
      ""
    end
  end
end
