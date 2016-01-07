# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ApplicationNamespace

  # Entries are of the form [type, annotations, hash/class]

  MAIN_MAP = {
    # REMOVE_ON_PROCESS_BEGIN
    "_dev_ctrl_js" => [:controller, {}, DevCtrlJSController],
    # REMOVE_ON_PROCESS_END
    "do" => [:sub, {:do_url => true}, {
        "authentication" => [:controller, {}, AuthenticationController],
        "session"        => [:controller, {}, SessionController],
        "account"        => [:controller, {}, AccountController],
        "tasks"          => [:controller, {}, TasksController],
        "tools"          => [:controller, {}, ToolsController],
        "help"           => [:controller, {}, HelpController],
        "tray"           => [:controller, {}, TrayController],
        "recent"         => [:controller, {}, RecentController],
        "edit"           => [:controller, {}, EditController],
        "display"        => [:controller, {}, DisplayController],
        "latest"         => [:controller, {}, LatestController],
        "unsubscribe"    => [:controller, {}, UnsubscribeController],
        "taxonomy"       => [:controller, {}, TaxonomyController],
        "file"           => [:controller, {}, FileController],
        "file-version"   => [:controller, {}, FileVersionController],
        "system"         => [:controller, {}, SystemController],
        "c"              => [:controller, {}, CopyrightController],
        "generated"      => [:controller, {}, GeneratedFileController],
        "admin"          => [:sub, {}, {
          "audit"          => [:controller, {}, Admin_AuditController],
          "latest"         => [:controller, {}, Admin_LatestController],
          "otp"            => [:controller, {}, Admin_OtpController],
          "user"           => [:controller, {}, Admin_UserController]
        }],
        "setup"          => [:sub, {}, {
          "type"           => [:controller, {}, Setup_TypeController],
          "attribute"      => [:controller, {}, Setup_AttributeController],
          "classification" => [:controller, {}, Setup_ClassificationController],
          "taxonomy"       => [:controller, {}, Setup_TaxonomyController],
          "labels"         => [:controller, {}, Setup_LabelsController],
          "navigation"     => [:controller, {}, Setup_NavigationController],
          "subset"         => [:controller, {}, Setup_SubsetController],
          "keychain"       => [:controller, {}, Setup_KeychainController],
          "plugins"        => [:controller, {}, Setup_PluginsController],
          "schema-requirements" =>
                              [:controller, {}, Setup_SchemaRequirementsController],
          "application"    => [:controller, {}, Setup_ApplicationController],
          "appearance"     => [:controller, {}, Setup_AppearanceController],
          "email_templates"=> [:controller, {}, Setup_EmailTemplatesController]
        }]
      }],
    "api" => [:sub, {:api_url => true}, {
        "authentication" => [:controller, {}, AuthenticationController],
        "object"         => [:controller, {}, ObjectController],
        "display"        => [:controller, {}, DisplayController],
        "search"         => [:controller, {}, SearchController],
        "edit"           => [:controller, {}, EditController],
        "latest"         => [:controller, {}, LatestController],
        "schema"         => [:controller, {}, SchemaController],
        "taxonomy"       => [:controller, {}, TaxonomyController],
        "navigation"     => [:controller, {}, NavigationController],
        "file"           => [:controller, {}, FileController],
        "tray"           => [:controller, {}, TrayController],
        "recent"         => [:controller, {}, RecentController],
        "oforms"         => [:controller, {}, OFormsController],
        "generated"      => [:controller, {}, GeneratedFileController],
        "test"           => [:controller, {}, TestController],
        "admin"          => [:sub, {}, {
          "user"           => [:controller, {}, Admin_UserController]
        }]
      }],
    "file"           => [:controller, {:file_request => true}, FileController],
    "_t"             => [:controller, {:thumbnail_request => true}, FileController],
    "search"         => [:controller, {}, SearchController]
  }.freeze

  # Returns
  #   [rest of path as array, controller class, annotations]
  # Controller may be nil
  def resolve(path)
    # Split path into elements
    elements = path.split('/').select { |e| ! e.empty? }
    annotations = Hash.new
    controller = nil
    if elements.empty?
      annotations[:root_url] = true
      controller = HomeController
    else
      # Use the map to find the URL
      search = MAIN_MAP
      if MAIN_MAP.has_key?(elements.first)
        while controller == nil
          e = elements.shift
          break if e == nil
          action = search[e]
          if action == nil
            controller = KPlugin.controller_for(e, elements, annotations)
            if controller == nil
              elements.unshift e
            end
            break
          end
          # Parse what's at this point in the path
          type, el_annotations, info = action
          annotations.merge!(el_annotations)
          case type
          when :sub
            search = info
          when :controller
            controller = info
          else
            raise "Bad mapping"
          end
        end
      else
        # Not in the main map; look for other things
        if elements.length >= 1 && elements[0] =~ KObjRef::VALIDATE_REGEXP
          annotations[:object_url] = true
          controller = DisplayController
        end
      end
    end
    [elements, controller, annotations].freeze
  end

end

# Return an instance to the application
ApplicationNamespace.new
