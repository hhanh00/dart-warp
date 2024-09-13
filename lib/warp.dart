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
  var lib = NativeLibrary(open());
  return lib;
}

DynamicLibrary open() {
  if (Platform.isAndroid) return DynamicLibrary.open('libzcash_warp.so');
  if (Platform.isIOS) return DynamicLibrary.executable();
  if (Platform.isWindows) return DynamicLibrary.open('zcash_warp.dll');
  if (Platform.isLinux) return DynamicLibrary.open('libzcash_warp.so');
  if (Platform.isMacOS) return DynamicLibrary.open('libzcash_warp.dylib');
  throw UnsupportedError('This platform is not supported.');
}

var warp = Warp();

class Warp {
  void setup() {
    warpLib.c_setup();
  }

  void configure(int coin, String? db, String? url, String? warp) {
    final config = fb.AppConfigT(db: db, url: url, warp: warp);
    final param = toParam(config);
    unwrapResultU8(warpLib.c_configure(coin, param.ref));
  }

  Future<void> initProver(Uint8List spend, Uint8List output) async {
    Isolate.run(() {
      unwrapResultU8(warpLib.c_init_sapling_prover(
          0, toParamBytes(spend).ref, toParamBytes(output).ref));
    });
  }

  Future<void> createTables(int coin) async {
    Isolate.run(() => unwrapResultU8(warpLib.c_reset_tables(coin)));
  }

  Future<void> createAccount(
      int coin, String name, String key, int accIndex, int birth) async {
    Isolate.run(() => unwrapResultU32(
          warpLib.c_create_new_account(
              coin, toNative(name), toNative(key), accIndex, birth),
        ));
  }

