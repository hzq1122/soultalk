import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/moment.dart';
import '../services/moments/moments_service.dart';

final momentsServiceProvider = Provider<MomentsService>((ref) {
  final service = MomentsService();
  service.init();
  return service;
});

class MomentsNotifier extends AsyncNotifier<List<Moment>> {
  @override
  Future<List<Moment>> build() async {
    return ref.read(momentsServiceProvider).getAllMoments(limit: 50);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(momentsServiceProvider).getAllMoments(limit: 50),
    );
  }

  Future<void> toggleLike(String momentId) async {
    await ref.read(momentsServiceProvider).toggleLike(momentId, 'user');
    await refresh();
  }

  Future<void> addComment(String momentId, MomentComment comment) async {
    await ref.read(momentsServiceProvider).addComment(momentId, comment);
    await refresh();
  }

  Future<void> generateMoments() async {
    await ref.read(momentsServiceProvider).generateMomentsForAllContacts();
    await refresh();
  }
}

final momentsProvider = AsyncNotifierProvider<MomentsNotifier, List<Moment>>(
  MomentsNotifier.new,
);
