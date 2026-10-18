Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  resources :recipes do
    resource :favorite, only: %i[ create destroy ]
  end
  resources :favorites, only: :index
  resources :tags, only: :index
  get "my/recipes", to: "my_recipes#index", as: :my_recipes
  resources :trashed_recipes, path: "trash", only: %i[ index destroy ] do
    member { post :restore }
    collection { delete :empty }
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"
end
