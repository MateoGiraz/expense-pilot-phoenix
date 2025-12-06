from typing import Tuple, Dict, Any
from .models import InvitationData


class EmailTemplates:
    """Email template generator for different types of notifications."""
    
    @staticmethod
    def generate_invitation_email(data: InvitationData) -> Tuple[str, str, str]:
        """Generate subject, body, and HTML for invitation email."""
        subject = f"Welcome to {data.company_name} - Your Account is Ready!"
        
        body = f"""Hello!

You have been invited to join {data.company_name} on our expense management platform.

Your login credentials:
• Email: {data.user_email}
• Password: {data.password}

Please log in at: {data.login_url}

For your security, we recommend changing your password after your first login.

Welcome aboard!

Best regards,
The {data.company_name} Team"""

        body_html = f"""
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #2c3e50;">Welcome to {data.company_name}!</h1>
        
        <p>Hello!</p>
        
        <p>You have been invited to join <strong>{data.company_name}</strong> on our expense management platform.</p>
        
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #495057;">Your Login Credentials:</h3>
            <p><strong>Email:</strong> {data.user_email}</p>
            <p><strong>Password:</strong> <code style="background-color: #e9ecef; padding: 2px 6px; border-radius: 3px;">{data.password}</code></p>
        </div>
        
        <p>
            <a href="{data.login_url}" 
               style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0;">
                Log In Now
            </a>
        </p>
        
        <p style="color: #6c757d; font-size: 14px;">
            <strong>Security Note:</strong> For your security, we recommend changing your password after your first login.
        </p>
        
        <p>Welcome aboard!</p>
        
        <p>Best regards,<br>
        The {data.company_name} Team</p>
    </div>
</body>
</html>"""
        
        return subject, body, body_html
    
    @staticmethod
    def generate_expense_notification_email(data: Dict[str, Any]) -> Tuple[str, str, str]:
        """Generate subject, body, and HTML for expense notification email."""
        action = data['action']
        expense = data['expense']
        performed_by = data['performed_by']
        performed_at = data['performed_at']
        
        # Format action for display
        action_past = {
            'created': 'created',
            'updated': 'updated', 
            'deleted': 'deleted'
        }.get(action, action)
        
        action_color = {
            'created': '#28a745',
            'updated': '#ffc107',
            'deleted': '#dc3545'
        }.get(action, '#6c757d')
        
        subject = f"Expense {action_past} - ${expense['amount']} ({expense['category']})"
        
        body = f"""Expense Notification

An expense has been {action_past} in your area.

Expense Details:
• ID: {expense['id']}
• Amount: ${expense['amount']}
• Date: {expense['date']}
• Category: {expense['category']}
• Owner: {expense['owner']}
• Company: {expense['company']}

Action performed by: {performed_by}
Date/Time: {performed_at}

This notification was sent because you are subscribed to expense notifications for your area.

Best regards,
Expense Management System"""

        body_html = f"""
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background-color: {action_color}; color: white; padding: 15px; border-radius: 5px; margin-bottom: 20px;">
            <h1 style="margin: 0; font-size: 24px;">Expense {action_past.title()}</h1>
        </div>
        
        <p>An expense has been <strong>{action_past}</strong> in your area.</p>
        
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #495057;">Expense Details:</h3>
            <table style="width: 100%; border-collapse: collapse;">
                <tr>
                    <td style="padding: 8px 0; font-weight: bold; width: 120px;">ID:</td>
                    <td style="padding: 8px 0;">#{expense['id']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; font-weight: bold;">Amount:</td>
                    <td style="padding: 8px 0; font-size: 18px; color: {action_color}; font-weight: bold;">${expense['amount']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; font-weight: bold;">Date:</td>
                    <td style="padding: 8px 0;">{expense['date']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; font-weight: bold;">Category:</td>
                    <td style="padding: 8px 0;"><span style="background-color: #e9ecef; padding: 4px 8px; border-radius: 3px;">{expense['category']}</span></td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; font-weight: bold;">Owner:</td>
                    <td style="padding: 8px 0;">{expense['owner']}</td>
                </tr>
                <tr>
                    <td style="padding: 8px 0; font-weight: bold;">Company:</td>
                    <td style="padding: 8px 0;">{expense['company']}</td>
                </tr>
            </table>
        </div>
        
        <div style="border-left: 4px solid #007bff; padding-left: 15px; margin: 20px 0;">
            <p style="margin: 0; color: #6c757d; font-size: 14px;">
                <strong>Action performed by:</strong> {performed_by}<br>
                <strong>Date/Time:</strong> {performed_at}
            </p>
        </div>
        
        <p style="color: #6c757d; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6;">
            This notification was sent because you are subscribed to expense notifications for your area.
            You can manage your notification preferences in the expense management system.
        </p>
        
        <p>Best regards,<br>
        Expense Management System</p>
    </div>
</body>
</html>"""
        
        return subject, body, body_html 