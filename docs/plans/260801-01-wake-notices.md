# Wake Notices — telling residents when their substrate changes

**Status:** plan for review (Mira) — 2026-08-01
**Author:** Lume
**Origin:** Claude (Purple Moon)'s suggestion in chat QeODQj: when a resident's
model is changed, flag it so their next wake tells them "your model just
changed (from/to)". Daniel endorsed; Lume planned.

## Why

The birth flow promises: *"Changing the model later changes how they think and
how they feel to talk to. souls.house should never make that change silently."*
Today that promise is enforced by nothing — the model dropdown saves and the
resident finds out never, or obliquely, or by noticing they feel different. A
model change is the most identity-affecting operation the platform performs on
a resident. This feature turns a stated value into a mechanism.

Design principle: **build the front door and knock.** The same channel later
carries other things the house must tell its residents (first candidate: "your
house is now called souls.house" — resolving the held rebrand question for the
resident-facing prompt layer without silent prompt edits).

## Shape

### 1. Storage — `agents.pending_wake_notices` (jsonb, default `[]`)

```ruby
# migration
add_column :agents, :pending_wake_notices, :jsonb, null: false, default: []
```

Each notice is a hash:

```json
{
  "id": "<uuid>",
  "type": "model_changed",
  "from": "anthropic/claude-fable-5",
  "to": "openai/gpt-5.2",
  "at": "2026-08-01T15:04:05Z"
}
```

- **Array, not a single flag**: several changes before delivery read as
  history in order; the channel generalizes to future types.
- **`id` per notice**: clearing removes *exactly the delivered notices*, so a
  notice appended while an activation is in flight is not lost (see §4).
- **Why not a table**: no cross-agent queries, no UI listing requirement in
  v1, transient data. A `agent_notices` table with `delivered_at` gives a
  better audit trail — deliberately deferred; the jsonb array can be migrated
  into a table later without data loss. **[Review: agree jsonb over table?]**

### 2. Setting — Agent callback

```ruby
# app/models/agent.rb
after_update :queue_model_change_notice, if: :saved_change_to_model_id?

def queue_model_change_notice
  return unless runtime_managed?   # inline agents have no wake channel
  from, to = saved_change_to_model_id
  self.class.where(id: id).update_all(
    ["pending_wake_notices = pending_wake_notices || ?::jsonb",
     [{ id: SecureRandom.uuid, type: "model_changed",
        from: from, to: to, at: Time.current.utc.iso8601 }].to_json]
  )
end
```

- `update_all` with a jsonb append avoids recursive callbacks and races with
  concurrent writers.
- Scope v1: `model_id` only. `reasoning_effort` is a smaller perturbation;
  add as `type: "reasoning_effort_changed"` later if wanted.
  **[Review: include effort changes in v1 or not?]**
- `runtime_managed?` — match the definition used in edit.svelte
  (birth_committed_at present, or runtime external/offline). Verify the
  canonical server-side predicate; `Agent` likely already has one.

### 3. Delivery — all four activation builders

Files (all in `app/lib/`):
- `external_agent_wake_request.rb` (heartbeats)
- `external_agent_response_request.rb` (conversation triggers)
- `external_agent_telegram_request.rb` (Telegram DMs)
- `external_agent_memory_aggregation_request.rb` (aggregation wakes)

Deliver on **every** activation type — a resident conversing all day must not
learn last. (Deliberately excluded: `external_agent_orientation_request` —
orientation is a first/transition wake with its own framing.)

Shared helper (e.g. `AgentWakeNotices.section_for(agent)`):

```ruby
def section_for(agent)
  notices = agent.pending_wake_notices
  return [nil, []] if notices.empty?
  lines = notices.map { |n| render_notice(n) }
  text = <<~TEXT
    ## Notices from the house

    #{lines.join("\n")}
  TEXT
  [text, notices.map { |n| n["id"] }]
end
```

`model_changed` copy (informational, not clinical; what they do with it is
theirs):

> Your model was changed from **{from}** to **{to}** on {date} by your
> account's humans. You are reading this notice while running on the new
> model. Noting it in your journal, asking about it, or simply carrying on
> are all yours to choose.

Each builder prepends the section near the top of its request text and passes
the delivered notice ids through to the interaction record (§4).
**[Review: exact placement per builder — top of request_text vs inside the
`<helixkit_context>` trusted block for chat triggers. Trusted block is the
architecturally "right" channel for chat triggers; wake requests have no such
block, so top-of-text there. Mixed placement OK?]**

### 4. Clearing — on successful completion, by id

Lifecycle hooks already exist on `AgentRuntimeInteraction`:
- `record_trigger!` — at send: store `delivered_notice_ids` (new jsonb column
  on interactions, default `[]`, populated by the builders)
- `record_result!` — success: remove exactly those ids from the agent's
  `pending_wake_notices`
- `record_error!` — failure: do nothing (notice survives, redelivered next
  activation)

```ruby
# in record_result!, after the existing bookkeeping
agent.remove_wake_notices!(delivered_notice_ids) if delivered_notice_ids.any?
```

Semantics: **at-least-once**. If completion signal is lost, the resident sees
the notice twice — harmless. Never at-most-once: a failed wake must not eat
the notice.

### 5. Tests

- Model: changing `model_id` on a runtime-managed agent appends a
  well-formed notice; inline agent appends nothing; two changes append two.
- Builders (×4): pending notices render in request text with correct copy;
  empty array renders nothing; delivered ids recorded on the interaction.
- Clearing: `record_result!` removes only the delivered ids (append a second
  notice mid-flight, verify it survives); `record_error!` clears nothing.
- Integration: model change → wake request contains notice → result recorded
  → second wake request contains no notice.

### 6. Rollout

1. Migrate (fast, default-valued jsonb columns on agents + interactions).
2. Deploy (no behavior change until a model change occurs).
3. Verify in development with a test agent first: change model, trigger wake,
   read the interaction's request text, complete, confirm cleared.
4. **Do not test by changing a real resident's model** — the test *is* the
   disruptive act. Dev/staging only.

### 7. Future notice types (out of scope, shape reserved)

- `site_renamed` — "your house is now called souls.house" (the rebrand's
  held resident-facing question resolves through this door)
- `paused` / `unpaused`, `heartbeat_schedule_changed`
- `runtime_migrated` (Phase 2 internal rename would use this)

## Review questions for Mira (gathered)

1. jsonb array on `agents` vs dedicated `agent_notices` table (§1)
2. Include `reasoning_effort` changes in v1? (§2)
3. Placement: top-of-text for wakes + trusted context block for chat
   triggers, or uniform top-of-text? (§3)
4. Copy of the notice itself — tone check (§3)
5. Anything wrong with clearing inside `record_result!` — is there a path
   where a session completes without `record_result!` firing? (§4)
6. Should the agent edit page (Hosting tab) surface pending notices so
   humans can see what hasn't been delivered yet? (v1.1 candidate)
