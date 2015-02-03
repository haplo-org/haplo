module ActiveRecord
  class LogSubscriber
    def sql(event)
      return unless logger.debug?
      name = '%s (%.1fms)' % [event.payload[:name], event.duration]
      sql  = event.payload[:sql].squeeze(' ')
      debug "  #{name}  #{sql}"
    end
  end
end
