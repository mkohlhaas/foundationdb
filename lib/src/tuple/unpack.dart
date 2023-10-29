import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../foundationdb.dart';

extension UnpackUint8List on Uint8List {
  Tuple unpack([bool isNested = false]) {
    int len = 0;
    Tuple result = [];
    dynamic res;
    Uint8List cpLst = Uint8List.sublistView(this);
    while (cpLst.isNotEmpty) {
      int opcode = cpLst[0];
      cpLst = Uint8List.sublistView(cpLst, 1);
      (res, len) = switch (opcode) {
        0x00 => cpLst.unpackNull(isNested),
        0x01 => cpLst.unpackUint8List(),
        0x02 => cpLst.unpackString(),
        0x05 => cpLst.unpackNestedTuple(true),
        0x0c => cpLst.unpackInteger(),
        0x1c => cpLst.unpackInteger(),
        0x14 => cpLst.unpackZeroInteger(),
        0x21 => cpLst.unpackDouble(),
        0x26 => cpLst.unpackFalse(),
        0x27 => cpLst.unpackTrue(),
        0x30 => cpLst.unpackUuidValue(),
        _ => throw ArgumentError('Found unknown opcode: $opcode'),
      };
      result.add(res);
      cpLst = Uint8List.sublistView(cpLst, len);
      print('${cpLst.length}: $len');
    }
    if (cpLst.isNotEmpty) {
      throw ArgumentError('There are still things to unpack in the buffer.');
    }
    return result;
  }

  (dynamic, int) unpackByteList(Function(List<int>) f, [bool isNested = false]) {
    final result = <int>[];
    int idx = 0;
    while (true) {
      if (this[idx] == 0x00 && length - idx - 1 > 0 && this[idx + 1] == 0xff) {
        result.add(this[idx]); // add 0x00
        idx++; // skip 0x00
        idx++; // skip 0xff
      } else if (this[idx] == 0x00) {
        return (f(result), idx + 1); // we reached the end
      } else {
        result.add(this[idx]);
        idx++; // skip current item
      }
    }
  }

  // if (this < 0) {
  //   for (var i = 0; i < r.length; i++) {
  //     r[i] = ~r[i];
  //   }
  // } else {
  //   r[0] ^= 0x80;
  // }

  (double, int) unpackDouble() {
    ByteData bdata = buffer.asByteData(offsetInBytes, 8);
    if (this[0] & 0x80 == 0) {
      for (var i = 0; i < length; i++) {
        this[i] = ~this[i];
      }
    } else {
      this[0] ^= 0x80;
    }
    return (bdata.getFloat64(0), 8);
  }

  (bool, int) unpackFalse() {
    return (false, 0);
  }

  (int, int) unpackIntegerNegative() {
    ByteData bdata = buffer.asByteData(offsetInBytes, 8);
    for (var i = 0; i < length; i++) {
      this[i] = ~this[i];
    }
    return (bdata.getInt64(0), 8);
  }

  (int, int) unpackInteger() {
    ByteData bdata = buffer.asByteData(offsetInBytes, 8);
    return (bdata.getInt64(0), 8);
  }

  (Tuple, int) unpackNestedTuple([bool isNested = false]) {
    return ([], 0);
  }

  (void, int) unpackNull([bool isNested = false]) {
    if (isNested) {
      if (this[0] != 0xff) {
        throw ArgumentError('Unpacking a nested Null must be terminated by 0xff.');
      }
      return (null, 1);
    } else {
      return (null, 0);
    }
  }

  (String, int) unpackString() {
    dynamic res;
    int length;
    (res, length) = unpackByteList(utf8.decode);
    return (res as String, length);
  }

  (bool, int) unpackTrue() {
    return (true, 0);
  }

  (Uint8List, int) unpackUint8List() {
    dynamic res;
    int length;
    (res, length) = unpackByteList(Uint8List.fromList);
    return (res as Uint8List, length);
  }

  (UuidValue, int) unpackUuidValue() {
    return (UuidValue.fromByteList(buffer.asUint8List(offsetInBytes, 16)), 16);
  }

  (int, int) unpackZeroInteger() {
    return (0, 0);
  }
}
