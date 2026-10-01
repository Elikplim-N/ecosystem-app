import 'package:flutter/material.dart';
import '../screens/design_system.dart';

/// The three account types in the system.
///
/// Roles are stored on `users/{uid}.role`:
///  * [user]       - default, created at signup / by admin registration
///  * [ambassador] - approved from an application; sees ambassador tools
///  * [admin]      - super admin; full control
enum AppRole {
  user,
  ambassador,
  admin;

  static AppRole fromString(Object? raw) {
    switch (raw) {
      case 'admin':
      case 'superadmin':
      case 'super_admin':
        return AppRole.admin;
      case 'ambassador':
        return AppRole.ambassador;
      default:
        return AppRole.user;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case AppRole.user:
        return 'Member';
      case AppRole.ambassador:
        return 'Ambassador';
      case AppRole.admin:
        return 'Admin';
    }
  }

  IconData get icon {
    switch (this) {
      case AppRole.user:
        return Icons.person_rounded;
      case AppRole.ambassador:
        return Icons.volunteer_activism_rounded;
      case AppRole.admin:
        return Icons.shield_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AppRole.user:
        return kColouredBottle;
      case AppRole.ambassador:
        return kAccentOrange;
      case AppRole.admin:
        return kPrimaryColor;
    }
  }

  Color get tint {
    switch (this) {
      case AppRole.user:
        return kPastelBlue;
      case AppRole.ambassador:
        return const Color(0xFFFBEFD9);
      case AppRole.admin:
        return kPastelMint;
    }
  }

  /// Deeper shade of [color] for solid fills, so white text on top of it
  /// stays legible (the orange accent is far too light on its own).
  Color get solidColor {
    switch (this) {
      case AppRole.user:
        return const Color(0xFF2F63C8);
      case AppRole.ambassador:
        return const Color(0xFF9A5B04);
      case AppRole.admin:
        return kPrimaryColor;
    }
  }

  bool get isAdmin => this == AppRole.admin;

  bool get isAmbassador => this == AppRole.ambassador;

  bool get isAmbassadorOrAdmin =>
      this == AppRole.ambassador || this == AppRole.admin;
}

/// Where a user's ambassador application currently sits.
enum AmbassadorStatus {
  none,
  pending,
  approved,
  rejected;

  static AmbassadorStatus fromString(Object? raw) {
    switch (raw) {
      case 'pending':
        return AmbassadorStatus.pending;
      case 'approved':
        return AmbassadorStatus.approved;
      case 'rejected':
        return AmbassadorStatus.rejected;
      default:
        return AmbassadorStatus.none;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case AmbassadorStatus.none:
        return 'Not applied';
      case AmbassadorStatus.pending:
        return 'Under review';
      case AmbassadorStatus.approved:
        return 'Ambassador';
      case AmbassadorStatus.rejected:
        return 'Not approved';
    }
  }

  Color get color {
    switch (this) {
      case AmbassadorStatus.none:
        return kTextMuted;
      case AmbassadorStatus.pending:
        return kAccentOrange;
      case AmbassadorStatus.approved:
        return kPrimaryColor;
      case AmbassadorStatus.rejected:
        return const Color(0xFFC0392B);
    }
  }

  IconData get icon {
    switch (this) {
      case AmbassadorStatus.none:
        return Icons.remove_circle_outline_rounded;
      case AmbassadorStatus.pending:
        return Icons.hourglass_top_rounded;
      case AmbassadorStatus.approved:
        return Icons.verified_rounded;
      case AmbassadorStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  bool get canApply =>
      this == AmbassadorStatus.none || this == AmbassadorStatus.rejected;
}
