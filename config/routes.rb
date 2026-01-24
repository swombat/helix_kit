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
    member do
      get "edit_password"
      patch "update_password"
    end
  end

  resource :user_avatar, only: %i[destroy], controller: "users", path: "user/avatar"

  # API Key Management (browser-based)
  resources :api_keys, only: [ :index, :create, :destroy ]
  get "api_keys/approve/:token", to: "api_keys#approve", as: :approve_api_key
  post "api_keys/approve/:token", to: "api_keys#confirm_approve"
  delete "api_keys/approve/:token", to: "api_keys#deny", as: :deny_api_key

  resources :accounts, only: [ :show, :edit, :update ] do
    resources :members, controller: "account_members", only: [ :destroy ]
    resources :invitations, only: [ :create ] do
      member do
        post :resend
      end
    end
    resources :chats do
      member do
        get :older_messages
        post "trigger_agent/:agent_id", action: :trigger_agent, as: :trigger_agent
        post :trigger_all_agents
        post :fork
        post :archive
        post :unarchive
        post :discard
        post :restore
        post :assign_agent
        post :moderate_all
      end
      resources :messages, only: :create
    end
    resources :agents, except: [ :show, :new ] do
      member do
        post "memories", action: :create_memory, as: :create_memory
        delete "memories/:memory_id", action: :destroy_memory, as: :destroy_memory
      end
    end
    resources :whiteboards, only: [ :index, :update ]
  end

  resources :messages, only: [ :update, :destroy ] do
    member do
      post :retry
      post :fix_hallucinated_tool_calls
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
        member do
          post :create_message
        end
      end
      resources :whiteboards, only: [ :index, :show, :create, :update ]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  get "create_flash" => "pages#create_flash"
  root "pages#home"
end
