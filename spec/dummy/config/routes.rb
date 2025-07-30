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


  # dummy app paths we are testing
  get "/dummy/immediate", to: "dummy_rate_limit#immediate", as: :dummy_immediate
  get "/dummy/rate_limit_1", to: "dummy_rate_limit#rate_limit_1", as: :dummy_rate_limit_1
  get "/dummy/download", to: "dummy_rate_limit#download", as: :dummy_download

  get "/alternate_dummy/rate_limit_1", to: "alternate_dummy_rate_limit#rate_limit_1", as: :alternate_dummy_rate_limit_1
  get "/alternate_dummy/rate_limit_1_with_separate_counter", to: "alternate_dummy_rate_limit#rate_limit_1_with_separate_counter", as: :alternate_dummy_rate_limit_1_with_separate_counter
end
