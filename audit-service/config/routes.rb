Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :audit_logs, only: [:index, :show, :create]
    end
  end

  get "/" => "rails/health#show", as: :rails_health_check
end
