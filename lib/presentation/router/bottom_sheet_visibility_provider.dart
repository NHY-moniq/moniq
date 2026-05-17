import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Tracks how many Moniq modal bottom sheets are currently open.
///
/// The app shell watches [bottomSheetOpenProvider] to decide whether the
/// floating bottom dock (홈/캘린더/팀/설정) should be shown. While a sheet
/// is open the dock slides out so it does not bleed through the sheet's
/// semi-transparent barrier.
///
/// A counter (rather than a plain bool) keeps the behaviour correct when
/// sheets are stacked — the dock reappears only after the last one closes.
class BottomSheetVisibilityNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Called by the [showMoniqBottomSheet] helper right before a sheet opens.
  void increment() => state = state + 1;

  /// Called by the helper after a sheet has been dismissed.
  void decrement() => state = state > 0 ? state - 1 : 0;
}

/// Open-sheet counter. `0` means no Moniq sheet is currently visible.
final bottomSheetCountProvider =
    NotifierProvider<BottomSheetVisibilityNotifier, int>(
  BottomSheetVisibilityNotifier.new,
);

/// `true` when at least one Moniq modal bottom sheet is open.
final bottomSheetOpenProvider = Provider<bool>(
  (ref) => ref.watch(bottomSheetCountProvider) > 0,
);
