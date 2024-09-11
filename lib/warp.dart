import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flat_buffers/flat_buffers.dart';

import 'data_fb_generated.dart' as fb;
import 'warp_generated.dart';

final warpLib = init();

NativeLibrary init() {
  var lib = NativeLibrary(Warp.open());
  return lib;
}

class Warp {
  static DynamicLibrary open() {
    if (Platform.isAndroid) return DynamicLibrary.open('libzcash_warp.so');
    if (Platform.isIOS) return DynamicLibrary.executable();
    if (Platform.isWindows) return DynamicLibrary.open('zcash_warp.dll');
    if (Platform.isLinux) return DynamicLibrary.open('libzcash_warp.so');
    if (Platform.isMacOS) return DynamicLibrary.open('libzcash_warp.dylib');
    throw UnsupportedError('This platform is not supported.');
  }

  static void setup() {
    warpLib.c_setup();
  }

  static List<fb.AccountNameT> listAccounts(int coin) {
    final accountBytes = unwrapResultBytes(warpLib.c_list_accounts(coin));
    final bb = Uint8List.fromList(accountBytes);
    final bd = ByteData.sublistView(bb, 0);
    final reader = ListReader<fb.AccountName>(fb.AccountName.reader);
    final list = reader.read(BufferContext(bd), 0);
    return list.map((e) => e.unpack()).toList();
  }
}

Pointer<Char> toNative(String s) {
  return s.toNativeUtf8().cast<Char>();
}

Pointer<Uint8> toNativeBytes(Uint8List bytes) {
  final len = bytes.length;
  final ptr = malloc.allocate<Uint8>(bytes.length);
  final list = ptr.asTypedList(bytes.length);
  for (var i = 0; i < len; i++) {
    list[i] = bytes[i];
  }
  return ptr;
}

// bool unwrapResultBool(CResult_bool r) {
//   if (r.error != nullptr) throw convertCString(r.error);
//   return r.value != 0;
// }

int unwrapResultU8(CResult_u8 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

// int unwrapResultU32(CResult_u32 r) {
//   if (r.error != nullptr) throw convertCString(r.error);
//   return r.value;
// }

// int unwrapResultU64(CResult_u64 r) {
//   if (r.error != nullptr) throw convertCString(r.error);
//   return r.value;
// }

// String unwrapResultString(CResult_____c_char r) {
//   if (r.error != nullptr) throw convertCString(r.error);
//   return convertCString(r.value);
// }

List<int> unwrapResultBytes(CResult______u8 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return convertBytes(r.value, r.len);
}

String convertCString(Pointer<Char> s) {
  final str = s.cast<Utf8>().toDartString();
  // warp_api_lib.deallocate_str(s);
  return str;
}

List<int> convertBytes(Pointer<Uint8> s, int len) {
  final bytes = [...s.asTypedList(len)];
  // warp_api_lib.deallocate_bytes(s, len);
  return bytes;
}
