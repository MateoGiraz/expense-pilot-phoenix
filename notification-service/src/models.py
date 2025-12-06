from typing import Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class EmailMessage:
    """Simple email message format."""
    to_email: str
    subject: str
    body: str
    body_html: Optional[str] = None


@dataclass
class InvitationData:
    """Data structure for invitation emails."""
    user_email: str
    company_name: str
    password: str
    login_url: Optional[str] = "http://localhost:4000/login"


@dataclass
class InvitationMessage:
    """Invitation email message format."""
    type: str
    recipient: str
    data: InvitationData
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'InvitationMessage':
        """Create InvitationMessage from dictionary."""
        invitation_data = InvitationData(**data['data'])
        return cls(
            type=data['type'],
            recipient=data['recipient'],
            data=invitation_data
        ) 