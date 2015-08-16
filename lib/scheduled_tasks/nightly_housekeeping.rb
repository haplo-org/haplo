# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KScheduledTasks

  KFramework.scheduled_task_register(
    "housekeeping", "Nightly housekeeping",
    3, 0, KFramework::SECONDS_IN_DAY,   # Once a day at 3am
    proc { KScheduledTasks.nightly_housekeeping }
  )

  def self.nightly_housekeeping_exception_catcher
    begin
      yield
    rescue => e
      KApp.logger.log_exception(e)
      KApp.logger.flush_buffered
    end
  end

  def self.nightly_housekeeping

    # Remove any old temporary data
    KApp.in_application(:no_app) do
      KTempDataStore.delete_old_data
    end

    # Go through the applications and report usage back to kmanager
    usage_message = Array.new
    objects_counter_index = KAccounting::COUNTER_NAMES.index(:objects)
    storage_counter_index = KAccounting::COUNTER_NAMES.index(:storage)
    KApp.in_every_application do
      nightly_housekeeping_exception_catcher do

        # Get counters of usage
        counters = KAccounting::COUNTER_NAMES.map { |e| KAccounting.get(e) }
        counters[objects_counter_index] -= KApp.global(:limit_init_objects)   # Don't include the objects created during app init
        counters[storage_counter_index] /= (1024*1024)                        # Convert to MB, rounding down
        # prepend the user count and current time
        counters.unshift KProduct.count_users()
        counters.unshift Time.now.to_i
        # Add an update for this app
        usage_message << [KApp.current_application, 'use', counters]

      end
    end

    # Send the update message (but only if there's a management server)
    if KFRAMEWORK_IS_MANAGED_SERVER && KManagementServer.have_management_server?
      KMessageQueuing.spool_message(KManagementServer.hostname, :app_update, usage_message)
    end

    # Decrement the event counters once it has been queued without error
    usage_message.each do |app_id, use, counters|
      # Switch to the app
      KApp.in_application(app_id) do
        nightly_housekeeping_exception_catcher do

          # Remove the user count and time
          counters.shift ; counters.shift
          # Do counter decrementing - just zeroing a counter wouldn't be accurate
          0.upto(KAccounting::COUNTER_NAMES.length - 1) do |i|
            if KAccounting::COUNTER_TYPES[i] == :event
              # Decrement this counter by the value just sent to kmanager
              KAccounting.add(KAccounting::COUNTER_NAMES[i], 0 - counters[i])
            end
          end

        end
      end
    end
  end

end

