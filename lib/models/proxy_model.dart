class ProxyInfo {
  ProxyInfo({
    required this.source,
    required this.country,
    required this.address,
    this.isSsl,
  });
  final String address;
  final String country;
  final bool? isSsl;
  final String source;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxyInfo &&
        other.address == address &&
        other.country == country;
  }

  @override
  int get hashCode => address.hashCode ^ country.hashCode;
}
