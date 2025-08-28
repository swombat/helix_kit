class FaviconController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication

  def show
    format = params[:format] || "png"

    # Path to the SVG file
    svg_path = Rails.root.join("app", "assets", "images", "helix-kit-logo.svg")

    case format
    when "svg"
      send_file svg_path, type: "image/svg+xml", disposition: "inline"
    when "png", "ico"
      # For now, let's use rsvg-convert if available, otherwise fall back to sending SVG
      temp_file = Tempfile.new([ "favicon", ".png" ])

      # Try to convert using rsvg-convert which handles SVG better
      if system("which rsvg-convert > /dev/null 2>&1")
        system("rsvg-convert -w 32 -h 32 -f png -o #{temp_file.path} #{svg_path}")
        send_file temp_file.path, type: "image/png", disposition: "inline"
      else
        # Fallback: send the SVG file
        send_file svg_path, type: "image/svg+xml", disposition: "inline"
      end

      temp_file.close
    else
      head :not_found
    end
  end
end
