Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  get "/services",    to: "pages#services"
  get "/prestations", to: "pages#prestations"
  get "/realisations", to: "pages#realisations"
  get "/contact",     to: "pages#contact"
  # Pages d'atterrissage Google Ads — une par groupe d'annonces. L'URL porte le
  # mot-clé : c'est elle que Google évalue pour l'« expérience de la page de
  # destination » (notée « inférieure à la moyenne » sur /estimation/new le
  # 02/09/2026, niveau de qualité 2-3/10 → 67 % d'impressions perdues au rang).
  get "/peintre-bordeaux",   to: "pages#landing", defaults: { metier: "peinture" }, as: :landing_peinture
  get "/plaquiste-bordeaux", to: "pages#landing", defaults: { metier: "placo" },    as: :landing_placo
  get "/parquet-bordeaux",   to: "pages#landing", defaults: { metier: "parquet" },  as: :landing_parquet

  get "/mentions-legales",             to: "pages#mentions_legales"
  get "/politique-de-confidentialite", to: "pages#politique_confidentialite", as: :politique_confidentialite
  get "/cgu",                          to: "pages#cgu",                       as: :cgu
  get "/sitemap.xml",                  to: "pages#sitemap",                   defaults: { format: "xml" }, as: :sitemap

  resource :estimation, only: [:new, :create, :show] do
    post :preview, on: :collection
  end

  # Balise de mesure du tunnel (agrégée, sans donnée personnelle).
  post "/suivi-tunnel", to: "tunnel#create", as: :suivi_tunnel

  namespace :admin do
    root to: "dashboard#index"
    resources :tarifs, except: :show
    resources :gammes, only: :index
    resources :prestations, except: :show
    resources :rdvs, except: :show do
      collection do
        get :semaine
        get :ical
      end
    end
    resources :estimations, only: [:index, :show, :update, :destroy] do
      member do
        get   :devis,              to: "devis#show"          # écran de saisie (tablette)
        post  :devis_prefill,      to: "devis#prefill"       # pré-remplissage depuis l'estimation web
        patch :devis_remise,       to: "devis#remise"        # remise (% ou montant)
        patch :devis_extras,       to: "devis#extras"        # trajet + consommables
        patch :devis_conditions,   to: "devis#conditions"    # acompte + modalités de paiement
        patch :devis_echeances,    to: "devis#echeances"     # échéancier de paiement (versements %)
        get   :devis_presentation, to: "devis#presentation"  # récap client + signature
        post  :devis_sign,         to: "devis#sign"          # enregistrer la signature
        post  :devis_resend,       to: "devis#resend"        # renvoyer le mail signé
        get   :devis_pdf,          to: "devis#pdf"           # télécharger le PDF
        get   :devis_lignes,       to: "devis#lignes"        # éditeur de devis en lignes libres
        post  :devis_document_generer, to: "devis#generer_document"  # génère le PDF (lignes) → DevisDocument
        get   :devis_envoi,        to: "devis#envoi"         # écran de composition du mail
        post  :devis_envoyer,      to: "devis#envoyer"       # envoyer le devis (doc joint) au client
        get   :devis_document_pdf, to: "devis#document_pdf"  # télécharger le PDF du devis (base)
        post  :devis_accepter,     to: "devis#accepter"      # accord reçu hors signature à l'écran
        post  :devis_refuser,      to: "devis#refuser"       # devis refusé (sort du CA potentiel)
        post  :devis_rouvrir,      to: "devis#rouvrir"       # annuler une acceptation
      end
    end

    # Liste de tous les devis chiffrés, tous états confondus.
    resources :devis, only: :index do
      collection do
        get  :nouveau           # créer un devis sans estimation en ligne
        post :creer, as: :creer
      end
    end

    # Devis en lignes libres (Vague 1).
    resources :devis_lignes, only: [:create, :update, :destroy] do
      collection do
        patch :renommer_section
        patch :reordonner            # réordonnancement par glisser-déposer
      end
    end

    # Devis terrain : structure imbriquée pièce → mur → déduction.
    resources :pieces,     only: [:create, :update, :destroy]
    resources :murs,       only: [:create, :update, :destroy]
    resources :deductions, only: [:create, :update, :destroy]
    resources :zones,      only: [:create, :update, :destroy]

    resources :clients, only: [:index, :show, :update, :new, :create, :destroy] do
      collection { get :kanban }
      member do
        patch :statut              # changement de colonne kanban (drag-and-drop)
        get   :message             # écran de composition d'un message libre
        post  :message, action: :envoyer_message, as: :envoyer_message
      end
      resources :notes, only: [:create, :destroy], controller: "client_notes"
    end

    patch "campagne-ads", to: "campagne_ads#update", as: :campagne_ads

    resources :factures do
      member do
        get  :pdf
        get  :envoi
        post :envoyer
        post :marquer_payee
        post :regenerer
      end
    end
    resources :encaissements, except: [:show]
    resources :depenses, except: [:show] do
      member { get :justificatif }
    end
    # Entonnoir du tunnel d'estimation (où décrochent les visiteurs)
    get "tunnel", to: "tunnel#index", as: :tunnel

    # Renvoi des conversions à Google Ads par gclid (contourne le consentement cookies)
    get  "conversions-ads",         to: "conversions_ads#index",   as: :conversions_ads
    post "conversions-ads/marquer", to: "conversions_ads#marquer", as: :marquer_conversions_ads

    # Analyse de rentabilité d'un devis (outil interne, jamais côté client)
    get  "calibrage",           to: "calibrage#index",     as: :calibrage
    post "calibrage/appliquer", to: "calibrage#appliquer", as: :calibrage_appliquer
    patch "estimations/:id/analyse", to: "devis_analyses#update",   as: :devis_analyse
    post  "estimations/:id/analyse/refiger", to: "devis_analyses#refiger", as: :devis_analyse_refiger
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
