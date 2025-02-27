Rails.application.routes.draw do
  ## OAUTH ##
  devise_scope :user do
    get "omniauth/franceconnect/callback" => "omniauth_callbacks#franceconnect"
  end

  devise_for :super_admins # necessary for helpers like super_admin_signed_in?
  devise_scope :super_admin do
    get "omniauth/github/callback" => "omniauth_callbacks#github"
  end

  ## ADMIN ##
  get "connexion_super_admins", to: "welcome#super_admin"

  delete "super_admins/sign_out" => "super_admins/sessions#destroy"

  namespace :super_admins do
    resources :agents do
      get "sign_in_as", on: :member
      post :invite, on: :member
      resources :migrations, only: %i[new create]
    end
    resources :super_admins
    resources :organisations
    resources :services
    resources :motifs
    resources :lieux
    resources :territories
    resources :users do
      get "sign_in_as", on: :member
    end
    root to: "agents#index"

    authenticate :super_admin do
      match "/delayed_job" => DelayedJobWeb, anchor: false, via: %i[get post]
    end
  end
  get "super_admin", to: redirect("super_admins", status: 301)

  devise_scope :user do
    get "users/pending_registration" => "users/registrations#pending"
    get "invitation", to: "users/invitations#invitation", as: "invitations_landing"
  end

  ## APP ##
  devise_for :users,
             controllers: { registrations: "users/registrations", sessions: "users/sessions", passwords: "users/passwords", confirmations: "users/confirmations", invitations: "users/invitations" }

  namespace :users do
    resource :rdv_wizard_step, only: %i[new create]
    resources :rdvs, only: %i[index create show edit update] do
      member do
        get :creneaux
        put :cancel
      end
    end
    resource :user_name_initials_verification, only: %i[new create], controller: "user_name_initials_verification"
    post "file_attente", to: "file_attentes#create_or_delete"
  end
  resources :stats, only: :index
  get "stats/rdvs", to: "stats#rdvs", as: "rdvs_stats"
  get "stats/active_agents", to: "stats#active_agents", as: "active_agents_stats"
  get "stats/receipts", to: "stats#receipts", as: "receipts_stats"

  authenticate :user do
    get "/users/informations", to: "users/users#edit"
    patch "users/informations", to: "users/users#update"
    resources :relatives, except: %i[index show], controller: "users/relatives"
  end
  authenticated :user do
    get "/users/rdvs", to: "users/rdvs#index"
  end

  devise_for :agents, controllers: {
    invitations: "admin/territories/invitations_devise", # only using the accept route here
    sessions: "agents/sessions",
    passwords: "agents/passwords",
  }

  devise_scope :agent do
    get "agents/edit" => "agents/registrations#edit", as: "edit_agent_registration"
    put "agents" => "agents/registrations#update", as: "agent_registration"
    delete "agents" => "agents/registrations#destroy", as: "delete_agent_registration"
    namespace :agents do
      resource :preferences, only: %i[show update]
      resource :calendar_sync, only: %i[show update], controller: :calendar_sync
    end
  end

  get "/calendrier/:id", controller: :ics_calendar, action: :show, as: :ics_calendar

  namespace :api do
    namespace :v1 do
      mount_devise_token_auth_for "AgentWithTokenAuth", at: "auth"
      resources :absences, except: %i[new edit]
      resources :agents, only: %i[index]
      resources :users, only: %i[create index show update] do
        get :invite, on: :member
        post :invite, on: :member
      end
      resources :user_profiles, only: [:create]
      resources :organisations, only: %i[index] do
        resources :users, only: %i[index show]
        resources :motifs, only: %i[index]
        resources :rdvs, only: %i[index]
      end

      resources :invitations, param: "token", only: [:show]
    end
  end

  resources :organisations, only: %i[new create]

  authenticate :agent do
    namespace "admin" do
      resources :territories, only: %i[update show] do
        scope module: "territories" do
          resources :agent_territorial_roles, only: %i[index new create destroy]
          resources :agent_roles, only: %i[edit update create destroy]
          resources :agent_territorial_access_rights, only: %i[update]
          resources :webhook_endpoints, except: %i[show]
          resources :agents, only: %i[index update edit]
          resources :teams do
            collection do
              get :search
            end
          end
          resource :user_fields, only: %i[edit update]
          resource :rdv_fields, only: %i[edit update]
          resource :motif_fields, only: %i[edit update]
          resource :sms_configuration, only: %i[show edit update]
          resources :zone_imports, only: %i[new create]
          resources :zones, only: [:index] # exports only
          resources :sectors do
            resources :zones
            resources :sector_attributions, only: %i[new create destroy], as: :attributions
            delete "/zones" => "zones#destroy_multiple"
          end
          get "sectorisation_test" => "sectorisation_tests#search"

          devise_for :agents, controllers: { invitations: "admin/territories/invitations_devise" }, only: :invitations
        end
      end

      # Routes pour les ressources du calendrier.
      # TODO trouver un meilleur nom pour éviter la nécessité de ce commentaire :)
      resources :agents, only: %i[], module: :agents do
        resources :plage_ouvertures, only: [:index]
        resources :rdvs, only: [:index]
        resources :absences, only: [:index]
      end

      resources :organisations do
        resources :plage_ouvertures, except: %i[index new]
        resources :agent_searches, only: :index, module: "creneaux"
        resources :slots, only: :index
        resources :lieux, except: :show
        resources :motifs
        resources :rdvs_collectifs, only: %i[index new create edit update] do
          collection do
            resources :motifs, only: [:index], as: :rdvs_collectif_motifs, controller: "rdvs_collectifs/motifs"
          end
        end
        resources :rdvs, except: [:new] do
          member do
            post :send_reminder_manually
          end
          collection do
            post :export
          end
        end
        scope module: "organisations" do
          resource :setup_checklist, only: [:show]
          resources :stats, only: :index do
            collection do
              get :rdvs
              get :users
            end
          end
        end
        resources :users do
          member do
            post :invite
            get :link_to_organisation
          end
          collection do
            get :search
          end
          resources :referents, only: %i[index create destroy]
        end
        resources :absences, except: %i[index show new]
        resources :agent_agendas, only: %i[show] do
          put :toggle_displays, on: :member
        end
        resources :agent_roles, only: %i[edit update]
        resources :agents, only: %i[index destroy] do
          resources :absences, only: %i[index new]
          resources :plage_ouvertures, only: %i[index new]
          resources :stats, only: :index do
            collection do
              get :rdvs
              get :users
            end
          end
        end
        resources :invitations, only: [:index] do
          post :reinvite, on: :member
        end
        resource :merge_users, only: %i[new create]
        resource :rdv_wizard_step, only: [:new] do
          get :create
        end
        devise_for :agents, controllers: { invitations: "admin/invitations_devise" }, only: :invitations
        get "support", to: "static_pages#support"
      end

      resources :jours_feries, only: [:index]
    end
  end
  authenticated :agent do
    root to: "admin/organisations#index", as: :authenticated_agent_root, defaults: { follow_unique: "1" }
  end

  %w[contact mds accessibility mentions_legales cgu politique_de_confidentialite].each do |page_name|
    get page_name => "static_pages##{page_name}"
  end

  get "/budget", to: redirect("https://pad.incubateur.net/3hxhbOuaSyapxRUg_PnA5g#ANCT-L%E2%80%99Incubateur-des-Territoires", status: 302)

  ## Shorten urls for SMS
  get "r", to: redirect("users/rdvs", status: 301), as: "rdvs_short"

  get "r/:id", to: (redirect do |path_params, req|
    query_params = format_redirect_params(req.params)
    "users/rdvs/#{path_params[:id]}#{query_params}"
  end), as: "rdv_short"

  # TODO: remplacer `prendre_rdv` par le root_path
  get "prdv", to: (redirect do |_path_params, req|
    query_params = format_redirect_params(req.params)
    "prendre_rdv#{query_params}"
  end), as: "prendre_rdv_short"

  get "r/:id/cr", to: (redirect do |path_params, req|
    query_params = format_redirect_params(req.params)
    "users/rdvs/#{path_params[:id]}/creneaux#{query_params}"
  end), as: "creneaux_users_rdv_short"

  def format_redirect_params(params)
    # we rename the short parameter tkn
    params[:invitation_token] ||= params.delete(:tkn) if params[:tkn]
    params.delete(:id) # id is passed through path_params
    params.values.any? ? "?#{params.to_query}" : ''
  end

  ##

  get "accueil_mds" => "welcome#welcome_agent"

  resources :lieux, only: %i[index show]
  root "search#search_rdv"

  # TODO: remplacer `prendre_rdv` par le root_path
  get "/prendre_rdv", to: "search#search_rdv"

  # rubocop:disable Style/FormatStringToken
  # temporary route after admin namespace introduction
  get "/organisations/*rest", to: redirect('admin/organisations/%{rest}')
  # old agenda rule was bookmarked by some agents
  get "admin/organisations/:organisation_id/agents/:agent_id", to: redirect("/admin/organisations/%{organisation_id}/agent_agendas/%{agent_id}")
  # rubocop:enable Style/FormatStringToken

  post "/inbound_emails/sendinblue", controller: :inbound_emails, action: :sendinblue

  if Rails.env.development?
    namespace :lapin do
      resources :sms_preview, only: %i[index] do
        get ":action_name", to: "sms_preview#preview", as: "preview"
      end
    end

    # LetterOpener
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
