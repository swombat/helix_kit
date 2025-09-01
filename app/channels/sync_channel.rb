class SyncChannel < ApplicationCable::Channel

  def subscribed
    return reject unless params[:model]

    model_class = params[:model].safe_constantize
    return reject unless model_class

    if params[:id] == "all"
      # Collection subscription - only for admins
      if current_user.site_admin
        stream_from "#{params[:model]}:all"
      else
        reject
      end
    elsif params[:id]
      # Single object subscription
      if model_class.respond_to?(:accessible_by)
        record = model_class.accessible_by(current_user)
                           .find_by_obfuscated_id(params[:id])
        if record
          stream_from "#{params[:model]}:#{params[:id]}"
        else
          reject
        end
      else
        reject
      end
    else
      reject
    end
  end

end
