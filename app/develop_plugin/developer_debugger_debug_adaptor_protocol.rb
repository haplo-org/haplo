# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DebugAdaptorProtocol

  def self.start_for_current_application(plugin_locations)
    raise "Bad plugin_locations" unless plugin_locations.kind_of?(Hash)
    dap = DebugAdaptorProtocol.new(plugin_locations)
    factory = Java::OrgHaploJavascriptDebugger::Debugger::Factory.new(dap)
    dap.factory = factory
    Java::OrgHaploJavascriptDebugger::Debug.setFactoryForApplication(KApp.current_application, factory)
    KJSPluginRuntime.invalidate_all_runtimes
    dap
  end

  def self.get_for_current_application
    factory = Java::OrgHaploJavascriptDebugger::Debug.getFactoryForApplication(KApp.current_application)
    if factory && factory.kind_of?(Java::OrgHaploJavascriptDebugger::Debugger::Factory)
      return factory.getDAP()
    end
    nil
  end

  def self.stop_for_current_application
    factory = Java::OrgHaploJavascriptDebugger::Debug.getFactoryForApplication(KApp.current_application)
    if factory && factory.kind_of?(Java::OrgHaploJavascriptDebugger::Debugger::Factory)
      Java::OrgHaploJavascriptDebugger::Debug.setFactoryForApplication(KApp.current_application, nil)
      KJSPluginRuntime.invalidate_all_runtimes
    end
  end

  # -------------------------------------------------------------------------

  def initialize(plugin_locations)
    @factory = nil
    @token = KRandom.random_api_key
    @plugin_locations = plugin_locations
    @max_threads = 0
  end

  attr_accessor :factory
  attr_reader :token

  def _dap_path_to_runtime_path_maybe(path)
    @plugin_locations.each do |pn, pp|
      if path.start_with?(pp)
        return "p/#{pn}#{path.delete_prefix(pp)}"
      end
    end
    nil
  end

  def _runtime_path_to_dap_path_maybe(path)
    if path =~ /\Ap\/(\w+)\/(.+?)\/([^\/]+)\z/
      [$3, "#{@plugin_locations[$1]}/#{$2}/#{$3}"]
    else
      []
    end
  end

  def handle(message)
    type = message['type']
    command = message['command']
    if type == 'request'
      case command
      when 'initialize'
        return handle_initialize(message)
      when 'attach'
        return handle_attach(message)
      when 'setBreakpoints'
        return handle_set_breakpoints(message)
      when 'setExceptionBreakpoints'
        return handle_set_exception_breakpoints(message)
      when 'threads'
        return handle_threads(message)
      when 'stackTrace'
        return handle_stack_trace(message)
      when 'scopes'
        return handle_scopes(message)
      when 'variables'
        return handle_variables(message)
      when 'continue'
        return handle_continue(message)
      when 'next', 'stepIn', 'stepOut'
        return handle_generic_step(message)
      when 'pause'
        return handle_pause(message)
      when 'evaluate'
        return handle_evaluate(message)
      when 'disconnect', 'terminate'
        return handle_terminate(message)
      else
        KApp.logger.info("DAP: Unknown command: #{command}")
        return []
      end
    end
  end

  def _response_for(message, props)
    return {
      "type" => "response",
      "request_seq" => message['seq'],
      "success" => true,
      "command" => message['command'],
    }.merge(props)
  end

  def handle_initialize(message)
    return [_response_for(message, {
      "body" => {
        "supportsFunctionBreakpoints" => false,
        "supportsConditionalBreakpoints" => false,
        "supportsHitConditionalBreakpoints" => false,
        "supportsEvaluateForHovers" => false,
        "exceptionBreakpointFilters" => []
      }
    }), {
      "type": "event",
      "event": "initialized"
    }]
  end

  def handle_attach(message)
    return [_response_for(message, {})]
  end

  def handle_set_breakpoints(message)
    dap_path = message['arguments']['source']['path']
    runtime_path = _dap_path_to_runtime_path_maybe(dap_path)
    if runtime_path
      lines = []
      message['arguments']['breakpoints'].each do |bp|
        lines.push(bp['line'].to_i)
      end
      @factory.setBreakpoints(runtime_path, lines)
      [_response_for(message, {
        "body" => {
          # TODO: Don't pretend all breakpoints are verified
          "breakpoints": lines.map { |l| {"line" => l, "verified" => true} }
        }
      })]
    else
      []
    end
  end

  def handle_set_exception_breakpoints(message)
    @factory.setBreakOnExceptions(true)  
    [_response_for(message, {})]
  end

  def handle_threads(message)
    threads = []
    0.upto(@max_threads) do |id|
      suffix = ''
      thread = @factory.getThread(id)
      if thread
        suffix = thread.getIsHandlingRequest() ? ' (request)' : ' (background)'
      end
      threads.push({"id" => id, "name" => "Runtime #{id}#{suffix}"})
    end
    [_response_for(message, {
      "body" => {
        "threads" => threads
      }
    })]
  end

  def handle_stack_trace(message)
    debugger = @factory.getThread(message['arguments']['threadId'])
    # TODO: Check thread is stopped

    unless debugger
      return [_response_for(message, {
        "body" => {
          "stackFrames" => [],
          "totalFrames": 0
        }
      })]
    end

    # Get frames from debugger
    frames = []
    f = debugger.getCurrentFrame()
    while f != nil
      frames << f
      f = f.getParentFrame()
    end

    # page from arguments
    start_frame = message['arguments']['startFrame'] || 0
    levels = message['arguments']['levels'] || 0
    send_frames = if levels == 0
      frames
    else
      frames.slice(start_frame, levels)
    end

    [_response_for(message, {
      "body" => {
        "stackFrames" => send_frames.map do |frame|
          file_name, dap_path = _runtime_path_to_dap_path_maybe(frame.getFilename())
          fr = {
            "id" => frame.getFrameId(),
            "name" => frame.getFrameName() || "(anon)",
            "line" => frame.getLastExecutedLine(),
            "column" => 0
          }
          if dap_path
            fr['source'] = {
              "name" => file_name,
              "path" => dap_path
            }
          else
            fr['source'] = {"name" => "<internal>"}
          end
          fr
        end,
        "totalFrames": frames.length
      }
    })]
  end

  def handle_scopes(message)
    # Send a message back with scopes having IDs based on the frame requested
    base_id = message['arguments']['frameId'] * 4
    [_response_for(message, {
      "body" => {
        "scopes" => [
          {
            "name" => "Locals",
            "presentationHint" => "locals",
            "variablesReference": base_id + 1
          },
          {
            "name" => "Arguments",
            "presentationHint" => "arguments",
            "variablesReference": base_id + 0
          }
        ]
      }
    })]
  end

  def handle_variables(message)
    # Variables requests queued for execution in the runtime's thread
    response = _response_for(message, {
      "body" => {"variables" => []}
    })
    scope_id = message['arguments']['variablesReference']
    frame_id = scope_id / 4
    scope_kind = scope_id % 4
    debugger = @factory.findStoppedDebuggerWithFrameId(frame_id)
    if debugger
      debugger.queueVariablesRequest(frame_id, scope_kind, response)
    end
    []
  end

  def handle_continue(message)
    @factory.continueExecution(message['arguments']['threadId'])
    [_response_for(message, {
      "body" => {
        "allThreadsContinued" => false
      }
    })]
  end

  def handle_generic_step(message)
    @factory.stepExecution(message['arguments']['threadId'], message['command'])
    [_response_for(message, {})]
  end

  def handle_pause(message)
    thread_id = message['arguments']['threadId']
    if thread_id
      thread = @factory.getThread(thread_id)
      thread.pauseExecution() if thread
    else
      @factory.pauseAllExecution()
    end
    [_response_for(message, {})]
  end

  def handle_evaluate(message)
    args = message['arguments']
    frame_id = args['frameId']
    debugger = frame_id ? @factory.findStoppedDebuggerWithFrameId(frame_id) : nil
    unless frame_id && debugger && (args['context'] == 'repl')
      return [_response_for(message, {
        "body" => {
          "result" => "(Evaluation is not currently supported in this context. Try again when execution is paused.)"
        }
      })]
    end
    debugger.queueEvaluateRequest(frame_id, args['expression'], _response_for(message, {}))
    []
  end

  def handle_terminate(message)
    @factory.terminateAll()
    org.haplo.javascript.debugger.Debug.setFactoryForApplication(KApp.current_application, nil)
    KJSPluginRuntime.invalidate_all_runtimes
    [_response_for(message, {})]
  end

  # -------------------------------------------------------------------------

  def _send_initiated_message(message)
    DeveloperLoader.broadcast_notification('DAP1', JSON.generate(message))
  end

  # -------------------------------------------------------------------------
  #    Implementation of the RubyInterface for the DAP
  # -------------------------------------------------------------------------

  def currentThreadIsHandlingHTTPRequest()
    nil != KFramework.request_context
  end

  def newMaximumThreadId(maxThreadId)
    @max_threads = maxThreadId
    _send_initiated_message({
      "type" => "event",
      "event" => "thread",
      "body" => {
        "reason": "started",
        "threadId": maxThreadId
      }
    })
  end

  def reportStopped(threadId, reason, text)
    m = {
      "type" => "event",
      "event" => "stopped",
      "body" => {
        "reason": reason,
        "threadId": threadId
      }
    }
    if text
      m['body']['text'] = text
    end
    _send_initiated_message(m)
  end

  def addVariableToVariablesResponse(response, name, value)
    response['body']['variables'].push({
      "name" => name,
      "value" => value,
      "variablesReference" => 0
    })
  end

  def sendVariablesResponse(response)
    _send_initiated_message(response)
  end

  def sendEvaluateResponse(response, result)
    response["body"] = {"result" => result}
    _send_initiated_message(response)
  end

  def sendTerminatedEvent()
    _send_initiated_message({
      "type" => "event",
      "event" => "terminated"
    })
  end

end
