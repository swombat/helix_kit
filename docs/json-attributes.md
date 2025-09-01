# JSON Attributes Documentation

## Overview

The `json_attributes` concern provides a powerful, declarative way to control how Rails models are serialized to JSON. This is essential for:
- Inertia.js props passed to Svelte components
- API responses
- WebSocket broadcasts
- Any place where models need JSON representation

## Key Features

### 1. Declarative Attribute Selection
Instead of overriding `as_json` in each model with complex logic, you declare what should be included:

```ruby
class User < ApplicationRecord
  include JsonAttributes
  
  # Only these attributes/methods will be in JSON
  json_attributes :full_name, :email_address, :site_admin, 
                  except: [:password_digest, :created_at, :updated_at]
end
```

### 2. Automatic ID Obfuscation
All model IDs are automatically obfuscated using the model's `to_param` method:

```ruby
user = User.find(1)
user.id          # => 1
user.to_param    # => "usr_abc123xyz"
user.as_json     # => { "id" => "usr_abc123xyz", ... }
```

This provides:
- Better security (real IDs aren't exposed)
- Cleaner URLs (`/users/usr_abc123xyz` instead of `/users/1`)
- Consistency across the application

### 3. Boolean Method Handling
Methods ending with `?` automatically have the `?` stripped in JSON:

```ruby
class Account < ApplicationRecord
  json_attributes :personal?, :active?
  
  def personal?
    account_type == "personal"
  end
end

account.as_json # => { "personal" => true, "active" => false }
# Note: not "personal?" or "active?"
```

### 4. Association Support
Include associated models with their own `json_attributes` configuration:

```ruby
class AccountUser < ApplicationRecord
  include JsonAttributes
  
  json_attributes :role, :confirmed_at,
                  include: { 
                    user: {},      # Uses User's json_attributes
                    account: {}    # Uses Account's json_attributes
                  }
end
```

### 5. Context Propagation
Pass context through nested associations for authorization:

```ruby
# In controller
@account.account_users.as_json(current_user: current_user)

# The current_user context flows through to nested associations
# allowing them to customize their output based on who's viewing
```

## Implementation Guide

### Basic Setup

1. **Include the concern in your model:**
```ruby
class Product < ApplicationRecord
  include JsonAttributes
  
  # Define what to include
  json_attributes :name, :price, :in_stock?, :category_name,
                  except: [:internal_cost, :supplier_id]
end
```

2. **Use in controllers:**
```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
    
    render inertia: "products/index", props: {
      products: @products.as_json  # Automatically uses json_attributes
    }
  end
  
  def show
    @product = Product.find(params[:id])
    
    render inertia: "products/show", props: {
      product: @product.as_json(
        include: :reviews,  # Can still add runtime includes
        current_user: current_user  # Pass context
      )
    }
  end
end
```

### Advanced Usage

#### Custom Enhancement Block
Add custom logic to modify the JSON hash:

```ruby
class User < ApplicationRecord
  include JsonAttributes
  
  json_attributes :email_address, :full_name do |hash, options|
    # Add computed properties
    hash[:initials] = full_name.split.map(&:first).join
    
    # Conditional attributes based on context
    if options[:current_user]&.admin?
      hash[:last_login_at] = last_login_at
    end
    
    hash
  end
end
```

#### Nested Association Configuration
Configure how nested associations are serialized:

```ruby
class Order < ApplicationRecord
  include JsonAttributes
  
  json_attributes :order_number, :total, :status,
                  include: {
                    line_items: {
                      include: :product,
                      except: [:internal_notes]
                    },
                    customer: {
                      only: [:name, :email]
                    }
                  }
end
```

#### Runtime Overrides
Override configuration at runtime:

```ruby
# Add additional attributes
@user.as_json(methods: [:additional_method])

# Include specific associations
@account.as_json(include: :recent_activities)

# Combine with configured attributes
@product.as_json(
  include: { reviews: { include: :author } },
  except: [:price]  # Remove a normally included attribute
)
```

## Best Practices

### 1. Security First
Never include sensitive attributes by default:

```ruby
# BAD
json_attributes :email, :password_digest, :api_key

# GOOD
json_attributes :email, except: [:password_digest, :api_key]
```

### 2. Use Methods for Computed Values
Instead of including raw database columns, use methods:

```ruby
class User < ApplicationRecord
  json_attributes :full_name, :display_email  # Not first_name, last_name
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def display_email
    confirmed? ? email_address : "Unconfirmed"
  end
end
```

### 3. Keep It Consistent
All models should use `json_attributes` for predictable behavior:

```ruby
# Every model in the app
class ApplicationRecord < ActiveRecord::Base
  include JsonAttributes if self.name != "ApplicationRecord"
  # ...
end
```

### 4. Document Your Attributes
Add comments explaining what's included and why:

```ruby
class Account < ApplicationRecord
  include JsonAttributes
  
  # Public attributes safe for any user in the account
  json_attributes :name, :slug, :created_at,
                  # Methods that provide computed values
                  :member_count, :active?,
                  # Exclude internal/sensitive fields
                  except: [:stripe_customer_id, :internal_notes]
end
```

## How It Works Internally

The `json_attributes` concern:

1. **Stores Configuration**: The DSL stores your configuration as class attributes
2. **Overrides `serializable_hash`**: Intercepts Rails' serialization
3. **Merges Options**: Combines class configuration with runtime options
4. **Processes Associations**: Ensures nested models use their own `json_attributes`
5. **Cleans Keys**: Removes `?` from boolean method names
6. **Obfuscates IDs**: Replaces `id` with `to_param` value

## Common Patterns

### API Versioning
Different JSON for different API versions:

```ruby
class User < ApplicationRecord
  include JsonAttributes
  
  json_attributes :email, :name  # Default/v2
  
  def as_json_v1(options = {})
    as_json(options.merge(
      only: [:email],  # v1 only had email
      except: [:name]
    ))
  end
end
```

### Role-Based Serialization
Different output based on viewer's role:

```ruby
class Project < ApplicationRecord
  include JsonAttributes
  
  json_attributes :name, :description do |hash, options|
    user = options[:current_user]
    
    if user&.admin? || user&.owns?(self)
      hash[:budget] = budget
      hash[:internal_notes] = internal_notes
    end
    
    hash
  end
end
```

### Partial Loading with Inertia
Optimize what gets reloaded:

```ruby
# Controller
render inertia: "projects/show", props: {
  project: @project.as_json,        # Full project data
  activities: @activities.as_json,   # Activities list
  stats: -> { @project.stats }      # Lazy-loaded, only when needed
}

# When project broadcasts changes, only project prop reloads
# Activities and stats remain unchanged unless specifically requested
```

## Testing

Test your json_attributes configuration:

```ruby
class UserTest < ActiveSupport::TestCase
  test "json_attributes includes expected fields" do
    user = users(:alice)
    json = user.as_json
    
    # ID is obfuscated
    assert_equal user.to_param, json["id"]
    
    # Included attributes are present
    assert json.key?("full_name")
    assert json.key?("email_address")
    
    # Excluded attributes are not present
    assert_not json.key?("password_digest")
    
    # Boolean methods have ? removed
    assert json.key?("site_admin")  # not "site_admin?"
  end
  
  test "json_attributes with associations" do
    account = accounts(:acme)
    json = account.as_json(include: :users)
    
    assert json["users"].is_a?(Array)
    assert_equal account.users.count, json["users"].length
    
    # Nested users use their own json_attributes
    assert json["users"].first.key?("full_name")
    assert_not json["users"].first.key?("password_digest")
  end
end
```

## Troubleshooting

### Attributes Missing from JSON
Check that they're included in `json_attributes`:
```ruby
json_attributes :missing_attribute  # Add it here
```

### Sensitive Data Appearing
Explicitly exclude it:
```ruby
json_attributes :safe_attr, except: [:sensitive_attr]
```

### Association Not Using json_attributes
Ensure the associated model includes the concern:
```ruby
class AssociatedModel < ApplicationRecord
  include JsonAttributes  # Required!
  json_attributes :whatever
end
```

### ID Not Being Obfuscated
Ensure your model has `to_param` defined (usually via `obfuscates_id` concern):
```ruby
class MyModel < ApplicationRecord
  include ObfuscatesId
  include JsonAttributes
end
```

## Integration with Other Systems

### Works With Synchronization
The real-time sync system uses `as_json` internally, so `json_attributes` automatically applies:

```ruby
class Account < ApplicationRecord
  include Broadcastable
  include JsonAttributes
  
  json_attributes :name, :active?
  broadcasts_to :all
  
  # When broadcast triggers a reload, the reloaded props
  # will use the json_attributes configuration
end
```

### Works With Inertia Partial Reloads
Props defined with `json_attributes` work seamlessly with partial reloads:

```ruby
# Only the 'account' prop reloads, using json_attributes
Inertia.partial('account')
```

### Works With ActiveModel Serializers
Can be used alongside or instead of AMS:

```ruby
# Use json_attributes for simple cases
render json: @users

# Use AMS for complex API responses
render json: @users, each_serializer: Api::V2::UserSerializer
```