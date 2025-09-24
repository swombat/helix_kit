class SyncChannel < ApplicationCable::Channel

  def subscribed
    debug "📡 Attempting to subscribe to #{params[:model]}:#{params[:id]}"

    return reject_for_reason("params[:model] is not present") unless params[:model]

    model_class = params[:model].safe_constantize
    return reject_for_reason("model_class is not present") unless model_class

    return reject_for_reason("params[:id] is not present") unless params[:id].present?

    if params[:id] == "all"
      return reject_for_reason("current_user.site_admin is false") unless current_user.site_admin
      stream_from "#{params[:model]}:all"
    end

    @model = model_class.find_by_obfuscated_id(params[:id].split(":")[0])
    return reject_for_reason("model is not present") unless @model

    return reject_for_reason("model is not accessible by current_user") unless @model.accessible_by?(current_user)

    if params[:id].include?(":")
      setup_collection_subscription
    else
      stream_from "#{params[:model]}:#{params[:id]}"
    end
  end

  def setup_collection_subscription
    collection = @model.send(params[:id].split(":")[1])
    return reject_for_reason("collection is not present") unless collection

    return reject_for_reason("collection is empty") unless collection.any?

    debug "📡 Streaming collection items (#{collection.first.class.name}: #{collection.count} items)"

    collection.each do |record|
      stream_from "#{record.class.name}:#{record.obfuscated_id}"
    end
  end

  def reject_for_reason(reason)
    debug "📡 ❌ Rejecting subscription for #{params[:model]}:#{params[:id]} because #{reason}"
    reject
  end

  def stream_from(identifier)
    debug "📡 ✅ Streaming #{identifier}"
    super(identifier)
  end

  def unsubscribed
    debug "📡 ❌ Unsubscribed from all"
    stop_all_streams
  end

end
