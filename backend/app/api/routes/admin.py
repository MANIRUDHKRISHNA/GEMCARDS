"""Deterministic, in-memory operations-console data for the GEMCARDS demo."""
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix='/api/v1/admin', tags=['admin'])

CUSTOMERS = [
    {'id': 'CUS-DEMO-001', 'name': 'Alex Morgan', 'email': 'alex.morgan@example.demo', 'kyc_status': 'verified', 'cards': 2, 'transactions': 18, 'risk': 'low'},
    {'id': 'CUS-DEMO-002', 'name': 'Priya Shah', 'email': 'priya.shah@example.demo', 'kyc_status': 'under_review', 'cards': 1, 'transactions': 7, 'risk': 'medium'},
    {'id': 'CUS-DEMO-003', 'name': 'Jordan Lee', 'email': 'jordan.lee@example.demo', 'kyc_status': 'pending', 'cards': 0, 'transactions': 0, 'risk': 'low'},
]
CARDS = [
    {'id': 'CARD-001', 'masked_number': '•••• 4821', 'customer_id': 'CUS-DEMO-001', 'customer': 'Alex Morgan', 'product': 'GEMCARDS Platinum', 'type': 'physical', 'network': 'Visa', 'status': 'active', 'issued_at': '2026-10-09', 'expiry': '09/30', 'limit': 50000, 'international_enabled': False, 'contactless_enabled': True},
    {'id': 'CARD-V01', 'masked_number': '•••• 9104', 'customer_id': 'CUS-DEMO-001', 'customer': 'Alex Morgan', 'product': 'GEM Virtual', 'type': 'virtual', 'network': 'Visa', 'status': 'active', 'issued_at': '2026-10-09', 'expiry': '09/30', 'limit': 25000, 'international_enabled': False, 'contactless_enabled': False},
    {'id': 'CARD-002', 'masked_number': '•••• 7730', 'customer_id': 'CUS-DEMO-002', 'customer': 'Priya Shah', 'product': 'GEMCARDS Classic', 'type': 'physical', 'network': 'RuPay', 'status': 'frozen', 'issued_at': '2026-10-08', 'expiry': '10/30', 'limit': 30000, 'international_enabled': True, 'contactless_enabled': True},
]
TRANSACTIONS = [
    {'id': 'TXN-101', 'amount': 1240, 'merchant': 'Metro Mart', 'customer': 'Alex Morgan', 'card': '•••• 4821', 'timestamp': '2026-10-09T10:42:00Z', 'status': 'approved', 'risk_score': 8},
    {'id': 'TXN-102', 'amount': 299, 'merchant': 'CloudStream', 'customer': 'Alex Morgan', 'card': '•••• 4821', 'timestamp': '2026-10-08T20:11:00Z', 'status': 'approved', 'risk_score': 4},
    {'id': 'TXN-103', 'amount': 9800, 'merchant': 'Northstar Electronics', 'customer': 'Priya Shah', 'card': '•••• 7730', 'timestamp': '2026-10-09T08:16:00Z', 'status': 'declined', 'risk_score': 91},
]
FRAUD = [{'id': 'FRA-01', 'severity': 'high', 'customer': 'Priya Shah', 'amount': 9800, 'location': 'Singapore', 'risk_score': 91, 'reason': 'Large foreign purchase on a frozen card', 'status': 'open', 'transaction_id': 'TXN-103'}]
DISPUTES = [{'id': 'DSP-01', 'transaction_id': 'TXN-101', 'customer': 'Alex Morgan', 'reason': 'Merchant recognition', 'status': 'open', 'date': '2026-10-09', 'notes': ['Opened by customer', 'Awaiting operations review']}]

class Simulation(BaseModel):
    card_id: str
    merchant: str = Field(min_length=1, max_length=80)
    amount: float = Field(gt=0)
    country: str = Field(min_length=2, max_length=80)
    transaction_type: Literal['purchase', 'atm', 'online'] = 'purchase'

class LimitUpdate(BaseModel): limit: int = Field(ge=1000, le=250000)
class StatusUpdate(BaseModel): status: Literal['open', 'investigating', 'dismissed', 'resolved']

def find(items: list[dict], item_id: str) -> dict:
    item = next((entry for entry in items if entry['id'] == item_id), None)
    if not item: raise HTTPException(404, 'Demo record not found')
    return item

