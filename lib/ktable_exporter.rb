# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# TODO: unit testing for KTableExporter
# TODO: see if KTableExporter can be made more memory/CPU efficient

class KTableExporter
  include KConstants
  include KObjectURLs

  def initialize(included_attrs = nil, include_urls = false)
    @included_attrs = included_attrs
    @include_urls = include_urls
  end

  # Column info
  ColumnInfo = Struct.new(
    :attr_desc,                 # schema attribute descriptior (full, not int)
    :data_value_cell_headings,  # Array of names for the data value cells for the column (gained from desc)
    :values_by_qualifier,       # Hash of qualifier (int) -> ColumnValues, containing all the data for the export
    :ordered_qualifiers,        # After gathering data, an array of ColumnValues
    :width                      # Width of the entire column, in data values
  )
  ColumnValues = Struct.new(
    :values,                    # Array of values, one per object exported. Is either nil or array of actual data values
    :qualifier,                 # Qualifier (int)
    :width                      # Width in data values
  )

  # objects must respond to each()
  def export(objects, format)

    # Get info about the attributes we want to export
    schema = KObjectStore.schema
    exporting_attrs = Hash.new
    schema.each_attr_descriptor { |d| exporting_attrs[d.desc] = d if @included_attrs == nil || @included_attrs.include?(d.desc)}
    schema.each_aliased_attr_descriptor { |d| exporting_attrs[d.desc] = d if @included_attrs == nil || @included_attrs.include?(d.desc)}
    return '' if exporting_attrs.empty?

    columns = Hash.new
    exporting_attrs.each do |key,attr_desc|
      # Get the data value width
      data_value_cell_headings = [nil]
      # Text?
      if attr_desc.data_type >= T_TEXT__MIN
        data_value_cell_headings = KText.export_data_value_cell_headings(attr_desc.data_type, attr_desc)
      end
      columns[key] = ColumnInfo.new(attr_desc, data_value_cell_headings, Hash.new)
    end

    types_found = Array.new
    index = 0                 # index of object; arrays will be sparse so << isn't going to work.
    objects.each do |object|
      # Root type of object type
      root_type = schema.type_descriptor(object.first_attr(A_TYPE) || O_TYPE_UNKNOWN).root_type
      types_found << root_type unless types_found << root_type

      # Use aliasing to separate out the attributes, and store in the columns
      aliased = KAttrAlias.attr_aliasing_transform(object, schema)
      aliased.each do |a|
        col = columns[a.descriptor.desc]
        if col != nil
          a.attributes.each do |v,d,q|
            col.values_by_qualifier[q] ||= ColumnValues.new(Array.new, q, 0)
            col.values_by_qualifier[q].values[index] ||= Array.new
            col.values_by_qualifier[q].values[index] << v
          end
        end
      end
      index += 1
    end
    number_of_objects = index

    # Order the qualifiers, work out how wide each of the columns is
    columns.each do |desc,col|
      col.ordered_qualifiers = col.values_by_qualifier.values.sort { |a,b| a.qualifier <=> b.qualifier }
      total_width = 0
      col.ordered_qualifiers.each do |vq|
        width = 0
        vq.values.each do |arr|
          if arr != nil
            l = arr.length
            width = l if l > width
          end
        end
        vq.width = width
        total_width += width
      end
      col.width = total_width
    end

    # Remove any columns without values
    columns.delete_if { |k,col| col.width < 0 }

    # Work out the order of output fields -- use the order from the types
    column_output_order = Array.new
    types_found.each do |type_objref|
      type_desc = schema.type_descriptor(type_objref)
      type_desc.attributes.each do |d|
        if columns.has_key?(d)
          column_output_order << d unless column_output_order.include?(d)
        end
      end
    end
    # and add in any which weren't included
    columns.each_value do |col|
      column_output_order << col.attr_desc.desc unless column_output_order.include?(col.attr_desc.desc)
    end

    # Turn the order into an array of columns
    output_columns = column_output_order.map { |d| columns[d] } .compact

    # Create a writer for the output
    writer_class = format.kind_of?(Class) ? format : FORMATS[format]
    raise "Bad format given to KTableExporter" unless writer_class != nil && writer_class.kind_of?(Class)
    writer = writer_class.new

    # Headings
    headings = Array.new
    headings << 'URL' if @include_urls
    output_columns.each do |column|
      nm = column.attr_desc.printable_name
      h = Array.new
      column.ordered_qualifiers.each do |values|
        qual_desc = schema.qualifier_descriptor(values.qualifier) # descriptor existance checked to be tolerant of bad quals from plugins
        base = (values.qualifier == Q_NULL || !qual_desc) ? "#{nm}" : "#{nm} / #{qual_desc.printable_name}"
        if values.width == 1
          h << base
        else
          1.upto(values.width) do |i|
            h << "#{base} #{i}"
          end
        end
      end
      ch = column.data_value_cell_headings
      h.each do |heading|
        if ch.length == 1
          headings << heading
        else
          ch.each do |hn|
            headings << "#{hn} / #{heading}"
          end
        end
      end
    end
    writer.write_headings(headings)

    objref_to_text = Hash.new

    url_base = KApp.url_base()

    0.upto(number_of_objects - 1) do |index|
      cells = Array.new
      if @include_urls
        cells << "#{url_base}#{object_urlpath(objects[index])}"
      end
      output_columns.each do |column|
        # How many cells wide is each value expected to be?
        expected_len = column.data_value_cell_headings.length
        # Go through each column
        column.ordered_qualifiers.each do |values|
          cells_output = 1
          arr = values.values[index]
          if arr == nil
            # This object doesn't have any values for this desc/qualifier paid
            (values.width * expected_len).times { cells << nil }
          else
            # There are some values.
            arr.each do |v|
              tc = v.k_typecode
              # TODO: Proper handling of attribute groups in table exporter - this just outputs the first value
              if tc == T_ATTRIBUTE_GROUP
                v = v.transformed.first.attributes.first.first
                next if v.nil?
                tc = v.k_typecode
              end
              # Determine type of value, for the conversion
              if tc == T_OBJREF
                # Objrefs need to be looked up, and text cached
                t = objref_to_text[v]
                if t == nil
                  o = KObjectStore.read(v)
                  if o
                    t = o.first_attr(A_TITLE)
                    t = t.to_s if t
                  end
                  t ||= '????'
                  objref_to_text[v] = t
                end
                cells << t
              elsif tc >= T_TEXT__MIN
                # KText deriviative -- might spit out more than one bit of info in an array
                c = v.to_export_cells
                if c.class == Array
                  # Adjust array?
                  if c.length > expected_len
                    # Too many bits of data here, concatendate some up
                    cn = Array.new
                    c.each do |cv|
                      if cn.length < expected_len
                        cn << cv
                      else
                        cn[cn.length-1] = "#{cn.last} #{cv}"
                      end
                    end
                    c = cn
                  end
                  c.each { |cv| cells << cv }
                  cells_output = c.length
                else
                  cells << c
                end
              else
                # Other value, just convert to text
                cells << v.to_s
              end
              # Fill in any empty space
              if expected_len != cells_output
                cells_output.upto(expected_len-1) { cells << nil }
              end
            end
            # And is the width less than the maximum in this column
            if arr.length < values.width
              ((values.width - arr.length) * expected_len).times { cells << nil }
            end
          end
        end
      end
      writer.write_row(cells)
    end

    writer.output
  end

  class FormatTSV
    BLANK_CELL = ''
    CELL_SEPARATOR = "\t"
    LINE_ENDING = "\r\n"

    def initialize
      @tsv = ''
    end
    def write_row(row)
      @tsv << row.map { |h| (h || BLANK_CELL).gsub(/\s+/,' ') } .join(CELL_SEPARATOR)
      @tsv << LINE_ENDING
    end
    alias write_headings write_row
    def output
      @tsv
    end
  end

  class FormatCSV
    def initialize
      @csv = ''.force_encoding(Encoding::UTF_8)
    end
    def write_row(row)
      @csv << row.to_csv
    end
    alias write_headings write_row
    def output
      @csv
    end
  end

  class FormatXLSX
    def initialize
      @workbook = Java::OrgApachePoiXssfUsermodel::XSSFWorkbook.new
      @sheet = @workbook.createSheet("#{KApp.global(:product_name)} Export")
      @sheet.createFreezePane(0, 1, 0, 1) # keeps the heading in position as the user scrolls
      @next_row = 0
    end
    def write_row(cells)
      row = @sheet.createRow(@next_row);
      @next_row += 1
      cells.each_with_index do |cell, index|
        unless cell == nil
          row.createCell(index).setCellValue(cell)
        end
      end
      row # so write_headings can style it
    end
    def write_headings(headings)
      row = write_row(headings)
      style = @workbook.createCellStyle()
      style.setBorderBottom(Java::OrgApachePoiSsUsermodel::BorderStyle::THIN)
      font = @workbook.createFont();
      font.setBold(true)
      style.setFont(font);
      row.setRowStyle(style)
      row.each { |cell| cell.setCellStyle(style) }
    end
    def output
      # TODO: Bit inefficient writing of XLS files
      stream = java.io.ByteArrayOutputStream.new
      @workbook.write(stream)
      String.from_java_bytes(stream.toByteArray())
    end
  end

  FORMATS = {
    'tsv' => FormatTSV, :tsv => FormatTSV,
    'csv' => FormatCSV, :csv => FormatCSV,
    'xlsx' => FormatXLSX, :xlsx => FormatXLSX
  }

end
