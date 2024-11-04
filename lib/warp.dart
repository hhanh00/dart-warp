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

enum AddressType {
  invalidAddress,
  address,
  paymentURI,
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

  void configure(int coin,
      {List<String>? servers, String? warp, int? warpEndHeight}) {
    final config = fb.ConfigT(
        servers: servers, warpUrl: warp, warpEndHeight: warpEndHeight ?? 0);
    final param = toParam(config);
    unwrapResultU8(warpLib.c_configure(coin, param.ref));
  }

  Future<void> initProver(Uint8List spend, Uint8List output) async {
    return Isolate.run(() {
      unwrapResultU8(warpLib.c_init_sapling_prover(
          toParamBytes(spend).ref, toParamBytes(output).ref));
    });
  }

  Future<int> pingServer(String url) async {
    return Isolate.run(() => unwrapResultU64(warpLib.c_ping(0, toNative(url))));
  }

  bool isValidKey(int coin, String key) {
    return unwrapResultBool(warpLib.c_is_valid_key(coin, toNative(key)));
  }

  int createAccount(
      int coin, String name, String key, int accIndex, int birth, bool transparentOnly,
      isNew) {
    return unwrapResultU32(
      warpLib.c_create_new_account(
          coin, toNative(name), toNative(key), accIndex, birth,
          transparentOnly ? 1 : 0, isNew ? 1 : 0),
    );
  }

  List<fb.AccountNameT> listAccounts(int coin) {
    final bc = toBC(warpLib.c_list_accounts(coin));
    return fb.AccountNameList.reader.read(bc, 0).unpack().items!;
  }

  fb.BalanceT getBalance(int coin, int account, int height) {
    final bc = toBC(warpLib.c_get_balance(coin, account, height));
    return fb.Balance.reader.read(bc, 0).unpack();
  }

  Future<void> resetChain(int coin, int height) async {
    return Isolate.run(
        () => unwrapResultU8(warpLib.c_reset_chain(coin, height)));
  }

  int getSyncHeight(int coin) {
    return unwrapResultU32(warpLib.c_get_sync_height(coin));
  }

  Future<int> getBCHeight(int coin) async {
    return Isolate.run(() => unwrapResultU32(warpLib.c_get_last_height(coin)));
  }

  Future<int?> getBCHeightOrNull(int coin) async {
    return Isolate.run(
        () => unwrapResultU32OrNull(warpLib.c_get_last_height(coin)));
  }

  Future<fb.TransactionSummaryT> pay(
    int coin,
    int account,
    fb.PaymentRequestT payment,
  ) async {
    return Isolate.run(() {
      final summaryBytes = toBC(warpLib.c_prepare_payment(
          coin, account, toParam(payment).ref, toNative("")));
      final summary = fb.TransactionSummary.reader.read(summaryBytes, 0);
      return summary.unpack();
    });
  }

  Future<fb.TransactionBytesT> sign(
      int coin, fb.TransactionSummaryT summary, int expirationHeight) async {
    return Isolate.run(() {
      final summaryParam = toParam(summary);
      final bc = toBC(warpLib.c_sign(coin, summaryParam.ref, expirationHeight));
      return fb.TransactionBytes.reader.read(bc, 0).unpack();
    });
  }

  Future<String> broadcast(int coin, fb.TransactionBytesT txBytes) async {
    return Isolate.run(() {
      final txBytesParam = toParam(txBytes);
      final r = warpLib.c_tx_broadcast(coin, txBytesParam.ref);
      return unwrapResultString(r);
    });
  }

  Uint8List getAccountProperty(int coin, int account, String name) {
    return unwrapResultBytes(
        warpLib.c_get_account_property(coin, account, toNative(name)));
  }

  void setAccountProperty(
      int coin, int account, String name, Uint8List value) {
    unwrapResultU8(warpLib.c_set_account_property(
        coin, account, toNative(name), toParamBytes(value).ref));
  }

  void editAccountName(int coin, int account, String name) {
    unwrapResultU8(warpLib.c_edit_account_name(coin, account, toNative(name)));
  }

  void editAccountBirthHeight(int coin, int account, int height) {
    unwrapResultU8(warpLib.c_edit_account_birth(coin, account, height));
  }

  void editAccountHidden(int coin, int account, bool hidden) {
    unwrapResultU8(warpLib.c_hide_account(coin, account, hidden ? 1 : 0));
  }

  void reorderAccount(int coin, int account, int newPosition) {
    unwrapResultU8(warpLib.c_reorder_account(coin, account, newPosition));
  }

  void deleteAccount(int coin, int account) {
    unwrapResultU8(warpLib.c_delete_account(coin, account));
  }

