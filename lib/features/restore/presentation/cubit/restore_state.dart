import 'package:equatable/equatable.dart';

import '../../../auth/session/domain/entities/auth_user.dart';
import '../../domain/entities/restore_entities.dart';

enum RestorePhase {
  initial,
  loading,
  signedOut,
  emailNotVerified,
  accountMismatch,
  offline,
  missingBackup,
  interruptedRecovery,
  previewReady,
  confirmingPrimary,
  confirmingReplacement,
  executing,
  completed,
  error,
}

enum RestoreRefreshReason { cloudVersionOrDeviceChanged, localLedgerChanged }

/// Immutable presentation state for the Cloud Restore and Device Transfer flow.
final class RestoreViewState extends Equatable {
  const RestoreViewState({
    this.phase = RestorePhase.initial,
    this.account,
    this.localLedger,
    this.cloudPreview,
    this.pendingTransfer,
    this.primaryConfirmed = false,
    this.replacementConfirmed = false,
    this.authorityTransferred = false,
    this.refreshReason,
    this.isPreview = false,
  });

  /// Default preview state when [RestoreCubit] is not mounted (e.g., isolated
  /// widget tests), reflecting [user] when signed in without fabricating any
  /// sample merchant or backup confirmation timestamp.
  factory RestoreViewState.preview({AuthUser? user}) {
    if (user == null) {
      return const RestoreViewState(
        phase: RestorePhase.signedOut,
        isPreview: true,
      );
    }
    if (!user.emailVerified) {
      return RestoreViewState(
        phase: RestorePhase.emailNotVerified,
        account: RestoreAccountInfo(
          userId: user.id,
          email: user.email,
          shopName: user.shopName,
          isEmailVerified: false,
        ),
        isPreview: true,
      );
    }
    return RestoreViewState(
      phase: RestorePhase.missingBackup,
      account: RestoreAccountInfo(
        userId: user.id,
        email: user.email,
        shopName: user.shopName,
        isEmailVerified: true,
      ),
      localLedger: const RestoreLocalLedgerSummary(deviceId: 'preview-device'),
      isPreview: true,
    );
  }

  final RestorePhase phase;
  final RestoreAccountInfo? account;
  final RestoreLocalLedgerSummary? localLedger;
  final CloudBackupSnapshotPreview? cloudPreview;
  final PendingRestoreTransfer? pendingTransfer;
  final bool primaryConfirmed;
  final bool replacementConfirmed;
  final bool authorityTransferred;
  final RestoreRefreshReason? refreshReason;
  final bool isPreview;

  String? get accountEmail => account?.email;

  String? get accountShopName => account?.shopName;

  bool get isBusy =>
      phase == RestorePhase.loading || phase == RestorePhase.executing;

  bool get requiresTakeover {
    if (pendingTransfer case final inFlight?) {
      return inFlight.requiresTakeover;
    }
    final local = localLedger;
    final cloud = cloudPreview;
    if (local == null || cloud == null) return false;
    return local.deviceId != cloud.activeDeviceId;
  }

  bool get requiresReplacement {
    if (pendingTransfer case final inFlight?) {
      return inFlight.requiresReplacement;
    }
    return localLedger?.isPopulated ?? false;
  }

  RestoreConsentToken? buildConsentToken() {
    final currentAccount = account;
    final currentLocal = localLedger;
    final currentCloud = cloudPreview;
    if (currentAccount == null ||
        currentLocal == null ||
        currentCloud == null) {
      return null;
    }
    return RestoreConsentToken(
      version: currentCloud.version,
      activeDeviceId: currentCloud.activeDeviceId,
      confirmedAt: currentCloud.confirmedAt,
      ownerUserId: currentAccount.userId,
      localDeviceId: currentLocal.deviceId,
      localRevisionStamp: currentLocal.revisionStamp,
      requiresTakeover: requiresTakeover,
      requiresReplacement: requiresReplacement,
      primaryConfirmed: primaryConfirmed,
      replacementConfirmed: replacementConfirmed,
    );
  }

  RestoreViewState copyWith({
    RestorePhase? phase,
    RestoreAccountInfo? Function()? account,
    RestoreLocalLedgerSummary? Function()? localLedger,
    CloudBackupSnapshotPreview? Function()? cloudPreview,
    PendingRestoreTransfer? Function()? pendingTransfer,
    bool? primaryConfirmed,
    bool? replacementConfirmed,
    bool? authorityTransferred,
    RestoreRefreshReason? Function()? refreshReason,
    bool? isPreview,
  }) => RestoreViewState(
    phase: phase ?? this.phase,
    account: account != null ? account() : this.account,
    localLedger: localLedger != null ? localLedger() : this.localLedger,
    cloudPreview: cloudPreview != null ? cloudPreview() : this.cloudPreview,
    pendingTransfer: pendingTransfer != null
        ? pendingTransfer()
        : this.pendingTransfer,
    primaryConfirmed: primaryConfirmed ?? this.primaryConfirmed,
    replacementConfirmed: replacementConfirmed ?? this.replacementConfirmed,
    authorityTransferred: authorityTransferred ?? this.authorityTransferred,
    refreshReason: refreshReason != null ? refreshReason() : this.refreshReason,
    isPreview: isPreview ?? this.isPreview,
  );

  @override
  List<Object?> get props => [
    phase,
    account,
    localLedger,
    cloudPreview,
    pendingTransfer,
    primaryConfirmed,
    replacementConfirmed,
    authorityTransferred,
    refreshReason,
    isPreview,
  ];
}
