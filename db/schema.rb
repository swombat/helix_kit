# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_28_115249) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.integer "account_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "is_site_admin", default: false, null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_memories", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "memory_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "created_at"], name: "index_agent_memories_on_agent_id_and_created_at"
    t.index ["agent_id", "memory_type"], name: "index_agent_memories_on_agent_id_and_memory_type"
    t.index ["agent_id"], name: "index_agent_memories_on_agent_id"
  end

  create_table "agents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "colour"
    t.datetime "created_at", null: false
    t.jsonb "enabled_tools", default: [], null: false
    t.string "icon"
    t.string "model_id", default: "openrouter/auto", null: false
    t.string "name", null: false
    t.text "reflection_prompt"
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.index ["account_id", "active"], name: "index_agents_on_account_id_and_active"
    t.index ["account_id", "name"], name: "index_agents_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_agents_on_account_id"
  end

  create_table "ai_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ai_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ai_models_on_family"
    t.index ["modalities"], name: "index_ai_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ai_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ai_models_on_provider"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["account_id", "created_at"], name: "index_audit_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_audit_logs_on_account_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "chat_agents", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "chat_id", null: false
    t.datetime "created_at", null: false
    t.index ["agent_id"], name: "index_chat_agents_on_agent_id"
    t.index ["chat_id", "agent_id"], name: "index_chat_agents_on_chat_id_and_agent_id", unique: true
    t.index ["chat_id"], name: "index_chat_agents_on_chat_id"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "ai_model_id"
    t.datetime "created_at", null: false
    t.datetime "last_consolidated_at"
    t.bigint "last_consolidated_message_id"
    t.boolean "manual_responses", default: false, null: false
    t.string "model_id_string", default: "openrouter/auto", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.boolean "web_access", default: false, null: false
    t.index ["account_id", "created_at"], name: "index_chats_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_chats_on_account_id"
    t.index ["ai_model_id"], name: "index_chats_on_ai_model_id"
    t.index ["last_consolidated_at"], name: "index_chats_on_last_consolidated_at"
    t.index ["manual_responses"], name: "index_chats_on_manual_responses"
    t.index ["web_access"], name: "index_chats_on_web_access"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invited_at"
    t.bigint "invited_by_id"
    t.string "role", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "user_id"], name: "index_memberships_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["confirmation_token"], name: "index_memberships_on_confirmation_token", unique: true
    t.index ["confirmed_at"], name: "index_memberships_on_confirmed_at"
    t.index ["invitation_accepted_at"], name: "index_memberships_on_invitation_accepted_at"
    t.index ["invited_by_id"], name: "index_memberships_on_invited_by_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "agent_id"
    t.bigint "ai_model_id"
    t.bigint "chat_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.string "model_id_string"
    t.integer "output_tokens"
    t.string "role", null: false
    t.boolean "streaming", default: false, null: false
    t.bigint "tool_call_id"
    t.string "tool_status"
    t.text "tools_used", default: [], array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["agent_id"], name: "index_messages_on_agent_id"
    t.index ["ai_model_id"], name: "index_messages_on_ai_model_id"
    t.index ["chat_id", "created_at"], name: "index_messages_on_chat_id_and_created_at"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["streaming"], name: "index_messages_on_streaming"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
    t.index ["tools_used"], name: "index_messages_on_tools_used", using: :gin
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "chat_colour"
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.jsonb "preferences", default: {}
    t.string "theme", default: "system"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "prompt_outputs", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.text "output"
    t.jsonb "output_json", default: {}
    t.string "prompt_key"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_prompt_outputs_on_account_id"
    t.index ["created_at"], name: "index_prompt_outputs_on_created_at"
    t.index ["prompt_key"], name: "index_prompt_outputs_on_prompt_key"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.boolean "allow_agents", default: false, null: false
    t.boolean "allow_chats", default: true, null: false
    t.boolean "allow_signups", default: true, null: false
    t.datetime "created_at", null: false
    t.string "site_name", default: "HelixKit", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "is_site_admin", default: false, null: false
    t.boolean "migrated_to_accounts", default: false
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_memories", "agents"
  add_foreign_key "agents", "accounts"
  add_foreign_key "audit_logs", "accounts"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "chat_agents", "agents"
  add_foreign_key "chat_agents", "chats"
  add_foreign_key "chats", "accounts"
  add_foreign_key "chats", "ai_models"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "messages", "agents"
  add_foreign_key "messages", "ai_models"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "users"
  add_foreign_key "profiles", "users"
  add_foreign_key "prompt_outputs", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "tool_calls", "messages"
end
