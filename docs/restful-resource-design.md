# RESTful Resource Design: The 37signals Way

## Philosophy

At 37signals, we model web endpoints as CRUD operations on resources. This is not just a style preference—it's a fundamental architectural decision that shapes how we build Rails applications. When you embrace truly RESTful routes, you get small, cohesive controllers by design. This isn't something you have to fight for; it comes naturally from thinking in resources.

The approach plays beautifully with how HTTP works. Resources are nouns. HTTP verbs (GET, POST, PATCH, DELETE) are the actions. Together, they express intent clearly and unambiguously.

## The Core Pattern: Resources as Nouns with Verbs

Every endpoint in Fizzy follows this pattern. When you want to close a card, you don't add a custom action called `close` to the cards controller. Instead, you create a `closure` resource:

```ruby
# routes.rb
resources :cards do
  resource :closure  # singular - a card has one closure state
end
```

```ruby
# app/controllers/cards/closures_controller.rb
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.reopen

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

Look at what happened here:
- `POST /cards/:id/closure` closes the card
- `DELETE /cards/:id/closure` reopens the card

The controller is laser-focused. It does one thing: manage the closure state of a card. Nine lines of actual code, and the entire lifecycle is expressed through standard HTTP verbs.

## Small Controllers Come By Design

This is the beautiful consequence of RESTful thinking: **controllers stay small automatically**. When you model resources properly, there's no room for bloat. You're constrained to four verbs (GET, POST, PATCH, DELETE) operating on a single resource. This constraint is liberating, not limiting.

Compare this to the alternative:

```ruby
# The wrong way - custom actions
class CardsController < ApplicationController
  def close
    # ...
  end

  def reopen
    # ...
  end

  def postpone
    # ...
  end

  def gild
    # ...
  end

  def ungild
    # ...
  end

  # ...and on and on, growing forever
end
```

Now your `CardsController` is a junk drawer. Every new feature adds another method. There's no natural organization, no cohesion, just an ever-growing list of things a card can do.

With resource-oriented design, each concern gets its own focused controller:

```ruby
# The 37signals way - focused controllers
resources :cards do
  resource :closure      # Cards::ClosuresController
  resource :goldness     # Cards::GoldnessesController
  resource :not_now      # Cards::NotNowsController
  resource :pin          # Cards::PinsController
end
```

Each controller is a tight, cohesive unit. They're easy to understand, easy to test, and easy to maintain.

## Creating Resources Instead of Custom Actions

When you encounter an action that doesn't map cleanly to CRUD, resist the urge to add a custom action. Instead, ask: "What resource am I really acting upon?"

### Example: Marking a Card as Golden

```ruby
# Bad - custom action
resources :cards do
  member do
    post :gild
    delete :ungild
  end
end

# Good - resource
resources :cards do
  resource :goldness
end
```

The controller becomes:

```ruby
class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.ungild

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

Again: `POST /cards/:id/goldness` marks it golden, `DELETE /cards/:id/goldness` removes the mark. Clean, standard, predictable.

### Example: Postponing a Card ("Not Now")

```ruby
# routes.rb
resources :cards do
  resource :not_now
end

# app/controllers/cards/not_nows_controller.rb
class Cards::NotNowsController < ApplicationController
  include CardScoped

  def create
    @card.postpone

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

Here we only need `create` because once postponed, cards are resumed through other actions (like moving them to triage). The resource models the concept perfectly: `POST /cards/:id/not_now` postpones the card.

### Example: Moving a Card Through Workflow

```ruby
# routes.rb
resources :cards do
  resource :triage  # Send to/from triage
end

# app/controllers/cards/triages_controller.rb
class Cards::TriagesController < ApplicationController
  include CardScoped

  def create
    column = @card.board.columns.find(params[:column_id])
    @card.triage_into(column)

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.send_back_to_triage

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
```

`POST /cards/:id/triage` with a `column_id` param moves the card into a column. `DELETE /cards/:id/triage` sends it back to the triage stream. The resource represents the card's state of being triaged.

## Nested Resources and Deep Routes

Some resources only make sense in the context of their parent. Fizzy has an interesting example with drag-and-drop operations. When you drop a card from a column, that's a nested operation:

```ruby
# routes.rb
namespace :columns do
  resources :cards do
    scope module: :cards do
      namespace :drops do
        resource :stream    # Drop card back to stream
        resource :column    # Drop card into another column
        resource :closure   # Drop card to close it
        resource :not_now   # Drop card to postpone it
      end
    end
  end
