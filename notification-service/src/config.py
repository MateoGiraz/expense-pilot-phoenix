import logging
from decouple import config


class Config:
    """Configuration settings for the notification service."""
    
    # AWS Configuration
    AWS_REGION = config('AWS_REGION', default='us-east-1')
    AWS_ACCESS_KEY_ID = config('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = config('AWS_SECRET_ACCESS_KEY')
    
    # SQS Configuration
    SQS_QUEUE_URL = config('SQS_QUEUE_URL')
    
    # SES Configuration
    SES_FROM_EMAIL = config('SES_FROM_EMAIL')
    
    # Application Configuration
    LOG_LEVEL = config('LOG_LEVEL', default='INFO')
    
    @classmethod
    def setup_logging(cls):
        """Setup logging configuration."""
        logging.basicConfig(
            level=cls.LOG_LEVEL,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(__name__) 