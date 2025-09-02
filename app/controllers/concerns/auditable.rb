module Auditable

  extend ActiveSupport::Concern

  private

  def audit(action, auditable = nil, **data)
    return unless Current.user

    create_audit_log(Current.user, action, auditable, data)
  end

  def audit_as(user, action, auditable = nil, **data)
    create_audit_log(user, action, auditable, data)
  end

  def audit_with_changes(action, record, attributes: nil, **extra_data)
    return unless Current.user

    changed_data = if attributes
      attributes.index_with { |attr|
        [ record.attribute_before_last_save(attr), record.send(attr) ]
      }.compact
    else
      record.saved_changes.transform_values { |values| values }
    end

    data = extra_data.merge(changes: changed_data) if changed_data.present?
    data ||= extra_data

    audit(action, record, **data)
  end

  def create_audit_log(user, action, auditable, data)
    AuditLog.create!(
      user: user,
      account: Current.account,
      action: action,
      auditable: auditable,
      data: data.presence,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

end
