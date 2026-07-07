Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  get "/services",    to: "pages#services"
  get "/prestations", to: "pages#prestations"
  get "/realisations", to: "pages#realisations"
  get "/contact",     to: "pages#contact"
  get "/mentions-legales",             to: "pages#mentions_legales"
  get "/politique-de-confidentialite", to: "pages#politique_confidentialite", as: :politique_confidentialite
  get "/cgu",                          to: "pages#cgu",                       as: :cgu
  get "/sitemap.xml",                  to: "pages#sitemap",                   defaults: { format: "xml" }, as: :sitemap

  resource :estimation, only: [:new, :create, :show] do
    post :preview, on: :collection
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :tarifs, except: :show
    resources :estimations, only: [:index, :show, :update, :destroy]

    resources :clients, only: [:index, :show, :update, :new, :create] do
      collection { get :kanban }
      resources :notes, only: [:create, :destroy], controller: "client_notes"
    end

    patch "campagne-ads", to: "campagne_ads#update", as: :campagne_ads

    resources :encaissements, except: [:show]
    get    "declarations",               to: "declarations#index",               as: :declarations
    post   "declarations/marquer",       to: "declarations#marquer_declaree",    as: :marquer_declaration
    delete "declarations/periodes/:id",  to: "declarations#annuler_declaration", as: :annuler_declaration
    patch  "declarations/reglages",      to: "declarations#update_reglages",     as: :declaration_reglages

    resources :site_texts, only: [:index, :update]
    resources :media_slots, only: [:index, :update] do
      member { delete :remove_image }
    end
    resources :realisations, except: :show do
      collection { patch :reorder }
    end
  end
end
