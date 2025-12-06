require "test_helper"

class Api::V1::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @valid_params = {
      audit_log: {
        action: "create",
        resource_type: "User",
        resource_id: 1,
        user_id: 1,
        company_id: 1,
        user_email: "test@example.com",
        data: { "name" => "John Doe" }
      }
    }
  end

  # INDEX tests
  test "should get index with company_id" do
    get api_v1_audit_logs_url, params: { company_id: 1 }
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('audit_logs')
    assert json_response.key?('total_count')
  end

  test "should filter by date range" do
    start_date = 1.day.ago.to_date.to_s
    end_date = Date.current.to_s
    
    get api_v1_audit_logs_url, params: { 
      company_id: 1, 
      start_date: start_date, 
      end_date: end_date 
    }
    assert_response :success
  end

  test "should ignore invalid date formats" do
    get api_v1_audit_logs_url, params: { 
      company_id: 1, 
      start_date: "invalid-date", 
      end_date: "also-invalid" 
    }
    assert_response :success
  end

  test "should filter by user_id" do
    get api_v1_audit_logs_url, params: { company_id: 1, user_id: 1 }
    assert_response :success
  end

  test "should filter by user_email" do
    get api_v1_audit_logs_url, params: { company_id: 1, user_email: "test@example.com" }
    assert_response :success
  end

  test "should filter by audit_action" do
    get api_v1_audit_logs_url, params: { company_id: 1, audit_action: "create" }
    assert_response :success
  end

  test "should filter by resource_type" do
    get api_v1_audit_logs_url, params: { company_id: 1, resource_type: "User" }
    assert_response :success
  end

  test "should handle pagination" do
    get api_v1_audit_logs_url, params: { company_id: 1, page: 1, per_page: 10 }
    assert_response :success
  end

  test "should use default pagination values" do
    get api_v1_audit_logs_url, params: { company_id: 1 }
    assert_response :success
  end

  test "should handle case insensitive email search" do
    get api_v1_audit_logs_url, params: { company_id: 1, user_email: "TEST@EXAMPLE.COM" }
    assert_response :success
  end

  # SHOW tests
  test "should show audit_log" do
    audit_log = audit_logs(:valid_log)
    get api_v1_audit_log_url(audit_log.id)
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal audit_log.id, json_response['id']
  end

  test "should return 404 for non-existent audit_log" do
    get api_v1_audit_log_url(999999)
    assert_response :not_found
  end

  # CREATE tests
  test "should create audit_log with valid params" do
    assert_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: @valid_params
    end
    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "create", json_response['action']
    assert_equal "Audit log created successfully", json_response['message']
  end

  test "should not create audit_log with invalid params" do
    invalid_params = @valid_params.deep_dup
    invalid_params[:audit_log].delete(:action)
    
    assert_no_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: invalid_params
    end
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?('errors')
  end

  test "should handle missing required parameters" do
    assert_no_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: { audit_log: {} }
    end
    assert_response :bad_request
  end

  test "should handle missing audit_log parameter" do
    post api_v1_audit_logs_url, params: {}
    assert_response :bad_request
  end

  test "should create audit_log without user_id" do
    params = @valid_params.deep_dup
    params[:audit_log].delete(:user_id)
    
    assert_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: params
    end
    assert_response :created
  end

  test "should create audit_log without user_email" do
    params = @valid_params.deep_dup
    params[:audit_log].delete(:user_email)
    
    assert_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: params
    end
    assert_response :created
  end

  test "should create audit_log with empty data" do
    params = @valid_params.deep_dup
    params[:audit_log][:data] = {}
    
    assert_difference('AuditLog.count') do
      post api_v1_audit_logs_url, params: params
    end
    assert_response :created
  end

  # JSON format tests
  test "should set json format by default" do
    get api_v1_audit_logs_url, params: { company_id: 1 }
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should handle different company filters" do
    get api_v1_audit_logs_url, params: { company_id: 2 }
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('audit_logs')
  end

  # Edge cases for pagination
  test "should handle zero page" do
    get api_v1_audit_logs_url, params: { company_id: 1, page: 0 }
    assert_response :success
  end

  test "should handle negative page" do
    get api_v1_audit_logs_url, params: { company_id: 1, page: -1 }
    assert_response :success
  end

  test "should handle string parameters" do
    get api_v1_audit_logs_url, params: { 
      company_id: "1", 
      user_id: "1", 
      page: "2", 
      per_page: "25" 
    }
    assert_response :success
  end

  test "should handle empty filter parameters" do
    get api_v1_audit_logs_url, params: { 
      company_id: 1,
      user_email: "",
      audit_action: "",
      resource_type: "",
      start_date: "",
      end_date: ""
    }
    assert_response :success
  end

  test "should handle nil company_id" do
    get api_v1_audit_logs_url, params: { company_id: nil }
    assert_response :success
  end
end 