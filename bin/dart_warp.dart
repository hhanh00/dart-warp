import 'package:dart_warp/warp.dart';

void main(List<String> arguments) {
  print("Run");
  warpLib.c_setup();
  print("Initialized");

  print("List accounts");
  final accounts = Warp.listAccounts(0);
  for (var a in accounts) {
    print(a);
  }
}
