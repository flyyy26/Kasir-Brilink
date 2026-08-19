class AccountBalance {
  final int id;
  final String name;
  final String? category;
  final String? subCategory;
  final double balance;
  final bool isFromPusat;
  final int? outletId;

  AccountBalance({
    required this.id,
    required this.name,
    this.category,
    this.subCategory,
    required this.balance,
    this.isFromPusat = false,
    this.outletId,
  });

  factory AccountBalance.fromJson(Map<String, dynamic> json) {
    return AccountBalance(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      category: json['category'],
      subCategory: json['sub_category'],
      balance: (json['balance'] ?? 0).toDouble(),
      isFromPusat: json['is_from_pusat'] ?? false,
      outletId: json['outlet_id'],
    );
  }
}