  Future<List<fb.AccountNameT>> listAccounts(int coin) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_list_accounts(coin));
      final reader = ListReader<fb.AccountName>(fb.AccountName.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<fb.BalanceT> getBalance(int coin, int account, int height) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_get_balance(coin, account, height));
      return fb.Balance.reader.read(bc, 0).unpack();
    });
  }

  Future<void> resetChain(int coin, int height) async {
    Isolate.run(() => unwrapResultU8(warpLib.c_reset_chain(coin, height)));
  }

  Future<int> getSyncHeight(int coin) async {
    return Isolate.run(() => unwrapResultU32(warpLib.c_get_sync_height(coin)));
  }

  Future<int> getBCHeight(int coin) async {
    return Isolate.run(() => unwrapResultU32(warpLib.c_get_last_height(coin)));
  }

  Future<fb.TransactionSummaryT> pay(
      int coin,
      int account,
      fb.PaymentRequestsT recipients,
      int srcPools,
      bool feePaidBySender,
      int confirmations) async {
    return Isolate.run(() {
      final builder = Builder();
      final recipientOffset = recipients.pack(builder);
      builder.finish(recipientOffset);
      final recipientParam = calloc<CParam>();
      recipientParam.ref.value = toNativeBytes(builder.buffer);
      recipientParam.ref.len = builder.buffer.length;
      final summaryBytes = toBC(warpLib.c_prepare_payment(
          coin,
          account,
          recipientParam.ref,
          srcPools,
          feePaidBySender ? 1 : 0,
          confirmations));
      final summary = fb.TransactionSummary.reader.read(summaryBytes, 0);
      calloc.free(recipientParam);
      return summary.unpack();
    });
  }

  Future<Uint8List> sign(
      int coin, fb.TransactionSummaryT summary, int expirationHeight) async {
    return Isolate.run(() {
      final summaryParam = toParam(summary);
      final r = warpLib.c_sign(coin, summaryParam.ref, expirationHeight);
      calloc.free(summaryParam);
      return unwrapResultBytes(r);
    });
  }

  Future<String> broadcast(int coin, Uint8List txBytes) async {
    return Isolate.run(() {
      final txBytesParam = toParamBytes(txBytes);
      final r = warpLib.c_tx_broadcast(coin, txBytesParam.ref);
      calloc.free(txBytesParam);
      return unwrapResultString(r);
    });
  }

  Future<Uint8List> getAccountProperty(
      int coin, int account, String name) async {
    return Isolate.run(() => unwrapResultBytes(
        warpLib.c_get_account_property(coin, account, toNative(name))));
  }

  Future<void> setAccountProperty(
      int coin, int account, String name, Uint8List value) async {
    Isolate.run(() => unwrapResultU8(warpLib.c_set_account_property(
        coin, account, toNative(name), toParamBytes(value).ref)));
  }

  Future<void> editAccountName(int coin, int account, String name) async {
    Isolate.run(() => unwrapResultU8(
        warpLib.c_edit_account_name(coin, account, toNative(name))));
  }

  Future<void> editAccountBirthHeight(int coin, int account, int height) async {
    Isolate.run(() =>
        unwrapResultU8(warpLib.c_edit_account_birth(coin, account, height)));
  }

  Future<void> deleteAccount(int coin, int account) async {
    Isolate.run(() => unwrapResultU8(warpLib.c_delete_account(coin, account)));
  }

  Future<List<fb.ContactCardT>> listContacts(int coin) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_list_contact_cards(coin));
      final reader = ListReader<fb.ContactCard>(fb.ContactCard.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<fb.ContactCardT> getContact(int coin, int id) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_get_contact_card(coin, id));
      return fb.ContactCard.reader.read(bc, 0).unpack();
    });
  }

  Future<void> editContactName(int coin, int id, String name) async {
    Isolate.run(() =>
        unwrapResultU8(warpLib.c_edit_contact_name(coin, id, toNative(name))));
  }

  Future<void> editContactAddress(int coin, int id, String address) async {
    Isolate.run(() => unwrapResultU8(
        warpLib.c_edit_contact_address(coin, id, toNative(address))));
  }

  Future<void> deleteContact(int coin, int id) async {
    Isolate.run(() => unwrapResultU8(warpLib.c_delete_contact(coin, id)));
  }

  Future<fb.TransactionSummaryT> saveContacts(
      int coin, int account, int height, int confirmations) async {
    return Isolate.run(() {
      final bc =
          toBC(warpLib.c_save_contacts(coin, account, height, confirmations));
      return fb.TransactionSummary.reader.read(bc, 0).unpack();
    });
  }

  Future<int> getActivationDate(int coin) async {
    return Isolate.run(
        () => unwrapResultU32(warpLib.c_get_activation_date(coin)));
  }

  Future<int> getHeightByTime(int coin, int time) async {
    return Isolate.run(
        () => unwrapResultU32(warpLib.c_get_height_by_time(coin, time)));
  }

  Future<fb.ShieldedMessageT> prevMessage(
      int coin, int account, int height) async {
    return Isolate.run(
        () => unwrapMessage(warpLib.c_prev_message(coin, account, height)));
  }

  Future<fb.ShieldedMessageT> nextMessage(
      int coin, int account, int height) async {
    return Isolate.run(
        () => unwrapMessage(warpLib.c_next_message(coin, account, height)));
  }

  Future<fb.ShieldedMessageT> prevMessageThread(
      int coin, int account, int height, String subject) async {
    return Isolate.run(() => unwrapMessage(warpLib.c_prev_message_thread(
        coin, account, height, toNative(subject))));
  }

  Future<fb.ShieldedMessageT> nextMessageThread(
      int coin, int account, int height, String subject) async {
    return Isolate.run(() => unwrapMessage(warpLib.c_prev_message_thread(
        coin, account, height, toNative(subject))));
  }

  Future<List<fb.ShieldedMessageT>> listMessages(int coin, int account) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_list_messages(coin, account));
      final reader = ListReader<fb.ShieldedMessage>(fb.ShieldedMessage.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<void> markMessageRead(int coin, int id, bool reverse) async {
    Isolate.run(
        () => unwrapResultU8(warpLib.c_mark_read(coin, id, reverse ? 1 : 0)));
  }

  Future<void> markAllMessagesRead(int coin, int account, bool reverse) async {
    Isolate.run(() => unwrapResultU8(
        warpLib.c_mark_all_read(coin, account, reverse ? 1 : 0)));
  }

  Future<List<fb.ShieldedNoteT>> listNotes(
      int coin, int account, int height) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_get_unspent_notes(coin, account, height));
      final reader = ListReader<fb.ShieldedNote>(fb.ShieldedNote.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<void> excludeNote(int coin, int id, bool reverse) async {
    Isolate.run(() => warpLib.c_exclude_note(coin, id, reverse ? 1 : 0));
  }

  Future<void> reverseNoteExclusion(int coin, int account) async {
    Isolate.run(() => warpLib.c_reverse_note_exclusion(coin, account));
  }

  Future<void> encryptDb(int coin, String password, String dbPath) async {
    Isolate.run(() => unwrapResultU8(
        warpLib.c_encrypt_db(coin, toNative(password), toNative(dbPath))));
  }

  Future<void> setDbPassword(int coin, String password, String dbPath) async {
    Isolate.run(() =>
        unwrapResultU8(warpLib.c_set_db_password(coin, toNative(password))));
  }

  Future<void> encryptZIPDbFiles(String directory, String extension,
      String targetPath, String publicKey) async {
    Isolate.run(() => warpLib.c_encrypt_zip_database_files(
        0,
        toNative(directory),
        toNative(extension),
        toNative(targetPath),
        toNative(publicKey)));
  }

  Future<void> decryptZIPDbFiles(
      String filePath, String targetPath, String secretKey) async {
    Isolate.run(() => warpLib.c_decrypt_zip_database_files(
        0, toNative(filePath), toNative(targetPath), toNative(secretKey)));
  }

  Future<List<fb.PacketT>> splitData(
      int coin, Uint8List data, int threshold) async {
    return Isolate.run(() {
      final dataParam = calloc<CParam>();
      dataParam.ref.value = toNativeBytes(data);
      dataParam.ref.len = data.length;
      final bc = toBC(warpLib.c_split(coin, dataParam.ref, threshold));
      final reader = ListReader<fb.Packet>(fb.Packet.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<fb.PacketT> mergeData(int coin, List<fb.PacketT> packets) async {
    return Isolate.run(() {
      final p = fb.PacketsT(packets: packets);
      final packetsParam = toParam(p);
      final bc = toBC(warpLib.c_merge(coin, packetsParam.ref));
      return fb.Packet.reader.read(bc, 0).unpack();
    });
  }

  Future<String> generateSeed() async {
    return Isolate.run(() => unwrapResultString(
        warpLib.c_generate_random_mnemonic_phrase_os_rng(0)));
  }

  Future<fb.BackupT> getBackup(int coin, int account) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_create_backup(coin, account));
      return fb.Backup.reader.read(bc, 0).unpack();
    });
  }

  Future<String> getAccountAddress(int coin, int account, int mask) async {
    return Isolate.run(
        () => unwrapResultString(warpLib.c_get_address(coin, account, mask)));
  }

  Future<String> getAccountDiversifiedAddress(
      int coin, int account, int mask) async {
    return Isolate.run(() => unwrapResultString(
        warpLib.c_get_account_diversified_address(coin, account, mask)));
  }

  Future<fb.TransactionSummaryT> sweep(int coin, int account, int confirmations,
      String destination, int gap) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_prepare_sweep_tx(
          coin, account, confirmations, toNative(destination), gap));
      return fb.TransactionSummary.reader.read(bc, 0).unpack();
    });
  }

  Future<fb.TransactionSummaryT> sweepSK(int coin, int account,
      String secretKey, int confirmations, String destination) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_prepare_sweep_tx_by_sk(coin, account,
          toNative(secretKey), confirmations, toNative(destination)));
      return fb.TransactionSummary.reader.read(bc, 0).unpack();
    });
  }

  Future<fb.TransactionInfoExtendedT> fetchTxDetails(
      int coin, int account, int id) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_fetch_tx_details(coin, account, id));
      return fb.TransactionInfoExtended.reader.read(bc, 0).unpack();
    });
  }

  Future<fb.UareceiversT> decodeAddress(int coin, String address) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_decode_address(coin, toNative(address)));
      return fb.Uareceivers.reader.read(bc, 0).unpack();
    });
  }

  Future<List<fb.TransactionInfoT>> listTransactions(
      int coin, int account, int height) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_get_txs(coin, account, height));
      final reader = ListReader<fb.TransactionInfo>(fb.TransactionInfo.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<String> makePaymentURI(
      int coin, List<fb.PaymentRequestT> recipients) async {
    return Isolate.run(() {
      final payments = toParam(fb.PaymentRequestsT(payments: recipients));
      return unwrapResultString(warpLib.c_make_payment_uri(coin, payments.ref));
    });
  }

  Future<fb.PaymentRequestsT> parsePaymentURI(int coin, String uri) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_parse_payment_uri(coin, toNative(uri)));
      return fb.PaymentRequests.reader.read(bc, 0).unpack();
    });
  }

  Future<void> retrieveTransactionDetails(int coin) async {
    Isolate.run(() => warpLib.c_retrieve_tx_details(coin));
  }
}

class WarpSync {
  static Future<void> synchronize(int coin, int endHeight) async {
    await Isolate.run(() => warpLib.warp_synchronize(coin, endHeight));
  }
}

fb.ShieldedMessageT unwrapMessage(CResult______u8 m) {
  final bc = toBC(m);
  return fb.ShieldedMessage.reader.read(bc, 0).unpack();
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
