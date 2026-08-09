class AccountAgentCredentialsRefreshJob < ApplicationJob

  queue_as :default

  retry_on Agents::Sandbox::SandboxError, wait: 5.minutes, attempts: 3

  def perform(account_id, agent_id = nil)
    account = Account.find(account_id)
    scope = account.agents.externally_hosted
    scope = scope.where(id: agent_id) if agent_id.present?

    scope.where.not(container_name: nil).find_each do |agent|
      sandbox = Agents::Sandbox.new(agent)

      if sandbox.active_turn?
        self.class.set(wait: 5.minutes).perform_later(account.id, agent.id)
      else
        sandbox.recreate!
        mark_service_accesses_reconciled!(agent)
      end
    end
  end

  private

  def mark_service_accesses_reconciled!(agent)
    agent.agent_service_accesses.includes(:service_connection).find_each do |access|
      if access.enabled?
        access.mark_provisioned!
      else
        access.update!(
          provisioned_revision: nil,
          provisioned_at: Time.current,
          provisioning_status: "removed",
          provisioning_error_code: nil
        )
      end
    end
  end

end