end
```

This creates routes like:
- `POST /columns/cards/:card_id/drops/stream` - Drop a card back to the triage stream
- `POST /columns/cards/:card_id/drops/column` - Drop a card into a column
- `POST /columns/cards/:card_id/drops/closure` - Drop a card to close it

The controllers are minimal:

```ruby
class Columns::Cards::Drops::StreamsController < ApplicationController
  include CardScoped

  def create
    @card.send_back_to_triage
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first
  end
end
```

```ruby
class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  def create
    @column = @card.board.columns.find(params[:column_id])
    @card.triage_into(@column)
  end
end
```

The nesting expresses the context: these are operations that happen when dropping a card from a column. The resource names (`stream`, `column`, `closure`) indicate what happens to the card.

## Namespacing: When to Nest Models

How do you decide whether to namespace a model under its parent? In Fizzy:

- `Card::Goldness` is namespaced - it has no meaning outside of a card
- `Card::Closure` is namespaced - a closure is always about a specific card
- `Card::NotNow` is namespaced - postponement is a card concern
- `Comment` is NOT namespaced - it has substance and identity beyond the card

The test is simple: **Does this concept have meaning or identity outside its parent?**

`Card::Goldness` without a card is nonsensical. What would you do with a `Goldness` object in isolation? Nothing. It only exists to mark a card as golden.

`Comment`, on the other hand, is important in its own right. Comments generate events. They appear in activity timelines. They trigger notifications and emails. They have a life beyond just "being attached to a card." So `Comment` is a root model.

This is admittedly subjective territory. Different developers will draw the line in different places. But ask yourself: "If I removed the parent, would this still be a coherent concept?" If not, namespace it.

## Practical URL Examples

Here's how RESTful resource design plays out in practice across Fizzy:

```ruby
# Card lifecycle
POST   /cards                        # Create a new card
GET    /cards/:id                    # View a card
PATCH  /cards/:id                    # Update a card
DELETE /cards/:id                    # Delete a card

# Card closure (open/closed state)
POST   /cards/:id/closure            # Close the card
DELETE /cards/:id/closure            # Reopen the card

# Card goldness (golden/normal state)
POST   /cards/:id/goldness           # Mark as golden
DELETE /cards/:id/goldness           # Unmark as golden

# Card postponement
POST   /cards/:id/not_now            # Postpone the card

# Card pinning (user-specific)
POST   /cards/:id/pin                # Pin for current user
DELETE /cards/:id/pin                # Unpin for current user

# Card workflow
POST   /cards/:id/triage             # Move card into a column
DELETE /cards/:id/triage             # Send card back to triage

# Card board transfer
PATCH  /cards/:id/board              # Move card to different board

# Drag-and-drop operations (from column context)
POST   /columns/cards/:id/drops/stream    # Drop to stream
POST   /columns/cards/:id/drops/column    # Drop to column
POST   /columns/cards/:id/drops/closure   # Drop to close
POST   /columns/cards/:id/drops/not_now   # Drop to postpone
```

Notice the pattern:
- The resource noun tells you what state or relationship is being managed
- The HTTP verb tells you what's happening to that resource
- The nesting tells you the context

Every URL reads like a sentence: "POST to this card's closure" means "close this card." "DELETE from this card's goldness" means "unmark this card as golden."

## The Link to Thin Controllers and Rich Models

This is where RESTful resource design connects to the broader 37signals architectural philosophy: **thin controllers, rich domain models, no service objects**.

When your controllers are this focused, they're already doing exactly what "application service objects" claim to do: high-level orchestration. Look at any controller in Fizzy:

```ruby
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close
    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

That IS high-level orchestration. It says: "Close the card, then render the appropriate response." The controller doesn't know HOW to close a card—that's the domain model's job. The controller just orchestrates the operation and handles the HTTP response.

If you wrapped this in a service object:

```ruby
# Don't do this
class CloseCardService
  def initialize(card)
    @card = card
  end

  def call
    @card.close
  end
end

# Then in the controller
def create
  CloseCardService.new(@card).call
  respond_to do |format|
    format.turbo_stream { render_card_replacement }
    format.json { head :no_content }
  end
end
```

You've added a layer of indirection for no benefit. The service object contains one line: `@card.close`. It's pure boilerplate. The controller was already thin. The service object doesn't make it thinner, it just adds ceremony.

The RESTful resource pattern already gives you the orchestration layer. Don't add another one.

## The CRUD Constraint is a Feature, Not a Bug

Some developers see the four CRUD verbs as limiting. "What if I need more than create, read, update, delete?"

