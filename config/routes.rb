Rails.application.routes.draw do
  resources :shortened_urls, only: [:show, :create, :destroy], module: 'shortener'
end
