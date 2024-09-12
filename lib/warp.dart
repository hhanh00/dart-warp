import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flat_buffers/flat_buffers.dart';

import 'data_fb_generated.dart' as fb;
import 'warp_generated.dart' hide bool;

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

  static void createTables(int coin) {
    unwrapResultU8(warpLib.c_reset_tables(coin));
  }

  static void createAccount(
      int coin, String name, String key, int accIndex, int birth) {
    unwrapResultU32(
      warpLib.c_create_new_account(
          coin, toNative(name), toNative(key), accIndex, birth),
    );
  }

  static List<fb.AccountNameT> listAccounts(int coin) {
    final bc = toBC(warpLib.c_list_accounts(coin));
    final reader = ListReader<fb.AccountName>(fb.AccountName.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  static fb.BalanceT getBalance(int coin, int account, int height) {
    final bc = toBC(warpLib.c_get_balance(coin, account, height));
    return fb.Balance.reader.read(bc, 0).unpack();
  }

  static void resetChain(int coin, int height) {
    unwrapResultU8(warpLib.c_reset_chain(coin, height));
  }

  static int getSyncHeight(int coin) {
    return unwrapResultU32(warpLib.c_get_sync_height(coin));
  }

  static int getBCHeight(int coin) {
    return unwrapResultU32(warpLib.c_get_last_height(coin));
  }

  static Future<void> synchronize(int coin, int endHeight) async {
    await Isolate.run(() => warpLib.warp_synchronize(coin, endHeight));
  }

  static fb.TransactionSummaryT pay(int coin, int account, fb.PaymentRequestsT recipients, int srcPools, bool feePaidBySender, int confirmations) {
    final builder = Builder();
    final recipientOffset = recipients.pack(builder);
    builder.finish(recipientOffset);
    final recipientParam = calloc<CParam>();
    recipientParam.ref.value = toNativeBytes(builder.buffer);
    recipientParam.ref.len = builder.buffer.length;
    final summaryBytes = toBC(warpLib.c_pay(coin, account, recipientParam.ref, srcPools, feePaidBySender ? 1 : 0, confirmations));
    final summary = fb.TransactionSummary.reader.read(summaryBytes, 0);
    calloc.free(recipientParam);
    return summary.unpack();
  }

  static Uint8List sign(int coin, fb.TransactionSummaryT summary, int expirationHeight) {
    final summaryParam = toParam(summary);
    final r = warpLib.c_sign(coin, summaryParam.ref, expirationHeight);
    calloc.free(summaryParam);
    return unwrapResultBytes(r);
  }

  static String broadcast(int coin, Uint8List txBytes) {
    final txBytesParam = toParamBytes(txBytes);
    final r = warpLib.c_tx_broadcast(coin, txBytesParam.ref);
    calloc.free(txBytesParam);
    return unwrapResultString(r);
  }
}

BufferContext toBC(CResult______u8 r) {
  final bytes = unwrapResultBytes(r);
  final bb = Uint8List.fromList(bytes);
  final bd = ByteData.sublistView(bb, 0);
  return BufferContext(bd);
}

Pointer<CParam> toParam<T extends Packable>(T value) {
    final builder = Builder();
    final paramOffset = value.pack(builder);
    builder.finish(paramOffset);
    final param = calloc<CParam>();
    param.ref.value = toNativeBytes(builder.buffer);
    param.ref.len = builder.buffer.length;
    return param;
}

Pointer<CParam> toParamBytes(Uint8List value) {
    final param = calloc<CParam>();
    param.ref.value = toNativeBytes(value);
    param.ref.len = value.length;
    return param;
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

int unwrapResultU32(CResult_u32 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

// int unwrapResultU64(CResult_u64 r) {
//   if (r.error != nullptr) throw convertCString(r.error);
//   return r.value;
// }

String unwrapResultString(CResult_____c_char r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return convertCString(r.value);
}

Uint8List unwrapResultBytes(CResult______u8 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return convertBytes(r.value, r.len);
}

String convertCString(Pointer<Char> s) {
  final str = s.cast<Utf8>().toDartString();
  // warp_api_lib.deallocate_str(s);
  return str;
}

Uint8List convertBytes(Pointer<Uint8> s, int len) {
  // warp_api_lib.deallocate_bytes(s, len);
  return s.asTypedList(len);
}