The constraint is the point. It forces you to think clearly about what you're really doing. It prevents controllers from becoming grab bags of loosely related actions.

When you can't express an operation as CRUD, that's a signal: you need a new resource. The discipline of finding that resource name—`closure`, `goldness`, `not_now`, `triage`—forces you to clarify your thinking. What concept am I really modeling here?

This is design under constraint, and constraint breeds clarity.

## Routes Tell a Story

Well-designed RESTful routes read like a table of contents for your application:

```ruby
resources :cards do
  scope module: :cards do
    resource :board           # Cards can change boards
    resource :closure         # Cards can be closed/reopened
    resource :column          # Cards can be in columns
    resource :goldness        # Cards can be golden
    resource :not_now         # Cards can be postponed
    resource :pin             # Cards can be pinned
    resource :triage          # Cards can be triaged

    resources :comments       # Cards have comments
    resources :taggings       # Cards have tags
    resources :steps          # Cards have steps (subtasks)
  end
end
```

Reading this, you immediately understand the card domain:
- Cards move between boards and columns
- Cards have states: closed/open, golden/normal, postponed/active, pinned/unpinned
- Cards have collections: comments, tags, steps

The `resource` (singular) vs `resources` (plural) distinction matters:
- `resource :closure` - A card has one closure state (closed or not)
- `resources :comments` - A card has many comments

The routes themselves are documentation.

## Practical Guidelines

### When to Use `resource` (Singular)

Use singular resource when you're modeling a unique state or relationship:

```ruby
resource :closure       # A card has one closure state
resource :goldness      # A card has one goldness state
resource :pin           # Current user has one pin relationship with this card
```

The controller only needs `create`, `destroy`, and sometimes `show` or `update`. There's no `index` because there's only one.

### When to Use `resources` (Plural)

Use plural resources when you're modeling a collection:

```ruby
resources :comments     # A card has many comments
resources :taggings     # A card has many tag associations
resources :steps        # A card has many steps
```

These controllers typically implement the full CRUD suite: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`.

### When Actions Don't Fit CRUD

If you're struggling to map an action to CRUD, you probably need a new resource. Some questions to ask:

**"What am I really creating when I close a card?"**
→ A closure. `POST /cards/:id/closure`

**"What am I really destroying when I reopen a card?"**
→ The closure. `DELETE /cards/:id/closure`

**"What am I really creating when I pin a card?"**
→ A pin relationship. `POST /cards/:id/pin`

**"What am I really updating when I move a card to a different board?"**
→ The card's board association. `PATCH /cards/:id/board`

The resource name emerges from clear thinking about what you're actually manipulating.

## Testing Resource-Oriented Controllers

Small, focused controllers are a joy to test. Each controller tests exactly one concern:

```ruby
# test/controllers/cards/closures_controller_test.rb
class Cards::ClosuresControllerTest < ActionController::TestCase
  test "closing a card" do
    card = cards(:feature_request)

    post :create, params: { card_id: card }

    assert card.reload.closed?
  end

  test "reopening a card" do
    card = cards(:closed_bug)

    delete :destroy, params: { card_id: card }

    assert_not card.reload.closed?
  end
end
```

No complex setup, no tangled scenarios. The test is as focused as the controller.

## The Cumulative Effect

When every controller in your application follows this pattern:
- Controllers stay small and focused
- Routes are predictable and consistent
- The domain model bears the complexity (where it belongs)
- New developers can navigate the codebase intuitively
- Testing is straightforward
- Refactoring is safer

This is not a silver bullet. You still need to design your domain model well. You still need to organize your concerns. You still need to think.

But RESTful resource design gives you a framework that nudges you toward good decisions. It's harder to make a mess when you're constrained to thinking in resources and CRUD verbs.

## Final Thoughts

The 37signals approach to RESTful routes isn't radical. It's just Rails, taken seriously. It's the philosophy that DHH outlined years ago, applied with discipline and consistency.

We don't add custom actions. We don't bypass REST when it feels inconvenient. We find the resource, even when it takes effort to name it well. The payoff is a codebase that scales gracefully, both in size and in team dynamics.

When you open a Fizzy controller, you know exactly what to expect: a small, focused class that delegates to the domain model. No surprises, no sprawl, no junk drawers.

That's the power of constraint. That's the beauty of REST done right.

---

**Further Reading:**
- AGENTS.md - Overview of Fizzy architecture and multi-tenancy
- domain-driven-design.md - How we structure our domain models
- concerns-for-organization.md - Using concerns to organize large models
- STYLE.md - Our coding style, including controller conventions
