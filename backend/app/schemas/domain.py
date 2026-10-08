from typing import Literal

from pydantic import BaseModel, Field, model_validator

CardStatus = Literal["active", "frozen", "closed"]
TransactionDecision = Literal["APPROVED", "DECLINED", "FLAGGED"]
TransactionChannel = Literal["ONLINE", "POS", "ATM"]


class Customer(BaseModel):
    id: str
    name: str
    email: str
    kyc_status: str
    member_since: str
    application_status: Literal[
        "draft", "kyc_in_progress", "kyc_verified", "card_pending", "card_active"
    ] = "draft"


class CardControls(BaseModel):
    daily_limit: int | None = Field(default=None, ge=1000, le=250000)
    international_enabled: bool | None = None
    contactless_enabled: bool | None = None
    online_enabled: bool | None = None
    atm_enabled: bool | None = None

    @model_validator(mode="after")
    def require_control(self) -> "CardControls":
        if not self.model_fields_set:
            raise ValueError("At least one card control must be provided")
        if any(getattr(self, name) is None for name in self.model_fields_set):
            raise ValueError("Card controls cannot be null")
        return self


class VirtualCardCreate(BaseModel):
    nickname: str = Field(default="GEM Virtual", min_length=1, max_length=40)
    daily_limit: int = Field(default=25000, ge=1000, le=250000)


class Card(BaseModel):
    id: str
    customer_id: str
    product: str
    card_type: Literal["physical", "virtual"]
    network: Literal["Visa", "RuPay"]
    masked_number: str
    expiry: str
    status: CardStatus
    daily_limit: int
    international_enabled: bool
    contactless_enabled: bool
    online_enabled: bool
    atm_enabled: bool


class Transaction(BaseModel):
    id: str
    authorization_id: str
    card_id: str
    merchant: str
    amount: float
    currency: str = "INR"
    country: str
    channel: TransactionChannel
    decision: TransactionDecision
    occurred_at: str
    reasons: list[str] = Field(default_factory=list)


class AuthorizationRequest(BaseModel):
    card_id: str = Field(min_length=1, max_length=40)
    merchant: str = Field(min_length=1, max_length=80)
    amount: float = Field(gt=0, le=10000000)
    country: str = Field(min_length=2, max_length=80)
    channel: TransactionChannel


class RuleResult(BaseModel):
    rule: str
    passed: bool
    detail: str


class AuthorizationResponse(BaseModel):
    decision: TransactionDecision
    authorization_id: str
    reasons: list[str]
    rule_results: list[RuleResult]


class FraudAlert(BaseModel):
    id: str
    transaction_id: str
    customer_id: str
    merchant: str
    amount: float
    country: str
    severity: Literal["low", "medium", "high"]
    reason: str
    status: Literal["open", "resolved"] = "open"
    created_at: str
    resolved_at: str | None = None


class DisputeCreate(BaseModel):
    transaction_id: str = Field(min_length=1, max_length=40)
    reason: str = Field(min_length=3, max_length=120)
    details: str | None = Field(default=None, max_length=500)


class Dispute(BaseModel):
    id: str
    transaction_id: str
    customer_id: str
    reason: str
    details: str | None = None
    status: Literal["open", "investigating", "resolved"] = "open"
    created_at: str


class RewardSummary(BaseModel):
    customer_id: str
    points: int
    available_value: float
    currency: str = "INR"


class CustomerDashboard(BaseModel):
    customer: Customer
    available_balance: float
    currency: str = "INR"
    cards: list[Card]
    recent_transactions: list[Transaction]
    open_fraud_alerts: list[FraudAlert]
    rewards: RewardSummary
