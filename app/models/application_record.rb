class ApplicationRecord < ActiveRecord::Base

  include ObfuscatesId

  primary_abstract_class

  def as_json(options = {})
    hash = super(options)
    hash["id"] = to_param
    hash
  end

end
