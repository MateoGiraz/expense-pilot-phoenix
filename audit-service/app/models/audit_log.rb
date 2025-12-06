class AuditLog < ApplicationRecord
  # Validations
  validates :action, presence: true
  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :company_id, presence: true

  # Scopes
  scope :by_company, ->(company_id) { where(company_id: company_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :sort_by_date, -> { order(created_at: :desc) }
end
