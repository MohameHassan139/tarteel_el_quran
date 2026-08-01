import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final RxBool isOnline = true.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<ConnectivityService> init() async {
    final initialResults = await _connectivity.checkConnectivity();
    isOnline.value = _hasConnection(initialResults);

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
    });

    return this;
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
