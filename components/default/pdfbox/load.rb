# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require "#{File.dirname(__FILE__)}/lib/pdfbox_file_transform"

KTextExtract.register_op_class('application/pdf', Java::OrgHaploComponentPdfbox::TextExtractPDF)

KFileTransform::COMPONENTS << PdfboxFileTransform.new
