enum CardStatus { active, frozen, pending }
enum TransactionStatus { approved, declined, pending }
enum FraudSeverity { low, medium, high }

class Customer { const Customer({required this.id, required this.name, required this.email}); final String id; final String name; final String email; }
class Card { const Card({required this.id, required this.lastFour, required this.type, required this.status, required this.virtual}); final String id; final String lastFour; final String type; final CardStatus status; final bool virtual; }
class CardTransaction { const CardTransaction({required this.id, required this.merchant, required this.amount, required this.status, required this.time}); final String id; final String merchant; final double amount; final TransactionStatus status; final DateTime time; }
class FraudAlert { const FraudAlert({required this.id, required this.title, required this.severity, required this.resolved}); final String id; final String title; final FraudSeverity severity; final bool resolved; }
class Dispute { const Dispute({required this.id, required this.transactionId, required this.reason, required this.status}); final String id; final String transactionId; final String reason; final String status; }
class RewardSummary { const RewardSummary({required this.points, required this.availableValue}); final int points; final double availableValue; }
class DashboardSummary { const DashboardSummary({required this.customer, required this.cards, required this.transactions, required this.alerts, required this.rewards}); final Customer customer; final List<Card> cards; final List<CardTransaction> transactions; final List<FraudAlert> alerts; final RewardSummary rewards; }
