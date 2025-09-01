class DocumentationController < ApplicationController

  skip_before_action :require_authentication

  def index
    render inertia: "documentation", props: {}
  end

end
