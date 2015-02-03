# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Define some classes so hook definitions will load
class KObjRef; end
class KObject; end
class WorkUnit; end
class AuditEntry; end
class User; end
class KLabelChanges; end
class KLabelStatements; end
class StoredFile; end

class HookNode < DocNodeTextile
  def body_textile
    # Append HTML for the arguments etc to the end of the node
    html = super
    d = KHooks::LOOKUP[self.name]
    "#{html}\n\n#{d.to_textile}"
  end
end

module KHooks
  class DocDefiner
    attr_accessor :name
    attr_accessor :private

    def initialize(name, node_name)
      @name = name
      @node_name = node_name
      @arguments = ''
      @fn_args = ['response']
      @results = ''
    end

    def private_hook
      @private = true
    end

    def argument(name, klass, description)
      @arguments << %Q!|@#{name}@|#{klass_to_name(klass)}|#{description.gsub(/[\r\n]+/,' ')}|\n!
      @fn_args << name
    end

    def result(name, klass, default_value, description)
      @first_result_name = name unless @first_result_name
      @results << %Q!|@#{name}@|#{klass_to_name(klass)}|#{description.gsub(/[\r\n]+/,' ')}|\n!
    end

    def klass_to_name(klass)
      if klass.kind_of?(String) && klass =~ /\Ajs:(.+)\z/
        "[node:dev/plugin/interface/#{$1.gsub(/([a-z0-9])([A-Z])/,'\\1-\\2').downcase}]"
      elsif klass == Symbol
        "@String@"
      elsif klass == "bool"
        "boolean"
      elsif klass == Fixnum
        "number"
      elsif klass == KObjRef
        "[node:dev/plugin/interface/ref]"
      elsif klass == KObject
        "[node:dev/plugin/interface/store-object]"
      elsif klass == WorkUnit
        "[node:dev/plugin/interface/work-unit]"
      elsif klass == AuditEntry
        "[node:dev/plugin/interface/audit-entry]"
      elsif klass == User
        "[node:dev/plugin/interface/security-principal]"
      elsif klass == KLabelChanges
        "[node:dev/plugin/interface/label-changes]"
      elsif klass == KLabelStatements
        "[node:dev/plugin/interface/label-statements]"
      elsif klass == StoredFile
        "[node:dev/plugin/interface/file]"
      elsif klass == Hash
        "@Object@ (as dictionary)"
      else
        %Q!@#{klass.name.to_s}@!
      end
    end

    def to_textile
      textile = ''
      if @arguments.empty?
        textile << "h3. Arguments\n\nThis hook does not take any arguments.\n\n"
      else
        textile << "h3. Arguments\n\n|*Name*|*Type*|*Description*|\n#{@arguments}\n\n"
      end
      if @results.empty?
        textile << "h3. Response\n\nNo data is returned in the @response@ object.\n\n"
      else
        textile << "h3. Response\n\nReturn information by changing these properties of the @response@ object.\n\n|*Name*|*Type*|*Description*|\n#{@results}\n\n"
      end
      textile << <<__E
h3. JavaScript template

<pre>

P.hook('#{@name}', function(#{@fn_args.join(', ')}) {
    // Respond to hook#{@first_result_name ? ", for example\n    // response.#{@first_result_name} = ..." : ""}
});
</pre>


__E
      textile
    end

    def make_node
      HookNode.new(@node_name, self)
    end
  end

  LOOKUP = {}

  def self.define_hook(name)
    node_name = name.to_s.gsub(/\Ah/,'').gsub(/([a-z0-9])([A-Z])/,'\\1-\\2').downcase
    h = DocDefiner.new(name, node_name)
    yield h
    unless h.private
      # Store the node definition for later
      LOOKUP[node_name] = h
      # Check the description file exists
      node_filename = "doc/root/050-dev/020-plugin/090-hook/#{node_name}.txt"
      unless File.exist?(node_filename)
        raise "Expected to find a #{node_filename} for hook"
      end
    end
  end
end

# Load all the hook definitions, creating nodes
Dir.glob("app/hooks/**/*.rb") do |hook_defn|
  require hook_defn
end
