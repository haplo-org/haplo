# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KFileTransformExcelToJsonTest < Test::Unit::TestCase

  def setup
    destroy_all FileCacheEntry # to delete files from disk
    destroy_all StoredFile # to delete files from disk
    KApp.with_pg_database { |db| db.perform("DELETE FROM public.jobs WHERE application_id=#{_TEST_APP_ID}") }
  end

  def transform_excel(stored_file)
    transformed_filename = KFileTransform.transform(stored_file, KFileTransform::HAPLO_SPREADSHEET_JSON_MIME_TYPE)
    return nil if transformed_filename.nil?
    JSON.parse(File.read(transformed_filename))
  end

  def test_simple_transform
    xlsx_file = StoredFile.from_upload(fixture_file_upload('files/datatypes.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'))
    json =  transform_excel(xlsx_file)
    assert_equal(JSON.parse(DATATYPES_EXPECTED_JSON), json)

    xls_file = StoredFile.from_upload(fixture_file_upload('files/simple.xls', 'application/vnd.ms-excel'))
    json2 = transform_excel(xls_file)
    assert_equal(JSON.parse(SIMPLE_EXPECTED_JSON), json2);

    # PDF returns nothing
    pdf_file = StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))
    assert_equal(nil, transform_excel(pdf_file))

    run_all_jobs({})
  end

  DATATYPES_EXPECTED_JSON = <<'___E'
{
  "format": "application/vnd.haplo.spreadsheet+json",
  "sheets": [
    {
      "name": "Sheet1",
      "rows": [
        [
          {
            "t": 0,
            "v": "String"
          },
          {
            "t": 0,
            "v": "string 1"
          }
        ],
        [
          {
            "t": 0,
            "v": "Integer"
          },
          {
            "t": 1,
            "v": 1.0
          }
        ],
        [
          {
            "t": 0,
            "v": "Numeric"
          },
          {
            "t": 1,
            "v": 199.2
          }
        ],
        [
          {
            "t": 0,
            "v": "Date"
          },
          {
            "t": 2,
            "v": "2018-02-10T00:00:00.000Z"
          }
        ],
        [
          {
            "t": 0,
            "v": "Formula"
          },
          {
            "t": 4,
            "v": "B2+B3",
            "ct": 1,
            "cv": 200.2
          },
          {
            "t": 4,
            "v": "\"X-\" & B1",
            "ct": 0,
            "cv": "X-string 1"
          },
          {
            "t": 4,
            "v": "B2>B3",
            "ct": 3,
            "cv": false
          }
        ]
      ]
    },
    {
      "name": "Hidden sheet",
      "hidden": true,
      "rows": []
    },
    {
      "name": "Another sheet",
      "rows": [
        [
          {
            "t": 0,
            "v": "Hello"
          }
        ],
        [
          null,
          {
            "t": 0,
            "v": "there"
          }
        ],
        [
          null,
          null,
          {
            "t": 0,
            "v": "cells"
          }
        ],
        [
          null,
          null,
          null,
          {
            "t": 1,
            "v": 12.0
          }
        ]
      ]
    }
  ]
}
___E

  SIMPLE_EXPECTED_JSON = <<'___E'
{
  "format": "application/vnd.haplo.spreadsheet+json",
  "sheets": [
    {
      "name": "Sheet1",
      "rows": [
        [
        ],
        [
          null,
          {
            "t": 0,
            "v": "abc"
          }
        ],
        [
          null,
          null,
          {
            "t": 0,
            "v": "def"
          }
        ],
        [
        ],
        [
          null,
          {
            "t": 1,
            "v": 1.2
          }
        ],
        [
          {
            "t": 1,
            "v": 0.0
          }
        ]
      ]
    }
  ]
}  
___E

end
