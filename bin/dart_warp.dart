import 'package:cbor/cbor.dart';
import 'package:dart_warp/data_fb_generated.dart';
import 'package:dart_warp/warp.dart';

void main(List<String> arguments) async {
  const zcash = 0;
  print("Started");
  Warp.setup();
  print("Initialized");

  // Warp.createTables(0);
  // Warp.createAccount(0, "Unstoppable", "<SEED PHRASE>",
  //   0, 419201);
  // Warp.resetChain(0, 0);

  print("List accounts");
  final accounts = Warp.listAccounts(zcash);
  for (var a in accounts) {
    print(a);
  }

  final balance = Warp.getBalance(zcash, 1, 0);
  print(balance);

  while (Warp.getBCHeight(zcash) > Warp.getSyncHeight(zcash)) {
    print("${Warp.getBCHeight(zcash)} ${Warp.getSyncHeight(zcash)}");
    await Warp.synchronize(zcash, Warp.getBCHeight(zcash));
  }
  print('Synchronization completed');

  // final payments = [PaymentRequestT(
  //   address: "zs1avauf3r6afmt052aw03wwk874uu3s5cxwdtmcqaawt5jxevr5sevw6avna6wvf233ezu59zgkfm",
  //   amount: 1000000,
  //   memoString: "Hello",
  //   memoBytes: [])];

  // final req = PaymentRequestsT(payments: payments);
  // var plan = Warp.pay(zcash, 1, req, 7, true, 1);
  // // plan.data = []; // discard the tx bytes
  // // print(plan);
  // final txBytes = Warp.sign(zcash, plan, Warp.getBCHeight(0) + 50);
  // print(txBytes.length);

  // final txid = Warp.broadcast(zcash, txBytes);
  // print(txid);

  final txd = Warp.fetchTxDetails(zcash, 1, 25);
  print(txd);
}
