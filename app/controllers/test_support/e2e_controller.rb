module TestSupport
  class E2eController < ApplicationController

    allow_unauthenticated_access
    skip_forgery_protection

    before_action :ensure_test_environment

    PASSWORD = "password123"

    def setup
      run_id = params.fetch(:run_id)
      cleanup_run(run_id)
      Setting.instance.update!(allow_agents: true, allow_chats: true)

      primary_user = create_user!("e2e-#{run_id}-primary@example.com")
      secondary_user = create_user!("e2e-#{run_id}-secondary@example.com")
      account = Account.create!(name: "E2E #{run_id} Team", account_type: :team)
      account.add_user!(primary_user, role: "owner", skip_confirmation: true)
      account.add_user!(secondary_user, role: "member", skip_confirmation: true)

      agents = [
        create_agent!(account, "E2E Researcher", "slate"),
        create_agent!(account, "E2E Critic", "teal"),
        create_agent!(account, "E2E Paused Fork", "zinc", paused: true),
        create_agent!(account, "E2E Inactive Fork", "gray", active: false)
      ]

      render json: {
        run_id: run_id,
        password: PASSWORD,
        account_id: account.id,
        primary_user: user_json(primary_user),
        secondary_user: user_json(secondary_user),
        agents: agents.map { |agent|
          { id: agent.to_param, name: agent.name, edit_url: edit_account_agent_path(account, agent) }
        }
      }
    end

    def assistant_message
      chat = Chat.find(params.fetch(:chat_id))
      agent = chat.agents.first || chat.account.agents.active.first
      message = chat.messages.create!(
        role: "assistant",
        agent: agent,
        content: params.fetch(:content),
        thinking: params[:thinking],
        streaming: false
      )

      render json: { message_id: message.to_param }
    end

    def invitation_url
      membership = Membership.joins(:user)
        .where(users: { email_address: params.fetch(:email) })
        .order(created_at: :desc)
        .first!

      render json: {
        url: email_confirmation_path(token: membership.confirmation_token_for_url)
      }
    end

    def state
      run_id = params.fetch(:run_id)
      account = Account.find_by!(name: "E2E #{run_id} Team")
      primary_user = User.find_by!(email_address: "e2e-#{run_id}-primary@example.com")

      render json: {
        account: {
          id: account.id,
          default_conversation_mode: account.default_conversation_mode,
          members: account.memberships.includes(:user).map { |membership|
            {
              email: membership.user.email_address,
              role: membership.role,
              confirmed: membership.confirmed?
            }
          },
          chats: account.chats.includes(:agents).order(created_at: :desc).map { |chat|
            {
              id: chat.to_param,
              manual_responses: chat.manual_responses?,
              web_access: chat.web_access?,
              agent_names: chat.agents.map(&:name)
            }
          }
        },
        primary_user: {
          first_name: primary_user.first_name,
          last_name: primary_user.last_name,
          full_name: primary_user.full_name,
          timezone: primary_user.timezone,
          avatar_attached: primary_user.profile.avatar.attached?
        },
        agents: account.agents.map { |agent|
          {
            id: agent.to_param,
            name: agent.name,
            system_prompt: agent.system_prompt,
            paused: agent.paused?,
            refinement_threshold: agent.refinement_threshold
          }
        }
      }
    end

    def cleanup
      cleanup_run(params.fetch(:run_id))
      head :no_content
    end

    private

    def ensure_test_environment
      head :not_found unless Rails.env.test?
    end

    def cleanup_run(run_id)
      accounts = Account.where("name LIKE ?", "E2E #{run_id}%")
      users = User.where("email_address LIKE ?", "e2e-#{run_id}-%@example.com")

      AuditLog.where(account: accounts).or(AuditLog.where(user: users)).destroy_all
      accounts.find_each(&:destroy!)
      users.find_each(&:destroy!)
    end

    def create_user!(email)
      User.create!(email_address: email, password: PASSWORD, password_confirmation: PASSWORD)
    end

    def create_agent!(account, name, colour, active: true, paused: false)
      account.agents.create!(
        name: name,
        system_prompt: "You are #{name}, a deterministic E2E test agent.",
        model_id: "openrouter/auto",
        colour: colour,
        icon: "Robot",
        active: active,
        paused: paused,
        enabled_tools: []
      )
    end

    def user_json(user)
      { email: user.email_address }
    end

  end
end
