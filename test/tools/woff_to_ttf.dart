// Minimal WOFF -> SFNT (TTF/OTF) converter used by the page-render spike.
//
// flutter_test's font path doesn't shape PUA codepoints from WOFF reliably,
// but it shapes them fine from a proper TTF/OTF. This converter parses the
// WOFF header + table directory, zlib-decompresses each table, and rebuilds
// an SFNT-format buffer with 4-byte padded tables and a fresh header.
//
// Spec: https://www.w3.org/TR/WOFF/

import 'dart:io';
import 'dart:typed_data';

const int _kWoffSignature = 0x774F4646; // 'wOFF'

Uint8List woffToSfnt(Uint8List woff) {
  final bd = ByteData.view(woff.buffer, woff.offsetInBytes, woff.length);
  if (bd.getUint32(0) != _kWoffSignature) {
    throw FormatException('Not a WOFF file');
  }
  final flavor = bd.getUint32(4);
  final numTables = bd.getUint16(12);

  final entries = <_WoffEntry>[];
  for (var i = 0; i < numTables; i++) {
    final o = 44 + i * 20;
    entries.add(_WoffEntry(
      tag: bd.getUint32(o),
      offset: bd.getUint32(o + 4),
      compLength: bd.getUint32(o + 8),
      origLength: bd.getUint32(o + 12),
      origChecksum: bd.getUint32(o + 16),
    ));
  }

  final tables = <Uint8List>[];
  for (final e in entries) {
    final raw = Uint8List.sublistView(woff, e.offset, e.offset + e.compLength);
    if (e.compLength == e.origLength) {
      tables.add(raw);
    } else {
      tables.add(Uint8List.fromList(ZLibCodec().decode(raw)));
    }
  }

  var pow2 = 1;
  var entrySelector = 0;
  while (pow2 * 2 <= numTables) {
    pow2 *= 2;
    entrySelector++;
  }
  final searchRange = pow2 * 16;
  final rangeShift = numTables * 16 - searchRange;

  final headerSize = 12 + numTables * 16;
  var cursor = headerSize;
  final tableOffsets = <int>[];
  for (var i = 0; i < numTables; i++) {
    tableOffsets.add(cursor);
    cursor += (tables[i].length + 3) & ~3;
  }
  final total = cursor;
  final out = Uint8List(total);
  final outBd = ByteData.view(out.buffer);

  outBd.setUint32(0, flavor);
  outBd.setUint16(4, numTables);
  outBd.setUint16(6, searchRange);
  outBd.setUint16(8, entrySelector);
  outBd.setUint16(10, rangeShift);

  for (var i = 0; i < numTables; i++) {
    final o = 12 + i * 16;
    outBd.setUint32(o, entries[i].tag);
    outBd.setUint32(o + 4, entries[i].origChecksum);
    outBd.setUint32(o + 8, tableOffsets[i]);
    outBd.setUint32(o + 12, entries[i].origLength);
  }

  for (var i = 0; i < numTables; i++) {
    out.setRange(tableOffsets[i], tableOffsets[i] + tables[i].length, tables[i]);
  }

  return out;
}

class _WoffEntry {
  _WoffEntry({
    required this.tag,
    required this.offset,
    required this.compLength,
    required this.origLength,
    required this.origChecksum,
  });
  final int tag;
  final int offset;
  final int compLength;
  final int origLength;
  final int origChecksum;
}