  int newTransparentAddress(int coin, int account, int external) {
    return unwrapResultU32(warpLib.c_new_transparent_address(coin, account));
  }

  List<fb.TransparentAddressT> listTransparentAddresses(int coin, int account) {
    final bc =
        toBC(warpLib.c_list_account_transparent_addresses(coin, account));
    final reader =
        ListReader<fb.TransparentAddress>(fb.TransparentAddress.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  void changeAccountAddrIndex(int coin, int account, int addrIndex) {
    unwrapResultU8(warpLib.c_change_account_dindex(
        coin, account, addrIndex));
  }

  Future<List<fb.ContactCardT>> listContacts(int coin) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_list_contact_cards(coin));
      final reader = ListReader<fb.ContactCard>(fb.ContactCard.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<int> addContact(int coin, fb.ContactCardT contact) async {
    return Isolate.run(() {
      final c = toParam(contact);
      return unwrapResultU32(warpLib.c_store_contact(coin, c.ref));
    });
  }

  fb.ContactCardT getContact(int coin, int id) {
    final bc = toBC(warpLib.c_get_contact_card(coin, id));
    return fb.ContactCard.reader.read(bc, 0).unpack();
  }

  Future<void> editContactName(int coin, int id, String name) async {
    return Isolate.run(() =>
        unwrapResultU8(warpLib.c_edit_contact_name(coin, id, toNative(name))));
  }

  Future<void> editContactAddress(int coin, int id, String address) async {
    return Isolate.run(() => unwrapResultU8(
        warpLib.c_edit_contact_address(coin, id, toNative(address))));
  }

  Future<void> deleteContact(int coin, int id) async {
    return Isolate.run(
        () => unwrapResultU8(warpLib.c_delete_contact(coin, id)));
  }

  Future<fb.TransactionSummaryT> saveContacts(
      int coin, int account, int height, String redirect) async {
    return Isolate.run(() {
      final bc = toBC(
          warpLib.c_save_contacts(coin, account, height, toNative(redirect)));
      return fb.TransactionSummary.reader.read(bc, 0).unpack();
    });
  }

  void onContactsSaved(int coin, int account) {
    warpLib.c_on_contacts_saved(coin, account);
  }

  int getActivationDate(int coin) {
    return unwrapResultU32(warpLib.c_get_activation_date(coin));
  }

  int getActivationHeight(int coin) {
    return unwrapResultU32(warpLib.c_get_activation_height(coin));
  }

  Future<int> getHeightByTime(int coin, int time) async {
    return Isolate.run(
        () => unwrapResultU32(warpLib.c_get_height_by_time(coin, time)));
  }

  Future<int> getTimeByHeight(int coin, int height) async {
    return Isolate.run(
        () => unwrapResultU32(warpLib.c_get_time_by_height(coin, height)));
  }

  Future<List<fb.CheckpointT>> listCheckpoints(int coin) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_list_checkpoints(coin));
      final reader = ListReader<fb.Checkpoint>(fb.Checkpoint.reader);
      final list = reader.read(bc, 0);
      return list.map((e) => e.unpack()).toList();
    });
  }

  Future<void> rewindTo(int coin, int height) async {
    return Isolate.run(() => unwrapResultU8(warpLib.c_rewind(coin, height)));
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
    return Isolate.run(
        () => unwrapResultU8(warpLib.c_mark_read(coin, id, reverse ? 1 : 0)));
  }

  Future<void> markAllMessagesRead(int coin, int account, bool reverse) async {
    return Isolate.run(() => unwrapResultU8(
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

  List<fb.InputTransparentT> listUtxos(int coin, int account, int height) {
    final bc = toBC(warpLib.c_get_unspent_utxos(coin, account, height));
    final reader = ListReader<fb.InputTransparent>(fb.InputTransparent.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  Future<void> excludeNote(int coin, int id, bool reverse) async {
    return Isolate.run(() => warpLib.c_exclude_note(coin, id, reverse ? 0 : 1));
  }

  Future<void> reverseNoteExclusion(int coin, int account) async {
    return Isolate.run(() => warpLib.c_reverse_note_exclusion(coin, account));
  }

  int getSchemaVersion() {
    return warpLib.c_schema_version();
  }

  Future<void> createDb(int coin, String path, String password, String version) {
    return Isolate.run(() => unwrapResultU8(
        warpLib.c_create_db(toNative(path), toNative(password), toNative(version))));
  }

  bool checkDbPassword(String path, String password) {
    return unwrapResultU8(
            warpLib.c_check_db_password(toNative(path), toNative(password))) !=
        0;
  }

  Future<void> encryptDb(int coin, String password, String dbPath) async {
    return Isolate.run(() => unwrapResultU8(
        warpLib.c_encrypt_db(coin, toNative(password), toNative(dbPath))));
  }

  void setDbPathPassword(int coin, String path, String password) {
    unwrapResultU8(warpLib.c_set_db_path_password(
        coin, toNative(path), toNative(password)));
  }

  Future<fb.AgekeysT> generateZIPDbKeys() async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_generate_zip_database_keys());
      return fb.Agekeys.reader.read(bc, 0).unpack();
    });
  }

  Future<void> encryptZIPDbFiles(String directory, List<String> fileList,
      String targetPath, String publicKey) async {
    return Isolate.run(() {
      final config = fb.ZipDbConfigT(
          directory: directory,
          fileList: fileList,
          targetPath: targetPath,
          publicKey: publicKey);
      warpLib.c_encrypt_zip_database_files(toParam(config).ref);
    });
  }

  Future<void> decryptZIPDbFiles(
      String filePath, String targetPath, String secretKey) async {
    return Isolate.run(() => unwrapResultU8(
        warpLib.c_decrypt_zip_database_files(
            toNative(filePath), toNative(targetPath), toNative(secretKey))));
  }

  List<fb.PacketT> splitData(Uint8List data, int threshold) {
    final bc = toBC(warpLib.c_split(toParamBytes(data).ref, threshold));
    final list = ListReader<fb.Packet>(fb.Packet.reader).read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  Future<Uint8List> mergeData(List<fb.PacketT> packets) async {
    return Isolate.run(() {
      final p = fb.PacketsT(packets: packets);
      final packetsParam = toParam(p);
      return unwrapResultBytes(warpLib.c_merge(packetsParam.ref));
    });
  }

  Future<String> generateSeed() async {
    return Isolate.run(() => unwrapResultString(
        warpLib.c_generate_random_mnemonic_phrase_os_rng()));
  }

  fb.BackupT getBackup(int coin, int account) {
    final bc = toBC(warpLib.c_create_backup(coin, account));
    return fb.Backup.reader.read(bc, 0).unpack();
  }

  void setBackupReminder(int coin, int account, bool saved) {
    unwrapResultU8(warpLib.c_set_backup_reminder(coin, account, saved ? 1 : 0));
  }

  String getAccountAddress(int coin, int account, int time, int mask) {
    // if no receiver available, return empty string
    return unwrapOrDefaultString(
        warpLib.c_get_address(coin, account, time, mask));
  }

  fb.AccountSigningCapabilitiesT getAccountCapabilities(int coin, int account) {
    final bc = toBC(warpLib.c_get_account_signing_capabilities(coin, account));
    return fb.AccountSigningCapabilities.reader.read(bc, 0).unpack();
  }

  Future<void> downgradeAccount(int coin, int account,
      fb.AccountSigningCapabilitiesT capabilities) async {
    return Isolate.run(() => unwrapResultU8(
        warpLib.c_downgrade_account(coin, account, toParam(capabilities).ref)));
  }

  bool canSign(int coin, int account, fb.TransactionSummaryT summary) {
    return unwrapResultBool(
        warpLib.c_can_sign(coin, account, toParam(summary).ref));
  }

  Future<void> scanTransparentAddresses(
      int coin, int account, int external, int gapLimit) async {
    return Isolate.run(() {
      unwrapResultU8(
          warpLib.c_scan_transparent_addresses(coin, account, external, gapLimit));
    });
  }

  Future<void> transparentSync(int coin, int account, int height) async {
    return Isolate.run(() {
      unwrapResultU8(warpLib.c_transparent_scan(coin, account, height));
    });
  }

  void mempoolRun(int coin) {
    unwrapResultU8(warpLib.c_mempool_run(coin));
  }

  void mempoolSetAccount(int coin, int account) {
    unwrapResultU8(warpLib.c_mempool_set_account(coin, account));
  }

  List<fb.UnconfirmedTxT> listUnconfirmedTxs(int coin, int account) {
    final bc = toBC(warpLib.c_list_unconfirmed_txs(coin, account));
    final reader = ListReader<fb.UnconfirmedTx>(fb.UnconfirmedTx.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  int getUnconfirmedBalance(int coin, int account) {
    return unwrapResultI64(warpLib.c_get_unconfirmed_balance(coin, account));
  }

  fb.SpendableT getSpendableBalance(int coin, int account, int height) {
    final bc = toBC(warpLib.c_get_spendable(coin, account, height));
    return fb.Spendable.reader.read(bc, 0).unpack();
  }

  Future<fb.TransactionInfoExtendedT> fetchTxDetails(
      int coin, int account, int id) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_fetch_tx_details(coin, account, id));
      return fb.TransactionInfoExtended.reader.read(bc, 0).unpack();
    });
  }

  fb.UareceiversT decodeAddress(int coin, String address) {
    final bc = toBC(warpLib.c_decode_address(coin, toNative(address)));
    return fb.Uareceivers.reader.read(bc, 0).unpack();
  }

  List<fb.TransactionInfoT> listTransactions(
      int coin, int account, int height) {
    final bc = toBC(warpLib.c_get_txs(coin, account, height));
    final reader = ListReader<fb.TransactionInfo>(fb.TransactionInfo.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  fb.TransactionInfoExtendedT getTransactionDetails(int coin, Uint8List txid) {
    final bc = toBC(warpLib.c_get_tx_details(coin, toParamBytes(txid).ref));
    return fb.TransactionInfoExtended.reader.read(bc, 0).unpack();
  }

  AddressType isValidAddressOrUri(int coin, String s) {
    final a =
        unwrapResultU8(warpLib.c_is_valid_address_or_uri(coin, toNative(s)));
    return AddressType.values[a];
  }

  String makePaymentURI(int coin, fb.PaymentRequestT payment) {
    return unwrapResultString(
        warpLib.c_make_payment_uri(coin, toParam(payment).ref));
  }

  fb.PaymentRequestT parsePaymentURI(
      int coin, String uri, int height, int expiration) {
    final bc = toBC(
        warpLib.c_parse_payment_uri(coin, toNative(uri), height, expiration));
    return fb.PaymentRequest.reader.read(bc, 0).unpack();
  }

  Future<void> retrieveTransactionDetails(int coin) async {
    return Isolate.run(() => warpLib.c_retrieve_tx_details(coin));
  }

  List<fb.SpendingT> getSpendings(
      int coin, int account, int timestamp) {
    final bc = toBC(warpLib.c_get_spendings(coin, account, timestamp));
    final reader = ListReader<fb.Spending>(fb.Spending.reader);
    final list = reader.read(bc, 0);
    return list.map((e) => e.unpack()).toList();
  }

  Future<fb.Zip32KeysT> deriveZip32Keys(int coin, int account, int aindex,
      int addrIndex, bool defaultAddress) async {
    return Isolate.run(() {
      final bc = toBC(warpLib.c_derive_zip32_keys(
          coin, account, aindex, addrIndex, defaultAddress ? 1 : 0));
      return fb.Zip32Keys.reader.read(bc, 0).unpack();
    });
  }

  void storeSwap(int coin, int account, fb.SwapT swap) {
    warpLib.c_store_swap(coin, account, toParam(swap).ref);
  }

  List<fb.SwapT> listSwaps(int coin, int account) {
    final bc = toBC(warpLib.c_list_swaps(coin, account));
    return fb.SwapList.reader.read(bc, 0).unpack().items!;
  }

  void clearSwapHistory(int coin, int account) {
    warpLib.c_clear_swap_history(coin, account);
  }
}

class WarpSync {
  static Future<void> synchronize(int coin, int endHeight) async {
    await Isolate.run(() => warpLib.c_warp_synchronize(coin, endHeight));
  }

  static Future<void> downloadWarpFile(
      int coin, String url, int endHeight, String filename) async {
    return await Isolate.run(() => warpLib.c_download_warp_blocks(
        coin, toNative(url), endHeight, toNative(filename)));
  }

  static Future<void> syncFromFile(int coin, String filename) async {
    return await Isolate.run(
        () => warpLib.c_warp_synchronize_from_file(coin, toNative(filename)));
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

bool unwrapResultBool(CResult_bool r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value != 0;
}

int unwrapResultU8(CResult_u8 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

int unwrapResultU32(CResult_u32 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

int? unwrapResultU32OrNull(CResult_u32 r) {
  if (r.error != nullptr) return null;
  return r.value;
}

int unwrapResultU64(CResult_u64 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

int unwrapResultI64(CResult_i64 r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return r.value;
}

String unwrapResultString(CResult_____c_char r) {
  if (r.error != nullptr) throw convertCString(r.error);
  return convertCString(r.value);
}

String unwrapOrDefaultString(CResult_____c_char r) {
  if (r.error != nullptr) return '';
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
  final b = s.asTypedList(len);
  Uint8List copy = Uint8List(b.length);
  copy.setRange(0, b.length, b);
  // warp_api_lib.deallocate_bytes(s, len);
  return copy;
}
