import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:twelve_step_guide/features/ads/ad_gateway.dart';
import 'package:twelve_step_guide/features/audio/data/audio_engine.dart';
import 'package:twelve_step_guide/features/audio/data/download_gateway.dart';
import 'package:twelve_step_guide/features/audio/domain/catalogue.dart';
import 'package:twelve_step_guide/features/premium/purchase_gateway.dart';

/// An audio engine that plays nothing and records what it was asked to do.
class FakeAudioEngine implements AudioEngine {
  final _snapshot = ValueNotifier<PlayerSnapshot>(PlayerSnapshot.empty);
  final calls = <String>[];

  @override
  ValueListenable<PlayerSnapshot> get snapshot => _snapshot;

  PlayerSnapshot get value => _snapshot.value;

  /// Pushes a state, as the real engine does when playback changes.
  void emit(PlayerSnapshot s) => _snapshot.value = s;

  void _at(int index, {Duration position = Duration.zero}) {
    final q = value.queue;
    emit(
      value.copyWith(
        index: index,
        position: position,
        duration: q[index].track.duration,
        status: EngineStatus.ready,
      ),
    );
  }

  @override
  Future<void> playQueue(List<QueueItem> queue, int index, {Duration start = Duration.zero}) async {
    calls.add('playQueue ${queue[index].track.id} at ${start.inSeconds}s of ${queue.length}');
    emit(
      PlayerSnapshot(
        queue: queue,
        index: index,
        playing: true,
        status: EngineStatus.ready,
        position: start,
        duration: queue[index].track.duration,
      ),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(value.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(PlayerSnapshot.empty);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek ${position.inSeconds}');
    emit(value.copyWith(position: position));
  }

  @override
  Future<void> seekBy(Duration delta) async {
    calls.add('seekBy ${delta.inSeconds}');
    final d = value.duration ?? Duration.zero;
    var p = value.position + delta;
    if (p < Duration.zero) p = Duration.zero;
    if (p > d) p = d;
    emit(value.copyWith(position: p));
  }

  @override
  Future<void> skipToNext() async {
    calls.add('next');
    _at((value.index! + 1) % value.queue.length);
  }

  @override
  Future<void> skipToPrevious() async {
    calls.add('previous');
    _at(value.index == 0 ? value.queue.length - 1 : value.index! - 1);
  }

  @override
  Future<void> skipToIndex(int index) async {
    calls.add('skipTo $index');
    _at(index);
  }

  @override
  Future<void> retry() async {
    calls.add('retry');
    emit(value.copyWith(status: EngineStatus.ready, playing: true, clearError: true));
  }
}

/// A downloader that queues nothing; tests push its events.
class FakeDownloadGateway implements DownloadGateway {
  final _events = StreamController<DownloadEvent>.broadcast(sync: true);
  final enqueued = <int>[];
  final cancelled = <int>[];
  final urls = <Uri>[];
  final wifiOnly = <bool>[];
  bool accept = true;
  Set<int> running = {};

  void emit(DownloadEvent e) => _events.add(e);

  @override
  Stream<DownloadEvent> get events => _events.stream;

  @override
  Future<void> start() async {}

  @override
  Future<bool> enqueue(Track track, Uri url, {required bool wifiOnly}) async {
    enqueued.add(track.id);
    urls.add(url);
    this.wifiOnly.add(wifiOnly);
    return accept;
  }

  @override
  Future<void> cancel(int trackId) async => cancelled.add(trackId);

  @override
  Future<Set<int>> active() async => running;
}

/// A store that sells the Android tiers (or the iOS annual) and records purchases.
class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({this.available = true, List<StoreProduct>? products, this.owned = const []})
    : catalogue =
          products ??
          const [
            StoreProduct(id: 'donatetier1', title: 'Tier 1', price: '£1.99', rawPrice: 1.99),
            StoreProduct(id: 'donatetier2', title: 'Tier 2', price: '£4.99', rawPrice: 4.99),
            StoreProduct(id: 'donatetier3', title: 'Tier 3', price: '£9.99', rawPrice: 9.99),
            StoreProduct(id: 'annual', title: 'Annual', price: '£16.99', rawPrice: 16.99),
          ];

  bool available;
  final List<StoreProduct> catalogue;

  /// What the store says the user owns (sent as `restored` on refresh).
  List<PurchaseEvent> owned;
  bool trialEligible = true;
  bool failRefresh = false;
  final bought = <String>[];
  final completed = <String>[];
  int restores = 0;
  final _events = StreamController<List<PurchaseEvent>>.broadcast(sync: true);

  void emit(List<PurchaseEvent> events) => _events.add(events);

  @override
  Stream<List<PurchaseEvent>> get events => _events.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final p in catalogue)
      if (ids.contains(p.id)) p,
  ];

  @override
  Future<void> buy(StoreProduct product) async => bought.add(product.id);

  @override
  Future<void> refreshOwned() async {
    if (failRefresh) throw StateError('store unreachable');
    if (owned.isNotEmpty) emit(owned);
  }

  @override
  Future<void> restore() async {
    restores++;
    await refreshOwned();
  }

  @override
  Future<void> complete(PurchaseEvent event) async => completed.add(event.productId);

  @override
  Future<bool> isTrialEligible(String productId) async => trialEligible;
}

/// Adverts that are always "loaded" and record what was shown.
class FakeAdGateway implements AdGateway {
  final shown = <String>[];
  bool interstitialLoaded = true;
  DateTime? appOpenLoaded;
  bool started = false;

  @override
  Future<void> start() async => started = true;
  @override
  bool get interstitialReady => interstitialLoaded;
  @override
  Future<bool> showInterstitial() async {
    shown.add('interstitial');
    return true;
  }

  @override
  DateTime? get appOpenLoadedAt => appOpenLoaded;
  @override
  Future<bool> showAppOpen() async {
    shown.add('appOpen');
    return true;
  }

  @override
  void dropStaleAppOpen(Duration maxAge) {}
}
