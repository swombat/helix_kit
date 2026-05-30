require "test_helper"

class ExternalAgentMemoryAggregationJobTest < ActiveJob::TestCase

  test "daily aggregation defaults to yesterday" do
    job = ExternalAgentMemoryAggregationJob.new

    travel_to Time.zone.local(2026, 5, 30, 12) do
      assert_equal "2026-05-29", job.send(:default_target_for, "daily")
    end
  end

  test "weekly aggregation defaults to the previous week monday" do
    job = ExternalAgentMemoryAggregationJob.new

    travel_to Time.zone.local(2026, 5, 30, 12) do
      assert_equal "2026-05-18", job.send(:default_target_for, "weekly")
    end
  end

  test "monthly aggregation defaults to the previous month" do
    job = ExternalAgentMemoryAggregationJob.new

    travel_to Time.zone.local(2026, 5, 30, 12) do
      assert_equal "2026-04", job.send(:default_target_for, "monthly")
    end
  end

end
