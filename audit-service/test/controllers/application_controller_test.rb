require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should handle 404 errors" do
    get "/api/v1/audit_logs/999999"
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Not Found", json_response['error']
  end

  test "should handle 400 errors for missing parameters" do
    post "/api/v1/audit_logs", params: {}
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Bad Request", json_response['error']
  end
end

# Separate test class to test authentication methods directly
class AuthenticationTest < ActionDispatch::IntegrationTest
  test "authentication method returns unauthorized when no api key" do
    controller = ApplicationController.new
    request = ActionDispatch::Request.new({})
    controller.request = request
    
    # Mock the render method to capture the response
    rendered_response = nil
    controller.define_singleton_method(:render) do |options|
      rendered_response = options
    end
    
    # Set up environment
    ENV.delete('API_SECRET_KEY')
    
    # Call the private method
    controller.send(:authenticate_api_key)
    
    assert_equal({ json: { error: 'Unauthorized' }, status: :unauthorized }, rendered_response)
  end

  test "authentication method returns unauthorized when api keys don't match" do
    ENV['API_SECRET_KEY'] = 'correct-key'
    
    controller = ApplicationController.new
    request = ActionDispatch::Request.new({
      'HTTP_X_API_KEY' => 'wrong-key'
    })
    controller.request = request
    
    # Mock the render method to capture the response
    rendered_response = nil
    controller.define_singleton_method(:render) do |options|
      rendered_response = options
    end
    
    # Call the private method
    controller.send(:authenticate_api_key)
    
    assert_equal({ json: { error: 'Unauthorized' }, status: :unauthorized }, rendered_response)
    
    ENV.delete('API_SECRET_KEY')
  end

  test "authentication method passes when api keys match" do
    ENV['API_SECRET_KEY'] = 'correct-key'
    
    controller = ApplicationController.new
    request = ActionDispatch::Request.new({
      'HTTP_X_API_KEY' => 'correct-key'
    })
    controller.request = request
    
    # Mock the render method - should not be called
    render_called = false
    controller.define_singleton_method(:render) do |options|
      render_called = true
    end
    
    # Call the private method
    controller.send(:authenticate_api_key)
    
    assert_not render_called, "render should not be called when authentication passes"
    
    ENV.delete('API_SECRET_KEY')
  end

  test "authentication method returns unauthorized when api secret key not configured" do
    ENV.delete('API_SECRET_KEY')
    
    controller = ApplicationController.new
    request = ActionDispatch::Request.new({
      'HTTP_X_API_KEY' => 'some-key'
    })
    controller.request = request
    
    # Mock the render method to capture the response
    rendered_response = nil
    controller.define_singleton_method(:render) do |options|
      rendered_response = options
    end
    
    # Call the private method
    controller.send(:authenticate_api_key)
    
    assert_equal({ json: { error: 'Unauthorized' }, status: :unauthorized }, rendered_response)
  end
end 