import 'package:warp/data_fb_generated.dart';
import 'package:warp/warp.dart';

void main(List<String> arguments) async {
  const zcash = 0;
  print("Started");
  warp.setup();
  print("Initialized");

  // Warp.createTables(0);
  // Warp.createAccount(0, "Unstoppable", "<SEED PHRASE>",
  //   0, 419201);
  // Warp.resetChain(0, 0);

  print("List accounts");
  final accounts = await warp.listAccounts(zcash);
  for (var a in accounts) {
    print(a);
  }

  final balance = await warp.getBalance(zcash, 1, 0);
  print(balance);

  while (await warp.getBCHeight(zcash) > warp.getSyncHeight(zcash)) {
    await WarpSync.synchronize(zcash, await warp.getBCHeight(zcash));
  }
  print('Synchronization completed');

  await warp.retrieveTransactionDetails(zcash);

  // final payments = [PaymentRequestT(
  //   address: "zs1avauf3r6afmt052aw03wwk874uu3s5cxwdtmcqaawt5jxevr5sevw6avna6wvf233ezu59zgkfm",
  //   amount: 1000000,
  //   memoString: "Hello",
  //   memoBytes: [])];

  // final req = PaymentRequestsT(payments: payments);
  // var plan = await warp.pay(zcash, 1, req, 7, true, 1);
  // // plan.data = []; // discard the tx bytes
  // final txBytes = await warp.sign(zcash, plan, await warp.getBCHeight(0) + 50);
  // print(txBytes.length);

  // final txid = await warp.broadcast(zcash, txBytes);
  // print(txid);

  final txd = await warp.fetchTxDetails(zcash, 1, 25);
  print(txd);
}
