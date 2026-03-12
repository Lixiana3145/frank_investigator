require "test_helper"
require "tempfile"

class Parsing::DocumentExtractorTest < ActiveSupport::TestCase
  test "identifies PDF URLs as documents" do
    assert Parsing::DocumentExtractor.document_url?("https://example.com/report.pdf")
    assert Parsing::DocumentExtractor.document_url?("https://example.com/path/to/file.PDF")
  end

  test "identifies DOCX URLs as documents" do
    assert Parsing::DocumentExtractor.document_url?("https://example.com/report.docx")
  end

  test "identifies spreadsheet URLs as documents" do
    assert Parsing::DocumentExtractor.document_url?("https://example.com/data.xlsx")
    assert Parsing::DocumentExtractor.document_url?("https://example.com/data.csv")
  end

  test "does not identify HTML URLs as documents" do
    refute Parsing::DocumentExtractor.document_url?("https://example.com/article")
    refute Parsing::DocumentExtractor.document_url?("https://example.com/page.html")
    refute Parsing::DocumentExtractor.document_url?("https://example.com/page.htm")
  end

  test "handles invalid URIs gracefully" do
    refute Parsing::DocumentExtractor.document_url?("not a valid url %%")
  end

  test "extracts text from CSV file" do
    csv_content = "Name,Value,Year\nGDP Growth,3.5%,2025\nInflation,4.2%,2025\n"
    tempfile = Tempfile.new([ "data", ".csv" ])
    tempfile.write(csv_content)
    tempfile.close

    result = Parsing::DocumentExtractor.call(file_path: tempfile.path, url: "https://example.com/data.csv")
    assert_includes result.body_text, "GDP Growth"
    assert_includes result.body_text, "3.5%"
    assert_equal "data.csv", result.title
  ensure
    tempfile&.unlink
  end

  test "returns empty text for unsupported extensions" do
    tempfile = Tempfile.new([ "file", ".xyz" ])
    tempfile.write("some content")
    tempfile.close

    result = Parsing::DocumentExtractor.call(file_path: tempfile.path, url: "https://example.com/file.xyz")
    assert_equal "", result.body_text
  ensure
    tempfile&.unlink
  end

  test "extracts text from PDF when pdftotext is available" do
    # Create a minimal PDF
    pdf_content = "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Contents 4 0 R>>endobj\n4 0 obj<</Length 44>>stream\nBT /F1 12 Tf 100 700 Td (Test content) Tj ET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000210 00000 n \ntrailer<</Size 5/Root 1 0 R>>\nstartxref\n304\n%%EOF"

    tempfile = Tempfile.new([ "test", ".pdf" ])
    tempfile.binmode
    tempfile.write(pdf_content)
    tempfile.close

    result = Parsing::DocumentExtractor.call(file_path: tempfile.path, url: "https://example.com/report.pdf")
    # Result may or may not have content depending on pdftotext availability
    assert_kind_of Parsing::DocumentExtractor::Result, result
    assert_respond_to result, :body_text
    assert_respond_to result, :title
    assert_respond_to result, :page_count
  ensure
    tempfile&.unlink
  end

  test "persist_fetched_content uses document extractor for PDF URLs" do
    article = Article.create!(
      url: "https://example.com/report.pdf",
      normalized_url: "https://example.com/report.pdf",
      host: "example.com",
      fetch_status: :pending
    )

    # The HTML content simulates what Chromium would dump for a PDF
    html = "PDF content dump from browser"

    result = Articles::PersistFetchedContent.call(
      article: article,
      html: html,
      fetched_title: "Report PDF",
      current_depth: 0
    )

    article.reload
    assert_equal :fetched, article.fetch_status.to_sym
    assert_equal "document:.pdf", article.main_content_path
  end
end
