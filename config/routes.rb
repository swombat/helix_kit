Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Favicon routes
  get "favicon.:format", to: "favicon#show", as: :favicon, defaults: { format: "ico" }
  get "favicon", to: "favicon#show", defaults: { format: "ico" }

  # Documentation
  get "documentation" => "documentation#index", as: :documentation

  get "login" => "sessions#new", as: :login
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout

  get "signup" => "registrations#new", as: :signup
  post "signup" => "registrations#create"
  get "check-email" => "registrations#check_email", as: :check_email
  get "email-confirmation" => "registrations#confirm_email", as: :email_confirmation
  get "set-password" => "registrations#set_password", as: :set_password
  patch "set-password" => "registrations#update_password"

  resources :passwords, param: :token, only: %i[new create edit update]

  resource :user, only: %i[edit update] do
    scope module: :users do
      resource :password, only: [ :edit, :update ]
      resource :avatar, only: :destroy
    end
  end

  # API Key Management (browser-based)
  resources :api_keys, only: [ :index, :create, :destroy ]

  # API Key Approvals (all actions keyed by token)
  get    "api_keys/approvals/:token", to: "api_key_approvals#show",    as: :api_key_approval
  post   "api_keys/approvals/:token", to: "api_key_approvals#create"
  delete "api_keys/approvals/:token", to: "api_key_approvals#destroy"

  # Telegram webhook (called by Telegram, no auth)
  post "telegram/webhook/:token", to: "telegram_webhooks#receive", as: :telegram_webhook

  resources :accounts, only: [ :show, :edit, :update ] do
    resources :members, controller: "account_members", only: [ :destroy ]
    resources :invitations, only: [ :create ] do
      member do
        post :resend
      end
    end

    resource :agent_initiation, only: :create, module: :accounts

    resources :chats do
      scope module: :chats do
        resource :archive, only: [ :create, :destroy ]
        resource :discard, only: [ :create, :destroy ]
        resource :fork, only: :create
        resource :moderation, only: :create
        resource :agent_assignment, only: :create
        resource :participant, only: :create
        resource :agent_trigger, only: :create
      end
      resources :messages, only: [ :index, :create ]
    end

    resources :agents, except: [ :show, :new ] do
      scope module: :agents do
        resource :refinement, only: :create
        resource :telegram_test, only: :create
        resource :telegram_webhook, only: :create
        resources :memories, only: [ :create ] do
          resource :discard, only: [ :create, :destroy ], module: :memories
          resource :protection, only: [ :create, :destroy ], module: :memories
        end
      end
    end

    resources :whiteboards, only: [ :index, :update ]
  end

  resources :messages, only: [ :update, :destroy ] do
    scope module: :messages do
      resource :retry, only: :create
      resource :hallucination_fix, only: :create
    end
  end

  namespace :admin do
    resources :accounts, only: [ :index ]
    resources :audit_logs, only: [ :index ]
    resource :settings, only: [ :show, :update ]
  end

  # JSON API for external clients (Claude Code, etc.)
  namespace :api do
    namespace :v1 do
      resources :key_requests, only: [ :create, :show ]
      resources :conversations, only: [ :index, :show ] do
        resources :messages, only: :create
      end
      resources :whiteboards, only: [ :index, :show, :create, :update ]
    end
  end

  # Oura Ring integration (OAuth + settings)
  resource :oura_integration, only: %i[show create update destroy], controller: "oura_integration" do
    get :callback
    post :sync
  end

  # GitHub integration (OAuth + repo selection + settings)
  resource :github_integration, only: %i[show create update destroy], controller: "github_integration" do
    get :callback
    get :select_repo
    post :save_repo
    post :sync
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  get "privacy" => "pages#privacy", as: :privacy
  get "terms" => "pages#terms", as: :terms
  get "create_flash" => "pages#create_flash"
  root "pages#home"
end
