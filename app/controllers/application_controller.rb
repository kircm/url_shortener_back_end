class ApplicationController < ActionController::API
  def not_found
    render :status => 404
  end
  def application_error
    render :status => 500
  end
  rescue_from StandardError do
    render :status => 500
  end
end
