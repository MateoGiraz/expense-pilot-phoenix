# Notification Service

A Python service that listens to AWS SQS queue and sends emails using AWS SES.

## Features

- Email Processing: Supports both invitation emails and simple email formats
- AWS Integration: SQS for message queuing, SES for email delivery

## Project Structure

```
notification-service/
├── src/
│   ├── __init__.py           # Package init
│   ├── config.py             # Configuration management
│   ├── models.py             # Data models and types
│   ├── email_templates.py    # Email template generation
│   └── notification_service.py # Main service logic
├── main.py                   # Application entry point
├── requirements.txt          # Python dependencies
├── Dockerfile                # Container configuration
├── env.example               # Environment variables template
└── README.md                 # This file
```

## Prerequisites

- Python 3.11+
- AWS Account with SQS and SES configured
- AWS credentials (Access Key ID and Secret Access Key)

## Installation

### Using pip

1. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### Configuration

1. Copy the environment example file:
   ```bash
   cp env.example .env
   ```

2. Update the `.env` file with your AWS configuration:
   ```bash
   AWS_ACCESS_KEY_ID=your_aws_access_key_id
   AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
   AWS_REGION=us-east-1
   SQS_QUEUE_URL=your_sqs_queue_url
   SES_FROM_EMAIL=your_verified_ses_email@example.com
   LOG_LEVEL=INFO
   ```

## Usage

### Running the Service

```bash
# Make sure your virtual environment is activated
python main.py
```

## Message Formats

### Invitation Email
```json
{
  "type": "invitation_email",
  "recipient": "user@example.com",
  "data": {
    "user_email": "user@example.com",
    "company_name": "Your Company",
    "password": "temp_password",
    "login_url": "http://localhost:4000/login"
  }
}
```

### Environment Variables

All configuration is handled through environment variables:

- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key  
- `AWS_REGION` - AWS region (default: us-east-1)
- `SQS_QUEUE_URL` - SQS queue URL
- `SES_FROM_EMAIL` - Verified SES sender email
- `LOG_LEVEL` - Logging level (default: INFO)

## Run with docker

### Build Image
```bash
docker build -t notification-service .
```

### Run Container
```bash
docker run --env-file .env notification-service
```

### Docker Compose (Optional)
```yaml
version: '3.8'
services:
  notification-service:
    build: .
    env_file: .env
    restart: unless-stopped
```

## AWS Setup

### SES Configuration
1. Verify your sender email address in AWS SES
2. If in SES sandbox, verify recipient email addresses
3. Request production access if needed

### SQS Configuration  
1. Create an SQS queue
2. Note the queue URL for configuration
3. Ensure proper IAM permissions

### Required AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "arn:aws:sqs:*:*:your-queue-name"
    },
    {
      "Effect": "Allow", 
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    }
  ]
}
```

## Monitoring and Logging

The service provides comprehensive logging:
- Service initialization and health
- Message processing status
- Email delivery results
- Error details and stack traces

Configure log level via the `LOG_LEVEL` environment variable.
