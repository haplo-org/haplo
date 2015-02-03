# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class XMLAPITest < IntegrationTest
  include KConstants

  # TODO: More detailed XML API tests

  def setup
    # Don't want to use cookies at all for this API only test
    set_ignore_cookies(true)
    # Clean store
    restore_store_snapshot("basic")
    # Fixtures
    db_reset_test_data
    # Make a basic API key
    @api_key = ApiKey.new(:user_id => 41, :path => '/api/', :name => 'test')
    @api_key_secret = @api_key.set_random_api_key
    @api_key.save!
  end

  def teardown
    # Clean up
    @api_key.destroy
  end

  # ====================================================================================================
  def test_obj_api
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Book title", A_TITLE)
    obj.add_attr("Alternative title", A_TITLE, Q_ALTERNATIVE)
    KObjectStore.create(obj)

    # Fetch the object
    get '/api/object/ref/'+obj.objref.to_presentation, {}, {'X-ONEIS-Key' => @api_key_secret}
    assert_response :success
    assert_equal "success", find_tag(:tag => 'response').attributes['status']
    assert_equal "text/xml; charset=utf-8", response['content-type']

    # Decode the document
    xml_doc = REXML::Document.new(response.body)
    objr = KObject.new()
    objr.add_attrs_from_xml(xml_doc.elements['response/read/object'], KObjectStore.schema)

    # Check it looks OK
    assert_equal "Book title", objr.first_attr(A_TITLE).to_s
    assert_equal O_TYPE_BOOK, objr.first_attr(A_TYPE)
  end

  # ====================================================================================================
  def test_batch_api
    # Make test objects
    obj1 = KObject.new()
    obj1.add_attr(O_TYPE_BOOK, A_TYPE)
    obj1.add_attr("Book1", A_TITLE)
    KObjectStore.create(obj1)

    obj2 = KObject.new()
    obj2.add_attr(O_TYPE_BOOK, A_TYPE)
    obj2.add_attr("Book2", A_TITLE)
    KObjectStore.create(obj2)

    # Make a request
    builder = Builder::XmlMarkup.new
    builder.instruct!
    builder.request(:identifier => 'TEST') do |req|
      req.operations do |ops|
        ops.read(:ref => obj1.objref.to_presentation)
        ops.no_op
        ops.create() do |op|
          op.object do |ob|
            ob.attributes do |attrs|
              attrs.a('20x1', :d => 'x2', :vt => 0) # type
              attrs.a(:d => 'x3', :vt => 16) { |a| a.text 'Random title' }
              # NOTE: This date has a non-GMT timezone. This broke a previous version of the code
              attrs.a('2010-03-30T11:53:57+01:00', :d => 'x9', :vt => 4)
            end
          end
        end
        ops.delete(:ref => obj2.objref.to_presentation)
        ops.update(:ref => obj1.objref.to_presentation)
        ops.update(:ref => obj1.objref.to_presentation) do |op|
          op.object(:included_attrs => '9w5') do |ob|
            ob.attributes do |attrs|
              attrs.a(:d => '9w5', :vt => 16) { |a| a.text 'Notes updated ' + Time.now.to_s }
            end
          end
        end
      end
    end
    # POST the document
    post '/api/object/batch', builder.target!, {'X-ONEIS-Key' => @api_key_secret}
    assert_response :success
    assert_equal "success", find_tag(:tag => 'response').attributes['status']
    assert_equal "TEST", find_tag(:tag => 'response').attributes['identifier']
    assert_equal "text/xml; charset=utf-8", response['content-type']

    # Check basic responses
    assert nil != find_tag(:tag => 'read', :attributes => {:index => 0, :ref => obj1.objref.to_presentation})
    assert nil != find_tag(:tag => 'error', :attributes => {:index => 1})
    assert nil != find_tag(:tag => 'create', :attributes => {:index => 2})
    assert nil != find_tag(:tag => 'delete', :attributes => {:index => 3, :ref => obj2.objref.to_presentation})
    assert nil != find_tag(:tag => 'error', :attributes => {:index => 4})
    assert nil != find_tag(:tag => 'update', :attributes => {:index => 5, :ref => obj1.objref.to_presentation})

    # Check object is read
    xml_doc = REXML::Document.new(response.body)
    obj1r = KObject.new()
    obj1r.add_attrs_from_xml(xml_doc.elements['response/read/object'], KObjectStore.schema)
    assert_equal "Book1", obj1r.first_attr(A_TITLE).to_s

    # Check object got deleted
    assert KObjectStore.read(obj2.objref).labels.include? O_LABEL_DELETED

    # Check object got updated
    obj1_update = KObjectStore.read(obj1.objref)
    assert_equal "Book1", obj1_update.first_attr(A_TITLE).to_s
    assert obj1_update.first_attr(A_NOTES).to_s =~ /Notes updated/
  end

  # ====================================================================================================
  def test_search_api
    0.upto(200) do |i|
      obj = KObject.new()
      obj.add_attr(O_TYPE_BOOK, A_TYPE)
      obj.add_attr("Book "+sprintf("%04d",i), A_TITLE)
      KObjectStore.create(obj)
    end

    made_requests = 0
    start_index = 0
    seen = Hash.new
    seen_all = false

    while made_requests < 200 && !seen_all
      # Make a request
      get '/api/search/q', {:q => 'type:book', :start_index => start_index}, {'X-ONEIS-Key' => @api_key_secret}
      assert_response :success
      assert_equal "success", find_tag(:tag => 'response').attributes['status']
      assert_equal "text/xml; charset=utf-8", response['content-type']

      # Decode
      xml = REXML::Document.new(response.body)

      # Scan the things returned
      got_results = 0
      results = xml.elements['response/results']
      results.children.each do |result|
        assert_equal "object", result.name
        got_results += 1
        # Decode obj
        o = KObject.new()
        o.add_attrs_from_xml(result, KObjectStore.schema)
        # Check it's as expected, find the number from the title
        assert o.first_attr(A_TITLE).to_s =~ /^Book (\d+)$/
        i = $1.to_i
        # Check seen status
        assert !(seen.has_key?(i))
        seen[i] = true
      end

      # Check the number of results matches the thing it's supposed to be
      assert got_results > 0
      assert_equal got_results, xml.elements['response/results'].attributes['results_included'].to_i
      assert_equal start_index, xml.elements['response/results'].attributes['start_index'].to_i
      assert_equal 201, xml.elements['response/results'].attributes['result_count'].to_i

      # Seen everything yet?
      seen_all = true
      0.upto(200) { |i| seen_all = false unless seen.has_key?(i)}

      # Next...
      made_requests += 1
      start_index += got_results
    end

    # Check everything was seen
    assert seen_all

    # Check mulitple requests were made
    assert made_requests > 1

    # Check that a search which returns nothing doesn't break
    tsa_check_zero_results '/api/search/q', {:q => 'not finding anything'}
    tsa_check_zero_results '/api/search/q', {:q => 'not finding anything', :start_index => 2000}

    # Check that a search for an non-empty string which parses to an empty search doesn't error
    tsa_check_zero_results '/api/search/q', {:q => ' - '}, false

    # Check that a search for an empty string doesn't error
    tsa_check_zero_results '/api/search/q', {:q => ''}, false
  end

  def tsa_check_zero_results(path, params, expected_to_do_search = true)
    get path, params, {'X-ONEIS-Key' => @api_key_secret}
    assert_response :success
    assert_equal "success", find_tag(:tag => 'response').attributes['status']
    assert_equal (expected_to_do_search ? 'true' : 'false'), find_tag(:tag => 'response').attributes['searched']
    assert_equal "0", find_tag(:tag => 'results').attributes['result_count']
    assert_equal "0", find_tag(:tag => 'results').attributes['start_index']
    assert_equal "0", find_tag(:tag => 'results').attributes['results_included']
  end

  # ====================================================================================================

  def test_file_upload_auth_requirements
    set_ignore_cookies(false) # need cookies for this test!
    make_upload_params = Proc.new { { :file => fixture_file_upload('files/example.doc', 'application/msword') } }
    get_a_page_to_refresh_csrf_token
    # Without a file, no auth
    post_403('/api/file/upload-new-file', {})
    # Without authentication
    multipart_post_403('/api/file/upload-new-file', make_upload_params.call)
    # Log in
    assert_login_as('user1@example.com', 'password')
    # But still no uploading
    post_403('/api/file/upload-new-file', {})
    # But because it's not using an API key, it still can't be uploaded
    multipart_post_403('/api/file/upload-new-file', make_upload_params.call)
  end

  def test_file_upload_api
    upload_params = { :file => fixture_file_upload('files/example.doc', 'application/msword') }
    multipart_post('/api/file/upload-new-file', upload_params, {'X-ONEIS-Key' => @api_key_secret})
    assert_response :success
    assert_equal "success", find_tag(:tag => 'response').attributes['status']
    assert_equal "text/xml; charset=utf-8", response['content-type']

    # Decode the response and check basics look OK
    xml = REXML::Document.new(response.body)
    ref = xml.elements['response/file_reference']
    assert /\A[a-f0-9]{64,64}\z/.match(ref.elements['digest'].text)
    assert /\A[a-f0-9]{64,64}\z/.match(ref.elements['secret'].text)
    assert /\A[a-zA-Z0-9_-]{12,12}\z/.match(ref.elements['tracking_id'].text)
    assert File.size("test/fixtures/files/example.doc").to_s, ref.elements['file_size'].text
    assert ref.elements['filename'].text == 'example.doc'
    assert ref.elements['mime_type'].text == 'application/msword'

    [false,true].each do |mess_up_secret|
      # Change the secret to test the security of file identifiers
      secret = ref.elements['secret'].text
      if mess_up_secret
        # Change the last char to X, which breaks the secret
        secret = secret.gsub(/\w\z/,'X')
      end

      # Make a new object with it in
      builder = Builder::XmlMarkup.new
      builder.instruct!
      builder.request(:identifier => 'TEST') do |req|
        req.operations do |ops|
          ops.create() do |op|
            op.object do |ob|
              ob.attributes do |attrs|
                attrs.a('2134', :d => 'x2', :vt => 0) # type = 'File'
                attrs.a(:d => 'x3', :vt => 16) { |a| a.text 'Uploaded file'} # title attribute
                attrs.a(:d => '9w6', :vt => 27) do |a|
                  a.file_reference do |r|
                    r.digest ref.elements['digest'].text
                    r.file_size ref.elements['file_size'].text
                    r.secret secret
                    r.filename ref.elements['filename'].text
                    r.mime_type ref.elements['mime_type'].text
                    r.tracking_id ref.elements['tracking_id'].text
                    r.log_message ref.elements['log_message'].text if ref.elements['log_message']
                    r.version ref.elements['version']
                  end
                end
              end
            end
          end
        end
      end

      # POST the document
      post '/api/object/batch', builder.target!, {'X-ONEIS-Key' => @api_key_secret}
      assert_response :success
      assert_equal "success", find_tag(:tag => 'response').attributes['status']
      assert_equal "TEST", find_tag(:tag => 'response').attributes['identifier']
      assert_equal "text/xml; charset=utf-8", response['content-type']

      # Check the result - either success or an error depending on whether the secret was changes
      xml = REXML::Document.new(response.body)
      results = xml.elements['response'].children
      assert results != nil
      assert_equal 1, results.length
      assert_equal (mess_up_secret ? 'error' : 'create'), results[0].name
    end
  end

end

