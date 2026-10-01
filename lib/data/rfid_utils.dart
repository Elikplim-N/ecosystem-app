/// RFID tag handling shared by every screen that accepts a card UID.
///
/// Readers emit the same tag in different shapes — `A3F921C0`, `a3f9:21c0`,
/// `A3F9 21C0`. Normalising once here means one physical card can never end
/// up in the registry twice because two people typed it differently.
library;

/// Strips separators, uppercases, keeps hex characters and groups in fours.
String normaliseRfidTag(String raw) {
  final hex = raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < hex.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(hex[i]);
  }
  return buffer.toString();
}

/// Number of hex characters in [raw], ignoring any separators.
int hexLength(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '').length;

/// Short description of a UID length, so staff can sanity-check a scan.
String describeRfidLength(int length) {
  if (length == 0) return 'Scan with the reader or type the UID';
  if (length == 8) return '4-byte UID — short range';
  if (length == 14) return '7-byte UID — standard for MIFARE Classic';
  if (length == 16) return '8-byte UID — long range';
  if (length == 20) return '10-byte UID — EM4100 / long range';
  return '$length characters — double-check the card';
}

/// Minimum characters before a UID is accepted.
const int kMinRfidHexLength = 8;
