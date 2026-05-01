class WalletTransaction {
  final String id;
  final double amount;
  final String type;
  final String description;
  final String? contactId;
  final String? contactName;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.contactId,
    this.contactName,
    required this.createdAt,
  });

  WalletTransaction copyWith({
    String? id,
    double? amount,
    String? type,
    String? description,
    String? contactId,
    String? contactName,
    DateTime? createdAt,
  }) => WalletTransaction(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    description: description ?? this.description,
    contactId: contactId ?? this.contactId,
    contactName: contactName ?? this.contactName,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'amount': amount,
    'type': type,
    'description': description,
    'contact_id': contactId,
    'contact_name': contactName,
    'created_at': createdAt.toIso8601String(),
  };

  factory WalletTransaction.fromDbMap(Map<String, dynamic> map) =>
      WalletTransaction(
        id: map['id'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        type: map['type'] as String? ?? 'spend',
        description: map['description'] as String? ?? '',
        contactId: map['contact_id'] as String?,
        contactName: map['contact_name'] as String?,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => toDbMap();

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction.fromDbMap(json);
}
