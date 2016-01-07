# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  HOOKS = Hash.new

  class Definer
    def initialize(name)
      @name = name
      @runner = Class.new(KPlugin::HookSite::HookRunner)
      @runner.instance_variable_set(:@_NAME, name)  # so name can be retrieved
      @response = Class.new(KPlugin::HookSite::HookResponse)
      @response_init = ''
      @run_arguments = []
      @js_call_index = 0
      @js_call_args = ''
      @response_fields = Java::ComOneisJsinterface::KPluginResponse::Fields.new
      @response_in = ""
      @response_out = ""
    end

    def private_hook
      # Ignored by application, but stops it from appearing in the documentation
    end

    def description(desc)
    end

    def argument(name, klass, description)
      @run_arguments << name
      # Build the JavaScript hook caller array
      if klass.equal?(String) || klass.equal?(Symbol)
        @js_call_args << %Q!, args[#{@js_call_index}].to_s.to_java_string()!
      elsif klass.equal?(Fixnum)
        @js_call_args << %Q!, args[#{@js_call_index}].to_i!
      elsif klass.equal?(KObject)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KObject.fromAppObject(args[#{@js_call_index}], false))!
      elsif klass.equal?(KObjRef)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KObjRef.fromAppObjRef(args[#{@js_call_index}]))!
      elsif klass.equal?(WorkUnit)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KWorkUnit.fromAppWorkUnit(args[#{@js_call_index}]))!
      elsif klass.equal?(User)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KUser.fromAppUser(args[#{@js_call_index}]))!
      elsif klass.equal?(AuditEntry)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KAuditEntry.fromAppAuditEntry(args[#{@js_call_index}]))!
      elsif klass.equal?(StoredFile)
        @js_call_args << %Q!, ((args[#{@js_call_index}] == nil) ? nil : Java::ComOneisJsinterface::KStoredFile.fromAppStoredFile(args[#{@js_call_index}]))!
      elsif klass == "bool"
        @js_call_args << %Q@, !!(args[#{@js_call_index}])@
      else
        raise "Hook #{@name} defined with unsupported argument class #{klass.name}"
      end
      @js_call_index += 1
    end

    def result(name, klass, default_value, description)
      if default_value != nil
        @response_init << "@#{name} = #{default_value}\n"
      end
      if klass.equal?(String)
        @response_fields.stringField(name, false) # isn't a symbol
        @response_in << "j.putR('#{name}',r.#{name}.to_java_string) if r.#{name} != nil\n"
        @response_out << "r.#{name} = j.getR('#{name}')\n"
      elsif klass.equal?(Symbol)
        @response_fields.stringField(name, true)  # is symbol
        @response_in << "j.putR('#{name}',r.#{name}.to_s.to_java_string) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : v.to_sym\n"
      elsif klass.equal?(Fixnum)
        @response_fields.integerField(name)
        @response_in << "j.putR('#{name}',java.lang.Integer.new(r.#{name})) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : v.to_i\n"
      elsif klass == "bool"
        @response_fields.booleanField(name)
        @response_in << "j.putR('#{name}',r.#{name} ? java.lang.Boolean::TRUE : java.lang.Boolean::FALSE) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : (v ? true : false)\n"
      elsif klass.equal?(Array)
        @response_fields.arrayField(name)
        @response_in << "j.putR('#{name}',KHooks.structure_r_to_j(r.#{name})) if r.#{name} != nil\n"
        @response_out << "r.#{name} = KHooks.structure_j_to_r(j.getRJSON('#{name}'), Array)\n"
      elsif klass.equal?(Hash)
        @response_fields.hashField(name)
        @response_in << "j.putR('#{name}',KHooks.structure_r_to_j(r.#{name})) if r.#{name} != nil\n"
        @response_out << "r.#{name} = KHooks.structure_j_to_r(j.getRJSON('#{name}'), Hash)\n"
      elsif klass.equal?(KObject)
        @response_fields.kobjectField(name)
        @response_in << "j.putR('#{name}',Java::ComOneisJsinterface::KObject.fromAppObject(r.#{name},false)) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : Java::ComOneisJsinterface::KObject.toHookResponseAppValue(v)\n"
      elsif klass.equal?(KLabelChanges)
        @response_fields.labelChangesField(name)
        @response_in << "j.putR('#{name}',Java::ComOneisJsinterface::KLabelChanges.fromAppLabelChanges(r.#{name})) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : v.toRubyObject()\n"
      elsif klass.equal?(KLabelStatements)
        @response_fields.labelStatementsField(name)
        @response_in << "j.putR('#{name}',Java::ComOneisJsinterface::KLabelStatements.fromAppLabelStatements(r.#{name})) if r.#{name} != nil\n"
        @response_out << "v = j.getR('#{name}'); r.#{name} = (v == nil) ? nil : v.toRubyObject()\n"
      elsif klass.kind_of?(String) && klass =~ /\Ajs:(.+?)\z/
        @response_fields.hashField(name)
        @response_in << "j.putConstructedJSObject('#{name}','$#{$1}')\n"
        @response_out << "r.#{name} = KHooks.structure_j_to_r(j.getRJSON('#{name}'), Hash)\n"
      else
        raise "Hook #{@name} defined with unsupported result class #{klass.name}"
      end
      @response.send(:attr_accessor, name)
    end

    def define
      @response_fields.finishDescription()
      @runner.instance_variable_set(:@_RESPONSE_FIELDS, @response_fields)
      # Define JavaScript argument conversion method
      @runner.module_eval(%Q!def jsargs(hook_name, response, args); [hook_name, response #{@js_call_args}]; end!, "#{@name}-jsargs")
      # Define initialiser for response, if it has any default values
      unless @response_init.empty?
        @response.module_eval("def initialize\n#{@response_init}\nend", "#{@name}-init")
      end
      # Define conversion to JavaScript for response
      @runner.module_eval(%Q!def response_r_to_j(r,j)\n#{@response_in}\nend!, "#{@name}-r-to-j")
      # Define conversion from JavaScript for response
      @runner.module_eval(%Q!def response_j_to_r(r,j)\n#{@response_out}\nend!, "#{@name}-j-to-r")
      # Define run method - use actual arguments rather than a *args so that the number of arguments is checked by the runtime.
      arglist = @run_arguments.join(',')
      @runner.module_eval("def run(#{arglist})\nrun2([#{arglist}])\nend", "#{@name}-run")
      # Set the class of the response in the runner
      @runner.instance_variable_set(:@_RESPONSE, @response)
      # Define the runner class in the KHooks module to give it a name
      class_const_name = "#{@name}Runner"
      class_const_name[0] = class_const_name[0,1].upcase
      KHooks.const_set(class_const_name, @runner)
      # And give the response class a name within the runner class
      @runner.const_set(:Response, @response)
      HOOKS[@name] = @runner
    end
  end

  def self.define_hook(name)
    h = Definer.new(name)
    yield h
    h.define
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Conversion of nested data structures
  # TODO: Consider whether there are faster ways of converting structures than using JSON as an intermediate format.
  # TODO: Prevent plugins from sending lots of data to and from the Ruby host, to avoid using up lots of memory.

  JSON_NULL = 'null'

  def self.structure_r_to_j(ruby_structure)
    return nil if ruby_structure == nil
    json = ruby_structure.to_json()
    parser = KJSPluginRuntime.current.make_json_parser
    parser.parseValue(json)
  end

  def self.structure_j_to_r(json, root_class)
    return nil if json == nil || json == JSON_NULL
    r = JSON.parse(json)
    return nil if r == nil
    raise "When converting from JavaScript data structure, #{root_class.name} expected, but got #{r.class.name}" unless r.kind_of?(root_class)
    r
  end

end
