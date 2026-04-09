class FaviconController < ApplicationController

  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication

  def show
    format = params[:format] || "png"
    svg_path = Rails.root.join("app", "assets", "images", "helix-kit-logo.svg")
    temp_file = nil

    case format
    when "svg"
      send_file svg_path, type: "image/svg+xml", disposition: "inline"
    when "png", "ico"
      temp_file = Tempfile.new([ "favicon", ".png" ])

      if system("which", "rsvg-convert", out: File::NULL, err: File::NULL) &&
          system("rsvg-convert", "-w", "32", "-h", "32", "-f", "png", "-o", temp_file.path, svg_path.to_s)
        send_file temp_file.path, type: "image/png", disposition: "inline"
      else
        send_file svg_path, type: "image/svg+xml", disposition: "inline"
      end
    else
      head :not_found
    end
  ensure
    temp_file&.close
    temp_file&.unlink
  end

end