@router.get('/metrics')
def metrics() -> dict:
    return {'total_customers': 12480, 'active_cards': 18340, 'transactions_today': 918, 'transaction_volume': 1284500, 'pending_kyc': 24, 'fraud_alerts': len([item for item in FRAUD if item['status'] == 'open']), 'open_disputes': len([item for item in DISPUTES if item['status'] == 'open']), 'cards_issued_today': 42, 'volume_series': [64, 82, 70, 94, 108, 121, 116], 'issuance_series': [18, 22, 19, 34, 28, 42, 39]}

@router.get('/customers')
def customers(query: str = '', kyc_status: str = '') -> list[dict]:
    needle = query.lower()
    return [customer for customer in CUSTOMERS if (not needle or needle in customer['name'].lower() or needle in customer['id'].lower()) and (not kyc_status or customer['kyc_status'] == kyc_status)]

@router.get('/customers/{customer_id}')
def customer_detail(customer_id: str) -> dict:
    customer = find(CUSTOMERS, customer_id)
    return {**customer, 'cards_detail': [card for card in CARDS if card['customer_id'] == customer_id], 'transactions_detail': [transaction for transaction in TRANSACTIONS if transaction['customer'] == customer['name']], 'disputes': [dispute for dispute in DISPUTES if dispute['customer'] == customer['name']]}

@router.get('/cards')
def cards(status: str = '') -> list[dict]: return [card for card in CARDS if not status or card['status'] == status]
@router.get('/cards/{card_id}')
def card_detail(card_id: str) -> dict: return find(CARDS, card_id)
@router.post('/cards/{card_id}/freeze')
def freeze(card_id: str) -> dict: card = find(CARDS, card_id); card['status'] = 'frozen'; return card
@router.post('/cards/{card_id}/unfreeze')
def unfreeze(card_id: str) -> dict: card = find(CARDS, card_id); card['status'] = 'active'; return card
@router.post('/cards/{card_id}/limit')
def update_limit(card_id: str, payload: LimitUpdate) -> dict: card = find(CARDS, card_id); card['limit'] = payload.limit; return card
@router.post('/cards/{card_id}/replace')
def replace(card_id: str) -> dict: card = find(CARDS, card_id); card['status'] = 'replaced'; return {'card': card, 'message': 'Demo replacement requested'}

@router.get('/transactions')
def transactions(status: str = '') -> list[dict]: return [transaction for transaction in TRANSACTIONS if not status or transaction['status'] == status]
@router.post('/transactions/simulate')
def simulate(payload: Simulation) -> dict:
    card = find(CARDS, payload.card_id)
    rules = []
    if card['status'] != 'active': rules.append(('Card status', False, 'Card is not active'))
    else: rules.append(('Card status', True, 'Card is active'))
    if payload.amount > card['limit']: rules.append(('Spending limit', False, 'Amount exceeds demo card limit'))
    else: rules.append(('Spending limit', True, 'Amount is within the card limit'))
    foreign = payload.country.lower() not in {'india', 'in'}
    if foreign and not card['international_enabled']: rules.append(('International controls', False, 'International payments are disabled'))
    else: rules.append(('International controls', True, 'Location is permitted'))
    flagged = foreign and payload.amount >= 7500
    decision = 'DECLINED' if any(not result for _, result, _ in rules) else ('FLAGGED' if flagged else 'APPROVED')
    return {'decision': decision, 'authorization_id': 'AUTH-DEMO-4821', 'rules': [{'name': name, 'passed': passed, 'explanation': explanation} for name, passed, explanation in rules], 'explanation': 'Large unusual foreign transaction needs review.' if flagged else 'Deterministic demo rules completed.'}

@router.get('/fraud')
def fraud() -> list[dict]: return FRAUD
@router.post('/fraud/{alert_id}/resolve')
def resolve_fraud(alert_id: str, payload: StatusUpdate) -> dict: alert = find(FRAUD, alert_id); alert['status'] = payload.status; return alert
@router.get('/disputes')
def disputes() -> list[dict]: return DISPUTES
@router.post('/disputes/{dispute_id}/status')
def update_dispute(dispute_id: str, payload: StatusUpdate) -> dict: dispute = find(DISPUTES, dispute_id); dispute['status'] = payload.status; dispute['notes'].append(f'Status set to {payload.status} in demo'); return dispute
