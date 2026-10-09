import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/logging/log.dart';
import 'entitlement.dart';
import 'entitlement_controller.dart';
import 'purchase_gateway.dart';

final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => throw UnimplementedError('overridden in bootstrap'),
);

/// How long to wait after a refresh for the store's answers to arrive on the purchase stream
/// (they are sent just before the call returns). Tests set it to zero.
final purchaseSettleDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 300));

/// Whether this build talks to the App Store (true) or Google Play.
final isIOSStoreProvider = Provider<bool>((ref) => defaultTargetPlatform == TargetPlatform.iOS);

enum StoreStatus { loading, ready, unavailable }

/// Feedback for the Premium page and paywall (S-51 states).
enum PurchaseFeedback { none, success, restored, nothingToRestore, pending, error }

@immutable
class PurchaseState {
  const PurchaseState({
    this.status = StoreStatus.loading,
    this.products = const [],
    this.trialEligible = false,
    this.busy = false,
    this.feedback = PurchaseFeedback.none,
    this.errorMessage,
  });

  final StoreStatus status;

  /// What is for sale, in display order.
  final List<StoreProduct> products;
  final bool trialEligible;

  /// A purchase or restore is under way: buttons wait and no app-open advert may show.
  final bool busy;
  final PurchaseFeedback feedback;
  final String? errorMessage;

  StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  PurchaseState copyWith({
    StoreStatus? status,
    List<StoreProduct>? products,
    bool? trialEligible,
    bool? busy,
    PurchaseFeedback? feedback,
    String? errorMessage,
  }) => PurchaseState(
    status: status ?? this.status,
    products: products ?? this.products,
    trialEligible: trialEligible ?? this.trialEligible,
    busy: busy ?? this.busy,
    feedback: feedback ?? this.feedback,
    errorMessage: feedback == null ? this.errorMessage : errorMessage,
  );
}

/// Buys, restores and keeps Premium in step with the store (FLUTTER_ARCHITECTURE §11,
/// "Purchase"). On every start it asks the store, silently, what the user owns; the answer
/// replaces the cached one, and the legacy lifetime flag is never touched (MIGRATION_PLAN §5.3).
class PurchaseService extends Notifier<PurchaseState> {
  StreamSubscription<List<PurchaseEvent>>? _sub;
  final _owned = <String, DateTime?>{};
  bool _refreshing = false;
  bool _restoreRequested = false;
  int _restoredThisRound = 0;

  PurchaseGateway get _gateway => ref.read(purchaseGatewayProvider);
  bool get _isIOS => ref.read(isIOSStoreProvider);

  @override
  PurchaseState build() {
    final gateway = ref.watch(purchaseGatewayProvider);
    _sub = gateway.events.listen(_onEvents, onError: _onStreamError);
    ref.onDispose(() => _sub?.cancel());
    unawaited(Future<void>.microtask(_start));
    return const PurchaseState();
  }

  Future<void> _start() async {
    final available = await _safe(_gateway.isAvailable, false);
    if (!available) {
      state = state.copyWith(status: StoreStatus.unavailable);
      return;
    }
    await Future.wait([loadProducts(), refresh()]);
  }

