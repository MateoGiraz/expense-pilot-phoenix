class Api::V1::AuditLogsController < ApplicationController
  before_action :set_default_format
  
  def index
    company_id = params[:company_id]&.to_i
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    
    # Calculate offset
    offset = (page - 1) * per_page
    
    # Build base query
    query = AuditLog.by_company(company_id)
    
    # Apply filters
    query = apply_filters(query)
    
    # Get paginated results
    @audit_logs = query.sort_by_date
                       .limit(per_page)
                       .offset(offset)
    
    # Get total count for pagination
    @total_count = query.count
  end

  def show
    @audit_log = AuditLog.find(params[:id])
  end

  def create
    @audit_log = AuditLog.new(audit_log_params)
    
    if @audit_log.save
      render :create, status: :created
    else
      render json: { errors: @audit_log.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_default_format
    request.format = :json
  end

  def audit_log_params
    params.require(:audit_log).permit(:action, :resource_type, :resource_id, :user_id, :company_id, :user_email, data: {})
  end

  def apply_filters(query)
    # Filter by date range
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        query = query.where('created_at >= ?', start_date.beginning_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end

    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        query = query.where('created_at <= ?', end_date.end_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end

    # Filter by user
    if params[:user_id].present?
      query = query.by_user(params[:user_id])
    end

    if params[:user_email].present?
      # Use LIKE with UPPER for SQLite compatibility (instead of ILIKE)
      query = query.where('UPPER(user_email) LIKE ?', "%#{params[:user_email].upcase}%")
    end

    # Filter by action type - use audit_action instead of action to avoid Rails conflict
    if params[:audit_action].present?
      query = query.where(action: params[:audit_action])
    end

    # Filter by resource type
    if params[:resource_type].present?
      query = query.where(resource_type: params[:resource_type])
    end

    query
  end
end
