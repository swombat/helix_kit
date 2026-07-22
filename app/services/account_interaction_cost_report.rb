class AccountInteractionCostReport

  DEFAULT_DAY_LIMIT = 30

  def initialize(account:)
    @account = account
  end

  def call
    daily_costs = Hash.new do |dates, date|
      dates[date] = Hash.new { |agents, agent_id| agents[agent_id] = BigDecimal("0") }
    end
    totals = Hash.new { |agents, agent_id| agents[agent_id] = BigDecimal("0") }
    pricing_dates = []

    interactions.find_each do |interaction|
      cost = interaction.estimated_cost
      next unless cost[:amount_usd]

      amount = BigDecimal(cost[:amount_usd])
      date = interaction.started_at.in_time_zone.to_date
      daily_costs[date][interaction.agent_id] += amount
      totals[interaction.agent_id] += amount
      pricing_dates << cost[:pricing_as_of] if cost[:pricing_as_of]
    end

    agents = account.agents.select { |agent| totals.key?(agent.id) }.sort_by { |agent| agent.name.downcase }
    days = daily_costs.sort_by { |date, _| date }.reverse.first(DEFAULT_DAY_LIMIT).map do |date, costs|
      {
        date: date.iso8601,
        agent_costs: agents.to_h do |agent|
          amount = costs[agent.id]
          [ agent.to_param, amount.zero? ? nil : amount.to_s("F") ]
        end,
        total_amount_usd: costs.values.sum.to_s("F")
      }
    end

    {
      agents: agents.map { |agent| { id: agent.to_param, name: agent.name } },
      days: days,
      agent_totals: agents.to_h { |agent| [ agent.to_param, totals[agent.id].to_s("F") ] },
      total_amount_usd: totals.any? ? totals.values.sum.to_s("F") : nil,
      pricing_as_of: pricing_dates.max
    }
  end

  private

  attr_reader :account

  def interactions
    AgentRuntimeInteraction.where(agent_id: account.agent_ids)
  end

end
