Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # Added for bot_challenge_page engine
  get "/challenge", to: "bot_challenge_page/bot_challenge_page#challenge", as: :bot_detect_challenge
  post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge"

  get "/dummy", to: "dummy#index", as: :dummy
  get "/dummy_download", to: "dummy#download", as: :dummy_download
  get "/dummy_immediate", to: "dummy_immediate#index", as: :dummy_immediate
end
