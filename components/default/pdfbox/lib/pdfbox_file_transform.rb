# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PdfboxFileTransform < KFileTransform::TransformComponent

  PDFPageRender = Java::OrgHaploComponentPdfbox::PDFPageRender
  ConvertPDFToText = Java::OrgHaploComponentPdfbox::ConvertPDFToText
  ThumbnailPDF = Java::OrgHaploComponentPdfbox::ThumbnailPDF

  # -----------------------------------------------------------------------------------------------------------------------

  def get_transformer(input_mime_type, output_mime_type)
    transformer = nil
    if input_mime_type == 'application/pdf'
      if output_mime_type =~ /\Aimage\//
        transformer = TransformPDF
      elsif output_mime_type == 'text/plain'
        transformer = TransformPDFToText.new
      end
    end
    transformer
  end

  # -----------------------------------------------------------------------------------------------------------------------

  def set_image_dimensions_and_make_thumbnail(mime_type, stored_file, disk_pathname, thumbnail_pathname)
    return nil unless mime_type == 'application/pdf'
    thumbnailer = ThumbnailPDF.new(disk_pathname, thumbnail_pathname, KFileTransform::THUMBNAIL_MAX_DIMENSION)
    thumbnailer.perform()
    success = false
    if thumbnailer.isValid()
      stored_file.set_dimensions(thumbnailer.getPDFWidth(), thumbnailer.getPDFHeight(), 'pt')
      stored_file.dimensions_pages = thumbnailer.getNumberOfPages()
      if thumbnailer.hasMadeThumbnail()
        dims = thumbnailer.getThumbnailDimensions()
        stored_file.set_thumbnail(dims.width, dims.height, StoredFile::THUMBNAIL_FORMAT_PNG)
        success = true
      end
    end
    success
  end

  # -----------------------------------------------------------------------------------------------------------------------

  class TransformPDF
    def self.make_op(input_disk_pathname, output_disk_pathname, input_mime_type, output_mime_type, output_options)
      width = output_options[:w].to_i || THUMBNAIL_MAX_DIMENSION
      width = 16 if width <= 0
      height = output_options[:h].to_i || THUMBNAIL_MAX_DIMENSION
      height = 16 if height <= 0
      raise "Can only render PDFs into images" unless output_mime_type =~ /\Aimage\/(\w+)/
      output_format = $1
      page = (output_options[:page] || 1)

      PDFPageRender.new(input_disk_pathname, output_disk_pathname, page, width, height, output_format)
    end
    def self.complete_op(op)
      op.getSuccess()
    end
    def self.clean_up
    end
  end

  class TransformPDFToText
    def initialize
    end
    def make_op(input_disk_pathname, output_disk_pathname, input_mime_type, output_mime_type, output_options)
      @output_disk_pathname = output_disk_pathname
      ConvertPDFToText.new(input_disk_pathname, output_disk_pathname)
    end
    def complete_op(op)
      File.exist?(@output_disk_pathname)
    end
    def clean_up
    end
  end

end
