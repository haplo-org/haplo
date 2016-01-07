# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class KDelegateAppTest < Test::Unit::TestCase
  include KConstants

  def test_schema_updates
    restore_store_snapshot("basic")

    checking_schema_version_update do
      KObjectStore.erase(O_TYPE_FILE_NEWSLETTER) # objref
    end

    taxonomy_root = KObject.new()
    taxonomy_root.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE)
    taxonomy_root.add_attr('Root', A_TITLE)
    checking_user_not_main_schema_update do
      KObjectStore.create(taxonomy_root)
    end

    taxonomy_term = KObject.new()
    taxonomy_term.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE)
    taxonomy_term.add_attr('Term', A_TITLE)
    taxonomy_term.add_attr(taxonomy_root, A_PARENT)
    checking_user_not_main_schema_update do
      KObjectStore.create(taxonomy_term)
    end

    taxonomy_term = taxonomy_term.dup
    taxonomy_term.add_attr('Something', A_TITLE, Q_ALTERNATIVE)
    checking_user_not_main_schema_update do
      KObjectStore.update(taxonomy_term)
    end

    checking_user_not_main_schema_update do
      KObjectStore.erase(taxonomy_term)  # object
    end

    # Now check it doesn't update things which aren't part of the schema
    book = KObject.new()
    book.add_attr(O_TYPE_BOOK, A_TYPE)
    book.add_attr('Pants', A_TITLE)
    checking_schema_doesnt_update do
      book = KObjectStore.create(book).dup
    end
    book.add_attr('Underwear', A_TITLE, Q_ALTERNATIVE)
    checking_schema_doesnt_update do
      book = KObjectStore.update(book).dup
    end
    checking_schema_doesnt_update do
      KObjectStore.erase(book)
    end

    # And a final schema update
    checking_schema_version_update do
      KObjectStore.erase(O_TYPE_PROJECT)
    end
  end

  def checking_user_not_main_schema_update
    checking_schema_version_update(:user) do
      checking_schema_doesnt_update do
        yield
      end
    end
  end

  def checking_schema_version_update(type = nil)
    global_name = (type == :user) ? :schema_user_version : :schema_version
    KApp.set_global(global_name, 1)
    assert_equal 1, KApp.global(global_name)
    expected_ver = Time.now.to_i
    yield
    ver_now = KApp.global(global_name)
    assert ver_now != 1
    assert ver_now >= expected_ver
  end

  def checking_schema_doesnt_update
    @csdu_serial ||= 12
    KApp.set_global(:schema_version, @csdu_serial)
    assert_equal @csdu_serial, KApp.global(:schema_version)
    yield
    assert_equal @csdu_serial, KApp.global(:schema_version)
    @csdu_serial += 1
  end

end
