class SyncOuraDataJob < ApplicationJob

  queue_as :default

  retry_on OuraApi::Error, wait: :polynomially_longer, attempts: 3

  def perform(oura_integration_id = nil)
    if oura_integration_id
      sync_one(oura_integration_id)
    else
      sync_all
    end
  end

  private

  def sync_one(id)
    OuraIntegration.find(id).sync_health_data!
  rescue OuraApi::Error => e
    Rails.logger.error("Oura sync failed for integration #{id}: #{e.message}")
    raise
  end

  def sync_all
    OuraIntegration.needs_sync.with_valid_tokens.find_each do |integration|
      SyncOuraDataJob.perform_later(integration.id)
    end
  end

end
