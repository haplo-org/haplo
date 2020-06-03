# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KIdentifierFileTest < Test::Unit::TestCase

  def test_file_identifier_equality
    fake_file = StoredFile.new
    fake_file.digest = 'ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06'
    fake_file.size = 1
    fake_file.upload_filename = 'x.pdf'
    fake_file.mime_type = 'application/pdf'
    fileidentifier1 = KIdentifierFile.new(fake_file)
    fileidentifier2 = KIdentifierFile.new(fake_file)
    assert fileidentifier1 == fileidentifier2
    assert fileidentifier1.tracking_id != fileidentifier2.tracking_id # not included in the comparison

    stored_file3 = StoredFile.new
    stored_file3.digest = '6a07330da9cc6d1ec39037d7efc105b25208953877f96a0d7ea4ad5692a82b11'
    stored_file3.size = 33352
    stored_file3.upload_filename = 'o.doc'
    stored_file3.mime_type = 'application/msword'
    fileidentifier3 = KIdentifierFile.new(stored_file3)

    assert !(fileidentifier1 == fileidentifier3)
  end

  def test_file_identifier_attribute_checks
    fileidentifier = KIdentifierFile.new(nil)

    fileidentifier.digest = '6a07330da9cc6d1ec39037d7efc105b25208953877f96a0d7ea4ad5692a82b11'
    fileidentifier.digest = '7a07330da9cc6d1ec39037d7efc105b25208953877f96a0d7ea4ad5692a82b12'
    assert_raises(RuntimeError) { fileidentifier.digest = 'Xa07330da9cc6d1ec39037d7efc105b25208953877f96a0d7ea4ad5692a82b11' }
    assert_raises(RuntimeError) { fileidentifier.digest = '6a07330da9cc6d1ec39037d7efc105b25208953877f96a0d7ea4ad5692a82b1' }

    fileidentifier.tracking_id = '0123456789abcdefghijklmnopqrstuvwxyz_-'
    assert_raises(RuntimeError) { fileidentifier.tracking_id = '!!!' }
  end

end

