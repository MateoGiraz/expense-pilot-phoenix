#!/usr/bin/env python3
"""
Notification Service Entry Point

A simple Python service that listens to AWS SQS queue and sends emails using AWS SES.
"""

import sys
import newrelic.agent
from src.config import Config
from src.notification_service import NotificationService

# Setup logging
logger = Config.setup_logging()


@newrelic.agent.background_task()
def main():
    """Main function to start the notification service."""
    try:
        logger.info("Starting Notification Service...")
        # Record application start event
        newrelic.agent.record_custom_event('NotificationServiceStarted', {
            'service_name': 'notification-service',
            'version': '1.0.0'
        })
        service = NotificationService()
        service.listen_to_queue()
    except KeyboardInterrupt:
        logger.info("Service stopped by user")
        return 0
    except Exception as e:
        logger.error(f"Failed to start notification service: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main()) 