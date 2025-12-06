require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      action: "create",
      resource_type: "User",
      resource_id: 1,
      company_id: 1,
      user_id: 1,
      user_email: "test@example.com",
      data: { "name" => "John Doe" }
    }
  end

  test "should be valid with valid attributes" do
    audit_log = AuditLog.new(@valid_attributes)
    assert audit_log.valid?
  end

  test "should require action" do
    audit_log = AuditLog.new(@valid_attributes.except(:action))
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:action], "can't be blank"
  end

  test "should require resource_type" do
    audit_log = AuditLog.new(@valid_attributes.except(:resource_type))
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:resource_type], "can't be blank"
  end

  test "should require resource_id" do
    audit_log = AuditLog.new(@valid_attributes.except(:resource_id))
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:resource_id], "can't be blank"
  end

  test "should require company_id" do
    audit_log = AuditLog.new(@valid_attributes.except(:company_id))
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:company_id], "can't be blank"
  end

  test "by_company scope filters by company_id" do
    logs = AuditLog.by_company(1)
    assert_equal 2, logs.count
    logs.each do |log|
      assert_equal 1, log.company_id
    end
  end

  test "by_user scope filters by user_id" do
    logs = AuditLog.by_user(1)
    assert_equal 1, logs.count
    assert_equal 1, logs.first.user_id
  end

  test "sort_by_date scope orders by created_at desc" do
    logs = AuditLog.sort_by_date
    assert logs.count > 0
    previous_date = Time.current
    logs.each do |log|
      assert log.created_at <= previous_date
      previous_date = log.created_at
    end
  end

  test "should allow nil user_id" do
    audit_log = AuditLog.new(@valid_attributes.merge(user_id: nil))
    assert audit_log.valid?
  end

  test "should allow nil user_email" do
    audit_log = AuditLog.new(@valid_attributes.merge(user_email: nil))
    assert audit_log.valid?
  end

  test "should allow empty data" do
    audit_log = AuditLog.new(@valid_attributes.merge(data: {}))
    assert audit_log.valid?
  end
end 