/**
 * RFID tag normalisation.
 *
 * The database stores tag_normalised as UNIQUE, so this function is what
 * stops one physical card becoming three records. Scanners emit the same card
 * as 'a3f9:21c0', 'A3F9 21C0' and 'A3F9-21C0'; all three must produce one value.
 *
 * This is a deliberate port of lib/data/rfid_utils.dart. If you change one,
 * change the other, or tags already in the database will stop matching.
 */

const SEPARATORS = /[\s:._-]/g;
const VALID_HEX = /^[0-9A-F]+$/;

/** Common tag sizes in hex characters, and the byte count for display. */
const LENGTH_HINTS = {
  8: { bytes: 4, label: 'EM4100 / HID 40-bit' },
  10: { bytes: 5, label: '40-bit + parity' },
  14: { bytes: 7, label: 'HID 56-bit' },
  16: { bytes: 8, label: 'MIFARE Classic 1K' },
  20: { bytes: 10, label: 'MIFARE DESFire / UID 80-bit' },
};

/**
 * @param {string} raw
 * @returns {{ ok: true, normalised: string, hex: string, length: number, bytes: number, label: string }
 *          | { ok: false, reason: string }}
 */
export function normaliseTag(raw) {
  if (typeof raw !== 'string' || raw.trim() === '') {
    return { ok: false, reason: 'Tag is empty.' };
  }

  const hex = raw.replace(SEPARATORS, '').toUpperCase();

  if (!VALID_HEX.test(hex)) {
    return {
      ok: false,
      reason: 'Tag must contain hex digits 0-9 and A-F only (separators are ignored).',
    };
  }

  if (hex.length < 8 || hex.length > 20) {
    return { ok: false, reason: `Tag must be 8-20 hex characters; this one is ${hex.length}.` };
  }

  return {
    ok: true,
    hex,
    length: hex.length,
    bytes: hex.length / 2,
    normalised: hex.match(/.{1,4}/g).join(' '),
    label: LENGTH_HINTS[hex.length]?.label ?? `${hex.length}-bit`,
  };
}

/** Accepts 'a3f9:21c0', 'A3F921C0' or 'A3F9 21C0' as the same card. */
export function tagsMatch(a, b) {
  const na = normaliseTag(a);
  const nb = normaliseTag(b);
  return na.ok && nb.ok && na.hex === nb.hex;
}

export default { normaliseTag, tagsMatch };
