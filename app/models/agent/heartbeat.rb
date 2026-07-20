module Agent::Heartbeat

  extend ActiveSupport::Concern

  SLOTS_PER_DAY = 48

  def heartbeat_wake_due_at?(time)
    heartbeat_wake_slots.include?(heartbeat_slot_at(time))
  end

  private

  def heartbeat_wake_slots
    return [ SLOTS_PER_DAY / 2 ] if heartbeat_wakes_per_day == 1

    heartbeat_wakes_per_day.times.map do |wake_index|
      wake_index * SLOTS_PER_DAY / heartbeat_wakes_per_day
    end
  end

  def heartbeat_slot_at(time)
    utc = time.utc
    (utc.hour * 2) + (utc.min / 30)
  end

end
