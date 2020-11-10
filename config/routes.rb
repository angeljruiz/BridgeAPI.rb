Rails.application.routes.draw do
  post 'users', to: 'users#create'
  get 'users', to: 'users#show'
  patch 'users', to: 'users#update'
  put 'users', to: 'users#update'
  delete 'users', to: 'users#destroy'
  post 'login', to: 'sessions#create'
  get 'events', to: 'events#index'
end
