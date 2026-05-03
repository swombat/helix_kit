module TestSupport
  class E2eController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    before_action :ensure_test_environment

    PASSWORD = "password123"

    def setup
      run_id = params.fetch(:run_id)
      cleanup_run(run_id)

      primary_user = create_user!("e2e-#{run_id}-primary@example.com")
      secondary_user = create_user!("e2e-#{run_id}-secondary@example.com")
      account = Account.create!(name: "E2E #{run_id} Team", account_type: :team)
      account.add_user!(primary_user, role: "owner", skip_confirmation: true)
      account.add_user!(secondary_user, role: "member", skip_confirmation: true)

      agents = [
        create_agent!(account, "E2E Researcher", "slate"),
        create_agent!(account, "E2E Critic", "teal")
      ]

      render json: {
        run_id: run_id,
        password: PASSWORD,
        account_id: account.id,
        primary_user: user_json(primary_user),
        secondary_user: user_json(secondary_user),
        agents: agents.map { |agent| { id: agent.to_param, name: agent.name } }
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
      users = User.where(email_address: [
        "e2e-#{run_id}-primary@example.com",
        "e2e-#{run_id}-secondary@example.com"
      ])

      AuditLog.where(account: accounts).or(AuditLog.where(user: users)).destroy_all
      accounts.find_each(&:destroy!)
      users.find_each(&:destroy!)
    end

    def create_user!(email)
      User.create!(email_address: email, password: PASSWORD, password_confirmation: PASSWORD)
    end

    def create_agent!(account, name, colour)
      account.agents.create!(
        name: name,
        system_prompt: "You are #{name}, a deterministic E2E test agent.",
        model_id: "openrouter/auto",
        colour: colour,
        icon: "Robot",
        active: true,
        enabled_tools: []
      )
    end

    def user_json(user)
      { email: user.email_address }
    end
  end
end
