import json
import logging
import time
from typing import Dict, Any

import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from email_validator import validate_email, EmailNotValidError
import newrelic.agent

from .config import Config
from .models import EmailMessage, InvitationMessage, InvitationData
from .email_templates import EmailTemplates

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for processing email notifications from SQS queue."""
    
    def __init__(self):
        """Initialize the notification service with AWS clients."""
        try:
            # Initialize AWS clients
            self.sqs_client = boto3.client(
                'sqs',
                region_name=Config.AWS_REGION,
                aws_access_key_id=Config.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=Config.AWS_SECRET_ACCESS_KEY
            )
            
            self.ses_client = boto3.client(
                'ses',
                region_name=Config.AWS_REGION,
                aws_access_key_id=Config.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=Config.AWS_SECRET_ACCESS_KEY
            )
            
            self.email_templates = EmailTemplates()
            
            logger.info("Notification service initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize notification service: {e}")
            raise

    def validate_email_message(self, message_data: Dict[str, Any]) -> bool:
        """Validate the email message structure and content."""
        
        required_fields = ['recipient', 'data']
        for field in required_fields:
            if field not in message_data:
                logger.error(f"Missing required field for invitation_email: {field}")
                return False
        
        data = message_data.get('data', {})
        required_data_fields = ['user_email', 'company_name', 'password']
        for field in required_data_fields:
            if field not in data:
                logger.error(f"Missing required data field for invitation_email: {field}")
                return False
        
            try:
                # Validate email address
                validate_email(message_data['recipient'])
                return True
            except EmailNotValidError as e:
                logger.error(f"Invalid email address {message_data['recipient']}: {e}")
                return False

    @newrelic.agent.function_trace()
    def send_email(self, to_email: str, subject: str, body: str, body_html: str = None) -> bool:
        """Send email using AWS SES."""
        try:
            # Prepare email message
            destination = {'ToAddresses': [to_email]}
            
            message = {
                'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                'Body': {'Text': {'Data': body, 'Charset': 'UTF-8'}}
            }
            
            # Add HTML body if provided
            if body_html:
                message['Body']['Html'] = {'Data': body_html, 'Charset': 'UTF-8'}
            
            # Send email
            response = self.ses_client.send_email(
                Source=Config.SES_FROM_EMAIL,
                Destination=destination,
                Message=message
            )
            
            logger.info(f"Email sent successfully to {to_email}. MessageId: {response['MessageId']}")
            return True
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Failed to send email to {to_email}. Error: {error_code} - {error_message}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error sending email to {to_email}: {e}")
            return False

    @newrelic.agent.background_task()
    def process_message(self, message: Dict[str, Any]) -> bool:
        """Process a single SQS message."""
        try:
            # Parse message body
            body = json.loads(message['Body'])
            logger.info(f"Processing message: {message['MessageId']}")
            logger.debug(f"Message body structure: {json.dumps(body, indent=2)}")
            
            # Handle invitation email format
            if body.get('type') == 'invitation_email':
                # Validate message structure
                if not self.validate_email_message(body):
                    logger.error(f"Invalid message structure for message: {message['MessageId']}")
                    # Delete invalid messages instead of leaving them in queue to retry
                    logger.info("Deleting invalid message from queue to prevent infinite retries")
                    return True  # Return True so the message gets deleted
                
                invitation_msg = InvitationMessage.from_dict(body)
                to_email = invitation_msg.recipient
                
                # Generate email content from invitation data
                subject, email_body, body_html = self.email_templates.generate_invitation_email(invitation_msg.data)
                
                logger.info(f"Processing invitation email for {to_email} from {invitation_msg.data.company_name}")
                
            # Handle expense notification email format
            elif body.get('type') == 'expense_notification_email':
                to_email = body.get('recipient')
                notification_data = body.get('data', {})
                
                if not to_email or not notification_data:
                    logger.error(f"Invalid expense notification message structure: {message['MessageId']}")
                    return True  # Delete invalid message
                
                # Generate email content from expense notification data
                subject, email_body, body_html = self.email_templates.generate_expense_notification_email(notification_data)
                
                logger.info(f"Processing expense notification email for {to_email} - {notification_data.get('action', 'unknown')} action")
                
            # Handle simple email format
            else:
                email_msg = EmailMessage(
                    to_email=body['to_email'],
                    subject=body['subject'],
                    body=body['body'],
                    body_html=body.get('body_html')
                )
                
                to_email = email_msg.to_email
                subject = email_msg.subject
                email_body = email_msg.body
                body_html = email_msg.body_html
                
                logger.info(f"Processing simple email for {to_email}")
            
            # Send email
            success = self.send_email(to_email, subject, email_body, body_html)
            
            # Record custom metrics for New Relic
            if success:
                newrelic.agent.record_custom_metric('Custom/NotificationService/EmailsSent', 1)
                logger.info(f"Successfully processed message: {message['MessageId']}")
                return True
            else:
                newrelic.agent.record_custom_metric('Custom/NotificationService/EmailsFailed', 1)
                logger.error(f"Failed to process message: {message['MessageId']}")
                return False
                
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse message body as JSON: {e}")
            # Delete malformed JSON messages
            logger.info("Deleting malformed JSON message from queue")
            return True
        except Exception as e:
            logger.error(f"Unexpected error processing message: {e}")
            return False

    def delete_message(self, receipt_handle: str) -> bool:
        """Delete processed message from SQS queue."""
        try:
            self.sqs_client.delete_message(
                QueueUrl=Config.SQS_QUEUE_URL,
                ReceiptHandle=receipt_handle
            )
            logger.info("Message deleted from queue successfully")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete message from queue: {e}")
            return False

    def listen_to_queue(self):
        """Main loop to listen for messages in the SQS queue."""
        logger.info(f"Starting to listen for messages on queue: {Config.SQS_QUEUE_URL}")
        
        # Record that the service is starting
        newrelic.agent.record_custom_metric('Custom/NotificationService/ServiceStarted', 1)
        
        while True:
            try:
                # Receive messages from SQS
                response = self.sqs_client.receive_message(
                    QueueUrl=Config.SQS_QUEUE_URL,
                    MaxNumberOfMessages=10,  # Process up to 10 messages at once
                    WaitTimeSeconds=20,      # Long polling for efficiency
                    VisibilityTimeout=30
                )
                
                messages = response.get('Messages', [])
                
                if not messages:
                    logger.debug("No messages received, continuing to poll...")
                    continue
                
                logger.info(f"Received {len(messages)} message(s)")
                # Record the number of messages received
                newrelic.agent.record_custom_metric('Custom/NotificationService/MessagesReceived', len(messages))
                
                # Process each message
                for message in messages:
                    success = self.process_message(message)
                    
                    if success:
                        # Delete message from queue if processed successfully
                        self.delete_message(message['ReceiptHandle'])
                    else:
                        logger.warning(f"Message processing failed, leaving in queue: {message['MessageId']}")
                
            except KeyboardInterrupt:
                logger.info("Received shutdown signal, stopping...")
                break
            except NoCredentialsError:
                logger.error("AWS credentials not found. Please check your configuration.")
                break
            except ClientError as e:
                logger.error(f"AWS client error: {e}")
                time.sleep(5)  # Wait before retrying
            except Exception as e:
                logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(5)  # Wait before retrying 