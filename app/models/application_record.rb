class ApplicationRecord < ActiveRecord::Base

  include ObfuscatesId

  primary_abstract_class

end
