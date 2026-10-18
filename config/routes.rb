Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :account, only: %i[ show update destroy ]

  resources :recipes do
    resource :favorite, only: %i[ create destroy ]
    resources :shopping_items, only: :create, controller: "recipe_shopping_items"
    resources :reports, only: %i[ new create ]
  end
  resources :shopping_items, only: %i[ index create update destroy ] do
    collection do
      delete :clear_checked
      delete :clear_all
    end
  end
  resources :meal_plans, only: %i[ index create destroy ] do
    collection { post :add_to_shopping_list }
  end
  resources :favorites, only: :index
  resources :tags, only: :index
  get "my/recipes", to: "my_recipes#index", as: :my_recipes
  resources :trashed_recipes, path: "trash", only: %i[ index destroy ] do
    member { post :restore }
    collection { delete :empty }
  end

  # 管理画面(管理者だけ。それ以外の人には 404)
  namespace :admin do
    root to: redirect("/admin/reports")
    resources :reports, only: %i[ index update ]
    resources :recipes, only: [] do
      member do
        post :hide
        post :unhide
      end
    end
    resources :users, only: :index do
      member do
        post :suspend
        post :unsuspend
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"
end
