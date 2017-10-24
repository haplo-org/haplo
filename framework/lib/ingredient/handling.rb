# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# To use, in the base class:
#
#   extend  Ingredient::Annotations
#   include Ingredient::Handling
#   extend  Ingredient::Handling::ClassMethods
#

module Ingredient
  module Handling

    module ClassMethods
      # Annotations for handler methods
      def _PostOnly
        annotate_method(:_frm_post, :only)
      end
      def _GetAndPost
        annotate_method(:_frm_post, :both)
      end
    end

    # Note: Unlike other parts of the system, handle is a *suffix* because handle_* names are reserved for the handler methods

    def handle(exchange, path_elements)
      @exchange = exchange

      requested_method = url_decode_for_handle(exchange, path_elements)

      exchange.annotations[:request_path] = path_elements
      exchange.annotations[:requested_method] = requested_method

      continue_with_handling = self.pre_handle

      csrf_check(exchange)

      # Only perform the actual handling the pre_handle method allows it
      if continue_with_handling
        begin
          perform_handle(exchange, path_elements, requested_method)
        rescue => e
          # Exception happened during main hander, do something with it
          raise unless exception_during_handle(e)
        end
      end

      self.post_handle
    end

    # Default implementations of callbacks which do nothing
    def pre_handle
      true  # allow handling to continue
    end
    def post_handle
      nil
    end

    # Default implementation of CSRF prevention
    def csrf_check(exchange)
      if exchange.request.post?
        # Requires token to be set, unless:
        # - it's a request for instructions in a file upload
        # - the request is being resumed from suspension (it was checked the first time round and request body no longer available)
        uploads = exchange.annotations[:uploads]
        unless uploads != nil && uploads.getInstructionsRequired()
          if params[:__] != csrf_get_token
            if request.continuation.isInitial()
              raise KFramework::CSRFAttempt
            end
          end
        end
      end
      true
    end
    def csrf_get_token
      raise "csrf_get_token should be implemented"
    end

    # Default rails-style decoding of URLs and paths, with extension method name munging for AP calls
    def url_decode_for_handle(exchange, path_elements)
      requested_method, requested_id = path_elements
      requested_method ||= 'index'
      requested_method = "#{requested_method}_api" if exchange.annotations[:api_url]
      if use_rails_compatible_action_and_id_params?
        exchange.params['action'] = requested_method
        exchange.params['id'] = requested_id unless requested_id == nil
      end
      requested_method
    end

    def use_rails_compatible_action_and_id_params?
      true
    end

    # Default implementation of main handler
    def perform_handle(exchange, path_elements, requested_method)
      method_name = requested_method_to_method_name(requested_method)

      # Security check - is GET and/or POST allowed?
      check_request_method_for(method_name)

      self.__send__(method_name)
    end

    def requested_method_to_method_name(requested_method)
      # Got a list of acceptable methods?
      acceptable_methods = self.class.instance_variable_get(:@_frm_acceptable_methods)
      if acceptable_methods == nil
        # Generate and set the methods
        acceptable_methods = Hash.new
        self.class.instance_methods(false).each do |method_name|
          if method_name =~ /\Ahandle_(.+?)(_api)?\z/
            name = $1; is_api = $2
            acceptable_methods["#{name}#{is_api}"] = method_name
            acceptable_methods["#{name.gsub('_','-')}#{is_api}"] = method_name
          end
        end
        self.class.instance_variable_set(:@_frm_acceptable_methods, acceptable_methods)
      end

      # Check the list of acceptable methods
      method_name = acceptable_methods[requested_method]
      raise KFramework::RequestPathNotFound.new("Unhandled method: #{self.class.name} does not implement handler for #{requested_method} named handle_#{requested_method}") unless method_name != nil

      method_name
    end

    # Check whether GET/POST allowed
    def check_request_method_for(method_name)
      post_allowable = self.class.annotation_get(method_name, :_frm_post)
      case post_allowable
      when nil
        # Only GET allowed
        # NOTE: Message exposed to end users
        raise KFramework::WrongHTTPMethod.new("GET expected") if exchange.request.post?
      when :only
        # NOTE: Message exposed to end users
        raise KFramework::WrongHTTPMethod.new("POST expected") unless exchange.request.post?
      when :both
        # Do nothing
      else
        raise "Bad annotation"
      end
    end

    # Default exception handling returns false to say it didn't handle it
    def exception_during_handle(exception)
      false
    end

    # Some helper methods
    def exchange
      raise JavaScriptAPIError, "No request active" unless @exchange # possible when some standard templates are rendered by a plugin
      @exchange
    end
    def request
      @exchange.request
    end
    def params
      @exchange.params
    end
    def response
      @exchange.response
    end
    def response=(r)
      @exchange.response = r
    end

  end
end

