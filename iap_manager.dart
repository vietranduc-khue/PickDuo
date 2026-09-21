import 'dart:async';
import 'package:in_app_purchase/in_app_purchase';

class IAPManager {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final String _removeAdsProductId = 'pickduo_remove_ads'; 
  bool isUserPremium = false;

  void initializeIAP() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print(error);
    });
  }

  Future<void> buyRemoveAds() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) return;

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_removeAdsProductId});
    if (response.notFoundIDs.contains(_removeAdsProductId) || response.productDetails.isEmpty) return;

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        continue;
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        if (purchaseDetails.productID == _removeAdsProductId) {
          isUserPremium = true;
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}