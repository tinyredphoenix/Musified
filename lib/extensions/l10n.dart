import 'package:flutter/widgets.dart';
import 'package:musified/localization/app_localizations.dart';
import 'package:musified/localization/app_localizations_en.dart';

extension ContextX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}
