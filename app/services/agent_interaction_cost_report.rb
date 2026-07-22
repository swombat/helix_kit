class AgentInteractionCostReport

  DEFAULT_DAY_LIMIT = 30

  def initialize(agent:)
    @agent = agent
  end

  def call
    daily_costs = Hash.new { |hash, date| hash[date] = { amount: BigDecimal("0"), interaction_count: 0 } }
    pricing_dates = []
    interaction_count = 0

    agent.agent_runtime_interactions.find_each do |interaction|
      cost = interaction.estimated_cost
      next unless cost[:amount_usd]

      date = interaction.started_at.in_time_zone.to_date
      daily_costs[date][:amount] += BigDecimal(cost[:amount_usd])
      daily_costs[date][:interaction_count] += 1
      interaction_count += 1
      pricing_dates << cost[:pricing_as_of] if cost[:pricing_as_of]
    end

    days = daily_costs.sort_by { |date, _| date }.reverse.first(DEFAULT_DAY_LIMIT).map do |date, values|
      {
        date: date.iso8601,
        amount_usd: values[:amount].to_s("F"),
        interaction_count: values[:interaction_count]
      }
    end

    {
      total_amount_usd: days.any? ? daily_costs.values.sum { |values| values[:amount] }.to_s("F") : nil,
      interaction_count: interaction_count,
      pricing_as_of: pricing_dates.max,
      days: days
    }
  end

  private

  attr_reader :agent

end
