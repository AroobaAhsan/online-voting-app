class Party {
  final String id;
  final String name;
  final String symbol; // optional text

  Party({required this.id, required this.name, required this.symbol});

  factory Party.fromMap(String id, Map<String, dynamic> d) {
    return Party(
      id: id,
      name: (d['name'] ?? '') as String,
      symbol: (d['symbol'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'symbol': symbol};
}
