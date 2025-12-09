// lib/providers/subscription_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:student_suite/utils/error_utils.dart';

// Stripe price IDs
//const String _kStripePromoPriceId = 'price_1P3zY1J2xQ3zY1J2xQ3zY1J2';
//const String _kStripeStandardPriceId = 'price_1P3zY1J2xQ3zY1J2xQ3zY1J3';
const String _kStripePromoPriceId = 'price_1RkqBzAt2vKSOayIIDwsvYTr';
const String _kStripeStandardPriceId = 'price_1RpIkuAt2vKSOayIyqw5nZnO';

const String _kStripeReferralCouponId =
    'referral-bonus'; // Must match the ID you create in Stripe Dashboard
// IAP product ID
const String _kProSubscriptionId = 'com.pegumax.studentsuite.pro.monthly';
const String _kFounderSubscriptionId = 'com.pegumax.studentsuite.pro.founder';
// Platform channel to native iOS helper
const MethodChannel _kIapMethodChannel = MethodChannel('com.pegumax.iap');

class SubscriptionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppPurchase _iap = InAppPurchase.instance;
  final bool _showDeveloperBuildNote = false;

  User? _user;
  String? _referralCode;

  bool _hasReferral = false;

  bool _isPro = false;
  bool get isPro => _isPro;

  // NEW: Expose expiry and ID for UI logic
  DateTime? _expiryDate;
  DateTime? get trialExpiryDate => _expiryDate;

  String? _currentProductId;
  String? get currentProductId => _currentProductId;

  bool get isStripeSubscription {
    return _stripeSubscriptionId != null && _stripeSubscriptionId!.isNotEmpty;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final bool _verifyingPurchase = false;
  bool get verifyingPurchase => _verifyingPurchase;

  String? _purchaseError;
  String? get purchaseError => _purchaseError;

  bool _nativeIAPProductsFetched = false;
  bool get nativeIAPProductsFetched => _nativeIAPProductsFetched;

  bool get canBuySubscription {
    // Web uses Stripe flow; assume true there.
    if (kIsWeb) return true;
    if (_isMobilePlatform) return _nativeIAPProductsFetched;
    return true;
  }

  // Stripe customer identifier
  // This field is intentionally kept for future server-side flows.
  // The analyzer may report it as unused in some configurations.
  // ignore: unused_field
  String? _stripeCustomerId;
  String? _stripeSubscriptionId;
  // Diagnostics: last checkout doc path and last server-side error (if any)
  String? _lastCheckoutDocPath;
  String? _lastCheckoutServerError;

  String? get referralCode => _referralCode;
  bool get showDeveloperBuildNote => _showDeveloperBuildNote;

  // Diagnostics accessors
  String? get lastCheckoutDocPath => _lastCheckoutDocPath;
  String? get lastCheckoutServerError => _lastCheckoutServerError;

  // Single purchase listener (the fix)
  StreamSubscription<List<PurchaseDetails>>? _purchaseUpdatedSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscriptionStatusSubscription;

  bool _processingPurchase = false;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  final Map<String, String> _restoredReceipts = {};
  final Set<String> _processedPurchaseIds = {};
  Completer<String?>? _restoreCompleter;

  bool _showRestoreButton = false;
  bool get showRestoreButton => _showRestoreButton;

  Timer? _purchaseWatchdogTimer; // watchdog to avoid indefinite spinner

  // Platform helpers: avoid calling dart:io Platform.* on web where it
  // throws. Use kIsWeb/defaultTargetPlatform for safe checks.
  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get _isIOSPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  SubscriptionProvider() {
    // Guard attaching to native purchase stream on web or unsupported
    // environments. The in_app_purchase plugin can throw during
    // initialization on some platforms; avoid letting that crash provider
    // construction by wrapping it in a try/catch and skipping on web.
    try {
      if (!kIsWeb) {
        //_listenToPurchaseUpdated();
      } else {
        debugPrint(
            'DEBUG (Flutter): Skipping purchase stream listener on web.');
      }
    } catch (e, st) {
      debugPrint(
          'ERROR (Flutter): Failed to attach purchase stream listener: $e\n$st');
    }
  }

  Future<void> update(User? user) async {
    debugPrint("DEBUG (Flutter): SubscriptionProvider.update() called.");
    if (_user?.uid != user?.uid) {
      await cancelStreams();
      await resetProStatus();
    }
    await loadSubscriptionStatus(user);
    if (user != null) {
      await initializePurchaseFlow();
    }
  }

  Future<void> initializePurchaseFlow() async {
    if (!_isMobilePlatform) return;
    // --- FIX: ADD THIS BLOCK ---
    // This ensures the IAP plugin is fully ready before we listen.
    if (_purchaseUpdatedSubscription == null) {
      try {
        _listenToPurchaseUpdated();
        debugPrint("DEBUG (Flutter): Purchase stream listener attached.");
      } catch (e) {
        debugPrint("DEBUG (Flutter): Attaching listener failed: $e");
      }
    }
    // --- FIX: AUTO-RESTORE ON APP LOAD ---
    // This catches any purchases that were missed or made on another device.
    try {
      debugPrint("DEBUG (Flutter): Calling restorePurchases() on init.");
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint("DEBUG (Flutter): Initial restorePurchases() failed: $e");
      // Don't block the app, just log it.
    }
    // ------------------------------------
    if (_nativeIAPProductsFetched) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _fetchIAPProducts();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearPurchaseError() {
    _purchaseError = null;
    _showRestoreButton = false;
    notifyListeners();
  }

  // NEW helper: start watchdog
  void _startPurchaseWatchdog(
      {Duration timeout = const Duration(seconds: 30)}) {
    _cancelPurchaseWatchdog();
    debugPrint(
        'DEBUG (Flutter): Starting purchase watchdog (${timeout.inSeconds}s).');
    _purchaseWatchdogTimer = Timer(timeout, () {
      debugPrint(
          'DEBUG (Flutter): Purchase watchdog fired — starting diagnostic attempt.');
      _diagnoseStuckPurchase().whenComplete(() {
        debugPrint(
            'DEBUG (Flutter): Purchase watchdog diagnostic completed — clearing UI.');
        _isLoading = false;
        _processingPurchase = false;
        _purchaseError ??=
            "No purchase response from platform. Please try again or use Restore Purchases.";
        _showRestoreButton = true;
        notifyListeners();
      });
    });
  }

  // NEW helper: cancel watchdog
  void _cancelPurchaseWatchdog() {
    if (_purchaseWatchdogTimer != null) {
      try {
        _purchaseWatchdogTimer!.cancel();
      } catch (_) {}
      _purchaseWatchdogTimer = null;
      debugPrint('DEBUG (Flutter): Purchase watchdog cancelled.');
    }
  }

  // NEW: Attempt to recover a receipt and force backend verification so you get function logs.
  Future<void> _diagnoseStuckPurchase() async {
    debugPrint('DEBUG (Flutter): _diagnoseStuckPurchase: start');
    try {
      // 1) Quick diagnostic: check cached verificationData on any recent PurchaseDetails
      try {
        final cached = _restoredReceipts[_kProSubscriptionId];
        if (cached != null && cached.trim().isNotEmpty) {
          debugPrint(
              'DEBUG (Flutter): _diagnoseStuckPurchase: using cached restored receipt (len=${cached.length}).');
          await _attemptBackendVerify(cached,
              platform: _isIOSPlatform ? 'app_store' : 'play_store');
          return;
        }
      } catch (e) {
        debugPrint(
            'DEBUG (Flutter): _diagnoseStuckPurchase cached-check failed: $e');
      }

      // 2) Ask plugin for past purchases / trigger restore to force a purchaseStream emission
      try {
        debugPrint(
            'DEBUG (Flutter): _diagnoseStuckPurchase: calling restorePurchases to prompt platform.');
        await _iap.restorePurchases();
      } catch (e) {
        debugPrint(
            'DEBUG (Flutter): _diagnoseStuckPurchase: restorePurchases() threw: $e');
      }

      // 3) Try to get receipt via platform channel (iOS specific)
      if (_isIOSPlatform) {
        try {
          debugPrint(
              'DEBUG (Flutter): _diagnoseStuckPurchase: invoking getAppStoreReceipt()');
          final nativeReceipt = await _kIapMethodChannel
              .invokeMethod<String>('getAppStoreReceipt');
          if (nativeReceipt != null && nativeReceipt.trim().isNotEmpty) {
            debugPrint(
                'DEBUG (Flutter): _diagnoseStuckPurchase: got native receipt (len=${nativeReceipt.length}).');
            await _attemptBackendVerify(nativeReceipt, platform: 'app_store');
            return;
          } else {
            debugPrint(
                'DEBUG (Flutter): _diagnoseStuckPurchase: native getAppStoreReceipt returned empty.');
          }

          debugPrint(
              'DEBUG (Flutter): _diagnoseStuckPurchase: invoking refreshAppStoreReceipt()');
          final refreshed = await _kIapMethodChannel
              .invokeMethod<String>('refreshAppStoreReceipt');
          if (refreshed != null && refreshed.trim().isNotEmpty) {
            debugPrint(
                'DEBUG (Flutter): _diagnoseStuckPurchase: got refreshed receipt (len=${refreshed.length}).');
            await _attemptBackendVerify(refreshed, platform: 'app_store');
            return;
          } else {
            debugPrint(
                'DEBUG (Flutter): _diagnoseStuckPurchase: refreshAppStoreReceipt returned empty.');
          }
        } catch (e, st) {
          debugPrint(
              'DEBUG (Flutter): _diagnoseStuckPurchase: MethodChannel call failed: $e\n$st');
        }
      }

      // 4) Android: try to inspect verificationData from any recent purchase if possible (best-effort)
      if (_isAndroidPlatform) {
        try {
          final cached = _restoredReceipts[_kProSubscriptionId];
          if (cached != null && cached.trim().isNotEmpty) {
            debugPrint(
                'DEBUG (Flutter): _diagnoseStuckPurchase: Android using cached receipt.');
            await _attemptBackendVerify(cached, platform: 'play_store');
            return;
          }
        } catch (e) {
          debugPrint(
              'DEBUG (Flutter): _diagnoseStuckPurchase: Android cached-check failed: $e');
        }
      }

      debugPrint(
          'DEBUG (Flutter): _diagnoseStuckPurchase: no receipt found during diagnostic.');
    } catch (e, st) {
      debugPrint(
          'DEBUG (Flutter): _diagnoseStuckPurchase: unexpected error: $e\n$st');
    } finally {
      debugPrint('DEBUG (Flutter): _diagnoseStuckPurchase: end');
    }
  }

  Future<bool> redeemReferralCode(String code) async {
    if (_user == null) return false;

    try {
      final inviterQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (inviterQuery.docs.isEmpty) {
        _purchaseError = "Invalid referral code.";
        notifyListeners();
        return false;
      }

      final inviterDoc = inviterQuery.docs.first;

      // 1. Give the new user 30 days Pro
      await _firestore.collection('users').doc(_user!.uid).set({
        'subscription': {
          'platform': 'referral',
          'productId': 'referral_free_month',
          'expiresDate':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'referralUsed': code,
      }, SetOptions(merge: true));

      _isPro = true;
      notifyListeners();

      // 2. Optionally reward inviter with extra month
      await _firestore.collection('users').doc(inviterDoc.id).update({
        'referralRewards': FieldValue.increment(1),
      });

      return true;
    } catch (e, st) {
      debugPrint("redeemReferralCode error: $e\n$st");
      _purchaseError = "Could not redeem referral code. Please try again.";
      notifyListeners();
      return false;
    }
  }

  Future<void> assignReferralCode(User user) async {
    final code = user.uid.substring(0, 6).toUpperCase(); // Simple short code

    await _firestore.collection('users').doc(user.uid).set({
      'referralCode': code,
      'referralRewards': 0,
    }, SetOptions(merge: true));

    _referralCode = code;
    notifyListeners();
  }

  // NEW helper: try to call the backend verification callable so you get server logs
  Future<void> _attemptBackendVerify(String receipt,
      {required String platform}) async {
    if (_user == null) {
      debugPrint(
          'DEBUG (Flutter): _attemptBackendVerify: no authenticated user; skipping backend call.');
      return;
    }

    try {
      debugPrint(
          'DEBUG (Flutter): _attemptBackendVerify: calling processIAPReceipt (platform=$platform, receiptLen=${receipt.length}).');
      final verifyPurchaseFn =
          FirebaseFunctions.instance.httpsCallable('processIAPReceipt');
      final result = await verifyPurchaseFn.call(<String, dynamic>{
        'receiptData': receipt,
        'userId': _user!.uid,
        'productId': _kProSubscriptionId,
        'source': platform,
      });

      final data = result.data as Map<String, dynamic>?;
      debugPrint(
          'DEBUG (Flutter): _attemptBackendVerify: backend response -> $data');

      if (data != null && data['success'] == true) {
        debugPrint(
            'DEBUG (Flutter): _attemptBackendVerify: verification success — updating local state.');
        _isPro = true;
        _showRestoreButton = false;
        _purchaseError = null;
        await saveSubscriptionStatus(
            platform: platform, productId: _kProSubscriptionId);
      } else {
        final backendError =
            data?['error'] ?? 'verification failed or returned false';
        debugPrint(
            'DEBUG (Flutter): _attemptBackendVerify: backend verification failed -> $backendError');
        _purchaseError = 'Verification failed: $backendError';
        _showRestoreButton = true;
      }
    } catch (e, st) {
      debugPrint(
          'DEBUG (Flutter): _attemptBackendVerify: exception calling processIAPReceipt: $e\n$st');
      _purchaseError = 'Error verifying purchase. See logs.';
      _showRestoreButton = true;
    } finally {
      // ensure UI updated
      _isLoading = false;
      _processingPurchase = false;
      notifyListeners();
    }
  }

  // Single listener for purchase updates (clean implementation)
  void _listenToPurchaseUpdated() {
    _purchaseUpdatedSubscription = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) async {
        for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
          try {
            debugPrint("DEBUG (Flutter): Purchase update -> "
                "status=${purchaseDetails.status}, "
                "product=${purchaseDetails.productID}, "
                "source=${purchaseDetails.verificationData.source}, "
                "localLen=${purchaseDetails.verificationData.localVerificationData.length}, "
                "serverLen=${purchaseDetails.verificationData.serverVerificationData.length}");
            if (purchaseDetails.purchaseID != null &&
                _processedPurchaseIds.contains(purchaseDetails.purchaseID)) {
              debugPrint(
                  "DEBUG (Flutter): Skipping already processed purchaseID: ${purchaseDetails.purchaseID}");
              continue;
            }
            // Cancel watchdog early - we received an event
            try {
              _cancelPurchaseWatchdog();
            } catch (_) {}

            // Error path
            if (purchaseDetails.status == PurchaseStatus.error) {
              debugPrint(
                  'DEBUG (Flutter): Purchase error: ${purchaseDetails.error}');
              _purchaseError = ErrorUtils.getFriendlyMessage(
                "Purchase failed: ${purchaseDetails.error?.message ?? 'unknown'}",
                context: "subscription",
              );
              _isLoading = false;
              _processingPurchase = false;
              notifyListeners();

              if (purchaseDetails.pendingCompletePurchase) {
                try {
                  _iap.completePurchase(purchaseDetails);
                } catch (e) {
                  debugPrint(
                      'DEBUG (Flutter): completePurchase error after failure -> $e');
                }
              }
              continue;
            }

            // Pending path
            if (purchaseDetails.status == PurchaseStatus.pending) {
              debugPrint(
                  'DEBUG (Flutter): Purchase pending for product: ${purchaseDetails.productID}');
              _purchaseError = null;
              _isLoading = true;
              _processingPurchase = true;
              notifyListeners();
              continue;
            }

            // Purchased or Restored -> verify and finalize
            if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              if (purchaseDetails.purchaseID != null) {
                _processedPurchaseIds.add(purchaseDetails.purchaseID!);
              }
              debugPrint('DEBUG (Flutter): Purchase completed; verifying...');

              _isLoading = true;
              _processingPurchase = true;
              notifyListeners();

              // --- DEADLOCK FIX: Acknowledge IMMEDIATELY ---
              // The backend refuses to verify unacknowledged purchases, so we
              // must acknowledge them on the client side first to break the loop.
              if (purchaseDetails.pendingCompletePurchase) {
                try {
                  debugPrint(
                      'DEBUG (Flutter): Acknowledging purchase BEFORE verification to prevent deadlock...');
                  await _iap.completePurchase(purchaseDetails);
                  debugPrint('DEBUG (Flutter): Acknowledgement sent to Store.');
                } catch (e) {
                  debugPrint(
                      'DEBUG (Flutter): Pre-verification acknowledgement warning: $e');
                }
              }

              // FIX: Use localVerificationData for Android (contains packageName + token)
              // Use serverVerificationData for iOS (contains base64 receipt)
              String receiptToVerify;
              if (_isAndroidPlatform) {
                receiptToVerify =
                    purchaseDetails.verificationData.localVerificationData;
                debugPrint(
                    "DEBUG (Flutter): Using localVerificationData for Android verification.");
              } else {
                receiptToVerify =
                    purchaseDetails.verificationData.serverVerificationData;
              }

              final String platform =
                  _isIOSPlatform ? 'app_store' : 'play_store';

              try {
                if (receiptToVerify.isNotEmpty) {
                  await _attemptBackendVerify(receiptToVerify,
                      platform: platform);
                } else {
                  debugPrint(
                      'DEBUG (Flutter): No server receipt available; attempting alternate verification.');
                  // Fallback flows (native receipt) are handled in _handleSuccessfulPurchase if used elsewhere
                }

                // At this point _attemptBackendVerify should have updated entitlement.
                if (_isPro) {
                  try {
                    await saveSubscriptionStatus(
                      platform: platform,
                      productId: purchaseDetails.productID,
                    );
                  } catch (e) {
                    debugPrint(
                        'DEBUG (Flutter): saveSubscriptionStatus failed: $e');
                  }

                  // if (purchaseDetails.pendingCompletePurchase) {
                  //   try {
                  //     await _iap.completePurchase(purchaseDetails);
                  //   } catch (e) {
                  //     debugPrint(
                  //         'DEBUG (Flutter): completePurchase error -> $e');
                  //   }
                  // }

                  _purchaseError = null;
                  _processingPurchase = false;
                  _isLoading = false;
                  notifyListeners();
                } else {
                  _purchaseError = ErrorUtils.getFriendlyMessage(
                    "Purchase verification failed. Please contact support.",
                    context: "subscription",
                  );
                  _processingPurchase = false;
                  _isLoading = false;
                  notifyListeners();

                  // if (purchaseDetails.pendingCompletePurchase) {
                  //   try {
                  //     await _iap.completePurchase(purchaseDetails);
                  //   } catch (e) {
                  //     debugPrint(
                  //         'DEBUG (Flutter): completePurchase after failed verification -> $e');
                  //   }
                  // }
                }
              } catch (e, st) {
                debugPrint(
                    'DEBUG (Flutter): Exception verifying/persisting purchase -> $e\n$st');
                _purchaseError = ErrorUtils.getFriendlyMessage(
                  "Error verifying purchase. Try again later or use web Stripe to subscribe.",
                  context: "subscription",
                );
                _processingPurchase = false;
                _isLoading = false;
                notifyListeners();
              }

              continue;
            }

            debugPrint(
                'DEBUG (Flutter): Unhandled purchase status: ${purchaseDetails.status}');
          } catch (e, st) {
            debugPrint(
                'DEBUG (Flutter): Exception in purchase update loop -> $e\n$st');
          }
        }
      },
      onDone: () {
        debugPrint('DEBUG (Flutter): Purchase stream done.');
      },
      onError: (error) {
        debugPrint('DEBUG (Flutter): Purchase stream error: $error');
      },
    );
  }

  // This helper is retained for platform-specific recovery flows. It may
  // not be referenced on every platform/configuration. Suppress unused
  // warning to keep the logic available for future debugging.
  // ignore: unused_element
  Future<String?> _getValidReceiptDataForProduct(String productId,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final existing = _restoredReceipts[productId];
    if (existing != null && existing.trim().isNotEmpty) {
      debugPrint(
          'DEBUG (Flutter): Found existing restored receipt for $productId (len=${existing.length}).');
      return existing;
    }

    if (!_isIOSPlatform) {
      debugPrint(
          'DEBUG (Flutter): Not iOS; cannot attempt restore for $productId.');
      return null;
    }

    debugPrint(
        'DEBUG (Flutter): Attempting restorePurchases() for $productId.');
    _restoreCompleter = Completer<String?>();

    try {
      await _iap.restorePurchases();

      final val =
          await _restoreCompleter!.future.timeout(timeout, onTimeout: () {
        if (!_restoreCompleter!.isCompleted) {
          _restoreCompleter!.complete(null);
        }
        return null;
      });

      _restoreCompleter = null;

      if (val != null && val.trim().isNotEmpty) {
        debugPrint(
            'DEBUG (Flutter): restorePurchases yielded a receipt for $productId (len=${val.length}).');
        return val;
      }

      final fallback = _restoredReceipts[productId];
      if (fallback != null && fallback.trim().isNotEmpty) {
        debugPrint(
            'DEBUG (Flutter): Found restored receipt after restorePurchases.');
        return fallback;
      }

      debugPrint('DEBUG (Flutter): No receipt found after restorePurchases.');
      return null;
    } catch (e) {
      debugPrint('DEBUG (Flutter): restorePurchases error: $e');
      _restoreCompleter = null;
      return null;
    }
  }

  Future<void> _fetchIAPProducts() async {
    try {
      debugPrint("DEBUG (Flutter): Requesting IAP products...");
      _purchaseError = null;
      notifyListeners();

      const Set<String> ids = {_kProSubscriptionId, _kFounderSubscriptionId};
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(ids);

      debugPrint(
          'DEBUG (Flutter): ProductDetailsResponse -> products=${response.productDetails.length}, notFoundIDs=${response.notFoundIDs}, error=${response.error}');

      if (response.error != null) {
        debugPrint("DEBUG (Flutter): Product query error: ${response.error}");
        _purchaseError = ErrorUtils.getFriendlyMessage(
          "Error fetching products: ${response.error?.message ?? response.error}",
          context: "subscription",
        );
        _products = [];
        _nativeIAPProductsFetched = false;
        notifyListeners();
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            "DEBUG (Flutter): Product IDs not found by store: ${response.notFoundIDs}");
        _purchaseError = ErrorUtils.getFriendlyMessage(
          "Subscription not available in this build/environment. Upload a TestFlight/internal Play build and ensure the product is linked to the binary.",
          context: "subscription",
        );
        _products = response.productDetails;
        _nativeIAPProductsFetched = false;
        notifyListeners();
        return;
      }

      _products = response.productDetails;
      _nativeIAPProductsFetched = true;
      _purchaseError = null;

      debugPrint("DEBUG (Flutter): Successfully fetched products.");
      for (final p in _products) {
        debugPrint(
            "DEBUG (Flutter): Product -> id=${p.id}, title=${p.title}, price=${p.price}");
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint("DEBUG (Flutter): Exception in _fetchIAPProducts: $e\n$st");
      _purchaseError = ErrorUtils.getFriendlyMessage(
        "Failed to fetch IAP products: $e",
        context: "subscription",
      );
      _products = [];
      _nativeIAPProductsFetched = false;
      notifyListeners();
    }
  }

  Future<void> _handleSuccessfulPurchase(
      PurchaseDetails purchaseDetails) async {
    debugPrint(
        "DEBUG (Flutter): Handling successful purchase for product: ${purchaseDetails.productID}");

    _cancelPurchaseWatchdog();

    if (_user == null) {
      _purchaseError = ErrorUtils.getFriendlyMessage(
        "User not logged in.",
        context: "subscription",
      );
      _isLoading = false;
      _processingPurchase = false;
      notifyListeners();
      return;
    }

    String? receiptData;

    try {
      if (_isIOSPlatform) {
        if (purchaseDetails
            .verificationData.serverVerificationData.isNotEmpty) {
          receiptData = purchaseDetails.verificationData.serverVerificationData;
          debugPrint("DEBUG (Flutter): Using serverVerificationData (iOS).");
        }
        if (receiptData == null || receiptData.trim().isEmpty) {
          receiptData = await _kIapMethodChannel
              .invokeMethod<String>('getAppStoreReceipt');
          debugPrint(
              "DEBUG (Flutter): Using native App Store receipt (cached).");
        }
        if (receiptData == null ||
            receiptData.trim().isEmpty ||
            !_isValidBase64(receiptData)) {
          debugPrint(
              "DEBUG (Flutter): Forcing refresh of App Store receipt...");
          receiptData = await _kIapMethodChannel
              .invokeMethod<String>('refreshAppStoreReceipt');
        }
      } else if (_isAndroidPlatform) {
        // FIX: Always prioritize localVerificationData on Android
        // The backend needs the full JSON to extract the packageName.
        if (purchaseDetails.verificationData.localVerificationData.isNotEmpty) {
          receiptData = purchaseDetails.verificationData.localVerificationData;
          debugPrint("DEBUG (Flutter): Using localVerificationData (Android).");
        } else {
          receiptData = purchaseDetails.verificationData.serverVerificationData;
          debugPrint(
              "DEBUG (Flutter): Fallback to serverVerificationData (Android).");
        }
      }
    } catch (e) {
      debugPrint("DEBUG (Flutter): Receipt extraction failed: $e");
    }

    receiptData = _normalizePossibleWrappedReceipt(receiptData);

    if (receiptData == null ||
        receiptData.trim().isEmpty ||
        !_isValidBase64(receiptData)) {
      debugPrint("DEBUG (Flutter): No valid receipt found.");
      _purchaseError = ErrorUtils.getFriendlyMessage(
        "Unable to validate purchase. Please try Restore Purchases.",
        context: "subscription",
      );
      _showRestoreButton = true;
      _isLoading = false;
      _processingPurchase = false;
      notifyListeners();
      return;
    }

    try {
      final verifyPurchaseFn =
          FirebaseFunctions.instance.httpsCallable('processIAPReceipt');
      final result = await verifyPurchaseFn.call(<String, dynamic>{
        'receiptData': receiptData,
        'userId': _user!.uid,
        'productId': purchaseDetails.productID,
        'source': _isIOSPlatform ? 'app_store' : 'play_store',
      });

      final data = result.data as Map<String, dynamic>?;

      if (data != null && data['success'] == true) {
        debugPrint("DEBUG (Flutter): Purchase validated successfully.");
        _isPro = true;
        _showRestoreButton = false;
        _purchaseError = null;

        await saveSubscriptionStatus(
          platform: _isIOSPlatform ? 'app_store' : 'play_store',
          productId: purchaseDetails.productID,
        );
      } else {
        final backendError = data?['error'] ?? "Purchase validation failed.";
        debugPrint("DEBUG (Flutter): Validation failed: $backendError");
        if (!_isPro) {
          _isPro = false;
          _purchaseError = ErrorUtils.getFriendlyMessage(
            backendError,
            context: "subscription",
          );
          _showRestoreButton = true;
        }
      }
    } catch (e, st) {
      debugPrint(
          "DEBUG (Flutter): Exception during purchase validation: $e\n$st");
      if (!_isPro) {
        _isPro = false;
        _purchaseError = ErrorUtils.getFriendlyMessage(
          "Error validating purchase: $e",
          context: "subscription",
        );
        _showRestoreButton = true;
      }
    } finally {
      _isLoading = false;
      _processingPurchase = false;
      notifyListeners();
    }
  }

  String? _normalizePossibleWrappedReceipt(String? raw) {
    if (raw == null) return null;
    String s = raw.trim();

    if (s.startsWith('{')) {
      try {
        final parsed = json.decode(s);
        if (parsed is Map) {
          for (final key in [
            'data',
            'receipt',
            'signedTransactionInfo',
            'transactionReceipt',
            'payload'
          ]) {
            if (parsed.containsKey(key) && parsed[key] is String) {
              final candidate = (parsed[key] as String).trim();
              if (candidate.isNotEmpty) {
                s = candidate;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    if (s.startsWith('"') && s.endsWith('"') && s.length > 1) {
      s = s.substring(1, s.length - 1);
    }

    if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length >= 2) {
        try {
          String payloadPart = parts[1];
          payloadPart = payloadPart.replaceAll('-', '+').replaceAll('_', '/');
          while (payloadPart.length % 4 != 0) {
            payloadPart += '=';
          }
          final decoded = utf8.decode(base64.decode(payloadPart));
          final decodedJson = json.decode(decoded);
          if (decodedJson is Map) {
            for (final key in [
              'receipt',
              'data',
              'signedTransactionInfo',
              'transactionReceipt'
            ]) {
              if (decodedJson.containsKey(key) && decodedJson[key] is String) {
                final candidate = (decodedJson[key] as String).trim();
                if (candidate.isNotEmpty) return candidate;
              }
            }
          }
        } catch (_) {}
      }
      return s;
    }

    if (s.contains('-') || s.contains('_')) {
      s = s.replaceAll('-', '+').replaceAll('_', '/');
      while (s.length % 4 != 0) {
        s += '=';
      }
    }

    return s;
  }

  bool _isValidBase64(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final t = s.trim();
    if (t.contains('.')) return false;
    final reg = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (!reg.hasMatch(t)) return false;
    try {
      base64.decode(t);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _processDocData(Map<String, dynamic> data) {
    final sub = data['subscription'] as Map<String, dynamic>?;
    String? productId;
    DateTime? expiry;

    if (sub != null) {
      productId = sub['productId'] as String?;
      final expiresDate = sub['expiresDate'];
      if (expiresDate != null) {
        if (expiresDate is Timestamp) {
          expiry = expiresDate.toDate();
        } else if (expiresDate is String) {
          expiry = DateTime.tryParse(expiresDate);
        }
      }
    }

    _currentProductId = productId;
    _expiryDate = expiry;

    final hasStripe = (data['stripeRole'] as String?) == 'pro';
    _stripeCustomerId = data['stripeCustomerId'] as String?;
    _stripeSubscriptionId = data['stripeSubscriptionId'] as String?;

    final bool isStandard = productId == _kProSubscriptionId;
    final bool isFounder = productId == _kFounderSubscriptionId;
    final bool isReferralGrant =
        productId == 'referral_bonus'; // Matches AuthProvider

    final bool isIAPPro = (isStandard || isFounder || isReferralGrant);

    // FIX: Benefit of the Doubt.
    // If expiry is null, we assume they are ACTIVE (not expired).
    // This allows the "Mobile Grant" to work while Firestore is still writing the date.
    // We only mark them expired if we have a date AND it is in the past.
    bool isIAPExpired = false;
    if (expiry != null) {
      isIAPExpired = expiry.isBefore(DateTime.now());
    }
    final bool isStripePro = hasStripe;

    _isPro = (isIAPPro && !isIAPExpired) || isStripePro;
    debugPrint(
        'DEBUG (Flutter): User ${_user?.uid ?? "null"} - productId: $productId, expiry: $expiry, isStripePro: $isStripePro -> _isPro: $_isPro');
    if (data['referredBy'] != null) {
      _hasReferral = true;
    } else {
      _hasReferral = false;
    }
  }

  Future<void> loadSubscriptionStatus(User? user) async {
    debugPrint(
        'DEBUG (Flutter): loadSubscriptionStatus called with user: ${user?.uid ?? "null"}');
    if (_userSubscriptionStatusSubscription != null &&
        (_user == null || user?.uid != _user?.uid)) {
      debugPrint(
          'DEBUG (Flutter): Cancelling previous user subscription listener.');
      await _userSubscriptionStatusSubscription?.cancel();
      _userSubscriptionStatusSubscription = null;
    }

    _user = user;

    if (_user == null) {
      _isPro = false;
      _isLoading = false;
      _nativeIAPProductsFetched = false;
      _stripeCustomerId = null;
      _stripeSubscriptionId = null;
      notifyListeners();
      debugPrint('DEBUG (Flutter): User is null, setting _isPro to false.');
      return;
    }

    if (_userSubscriptionStatusSubscription == null) {
      debugPrint(
          'DEBUG (Flutter): Setting up NEW user subscription listener for UID: ${_user!.uid}');
      _userSubscriptionStatusSubscription =
          _firestore.collection('users').doc(_user!.uid).snapshots().listen(
        (doc) {
          if (doc.exists) {
            _processDocData(doc.data()!);
          } else {
            debugPrint(
                'DEBUG (Flutter): User doc does not exist, setting _isPro=false.');
            _isPro = false;
            _stripeCustomerId = null;
            _stripeSubscriptionId = null;
          }
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          debugPrint(
              'DEBUG (Flutter): Error listening to subscription status: $error');
          _isPro = false;
          _isLoading = false;
          _stripeCustomerId = null;
          _stripeSubscriptionId = null;
          notifyListeners();
        },
      );
    } else {
      debugPrint(
          'DEBUG (Flutter): Subscription listener already active for UID: ${_user!.uid}');
      _firestore.collection('users').doc(_user!.uid).get().then((doc) {
        if (doc.exists) {
          _processDocData(doc.data()!);
        }
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  Future<bool> buySubscription(bool isFounder) async {
    if (_isLoading || _processingPurchase) {
      debugPrint('DEBUG (Flutter): buySubscription called while already busy.');
      return false;
    }
    _isLoading = true;
    notifyListeners();

    try {
      if (_isMobilePlatform) {
        // Ensure products loaded
        if (_products.isEmpty) {
          await initializePurchaseFlow();
        }

        if (_products.isEmpty) {
          _purchaseError = ErrorUtils.getFriendlyMessage(
            "Could not load products. Please try again.",
            context: "subscription",
          );
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // --- NEW SELECTION LOGIC ---
        // Decide which ID to buy
        String targetId =
            isFounder ? _kFounderSubscriptionId : _kProSubscriptionId;

        // Find it in the list
        ProductDetails? productToBuy;
        try {
          productToBuy = _products.firstWhere((p) => p.id == targetId);
        } catch (_) {
          // Fallback: If they are a Founder but for some reason that SKU is
          // missing/inactive in the store, gracefully degrade to the Standard SKU
          // so they can at least buy *something*.
          if (isFounder) {
            debugPrint("DEBUG: Founder SKU missing, falling back to Standard.");
            try {
              productToBuy =
                  _products.firstWhere((p) => p.id == _kProSubscriptionId);
            } catch (_) {}
          }
        }

        if (productToBuy == null) {
          _purchaseError = ErrorUtils.getFriendlyMessage(
            "Product unavailable ($targetId). Please check store configuration.",
            context: "subscription",
          );
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // ---------------------------

        debugPrint(
            'DEBUG (Flutter): Initiating purchase for product id: ${productToBuy.id}');

        final PurchaseParam purchaseParam =
            PurchaseParam(productDetails: productToBuy);

        // Try to open platform purchase UI
        final bool initiated =
            await _iap.buyNonConsumable(purchaseParam: purchaseParam);
        debugPrint(
            'DEBUG (Flutter): _iap.buyNonConsumable returned -> $initiated');

        if (!initiated) {
          _purchaseError = ErrorUtils.getFriendlyMessage(
            "Purchase UI did not open. This often means the product is not available in this build (upload TestFlight / Play Internal).",
            context: "subscription",
          );
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Started successfully — start watchdog to detect no events arriving
        _startPurchaseWatchdog(timeout: const Duration(seconds: 30));
        notifyListeners();
        return true;
      } else {
        // Web/Desktop - use Stripe fallback
        final priceId =
            isFounder ? _kStripePromoPriceId : _kStripeStandardPriceId;
        await launchCheckoutSession(priceId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e, st) {
      debugPrint('DEBUG (Flutter): buySubscription error: $e\n$st');
      _purchaseError = ErrorUtils.getFriendlyMessage(
        "Unexpected error: $e",
        context: "subscription",
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isMobilePlatform) {
      _purchaseError = "Restore is only available on mobile.";
      notifyListeners();
      return;
    }

    if (_isLoading || _processingPurchase) return;

    _isLoading = true;
    _purchaseError = null;
    notifyListeners();

    try {
      String? receiptData;
      if (_isIOSPlatform) {
        try {
          receiptData = await _kIapMethodChannel
              .invokeMethod<String>('getAppStoreReceipt');
        } catch (_) {}
      }

      if (receiptData != null && receiptData.trim().isNotEmpty) {
        final fakePurchase = PurchaseDetails(
          purchaseID: "manual_restore",
          productID: _kProSubscriptionId,
          status: PurchaseStatus.restored,
          transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
          verificationData: PurchaseVerificationData(
            localVerificationData: receiptData,
            serverVerificationData: receiptData,
            source: "app_store",
          ),
        );
        await _handleSuccessfulPurchase(fakePurchase);
      } else {
        debugPrint("DEBUG (Flutter): Falling back to restorePurchases().");
        // Start a short watchdog for restore as well to avoid indefinite wait
        _restoreCompleter = Completer<String?>();
        _startPurchaseWatchdog(timeout: const Duration(seconds: 20));
        await _iap.restorePurchases();
        try {
          final val = await (_restoreCompleter?.future
              .timeout(const Duration(seconds: 20)));
          if (val != null && val.trim().isNotEmpty) {
            _restoredReceipts[_kProSubscriptionId] = val;
            final fakePurchase2 = PurchaseDetails(
              purchaseID: "manual_restore2",
              productID: _kProSubscriptionId,
              status: PurchaseStatus.restored,
              transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
              verificationData: PurchaseVerificationData(
                localVerificationData: val,
                serverVerificationData: val,
                source: "app_store",
              ),
            );
            await _handleSuccessfulPurchase(fakePurchase2);
          }
        } catch (_) {
          debugPrint(
              "DEBUG (Flutter): restorePurchases fallback timed out or failed.");
        } finally {
          _restoreCompleter = null;
          _cancelPurchaseWatchdog();
        }
      }
    } catch (e) {
      _purchaseError = "Failed to restore purchases. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSubscriptionStatus({
    required String platform,
    required String productId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final uid = user.uid;

      // Save subscription info in Firestore
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "subscription": {
          "platform": platform,
          "productId": productId,
          "updatedAt": FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Update local state
      _isPro = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint("saveSubscriptionStatus error: $e\n$st");
      rethrow;
    }
  }

  Future<void> manageIAPPurchase() async {
    try {
      if (_isIOSPlatform) {
        const url = 'https://apps.apple.com/account/subscriptions';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          debugPrint("Could not launch iOS subscriptions URL.");
        }
      } else if (_isAndroidPlatform) {
        const url = 'https://play.google.com/store/account/subscriptions';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          debugPrint("Could not launch Android subscriptions URL.");
        }
      } else {
        final user = _auth.currentUser;
        if (user == null) return;

        final docRef = FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("portal_links")
            .doc();

        await docRef.set({
          "return_url": "https://yourapp.com/account",
          "createdAt": FieldValue.serverTimestamp(),
        });

        final snap = await docRef.get();
        final url = snap.data()?['url'];

        if (url != null) {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          } else {
            debugPrint("Could not launch Stripe portal URL.");
          }
        } else {
          debugPrint("Stripe portal URL not available yet.");
        }
      }
    } catch (e, st) {
      debugPrint("manageIAPPurchase error: $e\n$st");
    }
  }

  Future<void> manageStripeSubscription(
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (_user == null) {
      _purchaseError = "Not signed in.";
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final userId = _user!.uid;
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('portal_links')
          .doc();

      final String returnUrl = kIsWeb
          ? Uri.base.toString()
          : 'https://your-studentsuite-account-return.example/';

      await docRef.set({
        'return_url': returnUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final Completer<String?> completer = Completer();
      late StreamSubscription sub;
      sub = docRef.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        if (data['url'] != null && !completer.isCompleted) {
          completer.complete(data['url'] as String);
        } else if (data['error'] != null && !completer.isCompleted) {
          completer.completeError(
              Exception(data['error']['message'] ?? 'Portal error'));
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      String? url;
      try {
        url = await completer.future.timeout(timeout, onTimeout: () {
          return null;
        });
      } finally {
        try {
          await sub.cancel();
        } catch (_) {}
      }

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('DEBUG (Flutter): Cannot open Stripe portal url.');
          _purchaseError = "Unable to open subscription portal.";
          notifyListeners();
        }
      } else {
        debugPrint('DEBUG (Flutter): No portal url available (timed out).');
        _purchaseError =
            "Subscription portal not available yet. Try again shortly.";
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('DEBUG (Flutter): manageStripeSubscription error: $e\n$st');
      _purchaseError = "Failed to open subscription portal.";
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelSubscription() async {
    if (_user == null || _stripeSubscriptionId == null) {
      debugPrint('DEBUG (Flutter): Cannot cancel, no Stripe subscription.');
      _isLoading = false;
      notifyListeners();
      return;
    }
    final userId = _user!.uid;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final uri =
          Uri.parse('https://play.google.com/store/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('stripe_commands')
          .doc();
      await docRef.set({
        'command': 'cancel_subscription',
        'timestamp': FieldValue.serverTimestamp()
      });
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> launchCheckoutSession(String priceId,
      {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final userId = user.uid;
      String? couponId;
      // If user was referred, apply the referral bonus coupon
      if (_hasReferral) {
        couponId = _kStripeReferralCouponId;
        debugPrint(
            'DEBUG (Flutter): User has referral, applying coupon: $couponId');
      }
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('checkout_sessions')
          .doc();

      await docRef.set({
        'price': priceId,
        'couponId': couponId, // <--- Add this line
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userId,
      });
      debugPrint(
          'DEBUG (Flutter): Created checkout_sessions document at ${docRef.path} for user $userId price $priceId');

      final completer = Completer<String?>();
      late StreamSubscription sub;
      sub = docRef.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        // Save the doc path for diagnostics
        _lastCheckoutDocPath = docRef.path;
        if (data['url'] != null && !completer.isCompleted) {
          completer.complete(data['url'] as String);
        } else if (data['error'] != null && !completer.isCompleted) {
          // Capture server-side error for diagnostics/UI
          try {
            _lastCheckoutServerError = data['error'] is Map
                ? (data['error']['message']?.toString() ??
                    data['error'].toString())
                : data['error'].toString();
          } catch (_) {
            _lastCheckoutServerError = data['error'].toString();
          }
          completer.completeError(Exception(_lastCheckoutServerError));
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      String? url;
      try {
        url = await completer.future.timeout(timeout, onTimeout: () => null);
      } finally {
        await sub.cancel();
      }

      if (url == null) {
        throw Exception("Checkout session not available yet.");
      }

      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch checkout URL");
      }
    } catch (e, st) {
      final errStr = e.toString();
      // Friendly message for common server-side misconfiguration
      if (errStr.contains('Stripe secret') ||
          errStr.toLowerCase().contains('server configuration') ||
          errStr.toLowerCase().contains('stripe')) {
        _purchaseError =
            'Payment system temporarily unavailable. Please try again later or contact support.';
      } else {
        _purchaseError = 'Stripe checkout failed: $e';
      }
      debugPrint('Stripe checkout error: $e\n$st');

      // If this looks like a server-side missing secret and we're in debug,
      // allow a developer-only fallback to open a simulated checkout page so
      // the client redirect/navigation code can be exercised locally.
      if (kDebugMode &&
          errStr.toLowerCase().contains('stripe') &&
          errStr.toLowerCase().contains('secret')) {
        try {
          debugPrint(
              'DEBUG (Flutter): Launching dev-only simulated checkout page.');
          final html = Uri.dataFromString(
            '<html><body style="font-family: sans-serif; text-align:center; padding:40px;">'
            '<h2>Simulated Stripe Checkout</h2>'
            '<p>This is a developer-only simulation because the server Stripe secret appears missing.</p>'
            '<a href="https://example.com/checkout-success" id="success">Simulate Success</a>'
            '</body></html>',
            mimeType: 'text/html',
          ).toString();

          await launchUrl(Uri.parse(html),
              mode: LaunchMode.externalApplication);
          _purchaseError = 'Opened simulated checkout for local testing.';
        } catch (e2) {
          debugPrint(
              'DEBUG (Flutter): Failed to launch simulated checkout: $e2');
          _purchaseError =
              'Payment system temporarily unavailable. Please try again later or contact support.';
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Ensure any loading UI is cleared
      _isLoading = false;
      notifyListeners();
      // Do not rethrow; callers should read purchaseError and react accordingly.
      return;
    }
  }

  Future<void> cancelStreams() async {
    debugPrint('DEBUG (Flutter): Cancelling all subscription streams.');
    _cancelPurchaseWatchdog();
    try {
      await _purchaseUpdatedSubscription?.cancel();
    } catch (_) {
      debugPrint(
          'DEBUG (Flutter): Error cancelling purchase stream (already closed).');
    }
    try {
      await _userSubscriptionStatusSubscription?.cancel();
    } catch (_) {
      debugPrint(
          'DEBUG (Flutter): Error cancelling user subscription stream (already closed).');
    }
    _userSubscriptionStatusSubscription = null;
    _purchaseUpdatedSubscription = null;
  }

  /// True if the current subscription is an auto-renewing IAP (iOS/Android)
  /// that requires manual cancellation in the App Store settings.
  bool get isIAPSubscription {
    // 1. If they aren't Pro, there is nothing to cancel.
    if (!_isPro) return false;

    // 2. If it's Stripe, it is handled by the Web Portal logic.
    if (isStripeSubscription) return false;

    // 3. If it's the "Mobile Grant" (Trial), it auto-expires.
    //    We do NOT want to warn them to cancel, because they can't.
    if (_currentProductId == 'referral_bonus') return false;

    // 4. If we are here, they are Pro, Not Stripe, and Not a Grant.
    //    Therefore, they must be on a paid App Store subscription.
    return true;
  }

  @override
  void dispose() {
    debugPrint(
        'DEBUG (Flutter): SubscriptionProvider disposed, cleaning up streams.');
    cancelStreams();
    _cancelPurchaseWatchdog();
    super.dispose();
  }

  Future<void> resetProStatus() async {
    debugPrint(
        "DEBUG (Flutter): Resetting Pro status and clearing subscription state.");
    _isLoading = true;
    notifyListeners();

    _isPro = false;
    _purchaseError = null;
    _showRestoreButton = false;
    _stripeCustomerId = null;
    _stripeSubscriptionId = null;
    _nativeIAPProductsFetched = false;
    _products = [];
    _restoredReceipts.clear();
    _user = null;

    _cancelPurchaseWatchdog();
    if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
      try {
        _restoreCompleter!.complete(null);
      } catch (_) {}
      _restoreCompleter = null;
    }

    _isLoading = false;
    notifyListeners();
    debugPrint(
        "DEBUG (Flutter): Pro status and subscription state fully reset.");
  }

  Future<void> deleteAccountAndCancelSubscriptions() async {
    debugPrint('DEBUG (Flutter): Deleting account + cancel subscriptions.');

    if (_isPro) {
      if (_stripeSubscriptionId != null) {
        final userId = _user!.uid;
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('stripe_commands')
            .doc();
        await docRef.set({
          'command': 'cancel_subscription',
          'timestamp': FieldValue.serverTimestamp()
        });
        debugPrint('DEBUG (Flutter): Queued Stripe cancellation for $userId');
        // --- ADD THIS WAIT ---
        // Wait 4 seconds for backend to execute cancellation before we delete data
        await Future.delayed(const Duration(seconds: 4));
        // ---------------------
      } else {
        debugPrint('DEBUG (Flutter): Awaiting IAP transaction completion.');
      }
    }

    await cancelStreams();
    await resetProStatus();

    debugPrint(
        'DEBUG (Flutter): Account cleanup complete, subscription state reset.');
  }
}