  Future<T> _safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } on Object catch (error) {
      Log.w('Store call failed: ${error.runtimeType}');
      return fallback;
    }
  }

  Future<void> loadProducts() async {
    final ids = ProductIds.forSale(isIOS: _isIOS);
    final found = await _safe(() => _gateway.products(ProductIds.queried(isIOS: _isIOS)), null);
    if (found == null || found.isEmpty) {
      state = state.copyWith(status: StoreStatus.unavailable);
      return;
    }
    final ordered = [for (final id in ids) ...found.where((p) => p.id == id)];
    final trial = _isIOS && await _safe(() => _gateway.isTrialEligible(ProductIds.annual), false);
    state = state.copyWith(
      status: ordered.isEmpty ? StoreStatus.unavailable : StoreStatus.ready,
      products: ordered,
      trialEligible: trial,
    );
  }

  /// The launch check (and the end of a restore): what the store says the user owns now. If the
  /// store can't be reached, the cached answer stands.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _owned.clear();
    _restoredThisRound = 0;
    try {
      await _gateway.refreshOwned();
      // Restored purchases arrive on the stream just before the call returns.
      await Future<void>.delayed(ref.read(purchaseSettleDelayProvider));
      await _apply();
    } on Object catch (error) {
      Log.w('Could not refresh purchases: ${error.runtimeType}');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> buy(StoreProduct product) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, feedback: PurchaseFeedback.none);
    try {
      await _gateway.buy(product);
    } on Object catch (error) {
      Log.w('Purchase could not start: ${error.runtimeType}');
      state = state.copyWith(
        busy: false,
        feedback: PurchaseFeedback.error,
        errorMessage: "The purchase couldn't start. Try again.",
      );
    }
  }

  /// "Restore purchases" (F-079).
  Future<void> restore() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, feedback: PurchaseFeedback.none);
    _restoreRequested = true;
    _refreshing = true;
    _owned.clear();
    _restoredThisRound = 0;
    try {
      await _gateway.restore();
      await Future<void>.delayed(ref.read(purchaseSettleDelayProvider));
      await _apply();
      final premium = ref.read(isPremiumProvider);
      state = state.copyWith(
        busy: false,
        feedback: _restoredThisRound > 0 || premium
            ? PurchaseFeedback.restored
            : PurchaseFeedback.nothingToRestore,
      );
    } on Object catch (error) {
      Log.w('Restore failed: ${error.runtimeType}');
      state = state.copyWith(
        busy: false,
        feedback: PurchaseFeedback.error,
        errorMessage: "Couldn't reach the store. Try again.",
      );
    } finally {
      _refreshing = false;
      _restoreRequested = false;
    }
  }

  void clearFeedback() => state = state.copyWith(feedback: PurchaseFeedback.none);

  Future<void> _onEvents(List<PurchaseEvent> events) async {
    var bought = false;
    for (final e in events) {
      switch (e.kind) {
        case PurchaseEventKind.pending:
          ref.read(entitlementProvider.notifier).setPending(true);
          state = state.copyWith(busy: false, feedback: PurchaseFeedback.pending);
        case PurchaseEventKind.purchased || PurchaseEventKind.restored:
          if (_recognised(e.productId)) {
            _owned[e.productId] = e.expiresAt;
            if (e.kind == PurchaseEventKind.restored) _restoredThisRound++;
            if (e.kind == PurchaseEventKind.purchased) bought = true;
          }
          if (e.needsCompletion) {
            try {
              await _gateway.complete(e);
            } on Object catch (error) {
              Log.w('Could not complete a purchase: ${error.runtimeType}');
            }
          }
        case PurchaseEventKind.canceled:
          state = state.copyWith(busy: false, feedback: PurchaseFeedback.none);
          if (e.needsCompletion) await _gateway.complete(e);
        case PurchaseEventKind.error:
          state = state.copyWith(
            busy: false,
            feedback: PurchaseFeedback.error,
            errorMessage: e.message ?? 'The purchase did not go through.',
          );
          if (e.needsCompletion) await _gateway.complete(e);
      }
    }
    // A purchase made now adds to what is known; a refresh in progress applies at its end.
    if (bought) {
      await _apply(merge: true);
      ref.read(entitlementProvider.notifier).setPending(false);
      state = state.copyWith(busy: false, feedback: PurchaseFeedback.success);
    } else if (!_refreshing && !_restoreRequested) {
      await _apply(merge: true);
    }
  }

  void _onStreamError(Object error) {
    Log.w('Purchase stream error: ${error.runtimeType}');
    state = state.copyWith(busy: false);
  }

  bool _recognised(String id) => id == ProductIds.annual || ProductIds.lifetime.contains(id);

  /// Turns what the store reported into the entitlement. With [merge], products already known
  /// from the cache stay (a single purchase event does not list everything the user owns).
  Future<void> _apply({bool merge = false}) async {
    final controller = ref.read(entitlementProvider.notifier);
    final now = ref.read(clockProvider)();
    final current = ref.read(entitlementProvider);
    final lifetime = _owned.keys.any(ProductIds.lifetime.contains);
    final annualOwned = _owned.containsKey(ProductIds.annual);
    final expires = _owned[ProductIds.annual];
    final annualActive = annualOwned && (expires == null || expires.isAfter(now));
    final knewLifetime =
        current.kind == PremiumKind.lifetime && current.lifetimeSource == LifetimeSource.store;
    final knewAnnual = current.kind == PremiumKind.annual;
    await controller.applyStore(
      storeLifetime: lifetime || (merge && knewLifetime),
      subscriptionActive: annualActive || (merge && !annualOwned && knewAnnual),
      renewsAt: annualActive ? expires : (merge && knewAnnual ? current.renewsAt : null),
      pending: current.pending,
    );
  }
}

final purchaseServiceProvider = NotifierProvider<PurchaseService, PurchaseState>(
  PurchaseService.new,
);
