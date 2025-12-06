class ApplicationController < ActionController::API
  before_action :authenticate_api_key, unless: -> { Rails.env.test? }

  rescue_from ActiveRecord::RecordNotFound, with: :render_404
  rescue_from ActionController::ParameterMissing, with: :render_400

  private

  def authenticate_api_key
    api_key = request.headers['X-API-Key']
    expected_key = ENV['API_SECRET_KEY']
    
    unless api_key.present? && expected_key.present? && api_key == expected_key
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def render_404
    render json: { error: 'Not Found' }, status: :not_found
  end

  def render_400
    render json: { error: 'Bad Request' }, status: :bad_request
  end
end
