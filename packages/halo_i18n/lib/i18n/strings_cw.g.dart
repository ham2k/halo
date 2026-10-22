///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsCw extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsCw({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.cw,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <cw>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsCw _root = this; // ignore: unused_field

	@override 
	TranslationsCw $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsCw(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$cw common = _Translations$common$cw._(_root);
	@override late final _Translations$onboarding$cw onboarding = _Translations$onboarding$cw._(_root);
	@override late final _Translations$startScreen$cw startScreen = _Translations$startScreen$cw._(_root);
	@override late final _Translations$testerOverlay$cw testerOverlay = _Translations$testerOverlay$cw._(_root);
	@override late final _Translations$extensionsPanel$cw extensionsPanel = _Translations$extensionsPanel$cw._(_root);
	@override late final _Translations$home$cw home = _Translations$home$cw._(_root);
	@override late final _Translations$chase$cw chase = _Translations$chase$cw._(_root);
	@override late final _Translations$dialogs$cw dialogs = _Translations$dialogs$cw._(_root);
	@override late final _Translations$operation$cw operation = _Translations$operation$cw._(_root);
	@override late final _Translations$map$cw map = _Translations$map$cw._(_root);
	@override late final _Translations$mapsView$cw mapsView = _Translations$mapsView$cw._(_root);
	@override late final _Translations$activitiesView$cw activitiesView = _Translations$activitiesView$cw._(_root);
	@override late final _Translations$loggingControls$cw loggingControls = _Translations$loggingControls$cw._(_root);
	@override late final _Translations$formChrome$cw formChrome = _Translations$formChrome$cw._(_root);
	@override late final _Translations$qsoEditForm$cw qsoEditForm = _Translations$qsoEditForm$cw._(_root);
	@override late final _Translations$qsoList$cw qsoList = _Translations$qsoList$cw._(_root);
	@override late final _Translations$loggingPanel$cw loggingPanel = _Translations$loggingPanel$cw._(_root);
	@override late final _Translations$callInfo$cw callInfo = _Translations$callInfo$cw._(_root);
	@override late final _Translations$settings$cw settings = _Translations$settings$cw._(_root);
	@override late final _Translations$commands$cw commands = _Translations$commands$cw._(_root);
	@override late final _Translations$commandDialog$cw commandDialog = _Translations$commandDialog$cw._(_root);
	@override late final _Translations$keyboardShortcuts$cw keyboardShortcuts = _Translations$keyboardShortcuts$cw._(_root);
	@override late final _Translations$expiredBuild$cw expiredBuild = _Translations$expiredBuild$cw._(_root);
	@override late final _Translations$staleness$cw staleness = _Translations$staleness$cw._(_root);
	@override late final _Translations$spotting$cw spotting = _Translations$spotting$cw._(_root);
	@override late final _Translations$dataFiles$cw dataFiles = _Translations$dataFiles$cw._(_root);
	@override late final _Translations$updates$cw updates = _Translations$updates$cw._(_root);
	@override late final _Translations$extensionService$cw extensionService = _Translations$extensionService$cw._(_root);
	@override late final _Translations$operationLocationScreen$cw operationLocationScreen = _Translations$operationLocationScreen$cw._(_root);
	@override late final _Translations$versionLabel$cw versionLabel = _Translations$versionLabel$cw._(_root);
	@override late final _Translations$notices$cw notices = _Translations$notices$cw._(_root);
	@override late final _Translations$syncAccount$cw syncAccount = _Translations$syncAccount$cw._(_root);
	@override late final _Translations$deepLink$cw deepLink = _Translations$deepLink$cw._(_root);
	@override late final _Translations$confirmDevice$cw confirmDevice = _Translations$confirmDevice$cw._(_root);
	@override late final _Translations$switchAccounts$cw switchAccounts = _Translations$switchAccounts$cw._(_root);
	@override late final _Translations$qsonImport$cw qsonImport = _Translations$qsonImport$cw._(_root);
	@override late final _Translations$adifImport$cw adifImport = _Translations$adifImport$cw._(_root);
	@override late final _Translations$offline$cw offline = _Translations$offline$cw._(_root);
	@override late final _Translations$exportSettings$cw exportSettings = _Translations$exportSettings$cw._(_root);
	@override late final _Translations$templateEditor$cw templateEditor = _Translations$templateEditor$cw._(_root);
}

// Path: common
class _Translations$common$cw extends Translations$common$en {
	_Translations$common$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get save => '··· ·— ···— ·';
	@override String get ok => '——— —·—';
	@override String get cancel => '—·—· ·— —· —·—· · ·—··';
	@override String get delete => '—·· · ·—·· · — ·';
	@override String get create => '—·—· ·—· · ·— — ·';
	@override String get error => '· ·—· ·—· ——— ·—·';
	@override String get close => '—·—· ·—·· ——— ··· ·';
	@override String get done => '—·· ——— —· ·';
	@override String get callsign => '—·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get clear => '—·—· ·—·· · ·— ·—·';
	@override String get dismiss => '—·· ·· ··· —— ·· ··· ···';
	@override String get expand => '· —··— ·——· ·— —· —··';
	@override String get collapse => '—·—· ——— ·—·· ·—·· ·— ·——· ··· ·';
}

// Path: onboarding
class _Translations$onboarding$cw extends Translations$onboarding$en {
	_Translations$onboarding$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => '·—— · ·—·· —·—· ——— —— · / — ——— / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· —·—·——';
	@override String get welcomeTitleDesktop => '·—— · ·—·· —·—· ——— —— · / — ——— / ···· ·— —— ··——— —·— / ·——· ——— ·—— · ·—· / ·—·· ——— ——· ——· · ·—· —·—·——';
	@override String get welcomeBody => '·—— · / ···· ·— ···— · / ·— / ··—· · ·—— / ——·— ··— · ··· — ·· ——— —· ··· / — ——— / ···· · ·—·· ·——· / ··— ··· / —··· · — — · ·—· / ··· ··— ·· — / —·—— ——— ··— ·—· / —· · · —·· ··· ·—·—·—';
	@override String get skip => '··· —·— ·· ·——·';
	@override String get kContinue => '—·—· ——— —· — ·· —· ··— ·';
	@override String get back => '—··· ·— —·—· —·—';
	@override String get next => '—· · —··— —';
	@override String get done => '—·· ——— —· ·';
	@override String get callsignTitle => '·—— ···· ·— — ·————· ··· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··——··';
	@override String get callsignBody => '—·—— ——— ··— / —· · · —·· / ·— —· / ·— —— ·— — · ··— ·—· / ·—· ·— —·· ·· ——— / ——— ·——· · ·—· ·— — ——— ·—· / ·—·· ·· —·—· · —· ··· · / ·· —· / ——— ·—· —·· · ·—· / — ——— / ··—· ·· —· —·· / — ···· ·· ··· / ·— ·——· ·——· / ··— ··· · ··—· ··— ·—··';
	@override String get callsignLabel => '——— ·——· · ·—· ·— — ——— ·—· ·————· ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get alreadyHaveAccount => '·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ···— · / ·— —· / ·— —·—· —·—· ——— ··— —· — ··——··';
	@override String get foundSiblingTitle => '·—·· ·· —· —·— / ·— —· / · —··— ·· ··· — ·· —· ——· / ·— —·—· —·—· ——— ··— —· — ··——··';
	@override String foundSiblingBody({required Object app}) => '·—— · / ··—· ——— ··— —· —·· / ${app} / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / — ···· · / ··· ·— —— · / ·— —·—· —·—· ——— ··— —· — / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—';
	@override String get foundPoloBody => '·—— · / ··—· ——— ··— —· —·· / ·— —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / — ···· · / ··· ·— —— · / ·— —·—· —·—· ——— ··— —· — / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—';
	@override String get foundSiblingsBody => '·—— · / ··—· ——— ··— —· —·· / ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——· ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / ——— —· · / ——— ··—· / — ···· · ·· ·—· / ·— —·—· —·—· ——— ··— —· — ··· / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—';
	@override String linkWithApp({required Object app}) => '·—·· ·· —· —·— / ·—— ·· — ···· / ${app}';
	@override String get linkWithPolo => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — / ·· —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —·';
	@override String get setUpFresh => '··· · — / ··— ·——· / ··—· ·—· · ··· ····';
	@override String get activitiesTitle => '··—· ·— ···— ——— ·—· ·· — · / ·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get activitiesBody => '·— ·—· · / —·—— ——— ··— / ·· —· — · ·—· · ··· — · —·· / ·· —· / ·— —· —·—— / ——— ··—· / — ···· · ··· · / ·——· ——— ·——· ··— ·—·· ·— ·—· / ·— —·—· — ·· ···— ·— — ·· ——— —· / ·——· ·—· ——— ——· ·—· ·— —— ··· ··——··';
	@override String get activitiesFooter => '—·——· —·—— ——— ··— / —·—· ·— —· / ··—· ·· —· —·· / —— ——— ·—· · / ——— ·——· — ·· ——— —· ··· / ·· —· / — ···· · / ··· · — — ·· —· ——· ··· —·——·—';
	@override String get activityPota => '·——· ·— ·—· —·— ··· / ——— —· / — ···· · / ·— ·· ·—·';
	@override String get activitySota => '··· ··— —— —— ·· — ··· / ——— —· / — ···· · / ·— ·· ·—·';
	@override String get activityWwff => '·—— ——— ·—· ·—·· —·· / ·—— ·· —·· · / ··—· ·—·· ——— ·—· ·— / ·—··· / ··—· ·— ··— —· ·—';
	@override String get consentTitle => '—·· ·— — ·— / ·—··· / ·——· ·—· ·· ···— ·— —·—· —·——';
	@override String get consentUsageBody => '— ——— / ···· · ·—·· ·——· / ··— ··· / —— ·— —·— · / — ···· · / ·— ·——· ·——· / —··· · — — · ·—· ——··—— / ·—— · ·————· —·· / ·—·· ·· —·— · / — ——— / —·—· ——— ·—·· ·—·· · —·—· — / ·——· · ·—· ··—· ——— ·—· —— ·— —· —·—· · ——··—— / —·—· ·—· ·— ··· ···· ——··—— / ·— —· —·· / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·— ·—·—·—';
	@override String get consentUsageLabel => '··· ···· ·— ·—· · / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·—';
	@override String get consentOperationBody => '··· ——— —— · / ··—· · ·— — ··— ·—· · ··· / —— ·· ——· ···· — / ·· —· ···— ——— ·—·· ···— · / ··· ···· ·— ·—· ·· —· ——· / —·—— ——— ··— ·—· / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·—— ·· — ···· / ——— — ···· · ·—· / ··— ··· · ·—· ··· ·—·—·— / —·—— ——— ··— / —·—· ·— —· / ——— ·——· — —····— ——— ··— — / ·— — / ·— —· —·—— / — ·· —— · ·—·—·—';
	@override String get consentOperationLabel => '··· ···· ·— ·—· · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·—';
	@override String get finishingSetup => '··—· ·· —· ·· ··· ···· ·· —· ——· / ··· · — ··— ·——· / — / —·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· / ·—· · ··—· · ·—· · —· —·—· · / —·· ·— — ·— …';
}

// Path: startScreen
class _Translations$startScreen$cw extends Translations$startScreen$en {
	_Translations$startScreen$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get credits => '—··· —·—— / —·— ·· ··——— —·· / ·— —· —·· / ··—· ·—· ·· · —· —·· ···';
}

// Path: testerOverlay
class _Translations$testerOverlay$cw extends Translations$testerOverlay$en {
	_Translations$testerOverlay$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get tape => '—·—· ·— ··— — ·· ——— —· ———··· / ··— —· —·· · ·—· / —·—· ——— —· ··· — ·—· ··— —·—· — ·· ——— —·';
	@override String get warningTitle => '— ···· ·· ··· / ·— ·——· ·——· / ·· ··· / ·— / ·—— ——— ·—· —·— / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ···';
	@override String get warningBody => '—— ——— ··· — / ··—· · ·— — ··— ·—· · ··· / ···· ·— ···— · / ··— —· · ···— · —· / ··· ··— ·—· ··—· ·— —·—· · ··· / ·— —· —·· / — ···· · ·—· · / ·— ·—· · / — ·—· ·· ·——· / ···· ·— ——·· ·— ·—· —·· ··· / ·— ·—·· ·—·· / ——— ···— · ·—· ·—·—·— / ·——· ·—·· · ·— ··· · / —·—· ···· · —·—· —·— / ··—· ——— ·—· / ··— ·——· —·· ·— — · ··· / ·—· · ——· ··— ·—·· ·— ·—· ·—·· —·—— ·—·—·—';
	@override String whatsNew({required Object build}) => '·—— ···· ·— — ·————· ··· / —· · ·—— / ·· —· / —··· ··— ·· ·—·· —·· / ${build}';
	@override String get thanks => '— ···· ·— —· —·— / —·—— ——— ··— / ··—· ——— ·—· / ·——· ··— — — ·· —· ——· / —·—— ——— ··— ·—· / ·—·· ——— ——· / ·— — / ·—· ·· ··· —·— / ·· —· / ——— ·—· —·· · ·—· / — ——— / ···· · ·—·· ·——· / ··— ··· / —— ·— —·— · / — ···· ·· ··· / ·— ·——· ·——· / —··· · — — · ·—· —·—·——';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$cw extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => '·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get categoryAward => '·— ·—— ·— ·—· —·· ···';
	@override String get categoryContest => '—·—· ——— —· — · ··· — ···';
	@override String get categoryLookup => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ···';
	@override String get categorySpots => '··· ·——· ——— — / ··· ——— ··— ·—· —·—· · ···';
	@override String get categoryDashboard => '—·· ·— ··· ···· —··· ——— ·— ·—· —·· / ·——· ·— —· · ·—·· ···';
	@override String get categoryOther => '——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —· ···';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / · —··— — · —· ··· ·· ——— —· ···';
	@override String get applying => '·— —·—· — ·· ···— ·— — ·· —· ——· / · —··— — · —· ··· ·· ——— —· / —·—· ···· ·— —· ——· · ··· ——··—— / — ···· ·· ··· / —— ·— —·—— / — ·— —·— · / ·— / —— ——— —— · —· — …';
	@override String get noMatches => '—· ——— / · —··— — · —· ··· ·· ——— —· ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ····';
	@override String get installFromFile => '·· —· ··· — ·— ·—·· ·—·· / ··—· ·—· ——— —— / ··—· ·· ·—·· · …';
	@override String installVersion({required Object version}) => '···— · ·—· ··· ·· ——— —· / ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => '··· —·—· ·—· · · —· ··· ···· ——— — / ${n} / ——— ··—· / ${count}';
	@override String moreScreenshots({required Object count}) => '·—·—· ${count}';
	@override String get previousScreenshot => '·——· ·—· · ···— ·· ——— ··— ··· / ··· —·—· ·—· · · —· ··· ···· ——— —';
	@override String get nextScreenshot => '—· · —··— — / ··· —·—· ·—· · · —· ··· ···· ——— —';
	@override String get screenshotUnavailable => '··· —·—· ·—· · · —· ··· ···· ——— — / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get canReach => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —·—· ·— —· / —·—· ——— —· — ·— —·—· —';
	@override String canHoldConnection({required Object host}) => '${host} ——··—— / ——— ···— · ·—· / ·— / ·—·· ·· ···— · / —·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get canHoldLocalConnection => '—·· · ···— ·· —·—· · ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ——··—— / ——— ···— · ·—· / ·— / ·—·· ·· ···— · / —·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get canUseLocation => '—·—— ——— ··— ·—· / ·—·· ——— —·—· ·— — ·· ——— —·';
	@override String get canReadRadio => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / ·—· · ·— —·· / ·· — ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· ·';
	@override String get canControlRadio => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / —·—· ——— —· — ·—· ——— ·—·· / ·· — / ·— —· —·· / — ——— / — ·—· ·— —· ··· —— ·· — / ·—— ·· — ···· / ·· — / — / — ··— —· ·· —· ——· ——··—— / ·——· ——— ·—— · ·—· ——··—— / —·—· ·—— ——··—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ·— —· —·· / ·——· — —';
	@override String get canCommandRadioRaw => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / ··· · —· —·· / ·· — / ·— —· —·—— / —·—· ——— —— —— ·— —· —·· / ·· —· / ·· — ··· / ——— ·—— —· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / — / ·· —· —·—· ·—·· ··— —·· ·· —· ——· / ——— —· · ··· / — ···· ·— — / — ·—· ·— —· ··· —— ·· — / ——— ·—· / —·—· ···· ·— —· ——· · / ·· — ··· / ··· · — — ·· —· ——· ···';
	@override String get canReadCluster => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ·—· · ·— —·· / ·—— ···· ·— — / ·· — / ··· · —· —·· ···';
	@override String get canSpotCluster => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ·——· ——— ··· — / ··· ·——· ——— — ··· / ·· —· / —·—— ——— ··— ·—· / —· ·— —— ·';
	@override String get canCommandCluster => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ··· · —· —·· / ·· — / ·— —· —·—— / —·—· ——— —— —— ·— —· —·· / ·· —· / —·—— ——— ··— ·—· / —· ·— —— ·';
	@override String get canSetUserAgent => '·· —·· · —· — ·· ··—· —·—— / ·· — ··· · ·—·· ··—· / — ——— / ··· · ·—· ···— · ·—· ··· / ··— —· —·· · ·—· / ·· — ··· / ——— ·—— —· / —· ·— —— ·';
	@override String get noCapabilities => '·· — / ·— ··· —·— ··· / ··—· ——— ·—· / —· ——— — ···· ·· —· ——· / ——— ··— — ··· ·· —·· · / — ···· · / ·— ·——· ·——· ·—·—·—';
	@override String get sandboxNote => '· —··— — · —· ··· ·· ——— —· ··· / ·—· ··— —· / ··· ·— —· —·· —··· ——— —··— · —·· ———··· / —· ——— / ·— —·—· —·—· · ··· ··· / — ——— / —·—— ——— ··— ·—· / ··—· ·· ·—·· · ··· ——··—— / ·— —· —·· / —· ——— / —· · — ·—— ——— ·—· —·— / —··· · —·—— ——— —· —·· / ·—— ···· ·— — / ·· ··· / ·—·· ·· ··· — · —·· / ···· · ·—· · ·—·—·—';
	@override String get installAction => '·· —· ··· — ·— ·—·· ·—··';
	@override String get updateAction => '··— ·——· —·· ·— — ·';
	@override String get installFailed => '— ···· ·— — / · —··— — · —· ··· ·· ——— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·· —· ··· — ·— ·—·· ·—·· · —··';
	@override String get installedBadge => '·· —· ··· — ·— ·—·· ·—·· · —··';
	@override String get uninstallAction => '·—· · —— ——— ···— ·';
	@override String uninstallTitle({required Object name}) => '·—· · —— ——— ···— · / ${name} ··——··';
	@override String get uninstallBody => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ·— —· —·· / ·· — ··· / ··· · — — ·· —· ——· ··· / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —— ——— ···— · —·· ·—·—·— / —·—— ——— ··— ·—· / ·—·· ——— ——· ··· / ·—— ·· ·—·· ·—·· / ·—· · —— ·— ·· —· / ··— —· — ——— ··— —·—· ···· · —·· ·—·—·—';
	@override String installedMessage({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· · —·· / ${name}';
	@override String get installDownloading => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· …';
	@override String get installWaiting => '·—— ·— ·· — ·· —· ——· / — ——— / ·· —· ··· — ·— ·—·· ·—·· …';
	@override String get installInstalling => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· …';
	@override String get installAwaitingApproval => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—— ——— ··— ·—· / ·— ·——· ·——· ·—· ——— ···— ·— ·—·· …';
	@override String installAlreadyRunning({required Object name}) => '${name} / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / —··· · ·· —· ——· / ·· —· ··· — ·— ·—·· ·—·· · —·· ·—·—·—';
	@override String updatedTo({required Object version}) => '··— ·——· —·· ·— — · —·· / — ——— / ${version}';
	@override String installIncomplete({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / ${name} / —·· ·· —·· / —· ——— — / ··—· ·· —· ·· ··· ···· ·—·—·— / ·· — / —— ·— —·—— / —· · · —·· / ·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—';
	@override String uninstallFailed({required Object name}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · —— ——— ···— · / ${name}';
	@override String installedFrom({required Object source}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ··—· ·—· ——— —— / ${source}';
	@override String get dropHint => '—·· ·—· ——— ·——· / ·— / ·—·—·— ···· ··——— —·— · —··— — / · —··— — · —· ··· ·· ——— —· / — ——— / ·· —· ··· — ·— ·—·· ·—·· / ·· —';
	@override String get dropOneOnly => '—·· ·—· ——— ·——· / ——— —· · / · —··— — · —· ··· ·· ——— —· / ·— — / ·— / — ·· —— · ·—·—·—';
	@override String downloadFailed({required Object source, required Object status}) => '${source} / ·—· · — ··— ·—· —· · —·· / ${status} / ··—· ——— ·—· / — ···· ·— — / · —··— — · —· ··· ·· ——— —· ·—·—·—';
	@override String get downloadTooLarge => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / ··—· ·— ·—· / — ——— ——— / ·—·· ·— ·—· ——· · / — ——— / —··· · / ·— —· / · —··— — · —· ··· ·· ——— —· ·—·—·—';
	@override String get downloadNotSecure => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·—· · —·· ·· ·—· · —·—· — · —·· / ··· ——— —— · ·—— ···· · ·—· · / ·· —· ··· · —·—· ··— ·—· · ·—·—·—';
	@override String get catalogSection => '—·—· ·— — ·— ·—·· ——— ——·';
	@override String get catalogLoading => '·—·· ——— ·— —·· ·· —· ——· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· …';
	@override String get catalogUnreachable => '—·—· ·— — ·— ·—·· ——— ——· / ··— —· ·—· · ·— —·—· ···· ·— —··· ·—·· ·';
	@override String get builtIn => '—··· ··— ·· ·—·· — / ·· —·';
	@override String get updateAvailableBadge => '··— ·——· —·· ·— — · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get updatesAvailableTitle => '· —··— — · —· ··· ·· ——— —· / ··— ·——· —·· ·— — · ···';
	@override String updateAvailableFor({required Object name}) => '·— —· / ··— ·——· —·· ·— — · / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ··—· ——— ·—· / ${name} ·—·—·—';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} / ·— —· —·· / ${count} / —— ——— ·—· · / —· · · —·· / ··— ·——· —·· ·— — ·· —· ——· ·—·—·—';
	@override String updatesAvailableFor({required Object names}) => '${names} / —· · · —·· / ··— ·——· —·· ·— — ·· —· ——· ·—·—·—';
	@override String get pendingUpdatesSection => '·——· · —· —·· ·· —· ——· / ··— ·——· —·· ·— — · ···';
	@override String get updateAllAction => '··— ·——· —·· ·— — · / ·— ·—·· ·—··';
	@override String get updatesUnderWay => '— ···· ——— ··· · / ··— ·——· —·· ·— — · ··· / ·— ·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ··— —· —·· · ·—· / ·—— ·— —·—— ·—·—·—';
	@override String get updatesNothingLeft => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ··— ·——· / — ——— / —·· ·— — · ·—·—·—';
	@override String get updatesNoticeAction => '—— ——— ·—· · / ·· —· ··—· ———';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··— ·——· —·· ·— — · / ${count} / · —··— — · —· ··· ·· ——— —· ··——··',
		other: '··— ·——· —·· ·— — · / ${count} / · —··— — · —· ··· ·· ——— —· ··· ··——··',
	);
	@override String get upgradeDoneTitle => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ·—· · ·— —·· —·——';
	@override String get upgradeDoneBody => '— ···· · —·—— / —· ——— ·—— / —·—· ——— —— · / ··—· ·—· ——— —— / — ···· · / ···· ·— —— ··——— —·— / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ——··—— / ··· ——— / — ···· · —·—— / —·—· ·— —· / —··· · / ··— ·——· —·· ·— — · —·· / ·—— ·· — ···· ——— ··— — / ·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / ·— / —· · ·—— / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——· ·—·—·—';
	@override String upgradeDoneUnserved({required Object names}) => '—· ——— — / ··— ·——· ——· ·—· ·— —·· · —·· ———··· / ${names} ·—·—·—';
	@override String upgradeDoneRefused({required Object names}) => '·—— ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —· ———··· / ${names} ·—·—·—';
	@override String get upgradeDoneRefusedHint => '— ···· · —·—— / ·— ·—· · / ··· — ·· ·—·· ·—·· / ·· —· ··· — ·— ·—·· ·—·· · —·· / ·— —· —·· / —— ·— ·—· —·— · —·· / ·· —· / ··· · — — ·· —· ——· ··· / › / · —··— — · —· ··· ·· ——— —· ··· / — / ··— ·——· —·· ·— — ·· —· ——· / — ···· · —— / — ···· · ·—· · / ·—— ·· ·—·· ·—·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—';
	@override String get upgradeDoneUnservedHint => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / —·· ·· ·—· · —·—· — / ·—· · ·——· ·—·· ·— —·—· · —— · —· — / ··—· ——— ·—· / — ···· · ··· · ——··—— / ··· ——— / ·—·· ——— ——— —·— / — ···· · ·—· · / ··—· ——— ·—· / · —··— — · —· ··· ·· ——— —· ··· / — ···· ·— — / —·—· ——— ···— · ·—· / ·—— ···· ·— — / —·—— ——— ··— / ··— ··· · —·· ·—·—·—';
	@override String get retiredQp => '——·— ··· ——— / ·——· ·— ·—· — ·· · ···';
	@override String get retiredStateparks => '··· — ·— — · / ·——· ·— ·—· —·— ··· / · ···— · —· — ···';
	@override String upgradeDoneMissing({required Object count}) => '${count} / ——— ··—· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ···· ·— ···— · / —· ——— — / ·— ·—· ·—· ·· ···— · —·· / —·—— · — ·—·—·— / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —··· · / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / — ···· · / —· · —··— — / — ·· —— · / — ···· · / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· / —·—· ·— —· / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—';
	@override String get runtimeDeadBody => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ··· — ·— ·—· — ·—·—·— / ·—· · ··· — ·— ·—· — ·· —· ——· / — ···· · / ·— ·——· ·——· / ··· ···· ——— ··— ·—·· —·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—';
	@override String get refusedTitle => '··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —·';
	@override String get upgradeBusyTitle => '··· — ·· ·—·· ·—·· / ··· · — — ·· —· ——· / ··— ·——·';
	@override String get upgradeRuntimeDeadTitle => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —· ——— — / ·—· ··— —· —· ·· —· ——·';
	@override String get restoreTitle => '··· ——— —— · / ——— ··—· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —— ·· ··· ··· ·· —· ——·';
	@override String get restoreBody => '— ···· · ··· · / · —··— — · —· ··· ·· ——— —· ··· / —·—— ——— ··— / ·· —· ··· — ·— ·—·· ·—·· · —·· / ·— ·—· · / —· ——— — / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—— · / —·—· ·— —· / —·· ——— ·—— —· ·—·· ——— ·— —·· / — ···· · —— / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · / ···· ·— —— ··——— —·— / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ———···';
	@override String get restoreFromFile => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / ··—· ·· ·—·· · ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / — ···· · ··· · / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · ·· ·—· / ··—· ·· ·—·· · ··· ——··—— / ——— ·—· / ··—· ——— ·—· ——· · — / — ···· · —— ———···';
	@override String get restoreOtherCatalog => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / —·· ·· ··—· ··—· · ·—· · —· — / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ——··—— / ··· ——— / — ···· · —·—— / ·— ·—· · / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· · ———···';
	@override String get restoreForget => '··—· ——— ·—· ——· · —';
	@override String get restoreInstall => '·· —· ··· — ·— ·—·· ·—··';
	@override String get restoreLater => '·—·· ·— — · ·—·';
	@override String get restoreInstalling => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· …';
	@override String get restoreDoneTitle => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —··· ·— —·—· —·—';
	@override String restoreDoneBody({required Object names}) => '·· —· ··· — ·— ·—·· ·—·· · —·· / ·— ——· ·— ·· —· ———··· / ${names} ·—·—·—';
	@override String get restorePartialTitle => '··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·· —· ··· — ·— ·—·· ·—·· · —··';
	@override String restoreFailed({required Object names}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —· ··· — ·— ·—·· ·—·· ———··· / ${names} ·—·—·— / ·—— · / ·—— ·· ·—·· ·—·· / ——— ··—· ··—· · ·—· / — ···· · —— / ·— ——· ·— ·· —· / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—';
	@override String get restoreBusyBody => '— ···· · / ·— ·——· ·——· / ·· ··· / ··· — ·· ·—·· ·—·· / ··· · — — ·· —· ——· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ··— ·——· ·—·—·— / ·—— · / ·—— ·· ·—·· ·—·· / ——— ··—· ··—· · ·—· / — ···· · ··· · / ·— ——· ·— ·· —· / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—';
	@override String get restoreRuntimeDeadBody => '·—— · / ·· —· ··· — ·— ·—·· ·—·· · —·· / — ···· · —— / ·— ——· ·— ·· —· ——··—— / —··· ··— — / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ··· — ·— ·—· — ·—·—·— / ·—· · ··· — ·— ·—· — ·· —· ——· / — ···· · / ·— ·——· ·——· / ··· ···· ——— ··— ·—·· —·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—';
	@override String revokedTitle({required Object name}) => '${name} / ·—— ·— ··· / ·—— ·· — ···· —·· ·—· ·— ·—— —·';
	@override String get revokedBody => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ·—— ·· — ···· —·· ·—· · ·—— / — ···· ·· ··· / ···— · ·—· ··· ·· ——— —· ——··—— / ··· ——— / ·· — / ···· ·— ··· / —··· · · —· / —·· ·· ··· ·— —··· ·—·· · —·· ·—·—·—';
	@override String get downloadHashMismatch => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / —· ——— — / — ···· · / · —··— — · —· ··· ·· ——— —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / —·· · ··· —·—· ·—· ·· —··· · —·· ·—·—·—';
	@override String catalogVersionUnknown({required Object version, required Object key}) => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / ···— · ·—· ··· ·· ——— —· / ${version} / ——— ··—· / ${key} ·—·—·—';
	@override String get catalogLinkUnknown => '— ···· ·— — / —·—· ·— — ·— ·—·· ——— ——· / ·—·· ·· —· —·— / —·· ——— · ··· / —· ——— — / —· ·— —— · / ·— —· / · —··— — · —· ··· ·· ——— —· / ···— · ·—· ··· ·· ——— —· ·—·—·—';
	@override String catalogNoRelease({required Object key}) => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / ·—· · ·—·· · ·— ··· · / ——— ··—· / ${key} / ——— —· / — ···· ·— — / — ·—· ·— —·—· —·— ·—·—·—';
	@override String get installFromLink => '·· —· ··· — ·— ·—·· ·—·· / ··—· ·—· ——— —— / ·—·· ·· —· —·—';
	@override String get unstableReleaseWarning => '— ···· ·· ··· / ·· ··· / ·— —· / ··— —· ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ——··—— / ·—— ···· ·· —·—· ···· / ·· — ··· / ·——· ··— —··· ·—·· ·· ··· ···· · ·—· / ···· ·— ··· / —· ——— — / —·—· ·— ·—·· ·—·· · —·· / ··—· ·· —· ·· ··· ···· · —·· ·—·—·— / ·· — / —— ·— —·—— / —— ·· ··· —··· · ···· ·— ···— · ——··—— / ·— —· —·· / ·· — / ·—— ·· ·—·· ·—·· / —·— · · ·——· / ·—· · —·—· · ·· ···— ·· —· ——· / ··— —· ··· — ·— —··· ·—·· · / ··— ·——· —·· ·— — · ··· ·—·—·—';
	@override String get bleedingReleaseWarning => '— ···· ·· ··· / ·· ··· / ·— / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · / ·—· · ·—·· · ·— ··· · ———··· / ·—— ——— ·—· —·— / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ··· / — ···· ·— — / —— ·— —·—— / —··· ·—· · ·— —·— / ——— ·—· / ·—·· ——— ··· · / ·· — ··· / ··· · — — ·· —· ——· ··· ·—·—·— / ·· — / ·—— ·· ·—·· ·—·· / —·— · · ·——· / ·—· · —·—· · ·· ···— ·· —· ——· / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · / ··— ·——· —·· ·— — · ··· ·—·—·—';
	@override String get channelUnstable => '··— —· ··· — ·— —··· ·—·· ·';
	@override String get channelBleeding => '—··· ·—·· · · —·· ·· —· ——·';
	@override String get followsUnstable => '·—· · —·—· · ·· ···— · ··· / ··— —· ··· — ·— —··· ·—·· · / ·— —· —·· / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ···';
	@override String get followsBleeding => '·—· · —·—· · ·· ···— · ··· / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · ——··—— / ··— —· ··· — ·— —··· ·—·· · / ·— —· —·· / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ···';
	@override String get followStableAction => '··—· ——— ·—·· ·—·· ——— ·—— / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ··· / ——— —· ·—·· —·——';
	@override String get revokedBadge => '·—· · ···— ——— —·— · —··';
	@override String get refusedBadge => '—·· ·· —·· / —· ——— — / ·—·· ——— ·— —··';
	@override String get downloadNotHttps => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / —· ——— — / ——— ···— · ·—· / ·— / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· ·—·—·—';
	@override String downloadUnreachable({required Object source}) => '${source} / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· / ··—· ——— ·—· / — ···· ·— — / · —··— — · —· ··· ·· ——— —· ·—·—·—';
	@override String get detailsAction => '—·· · — ·— ·· ·—·· ···';
	@override String get installedFromFile => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / ··—· ·· ·—·· ·';
	@override String get detailsWhatItDoes => '·——· ·—· ——— ···— ·· —·· · ··· / ··· ··— ·——· ·——· ——— ·—· — / ··—· ——— ·—·';
	@override String get installedPreloaded => '·——· ·—· · —····— ·· —· ··· — ·— ·—·· ·—·· · —··';
	@override String get hookAccount => '·— —·—· —·—· ——— ··— —· — / ··· ·· ——· —· —····— ·· —·';
	@override String get hookCallNotes => '—·—· ·— ·—·· ·—·· / —· ——— — · ···';
	@override String get hookDataFile => '——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·—';
	@override String get hookExport => '· —··— ·——· ——— ·—· —';
	@override String get hookLookup => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ···';
	@override String get hookScoring => '··· —·—· ——— ·—· ·· —· ——·';
	@override String get hookSpots => '··· ·——· ——— — ···';
	@override String hookHunting({required Object program}) => '···· ··— —· — ·· —· ——· / ${program}';
	@override String hookActivating({required Object program}) => '·— —·—· — ·· ···— ·— — ·· —· ——· / ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '… / ·— —· —·· / ${count} / ——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —·',
		other: '… / ·— —· —·· / ${count} / ——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —· ···',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / · —··— — · —· ··· ·· ——— —· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
		other: '${count} / · —··— — · —· ··· ·· ——— —· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
	);
}

// Path: home
class _Translations$home$cw extends Translations$home$en {
	_Translations$home$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—·';
	@override String get newOperation => '—· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get stationCallsign => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get titleOptional => '— ·· — ·—·· · / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—';
	@override String get emptyList => '—· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ··· / —·—— · — ·—·—·— / —·—· ·—· · ·— — · / ——— —· · / — ——— / ··· — ·— ·—· — / ·—·· ——— ——· ——· ·· —· ——· ·—·—·—';
	@override String get quickLookup => '——·— ··— ·· —·—· —·— / ·—·· ——— ——— —·— ··— ·——·';
	@override late final _Translations$home$nav$cw nav = _Translations$home$nav$cw._(_root);
	@override late final _Translations$home$panels$cw panels = _Translations$home$panels$cw._(_root);
	@override String get toggleNav => '··· ···· ——— ·—— / ——— ·—· / ···· ·· —·· · / — ···· · / —· ·— ···— ·· ——· ·— — ·· ——— —· / ·—·· ·— —··· · ·—·· ···';
	@override late final _Translations$home$logs$cw logs = _Translations$home$logs$cw._(_root);
}

// Path: chase
class _Translations$chase$cw extends Translations$chase$en {
	_Translations$chase$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => '——— ·——·';
	@override String get chasing => '—·—· ···· ·— ··· ·· —· ——·';
	@override String goalsTwo({required Object first, required Object second}) => '${first} / ·—··· / ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first} ——··—— / ${second} / ·—··· / —— ——— ·—· ·';
	@override late final _Translations$chase$station$cw station = _Translations$chase$station$cw._(_root);
	@override late final _Translations$chase$periodInline$cw periodInline = _Translations$chase$periodInline$cw._(_root);
	@override late final _Translations$chase$periodStats$cw periodStats = _Translations$chase$periodStats$cw._(_root);
	@override late final _Translations$chase$period$cw period = _Translations$chase$period$cw._(_root);
	@override late final _Translations$chase$goals$cw goals = _Translations$chase$goals$cw._(_root);
	@override late final _Translations$chase$panels$cw panels = _Translations$chase$panels$cw._(_root);
	@override late final _Translations$chase$claims$cw claims = _Translations$chase$claims$cw._(_root);
	@override late final _Translations$chase$notice$cw notice = _Translations$chase$notice$cw._(_root);
	@override late final _Translations$chase$alerts$cw alerts = _Translations$chase$alerts$cw._(_root);
	@override String get checklists => '—·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· · ··· ···';
	@override late final _Translations$chase$imports$cw imports = _Translations$chase$imports$cw._(_root);
}

// Path: dialogs
class _Translations$dialogs$cw extends Translations$dialogs$en {
	_Translations$dialogs$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => '——— ·——· · ·—· ·— — ·· ——— —· / —·· · — ·— ·· ·—·· ···';
	@override String get activities => '·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get stationCallsign => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get multiStationIdentifier => '—— ··— ·—·· — ·· —····— ··· — ·— — ·· ——— —· / ·· —·· · —· — ·· ··—· ·· · ·—· / —·——· —· ··— —— —··· · ·—· ··· / ——— —· ·—·· —·—— —·——·—';
	@override String get notes => '—· ——— — · ···';
	@override String get deleteOperationTitle => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get purgeTestsTitle => '·——· ··— ·—· ——· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String get purgeTestsBody => '— ···· ·· ··· / ·——· · ·—· —— ·— —· · —· — ·—·· —·—— / —·· · ·—·· · — · ··· / — ···· · ··· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·— —· —·· / — ···· · ·· ·—· / ——·— ··· ——— ··· ·—·—·— / ·· — / —·—· ·— —· —· ——— — / —··· · / ··— —· —·· ——— —· · ·—·—·—';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·——· ·—·· ··— ··· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — / — ···· ·— — / —··· · ·—·· ——— —· ——· ··· / — ——— / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—',
		other: '·——· ·—·· ··— ··· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / — ···· ·— — / —··· · ·—·· ——— —· ——· / — ——— / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—',
	);
	@override String get purgeTestsAction => '·——· ··— ·—· ——· ·';
	@override String get syncAllTitle => '·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / ·—·· ——— ——· ··——··';
	@override String syncAllBody({required Object qsos}) => '··· —·—— —· —·—· ·— ·—·· ·—·· / —··· ·— —·—· —·— ··· / ··— ·——· / ·— —· —·· / —·—· ·—·· · ·— ·—· ··· / ${qsos} / ··—· ·—· ——— —— / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / — ···· · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / ·—·· ——— ——· / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · / ··· · ·—· ···— · ·—· ·—·—·— / — ···· · / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ·· —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / —·· ·— — ·— —··· ·— ··· · ·—·—·—';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${n} / ——·— ··· ——— / ···· ·— ··· / —· ——— — / —··· · · —· / ··· —·—— —· —·—· · —·· / —·—— · — / — / — ···· · / ··· · ·—· ···— · ·—· / —· · ···— · ·—· / ·—· · —·—· · ·· ···— · —·· / ·· — ——··—— / ·— —· —·· / ·· — / ·—— ·· ·—·· ·—·· / —· ——— — / —·—· ——— —— · / —··· ·— —·—· —·— ·—·—·—',
		other: '${n} / ——·— ··· ——— ··· / ···· ·— ···— · / —· ——— — / —··· · · —· / ··· —·—— —· —·—· · —·· / —·—— · — / — / — ···· · / ··· · ·—· ···— · ·—· / —· · ···— · ·—· / ·—· · —·—· · ·· ···— · —·· / — ···· · —— ——··—— / ·— —· —·· / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —· ——— — / —·—· ——— —— · / —··· ·— —·—· —·— ·—·—·—',
	);
	@override String get syncAllAction => '·—— ·· ·——· · / ·— —· —·· / ·—· · ··· —·—— —· —·—·';
	@override String get receivedPurgesTitle => '— · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·—· · —— ——— ···— · —·· / · ·—·· ··· · ·—— ···· · ·—· ·';
	@override String get receivedPurgesBody => '— ···· · ··· · / ·—— · ·—· · / —·· · ·—·· · — · —·· / ·— ··· / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· · ·—·—·— / ·—· · —— ——— ···— · / — ···· · —— / ···· · ·—· · / — ——— ——— ··——·· / — ···· ·· ··· / ·——· · ·—· —— ·— —· · —· — ·—·· —·—— / —·· · ·—·· · — · ··· / — ···· · —— / ·— —· —·· / — ···· · ·· ·—· / ——·— ··· ——— ··· ——··—— / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ··— —· —·· ——— —· · ·—·—·—';
	@override String get receivedPurgesAction => '·—· · —— ——— ···— ·';
	@override late final _Translations$dialogs$callChange$cw callChange = _Translations$dialogs$callChange$cw._(_root);
}

// Path: operation
class _Translations$operation$cw extends Translations$operation$en {
	_Translations$operation$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / —·· · ·—·· · — · —·· ·—·—·— / ··— —· —·· · ·—·· · — · / ·· — / — ——— / ·—·· ——— ——· / ——— ·—· / —— ·— —·— · / —·—· ···· ·— —· ——· · ··· ·—·—·—';
	@override late final _Translations$operation$tabs$cw tabs = _Translations$operation$tabs$cw._(_root);
	@override late final _Translations$operation$positions$cw positions = _Translations$operation$positions$cw._(_root);
	@override String get stationCallsignNone => '—· ——— / ··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get titleNone => '—· ——— / — ·· — ·—·· ·';
	@override String get deleteOperation => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get loggingControlsStale => '·— —·—· — ·· ···— ·· — —·—— / ··—· ·· · ·—·· —·· ··· / —— ·— —·—— / —··· · / ——— ··— — / ——— ··—· / —·· ·— — · / — / ·—· · ——— ·——· · —· / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· / — ——— / ·—· · ··—· ·—· · ··· ···· / — ···· · ——';
	@override String get locationNone => '—· ——— — / ··· · —';
	@override String get generalOperation => '——· · —· · ·—· ·— ·—·· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String titleFor({required Object value}) => '··—· ——— ·—· / ${value}';
	@override String titleAt({required Object value}) => '·— — / ${value}';
	@override String segmentNow({required Object description}) => '—· ——— ·—— / ${description}';
	@override String get testOperationSuffix => '— · ··· — ·· —· ——·';
	@override late final _Translations$operation$menu$cw menu = _Translations$operation$menu$cw._(_root);
	@override late final _Translations$operation$layout$cw layout = _Translations$operation$layout$cw._(_root);
	@override late final _Translations$operation$export$cw export = _Translations$operation$export$cw._(_root);
	@override late final _Translations$operation$spots$cw spots = _Translations$operation$spots$cw._(_root);
	@override late final _Translations$operation$import$cw import = _Translations$operation$import$cw._(_root);
}

// Path: map
class _Translations$map$cw extends Translations$map$en {
	_Translations$map$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$cw outlineIssue = _Translations$map$outlineIssue$cw._(_root);
	@override String get outlinesDisclaimer => '——— ··— — ·—·· ·· —· · ··· / ·— ·—· · / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · / ——— —· ·—·· —·—— ·—·—·— / —·· ——— / —·—— ——— ··— ·—· / ——— ·—— —· / ·—· · ··· · ·— ·—· —·—· ···· —·—·——';
	@override String outlinesCredit({required Object sources}) => '——— ··— — ·—·· ·· —· · ··· ———··· / ${sources}';
	@override String boundariesCredit({required Object sources}) => '—··· ——— ··— —· —·· ·— ·—· ·· · ··· ———··· / ${sources}';
	@override String facilitiesCredit({required Object sources}) => '··—· ·— —·—· ·· ·—·· ·· — ·· · ··· ———··· / ${sources}';
	@override String get fullCredits => '··—· ··— ·—·· ·—·· / —·· ·— — ·— ··· · — / —·—· ·—· · —·· ·· — ···';
	@override String get fewerCredits => '··—· · ·—— · ·—· / —·—· ·—· · —·· ·· — ···';
	@override String get emptyState => '—· ——— / ——·— ··· ——— / ·—·· ——— —·—· ·— — ·· ——— —· ··· / —·—— · — ·—·—·—\n——·— ··· ——— ··· / ·—— ·· — ···· / ·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · ——··—— / ··· — ·— — · ——··—— / ——— ·—· / —·—· ——— ··— —· — ·—· —·—— / ·—— ·· ·—·· ·—·· / ··· ···· ——— ·—— / ··— ·——· / ···· · ·—· · ·—·—·—';
	@override String get unavailable => '— ···· · / —— ·— ·——· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—';
	@override String qthPopupTitle({required Object grid}) => '——·— — ···· ———··· / ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} / —·— ——';
	@override String distanceMiles({required Object distance}) => '${distance} / —— ··';
	@override String get flat => '··—· ·—·· ·— —';
	@override String get globe => '——· ·—·· ——— —··· ·';
	@override String get zoomIn => '——·· ——— ——— —— / ·· —·';
	@override String get zoomOut => '——·· ——— ——— —— / ——— ··— —';
	@override String get resetNorth => '·—· · ··· · — / — ——— / —· ——— ·—· — ···· / ··— ·——·';
	@override late final _Translations$map$postcard$cw postcard = _Translations$map$postcard$cw._(_root);
}

// Path: mapsView
class _Translations$mapsView$cw extends Translations$mapsView$en {
	_Translations$mapsView$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—— ·— ·——· ···';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / ·——· ·— ·—· —·— ··· ——··—— / ··· ··— —— —— ·· — ··· / ·— —· —·· / —— ——— ·—· ·';
	@override String get activities => '·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get layers => '·—·· ·— —·—— · ·—· ···';
	@override String get baseMap => '—··· ·— ··· · / —— ·— ·——·';
	@override String get satellite => '··· ·— — · ·—·· ·—·· ·· — · / —·——· · ··· ·—· ·· —·——·—';
	@override String get facilities => '·——· ·— ·—· —·— / ··—· ·— —·—· ·· ·—·· ·· — ·· · ···';
	@override String get boundaries => '—··· ——— ··— —· —·· ·— ·—· ·· · ···';
	@override String get currentLocation => '—·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— — ·· ——— —·';
	@override String noMatches({required Object text}) => '—· ——— — ···· ·· —· ——· / —— ·— — —·—· ···· · ··· / “ ${text} ”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ·—· · ··—· · ·—· · —· —·—· · / ·— — / ${where}',
		other: '${count} / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— — / ${where}',
	);
	@override String get startOperation => '··· — ·— ·—· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ·—— ·· — ···· / — ···· · ··· · / ·—· · ··—· · ·—· · —· —·—· · ···';
}

// Path: activitiesView
class _Translations$activitiesView$cw extends Translations$activitiesView$en {
	_Translations$activitiesView$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get activitiesCountZero => '—· ——— / ·— —·—· — ·· ···— ·· — ·· · ··· / ··· · ·—·· · —·—· — · —··';
	@override String get activitiesCountOne => '·———— / ·— —·—· — ·· ···— ·· — —·——';
	@override String activitiesCountOther({required Object count}) => '${count} / ·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get empty => '—· ——— / ·— —·—· — ·· ···— ·· — ·· · ··· / —·—— · — / — / ··— ··· · / ··· ··— ——· ——· · ··· — ·· ——— —· ··· / ·—··· / ··· · ·— ·—· —·—· ···· / —··· · ·—·· ——— ·—— / — ——— / ·— —·· —·· / ——— —· ·';
	@override String get removeActivity => '·—· · —— ——— ···— ·';
	@override String openReferenceLink({required Object name}) => '——— ·——· · —· / ${name}';
	@override String get editActivity => '· —·· ·· — / ·— —·—· — ·· ···— ·· — —·——';
	@override String get manageExtensions => '—— ·— —· ·— ——· · / · —··— — · —· ··· ·· ——— —· ···';
	@override String get manage => '—— ·— —· ·— ——· ·';
	@override String activitiesTitle1({required Object first}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first} / ·— —· —·· / ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first} ——··—— / ${second} / ·— —· —·· / ${more} / —— ——— ·—· ·';
	@override String get reference => '·—· · ··—· · ·—· · —· —·—· ·';
	@override String get invalidReference => '—· ——— — / ···— ·— ·—·· ·· —··';
	@override String get duplicateReference => '·— ·—·· ·—· · ·— —·· —·—— / ·— —·· —·· · —··';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / —··· —·—— / —· ·— —— · ——··—— / ·—· · ··—· · ·—· · —· —·—· · / ——— ·—· / ·— —· —·—— — ···· ·· —· ——· / · ·—·· ··· · …';
	@override String get noSuggestions => '—· ——— / —— ·— — —·—· ···· · ···';
	@override String get noSuggestionsHint => '··· · ·— ·—· —·—· ···· / —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · / —· ·— —— · / ——— ·—· / —· ··— —— —··· · ·—· / ·— —··· ——— ···— ·';
	@override String get noSuggestionsExample => '—·——· ··—· ——— ·—· / · —··— ·— —— ·——· ·—·· · / ·————· — ·—· ·— ·· ·—·· ·————· / ——— ·—· / ·————· ····— ····· ····· —···· ·————· —·——·—';
	@override String get allOptions => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ···';
	@override String get determiningLocation => '—·· · — · ·—· —— ·· —· ·· —· ——· / —·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— — ·· ——— —· …\n·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / ——· ·——· ··· / ··—· ·· —··— / — ——— / ··—· ·· —· —·· / —· · ·— ·—· —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · ···';
	@override String get locationUnavailableTitle => '·—·· ——— —·—· ·— — ·· ——— —· / —·· ·— — ·— / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get locationDeniedTitle => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —·· · —· ·· · —··';
	@override String get locationBlockedTitle => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —··· ·—·· ——— —·—· —·— · —··';
	@override String get noNearbyReason => '—·—· ·— —· —· ——— — / —·· · — · ·—· —— ·· —· · / —· · ·— ·—· —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · ···';
	@override String locationManualHint({required Object icon}) => '— ·— ·——· / ${icon} / — ——— / —— ·— —· ··— ·— ·—·· ·—·· —·—— / · —· — · ·—· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— — ·· ——— —· ——··——\n——— ·—· / ·——— ··— ··· — / ··· · ·— ·—· —·—· ···· / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · ··· / —··· —·—— / —· ·— —— ·';
	@override String get locationGrantAction => '·— ·—·· ·—·· ——— ·—— / ·—·· ——— —·—· ·— — ·· ——— —· / ·— —·—· —·—· · ··· ···';
	@override String get locationSettingsAction => '——— ·——· · —· / ··· · — — ·· —· ——· ···';
	@override String get locationSettingsUnavailable => '·— ·—·· ·—·· ——— ·—— / ·—·· ——— —·—· ·— — ·· ——— —· / ·— —·—· —·—· · ··· ··· / ·· —· / —·—— ——— ··— ·—· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···';
	@override String get locationGrantRefused => '··· — ·· ·—·· ·—·· / —· ——— / ·—·· ——— —·—· ·— — ·· ——— —· / — / — ···· · / ··· —·—— ··· — · —— / ··· ·— ·· —·· / —· ——— / ·— ——· ·— ·· —·';
	@override String get searchUnavailableTitle => '·— —·—· — ·· ···— ·· — —·—— / ··· · ·— ·—· —·—· ···· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get searchUnavailableReason => '—· ——— / ·— —·—· — ·· ···— ·· — —·—— / · —··— — · —· ··· ·· ——— —· / —·—· ——— ··— ·—·· —·· / ·—· ··— —· / — ···· · / ··· · ·— ·—· —·—· ···· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—';
	@override String get emptySheet => '··— ··· · / ··· ··— ——· ——· · ··· — ·· ——— —· ··· / ·—··· / ··· · ·— ·—· —·—· ···· / —··· · ·—·· ——— ·—— / — ——— / ·— —·· —·· / ——— —· ·';
	@override String get exports => '· —··— ·——· ——— ·—· — ···';
	@override String get exportLogs => '· —··— ·——· ——— ·—· — / ·—·· ——— ——· ···';
	@override String get tools => '— ——— ——— ·—·· ···';
	@override String get toolsTitle => '——— ·——· · ·—· ·— — ·· ——— —· / — ——— ——— ·—·· ···';
	@override String get operationDetails => '——— ·——· · ·—· ·— — ·· ——— —· / —·· · — ·— ·· ·—·· ···';
	@override String get share => '··· ···· ·— ·—· ·';
	@override String get archive => '·— ·—· —·—· ···· ·· ···— ·';
	@override String get deleteOperation => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get undeleteOperation => '··— —· —·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get alreadySelected => '·— ·—·· ·—· · ·— —·· —·—— / ··· · ·—·· · —·—· — · —··';
	@override String get selected => '··· · ·—·· · —·—· — · —··';
	@override String pickPosition({required Object index, required Object count}) => '${index} / ——— ··—· / ${count}';
	@override String get previousPick => '·——· ·—· · ···— ·· ——— ··— ··· / —— ·— — —·—· ····';
	@override String get nextPick => '—· · —··— — / —— ·— — —·—· ····';
	@override String get retiredReference => '·—· · — ·· ·—· · —··';
	@override String enableExtension({required Object name}) => '· —· ·— —··· ·—·· · / ${name}';
	@override String get enableExtensionHint => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / —·—· ··— ·—· ·—· · —· — ·—·· —·—— / · —· ·— —··· ·—·· · —··';
	@override String get enableExtensionForRefHint => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ···· ·— —· —·· ·—·· · ··· / ——— —· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · ··· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / —·—· ··— ·—· ·—· · —· — ·—·· —·—— / · —· ·— —··· ·—·· · —··';
	@override String extensionNotRunning({required Object name}) => '${name} / ·· ··· / —· ——— — / ·—· ··— —· —· ·· —· ——·';
	@override String get extensionNotRunningHint => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ···· ·— ··· / —··· · · —· / —·· ·· ··· ·— —··· ·—·· · —·· ——··—— / ——— ·——· · —· / · —··— — · —· ··· ·· ——— —· / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / —— ——— ·—· · / ·· —· ··—· ———';
	@override String installExtension({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· / ${name}';
	@override String get installExtensionHint => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / ·· —· ··· — ·— ·—·· ·—·· · —··';
	@override String get onlyCatalogMatches => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / ·· —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· ·—·—·—\n·· —· ··· — ·— ·—·· ·—·· / — ···· · —— / ·· —· / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—';
	@override String get setupUnavailable => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—·· ——— ·— —·· / — ···· ·· ··· / ·— —·—· — ·· ···— ·· — —·—— ·————· ··· / ··· · — ··— ·——· / — / — ·—· —·—— / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / —— ·— —· ·— ——· ·';
	@override String get controlsUnavailableTitle => '·— —·—· — ·· ···— ·· — —·—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get controlsUnavailableReason => '—·—— ——— ··— ·—· / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— ·—· · / ··· ·— ··—· · ——··—— / —··· ··— — / · —·· ·· — ·· —· ——· / — ···· · —— / ·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—';
	@override String get controlsUnavailableRetry => '·—· · — ·—· —·——';
	@override String get onlyDisabledMatches => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / · —··— — · —· ··· ·· ——— —· ··· / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· ·—·—·—\n· —· ·— —··· ·—·· · / — ···· · —— / ·· —· / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—';
	@override String get onlyNotRunningMatches => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / — ···· ·— — / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· / ·— ·—· · / —· ——— — / ·—· ··— —· —· ·· —· ——· ·—·—·—\n··· · · / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—';
	@override String get mapToggle => '—— ·— ·——·';
	@override String get searchToggle => '··· · ·— ·—· —·—· ····';
	@override String get addToOperation => '·— —·· —·· / — ——— / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get addToOperationShort => '·— —·· —·· / — ——— / ——— ·——· ·—·—·—';
	@override String get mapEmptyState => '—· ——— / ·—· · ··· ··— ·—·· — ··· / — ——— / ··· ···· ——— ·—— / ——— —· / — ···· · / —— ·— ·——·';
	@override String get mapEmptyStateHint => '··· ·—— ·· — —·—· ···· / —··· ·— —·—· —·— / — ——— / — ···· · / ·—·· ·· ··· — ——··—— / ——— ·—· / ··· · ·— ·—· —·—· ···· / ··—· ——— ·—· / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· ·';
	@override String get imports => '·· —— ·——· ——— ·—· — ···';
}

// Path: loggingControls
class _Translations$loggingControls$cw extends Translations$loggingControls$en {
	_Translations$loggingControls$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => '— ·· —— · / —·——· ··— — —·—· —·——·—';
	@override String get date => '—·· ·— — ·';
	@override String get now => '—· ——— ·——';
	@override String get manualTimeSettings => '—— ·— —· ··— ·— ·—·· / — ·· —— ·';
	@override String get manualTimeIncrement => '·· —· —·—· ·—· · —— · —· — / ·——· · ·—· / ——·— ··· ———';
	@override String get manualTimeIncrementNone => '—· ——— —· ·';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / —— ·· —· ··— — ·',
		other: '${count} / —— ·· —· ··— — · ···',
	);
	@override String get frequency => '··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get mode => '—— ——— —·· ·';
	@override String get theirCall => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—··';
	@override String get noteField => '—· ——— — ·';
	@override String get todoField => '— ——— —·· ———';
	@override String get sent => '··· · —· —';
	@override String get rcvd => '·—· —·—· ···— —··';
	@override String get more => '—— ——— ·—· ·';
	@override String get revert => '·—· · ···— · ·—· —';
	@override String get undoDelete => '··— —· —·· ——— / —·· · ·—·· · — ·';
	@override String get restore => '·—· · ··· — ——— ·—· ·';
	@override String get wipe => '·—— ·· ·——· ·';
	@override String get undo => '··— —· —·· ———';
	@override String get pendingDeleteTapWarning => '— ·— ·——· / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ——·— ··· ———';
	@override String get pendingDeleteClickWarning => '—·—· ·—·· ·· —·—· —·— / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ——·— ··· ———';
	@override String get deletedQsoWarning => '—·· · ·—·· · — · —·· / ——·— ··· ———';
	@override String pendingDeleteEventTapWarning({required Object kind}) => '— ·— ·——· / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => '—·—· ·—·· ·· —·—· —·— / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ${kind}';
	@override String deletedEventWarning({required Object kind}) => '—·· · ·—·· · — · —·· / ${kind}';
	@override String get timeControl => '— ·· —— ·';
	@override String get radioControl => '·—· ·— —·· ·· ———';
	@override String get powerControl => '·——· ——— ·—— · ·—·';
	@override String get notesControl => '—· ——— — · ···';
	@override String get power => '·——· ——— ·—— · ·—·';
	@override String get powerUnit => '·——';
	@override String get controlSettings => '·—·· ——— ——· ——· ·· —· ——· / —·—· ——— —· — ·—· ——— ·—·· ···';
	@override String get spottingControl => '··· ·——· ——— — — ·· —· ——·';
	@override String get spottingSelfControl => '··· · ·—·· ··—· —····— ··· ·——· ——— — — ·· —· ——·';
	@override String spotSelfAt({required Object freq}) => '··· · ·—·· ··—· —····— ··· ·——· ——— — / ·— — / ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => '··· ·——· ——— — / ${call} / ·— — / ${freq}';
	@override String spotTooLate({required Object call}) => '— ——— ——— / ·—·· ·— — · / — ——— / ··· ·——· ——— — / ${call}';
	@override String get spotNoFreq => '··—· ·· ·—· ··· — / ··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ··· ·——· ——— —';
	@override String get spotComment => '—·—· ——— —— —— · —· —';
	@override String get spottingAutoControl => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— —';
	@override String spotAutoEvery({required Object minutes}) => '·—· · —····— ··· ·——· ——— — / · ···— · ·—· —·—— / ${minutes} / —— ·· —·';
	@override String spotAutoNext({required Object time}) => '·— ··— — ——— / ·· —· / ${time} ·—·—·— / ··· — ——— ·——· ··——··';
	@override String spotAutoInMinutes({required Object minutes}) => '·— ··— — ——— / ·· —· / ${minutes} ——';
	@override String spotAutoInSeconds({required Object seconds}) => '·— ··— — ——— / ·· —· / ${seconds} ···';
	@override String spotAutoInCount({required Object seconds}) => '·— ··— — ——— / ·· —· / ${seconds}';
	@override String get spotAutoNotStarted => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —· ——— — / ··· — ·— ·—· — · —·· ———··· / — ···· · / ··· ·——· ——— — / —·· ·· —·· / —· ——— — / ——· ——— / — ···· ·—· ——— ··— ——· ····';
	@override String get spotAutoMoved => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —· ——— — / ··· — ·— ·—· — · —·· ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ···· ·— —· ——· · —·· / ·—— ···· ·· ·—·· · / ··· ·——· ——— — — ·· —· ——·';
	@override String get spotAutoStopped => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —··';
	@override String get spotAutoLeftFreq => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —·· ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ···· ·— —· ——· · —··';
	@override String get spotAutoNoFreq => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —·· ———··· / — ···· · / ·—· ·— —·· ·· ——— / ·—· · ·——· ——— ·—· — ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get spotBusy => '·— —· ——— — ···· · ·—· / ··· ·——· ——— — / ·· ··· / ··· — ·· ·—·· ·—·· / —··· · ·· —· ——· / ··· · —· —';
	@override String get bandOrFreqRequired => '··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— ·—· / —··· ·— —· —·· / —··· · ··—· ——— ·—· · / ·—·· ——— ——· ——· ·· —· ——·';
	@override String get missingBand => '—· ——— / —··· ·— —· —··';
	@override String get missingMode => '—· ——— / —— ——— —·· ·';
	@override String saveFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— ···— · ———··· / ${error}';
	@override String deleteFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —·· · ·—·· · — · ———··· / ${error}';
	@override late final _Translations$loggingControls$info$cw info = _Translations$loggingControls$info$cw._(_root);
}

// Path: formChrome
class _Translations$formChrome$cw extends Translations$formChrome$en {
	_Translations$formChrome$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get untitled => '—·——· ··— —· — ·· — ·—·· · —·· —·——·—';
	@override String get showMore => '··· ···· ——— ·—— / —— ——— ·—· ·';
	@override String get showAll => '··· ···· ——— ·—— / ·— ·—·· ·—··';
	@override String get showFewer => '··· ···· ——— ·—— / ··—· · ·—— · ·—·';
	@override String get defaults => '—·· · ··—· ·— ··— ·—·· — ···';
	@override String get search => '··· · ·— ·—· —·—· ····';
	@override String get clear => '—·—· ·—·· · ·— ·—·';
	@override String get openPage => '——— ·——· · —· / ·——· ·— ——· ·';
	@override String get connected => '—·—· ——— —· —· · —·—· — · —··';
	@override String get notConnected => '—· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get manage => '—— ·— —· ·— ——· ·';
	@override String get connect => '—·—· ——— —· —· · —·—· —';
	@override String get formTitle => '··—· ——— ·—· ——';
	@override String addItem({required Object label}) => '·— —·· —·· / ${label}';
	@override String editItem({required Object label}) => '· —·· ·· — / ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => '··· ···· ——— ·—— ·· —· ——· / ${shown} / ——— ··—· / ${total} / —·——· ${selected} / ··· · ·—·· · —·—· — · —·· —·——·—';
	@override String validationError({required Object error}) => '···— ·— ·—·· ·· —·· ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}';
	@override String transformationError({required Object error}) => '— ·—· ·— —· ··· ··—· ——— ·—· —— ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}';
	@override String actionError({required Object error}) => '· ·—· ·—· ——— ·—· ———··· / ${error}';
	@override String get removeItem => '—·· · ·—·· · — ·';
	@override String deleteItemTitle({required Object name}) => '—·· · ·—·· · — · / ${name} ··——··';
	@override String get storageUnavailable => '·—·· ——— ——· ·· —· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$cw extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '· —·· ·· — / ——·— ··· ———';
	@override String get operatorCall => '——— ·——· · ·—· ·— — ——— ·—·';
	@override String get position => '·——· ——— ··· ·· — ·· ——— —·';
	@override String get theirName => '—· ·— —— ·';
	@override String get theirGrid => '——· ·—· ·· —··';
	@override String get theirState => '··· — ·— — ·';
	@override String get band => '—··· ·— —· —··';
	@override String get notes => '—· ——— — · ···';
	@override String get sectionQso => '——·— ··· ———';
	@override String get sectionTheir => '— ···· · ·· ·—· / ·· —· ··—· ———';
	@override String get sectionOur => '——— ··— ·—· / ·· —· ··—· ———';
	@override String get sectionNotes => '—· ——— — · ···';
	@override String get theirCity => '—·—· ·· — —·——';
	@override String get theirCounty => '—·—· ——— ··— —· — —·——';
	@override String get theirEntity => '· —· — ·· — —·——';
	@override String get theirCqZone => '—·—· ——·— / ——·· ——— —· ·';
	@override String get theirItuZone => '·· — ··— / ——·· ——— —· ·';
	@override String get theirArrlSection => '·— ·—· ·—· ·—·· / ··· · —·—· — ·· ——— —·';
	@override String get theirLat => '·—·· ·— — ·· — ··— —·· ·';
	@override String get theirLon => '·—·· ——— —· ——· ·· — ··— —·· ·';
	@override String get theirPower => '— ···· · ·· ·—· / ·——· ——— ·—— · ·—·';
}

// Path: qsoList
class _Translations$qsoList$cw extends Translations$qsoList$en {
	_Translations$qsoList$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get empty => '—· ——— / ——·— ··· ——— ··· / —·—— · — / — / ·—— ——— ·—· —·— / ··· ——— —— · ——— —· · —·—·——';
	@override String get bandOrModeWarning => '·——· ·—·· · ·— ··· · / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / —··· ·— —· —·· / ·— —· —·· / —— ——— —·· · / ·— ·—· · / —·—· ——— ·—· ·—· · —·—· —';
	@override String get today => '— ——— —·· ·— —·——';
	@override String get yesterday => '—·—— · ··· — · ·—· —·· ·— —·——';
	@override String get tomorrow => '— ——— —— ——— ·—· ·—· ——— ·——';
	@override late final _Translations$qsoList$find$cw find = _Translations$qsoList$find$cw._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$cw extends Translations$loggingPanel$en {
	_Translations$loggingPanel$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get stats => '——— ·——· · ·—· ·— — ·· ——— —· / ··· — ·— — ···';
	@override String get scoring => '··· —·—· ——— ·—· ·· —· ——·';
	@override String get dxccEntities => '—·· —··— —·—· —·—· / · —· — ·· — ·· · ···';
	@override String get statesWorked => '··· — ·— — · ···';
	@override String get provincesWorked => '·——· ·—· ——— ···— ·· —· —·—· · ···';
	@override String get duplicates => '—·· ··— ·——· ·—·· ·· —·—· ·— — · ···';
}

// Path: callInfo
class _Translations$callInfo$cw extends Translations$callInfo$en {
	_Translations$callInfo$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get qrz => '——·— ·—· ——··';
	@override String get showImage => '··· ···· ——— ·—— / ·· —— ·— ——· ·';
	@override String get imageUnavailable => '·——· ···· ——— — ——— / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get photo => '·——· ···· ——— — ———';
	@override String get notes => '—· ——— — · ···';
	@override String distanceTo({required Object distance}) => '${distance} / — ———';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / — ———';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / — ———';
	@override String distanceAway({required Object distance}) => '${distance} / ·— ·—— ·— —·——';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / ·— ·—— ·— —·——';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / ·— ·—— ·— —·——';
	@override String get thisOpCountOne => '·———— / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String thisOpCountOther({required Object count}) => '${count} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get otherOpsCountOne => '·———— / ——·— ··· ——— / ·· —· / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String otherOpsCountOther({required Object count}) => '${count} / ——·— ··· ——— ··· / ·· —· / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String andMore({required Object count}) => '… / ·— —· —·· / ${count} / —— ——— ·—· ·';
	@override String withCall({required Object call}) => '·—— ·· — ···· / ${call}';
	@override String fromOperation({required Object where}) => '··—· ·—· ——— —— / ${where}';
	@override late final _Translations$callInfo$history$cw history = _Translations$callInfo$history$cw._(_root);
}

// Path: settings
class _Translations$settings$cw extends Translations$settings$en {
	_Translations$settings$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· · — — ·· —· ——· ···';
	@override String get language => '·—·· ·— —· ——· ··— ·— ——· ·';
	@override String languageSystem({required Object language}) => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / —·——· ${language} —·——·—';
	@override late final _Translations$settings$theme$cw theme = _Translations$settings$theme$cw._(_root);
	@override late final _Translations$settings$themeDescription$cw themeDescription = _Translations$settings$themeDescription$cw._(_root);
	@override String get fontScale => '··—· ——— —· — / ··· —·—· ·— ·—·· ·';
	@override late final _Translations$settings$fontScaleOpts$cw fontScaleOpts = _Translations$settings$fontScaleOpts$cw._(_root);
	@override late final _Translations$settings$keepDeviceAwake$cw keepDeviceAwake = _Translations$settings$keepDeviceAwake$cw._(_root);
	@override String get layoutDensity => '·—·· ·— —·—— ——— ··— — / —·· · —· ··· ·· — —·——';
	@override late final _Translations$settings$layoutDensityOpts$cw layoutDensityOpts = _Translations$settings$layoutDensityOpts$cw._(_root);
	@override String layoutDensityClamped({required Object effective}) => '— ···· · / ·—— ·· —· —·· ——— ·—— / ·· ··· / — ——— ——— / ··· ···· ——— ·—· — ——··—— / ··— ··· ·· —· ——· / ${effective}';
	@override String get layoutDensityAtLimit => '·— ··· / ··—· ·— ·—· / ·— ··· / ·· — / ——· ——— · ···';
	@override String get distanceUnits => '—·· ·· ··· — ·— —· —·—· · / ··— —· ·· — ···';
	@override late final _Translations$settings$distanceUnitsOpts$cw distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$cw._(_root);
	@override String get userInterface => '··— ··· · ·—· / ·· —· — · ·—· ··—· ·— —·—· ·';
	@override late final _Translations$settings$logging$cw logging = _Translations$settings$logging$cw._(_root);
	@override late final _Translations$settings$catServer$cw catServer = _Translations$settings$catServer$cw._(_root);
	@override late final _Translations$settings$cluster$cw cluster = _Translations$settings$cluster$cw._(_root);
	@override late final _Translations$settings$spotting$cw spotting = _Translations$settings$spotting$cw._(_root);
	@override late final _Translations$settings$radio$cw radio = _Translations$settings$radio$cw._(_root);
	@override late final _Translations$settings$help$cw help = _Translations$settings$help$cw._(_root);
	@override late final _Translations$settings$exports$cw exports = _Translations$settings$exports$cw._(_root);
	@override late final _Translations$settings$extensionSections$cw extensionSections = _Translations$settings$extensionSections$cw._(_root);
	@override late final _Translations$settings$map$cw map = _Translations$settings$map$cw._(_root);
	@override late final _Translations$settings$privacy$cw privacy = _Translations$settings$privacy$cw._(_root);
	@override String get operatorCall => '——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override late final _Translations$settings$sync$cw sync = _Translations$settings$sync$cw._(_root);
	@override late final _Translations$settings$peers$cw peers = _Translations$settings$peers$cw._(_root);
	@override String get developerMode => '—·· · ···— · ·—·· ——— ·——· · ·—· / —— ——— —·· ·';
	@override late final _Translations$settings$syncPanel$cw syncPanel = _Translations$settings$syncPanel$cw._(_root);
	@override late final _Translations$settings$accounts$cw accounts = _Translations$settings$accounts$cw._(_root);
	@override late final _Translations$settings$station$cw station = _Translations$settings$station$cw._(_root);
	@override late final _Translations$settings$offlineData$cw offlineData = _Translations$settings$offlineData$cw._(_root);
	@override late final _Translations$settings$profiles$cw profiles = _Translations$settings$profiles$cw._(_root);
	@override late final _Translations$settings$search$cw search = _Translations$settings$search$cw._(_root);
	@override late final _Translations$settings$developer$cw developer = _Translations$settings$developer$cw._(_root);
	@override late final _Translations$settings$about$cw about = _Translations$settings$about$cw._(_root);
	@override late final _Translations$settings$panels$cw panels = _Translations$settings$panels$cw._(_root);
	@override String get showMoreSettings => '··· ···· ——— ·—— / —— ——— ·—· · / ··· · — — ·· —· ——· ···';
	@override String get numberFormat => '—· ··— —— —··· · ·—· / ··—· ——— ·—· —— ·— — — ·· —· ——·';
	@override late final _Translations$settings$numberFormatOpts$cw numberFormatOpts = _Translations$settings$numberFormatOpts$cw._(_root);
	@override late final _Translations$settings$numberFormatDescription$cw numberFormatDescription = _Translations$settings$numberFormatDescription$cw._(_root);
	@override late final _Translations$settings$numberFormatSeparators$cw numberFormatSeparators = _Translations$settings$numberFormatSeparators$cw._(_root);
	@override String get gridPrecision => '——· ·—· ·· —·· / ·——· ·—· · —·—· ·· ··· ·· ——— —·';
	@override late final _Translations$settings$gridPrecisionOpts$cw gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$cw._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$cw gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$cw._(_root);
}

// Path: commands
class _Translations$commands$cw extends Translations$commands$en {
	_Translations$commands$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => '· —· ·— —··· ·—·· · / ··· —·—— —· —·—· / ·· —· / ··· · — — ·· —· ——· ··· / ··—· ·· ·—· ··· — ·—·—·—';
	@override String get fullResyncStarted => '··—· ··— ·—·· ·—·· / ·—· · ··· —·—— —· —·—· / ··· — ·— ·—· — · —·· / — / ·—·· ——— —·—· ·— ·—·· / —·· ·— — ·— / ·—— ·— ··· / —··· ·— —·—· —·— · —·· / ··— ·——· / ··—· ·· ·—· ··· — ·—·—·—';
	@override String noDataFilesMatched({required Object target}) => '—· ——— / —·· ·— — ·— / ··—· ·· ·—·· · ··· / —— ·— — —·—· ···· · —·· / ·—··—· ${target} ·—··—· ·—·—·—';
	@override String reloadFailed({required Object error}) => '·—· · ·—·· ——— ·— —·· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override String get reloadingAll => '·—· · ·—·· ——— ·— —·· ·· —· ——· / ·— ·—·· ·—·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· …';
	@override String reloadingTarget({required Object target}) => '·—· · ·—·· ——— ·— —·· ·· —· ——· / ${target} / —·· ·— — ·— / ··—· ·· ·—·· · ··· …';
	@override String unknownExperiment({required Object token}) => '··— —· —·— —· ——— ·—— —· / · —··— ·——· · ·—· ·· —— · —· — / ·—··—· ${token} ·—··—·';
	@override String experimentEnabled({required Object name}) => '${name} / · —· ·— —··· ·—·· · —··';
	@override String experimentDisabled({required Object name}) => '${name} / —·· ·· ··· ·— —··· ·—·· · —··';
	@override String get sentryTestSent => '— · ··· — / · ·—· ·—· ——— ·—· / ·—· · ·——· ——— ·—· — / ··· · —· — / — ——— / ··· · —· — ·—· —·——';
	@override String get idleMetricsEnabled => '·· —·· ·—·· · / —— · — ·—· ·· —·—· ··· / · —· ·— —··· ·—·· · —·· / ·· —· / — ···· · / ··· — ·— — ··— ··· / —··· ·— ·—·';
	@override String get idleMetricsDisabled => '·· —·· ·—·· · / —— · — ·—· ·· —·—· ··· / —·· ·· ··· ·— —··· ·—·· · —··';
	@override String get sentryTestLocalOnly => '··· · —· — ·—· —·—— / ·· ··· / —·· ·· ··· ·— —··· ·—·· · —·· / ·· —· / — ···· ·· ··· / —··· ··— ·· ·—·· —·· / — / — · ··· — / · ·—· ·—· ——— ·—· / ·—·· ——— ——· ——· · —·· / ·—·· ——— —·—· ·— ·—·· ·—·· —·—— / ——— —· ·—·· —·——';
	@override String get noOperationOpen => '— ···· ·— — / —·—· ——— —— —— ·— —· —·· / —· · · —·· ··· / ·— —· / ——— ·——· · —· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String unknownSegmentKind({required Object kind}) => '—·· ——— —· ·————· — / —·— —· ——— ·—— / ···· ——— ·—— / — ——— / —— ·— ·—· —·— / ·— / ·————· ${kind} ·————·';
	@override String goUnavailable({required Object place}) => '${place} / ·· ··· —· ·————· — / — ··— ·—· —· · —·· / ——— —· / ·· —· / — ···· ·· ··· / ·— ·——· ·——·';
	@override String goUnknown({required Object to}) => '—·· ——— —· ·————· — / —·— —· ——— ·—— / ···· ——— ·—— / — ——— / ——· ——— / — ——— / ·————· ${to} ·————·';
	@override String get goBlocked => '—·—· ·—·· ——— ··· · / — ···· · / ——— ·——· · —· / —·· ·· ·— ·—·· ——— ——· / ··—· ·· ·—· ··· —';
	@override String get operationAlreadyStarted => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / ·— / ··· — ·— ·—· — / —— ·— ·—· —·— · ·—·';
	@override String get couldNotOpenLocation => '·— —·· —·· · —·· / — ···· · / —··· ·—· · ·— —·— ——··—— / —··· ··— — / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / — ···· · / ·—·· ——— —·—· ·— — ·· ——— —· / ··· —·—· ·—· · · —·';
	@override String get noTestOperations => '—· ——— / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — ——— / ·——· ··— ·—· ——· ·';
	@override String get purgeTestsUnavailable => '·——· ··— ·—· ——· · — · ··· — ··· / —· · · —·· ··· / — ——— / ··· ···· ——— ·—— / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·· ·· ·— ·—·· ——— ——· ——··—— / ·—— ···· ·· —·—· ···· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· ·';
	@override String get syncAllUnavailable => '··· —·—— —· —·—· ·— ·—·· ·—·· / —· · · —·· ··· / — ——— / ··· ···· ——— ·—— / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·· ·· ·— ·—·· ——— ——· ——··—— / ·—— ···· ·· —·—· ···· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· ·';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —·',
		other: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ···',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '·——· ··— ·—· ——· · —·· / ${purged} / ——— ··—· / ${total} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ···· · / ·—· · ··· — / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·——· ··— ·—· ——· · — · ··· — ··· / ·— ——· ·— ·· —·';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —·',
		other: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —·',
	);
	@override String get purgeTestsContactsFailed => '·——· ··— ·—· ——· · —·· / — ···· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / —··· ··— — / — ···· · / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·——· ··— ·—· ——· · — · ··· — ··· / ·— ——· ·— ·· —·';
	@override String get purgeTestsNothingToDo => '—· ——— — ···· ·· —· ——· / ·—— ·— ··· / ·——· ··— ·—· ——· · —··';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '·—· · —— ——— ···— · —·· / ${removed} / ——— ··—· / ${total} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ···· · / ·—· · ··· — / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·—· · ···— ·· · ·—— / ·— ——· ·— ·· —·';
	@override String get receivedPurgesFailed => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · —— ——— ···— · / — ···· ——— ··· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ·—· —·—— / ·—· · ···— ·· · ·—— / ·— ——· ·— ·· —·';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· / ·—— ·— ··· / ·—· · —— ——— ···— · —·· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·',
		other: '${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·—— · ·—· · / ·—· · —— ——— ···— · —·· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·',
	);
	@override String get receivedPurgesReview => '·—· · ···— ·· · ·——';
	@override String get settingOn => '——— —·';
	@override String get settingOff => '——— ··—· ··—·';
	@override String get settingEmpty => '—·——· · —— ·——· — —·—— —·——·—';
	@override String get settingSecretSet => '—·——· ··· · — —·——·—';
	@override String get settingSecretUnset => '—·——· —· ——— — / ··· · — —·——·—';
	@override String settingSelectedCount({required Object count}) => '${count} / ··· · ·—·· · —·—· — · —··';
	@override String get settingExpectsOnOff => '——— —· / ——— ·—· / ——— ··—· ··—·';
	@override String settingExpectsOneOf({required Object choices}) => '——— —· · / ——— ··—· ———··· / ${choices}';
	@override String get settingExpectsNumber => '·— / —· ··— —— —··· · ·—·';
	@override String settingVanished({required Object label}) => '“ ${label} ” / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get noCwKeyer => '—· ——— / —·—· ——— —· —· · —·—· — · —·· / ·—· ·— —·· ·· ——— / —·—· ·— —· / —·— · —·—— / —·—· ·——';
	@override String get noKeyer => '—· ——— / —·—· ——— —· —· · —·—· — · —·· / ·—· ·— —·· ·· ——— / —·—· ·— —· / —·— · —·—— / —·—· ·—— / ——— ·—· / ·——· ·—·· ·— —·—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···';
	@override String get keyerNeedsOperation => '——— ·——· · —· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / — ——— / ··— ··· · / — ···· · / —·—· ·—— / —·— · —·—— · ·—·';
	@override String get keyerExperimentOff => '—·—· ·—— / —·— · —·—— ·· —· ——· / ·· ··· / ——— ··—· ··—· / — / — ··— ·—· —· / ·· — / ——— —· / ·—— ·· — ···· / · —··— ·——· / —·— · —·—— · ·—·';
	@override String get esmExperimentOff => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· / ·· ··· / ——— ··—· ··—· / — / — ··— ·—· —· / ·· — / ——— —· / ·—— ·· — ···· / · —··— ·——· / · ··· ——';
	@override String cwSending({required Object text}) => '··· · —· —·· ·· —· ——· / —·—· ·—— ———··· / ${text}';
	@override String cwMessageError({required Object n, required Object error}) => '—·—· ·—— / —— · ··· ··· ·— ——· · / ··—· ${n} ———··· / ${error}';
	@override String cwMessageNotRendered({required Object n}) => '—·—· ·—— / —— · ··· ··· ·— ——· · / ··—· ${n} / ·—— ·— ··· / —· ——— — / ··· · —· — ———··· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —· ——— — / ·—· · ·— —·· —·——';
	@override String settingNotStored({required Object label}) => '“ ${label} ” / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· ·— — / ···— ·— ·—·· ··— ·';
}

// Path: commandDialog
class _Translations$commandDialog$cw extends Translations$commandDialog$en {
	_Translations$commandDialog$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get hint => '··· · ·— ·—· —·—· ···· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· / ——— ·—· / — —·—— ·——· · / ·— / —·—· ——— —— —— ·— —· —··';
	@override String noResults({required Object text}) => '—· ——— — ···· ·· —· ——· / —— ·— — —·—· ···· · ··· / “ ${text} ”';
	@override String get sectionCommands => '—·—· ——— —— —— ·— —· —·· ···';
	@override String get sectionGoTo => '——· ——— / — ———';
	@override String get sectionOperations => '——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String get goHome => '···· ——— —— ·';
	@override String get goSettings => '··· · — — ·· —· ——· ···';
	@override String get goNewOperation => '—· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String runTyped({required Object text}) => '·—· ··— —· / “ ${text} ”';
	@override String get sectionSuggestions => '— ·—· —·——';
	@override String get lookingUp => '·—·· ——— ——— —·— ·· —· ——· / ··— ·——· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· …';
	@override String get blockedByPane => '—·—· ·— —· —· ——— — / ··— ··· · / —·—· ——— —— —— ·— —· —·· ··· / ·—— ···· ·· ·—·· · / ·— / ·——· ·— —· · ·—·· / ——— ·—· / —·· ·· ·— ·—·· ——— ——· / ·· ··· / ——— ·——· · —·';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$cw extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·— · —·—— —··· ——— ·— ·—· —·· / ··· ···· ——— ·—· — —·—· ··— — ···';
	@override String get description => '—·—· ··— ··· — ——— —— ·· ——·· · / —·— · —·—— / —— ·— ·——· ·——· ·· —· ——· ···';
	@override String get search => '··· · ·— ·—· —·—· ···· / —·—· ——— —— —— ·— —· —·· ··· / ·— —· —·· / —·— · —·—— ···';
	@override String get import => '·· —— ·——· ——— ·—· — …';
	@override String get export => '· —··— ·——· ——— ·—· — …';
	@override String get resetAll => '·—· · ··· · — / ·— ·—·· ·—··';
	@override String get resetAllTitle => '·—· · ··· · — / · ···— · ·—· —·—— / ··· ···· ——— ·—· — —·—· ··— — ··——··';
	@override String get resetAllBody => '· ···— · ·—· —·—— / —·—· ——— —— —— ·— —· —·· / ——· ——— · ··· / —··· ·— —·—· —·— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — / —·— · —·—— ··· ——··—— / ·— —· —·· / — ···· · / —·— · —·—— ··· / —··· ——— ··— —· —·· / — ——— / — —·—— ·——· · —·· / —·—· ——— —— —— ·— —· —·· ··· / ·— ·—· · / ·—· · —— ——— ···— · —·· ·—·—·—';
	@override String get reset => '·—· · ··· · —';
	@override String get noKey => '—· ——— / —·— · —·——';
	@override String get changed => '—·—· ···· ·— —· ——· · —··';
	@override String conflict({required Object keys, required Object commands}) => '${keys} / ·· ··· / ·— ·—·· ··· ——— / —··· ——— ··— —· —·· / — ——— / ${commands}';
	@override String get groupApp => '·— ·——· ·——·';
	@override String get groupKeying => '—·— · —·—— ·· —· ——·';
	@override String get groupLogging => '·—·· ——— ——· ——· ·· —· ——·';
	@override String get groupCommands => '—·—· ——— —— —— ·— —· —·· ···';
	@override String get groupFixed => '··—· ·· —··— · —·· / —·— · —·—— ···';
	@override String get contextApp => '·— —· —·—— ·—— ···· · ·—· ·';
	@override String get contextLogView => '——— ·——· · ·—· ·— — ·· ——— —· ——··—— / —·—· ···· ·— ··· ·· —· ——· / ·— —· —·· / ·—·· ——— ——· ··· / ···— ·· · ·—— ···';
	@override String get contextOperation => '——— ·——· · ·—· ·— — ·· ——— —· / ···— ·· · ·—— ——··—— / —·— · —·—— ·· —· ——· / ·— / —·—· ·— — / ·—· ·— —·· ·· ———';
	@override String get contextLogging => '·· —· / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ·——· ·— —· · ·—··';
	@override String get addCommand => '·— —·· —·· / ·— / —·—· ——— —— —— ·— —· —·· …';
	@override String unknownCommand({required Object command}) => '··— —· —·— —· ——— ·—— —· / —·—· ——— —— —— ·— —· —·· ———··· / ${command}';
	@override late final _Translations$keyboardShortcuts$command$cw command = _Translations$keyboardShortcuts$command$cw._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$cw fixed = _Translations$keyboardShortcuts$fixed$cw._(_root);
	@override late final _Translations$keyboardShortcuts$editor$cw editor = _Translations$keyboardShortcuts$editor$cw._(_root);
	@override late final _Translations$keyboardShortcuts$file$cw file = _Translations$keyboardShortcuts$file$cw._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$cw modifier = _Translations$keyboardShortcuts$modifier$cw._(_root);
	@override late final _Translations$keyboardShortcuts$platform$cw platform = _Translations$keyboardShortcuts$platform$cw._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$cw extends Translations$expiredBuild$en {
	_Translations$expiredBuild$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '— ···· ·· ··· / —··· ··— ·· ·—·· —·· / ···· ·— ··· / · —··— ·——· ·· ·—· · —··';
	@override String get body => '·——· ·—·· · ·— ··· · / ···— ·· ··· ·· — / ···· ·— —— ··——— —·— ·—·—·— —·—· ——— —— / ·— —· —·· / ——· · — / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· ·—·—·—';
	@override String get visit => '···— ·· ··· ·· — / ···· ·— —— ··——— —·— ·—·—·— —·—· ——— ——';
	@override String get dismiss => '—·—· ——— —· — ·· —· ··— · / ·— —· —·—— ·—— ·— —·——';
}

// Path: staleness
class _Translations$staleness$cw extends Translations$staleness$en {
	_Translations$staleness$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => '·— —· / ·· —— ·——· ——— ·—· — ·— —· — / ··— ·——· —·· ·— — · / ·· ··· / ·—— ·— ·· — ·· —· ——·';
	@override String get codePushFloorBody => '— ···· ·· ··· / ···— · ·—· ··· ·· ——— —· / ···· ·— ··· / ·— / ··—· ·· —··— / —·—— ——— ··— / —·· ——— —· ·————· — / ···· ·— ···— · / —·—— · — ·—·—·—';
	@override String get restartToApply => '·—· · ··· — ·— ·—· — / — ···· · / ·— ·——· ·——· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—';
	@override String get quitAndReopen => '——·— ··— ·· — / — ···· · / ·— ·——· ·——· / ·— —· —·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—';
	@override String get reopenToApply => '—·—· ·—·· ——— ··· · / — ···· · / ·— ·——· ·——· / ·— —· —·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—';
	@override String get ignoreForNow => '·· ——· —· ——— ·—· · / ··—· ——— ·—· / —· ——— ·——';
}

// Path: spotting
class _Translations$spotting$cw extends Translations$spotting$en {
	_Translations$spotting$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => '—· ——— / ——·— ··· ——— / ·—·· ——— ——· ——· · —·· / —·—— · — / — ——— / ··· ·——· ——— — ·—·—·—';
	@override String get setFrequencyFirst => '··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··—· ·· ·—· ··· — ·—·—·—';
	@override String get nothingToSpot => '—· ——— — ···· ·· —· ——· / — ——— / ··· ·——· ——— — / — / —· ——— / · —··— — · —· ··· ·· ——— —· / ——— ··—· ··—· · ·—· ··· / ··· ·——· ——— — — ·· —· ——· / ···· · ·—· · ·—·—·—';
	@override String get incompleteCall => '—·—· ·— —· ·————· — / ··· ·——· ——— — / ·— —· / ·· —· —·—· ——— —— ·——· ·—·· · — · / —·—· ·— ·—·· ·—·· / — / ··—· ·· —· ·· ··· ···· / — ···· · / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ··—· ·· ·—· ··· — ·—·—·—';
	@override String spotFailed({required Object source, required Object message}) => '${source} / ··—· ·— ·· ·—·· · —·· ———··· / ${message}';
	@override String get unknownError => '··— —· —·— —· ——— ·—— —· / · ·—· ·—· ——— ·—·';
	@override String get notSent => '··· ·——· ——— — / —· ——— — / ··· · —· — ·—·—·—';
	@override String get allSkipped => '··· ·——· ——— — / —· ——— — / ··· · —· — ———··· / · ···— · ·—· —·—— / ··· ·——· ——— — / ··· ——— ··— ·—· —·—· · / ··· —·— ·· ·——· ·——· · —·· / ·· — ·—·—·—';
	@override String get notRefreshedOffline => '—· ——— / —·—· ——— —· —· · —·—· — ·· ——— —· / — / ··· ·——· ——— — ··· / ·—— · ·—· · / —· ——— — / ·—· · ··—· ·—· · ··· ···· · —··';
}

// Path: dataFiles
class _Translations$dataFiles$cw extends Translations$dataFiles$en {
	_Translations$dataFiles$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get downloading => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· …';
	@override String downloadFailedTitle({required Object name}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ${name}';
	@override String get downloadFailedWebHint => '— ···· ·· ··· / —·—· ——— ··— ·—·· —·· / —··· · / ·— / —· · — ·—— ——— ·—· —·— / ·· ··· ··· ··— · ——··—— / ——— ·—· / — ···· ·· ··· / ·—·· ·· —· —·— ·————· ··· / ···· ——— ··· — / —— ·— —·—— / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / —·· ·· ·—· · —·—· — / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / ··—· ·—· ——— —— / ·— / ·—— · —··· / —··· ·—· ——— ·—— ··· · ·—· ·—·—·— / — ·—· —·—— / — ···· · / —·· · ··· —·— — ——— ·——· / ——— ·—· / —— ——— —··· ·· ·—·· · / ·— ·——· ·——· ——··—— / ——— ·—· / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ···· ——— ··· — ·· —· ——· / ·—·· ——— —·—· ·— — ·· ——— —· ·—·—·—';
	@override String get downloadTimedOut => '— ···· · / ··· · ·—· ···— · ·—· / — ——— ——— —·— / — ——— ——— / ·—·· ——— —· ——· / — ——— / ·—· · ··· ·——· ——— —· —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String downloadServerError({required Object host, required Object status}) => '${host} / ·— —· ··· ·—— · ·—· · —·· / ·—— ·· — ···· / ·— —· / · ·—· ·—· ——— ·—· / —·——· ···· — — ·——· / ${status} —·——·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} / —·—· ——— ··— ·—·· —·· —· ·————· — / ·——· ·—· ——— ···— ·· —·· · / — ···· ·· ··· / ··—· ·· ·—·· · / —·——· ···· — — ·——· / ${status} —·——·— ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ·· — ··· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ··· — ·· ·—·· ·—·· / ·—· ·· ——· ···· — ·—·—·—';
	@override String n1mmHistoryNoMatch({required Object stem}) => '—· ·———— —— —— / ···· ·— ··· / —· ——— / —·—· ·— ·—·· ·—·· / ···· ·· ··· — ——— ·—· —·—— / ··—· ·· ·—·· · / ··—· ——— ·—· / ${stem} ·—·—·—';
	@override String n1mmHistoryUnavailable({required Object stem}) => '—· ·———— —— —— ·————· ··· / —·—· ·— ·—·· ·—·· / ···· ·· ··· — ——— ·—· —·—— / —·· ——— ·—— —· ·—·· ——— ·— —·· / ··—· ——— ·—· / ${stem} / —·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String processingFailedTitle({required Object name}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·——· ·—· ——— —·—· · ··· ··· / ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => '— ···· · / —·· ——— ·—— —· ·—·· ——— ·— —·· / ···· ·— —·· / ——— —· ·—·· —·—— / ${imported} / ——— ··—· / — ···· · / ${existing} / ·—· · —·—· ——— ·—· —·· ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / ··· ——— / — ···· · / ——— —· · ··· / ·· — / ·—·· · ··—· — / ——— ··— — / ·—— · ·—· · / —·— · ·——· — ·—·—·— / ·—· · ··—· ·—· · ··· ···· ·· —· ——· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— / ·— —·—· —·—· · ·——· — ··· / ·· — / ·— —· —·—— ·—— ·— —·—— ·—·—·—';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·· —— ·——· ——— ·—· — · —·· / ${count} / ·—· · —·—· ——— ·—· —·· / ··—· ——— ·—· / ${label} ·—·—·—',
		other: '·· —— ·——· ——— ·—· — · —·· / ${count} / ·—· · —·—· ——— ·—· —·· ··· / ··—· ——— ·—· / ${label} ·—·—·—',
	);
	@override String importedData({required Object label}) => '·· —— ·——· ——— ·—· — · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${label} ·—·—·—';
	@override String get cleanedUpTitle => '—·—· ·—·· · ·— —· · —·· / ··— ·——· / · —··— — · —· ··· ·· ——— —· / —·· ·— — ·—';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·—· · —— ——— ···— · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${count} / —·· ·— — ·— / ··—· ·· ·—·· · / ··—· ·—· ——— —— / —·· ·· ··· ·— —··· ·—·· · —·· / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—',
		other: '·—· · —— ——— ···— · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${count} / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ··—· ·—· ——— —— / —·· ·· ··· ·— —··· ·—·· · —·· / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / —··—· / ${total} / ·—· · —·—· ——— ·—· —·· ···';
	@override String get definitionUnavailable => '— ···· · / ··—· ·· ·—·· · ·————· ··· / ··· ——— ··— ·—· —·—· · / —·· ·· —·· —· ·————· — / ·——· ·—· ——— ···— ·· —·· · / ·— / —·· · ··—· ·· —· ·· — ·· ——— —· / — / ·· — ··· / · —··— — · —· ··· ·· ——— —· / —— ·— —·—— / —··· · / —— ·· —·· —····— ·—· · ··· — ·— ·—· — / ——— ·—· / —— ·· ··· —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—';
}

// Path: updates
class _Translations$updates$cw extends Translations$updates$en {
	_Translations$updates$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => '··— ·——· —·· ·— — · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String newVersionAvailable({required Object version}) => '·— / —· · ·—— / ···— · ·—· ··· ·· ——— —· / —·——· ${version} —·——·— / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · ·—·—·—';
	@override String get getIt => '——· · — / ·· —';
	@override String get ok => '——— —·—';
	@override String get updateReady => '··— ·——· —·· ·— — · / ·—· · ·— —·· —·——';
	@override String get restartToApply => '·— —· / ··— ·——· —·· ·— — · / ···· ·— ··· / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· ·—·—·— / ·—· · ··· — ·— ·—· — / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—';
	@override String get appliesNextLaunch => '·— —· / ··— ·——· —·· ·— — · / ···· ·— ··· / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· ·—·—·— / ·· — / ·—— ·· ·—·· ·—·· / ·— ·——· ·——· ·—·· —·—— / — ···· · / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—';
	@override String get restartNow => '·—· · ··· — ·— ·—· — / —· ——— ·——';
	@override String get reloadToUpdate => '·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· ·· ··· / ·——· ·— ——· · / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · ·—·—·— / ·—· · ·—·· ——— ·— —·· / — ——— / ——· · — / ·· — ·—·—·—';
	@override String get reloadNow => '·—· · ·—·· ——— ·— —·· / —· ——— ·——';
	@override String get checkForUpdates => '—·—· ···· · —·—· —·— / ··—· ——— ·—· / ··— ·——· —·· ·— — · ···';
	@override String get checkingForUpdates => '—·—· ···· · —·—· —·— ·· —· ——· / ··—· ——— ·—· / ··— ·——· —·· ·— — · ··· …';
	@override String get upToDate => '··— ·——· / — ——— / —·· ·— — ·';
	@override String get automaticChecks => '—·—· ···· · —·—· —·— / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——';
	@override String get automaticChecksDescription => '·—·· ——— ——— —·— / ··—· ——— ·—· / —· · ·—— / ···— · ·—· ··· ·· ——— —· ··· / ·· —· / — ···· · / —··· ·— —·—· —·— ——· ·—· ——— ··— —· —·· ——··—— / ··—· ·—· ——— —— / — ···· · / —· · —··— — / — ·· —— · / —·—— ——— ··— / ··· — ·— ·—· — / — ···· · / ·— ·——· ·——·';
}

// Path: extensionService
class _Translations$extensionService$cw extends Translations$extensionService$en {
	_Translations$extensionService$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => '· —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / —· ——— — / ·—· · ·— —·· —·—— ·—·—·—';
	@override String testFailed({required Object error}) => '— · ··· — / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override String connectedAs({required Object identity}) => '—·—· ——— —· —· · —·—· — · —·· / ·— ··· / ${identity}';
	@override String get invalidFieldConfiguration => '·· —· ···— ·— ·—·· ·· —·· / ··—· ·· · ·—·· —·· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get invalidValue => '·· —· ···— ·— ·—·· ·· —·· / ···— ·— ·—·· ··— ·';
	@override String validationError({required Object error}) => '···— ·— ·—·· ·· —·· ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}';
	@override String actionFailed({required Object error}) => '·— —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override String get commandFailed => '— ···· · / —·—· ——— —— —— ·— —· —·· / ··—· ·— ·· ·—·· · —·· / — ——— / ·—· ··— —·';
	@override String get reportUnavailable => '·—· · ·——· ——— ·—· — ··· / —·—· ·— —· ·————· — / —··· · / ··· · —· — / ·—· ·· ——· ···· — / —· ——— ·——';
	@override String get stashUnavailable => '···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· / ·—· ·· ——· ···· — / —· ——— ·——';
	@override String timersSuspendedBudget({required Object name}) => '${name} / ··· ·——· · —· — / — ——— ——— / —— ··— —·—· ···· / — ·· —— · / ·· —· / ·· — ··· / — ·· —— · ·—· ··· ·—·—·— / — ···· · —·—— ·————· ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—';
	@override String timersSuspendedFailures({required Object name}) => '${name} ·————· ··· / — ·· —— · ·—· ··· / —·— · ·——· — / ··—· ·— ·· ·—·· ·· —· ——· ·—·—·— / — ···· · —·—— ·————· ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} / ——· ——— — / ··· — ··— —·—· —·— / ·· —· / ·— / — ·· —— · ·—· ·—·—·— / ·· — ··· / — ·· —— · ·—· ··· / ·— ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$cw extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '——— ·——· · ·—· ·— — ·· ——— —· / ·—·· ——— —·—· ·— — ·· ——— —·';
	@override String get selectedLocation => '··· · ·—·· · —·—· — · —·· / ·—·· ——— —·—· ·— — ·· ——— —·';
	@override String get gridSquare => '—— ·— ·· —·· · —· ···· · ·— —·· / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / ·—·· ——— —·—· ·— — ——— ·—·';
	@override String get gridInvalid => '—· · · —·· ··· / ····— ——··—— / —···· ——··—— / ———·· / ——— ·—· / ·———— ————— / —·—· ···· ·— ·—· ·— —·—· — · ·—· ··· ——··—— / ·—·· ·· —·— · / ··—· —· ···—— ·———— ·——· ·—·';
	@override String get suggestedLocations => '··· ··— ——· ——· · ··· — · —·· / ·—·· ——— —·—· ·— — ·· ——— —· ···';
	@override String get deviceGps => '—·· · ···— ·· —·—· · / ——· ·——· ···';
	@override String peerGps({required Object device}) => '——· ·——· ··· / ··—· ·—· ——— —— / ${device}';
	@override String get locating => '·—·· ——— —·—· ·— — ·· —· ——· …';
	@override String get gpsUnavailable => '·—·· ——— —·—· ·— — ·· ——— —· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get permissionDenied => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —·· · —· ·· · —··';
	@override String get permissionBlocked => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —··· ·—·· ——— —·—· —·— · —··';
	@override String get moreDetails => '—— ——— ·—· · / —·· · — ·— ·· ·—·· ···';
	@override String get stateOrProvince => '··· — ·— — · / ——— ·—· / ·——· ·—· ——— ···— ·· —· —·—· · / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—';
	@override String get controlsUnavailableTitle => '·— —·—· — ·· ···— ·· — —·—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get controlsUnavailableReason => '— ···· · ··· · / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— ·—· · / ··· — ·· ·—·· ·—·· / ··— ··· ·— —··· ·—·· · —·—·—· / — ···· · ·· ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· / ·——— ··— ··· — / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—';
	@override String get controlsUnavailableRetry => '·—· · — ·—· —·——';
	@override String get county => '—·—· ——— ··— —· — —·—— / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—';
}

// Path: versionLabel
class _Translations$versionLabel$cw extends Translations$versionLabel$en {
	_Translations$versionLabel$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => '···— · ·—· ··· ·· ——— —· / ${version}';
	@override String patch({required Object patch}) => '·——· ·— — —·—· ···· / ${patch}';
	@override String build({required Object build}) => '—··· ··— ·· ·—·· —·· / ${build}';
}

// Path: notices
class _Translations$notices$cw extends Translations$notices$en {
	_Translations$notices$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => '—· ——— / —· ——— — ·· —·—· · ··· / —·—— · —';
	@override String get webStorageInMemory => '— ···· ·· ··· / —··· ·—· ——— ·—— ··· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·——· ·—· ——— ···— ·· —·· · / ·——· · ·—· ··· ·· ··· — · —· — / ··· — ——— ·—· ·— ——· · / — / — ···· · / ·—·· ——— ——· / ·—·· ·· ···— · ··· / ·· —· / —— · —— ——— ·—· —·—— / ——— —· ·—·· —·—— / ·— —· —·· / ·—— ·· ·—·· ·—·· / —··· · / ·—·· ——— ··· — / ·—— ···· · —· / — ···· ·· ··· / — ·— —··· / —·—· ·—·· ——— ··· · ··· ·—·—·— / ··— ··· · / ·— / —·—· ··— ·—· ·—· · —· — / —·—· ···· ·—· ——— —— · ——··—— / ··—· ·· ·—· · ··—· ——— —··— ——··—— / ··· ·— ··—· ·— ·—· ·· / ——— ·—· / · —·· ——· · ·—·—·—';
	@override String get webStorageUnreliable => '— ···· ·· ··· / —··· ·—· ——— ·—— ··· · ·—· / ·· ··· / ··— ··· ·· —· ——· / ··—· ·— ·—·· ·—·· —··· ·— —·—· —·— / ··· — ——— ·—· ·— ——· · / — ···· ·— — / ·· ··· / —· ——— — / ··· ·— ··—· · / ·—— ·· — ···· / —— ··— ·—·· — ·· ·——· ·—·· · / — ·— —··· ··· / — / —·— · · ·——· / ·— / ··· ·· —· ——· ·—·· · / — ·— —··· / ——— ·——· · —· ——··—— / ·— —· —·· / —·— · · ·——· / ··· —·—— —· —·—· / ——— —· ·—·—·—';
	@override String get logFromNewerBuildTitle => '— ···· ·· ··· / ·—·· ——— ——· / —· · · —·· ··· / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —·';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => '—·—— ——— ··— ·—· / ·—·· ——— ——· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— ·—·· ——— / —·——· ··· — ——— ·—· ·— ——· · / ···— · ·—· ··· ·· ——— —· / ${storage} —·—·—· / — ···· ·· ··· / ——— —· · / ··— —· —·· · ·—· ··· — ·— —· —·· ··· / ${understood} —·——·— ——··—— / ··· ——— / ·· — / —·—· ·— —· —· ——— — / —··· · / ——— ·——· · —· · —·· ——··—— / ·— —· —·· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· ·—·· ·—·· / —· ——— — / —··· · / ··· ·— ···— · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / — ···· · / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ·— ——· ·— ·· —· / — / ——— ·—· ——··—— / ·· ··—· / —·—— ——— ··— / —— · ·— —· — / — ——— / ·—· ··— —· / — ···· ·· ··· / —··· ··— ·· ·—·· —·· ——··—— / ·——· ——— ·· —· — / ·· — / ·— — / ·— / —·· ·· ··—· ··—· · ·—· · —· — / —·· ·— — ·— / ··—· ——— ·—·· —·· · ·—· ·—·—·— / — ···· · / ·—·· ——— ——· / ·· ··· / ·· —· / ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => '—·—— ——— ··— ·—· / ·—·· ——— ——· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— ·—·· ——— / —·——· ··· — ——— ·—· ·— ——· · / ···— · ·—· ··· ·· ——— —· / ${storage} —·—·—· / — ···· ·· ··· / ——— —· · / ··— —· —·· · ·—· ··· — ·— —· —·· ··· / ${understood} —·——·— ——··—— / ··· ——— / ·· — / —·—· ·— —· —· ——— — / —··· · / ——— ·——· · —· · —·· ——··—— / ·— —· —·· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· ·—·· ·—·· / —· ——— — / —··· · / ··· ·— ···— · —·· ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·—·· ——— ——· / ·—— ·· — ···· / — ···· ·— — / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ·· —· ··· — · ·— —·· ·—·—·—';
	@override String get preferencesRestoredTitle => '··· · — — ·· —· ——· ··· / ·—· · ··· — ——— ·—· · —·· / ··—· ·—· ——— —— / ·— / —··· ·— —·—· —·— ··— ·——·';
	@override String get preferencesRestored => '— ···· · / ··· · — — ·· —· ——· ··· / ··—· ·· ·—·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / ···· ·— ·—·· ——— / ·—· · ··· — ——— ·—· · —·· / — ···· · / ·—·· ·— ··· — / ——· ——— ——— —·· / —·—· ——— ·——· —·—— / ——— ··—· / ·· — ·—·—·— / ·— —· —·—— — ···· ·· —· ——· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· —· / —·—— ——— ··— ·—· / ·——· ·—· · ···— ·· ——— ··— ··· / ··· · ··· ··· ·· ——— —· / —— ·— —·—— / —· · · —·· / ··· · — — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·— / — ···· · / ··— —· ·—· · ·— —·· ·— —··· ·—·· · / ··—· ·· ·—·· · / ·· ··· / —·— · ·——· — / ·— ·—·· ——— —· ——· ··· ·· —·· · / ·· — ——··—— / —· ·— —— · —·· / ··· ···· ·— ·—· · —·· ··——·— ·——· ·—· · ··—· · ·—· · —· —·—· · ··· ·—·—·— —·—· ——— ·—· ·—· ··— ·——· — —····— … ·—·—·— ·——— ··· ——— —· ·—·—·—';
	@override String get preferencesResetTitle => '··· · — — ·· —· ——· ··· / ·—· · ··· · —';
	@override String get preferencesReset => '— ···· · / ··· · — — ·· —· ——· ··· / ··—· ·· ·—·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· / ·— —· —·· / — ···· · ·—· · / ·—— ·— ··· / —· ——— / —··· ·— —·—· —·— ··— ·——· / — ——— / ··—· ·— ·—·· ·—·· / —··· ·— —·—· —·— / ——— —· ——··—— / ··· ——— / ···· ·— ·—·· ——— / ··· — ·— ·—· — · —·· / ·—— ·· — ···· / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·— / — ···· · / ··— —· ·—· · ·— —·· ·— —··· ·—·· · / ··—· ·· ·—·· · / ·· ··· / —·— · ·——· — / ·· —· / — ···· · / ·— ·——· ·——· ·————· ··· / —·· ·— — ·— / ··—· ——— ·—·· —·· · ·—· ——··—— / —· ·— —— · —·· / ··· ···· ·— ·—· · —·· ··——·— ·——· ·—· · ··—· · ·—· · —· —·—· · ··· ·—·—·— —·—· ——— ·—· ·—· ··— ·——· — —····— … ·—·—·— ·——— ··· ——— —· ·—·—·—';
	@override String autoConnectHeldTitle({required Object name}) => '${name} / ·—— ·— ··· / —· ——— — / —·—· ——— —· —· · —·—· — · —·· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——';
	@override String autoConnectHeld({required Object name}) => '···· ·— ·—·· ——— / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — ···· · / ·—·· ·— ··· — / — ·· —— · / ·· — / ··· — ·— ·—· — · —·· / —·—· ——— —· —· · —·—· — ·· —· ——· / — ——— / ${name} ——··—— / ··· ——— / ·· — / ·—·· · ··—· — / ·· — / ·— ·—·· ——— —· · / — ···· ·· ··· / — ·· —— · / ·—· ·— — ···· · ·—· / — ···· ·— —· / ·—· ·· ··· —·— / —·· ——— ·· —· ——· / ·· — / ·— ——· ·— ·· —· ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— —· / ·— —· —·· / ·· — ··· / —·—· ·— —··· ·—·· · / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· ——··—— / — ···· · —· / ·——· ·—· · ··· ··· / —·—· ——— —· —· · —·—· — / ——— —· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· ·—·—·—';
}

// Path: syncAccount
class _Translations$syncAccount$cw extends Translations$syncAccount$en {
	_Translations$syncAccount$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => '·— —· ——— —· —·—— —— ——— ··— ··· / ·— —·—· —·—· ——— ··— —· — / —·——· # ${id} —·——·—';
	@override String pendingConfirmation({required Object email}) => '${email} / —·——· ·——· · —· —·· ·· —· ——· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· —·——·—';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} / —·——· ·——· · —· —·· ·· —· ——· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —····— / # ${id} —·——·—';
}

// Path: deepLink
class _Translations$deepLink$cw extends Translations$deepLink$en {
	_Translations$deepLink$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => '··· — ·— ·—· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·· ·—· ··· — ——··—— / — ···· · —· / ··· · —· —·· / — ···· ·— — / —·—· ——— —· — ·— —·—· — / ·— ——· ·— ·· —·';
	@override String get waitingInOperation => '— ···· ·— — / —·—· ——— —· — ·— —·—· — / ·· ··· / ·—— ·— ·· — ·· —· ——· / ·· —· / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· / —··· · ···· ·· —· —·· / — ···· ·· ··· / ··· —·—· ·—· · · —·';
	@override String unknownActivities({required Object refs}) => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / ·— —·—· — ·· ···— ·· — —·—— / ··—· ——— ·—· / ${refs} ——··—— / ··· ——— / — ···· ——— ··· · / ·—· · ··—· · ·—· · —· —·—· · ··· / ·—— · ·—· · / ·—·· · ··—· — / ——— ··—· ··—·';
	@override String activitiesUnavailable({required Object refs}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·—· ···· / —·—— ——— ··— ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· ——··—— / ··· ——— / ${refs} / ·—— ·— ··· / ·—·· · ··—· — / ——— ··—· ··—· / — / — ·—· —·—— / — ···· ·— — / ·—·· ·· —· —·— / ·— ——· ·— ·· —·';
}

// Path: confirmDevice
class _Translations$confirmDevice$cw extends Translations$confirmDevice$en {
	_Translations$confirmDevice$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ——— —· ··—· ·· ·—· —— / ·— / —·· · ···— ·· —·—· ·';
	@override String get codePrompt => '· —· — · ·—· / — ···· · / —·—· ——— —·· · / ··· ···· ——— ·—— —· / ——— —· / — ···· · / —·· · ···— ·· —·—· · / — ···· ·— — / ·—— ·— —· — ··· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—';
	@override String get code => '—·—· ——— —·· ·';
	@override String get lookUp => '·—·· ——— ——— —·— / ··— ·——·';
	@override String get codeNotFound => '—· ——— / ·—· · ——·— ··— · ··· — / —— ·— — —·—· ···· · ··· / — ···· ·— — / —·—· ——— —·· · ·—·—·— / —·—· ——— —·· · ··· / · —··— ·——· ·· ·—· · / ·— ··—· — · ·—· / ·———— ————— / —— ·· —· ··— — · ··· / — / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / ··—· ——— ·—· / ·— / ··—· ·—· · ··· ···· / ——— —· · ·—·—·—';
	@override String get linkExpired => '— ···· ·— — / ·—·· ·· —· —·— / ···· ·— ··· / · —··— ·——· ·· ·—· · —·· ·—·—·— / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / — ——— / ··· ···· ——— ·—— / ·— / —· · ·—— / ——·— ·—· / —·—· ——— —·· · ·—·—·—';
	@override String areYouSure({required Object device}) => '·—·· ·· —· —·— / ${device} / — ——— / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ··——··';
	@override String get unnamedDevice => '·— —· / ··— —· —· ·— —— · —·· / —·· · ···— ·· —·—· ·';
	@override String get grantWarning => '·· — / ·—— ·· ·—·· ·—·· / —··· · / ·— —··· ·—·· · / — ——— / ·—· · ·— —·· / ·— —· —·· / —·—· ···· ·— —· ——· · / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· ——— —· / ·— —· —·· / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—';
	@override String get needsSyncTitle => '— ···· ·· ··· / —·· · ···— ·· —·—· · / —·· ——— · ··· / —· ——— — / ··· —·—— —· —·—· / —·—— · —';
	@override String get needsSyncText => '— ··— ·—· —· / ——— —· / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / ··· —·—— —· —·—· / ·— —· —·· / ·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ·— —· / ·— —·—· —·—· ——— ··— —· — / —··· · ··—· ——— ·—· · / ·· — / —·—· ·— —· / ·— —·· —— ·· — / ·— —· ——— — ···· · ·—· / ——— —· · ·—·—·—';
	@override String get malformedRequest => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / ··· · —· — / ·— / ·—· · ——·— ··— · ··· — / — ···· ·· ··· / ·— ·——· ·——· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· ·—·—·— / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / — ——— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get linkIt => '·—·· ·· —· —·— / —·· · ···— ·· —·—· ·';
}

// Path: switchAccounts
class _Translations$switchAccounts$cw extends Translations$switchAccounts$en {
	_Translations$switchAccounts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => '—· ——— / ·— —·—· —·—· ——— ··— —· — / —·· · — ·— ·· ·—·· ··· / —·—— · —';
	@override String get currentAccount => '—·—· ··— ·—· ·—· · —· — / ·— —·—· —·—· ——— ··— —· —';
	@override String get otherAccounts => '——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· — ···';
	@override String get linkToAnother => '·—·· ·· —· —·— / — ——— / ·— —· ——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· —';
	@override String get linkWithSibling => '·—·· ·· —· —·— / ·—— ·· — ···· / ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——·';
	@override String get linkWithPolo => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — / ·· —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —·';
	@override String get linkWithSiblingDescription => '—·—— ——— ··— / ···· ·— ···— · / ·— —· ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——· / ·· —· ··· — ·— ·—·· ·—·· · —·· ·—·—·— / ·—·· ·· —· —·— / ·—— ·· — ···· / — ···· · / ·— —·—· —·—· ——— ··— —· — / ·· —· / ··— ··· · / — ···· · ·—· · ·—·—·—';
	@override String siblingPrompt({required Object app}) => '·— ·——· ·——· ·—· ——— ···— · / — ···· · / ·—· · ——·— ··— · ··· — / ·· —· / ${app} ——··—— / — ···· · —· / —·—· ——— —— · / —··· ·— —·—· —·— / ···· · ·—· · ·—·—·—';
	@override String openSiblingAgain({required Object app}) => '——— ·——· · —· / ${app} / ·— ——· ·— ·· —·';
	@override String get siblingNoGrant => '—·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— ··——·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ·—·· ·· —· —·— / ·— —· ——— — ···· · ·—· / ·—— ·— —·—— ·—·—·—';
	@override String siblingOpenFailed({required Object app}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / ${app} ·—·—·—';
	@override String siblingLinkRenewed({required Object app}) => '— ···· · / ·—·· ·· —· —·— / · —··— ·——· ·· ·—· · —·· / ·— —· —·· / ·— / —· · ·—— / ——— —· · / ·· ··· / ·—· · ·— —·· —·—— / — / ——— ·——· · —· / ${app} / ·— ——· ·— ·· —· ·—·—·—';
	@override String get tryAgain => '— ·—· —·—— / ·— ——· ·— ·· —·';
	@override String get linkWithQr => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— / ——·— ·—· / —·—· ——— —·· ·';
	@override String get linkWithQrDescription => '··· —·—· ·— —· / ·· — / ··—· ·—· ——— —— / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ··— ··· ·· —· ——· / — ···· · / ·— —·—· —·—· ——— ··— —· —';
	@override String get linkWithEmail => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ···';
	@override String get linkWithEmailDescription => '—·—· ——— —· ··—· ·· ·—· —— / ·—— ·· — ···· / ·— / —·—· ——— —·· · / ——— ·—· / ·— —· / · —— ·— ·· ·—·· / ·—·· ·· —· —·—';
	@override String get enterEmailPrompt => '· —· — · ·—· / — ···· · / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ——— ··—· / — ···· · / ·— —·—· —·—· ——— ··— —· — / —·—— ——— ··— / ·—— ·— —· — / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ··— ··· · ·—·—·—';
	@override String get emailAddress => '· —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ···';
	@override String get linkAccount => '·—·· ·· —· —·— / ·— —·—· —·—· ——— ··— —· —';
	@override String get copiedCode => '—·—· ——— ·——· ·· · —·· / —·—· ——— —·· · / — ——— / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··';
	@override String get copyCode => '—·—· ——— ·——· —·—— / —·—· ——— —·· ·';
	@override String codePrompt({required Object email}) => '——— ·——· · —· / — ···· · / ···· ·— —— ··——— —·— / ·— ·——· ·——· / ——— —· / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ·· —· —·— · —·· / ·—— ·· — ···· / ${email} / ·— —· —·· / · —· — · ·—· / — ···· ·· ··· / —·—· ——— —·· · / — ——— / ·— ·——· ·——· ·—· ——— ···— · / — ···· · / ·—· · ——·— ··— · ··· — ———···';
	@override String get waitingForConfirmation => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· …';
	@override String get sendEmailInstead => '··· · —· —·· / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / · —— ·— ·· ·—·· / ·· —· ··· — · ·— —··';
	@override String emailSent({required Object email}) => '·— —· / · —— ·— ·· ·—·· / ·—— ·— ··· / ··· · —· — / — ——— / ${email} ·—·—·— / ——— ·——· · —· / ·· — / ·— —· —·· / —·—· ——— —· ··—· ·· ·—· —— / — ···· · / ·—· · ——·— ··— · ··· — / — ——— / ·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·—';
	@override String get resendEmail => '·—· · ··· · —· —·· / · —— ·— ·· ·—··';
	@override String get qrPrompt => '··· —·—· ·— —· / — ···· ·· ··· / ——·— ·—· / —·—· ——— —·· · / ··—· ·—· ——— —— / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ·· —· —·— · —·· / — ——— / — ···· · / ·— —·—· —·—· ——— ··— —· — / —·—— ——— ··— / ·—— ·— —· — / — / ··—· ——— ·—· / · —··— ·— —— ·——· ·—·· · / ·—— ·· — ···· / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· / ——— —· / —·—— ——— ··— ·—· / ·——· ···· ——— —· · ·—·—·—';
	@override String get serverUnreachable => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String get emailRequired => '· —· — · ·—· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / — ——— / ·—·· ·· —· —·— ·—·—·—';
	@override String noAccountForEmail({required Object email}) => '—· ——— / ·— —·—· —·—· ——— ··— —· — / ··—· ——— ··— —· —·· / ··—· ——— ·—· / ${email} ·—·—·—';
	@override String serverRejected({required Object error}) => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / ·—· · ·——— · —·—· — · —·· / — ···· · / ·—· · ——·— ··— · ··· — ———··· / ${error}';
	@override String get noLinkCode => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —·· ·· —·· / —· ——— — / ·—· · — ··— ·—· —· / ·— / ·—·· ·· —· —·— / —·—· ——— —·· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String get noConfirmationCode => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —·· ·· —·· / —· ——— — / ··· · —· —·· / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·—· ——— —·· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String get switchNotAccepted => '— ···· ·— — / ·— —·—· —·—· ——— ··— —· — / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· · / ··· ·—— ·· — —·—· ···· ·—·—·— / — ·—· —·—— / ·—·· ·· —· —·— ·· —· ——· / ·· — / ·—— ·· — ···· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ·· —· ··· — · ·— —·· ·—·—·—';
	@override String get requestFailed => '··· ——— —— · — ···· ·· —· ——· / ·—— · —· — / ·—— ·—· ——— —· ——· / — ·— ·—·· —·— ·· —· ——· / — ——— / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——·— ··· ———',
		other: '${count} / ——·— ··· ——— ···',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——— ·——· · ·—· ·— — ·· ——— —·',
		other: '${count} / ——— ·——· · ·—· ·— — ·· ——— —· ···',
	);
}

// Path: qsonImport
class _Translations$qsonImport$cw extends Translations$qsonImport$en {
	_Translations$qsonImport$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·· —— ·——· ——— ·—· — / ——·— ··· ——— —· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get description => '—·—· ·—· · ·— — · / ·— / —· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·—· ——— —— / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· · ——··—— / ·— ··· / —·· · ···— · ·—·· ——— ·——· · ·—· / —— ——— —·· · / · —··— ·——· ——— ·—· — ··· / ——— —· · / ···· · ·—· · / ——— ·—· / ·· —· / ·——· ——— ·—·· ——— ·—·—·—';
	@override String get dropHint => '—·· ·—· ——— ·——· / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — / ·· — / ·— ··· / ·— / —· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String importing({required Object filename}) => '·· —— ·——· ——— ·—· — ·· —· ——· / ${filename} …';
	@override String failed({required Object filename, required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —— ·——· ——— ·—· — / ${filename} ———··· / ${error}';
	@override String pickerFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / ·— / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — ———··· / ${error}';
	@override String notUtf8({required Object filename}) => '${filename} / ·· ··· / —· ——— — / ··— — ··—· —····— ———·· / — · —··— — ——··—— / ··· ——— / ·· — / ·· ··· / —· ——— — / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· ·';
	@override String notJson({required Object filename}) => '${filename} / ·· ··· / —· ——— — / ·— / ·——— ··· ——— —· / ··—· ·· ·—·· · ——··—— / ··· ——— / ·· — / ·· ··· / —· ——— — / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· ·';
	@override String notOperation({required Object filename}) => '${filename} / —·· ——— · ··· / —· ——— — / ···· ——— ·—·· —·· / ·— / ——·— ··· ——— —· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get busy => '·— —· / ·· —— ·——· ——— ·—· — / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—· ··— —· —· ·· —· ——· ·—·—·— / ·—— ·— ·· — / ··—· ——— ·—· / ·· — / — ——— / ··—· ·· —· ·· ··· ···· / —··· · ··—· ——— ·—· · / ··· — ·— ·—· — ·· —· ——· / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get oneFileOnly => '—·· ·—· ——— ·——· / ——— —· · / ——·— ··· ——— —· / ··—· ·· ·—·· · / ·— — / ·— / — ·· —— · / — / · ·— —·—· ···· / ——— —· · / ——— ·——· · —· ··· / ·— ··· / ·· — ··· / ——— ·—— —· / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—';
}

// Path: adifImport
class _Translations$adifImport$cw extends Translations$adifImport$en {
	_Translations$adifImport$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·· —— ·——· ——— ·—· — / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ·— —·· ·· ··—·';
	@override String reading({required Object filename}) => '·—· · ·— —·· ·· —· ——· / ${filename} …';
	@override String get dropHint => '—·· ·—· ——— ·——· / ·— —· / ·— —·· ·· ··—· / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· —';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· ·',
		other: '${formatted} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· ·',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ·— ·—·· ·—· · ·— —·· —·—— / ·· —· / —·—— ——— ··— ·—· / ·—·· ——— ——·',
		other: '${formatted} / ·— ·—·· ·—· · ·— —·· —·—— / ·· —· / —·—— ——— ··— ·—· / ·—·· ——— ——·',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —··',
		other: '${formatted} / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —··',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / —· · ·—— / —·—· ——— —· — ·— —·—· —',
		other: '${formatted} / —· · ·—— / —·—· ——— —· — ·— —·—· — ···',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ·—— ·· ·—·· ·—·· / —— · ·—· ——· · / ·—— ·· — ···· / ·— —· / · —··— ·· ··· — ·· —· ——· / —·—· ——— —· — ·— —·—· —',
		other: '${formatted} / ·—— ·· ·—·· ·—·· / —— · ·—· ——· · / ·—— ·· — ···· / · —··— ·· ··· — ·· —· ——· / —·—· ——— —· — ·— —·—· — ···',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —·· / —·——· —· ——— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· —·——·—',
		other: '${formatted} / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —·· / —·——· —· ——— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· —·——·—',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / —· · · —·· ··· / ·— / —·—· ·—·· ——— ··· · ·—· / ·—·· ——— ——— —·—',
		other: '${formatted} / —· · · —·· / ·— / —·—· ·—·· ——— ··· · ·—· / ·—·· ——— ——— —·—',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·—· · ··—· · ·—· · —· —·—· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · —·—· ——— ···— · ·—· · —·· / ··—· ——— ·—· / ${count} / —·—· ——— —· — ·— —·—· —',
		other: '·—· · ··—· · ·—· · —· —·—· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · —·—· ——— ···— · ·—· · —·· / ··—· ——— ·—· / ${formatted} / —·—· ——— —· — ·— —·—· — ···',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${programs} / ·—· · ··—· · ·—· · —· —·—· · ··· / —— ·— —·—— / —··· · / ·· —· —·—· ——— —— ·——· ·—·· · — · / ··—· ——— ·—· / ${count} / —·—· ——— —· — ·— —·—· —',
		other: '${programs} / ·—· · ··—· · ·—· · —· —·—· · ··· / —— ·— —·—— / —··· · / ·· —· —·—· ——— —— ·——· ·—·· · — · / ··—· ——— ·—· / ${formatted} / —·—· ——— —· — ·— —·—· — ···',
	);
	@override String get stackingTypesUnknown => '—·—· ——— —— —··· ·· —· · —·· / —·—· ——— —· — ·— —·—· — ··· / —— ·— —·—— / ·—·· ——— ··· · / ·— / ·—· · ··—· · ·—· · —· —·—· · / — / — ···· · / ·— —·—· — ·· ···— ·· — ·· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / — —·—— ·——· · ··· / ··· — ·— —·—· —·— ·—·—·— / —·—· ·— —· —·—· · ·—·· / ·— —· —·· / ·—· · — ·—· —·—— / — ——— / ·— ···— ——— ·· —·· / — ···· ·· ··· ·—·—·—';
	@override String get nothingToImport => '—· ——— — ···· ·· —· ——· / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· · / —·—· ·— —· / —··· · / ·· —— ·——· ——— ·—· — · —··';
	@override String get confirm => '·· —— ·——· ——— ·—· —';
	@override String importing({required Object filename}) => '·· —— ·——· ——— ·—· — ·· —· ——· / ${filename} …';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·· —— ·——· ——— ·—· — · —·· / ${count} / —·—· ——— —· — ·— —·—· — / ··—· ·—· ——— —— / ${filename}',
		other: '·· —— ·——· ——— ·—· — · —·· / ${formatted} / —·—· ——— —· — ·— —·—· — ··· / ··—· ·—· ——— —— / ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —— ·——· ——— ·—· — / ${filename} ———··· / ${error}';
	@override String notAdif({required Object filename}) => '${filename} / —·· ——— · ··· / —· ——— — / ·—·· ——— ——— —·— / ·—·· ·· —·— · / ·— —· / ·— —·· ·· ··—· / ··—· ·· ·—·· ·';
	@override String stationWarning({required Object calls, required Object station}) => '·—— ·— ·—· —· ·· —· ——· ———··· / — ···· ·· ··· / ·— —·· ·· ··—· / ···· ·— ··· / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ${calls} ——··—— / —··· ··— — / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —·· / ·— ··· / ${station} / ·· ··—· / —·—— ——— ··— / —·—· ——— —· — ·· —· ··— · ·—·—·—';
	@override String get stationCallJoin => '·— —· —··';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ···· ·— ··· / —· ——— / —·· ·— — · / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —··',
		other: '${formatted} / ···· ·— ···— · / —· ——— / —·· ·— — · / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —··',
	);
	@override String activationFound({required Object refs}) => '— ···· ·· ··· / ··—· ·· ·—·· · / ·—· · —·—· ——— ·—· —·· ··· / ·— —· / ·— —·—· — ·· ···— ·— — ·· ——— —· / ——— ··—· / ${refs} ·—·—·—';
	@override String get addActivation => '·— —·· —·· / ·· — / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String shortfall({required Object written, required Object planned}) => '——— —· ·—·· —·—— / ${written} / ——— ··—· / ${planned} / —·—· ——— ··— ·—·· —·· / —··· · / ·— ·——· ·——· ·—·· ·· · —·· / — / — ···· · / ·—·· ——— ——· / —·—· ···· ·— —· ——· · —·· / ·—— ···· ·· ·—·· · / —·—— ——— ··— / ·—— · ·—· · / —·· · —·—· ·· —·· ·· —· ——· ·—·—·—';
	@override String get busy => '·— —· / ·· —— ·——· ——— ·—· — / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—· ··— —· —· ·· —· ——· ·—·—·— / ·—— ·— ·· — / ··—· ——— ·—· / ·· — / — ——— / ··—· ·· —· ·· ··· ···· / —··· · ··—· ——— ·—· · / ··· — ·— ·—· — ·· —· ——· / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get oneFileOnly => '—·· ·—· ——— ·——· / ——— —· · / ·— —·· ·· ··—· / ··—· ·· ·—·· · / ·— — / ·— / — ·· —— · / — / — ···· · / ——— ·—· —·· · ·—· / ··—· ·· ·—·· · ··· / ·— ·—· · / ·· —— ·——· ——— ·—· — · —·· / ·· —· / —·· · —·—· ·· —·· · ··· / ·—— ···· ·· —·—· ···· / —·· ·— — ·— / ·—— ·· —· ··· ·—·—·—';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} / ···· ·— ··· / —— ——— ·—· · / — ···· ·— —· / ${limit} / ——·— ··· ——— ··· ——··—— / — ···· · / —— ——— ··· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / —·—· ·— —· / ·· —— ·——· ——— ·—· — / ·— — / ·— / — ·· —— · ·—·—·—';
}

// Path: offline
class _Translations$offline$cw extends Translations$offline$en {
	_Translations$offline$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => '·· —· — · ·—· —· · — ———··· / ——— ··—· ··—· ·—·· ·· —· ·';
	@override String get statusOnline => '·· —· — · ·—· —· · — ———··· / —·—· ——— —· —· · —·—· — · —··';
	@override String get noRoute => '—· ——— / —· · — ·—— ——— ·—· —·— / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— — / ·— ·—·· ·—·· ·—·—·—';
	@override String get unreachable => '— ···· · / —· · — ·—— ——— ·—· —·— / ·· ··· / ··— ·——· ——··—— / —··· ··— — / —· ——— / ··· · ·—· ···— · ·—· / ·· ··· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — / ——— ··—· — · —· / ·— / ··· ·· ——· —· —····— ·· —· / ·——· ·— ——· · / ·—— ·— ·· — ·· —· ——· / ·· —· / ·— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—';
	@override String get reachable => '·— ·—·· ·—·· / ··· · ·—· ···— ·· —·—· · ··· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·— ··· / · —··— ·——· · —·—· — · —·· ·—·—·—';
	@override String get whatStops => '·—·· ——— ——— —·— ··— ·——· ··· ——··—— / ··· ·——· ——— — ··· / ·— —· —·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ·— ·—· · / ·——· ·— ··— ··· · —·· ·—·—·— / ·—·· ——— ——· ——· ·· —· ——· / ·— —· —·· / —· · ·— ·—· —··· —·—— / ··· —·—— —· —·—· / ·— ·—· · / —· ——— — ·—·—·—';
	@override String get servicesTitle => '··· · ·—· ···— ·· —·—· · ···';
	@override String get noServices => '—· ——— / ··· · ·—· ···— ·· —·—· · / ···· ·— ··· / ·—· · ·——· ——— ·—· — · —·· / ·· —· / —·—— · — ·—·—·—';
	@override String lastSuccess({required Object when}) => '·—·· ·— ··· — / ·—· · ··· ·——· ——— —· —·· · —·· / ${when} / ·— ——· ———';
	@override String get neverSucceeded => '···· ·— ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· · —·· / —·—— · —';
	@override String nextAttempt({required Object when}) => '—· · —··— — / ·— — — · —— ·——· — / ·· —· / ${when}';
	@override String get nextAttemptNow => '—· · —··— — / ·— — — · —— ·——· — / —·· ··— ·';
	@override String get retry => '·—· · — ·—· —·—— / —· ——— ·——';
	@override String get retrying => '— ·—· —·—— ·· —· ——· …';
	@override String get retryReached => '—··· ·— —·—· —·— / ——— —· ·—·· ·· —· · ·—·—·—';
	@override String get retryUnreachable => '··· — ·· ·—·· ·—·· / —· ——— / ·—· · ··· ·——· ——— —· ··· · ·—·—·—';
	@override String get retryNotAttempted => '—· ——— — ···· ·· —· ——· / — ——— / ··· · —· —·· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—';
	@override String get retryThrottled => '·——— ··— ··· — / — ·—· ·· · —·· / — / ——· ·· ···— · / ·· — / ·— / —— ——— —— · —· — ·—·—·—';
	@override String get retryDisabled => '··· —·—— —· —·—· / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— ··—· ··—· ——··—— / ··· ——— / — ···· · ·—· · / ·· ··· / —· ——— — ···· ·· —· ——· / — ——— / ·——· ·—· ——— —··· · / ·—— ·· — ···· ·—·—·—';
	@override String get syncService => '···· ·— —— ··——— —·— / ·—·· ——— ··—· ·· / ··· —·—— —· —·—·';
	@override String get retryInFlight => '·— ·—·· ·—· · ·— —·· —·—— / — ·—· —·—— ·· —· ——· / — / ···· ·— —· ——· / ——— —· ·—·—·—';
}

// Path: exportSettings
class _Translations$exportSettings$cw extends Translations$exportSettings$en {
	_Translations$exportSettings$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => '—··· ·— ··· · / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / · —··— ·——· ——— ·—· — ··· ——··—— / ·—— ·· — ···· / ··· · ·——· ·— ·—· ·— — · / ··—· ·· ·—·· · —· ·— —— · / ·— —· —·· / — ·· — ·—·· · / — · —— ·——· ·—·· ·— — · ··· / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · / ·— —·—· — ·· ···— ·· — ·· · ··· / ·— —· —·· / ——— — ···· · ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· ·—·—·— / · ·— —·—· ···· / · —··— ·——· ——— ·—· — / — —·—— ·——· · / —·—· ·— —· / ·——· ·—· ——— ···— ·· —·· · / ·· — ··· / ——— ·—— —· / —·· · ··—· ·— ··— ·—·· — ··· / ——— ·—· / —·—· ··— ··· — ——— —— / ··· · — — ·· —· ——· ··· ·—·—·—';
	@override String get referenceActivities => '·—· · ··—· · ·—· · —· —·—· · / ·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get otherActivities => '——— — ···· · ·—· / ·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get adifFields => '·— —·· ·· ··—· / ··—· ·· · ·—·· —·· ···';
	@override String get loadFailed => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—·· ——— ·— —·· · —·· ·—·—·—';
	@override String get retry => '·—· · — ·—· —·——';
	@override String get compactFileNamesDescriptionOn => '—·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · —· ·— —— · ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / —· ————— —·—· ·— ·—·· ·—·· ·——·—· ··— ··· —····— ·———— ··——— ···—— ····— —····— ··——— ————— ··——— —···· ————— ——··· ·———— ····· ·—·—·— ·— —·· ·· ·—·—·—';
	@override String get compactFileNamesDescriptionOff => '—·· · ··· —·—· ·—· ·· ·——· — ·· ···— · / ··—· ·· ·—·· · —· ·— —— · ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / ··——— ————— ··——— —···· —····— ————— ——··· —····— ·———— ····· / —· ————— —·—· ·— ·—·· ·—·· / ·— — / ··— ··· —····— ·———— ··——— ···—— ····— ·—·—·— ·— —·· ·· ·—·—·—';
	@override String get includePrivateDataDescriptionOn => '·· —· —·—· ·—·· ··— —·· ·· —· ——· / —· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / —· ——— — · ··· / ·— —· —·· / ·——· ·—· · —·—· ·· ··· · / ·—·· ——— —·—· ·— — ·· ——— —· ··· / ·· —· / ·— —·· ·· ··—· / ··—· ·· ·—·· · ··· ·—·—·—';
	@override String get includePrivateDataDescriptionOff => '——— —— ·· — — ·· —· ——· / —· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· / ·— —· —·· / —· ——— — · ··· —·—·—· / ·—·· ·· —— ·· — ·· —· ——· / ·—·· ——— —·—· ·— — ·· ——— —· ··· / — ——— / ··· ·· —··— —····— —·—· ···· ·— ·—· ·— —·—· — · ·—· / ——· ·—· ·· —·· ··· ·—·—·—';
	@override String get includeLookupDataDescriptionOn => '·· —· —·—· ·—·· ··— —·· ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —· / ··—· ·—· ——— —— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· / ··· · ·—· ···— ·· —·—· · ··· ·—·—·—';
	@override String get includeLookupDataDescriptionOff => '——— —— ·· — — ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —· / ··—· ·—· ——— —— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· / ··· · ·—· ···— ·· —·—· · ··· —·—·—· / —·— · · ·——· ·· —· ——· / —— ·— —· ··— ·— ·—·· ·—·· —·—— / · —· — · ·—· · —·· / ···— ·— ·—·· ··— · ··· ·—·—·—';
	@override String get customTemplatesDescriptionOn => '—·—— ——— ··— ·—· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / ·— —·—· — ·· ···— · / ·— —· —·· / —·—· ·— —· / —··· · / · —·· ·· — · —·· / —··· · ·—·· ——— ·—— ·—·—·—';
	@override String get customTemplatesDescriptionOff => '—·· · ··—· ·— ··— ·—·· — / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / ·— —·—· — ·· ···— · ·—·—·— / —·—— ——— ··— ·—· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / —·— · ·——· — / ··—· ——— ·—· / ·—·· ·— — · ·—· ·—·—·—';
	@override String get type => '· —··— ·——· ——— ·—· — / — —·—— ·——· ·';
	@override String get defaults => '—·· · ··—· ·— ··— ·—·· — ···';
	@override String get includeLookupData => '·· —· —·—· ·—·· ··— —·· · / ·—·· ——— ——— —·— ··— ·——· / —·· ·— — ·—';
	@override String get customTemplates => '—·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ···';
	@override String get filenameTemplate => '··—· ·· ·—·· · / —· ·— —— · / — · —— ·——· ·—·· ·— — ·';
	@override String get compactFilenameTemplate => '—·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · / —· ·— —— · / — · —— ·——· ·—·· ·— — ·';
	@override String get titleTemplate => '— ·· — ·—·· · / — · —— ·——· ·—·· ·— — ·';
	@override String get adifNotesTemplate => '·— —·· ·· ··—· / ——·— ··· ——— / —· ——— — · ···';
	@override String get adifCommentTemplate => '·— —·· ·· ··—· / ——·— ··· ——— / —·—· ——— —— —— · —· — ···';
	@override String get adifQslMessageTemplate => '·— —·· ·· ··—· / ——·— ··· ·—·· / —— · ··· ··· ·— ——· ·';
	@override String get shared => '··· · — — ·· —· ——· ··· / ·— ·——· ·——· ·—·· —·—— / — ——— / · ···— · ·—· —·—— / · —··— — · —· ··· ·· ——— —· / ··— ··· ·· —· ——· / — ···· ·· ··· / · —··— ·——· ——— ·—· — / — —·—— ·——· · ·—·—·—';
	@override String get defaultTemplates => '— ··— ·—· —· / ——— —· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / — ——— / · —·· ·· — / — ···· ·· ··· / — —·—— ·——· · ’ ··· / — · —— ·——· ·—·· ·— — · ··· ·—·—·—';
}

// Path: templateEditor
class _Translations$templateEditor$cw extends Translations$templateEditor$en {
	_Translations$templateEditor$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => '·——· ·—· · ···— ·· · ·—— ———···';
	@override String get reset => '·—· · ··· · —';
	@override String get docs => '— · —— ·——· ·—·· ·— — ·· —· ——· / —·· ——— —·—· ···';
	@override String get preview => '··· ·— —— ·——· ·—·· · / ·——· ·—· · ···— ·· · ·——';
	@override String get reference => '— · —— ·——· ·—·· ·— — · / ·—· · ··—· · ·—· · —· —·—· ·';
	@override String get attributes => '·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·— — — ·—· ·· —··· ··— — · ···';
	@override String get filters => '··—· ·· ·—·· — · ·—· ···';
	@override String get flowControl => '··—· ·—·· ——— ·—— / —·—· ——— —· — ·—· ——— ·—··';
	@override String get unavailable => '·——· ·—· · ···— ·· · ·—— / ·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ··— —· — ·· ·—·· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ·—· · ·— —·· —·—— ·—·—·—';
	@override String get empty => '—·——· · —— ·——· — —·—— / ——— ··— — ·——· ··— — —·——·—';
}

// Path: home.nav
class _Translations$home$nav$cw extends Translations$home$nav$en {
	_Translations$home$nav$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get operations => '——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String get chase => '—·—· ···· ·— ··· ·· —· ——·';
	@override String get logs => '·—·· ——— ——· ···';
	@override String get maps => '—— ·— ·——· ···';
	@override String get settings => '··· · — — ·· —· ——· ···';
}

// Path: home.panels
class _Translations$home$panels$cw extends Translations$home$panels$en {
	_Translations$home$panels$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get operations => '——— ·——· · ·—· ·— — ·· ——— —· / ·—·· ·· ··· —';
	@override String get operationsDescription => '—·—— ——— ··— ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / —— ——— ··· — / ·—· · —·—· · —· — / ··—· ·· ·—· ··· — ·—·—·—';
	@override String get version => '—·—· ··— ·—· ·—· · —· — / ···— · ·—· ··· ·· ——— —·';
	@override String get versionDescription => '— ···· · / ···· ·— —— ··——— —·— / —— ·— ·—· —·— ——··—— / — ···· ·· ··· / ·— ·——· ·——· ’ ··· / —· ·— —— · / ·— —· —·· / ·—— ···· ·· —·—· ···· / —··· ··— ·· ·—·· —·· / —·—— ——— ··— / ·— ·—· · / ·—· ··— —· —· ·· —· ——· ·—·—·—';
}

// Path: home.logs
class _Translations$home$logs$cw extends Translations$home$logs$en {
	_Translations$home$logs$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·—·· ——— ——· ···';
	@override String get titleFor => '·—·· ——— ——· ··· / ··—· ——— ·—·';
	@override String get emptyCallsigns => '—· ——— / ——·— ··· ——— ··· / ·—·· ——— ——· ——· · —·· / —·—— · —';
	@override String emptyQsos({required Object call}) => '—· ——— / ——·— ··· ——— ··· / ··—· ——— ·—· / ${call}';
	@override String get mapNoSelection => '··· · ·—·· · —·—· — / ·— / ——·— ··· ——— / — ——— / ··· · · / ·· — / ——— —· / — ···· · / —— ·— ·——·';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ——— ·—· / —· ·— —— ·';
	@override String get noSearchMatches => '—· ——— / ——·— ··· ——— ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ····';
	@override String get titleAll => '·— ·—·· ·—·· / ·—·· ——— ——· ···';
	@override String get allCallsigns => '·— ·—·· ·—·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···';
	@override String get noOperation => '—· ——— — / ·——· ·— ·—· — / ——— ··—· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get unsavedTitle => '··— —· ··· ·— ···— · —·· / —·—· ···· ·— —· ——· · ···';
	@override String get unsavedBody => '— ···· ·· ··· / ——·— ··· ——— / ···· ·— ··· / —·—· ···· ·— —· ——· · ··· / —·—— ——— ··— / ···· ·— ···— · —· ’ — / ··· ·— ···— · —·· ·—·—·—';
	@override String get pendingDeleteBody => '— ···· ·· ··· / ——·— ··· ——— / ·· ··· / —— ·— ·—· —·— · —·· / ··—· ——— ·—· / —·· · ·—·· · — ·· ——— —· ·—·—·—';
	@override String get editGone => '—· ——— — / ··· ·— ···— · —·· ———··· / — ···· ·— — / ——·— ··· ——— / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / ·· —· / — ···· ·· ··· / ·—·· ——— ——· ·—·—·—';
	@override String get discard => '—·· ·· ··· —·—· ·— ·—· —··';
	@override late final _Translations$home$logs$sheet$cw sheet = _Translations$home$logs$sheet$cw._(_root);
	@override late final _Translations$home$logs$groupBy$cw groupBy = _Translations$home$logs$groupBy$cw._(_root);
	@override late final _Translations$home$logs$period$cw period = _Translations$home$logs$period$cw._(_root);
	@override late final _Translations$home$logs$periodTitle$cw periodTitle = _Translations$home$logs$periodTitle$cw._(_root);
	@override late final _Translations$home$logs$columns$cw columns = _Translations$home$logs$columns$cw._(_root);
	@override late final _Translations$home$logs$panels$cw panels = _Translations$home$logs$panels$cw._(_root);
	@override late final _Translations$home$logs$import$cw import = _Translations$home$logs$import$cw._(_root);
}

// Path: chase.station
class _Translations$chase$station$cw extends Translations$chase$station$en {
	_Translations$chase$station$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ···· ·— ··· ·· —· ——· / ··· — ·— — ·· ——— —·';
	@override String get stationLabel => '··· — ·— — ·· ——— —· ———···';
	@override String get operatorLabel => '——— ·——· ———···';
	@override String get noLocation => '—· ——— / ·—·· ——— —·—· ·— — ·· ——— —·';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$cw extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get today => '— ——— —·· ·— —·——';
	@override String get thisWeek => '— ···· ·· ··· / ·—— · · —·—';
	@override String get last14Days => '·· —· / — ···· · / ·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···';
	@override String get thisMonth => '— ···· ·· ··· / —— ——— —· — ····';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$cw extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get today => '··· — ·— — ··· / ··—· ——— ·—· / — ——— —·· ·— —·——';
	@override String get thisWeek => '··· — ·— — ··· / ··—· ——— ·—· / — ···· ·· ··· / ·—— · · —·—';
	@override String get last14Days => '··· — ·— — ··· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···';
	@override String get thisMonth => '··· — ·— — ··· / ··—· ——— ·—· / — ···· ·· ··· / —— ——— —· — ····';
}

// Path: chase.period
class _Translations$chase$period$cw extends Translations$chase$period$en {
	_Translations$chase$period$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get today => '— ——— —·· ·— —·——';
	@override String get thisWeek => '— ···· ·· ··· / ·—— · · —·—';
	@override String get last14Days => '·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···';
	@override String get thisMonth => '— ···· ·· ··· / —— ——— —· — ····';
}

// Path: chase.goals
class _Translations$chase$goals$cw extends Translations$chase$goals$en {
	_Translations$chase$goals$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ···· ·— ··· ·· —· ——· / ——· ——— ·— ·—·· ···';
	@override String remove({required Object name}) => '··· — ——— ·——· / —·—· ···· ·— ··· ·· —· ——· / ${name}';
	@override String get extensionsTitle => '—— ——— ·—· · / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— ···';
}

// Path: chase.panels
class _Translations$chase$panels$cw extends Translations$chase$panels$en {
	_Translations$chase$panels$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get logging => '——·— ··· ——— ···';
	@override String get loggingDescription => '·—·· ——— ——· ——· ·· —· ——· / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— —··· ——— ···— · / — ···· · / ——·— ··· ——— ··· / —·—· ···· ·— ··· · —·· / ·· —· / — ···· · / ·——· · ·—· ·· ——— —·· ·—·—·—';
	@override String get info => '·· —· ··—· ———';
	@override String get infoDescription => '— ···· · / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —·· ——··—— / ——— ·—· / — ···· · / ·——· · ·—· ·· ——— —·· ·————· ··· / ··· — ·— — ··· ·—·—·—';
	@override String get spots => '··· ·——· ——— — ···';
	@override String get spotsDescription => '··· — ·— — ·· ——— —· ··· / ··· ·——· ——— — — · —·· / ——— —· / — ···· · / ·— ·· ·—· ——··—— / ·—· · ·— —·· —·—— / — ——— / —·—· ···· ·— ··· · ·—·—·—';
	@override String get map => '—— ·— ·——·';
	@override String get mapDescription => '— ···· · / ·——· · ·—· ·· ——— —·· ·————· ··· / ——·— ··· ——— ··· / ·— —· —·· / — ···· · / ··· — ·— — ·· ——— —· / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —·· ·—·—·—';
}

// Path: chase.claims
class _Translations$chase$claims$cw extends Translations$chase$claims$en {
	_Translations$chase$claims$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get checking => '—·—· ···· · —·—· —·— ·· —· ——· / ——·— ··· ——— ··· / ··—· ——— ·—· / —·—· ···· ·— ··· ·· —· ——·';
	@override String rebuilding({required Object program}) => '—·—· ···· · —·—· —·— ·· —· ——· / — ···· · / ·—·· ——— ——· / ··—· ——— ·—· / ${program}';
	@override String progress({required Object done, required Object total}) => '${done} / ——— ··—· / ${total} / ——·— ··· ——— ···';
}

// Path: chase.notice
class _Translations$chase$notice$cw extends Translations$chase$notice$en {
	_Translations$chase$notice$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => '—· · ·—— / ${program}';
	@override String newRefGuess({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program}';
	@override String newBand({required Object program}) => '—· · ·—— / ${program} / —··· ·— —· —··';
	@override String newBandGuess({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program} / —··· ·— —· —··';
	@override String newMode({required Object program}) => '—· · ·—— / ${program} / —— ——— —·· ·';
	@override String newModeGuess({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program} / —— ——— —·· ·';
	@override String unconfirmed({required Object program}) => '${program} / ··— —· —·—· ——— —· ··—· ·· ·—· —— · —··';
}

// Path: chase.alerts
class _Translations$chase$alerts$cw extends Translations$chase$alerts$en {
	_Translations$chase$alerts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— ·—·· · ·—· — ···';
	@override String get newRef => '—· · ·—— / ·—· · ··—· · ·—· · —· —·—· ·';
	@override String get newBand => '—· · ·—— / —··· ·— —· —··';
	@override String get newMode => '—· · ·—— / —— ——— —·· ·';
	@override String get unconfirmed => '··— —· —·—· ——— —· ··—· ·· ·—· —— · —··';
}

// Path: chase.imports
class _Translations$chase$imports$cw extends Translations$chase$imports$en {
	_Translations$chase$imports$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => '·· —— ·——· ——— ·—· — / ${label}';
	@override String pickTitle({required Object file}) => '·· —— ·——· ——— ·—· — / ${file} / ·— ···';
	@override String get dropHint => '—·· ·—· ——— ·——· / ·— / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — / ·· — / ·· —· — ——— / ·— / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— ——';
	@override String done({required Object count, required Object program, required Object file}) => '·· —— ·——· ——— ·—· — · —·· / ${count} / ${program} / · —· — ·—· ·· · ··· / ··—· ·—· ——— —— / ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => '·· —— ·——· ——— ·—· — · —·· / ${count} / ${program} / · —· — ·—· ·· · ··· / ··—· ·—· ——— —— / ${file} ——··—— / ··· —·— ·· ·——· ·——· · —·· / ${skipped} / ·· — / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —··';
	@override String nothing({required Object file, required Object program}) => '${file} / ···· ·— ··· / —· ——— — ···· ·· —· ——· / ${program} / —·—· ·— —· / ·· —— ·——· ——— ·—· —';
	@override String failed({required Object program, required Object file}) => '${program} / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· / ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· / ·— —· —·—— / ——— ··—· / — ···· · / ${skipped} / ·—· · —·—· ——— ·—· —·· ··· / ·· —· / ${file}';
	@override String noProgram({required Object file}) => '—· ——— / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— / ·· —— ·——· ——— ·—· — ··· / ${file}';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$cw extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => '·· —· ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ———··· / ${call}';
	@override String invalidCallsigns({required Object calls}) => '·· —· ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ———··· / ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} / ···· ·— ··· / ——— ·——· · ·—· ·— — · —·· / ··· ——— / ··—· ·— ·—· ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· ·—·—·—';
	@override String operatorNoneSoFar({required Object typed}) => '—· ——— / ——— ·——· · ·—· ·— — ——— ·—· / ·—· · —·—· ——— ·—· —·· · —·· / ··· ——— / ··—· ·— ·—· ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· ·—·—·—';
	@override String operatorSeveral({required Object calls, required Object typed}) => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / —·—· ——— —· — ·— —·—· — ··· / —··· —·—— / ${calls} ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / ——— —· ·—·· —·—— / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / ——— —· · ··· ·—·—·—';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·— ·—·· ··· ——— / ·—· · —·—· ——— ·—· —·· / ${typed} / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ——— ··—· / — ···· · / —·—· ——— —· — ·— —·—· — / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —··',
		other: '·— ·—·· ··· ——— / ·—· · —·—· ——— ·—· —·· / ${typed} / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ——— ··—· / ·— ·—·· ·—·· / ${count} / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —··',
	);
	@override String get operatorSeveralStations => '·—— ···· · —· / ··— ··· ·· —· ——· / —— ··— ·—·· — ·· ·——· ·—·· · / ··· — ·— — ·· ——— —· ··· / ——— ···— · ·—· / — ···· · / ·— ·· ·—· ——··—— / — ···· · ·—· · ·————· ··· / —· ——— / ··· ··— ·——· ·——· ——— ·—· — / ··—· ——— ·—· / ··· · ·——· ·— ·—· ·— — · / ——— ·——· · ·—· ·— — ——— ·—· ···';
	@override String get contactsUnreadable => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / —·—· ——— —· — ·— —·—· — ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / —·—· ···· ·— —· ——· ·· —· ——· / ·— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ···· · ·—· · / ·—— ——— —· ·————· — / ——— ··—· ··—· · ·—· / — ——— / ··— ·——· —·· ·— — · / — ···· · ——';
	@override String restampFailed({required Object error}) => '— ···· · / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —·· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··— ·——· —·· ·— — · —·· ——··—— / ··· ——— / —· ——— / —·—· ···· ·— —· ——· · ··· / ·—— · ·—· · / —— ·— —·· · ———··· / ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} / ——— ··—· / ${planned} / —·—· ——— —· — ·— —·—· — ··· / ·—— · ·—· · / ··— ·——· —·· ·— — · —·· / — / — ···· · / ·—· · ··· — / ·— ·—· · / —· ——— / ·—·· ——— —· ——· · ·—· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
}

// Path: operation.tabs
class _Translations$operation$tabs$cw extends Translations$operation$tabs$en {
	_Translations$operation$tabs$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} / ——·— ··· ——— ···';
	@override String get info => '·· —· ··—· ———';
	@override String get spots => '··· ·——· ——— — ···';
	@override String get map => '—— ·— ·——·';
	@override String get qsosPlain => '——·— ··· ——— ···';
	@override String get clock => '—·—· ·—·· ——— —·—· —·—';
	@override String get weather => '·—— · ·— — ···· · ·—·';
	@override String get website => '·—— · —··· / ··· ·· — ·';
	@override String get remoteScreen => '·—· · —— ——— — · / ··· —·—· ·—· · · —·';
	@override String get solar => '··· ——— ·—·· ·— ·—·';
	@override String get radio => '·—· ·— —·· ·· ———';
	@override String get summaries => '——— ·——· · ·—· ·— — ·· ——— —· / ··· ··— —— —— ·— ·—· ·· · ···';
}

// Path: operation.positions
class _Translations$operation$positions$cw extends Translations$operation$positions$en {
	_Translations$operation$positions$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => '—· ——— / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —· ··· / ·— ·—· · / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / —·—— · — ·—·—·—';
	@override String positionLabel({required Object number}) => '·——· ——— ··· ———··· / ${number}';
	@override String operatorLabel({required Object call}) => '——— ·——· ———··· / ${call}';
	@override String get unnamedPosition => '·— —· ——— — ···· · ·—· / ·——· ——— ··· ·· — ·· ——— —·';
	@override String get thisDevice => '——— ··— ·—· / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —·';
	@override String get nameIn => '·· —·';
	@override String get panelTitle => '·——· ——— ··· ·· — ·· ——— —· ···';
	@override String get panelDescription => '·—— ···· ·— — / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —· / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / ·—·· ——— ——· ——· ·· —· ——· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—';
}

// Path: operation.menu
class _Translations$operation$menu$cw extends Translations$operation$menu$en {
	_Translations$operation$menu$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => '··· ···· ——— ·—— / ·—· ··· — / ··—· ·· · ·—·· —·· ···';
	@override String get showStateField => '··· ···· ——— ·—— / ··· — ·— — · / ··—· ·· · ·—·· —··';
	@override String get showGridField => '··· ···· ——— ·—— / ——· ·—· ·· —·· / ··—· ·· · ·—·· —··';
	@override String get showDeletedQsos => '··· ···· ——— ·—— / —·· · ·—·· · — · —·· / ——·— ··· ——— ···';
	@override String get showDeletedOps => '··· ···· ——— ·—— / —·· · ·—·· · — · —·· / ——— ·——· · ·—· ·— — ·· ——— —· ···';
	@override String get showQsoNumbers => '··· ···· ——— ·—— / ——·— ··· ——— / —· ··— —— —··· · ·—· ···';
	@override String get lookupAllQsos => '·—·· ——— ——— —·— ··— ·——· / ·— ·—·· ·—·· / ——·— ··· ——— ···';
	@override String get loggingSettingsTitle => '·—·· ——— ——· ——· ·· —· ——· / ··· · — — ·· —· ——· ···';
	@override String get mapSettingsTitle => '—— ·— ·——· / ··· · — — ·· —· ——· ···';
	@override String get actionsSection => '·— —·—· — ·· ——— —· ···';
}

// Path: operation.layout
class _Translations$operation$layout$cw extends Translations$operation$layout$en {
	_Translations$operation$layout$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— —·· —·· / ·— / ·——· ·— —· · ·—··';
	@override String get availableSection => '·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·——· ·— —· · ·—·· ···';
	@override String panelSettings({required Object panel}) => '${panel} / ··· · — — ·· —· ——· ···';
	@override String get panelSettingsAction => '·——· ·— —· · ·—·· / ··· · — — ·· —· ——· ···';
	@override String get viewName => '——— ·——· · ·—· ·— — ·· ——— —· / ···— ·· · ·——';
	@override String get viewOptions => '···— ·· · ·—— / ·—·· ·— —·—— ——— ··— — / ——— ·——· — ·· ——— —· ···';
	@override String get viewTitleBuiltIn => '— ···· ·· ··· / ···— ·· · ·—— / ·· ··· / —··· ··— ·· ·—·· — / ·· —· — ——— / — ···· · / ·— ·——· ·——· ——··—— / ·— —· —·· / ··· ——— / ·· ··· / ·· — ··· / —· ·— —— ·';
	@override String get resetOptions => '·—· · ··· — ——— ·—· · / —·· · ··—· ·— ··— ·—·· — ···';
	@override String get removePane => '·—· · —— ——— ···— ·';
	@override String resetPaneConfirm({required Object panel}) => '·—· · ··· — ——— ·—· · / ${panel} / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ··· ··——··';
	@override String get resetPaneConfirmBody => '·· — ··· / — ·· — ·—·· · ——··—— / ···· · ·— —·· · ·—· / ·— —· —·· / ··· ·· ——·· · / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·— / — ···· · / ·—· · ··· — / ——— ··—· / — ···· · / ·—·· ·— —·—— ——— ··— — / ··· — ·— —·—— ··· / ·— ··· / ·· — / ·· ··· ·—·—·—';
	@override String get resetViewConfirm => '·—· · ··· — ——— ·—· · / — ···· ·· ··· / ···— ·· · ·—— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — / ·—·· ·— —·—— ——— ··— — ··——··';
	@override String get resetViewConfirmBody => '— ···· · / ·——· ·— —· · ·—·· ··· / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · ·· ·—· / —·· · ··—· ·— ··— ·—·· — / ·— ·—· ·—· ·— —· ——· · —— · —· — ——··—— / ·— —· —·· / — ···· · / ···— ·· · ·—— ·————· ··· / ——— ·——· — ·· ——— —· ··· / ·— —· —·· / · ···— · ·—· —·—— / ·——· ·— —· · ·—·· ·————· ··· / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·—';
	@override String paneOptionsTitle({required Object panel}) => '${panel} / ·—·· ·— —·—— ——— ··— — / ··· · — — ·· —· ——· ···';
	@override String get paneTitle => '— ·· — ·—·· ·';
	@override String get paneShowHeader => '··· ···· ——— ·—— / ···· · ·— —·· · ·—·';
	@override String get paneShowHeaderTabset => '·— ·—·· ·—— ·— —·—— ··· / ··· ···· ——— ·—— —· / ·—— ···· ·· ·—·· · / — ···· ·· ··· / ·——· ·— —· · / ··· ···· ·— ·—· · ··· / ·— / ——· ·—· ——— ··— ·——· / — / — ···· · / ···· · ·— —·· · ·—· / ·· ··· / ···· ——— ·—— / — ···· · / ——— — ···· · ·—· ··· / ·— ·—· · / ·—· · ·— —·—· ···· · —··';
	@override String get paneInherit => '··· ·— —— · / ·— ··· / — ···· · / ·— ·——· ·——·';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / ·——· ·— —· · ·—·· ···';
	@override String get noPanelsMatch => '—· ——— / ·——· ·— —· · ·—·· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ·—·—·—';
	@override String get nothingToAdd => '— ···· ·· ··· / ···— ·· · ·—— / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / ·— ·—·· ·—·· / ·——· ——— ··· ··· ·· —··· ·—·· · / ·——· ·— —· · ·—·· ···';
	@override String addPanel({required Object panel}) => '·— —·· —·· / ${panel}';
	@override String showPreview({required Object panel}) => '·——· ·—· · ···— ·· · ·—— / ${panel}';
	@override String missingExtension({required Object name}) => '· —··— — · —· ··· ·· ——— —· / ·—··—· ${name} ·—··—· / ·· ··· / —— ·· ··· ··· ·· —· ——·';
	@override String get missingExtensionEnable => '· —· ·— —··· ·—·· ·';
	@override String get missingExtensionInstall => '·· —· ··· — ·— ·—·· ·—·· …';
	@override String get missingExtensionWontRun => '— ···· ·· ··· / ···— · ·—· ··· ·· ——— —· / ·—— ——— —· ’ — / ·—· ··— —· ·—·—·— / ··— ·——· —·· ·— — · / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—';
	@override String get missingExtensionUnavailable => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· ·· ··· / ·— ·——· ·——·';
	@override String get missingExtensionNotInCatalog => '—· ——— — / ·· —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——·';
	@override String get missingExtensionCatalogUnreachable => '—·—· ——— ··— ·—·· —·· —· ’ — / ·—· · ·— —·—· ···· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —·';
	@override String get missingExtensionFailed => '— ···· ·— — / —·· ·· —·· —· ’ — / ·—— ——— ·—· —·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —·';
	@override String get previewUnavailable => '— ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ·——· ·—· · ···— ·· · ·—— / ·· —— ·— ——· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··· ···· ——— ·—— —· ·—·—·—';
	@override String get nestedPaneTitle => '—— ——— ·—· ·';
	@override late final _Translations$operation$layout$layouts$cw layouts = _Translations$operation$layout$layouts$cw._(_root);
	@override String get editLayout => '· —·· ·· — / ·—·· ·— —·—— ——— ··— —';
	@override String get saveLayout => '··· ·— ···— · / ·—·· ·— —·—— ——— ··— —';
	@override String get revertLayout => '—·· ·· ··· —·—· ·— ·—· —·· / ·—·· ·— —·—— ——— ··— — / —·—· ···· ·— —· ——· · ···';
	@override String get done => '—·· ——— —· ·';
	@override String get layoutUnreadableTitle => '·—·· ·— —·—— ——— ··— — / —·—· ——— ··— ·—·· —·· —· ·————· — / —··· · / ·—· · ·— —··';
	@override String get layoutUnreadableBody => '—·—— ——— ··— ·—· / ··· ·— ···— · —·· / ·—·· ·— —·—— ——— ··— — / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·— ·—· ·—· ·— —· ——· · —— · —· — / ·· ··· / ··· ···· ——— ·—— ·· —· ——· / ·· —· ··· — · ·— —·· ·—·—·— / ·· — / ·—— ——— —· ·————· — / —··· · / ··· ·— ···— · —·· / ——— ···— · ·—· / —·—— ——— ··— ·—· / ——— ·—· ·· ——· ·· —· ·— ·—·· / ··— —· — ·· ·—·· / —·—— ——— ··— / —·—· ···· ——— ——— ··· · / — ——— / —·— · · ·——· / ·· — ·—·—·—';
	@override String get layoutUnreadableAction => '··— ··· · / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —';
	@override String panelRenderFailed({required Object panel}) => '${panel} / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / —·· ·· ··· ·——· ·—·· ·— —·—— · —··';
	@override String get panelRenderRetry => '— ·—· —·—— / ·— ——· ·— ·· —·';
	@override String get panelActionFailed => '— ···· ·— — / ·——· ·— —· · ·—·· / ·— —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override late final _Translations$operation$layout$panels$cw panels = _Translations$operation$layout$panels$cw._(_root);
	@override String get htmlPanelUnsupported => '— ···· ·· ··· / ·——· ·— —· · ·—·· / —· · · —·· ··· / ·— / ·—— · —··· / ···— ·· · ·—— ——··—— / ·—— ···· ·· —·—· ···· / — ···· ·· ··· / ·——· ·—·· ·— — ··—· ——— ·—· —— / —·· ——— · ··· / —· ——— — / ·——· ·—· ——— ···— ·· —·· ·';
	@override String get htmlPanelUnsupportedOnWeb => '— ···· ·· ··· / ·——· ·— —· · ·—·· / —· · · —·· ··· / ·— / ··· ·— —· —·· —··· ——— —··— / — ···· · / ·—— · —··· / ···— · ·—· ··· ·· ——— —· / —·—· ·— —· —· ——— — / ·——· ·—· ——— ···— ·· —·· ·';
}

// Path: operation.export
class _Translations$operation$export$cw extends Translations$operation$export$en {
	_Translations$operation$export$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '——— ·——· · ·—· ·— — ·· ——— —· / · —··— ·——· ——— ·—· — ···';
	@override String get syncedOperation => '——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / ··· —·—— —· —·—· · —··';
	@override String get unsyncedOperation => '——— ·——· · ·—· ·— — ·· ——— —· / ···· ·— ··· / ··— —· ··· —·—— —· —·—· · —·· / —·—· ···· ·— —· ——· · ···';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
		other: '${count} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
	);
	@override String qsosSynced({required Object total}) => '·— ·—·· ·—·· / ${total} / ——·— ··· ——— ··· / ·— ·—· · / ··· —·—— —· —·—· · —··';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} / ——— ··—· / ${total} / ——·— ··· ——— ··· / ·——· · —· —·· ·· —· ——· / ··· —·—— —· —·—·';
	@override String eventsSynced({required Object total}) => '${total} / · ···— · —· — / —— ·— ·—· —·— · ·—· ··· / ··· —·—— —· —·—· · —··';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} / ——— ··—· / ${total} / · ···— · —· — / —— ·— ·—· —·— · ·—· ··· / ·——· · —· —·· ·· —· ——·';
	@override String get loading => '·—·· ——— ·— —·· ·· —· ——· / · —··— ·——· ——— ·—· — / ——— ·——· — ·· ——— —· ··· …';
	@override String get noOptions => '—· ——— / · —··— ·——· ——— ·—· — / ··—· ——— ·—· —— ·— — ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / —·——· · —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / ··· — ·· ·—·· ·—·· / ··· — ·— ·—· — ·· —· ——· ··——·· —·——·—';
	@override String get nothingLogged => '—· ——— — ···· ·· —· ——· / — ——— / · —··— ·——· ——— ·—· — / —·—— · — / — / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ···· ·— ··· / —· ——— / ——·— ··· ——— ··· ·—·—·—';
	@override String get share => '··· ···· ·— ·—· ·';
	@override String get nothingSelected => '—· ——— — ···· ·· —· ——· / ··· · ·—·· · —·—· — · —··';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· ·— ···— · / ${count} / ··—· ·· ·—·· ·',
		other: '··· ·— ···— · / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· ···· ·— ·—· · / ${count} / ··—· ·· ·—·· ·',
		other: '··· ···· ·— ·—· · / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '· —··— ·——· ——— ·—· — / ${count} / ··—· ·· ·—·· ·',
		other: '· —··— ·——· ——— ·—· — / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${count} / ··—· ·· ·—·· ·',
		other: '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· ·— ···— · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '··· ·— ···— · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· ···· ·— ·—· · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '··· ···· ·— ·—· · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '· —··— ·——· ——— ·—· — / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '· —··— ·——· ——— ·—· — / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '—·· ——— ·—— —· ·—·· ——— ·— —·· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '—·· ——— ·—— —· ·—·· ——— ·— —·· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String saveOne({required Object name}) => '··· ·— ···— · / ${name}';
	@override String shareOne({required Object name}) => '··· ···· ·— ·—· · / ${name}';
	@override String exportOne({required Object name}) => '· —··— ·——· ——— ·—· — / ${name}';
	@override String downloadOne({required Object name}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· — ·— ··· ···· / ${count} / ··—· ·· ·—·· ·',
		other: '··· — ·— ··· ···· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· — ·— ··· ···· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '··· — ·— ··· ···· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String get settingsButton => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ···';
	@override String get settingsTitle => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ···';
	@override late final _Translations$operation$export$compactFileNames$cw compactFileNames = _Translations$operation$export$compactFileNames$cw._(_root);
	@override late final _Translations$operation$export$includePrivateData$cw includePrivateData = _Translations$operation$export$includePrivateData$cw._(_root);
	@override String get resultTitle => '· —··— ·——· ——— ·—· — / —·—· ——— —— ·——· ·—·· · — ·';
	@override String get resultFailedTitle => '· —··— ·——· ——— ·—· — / ··—· ·— ·· ·—·· · —··';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · / — ——— / ${path}',
		other: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ··· / — ——— / ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ———··· / ${path}',
		other: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ··· ———··· / ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· ···· ·— ·—· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '··· ···· ·— ·—· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${count} / ··—· ·· ·—·· ·',
		other: '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${count} / ··—· ·· ·—·· · ···',
	);
	@override String exportFailed({required Object error}) => '· —··— ·——· ——— ·—· — / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override late final _Translations$operation$export$stash$cw stash = _Translations$operation$export$stash$cw._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$cw extends Translations$operation$spots$en {
	_Translations$operation$spots$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get empty => '—· ——— / ··· ·——· ——— — ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··—· ·· ·—·· — · ·—· ···';
	@override String error({required Object error}) => '··—· ·— ·· ·—·· · —·· / — ——— / ·—·· ——— ·— —·· / ··· ·——· ——— — ··· ———··· / ${error}';
	@override String get unknownBand => '——— — ···· · ·—·';
	@override String get auto => '·— ··— — ——— —— ·— — ·· —·—·';
	@override String autoValue({required Object value}) => '·— ··— — ——— —— ·— — ·· —·—· / —·——· —·—· ··— ·—· ·—· · —· — ·—·· —·—— / ${value} —·——·—';
	@override String valueAuto({required Object value}) => '${value} / —·——· ·— ··— — ——— —·——·—';
	@override String get any => '·— —· —·——';
	@override String get allBands => '·— ·—·· ·—·· / —··· ·— —· —·· ···';
	@override String get allModes => '·— ·—·· ·—·· / —— ——— —·· · ···';
	@override String get phoneAndCw => '·——· ···· ——— —· · / ·—··· / —·—· ·——';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ··· ·——· ——— —',
		other: '${count} / ··· ·——· ——— — ···',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => '··· ···· ——— ·—— ·· —· ——· / ${count} / ——— ··—· / ${total} / ··· ·——· ——— — ···';
	@override String ageMinutes({required Object minutes}) => '${minutes} / —— ·· —· ··— — · ···';
	@override String get callsOfNote => '—·—· ·— ·—·· ·—·· ··· / ——— ··—· / —· ——— — ·';
	@override String get yourSpots => '—·—— ——— ··— ·—· / ··· ·——· ——— — ···';
	@override String get allSpots => '·— ·—·· ·—·· / ··· ·——· ——— — ···';
	@override late final _Translations$operation$spots$continents$cw continents = _Translations$operation$spots$continents$cw._(_root);
	@override late final _Translations$operation$spots$filters$cw filters = _Translations$operation$spots$filters$cw._(_root);
	@override String get unavailableTitle => '··· ·——· ——— — ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String unavailableText({required Object sources}) => '${sources} / —·· ·· —·· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·—·—·—';
	@override String get failedTitle => '··· ·——· ——— — / ··· ——— ··— ·—· —·—· · / · ·—· ·—· ——— ·—·';
	@override String failedText({required Object sources}) => '${sources} / ·—· · — ··— ·—· —· · —·· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—';
	@override String get slideLogIt => '·—·· ——— ——· / ·· —';
	@override String get slideIgnore => '·· ——· —· ——— ·—· ·';
	@override String get slideRestore => '·—· · ··· — ——— ·—· ·';
	@override late final _Translations$operation$spots$logConflict$cw logConflict = _Translations$operation$spots$logConflict$cw._(_root);
}

// Path: operation.import
class _Translations$operation$import$cw extends Translations$operation$import$en {
	_Translations$operation$import$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·· —— ·——· ——— ·—· — / —·· ·— — ·— / ·· —· — ——— / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get importAdifAction => '·· —— ·——· ——— ·—· — / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ·— —·· ·· ··—·';
	@override String get settingsButton => '·—·· ·· ··· — · —· / ··· · — — ·· —· ——· ···';
	@override String get settingsTitle => '·—·· ·· ··· — · —· / ··—· ——— ·—· / ——— — ···· · ·—· / ·— ·——· ·——· ···';
	@override String get protocolAddressLabel => '·— —·· —·· ·—· · ··· ···';
	@override String get protocolPortLabel => '·——· ——— ·—· —';
	@override String get protocolPortInvalid => '· —· — · ·—· / ·— / ·——· ——— ·—· — / —··· · — ·—— · · —· / ·———— / ·— —· —·· / —···· ····· ····· ···—— ·····';
	@override String get protocolAddressInvalid => '· —· — · ·—· / ·— / ···— ·— ·—·· ·· —·· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / —·——· · ·—·—·— ——· ·—·—·— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ——— ·—· / ··——— ···—— ————· ·—·—·— ··——— ···—— ————· ·—·—·— ————— ·—·—·— ··——— —·——·—';
	@override String get protocolStatusReceiving => '·—· · —·—· · ·· ···— ·· —· ——· / —·· ·— — ·—';
	@override String get protocolStatusNoData => '—· ——— / —·· ·— — ·— / ·—· · —·—· · ·· ···— · —·· / ·—· · —·—· · —· — ·—·· —·——';
	@override String protocolBindError({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ··· — ·— ·—· — / ·—·· ·· ··· — · —· ·· —· ——· ———··· / ${error}';
	@override String captureFailed({required Object error}) => '·· —· —·—· ——— —— ·· —· ——· / ——·— ··· ——— ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··· ·— ···— · —·· / ·— —· —·· / ·— ·—· · / —··· · ·· —· ——· / ·—· · — ·—· ·· · —·· ———··· / ${error}';
	@override String get n1mmProtocolName => '—· ·———— —— —— ·—·—· / —·—· ——— —· — ·— —·—· — / —··· ·—· ——— ·— —·· —·—· ·— ··· —';
	@override String get n1mmAddressValue => '·— —· —·—— / —·——· —··· ·—· ——— ·— —·· —·—· ·— ··· — —·——·—';
	@override String get wsjtxProtocolName => '·—— ··· ·——— — —····— —··— / ··— —·· ·——· / ··· · ·—· ···— · ·—·';
	@override String get helpN1mmSetup => '—·—· ——— —· ··—· ·· ——· / → / —·—· ——— —· ··—· ·· ——· ··— ·—· · / ·——· ——— ·—· — ··· ——··—— / —— ——— —·· · / —·—· ——— —· — ·—· ——— ·—·· … / → / —··· ·—· ——— ·— —·· —·—· ·— ··· — / —·· ·— — ·— / — ·— —··· / → / —·—· ···· · —·—· —·— / ·—··—· · —· ·— —··· ·—·· · / —··· ·—· ——— ·— —·· —·—· ·— ··· — ··· ·—··—· / ··—· ——— ·—· / —·—· ——— —· — ·— —·—· — / ·· —· ··—· ——— ·—·—·— / ··· · — / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / — ——— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ·· ··—· / ·—· ··— —· —· ·· —· ——· / ——— —· / — ···· ·· ··· / ··· ·— —— · / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ——— ·—· / ··——— ····· ····· ·—·—·— ··——— ····· ····· ·—·—·— ··——— ····· ····· ·—·—·— ··——— ····· ····· / — ——— / —··· ·—· ——— ·— —·· —·—· ·— ··· — / ——— —· / — ···· · / —·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ·—·—·—';
	@override String get helpWsjtxSetup => '··—· ·· ·—·· · / → / ··· · — — ·· —· ——· ··· / → / ·—· · ·——· ——— ·—· — ·· —· ——· / — ·— —··· / → / ··— —·· ·——· / ··· · ·—· ···— · ·—· / ··· · —·—· — ·· ——— —· / → / —·—· ···· · —·—· —·— / ·—··—· ·— —·—· —·—· · ·——· — / ··— —·· ·——· / ·—· · ——·— ··— · ··· — ··· ·—··—· ·—·—·— / ··· · — / ··— —·· ·——· / ··· · ·—· ···— · ·—· / — ——— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ·· ··—· / ·—· ··— —· —· ·· —· ——· / ——— —· / — ···· ·· ··· / ··· ·— —— · / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ——— ·—· / ·— / —— ··— ·—·· — ·· —·—· ·— ··· — / ·— —·· —·· ·—· · ··· ··· / ··· ··— —·—· ···· / ·— ··· / ··——— ···—— ————· ·—·—·— ··——— ···—— ————· ·—·—·— ————— ·—·—·— ··——— ——··—— / ·— —· —·· / ··— ··· · / — ···· · / ··· ·— —— · / ·— —·· —·· ·—· · ··· ··· / ·· —· / — ···· · / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·— —··· ——— ···— · / ·· —· / — ···· ·· ··· / ·— ·——· ·——· ·—·—·—';
	@override String get listenTitle => '·—·· ·· ··· — · —· / ··—· ——— ·—· / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ——— — ···· · ·—· / ·— ·——· ·——· ···';
	@override String get listenDescriptionOnN1mm => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / —· ·———— —— —— ·—·—·';
	@override String get listenDescriptionOnWsjtx => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / ·—— ··· ·——— — —····— —··—';
	@override String get listenDescriptionOnBoth => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / —· ·———— —— —— ·—·—· / ·— —· —·· / ·—— ··· ·——— — —····— —··—';
	@override String get listenDescriptionOff => '——— ··—· ··—·';
	@override String get addToOperationTitle => '·— —·· —·· / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get addToOperationDescriptionOn => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ··· / ·— ·—· · / ·— —·· —·· · —·· / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ··· / — ···· · —·—— / ·— ·—· ·—· ·· ···— ·';
	@override String get addToOperationDescriptionOff => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ··· / ·— ·—· · / ···· · ·—·· —·· / ··— —· — ·· ·—·· / —·—— ——— ··— / — ··— ·—· —· / — ···· ·· ··· / ——— —·';
	@override String get pendingSectionTitle => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ···';
	@override String get pendingEmpty => '—· ——— — ···· ·· —· ——· / —·—· ·— ·——· — ··— ·—· · —·· / —·—— · —';
	@override String stationMismatch({required Object call}) => '·—·· ——— ——· ——· · —·· / ·— ··· / ${call} ——··—— / —· ——— — / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ··· — ·— — ·· ——— —·';
	@override String get discardAction => '—·· ·· ··· —·—· ·— ·—· —··';
	@override String get gapDialogTitle => '·· —· —·—· ·—·· ··— —·· · / · ·— ·—· ·—·· ·· · ·—· / —·—· ·— ·——· — ··— ·—· · ··· ··——··';
	@override String gapDialogBody({required Object count}) => '${count} / —— ——— ·—· · / ——·— ··· ——— ··· / ·—— · ·—· · / —·—· ·— ·——· — ··— ·—· · —·· / · ·— ·—· ·—·· ·· · ·—· ——··—— / —··· · ··—· ——— ·—· · / ·— / ——· ·— ·——· / ·· —· / — ···· · / —·· ·— — ·— ·—·—·— / ·· —· —·—· ·—·· ··— —·· · / — ···· · —— / — ——— ——— ··——··';
	@override String get gapDialogRecentOnly => '·——— ··— ··· — / — ···· · / ·—· · —·—· · —· — / ——— —· · ···';
	@override String gapDialogIncludeAll({required Object count}) => '·· —· —·—· ·—·· ··— —·· · / ·— ·—·· ·—·· / ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$cw extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get link => '·· ··· ··· ··— · ··· ··——··';
	@override String get title => '·—· · ·——· ——— ·—· — / ·— —· / ——— ··— — ·—·· ·· —· · / ·· ··· ··· ··— ·';
	@override String get reference => '·—— ···· ·· —·—· ···· / ——— ··— — ·—·· ·· —· ·';
	@override String get severity => '···· ——— ·—— / —··· ·— —·· / ·· ··· / ·· — ··——··';
	@override String get minor => '—— ·· —· ——— ·—· / —· ·· —';
	@override String get major => '—··· ·· ——· / —·· · ·— ·—··';
	@override String get explanation => '·—— ···· ·— — ·————· ··· / ·—— ·—· ——— —· ——· / ·—— ·· — ···· / ·· — ··——··';
	@override String get explanationHint => '·—— ···· ·— — / — ···· · / ——— ··— — ·—·· ·· —· · / ——· · — ··· / ·—— ·—· ——— —· ——· ——··—— / ·— —· —·· / ·—— ···· · ·—· ·';
	@override String get send => '··· · —· —··';
	@override String get sending => '··· · —· —·· ·· —· ——· / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / — / — ···· ·— —· —·— ···';
	@override String get copy => '—·—· ——— ·——· —·—— / ·—· · ·——· ——— ·—· —';
	@override String get notSent => '—·—· ——— ··— ·—·· —·· —· ·————· — / ··· · —· —·· / — ···· · / ·—· · ·——· ——— ·—· —';
	@override String get copied => '·—· · ·——· ——— ·—· — / —·—· ——— ·——· ·· · —··';
	@override String get notCopied => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ——— ·——· —·—— / — ···· · / ·—· · ·——· ——— ·—· —';
}

// Path: map.postcard
class _Translations$map$postcard$cw extends Translations$map$postcard$en {
	_Translations$map$postcard$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get button => '——— ·——· · ·—· ·— — ·· ——— —· / ·——· ——— ··· — —·—· ·— ·—· —··';
	@override String title({required Object title}) => '·——· ——— ··· — —·—· ·— ·—· —·· / ··—· ——— ·—· / ${title}';
	@override String get portrait => '·——· ——— ·—· — ·—· ·— ·· —';
	@override String get landscape => '·—·· ·— —· —·· ··· —·—· ·— ·——· ·';
	@override String get square => '··· ——·— ··— ·— ·—· ·';
	@override String get save => '··· ·— ···— · …';
	@override String get download => '—·· ——— ·—— —· ·—·· ——— ·— —··';
	@override String get share => '··· ···· ·— ·—· ·';
	@override String get copy => '—·—· ——— ·——· —·——';
	@override String get copied => '—·—· ——— ·——· ·· · —·· / — ——— / — ···· · / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··';
	@override String saved({required Object path}) => '··· ·— ···— · —·· / — ——— / ${path}';
	@override String downloaded({required Object name}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${name}';
	@override String savedMany({required Object count, required Object path}) => '··· ·— ···— · —·· / ${count} / ·· —— ·— ——· · ··· / — ——— / ${path}';
	@override String savedFiles({required Object names}) => '··· ·— ···— · —·· / ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} / — / ${names} / ···· ·— —·· / ·— ·—·· ·—· · ·— —·· —·—— / —··· · · —· / ··· ·— ···— · —··';
	@override String downloadedMany({required Object count}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· / ${count} / ·· —— ·— ——· · ··· / — / ·— ·—·· ·—·· ——— ·—— / — ···· · —— / ·· ··—· / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ·— ··· —·— ···';
	@override String get mapLeftOut => '— ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ·—·· ——— ·— —·· ——··—— / ··· ——— / ·· — / ·—— ·— ··· / ·—·· · ··—· — / ——— ··— —';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} / — / — ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ·—·· ——— ·— —·· ——··—— / ··· ——— / ·· — / ·—— ·— ··· / ·—·· · ··—· — / ——— ··— —';
	@override String continued({required Object title}) => '${title} / —·——· —·—· ——— —· — ·· —· ··— · —·· —·——·—';
	@override String get previousPage => '·——· ·—· · ···— ·· ——— ··— ··· / ·——· ·— ——· ·';
	@override String get nextPage => '—· · —··— — / ·——· ·— ——· ·';
	@override String pageOf({required Object page, required Object count}) => '·——· ·— ——· · / ${page} / ——— ··—· / ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——·—',
		other: '${count} / ——·— ···',
	);
	@override String get options => '·——· ——— ··· — —·—· ·— ·—· —·· / ——— ·——· — ·· ——— —· ···';
	@override String get bandLegend => '··· ···· ——— ·—— / —··· ·— —· —·· / ·—·· · ——· · —· —··';
	@override String get grayline => '··· ···· ——— ·—— / ——· ·—· ·— —·—— ·—·· ·· —· ·';
	@override String get sectionsAndOrder => '··· ··— —— —— ·— ·—· —·—— / ··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—· ·· —· ——·';
	@override String get sectionDays => '· ·— —·—· ···· / —·· ·— —·——';
	@override String get reset => '·—· · ··· · —';
	@override String failed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —— ·— —·— · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ———··· / ${error}';
	@override String get mapNotReady => '— ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ··—· ·· —· ·· ··· ···· / ·—·· ——— ·— —·· ·· —· ——· ·—·—·— / —·—· ···· · —·—· —·— / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String saveFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— ···— · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ———··· / ${error}';
	@override String get copyFailed => '— ···· · / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —·· / —·· ·· —·· —· ·————· — / — ·— —·— · / — ···· · / ·· —— ·— ——· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get shareFailed => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ···· ·— ·—· · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get fileName => '·——· ——— ··· — —·—· ·— ·—· —··';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$cw extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get noQsos => '—· ——— / ——·— ··· ——— ··· / —·—— · — ·—·—·— ·—·—·— ·—·—·— / ·—·· · — ·————· ··· / ——· · — / ——— —· / — ···· · / ·— ·· ·—· —·—·——';
	@override String get qsoCountOne => '·———— / ——·— ··· ———';
	@override String qsoCountOther({required Object count}) => '${count} / ——·— ··· ——— ···';
	@override String qsosInTime({required Object count, required Object time}) => '${count} / ·· —· / ${time}';
	@override String sinceLast({required Object time}) => '${time} / ··· ·· —· —·—· · / ·—·· ·— ··· —';
	@override String ratePer10({required Object rate}) => '${rate} / ——·— —··—· ···· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— —————';
	@override String ratePer100({required Object rate}) => '${rate} / ——·— —··—· ···· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— ————— —————';
	@override String distanceTo({required Object distance}) => '${distance} / — ———';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / — ———';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / — ———';
	@override String distanceAway({required Object distance}) => '${distance} / ·— ·—— ·— —·——';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / ·— ·—— ·— —·——';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / ·— ·—— ·— —·——';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer} ———··· / ${notice}';
	@override String get noticeDupe => '—·· ··— ·——· · —·—·——';
	@override String get noticeNewBand => '—· · ·—— / —··· ·— —· —··';
	@override String get noticeNewMode => '—· · ·—— / —— ——— —·· ·';
	@override String get noticeNewDXCC => '—· · ·—— / —·· —··— —·—· —·—·';
	@override String get noticeNewState => '—· · ·—— / ··· — ·— — ·';
	@override String get noticeNewProvince => '—· · ·—— / ·——· ·—· ——— ···— ·· —· —·—· ·';
	@override String get noticeNewDay => '—· · ·—— / —·· ·— —·——';
	@override String get noticeNewRef => '—· · ·—— / ·—· · ··—·';
	@override String get noticeNewMult => '—· · ·—— / —— ··— ·—·· —';
	@override String get noticeNewZone => '—· · ·—— / ——·· ——— —· ·';
	@override String get noticeInvalidMode => '·—— ·—· ——— —· ——· / —— ——— —·· ·';
	@override String get noticeInvalidBand => '·—— ·—· ——— —· ——· / —··· ·— —· —··';
	@override String get noticeInvalidCategory => '—· ——— — / ·—— ——— ·—· —·— ·— —··· ·—·· ·';
	@override String get noticeOverTime => '— ·· —— · / ——— ···— · ·—·';
	@override String get noticeWorkedBefore => '·—— ——— ·—· —·— · —·· / —··· · ··—· ——— ·—· ·';
	@override String get noticeNewPark => '—· · ·—— / ·——· ·— ·—· —·—';
	@override String get noticeNewSection => '—· · ·—— / ··· · —·—· — ·· ——— —·';
	@override String get noticeBonusStation => '—··· ——— —· ··— ··· / ··· — ·— — ·· ——— —· —·—·——';
	@override String get noticeMissingExchange => '—· ——— / · —··— —·—· ···· ·— —· ——· ·';
	@override String get noticeInvalidExchange => '—··· ·— —·· / · —··— —·—· ···· ·— —· ——· ·';
	@override String get noticeUnknownEvent => '··— —· —·— —· ——— ·—— —· / · ···— · —· —';
	@override String get noticeIncompleteCall => '·· —· —·—· ——— —— ·——· ·—·· · — · / —·—· ·— ·—·· ·—·· / — / —· ——— — / ··· —·—· ——— ·—· · —··';
	@override String get noticeOurGrid => '··· · — / ——— ··— ·—· / ——· ·—· ·· —··';
	@override String get noticeRareCounty => '·—· ·— ·—· · / —·—· ——— ··— —· — —·—— —·—·——';
	@override String get noticeOurLocation => '··· · — / ——— ··— ·—· / —·—· ——— ··— —· — —·——';
	@override String get noticeShortGrid => '——· ·—· ·· —·· / — ——— ——— / ··· ···· ——— ·—· —';
}

// Path: qsoList.find
class _Translations$qsoList$find$cw extends Translations$qsoList$find$en {
	_Translations$qsoList$find$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => '··—· ·· —· —·· / ·· —· / ·—·· ——— ——· / —·——· ${shortcut} —·——·—';
	@override String get menuItemNoShortcut => '··—· ·· —· —·· / ·· —· / ·—·· ——— ——·';
	@override String get hint => '——·— ··· ——— / —· ··— —— —··· · ·—· / ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get noMatches => '—· ——— / —— ·— — —·—· ····';
	@override String get noOperationQsos => '—· ——— / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get noPeriodQsos => '—· ——— / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ·——· · ·—· ·· ——— —··';
	@override String get outsideQsosOne => '·———— / ——·— ··· ——— / ——— ··— — ··· ·· —·· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String outsideQsosOther({required Object count}) => '${count} / ——·— ··· ——— ··· / ——— ··— — ··· ·· —·· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get pastQsosOne => '·———— / ·——· ·— ··· — / ——·— ··· ———';
	@override String pastQsosOther({required Object count}) => '${count} / ·——· ·— ··· — / ——·— ··· ——— ···';
}

// Path: callInfo.history
class _Translations$callInfo$history$cw extends Translations$callInfo$history$en {
	_Translations$callInfo$history$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} / ·· —· / ·—·· ·— ··· — / ——··· / —·· ·— —·—— ···';
	@override String today({required Object n}) => '${n} / — ——— —·· ·— —·——';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${n} / ——·— ··· ———',
		other: '${n} / ——·— ··· ——— ···',
	);
}

// Path: settings.theme
class _Translations$settings$theme$cw extends Translations$settings$theme$en {
	_Translations$settings$theme$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '— ···· · —— · / —— ——— —·· ·';
	@override String get system => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···';
	@override String get light => '·—·· ·· ——· ···· —';
	@override String get dark => '—·· ·— ·—· —·—';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$cw extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get system => '··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···';
	@override String get light => '·— ·—·· ·—— ·— —·—— ··· / ·· —· / ·—·· ·· ——· ···· — / —— ——— —·· ·';
	@override String get dark => '·— ·—·· ·—— ·— —·—— ··· / ·· —· / —·· ·— ·—· —·— / —— ——— —·· ·';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$cw extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => '··· —— ·— ·—·· ·—·· · ··· — —····— —····—';
	@override String get smallestMinus => '··· —— ·— ·—·· ·—·· · ··· — —····—';
	@override String get smallest => '··· —— ·— ·—·· ·—·· · ··· —';
	@override String get smaller => '··· —— ·— ·—·· ·—·· · ·—·';
	@override String get normal => '—· ——— ·—· —— ·— ·—··';
	@override String get larger => '·—·· ·— ·—· ——· · ·—·';
	@override String get largest => '·—·· ·— ·—· ——· · ··· —';
	@override String get largestPlus => '·—·· ·— ·—· ——· · ··· — ·—·—·';
	@override String get largestPlusPlus => '·—·· ·— ·—· ——· · ··· — ·—·—· ·—·—·';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$cw extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·— · · ·——· / —·· · ···— ·· —·—· · / ·— ·—— ·— —·— ·';
	@override String get descriptionOn => '··· — ·— —·—— ·· —· ——· / ·— ·—— ·— —·— · / ·—— ···· ·· ·—·· · / —·—— ——— ··— / ·— ·—· · / ——— —· / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ···— ·· · ·—— / ——— ·—· / ·— / ··· —·—— —· —·—· / ·· ··· / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ···';
	@override String get descriptionOff => '··· ·—·· · · ·——· ·· —· ——· / ·— ··· / ··— ··· ··— ·— ·—··';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$cw extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get auto => '·— ··— — ——— —— ·— — ·· —·—·';
	@override String get densest => '—·· · —· ··· · ··· —';
	@override String get dense => '—·· · —· ··· ·';
	@override String get normal => '—· ——— ·—· —— ·— ·—··';
	@override String get sparse => '··· ·——· ·— ·—· ··· ·';
	@override String get sparsest => '··· ·——· ·— ·—· ··· · ··· —';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$cw extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get kilometers => '—·— ·· ·—·· ——— —— · — · ·—· ···';
	@override String get miles => '—— ·· ·—·· · ···';
}

// Path: settings.logging
class _Translations$settings$logging$cw extends Translations$settings$logging$en {
	_Translations$settings$logging$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·—·· ——— ——· ——· ·· —· ——·';
	@override late final _Translations$settings$logging$leftieMode$cw leftieMode = _Translations$settings$logging$leftieMode$cw._(_root);
	@override late final _Translations$settings$logging$countryFlags$cw countryFlags = _Translations$settings$logging$countryFlags$cw._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$cw countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$cw._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$cw suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$cw._(_root);
	@override late final _Translations$settings$logging$showBearing$cw showBearing = _Translations$settings$logging$showBearing$cw._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$cw showReverseBearing = _Translations$settings$logging$showReverseBearing$cw._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$cw switchSentRcvd = _Translations$settings$logging$switchSentRcvd$cw._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$cw jumpAfterRST = _Translations$settings$logging$jumpAfterRST$cw._(_root);
	@override late final _Translations$settings$logging$defaultReport$cw defaultReport = _Translations$settings$logging$defaultReport$cw._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$cw defaultReportCW = _Translations$settings$logging$defaultReportCW$cw._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$cw defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$cw._(_root);
	@override late final _Translations$settings$logging$numbersRow$cw numbersRow = _Translations$settings$logging$numbersRow$cw._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$cw numbersRowExtra = _Translations$settings$logging$numbersRowExtra$cw._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$cw numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$cw._(_root);
	@override String get bands => '·——· ·—· · ··—· · ·—· ·—· · —·· / —··· ·— —· —·· ···';
	@override String get modes => '·——· ·—· · ··—· · ·—· ·—· · —·· / —— ——— —·· · ···';
}

// Path: settings.catServer
class _Translations$settings$catServer$cw extends Translations$settings$catServer$en {
	_Translations$settings$catServer$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ·— — / ··· · ·—· ···— · ·—·';
	@override String get description => '·— ·—·· ·—·· ——— ·—— / ——— — ···· · ·—· / ·— ·——· ·——· ··· / —·——· ·—— ··· ·——— — —····— —··— ——··—— / ·—·· ——— ——· ——· · ·—· ··· ——··—— / · — —·—· —·——·— / — ——— / —·—· ——— —· — ·—· ——— ·—·· / — ···· · / ·—· ·— —·· ·· ——— / — ···· ·—· ——— ··— ——· ···· / ···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· ·—·—·—';
	@override String get protocol => '·——· ·—· ——— — ——— —·—· ——— ·—··';
	@override late final _Translations$settings$catServer$protocolOpts$cw protocolOpts = _Translations$settings$catServer$protocolOpts$cw._(_root);
	@override String get port => '·——· ——— ·—· —';
	@override String get openAccess => '——— ·——· · —· / ·— —·—· —·—· · ··· ···';
	@override String get openAccessOn => '·— —· —·—— / —·—· ——— —— ·——· ··— — · ·—· / ——— —· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— / —·—· ·— —· / —·—· ——— —· —· · —·—· — ·—·—·—';
	@override String get openAccessOff => '——— —· ·—·· —·—— / ·— ·——· ·——· ··· / ——— —· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· / —·—· ·— —· / —·—· ——— —· —· · —·—· — ·—·—·—';
	@override String get off => '——— ··—· ··—· ·—·—·—';
	@override String starting({required Object protocol}) => '${protocol} ——··—— / ··· — ·— ·—· — ·· —· ——· …';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} / ——— —· / ·——· ——— ·—· — / ${port} ·—·—·— / —·—· ·—·· ·· · —· — ··· / —·—· ——— —· —· · —·—· — · —·· ———··· / ${clients} ·—·—·—';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} / ——— —· / ·——· ——— ·—· — / ${port} ——··—— / —··· ··— — / —· ——— / —— ·— ·· —· / ···— ··—· ——— / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· ·—·—·—';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— / ·· ··· / ··— ··· ·· —· ——· / ·· — ——··—— / ——— ··—· — · —· / ${protocol} / ·· — ··· · ·—·· ··—· ·—·—·— / —·—· ·—·· ——— ··· · / — ···· ·— — / ·——· ·—· ——— ——· ·—· ·— —— / ——— ·—· / —·—· ···· ——— ——— ··· · / ·— —· ——— — ···· · ·—· / ·——· ——— ·—· — ·—·—·—';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· / —·· ——— · ··· / —· ——— — / ·— ·—·· ·—·· ——— ·—— / ·· — ·—·—·— / —·—· ···· ——— ——— ··· · / ·— / ·——· ——— ·—· — / ·— —··· ——— ···— · / ·———— ————— ··——— ····— ·—·—·—';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} / ··· — ——— ·——· ·——· · —·· / ·—·· ·· ··· — · —· ·· —· ——· / ——— —· / ·——· ——— ·—· — / ${port} ·—·—·— / — ·—· —·—— ·· —· ——· / ·— ——· ·— ·· —· …';
}

// Path: settings.cluster
class _Translations$settings$cluster$cw extends Translations$settings$cluster$en {
	_Translations$settings$cluster$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·· —··— / —·—· ·—·· ··— ··· — · ·—·';
	@override String get description => '— ···· · / ··· · ·—· ···— · ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·——· ——— ··· — / ··· ·——· ——— — ··· / — ——— / ·— —· —·· / ·—· · ·— —·· / ··· ·——· ——— — ··· / ··—· ·—· ——— —— ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· ·—·—·—';
	@override String get server => '—·—· ·—·· ··— ··· — · ·—· / ··· · ·—· ···— · ·—·';
	@override String get selectServer => '··· · ·—·· · —·—· — / ··· · ·—· ···— · ·—·';
	@override String get serverOther => '——— — ···· · ·—·';
	@override String serverOtherIncomplete({required Object node}) => '—· ——— / ···· ——— ··· — / · —· — · ·—· · —·· / —·—— · — ——··—— / ··· ——— / ··· ·——· ——— — ··· / ——· ——— / — ——— / ${node}';
	@override String get customHost => '··· · ·—· ···— · ·—·';
	@override String get customPort => '·——· ——— ·—· —';
	@override String get password => '·——· ·— ··· ··· ·—— ——— ·—· —··';
	@override String get passwordDescription => '——— —· ·—·· —·—— / ·· ··—· / —· · · —·· · —··';
	@override String passwordStored({required Object node}) => '·——· ·— ··· ··· ·—— ——— ·—· —·· / ——— —· / ··—· ·· ·—·· · / ··—· ——— ·—· / ${node}';
	@override String get scrollback => '·—·· ·· —· · ··· / —·— · ·——· —';
	@override String scrollbackOpt({required Object count}) => '${count} / ·—·· ·· —· · ···';
	@override String get connection => '—·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get statusIdle => '—· ——— — / —·—· ——— —· —· · —·—· — · —·· ·—·—·— / —·—· ——— —· —· · —·—· — ··· / ·—— ···· · —· / ·— —· / · —··— — · —· ··· ·· ——— —· / —· · · —·· ··· / ·· — ·—·—·— / — ·— ·——· / — ——— / — · ··· — ·—·—·—';
	@override String statusConnecting({required Object node}) => '—·—· ——— —· —· · —·—· — ·· —· ——· / — ——— / ${node} …';
	@override String statusConnected({required Object node, required Object call}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${node} / ·— ··· / ${call} ·—·—·—';
	@override String statusFailed({required Object node, required Object reason}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —·—· ——— —· —· · —·—· — / — ——— / ${node} ———··· / ${reason}';
	@override String get statusUnsupported => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· · / ·—— · —··· / ···— · ·—· ··· ·· ——— —· ·—·—·—';
	@override late final _Translations$settings$cluster$errors$cw errors = _Translations$settings$cluster$errors$cw._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$cw extends Translations$settings$spotting$en {
	_Translations$settings$spotting$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ·——· ——— — — ·· —· ——·';
	@override String get respotInterval => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / · ···— · ·—· —·——';
	@override String minutes({required Object minutes}) => '${minutes} / —— ·· —·';
	@override String get autoRespotByDefault => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —··· —·—— / —·· · ··—· ·— ··— ·—·· —';
	@override String get autoRespotByDefaultOn => '· —· ·— —··· ·—·· · / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ·— ··—· — · ·—· / ·— —· —·—— / ··· ·——· ——— — / ·· ··· / ·——· ——— ··· — · —··';
	@override String get autoRespotByDefaultOff => '·—· · ——·— ··— ·· ·—· · / ··— ··· · ·—· / ·— —·—· — ·· ——— —· / — ——— / · —· ·— —··· ·—·· · / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— — — ·· —· ——·';
	@override String get pulseBeforeRespot => '·——· ··— ·—·· ··· · / —··· · ··—· ——— ·—· · / · ·— —·—· ···· / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— —';
	@override String pulseBeforeRespotOn({required Object seconds}) => '— ···· · / ··· ·——· ——— — — ·· —· ——· / —·—· ···· ·· ·——· / ·——· ··— ·—·· ··· · ··· / —··· ·—·· ··— · / ··—· ——— ·—· / — ···· · / ${seconds} / ··· · —·—· ——— —· —·· ··· / —··· · ··—· ——— ·—· · / · ·— —·—· ···· / ·—· · —····— ··· ·——· ——— —';
	@override String get pulseBeforeRespotOff => '—· ——— / ·——· ··— ·—·· ··· ·· —· ——· / —··· · ··—· ——— ·—· · / ·— —· / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— —';
}

// Path: settings.radio
class _Translations$settings$radio$cw extends Translations$settings$radio$en {
	_Translations$settings$radio$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—··';
	@override String get loggingAndCat => '·—·· ——— ——· ——· ·· —· ——· / ·—··· / —·—· ·— —';
	@override String get tuningSection => '— ··— —· ·· —· ——·';
	@override String get keyerSection => '—·— · —·—— · ·—·';
	@override String get servicesSection => '··· · ·—· ···— ·· —·—· · ···';
	@override String get stationConfigurationSection => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get moreSettings => '—— ——— ·—· · / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ··· · — — ·· —· ——· ···';
	@override late final _Translations$settings$radio$units$cw units = _Translations$settings$radio$units$cw._(_root);
	@override late final _Translations$settings$radio$pttKey$cw pttKey = _Translations$settings$radio$pttKey$cw._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$cw smartVfoSnap = _Translations$settings$radio$smartVfoSnap$cw._(_root);
	@override late final _Translations$settings$radio$snapDebounce$cw snapDebounce = _Translations$settings$radio$snapDebounce$cw._(_root);
	@override late final _Translations$settings$radio$snapLongMove$cw snapLongMove = _Translations$settings$radio$snapLongMove$cw._(_root);
	@override late final _Translations$settings$radio$snapMinMove$cw snapMinMove = _Translations$settings$radio$snapMinMove$cw._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$cw snapMinSpeed = _Translations$settings$radio$snapMinSpeed$cw._(_root);
	@override late final _Translations$settings$radio$enterSends$cw enterSends = _Translations$settings$radio$enterSends$cw._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$cw keyerSpeed = _Translations$settings$radio$keyerSpeed$cw._(_root);
	@override late final _Translations$settings$radio$cwMessages$cw cwMessages = _Translations$settings$radio$cwMessages$cw._(_root);
	@override late final _Translations$settings$radio$voiceMessages$cw voiceMessages = _Translations$settings$radio$voiceMessages$cw._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$cw avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$cw._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$cw zeroBeatRange = _Translations$settings$radio$zeroBeatRange$cw._(_root);
}

// Path: settings.help
class _Translations$settings$help$cw extends Translations$settings$help$en {
	_Translations$settings$help$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '···· · ·—·· ·——· / ·—··· / ·—· · ··· ——— ··— ·—· —·—· · ···';
	@override String get description => '—·—· ——— —— —— ··— —· ·· — —·—— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· —';
	@override String get forums => '···· ·— —— ··——— —·— / ··—· ——— ·—· ··— —— ···';
	@override String get forumsDescription => '··—· ·· —· —·· / ···· · ·—·· ·——· ——··—— / ——· ·· ···— · / ··—· · · —·· —··· ·— —·—· —·— ——··—— / —·· ·· ··· —·—· ··— ··· ··· / ·· —·· · ·— ··· …';
	@override String get chat => '···· ·— —— ··——— —·— / —·—· ···· ·— —';
	@override String get chatDescription => '— ···· · / —·· ·· ··· —·—· ——— ·—· —·· / ··· · ·—· ···— · ·—· / ··—· ——— ·—· / ——— ··— ·—· / ——— —· ·—·· ·· —· · / —·—· ——— —— —— ··— —· ·· — —·——';
	@override String get youtube => '···· ·— —— ··——— —·— / —·—— ——— ··— — ··— —··· ·';
	@override String get youtubeDescription => '···— ·· —·· · ——— ··· / ·— —· —·· / ·—·· ·· ···— · / ··· — ·—· · ·— —— ···';
	@override String get instagram => '···· ·— —— ··——— —·— / ·· —· ··· — ·— ——· ·—· ·— ——';
	@override String get instagramDescription => '—··· · —·—· ·— ··— ··· · / —·—— ——— ··— / —·—· ·— —· —· ——— — / ···· ·— ···— · / — ——— ——— / —— ·— —· —·—— / ·——· ···· ——— — ——— ··· …';
	@override String get bluesky => '···· ·— —— ··——— —·— / —··· ·—·· ··— · ··· —·— —·——';
	@override String get blueskyDescription => '··—· ——— ·—·· ·—·· ——— ·—— / ··— ··· / ··—· ——— ·—· / —· · ·—— ··· / ·— —· —·· / ··— ·——· —·· ·— — · ···';
	@override String get contact => '—·—· ——— —· — ·— —·—· — / ··— ···';
	@override String get contactDescription => '···· · ·—·· ·——· ·——·—· ···· ·— —— ··——— —·— ·—·—·— —·—· ——— —— / — / —··· ··— — / — ·—· —·—— / — ···· · / ··—· ——— ·—· ··— —— ··· / ——— ·—· / —·—· ···· ·— — / ··—· ·· ·—· ··· — —·—·——';
}

// Path: settings.exports
class _Translations$settings$exports$cw extends Translations$settings$exports$en {
	_Translations$settings$exports$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '· —··— ·——· ——— ·—· — ···';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$cw extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get activities => '·— —·—· — ·· ···— ·· — ·· · ···';
	@override String get hunting => '···· ··— —· — ·· —· ——·';
	@override String get contests => '—·—· ——— —· — · ··· — ···';
	@override String get lookups => '·—·· ——— ——— —·— ··— ·——· ···';
	@override String get dashboard => '—·· ·— ··· ···· —··· ——— ·— ·—· —··';
}

// Path: settings.map
class _Translations$settings$map$cw extends Translations$settings$map$en {
	_Translations$settings$map$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—— ·— ·——· ···';
	@override late final _Translations$settings$map$style$cw style = _Translations$settings$map$style$cw._(_root);
	@override late final _Translations$settings$map$showCallsigns$cw showCallsigns = _Translations$settings$map$showCallsigns$cw._(_root);
	@override late final _Translations$settings$map$showGrayline$cw showGrayline = _Translations$settings$map$showGrayline$cw._(_root);
	@override late final _Translations$settings$map$styleOpts$cw styleOpts = _Translations$settings$map$styleOpts$cw._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$cw extends Translations$settings$privacy$en {
	_Translations$settings$privacy$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·——· ·—· ·· ···— ·— —·—· —·——';
	@override late final _Translations$settings$privacy$shareAppData$cw shareAppData = _Translations$settings$privacy$shareAppData$cw._(_root);
	@override late final _Translations$settings$privacy$shareOpData$cw shareOpData = _Translations$settings$privacy$shareOpData$cw._(_root);
	@override String get privacyPolicy => '·——· ·—· ·· ···— ·— —·—· —·—— / ·——· ——— ·—·· ·· —·—· —·——';
	@override String get termsOfService => '— · ·—· —— ··· / ——— ··—· / ··· · ·—· ···— ·· —·—· ·';
}

// Path: settings.sync
class _Translations$settings$sync$cw extends Translations$settings$sync$en {
	_Translations$settings$sync$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—·';
	@override String get moreSettings => '—— ——— ·—· · / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ···';
	@override String get enable => '· —· ·— —··· ·—·· · / ··· —·—— —· —·—·';
	@override String get deviceKey => '—·· · ···— ·· —·—· · / —·— · —·——';
}

// Path: settings.peers
class _Translations$settings$peers$cw extends Translations$settings$peers$en {
	_Translations$settings$peers$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·——· · · ·—· / —·· · ···— ·· —·—· · ···';
	@override String get enable => '—·—· ——— —· —· · —·—· — / — ——— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···';
	@override String get enableDescription => '·— ·—·· ·—·· ——— ·—— / ··· ···· ·— ·—· ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / ·—·· ——— ——· ——· ·· —· ——· ——··—— / —·—· ·— — / ·— —· —·· / ——· ·——· ··· / ·—— ·· — ···· / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / ——— ···— · ·—· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·—';
	@override String get bleEnable => '—·—· ——— —· —· · —·—· — / ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ····';
	@override String get bleDescription => '··— ··· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / — ——— / —·—· ——— —· —· · —·—· — / · ···— · —· / ·· ··—· / — ···· · ·—· · / ·· ··· / —· ——— / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·—';
	@override String get thisDevice => '— ···· ·· ··· / —·· · ···— ·· —·—· ·';
	@override String get deviceName => '—· ·— —— ·';
	@override String get deviceNameHint => '···· ——— ·—— / — ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / ··· · · —· / —··· —·—— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···';
	@override String get pairedDevices => '·—·· ·· —· —·— · —·· / —·· · ···— ·· —·—· · ···';
	@override String get noPairedDevices => '—· ——— / —·· · ···— ·· —·—· · ··· / ·—·· ·· —· —·— · —·· / —·—— · — ·—·—·— / — ··— ·—· —· / — ···· ·· ··· / ——— —· ——··—— / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —· · — ·—— ——— ·—· —·— ——··—— / — ——— / ·—·· ·· —· —·— / — ···· · —— ·—·—·—';
	@override String deviceListProblem({required Object error}) => '—·—· ·— —· ·————· — / ·—· · ·— —·· / —·—— ——— ··— ·—· / ·—·· ·· —· —·— · —·· / —·· · ···— ·· —·—· · ··· ———··· / ${error}';
	@override String get nearby => '—· · ·— ·—· —··· —·——';
	@override String get connected => '—·—· ——— —· —· · —·—· — · —··';
	@override String get viaBluetooth => '···— ·· ·— / —··· ·—·· ··— · — ——— ——— — ····';
	@override String get connecting => '—·—· ——— —· —· · —·—· — ·· —· ——· …';
	@override String get syncing => '··· —·—— —· —·—· ·· —· ——· …';
	@override String get waitingForThem => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· ·';
	@override String get notConnected => '—· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get wantsToPair => '·—— ·— —· — ··· / — ——— / ··· ···· ·— ·—· · / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get allow => '·— ·—·· ·—·· ——— ·——';
	@override String get link => '·—·· ·· —· —·—';
	@override String get reject => '·—· · ·——— · —·—· —';
	@override String get forget => '··—· ——— ·—· ——· · —';
	@override String forgetTitle({required Object name}) => '··—· ——— ·—· ——· · — / ${name} ··——··';
	@override String get forgetBody => '·· — / ·—— ·· ·—·· ·—·· / ··· — ——— ·——· / ··· —·—— —· —·—· ·· —· ——· / ·—— ·· — ···· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / —·—— ——— ··— / —·—· ·— —· / ·— ·—·· ·—·· ——— ·—— / ·· — / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ——··—— / ·— —· —·· / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —·· / ·— ·—· · / —·— · ·——· — ·—·—·—';
	@override String pairTitle({required Object name}) => '·—·· ·· —· —·— / ·—— ·· — ···· / ${name}';
	@override String get pairBody => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— / ·— —· —·· / ·—— ·— —· — ··· / — ——— / —·—· ——— —· —· · —·—· — ·—·—·—';
	@override String get pairBodyBle => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / —· · ·— ·—· —··· —·—— / ·— —· —·· / ·—— ·— —· — ··· / — ——— / —·—· ——— —· —· · —·—· — / ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ·—·—·—';
	@override String get pairIdLabel => '—·· · ···— ·· —·—· · / ·· —··';
	@override String get pairWarning => '——— —· ·—·· —·—— / ·—·· ·· —· —·— / ·—— ·· — ···· / —·· · ···— ·· —·—· · ··· / —·—— ——— ··— / ·—· · —·—· ——— ——· —· ·· ··· · ·—·—·— / ·— —· —·—— / —·· · ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —· · — ·—— ——— ·—· —·— / —·—· ·— —· / ··· · —· —·· / ·— / ·—· · ——·— ··— · ··· — ·—·—·—';
	@override String get pairWarningBle => '——— —· ·—·· —·—— / ·—·· ·· —· —·— / ·—— ·· — ···· / —·· · ···— ·· —·—· · ··· / —·—— ——— ··— / ·—· · —·—· ——— ——· —· ·· ··· · ·—·—·— / ·— —· —·—— / —· · ·— ·—· —··· —·—— / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· · —· —·· / ·— / ·—· · ——·— ··— · ··· — ·—·—·—';
	@override String problem({required Object error}) => '—·—· ·— —· ·————· — / ·—· · ·— —·—· ···· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ———··· / ${error}';
	@override String bleProblem({required Object error}) => '—··· ·—·· ··— · — ——— ——— — ···· ———··· / ${error}';
	@override String statusConnected({required Object device}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${device}';
	@override String statusLost({required Object device}) => '·—·· ——— ··· — / —·—· ——— —· —· · —·—· — ·· ——— —· / — ——— / ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => '·——· · · ·—· / —·· · ···— ·· —·—· · ··· ———··· / ${connected} / ——— ··—· / ${linked} / —·—· ——— —· —· · —·—· — · —··';
	@override String get screenEnable => '··· ···· ·— ·—· · / ··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ···';
	@override String get screenDescription => '·— ·—·· ·—·· ——— ·—— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / — ——— / ··· ···· ——— ·—— / ··· —·—· ·—· · · —· ··· / ——— ·—· / ·—— ·· —· —·· ——— ·—— ··· / ··—· ·—· ——— —— / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—·';
	@override String get screenSources => '··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ···';
	@override String get screenRefresh => '·—· · ··—· ·—· · ··· ···· / — ···· · / ·—·· ·· ··· —';
	@override String get screenUnsupportedPlatform => '— ···· ·· ··· / —·· · ···— ·· —·—· · / —·—· ·— —· ·————· — / ··· ···· ·— ·—· · / ·· — ··· / ··· —·—· ·—· · · —· ·—·—·— / —— ·— —·—· ——— ··· / —·—· ·— —· —·—·—· / · ···— · ·—· —·—— / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· ···· ——— ·—— / ——— —· · / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get screenUnsupportedVersion => '··· ···· ·— ·—· ·· —· ——· / ·— / ··· —·—· ·—· · · —· / —· · · —·· ··· / —— ·— —·—· ——— ··· / ·———— ··——— ·—·—·— ···—— / ——— ·—· / ·—·· ·— — · ·—· ·—·—·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· — ·· ·—·· ·—·· / ··· ···· ——— ·—— / ·— / ··· —·—· ·—· · · —· / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get screenNeedsPermission => '—— ·— —·—· ——— ··· / —· · · —·· ··· / —·—— ——— ··— ·—· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / — ——— / ·—· · —·—· ——— ·—· —·· / — ···· · / ··· —·—· ·—· · · —· / —··· · ··—· ——— ·—· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ··· ···· ·— ·—· · / ——— —· · ·—·—·—';
	@override String get screenGrantPermission => '·— ··· —·— / ··—· ——— ·—· / ·——· · ·—· —— ·· ··· ··· ·· ——— —·';
	@override String get screenRelaunchAfterGranting => '·— ·—·· ·—·· ——— ·—— / ·· — / ·· —· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / ··— —· —·· · ·—· / ·——· ·—· ·· ···— ·— —·—· —·—— / ·—··· / ··· · —·—· ··— ·—· ·· — —·—— / → / ··· —·—· ·—· · · —· / ·—· · —·—· ——— ·—· —·· ·· —· ——· ——··—— / — ···· · —· / ——·— ··— ·· — / ·— —· —·· / ·—· · ——— ·——· · —· / — ···· ·· ··· / ·— ·——· ·——· / — / —— ·— —·—· ——— ··· / ——— —· ·—·· —·—— / — · ·—·· ·—·· ··· / ·— —· / ·— ·——· ·——· / ·— —··· ——— ··— — / — ···· · / —·—· ···· ·— —· ——· · / ——— —· / ·· — ··· / —· · —··— — / ·—·· ·— ··— —· —·—· ···· ·—·—·—';
	@override String screenProblem({required Object error}) => '··· —·—· ·—· · · —· / ··· ···· ·— ·—· ·· —· ——· ———··· / ${error}';
	@override String get screenChooseTitle => '—·—· ···· ——— ——— ··· · / ·—— ···· ·— — / — ——— / ··· ···· ·— ·—· ·';
	@override String get screenChooseButton => '—·—· ···· ——— ——— ··· · / ·—— ···· ·— — / — ——— / ··· ···· ·— ·—· · …';
	@override String get screenTabScreens => '··· —·—· ·—· · · —· ···';
	@override String get screenTabApps => '·— ·——· ·——· ···';
	@override String get screenTabWindows => '·—— ·· —· —·· ——— ·—— ···';
	@override String get screenTabEmpty => '—· ——— — ···· ·· —· ——· / ——— ··—· / — ···· ·· ··· / —·— ·· —· —·· / ·—— ·— ··· / ··—· ——— ··— —· —·· ·—·—·—';
	@override String get screenSharedSummaryNone => '—· ——— — ···· ·· —· ——· / —·—· ···· ——— ··· · —· / —·—— · — ·—·—·—';
	@override String get screenThisDevice => '— ···· ·· ··· / —·· · ···— ·· —·—· ·';
	@override String screenSharedTo({required Object devices}) => '··· ···· ——— ·—— —· / ——— —· / ${devices}';
	@override String get screenSharedToNobody => '—· ——— — / —··· · ·· —· ——· / ··· ···· ——— ·—— —·';
	@override String screenStopSharing({required Object name}) => '··· — ——— ·——· / ··· ···· ·— ·—· ·· —· ——· / ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$cw extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get configuration => '··· —·—— —· —·—· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get enableTitle => '··· —·—— —· —·—· / ·—— ·· — ···· / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—·';
	@override String get enabledDescription => '—··· ·— —·—· —·— ·· —· ——· / ··— ·——· / ·— —· —·· / ··· —·—— —· —·—· ·· —· ——· / —·—— ——— ··— ·—· / ·—·· ——— ——· / ·— —·—· ·—· ——— ··· ··· / —·· · ···— ·· —·—· · ···';
	@override String get disabledDescription => '——— ··—· ··—· / — / ··· — ·— —·—— ·· —· ——· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · / ——— —· ·—·· —·——';
	@override String get syncing => '··· —·—— —· —·—· ·· —· ——·';
	@override String get account => '·— —·—· —·—· ——— ··— —· —';
	@override String get refresh => '·—· · ··—· ·—· · ··· ····';
	@override String get switchAccounts => '··· ·—— ·· — —·—· ···· / ·— —·—· —·—· ——— ··— —· — ···';
	@override String get switchAccountsDescription => '·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ·— —· ——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· — / ·—— ·· — ···· / ·— / ——·— ·—· / —·—· ——— —·· · / ——— ·—· / · —— ·— ·· ·—··';
	@override String get connectionRequests => '—·—· ——— —· —· · —·—· — ·· ——— —· / ·—· · ——·— ··— · ··· — ···';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '·— / —·· · ···— ·· —·—· · / ·· ··· / ·—— ·— ·· — ·· —· ——· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· —',
		other: '${n} / —·· · ···— ·· —·—· · ··· / ·— ·—· · / ·—— ·— ·· — ·· —· ——· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· —',
	);
	@override String get accountEmailTitle => '·— —·—· —·—· ——— ··— —· — / · —— ·— ·· ·—··';
	@override String accountEmailSent({required Object email}) => '—·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / ··· · —· — / — ——— / ${email} ·—·—·— / ——— ·——· · —· / — ···· · / ·—·· ·· —· —·— / — ···· · ·—· · / — ——— / ··—· ·· —· ·· ··· ···· / — ···· · / —·—· ···· ·— —· ——· · ·—·—·—';
	@override String get resendConfirmation => '·—· · ··· · —· —·· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / · —— ·— ·· ·—··';
	@override String resendConfirmationDescription({required Object email}) => '·—— ·— ·· — ·· —· ——· / ——— —· / ${email}';
	@override String accountEmailResent({required Object email}) => '··· · —· — / ·— ——· ·— ·· —· / — ——— / ${email} ·—·—·—';
	@override String get deviceLinked => '— ···· ·— — / —·· · ···— ·· —·—· · / ·· ··· / —· ——— ·—— / ·—·· ·· —· —·— · —·· / — ——— / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—';
	@override String get checking => '—·—· ···· · —·—· —·— ·· —· ——· …';
	@override String get notLinked => '—· ——— — / ·—·· ·· —· —·— · —·· / —·—— · —';
	@override String linkedAccount({required Object account, required Object id}) => '${account} / —·——· # ${id} —·——·—';
	@override String get replaceDialogTitle => '·—· · ·——· ·—·· ·— —·—· · / ·—·· ——— —·—· ·— ·—·· / —·· ·— — ·— ··——··';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${n} / ——— ·——· · ·—· ·— — ·· ——— —·',
		other: '${n} / ——— ·——· · ·—· ·— — ·· ——— —· ···',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${n} / ——·— ··· ———',
		other: '${n} / ——·— ··· ——— ···',
	);
	@override String get counts => '··· —·—— —· —·—· · —·· / —·· ·— — ·—';
	@override String countsLocal({required Object qsos, required Object operations}) => '— ···· ·· ··· / —·· · ···— ·· —·—· · ———··· / ${qsos} / · / ${operations}';
	@override String countsPending({required Object items}) => '·—— ·— ·· — ·· —· ——· / — ——— / ··— ·——· ·—·· ——— ·— —·· ———··· / ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => '··· · ·—· ···— · ·—· ———··· / ${qsos} / · / ${operations}';
	@override String get countsLocalChecking => '— ···· ·· ··· / —·· · ···— ·· —·—· · ———··· / —·—· ···· · —·—· —·— ·· —· ——· …';
	@override String get countsServerChecking => '··· · ·—· ···— · ·—· ———··· / —·—· ···· · —·—· —·— ·· —· ——· …';
	@override String get countsServerUnavailable => '··· · ·—· ···— · ·—· ———··· / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => '— ···· ·· ··· / —··· ·— —·—· —·— ··· / ··— ·——· / ·— —· —·· / —·—· ·—·· · ·— ·—· ··· / ${operations} / ·— —· —·· / ${qsos} / ··—· ·—· ——— —— / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / — ···· · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / —·· ·— — ·— / ·· —· ··· — · ·— —·· ·—·—·— / — ···· · / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ·· —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / —·· ·— — ·— —··· ·— ··· · ·—·—·—';
	@override String get replace => '·—· · ·——· ·—·· ·— —·—· ·';
	@override String get pendingBannerTitle => '—· · ·—— / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / ·— —·—· —·—· ——— ··— —· — / —·· · — · —·—· — · —··';
	@override String get pendingBannerBody => '—·— · · ·——· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / · —··— ·· ··· — ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·— —· —·· / ——·— ··· ——— ··· / ·— —· —·· / —— · ·—· ——· · / — ···· · —— / ·· —· — ——— / — ···· · / ·— —·—· —·—· ——— ··— —· — ——··—— / ——— ·—· / ·—· · ·——· ·—·· ·— —·—· · / — ···· · —— / ·—— ·· — ···· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / —·· ·— — ·— / —·——· ·— / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · / · ·· — ···· · ·—· / ·—— ·— —·—— —·——·— ·—·—·—';
	@override String get combine => '—·—· ——— —— —··· ·· —· ·';
	@override String get authIssueTitle => '··· —·—— —· —·—· / —·—· ·— —· ·————· — / —·—· ——— —· —· · —·—· —';
	@override String get authIssueText => '···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / —·— · · ·——· ··· / ·—· · ·——— · —·—· — ·· —· ——· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / —·—· ···· · —·—· —·— / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·· —· / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ··· ·—·—·—';
	@override String get openSettings => '——— ·——· · —· / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ···';
}

// Path: settings.accounts
class _Translations$settings$accounts$cw extends Translations$settings$accounts$en {
	_Translations$settings$accounts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— —·—· —·—· ——— ··— —· — ··· ——··—— / ··· · ·—· ···— ·· —·—· · ··· / ·—··· / —·· ·— — ·— / ··· ——— ··— ·—· —·—· · ···';
	@override String get none => '—· ——— / ·— —·—· — ·· ···— · / · —··— — · —· ··· ·· ——— —· ··· / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — ···';
	@override String get notConfigured => '—· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··';
	@override String get connected => '—·—· ——— —· —· · —·—· — · —··';
	@override String get cancelLogin => '—·—· ·— —· —·—· · ·—·· / ··· ·· ——· —· —····— ·· —·';
	@override String get openInBrowser => '——— ·——· · —· / ·· —· / —··· ·—· ——— ·—— ··· · ·—·';
	@override String loggedInAs({required Object identity}) => '·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / ${identity}';
	@override String get pressSaveToKeep => '·——· ·—· · ··· ··· / ··· ·— ···— · / — ——— / —·— · · ·——· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — / —·—· ——— —· —· · —·—· — · —·· ·—·—·—';
	@override String connectedTo({required Object label}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${label}';
	@override String get connect => '—·—· ——— —· —· · —·—· —';
	@override String get disconnect => '—·· ·· ··· —·—· ——— —· —· · —·—· —';
	@override String get connectedAs => '—·—· ——— —· —· · —·—· — · —·· / ·— ···';
	@override String get test => '— · ··· —';
	@override String saveFailed({required Object error}) => '··· ·— ···— · / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override String loginFailed({required Object error}) => '·—·· ——— ——· ·· —· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}';
	@override String get lookupFailed => '·— —·—· —·—· ——— ··— —· — ··· / ·— ·—· · / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— / — / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· —';
	@override String get browserLoginTitle => '··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / ·—— ·· — ···· / —·—— ——— ··— ·—· / ·—— · —··· / —··· ·—· ——— ·—— ··· · ·—·';
	@override String browserLoginSteps({required Object prefix}) => '·—— ···· · —· / —·—— ——— ··— / ·— ·—· · / —·· ——— —· · ——··—— / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / — ——— / ——— ·——· · —· / ·— / ·—·· ·· —· —·— / ··· — ·— ·—· — ·· —· ——· / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· ·—·—·— / —·—— ——— ··— ·—· / —·· · ··· —·— — ——— ·——· / —— ——— ··· — / ·—·· ·· —·— · ·—·· —·—— / ···· ·— ··· / —· ——— — ···· ·· —· ——· / ·—· · ——· ·· ··· — · ·—· · —·· / — ——— / ——— ·——· · —· / ·· — ——··—— / ··· ——— / —·—· ——— ·——· —·—— / — ···· ·— — / ·—·· ·· —· —·— / —·——· ··—· ·—· ——— —— / — ···· · / ·— —·· —·· ·—· · ··· ··· / —··· ·— ·—· ——··—— / ——— ·—· / ··—· ·—· ——— —— / — ···· · / · ·—· ·—· ——— ·—· / ·——· ·— ——· · / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ··· ···· ——— ·—— ··· —·——·— / ·— —· —·· / ·——· ·— ··· — · / ·· — / ···· · ·—· · ·—·—·—';
	@override String browserLoginNotOpened({required Object prefix}) => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· ·—·—·— / —·—· ——— ·——· —·—— / — ···· · / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·— / —··· · ·—·· ——— ·—— / ·— —· —·· / ——— ·——· · —· / ·· — / —·—— ——— ··— ·—· ··· · ·—·· ··—· ——··—— / — ···· · —· / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·· —· —·— / ·· — / ··· · —· —·· ··· / —·—— ——— ··— / — ——— / —·——· ·· — / ··· — ·— ·—· — ··· / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· —·——·— / ·— —· —·· / ·——· ·— ··· — · / — ···· ·— — / ···· · ·—· · ·—·—·—';
	@override String get copyLoginLink => '—·—· ——— ·——· —·—— / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·—';
	@override String get pastedLinkLabel => '·——· ·— ··· — · / — ···· · / ·—·· ·· —· —·— / ···· · ·—· ·';
	@override String get finishLogin => '··—· ·· —· ·· ··· ···· / ·—·· ——— ——· ·· —·';
	@override String pastedLinkNotARedirect({required Object prefix}) => '— ···· ·— — / ·· ··· / —· ——— — / — ···· · / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·— / — / ·· — / ··· ···· ——— ··— ·—·· —·· / ··· — ·— ·—· — / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· ·—·—·—';
	@override String get pastedLinkWrongLogin => '— ···· ·— — / ·—·· ·· —· —·— / —··· · ·—·· ——— —· ——· ··· / — ——— / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ·—·· ——— ——· ·· —· / ·— — — · —— ·——· — ·—·—·— / —·—· ·—·· ——— ··· · / — ···· ·· ··· / ·——· ·— ——· · / ·— —· —·· / —·—· ——— —· —· · —·—· — / ·— ——· ·— ·· —· ·—·—·—';
	@override String get pastedLinkNoCode => '— ···· ·— — / ·—·· ·· —· —·— / ···· ·— ··· / —· ——— / ·—·· ——— ——· ·· —· / —·—· ——— —·· · ·—·—·— / ··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / ··—· ·· ·—· ··· — ——··—— / — ···· · —· / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·· —· —·— / ·· — / ··· · —· —·· ··· / —·—— ——— ··— / — ——— ·—·—·—';
	@override String get pastedLinkMalformed => '— ···· ·— — / ·—·· ·· —· —·— / ·—·· ——— ——— —·— ··· / —·—· ··— — / ——— ··—· ··—· ·—·—·— / —·—· ——— ·——· —·—— / — ···· · / ·—— ···· ——— ·—·· · / — ···· ·· —· ——· / ·— —· —·· / ·——· ·— ··· — · / ·· — / ·— ——· ·— ·· —· ·—·—·—';
	@override String get relayLoginWaiting => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—— ——— ··— / — ——— / ··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / — / — ···· ·· ··· / ·—— ·· ·—·· ·—·· / —·—· ——— —· — ·· —· ··— · / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·—— / ——— —· —·—· · / —·—— ——— ··— / —·· ——— ·—·—·—';
	@override String get loginNoResponse => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· —· ·————· — / ···· · ·— ·—· —·· / —··· ·— —·—· —·— / ··—· ·—· ——— —— / — ···· · / ··· ·· ——· —· —····— ·· —· / —·—— · — ·—·—·— / ·· ··—· / —·—— ——— ··— / ·— ·—·· ·—· · ·— —·· —·—— / ··—· ·· —· ·· ··· ···· · —·· / ·· —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· ——··—— / —·—· ·— —· —·—· · ·—·· / ·— —· —·· / — ·—· —·—— / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—';
	@override String get relayLoginNotOpened => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·—— ·—·—·— / ··— ··· · / — ···· · / —··· ··— — — ——— —· / —··· · ·—·· ——— ·—— / — ——— / ——— ·——· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·——· ·— ——· · / —·—— ——— ··— ·—· ··· · ·—·· ··—· ·—·—·—';
	@override String get relayLoginUnavailable => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —· · · —·· · —·· / — ——— / —·—· ——— —— ·——· ·—·· · — · / — ···· ·· ··· / ·—·· ——— ——· ·· —· ·—·—·— / —·—· ···· · —·—· —·— / —·—— ——— ··— ·—· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get loginIncompleteResponse => '— ···· ·— — / ·—·· ——— ——· ·· —· / ·— — — · —— ·——· — / —·· ·· —·· —· ·————· — / —·—· ——— —— ·——· ·—·· · — · / —·—· ——— ·—· ·—· · —·—· — ·—·· —·—— ·—·—·— / ·——· ·—·· · ·— ··· · / — ·—· —·—— / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—';
	@override String get noKeyringTitle => '·— —·—· —·—· ——— ··— —· — / ·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —··';
	@override String get noKeyringText => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ·— —· ’ — / ·—· · ·— —·—· ···· / ·— / —·— · —·—— ·—· ·· —· ——· / ··· · ·—· ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ··· ——— / ·— —·—· —·—· ——— ··— —· — / ·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· — ——— ·—· · —·· / ——— ·—· / ·—· · ·— —·· / — / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— —· / ·— —·—· —·—· ——— ··— —· — / ·—— ·· ·—·· ·—·· / ··—· ·— ·· ·—·· / ··— —· — ·· ·—·· / — ···· ·· ··· / ·· ··· / ··· ——— ·—· — · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / ·— —· —·· / ··· — ·— ·—· — / ** ——· —· ——— —— · —····— —·— · —·—— ·—· ·· —· ——· ** ——··—— / ** —·— ·—— ·— ·—·· ·—·· · — ** / ——— ·—· / ** —·— · · ·——· ·— ··· ··· —··— —·—· ** ——··—— / ——— ·—· / ··— —· ·—·· ——— —·—· —·— / — ···· · / —·— · —·—— ·—· ·· —· ——· / —·—— ——— ··— / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ···— · ——··—— / — ···· · —· / ·—· · ··· — ·— ·—· — ·—·—·— / ·—·· ——— ——· ——· ·· —· ——· ——··—— / · —··— ·——· ——— ·—· — ··· / ·— —· —·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ·— ·—· · / ··— —· ·— ··—· ··—· · —·—· — · —·· —·—·—· / ·—·· ——— ——· / ··· —·—— —· —·—· / ··· — ·— —·—— ··· / ——— ··—· ··—· / ·—— ···· ·· ·—·· · / — ···· ·· ··· / ·—·· ·— ··· — ··· ·—·—·—';
	@override String get noKeyringInline => '·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —·· ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ’ ··· / —·— · —·—— ·—· ·· —· ——· / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / ·— —· —·· / ··· — ·— ·—· — / ——· —· ——— —— · —····— —·— · —·—— ·—· ·· —· ——· ——··—— / —·— ·—— ·— ·—·· ·—·· · — / ——— ·—· / —·— · · ·——· ·— ··· ··· —··— —·—· ——··—— / ——— ·—· / ··— —· ·—·· ——— —·—· —·— / — ···· · / ——— —· · / —·—— ——— ··— / ···· ·— ···— · ·—·—·—';
	@override String get noSecureStorageInline => '·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —·· ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ’ ··· / ··· · —·—· ··— ·—· · / ··· — ——— ·—· ·— ——· · / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—';
}

// Path: settings.station
class _Translations$settings$station$cw extends Translations$settings$station$en {
	_Translations$settings$station$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·—··· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—··';
	@override String get none => '—· ——— / · ——·— ··— ·· ·——· —— · —· — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··';
	@override String get add => '·— —·· —··';
	@override String get addTitle => '·— —·· —·· / · ——·— ··— ·· ·——· —— · —· —';
	@override String get searchHint => '··· · ·— ·—· —·—· ···· / · ——·— ··— ·· ·——· —— · —· —';
	@override String get noMatches => '—· ——— / · ——·— ··— ·· ·——· —— · —· — / —— ·— — —·—· ···· · ···';
	@override String get detectedEquipment => '—·· · — · —·—· — · —·· / · ——·— ··— ·· ·——· —— · —· —';
	@override String discoveryUnavailable({required Object error}) => '—·—· ·— —· ·————· — / ·—·· ·· ··· — · —· / ··—· ——— ·—· / ·—· ·— —·· ·· ——— ··· ———··· / ${error}';
	@override String get edit => '· —·· ·· — / · ——·— ··— ·· ·——· —— · —· —';
	@override String get name => '—· ·— —— ·';
	@override String get nameDescription => '·—— ···· ·— — / —·—— ——— ··— / —·—· ·— ·—·· ·—·· / ·· — / — / ·—··—· ·—·· · ··—· — / ·—· ·— —·· ·· ——— ·—··—· ·—·—·— / ——— ·——· — ·· ——— —· ·— ·—·· ·—·—·—';
	@override String get transport => '—·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get host => '·— —·· —·· ·—· · ··· ···';
	@override String get hostDescription => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ···· ——— ··· — —· ·— —— · / ——— ·—· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / —· · — ·—— ——— ·—· —·— ·—·—·—';
	@override String get port => '·——· ——— ·—· —';
	@override String get hostRequired => '·— —· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··';
	@override String get portInvalid => '·——· ——— ·—· — / —— ··— ··· — / —··· · / —··· · — ·—— · · —· / ·———— / ·— —· —·· / —···· ····· ····· ···—— ·····';
	@override String get connect => '—·—· ——— —· —· · —·—· —';
	@override String get disconnect => '—·· ·· ··· —·—· ——— —· —· · —·—· —';
	@override String get remove => '·—· · —— ——— ···— ·';
	@override String removeTitle({required Object name}) => '·—· · —— ——— ···— · / ${name} ··——··';
	@override String get removeMessage => '— ···· ·· ··· / ——— —· ·—·· —·—— / ·—· · —— ——— ···— · ··· / ·· — / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — ···· · / · ——·— ··— ·· ·——· —— · —· — ·————· ··· / ··· · — — ·· —· ——· ··· / ··· — ·— —·—— / ·— ··· / — ···· · —·—— / ·— ·—· · ·—·—·—';
	@override String unknownType({required Object typeKey}) => '··— —· ·—· · —·—· ——— ——· —· ·· ——·· · —·· / · ——·— ··— ·· ·——· —— · —· — / — —·—— ·——· · / ·—··—· ${typeKey} ·—··—·';
	@override String get report => '·—· · ·——· ——— ·—· —';
	@override String get reportTitle => '·—· · ·——· ——— ·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———';
	@override String get reportIntro => '— · ·—·· ·—·· / ··— ··· / ·—— ···· ·— — / ·—· ·— —·· ·· ——— / — ···· ·· ··· / ·—· · ·— ·—·· ·—·· —·—— / ·· ··· / ·— —· —·· / ···· ——— ·—— / ·· — / ·—— · —· — ·—·—·— / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / —··· · —·—· ——— —— · ··· / ·— / —·—· ·— ·—· —·· / — ···· · / ···· ·— —— ··——— —·— / — · ·— —— / ·—· · ·— —·· ··· ——··—— / ·— —· —·· / ·—— ···· ·— — / —·—— ——— ··— / ·—— ·—· ·· — · / ·— —··· ——— ··— — / ——· · — — ·· —· ——· / ·· — / ·—— ——— ·—· —·— ·· —· ——· / —— ·— —·—— / · —· —·· / ··— ·——· / ···· · ·—·· ·——· ·· —· ——· / — ···· · / —· · —··— — / ——— ·——· · ·—· ·— — ——— ·—· / ·—— ·· — ···· / — ···· · / ··· ·— —— · / ·—· ·· ——· ·—·—·—';
	@override String get reportManufacturer => '—— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—·';
	@override String get reportManufacturerDescription => '·—— ···· ——— / —— ·— —·— · ··· / ·· — / — / ·· —·—· ——— —— ——··—— / —·—— ·— · ··· ··— ——··—— / —·— · —· ·—— ——— ——— —·· ——··—— / · ·—·· · —·—· ·—· ·— ··—· — …';
	@override String get reportManufacturerRequired => '·— / —— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··';
	@override String get reportModel => '—— ——— —·· · ·—··';
	@override String get reportModelDescription => '— ···· · / —— ——— —·· · ·—·· ——··—— / ·— ··· / — ···· · / ·—· ·— —·· ·· ——— / ·· — ··· · ·—·· ··—· / —·—· ·— ·—·· ·—·· ··· / ·· — / — / ·—··—· ·· —·—· —····— ——··· ···—— ————— ————— ·—··—· ——··—— / ·—··—· ··—· — —····— ————· ————· ·———— ·— ·—··—· ·—·—·—';
	@override String get reportModelRequired => '·— / —— ——— —·· · ·—·· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··';
	@override String get reportOutcome => '···· ——— ·—— / —·· ·· —·· / ·· — / ——· ——— ··——··';
	@override String get reportOutcomeWorks => '·—— ——— ·—· —·— · —·· / ·—— · ·—·· ·—··';
	@override String get reportOutcomeIssues => '·—— ——— ·—· —·— · —·· ——··—— / ·—— ·· — ···· / ·· ··· ··· ··— · ···';
	@override String get reportOutcomeFails => '—·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— / ·— — / ·— ·—·· ·—··';
	@override String get reportOutcomeRequired => '·——· ·—·· · ·— ··· · / — · ·—·· ·—·· / ··— ··· / ···· ——— ·—— / ·· — / ·—— · —· —';
	@override String get reportComments => '—·—· ——— —— —— · —· — ···';
	@override String get reportCommentsPlaceholder => '·—— ···· ·— — / ·—— ——— ·—· —·— · —·· ——··—— / ·—— ···· ·— — / —·· ·· —·· —· ·————· — ——··—— / ·— —· —·—— — ···· ·· —· ——· / — ···· ·— — / ··· ··— ·—· ·——· ·—· ·· ··· · —·· / —·—— ——— ··— ·—·—·—';
	@override String get reportHints => '— ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / ···· ·· —· — ···';
	@override String get reportHintsPlaceholder => '·—— ·— —· — / — ——— / ··· ··— ——· ——· · ··· — / ··· ——— —— · / — ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / ···· ·· —· — ··· / ··—· ——— ·—· / ——— — ···· · ·—· / ··— ··· · ·—· ··· ··——··';
	@override String get reportSend => '··· · —· —·· / ·—· · ·——· ——— ·—· —';
	@override String get reportSending => '··· · —· —·· ·· —· ——· / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — …';
	@override String reportSent({required Object ref}) => '— ···· ·— —· —·— ··· / — / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / ·—— ·— ··· / ··—· ·· ·—·· · —·· / ·— ··· / ${ref} ·—·—·—';
	@override String get reportSentNoRef => '— ···· ·— —· —·— ··· / — / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / ·—— ·— ··· / ··· · —· — ·—·—·—';
	@override String reportFailed({required Object error}) => '— ···· · / ·—· · ·——· ——— ·—· — / ·—— ·— ··· —· ·————· — / ··· · —· — ———··· / ${error}';
	@override String get troubleshootingNotes => '— ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / —· ——— — · ···';
	@override String get mainVfo => '—— ·— ·· —· / ···— ··—· ———';
	@override String get useAsMainVfo => '··— ··· · / ·— ··· / —— ·— ·· —· / ···— ··—· ———';
	@override String get serialPort => '··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· —';
	@override String get serialPortDescription => '— ···· · / ·——· ——— ·—· — / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·· —· — · ·—· ··—· ·— —·—· · / ·— ·——· ·——· · ·— ·—· ··· / ——— —· ·—·—·—';
	@override String get serialPortNone => '—· ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ··—· ——— ··— —· —··';
	@override String get serialPortRequired => '—·—· ···· ——— ——— ··· · / ·— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· —';
	@override String serialPortOrdinal({required Object n, required Object total}) => '·——· ——— ·—· — / ${n} / ——— ··—· / ${total}';
	@override String get serialPortSuggested => '··· ··— ——· ——· · ··· — · —··';
	@override String get serialPortJustNow => '·—· · —·—· · —· — ·—·· —·—— / —·—· ——— —· —· · —·—· — · —··';
	@override String get serialDeviceRequest => '·— —·· —·· / ·— / ··— ··· —··· / —·· · ···— ·· —·—· · …';
	@override String get bleDevice => '—··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· ·';
	@override String get bleDeviceDescription => '— ···· · / ··· · ·—· ·· ·— ·—·· / —··· ·—· ·· —·· ——· · / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ···· ·—· ——— ··— ——· ···· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / ·· —· / ·· — ··· / ·· ——— ··· / —— ——— —·· · / ——— ·—· / ·— / —··· ·—·· · / ··· · ·—· ·· ·— ·—·· / ·— —·· ·— ·——· — · ·—· ·—·—·—';
	@override String get bleScan => '··· —·—· ·— —· / ··—· ——— ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ··· …';
	@override String get bleScanNoneFound => '—· ——— / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ··· / ··—· ——— ··— —· —·· ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / — ···· · / —··· ·—· ·· —·· ——· · / ·· ··· / ——— —· ——··—— / —· · ·— ·—· —··· —·—— ——··—— / ·— —· —·· / ·· —· / ·· — ··· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·——· ·· ——— ··· —·——·— / —— ——— —·· · ·—·—·—';
	@override String bleScanFailed({required Object reason}) => '— ···· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / ··· —·—· ·— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —· ———··· / ${reason}';
	@override String get bleOff => '—··· ·—·· ··— · — ——— ——— — ···· / ·· ··· / — ··— ·—· —· · —·· / ——— ··—· ··—· ·—·—·—';
	@override String get bleDenied => '—··· ·—·· ··— · — ——— ——— — ···· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / ·—— ·— ··· / —· ——— — / ——· ·—· ·— —· — · —·· ·—·—·— / ·— ·—·· ·—·· ——— ·—— / ·· — / ·· —· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· ——··—— / — ···· · —· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get bleUnsupported => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ·—·—·—';
	@override String get bleStarting => '—··· ·—·· ··— · — ——— ——— — ···· / ·· ··· / ··· — ·· ·—·· ·—·· / ··· — ·— ·—· — ·· —· ——· / ··— ·——· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—';
	@override String get bleConnectFailed => '—·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ·· — ·————· ··· / ——— —· ——··—— / —· · ·— ·—· —··· —·—— ——··—— / ·— —· —·· / —· ——— — / —·—· ——— —· —· · —·—· — · —·· / — ——— / ·— —· ——— — ···· · ·—· / ·— ·——· ·——· ·—·—·—';
	@override String bleNoSerialService({required Object services}) => '— ···· ·· ··· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / ··· · ·—· ·· ·— ·—·· / ··· · ·—· ···— ·· —·—· · / — ···· · / ·— ·——· ·——· / ·—· · —·—· ——— ——· —· ·· ——·· · ··· ·—·—·— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·· — / ·—— ·· — ···· / ·· — ··· / ··· · ·—· ···— ·· —·—· · ··· ———··· / ${services}';
	@override String get baudRate => '··· ·——· · · —·· / —·——· —··· ·— ··— —·· —·——·—';
	@override String get baudRateDescription => '—— ··— ··· — / —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ·— —· —·· / —· ——— / · ·—· ·—· ——— ·—· ·—·—·—';
	@override String get serialRtsHigh => '···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ····';
	@override String get serialRtsHighDescription => '——— —· ·—·· —·—— / ··—· ——— ·—· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·—· — ··· / —··· · ··—· ——— ·—· · / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / —·—— ·— · ··· ··— / ·—— ·· — ···· / —·—· ·— — / ·—· — ··· / — ··— ·—· —· · —·· / ——— —· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ·— —· —·· / —— ——— ··· — / ···· ——— —— · —····— —— ·— —·· · / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / — ·—· ·— —· ··· —— ·· — ··· ·—·—·—';
	@override String get serialDtrHigh => '···· ——— ·—·· —·· / —·· — ·—· / ···· ·· ——· ····';
	@override String get serialDtrHighDescription => '——— —· ·—·· —·—— / ··—· ——— ·—· / ·— / —·—· ·— — / ·· —· — · ·—· ··—· ·— —·—· · / — ···· ·— — / —·· ·—· ·— ·—— ··· / ·· — ··· / ·——· ——— ·—— · ·—· / ··—· ·—· ——— —— / —·· — ·—· ——··—— / ··· ··— —·—· ···· / ·— ··· / ··· ——— —— · / ·—· ··· —····— ··——— ···—— ··——— / —·—· ·— —··· ·—·· · ··· / ··—· ——— ·—· / — ···· · / ··—· — —····— ———·· ·———— ——··· ·—·—·— / ——— —· / —— ·— —· —·—— / —·—· ·— —··· ·—·· · ··· / —·· — ·—· / —·— · —·—— ··· / —·—· ·—— / ——— ·—· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / — ·—· ·— —· ··· —— ·· — ··· ·—·—·—';
	@override String get civAddress => '·—· ·— —·· ·· ——— / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ···';
	@override String get civAddressDescription => '···· · —··— ——··—— / ·— ··· / ··· ···· ——— ·—— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / —— · —· ··— ·—·—·— / — ···· · / ·· —·—· —····— ——··· ————— ····· / ··· ···· ·· ·——· ··· / ·— ··· / ·— ····— ·—·—·—';
	@override String get civAddressInvalid => '·— / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / ·· ··· / — ·—— ——— / ···· · —··— / —·· ·· ——· ·· — ··· ——··—— / ————— ·———— / — ——— / ··—· ··—·';
	@override String get flexSlice => '··· ·—·· ·· —·—· ·';
	@override String get flexSliceDescription => '·—— ···· ·· —·—· ···· / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·—·· ·· —·—· · ··· / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·—· · ·— —·· ··· / ··—· ·—· ——— —— / ·— —· —·· / — ··— —· · ··· ·—·—·—';
	@override String flexSliceLabel({required Object letter}) => '··· ·—·· ·· —·—· · / ${letter}';
	@override String get flexSliceInvalid => '·——· ·· —·—· —·— / ——— —· · / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·—·· ·· —·—· · ··· ——··—— / ·— / — ···· ·—· ——— ··— ——· ···· / ····';
	@override String flexSliceMissing({required Object letter}) => '··· ·—·· ·· —·—· · / ${letter} / ·· ··· / —· ——— — / ·· —· / ··— ··· · / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — / ·——· ·· —·—· —·— / ·— —· ——— — ···· · ·—· / ··· ·—·· ·· —·—· · ——··—— / ——— ·—· / —·—· ·—· · ·— — · / ·· — / ·· —· / ··· —— ·— ·—· — ··· —·· ·—·';
	@override String get channelNotInUse => '—· ——— — / ·· —· / ··— ··· ·';
	@override String get channelHeldByUnknown => '·· —· / ··— ··· · / —··· —·—— / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— ——';
	@override String get flexNoSlices => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ···· ·— ··· / —· ——— — / ·—· · ·——· ——— ·—· — · —·· / ·— —· —·—— / ··· ·—·· ·· —·—· · ··· / — / —·—· ···· · —·—· —·— / — ···· ·— — / ··· —— ·— ·—· — ··· —·· ·—· / ·· ··· / ·—· ··— —· —· ·· —· ——· / ·— —· —·· / — ···· ·— — / — ···· ·· ··· / —·—· ·—·· ·· · —· — / —— ·— —·—— / ··· ··— —··· ··· —·—· ·—· ·· —··· ·';
	@override String get spectrumUnsupported => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —· ——— / ··· ·——· · —·—· — ·—· ··— —— / ——— ···— · ·—· / —·—· ·— —';
	@override String get spectrumRequiresBaud => '·—· · ——·— ··— ·· ·—· · ··· / —·—· ·— — / ·— — / ·———— ·———— ····· ··——— ————— ————— / —··· ·——· ···';
	@override String get spectrumNoRadio => '—· ——— / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — · —··';
	@override String get spectrumWaiting => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·——· · —·—· — ·—· ··— —— …';
	@override String get spectrumUnavailable => '··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get spectrumNoDaxChannel => '· ···— · ·—· —·—— / —·· ·— —··— / ·· ——·— / —·—· ···· ·— —· —· · ·—·· / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / ·· —· / ··— ··· ·';
	@override String get spectrumNoPanadapter => '— ···· ·· ··· / ··· ·—·· ·· —·—· · / ···· ·— ··· / —· ——— / ·——· ·— —· ·— —·· ·— ·——· — · ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ———';
	@override String spectrumStreamRefused({required Object code}) => '— ···· · / ·—· ·— —·· ·· ——— / ·—· · ··—· ··— ··· · —·· / ·— / —·· ·— —··— / ·· ——·— / ··· — ·—· · ·— —— / —·——· · ·—· ·—· ——— ·—· / ${code} —·——·—';
	@override String get spectrumNoUdp => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·——· · —·—· — ·—· ··— —— / —·· ·— — ·— / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· ·· ··· / —·· · ···— ·· —·—· ·';
	@override String get spectrumK4Unavailable => '—·—· ·— —· —· ——— — / ·—· · —·—· · ·· ···— · / — ···· · / —·— ····— ’ ··· / ·—·· ·— —· / ··· ·——· · —·—· — ·—· ··— —— ·—·—·— / ·—· · — ·—· —·—— ·· —· ——· …';
	@override String get spectrumK4RemoteUnavailable => '—·—· ·— —· —· ——— — / ·—· · —·—· · ·· ···— · / — ···· · / —·— ····— ’ ··· / ·—· · —— ——— — · / ··· ·——· · —·—· — ·—· ··— ——';
	@override String get spectrumScopeRefused => '— ···· · / ·—· ·— —·· ·· ——— / ·—· · ··—· ··— ··· · —·· / ·· — ··· / ··· —·—· ——— ·——· · / —·—· ——— —— —— ·— —· —·· ···';
	@override String get spectrumOutOfRange => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· —·—· ——— ·——· · / ·· ··· / ··· · — / ——— ··— — ··· ·· —·· · / — ···· · / ·—· ·— —· ——· · / ·· — / —·—· ·— —· / ··· ···· ——— ·——';
	@override String get spectrumBandUnsupported => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· —·—· ——— ·——· · / —·—· ·— —· —· ——— — / —··· · / ··· ···· ——— ·—— —· / ——— —· / — ···· ·· ··· / —··· ·— —· —··';
	@override String get spectrumSdrNoRadio => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ·—·· ·· —· —·— · —·· / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— …';
	@override String get spectrumSdrNotConnected => '— ···· · / ··· —·· ·—· / ·· ··· / —· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get spectrumSdrNoIf => '··· · — / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· —· / — ···· ·· ··· / ··· —·· ·—· ·————· ··· / ··· · — — ·· —· ——· ···';
	@override String get sdrRadio => '··· ···· ——— ·—— ··· / — ···· · / ··· ·——· · —·—· — ·—· ··— —— / ··—· ——— ·—·';
	@override String get sdrRadioDescription => '·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / —·· ·—· ·— ·—— ··· / ··—· ·—· ——— —— / — ···· ·· ··· / ·—· · —·—· · ·· ···— · ·—· / ·· —· ··· — · ·— —·· / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··· —·—· ——— ·——· · ·—·—·—';
	@override String get sdrRadioMain => '— ···· · / —— ·— ·· —· / ·—· ·— —·· ·· ———';
	@override String get sdrTuning => '·— —· — · —· —· ·— / ·· —· ·——· ··— —';
	@override String get sdrTuningDescription => '·—— ···· · ·—· · / — ···· · / ·—· · —·—· · ·· ···— · ·—· ·————· ··· / ··· ·· ——· —· ·— ·—·· / —·—· ——— —— · ··· / ··—· ·—· ——— —— ·—·—·— / ——— —· / ·· — ··· / ——— ·—— —· / ·— —· — · —· —· ·— / ·· — / — ··— —· · ··· / ·· — ··· · ·—·· ··—· / — ——— / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ·—· ·— —·· ·· ——— —·—·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ——— ··— — ·——· ··— — / ·· — / ··· — ·— —·—— ··· / ——— —· / — ···· · / ·· ··—· ·—·—·—';
	@override String get sdrTuningIndependent => '·· — ··· / ——— ·—— —· / ·— —· — · —· —· ·—';
	@override String get sdrTuningIfTap => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ——— ··— — ·——· ··— —';
	@override String get sdrIfHz => '·· ··—· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·——· ···· ——·· —·——·—';
	@override String get sdrIfHzDescription => '··—· ——— ·—· / ·— —· / ·· ··—· / ——— ··— — ·——· ··— — / ——— —· ·—·· —·—— ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·· ·· ·— ·—·· / ··· ·· — ··· / ·— — / ——— —· / ·· — ··· / ·· ··—· ——··—— / ··· ··— —·—· ···· / ·— ··· / —···· ———·· ···—— ···—— ————— ————— ————— ————— / ——— —· / ·— —· / ··—· — —····— ———·· ·———— ——··· ·—·—·—';
	@override String get sdrIfInverted => '·· ··—· / ·· ··· / ·· —· ···— · ·—· — · —··';
	@override String get sdrGainDb => '——· ·— ·· —· / —·——· —·· —··· —·——·—';
	@override String get sdrGainDbDescription => '·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / — ···· · / ·—· · —·—· · ·· ···— · ·—· ·————· ··· / ·— ··— — ——— —— ·— — ·· —·—· / ——· ·— ·· —· ·—·—·—';
	@override String get sdrOffsetHz => '··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— ··—· ··—· ··· · — / —·——· ···· ——·· —·——·—';
	@override String get sdrOffsetHzDescription => '·— —·· —·· · —·· / — ——— / · ···— · ·—· —·—— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··· · —· — / — ——— / — ···· · / ·—· · —·—· · ·· ···— · ·—· ——··—— / ··—· ——— ·—· / ·— —· / ··— ·——· —·—· ——— —· ···— · ·—· — · ·—· ———··· / ·———— ··——— ····· ————— ————— ————— ————— ————— ————— / ··—· ——— ·—· / ·— / ···· ·— —— / ·· — / ··— ·——· ·—·—·—';
	@override String get sdrPpm => '··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ——— ·—· ·—· · —·—· — ·· ——— —· / —·——· ·——· ·——· —— —·——·—';
	@override String get rtlDirectSampling => '—·· ·· ·—· · —·—· — / ··· ·— —— ·——· ·—·· ·· —· ——·';
	@override String get rtlDirectSamplingDescription => '··—· ——— ·—· / ···· ··—· / ——— —· / ·— —· / ·—· — ·—·· —····— ··· —·· ·—· / ···— ···—— / ·—— ·· — ···· ——— ··— — / ·— —· / ··— ·——· —·—· ——— —· ···— · ·—· — · ·—· ·—·—·— / ·— —· / ·—· — ·—·· —····— ··· —·· ·—· / ···— ····— / ·—· · ·— —·—· ···· · ··· / ···· ··—· / ·—— ·· — ···· ——— ··— — / ·· — ·—·—·—';
	@override String get rtlDirectSamplingOff => '——— ··—· ··—·';
	@override String get rtlDirectSamplingI => '·· / —··· ·—· ·— —· —·—· ····';
	@override String get rtlDirectSamplingQ => '——·— / —··· ·—· ·— —· —·—· ····';
	@override String get rtlTcpNotAServer => '— ···· ·· ··· / ·· ··· / —· ——— — / ·— —· / ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—·';
	@override String get rtlTcpNotes => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** / ——— —· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / — ···· · / —·· ——— —· ——· ·—·· · / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—\n\n—····— / ** ··· — ·— ·—· — / ·· — ** / ·—— ·· — ···· / `rtl_tcp -a 0.0.0.0` / ··· ——— / ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ··· / —·—· ·— —· / ·—· · ·— —·—· ···· / ·· — —·—·—· / ——— —· / — ···· · / ··· ·— —— · / —— ·— —·—· ···· ·· —· · ——··—— / `rtl_tcp` / ·— ·—·· ——— —· · / ·—— ·· ·—·· ·—·· / —·· ——— ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / ·· — / ·—— ·· — ···· / `-p` ·—·—·—\n—····— / ** ——— —· · / ·——· ·—· ——— ——· ·—· ·— —— / ·— — / ·— / — ·· —— · ———··· ** / ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ··· / ·— / ··· ·· —· ——· ·—·· · / —·—· ·—·· ·· · —· — ·—·—·— / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·· ·—·· · / ·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··· ···· ——— ·—— ·· —· ——· ——··—— / ·— —· —·· / ·—·· · — ··· / ——· ——— / ·— / ··—· · ·—— / ··· · —·—· ——— —· —·· ··· / ·— ··—· — · ·—· / ·· — / —·—· ·—·· ——— ··· · ··· ·—·—·—\n—····— / ** ——— —· / ·— —· —·· ·—· ——— ·· —·· ** ——··—— / — ···· · / * ··· —·· ·—· / —·· ·—· ·· ···— · ·—· * / ·— ·——· ·——· / ·—· ··— —· ··· / — ···· · / ··· ·— —— · / ··· · ·—· ···— · ·—· / ——— —· / — ···· · / ·——· ···· ——— —· · ·—·—·—';
	@override String get rspTcpNotes => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ·—· ··· ·——· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** / ——— —· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / — ···· · / ·—· ··· ·——· / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ——··—— / ·—— ·· — ···· / ··· —·· ·—· ·——· ·—·· ·— —·—— ·————· ··· / ·— ·——· ·· / ·· —· ··· — ·— ·—·· ·—·· · —·· / — ···· · ·—· · ·—·—·—\n\n—····— / ** ··· — ·— ·—· — / ·· — ** / ·—— ·· — ···· / `rsp_tcp -a 0.0.0.0` ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / ·· — / ·—— ·· — ···· / `-p` ·—·—·—\n—····— / ** ——— —· · / ·——· ·—· ——— ——· ·—· ·— —— / ·— — / ·— / — ·· —— · ———··· ** / — ···· · / ··· · ·—· ···— · ·—· / — ·— —·— · ··· / ·— / ··· ·· —· ——· ·—·· · / —·—· ·—·· ·· · —· — ·—·—·— / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·· ·—·· · / ·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··· ···· ——— ·—— ·· —· ——· ·—·—·—';
	@override String get n3fjpNoRig => '—· ···—— ··—· ·——— ·——· / ···· ·— ··· / —· ——— / ·—· ·— —·· ·· ——— / ·· —· — · ·—· ··—· ·— —·—· · / ··· · — / ··— ·——· ——··—— / ··· ——— / — ···· ·· ··· / ··—· ——— ·—·· ·—·· ——— ·—— ··· / ·—— ···· ·— — / ·· ··· / — —·—— ·——· · —·· / ·· —· — ——— / —· ···—— ··—· ·——— ·——· ——··—— / —· ——— — / ·— / ·—· ·— —·· ·· ———';
	@override String get winkeyerKeyPort => '—·— · —·—— / ——— ··— — ·——· ··— —';
	@override String get winkeyerKeyPortDescription => '·—— ···· ·· —·—· ···· / ——— ··—· / — ···· · / —·— · —·—— · ·—· ·————· ··· / — ·—— ——— / ——— ··— — ·——· ··— — / ·——— ·— —·—· —·— ··· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—';
	@override String winkeyerKeyPortLabel({required Object n}) => '·——· ——— ·—· — / ${n}';
	@override String get winkeyerPtt => '··— ··· · / — ···· · / —·— · —·—— · ·—· ·————· ··· / ·——· — —';
	@override String get winkeyerPttDescription => '—·— · —·—— / — ···· · / ·——· — — / ·—·· ·· —· · / ——— —· / — ···· · / ··· ·— —— · / ·——— ·— —·—· —·— ——··—— / ··—· ——— ·—· / ·— —· / ·— —— ·——· ·—·· ·· ··—· ·· · ·—· / ——— ·—· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / —· · · —·· ··· / ·· — ·—·—·— / ·—·· · ·— ···— · / ——— ··—· ··—· / ··—· ——— ·—· / ·— / ·—· ·— —·· ·· ——— / —·— · —·—— · —·· / ——— —· / ·· — ··· / —·— · —·—— / ·——— ·— —·—· —·— ·—·—·—';
	@override String get winkeyerNoAnswer => '—· ——— / ·—— ·· —· —·— · —·—— · ·—· / ·—· · ··· ·——· ——— —· —·· · —·· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· —';
	@override String get winkeyerStoppedAnswering => '— ···· · / ·—— ·· —· —·— · —·—— · ·—· / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·—— ···· ·· ·—·· · / ··· · —· —·· ·· —· ——· —·—·—· / — ···· · / —— · ··· ··· ·— ——· · / ·—— ·— ··· / —·· ·—· ——— ·——· ·——· · —··';
	@override String get icomControlPort => '—·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·—';
	@override String get icomControlPortDescription => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— / — / ····· ————— ————— ————— ·———— / ··— —· ·—·· · ··· ··· / —·—· ···· ·— —· ——· · —·· / ·· —· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get icomSerialPort => '··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·—';
	@override String get icomSerialPortDescription => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— / — / ····· ————— ————— ————— ··——— / ··— —· ·—·· · ··· ··· / —·—· ···· ·— —· ——· · —·· / ·· —· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / ·— —· ——— — ···· · ·—· ·—·—·—';
	@override String get icomPortsDiffer => '— ···· · / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / —— ··— ··· — / —·· ·· ··—· ··—· · ·—·';
	@override String get radioUser => '·—· ·— —·· ·· ——— / ··— ··· · ·—· —· ·— —— ·';
	@override String get radioPass => '·—· ·— —·· ·· ——— / ·——· ·— ··· ··· ·—— ——— ·—· —··';
	@override String get radioLoginDescription => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / → / ·—· · —— ——— — · / ·—·· ——— ——· ·· —· ——··—— / —· ——— — / —·—— ——— ··— ·—· / ·—— ·· ··—· ·· / ·——· ·— ··· ··· ·—— ——— ·—· —·· ·—·—·—';
	@override String get radioUserRequired => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··— ··· · ·—· —· ·— —— · / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··';
	@override String get connectFailedBusy => '—·· · ···— ·· —·—· · / ·· ··· / ·· —· / ··— ··· ·';
	@override String get connectFailedDenied => '·— —·—· —·—· · ··· ··· / —·· · —· ·· · —··';
	@override String get connectFailedDevice => '—·· · ···— ·· —·—· · / —· ——— — / ··—· ——— ··— —· —··';
	@override String get connectFailedLines => '·—· — ··· —··—· —·· — ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ···· · ·—·· —·· / ·— ··· / ··· · — ——··—— / ··· ——— / — ···· · / ·——· ——— ·—· — / ·—— ·— ··· / —·—· ·—·· ——— ··· · —·· ·—·—·— / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— / —— ·— —·—— / ···· ·— ···— · / ·—·· · ··—· — / ···· ·— ·—· —·· ·—— ·— ·—· · / ···· ·— —· —·· ··· ···· ·— —·— ·· —· ——· / ——— —· / — / ··— —· ·——· ·—·· ··— ——· / ·— —· —·· / ·—· · ·——· ·—·· ··— ——· / — ···· · / —·—· ·— —··· ·—·· · ·—·—·—';
	@override String get connectFailedNetwork => '—·—· ·— —· —· ——— — / ··—· ·· —· —·· / — ···· · / ·—· ·— —·· ·· ——— / ——— ···— · ·—· / — ···· · / —· · — ·—— ——— ·—· —·— ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / ·— —·· —·· ·—· · ··· ··· / ·— —· —·· / — ···· ·— — / ·· — ·————· ··· / ·——· ——— ·—— · ·—· · —·· / ——— —· / ·— —· —·· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·—';
	@override String get connectFailedTimeout => '— ···· · / ·—· ·— —·· ·· ——— / —·· ·· —·· —· ·————· — / ·—· · ··· ·——· ——— —· —·· / ·· —· / — ·· —— · ·—·—·— / —·—· ···· · —·—· —·— / ·· — ·————· ··· / ·——· ——— ·—— · ·—· · —·· / ——— —· / ·— —· —·· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·—';
	@override late final _Translations$settings$station$models$cw models = _Translations$settings$station$models$cw._(_root);
	@override late final _Translations$settings$station$transports$cw transports = _Translations$settings$station$transports$cw._(_root);
	@override String get troubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get ft891Troubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ——— ·—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ——— —· ·—·—·— ** / ·—— ·· — ···· / ** —·—· ·— — / ·—· — ··· ** / ——— —· / —·——· ··—· — —····— ———·· ————· ·———— / —— · —· ··— / ** ————— ····· —····— ————— ———·· ** —·——·— ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — / ·—— ···· ·· ·—·· · / ·—· — ··· / ·· ··· / ·—·· ——— ·—— / — / ·· — / —— ·— —·—— / ·— —· ··· ·—— · ·—· / ——— —· —·—· · / ·— ··· / — ···· · / ·——· ——— ·—· — / ——— ·——· · —· ··· ——··—— / — ···· · —· / —· ——— — ···· ·· —· ——· ·—·—·— / ·——· ·· —·—· —·— ·· —· ——· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — / — ··— ·—· —· ··· / ——— —· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / —·— · —·—— ··· / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ———··· / — ··— ·—· —· / —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· —· ··· — · ·— —·· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —·——· —— · —· ··— / ** ————— ····· —····— ————— —···· ** —·——·— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—';
	@override String get yaesuBinaryTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get yaesuBinaryTroubleshooting => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ··· ·——· · ·— —·— ··· / —·—— ·— · ··· ··— ·————· ··· / ——— ·—·· —·· · ·—· / ··—· ·· ···— · —····— —··· —·—— — · / —·—· ·— — ——··—— / ·— —· —·· / ·· — / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· / ·— — / ·— ·—·· ·—·· / ·—— ···· · —· / ··· ——— —— · — ···· ·· —· ——· / ·· ··· / ——— ··—· ··—· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** — ···· · / —·—· ·— —··· ·—·· · / —— ··— ··· — / —·—· ——— —· ···— · ·—· — / ·—·· · ···— · ·—·· ··· ·—·—·— ** / — ···· · / —·—· ·— — / ·——— ·— —·—· —·— / ——— —· / — ···· · / —··· ·— —·—· —·— / ·· ··· / —· ——— — / ·—· ··· —····— ··——— ···—— ··——— / ·— —· —·· / —· ——— — / ··— ··· —··· —·—·—· / ·· — / —· · · —·· ··· / ·— / —·—· — —····— —···· ··——— / ——— ·—· / ·— —· / · ——·— ··— ·· ···— ·— ·—·· · —· — / ·— —·· ·— ·——· — · ·—· ·—·—·— / ·— / ·——· ·—·· ·— ·· —· / ·— ··— —·· ·· ——— / ——— ·—· / —·· ·— — ·— / —·—· ·— —··· ·—·· · / ·—— ——— —· ·————· — / ·—— ——— ·—· —·— / ··—· ——— ·—· / —·—· ·— — ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— / —·——· ** # ·———— ····— ** / ——— —· / ·— —· / ··—· — —····— ———·· ·———— ——··· ——··—— / ** # ·———— ————· ** / ——— —· / ·— —· / ··—· — —····— ———·· ····· ——··· / ——— ·—· / ··—· — —····— ———·· ————· ——··· —·——·— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —· ——— — ···· ·· —· ——· / —··· ·— —·—· —·— ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** —· · ···— · ·—· / ·—·· · — / ·— —· —·—— — ···· ·· —· ——· / ·—· ·— ·· ··· · / ·—· — ··· / ——— ·—· / —·· — ·—· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· — ·—·—·— ** / ——— —· / —— ——— ··· — / —·—· ·— —··· ·—·· · ··· / ··—· ——— ·—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· / — ···· ——— ··· · / ·—·· ·· —· · ··· / ·— ·—· · / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·— / ·— —· / ——— ·—·· —·· · ·—· / ·· —· — · ·—· ··—· ·— —·—· · / ·——· ——— ·—— · ·—· · —·· / ··—· ·—· ——— —— / —·· — ·—· / ·· ··· / — ···· · / · —··— —·—· · ·——· — ·· ——— —· ———··· / — ··— ·—· —· / ——— —· / ** ···· ——— ·—·· —·· / —·· — ·—· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / — ···· ·— — / ——— —· · ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —·—— ·— · ··· ··— ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / —·—· ···· ·— ·—· — / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get tenTecTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get tenTecEagleTroubleshooting => '—····— / ** — ···· · / ··— ··· —··· —····— —··· / ·——· ——— ·—· — / ——— —· / — ···· · / —··· ·— —·—· —·— / ·· ··· / — ···· · / —·—· ·— — / ·—·· ·· —· —·— ·—·—·— ** / — ···· · / ·—· ·— —·· ·· ——— / ··· ···· ——— ·—— ··· / ··— ·——· / ·— ··· / ·— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — —·—·—· / ——— —· / ·—— ·· —· —·· ——— ·—— ··· / ·· — / —· · · —·· ··· / — · —· —····— — · —·—· ·————· ··· / ··— ··· —··· / — ——— / ··— ·— ·—· — / —·· ·—· ·· ···— · ·—· ——··—— / ·—— ···· ·· —·—· ···· / ·— ·——· ·——· · ·— ·—· ··· / ·· —· / —·· · ···— ·· —·—· · / —— ·— —· ·— ——· · ·—· / ·— ··· / ·—··—· ··— ··· —··· / — ——— / ··— ·— ·—· — / —·——· —·—· ——— —— —··— —·——·— ·—··—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ——··—— / ·— —· —·· / ··· ——— / —·· ——— · ··· / — · —· —····— — · —·—· ·————· ··· / ··—· ·· ·—· —— ·—— ·— ·—· · / ··— ·——· —·· ·— — · ·—· ·—·—·—\n—····— / ** ··· · — — ·· —· ——· / — ···· · / ··—· ·· ·—·· — · ·—· / ·—— ·· —·· — ···· / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· / — ·— —·— · ··· / ·· — / ·— ·—— ·— —·—— / ··—· ·—· ——— —— / — ···· · / —··· ·—— / —·— —· ——— —··· ** / ··— —· — ·· ·—·· / — ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— ··—· ··—· / ·— —· —·· / ——— —· / ·— ——· ·— ·· —· ·—·—·— / — ···· ·— — / ·· ··· / ···· ——— ·—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ——— ·—· —·— ··· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — · —· —····— — · —·—· ·————· ··· / ·——· ·—· ——— ——· ·—· ·— —— —— · ·—· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · / ——· ··— ·· —·· · ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ——··—— / ·—— ·· — ···· / — ···· · / ··—· ·· ·—· —— ·—— ·— ·—· · / ···— · ·—· ··· ·· ——— —· / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—';
	@override String get tenTecOrionTroubleshooting => '—····— / ** ··— ··· · / ·— / ··· — ·—· ·— ·· ——· ···· — —····— — ···· ·—· ——— ··— ——· ···· / —·· —··· —····— ————· / ··· · ·—· ·· ·— ·—·· / —·—· ·— —··· ·—·· · ** / — ——— / — ···· · / ··· · ·—· ·· ·— ·—·· / —·· ·— — ·— / ·——· ——— ·—· — ——··—— / —· ——— — / ·— / —· ··— ·—·· ·—·· —····— —— ——— —·· · —— / ——— —· · ·—·—·—\n—····— / ** — ···· ·· ··· / · —· — ·—· —·—— / ···· ——— ·—·· —·· ··· / ·—· — ··· / ···· ·· ——· ···· ** ——··—— / —··· · —·—· ·— ··— ··· · / — ···· · / ——— ·—· ·· ——— —· / ··— ··· · ··· / ·—· — ··· / ·— —· —·· / —·—· — ··· / ·— ··· / ·· — ··· / ···· ·— —· —·· ··· ···· ·— —·— · ·—·—·— / ——— —· / ·— —· / ·· —· — · ·—· ··—· ·— —·—· · / — ···· ·— — / —·— · —·—— ··· / ·——· — — / ··—· ·—· ——— —— / ·—· — ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / — ··— ·—· —· / ——— ··—· ··—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / — ···· · / ·—· ·— —·· ·· ——— / — ·—· ·— —· ··· —— ·· — ··· / ·— ··· / ··· ——— ——— —· / ·— ··· / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· ·—·—·—\n—····— / ** —·—· ·—— / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· / —· · · —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· —· — · ·—· —· ·— ·—·· / —·— · —·—— · ·—· / ——— —· ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— ··—· ··—· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·· ——· —· ——— ·—· · ··· / ·—— ···· ·— — / — ···· · / ·— ·——· ·——· / ··· · —· —·· ··· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — · —· —····— — · —·—· ·————· ··· / ·——· ·—· ——— ——· ·—· ·— —— —— · ·—· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · / ——· ··— ·· —·· · / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ·— —· / ——— ·—· ·· ——— —· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ——··—— / ·—— ·· — ···· / — ···· · / ··—· ·· ·—· —— ·—— ·— ·—· · / ···— · ·—· ··· ·· ——— —· / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—';
	@override String get tenTecNoCw => '— ···· ·· ··· / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·· ·—· —— ·—— ·— ·—· · / —·· ——— · ··· / —· ——— — / — ·— —·— · / —·—· ·—— / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — · —· —····— — · —·—· / ·— —·· —·· · —·· / ·· — / ·· —· / ——— ·—· ·· ——— —· / ··—· ·· ·—· —— ·—— ·— ·—· · / ·———— ·—·—·— ···—— —···· —···· ·—·—·—';
	@override String get tenTecKeyerOff => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· —· — · ·—· —· ·— ·—·· / —·— · —·—— · ·—· / ·· ··· / ——— ··—· ··—· ——··—— / ··· ——— / ·· — / ·· ——· —· ——— ·—· · ··· / —·—· ·—— / ··· · —· — / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — ··— ·—· —· / — ···· · / —·— · —·—— · ·—· / ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—';
	@override String get guohetecTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get guohetecTroubleshooting => '— ···· · / ——·— ————· ————— ————— / ···· ·— ··· / — ·—— ——— / —·—· ·— — / ·——· ·—· ——— — ——— —·—· ——— ·—·· ··· ——··—— / ·— —· —·· / — ···· ·· ··· / · —· — ·—· —·—— / ··— ··· · ··· / ·· — ··· / —· ·— — ·· ···— · / ——— —· · / ·—· ·— — ···· · ·—· / — ···· ·— —· / — ···· · / ··—· — —····— ———·· ·———— ——··· / ·· —— ·· — ·— — ·· ——— —· ·—·—·— / ·——· ·· —·—· —·— / ** ——· ··— ——— ···· · — · —·—· / ——·— ————· ————— ————— ** / ···· · ·—· · ——··—— / —· ——— — / ·— —· / ··—· — —····— ———·· ·———— ——··· / — / — ···· · / ·· —— ·· — ·— — ·· ——— —· / ··· ··— ·——· ·——· ——— ·—· — ··· / ··—· · ·—— · ·—· / —·—· ——— —— —— ·— —· —·· ··· ——··—— / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / ——— —· · / ·· — / ·· ··· / ··— ··· ·· —· ——· ·—·—·—\n\n—····— / ** — ···· · / ··— ··· —··· —····— —·—· / —·—· ·— —··· ·—·· · / ·· ··· / — ···· · / —·—· ·— — / ·—·· ·· —· —·— ** ——··—— / ·— —· —·· / ·· — / —·—· ——— —· —· · —·—· — ··· / — ···· · / ··· ——— ··— —· —·· / —·—· ·— ·—· —·· / — ——— ——— ·—·—·— / ··· ·——· · · —·· / —·· ——— · ··· / —· ——— — / —— ·— — — · ·—· / ——— —· / ·· — —·—·—· / — ···· · / ·——· ——— ·—· — / ·· ——· —· ——— ·—· · ··· / ·—— ···· ·— — · ···— · ·—· / ·· — / ·· ··· / ··· · — / — ——— ·—·—·—\n—····— / ** —· · ···— · ·—· / ·—·· · — / ·— —· —·—— — ···· ·· —· ——· / ·—· ·— ·· ··· · / ·—· — ··· / ——— ·—· / —·· — ·—· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· — ·—·—·— ** / ——— —· / ·— / ··· · ·—· ·· ·— ·—·· / —·—· ·— —··· ·—·· · / — ···· ——— ··· · / ·—·· ·· —· · ··· / ·— ·—· · / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** ·— / ··· · —·—· ——— —· —·· —····— ——· · —· · ·—· ·— — ·· ——— —· / ·—· ·— —·· ·· ——— / —··· · ···· ·— ···— · ··· / —·· ·· ··—· ··—· · ·—· · —· — ·—·· —·—— ** / ··—· ·—· ——— —— / ·— / ··—· ·· ·—· ··· — ·—·—·— / ·—·· ——— —· ——· / ·——· ·—· · ··· ··· / —— · —· ··— ——··—— / — ···· · —· / ·— —··· ——— ··— — ———··· / ···· ·—— / ··——— ·—·—·— ————— / ·· ··· / — ···· · / ··· · —·—· ——— —· —·· / ——· · —· · ·—· ·— — ·· ——— —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — ···· · / —— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get yaesuTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get yaesuTroubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** —·—· ·— — / ·—· — ··· / —— ··— ··· — / —··· · / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·— / ···· ·— —· —·· ··· ···· ·— —·— · / ·—·· ·· —· · / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ·—·· ——— ·—— ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / — ···· ·— — / ··· ·— —— · / ·—·· ·· —· · / ·· ··· / ·——· — — ——··—— / ··· ——— / ·—· ·— ·· ··· ·· —· ——· / ·· — / ·—— ——— ··— ·—·· —·· / —·— · —·—— / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ·—·—·— / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — ——··—— / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· / ·· ··· / — ···· · / ·— ·—·· — · ·—· —· ·— — ·· ···— · ·—·—·— / ·—— ···· · ·—· · / — ···· ·— — / ··· · — — ·· —· ——· / ·—·· ·· ···— · ··· / —·· ·· ··—· ··—· · ·—· ··· / —··· —·—— / —— ——— —·· · ·—·· / —·——· —— · —· ··— / ** ————— ····· —····— ————— ———·· ** / ——— —· / ·— —· / ··—· — —····— ———·· ————· ·———— —·——·— ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** —— ——— —·· · ··· / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ··—· — —····— ———·· ————· ·———— ·————· ··· / — ·— —··· ·—·· · ·—·—·— ** / —— ——— ··· — / ——— ··—· / — ···· · / —·—— ·— · ··· ··— / ·—·· ·· —· · / —— ·— — —·—· ···· · ··· / ·· — ——··—— / —··· ··— — / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / —· ··— —— —··· · ·—· ··· / ·· — ··· / —— ——— —·· · ··· / —·· ·· ··—· ··—· · ·—· · —· — ·—·· —·—— / ·—— ·· ·—·· ·—·· / ··· ···· ——— ·—— / ·— —· —·· / ··· · — / — ···· · / ·—— ·—· ——— —· ——· / ——— —· · / ··—· ——— ·—· / — ···· ——— ··· · ·—·—·— / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ··— —· ·— ··—· ··—· · —·—· — · —·· ·—·—·—';
	@override String get yaesuRs232Troubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** — ···· · / —·—· ·— — / ·——— ·— —·—· —·— / ·· ··· / ·—· ··· —····— ··——— ···—— ··——— ·—·—·— ** / ·· — / —· · · —·· ··· / ·— / ··— ··· —··· —····— — ——— —····— ··· · ·—· ·· ·— ·—·· / ·— —·· ·— ·——· — · ·—· / ·— —· —·· / ·— / ··· — ·—· ·— ·· ——· ···· — —····— — ···· ·—· ——— ··— ——· ···· / —·· —··· —····— ————· / —·—· ·— —··· ·—·· · / — / ·— / —· ··— ·—·· ·—·· —····— —— ——— —·· · —— / —·—· ·— —··· ·—·· · / ··· ·—— ·— ·——· ··· / — ···· · / ·—·· ·· —· · ··· ——··—— / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ···· · ·— ·—· ··· / ·— / — ···· ·· —· ——· ·—·—·—\n—····— / ** —·—· ·— — / ·—· — ··· / —— ··— ··· — / —··· · / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·— / ···· ·— —· —·· ··· ···· ·— —·— · / ·—·· ·· —· · / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ·—·· ——— ·—— / ··— —· ·—·· · ··· ··· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ·· ··· / ——— —· / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / —·· ——— —·—· ··— —— · —· — ·— — ·· ——— —· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get yaesuUsbTroubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··— ··· · / — ···· · / ··—· ·· ·—· ··· — / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / — ·—— ——— / ··— ··· —··· / ·——· ——— ·—· — ··· ·—·—·— ** / —·—· ·— — / ·· ··· / —· ——— ·—· —— ·— ·—·· ·—·· —·—— / ——— —· / — ···· · / ··—· ·· ·—· ··· — / —·——· — ···· · / ** · —· ···· ·— —· —·—· · —·· ** / —·—· ——— —— / ·——· ——— ·—· — / ——— —· / ·—— ·· —· —·· ——— ·—— ··· —·——·— —·—·—· / — ···· · / ··· · —·—· ——— —· —·· / —·——· ** ··· — ·— —· —·· ·— ·—· —·· ** —·——·— / ·· ··· / ··—· ——— ·—· / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·— / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — / — ···· · / ··—· ·· ·—· ··· — / ·—— ···· · ·—· · ···— · ·—· / ·· — / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·— ·——· ·— ·—· — ·—·—·—\n—····— / ** —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ——— ·—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ——— —· ·—·—·— ** / ·—— ·· — ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ** —·—· ·— — / ·—· — ··· ** / —— · —· ··— / ——— —· ——··—— / ·· — / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — / ·—— ···· ·· ·—·· · / ·—· — ··· / ·· ··· / ·—·· ——— ·—— / — / ·· — / —— ·— —·—— / ·— —· ··· ·—— · ·—· / ——— —· —·—· · / ·— ··· / — ···· · / ·——· ——— ·—· — / ——— ·——· · —· ··· ——··—— / — ···· · —· / —· ——— — ···· ·· —· ——· ·—·—·— / ·——· ·· —·—· —·— ·· —· ——· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — / — ··— ·—· —· ··· / ——— —· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / —·— · —·—— ··· / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ———··· / — ··— ·—· —· / —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· —· ··· — · ·— —·· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—';
	@override String get k4SerialNotes => '—·—· ——— —· —· · —·—· — / — ···· · / —·— ····— ’ ··· / ·—· · ·— ·—· / ··— ··· —··· —····— —··· / —·——· ·——· —·—· —·——·— / ··· ——— —·—· —·— · — ·—·—·— / · ·· — ···· · ·—· / ··— ··· —··· —····— ·——· —·—· ·———— / ——— ·—· / ··— ··· —··· —····— ·——· —·—· ··——— / ·—— ——— ·—· —·— ··· / ··—· ——— ·—· / —·—· ·— — —·—·—· / —·—· ···· ——— ——— ··· · / ·— —· / ··— —· ··— ··· · —·· / ·——· ——— ·—· — / ·— —· —·· / —— ·— — —·—· ···· / ·· — ··· / ··· · ·—· ·· ·— ·—·· / ··— ··· —··· —····— ·——· —·—· —· ———··· / —··· ·— ··— —·· / ·—· ·— — · / ··· · — — ·· —· ——· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / ···· ·— ·—·· ——— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / ···—— ———·· ····— ————— ————— —·—·—· / —·—· ···· ·— —· ——· · / ·· — / ·· ··—· / —· · · —·· · —·· ·—·—·— / ·— —· ——— — ···· · ·—· / ·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / —— ··— ··· — / ··— ··· · / — ···· · / ——— — ···· · ·—· / ·——· ——— ·—· — / ——— ·—· / · — ···· · ·—· —· · — ·—·—·—\n\n— ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ——— —· — ·—· ——— ·—·· ··· / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ·· — ··· / —·— · —·—— · ·—· ··· —·—·—· / ·· — / —·· ——— · ··· / —· ——— — / ··· · —· —·· / ·— ··— —·· ·· ——— / — ——— / ···· ·— ·—·· ——— ·—·—·—';
	@override String get k4TcpNotes => '—·—· ——— —· —· · —·—· — / — ···· · / —·— ····— ’ ··· / · — ···· · ·—· —· · — / ··· ——— —·—· —·— · — / — ——— / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ·—·—·— / · —· — · ·—· / ·· — ··· / ···· ——— ··· — —· ·— —— · / ——— ·—· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / ·— —· —·· / —·—· ·— — / ·——· ——— ·—· — / ————· ··——— ————— ————— ·—·—·— / ···· ·— ·—·· ——— / ··— ··· · ··· / — ···· · / ··· ·— —— · / ···· ——— ··· — / ——— —· / ··—· ·· —··— · —·· / ·——· ——— ·—· — / ————· ··——— ————— ·———— / ·—— ···· · —· / ·— / ·——· ·— —· ·— —·· ·— ·——· — · ·—· / ——— ·—· / ·—— ·— — · ·—· ··—· ·— ·—·· ·—·· / ·· ··· / ···— ·· ··· ·· —··· ·—·· · —·—·—· / —·—· ···· ·— —· ——· ·· —· ——· / — ···· · / —·—· ·— — / ·——· ——— ·—· — / —·· ——— · ··· / —· ——— — / —·—· ···· ·— —· ——· · / — ···· · / ··· ·——· · —·—· — ·—· ··— —— / ·——· ——— ·—· — ·—·—·—\n\n— ···· · / ··· ·——· · —·—· — ·—· ··— —— / ··· ···· ——— ·—— ··· / — ···· · / —— ·— ·· —· / ·—· · —·—· · ·· ···— · ·—· ·—·—·— / ·· — ··· / ——·· ——— ——— —— ——··—— / ·—· · ··—· · ·—· · —· —·—· · / ·— —·· ·——— ··— ··· — —— · —· — / ·— —· —·· / ··· ·——· · · —·· / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— ··—· ··—· · —·—· — / ——— —· ·—·· —·—— / ···· ·— ·—·· ——— ’ ··· / —·· ·· ··· ·——· ·—·· ·— —·—— ·—·—·— / ·— ··— —·· ·· ——— / ··· — ·—· · ·— —— ·· —· ——· / ·· ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· ·—·—·—';
	@override String get k4PowerTimeout => '—·— ····— / ·——· ——— ·—— · ·—· / ·—— ·— ··· / —· ——— — / —·—· ···· ·— —· ——· · —·· / —··· · —·—· ·— ··— ··· · / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· —·· / —· ——— — / —·—· ——— —· ··—· ·· ·—· —— / ·· — ··· / ——— ··— — ·——· ··— — / ·—· ·— —· ——· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
	@override String get k4RemoteNotes => '· —· ·— —··· ·—·· · / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / —·— ····— / ·— —· —·· / · —· — · ·—· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· ·—·—·— / —— ·— ·· —· / ·— —· —·· / ··· ··— —··· / ··· ···· ·— ·—· · / ——— —· · / · —· —·—· ·—· —·—— ·——· — · —·· / —·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ——— ·—· / ·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / ··· ·——· · —·—· — ·—· ··— —— ·—·—·— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·——· ——— ·—· — / ·· ··· / ————· ··——— ————— ····— —·—·—· / · —· — · ·—· / —·—— ——— ··— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / ·——· ——— ·—· — / ·—— ···· · —· / —·—· ——— —· —· · —·—· — ·· —· ——· / ·—· · —— ——— — · ·—·· —·—— ·—·—·—\n\n·— ··— —·· ·· ——— / ·——· ·—·· ·— —·—— —··· ·— —·—· —·— / ·— —· —·· / —— ·· —·—· ·—· ——— ·——· ···· ——— —· · / ··· — ·—· · ·— —— ·· —· ——· / ·— ·—· · / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· ·—·—·—';
	@override String get k4Receiver => '·—· · —·—· · ·· ···— · ·—·';
	@override String get k4ReceiverMain => '—— ·— ·· —·';
	@override String get k4ReceiverSub => '··· ··— —···';
	@override String get k4ReceiverInvalid => '—·—· ···· ——— ——— ··· · / —— ·— ·· —· / ——— ·—· / ··· ··— —···';
	@override String get k4ReceiverAlreadyConfigured => '— ···· ·— — / ·—· · —·—· · ·· ···— · ·—· / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ··—· ——— ·—· / — ···· ·· ··· / —·— ····—';
	@override String get k4SubReceiverOff => '— ···· · / —·— ····— / ··· ··— —··· / ·—· · —·—· · ·· ···— · ·—· / ·· ··· / ——— ··—· ··—·';
	@override String get k4RemotePasswordRequired => '· —· — · ·—· / — ···· · / —·— ····— ’ ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· / — ——— / —·—· ——— —· —· · —·—· — / ··· · —·—· ··— ·—· · ·—·· —·—— ·—·—·—';
	@override String get k4RemoteHandshakeFailed => '— ···· · / —·— ····— / —·—· ——— ··— ·—·· —·· / —· ——— — / · ··· — ·— —··· ·—·· ·· ··· ···· / ·— / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·— —· —·· / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ··· · — — ·· —· ——· ··· ·—·—·—';
	@override String get k4RemoteUnreachable => '— ···· · / —·— ····— ’ ··· / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / ·— —·· —·· ·—· · ··· ··· ——··—— / ·——· ——— ·—· — / ·— —· —·· / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ··· · — — ·· —· ——· ··· ·—·—·—';
	@override String get k4PowerRange => '—·— ····— / ·——· ——— ·—— · ·—· / —— ··— ··· — / —··· · / ————— ·—·—·— ·———— – ·———— ·———— ————— / ·—— ——··—— / ——— ·—· / ————— ·—·—·— ————— ————— ————— ·———— – ————— ·—·—·— ————— ·———— / ·—— / ·—— ···· · —· / — ···· · / — ·—· ·— —· ··· ···— · ·—· — · ·—· / —— ·· ·—·· ·—·· ·· ·—— ·— — — / ——— ··— — ·——· ··— — / ·· ··· / ·— —·—· — ·· ···— · ·—·—·—';
	@override String get elecraftTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get elecraftTroubleshooting => '· ·—·· · —·—· ·—· ·— ··—· — / ·—· ·· ——· ··· / ··· ·——· · ·— —·— / —·— · —· ·—— ——— ——— —·· / —·—· ·— — ——··—— / ·— —· —·· / ·— / —·— —··— ··——— / ·— —· —·· / ·— / —·— —··— ···—— / ···· ·— ···— · / —··· ——— — ···· / —··· · · —· / ·—· ··— —· / — ···· ·· ··· / ·—— ·— —·—— / — / ···— ··—· ——— / ·· —· / —··· ——— — ···· / —·· ·· ·—· · —·—· — ·· ——— —· ··· ——··—— / —— ——— —·· · / ··· ·—— ·· — —·—· ···· ·· —· ——· / ·— —· —·· / —·—· ·—— / ——·· · ·—· ——— —····— —··· · ·— — / ·— ·—·· ·—·· / ·—— ——— ·—· —·— ·· —· ——· ·—·—·—\n\n·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ——··—— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— — · / ··· · — / ··— —· —·· · ·—· / ** ·—· ··· ··——— ···—— ··——— ** / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / ···—— ———·· ····— ————— ————— / ·· ··· / ·—— ···· ·— — / — ···· · ··· · / ··· ···· ·· ·——· / ——— —· ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n** ·· ··—· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ·· ——· ···· — / —··· ··— — / — ···· · / —— ——— —·· · / ·· ··· / ·—— ·—· ——— —· ——· ** ——··—— / — · ·—·· ·—·· / ··— ··· ·—·—·— / — ···· · / —·— —··— ··——— / ·— —· —·· / —·— —··— ···—— / · —· — ·—· ·· · ··· / ·—· · ·— —·· / — ···· · / —— ——— —·· · / ··—· ·—· ——— —— / ·— / ·——· ——— ··· ·· — ·· ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· — ·— — ··— ··· / ·—· · ·——· ·—·· —·—— / — ···· ·— — / ·—— · / ···· ·— ···— · / ·——· ·· —· —· · —·· / ··—· ·—· ——— —— / — ···· · / ·—· ·· ——· ··· / ·—— · / ···· ·— ···— · / ··· · · —· ——··—— / ·— —· —·· / ·— / ··—· ·· ·—· —— ·—— ·— ·—· · / — ···· ·— — / ·——· ··— — ··· / ·· — / · ·—·· ··· · ·—— ···· · ·—· · / ·· ··· / ··· ——— —— · — ···· ·· —· ——· / ——— —· ·—·· —·—— / ·— / ·—· · ·——· ——— ·—· — / ·—· · ·— —·—· ···· · ··· / ··— ··· / ·— ··· ·—·—·—\n\n— ···· · / —·— ···—— / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· · ·——· ——— ·—· — · —·· / · ·· — ···· · ·—· / ·—— ·— —·—— ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ··· ·— —·—— / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / ·· ··—· / —·—— ——— ··— / ·—· ··— —· / ——— —· · ·—·—·— / ·— / —·— ····— / ···· ·— ··· / ·· — ··· / ——— ·—— —· / · —· — ·—· —·—— ·—·—·—';
	@override String get lab599TroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get lab599Troubleshooting => '— ···· · / — —··— —····— ····· ————— ————— / ·—·· ·· —· · / ··· ·——· · ·— —·— ··· / —·— · —· ·—— ——— ——— —·· / —·—· ·— — ·—·—·— / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·—· · ··—· · ·—· · —· —·—· · ··· / ·—· ·— — ···· · ·—· / — ···· ·— —· / — · ··· — · —·· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / · ·· — ···· · ·—· / ·—— ·— —·—— ·—·—·—\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ··· · — — ·· —· ——· ——··—— / ————· —···· ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·——· ·· —·—· —·— / — ···· · / —·—· ·— — / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / — ··· —····— ··——— ————— ————— ————— / —·—· ——— ···— · ·—· ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· · ·—·—·— / ·—·· ·— —··· ····· ————· ————· / ·— ·—·· ··· ——— / ·—·· · — ··· / — ···· · / ·— ·——· ·——· / ··· ·—— ·· — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— / — ——— / —·· ·· ——· ·—·—·—\n—····— / ** — ···· ·—· ——— ··— ——· ···· / ·— / ·—·· ·· —· —·— ····· ————— ————— —— ·——· ** ——··—— / ·——· ·—· · ··· ··· / ·— —· —·· / ···· ——— ·—·· —·· / — ···· · / ···— ··—· ——— / —·— —· ——— —··· / ··—· ——— ·—· / ·— —··· ——— ··— — / — ···· ·—· · · / ··· · —·—· ——— —· —·· ··· / — ——— / ···· ·— —· —·· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / — ——— / — ···· · / ·· —· — · ·—· ··—· ·— —·—· · ·—·—·—\n—····— / ** ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ——— —· / ·— / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / — ···· · / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / ·——· ·— ·· ·—· ··· / ·— ··· / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·— —· —·· / ——— —· ·—·· —·—— / ——— —· · / —·—· ·— ·—· ·—· ·· · ··· / —·—· ·— — ·—·—·— / ·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — ——··—— / ·——· ·· —·—· —·— / — ···· · / ——— — ···· · ·—· ·—·—·—\n—····— / ** ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ** ——··—— / ·— ··· / ——— —· / ·— —· / ·· ·——· ···· ——— —· · / ——— ·—· / ·· ·——· ·— —·· ——··—— / ··· ·—— ·· — —·—· ···· / — ···· · / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / — ——— / ·· — ··· / ·· ——— ··· / —— ——— —·· · / ··—· ·· ·—· ··· — ·—·—·— / ·· —· / ·· — ··· / ——— — ···· · ·—· / —— ——— —·· · ··· / ·· — / —·· ——— · ··· / —· ——— — / ··· ···· ——— ·—— / ··— ·——· / ·· —· / ·— / ··· —·—· ·— —· ·—·—·—';
	@override String get kenwoodTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get kenwoodTroubleshooting => '— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·· ··· / ·——· ·—· ——— ···— · —· / ·— ——· ·— ·· —· ··· — / —·— · —· ·—— ——— ——— —·· ·————· ··· / — ··· —····— ····· ————· ————— ··· ——· / ·— —· —·· / — ··· —····— ····— ———·· ————— ——··—— / ——·— ·—· ·——· / ·—·· ·— —··· ··· ·————· / ——·— —— —··— / ·— —· —·· / ——·— —·—· —··— —····— —— ·· —· ·· ——··—— / ·— —· —·· / · ·—·· · —·—· ·—· ·— ··—· — ·————· ··· / —·— —··— ··——— / ·— —· —·· / —·— —··— ···—— ·—·—·— / — ···· · / ·—· · ··· — / ——— ··—· / — ···· · / ·—·· ·· —· · / ·· ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / ·—· · ··—· · ·—· · —· —·—· · ··· ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / · ·· — ···· · ·—· / ·—— ·— —·—— ·—·—·—\n\n·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ——··—— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** ··· ——— —— · / ·—· ·· ——· ··· / —· · · —·· / —·—· ·— — / · —· ·— —··· ·—·· · —·· ** / ·· —· / — ···· · / —— · —· ··— / —··· · ··—· ——— ·—· · / — ···· · —·—— / ·—· · ··· ·——· ——— —· —·· / ·— — / ·— ·—·· ·—·· ·—·—·—\n\n** ··· · ···— · ·—· ·— ·—·· / ··· —·· ·—· / ··—· ·—· ——— —· — —····— · —· —·· ··· / ··· ·——· · ·— —·— / — ···· ·· ··· / ··· ·— —— · / ·——· ·—· ——— — ——— —·—· ——— ·—·· ** ——··—— / ··· ——— / — ···· ·· ··· / · —· — ·—· —·—— / ·· ··· / ·—— ——— ·—· — ···· / — ·—· —·—— ·· —· ——· / ··—· ——— ·—· / — ···· ——— ··· · / — ——— ——— —·—·—· / · ·—·· · —·—· ·—· ·— ··—· — / ·—· ·· ——· ··· / ·— ·—· · / ·—·· ·· ··· — · —·· / ··· · ·——· ·— ·—· ·— — · ·—·· —·—— ——··—— / ··— —· —·· · ·—· / · ·—·· · —·—· ·—· ·— ··—· — ·—·—·— / ·· ··—· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ·· ——· ···· — / —··· ··— — / — ···· · / —— ——— —·· · / ·· ··· / ·—— ·—· ——— —· ——· / ——— ·—· / —— ·· ··· ··· ·· —· ——· ——··—— / — ···· ·— — / ·· ··· / — ···· · / ——— —· · / ·——· ·— ·—· — / — ···· ·— — / —·· ·· ··—· ··—· · ·—· ··· / ·— —·—· ·—· ——— ··· ··· / — ···· · / ·—·· ·· —· · / — / — ···· · / ·— ·——· ·——· / ·—— ——— ·—· —·— ··· / ·· — / ——— ··— — / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··—· ·— ·—·· ·—·· ··· / —··· ·— —·—· —·— / — ——— / ·— ··· —·— ·· —· ——· / —·· ·· ·—· · —·—· — ·—·· —·—— ——··—— / ··· ——— / — ···· · / —— ——— —·· · / —— ·— —·—— / ··· ·· —— ·——· ·—·· —·—— / ·—·· ·— ——· ·—·—·—';
	@override String get statusConnected => '—·—· ——— —· —· · —·—· — · —··';
	@override String get statusLost => '—·· ·· ··· —·—· ——— —· —· · —·—· — · —··';
	@override String get notConfigured => '—· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··';
	@override String get currentConfiguration => '—·—· ··— ·—· ·—· · —· — / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get currentTransceiver => '—·—· ··— ·—· ·—· · —· — / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·';
	@override String get radioMode => '·—· ·— —·· ·· ——— / —— ——— —·· ·';
	@override String get keyerNotSupported => '—· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· / —··· —·—— / —·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ———';
	@override String get catControlPreferences => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···';
	@override String get chooseTransceiver => '—·—· ···· ——— ——— ··· · / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·';
	@override String get configurationSection => '—·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get noTransceiverSelected => '—· ——— / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· / ··· · ·—·· · —·—· — · —··';
	@override String makeMainVfo({required Object name}) => '··— ··· · / ${name} / ··—· ——— ·—· / — ···· · / —— ·— ·· —· / ···— ··—· ———';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		zero: '—· ——— / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· ···',
		one: '${count} / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·',
		other: '${count} / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· ···',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ·— —· — · —· —· ·—',
		other: '${count} / ·— —· — · —· —· ·— ···',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ——— — ···· · ·—· / —·· · ···— ·· —·—· ·',
		other: '${count} / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···',
	);
	@override String get equipmentInventory => '· ——·— ··— ·· ·——· —— · —· — / ·· —· ···— · —· — ——— ·—· —·——';
	@override String get equipmentInUse => '— ·—· ·— —· ··· —·—· · ·· ···— · ·—· / —·—· ——— —· — ·—· ——— ·—·· ···';
	@override String get noTransceiver => '—· ——— —· ·';
	@override String get peerRadioNotAvailable => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String peerRadioOnDevice({required Object device}) => '——— —· / ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} / ·· ··· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·';
	@override String peerRadioElsewhereMessage({required Object device}) => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ——— / ${device} ·—·—·— / ·· — ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / ··· · — — ·· —· ——· ··· / ·— ·—· · / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ——— —· / — ···· ·— — / —·· · ···— ·· —·—· · ·—·—·—';
	@override String get antennaInUse => '·— —· — · —· —· ·— / ·· —· / ··— ··· ·';
	@override String get keyInUse => '—·— · —·—— / ·· —· / ··— ··· ·';
	@override String get noneSelected => '—· ——— —· ·';
	@override String get moreSettings => '—— ——— ·—· · / ··· · — — ·· —· ——· ···';
	@override String get icomCivTroubleshootingTitle => '·· ··—· / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ··· ···· ——— ·—— / ··— ·——· / ··—· ——— ·—· / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ———';
	@override String get icomCivTroubleshooting => '··· · ···— · ·—· ·— ·—·· / ·· —·—· ——— —— / ·—· ·— —·· ·· ——— ··· ——··—— / — ···· · / ·· —·—· —····— ——··· ————— ····· / ·— —— ——— —· ——· / — ···· · —— ——··—— / ·——· ·—· · ··· · —· — / ** — ·—— ——— ** / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·— — / ——— —· —·—· · / —·——· ·· —·—· ——— —— / —·—· ·— ·—·· ·—·· ··· / — ···· · —— / ·——· ——— ·—· — / ·— / ·— —· —·· / ·——· ——— ·—· — / —··· —·——·— ——··—— / —··· ——— — ···· / ··· · — / — ——— / —·—· ·· —····— ···— / —··· —·—— / —·· · ··—· ·— ··— ·—·· — ·—·—·— / —· · ·· — ···· · ·—· / — ···· ·· ··· / ·— ·——· ·——· / —· ——— ·—· / —·—— ——— ··— ·—· / ——— ··· / —·—· ·— —· / — · ·—·· ·—·· / — ···· · —— / ·— ·——· ·— ·—· — / —··· · —·—— ——— —· —·· / — ···· ·— — ———··· / — ···· · / ··· ·— —— · / ··— ··· —··· / ···— · —· —·· ——— ·—· —··—· ·——· ·—· ——— —·· ··— —·—· — / ·· —·· / ·——— ··— ··· — / ··· ···· ——— ·—— ··· / ··— ·——· / — ·—— ·· —·—· · ——··—— / ··· ——— —— · — ·· —— · ··· / —— ·— ·—· —·— · —·· / ·—— ·· — ···· / ·— / `#2` / ··· ··— ··—· ··—· ·· —··— / ···· · ·—· · ·—·—·— / ** ·——· ——— ·—· — / ·— / ·· ··· / ··— ··· ··— ·— ·—·· ·—·· —·—— / — ···· · / ·—· ·· ——· ···· — / ——— —· · ** / — / —· ——— ·—· —— ·— ·—·· ·—·· —·—— / — ···· · / ··—· ·· ·—· ··· — / ——— —· · / —·—— ——— ··— ·—· / ——— ··· / ——— ·—· / —··· ·—· ——— ·—— ··· · ·—· / ·—·· ·· ··· — ··· ——··—— / ·— —· —·· / ·—— ···· · ·—· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·——· ——— ·—· — ··· / ·— ·——· ·— ·—· — / ·· — / —— ·— ·—· —·— ··· / — ···· ·— — / ——— —· · / ·— ··· / ··· ··— ——· ——· · ··· — · —·· ·—·—·— / ·· ··—· / —·—· ——— —— —— ·— —· —·· ··· / ——· ——— / ——— ··— — / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ··· ——··—— / — ·—· —·—— / — ···· · / ——— — ···· · ·—· / ·——· ——— ·—· — / —· · —··— — ·—·—·—';
	@override String get civAddressTroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ···';
	@override String get civAddressTroubleshooting => '—····— / ** — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ——··—— / —··· ··— — / ·— / ·—· ·· ——· / ··· ···· ·— ·—· ·· —· ——· / ·— / —·—· ·· —····— ···— / —··· ··— ··· / ·· ··· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / — ···· ·— — / ——· · — ··· / —·—· ···· ·— —· ——· · —·· ·—·—·— / ·— / ··—· ·—· ·— —— · / ··· · —· — / — ——— / — ···· · / ·—— ·—· ——— —· ——· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·· ——· —· ——— ·—· · —·· / ·· —· / ··· ·· ·—·· · —· —·—· · ——··—— / ·—— ···· ·· —·—· ···· / ·—·· ——— ——— —·— ··· / · —··— ·— —·—· — ·—·· —·—— / ·—·· ·· —·— · / ·— / —·· · ·— —·· / —·—· ·— —··· ·—·· · ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / —··· ·— ··— —·· / ·—· ·— — · / —·——· ——— —· / ··— ··· —··· ——··—— / —·—· ·· —····— ···— / ··— ··· —··· / —··· ·— ··— —·· / ·—· ·— — · —·——·— ·—·—·— / ··· · — / — ···· · / ·—· ·— —·· ·· ——— / — ——— / — ···· · / ··· ·— —— · / —· ··— —— —··· · ·—· / ··· ···· ——— ·—— —· / ···· · ·—· · ——··—— / ** —· ——— — / ·— ··— — ——— ** ·—·—·— / ——— —· / ·— ··— — ——— / ··· ——— —— · / ·—· ·— —·· ·· ——— ··· ——··—— / — ···· · / ·· —·—· —····— ——··· ···—— ————— ————— / ·— —— ——— —· ——· / — ···· · —— ——··—— / —·—· ——— —· —· · —·—· — / ·— —· —·· / — ···· · —· / ··· — ——— ·——· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·— ··—· — · ·—· / ·— / —— ·· —· ··— — · / ——— ·—· / ··· ——— ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '—····— / ** — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ——··—— / —··· ··— — / ·— / ·—· ·· ——· / ··· ···· ·— ·—· ·· —· ——· / ·— / —·—· ·· —····— ···— / —··· ··— ··· / ·· ··· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / — ···· ·— — / ——· · — ··· / —·—· ···· ·— —· ——· · —·· ·—·—·— / ·— / ··—· ·—· ·— —— · / ··· · —· — / — ——— / — ···· · / ·—— ·—· ——— —· ——· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·· ——· —· ——— ·—· · —·· / ·· —· / ··· ·· ·—·· · —· —·—· · ——··—— / ·—— ···· ·· —·—· ···· / ·—·· ——— ——— —·— ··· / · —··— ·— —·—· — ·—·· —·—— / ·—·· ·· —·— · / ·— / —·· · ·— —·· / —·—· ·— —··· ·—·· · ·—·—·—\n${speed}\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—';
	@override String get icomUsbSpeedFollows => '—····— / ** — ···· · ·—· · / ·· ··· / —· ——— / ··· ·——· · · —·· / — ——— / ··· · — ·—·—·— ** / ——— ···— · ·—· / ··— ··· —··· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ·— ·—·· —·— ··· / ·— — / ·—— ···· ·— — · ···— · ·—· / ··· ·——· · · —·· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / ··— ··· · ··· ——··—— / ·— —· —·· / — ···· ·· ··· / · —· — ·—· —·—— / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· · ··· / ·———— ·———— ····· ··——— ————— ————— ——··—— / — ···· · / ··· ·——· · · —·· / — ···· · / ··· —·—· ——— ·——· · / —· · · —·· ··· ·—·—·—';
	@override String get ic7610UsbSpeed => '—····— / ** ··· · — / —·—· ·· —····— ···— / ··— ··· —··· / —··· ·— ··— —·· / ·—· ·— — · / — ——— / ·———— ·———— ····· ··——— ————— ————— ** ——··—— / — ···· · / ··· ·——· · · —·· / — ···· ·· ··· / · —· — ·—· —·—— / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· · ··· ——··—— / ··· ·· —· —·—· · / — ···· · / ··· —·—· ——— ·——· · / —· · · —·· ··· / ·· — / — / ** —· ——— — / ·— ··— — ——— ** ·—·—·— / ·— / ·—· ·— —·· ·· ——— / ··· · — / — ——— / ·— —· —·—— / ——— — ···· · ·—· / ··· ·——· · · —·· / ·— —· ··· ·—— · ·—· ··· / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ·—·—·—';
	@override String get ic7300Mk2Note => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··——— ** / ··· ···· ·· ·——· ··· / ——— —· / ·— —·· —·· ·—· · ··· ··· / `B6` ——··—— / —· ——— — / — ···· · / `94` / ·——· ·—· · ··—· ·· ·—·· ·—·· · —·· / ···· · ·—· · / — / ·——· ·· —·—· —·— / — ···· · / ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··——— / · —· — ·—· —·—— / ·· —· ··· — · ·— —·· ·—·—·—';
	@override String get ic705PortNote => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ————— ····· ** / ·——· ·—· · ··· · —· — ··· / — ·—— ——— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· ——··—— / —··· ——— — ···· / —· ·— —— · —·· / ·— ··—· — · ·—· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / —·—· ·· —····— ···— / ·· ··· / ——— —· / — ···· · / ** ··—· ·· ·—· ··· — ** / ——— ··—· / — ···· · —— ——··—— / ·—— ···· ·· —·—· ···· / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — / ·—— ···· · ·—· · ···— · ·—· / ·· — / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·— ·——· ·— ·—· — ·—·—·—';
	@override String get ic7760PortNote => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ——··· —···· ————— ** / ··· ·——· · ·— —·— ··· / —·—· ·· —····— ···— / ——— —· / ** ·——· ——— ·—· — / ·— ** / ——— ··—· / — ···· · / — ·—— ——— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·· — / ·——· ·—· · ··· · —· — ··· ·—·—·—';
	@override String get x6100PortNote => '\n—····— / — ···· · / ** —··— —···· ·———— ————— ————— ** / ··· ·——· · ·— —·— ··· / —·—· ·· —····— ···— / ——— —· / ·· — ··· / ** —·· · ···— ** / ·——· ——— ·—· — / — / — ···· · / ··· · —·—· ——— —· —·· / ——— ··—· / — ···· · / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·· — / ·——· ·—· · ··· · —· — ··· ——··—— / ·— —· —·· / — ···· · / ——— —· · / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — ·—·—·—';
	@override String get rigctldTroubleshootingTitle => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —';
	@override String get rigctldTroubleshooting => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— / ** ·—· ·· ——· —·—· — ·—·· —·· / —·· ·— · —— ——— —· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ···· ·— —— ·—·· ·· —··· ·————· ··· / —··· ·— —·—· —·— · —· —·· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· — ··· / ···· ··— —· —·· ·—· · —·· ··· / ——— ··—· / —— ——— —·· · ·—·· ··· ·—·—·—\n\n—····— / ** — ···· · / —·· ·— · —— ——— —· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** ——··—— / · ·—·—·— ——· ·—·—·— / `rigctld -m 1035 -r /dev/ttyUSB0` ·—·—·— / ··—· ·· —· —·· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ·————· ··· / —— ——— —·· · ·—·· / —· ··— —— —··· · ·—· / ·—— ·· — ···· / `rigctl -l` ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / ··· — ·— ·—· — / ·· — / ·—— ·· — ···· / `-T 0.0.0.0` ———··· / —··· —·—— / —·· · ··—· ·— ··— ·—·· — / ·—· ·· ——· —·—· — ·—·· —·· / ——— —· ·—·· —·—— / ·— —·—· —·—· · ·——· — ··· / —·—· ——— —· —· · —·—· — ·· ——— —· ··· / ··—· ·—· ——— —— / — ···· · / —— ·— —·—· ···· ·· —· · / ·· — / ·—· ··— —· ··· / ——— —· ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ····— ····· ···—— ··——— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / — ···· · / —·· ·— · —— ——— —· / ·—— ·· — ···· / `-t` ·—·—·—\n—····— / ——— —· —·—· · / —·—· ——— —· —· · —·—· — · —·· ——··—— / ·— / —— ·· ··· ··· ·· —· ——· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··— ··· ··— ·— ·—·· ·—·· —·—— / —— · ·— —· ··· / — ···· · / —·· ·— · —— ——— —· / ·· — ··· · ·—·· ··—· / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / — · ··· — / ·· — / ·—— ·· — ···· / `rigctl -m 2 f` / ——— —· / — ···· · / —·· ·— · —— ——— —· ·————· ··· / —— ·— —·—· ···· ·· —· · ·—·—·—';
	@override String get flrigTroubleshootingTitle => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —';
	@override String get flrigTroubleshooting => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ··—· ·—·· ·—· ·· ——· / ·——· ·—· ——— ——· ·—· ·— —— / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ··—· ·—·· ·—· ·· ——· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· — ··· / —— ——— ··· — / —— ·— —·— · ··· / ·— —· —·· / —— ——— —·· · ·—·· ··· ·—·—·—\n\n—····— / ** ··—· ·—·· ·—· ·· ——· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** ——··—— / ·—— ·· — ···· / ·· — ··· / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— ····· / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / ·· —· / ··—· ·—·· ·—· ·· ——· ·————· ··· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / —·——· —·—· ——— —· ··—· ·· ——· / → / ··· · — ··— ·——· / → / ··· · ·—· ···— · ·—· —·——·— ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / ··—· ·—·· ·—· ·· ——· ·————· ··· / ··· · ·—· ···— · ·—· / ·· ··· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·— / ·· — / ·—·· ·· ··· — · —· ··· / ——— —· / ·— ·—·· ·—·· / ·· —· — · ·—· ··—· ·— —·—· · ··· ——··—— / —··· ··— — / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / —— ·— —·—— / —· ——— — / ·— ——· ·—· · · ·—·—·—\n—····— / ——— —· —·—· · / —·—· ——— —· —· · —·—· — · —·· ——··—— / ·— / —— ·· ··· ··· ·· —· ——· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··— ··· ··— ·— ·—·· ·—·· —·—— / —— · ·— —· ··· / ··—· ·—·· ·—· ·· ——· / ·· — ··· · ·—·· ··—· / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ··—· ·—·· ·—· ·· ——· ·————· ··· / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / — ···· · / —·· ·· ·— ·—·· ·—·—·—';
	@override String get hrdTroubleshootingTitle => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —';
	@override String get hrdTroubleshooting => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** ···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ·————· ··· / ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· ——··—— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ···· ·—· —·· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** ·· — ··· / ·· ·——· / ··· · ·—· ···— · ·—· / —— ··— ··· — / —··· · / · —· ·— —··· ·—·· · —·· ·—·—·— ** / ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· / ——— —· ·—·· —·—— / — ·— ·—·· —·— ··· / — ——— / ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— ··· / — ···· ·—· ——— ··— ——· ···· / ·· — ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ——··· ———·· ————— ————· / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / ·· —· / — ···· · / ·· ·——· / ··· · ·—· ···— · ·—· ·————· ··· / ··· · — — ·· —· ——· ··· ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ·—·· · — ··· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / — ···· ·—· ——— ··— ——· ···· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·· · ··· —·—· ·—· ·· ·——· — ·· ——— —· ··· / ——— ··—· / ···· ·—· —·· ·————· ··· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ···· ·—· —·· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get n3fjpTroubleshootingTitle => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —';
	@override String get n3fjpTroubleshooting => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** ·— —· / —· ···—— ··—· ·——— ·——· / ·—·· ——— ——· ——· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / —· ···—— ··—· ·——— ·——· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** — ···· · / ·——· ·—· ——— ——· ·—· ·— —— ·————· ··· / ·— ·——· ·· / —— ··— ··· — / —··· · / ——— —· ** ———··· / ··· · — — ·· —· ——· ··· / → / ·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / ·——· ·—· ——— ——· ·—· ·— —— / ·· —· — · ·—· ··—· ·— —·—· · ——··—— / —·—· ···· · —·—· —·— / ** — —·—· ·——· / ·— ·——· ·· / · —· ·— —··· ·—·· · —·· ** ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ·———— ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / — ···· · ·—· · ·—·—·—\n—····— / ** —· ···—— ··—· ·——— ·——· / —— ··— ··· — / ···· ·— ···— · / ·— / ·—· ·— —·· ·· ——— / ·· —· — · ·—· ··—· ·— —·—· · / ··· · — / ··— ·——· ** / — ——— / ··—· ——— ·—·· ·—·· ——— ·—— / ——— ·—· / — ··— —· · / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / ·—— ·· — ···· ——— ··— — / ——— —· · ——··—— / ·· — / ·—· · ·——· ——— ·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·— — / ·· ··· / — —·—— ·——· · —·· / ·· —· — ——— / ·· — ··· / · —· — ·—· —·—— / ·—— ·· —· —·· ——— ·—— ·—·—·—\n—····— / —· ···—— ··—· ·——— ·——· / ·—· · ·——· ——— ·—· — ··· / —··· ·— —· —·· ——··—— / —— ——— —·· · / ·— —· —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— —· ·—·· —·—— ———··· / —· ——— / ·——· ——— ·—— · ·—· ——··—— / —· ——— / — ·—· ·— —· ··· —— ·· — / ··· — ·— — · ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —· ···—— ··—· ·——— ·——· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·— ·——· ·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / —· ···—— ··—· ·——— ·——· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get commanderTroubleshootingTitle => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —';
	@override String get commanderTroubleshooting => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** —·· —··— ·—·· ·— —··· / —·—· ——— —— —— ·— —· —·· · ·—· ——··—— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / —·—· ——— —— —— ·— —· —·· · ·—· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** —·—· ——— —— —— ·— —· —·· · ·—· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · ·—· ···— ·· —·—· · / —— ··— ··· — / —··· · / ——— —· ** ———··· / — ···· · / ** —· · — / ··· · ·—· ···— ** / —··· ··— — — ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·— —· · ·—·· / ——— ··—· / —·—· ——— —— —— ·— —· —·· · ·—· ·————· ··· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·—— ·· —· —·· ——— ·—— ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ····· ··——— ————— ————— ··——— ——··—— / — ···· · / — ···· ·· ·—· —·· / ·——· ——— ·—· — / ——— ··—· / — ···· · / —··· ·—·· ——— —·—· —·— / ··· — ·— ·—· — ·· —· ——· / ·— — / —· · — / ··· · ·—· ···— ·————· ··· / ** —··· ·— ··· · / ·——· ——— ·—· — ** / —·——· ····· ··——— ————— ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — —·——·— ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ·—·· · — ··· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / — ···· ·—· ——— ··— ——· ···· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —·—· ——— —— —— ·— —· —·· · ·—· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / — —·—· ·——· / —— · ··· ··· ·— ——· · ··· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / —·—· ——— —— —— ·— —· —·· · ·—· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—';
	@override String get ic705TroubleshootingTitle => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ···';
	@override String get ic705Troubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ···· ·— ··· / ·— / ** ··· ·· —· ——· ·—·· · ** / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··· · ··· ··· ·· ——— —· ·—·—·— / ·—— ···· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·· ··· / ·· ——· —· ——— ·—· · —·· ——··—— / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· · / ·· ··· / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·· — ·—·—·—\n\n—····— / ** —·—· ·—·· ——— ··· · / ·— —· —·—— / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ·—·—·— ** / ·—— ··—· ···— ·· · ·—— / ——— ·—· / ·—· ··· —····— —··· ·— ·———— / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ——— / ···· ——— ·—·· —·· ··· / — ···· ·— — / ——— —· · / ··· · ··· ··· ·· ——— —· ——··—— / ·— —· —·· / — ···· · / ·—·· ——— ——· ·· —· / ···· · ·—· · / ·· ··· / ··· ·· —— ·——· ·—·· —·—— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·· — / —·· ——— · ··· ·—·—·—\n—····— / ** —·—· ···· · —·—· —·— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ·—·—·— ** / ·—— ·—·· ·— —· / —— ··— ··· — / —··· · / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / —— ··— ··· — / —··· · / ——— —· / — ···· · / ··· ·— —— · / —· · — ·—— ——— ·—· —·— ——··—— / ·— —· —·· / ·· — ··· / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / —·——· —· · — ·—— ——— ·—· —·— —·——·— / ··—· ··— —· —·—· — ·· ——— —· / —— ··— ··· — / —··· · / · —· ·— —··· ·—·· · —·· ·—·—·—\n—····— / ** — ···· · / ·——· ——— ·—· — ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— ——··—— / ——— ·—· / — ···· · / ·——· ——— ·—· — ··· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / — ···· · —— ·—·—·— / ·— / ·—— ·—· ——— —· ——· / ·——· ——— ·—· — / ·· ··· / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ——··—— / — ···· · / ··· ·— —— · / ·— ··· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·· ··· / ——— ··—· ··—· ·—·—·—\n—····— / ** ·——· ——— ·—— · ·—· —····— —·—· —·—— —·—· ·—·· · / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·—— ·—·· ·— —· ** / ·· ··—· / ·· — / ··· — ·— —·—— ··· / ··· — ··— —·—· —·— ·—·—·— / — ···· ·— — / ·—· · ·—·· ·· ·— —··· ·—·· —·—— / —·—· ·—·· · ·— ·—· ··· / ·— / ··· · ··· ··· ·· ——— —· / ··· — ··— —·—· —·— / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n·— / ** ·—— ·—· ——— —· ——· / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·· ··· / ·—· · ··—· ··— ··· · —·· / · —··— ·——· ·—·· ·· —·—· ·· — ·—·· —·—— ** ——··—— / —· ——— — / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ·—·—·— / ·· ··—· / —·—— ——— ··— / ——· ——— — / ···· · ·—· · / ·—· ·— — ···· · ·—· / — ···· ·— —· / ·— / ·—··—· ·—· · ·——— · —·—· — · —·· ·—··—· / —— · ··· ··· ·— ——· · ——··—— / — ···· · / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·· ··· / —· ——— — / — ···· · / ·——· ·—· ——— —··· ·—·· · —— ·—·—·—';
	@override String get icomLanTroubleshooting => '— ···· · / ·—· ·— —·· ·· ——— / ···· ·— ··· / ·— / ** ··· ·· —· ——· ·—·· · ** / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··· · ··· ··· ·· ——— —· ·—·—·— / ·—— ···· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·· ··· / ·· ——· —· ——— ·—· · —·· ——··—— / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· · / ·· ··· / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·· — ·—·—·—\n\n—····— / ** —·—· ·—·· ——— ··· · / ·— —· —·—— / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ·—·—·— ** / ·—— ··—· ···— ·· · ·—— ——··—— / ·—· ··· —····— —··· ·— ·———— / ——— ·—· / ·· —·—· ——— —— ·————· ··· / ·—· · —— ——— — · / ··— — ·· ·—·· ·· — —·—— / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ——— / ···· ——— ·—·· —·· ··· / — ···· ·— — / ——— —· · / ··· · ··· ··· ·· ——— —· ——··—— / ·— —· —·· / — ···· · / ·—·· ——— ——· ·· —· / ···· · ·—· · / ·· ··· / ··· ·· —— ·——· ·—·· —·—— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·· — / —·· ——— · ··· ·—·—·—\n—····— / ** —·—· ···· · —·—· —·— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ·—·—·— ** / ·· — ··· / ·—·· ·— —· / ·——· ——— ·—· — / —— ··— ··· — / —··· · / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / —· · — ·—— ——— ·—· —·— / ·— ··· / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / ·· — ··· / ** —· · — ·—— ——— ·—· —·— / —·—· ——— —· — ·—· ——— ·—·· ** / —— ··— ··· — / —··· · / ——— —· ——··—— / ·— —· —·· / — ···· · / ··— ··· · ·—· —· ·— —— · / ·— —· —·· / ·——· ·— ··· ··· ·—— ——— ·—· —·· / —— ··— ··· — / —··· · / ··· · — / ··— ·——· / ·— ··· / ·— / —· · — ·—— ——— ·—· —·— / ··— ··· · ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** — ···· · / ·——· ——— ·—· — ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— ——··—— / ——— ·—· / — ···· · / ·——· ——— ·—· — ··· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / — ···· · —— ·—·—·— / ·— / ·—— ·—· ——— —· ——· / ·——· ——— ·—· — / ·· ··· / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ——··—— / — ···· · / ··· ·— —— · / ·— ··· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·· ··· / ——— ··—· ··—· ·—·—·—\n—····— / ** ·· ··—· / ·· — / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / —· · ···— · ·—· / ·— —· ··· ·—— · ·—· ··· ** ——··—— / — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / ···· · ·—· · / —— ··— ··· — / —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ·—·—·—\n—····— / ** — ··— ·—· —· / — ···· · / ·—· ·— —·· ·· ——— / ——— ··—· ··—· / ·— —· —·· / ——— —· ** / ·· ··—· / ·· — / ··· — ·— —·—— ··· / ··· — ··— —·—· —·— ·—·—·—';
	@override String get statusStale => '—· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——·';
	@override String get statusDisconnected => '—· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get statusConnecting => '—·—· ——— —· —· · —·—· — ·· —· ——· …';
	@override String get statusDisconnecting => '—·· ·· ··· —·—· ——— —· —· · —·—· — ·· —· ——· …';
	@override String get statusError => '—·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —··';
	@override String get currentRadioSettings => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / ··· · — — ·· —· ——· ···';
	@override String get notSupportedByThisRadio => '—· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· / —··· —·—— / — ···· ·· ··· / ·—· ·— —·· ·· ———';
	@override String get keyerRowLabel => '—·— · —·—— · ·—·';
	@override String get cwMessagesButton => '—·—· ·——';
	@override String get voiceMessagesButton => '·——· ···· ——— —· ·';
	@override String voiceKeyerAvailable({required Object count}) => '···— ——— ·· —·—· · / —·— · —·—— · ·—· ———··· / ${count} / —— · —— ——— ·—· ·· · ··· / ·· —· / — ···· · / ·—· ·— —·· ·· ———';
	@override String get antennaBands => '—··· ·— —· —·· ···';
	@override String get antennaType => '·— —· — · —· —· ·— / — —·—— ·——· ·';
	@override String get antennaTypeRequired => '—·—· ···· ——— ——— ··· · / ·— —· / ·— —· — · —· —· ·— / — —·—— ·——· ·';
	@override late final _Translations$settings$station$antennaTypes$cw antennaTypes = _Translations$settings$station$antennaTypes$cw._(_root);
	@override String get keyType => '—·— · —·—— / — —·—— ·——· ·';
	@override String get keyTypeRequired => '—·—· ···· ——— ——— ··· · / ·— / —·— · —·—— / — —·—— ·——· ·';
	@override late final _Translations$settings$station$keyTypes$cw keyTypes = _Translations$settings$station$keyTypes$cw._(_root);
	@override String get softwareIntermediaries => '··· ——— ··—· — ·—— ·— ·—· · / ·· —· — · ·—· —— · —·· ·· ·— ·—· ·· · ···';
	@override String get otherBrands => '——— — ···· · ·—· / —··· ·—· ·— —· —·· ···';
	@override String get otherEquipment => '——— — ···· · ·—· / · ——·— ··— ·· ·——· —— · —· — / —·——· ·— —· — · —· —· ·— ··· ——··—— / —·— · —·—— ··· ——··—— / · — —·—· —·——·—';
	@override String get newAntenna => '—· · ·—— / ·— —· — · —· —· ·—';
	@override String get newKey => '—· · ·—— / —·— · —·——';
	@override String get newKeyer => '·—— ·· —· —·— · —·—— · ·—· / —·——· —·— ·———— · ·—·· / ——— ·—· / —·—· ——— —— ·——· ·— — ·· —··· ·—·· · —·——·—';
	@override String keyViaRadio({required Object radio}) => '—·—· ·— — / —·— · —·—— · ·—· / ·· —· / ${radio}';
	@override String keyOnDevice({required Object device}) => '—·— · —·—— / ——— —· / ${device}';
	@override String get cwKeyerArea => '—·— · —·—— · ·—· / ·— ·—· · ·—';
	@override String get trackStationInfo => '— ·—· ·— —·—· —·— / ··· — ·— — ·· ——— —· / ·· —· ··—· ——— / ··—· ——— ·—· / · ·— —·—· ···· / ——·— ··· ———';
	@override String get includeStationInfoInAdif => '·· —· —·—· ·—·· ··— —·· · / ·· —· / ·— —·· ·· ··—· / · —··— ·——· ——— ·—· — ···';
	@override String get whatToTrack => '·—— ···· ·— — / — ——— / — ·—· ·— —·—· —·— ··——··';
	@override String get trackFieldRig => '— ·—· ·— —· ··· —·—· · ·· ···— · ·—·';
	@override String get trackFieldPower => '·——· ——— ·—— · ·—·';
	@override String get watts => '·—— ·— — — ···';
	@override String get trackFieldAntenna => '·— —· — · —· —· ·—';
	@override String get trackFieldKey => '—·—· ·—— / —·— · —·——';
	@override String get placeholderConnectDelay => '—·—· ——— —· —· · —·—· — / —·· · ·—·· ·— —·—— / —·——· —— ··· —·——·—';
	@override String get placeholderConnectDelayDescription => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / ··· ·· —— ··— ·—·· ·— — · —·· / ···· ·— —· —·· ··· ···· ·— —·— · / — ·— —·— · ··· ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / —·—· ——— —· —· · —·—· — ··· / ·· —· ··· — ·— —· — ·—·· —·—— ·—·—·—';
	@override String get placeholderDropAfter => '—·· ·—· ——— ·——· / ·— ··—· — · ·—· / —·——· ··· · —·—· ——— —· —·· ··· —·——·—';
	@override String get placeholderDropAfterDescription => '—·—· ·—·· ——— ··· · / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ——— —· / ·· — ··· / ——— ·—— —· ——··—— / — ——— / · —··— · ·—· —·—· ·· ··· · / — ···· · / ·—· · —·—· ——— —· —· · —·—· — / ·——· ·— — ···· ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / —· · ···— · ·—· / —·· ·—· ——— ·——· ··· ·—·—·—';
	@override String get placeholderFailConnect => '·— ·—·· ·—— ·— —·—— ··· / ··—· ·— ·· ·—·· / — ——— / —·—· ——— —· —· · —·—· —';
	@override String get placeholderConnectFailure => '— ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ·—— ·— ··· / — ——— ·—·· —·· / — ——— / ·—· · ··—· ··— ··· · / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get placeholderFreq => '··—· ·—· · ——·— ··— · —· —·—· —·—— / —·——· —·— ···· ——·· —·——·—';
	@override String get placeholderFreqDescription => '·—— ···· · ·—· · / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ··· — ·— ·—· — ··· ·—·—·— / ·· — / ·—· · ·——· ——— ·—· — ··· / —··· ·— —·—· —·— / ·—— ···· ·— — · ···— · ·—· / — ···· · / ·— ·——· ·——· / — ··— —· · ··· / ·· — / — ——— / ·— ··—· — · ·—· ·—— ·— ·—· —·· ··· ·—·—·—';
	@override String get placeholderMode => '—— ——— —·· ·';
	@override String get placeholderModeDescription => '— ···· · / —— ——— —·· · / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ··· — ·— ·—· — ··· / ——— —· ——··—— / · ·—·—·— ——· ·—·—·— / ··— ··· —··· ——··—— / —·—· ·—— ——··—— / ··—· — ———·· ·—·—·—';
	@override String get placeholderPower => '·——· ——— ·—— · ·—· / —·——· ·—— ·— — — ··· —·——·—';
	@override String get placeholderPurpose => '··— ··· · / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ——— / —·— · · ·——· / — ·—· ·— —·—· —·— / ——— ··—· / ·—— ···· ·· —·—· ···· / ·—· ·· ——· / —·—— ——— ··— ·————· ·—· · / ··— ··· ·· —· ——· / ··—· ——— ·—· / ·—·· ——— ——· ——· ·· —· ——· / ·——· ··— ·—· ·——· ——— ··· · ···';
	@override String get placeholderReplyDelay => '·—· · ·——· ·—·· —·—— / —·· · ·—·· ·— —·—— / —·——· —— ··· —·——·—';
	@override String get placeholderReplyDelayDescription => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / — ·— —·— · ··· / — ——— / ·—· · ·——· ——— ·—· — / ·— / —·—· ···· ·— —· ——· · / —··· ·— —·—· —·— ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / ·—· · ·——· ·—·· ·· · ··· / ·— — / ——— —· —·—· · ·—·—·—';
	@override String get cwKeyerField => '—·—· ·— — / —·—· ·—— / —·— · —·—— · ·—·';
	@override String get cwKeyerFieldDescription => '·—— ···· · — ···· · ·—· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / —·— · —·—— ··· / —·—· ·—— / ··—· ·—· ——— —— / — · —··— — / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ——— ··—· ··—· / ··—· ——— ·—· / ·— / ·—· ·· ——· / — ···· · / ·— ·——· ·——· / —·· ——— · ··· / —· ——— — / —·— —· ——— ·—— ·—·—·—';
	@override String get voiceMemories => '···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···';
	@override String get voiceMemoriesDescription => '···· ——— ·—— / —— ·— —· —·—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ————— / ··—· ——— ·—· / —· ——— —· · ·—·—·—';
	@override String get voiceMemoriesInvalid => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· ——··—— / ————— / ——— ·—· / —— ——— ·—· ·';
	@override String get yaesuMeterCapture => '—·—· ·— ·——· — ··— ·—· · / —— · — · ·—· / ·—· · ·— —·· ·· —· ——· ···';
	@override String get yaesuBinaryMeterCaptureDescription => '·—· · ·— —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·——· ——— ·—— · ·—· —····— ——— ··— — ·——· ··— — / —— · — · ·—· / ·— —· —·· / ···· ·· ——· ···· —····— ··· ·—— ·—· / ··—· ·—·· ·— ——· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / ·— —· —·· / ·——· ·—· ·· —· — ··· / — ···· · / ·—· ·— ·—— / ···— ·— ·—·· ··— · ··· / — ——— / — ···· · / ·—·· ——— ——· ·—·—·— / ··—· ——— ·—· / —··· ··— ·· ·—·· —·· ·· —· ——· / — ···· · / ··· —·—· ·— ·—·· · / —·—— ·— · ··· ··— / —·· ——— · ··· / —· ——— — / ·——· ··— —··· ·—·· ·· ··· ···· / — / — ···· · / ···— ·— ·—·· ··— · ··· / ·— ·—· · / —· ——— — / ··· ···· ——— ·—— —· / ·— ··· / —— · — · ·—· ··· ·—·—·—';
	@override String get yaesuMeterCaptureDescription => '·—· · ·— —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·——· ——— ——··—— / ··· ·—— ·—· / ·— —· —·· / ·— ·—·· —·—· / —— · — · ·—· ··· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / ·— —· —·· / ·——· ·—· ·· —· — ··· / — ···· · / ·—· ·— ·—— / ···— ·— ·—·· ··— · ··· / — ——— / — ···· · / ·—·· ——— ——· ·—·—·— / ··—· ——— ·—· / —··· ··— ·· ·—·· —·· ·· —· ——· / — ···· · / ··· —·—· ·— ·—·· · / —·—— ·— · ··· ··— / —·· ——— · ··· / —· ——— — / ·——· ··— —··· ·—·· ·· ··· ···· / — / — ···· · / ···— ·— ·—·· ··— · ··· / ·— ·—· · / —· ——— — / ··· ···· ——— ·—— —· / ·— ··· / —— · — · ·—· ··· ·—·—·—';
	@override String get telemetryInterval => '—— · — · ·—· / ·—· · ·— —·· ·· —· ——· / ·· —· — · ·—· ···— ·— ·—·· / —·——· —— ··· —·——·—';
	@override String get telemetryIntervalDescription => '···· ——— ·—— / ——— ··—· — · —· / — ——— / ·—· · ·— —·· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · — · ·—· ··· / ·—— ···· ·· ·—·· · / ·· — / ·· ··· / — ·—· ·— —· ··· —— ·· — — ·· —· ——· ·—·—·— / ·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / — ···· · / ··—· ·— ··· — · ··· — / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ·— —· / ···· ·— —· —·· ·—·· · ——··—— / ··— ·——· / — ——— / ··——— ————— ————— / —— ··· ·—·—·—';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· / ——— ··—· / —— ·· ·—·· ·—·· ·· ··· · —·—· ——— —· —·· ··· ——··—— / ${min} / — ——— / ${max}';
	@override String get pollInterval => '·· —·· ·—·· · / ·——· ——— ·—·· ·—·· ·· —· ——· / ·· —· — · ·—· ···— ·— ·—·· / —·——· —— ··· —·——·—';
	@override String pollIntervalDescription({required Object fallback}) => '···· ——— ·—— / ——— ··—· — · —· / — ——— / ·— ··· —·— / — ···· · / ·—· ·— —·· ·· ——— / ··—· ——— ·—· / ·· — ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· · / ·—— ···· ·· ·—·· · / —· · ·· — ···· · ·—· / ·· ··· / —·—· ···· ·— —· ——· ·· —· ——· ·—·—·— / ·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / ${fallback} / —— ··· ·—·—·—';
	@override String pollIntervalInvalid({required Object min, required Object max}) => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· / ——— ··—· / —— ·· ·—·· ·—·· ·· ··· · —·—· ——— —· —·· ··· ——··—— / ${min} / — ——— / ${max}';
	@override String get advancedSettings => '·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ···';
	@override String get placeholderSwr => '··· ·—— ·—· / ·—· · ·— —·· ·· —· ——·';
	@override String get placeholderSwrDescription => '·—— ···· ·— — / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·—· · ·——· ——— ·—· — ··· / ——— —· / ·· — ··· / ··· ·—— ·—· / —— · — · ·—· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· ·—·—·— / ·— —··· ——— ···— · / ·———— ·—·—·— ———·· / — ···· · / ·——· ·— —· · ·—·· / ·—— ·— ·—· —· ··· ·—·—·—';
	@override String get placeholderSwrInvalid => '·— / —· ··— —— —··· · ·—· ——··—— / ·———— / ——— ·—· / —— ——— ·—· ·';
	@override String get keyerNone => '—· ——— —· ·';
	@override String get cwDialect => '—·—· ·—— / —·— · —·—— ·· —· ——· / —·· ·· ·— ·—·· · —·—· —';
	@override String get cwDialectDescription => '·—— ···· ·· —·—· ···· / ··· ···· ·— ·——· · / ——— ··—· / — ···· · / —·— —·—— / —·—· ——— —— —— ·— —· —·· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ·— —·— · ··· ·—·—·— / —· ——— —· · / —— · ·— —· ··· / —· ——— / —·—· ·—— / —·— · —·—— ·· —· ——· / ——— ···— · ·—· / —·—· ·— — ·—·—·—';
	@override String get cwDialectKenwood => '—·— · —· ·—— ——— ——— —·· / —·——· —·— —·—— ——··—— / ·——· ·— —·· —·· · —·· / — ——— / ··——— ····— —·——·—';
	@override String get cwDialectElecraft => '· ·—·· · —·—· ·—· ·— ··—· — / —·——· —·— —·—— / — · —··— — —·——·—';
	@override String get voiceDialect => '···— ——— ·· —·—· · / —·— · —·—— · ·—· / —·· ·· ·— ·—·· · —·—· —';
	@override String get voiceDialectDescription => '···· ——— ·—— / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— ··· / ·· — ··· / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / —· ——— —· · / —— · ·— —· ··· / —· ——— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ·—— ·· — ···· / ·— / —·· ·· ·— ·—·· · —·—· — / ·— —· —·· / —· ——— / —·—· ——— ··— —· — ——··—— / — ···· · / —·· ·· ·— ·—·· · —·—· — ·————· ··· / —·· · ··—· ·— ··— ·—·· — / —·—· ——— ··— —· — / ·— ·——· ·——· ·—·· ·· · ··· ·—·—·—';
	@override String get voiceDialectPb => '—·— · —· ·—— ——— ——— —·· / —·——· ·——· —··· ——··—— / — ··· —····— ····· ————· ————— / ··· — —·—— ·—·· · —·——·—';
	@override String get voiceDialectK4 => '· ·—·· · —·—· ·—· ·— ··—· — / —·— ····— / —·——· ·——· —··· / ·— —· —·· / —·· ·— —·——·—';
	@override String get voiceDialectKx => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··——— —··—· —·— —··— ···—— / —·——· ··· ·—— ·· — —·—· ···· / — ·— ·——· ··· —·——·—';
	@override String get placeholderDiagnostic => '··· ·· —— ··— ·—·· ·— — · —··';
	@override String get placeholderWholeNumberInvalid => '—— ··— ··· — / —··· · / ·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· ——··—— / ————— / ——— ·—· / —— ——— ·—· ·';
	@override String get placeholderFreqInvalid => '—— ··— ··· — / —··· · / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· —· / —·— ···· ——·· ——··—— / ——· ·—· · ·— — · ·—· / — ···· ·— —· / ——·· · ·—· ———';
	@override String get placeholderModeInvalid => '—— ··— ··· — / —··· · / ·— / —— ——— —·· · / —· ·— —— · ——··—— / · ·—·—·— ——· ·—·—·— / ··— ··· —··· ——··—— / —·—· ·—— ——··—— / ··—· — ———··';
	@override String get switchLayout => '·—·· ·— —·—— ——— ··— —';
	@override String get switchLayoutDescription => '·—— ···· ·· —·—· ···· / ··· ·· —·· · / ——— ··—· / — ···· · / ··· ·—— ·· — —·—· ···· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ··· / ·— ·—· · / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—';
	@override String get switchLayoutRequired => '—·—· ···· ——— ——— ··· · / ···· ——— ·—— / — ···· · / ··· ·—— ·· — —·—· ···· / ·· ··· / ·—— ·· ·—· · —··';
	@override String switchCommandRefused({required Object command, required Object code}) => '— ···· · / ··· ·—— ·· — —·—· ···· / ·—· · ··—· ··— ··· · —·· / ·—··—· ${command} ·—··—· / —·——· · ·—· ·—· ——— ·—· / ${code} —·——·—';
	@override String get switchBusyTransmitting => '— ···· ·— — / ·——· ——— ·—· — / ·· ··· / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / — / ·— —· — · —· —· ·— / —· ——— — / —·—· ···· ·— —· ——· · —··';
	@override String get switchNoAntenna => '—· ——— —· ·';
	@override String switchAntennaFor({required Object port}) => '·— —· — · —· —· ·— / ——— —· / ·——· ——— ·—· — / ${port}';
	@override String get switchAntennaForDescription => '·—— ···· ·· —·—· ···· / ——— ··—· / —·—— ——— ··— ·—· / ·— —· — · —· —· ·— ··· / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· ·· ··· / ·——· ——— ·—· — / ——— —· / — ···· · / ··· ·—— ·· — —·—· ···· ·—·—·—';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} / ·— —· — · —· —· ·— ··· ——··—— / ${radios} / ·—· ·— —·· ·· ——— ···';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} / ·— —· — · —· —· ·— ··· ——··—— / ·———— / ·—· ·— —·· ·· ———';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '·———— / ·— —· — · —· —· ·— ——··—— / ${radios} / ·—· ·— —·· ·· ——— ···';
	@override String get switchCommonPort => '—·—· ——— —— —— ——— —·';
	@override String get dcnAddress => '—·· · ···— ·· —·—· · / ·— —·· —·· ·—· · ··· ···';
	@override String get dcnAddressDescription => '— ···· · / ·— —·· —·· ·—· · ··· ··· / ··· · — / ——— —· / — ···· · / —— ——— —·· ··— ·—·· · ·————· ··· / —·· ·· ·——· / ··· ·—— ·· — —·—· ···· · ··· ·—·—·— / ·— / —·—· ——— ·— —··— / ·—· · ·—·· ·— —·—— / —— ——— —·· ··— ·—·· · / ·—·· · ·— ···— · ··· / — ···· · / ··—· ·— —·—· — ——— ·—· —·—— / ·— — / ··——— ·—·—·—';
	@override String get dcnAddressRequired => '—— ··— ··· — / —··· · / ·— / —·· · ···— ·· —·—· · / ·— —·· —·· ·—· · ··· ··· / ··—· ·—· ——— —— / ·———— / — ——— / ————· ————·';
	@override String switchPortLabel({required Object port}) => '·——· ——— ·—· — / ${port}';
	@override String get switchPortAutoHint => '··—· ——— ·—·· ·—·· ——— ·—— ··· / —··· ·— —· —·· / —·· ·— — ·—';
	@override String get switchPortTransmittingHint => '— ·—· ·— —· ··· —— ·· — — ·· —· ——· / — / —·—· ·— —· —· ——— — / —·—· ···· ·— —· ——· · / —· ——— ·——';
	@override String get switchCurrentStateHeader => '—·—· ··— ·—· ·—· · —· — / ··· — ·— — ·';
	@override String get switchCurrentStateDescription => '·—— ···· ·· —·—· ···· / ·— —· — · —· —· ·— / · ·— —·—· ···· / ·—· ·— —·· ·· ——— / ·——· ——— ·—· — / ·· ··· / ——— —· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·— / —·—· ···· ·— —· ——· · ··· / — ·— —·— · / · ··—· ··—· · —·—· — / ·· —— —— · —·· ·· ·— — · ·—·· —·—— ·—·—·—';
	@override String get switchWiringHeader => '·—— ·· ·—· ·· —· ——·';
	@override String get switchPortInhibitedHint => '— ·—· ·— —· ··· —— ·· — / ·· —· ···· ·· —··· ·· — · —··';
	@override String get configUnreadable => '— ···· ·· ··· / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·— ···— · —·· / ··· · — — ·· —· ——· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ·—·—·— / ——— ·——· · —· / ·· — ··· / ··· · — — ·· —· ——· ··· / ·— —· —·· / · —· — · ·—· / — ···· · —— / ·— ——· ·— ·· —· ——··—— / ——— ·—· / ·—· · —— ——— ···— · / ·· — / ·— —· —·· / ·— —·· —·· / ·· — / —··· ·— —·—· —·— ·—·—·—';
	@override String get autoConnectHeld => '···· ·— ·—·· ——— / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — ···· · / ·—·· ·— ··· — / — ·· —— · / ·· — / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· ·· ··· / ·—· ·— —·· ·· ——— ——··—— / ··· ——— / ·· — / —·· ·· —·· / —· ——— — / —·—· ——— —· —· · —·—· — / ——— —· / ·· — ··· / ——— ·—— —· / — ···· ·· ··· / — ·· —— · ·—·—·— / ·——· ·—· · ··· ··· / —·—· ——— —· —· · —·—· — / — ——— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$cw extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·—';
	@override String get noFiles => '—· ——— / —·· ·— — ·— / ··—· ·· ·—·· · ···';
	@override String get noFilesDescription => '· —· ·— —··· ·—·· · / ·— —·—· — ·· ···— ·· — —·—— / ——— ·—· / ·—·· ——— ——— —·— ··— ·——· / · —··— — · —· ··· ·· ——— —· ··· / — ——— / —·· ——— ·—— —· ·—·· ——— ·— —·· / — ···· · ·· ·—· / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— / ···· · ·—· · ·—·—·—';
	@override String get refresh => '·—· · ··—· ·—· · ··· ····';
	@override String get refreshing => '·—· · ··—· ·—· · ··· ···· ·· —· ——· …';
	@override String get updateAll => '··— ·——· —·· ·— — · / ·— ·—·· ·—··';
	@override String get updatingAll => '··— ·——· —·· ·— — ·· —· ——· / ·— ·—·· ·—·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· …';
	@override String get neverDownloaded => '—· · ···— · ·—· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —··';
	@override String get updatedJustNow => '··— ·——· —·· ·— — · —·· / ·——— ··— ··· — / —· ——— ·——';
	@override String updatedDaysAgo({required Object days}) => '··— ·——· —·· ·— — · —·· / ${days} —·· / ·— ——· ———';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '··— ·——· —·· ·— — · —·· / ${days} —·· / ${hours} ···· / ·— ——· ———';
	@override String updatedHoursAgo({required Object hours}) => '··— ·——· —·· ·— — · —·· / ${hours} ···· / ·— ——· ———';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '··— ·——· —·· ·— — · —·· / ${hours} ···· / ${minutes} —— / ·— ——· ———';
	@override String updatedMinutesAgo({required Object minutes}) => '··— ·——· —·· ·— — · —·· / ${minutes} —— / ·— ——· ———';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => '— ···· · / ·—·· ·— ··· — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ···· ·— —·· / ——— —· ·—·· —·—— / ${imported} / ——— ··—· / ${existing} / ·—· · —·—· ——— ·—· —·· ··· / ·— —· —·· / ·—— ·— ··· / —· ——— — / ··— ··· · —·· ·—·—·— / ·—· · ··—· ·—· · ··· ···· / — ——— / ·— —·—· —·—· · ·——· — / ·· — ·—·—·—';
	@override String get extensionsSection => '· —··— — · —· ··· ·· ——— —· ···';
}

// Path: settings.profiles
class _Translations$settings$profiles$cw extends Translations$settings$profiles$en {
	_Translations$settings$profiles$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get notSet => '—· ——— — / ··· · —';
	@override String get personalInfo => '·——· · ·—· ··· ——— —· ·— ·—·· / ·· —· ··—· ———';
	@override String get personalInfoNote => '— ···· ·· ··· / —— ·· ——· ···· — / —··· · / ·· —· —·—· ·—·· ··— —·· · —·· / ·· —· / ——· · —· · ·—· ·— — · —·· / ·—·· ——— ——· ··· / ·—— ···· · —· / ·—· · ·—·· · ···— ·— —· — / ··—· ——— ·—· / ··· ··— —··· —— ·· ··· ··· ·· ——— —· ···';
	@override String get name => '—· ·— —— ·';
	@override String get email => '· —— ·— ·· ·—··';
	@override String get club => '—·—· ·—·· ··— —···';
	@override String get arrlSection => '·— ·—· ·—· ·—·· / ··· · —·—· — ·· ——— —·';
	@override String get racSection => '·—· ·— —·—· / ··· · —·—· — ·· ——— —·';
	@override String get section => '··· · —·—· — ·· ——— —·';
}

// Path: settings.search
class _Translations$settings$search$cw extends Translations$settings$search$en {
	_Translations$settings$search$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get clear => '—·—· ·—·· · ·— ·—·';
	@override String get hint => '··· · ·— ·—· —·—· ···· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···';
}

// Path: settings.developer
class _Translations$settings$developer$cw extends Translations$settings$developer$en {
	_Translations$settings$developer$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => '· —· ·— —··· ·—·· · / —·· · ···— · ·—·· ——— ·——· · ·—· / ·—— ·— ·—· —· ·· —· ——· ··· ——··—— / —·· · —··· ··— ——· / ·—·· ——— ——· ··· ——··—— / ·— —· —·· / — ——— ——— ·—·· ··· ·—·—·—';
	@override String get experiments => '· —··— ·——· · ·—· ·· —— · —· — ···';
	@override String get showIdleMetrics => '··· ···· ——— ·—— / ·· —·· ·—·· · / —— · — ·—· ·· —·—· ···';
	@override String get showIdleMetricsDescription => '··· ···· ——— ·—— / ·· —· / — ···· · / ··· — ·— — ··— ··· / —··· ·— ·—· / ···· ——— ·—— / ·· —·· ·—·· · / — ···· · / · —··— — · —· ··· ·· ——— —· / · —· ——· ·· —· · / ···· ·— ··· / —··· · · —· / ——— ···— · ·—· / — ···· · / ·—·· ·— ··· — / ··· · —·—· ——— —· —·· ·—·—·— / — ·— ·——· / ·· — / ··—· ——— ·—· / — ···· · / ·———— ————— —····— / ·— —· —·· / —···· ————— —····— ··· · —·—· ——— —· —·· / ·— ···— · ·—· ·— ——· · ··· ·—·—·—';
	@override String idleMetricsReadout({required Object percent}) => '${percent} % / ·· —·· ·—·· ·';
	@override String get idleMetricsAverages => '·· —·· ·—·· · / ·— ···— ——· ———···';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds} ··· / ${percent} %';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / · —· ·— —··· ·—·· · —··',
		other: '${count} / · —· ·— —··· ·—·· · —··',
	);
	@override String get patchTrack => '—·—· ——— —·· · / ·——· ··— ··· ···· / — ·—· ·— —·—· —·—';
	@override String get patchTrackDescription => '·—— ···· ·· —·—· ···· / ——— ···— · ·—· —····— — ···· · —····— ·— ·· ·—· / —·—· ——— —·· · / ·——· ··— ··· ···· / ·—· ·· —· ——· / — ···· ·· ··· / —·· · ···— ·· —·—· · / ··—· ——— ·—·· ·—·· ——— ·—— ··· ·—·—·— / —— ——— ·—· · / ·— —·· ···— · —· — ··— ·—· ——— ··— ··· / ·—· ·· —· ——· ··· / ——· · — / ··—· ·· —··— · ··· / · ·— ·—· ·—·· ·· · ·—· ——··—— / ·—·· · ··· ··· / — · ··· — · —·· ·—·—·— / —·—· ——— —·· · / ·——· ··— ··· ···· · ··· / ·— ·——· ·——· ·—·· —·—— / ——— —· / — ···· · / —· · —··— — / ·—· · ··· — ·— ·—· — ·—·—·—';
	@override String get trackStable => '··· — ·— —··· ·—·· ·';
	@override String get trackUnstable => '··— —· ··· — ·— —··· ·—·· ·';
	@override String get trackBleeding => '—··· ·—·· · · —·· ·· —· ——·';
	@override String checkingTrack({required Object track}) => '—·—· ···· · —·—· —·— ·· —· ——· / ·—··—· ${track} ·—··—· / ··—· ——— ·—· / ·— / —·—· ——— —·· · / ·——· ··— ··· ···· …';
	@override String get patchDownloaded => '—·—· ——— —·· · / ·——· ··— ··· ···· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / — / ·—· · ··· — ·— ·—· — / — ···· · / ·— ·——· ·——· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—';
	@override String noNewPatch({required Object track}) => '—· ——— / —· · ·—— / —·—· ——— —·· · / ·——· ··— ··· ···· / ——— —· / ·—··—· ${track} ·—··—· ·—·—·—';
	@override String get noPatchInstalled => '—· ——— / —·—· ——— —·· · / ·——· ··— ··· ···· / ·· —· ··· — ·— ·—·· ·—·· · —·· / — / ·—· ··— —· —· ·· —· ——· / — ···· · / ·—· · ·—·· · ·— ··· · / —··· ·· —· ·— ·—· —·—— ·—·—·—';
	@override String runningPatch({required Object patch}) => '·—· ··— —· —· ·· —· ——· / —·—· ——— —·· · / ·——· ··— ··· ···· / # ${patch} ·—·—·—';
	@override String get deepLinks => '—·· · · ·——· / ·—·· ·· —· —·— ···';
	@override String get registerUrlSchemes => '·—· · ——· ·· ··· — · ·—· / ··— ·—· ·—·· / ··· —·—· ···· · —— · ···';
	@override String get registerUrlSchemesDescription => '·—·· · — / —·—· ——— —— ·—·—·— ···· ·— —— ··——— —·— ———··· —··—· —··—· / ·—·· ·· —· —·— ··· / ——— ·——· · —· / — ···· ·· ··· / —·—· ——— ·——· —·—— / ——— ··—· / — ···· · / ·— ·——· ·——·';
	@override String get registerUrlSchemesDone => '— ···· ·· ··· / —·—· ——— ·——· —·—— / —· ——— ·—— / ——— ·——· · —· ··· / —·—· ——— —— ·—·—·— ···· ·— —— ··——— —·— ———··· —··—· —··—· / ·—·· ·· —· —·— ···';
	@override String registerUrlSchemesFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ——· ·· ··· — · ·—· ———··· / ${error}';
	@override String get systemInformation => '··· —·—— ··· — · —— / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·';
	@override String get appVersion => '·— ·——· ·——· / ···— · ·—· ··· ·· ——— —·';
	@override String get dataFolder => '—·· ·— — ·— / ··—· ——— ·—·· —·· · ·—·';
	@override String get loading => '—·——· ·—·· ——— ·— —·· ·· —· ——· … —·——·—';
	@override String get panelLoadFailed => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—·· ——— ·— —·· / — ···· ·· ··· / ··· · — — ·· —· ——· ··· / ·——· ·— —· · ·—·· ·—·—·—';
	@override String get extDevServer => '· —··— — · —· ··· ·· ——— —· / —·· · ···— / ··· · ·—· ···— · ·—·';
	@override String get extensionSettings => '· —··— — · —· ··· ·· ——— —· / ··· · — — ·· —· ——· ···';
	@override String get extDevServerDescription => '·—·· ——— ·— —·· / · —··— — · —· ··· ·· ——— —· ··· / ··—· ·—· ——— —— / ·— / —·· · ···— / ··· · ·—· ···— · ·—· / ——— —· / —·—— ——— ··— ·—· / —· · — ·—— ——— ·—· —·— / ·· —· ··· — · ·— —·· / ——— ··—· / — ···· · / ——— —· · ··· / —··· ··— ·· ·—·· — / ·· —· — ——— / — ···· · / ·— ·——· ·——· ——··—— / ·— —· —·· / ·—· · ·—·· ——— ·— —·· / — ···· · —— / ·— ··· / —·—— ——— ··— / ··· ·— ···— · ·—·—·—';
	@override String get extDevServerAddress => '··· · ·—· ···— · ·—· / ·— —·· —·· ·—· · ··· ···';
	@override String get extDevServerHint => '·———— ————· ··——— ·—·—·— ·———— —···· ———·· ·—·—·— ·———— ·—·—·— ··——— ————— ———··· ———·· ——··· ———·· ——···';
	@override String get extDevServerConnect => '—·—· ——— —· —· · —·—· —';
	@override String get extDevServerDisconnect => '—·· ·· ··· —·—· ——— —· —· · —·—· —';
	@override String get extDevServerConnecting => '—·—· ——— —· —· · —·—· — ·· —· ——· …';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· · ·—· ···— ·· —· ——· / ${count} / · —··— — · —· ··· ·· ——— —· ———··· / ${keys}',
		other: '··· · ·—· ···— ·· —· ——· / ${count} / · —··— — · —· ··· ·· ——— —· ··· ———··· / ${keys}',
	);
	@override String get extDevServerDisconnected => '—· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get extDevServerReconnect => '·—· · —·—· ——— —· —· · —·—· — / ·— — / ·—·· ·— ··— —· —·—· ····';
	@override String extDevServerLastReload({required Object key, required Object time}) => '·—·· ·— ··· — / ·—· · ·—·· ——— ·— —·· ———··· / ${key} / ·— — / ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / · —··— — · —· ··· ·· ——— —· / ··—· ·— ·· ·—·· ·· —· ——· / — ——— / —··· ··— ·· ·—·· —··',
		other: '${count} / · —··— — · —· ··· ·· ——— —· ··· / ··—· ·— ·· ·—·· ·· —· ——· / — ——— / —··· ··— ·· ·—·· —··',
	);
	@override String get catalog => '· —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——·';
	@override String get catalogDescription => '·—· · ·— —·· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / ··· · ·—· ···— · ·—· / — / ·— / ·—·· ——— —·—· ·— ·—·· / ——— —· · / ·—— ···· ·· ·—·· · / ·—— ——— ·—· —·— ·· —· ——· / ——— —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / ·· — ··· · ·—·· ··—· ·—·—·— / · —— ·——· — —·—— / —— · ·— —· ··· / —·—· ·— — ·— ·—·· ——— ——· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ·—·—·—';
	@override String get catalogAddress => '—·—· ·— — ·— ·—·· ——— ——· / ·— —·· —·· ·—· · ··· ···';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => '—·—· ·— — ·— ·—·· ——— ——· / ··· · ·— ·—· —·—· ···· / — ·—· ·— —·—· —·— ···';
	@override String get catalogSearchStable => '——— —· ·—·· —·—— / ··· — ·— —··· ·—·· ·';
	@override String get catalogSearchUnstable => '··— —· ··· — ·— —··· ·—·· · / ——— ·—· / —··· · — — · ·—·';
	@override String get catalogSearchBleeding => '—··· ·—·· · · —·· ·· —· ——· / ——— ·—· / —··· · — — · ·—·';
}

// Path: settings.about
class _Translations$settings$about$cw extends Translations$settings$about$en {
	_Translations$settings$about$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get notices => '—· ——— — ·· —·—· · ··· / ·—··· / —— · ··· ··· ·— ——· · ···';
	@override String get noticesDescription => '·— —· —· ——— ··— —· —·—· · —— · —· — ··· / ·— —· —·· / ··· — ·— — ··— ··· / —— · ··· ··· ·— ——· · ···';
	@override String get releaseNotes => '·—· · ·—·· · ·— ··· · / —· ——— — · ···';
	@override String get copiedVersion => '—·—· ——— ·——· ·· · —·· / ···— · ·—· ··· ·· ——— —· / —·· · — ·— ·· ·—·· ··· / — ——— / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··';
}

// Path: settings.panels
class _Translations$settings$panels$cw extends Translations$settings$panels$en {
	_Translations$settings$panels$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get settings => '·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···';
	@override String get settingsDescription => '—— ·— —·— · / — ···· · / ·— ·——· ·——· / ·—— ——— ·—· —·— / ···· ——— ·—— / —·—— ——— ··— / ·—— ·— —· — / ·· —';
	@override String get commonSettings => '—·—· ——— —— —— ——— —· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···';
	@override String get syncDescription => '—··· ·— —·—· —·— / ··— ·——· / ·— —· —·· / ··· —·—— —· —·—· / —·—— ——— ··— ·—· / ·—·· ——— ——· ··· / ·— —·—· ·—· ——— ··· ··· / —·· · ···— ·· —·—· · ···';
	@override String get accountsDescription => '··· · ·—· ···— ·· —·—· · / —·—· ·—· · —·· · —· — ·· ·— ·—·· ··· ——··—— / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— ——··—— / ·— —· —·· / —— ——— ·—· ·';
	@override String get extensions => '· —··— — · —· ··· ·· ——— —· ··· / ·—··· / ··—· · ·— — ··— ·—· · ···';
	@override String get extensionsDescription => '·— —·—· — ·· ···— ·· — ·· · ··· ——··—— / —·—· ——— —· — · ··· — ··· ——··—— / —·· ·— ··· ···· —··· ——— ·— ·—· —·· / ·——· ·— —· · ·—·· ··· / ·— —· —·· / —— ——— ·—· · / ··—· · ·— — ··— ·—· · ···';
	@override String get profilesDescription => '——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ··· — ·— — ·· ——— —· / ·——· ·—· ——— ··—· ·· ·—·· ·';
	@override String get stationProfiles => '··· — ·— — ·· ——— —· / ·——· ·—· ——— ··—· ·· ·—·· · ···';
	@override String get developerSettings => '—·· · ···— · ·—·· ——— ·——· · ·—· / ··· · — — ·· —· ——· ···';
	@override String get developerSettingsDescription => '—·· · —··· ··— ——· ——· ·· —· ——· / ·— —· —·· / —·· · ···— · ·—·· ——— ·——· —— · —· — / — ——— ——— ·—·· ···';
	@override String get about => '·— —··· ——— ··— —';
	@override String get aboutDescription => '···— · ·—· ··· ·· ——— —· ——··—— / —·—· ·—· · —·· ·· — ··· ——··—— / ·— —· —·· / ·—·· · ——· ·— ·—·· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·';
	@override String get unavailableTitle => '··· ——— —— · / ··· · — — ·· —· ——· ··· / ·— ·—· · / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·';
	@override String get unavailableText => '— ···· · / · —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / ··—· ·— ·· ·—·· · —·· / — ——— / ··· — ·— ·—· — ——··—— / ··· ——— / · —··— — · —· ··· ·· ——— —· —····— —·—· ——— —· — ·—· ·· —··· ··— — · —·· / ··· · — — ·· —· ——· ··· / ·— ·—· · / —— ·· ··· ··· ·· —· ——· ·—·—·—';
	@override String get station => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·';
	@override String get stationDescription => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / —— ——— ·—· · / ——— ·——· — ·· ——— —· ···';
	@override String get peers => '·——· · · ·—· / —·· · ···— ·· —·—· · ···';
	@override String get peersDescription => '—·—· ——— —· —· · —·—· — / — ——— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / —· · ·— ·—· —··· —·——';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$cw extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get locale => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···';
	@override String get period => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· · / ·——· · ·—· ·· ——— —·· / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···';
	@override String get comma => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· · / —·—· ——— —— —— ·— / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$cw extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => '··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / —·——· ··— ··· ·· —· ——· / ${separator} / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ··· —·——·—';
	@override String get period => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·——· · ·—· ·· ——— —·· / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···';
	@override String get comma => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / —·—· ——— —— —— ·— / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$cw extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get comma => '—·—· ——— —— —— ·—';
	@override String get period => '·——· · ·—· ·· ——— —··';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$cw extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get six => '—···· / —·· ·· ——· ·· — ··· / —·——· ··—· —· ···—— ·———— ·——· ·—· —·——·—';
	@override String get eight => '———·· / —·· ·· ——· ·· — ··· / —·——· ··—· —· ···—— ·———— ·——· ·—· ····· ····· —·——·—';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$cw extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get six => '—···· / —·· ·· ——· ·· — ···';
	@override String get eight => '———·· / —·· ·· ——· ·· — ···';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$cw extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => '——— ·——· · —· / — ···· · / —·—· ——— —— —— ·— —· —·· / —·· ·· ·— ·—·· ——— ——·';
	@override String get toggleTheme => '··· ·—— ·· — —·—· ···· / —··· · — ·—— · · —· / ·—·· ·· ——· ···· — / ·— —· —·· / —·· ·— ·—· —·—';
	@override String get toggleLanguage => '··· ·—— ·· — —·—· ···· / —··· · — ·—— · · —· / · —· ——· ·—·· ·· ··· ···· / ·— —· —·· / ··· ·——· ·— —· ·· ··· ····';
	@override String get fontScaleUp => '·—·· ·— ·—· ——· · ·—· / — · —··— —';
	@override String get fontScaleDown => '··· —— ·— ·—·· ·—·· · ·—· / — · —··— —';
	@override String get fontScaleReset => '—· ——— ·—· —— ·— ·—·· / — · —··— — / ··· ·· ——·· ·';
	@override String get densityLooser => '·—· ——— ——— —— ·· · ·—· / ·—·· ·— —·—— ——— ··— —';
	@override String get densityDenser => '—·· · —· ··· · ·—· / ·—·· ·— —·—— ——— ··— —';
	@override String get densityAuto => '·— ··— — ——— —— ·— — ·· —·—· / ·—·· ·— —·—— ——— ··— — / —·· · —· ··· ·· — —·——';
	@override String get find => '··—· ·· —· —·· / ·· —· / — ···· · / ·—·· ——— ——·';
	@override String keyerMessage({required Object n}) => '··· · —· —·· / —— · ··· ··· ·— ——· · / ${n}';
	@override String get keyboardMode => '—·— · —·—— —··· ——— ·— ·—· —·· / —— ——— —·· · / ——— —· / ——— ·—· / ——— ··—· ··—·';
	@override String get ptt => '·——· ··— ··· ···· / — ——— / — ·— ·—·· —·—';
	@override String get wipe => '—·—· ·—·· · ·— ·—· / — ···· · / —·—· ——— —· — ·— —·—· — / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —··';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$cw extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get callsign => '— —·—— ·——· ·· —· ——· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···';
	@override String get escape => '··· — ——— ·——· / ··· · —· —·· ·· —· ——· ——··—— / —··· ·— —·—· —·— / ——— ··— — / ——— —· · / ··· — · ·——· ——··—— / ——— ·—· / —·—· ·—·· ——— ··· ·';
	@override String get enter => '·—·· ——— ——· / — ···· · / —·—· ——— —· — ·— —·—· —';
	@override String get space => '—· · —··— — / ··—· ·· · ·—·· —··';
	@override String get tab => '—· · —··— — / ——— ·—· / ·——· ·—· · ···— ·· ——— ··— ··· / ··—· ·· · ·—·· —··';
	@override String get arrows => '—— ——— ···— · / —··· · — ·—— · · —· / ··—· ·· · ·—·· —·· ··· ——··—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— —· —·· / — ···· · / ·—·· ——— ——·';
	@override String get walk => '·——· ·— ——· · / — ···· ·—· ——— ··— ——· ···· / — ···· · / ·—·· ——— ——· ——··—— / ——— ·—· / ——· ——— / — ——— / ·· — ··· / · —· —·· ···';
	@override String get undo => '— ·— —·— · / —··· ·— —·—· —·— / ·— / ·—— ·· ·——· · / ——— ·—· / ·— / —·· · ·—·· · — ·';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$cw extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => '·— —·· —·· / ··· ···· ——— ·—· — —·—· ··— —';
	@override String get listening => '·——· ·—· · ··· ··· / — ···· · / —·— · —·—— ··· / ··—· ——— ·—· / — ···· · / ··· ···· ——— ·—· — —·—· ··— — …';
	@override String get listeningHint => '· ··· —·—· / ··· — ——— ·——· ··· / ·—·· ·· ··· — · —· ·· —· ——·';
	@override String get add => '·— —·· —··';
	@override String refusedFixed({required Object keys}) => '${keys} / —··· · ·—·· ——— —· ——· ··· / — ——— / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ··—· ·· · ·—·· —·· ··· / ——— ·—· / ·— / —·· ·· ·— ·—·· ——— ——· ——··—— / ·— —· —·· / —·—· ·— —· ’ — / —··· · / —·—· ···· ·— —· ——· · —·· ·—·—·—';
	@override String refusedCallsign({required Object keys}) => '${keys} / ·· ··· / ···· ——— ·—— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· / ·— ·—· · / — —·—— ·——· · —·· ·—·—·— / ···· ——— ·—·· —·· / —·—· —— —·· ——··—— / —·—· — ·—· ·—·· / ——— ·—· / ·— ·—·· — / ·—— ·· — ···· / ·· — ·—·—·—';
	@override String reserved({required Object keys}) => '— ···· · / ··· —·—— ··· — · —— / —— ·— —·—— / — ·— —·— · / ${keys} / —··· · ··—· ——— ·—· · / — ···· · / ·— ·——· ·——· / ··· · · ··· / ·· — ·—·—·—';
	@override String already({required Object keys}) => '${keys} / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ——— —· · / ——— ··—· / — ···· ·· ··· / —·—· ——— —— —— ·— —· —·· ’ ··· / —·— · —·—— ··· ·—·—·—';
	@override String takeIt({required Object keys, required Object command}) => '— ·— —·— · / ${keys} / ··—· ·—· ——— —— / “ ${command} ”';
	@override String get resetDefault => '·—· · ··· · — / — ——— / —·· · ··—· ·— ··— ·—·· —';
	@override String get remove => '·—· · —— ——— ···— ·';
	@override String get commandLabel => '—·—· ——— —— —— ·— —· —··';
	@override String get commandHint => '· —· — · ·—· / ·— —· —·—— / ···— ·— ·—·· ·· —·· / —·—· ——— —— —— ·— —· —·· ——··—— / ——— ·—· / —— ··— ·—·· — ·· ·——· ·—·· · / —·—· ——— —— —— ·— —· —·· ··· / ··· · ·——· ·— ·—· ·— — · —·· / —··· —·—— / ·—··—· —·—·—· ·—··—·';
	@override String get removeCommand => '·—· · —— ——— ···— · / —·—· ——— —— —— ·— —· —··';
	@override String commandUnknown({required Object text}) => '—· ——— / —·—· ——— —— —— ·— —· —·· / ·—· · ·— —·· ··· / “ ${text} ”';
	@override String get noShortcuts => '—· ——— / —·— · —·—— / —·—— · —';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$cw extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => '··· ···· ——— ·—· — —·—· ··— — ··· / ··· ·— ···— · —·· / — ——— / ${location}';
	@override String exportFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / · —··— ·——· ——— ·—· — / — ···· · / ··· ···· ——— ·—· — —·—· ··— — ··· ———··· / ${error}';
	@override String importPickerFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ——— ·——· · —· / — ···· · / ··—· ·· ·—·· · ———··· / ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} / ·· ··· —· ’ — / ·— / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ·· ·—·· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ·—· · ·— —·· ———··· / ${problem}';
	@override String problemNotYaml({required Object line}) => '— ···· · / — · —··— — / ·· ··· —· ’ — / ···— ·— ·—·· ·· —·· / —·—— ·— —— ·—·· / —·——· ·—·· ·· —· · / ${line} —·——·—';
	@override String get problemNotKeysFile => '·· — / ·· ··· —· ’ — / ·— / ···· ·— —— ··——— —·— / —·— · —·—— —··· ——— ·— ·—· —·· / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ·· ·—·· ·';
	@override String get problemNewerVersion => '·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——·';
	@override String get problemMalformed => '·——· ·— ·—· — / ——— ··—· / ·· — / —·· ——— · ··· —· ’ — / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ——— ·—· —— ·— —';
	@override String get problemTooLarge => '·· — / ·· ··· / — ——— ——— / ·—·· ·— ·—· ——· ·';
	@override String get importTitle => '·· —— ·——· ——— ·—· — / ··· ···· ——— ·—· — —·—· ··— — ···';
	@override String writtenOn({required Object platform}) => '·—— ·—· ·· — — · —· / ——— —· / ${platform} ·—·—·—';
	@override String get writtenOnUnknown => '— ···· · / ··—· ·· ·—·· · / —·· ——— · ··· —· ’ — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / —·— · —·—— —··· ——— ·— ·—· —·· / ·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ——— —· ·—·—·—';
	@override String get translate => '·—— ···· ·— — / ··· ···· ——— ··— ·—·· —·· / · ·— —·—· ···· / ——— ··—· / — ···· · ··· · / —·— · —·—— ··· / —··· · / ——— —· / — ···· ·· ··· / —·— · —·—— —··· ——— ·— ·—· —·· ··——··';
	@override String get leaveOut => '·—·· · ·— ···— · / — ···· ——— ··· · / ··· ···· ——— ·—· — —·—· ··— — ··· / ——— ··— —';
	@override String get replace => '·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / —·—· ——— —· ··—· ·· ——·';
	@override String get replaceHint => '· ···— · ·—· —·—— / ··· ···· ——— ·—· — —·—· ··— — / —· ——— — / ·· —· / — ···· · / ··—· ·· ·—·· · / ——· ——— · ··· / —··· ·— —·—· —·— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ·—·—·—';
	@override String get merge => '·— —·· —·· / — ——— / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / —·—· ——— —· ··—· ·· ——·';
	@override String get mergeHint => '— ···· · / ··—· ·· ·—·· · ’ ··· / ··· ···· ——— ·—· — —·—· ··— — ··· / ·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / ··—· ——— ·—· / — ···· · / ··· ·— —— · / —·—· ——— —— —— ·— —· —·· ··· ——··—— / ·— —· —·· / — ···· · / ·—· · ··· — / ··· — ·— —·—— ·—·—·—';
	@override String unknown({required Object commands}) => '—· ——— — / —·— —· ——— ·—— —· / ·· —· / — ···· ·· ··· / ···— · ·—· ··· ·· ——— —· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${commands}';
	@override String unreadableChords({required Object chords}) => '—· ——— — / ··· ···· ——— ·—· — —·—· ··— — ··· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${chords}';
	@override String refusedChords({required Object chords}) => '—·— · —·—— ··· / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ··—· ——— ·—· / ·· — ··· · ·—·· ··—· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${chords}';
	@override String conflicts({required Object keys}) => '—··· ——— ··— —· —·· / — ——— / —— ——— ·—· · / — ···· ·— —· / ——— —· · / —·—· ——— —— —— ·— —· —·· / ·— ··—· — · ·—· / — ···· · / ·· —— ·——· ——— ·—· — ———··· / ${keys}';
	@override String get importAction => '·· —— ·——· ——— ·—· —';
	@override String get imported => '··· ···· ——— ·—· — —·—· ··— — ··· / ·· —— ·——· ——— ·—· — · —··';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$cw extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ / —·—· ——— —— —— ·— —· —··';
	@override String get ctrl => '—·—· — ·—· ·—··';
	@override String get meta => '·—— ·· —· —·· ——— ·—— ··· / —··—· / ··· ··— ·——· · ·—·';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$cw extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get macos => '—— ·— —·—· ——— ···';
	@override String get ios => '·· ·——· ·— —·· ——— ···';
	@override String get windows => '·—— ·· —· —·· ——— ·—— ···';
	@override String get linux => '·—·· ·· —· ··— —··—';
	@override String get android => '·— —· —·· ·—· ——— ·· —··';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$cw extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get callsigns => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···';
	@override String get groupBy => '——· ·—· ——— ··— ·——· / —··· —·——';
	@override String get period => '— ·· —— · / ·——· · ·—· ·· ——— —··';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$cw extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get none => '—· ——— — / ——· ·—· ——— ··— ·——· · —··';
	@override String get date => '—·· ·— — ·';
	@override String get dx => '—·· —··—';
	@override String get unknownContinent => '··— —· —·— —· ——— ·—— —· / —·—· ——— —· — ·· —· · —· —';
	@override String get unknownEntity => '··— —· —·— —· ——— ·—— —· / · —· — ·· — —·——';
	@override String get unknownDate => '—· ——— / —·· ·— — ·';
}

// Path: home.logs.period
class _Translations$home$logs$period$cw extends Translations$home$logs$period$en {
	_Translations$home$logs$period$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => '— ···· ·· ··· / —— ——— —· — ····';
	@override String get last3Months => '·—·· ·— ··· — / ···—— / —— ——— —· — ···· ···';
	@override String get thisYear => '— ···· ·· ··· / —·—— · ·— ·—·';
	@override String get lastYear => '·—·· ·— ··· — / —·—— · ·— ·—·';
	@override String get allTime => '·— ·—·· ·—·· / — ·· —— ·';
	@override String get custom => '—·—· ··— ··· — ——— —— / ·—· ·— —· ——· ·';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$cw extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => '·· —· / ${span}';
	@override String get custom => '—·—· ··— ··· — ——— —— / ·—· ·— —· ——· ·';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$cw extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get date => '—·· ·— — ·';
	@override String get time => '— ·· —— ·';
	@override String get freq => '··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get mode => '—— ——— —·· ·';
	@override String get call => '—·—· ·— ·—·· ·—··';
	@override String get name => '—· ·— —— ·';
	@override String get station => '··· — ·— — ·· ——— —·';
	@override String get band => '—··· ·— —· —··';
	@override String get sent => '··· · —· —';
	@override String get rcvd => '·—· —·—· ···— —··';
	@override String get grid => '——· ·—· ·· —··';
	@override String get state => '··· — ·— — ·';
	@override String get country => '—·—· ——— ··— —· — ·—· —·——';
	@override String get refs => '·—· · ··—· ···';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$cw extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get qsos => '——·— ··· ——— / ·—·· ——— ——·';
	@override String get qsosDescription => '— ···· · / ··· · ·—·· · —·—· — · —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ·————· ··· / ——·— ··· ——— ··· ——··—— / ·— —·—· ·—· ——— ··· ··· / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—';
	@override String get info => '·· —· ··—· ———';
	@override String get infoDescription => '— ——— — ·— ·—·· / ——·— ··· ——— / —·—· ——— ··— —· — ——··—— / ——— ·—· / — ···· · / ··· · ·—·· · —·—· — · —·· / ——·— ··· ——— ·————· ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ·—·—·—';
	@override String get map => '—— ·— ·——·';
	@override String get mapDescription => '— ···· · / ··· · ·—·· · —·—· — · —·· / ——·— ··· ——— ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —· ·—·—·—';
}

// Path: home.logs.import
class _Translations$home$logs$import$cw extends Translations$home$logs$import$en {
	_Translations$home$logs$import$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ———··· / ${calls}';
	@override String get skippedOne => '·———— / ·—· · —·—· ——— ·—· —·· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —··';
	@override String skippedOther({required Object count}) => '${count} / ·—· · —·—· ——— ·—· —·· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —··';
	@override String get readingTitle => '·—· · ·— —·· ·· —· ——· / ·— —·· ·· ··—· / ··—· ·· ·—·· · …';
	@override String get checkingTitle => '—·—· ···· · —·—· —·— ·· —· ——· / ··—· ——— ·—· / —·· ··— ·——· ·—·· ·· —·—· ·— — · ··· …';
	@override String get importingTitle => '·· —— ·——· ——— ·—· — ·· —· ——· / ——·— ··· ——— ··· …';
	@override String readingDetail({required Object kb}) => '${kb} / —·— —···';
	@override String checkingDetail({required Object done, required Object total}) => '${done} / ——— ··—· / ${total} / —·—· ···· · —·—· —·— · —··';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} / ·· —— ·——· ——— ·—· — · —·· ——··—— / ——— ··— — / ——— ··—· / ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$cw extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get defaultName => '—·· · ··—· ·— ··— ·—·· —';
	@override String untitledName({required Object number}) => '·—·· ·— —·—— ——— ··— — / ${number}';
	@override String switcherLabel({required Object name}) => '·—·· ·— —·—— ——— ··— — ———··· / ${name}';
	@override String get menuNew => '—· · ·—— …';
	@override String get menuExport => '· —··— ·——· ——— ·—· — …';
	@override String get menuImport => '·· —— ·——· ——— ·—· — …';
	@override String get menuTitle => '·—·· ·— —·—— ——— ··— — ···';
	@override String get newTitle => '—· · ·—— / ·—·· ·— —·—— ——— ··— —';
	@override String get editTitle => '· —·· ·· — / ·—·· ·— —·—— ——— ··— —';
	@override String get edit => '· —·· ·· —';
	@override String get duplicateCurrent => '—·· ··— ·——· ·—·· ·· —·—· ·— — · / —·—· ··— ·—· ·—· · —· — / ·—·· ·— —·—— ——— ··— —';
	@override String get startFromDefault => '··· — ·— ·—· — / ··—· ·—· ——— —— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·—·· ·— —·—— ——— ··— —';
	@override String get nameLabel => '—· ·— —— ·';
	@override String get descriptionLabel => '—·· · ··· —·—· ·—· ·· ·——· — ·· ——— —·';
	@override String get create => '—·—· ·—· · ·— — ·';
	@override String leaveEditTitle({required Object name}) => '··· ·— ···— · / —·—· ···· ·— —· ——· · ··· / — ——— / ·—··—· ${name} ·—··—· ··——··';
	@override String get leaveEditBody => '— ···· ·· ··· / ·—·· ·— —·—— ——— ··— — / ···· ·— ··· / —·—· ···· ·— —· ——· · ··· / —·—— ——— ··— / ···· ·— ···— · —· ’ — / ··· ·— ···— · —·· ·—·—·—';
	@override String get discard => '—·· ·· ··· —·—· ·— ·—· —··';
	@override String get deleteTitle => '—·· · ·—·· · — · / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— — ··——··';
	@override String deleteBody({required Object name}) => '·— ·—· · / —·—— ——— ··— / ··· ··— ·—· · / —·—— ——— ··— / ·—— ·— —· — / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ·—··—· ${name} ·—··—· / ·—·· ·— —·—— ——— ··— — ··——··';
	@override String get exportTitle => '· —··— ·——· ——— ·—· — / ·—·· ·— —·—— ——— ··— —';
	@override String get exportPick => '·——· ·— —· · ·—·· ··· / — ——— / · —··— ·——· ——— ·—· —';
	@override String get tabSet => '— ·— —··· / ··· · —';
	@override String get exportAction => '· —··— ·——· ——— ·—· —';
	@override String exported({required Object location}) => '·—·· ·— —·—— ——— ··— — / ··· ·— ···— · —·· / — ——— / ${location}';
	@override String exportFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / · —··— ·——· ——— ·—· — / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}';
	@override String get importTitle => '·· —— ·——· ——— ·—· — / ·—·· ·— —·—— ——— ··— —';
	@override String importFromOtherView({required Object view}) => '—— ·— —·· · / ··—· ——— ·—· / — ···· · / ${view} / ···— ·· · ·—— ———··· / ·——· ·— —· · ·—·· ··· / ——— —· ·—·· —·—— / — ···· ·— — / ···— ·· · ·—— / ···· ·— ··· / ·— ·—· · / ·—·· · ··—· — / ——— ··— — ·—·—·—';
	@override String get viewHome => '···· ——— —— ·';
	@override String get viewOperation => '——— ·——· · ·—· ·— — ·· ——— —·';
	@override String get viewLogs => '·—·· ——— ——· ···';
	@override String get viewChase => '—·—· ···· ·— ··· ·· —· ——·';
	@override String get importAsNew => '·— ··· / ·— / —· · ·—— / ·—·· ·— —·—— ——— ··— —';
	@override String get importReplace => '·· —· / ·——· ·—·· ·— —·—· · / ——— ··—· / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —';
	@override String get importAdd => '·— —·· —·· · —·· / — ——— / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —';
	@override String get importAddHint => '— ···· · / ·——· ·— —· · ·—·· ··· / ·— ·—· ·—· ·· ···— · / ·· —· / ·— / —· · ·—— / —·—· ——— ·—·· ··— —— —· / ——— —· / — ···· · / ·—· ·· ——· ···· — ·—·—·—';
	@override String get importPick => '·——· ·— —· · ·—·· ··· / — ——— / ·· —— ·——· ——— ·—· —';
	@override String get importReplaceSettings => '·—· · ·——· ·—·· ·— —·—· · / — ···· · / ··· · — — ·· —· ——· ··· / ——— ··—· / ·——· ·— —· · ·—·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ··· · — / ··— ·——· / ···· · ·—· ·';
	@override String get importAction => '·· —— ·——· ——— ·—· —';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} / ·· ··· —· ·————· — / ·— / ·—·· ·— —·—— ——— ··— — / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ·—· · ·— —·· ———··· / ${problem}';
	@override String problemNotYaml({required Object line}) => '— ···· · / — · —··— — / ·· ··· —· ’ — / ···— ·— ·—·· ·· —·· / —·—— ·— —— ·—·· / —·——· ·—·· ·· —· · / ${line} —·——·—';
	@override String get problemNotLayoutFile => '·· — / ·· ··· —· ’ — / ·— / ···· ·— —— ··——— —·— / ·—·· ·— —·—— ——— ··— — / ··—· ·· ·—·· ·';
	@override String get problemNewerVersion => '·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——·';
	@override String get problemNoArrangement => '·· — / ···· ——— ·—·· —·· ··· / —· ——— / ·— ·—· ·—· ·— —· ——· · —— · —· —';
	@override String get problemMalformed => '·——· ·— ·—· — / ——— ··—· / ·· — / —·· ——— · ··· —· ’ — / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· —— ·— —';
	@override String get problemTooLarge => '·· — / ·· ··· / — ——— ——— / ·—·· ·— ·—· ——· ·';
	@override String importPickerFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ——— ·——· · —· / — ···· · / ··—· ·· ·—·· · ———··· / ${error}';
	@override String importFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·· —— ·——· ——— ·—· — / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}';
	@override String duplicateFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}';
	@override String get importNothing => '—· ——— / ·——· ·— —· · ·—·· / ·——· ·· —·—· —·— · —·· ——··—— / ··· ——— / —· ——— — ···· ·· —· ——· / ·—— ·— ··· / ·· —— ·——· ——— ·—· — · —·· ·—·—·—';
	@override String importSkipped({required Object panels}) => '·—·· · ··—· — / ——— ··— — ———··· / ${panels}';
	@override String importKeptPinned({required Object panels}) => '—·— · ·——· — / ${panels} ———··· / — ···· · / ··· —— ·— ·—·· ·—·· —····— ··· —·—· ·—· · · —· / ·— ·—· ·—· ·— —· ——· · —— · —· — / —·—· ·— —· ’ — / —·· ——— / ·—— ·· — ···· ——— ··— — / ·· — ·—·—·—';
	@override String get notOffered => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· ·· ··· / ···— ·· · ·——';
	@override String get alreadyPlaced => '·— ·—·· ·—· · ·— —·· —·—— / ·· —· / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —';
	@override String needsExtension({required Object name}) => '—· · · —·· ··· / ${name}';
	@override String get listRecoveredTitle => '·—·· ·— —·—— ——— ··— — / —· ·— —— · ··· / —·—· ——— ··— ·—·· —·· —· ’ — / —··· · / ·—· · ·— —··';
	@override String get listRecoveredBody => '— ···· ·· ··· / ···— ·· · ·—— ’ ··· / ·—·· ·· ··· — / ——— ··—· / ·—·· ·— —·—— ——— ··— — ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ·—·—·— / · ···— · ·—· —·—— / ·—·· ·— —·—— ——— ··— — / ·· ··· / ··· — ·· ·—·· ·—·· / ···· · ·—· · ——··—— / —· ··— —— —··· · ·—· · —·· / ·· —· / ·——· ·—·· ·— —·—· · / ——— ··—· / ·· — ··· / —· ·— —— · ·—·—·—';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$cw extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => '— ···· · / ·—·· ——— ——· / ·— —· —·· / — ···· · / · —· — ·—· —·—— / ··—· ·· · ·—·· —·· ···';
	@override String get infoDescription => '·—— ···· ·— — / ·—— · / —·— —· ——— ·—— / ·— —··· ——— ··— — / — ···· · / ··· — ·— — ·· ——— —· / —··· · ·· —· ——· / ·—— ——— ·—· —·— · —··';
	@override String get spotsDescription => '··· ·——· ——— — ··· / ··—· ·—· ——— —— / — ···· · / —·—· ·—·· ··— ··· — · ·—· ··· / ·— —· —·· / ·— —·—· — ·· ···— ·· — —·—— / ·——· ·—· ——— ——· ·—· ·— —— ···';
	@override String get mapDescription => '·—— ···· · ·—· · / — ···· · / —·—· ——— —· — ·— —·—· — ··· / ·— ·—· ·';
	@override String get summariesDescription => '— ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ··· — ·— — ··· / ·— —· —·· / ··· —·—· ——— ·—· · ··· ——··—— / ·· —· / — ···· · / ··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—· / —·—— ——— ··— / ·——· ·· —·—· —·—';
	@override String get summariesSections => '··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—·';
	@override String get summariesDays => '· ·— —·—· ···· / —·· ·— —·——';
	@override String get summariesReset => '··· ···· ——— ·—— / ·— ·—·· ·—··';
	@override String get summariesAllHidden => '· ···— · ·—· —·—— / ··· · —·—· — ·· ——— —· / ·· ··· / ···· ·· —·· —·· · —· ·—·—·— / ·——· ·· —·—· —·— / — ···· · / ——— —· · ··· / — ——— / ··· ···· ——— ·—— / ·· —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· ·—·—·—';
	@override String get clockDescription => '·— / —·—· ·—·· ——— —·—· —·— / ··—· ·— —·—· · ——··—— / ·· —· / ·— —· —·—— / — ·· —— · / ——·· ——— —· ·';
	@override String get clockFace => '··—· ·— —·—· ·';
	@override String get clockFaceLcd => '·—·· —·—· —··';
	@override String get clockFaceAnalog => '·— —· ·— ·—·· ——— ——·';
	@override String get clockZone => '— ·· —— · / ——·· ——— —· ·';
	@override String get clockZoneUtc => '··— — —·—·';
	@override String get clockZoneDevice => '— ···· ·· ··· / —·· · ···— ·· —·—· ·';
	@override String get clockShowSeconds => '··· ···· ——— ·—— / ··· · —·—· ——— —· —·· ···';
	@override String get weatherDescription => '—·—· ——— —· —·· ·· — ·· ——— —· ··· / —· ——— ·—— / ·— —· —·· / ··—· ——— ·—· / — ···· · / —· · —··— — / · ·· ——· ···· — / ···· ——— ··— ·—· ··· ——··—— / ·—— ···· · ·—· · / —·—— ——— ··— ·————· ·—· · / ——— ·——· · ·—· ·— — ·· —· ——·';
	@override String get weatherUseOperationLocation => '··— ··· · / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —·';
	@override String get weatherLocation => '·—·· ——— —·—· ·— — ·· ——— —·';
	@override String get weatherLocationDescription => '·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / —·——· ··—· —· ···—— ·———— ·——· ·—· —·——·— / ——— ·—· / ·—·· ·— — ——··—— ·—·· ——— —· ·—·—·— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·————· ··— ··· · / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —· ·————· / ·· ··· / —·—· ···· · —·—· —·— · —·· ·—·—·—';
	@override String get weatherNoLocation => '—· ——— / ·—·· ——— —·—· ·— — ·· ——— —· / ··· · — ·—·—·— / ——· ·· ···— · / — ···· ·· ··· / ·——· ·— —· · ·—·· / ·— / ·—·· ——— —·—· ·— — ·· ——— —· / ·· —· / ·· — ··· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ·——· ·—·· ·— —·—· · / ·· — / ·· —· ··· ·· —·· · / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / — ···· ·— — / ···· ·— ··· / ——— —· · ·—·—·—';
	@override String weatherBadLocation({required Object location}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·· / — ···· · / ·—·· ——— —·—· ·— — ·· ——— —· / ${location} ·—·—·— / ··— ··· · / ·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / ·—·· ·· —·— · / ··—· —· ···—— ·———— ·——· ·—· ——··—— / ——— ·—· / ····— ··——— ·—·—·— ···—— —···· ——··—— —····— ——··· ·———— ·—·—·— ————— —···· ·—·—·—';
	@override String get weatherUnreachable => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / ——— ·——· · —· —····— —— · — · ——— / — / —· ——— / —· · — ·—— ——— ·—· —·— ··——·· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—';
	@override String get weatherUnreadable => '——— ·——· · —· —····— —— · — · ——— / ·—· · ··· ·——· ——— —· —·· · —·· ——··—— / —··· ··— — / —· ——— — / ·—— ·· — ···· / ·— —· —·—— — ···· ·· —· ——· / ·—· · ·— —·· ·— —··· ·—·· · ·—·—·— / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—';
	@override String weatherGusts({required Object speed}) => '——· ··— ··· — ··· / ${speed}';
	@override String get panelAgeNow => '·——— ··— ··· — / —· ——— ·——';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / —— ·· —· / ·— ——· ———',
		other: '${count} / —— ·· —· / ·— ——· ———',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '${count} / ···· ·—· / ·— ——· ———',
		other: '${count} / ···· ·—· ··· / ·— ——· ———',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$cw weatherConditions = _Translations$operation$layout$panels$weatherConditions$cw._(_root);
	@override String get websiteDescription => '·— / ·—— · —··· / ·——· ·— ——· · / ——— ··—· / —·—— ——— ··— ·—· / —·—· ···· ——— ——— ··· ·· —· ——· ——··—— / ·· —· / ·— / ·——· ·— —· ·';
	@override String get websiteUrl => '·— —·· —·· ·—· · ··· ···';
	@override String get websiteRefresh => '·—· · ··—· ·—· · ··· ····';
	@override String get websiteRefreshNever => '—· · ···— · ·—·';
	@override String get websiteRefresh1 => '· ···— · ·—· —·—— / —— ·· —· ··— — ·';
	@override String get websiteRefresh5 => '· ···— · ·—· —·—— / ····· / —— ·· —· ··— — · ···';
	@override String get websiteRefresh15 => '· ···— · ·—· —·—— / ·———— ····· / —— ·· —· ··— — · ···';
	@override String get websiteTitle => '·——· ·— —· · ·—·· / —· ·— —— ·';
	@override String get websiteRefreshNow => '·—· · ··—· ·—· · ··· ···· / —· ——— ·——';
	@override String get websiteNoUrl => '—· ——— / ·— —·· —·· ·—· · ··· ··· / —·—— · — ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ’ ··· / ··· · — — ·· —· ——· ··· / — ——— / —·—· ···· ——— ——— ··· · / ·— / ·——· ·— ——· · ·—·—·—';
	@override String get websiteBadUrl => '— ···· ·— — / —·· ——— · ··· —· ’ — / ·—·· ——— ——— —·— / ·—·· ·· —·— · / ·— / ·—— · —··· / ·— —·· —·· ·—· · ··· ··· ·—·—·— / ·· — / —· · · —·· ··· / — ——— / ··· — ·— ·—· — / ·—— ·· — ···· / ···· — — ·——· ··· ———··· —··—· —··—·';
	@override String get websiteNotHttps => '——— —· ·—·· —·—— / ···· — — ·——· ··· ———··· —··—· —··—· / ·— —·· —·· ·—· · ··· ··· · ··· / —·—· ·— —· / —··· · / ··· ···· ——— ·—— —· / ···· · ·—· · ·—·—·—';
	@override String get websiteUnsupported => '·—— · —··· / ·——· ·— ——· · ··· / —·—· ·— —· ’ — / —··· · / ··· ···· ——— ·—— —· / ·· —· / ·— / ·——· ·— —· · ·—·· / ——— —· / — ···· ·· ··· / ··· —·—— ··· — · —— ·—·—·—';
	@override String get websiteOpenExternally => '——— ·——· · —· / ·· —· / —··· ·—· ——— ·—— ··· · ·—·';
	@override String websiteLoadFailed({required Object reason}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ·—·· ——— ·— —·· / — ···· · / ·——· ·— ——· · ———··· / ${reason}';
	@override String get remoteScreenDescription => '·— / ··· —·—· ·—· · · —· ——··—— / ·— ·——· ·——· / ——— ·—· / ·—— ·· —· —·· ——— ·—— / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· / ——— ··—· / —·—— ——— ··— ·—· / —·· · ···— ·· —·—· · ··· ·—·—·—';
	@override String get remoteScreenTarget => '··· —·—· ·—· · · —·';
	@override String get remoteScreenChoose => '—·—· ···· ——— ——— ··· · / ·— / ··· —·—· ·—· · · —· …';
	@override String get remoteScreenPickerTitle => '··· ···· ·— ·—· · —·· / ··· —·—· ·—· · · —· ···';
	@override String get remoteScreenPickerEmpty => '—· ——— —· · / ——— ··—· / —·—— ——— ··— ·—· / —·· · ···— ·· —·—· · ··· / ·· ··· / ··· ···· ·— ·—· ·· —· ——· / ·— / ··· —·—· ·—· · · —· ·—·—·— / — ··— ·—· —· / ··· ···· ·— ·—· · / ··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ··· / ——— —· / ··— —· —·· · ·—· / ··· · — — ·· —· ——· ··· / → / ·——· · · ·—· / —·· · ···— ·· —·—· · ··· ——··—— / ——— —· / — ···· · / —·· · ···— ·· —·—· · / —·—— ——— ··— / ·—— ·— —· — / — ——— / ··· · · ·—·—·—';
	@override String get remoteScreenUnset => '—· ——— / ··· —·—· ·—· · · —· / —·—· ···· ——— ··· · —· ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· / — ——— / ·——· ·· —·—· —·— / ——— —· · / —·—— ——— ··— ·—· / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / ·— ·—· · / ··· ···· ·— ·—· ·· —· ——· ·—·—·—';
	@override String get remoteScreenConnecting => '—·—· ——— —· —· · —·—· — ·· —· ——· …';
	@override String get remoteScreenPeerAway => '— ···· ·— — / —·· · ···— ·· —·—· · / ·· ··· —· ·————· — / —·—· ——— —· —· · —·—· — · —·· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—';
	@override String get remoteScreenNotOffered => '— ···· ·— — / —·· · ···— ·· —·—· · / ··· — ——— ·——· ·——· · —·· / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ··· —·—· ·—· · · —· ·—·—·—';
	@override String get remoteScreenNoListener => '— ···· ·— — / —·· · ···— ·· —·—· · / —·—· ·— —· ·————· — / ·— —·—· —·—· · ·——· — / —·—· ——— —· —· · —·—· — ·· ——— —· ··· / — / —·—· ···· · —·—· —·— / ·· — ··· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· ·—·—·—';
	@override String get remoteScreenNoLan => '··· —·—· ·—· · · —· ··· / ·— ·—· · / ——— —· ·—·· —·—— / ··· ···· ·— ·—· · —·· / ——— ···— · ·—· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ——··—— / —· ——— — / —··· ·—·· ··— · — ——— ——— — ···· ·—·—·—';
	@override String get remoteScreenRefused => '— ···· ·— — / —·· · ···— ·· —·—· · / ·—— ——— ··— ·—·· —·· —· ·————· — / ··· ···· ·— ·—· · / — ···· ·· ··· / ··· —·—· ·—· · · —· ·—·—·—';
	@override String get remoteScreenSettings => '·——· ·— —· · ·—·· / ··· · — — ·· —· ——· ···';
	@override String get remoteScreenAdjust => '·— —·· ·——— ··— ··· — / ···— ·· · ·——';
	@override String get remoteScreenDetail => '—·· · — ·— ·· ·—··';
	@override String get remoteScreenDetailStandard => '··· — ·— —· —·· ·— ·—· —··';
	@override String get remoteScreenDetailHigh => '···· ·· ——· ····';
	@override String get remoteScreenDetailMaximum => '—— ·— —··— ·· —— ··— ——';
	@override String get remoteScreenAdjustDone => '——— —·—';
	@override String get remoteScreenZoomIn => '——·· ——— ——— —— / ·· —·';
	@override String get remoteScreenZoomOut => '——·· ——— ——— —— / ——— ··— —';
	@override String get remoteScreenStopped => '— ···· ·— — / ··· —·—· ·—· · · —· / ——— ·—· / ·—— ·· —· —·· ——— ·—— / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / —··· · ·· —· ——· / ··· ···· ——— ·—— —· ·—·—·—';
	@override String get remoteScreenCaptureFailed => '— ···· ·— — / —·· · ···— ·· —·—· · / —·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ·— ·——· — ··— ·—· · / — ···· ·— — / ··· —·—· ·—· · · —· / — / ·· — / —— ·— —·—— / —· · · —·· / ··· —·—· ·—· · · —· / ·—· · —·—· ——— ·—· —·· ·· —· ——· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· ·—·—·—';
	@override String get remoteScreenNoAnswer => '— ···· ·— — / —·· · ···— ·· —·—· · / —·· ·· —·· —· ·————· — / ·—· · ··· ·——· ——— —· —·· ·—·—·— / ·· — / —— ·— —·—— / —· ——— — / ···· ·— ···— · / ··· —·—· ·—· · · —· / ··· ···· ·— ·—· ·· —· ——· / — ··— ·—· —· · —·· / ——— —· ·—·—·—';
	@override String get remoteScreenNoMedia => '—·—· ——— ··— ·—·· —·· —· ·————· — / ——— ·——· · —· / ·— / —·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ——— ·—· / — ···· · / ·——· ·· —·—· — ··— ·—· · ·—·—·— / —·—· ···· · —·—· —·— / — ···· · / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·—';
	@override String get solarDescription => '··· ——— ·—·· ·— ·—· / ·— —· —·· / ——· · ——— —— ·— ——· —· · — ·· —·—· / —·—· ——— —· —·· ·· — ·· ——— —· ··· ——··—— / ·—— ·· — ···· / —··· ·— —· —·· —····— —··· —·—— —····— —··· ·— —· —·· / ·——· ·—· ——— ·——· ·— ——· ·— — ·· ——— —·';
	@override String get solarUnreachable => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / ···· ·— —— ——·— ··· ·—·· ·—·—·— —·—· ——— —— / — / —· ——— / —· · — ·—— ——— ·—· —·— ··——·· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—';
	@override String get solarUnreadable => '···· ·— —— ——·— ··· ·—·· ·—·—·— —·—· ——— —— / ·—· · ··· ·——· ——— —· —·· · —·· ——··—— / —··· ··— — / —· ——— — / ·—— ·· — ···· / ·— / ·—· · ·— —·· ·· —· ——· / ·—— · / —·—· ——— ··— ·—·· —·· / ··— ··· · ·—·—·— / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—';
	@override String get solarAIndex => '·—';
	@override String get solarKIndex => '—·— ·——·';
	@override String get solarBandDay => '—·· ·— —·——';
	@override String get solarBandNight => '—· ·· ——· ···· —';
	@override String get solarBandGood => '——· ——— ——— —··';
	@override String get solarBandFair => '··—· ·— ·· ·—·';
	@override String get solarBandPoor => '·——· ——— ——— ·—·';
	@override String solarSources({required Object primary, required Object secondary}) => '··· ——— ··— ·—· —·—· · ··· ———··· / ${primary} ——··—— / ${secondary}';
	@override String get remoteScreenDegraded => '— ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ·· ··· / ··· — ·—· ··— ——· ——· ·—·· ·· —· ——· / — / ··· —·— ·· ·——· ·——· ·· —· ——· / ··—· ·—· ·— —— · ··· ·—·—·—';
	@override String get remoteScreenStalled => '··—· ·—· ·— —— · ··· / ··· — ——— ·——· ·——· · —·· / ——· · — — ·· —· ——· / — ···· ·—· ——— ··— ——· ···· / — / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —— ·— —·—— / —··· · / — ——— ——— / ··· ·—·· ——— ·—— ·—·—·—';
	@override String get radioDescription => '·— / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·—· ——— —· — / ·——· ·— —· · ·—·· / — / ··—· ·—· · ——·— ··— · —· —·—· —·—— ——··—— / —— ——— —·· · / ·— —· —·· / ·——· ——— ·—— · ·—· ——··—— / ··— —· —·· · ·—· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—··';
	@override String get radioStyle => '··· — —·—— ·—·· ·';
	@override String get radioStyleLcd => '·—·· —·—· —··';
	@override String get radioStyleModern => '—— ——— —·· · ·—· —·';
	@override String get radioRadio => '·—· ·— —·· ·· ———';
	@override String radioAutoNamed({required Object name}) => '···— ··—· ——— / ·— / — / ${name}';
	@override String get radioAutoNone => '···— ··—· ——— / ·— / — / —· ——— / ·—· ·— —·· ·· ——— / —·· · ··· ·· ——· —· ·— — · —··';
	@override String get radioNoRadio => '—· ——— / ·—· ·— —·· ·· ——— / — ——— / ··· ···· ——— ·—— ·—·—·— / ·——· ·· —·—· —·— / ——— —· · / ·· —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ·— —·· —·· / ——— —· · / ··— —· —·· · ·—· / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ·—·—·—';
	@override String get radioNotConfigured => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / —· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / —·—— · — ·—·—·— / —·—· ···· ——— ——— ··· · / ·· — ··· / ·——· ——— ·—· — / ——— ·—· / ·— —·· —·· ·—· · ··· ··· / ··— —· —·· · ·—· / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ·—·—·—';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => '·—· ·— —·· ·· ——— / —· ——— — / —·—· ——— —· —· · —·—· — · —··';
	@override String get radioWatts => '·——';
	@override String get radioConnect => '—·—· ——— —· —· · —·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———';
	@override String get radioDisconnect => '—·· ·· ··· —·—· ——— —· —· · —·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———';
	@override String get radioStale => '—· ——— / —·· ·— — ·—';
	@override String get radioTransmitting => '— —··—';
	@override String get radioSwr => '··· ·—— ·—·';
	@override String get radioAlc => '·— ·—·· —·—·';
	@override String get radioVolts => '···—';
	@override String get radioSwrHigh => '···· ·· ——· ···· / ··· ·—— ·—·';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$cw extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··— ··· · / —·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · / —· ·— —— · ···';
	@override String get descriptionOn => '··· ···· ——— ·—· — / —· ·— —— · ··· / —··· ··— ·· ·—·· — / ··—· ——— ·—· / ··— ·——· ·—·· ——— ·— —·· · ·—· ··· ——··—— / ·—·· ·· —·— · / —· ————— —·—· ·— ·—·· ·—·· ·——·—· ··— ··· —····— ·———— ··——— ···—— ····— —····— ··——— ————— ··——— —···· ————— ——··· ··——— ——··· ·—·—·— ·— —·· ··';
	@override String get descriptionOff => '·—· · ·— —·· ·— —··· ·—·· · / —· ·— —— · ··· ——··—— / ·—·· ·· —·— · / ··——— ————— ··——— —···· —····— ————— ——··· —····— ··——— ——··· / —· ————— —·—· ·— ·—·· ·—·· / ·— — / ··— ··· —····— ·———— ··——— ···—— ····— ·—·—·— ·— —·· ··';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$cw extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·· —· —·—· ·—·· ··— —·· · / ·——· ·—· ·· ···— ·— — · / ·· —· ··—· ———';
	@override String get descriptionOn => '—· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / ——· ·—· ·· —·· ··· ——·— ··— ·— ·—· · ··· / ·— —· —·· / —· ——— — · ··· / ·— ·—· · / ·· —· —·—· ·—·· ··— —·· · —··';
	@override String get descriptionOff => '—· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / ——· ·—· ·· —·· ··· ——·— ··— ·— ·—· · ··· / ·— —· —·· / —· ——— — · ··· / ·— ·—· · / ·—·· · ··—· — / ——— ··— —';
	@override String get note => '— ···· · / ··—· ··— ·—·· ·—·· / ·— —·· ·· ··—· / · —··— ·——· ——— ·—· — / ·— ·—·· ·—— ·— —·—— ··· / ·· —· —·—· ·—·· ··— —·· · ··· / · ···— · ·—· —·—— — ···· ·· —· ——·';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$cw extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => '·— —·· —·· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ··—· ·· ·—· ··· —';
	@override String get needsEmailBody => '···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / ··· · —· —·· ··· / —·—— ——— ··— ·—· / ··—· ·· ·—·· · ··· / — ——— / — ···· · / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— ··—· ·· / ·— —·—· —·—· ——— ··— —· — ——··—— / ·— —· —·· / —·—— ——— ··— / ··· ·· ——· —· / ·· —· / ·—— ·· — ···· / ·· — / ·— — / ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ·—·—·— / —·—— ——— ··— ·—· / ·— —·—· —·—· ——— ··— —· — / —·· ——— · ··· —· ’ — / ···· ·— ···— · / ·— / —·—· ——— —· ··—· ·· ·—· —— · —·· / ——— —· · / —·—— · — / — / ·— —·· —·· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / —·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—· ·—·—·—';
	@override String get openSyncSettings => '——— ·——· · —· / —·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—·';
	@override String get replaceTitle => '·—· · —·—· · —· — / ··· — ·— ··· ···· / ·—— ·· ·—·· ·—·· / —··· · / ·—· · ·——· ·—·· ·— —·—· · —··';
	@override String replaceBody({required Object name}) => '—·—— ——— ··— / ··· · —· — / “ ${name} ” / ·—·· · ··· ··· / — ···· ·— —· / —···· / ···· ——— ··— ·—· ··· / ·— ——· ——— / ·— —· —·· / ·· — / ···· ·— ··· —· ’ — / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / —·—— · — ·—·—·— / ··—· ·—· · · / ·— —·—· —·—· ——— ··— —· — ··· / —·— · · ·——· / ——— —· · / ··· — ·— ··· ···· / ·— — / ·— / — ·· —— · ——··—— / ··· ——— / ··· · —· —·· ·· —· ——· / —· ——— ·—— / ·—· · ·——· ·—·· ·— —·—· · ··· / ·· — ·—·—·—';
	@override String get replaceConfirm => '··· · —· —·· / ·— —· —·—— ·—— ·— —·——';
	@override String get failedTitle => '—·—· ——— ··— ·—·· —·· —· ’ — / ··· · —· —·· / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ····';
	@override String get sentTitle => '··· · —· — / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ····';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '—·—— ——— ··— / —·—· ·— —· / ·—· · — ·—· ·· · ···— · / — ···· ·· ··· / ··—· ·· ·—·· · / —··· —·—— / ···— ·· ··· ·· — ·· —· ——· / ** [ ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ](https://stash.ham2k.net) ** / ——— —· / ·— —· —·—— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—',
		other: '—·—— ——— ··— / —·—· ·— —· / ·—· · — ·—· ·· · ···— · / — ···· · ··· · / ··—· ·· ·—·· · ··· / —··· —·—— / ···— ·· ··· ·· — ·· —· ——· / ** [ ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ](https://stash.ham2k.net) ** / ——— —· / ·— —· —·—— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—',
	);
	@override String get mayHaveArrived => '—· ——— / ·— —· ··· ·—— · ·—· / ··—· ·—· ——— —— / — ···· · / ··· — ·— ··· ···· / — / — ···· · / ··—· ·· ·—·· · / —— ·— —·—— / ···· ·— ···— · / ·— ·—· ·—· ·· ···— · —·· / ·— —· —·—— ·—— ·— —·—— ·—·—·— / —·—· ···· · —·—· —·— / ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — / —··· · ··—· ——— ·—· · / ··· · —· —·· ·· —· ——· / ·— ——· ·— ·· —·';
	@override String get notSent => '—· ——— — / ··· · —· —';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '— ···· ·· ··· / ··—· ·· ·—·· · / —·· ·· —·· —· ’ — / ·— ·—· ·—· ·· ···— · ———···',
		other: '— ···· · ··· · / ${count} / ··—· ·· ·—·· · ··· / —·· ·· —·· —· ’ — / ·— ·—· ·—· ·· ···— · ———···',
	);
	@override String get emailOffer => '——— ·—· / ··—· ——— ·—· / —·—— ——— ··— ·—· / —·—· ——— —· ···— · —· ·· · —· —·—· · ——··—— / ·—— · / —·—· ·— —· / ··· · —· —·· / —·—— ——— ··— / ·— —· / · —— ·— ·· ·—·· / ·—— ·· — ···· / ·— / —·· ·· ·—· · —·—· — / ·—·· ·· —· —·— ·—·—·—';
	@override String get emailMe => '· —— ·— ·· ·—·· / —— · / ·— / ·—·· ·· —· —·—';
	@override String get emailSent => '·—— · ’ ···— · / · —— ·— ·· ·—·· · —·· / —·—— ——— ··— / ·— / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·—·· ·· —· —·— ·—·—·—';
	@override String emailFailed({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ··· · —· —·· / — ···· · / · —— ·— ·· ·—·· ———··· / ${error}';
	@override String get freeTier => '··—· ·—· · · / ·— —·—· —·—· ——— ··— —· — ··· / —·—· ·— —· / ——— —· ·—·· —·—— / —·— · · ·——· / ——— —· · / ··· — ·— ··· ···· / ·— — / ·— / — ·· —— · ·—·—·— / ··· ··— —··· ··· —·—· ·—· ·· —··· · ·—· ··· / —·—· ·— —· / —·— · · ·——· / ·— ··· / —— ·— —· —·—— / ·— ··· / — ···· · —·—— / ·—— ·— —· — ·—·—·—';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count,
		one: '··· · —· — / ${count} / ··—· ·· ·—·· · / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·——· ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — —·——·—',
		other: '··· · —· — / ${count} / ··—· ·· ·—·· · ··· / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·——· ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — —·——·—',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$cw extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get af => '·— ··—· ·—· ·· —·—· ·—';
	@override String get as => '·— ··· ·· ·—';
	@override String get eu => '· ··— ·—· ——— ·——· ·';
	@override String get na => '—· ——— ·—· — ···· / ·— —— · ·—· ·· —·—· ·—';
	@override String get oc => '——— —·—· · ·— —· ·· ·—';
	@override String get sa => '··· ——— ··— — ···· / ·— —— · ·—· ·· —·—· ·—';
	@override String get an => '·— —· — ·— ·—· —·—· — ·· —·—· ·—';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$cw extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··—· ·· ·—·· — · ·—· / ··· ·——· ——— — ···';
	@override String get band => '—··· ·— —· —··';
	@override String get mode => '—— ——— —·· ·';
	@override String get age => '·— ——· ·';
	@override String get sources => '··· ——— ··— ·—· —·—· · ···';
	@override String get continent => '—·—· ——— —· — ·· —· · —· —';
	@override String get sorting => '··· ——— ·—· — ·· —· ——·';
	@override String get sortByTime => '—··· —·—— / ··· ·——· ——— — / — ·· —— ·';
	@override String get sortByFrequency => '—··· —·—— / ··—· ·—· · ——·— ··— · —· —·—· —·——';
	@override String get sortByWanted => '—— ——— ··· — / ·—— ·— —· — · —··';
	@override String get groupByBand => '——· ·—· ——— ··— ·——· / —··· —·—— / —··· ·— —· —··';
	@override String get groupCallsWithNotes => '——· ·—· ——— ··— ·——· / —·—· ·— ·—·· ·—·· ··· / ·—— ·· — ···· / —· ——— — · ···';
	@override String get alertingOnly => '——— —· ·—·· —·—— / ··· ·——· ——— — ··· / ·—— ·· — ···· / ·— ·—·· · ·—· — ···';
	@override String get sourceNoReply => '—· ——— / ·—· · ·——· ·—·· —·——';
	@override String get sourceError => '· ·—· ·—· ——— ·—·';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$cw extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·—·· ——— ——· ——· ·· —· ——· / ·——· ·— —· · ·—·· / ·· ··· / —··· ··— ··· —·——';
	@override String get editingBody => '—·—— ——— ··— ·————· ·—· · / · —·· ·· — ·· —· ——· / ·— / ·—·· ——— ——· ——· · —·· / —·—· ——— —· — ·— —·—· — ·—·—·— / ·—·· ——— ——· / — ···· ·· ··· / ··· ·——· ——— — / ·· —· ··· — · ·— —·· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ··—· ·· —· ·· ··· ···· / — ···· · / · —·· ·· — ··——··';
	@override String get composingBody => '—·—— ——— ··— ·————· ···— · / ··· — ·— ·—· — · —·· / · —· — · ·—· ·· —· ——· / ·— / —·—· ——— —· — ·— —·—· — ·—·—·— / ·—·· ——— ——· / — ···· ·· ··· / ··· ·——· ——— — / ·· —· ··· — · ·— —·· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ··—· ·· —· ·· ··· ···· / ·—— ···· ·— — / —·—— ——— ··— / ·—— · ·—· · / — —·—— ·——· ·· —· ——· ··——··';
	@override String get goBack => '——· ——— / —··· ·— —·—· —·—';
	@override String get clearAndLog => '—·—· ·—·· · ·— ·—· / ·— —· —·· / ·—·· ——— ——· / ··· ·——· ——— —';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$cw extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·—·· · ··—· — ·· · / —— ——— —·· ·';
	@override String get descriptionOn => '··— ··· ·· —· ——· / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· / ·—·· · ··—· — —····— ···· ·— —· —·· · —·· / ··— ··· · ·—· ···';
	@override String get descriptionOff => '··— ··· ·· —· ——· / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· / ·—· ·· ——· ···· — —····— ···· ·— —· —·· · —·· / ··— ··· · ·—· ···';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$cw extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ——— ··— —· — ·—· —·—— / ··—· ·—·· ·— ——· ···';
	@override String get dx => '··· ···· ——— ·—— / ——— —· ·—·· —·—— / ··—· ——— ·—· / —·· —··— / —·—· ——— —· — ·— —·—· — ···';
	@override String get all => '··· ···· ——— ·—— / ··—· ·—·· ·— ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / —·—· ——— —· — ·— —·—· — ···';
	@override String get none => '—·· ——— —· ·————· — / ··· ···· ——— ·—— / ·— —· —·—— / ··—· ·—·· ·— ——· ···';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$cw extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get dx => '··· ···· ——— ·—— ·· —· ——· / ··—· ·—·· ·— ——· ··· / ——— —· ·—·· —·—— / ··—· ——— ·—· / —·· —··— / —·—· ——— —· — ·— —·—· — ···';
	@override String get all => '··· ···· ——— ·—— ·· —· ——· / ··—· ·—·· ·— ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / —·—· ——— —· — ·— —·—· — ···';
	@override String get none => '—· ——— — / ··· ···· ——— ·—— ·· —· ——· / ·— —· —·—— / ··—· ·—·· ·— ——· ···';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$cw extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ··— ——· ——· · ··· — / ——— ·——· · ·—· ·— — ——— ·—·';
	@override String get descriptionOn => '——— ··—· ··—· · ·—· ·· —· ——· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ·—— ···· · —· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ·—· ··— —· ··· / ··— —· —·· · ·—· / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get descriptionOff => '·—·· · ·— ···— ·· —· ——· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / —··· ·—·· ·— —· —·— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··—· ·· ·—·· ·—·· / ·· — / ·· —·';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$cw extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ···· ——— ·—— / —··· · ·— ·—· ·· —· ——·';
	@override String get descriptionOn => '··· ···· ——— ·—— ·· —· ——· / · ··· — ·· —— ·— — · —·· / —··· · ·— ·—· ·· —· ——· / — ——— / ··· — ·— — ·· ——— —·';
	@override String get descriptionOff => '—· ——— — / ··· ···· ——— ·—— ·· —· ——· / —··· · ·— ·—· ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$cw extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— ·—·· ··· ——— / ··· ···· ——— ·—— / ·—· · ···— · ·—· ··· · / —··· · ·— ·—· ·· —· ——·';
	@override String get descriptionOn => '··· ···· ——— ·—— ·· —· ——· / — ···· · / —··· · ·— ·—· ·· —· ——· / ··—· ·—· ——— —— / — ···· · / ··· — ·— — ·· ——— —· / — ——— ——— ——··—— / ·— ··· / ·—··—· ····— ····· ° / —··—· / ··——— ··——— ····· ° ·—··—·';
	@override String get descriptionOff => '——— —· ·—·· —·—— / ··· ···· ——— ·—— ·· —· ——· / — ···· · / —··· · ·— ·—· ·· —· ——· / — ——— / — ···· · / ··· — ·— — ·· ——— —·';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$cw extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ·—— ·· — —·—· ···· / ··· ·· ——· —· ·— ·—·· / ·—· · ·——· ——— ·—· — / ——— ·—· —·· · ·—·';
	@override String get sentFirst => '··· · —· — / ··—· ·· ·—· ··· — ——··—— / ·—· —·—· ···— —·· / ··· · —·—· ——— —· —··';
	@override String get rcvdFirst => '·—· —·—· ···— —·· / ··—· ·· ·—· ··· — ——··—— / ··· · —· — / ··· · —·—· ——— —· —··';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$cw extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·——— ··— —— ·——· / — ——— / —· · —··— — / ··—· ·· · ·—·· —·· / ——— —· / ·—· ··· — / · —· — ·—· —·——';
	@override String get descriptionOn => '·——— ··— —— ·——· ·· —· ——· / ·— ··—· — · ·—· / ·—· ··· — / ·· ··· / · —· — · ·—· · —··';
	@override String get descriptionOff => '—· ——— — / ·——— ··— —— ·——· ·· —· ——· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$cw extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / ·——· ···· ——— —· ·';
	@override String get description => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / ··· ··· —··· ——··—— / ··—· —— / ——— ·—· / ·— ——';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$cw extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / —·—· ·—— / ·— —· —·· / —·· ·— — ·—';
	@override String get description => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / —·—· ·—— ——··—— / ·—· — — —·—— / ·— —· —·· / ——— — ···· · ·—· / —·· ·— — ·— / —— ——— —·· · ···';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$cw extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / ··—· — ———·· / ·— —· —·· / ··—· — ····—';
	@override String get description => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / — ···· · / ··—· — / —— ——— —·· · ···';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$cw extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—· ··— —— —··· · ·—· ··· / ·—· ——— ·——';
	@override String get description => '··· ···· ——— ·—— / ·— / ·—· ——— ·—— / ——— ··—· / —· ··— —— —··· · ·—· / —·— · —·—— ··· / ·— —··· ——— ···— · / — ···· · / —·— · —·—— —··· ——— ·— ·—· —·· / ·—— ···· ·· ·—·· · / ·—·· ——— ——· ——· ·· —· ——·';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$cw extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ·—·· ·— ··· ···· / ·— —· —·· / ·——· · ·—· ·· ——— —·· / —·— · —·——';
	@override String get description => '·— —·· —·· ··· / ·— / —·—· ——— —· — · —··— — ··— ·— ·—·· / —·— · —·—— ———··· / “ —··—· ” / ··—· ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ——··—— / “ ·—·—·— ” / ··—· ——— ·—· / —· ··— —— —··· · ·—· ···';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$cw extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '···— ·· —··· ·—· ·— — · / ——— —· / —·— · —·—— / ·——· ·—· · ··· ···';
	@override String get description => '···· ·— ·——· — ·· —·—· / ··—· · · —·· —··· ·— —·—· —·— / ·—— ···· · —· / —·—— ——— ··— / — ·— ·——· / ·— / —· ··— —— —··· · ·—· / —·— · —·——';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$cw extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get off => '—·· ·· ··· ·— —··· ·—·· · —··';
	@override String get rigctld => '···· ·— —— ·—·· ·· —··· / ·—· ·· ——· —·—· — ·—·· —··';
	@override String get flrig => '··—· ·—·· ·—· ·· ——·';
	@override String get hrd => '···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ®';
	@override String get n3fjp => '—· ···—— ··—· ·——— ·——·';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$cw extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get noCall => '—· ——— / ——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / — ——— / ·—·· ——— ——· / ·· —· / ·—— ·· — ····';
	@override String get connectFailed => '— ···· · / —· ——— —·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —··';
	@override String get needsPassword => '— ···· · / —· ——— —·· · / ·— ··· —·— ··· / ··—· ——— ·—· / ·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· ——··—— / ·— —· —·· / —· ——— —· · / ·· ··· / ··· — ——— ·—· · —··';
	@override String get loginFailed => '— ···· · / —· ——— —·· · / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· · / ·—·· ——— ——· ·· —·';
	@override String get disconnected => '— ···· · / —· ——— —·· · / —·—· ·—·· ——— ··· · —·· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —·';
	@override String get timeout => '— ···· · / —· ——— —·· · / —·· ·· —·· / —· ——— — / ·— —· ··· ·—— · ·—·';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$cw extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get ms => '—— ···';
	@override String get kHz => '—·— ···· ——··';
	@override String get kHzPerSecond => '—·— ···· ——·· —··—· ···';
	@override String get hz => '···· ——··';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$cw extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ——— —· — ·—· ——— ·—·· / ·——· — — / ·—— ·· — ···· / [ ·————· ]';
	@override String get descriptionOn => '·· —· / ·——· ···· ——— —· · / —— ——— —·· · ··· ——··—— / [ ·————· ] / —·— · —·—— ··· / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / [ ·————· ] / ·— ——· ·— ·· —· / ··— —· —·— · —·—— ··· / ·· — ·—·—·— / ·· — / ··— —· —·— · —·—— ··· / —··· —·—— / ·· — ··· · ·—·· ··—· / ·— ··—· — · ·—· / ·— / —— ·· —· ··— — · ·—·—·—';
	@override String get descriptionOff => '— ···· · / [ ·————· ] / —·— · —·—— / —·· ——— · ··· / —· ——— — / —·— · —·—— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—';
	@override String get pill => '— —··—';
	@override String get transmitting => '— ·—· ·— —· ··· —— ·· — — ·· —· ——·';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$cw extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· —— ·— ·—· — / ···— ··—· ——— / ··· —· ·— ·——·';
	@override String get descriptionOn => '·— ··—· — · ·—· / —·—— ——— ··— / ··· — ——— ·——· / — ··— ·—· —· ·· —· ——· / — ···· · / —·· ·· ·— ·—·· ——··—— / ·—· ——— ··— —· —·· ·· —· ——· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ·— / ··· · —· ··· ·· —··· ·—·· · / ··· — · ·——· ·—·—·— / ···— ——— ·· —·—· · / —— ——— —·· · ··· / ——— —· ·—·· —·—— ·—·—·—';
	@override String get descriptionOff => '··· — ·— —·—— ·· —· ——· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / —·—— ——— ··— / — ··— —· · —·· / ·· — ·—·—·—';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$cw extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· · — — ·—·· · / —·· · ·—·· ·— —·——';
	@override String get description => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / —·· ·· ·— ·—·· / ···· ·— ··· / — ——— / ··· — ——— ·——· / —··· · ··—· ——— ·—· · / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ——— ··— —· —·· · —·· ·—·—·— / ··· ···· ——— ·—· — · ·—· / ··—· · · ·—·· ··· / ·· —— —— · —·· ·· ·— — · —·—·—· / ·—·· ——— —· ——· · ·—· / ·—·· · ·— ···— · ··· / ·—· ——— ——— —— / ··—· ——— ·—· / ·— / ··· ·—·· ——— ·—— / —— ——— ···— · ·—·—·—';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$cw extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ·—·· ——— —· ——· / —— ——— ···— ·';
	@override String get description => '—— ——— ···— · / ·— — / ·—·· · ·— ··· — / — ···· ·· ··· / ··—· ·— ·—· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·—· ——— ··— —· —·· ··· / — ——— / ·— / ·—— ···· ——— ·—·· · / —·— ···· ——·· ——··—— / ···· ——— ·—— · ···— · ·—· / ··· ·—·· ——— ·—— ·—·· —·—— / —·—— ——— ··— / ··—· ·· —· ·· ··· ···· · —·· ·—·—·—';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$cw extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· —— ·— ·—·· ·—·· · ··· — / —— ——— ···— ·';
	@override String get description => '—— ——— ···— · / ·—·· · ··· ··· / — ···· ·— —· / — ···· ·· ··· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / —· ——— — / ·—· ——— ··— —· —·· · —·· ——··—— / ··· ——— / ··—· ·· —· · / — ··— —· ·· —· ——· / ·· ··· / ·—·· · ··—· — / ·— ·—·· ——— —· · ·—·—·—';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$cw extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· ·—·· ——— ·—— · ··· — / —— ——— ···— ·';
	@override String get description => '— ··— ·—· —· / — ···· · / —·· ·· ·— ·—·· / ··· ·—·· ——— ·—— · ·—· / — ···· ·— —· / — ···· ·· ··· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / —· ——— — / ·—· ——— ··— —· —·· · —·· ——··—— / ··— —· ·—·· · ··· ··· / ·· — / ·—— ·— ··· / ·— / ·—·· ——— —· ——· / —— ——— ···— · ·—·—·—';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$cw extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get pillOff => '· ··· —— / ——— ··—· ··—·';
	@override String get pillRun => '· ··· —— / ·—· ··— —·';
	@override String get pillSp => '· ··· —— / ··· ·—··· ·——·';
	@override String get field => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ···';
	@override String get off => '——— ··—· ··—·';
	@override String get run => '·—· ··— —·';
	@override String get sp => '··· ·—··· ·——·';
	@override String semantics({required Object state}) => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· ———··· / ${state} ·—·—·— / — ·— ·——· / — ——— / —·—· ···· ·— —· ——· · ·—·—·—';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$cw extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·— · —·—— · ·—· / ··· ·——· · · —··';
	@override String get unit => '·—— ·——· ——';
	@override String pill({required Object wpm}) => '${wpm} / ·—— ·——· ——';
	@override String get pillUnknown => '– / ·—— ·——· ——';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$cw extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—·—· ·—— / —·— · —·—— · ·—· / —— · ··· ··· ·— ——· · ···';
	@override String get notSupported => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / —·—· ·—— / —·— · —·—— ·· —· ——·';
	@override String key({required Object n}) => '··—· ${n}';
	@override String messageTitle({required Object n}) => '—— · ··· ··· ·— ——· · / —·——· ${n} —·——·—';
	@override String get labelField => '·—·· ·— —··· · ·—··';
	@override String labelKey({required Object n}) => '··—· ${n} / ·—·· ·— —··· · ·—··';
	@override String get details => '—·· · — ·— ·· ·—·· ···';
	@override String get empty => '—·——· · —— ·——· — —·—— —·——·—';
	@override String get sets => '—— · ··· ··· ·— ——· · / ··· · —';
	@override String get newSet => '—· · ·—— / ··· · —';
	@override String get renameSet => '·—· · —· ·— —— · / ··· · —';
	@override String get deleteSet => '—·· · ·—·· · — · / ··· · —';
	@override String get newSetName => '—· ·— —— ·';
	@override String get setDefault => '—·· · ··—· ·— ··— ·—·· —';
	@override String get setPota => '·——· ——— — ·—';
	@override String get setEsm => '· ··· —— / —— · ··· ··· ·— ——· · ···';
	@override String get setSaved => '—— —·—— / —— · ··· ··· ·— ——· · ···';
	@override String get repeat => '·—· · ·——· · ·— — / —— · ··· ··· ·— ——· · / # ·————';
	@override String get repeatOff => '—· ———';
	@override String repeatAfter({required Object n}) => '·— ··—· — · ·—· / ${n} / ··· · —·—· ——— —· —·· ···';
	@override String get repeatWait => '·—· · ·——· · ·— — ·· —· ——·';
	@override String get keyboard => '— —·—— ·——· · / — ——— / ··· · —· —··';
	@override String get keyboardField => '— —·—— ·——· · / — ——— / ··· · —· —··';
	@override String get closeArea => '—·—· ·—·· ——— ··· · / — ···· · / —·— · —·—— · ·—· / ·— ·—· · ·—';
	@override String get help => '···· · ·—·· ·——·';
	@override String get helpTitle => '·—— ·—· ·· — ·· —· ——· / —·—· ·—— / —— · ··· ··· ·— ——· · ···';
	@override String get helpIntro => '—— · ··· ··· ·— ——· · ··· / —·—· ·— —· / ··— ··· · / — · —— ·——· ·—·· ·— — · ··· / ·—— ·· — ···· / — ···· · / ··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / ···— ·— ·—·· ··— · ··· ———···';
	@override String get helpOpCall => '—·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·';
	@override String get helpQsoCall => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / — / ·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —·—· ·— ·—·· ·—·· / — ···· ·— — / ·—— ·· ·—·· ·—·· / —··· · / ·—·· ——— ——· ——· · —··';
	@override String get helpQsoFullCall => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ——··—— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· —·—·—· / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / ·— / ·——· ·— ·—· — ·· ·— ·—··';
	@override String get helpQsoPartial => '·— / ·——· ·— ·—· — ·· ·— ·—·· / —·—· ·— ·—·· ·—·· —·—·—· / —··· ·—·· ·— —· —·— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ··—· ··— ·—·· ·—·· / ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—··';
	@override String get helpQsoNextCall => '·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —·—· ·— ·—·· ·—·· / — ···· ·— — / ·—— ·· ·—·· ·—·· / —··· · / ··· · ·—·· · —·—· — · —·· / ··—· ——— ·—· / ·—·· ——— ——· ——· ·· —· ——· / —· · —··— — ——··—— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ···— ·— ·—·· ·· —·· / ··—· ··— ·—·· ·—·· / —·—· ·— ·—·· ·—··';
	@override String get helpQsoNextPartial => '·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —· · —··— — / ·——· ·— ·—· — ·· ·— ·—·· / ·— ··—· — · ·—· / ·—·· ——— ——· ——· ·· —· ——· / — ···· · / —·—· ··— ·—· ·—· · —· — / —·—· ——— —· — ·— —·—· —';
	@override String get helpQsoName => '— ···· · ·· ·—· / ··—· ·· ·—· ··· — / —· ·— —— · ——··—— / ·— ··· / — —·—— ·——· · —·· / ——— ·—· / · ·—·· ··· · / ··—· ·—· ——— —— / — ···· · / ·—·· ——— ——— —·— ··— ·——·';
	@override String get helpQsoState => '— ···· · ·· ·—· / ··· — ·— — · ——··—— / ·— ··· / — —·—— ·——· · —·· / ——— ·—· / · ·—·· ··· · / ··—· ·—· ——— —— / — ···· · / ·—·· ——— ——— —·— ··— ·——·';
	@override String get helpKeyerMsg => '—— · ··· ··· ·— ——· · / ·———— / ·— ··· / ·· — / ·—— ——— ··— ·—·· —·· / —··· · / ··· · —· — ——··—— / ·· —· ··· ·· —·· · / ·— —· ——— — ···· · ·—· / —— · ··· ··· ·— ——· · ·—·—·— / ···— ·— ·—·· ·· —·· / ··—· ——— ·—· / —— · ··· ··· ·— ——· · ··· / ·———— / — ···· ·—· ——— ··— ——· ···· / ———··';
	@override String get helpQsoRst => '— ···· · / ·—· · ·——· ——— ·—· — / —·—— ——— ··— / ·— ·—· · / ··· · —· —·· ·· —· ——·';
	@override String get helpQsoSerial => '—·—— ——— ··— ·—· / ··· · ·—· ·· ·— ·—·· / —· ··— —— —··· · ·—· ——··—— / ·· —· / ·— / —·—· ——— —· — · ··· — / — ···· ·— — / ··· · —· —·· ··· / ——— —· ·';
	@override String get helpPad => '·——· ·— —·· ··· / ·—— ·· — ···· / ——·· · ·—· ——— ··· / — ——— / — ···· ·— — / —— ·— —· —·—— / —·· ·· ——· ·· — ··· ———··· / ——··· / ·· ··· / ··· · —· — / ·— ··· / ————— ————— ——···';
	@override String get helpCut => '—·—· ··— — / —· ··— —— —··· · ·—· ··· ——··—— / — / ··—· ——— ·—· / ————— / ·— —· —·· / —· / ··—· ——— ·—· / ————· ———··· / ····· ————· ————· / ·· ··· / ··· · —· — / ·— ··· / ····· —· —·';
	@override String get helpCutDigits => '—·—· ···· ——— ——— ··· · ··· / — ···· · / —·· ·· ——· ·· — ··· / — ——— / —·—· ··— — ——··—— / ·· —· / ——·— ··— ——— — · ··· / — / ————— / ·· ··· / — ——··—— / ·———— / ·· ··· / ·— ——··—— / ····· / ·· ··· / · ——··—— / ————· / ·· ··· / —·';
	@override String get helpFullExample => '··—· ··— ·—·· ·—·· / · —··— ·— —— ·——· ·—·· · ———···';
	@override String get helpExample => '··· · —· —·· ··· / ·—— ·———— ·— ·—— / ····· —· —· / — — ——···';
	@override String get helpEsmIntro => '·—— ·· — ···· / · —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· / ——— —· ——··—— / · —· — · ·—· / —·— · —·—— ··· / —— · ··· ··· ·— ——· · ··· / —··· —·—— / — ···· · ·· ·—· / ··—· ··— —· —·—· — ·· ——— —· / —·— · —·—— ——··—— / ·— ··· / —· ·———— —— —— / —·· ——— · ··· ·—·—·— / — ···· · / · ··· —— / —— · ··· ··· ·— ——· · ··· / ··· · — / ··· — ·— ·—· — ··· / ·—— ·· — ···· / — ···· · ··· · ———···';
	@override String get helpEsmCq => '·—· ··— —· —· ·· —· ——· ——··—— / · —· — · ·—· / ·—— ·· — ···· / — ···· · / —·—· ·— ·—·· ·—·· / ··—· ·· · ·—·· —·· / · —— ·——· — —·—— / —·—· ·— ·—·· ·—·· ··· / —·—· ——·—';
	@override String get helpEsmExchange => '—·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· · ———··· / ·— ··—· — · ·—· / — ···· · ·· ·—· / —·—· ·— ·—·· ·—·· / ·—— ···· · —· / ·—· ··— —· —· ·· —· ——· ——··—— / ·— ··—· — · ·—· / — ···· · —·—— / ·— —· ··· ·—— · ·—· / ·· —· / ··· ·—··· ·——·';
	@override String get helpEsmThanks => '— ···· ·— —· —·— ··· ——··—— / ——— —· —·—· · / — ···· · / —·—· ——— —· — ·— —·—· — / ···· ·— ··· / ·—·· ——— ——· ——· · —·· ———··· / ·· — ··· / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· ··· / —· ·— —— · / — ···· · / —· · —··— — / —·—· ——— —· — ·— —·—· — ——··—— / —· ——— — / — ···· ·· ··· / ——— —· ·';
	@override String get helpEsmMyCall => '·· —· / ··· ·—··· ·——· ——··—— / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· / — ——— / — ···· · / ··· — ·— — ·· ——— —· / —·—— ——— ··— / ·— ·—· · / ·— —· ··· ·—— · ·—· ·· —· ——·';
	@override String get helpEsmHisCall => '·—· ··— —· —· ·· —· ——· ——··—— / — ···· · ·· ·—· / —·—· ·— ·—·· ·—·· / ·— ···· · ·— —·· / ——— ··—· / —·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· ·';
	@override String get helpEsmAgain => '·— ··· —·— ··· / ·— ——· ·— ·· —· / ·—— ···· · —· / —· ——— — ···· ·· —· ——· / ——— ··—· / — ···· · ·· ·—· / · —··— —·—· ···· ·— —· ——· · / ·—— ·— ··· / —·—· ——— ·——· ·· · —··';
	@override String get helpEsmStackThanks => '··· ··— ——· ——· · ··· — · —·· / ··—· ···—— / ··—· ——— ·—· / —··—· —··—· / ··· — ·— —·—· —·— ··· ———··· / — ··— / ——· ——— · ··· / ——— ··— — / ·— ··—· — · ·—· / — ···· · / —·—· ——— —· — ·— —·—· — / ·—·· ——— ——· ··· ——··—— / ··· ——— / ·· — / — ···· ·— —· —·— ··· ——··—— / — ···· · —· / —·—· ·— ·—·· ·—·· ··· / — ···· · / —· · —··— — / ··· — ·— —·—· —·— · —·· / ··· — ·— — ·· ——— —· / ·— —· —·· / ··· · —· —·· ··· / —·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· · ——··—— / ——— ·—· / ·— ··· —·— ··· / ·— / ·——· ·— ·—· — ·· ·— ·—·· / —··· ·— —·—· —·— / —·——· — ··— / —·— ·—· ··——·· —·——·— —·—·—· / ·—— ·· — ···· / —· ——— — ···· ·· —· ——· / ·—·· · ··—· — ——··—— / ·——— ··— ··· — / — ··—';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$cw extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·——· ···· ——— —· · / —·— · —·—— · ·—· / —— · ··· ··· ·— ——· · ···';
	@override String get notSupported => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / ·——· ···· ——— —· · / —— · ··· ··· ·— ——· · ···';
	@override String get description => '— ···· ·· ··· / ··— ··· · ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···';
	@override String key({required Object n}) => '—— ${n}';
	@override String messageTitle({required Object n}) => '···— ——— ·· —·—· · / —— · —— ——— ·—· —·—— / —·——· ${n} —·——·—';
	@override String get labelField => '·—·· ·— —··· · ·—··';
	@override String labelKey({required Object n}) => '···— ——— ·· —·—· · / —— · —— ——— ·—· —·—— / ${n} / ·—·· ·— —··· · ·—··';
	@override String durationSeconds({required Object n}) => '${n} / ···';
	@override String get emptyOnRadio => '· —— ·——· — —·——';
	@override String get notMeasured => '··— —· —·— —· ——— ·—— —· / ·—·· · —· ——· — ····';
	@override String get playButton => '·——· ·—·· ·— —·——';
	@override String get recordButton => '·—· · —·—· ——— ·—· —··';
	@override String get stopButton => '··· — ——— ·——·';
	@override String get repeat => '·—· · ·——· · ·— — / —— · ··· ··· ·— ——· · / # ·————';
	@override String get repeatOff => '—· ———';
	@override String repeatAfter({required Object n}) => '·— ··—· — · ·—· / ${n} / ··· · —·—· ——— —· —·· ···';
	@override String recordHelpTitle({required Object model}) => '${model} / —· ——— — · ··· ———···';
	@override String namedOnDevice({required Object device}) => '— ···· · ··· · / —— · —— ——— ·—· ·· · ··· / ·— ·—· · / ·· —· / ${device} ·————· ··· / ·—· ·— —·· ·· ——— ·—·—·— / — ···· · ·· ·—· / —· ·— —— · ··· / ·— —· —·· / ·—·· · —· ——· — ···· ··· / —··· · ·—·· ——— —· ——· / — ——— / — ···· ·— — / —·· · ···— ·· —·—· · ·—·—·—';
	@override String get namedOnRadio => '··· ·— ···— · —·· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ·—— ···· · ·—· · / ·· — ··· / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ··· / ··· · · / ·· — / — ——— ——— ·—·—·—';
	@override String get recordHelpYaesuDvs => '·—— ·— ·· — / ··—· ——— ·—· / — ···· · / [ ·—· · —·—· ] / ·· —· —·· ·· —·—· ·— — ——— ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / — ···· · —· / ···· ——— ·—·· —·· / — ···· · / ·——· — — / —··· ··— — — ——— —· / ·— —· —·· / ·—· · —·—· ——— ·—· —·· / —·—— ——— ··— ·—· / —— · ··· ··· ·— ——· · ·—·—·— / · —· —·· / ·· — / —··· —·—— / ·——· ·—· · ··· ··· ·· —· ——· / — ···· · / ··· — ——— ·——· / —··· ··— — — ——— —· / ···· · ·—· · / ·· —· / — ···· · / ·— ·——· ·——· / —··· · ··—· ——— ·—· · / ·—· · ·—·· · ·— ··· ·· —· ——· / ·——· — — / — ——— / ·— ···— ——— ·· —·· / ··— —· ·—— ·— —· — · —·· / —·—· ·—·· ·· —·—· —·— ··· ·—·—·—';
	@override String get recordHelpFt891 => '·—— ·— ·· — / ··—· ——— ·—· / — ···· · / [ ·—· · —·—· ] / ·· —· —·· ·· —·—· ·— — ——— ·—· / — ——— / —··· ·—·· ·· —· —·— / ·— — / ·—·· · ·— ··· — / ··—· ——— ··— ·—· / — ·· —— · ··· ——··—— / — ···· · —· / ···· ——— ·—·· —·· / — ···· · / ·——· — — / —··· ··— — — ——— —· / ·— —· —·· / ·—· · —·—· ——— ·—· —·· / —·—— ——— ··— ·—· / —— · ··· ··· ·— ——· · ·—·—·— / · —· —·· / ·· — / —··· —·—— / ·——· ·—· · ··· ··· ·· —· ——· / — ···· · / ··· — ——— ·——· / —··· ··— — — ——— —· / ···· · ·—· · / ·· —· / — ···· · / ·— ·——· ·——· / —··· · ··—· ——— ·—· · / ·—· · ·—·· · ·— ··· ·· —· ——· / ·——· — — / — ——— / ·— ···— ——— ·· —·· / ··— —· ·—— ·— —· — · —·· / —·—· ·—·· ·· —·—· —·— ··· ·—·—·—';
	@override String get pill => '···— ——— ·· —·—· ·';
	@override String play({required Object n}) => '·——· ·—·· ·— —·—— / —— · —— ——— ·—· —·—— / ${n}';
	@override String get stop => '··· — ——— ·——·';
	@override String record({required Object n}) => '·—· · —·—· ——— ·—· —·· / —— · —— ——— ·—· —·—— / ${n}';
	@override String get stopRecording => '··· — ——— ·——· / ·—· · —·—· ——— ·—· —·· ·· —· ——·';
	@override String get playing => '·——· ·—·· ·— —·—— ·· —· ——· …';
	@override String get recording => '·—· · —·—· ——— ·—· —·· ·· —· ——· …';
	@override String playingMemory({required Object label}) => '·——· ·—·· ·— —·—— ·· —· ——· / ${label}';
	@override String recordingMemory({required Object label}) => '·—· · —·—· ——— ·—· —·· ·· —· ——· / ${label}';
	@override String get doubtful => '—·· ·· —·· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— / ·· — ··——·· / ·· — / ··· ·— ·· —·· / ·· — / ·—— ·— ··· / ·· —·· ·—·· · / ·—· ·· ——· ···· — / ·— ·—— ·— —·—— ·—·—·—';
	@override String get recordOnRadio => '—·—— ——— ··— / ···· ·— ···— · / — ——— / ·—· · —·—· ——— ·—· —·· / — ···· · / —— · —— ——— ·—· ·· · ··· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— / ·· — ··· · ·—·· ··—· ·—·—·—';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$cw extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '·— ···— ——— ·· —·· / ——·· · ·—· ——— —····— —··· · ·— — ·· —· ——· / ——— —· / ··· ·——· ——— — ···';
	@override String get descriptionOn => '·—— ·· — ···· / ·— / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — · —·· ——··—— / — ··— —· ·· —· ——· / ·— / ··—· · ·—— / ···· ——·· / ——— ··—· ··—· / ·— / —·—· ·—— / ··· ·——· ——— — ——··—— / ··· ——— / · ···— · ·—· —·—— ——— —· · / ·— —· ··· ·—— · ·—· ·· —· ——· / ·· — / ·· ··· —· ’ — / —·—· ·— ·—·· ·—·· ·· —· ——· / ——— —· / — ···· · / ··· ·— —— · / —· ——— — · ·—·—·—';
	@override String get descriptionOff => '— ··— —· ·· —· ——· / · —··— ·— —·—· — ·—·· —·—— / — ——— / — ···· · / ··· ·——· ——— — — · —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— ·—·—·—';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$cw extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '——·· · ·—· ——— —····— —··· · ·— — ———··· / ·— ···— ——— ·· —·· ·— —· —·—· · / ·—· ·— —· ——· ·';
	@override String get description => '···· ——— ·—— / ··—· ·— ·—· / ——— ··—· ··—· / — ···· · / ··· ·——· ——— — — · —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ·—·· ·— —· —·· ——··—— / · ·· — ···· · ·—· / ··· ·· —·· · ·—·—·— / — ···· · / ——— ··—· ··—· ··· · — / ·· ··· / —· · ···— · ·—· / —· · ·— ·—· / ——·· · ·—· ——— / — / — ···· ·— — / ·—— ——— ··— ·—·· —·· / —··· · / ·— / ——·· · ·—· ——— / —··· · ·— — / ·— ——· ·— ·· —· ·—·—·—';
}

// Path: settings.map.style
class _Translations$settings$map$style$cw extends Translations$settings$map$style$en {
	_Translations$settings$map$style$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '—— ·— ·——· / ··· — —·—— ·—·· ·';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$cw extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ···· ——— ·—— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···';
	@override String get description => '· ·— —·—· ···· / —·—· ——— —· — ·— —·—· — / ·· ··· / ·— / ·——· ·· ·—·· ·—·· / ·—— ·· — ···· / ·· — ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ——··—— / ·· —· / ·· — ··· / —··· ·— —· —·· ·————· ··· / —·—· ——— ·—·· ——— ·—·';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$cw extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ···· ——— ·—— / ——· ·—· ·— —·—— ·—·· ·· —· ·';
	@override String get description => '··· ···· ·— —·· · ··· / — ···· · / —· ·· ——· ···· — / ··· ·· —·· · / ——— ··—· / — ···· · / · ·— ·—· — ···· ——··—— / ·—— ·· — ···· / — ·—— ·· ·—·· ·· ——· ···· — / ·— ··· / ·— / ——· ·—· ·— —·· ·· · —· —';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$cw extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get automatic => '·— ··— — ——— —— ·— — ·· —·—·';
	@override String get liberty => '·—·· ·· —··· · ·—· — —·——';
	@override String get bright => '—··· ·—· ·· ——· ···· —';
	@override String get positron => '·——· ——— ··· ·· — ·—· ——— —·';
	@override String get voyager => '···— ——— —·—— ·— ——· · ·—·';
	@override String get darkMatter => '—·· ·— ·—· —·— / —— ·— — — · ·—·';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$cw extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ···· ·— ·—· · / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·—';
	@override String get descriptionOn => '···· · ·—·· ·——· ·· —· ——· / ··— ··· / ·· —— ·——· ·—· ——— ···— · / — ···· · / ·— ·——· ·——· / —··· —·—— / ··· ···· ·— ·—· ·· —· ——· / ··— ··· ·— ——· · ——··—— / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ——··—— / —·—· ·—· ·— ··· ···· / ·— —· —·· / ·——· · ·—· ··—· ——— ·—· —— ·— —· —·—· · / —·· ·— — ·—';
	@override String get descriptionOff => '—·— · · ·——· ·· —· ——· / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·— / ·——· ·—· ·· ···— ·— — · ·—·—·—\n— ···· · / ···· ·— —— ··——— —·— / — · ·— —— / ·—— ——— —· ·————· — / —··· · / ·— —··· ·—·· · / — ——— / —·· · — · —·—· — / —·—· ·—· ·— ··· ···· · ··· / ——— ·—· / ——— — ···· · ·—· / ·· ··· ··· ··— · ··· ·—·—·—';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$cw extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get title => '··· ···· ·— ·—· · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·—';
	@override String get descriptionOn => '··· ···· ·— ·—· ·· —· ——· / ··· ——— —— · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·——· ··— —··· ·—·· ·· —·—· ·—·· —·—— / ·— —· —·· / ·—— ·· — ···· / ——— — ···· · ·—· / ··— ··· · ·—· ···';
	@override String get descriptionOff => '—·— · · ·——· ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·——· ·—· ·· ···— ·— — ·';
}

// Path: settings.station.models
class _Translations$settings$station$models$cw extends Translations$settings$station$models$en {
	_Translations$settings$station$models$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get flexRadio => '··—· ·—·· · —··— ·—· ·— —·· ·· ——— / —·——· ··· —— ·— ·—· — ··· —·· ·—· —·——·—';
	@override String get ft891 => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ————· ·————';
	@override String get ft991a => '—·—— ·— · ··· ··— / ··—· — —····— ————· ————· ·———— —··—· ·—';
	@override String get ft710 => '—·—— ·— · ··· ··— / ··—· — —····— ——··· ·———— —————';
	@override String get ftdx10 => '—·—— ·— · ··· ··— / ··—· — —·· —··— ·———— —————';
	@override String get ftx1 => '—·—— ·— · ··· ··— / ··—· — —··— —····— ·————';
	@override String get ft817 => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ·———— ——··· / —··—· / ··—· — —····— ———·· ·———— ———··';
	@override String get ft857 => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ····· ——···';
	@override String get ft897 => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ————· ——···';
	@override String get ft450 => '—·—— ·— · ··· ··— / ··—· — —····— ····— ····· ————— / —··—· / ··—· — —····— ····— ····· ————— —··';
	@override String get q900 => '——· ··— ——— ···· · — · —·—· / ——·— ————· ————— —————';
	@override String get tenTecEagle => '— · —· —····— — · —·—· / · ·— ——· ·—·· · / —·——· ····· ————· ————· —·——·—';
	@override String get tenTecOrion => '— · —· —····— — · —·—· / ——— ·—· ·· ——— —· / —·——· ····· —···· ····· —·——·—';
	@override String get tenTecOrionII => '— · —· —····— — · —·—· / ——— ·—· ·· ——— —· / ·· ·· / —·——· ····· —···· —···· —·——·—';
	@override String get sotacat => '··· ——— — ·— —·—· ·— — / —·——· · ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··——— —··—· —·— —··— ···—— —·——·—';
	@override String get yaesuGeneric => '—·—— ·— · ··· ··— / —····— / ——· · —· · ·—· ·· —·—·';
	@override String get icomGeneric => '·· —·—· ——— —— / —····— / ——· · —· · ·—· ·· —·—·';
	@override String get kenwoodGeneric => '—·— · —· ·—— ——— ——— —·· / —····— / ——· · —· · ·—· ·· —·—·';
	@override String get ts590sg => '—·— · —· ·—— ——— ——— —·· / — ··· —····— ····· ————· ————— ··· ——·';
	@override String get ts480 => '—·— · —· ·—— ——— ——— —·· / — ··· —····— ····— ———·· —————';
	@override String get qmx => '——·— ·—· ·——· / ·—·· ·— —··· ··· / ——·— —— —··—';
	@override String get fx4cr => '—··· ——· ··——— ··—· —··— / ··—· —··— —····— ····— —·—· ·—·';
	@override String get tx500 => '·—·· ·— —··· ····· ————· ————· / — —··— —····— ····· ————— —————';
	@override String get tx500mp => '·—·· ·— —··· ····· ————· ————· / — —··— —····— ····· ————— ————— —— ·——·';
	@override String get qcx => '——·— ·—· ·——· / ·—·· ·— —··· ··· / ——·— —·—· —··—';
	@override String get elecraftGeneric => '· ·—·· · —·—· ·—· ·— ··—· — / —····— / ——· · —· · ·—· ·· —·—·';
	@override String get kx2 => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··———';
	@override String get kx3 => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ···——';
	@override String get k4 => '· ·—·· · —·—· ·—· ·— ··—· — / —·— ····—';
	@override String get ic705 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ————— ·····';
	@override String get ic7300 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ···—— ————— —————';
	@override String get ic7300mk2 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··———';
	@override String get ic706mkiig => '·· —·—· ——— —— / ·· —·—· —····— ——··· ————— —···· —— —·— ·· ·· ——·';
	@override String get ic7100 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ·———— ————— —————';
	@override String get ic7610 => '·· —·—· ——— —— / ·· —·—· —····— ——··· —···· ·———— —————';
	@override String get ic7760 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ——··· —···· —————';
	@override String get ic9700 => '·· —·—· ——— —— / ·· —·—· —····— ————· ——··· ————— —————';
	@override String get ic905 => '·· —·—· ——— —— / ·· —·—· —····— ————· ————— ·····';
	@override String get ic7850 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ———·· ····· —————';
	@override String get ic7851 => '·· —·—· ——— —— / ·· —·—· —····— ——··· ———·· ····· ·————';
	@override String get x6100 => '—··— ·· · ——· ··— / —··— —···· ·———— ————— —————';
	@override String get g90 => '—··— ·· · ——· ··— / ——· ————· —————';
	@override String get rigctld => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ·—· ·· ——· —·—· — ·—·· —··';
	@override String get rigctldNodeName => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ·—· ·· ——· —·—· — ·—·· —·· —·——·—';
	@override String get flrig => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ··—· ·—·· ·—· ·· ——·';
	@override String get flrigNodeName => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ··—· ·—·· ·—· ·· ——· —·——·—';
	@override String get hrd => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ®';
	@override String get hrdNodeName => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ···· ·—· —·· —·——·—';
	@override String get n3fjp => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / —· ···—— ··—· ·——— ·——·';
	@override String get n3fjpNodeName => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / —· ···—— ··—· ·——— ·——· —·——·—';
	@override String get commander => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / —·· —··— ·—·· ·— —··· / —·—· ——— —— —— ·— —· —·· · ·—·';
	@override String get commanderNodeName => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / —·—· ——— —— —— ·— —· —·· · ·—· —·——·—';
	@override String get antenna => '·— —· — · —· —· ·—';
	@override String get key => '—·—· ·—— / —·— · —·——';
	@override String get winkeyer => '·—— ·· —· —·— · —·—— · ·—·';
	@override String get placeholderRadio => '——· · —· · ·—· ·· —·—· / ·—· ·— —·· ·· ——— / —·——· ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· —·——·—';
	@override String get placeholderRadioNodeName => '—— —·—— / ·—· ·— —·· ·· ———';
	@override String get antennaGenius => '····— ——— ···—— ·— / ·— —· — · —· —· ·— / ——· · —· ·· ··— ···';
	@override String get sierraCoax => '··· ·· · ·—· ·—· ·— / ·—· ·— —·· ·· ——— / —·—· —··— —····— ·———— / —·—· ——— ·— —··— / ··· ·—— ·· — —·—· ····';
	@override String get rtlSdr => '·—· — ·—·· —····— ··· —·· ·—·';
	@override String get nesdr => '—· ——— ——— · ·—·· · —·—· / —· · ··· —·· ·—·';
	@override String get sdrplay => '··· —·· ·—· ·——· ·—·· ·— —·—— / ·—· ··· ·——·';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$cw extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get network => '—· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··';
	@override String get secureNetwork => '··· · —·—· ··— ·—· · / —· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··';
	@override String get usbSerial => '··— ··· —··· / ··· · ·—· ·· ·— ·—··';
	@override String get wifi => '—· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··';
	@override String get bluetoothSerial => '—··· ·—·· ··— · — ——— ——— — ···· / ··· · ·—· ·· ·— ·—··';
	@override String get bleSerial => '—··· ·—·· ··— · — ——— ——— — ···· / ·—·· ·';
	@override String get placeholder => '·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—·';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$cw extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get dipole => '—·· ·· ·——· ——— ·—·· ·';
	@override String get vertical => '···— · ·—· — ·· —·—· ·— ·—··';
	@override String get yagiBeam => '—·—— ·— ——· ·· / —··—· / —··· · ·— ——';
	@override String get loop => '·—·· ——— ——— ·——·';
	@override String get longWire => '·—·· ——— —· ——· / ·—— ·· ·—· · / —··—· / · ··—· ···· ·——';
	@override String get other => '——— — ···· · ·—·';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$cw extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get straight => '··· — ·—· ·— ·· ——· ···· — / —·— · —·——';
	@override String get sideswiper => '··· ·· —·· · ··· ·—— ·· ·——· · ·—·';
	@override String get bug => '—··· ··— ——· / —·——· —— · —·—· ···· ·— —· ·· —·—· ·— ·—·· / ··· · —— ·· —····— ·— ··— — ——— —— ·— — ·· —·—· —·——·—';
	@override String get fullyAutomatic => '··—· ··— ·—·· ·—·· —·—— —····— ·— ··— — ——— —— ·— — ·· —·—· / —·— · —·—— · ·—·';
	@override String get singlePaddle => '··· ·· —· ——· ·—·· · / ·——· ·— —·· —·· ·—·· ·';
	@override String get dualPaddle => '—·· ··— ·— ·—·· / ·——· ·— —·· —·· ·—·· ·';
	@override String get computerDriven => '—·—· ——— —— ·——· ··— — · ·—· / —·· ·—· ·· ···— · —·';
	@override String get other => '——— — ···· · ·—·';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$cw extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$cw._(TranslationsCw root) : this._root = root, super.internal(root);

	final TranslationsCw _root; // ignore: unused_field

	// Translations
	@override String get unknown => '··— —· —·— —· ——— ·—— —·';
	@override String get sunny => '··· ··— —· —· —·——';
	@override String get clear => '—·—· ·—·· · ·— ·—·';
	@override String get mainlySunny => '—— ·— ·· —· ·—·· —·—— / ··· ··— —· —· —·——';
	@override String get mainlyClear => '—— ·— ·· —· ·—·· —·—— / —·—· ·—·· · ·— ·—·';
	@override String get partlyCloudy => '·——· ·— ·—· — ·—·· —·—— / —·—· ·—·· ——— ··— —·· —·——';
	@override String get cloudy => '—·—· ·—·· ——— ··— —·· —·——';
	@override String get foggy => '··—· ——— ——· ——· —·——';
	@override String get rimeFog => '·—· ·· —— · / ··—· ——— ——·';
	@override String get lightDrizzle => '·—·· ·· ——· ···· — / —·· ·—· ·· ——·· ——·· ·—·· ·';
	@override String get drizzle => '—·· ·—· ·· ——·· ——·· ·—·· ·';
	@override String get heavyDrizzle => '···· · ·— ···— —·—— / —·· ·—· ·· ——·· ——·· ·—·· ·';
	@override String get lightFreezingDrizzle => '·—·· ·· ——· ···· — / ··—· ·—· · · ——·· ·· —· ——· / —·· ·—· ·· ——·· ——·· ·—·· ·';
	@override String get freezingDrizzle => '··—· ·—· · · ——·· ·· —· ——· / —·· ·—· ·· ——·· ——·· ·—·· ·';
	@override String get lightRain => '·—·· ·· ——· ···· — / ·—· ·— ·· —·';
	@override String get rain => '·—· ·— ·· —·';
	@override String get heavyRain => '···· · ·— ···— —·—— / ·—· ·— ·· —·';
	@override String get lightFreezingRain => '·—·· ·· ——· ···· — / ··—· ·—· · · ——·· ·· —· ——· / ·—· ·— ·· —·';
	@override String get freezingRain => '··—· ·—· · · ——·· ·· —· ——· / ·—· ·— ·· —·';
	@override String get lightSnow => '·—·· ·· ——· ···· — / ··· —· ——— ·——';
	@override String get snow => '··· —· ——— ·——';
	@override String get heavySnow => '···· · ·— ···— —·—— / ··· —· ——— ·——';
	@override String get snowGrains => '··· —· ——— ·—— / ——· ·—· ·— ·· —· ···';
	@override String get lightShowers => '·—·· ·· ——· ···· — / ··· ···· ——— ·—— · ·—· ···';
	@override String get showers => '··· ···· ——— ·—— · ·—· ···';
	@override String get heavyShowers => '···· · ·— ···— —·—— / ··· ···· ——— ·—— · ·—· ···';
	@override String get lightSnowShowers => '·—·· ·· ——· ···· — / ··· —· ——— ·—— / ··· ···· ——— ·—— · ·—· ···';
	@override String get snowShowers => '··· —· ——— ·—— / ··· ···· ——— ·—— · ·—· ···';
	@override String get thunderstorm => '— ···· ··— —· —·· · ·—· ··· — ——— ·—· ——';
	@override String get lightThunderstormsWithHail => '·—·· ·· ——· ···· — / — ···· ··— —· —·· · ·—· ··· — ——— ·—· —— ··· / ·—— ·· — ···· / ···· ·— ·· ·—··';
	@override String get thunderstormWithHail => '— ···· ··— —· —·· · ·—· ··· — ——— ·—· —— / ·—— ·· — ···· / ···· ·— ·· ·—··';
}

/// The flat map containing all translations for locale <cw>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsCw {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => '··· ·— ···— ·',
			'common.ok' => '——— —·—',
			'common.cancel' => '—·—· ·— —· —·—· · ·—··',
			'common.delete' => '—·· · ·—·· · — ·',
			'common.create' => '—·—· ·—· · ·— — ·',
			'common.error' => '· ·—· ·—· ——— ·—·',
			'common.close' => '—·—· ·—·· ——— ··· ·',
			'common.done' => '—·· ——— —· ·',
			'common.callsign' => '—·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'common.clear' => '—·—· ·—·· · ·— ·—·',
			'common.dismiss' => '—·· ·· ··· —— ·· ··· ···',
			'common.expand' => '· —··— ·——· ·— —· —··',
			'common.collapse' => '—·—· ——— ·—·· ·—·· ·— ·——· ··· ·',
			'onboarding.welcomeTitle' => '·—— · ·—·· —·—· ——— —— · / — ——— / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· —·—·——',
			'onboarding.welcomeTitleDesktop' => '·—— · ·—·· —·—· ——— —— · / — ——— / ···· ·— —— ··——— —·— / ·——· ——— ·—— · ·—· / ·—·· ——— ——· ——· · ·—· —·—·——',
			'onboarding.welcomeBody' => '·—— · / ···· ·— ···— · / ·— / ··—· · ·—— / ——·— ··— · ··· — ·· ——— —· ··· / — ——— / ···· · ·—·· ·——· / ··— ··· / —··· · — — · ·—· / ··· ··— ·· — / —·—— ——— ··— ·—· / —· · · —·· ··· ·—·—·—',
			'onboarding.skip' => '··· —·— ·· ·——·',
			'onboarding.kContinue' => '—·—· ——— —· — ·· —· ··— ·',
			'onboarding.back' => '—··· ·— —·—· —·—',
			'onboarding.next' => '—· · —··— —',
			'onboarding.done' => '—·· ——— —· ·',
			'onboarding.callsignTitle' => '·—— ···· ·— — ·————· ··· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··——··',
			'onboarding.callsignBody' => '—·—— ——— ··— / —· · · —·· / ·— —· / ·— —— ·— — · ··— ·—· / ·—· ·— —·· ·· ——— / ——— ·——· · ·—· ·— — ——— ·—· / ·—·· ·· —·—· · —· ··· · / ·· —· / ——— ·—· —·· · ·—· / — ——— / ··—· ·· —· —·· / — ···· ·· ··· / ·— ·——· ·——· / ··— ··· · ··—· ··— ·—··',
			'onboarding.callsignLabel' => '——— ·——· · ·—· ·— — ——— ·—· ·————· ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'onboarding.alreadyHaveAccount' => '·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ···— · / ·— —· / ·— —·—· —·—· ——— ··— —· — ··——··',
			'onboarding.foundSiblingTitle' => '·—·· ·· —· —·— / ·— —· / · —··— ·· ··· — ·· —· ——· / ·— —·—· —·—· ——— ··— —· — ··——··',
			'onboarding.foundSiblingBody' => ({required Object app}) => '·—— · / ··—· ——— ··— —· —·· / ${app} / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / — ···· · / ··· ·— —— · / ·— —·—· —·—· ——— ··— —· — / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—',
			'onboarding.foundPoloBody' => '·—— · / ··—· ——— ··— —· —·· / ·— —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / — ···· · / ··· ·— —— · / ·— —·—· —·—· ——— ··— —· — / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—',
			'onboarding.foundSiblingsBody' => '·—— · / ··—· ——— ··— —· —·· / ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——· ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—·· ·· —· —·— / — ···· ·· ··· / ·— ·——· ·——· / — ——— / ——— —· · / ——— ··—· / — ···· · ·· ·—· / ·— —·—· —·—· ——— ··— —· — ··· / ·— —· —·· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ·—·· ——— ——· ··· / —·—· ——— —— · / ·— —·—· ·—· ——— ··· ··· ·—·—·—',
			'onboarding.linkWithApp' => ({required Object app}) => '·—·· ·· —· —·— / ·—— ·· — ···· / ${app}',
			'onboarding.linkWithPolo' => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — / ·· —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —·',
			'onboarding.setUpFresh' => '··· · — / ··— ·——· / ··—· ·—· · ··· ····',
			'onboarding.activitiesTitle' => '··—· ·— ···— ——— ·—· ·· — · / ·— —·—· — ·· ···— ·· — ·· · ···',
			'onboarding.activitiesBody' => '·— ·—· · / —·—— ——— ··— / ·· —· — · ·—· · ··· — · —·· / ·· —· / ·— —· —·—— / ——— ··—· / — ···· · ··· · / ·——· ——— ·——· ··— ·—·· ·— ·—· / ·— —·—· — ·· ···— ·— — ·· ——— —· / ·——· ·—· ——— ——· ·—· ·— —— ··· ··——··',
			'onboarding.activitiesFooter' => '—·——· —·—— ——— ··— / —·—· ·— —· / ··—· ·· —· —·· / —— ——— ·—· · / ——— ·——· — ·· ——— —· ··· / ·· —· / — ···· · / ··· · — — ·· —· ——· ··· —·——·—',
			'onboarding.activityPota' => '·——· ·— ·—· —·— ··· / ——— —· / — ···· · / ·— ·· ·—·',
			'onboarding.activitySota' => '··· ··— —— —— ·· — ··· / ——— —· / — ···· · / ·— ·· ·—·',
			'onboarding.activityWwff' => '·—— ——— ·—· ·—·· —·· / ·—— ·· —·· · / ··—· ·—·· ——— ·—· ·— / ·—··· / ··—· ·— ··— —· ·—',
			'onboarding.consentTitle' => '—·· ·— — ·— / ·—··· / ·——· ·—· ·· ···— ·— —·—· —·——',
			'onboarding.consentUsageBody' => '— ——— / ···· · ·—·· ·——· / ··— ··· / —— ·— —·— · / — ···· · / ·— ·——· ·——· / —··· · — — · ·—· ——··—— / ·—— · ·————· —·· / ·—·· ·· —·— · / — ——— / —·—· ——— ·—·· ·—·· · —·—· — / ·——· · ·—· ··—· ——— ·—· —— ·— —· —·—· · ——··—— / —·—· ·—· ·— ··· ···· ——··—— / ·— —· —·· / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·— ·—·—·—',
			'onboarding.consentUsageLabel' => '··· ···· ·— ·—· · / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·—',
			'onboarding.consentOperationBody' => '··· ——— —— · / ··—· · ·— — ··— ·—· · ··· / —— ·· ——· ···· — / ·· —· ···— ——— ·—·· ···— · / ··· ···· ·— ·—· ·· —· ——· / —·—— ——— ··— ·—· / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·—— ·· — ···· / ——— — ···· · ·—· / ··— ··· · ·—· ··· ·—·—·— / —·—— ——— ··— / —·—· ·— —· / ——— ·——· — —····— ——— ··— — / ·— — / ·— —· —·—— / — ·· —— · ·—·—·—',
			'onboarding.consentOperationLabel' => '··· ···· ·— ·—· · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·—',
			'onboarding.finishingSetup' => '··—· ·· —· ·· ··· ···· ·· —· ——· / ··· · — ··— ·——· / — / —·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· / ·—· · ··—· · ·—· · —· —·—· · / —·· ·— — ·— …',
			'startScreen.credits' => '—··· —·—— / —·— ·· ··——— —·· / ·— —· —·· / ··—· ·—· ·· · —· —·· ···',
			'testerOverlay.tape' => '—·—· ·— ··— — ·· ——— —· ———··· / ··— —· —·· · ·—· / —·—· ——— —· ··· — ·—· ··— —·—· — ·· ——— —·',
			'testerOverlay.warningTitle' => '— ···· ·· ··· / ·— ·——· ·——· / ·· ··· / ·— / ·—— ——— ·—· —·— / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ···',
			'testerOverlay.warningBody' => '—— ——— ··· — / ··—· · ·— — ··— ·—· · ··· / ···· ·— ···— · / ··— —· · ···— · —· / ··· ··— ·—· ··—· ·— —·—· · ··· / ·— —· —·· / — ···· · ·—· · / ·— ·—· · / — ·—· ·· ·——· / ···· ·— ——·· ·— ·—· —·· ··· / ·— ·—·· ·—·· / ——— ···— · ·—· ·—·—·— / ·——· ·—·· · ·— ··· · / —·—· ···· · —·—· —·— / ··—· ——— ·—· / ··— ·——· —·· ·— — · ··· / ·—· · ——· ··— ·—·· ·— ·—· ·—·· —·—— ·—·—·—',
			'testerOverlay.whatsNew' => ({required Object build}) => '·—— ···· ·— — ·————· ··· / —· · ·—— / ·· —· / —··· ··— ·· ·—·· —·· / ${build}',
			'testerOverlay.thanks' => '— ···· ·— —· —·— / —·—— ——— ··— / ··—· ——— ·—· / ·——· ··— — — ·· —· ——· / —·—— ——— ··— ·—· / ·—·· ——— ——· / ·— — / ·—· ·· ··· —·— / ·· —· / ——— ·—· —·· · ·—· / — ——— / ···· · ·—·· ·——· / ··— ··· / —— ·— —·— · / — ···· ·· ··· / ·— ·——· ·——· / —··· · — — · ·—· —·—·——',
			'extensionsPanel.categoryActivity' => '·— —·—· — ·· ···— ·· — ·· · ···',
			'extensionsPanel.categoryAward' => '·— ·—— ·— ·—· —·· ···',
			'extensionsPanel.categoryContest' => '—·—· ——— —· — · ··· — ···',
			'extensionsPanel.categoryLookup' => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ···',
			'extensionsPanel.categorySpots' => '··· ·——· ——— — / ··· ——— ··— ·—· —·—· · ···',
			'extensionsPanel.categoryDashboard' => '—·· ·— ··· ···· —··· ——— ·— ·—· —·· / ·——· ·— —· · ·—·· ···',
			'extensionsPanel.categoryOther' => '——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —· ···',
			'extensionsPanel.searchHint' => '··· · ·— ·—· —·—· ···· / · —··— — · —· ··· ·· ——— —· ···',
			'extensionsPanel.applying' => '·— —·—· — ·· ···— ·— — ·· —· ——· / · —··— — · —· ··· ·· ——— —· / —·—· ···· ·— —· ——· · ··· ——··—— / — ···· ·· ··· / —— ·— —·—— / — ·— —·— · / ·— / —— ——— —— · —· — …',
			'extensionsPanel.noMatches' => '—· ——— / · —··— — · —· ··· ·· ——— —· ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ····',
			'extensionsPanel.installFromFile' => '·· —· ··· — ·— ·—·· ·—·· / ··—· ·—· ——— —— / ··—· ·· ·—·· · …',
			'extensionsPanel.installVersion' => ({required Object version}) => '···— · ·—· ··· ·· ——— —· / ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => '··· —·—· ·—· · · —· ··· ···· ——— — / ${n} / ——— ··—· / ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '·—·—· ${count}',
			'extensionsPanel.previousScreenshot' => '·——· ·—· · ···— ·· ——— ··— ··· / ··· —·—· ·—· · · —· ··· ···· ——— —',
			'extensionsPanel.nextScreenshot' => '—· · —··— — / ··· —·—· ·—· · · —· ··· ···· ——— —',
			'extensionsPanel.screenshotUnavailable' => '··· —·—· ·—· · · —· ··· ···· ——— — / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'extensionsPanel.canReach' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —·—· ·— —· / —·—· ——— —· — ·— —·—· —',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host} ——··—— / ——— ···— · ·—· / ·— / ·—·· ·· ···— · / —·—· ——— —· —· · —·—· — ·· ——— —·',
			'extensionsPanel.canHoldLocalConnection' => '—·· · ···— ·· —·—· · ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ——··—— / ——— ···— · ·—· / ·— / ·—·· ·· ···— · / —·—· ——— —· —· · —·—· — ·· ——— —·',
			'extensionsPanel.canUseLocation' => '—·—— ——— ··— ·—· / ·—·· ——— —·—· ·— — ·· ——— —·',
			'extensionsPanel.canReadRadio' => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / ·—· · ·— —·· / ·· — ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· ·',
			'extensionsPanel.canControlRadio' => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / —·—· ——— —· — ·—· ——— ·—·· / ·· — / ·— —· —·· / — ——— / — ·—· ·— —· ··· —— ·· — / ·—— ·· — ···· / ·· — / — / — ··— —· ·· —· ——· ——··—— / ·——· ——— ·—— · ·—· ——··—— / —·—· ·—— ——··—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ·— —· —·· / ·——· — —',
			'extensionsPanel.canCommandRadioRaw' => '—·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ——··—— / — ——— / ··· · —· —·· / ·· — / ·— —· —·—— / —·—· ——— —— —— ·— —· —·· / ·· —· / ·· — ··· / ——— ·—— —· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / — / ·· —· —·—· ·—·· ··— —·· ·· —· ——· / ——— —· · ··· / — ···· ·— — / — ·—· ·— —· ··· —— ·· — / ——— ·—· / —·—· ···· ·— —· ——· · / ·· — ··· / ··· · — — ·· —· ——· ···',
			'extensionsPanel.canReadCluster' => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ·—· · ·— —·· / ·—— ···· ·— — / ·· — / ··· · —· —·· ···',
			'extensionsPanel.canSpotCluster' => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ·——· ——— ··· — / ··· ·——· ——— — ··· / ·· —· / —·—— ——— ··— ·—· / —· ·— —— ·',
			'extensionsPanel.canCommandCluster' => '— ···· · / —·· —··— / —·—· ·—·· ··— ··· — · ·—· ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / —·—— ——— ··— ——··—— / — ——— / ··· · —· —·· / ·· — / ·— —· —·—— / —·—· ——— —— —— ·— —· —·· / ·· —· / —·—— ——— ··— ·—· / —· ·— —— ·',
			'extensionsPanel.canSetUserAgent' => '·· —·· · —· — ·· ··—· —·—— / ·· — ··· · ·—·· ··—· / — ——— / ··· · ·—· ···— · ·—· ··· / ··— —· —·· · ·—· / ·· — ··· / ——— ·—— —· / —· ·— —— ·',
			'extensionsPanel.noCapabilities' => '·· — / ·— ··· —·— ··· / ··—· ——— ·—· / —· ——— — ···· ·· —· ——· / ——— ··— — ··· ·· —·· · / — ···· · / ·— ·——· ·——· ·—·—·—',
			'extensionsPanel.sandboxNote' => '· —··— — · —· ··· ·· ——— —· ··· / ·—· ··— —· / ··· ·— —· —·· —··· ——— —··— · —·· ———··· / —· ——— / ·— —·—· —·—· · ··· ··· / — ——— / —·—— ——— ··— ·—· / ··—· ·· ·—·· · ··· ——··—— / ·— —· —·· / —· ——— / —· · — ·—— ——— ·—· —·— / —··· · —·—— ——— —· —·· / ·—— ···· ·— — / ·· ··· / ·—·· ·· ··· — · —·· / ···· · ·—· · ·—·—·—',
			'extensionsPanel.installAction' => '·· —· ··· — ·— ·—·· ·—··',
			'extensionsPanel.updateAction' => '··— ·——· —·· ·— — ·',
			'extensionsPanel.installFailed' => '— ···· ·— — / · —··— — · —· ··· ·· ——— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·· —· ··· — ·— ·—·· ·—·· · —··',
			'extensionsPanel.installedBadge' => '·· —· ··· — ·— ·—·· ·—·· · —··',
			'extensionsPanel.uninstallAction' => '·—· · —— ——— ···— ·',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '·—· · —— ——— ···— · / ${name} ··——··',
			'extensionsPanel.uninstallBody' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ·— —· —·· / ·· — ··· / ··· · — — ·· —· ——· ··· / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —— ——— ···— · —·· ·—·—·— / —·—— ——— ··— ·—· / ·—·· ——— ——· ··· / ·—— ·· ·—·· ·—·· / ·—· · —— ·— ·· —· / ··— —· — ——— ··— —·—· ···· · —·· ·—·—·—',
			'extensionsPanel.installedMessage' => ({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· · —·· / ${name}',
			'extensionsPanel.installDownloading' => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· …',
			'extensionsPanel.installWaiting' => '·—— ·— ·· — ·· —· ——· / — ——— / ·· —· ··· — ·— ·—·· ·—·· …',
			'extensionsPanel.installInstalling' => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· …',
			'extensionsPanel.installAwaitingApproval' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—— ——— ··— ·—· / ·— ·——· ·——· ·—· ——— ···— ·— ·—·· …',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / —··· · ·· —· ——· / ·· —· ··· — ·— ·—·· ·—·· · —·· ·—·—·—',
			'extensionsPanel.updatedTo' => ({required Object version}) => '··— ·——· —·· ·— — · —·· / — ——— / ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / ${name} / —·· ·· —·· / —· ——— — / ··—· ·· —· ·· ··· ···· ·—·—·— / ·· — / —— ·— —·—— / —· · · —·· / ·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · —— ——— ···— · / ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ··—· ·—· ——— —— / ${source}',
			'extensionsPanel.dropHint' => '—·· ·—· ——— ·——· / ·— / ·—·—·— ···· ··——— —·— · —··— — / · —··— — · —· ··· ·· ——— —· / — ——— / ·· —· ··· — ·— ·—·· ·—·· / ·· —',
			'extensionsPanel.dropOneOnly' => '—·· ·—· ——— ·——· / ——— —· · / · —··— — · —· ··· ·· ——— —· / ·— — / ·— / — ·· —— · ·—·—·—',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} / ·—· · — ··— ·—· —· · —·· / ${status} / ··—· ——— ·—· / — ···· ·— — / · —··— — · —· ··· ·· ——— —· ·—·—·—',
			'extensionsPanel.downloadTooLarge' => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / ··—· ·— ·—· / — ——— ——— / ·—·· ·— ·—· ——· · / — ——— / —··· · / ·— —· / · —··— — · —· ··· ·· ——— —· ·—·—·—',
			'extensionsPanel.downloadNotSecure' => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·—· · —·· ·· ·—· · —·—· — · —·· / ··· ——— —— · ·—— ···· · ·—· · / ·· —· ··· · —·—· ··— ·—· · ·—·—·—',
			'extensionsPanel.catalogSection' => '—·—· ·— — ·— ·—·· ——— ——·',
			'extensionsPanel.catalogLoading' => '·—·· ——— ·— —·· ·· —· ——· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· …',
			'extensionsPanel.catalogUnreachable' => '—·—· ·— — ·— ·—·· ——— ——· / ··— —· ·—· · ·— —·—· ···· ·— —··· ·—·· ·',
			'extensionsPanel.builtIn' => '—··· ··— ·· ·—·· — / ·· —·',
			'extensionsPanel.updateAvailableBadge' => '··— ·——· —·· ·— — · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'extensionsPanel.updatesAvailableTitle' => '· —··— — · —· ··· ·· ——— —· / ··— ·——· —·· ·— — · ···',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => '·— —· / ··— ·——· —·· ·— — · / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ··—· ——— ·—· / ${name} ·—·—·—',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} / ·— —· —·· / ${count} / —— ——— ·—· · / —· · · —·· / ··— ·——· —·· ·— — ·· —· ——· ·—·—·—',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} / —· · · —·· / ··— ·——· —·· ·— — ·· —· ——· ·—·—·—',
			'extensionsPanel.pendingUpdatesSection' => '·——· · —· —·· ·· —· ——· / ··— ·——· —·· ·— — · ···',
			'extensionsPanel.updateAllAction' => '··— ·——· —·· ·— — · / ·— ·—·· ·—··',
			'extensionsPanel.updatesUnderWay' => '— ···· ——— ··· · / ··— ·——· —·· ·— — · ··· / ·— ·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ··— —· —·· · ·—· / ·—— ·— —·—— ·—·—·—',
			'extensionsPanel.updatesNothingLeft' => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ··— ·——· / — ——— / —·· ·— — · ·—·—·—',
			'extensionsPanel.updatesNoticeAction' => '—— ——— ·—· · / ·· —· ··—· ———',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··— ·——· —·· ·— — · / ${count} / · —··— — · —· ··· ·· ——— —· ··——··', other: '··— ·——· —·· ·— — · / ${count} / · —··— — · —· ··· ·· ——— —· ··· ··——··', ), 
			'extensionsPanel.upgradeDoneTitle' => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ·—· · ·— —·· —·——',
			'extensionsPanel.upgradeDoneBody' => '— ···· · —·—— / —· ——— ·—— / —·—· ——— —— · / ··—· ·—· ——— —— / — ···· · / ···· ·— —— ··——— —·— / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ——··—— / ··· ——— / — ···· · —·—— / —·—· ·— —· / —··· · / ··— ·——· —·· ·— — · —·· / ·—— ·· — ···· ——— ··— — / ·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / ·— / —· · ·—— / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——· ·—·—·—',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => '—· ——— — / ··— ·——· ——· ·—· ·— —·· · —·· ———··· / ${names} ·—·—·—',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => '·—— ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —· ———··· / ${names} ·—·—·—',
			'extensionsPanel.upgradeDoneRefusedHint' => '— ···· · —·—— / ·— ·—· · / ··· — ·· ·—·· ·—·· / ·· —· ··· — ·— ·—·· ·—·· · —·· / ·— —· —·· / —— ·— ·—· —·— · —·· / ·· —· / ··· · — — ·· —· ——· ··· / › / · —··— — · —· ··· ·· ——— —· ··· / — / ··— ·——· —·· ·— — ·· —· ——· / — ···· · —— / — ···· · ·—· · / ·—— ·· ·—·· ·—·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—',
			'extensionsPanel.upgradeDoneUnservedHint' => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / —·· ·· ·—· · —·—· — / ·—· · ·——· ·—·· ·— —·—· · —— · —· — / ··—· ——— ·—· / — ···· · ··· · ——··—— / ··· ——— / ·—·· ——— ——— —·— / — ···· · ·—· · / ··—· ——— ·—· / · —··— — · —· ··· ·· ——— —· ··· / — ···· ·— — / —·—· ——— ···— · ·—· / ·—— ···· ·— — / —·—— ——— ··— / ··— ··· · —·· ·—·—·—',
			'extensionsPanel.retiredQp' => '——·— ··· ——— / ·——· ·— ·—· — ·· · ···',
			'extensionsPanel.retiredStateparks' => '··· — ·— — · / ·——· ·— ·—· —·— ··· / · ···— · —· — ···',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} / ——— ··—· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ···· ·— ···— · / —· ——— — / ·— ·—· ·—· ·· ···— · —·· / —·—— · — ·—·—·— / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —··· · / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / — ···· · / —· · —··— — / — ·· —— · / — ···· · / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· / —·—· ·— —· / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—',
			'extensionsPanel.runtimeDeadBody' => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ··· — ·— ·—· — ·—·—·— / ·—· · ··· — ·— ·—· — ·· —· ——· / — ···· · / ·— ·——· ·——· / ··· ···· ——— ··— ·—·· —·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—',
			'extensionsPanel.refusedTitle' => '··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —·',
			'extensionsPanel.upgradeBusyTitle' => '··· — ·· ·—·· ·—·· / ··· · — — ·· —· ——· / ··— ·——·',
			'extensionsPanel.upgradeRuntimeDeadTitle' => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —· ——— — / ·—· ··— —· —· ·· —· ——·',
			'extensionsPanel.restoreTitle' => '··· ——— —— · / ——— ··—· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —— ·· ··· ··· ·· —· ——·',
			'extensionsPanel.restoreBody' => '— ···· · ··· · / · —··— — · —· ··· ·· ——— —· ··· / —·—— ——— ··— / ·· —· ··· — ·— ·—·· ·—·· · —·· / ·— ·—· · / —· ——— — / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / ·—— · / —·—· ·— —· / —·· ——— ·—— —· ·—·· ——— ·— —·· / — ···· · —— / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · / ···· ·— —— ··——— —·— / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ———···',
			'extensionsPanel.restoreFromFile' => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / ··—· ·· ·—·· · ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / — ···· · ··· · / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · ·· ·—· / ··—· ·· ·—·· · ··· ——··—— / ——— ·—· / ··—· ——— ·—· ——· · — / — ···· · —— ———···',
			'extensionsPanel.restoreOtherCatalog' => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / —·· ·· ··—· ··—· · ·—· · —· — / · —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——· ——··—— / ··· ——— / — ···· · —·—— / ·— ·—· · / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· · ———···',
			'extensionsPanel.restoreForget' => '··—· ——— ·—· ——· · —',
			'extensionsPanel.restoreInstall' => '·· —· ··· — ·— ·—·· ·—··',
			'extensionsPanel.restoreLater' => '·—·· ·— — · ·—·',
			'extensionsPanel.restoreInstalling' => '·· —· ··· — ·— ·—·· ·—·· ·· —· ——· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· …',
			'extensionsPanel.restoreDoneTitle' => '—·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —··· ·— —·—· —·—',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => '·· —· ··· — ·— ·—·· ·—·· · —·· / ·— ——· ·— ·· —· ———··· / ${names} ·—·—·—',
			'extensionsPanel.restorePartialTitle' => '··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·· —· ··· — ·— ·—·· ·—·· · —··',
			'extensionsPanel.restoreFailed' => ({required Object names}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —· ··· — ·— ·—·· ·—·· ———··· / ${names} ·—·—·— / ·—— · / ·—— ·· ·—·· ·—·· / ——— ··—· ··—· · ·—· / — ···· · —— / ·— ——· ·— ·· —· / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—',
			'extensionsPanel.restoreBusyBody' => '— ···· · / ·— ·——· ·——· / ·· ··· / ··· — ·· ·—·· ·—·· / ··· · — — ·· —· ——· / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ··— ·——· ·—·—·— / ·—— · / ·—— ·· ·—·· ·—·· / ——— ··—· ··—· · ·—· / — ···· · ··· · / ·— ——· ·— ·· —· / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—',
			'extensionsPanel.restoreRuntimeDeadBody' => '·—— · / ·· —· ··· — ·— ·—·· ·—·· · —·· / — ···· · —— / ·— ——· ·— ·· —· ——··—— / —··· ··— — / —·—— ——— ··— ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·—— ——— ··— ·—·· —·· / —· ——— — / ··· — ·— ·—· — ·—·—·— / ·—· · ··· — ·— ·—· — ·· —· ——· / — ···· · / ·— ·——· ·——· / ··· ···· ——— ··— ·—·· —·· / —··· ·—· ·· —· ——· / — ···· · —— / —··· ·— —·—· —·— ·—·—·—',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} / ·—— ·— ··· / ·—— ·· — ···· —·· ·—· ·— ·—— —·',
			'extensionsPanel.revokedBody' => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ·—— ·· — ···· —·· ·—· · ·—— / — ···· ·· ··· / ···— · ·—· ··· ·· ——— —· ——··—— / ··· ——— / ·· — / ···· ·— ··· / —··· · · —· / —·· ·· ··· ·— —··· ·—·· · —·· ·—·—·—',
			'extensionsPanel.downloadHashMismatch' => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / —· ——— — / — ···· · / · —··— — · —· ··· ·· ——— —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / —·· · ··· —·—· ·—· ·· —··· · —·· ·—·—·—',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / ···— · ·—· ··· ·· ——— —· / ${version} / ——— ··—· / ${key} ·—·—·—',
			'extensionsPanel.catalogLinkUnknown' => '— ···· ·— — / —·—· ·— — ·— ·—·· ——— ——· / ·—·· ·· —· —·— / —·· ——— · ··· / —· ——— — / —· ·— —— · / ·— —· / · —··— — · —· ··· ·· ——— —· / ···— · ·—· ··· ·· ——— —· ·—·—·—',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => '— ···· · / —·—· ·— — ·— ·—·· ——— ——· / ···· ·— ··· / —· ——— / ·—· · ·—·· · ·— ··· · / ——— ··—· / ${key} / ——— —· / — ···· ·— — / — ·—· ·— —·—· —·— ·—·—·—',
			'extensionsPanel.installFromLink' => '·· —· ··· — ·— ·—·· ·—·· / ··—· ·—· ——— —— / ·—·· ·· —· —·—',
			'extensionsPanel.unstableReleaseWarning' => '— ···· ·· ··· / ·· ··· / ·— —· / ··— —· ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ——··—— / ·—— ···· ·· —·—· ···· / ·· — ··· / ·——· ··— —··· ·—·· ·· ··· ···· · ·—· / ···· ·— ··· / —· ——— — / —·—· ·— ·—·· ·—·· · —·· / ··—· ·· —· ·· ··· ···· · —·· ·—·—·— / ·· — / —— ·— —·—— / —— ·· ··· —··· · ···· ·— ···— · ——··—— / ·— —· —·· / ·· — / ·—— ·· ·—·· ·—·· / —·— · · ·——· / ·—· · —·—· · ·· ···— ·· —· ——· / ··— —· ··· — ·— —··· ·—·· · / ··— ·——· —·· ·— — · ··· ·—·—·—',
			'extensionsPanel.bleedingReleaseWarning' => '— ···· ·· ··· / ·· ··· / ·— / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · / ·—· · ·—·· · ·— ··· · ———··· / ·—— ——— ·—· —·— / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ··· / — ···· ·— — / —— ·— —·—— / —··· ·—· · ·— —·— / ——— ·—· / ·—·· ——— ··· · / ·· — ··· / ··· · — — ·· —· ——· ··· ·—·—·— / ·· — / ·—— ·· ·—·· ·—·· / —·— · · ·——· / ·—· · —·—· · ·· ···— ·· —· ——· / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · / ··— ·——· —·· ·— — · ··· ·—·—·—',
			'extensionsPanel.channelUnstable' => '··— —· ··· — ·— —··· ·—·· ·',
			'extensionsPanel.channelBleeding' => '—··· ·—·· · · —·· ·· —· ——·',
			'extensionsPanel.followsUnstable' => '·—· · —·—· · ·· ···— · ··· / ··— —· ··· — ·— —··· ·—·· · / ·— —· —·· / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ···',
			'extensionsPanel.followsBleeding' => '·—· · —·—· · ·· ···— · ··· / —··· ·—·· · · —·· ·· —· ——· —····— · —·· ——· · ——··—— / ··— —· ··· — ·— —··· ·—·· · / ·— —· —·· / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ···',
			'extensionsPanel.followStableAction' => '··—· ——— ·—·· ·—·· ——— ·—— / ··· — ·— —··· ·—·· · / ·—· · ·—·· · ·— ··· · ··· / ——— —· ·—·· —·——',
			'extensionsPanel.revokedBadge' => '·—· · ···— ——— —·— · —··',
			'extensionsPanel.refusedBadge' => '—·· ·· —·· / —· ——— — / ·—·· ——— ·— —··',
			'extensionsPanel.downloadNotHttps' => '— ···· ·— — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·· ··· / —· ——— — / ——— ···— · ·—· / ·— / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· ·—·—·—',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· / ··—· ——— ·—· / — ···· ·— — / · —··— — · —· ··· ·· ——— —· ·—·—·—',
			'extensionsPanel.detailsAction' => '—·· · — ·— ·· ·—·· ···',
			'extensionsPanel.installedFromFile' => '·· —· ··· — ·— ·—·· ·—·· · —·· / ··—· ·—· ——— —— / ·— / ··—· ·· ·—·· ·',
			'extensionsPanel.detailsWhatItDoes' => '·——· ·—· ——— ···— ·· —·· · ··· / ··· ··— ·——· ·——· ——— ·—· — / ··—· ——— ·—·',
			'extensionsPanel.installedPreloaded' => '·——· ·—· · —····— ·· —· ··· — ·— ·—·· ·—·· · —··',
			'extensionsPanel.hookAccount' => '·— —·—· —·—· ——— ··— —· — / ··· ·· ——· —· —····— ·· —·',
			'extensionsPanel.hookCallNotes' => '—·—· ·— ·—·· ·—·· / —· ——— — · ···',
			'extensionsPanel.hookDataFile' => '——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·—',
			'extensionsPanel.hookExport' => '· —··— ·——· ——— ·—· —',
			'extensionsPanel.hookLookup' => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ···',
			'extensionsPanel.hookScoring' => '··· —·—· ——— ·—· ·· —· ——·',
			'extensionsPanel.hookSpots' => '··· ·——· ——— — ···',
			'extensionsPanel.hookHunting' => ({required Object program}) => '···· ··— —· — ·· —· ——· / ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => '·— —·—· — ·· ···— ·— — ·· —· ——· / ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '… / ·— —· —·· / ${count} / ——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —·', other: '… / ·— —· —·· / ${count} / ——— — ···· · ·—· / · —··— — · —· ··· ·· ——— —· ···', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / · —··— — · —· ··· ·· ——— —· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·', other: '${count} / · —··— — · —· ··· ·· ——— —· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·', ), 
			'home.title' => '·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—·',
			'home.newOperation' => '—· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·',
			'home.stationCallsign' => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'home.titleOptional' => '— ·· — ·—·· · / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—',
			'home.emptyList' => '—· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ··· / —·—— · — ·—·—·— / —·—· ·—· · ·— — · / ——— —· · / — ——— / ··· — ·— ·—· — / ·—·· ——— ——· ——· ·· —· ——· ·—·—·—',
			'home.quickLookup' => '——·— ··— ·· —·—· —·— / ·—·· ——— ——— —·— ··— ·——·',
			'home.nav.operations' => '——— ·——· · ·—· ·— — ·· ——— —· ···',
			'home.nav.chase' => '—·—· ···· ·— ··· ·· —· ——·',
			'home.nav.logs' => '·—·· ——— ——· ···',
			'home.nav.maps' => '—— ·— ·——· ···',
			'home.nav.settings' => '··· · — — ·· —· ——· ···',
			'home.panels.operations' => '——— ·——· · ·—· ·— — ·· ——— —· / ·—·· ·· ··· —',
			'home.panels.operationsDescription' => '—·—— ——— ··— ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / —— ——— ··· — / ·—· · —·—· · —· — / ··—· ·· ·—· ··· — ·—·—·—',
			'home.panels.version' => '—·—· ··— ·—· ·—· · —· — / ···— · ·—· ··· ·· ——— —·',
			'home.panels.versionDescription' => '— ···· · / ···· ·— —— ··——— —·— / —— ·— ·—· —·— ——··—— / — ···· ·· ··· / ·— ·——· ·——· ’ ··· / —· ·— —— · / ·— —· —·· / ·—— ···· ·· —·—· ···· / —··· ··— ·· ·—·· —·· / —·—— ——— ··— / ·— ·—· · / ·—· ··— —· —· ·· —· ——· ·—·—·—',
			'home.toggleNav' => '··· ···· ——— ·—— / ——— ·—· / ···· ·· —·· · / — ···· · / —· ·— ···— ·· ——· ·— — ·· ——— —· / ·—·· ·— —··· · ·—·· ···',
			'home.logs.title' => '·—·· ——— ——· ···',
			'home.logs.titleFor' => '·—·· ——— ——· ··· / ··—· ——— ·—·',
			'home.logs.emptyCallsigns' => '—· ——— / ——·— ··· ——— ··· / ·—·· ——— ——· ——· · —·· / —·—— · —',
			'home.logs.emptyQsos' => ({required Object call}) => '—· ——— / ——·— ··· ——— ··· / ··—· ——— ·—· / ${call}',
			'home.logs.mapNoSelection' => '··· · ·—·· · —·—· — / ·— / ——·— ··· ——— / — ——— / ··· · · / ·· — / ——— —· / — ···· · / —— ·— ·——·',
			'home.logs.searchHint' => '··· · ·— ·—· —·—· ···· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ——— ·—· / —· ·— —— ·',
			'home.logs.noSearchMatches' => '—· ——— / ——·— ··· ——— ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ····',
			'home.logs.titleAll' => '·— ·—·· ·—·· / ·—·· ——— ——· ···',
			'home.logs.allCallsigns' => '·— ·—·· ·—·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···',
			'home.logs.noOperation' => '—· ——— — / ·——· ·— ·—· — / ——— ··—· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'home.logs.unsavedTitle' => '··— —· ··· ·— ···— · —·· / —·—· ···· ·— —· ——· · ···',
			'home.logs.unsavedBody' => '— ···· ·· ··· / ——·— ··· ——— / ···· ·— ··· / —·—· ···· ·— —· ——· · ··· / —·—— ——— ··— / ···· ·— ···— · —· ’ — / ··· ·— ···— · —·· ·—·—·—',
			'home.logs.pendingDeleteBody' => '— ···· ·· ··· / ——·— ··· ——— / ·· ··· / —— ·— ·—· —·— · —·· / ··—· ——— ·—· / —·· · ·—·· · — ·· ——— —· ·—·—·—',
			'home.logs.editGone' => '—· ——— — / ··· ·— ···— · —·· ———··· / — ···· ·— — / ——·— ··· ——— / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / ·· —· / — ···· ·· ··· / ·—·· ——— ——· ·—·—·—',
			'home.logs.discard' => '—·· ·· ··· —·—· ·— ·—· —··',
			'home.logs.sheet.callsigns' => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···',
			'home.logs.sheet.groupBy' => '——· ·—· ——— ··— ·——· / —··· —·——',
			'home.logs.sheet.period' => '— ·· —— · / ·——· · ·—· ·· ——— —··',
			'home.logs.groupBy.none' => '—· ——— — / ——· ·—· ——— ··— ·——· · —··',
			'home.logs.groupBy.date' => '—·· ·— — ·',
			'home.logs.groupBy.dx' => '—·· —··—',
			'home.logs.groupBy.unknownContinent' => '··— —· —·— —· ——— ·—— —· / —·—· ——— —· — ·· —· · —· —',
			'home.logs.groupBy.unknownEntity' => '··— —· —·— —· ——— ·—— —· / · —· — ·· — —·——',
			'home.logs.groupBy.unknownDate' => '—· ——— / —·· ·— — ·',
			'home.logs.period.thisMonth' => '— ···· ·· ··· / —— ——— —· — ····',
			'home.logs.period.last3Months' => '·—·· ·— ··· — / ···—— / —— ——— —· — ···· ···',
			'home.logs.period.thisYear' => '— ···· ·· ··· / —·—— · ·— ·—·',
			'home.logs.period.lastYear' => '·—·· ·— ··· — / —·—— · ·— ·—·',
			'home.logs.period.allTime' => '·— ·—·· ·—·· / — ·· —— ·',
			'home.logs.period.custom' => '—·—· ··— ··· — ——— —— / ·—· ·— —· ——· ·',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => '·· —· / ${span}',
			'home.logs.periodTitle.custom' => '—·—· ··— ··· — ——— —— / ·—· ·— —· ——· ·',
			'home.logs.columns.date' => '—·· ·— — ·',
			'home.logs.columns.time' => '— ·· —— ·',
			'home.logs.columns.freq' => '··—· ·—· · ——·— ··— · —· —·—· —·——',
			'home.logs.columns.mode' => '—— ——— —·· ·',
			'home.logs.columns.call' => '—·—· ·— ·—·· ·—··',
			'home.logs.columns.name' => '—· ·— —— ·',
			'home.logs.columns.station' => '··· — ·— — ·· ——— —·',
			'home.logs.columns.band' => '—··· ·— —· —··',
			'home.logs.columns.sent' => '··· · —· —',
			'home.logs.columns.rcvd' => '·—· —·—· ···— —··',
			'home.logs.columns.grid' => '——· ·—· ·· —··',
			'home.logs.columns.state' => '··· — ·— — ·',
			'home.logs.columns.country' => '—·—· ——— ··— —· — ·—· —·——',
			'home.logs.columns.refs' => '·—· · ··—· ···',
			'home.logs.panels.qsos' => '——·— ··· ——— / ·—·· ——— ——·',
			'home.logs.panels.qsosDescription' => '— ···· · / ··· · ·—·· · —·—· — · —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ·————· ··· / ——·— ··· ——— ··· ——··—— / ·— —·—· ·—· ——— ··· ··· / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—',
			'home.logs.panels.info' => '·· —· ··—· ———',
			'home.logs.panels.infoDescription' => '— ——— — ·— ·—·· / ——·— ··· ——— / —·—· ——— ··— —· — ——··—— / ——— ·—· / — ···· · / ··· · ·—·· · —·—· — · —·· / ——·— ··· ——— ·————· ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· ·—·—·—',
			'home.logs.panels.map' => '—— ·— ·——·',
			'home.logs.panels.mapDescription' => '— ···· · / ··· · ·—·· · —·—· — · —·· / ——·— ··· ——— ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —· ·—·—·—',
			'home.logs.import.callsigns' => ({required Object calls}) => '—·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ———··· / ${calls}',
			'home.logs.import.skippedOne' => '·———— / ·—· · —·—· ——— ·—· —·· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —··',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} / ·—· · —·—· ——— ·—· —·· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —··',
			'home.logs.import.readingTitle' => '·—· · ·— —·· ·· —· ——· / ·— —·· ·· ··—· / ··—· ·· ·—·· · …',
			'home.logs.import.checkingTitle' => '—·—· ···· · —·—· —·— ·· —· ——· / ··—· ——— ·—· / —·· ··— ·——· ·—·· ·· —·—· ·— — · ··· …',
			'home.logs.import.importingTitle' => '·· —— ·——· ——— ·—· — ·· —· ——· / ——·— ··· ——— ··· …',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} / —·— —···',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} / ——— ··—· / ${total} / —·—· ···· · —·—· —·— · —··',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} / ·· —— ·——· ——— ·—· — · —·· ——··—— / ——— ··— — / ——— ··—· / ${total}',
			'chase.operatorPrefix' => '——— ·——·',
			'chase.chasing' => '—·—· ···· ·— ··· ·· —· ——·',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} / ·—··· / ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first} ——··—— / ${second} / ·—··· / —— ——— ·—· ·',
			'chase.station.title' => '—·—· ···· ·— ··· ·· —· ——· / ··· — ·— — ·· ——— —·',
			'chase.station.stationLabel' => '··· — ·— — ·· ——— —· ———···',
			'chase.station.operatorLabel' => '——— ·——· ———···',
			'chase.station.noLocation' => '—· ——— / ·—·· ——— —·—· ·— — ·· ——— —·',
			'chase.periodInline.today' => '— ——— —·· ·— —·——',
			'chase.periodInline.thisWeek' => '— ···· ·· ··· / ·—— · · —·—',
			'chase.periodInline.last14Days' => '·· —· / — ···· · / ·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···',
			'chase.periodInline.thisMonth' => '— ···· ·· ··· / —— ——— —· — ····',
			'chase.periodStats.today' => '··· — ·— — ··· / ··—· ——— ·—· / — ——— —·· ·— —·——',
			'chase.periodStats.thisWeek' => '··· — ·— — ··· / ··—· ——— ·—· / — ···· ·· ··· / ·—— · · —·—',
			'chase.periodStats.last14Days' => '··· — ·— — ··· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···',
			'chase.periodStats.thisMonth' => '··· — ·— — ··· / ··—· ——— ·—· / — ···· ·· ··· / —— ——— —· — ····',
			'chase.period.today' => '— ——— —·· ·— —·——',
			'chase.period.thisWeek' => '— ···· ·· ··· / ·—— · · —·—',
			'chase.period.last14Days' => '·—·· ·— ··· — / ·———— ····— / —·· ·— —·—— ···',
			'chase.period.thisMonth' => '— ···· ·· ··· / —— ——— —· — ····',
			'chase.goals.title' => '—·—· ···· ·— ··· ·· —· ——· / ——· ——— ·— ·—·· ···',
			'chase.goals.remove' => ({required Object name}) => '··· — ——— ·——· / —·—· ···· ·— ··· ·· —· ——· / ${name}',
			'chase.goals.extensionsTitle' => '—— ——— ·—· · / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— ···',
			'chase.panels.logging' => '——·— ··· ——— ···',
			'chase.panels.loggingDescription' => '·—·· ——— ——· ——· ·· —· ——· / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— —··· ——— ···— · / — ···· · / ——·— ··· ——— ··· / —·—· ···· ·— ··· · —·· / ·· —· / — ···· · / ·——· · ·—· ·· ——— —·· ·—·—·—',
			'chase.panels.info' => '·· —· ··—· ———',
			'chase.panels.infoDescription' => '— ···· · / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —·· ——··—— / ——— ·—· / — ···· · / ·——· · ·—· ·· ——— —·· ·————· ··· / ··· — ·— — ··· ·—·—·—',
			'chase.panels.spots' => '··· ·——· ——— — ···',
			'chase.panels.spotsDescription' => '··· — ·— — ·· ——— —· ··· / ··· ·——· ——— — — · —·· / ——— —· / — ···· · / ·— ·· ·—· ——··—— / ·—· · ·— —·· —·—— / — ——— / —·—· ···· ·— ··· · ·—·—·—',
			'chase.panels.map' => '—— ·— ·——·',
			'chase.panels.mapDescription' => '— ···· · / ·——· · ·—· ·· ——— —·· ·————· ··· / ——·— ··· ——— ··· / ·— —· —·· / — ···· · / ··· — ·— — ·· ——— —· / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —·· ·—·—·—',
			'chase.claims.checking' => '—·—· ···· · —·—· —·— ·· —· ——· / ——·— ··· ——— ··· / ··—· ——— ·—· / —·—· ···· ·— ··· ·· —· ——·',
			'chase.claims.rebuilding' => ({required Object program}) => '—·—· ···· · —·—· —·— ·· —· ——· / — ···· · / ·—·· ——— ——· / ··—· ——— ·—· / ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} / ——— ··—· / ${total} / ——·— ··· ——— ···',
			'chase.notice.newRef' => ({required Object program}) => '—· · ·—— / ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program}',
			'chase.notice.newBand' => ({required Object program}) => '—· · ·—— / ${program} / —··· ·— —· —··',
			'chase.notice.newBandGuess' => ({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program} / —··· ·— —· —··',
			'chase.notice.newMode' => ({required Object program}) => '—· · ·—— / ${program} / —— ——— —·· ·',
			'chase.notice.newModeGuess' => ({required Object program}) => '·——· ·—· ——— —··· ·— —··· ·—·· —·—— / —· · ·—— / ${program} / —— ——— —·· ·',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} / ··— —· —·—· ——— —· ··—· ·· ·—· —— · —··',
			'chase.alerts.title' => '·— ·—·· · ·—· — ···',
			'chase.alerts.newRef' => '—· · ·—— / ·—· · ··—· · ·—· · —· —·—· ·',
			'chase.alerts.newBand' => '—· · ·—— / —··· ·— —· —··',
			'chase.alerts.newMode' => '—· · ·—— / —— ——— —·· ·',
			'chase.alerts.unconfirmed' => '··— —· —·—· ——— —· ··—· ·· ·—· —— · —··',
			'chase.checklists' => '—·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· · ··· ···',
			'chase.imports.importFrom' => ({required Object label}) => '·· —— ·——· ——— ·—· — / ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => '·· —— ·——· ——— ·—· — / ${file} / ·— ···',
			'chase.imports.dropHint' => '—·· ·—· ——— ·——· / ·— / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — / ·· — / ·· —· — ——— / ·— / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— ——',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => '·· —— ·——· ——— ·—· — · —·· / ${count} / ${program} / · —· — ·—· ·· · ··· / ··—· ·—· ——— —— / ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => '·· —— ·——· ——— ·—· — · —·· / ${count} / ${program} / · —· — ·—· ·· · ··· / ··—· ·—· ——— —— / ${file} ——··—— / ··· —·— ·· ·——· ·——· · —·· / ${skipped} / ·· — / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —··',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} / ···· ·— ··· / —· ——— — ···· ·· —· ——· / ${program} / —·—· ·— —· / ·· —— ·——· ——— ·—· —',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· / ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· / ·— —· —·—— / ——— ··—· / — ···· · / ${skipped} / ·—· · —·—· ——— ·—· —·· ··· / ·· —· / ${file}',
			'chase.imports.noProgram' => ({required Object file}) => '—· ——— / —·—· ···· ·— ··· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— / ·· —— ·——· ——— ·—· — ··· / ${file}',
			'dialogs.operationDetails' => '——— ·——· · ·—· ·— — ·· ——— —· / —·· · — ·— ·· ·—·· ···',
			'dialogs.activities' => '·— —·—· — ·· ···— ·· — ·· · ···',
			'dialogs.stationCallsign' => '··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'dialogs.multiStationIdentifier' => '—— ··— ·—·· — ·· —····— ··· — ·— — ·· ——— —· / ·· —·· · —· — ·· ··—· ·· · ·—· / —·——· —· ··— —— —··· · ·—· ··· / ——— —· ·—·· —·—— —·——·—',
			'dialogs.notes' => '—· ——— — · ···',
			'dialogs.deleteOperationTitle' => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·',
			'dialogs.purgeTestsTitle' => '·——· ··— ·—· ——· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ···',
			'dialogs.purgeTestsBody' => '— ···· ·· ··· / ·——· · ·—· —— ·— —· · —· — ·—·· —·—— / —·· · ·—·· · — · ··· / — ···· · ··· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·— —· —·· / — ···· · ·· ·—· / ——·— ··· ——— ··· ·—·—·— / ·· — / —·—· ·— —· —· ——— — / —··· · / ··— —· —·· ——— —· · ·—·—·—',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·——· ·—·· ··— ··· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — / — ···· ·— — / —··· · ·—·· ——— —· ——· ··· / — ——— / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—', other: '·——· ·—·· ··— ··· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / — ···· ·— — / —··· · ·—·· ——— —· ——· / — ——— / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—', ), 
			'dialogs.purgeTestsAction' => '·——· ··— ·—· ——· ·',
			'dialogs.syncAllTitle' => '·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / ·—·· ——— ——· ··——··',
			'dialogs.syncAllBody' => ({required Object qsos}) => '··· —·—— —· —·—· ·— ·—·· ·—·· / —··· ·— —·—· —·— ··· / ··— ·——· / ·— —· —·· / —·—· ·—·· · ·— ·—· ··· / ${qsos} / ··—· ·—· ——— —— / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / — ···· · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / ·—·· ——— ——· / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / — ···· · / ··· · ·—· ···— · ·—· ·—·—·— / — ···· · / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ·· —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / —·· ·— — ·— —··· ·— ··· · ·—·—·—',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${n} / ——·— ··· ——— / ···· ·— ··· / —· ——— — / —··· · · —· / ··· —·—— —· —·—· · —·· / —·—— · — / — / — ···· · / ··· · ·—· ···— · ·—· / —· · ···— · ·—· / ·—· · —·—· · ·· ···— · —·· / ·· — ——··—— / ·— —· —·· / ·· — / ·—— ·· ·—·· ·—·· / —· ——— — / —·—· ——— —— · / —··· ·— —·—· —·— ·—·—·—', other: '${n} / ——·— ··· ——— ··· / ···· ·— ···— · / —· ——— — / —··· · · —· / ··· —·—— —· —·—· · —·· / —·—— · — / — / — ···· · / ··· · ·—· ···— · ·—· / —· · ···— · ·—· / ·—· · —·—· · ·· ···— · —·· / — ···· · —— ——··—— / ·— —· —·· / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —· ——— — / —·—· ——— —— · / —··· ·— —·—· —·— ·—·—·—', ), 
			'dialogs.syncAllAction' => '·—— ·· ·——· · / ·— —· —·· / ·—· · ··· —·—— —· —·—·',
			'dialogs.receivedPurgesTitle' => '— · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·—· · —— ——— ···— · —·· / · ·—·· ··· · ·—— ···· · ·—· ·',
			'dialogs.receivedPurgesBody' => '— ···· · ··· · / ·—— · ·—· · / —·· · ·—·· · — · —·· / ·— ··· / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· · ·—·—·— / ·—· · —— ——— ···— · / — ···· · —— / ···· · ·—· · / — ——— ——— ··——·· / — ···· ·· ··· / ·——· · ·—· —— ·— —· · —· — ·—·· —·—— / —·· · ·—·· · — · ··· / — ···· · —— / ·— —· —·· / — ···· · ·· ·—· / ——·— ··· ——— ··· ——··—— / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ··— —· —·· ——— —· · ·—·—·—',
			'dialogs.receivedPurgesAction' => '·—· · —— ——— ···— ·',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => '·· —· ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ———··· / ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => '·· —· ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ———··· / ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} / ···· ·— ··· / ——— ·——· · ·—· ·— — · —·· / ··· ——— / ··—· ·— ·—· ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· ·—·—·—',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => '—· ——— / ——— ·——· · ·—· ·— — ——— ·—· / ·—· · —·—· ——— ·—· —·· · —·· / ··· ——— / ··—· ·— ·—· ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· ·—·—·—',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / —·—· ——— —· — ·— —·—· — ··· / —··· —·—— / ${calls} ·—·—·— / ${typed} / ·—— ·· ·—·· ·—·· / ——— —· ·—·· —·—— / —··· · / ·—· · —·—· ——— ·—· —·· · —·· / ··—· ——— ·—· / —· · ·—— / ——— —· · ··· ·—·—·—',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·— ·—·· ··· ——— / ·—· · —·—· ——— ·—· —·· / ${typed} / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ——— ··—· / — ···· · / —·—· ——— —· — ·— —·—· — / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —··', other: '·— ·—·· ··· ——— / ·—· · —·—· ——— ·—· —·· / ${typed} / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ——— ··—· / ·— ·—·· ·—·· / ${count} / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —··', ), 
			'dialogs.callChange.operatorSeveralStations' => '·—— ···· · —· / ··— ··· ·· —· ——· / —— ··— ·—·· — ·· ·——· ·—·· · / ··· — ·— — ·· ——— —· ··· / ——— ···— · ·—· / — ···· · / ·— ·· ·—· ——··—— / — ···· · ·—· · ·————· ··· / —· ——— / ··· ··— ·——· ·——· ——— ·—· — / ··—· ——— ·—· / ··· · ·——· ·— ·—· ·— — · / ——— ·——· · ·—· ·— — ——— ·—· ···',
			'dialogs.callChange.contactsUnreadable' => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / —·—· ——— —· — ·— —·—· — ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / —·—· ···· ·— —· ——· ·· —· ——· / ·— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ···· · ·—· · / ·—— ——— —· ·————· — / ——— ··—· ··—· · ·—· / — ——— / ··— ·——· —·· ·— — · / — ···· · ——',
			'dialogs.callChange.restampFailed' => ({required Object error}) => '— ···· · / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —·· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··— ·——· —·· ·— — · —·· ——··—— / ··· ——— / —· ——— / —·—· ···· ·— —· ——· · ··· / ·—— · ·—· · / —— ·— —·· · ———··· / ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} / ——— ··—· / ${planned} / —·—· ——— —· — ·— —·—· — ··· / ·—— · ·—· · / ··— ·——· —·· ·— — · —·· / — / — ···· · / ·—· · ··· — / ·— ·—· · / —· ——— / ·—·· ——— —· ——· · ·—· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.deletedReadOnly' => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / —·· · ·—·· · — · —·· ·—·—·— / ··— —· —·· · ·—·· · — · / ·· — / — ——— / ·—·· ——— ——· / ——— ·—· / —— ·— —·— · / —·—· ···· ·— —· ——· · ··· ·—·—·—',
			'operation.tabs.qsos' => ({required Object count}) => '${count} / ——·— ··· ——— ···',
			'operation.tabs.info' => '·· —· ··—· ———',
			'operation.tabs.spots' => '··· ·——· ——— — ···',
			'operation.tabs.map' => '—— ·— ·——·',
			'operation.tabs.qsosPlain' => '——·— ··· ——— ···',
			'operation.tabs.clock' => '—·—· ·—·· ——— —·—· —·—',
			'operation.tabs.weather' => '·—— · ·— — ···· · ·—·',
			'operation.tabs.website' => '·—— · —··· / ··· ·· — ·',
			'operation.tabs.remoteScreen' => '·—· · —— ——— — · / ··· —·—· ·—· · · —·',
			'operation.tabs.solar' => '··· ——— ·—·· ·— ·—·',
			'operation.tabs.radio' => '·—· ·— —·· ·· ———',
			'operation.tabs.summaries' => '——— ·——· · ·—· ·— — ·· ——— —· / ··· ··— —— —— ·— ·—· ·· · ···',
			'operation.positions.nobodyYet' => '—· ——— / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —· ··· / ·— ·—· · / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / —·—— · — ·—·—·—',
			'operation.positions.positionLabel' => ({required Object number}) => '·——· ——— ··· ———··· / ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => '——— ·——· ———··· / ${call}',
			'operation.positions.unnamedPosition' => '·— —· ——— — ···· · ·—· / ·——· ——— ··· ·· — ·· ——— —·',
			'operation.positions.thisDevice' => '——— ··— ·—· / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —·',
			'operation.positions.nameIn' => '·· —·',
			'operation.positions.panelTitle' => '·——· ——— ··· ·· — ·· ——— —· ···',
			'operation.positions.panelDescription' => '·—— ···· ·— — / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· —· ——· / ·——· ——— ··· ·· — ·· ——— —· / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / ·—·· ——— ——· ——· ·· —· ——· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—',
			'operation.stationCallsignNone' => '—· ——— / ··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'operation.titleNone' => '—· ——— / — ·· — ·—·· ·',
			'operation.deleteOperation' => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.loggingControlsStale' => '·— —·—· — ·· ···— ·· — —·—— / ··—· ·· · ·—·· —·· ··· / —— ·— —·—— / —··· · / ——— ··— — / ——— ··—· / —·· ·— — · / — / ·—· · ——— ·——· · —· / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· / — ——— / ·—· · ··—· ·—· · ··· ···· / — ···· · ——',
			'operation.locationNone' => '—· ——— — / ··· · —',
			'operation.generalOperation' => '——· · —· · ·—· ·— ·—·· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.titleFor' => ({required Object value}) => '··—· ——— ·—· / ${value}',
			'operation.titleAt' => ({required Object value}) => '·— — / ${value}',
			'operation.segmentNow' => ({required Object description}) => '—· ——— ·—— / ${description}',
			'operation.testOperationSuffix' => '— · ··· — ·· —· ——·',
			'operation.menu.showRstFields' => '··· ···· ——— ·—— / ·—· ··· — / ··—· ·· · ·—·· —·· ···',
			'operation.menu.showStateField' => '··· ···· ——— ·—— / ··· — ·— — · / ··—· ·· · ·—·· —··',
			'operation.menu.showGridField' => '··· ···· ——— ·—— / ——· ·—· ·· —·· / ··—· ·· · ·—·· —··',
			'operation.menu.showDeletedQsos' => '··· ···· ——— ·—— / —·· · ·—·· · — · —·· / ——·— ··· ——— ···',
			'operation.menu.showDeletedOps' => '··· ···· ——— ·—— / —·· · ·—·· · — · —·· / ——— ·——· · ·—· ·— — ·· ——— —· ···',
			'operation.menu.showQsoNumbers' => '··· ···· ——— ·—— / ——·— ··· ——— / —· ··— —— —··· · ·—· ···',
			'operation.menu.lookupAllQsos' => '·—·· ——— ——— —·— ··— ·——· / ·— ·—·· ·—·· / ——·— ··· ——— ···',
			'operation.menu.loggingSettingsTitle' => '·—·· ——— ——· ——· ·· —· ——· / ··· · — — ·· —· ——· ···',
			'operation.menu.mapSettingsTitle' => '—— ·— ·——· / ··· · — — ·· —· ——· ···',
			'operation.menu.actionsSection' => '·— —·—· — ·· ——— —· ···',
			'operation.layout.title' => '·— —·· —·· / ·— / ·——· ·— —· · ·—··',
			'operation.layout.availableSection' => '·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·——· ·— —· · ·—·· ···',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} / ··· · — — ·· —· ——· ···',
			'operation.layout.panelSettingsAction' => '·——· ·— —· · ·—·· / ··· · — — ·· —· ——· ···',
			'operation.layout.viewName' => '——— ·——· · ·—· ·— — ·· ——— —· / ···— ·· · ·——',
			'operation.layout.viewOptions' => '···— ·· · ·—— / ·—·· ·— —·—— ——— ··— — / ——— ·——· — ·· ——— —· ···',
			'operation.layout.viewTitleBuiltIn' => '— ···· ·· ··· / ···— ·· · ·—— / ·· ··· / —··· ··— ·· ·—·· — / ·· —· — ——— / — ···· · / ·— ·——· ·——· ——··—— / ·— —· —·· / ··· ——— / ·· ··· / ·· — ··· / —· ·— —— ·',
			'operation.layout.resetOptions' => '·—· · ··· — ——— ·—· · / —·· · ··—· ·— ··— ·—·· — ···',
			'operation.layout.removePane' => '·—· · —— ——— ···— ·',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '·—· · ··· — ——— ·—· · / ${panel} / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ··· ··——··',
			'operation.layout.resetPaneConfirmBody' => '·· — ··· / — ·· — ·—·· · ——··—— / ···· · ·— —·· · ·—· / ·— —· —·· / ··· ·· ——·· · / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·— / — ···· · / ·—· · ··· — / ——— ··—· / — ···· · / ·—·· ·— —·—— ——— ··— — / ··· — ·— —·—— ··· / ·— ··· / ·· — / ·· ··· ·—·—·—',
			'operation.layout.resetViewConfirm' => '·—· · ··· — ——— ·—· · / — ···· ·· ··· / ···— ·· · ·—— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — / ·—·· ·— —·—— ——— ··— — ··——··',
			'operation.layout.resetViewConfirmBody' => '— ···· · / ·——· ·— —· · ·—·· ··· / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · ·· ·—· / —·· · ··—· ·— ··— ·—·· — / ·— ·—· ·—· ·— —· ——· · —— · —· — ——··—— / ·— —· —·· / — ···· · / ···— ·· · ·—— ·————· ··· / ——— ·——· — ·· ——— —· ··· / ·— —· —·· / · ···— · ·—· —·—— / ·——· ·— —· · ·—·· ·————· ··· / ——· ——— / —··· ·— —·—· —·— / — ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·—',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} / ·—·· ·— —·—— ——— ··— — / ··· · — — ·· —· ——· ···',
			'operation.layout.paneTitle' => '— ·· — ·—·· ·',
			'operation.layout.paneShowHeader' => '··· ···· ——— ·—— / ···· · ·— —·· · ·—·',
			'operation.layout.paneShowHeaderTabset' => '·— ·—·· ·—— ·— —·—— ··· / ··· ···· ——— ·—— —· / ·—— ···· ·· ·—·· · / — ···· ·· ··· / ·——· ·— —· · / ··· ···· ·— ·—· · ··· / ·— / ——· ·—· ——— ··— ·——· / — / — ···· · / ···· · ·— —·· · ·—· / ·· ··· / ···· ——— ·—— / — ···· · / ——— — ···· · ·—· ··· / ·— ·—· · / ·—· · ·— —·—· ···· · —··',
			'operation.layout.paneInherit' => '··· ·— —— · / ·— ··· / — ···· · / ·— ·——· ·——·',
			'operation.layout.searchHint' => '··· · ·— ·—· —·—· ···· / ·——· ·— —· · ·—·· ···',
			'operation.layout.noPanelsMatch' => '—· ——— / ·——· ·— —· · ·—·· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ·—·—·—',
			'operation.layout.nothingToAdd' => '— ···· ·· ··· / ···— ·· · ·—— / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / ·— ·—·· ·—·· / ·——· ——— ··· ··· ·· —··· ·—·· · / ·——· ·— —· · ·—·· ···',
			'operation.layout.addPanel' => ({required Object panel}) => '·— —·· —·· / ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => '·——· ·—· · ···— ·· · ·—— / ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => '· —··— — · —· ··· ·· ——— —· / ·—··—· ${name} ·—··—· / ·· ··· / —— ·· ··· ··· ·· —· ——·',
			'operation.layout.missingExtensionEnable' => '· —· ·— —··· ·—·· ·',
			'operation.layout.missingExtensionInstall' => '·· —· ··· — ·— ·—·· ·—·· …',
			'operation.layout.missingExtensionWontRun' => '— ···· ·· ··· / ···— · ·—· ··· ·· ——— —· / ·—— ——— —· ’ — / ·—· ··— —· ·—·—·— / ··— ·——· —·· ·— — · / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—',
			'operation.layout.missingExtensionUnavailable' => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· ·· ··· / ·— ·——· ·——·',
			'operation.layout.missingExtensionNotInCatalog' => '—· ——— — / ·· —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——·',
			'operation.layout.missingExtensionCatalogUnreachable' => '—·—· ——— ··— ·—·· —·· —· ’ — / ·—· · ·— —·—· ···· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —·',
			'operation.layout.missingExtensionFailed' => '— ···· ·— — / —·· ·· —·· —· ’ — / ·—— ——— ·—· —·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —·',
			'operation.layout.previewUnavailable' => '— ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ·——· ·—· · ···— ·· · ·—— / ·· —— ·— ——· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··· ···· ——— ·—— —· ·—·—·—',
			'operation.layout.nestedPaneTitle' => '—— ——— ·—· ·',
			'operation.layout.layouts.defaultName' => '—·· · ··—· ·— ··— ·—·· —',
			'operation.layout.layouts.untitledName' => ({required Object number}) => '·—·· ·— —·—— ——— ··— — / ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => '·—·· ·— —·—— ——— ··— — ———··· / ${name}',
			'operation.layout.layouts.menuNew' => '—· · ·—— …',
			'operation.layout.layouts.menuExport' => '· —··— ·——· ——— ·—· — …',
			'operation.layout.layouts.menuImport' => '·· —— ·——· ——— ·—· — …',
			'operation.layout.layouts.menuTitle' => '·—·· ·— —·—— ——— ··— — ···',
			'operation.layout.layouts.newTitle' => '—· · ·—— / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.editTitle' => '· —·· ·· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.edit' => '· —·· ·· —',
			'operation.layout.layouts.duplicateCurrent' => '—·· ··— ·——· ·—·· ·· —·—· ·— — · / —·—· ··— ·—· ·—· · —· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.startFromDefault' => '··· — ·— ·—· — / ··—· ·—· ——— —— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.nameLabel' => '—· ·— —— ·',
			'operation.layout.layouts.descriptionLabel' => '—·· · ··· —·—· ·—· ·· ·——· — ·· ——— —·',
			'operation.layout.layouts.create' => '—·—· ·—· · ·— — ·',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => '··· ·— ···— · / —·—· ···· ·— —· ——· · ··· / — ——— / ·—··—· ${name} ·—··—· ··——··',
			'operation.layout.layouts.leaveEditBody' => '— ···· ·· ··· / ·—·· ·— —·—— ——— ··— — / ···· ·— ··· / —·—· ···· ·— —· ——· · ··· / —·—— ——— ··— / ···· ·— ···— · —· ’ — / ··· ·— ···— · —·· ·—·—·—',
			'operation.layout.layouts.discard' => '—·· ·· ··· —·—· ·— ·—· —··',
			'operation.layout.layouts.deleteTitle' => '—·· · ·—·· · — · / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— — ··——··',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => '·— ·—· · / —·—— ——— ··— / ··· ··— ·—· · / —·—— ——— ··— / ·—— ·— —· — / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ·—··—· ${name} ·—··—· / ·—·· ·— —·—— ——— ··— — ··——··',
			'operation.layout.layouts.exportTitle' => '· —··— ·——· ——— ·—· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.exportPick' => '·——· ·— —· · ·—·· ··· / — ——— / · —··— ·——· ——— ·—· —',
			'operation.layout.layouts.tabSet' => '— ·— —··· / ··· · —',
			'operation.layout.layouts.exportAction' => '· —··— ·——· ——— ·—· —',
			'operation.layout.layouts.exported' => ({required Object location}) => '·—·· ·— —·—— ——— ··— — / ··· ·— ···— · —·· / — ——— / ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / · —··— ·——· ——— ·—· — / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}',
			'operation.layout.layouts.importTitle' => '·· —— ·——· ——— ·—· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => '—— ·— —·· · / ··—· ——— ·—· / — ···· · / ${view} / ···— ·· · ·—— ———··· / ·——· ·— —· · ·—·· ··· / ——— —· ·—·· —·—— / — ···· ·— — / ···— ·· · ·—— / ···· ·— ··· / ·— ·—· · / ·—·· · ··—· — / ——— ··— — ·—·—·—',
			'operation.layout.layouts.viewHome' => '···· ——— —— ·',
			'operation.layout.layouts.viewOperation' => '——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.layout.layouts.viewLogs' => '·—·· ——— ——· ···',
			'operation.layout.layouts.viewChase' => '—·—· ···· ·— ··· ·· —· ——·',
			'operation.layout.layouts.importAsNew' => '·— ··· / ·— / —· · ·—— / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.importReplace' => '·· —· / ·——· ·—·· ·— —·—· · / ——— ··—· / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.importAdd' => '·— —·· —·· · —·· / — ——— / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.importAddHint' => '— ···· · / ·——· ·— —· · ·—·· ··· / ·— ·—· ·—· ·· ···— · / ·· —· / ·— / —· · ·—— / —·—· ——— ·—·· ··— —— —· / ——— —· / — ···· · / ·—· ·· ——· ···· — ·—·—·—',
			'operation.layout.layouts.importPick' => '·——· ·— —· · ·—·· ··· / — ——— / ·· —— ·——· ——— ·—· —',
			'operation.layout.layouts.importReplaceSettings' => '·—· · ·——· ·—·· ·— —·—· · / — ···· · / ··· · — — ·· —· ——· ··· / ——— ··—· / ·——· ·— —· · ·—·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ··· · — / ··— ·——· / ···· · ·—· ·',
			'operation.layout.layouts.importAction' => '·· —— ·——· ——— ·—· —',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} / ·· ··· —· ·————· — / ·— / ·—·· ·— —·—— ——— ··— — / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ·—· · ·— —·· ———··· / ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => '— ···· · / — · —··— — / ·· ··· —· ’ — / ···— ·— ·—·· ·· —·· / —·—— ·— —— ·—·· / —·——· ·—·· ·· —· · / ${line} —·——·—',
			'operation.layout.layouts.problemNotLayoutFile' => '·· — / ·· ··· —· ’ — / ·— / ···· ·— —— ··——— —·— / ·—·· ·— —·—— ——— ··— — / ··—· ·· ·—·· ·',
			'operation.layout.layouts.problemNewerVersion' => '·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——·',
			'operation.layout.layouts.problemNoArrangement' => '·· — / ···· ——— ·—·· —·· ··· / —· ——— / ·— ·—· ·—· ·— —· ——· · —— · —· —',
			'operation.layout.layouts.problemMalformed' => '·——· ·— ·—· — / ——— ··—· / ·· — / —·· ——— · ··· —· ’ — / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· —— ·— —',
			'operation.layout.layouts.problemTooLarge' => '·· — / ·· ··· / — ——— ——— / ·—·· ·— ·—· ——· ·',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ——— ·——· · —· / — ···· · / ··—· ·· ·—·· · ———··· / ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·· —— ·——· ——— ·—· — / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·— —·—— ——— ··— — ———··· / ${error}',
			'operation.layout.layouts.importNothing' => '—· ——— / ·——· ·— —· · ·—·· / ·——· ·· —·—· —·— · —·· ——··—— / ··· ——— / —· ——— — ···· ·· —· ——· / ·—— ·— ··· / ·· —— ·——· ——— ·—· — · —·· ·—·—·—',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => '·—·· · ··—· — / ——— ··— — ———··· / ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => '—·— · ·——· — / ${panels} ———··· / — ···· · / ··· —— ·— ·—·· ·—·· —····— ··· —·—· ·—· · · —· / ·— ·—· ·—· ·— —· ——· · —— · —· — / —·—· ·— —· ’ — / —·· ——— / ·—— ·· — ···· ——— ··— — / ·· — ·—·—·—',
			'operation.layout.layouts.notOffered' => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· ·· ··· / ···— ·· · ·——',
			'operation.layout.layouts.alreadyPlaced' => '·— ·—·· ·—· · ·— —·· —·—— / ·· —· / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => '—· · · —·· ··· / ${name}',
			'operation.layout.layouts.listRecoveredTitle' => '·—·· ·— —·—— ——— ··— — / —· ·— —— · ··· / —·—· ——— ··— ·—·· —·· —· ’ — / —··· · / ·—· · ·— —··',
			'operation.layout.layouts.listRecoveredBody' => '— ···· ·· ··· / ···— ·· · ·—— ’ ··· / ·—·· ·· ··· — / ——— ··—· / ·—·· ·— —·—— ——— ··— — ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ·—·—·— / · ···— · ·—· —·—— / ·—·· ·— —·—— ——— ··— — / ·· ··· / ··· — ·· ·—·· ·—·· / ···· · ·—· · ——··—— / —· ··— —— —··· · ·—· · —·· / ·· —· / ·——· ·—·· ·— —·—· · / ——— ··—· / ·· — ··· / —· ·— —— · ·—·—·—',
			'operation.layout.editLayout' => '· —·· ·· — / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.saveLayout' => '··· ·— ···— · / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.revertLayout' => '—·· ·· ··· —·—· ·— ·—· —·· / ·—·· ·— —·—— ——— ··— — / —·—· ···· ·— —· ——· · ···',
			'operation.layout.done' => '—·· ——— —· ·',
			'operation.layout.layoutUnreadableTitle' => '·—·· ·— —·—— ——— ··— — / —·—· ——— ··— ·—·· —·· —· ·————· — / —··· · / ·—· · ·— —··',
			'operation.layout.layoutUnreadableBody' => '—·—— ——— ··— ·—· / ··· ·— ···— · —·· / ·—·· ·— —·—— ——— ··— — / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·— ·—· ·—· ·— —· ——· · —— · —· — / ·· ··· / ··· ···· ——— ·—— ·· —· ——· / ·· —· ··· — · ·— —·· ·—·—·— / ·· — / ·—— ——— —· ·————· — / —··· · / ··· ·— ···— · —·· / ——— ···— · ·—· / —·—— ——— ··— ·—· / ——— ·—· ·· ——· ·· —· ·— ·—·· / ··— —· — ·· ·—·· / —·—— ——— ··— / —·—· ···· ——— ——— ··· · / — ——— / —·— · · ·——· / ·· — ·—·—·—',
			'operation.layout.layoutUnreadableAction' => '··— ··· · / — ···· ·· ··· / ·—·· ·— —·—— ——— ··— —',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / —·· ·· ··· ·——· ·—·· ·— —·—— · —··',
			'operation.layout.panelRenderRetry' => '— ·—· —·—— / ·— ——· ·— ·· —·',
			'operation.layout.panelActionFailed' => '— ···· ·— — / ·——· ·— —· · ·—·· / ·— —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'operation.layout.panels.loggingDescription' => '— ···· · / ·—·· ——— ——· / ·— —· —·· / — ···· · / · —· — ·—· —·—— / ··—· ·· · ·—·· —·· ···',
			'operation.layout.panels.infoDescription' => '·—— ···· ·— — / ·—— · / —·— —· ——— ·—— / ·— —··· ——— ··— — / — ···· · / ··· — ·— — ·· ——— —· / —··· · ·· —· ——· / ·—— ——— ·—· —·— · —··',
			'operation.layout.panels.spotsDescription' => '··· ·——· ——— — ··· / ··—· ·—· ——— —— / — ···· · / —·—· ·—·· ··— ··· — · ·—· ··· / ·— —· —·· / ·— —·—· — ·· ···— ·· — —·—— / ·——· ·—· ——— ——· ·—· ·— —— ···',
			'operation.layout.panels.mapDescription' => '·—— ···· · ·—· · / — ···· · / —·—· ——— —· — ·— —·—· — ··· / ·— ·—· ·',
			'operation.layout.panels.summariesDescription' => '— ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ··· — ·— — ··· / ·— —· —·· / ··· —·—· ——— ·—· · ··· ——··—— / ·· —· / — ···· · / ··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—· / —·—— ——— ··— / ·——· ·· —·—· —·—',
			'operation.layout.panels.summariesSections' => '··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—·',
			'operation.layout.panels.summariesDays' => '· ·— —·—· ···· / —·· ·— —·——',
			'operation.layout.panels.summariesReset' => '··· ···· ——— ·—— / ·— ·—·· ·—··',
			'operation.layout.panels.summariesAllHidden' => '· ···— · ·—· —·—— / ··· · —·—· — ·· ——— —· / ·· ··· / ···· ·· —·· —·· · —· ·—·—·— / ·——· ·· —·—· —·— / — ···· · / ——— —· · ··· / — ——— / ··· ···· ——— ·—— / ·· —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· ·—·—·—',
			'operation.layout.panels.clockDescription' => '·— / —·—· ·—·· ——— —·—· —·— / ··—· ·— —·—· · ——··—— / ·· —· / ·— —· —·—— / — ·· —— · / ——·· ——— —· ·',
			'operation.layout.panels.clockFace' => '··—· ·— —·—· ·',
			'operation.layout.panels.clockFaceLcd' => '·—·· —·—· —··',
			'operation.layout.panels.clockFaceAnalog' => '·— —· ·— ·—·· ——— ——·',
			'operation.layout.panels.clockZone' => '— ·· —— · / ——·· ——— —· ·',
			'operation.layout.panels.clockZoneUtc' => '··— — —·—·',
			'operation.layout.panels.clockZoneDevice' => '— ···· ·· ··· / —·· · ···— ·· —·—· ·',
			'operation.layout.panels.clockShowSeconds' => '··· ···· ——— ·—— / ··· · —·—· ——— —· —·· ···',
			'operation.layout.panels.weatherDescription' => '—·—· ——— —· —·· ·· — ·· ——— —· ··· / —· ——— ·—— / ·— —· —·· / ··—· ——— ·—· / — ···· · / —· · —··— — / · ·· ——· ···· — / ···· ——— ··— ·—· ··· ——··—— / ·—— ···· · ·—· · / —·—— ——— ··— ·————· ·—· · / ——— ·——· · ·—· ·— — ·· —· ——·',
			'operation.layout.panels.weatherUseOperationLocation' => '··— ··· · / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —·',
			'operation.layout.panels.weatherLocation' => '·—·· ——— —·—· ·— — ·· ——— —·',
			'operation.layout.panels.weatherLocationDescription' => '·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / —·——· ··—· —· ···—— ·———— ·——· ·—· —·——·— / ——— ·—· / ·—·· ·— — ——··—— ·—·· ——— —· ·—·—·— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·————· ··— ··· · / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—·· ——— —·—· ·— — ·· ——— —· ·————· / ·· ··· / —·—· ···· · —·—· —·— · —·· ·—·—·—',
			'operation.layout.panels.weatherNoLocation' => '—· ——— / ·—·· ——— —·—· ·— — ·· ——— —· / ··· · — ·—·—·— / ——· ·· ···— · / — ···· ·· ··· / ·——· ·— —· · ·—·· / ·— / ·—·· ——— —·—· ·— — ·· ——— —· / ·· —· / ·· — ··· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ·——· ·—·· ·— —·—· · / ·· — / ·· —· ··· ·· —·· · / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / — ···· ·— — / ···· ·— ··· / ——— —· · ·—·—·—',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·· / — ···· · / ·—·· ——— —·—· ·— — ·· ——— —· / ${location} ·—·—·— / ··— ··· · / ·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / ·—·· ·· —·— · / ··—· —· ···—— ·———— ·——· ·—· ——··—— / ——— ·—· / ····— ··——— ·—·—·— ···—— —···· ——··—— —····— ——··· ·———— ·—·—·— ————— —···· ·—·—·—',
			'operation.layout.panels.weatherUnreachable' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / ——— ·——· · —· —····— —— · — · ——— / — / —· ——— / —· · — ·—— ——— ·—· —·— ··——·· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—',
			'operation.layout.panels.weatherUnreadable' => '——— ·——· · —· —····— —— · — · ——— / ·—· · ··· ·——· ——— —· —·· · —·· ——··—— / —··· ··— — / —· ——— — / ·—— ·· — ···· / ·— —· —·—— — ···· ·· —· ——· / ·—· · ·— —·· ·— —··· ·—·· · ·—·—·— / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => '——· ··— ··· — ··· / ${speed}',
			'operation.layout.panels.panelAgeNow' => '·——— ··— ··· — / —· ——— ·——',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / —— ·· —· / ·— ——· ———', other: '${count} / —— ·· —· / ·— ——· ———', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ···· ·—· / ·— ——· ———', other: '${count} / ···· ·—· ··· / ·— ——· ———', ), 
			'operation.layout.panels.weatherConditions.unknown' => '··— —· —·— —· ——— ·—— —·',
			'operation.layout.panels.weatherConditions.sunny' => '··· ··— —· —· —·——',
			'operation.layout.panels.weatherConditions.clear' => '—·—· ·—·· · ·— ·—·',
			'operation.layout.panels.weatherConditions.mainlySunny' => '—— ·— ·· —· ·—·· —·—— / ··· ··— —· —· —·——',
			'operation.layout.panels.weatherConditions.mainlyClear' => '—— ·— ·· —· ·—·· —·—— / —·—· ·—·· · ·— ·—·',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panels.weatherConditions.partlyCloudy' => '·——· ·— ·—· — ·—·· —·—— / —·—· ·—·· ——— ··— —·· —·——',
			'operation.layout.panels.weatherConditions.cloudy' => '—·—· ·—·· ——— ··— —·· —·——',
			'operation.layout.panels.weatherConditions.foggy' => '··—· ——— ——· ——· —·——',
			'operation.layout.panels.weatherConditions.rimeFog' => '·—· ·· —— · / ··—· ——— ——·',
			'operation.layout.panels.weatherConditions.lightDrizzle' => '·—·· ·· ——· ···· — / —·· ·—· ·· ——·· ——·· ·—·· ·',
			'operation.layout.panels.weatherConditions.drizzle' => '—·· ·—· ·· ——·· ——·· ·—·· ·',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => '···· · ·— ···— —·—— / —·· ·—· ·· ——·· ——·· ·—·· ·',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => '·—·· ·· ——· ···· — / ··—· ·—· · · ——·· ·· —· ——· / —·· ·—· ·· ——·· ——·· ·—·· ·',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => '··—· ·—· · · ——·· ·· —· ——· / —·· ·—· ·· ——·· ——·· ·—·· ·',
			'operation.layout.panels.weatherConditions.lightRain' => '·—·· ·· ——· ···· — / ·—· ·— ·· —·',
			'operation.layout.panels.weatherConditions.rain' => '·—· ·— ·· —·',
			'operation.layout.panels.weatherConditions.heavyRain' => '···· · ·— ···— —·—— / ·—· ·— ·· —·',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => '·—·· ·· ——· ···· — / ··—· ·—· · · ——·· ·· —· ——· / ·—· ·— ·· —·',
			'operation.layout.panels.weatherConditions.freezingRain' => '··—· ·—· · · ——·· ·· —· ——· / ·—· ·— ·· —·',
			'operation.layout.panels.weatherConditions.lightSnow' => '·—·· ·· ——· ···· — / ··· —· ——— ·——',
			'operation.layout.panels.weatherConditions.snow' => '··· —· ——— ·——',
			'operation.layout.panels.weatherConditions.heavySnow' => '···· · ·— ···— —·—— / ··· —· ——— ·——',
			'operation.layout.panels.weatherConditions.snowGrains' => '··· —· ——— ·—— / ——· ·—· ·— ·· —· ···',
			'operation.layout.panels.weatherConditions.lightShowers' => '·—·· ·· ——· ···· — / ··· ···· ——— ·—— · ·—· ···',
			'operation.layout.panels.weatherConditions.showers' => '··· ···· ——— ·—— · ·—· ···',
			'operation.layout.panels.weatherConditions.heavyShowers' => '···· · ·— ···— —·—— / ··· ···· ——— ·—— · ·—· ···',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => '·—·· ·· ——· ···· — / ··· —· ——— ·—— / ··· ···· ——— ·—— · ·—· ···',
			'operation.layout.panels.weatherConditions.snowShowers' => '··· —· ——— ·—— / ··· ···· ——— ·—— · ·—· ···',
			'operation.layout.panels.weatherConditions.thunderstorm' => '— ···· ··— —· —·· · ·—· ··· — ——— ·—· ——',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => '·—·· ·· ——· ···· — / — ···· ··— —· —·· · ·—· ··· — ——— ·—· —— ··· / ·—— ·· — ···· / ···· ·— ·· ·—··',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => '— ···· ··— —· —·· · ·—· ··· — ——— ·—· —— / ·—— ·· — ···· / ···· ·— ·· ·—··',
			'operation.layout.panels.websiteDescription' => '·— / ·—— · —··· / ·——· ·— ——· · / ——— ··—· / —·—— ——— ··— ·—· / —·—· ···· ——— ——— ··· ·· —· ——· ——··—— / ·· —· / ·— / ·——· ·— —· ·',
			'operation.layout.panels.websiteUrl' => '·— —·· —·· ·—· · ··· ···',
			'operation.layout.panels.websiteRefresh' => '·—· · ··—· ·—· · ··· ····',
			'operation.layout.panels.websiteRefreshNever' => '—· · ···— · ·—·',
			'operation.layout.panels.websiteRefresh1' => '· ···— · ·—· —·—— / —— ·· —· ··— — ·',
			'operation.layout.panels.websiteRefresh5' => '· ···— · ·—· —·—— / ····· / —— ·· —· ··— — · ···',
			'operation.layout.panels.websiteRefresh15' => '· ···— · ·—· —·—— / ·———— ····· / —— ·· —· ··— — · ···',
			'operation.layout.panels.websiteTitle' => '·——· ·— —· · ·—·· / —· ·— —— ·',
			'operation.layout.panels.websiteRefreshNow' => '·—· · ··—· ·—· · ··· ···· / —· ——— ·——',
			'operation.layout.panels.websiteNoUrl' => '—· ——— / ·— —·· —·· ·—· · ··· ··· / —·—— · — ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ’ ··· / ··· · — — ·· —· ——· ··· / — ——— / —·—· ···· ——— ——— ··· · / ·— / ·——· ·— ——· · ·—·—·—',
			'operation.layout.panels.websiteBadUrl' => '— ···· ·— — / —·· ——— · ··· —· ’ — / ·—·· ——— ——— —·— / ·—·· ·· —·— · / ·— / ·—— · —··· / ·— —·· —·· ·—· · ··· ··· ·—·—·— / ·· — / —· · · —·· ··· / — ——— / ··· — ·— ·—· — / ·—— ·· — ···· / ···· — — ·——· ··· ———··· —··—· —··—·',
			'operation.layout.panels.websiteNotHttps' => '——— —· ·—·· —·—— / ···· — — ·——· ··· ———··· —··—· —··—· / ·— —·· —·· ·—· · ··· ··· · ··· / —·—· ·— —· / —··· · / ··· ···· ——— ·—— —· / ···· · ·—· · ·—·—·—',
			'operation.layout.panels.websiteUnsupported' => '·—— · —··· / ·——· ·— ——· · ··· / —·—· ·— —· ’ — / —··· · / ··· ···· ——— ·—— —· / ·· —· / ·— / ·——· ·— —· · ·—·· / ——— —· / — ···· ·· ··· / ··· —·—— ··· — · —— ·—·—·—',
			'operation.layout.panels.websiteOpenExternally' => '——— ·——· · —· / ·· —· / —··· ·—· ——— ·—— ··· · ·—·',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ·—·· ——— ·— —·· / — ···· · / ·——· ·— ——· · ———··· / ${reason}',
			'operation.layout.panels.remoteScreenDescription' => '·— / ··· —·—· ·—· · · —· ——··—— / ·— ·——· ·——· / ——— ·—· / ·—— ·· —· —·· ——— ·—— / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· / ——— ··—· / —·—— ——— ··— ·—· / —·· · ···— ·· —·—· · ··· ·—·—·—',
			'operation.layout.panels.remoteScreenTarget' => '··· —·—· ·—· · · —·',
			'operation.layout.panels.remoteScreenChoose' => '—·—· ···· ——— ——— ··· · / ·— / ··· —·—· ·—· · · —· …',
			'operation.layout.panels.remoteScreenPickerTitle' => '··· ···· ·— ·—· · —·· / ··· —·—· ·—· · · —· ···',
			'operation.layout.panels.remoteScreenPickerEmpty' => '—· ——— —· · / ——— ··—· / —·—— ——— ··— ·—· / —·· · ···— ·· —·—· · ··· / ·· ··· / ··· ···· ·— ·—· ·· —· ——· / ·— / ··· —·—· ·—· · · —· ·—·—·— / — ··— ·—· —· / ··· ···· ·— ·—· · / ··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ··· / ——— —· / ··— —· —·· · ·—· / ··· · — — ·· —· ——· ··· / → / ·——· · · ·—· / —·· · ···— ·· —·—· · ··· ——··—— / ——— —· / — ···· · / —·· · ···— ·· —·—· · / —·—— ——— ··— / ·—— ·— —· — / — ——— / ··· · · ·—·—·—',
			'operation.layout.panels.remoteScreenUnset' => '—· ——— / ··· —·—· ·—· · · —· / —·—· ···· ——— ··· · —· ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· / — ——— / ·——· ·· —·—· —·— / ——— —· · / —·—— ——— ··— ·—· / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / ·— ·—· · / ··· ···· ·— ·—· ·· —· ——· ·—·—·—',
			'operation.layout.panels.remoteScreenConnecting' => '—·—· ——— —· —· · —·—· — ·· —· ——· …',
			'operation.layout.panels.remoteScreenPeerAway' => '— ···· ·— — / —·· · ···— ·· —·—· · / ·· ··· —· ·————· — / —·—· ——— —· —· · —·—· — · —·· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—',
			'operation.layout.panels.remoteScreenNotOffered' => '— ···· ·— — / —·· · ···— ·· —·—· · / ··· — ——— ·——· ·——· · —·· / ··· ···· ·— ·—· ·· —· ——· / — ···· ·· ··· / ··· —·—· ·—· · · —· ·—·—·—',
			'operation.layout.panels.remoteScreenNoListener' => '— ···· ·— — / —·· · ···— ·· —·—· · / —·—· ·— —· ·————· — / ·— —·—· —·—· · ·——· — / —·—· ——— —· —· · —·—· — ·· ——— —· ··· / — / —·—· ···· · —·—· —·— / ·· — ··· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· ·—·—·—',
			'operation.layout.panels.remoteScreenNoLan' => '··· —·—· ·—· · · —· ··· / ·— ·—· · / ——— —· ·—·· —·—— / ··· ···· ·— ·—· · —·· / ——— ···— · ·—· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ——··—— / —· ——— — / —··· ·—·· ··— · — ——— ——— — ···· ·—·—·—',
			'operation.layout.panels.remoteScreenRefused' => '— ···· ·— — / —·· · ···— ·· —·—· · / ·—— ——— ··— ·—·· —·· —· ·————· — / ··· ···· ·— ·—· · / — ···· ·· ··· / ··· —·—· ·—· · · —· ·—·—·—',
			'operation.layout.panels.remoteScreenSettings' => '·——· ·— —· · ·—·· / ··· · — — ·· —· ——· ···',
			'operation.layout.panels.remoteScreenAdjust' => '·— —·· ·——— ··— ··· — / ···— ·· · ·——',
			'operation.layout.panels.remoteScreenDetail' => '—·· · — ·— ·· ·—··',
			'operation.layout.panels.remoteScreenDetailStandard' => '··· — ·— —· —·· ·— ·—· —··',
			'operation.layout.panels.remoteScreenDetailHigh' => '···· ·· ——· ····',
			'operation.layout.panels.remoteScreenDetailMaximum' => '—— ·— —··— ·· —— ··— ——',
			'operation.layout.panels.remoteScreenAdjustDone' => '——— —·—',
			'operation.layout.panels.remoteScreenZoomIn' => '——·· ——— ——— —— / ·· —·',
			'operation.layout.panels.remoteScreenZoomOut' => '——·· ——— ——— —— / ——— ··— —',
			'operation.layout.panels.remoteScreenStopped' => '— ···· ·— — / ··· —·—· ·—· · · —· / ——— ·—· / ·—— ·· —· —·· ——— ·—— / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / —··· · ·· —· ——· / ··· ···· ——— ·—— —· ·—·—·—',
			'operation.layout.panels.remoteScreenCaptureFailed' => '— ···· ·— — / —·· · ···— ·· —·—· · / —·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ·— ·——· — ··— ·—· · / — ···· ·— — / ··· —·—· ·—· · · —· / — / ·· — / —— ·— —·—— / —· · · —·· / ··· —·—· ·—· · · —· / ·—· · —·—· ——— ·—· —·· ·· —· ——· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· ·—·—·—',
			'operation.layout.panels.remoteScreenNoAnswer' => '— ···· ·— — / —·· · ···— ·· —·—· · / —·· ·· —·· —· ·————· — / ·—· · ··· ·——· ——— —· —·· ·—·—·— / ·· — / —— ·— —·—— / —· ——— — / ···· ·— ···— · / ··· —·—· ·—· · · —· / ··· ···· ·— ·—· ·· —· ——· / — ··— ·—· —· · —·· / ——— —· ·—·—·—',
			'operation.layout.panels.remoteScreenNoMedia' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ——— ·——· · —· / ·— / —·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ——— ·—· / — ···· · / ·——· ·· —·—· — ··— ·—· · ·—·—·— / —·—· ···· · —·—· —·— / — ···· · / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·—',
			'operation.layout.panels.solarDescription' => '··· ——— ·—·· ·— ·—· / ·— —· —·· / ——· · ——— —— ·— ——· —· · — ·· —·—· / —·—· ——— —· —·· ·· — ·· ——— —· ··· ——··—— / ·—— ·· — ···· / —··· ·— —· —·· —····— —··· —·—— —····— —··· ·— —· —·· / ·——· ·—· ——— ·——· ·— ——· ·— — ·· ——— —·',
			'operation.layout.panels.solarUnreachable' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / ···· ·— —— ——·— ··· ·—·· ·—·—·— —·—· ——— —— / — / —· ——— / —· · — ·—— ——— ·—· —·— ··——·· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—',
			'operation.layout.panels.solarUnreadable' => '···· ·— —— ——·— ··· ·—·· ·—·—·— —·—· ——— —— / ·—· · ··· ·——· ——— —· —·· · —·· ——··—— / —··· ··— — / —· ——— — / ·—— ·· — ···· / ·— / ·—· · ·— —·· ·· —· ——· / ·—— · / —·—· ——— ··— ·—·· —·· / ··— ··· · ·—·—·— / ·—— ·· ·—·· ·—·· / — ·—· —·—— / ·— ——· ·— ·· —· / ··· ···· ——— ·—· — ·—·· —·—— ·—·—·—',
			'operation.layout.panels.solarAIndex' => '·—',
			'operation.layout.panels.solarKIndex' => '—·— ·——·',
			'operation.layout.panels.solarBandDay' => '—·· ·— —·——',
			'operation.layout.panels.solarBandNight' => '—· ·· ——· ···· —',
			'operation.layout.panels.solarBandGood' => '——· ——— ——— —··',
			'operation.layout.panels.solarBandFair' => '··—· ·— ·· ·—·',
			'operation.layout.panels.solarBandPoor' => '·——· ——— ——— ·—·',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => '··· ——— ··— ·—· —·—· · ··· ———··· / ${primary} ——··—— / ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => '— ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ·· ··· / ··· — ·—· ··— ——· ——· ·—·· ·· —· ——· / — / ··· —·— ·· ·——· ·——· ·· —· ——· / ··—· ·—· ·— —— · ··· ·—·—·—',
			'operation.layout.panels.remoteScreenStalled' => '··—· ·—· ·— —— · ··· / ··· — ——— ·——· ·——· · —·· / ——· · — — ·· —· ——· / — ···· ·—· ——— ··— ——· ···· / — / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —— ·— —·—— / —··· · / — ——— ——— / ··· ·—·· ——— ·—— ·—·—·—',
			'operation.layout.panels.radioDescription' => '·— / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·—· ——— —· — / ·——· ·— —· · ·—·· / — / ··—· ·—· · ——·— ··— · —· —·—· —·—— ——··—— / —— ——— —·· · / ·— —· —·· / ·——· ——— ·—— · ·—· ——··—— / ··— —· —·· · ·—· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—··',
			'operation.layout.panels.radioStyle' => '··· — —·—— ·—·· ·',
			'operation.layout.panels.radioStyleLcd' => '·—·· —·—· —··',
			'operation.layout.panels.radioStyleModern' => '—— ——— —·· · ·—· —·',
			'operation.layout.panels.radioRadio' => '·—· ·— —·· ·· ———',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => '···— ··—· ——— / ·— / — / ${name}',
			'operation.layout.panels.radioAutoNone' => '···— ··—· ——— / ·— / — / —· ——— / ·—· ·— —·· ·· ——— / —·· · ··· ·· ——· —· ·— — · —··',
			'operation.layout.panels.radioNoRadio' => '—· ——— / ·—· ·— —·· ·· ——— / — ——— / ··· ···· ——— ·—— ·—·—·— / ·——· ·· —·—· —·— / ——— —· · / ·· —· / — ···· ·· ··· / ·——· ·— —· · ·—·· ·————· ··· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ·— —·· —·· / ——— —· · / ··— —· —·· · ·—· / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ·—·—·—',
			'operation.layout.panels.radioNotConfigured' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / —· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / —·—— · — ·—·—·— / —·—· ···· ——— ——— ··· · / ·· — ··· / ·——· ——— ·—· — / ——— ·—· / ·— —·· —·· ·—· · ··· ··· / ··— —· —·· · ·—· / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ·—·—·—',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => '·—· ·— —·· ·· ——— / —· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'operation.layout.panels.radioWatts' => '·——',
			'operation.layout.panels.radioConnect' => '—·—· ——— —· —· · —·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———',
			'operation.layout.panels.radioDisconnect' => '—·· ·· ··· —·—· ——— —· —· · —·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———',
			'operation.layout.panels.radioStale' => '—· ——— / —·· ·— — ·—',
			'operation.layout.panels.radioTransmitting' => '— —··—',
			'operation.layout.panels.radioSwr' => '··· ·—— ·—·',
			'operation.layout.panels.radioAlc' => '·— ·—·· —·—·',
			'operation.layout.panels.radioVolts' => '···—',
			'operation.layout.panels.radioSwrHigh' => '···· ·· ——· ···· / ··· ·—— ·—·',
			'operation.layout.htmlPanelUnsupported' => '— ···· ·· ··· / ·——· ·— —· · ·—·· / —· · · —·· ··· / ·— / ·—— · —··· / ···— ·· · ·—— ——··—— / ·—— ···· ·· —·—· ···· / — ···· ·· ··· / ·——· ·—·· ·— — ··—· ——— ·—· —— / —·· ——— · ··· / —· ——— — / ·——· ·—· ——— ···— ·· —·· ·',
			'operation.layout.htmlPanelUnsupportedOnWeb' => '— ···· ·· ··· / ·——· ·— —· · ·—·· / —· · · —·· ··· / ·— / ··· ·— —· —·· —··· ——— —··— / — ···· · / ·—— · —··· / ···— · ·—· ··· ·· ——— —· / —·—· ·— —· —· ——— — / ·——· ·—· ——— ···— ·· —·· ·',
			'operation.export.title' => '——— ·——· · ·—· ·— — ·· ——— —· / · —··— ·——· ——— ·—· — ···',
			'operation.export.syncedOperation' => '——— ·——· · ·—· ·— — ·· ——— —· / ·· ··· / ··· —·—— —· —·—· · —··',
			'operation.export.unsyncedOperation' => '——— ·——· · ·—· ·— — ·· ——— —· / ···· ·— ··· / ··— —· ··· —·—— —· —·—· · —·· / —·—· ···· ·— —· ——· · ···',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·', other: '${count} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·', ), 
			'operation.export.qsosSynced' => ({required Object total}) => '·— ·—·· ·—·· / ${total} / ——·— ··· ——— ··· / ·— ·—· · / ··· —·—— —· —·—· · —··',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} / ——— ··—· / ${total} / ——·— ··· ——— ··· / ·——· · —· —·· ·· —· ——· / ··· —·—— —· —·—·',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} / · ···— · —· — / —— ·— ·—· —·— · ·—· ··· / ··· —·—— —· —·—· · —··',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} / ——— ··—· / ${total} / · ···— · —· — / —— ·— ·—· —·— · ·—· ··· / ·——· · —· —·· ·· —· ——·',
			'operation.export.loading' => '·—·· ——— ·— —·· ·· —· ——· / · —··— ·——· ——— ·—· — / ——— ·——· — ·· ——— —· ··· …',
			'operation.export.noOptions' => '—· ——— / · —··— ·——· ——— ·—· — / ··—· ——— ·—· —— ·— — ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / —·——· · —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / ··· — ·· ·—·· ·—·· / ··· — ·— ·—· — ·· —· ——· ··——·· —·——·—',
			'operation.export.nothingLogged' => '—· ——— — ···· ·· —· ——· / — ——— / · —··— ·——· ——— ·—· — / —·—— · — / — / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ···· ·— ··· / —· ——— / ——·— ··· ——— ··· ·—·—·—',
			'operation.export.share' => '··· ···· ·— ·—· ·',
			'operation.export.nothingSelected' => '—· ——— — ···· ·· —· ——· / ··· · ·—·· · —·—· — · —··',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· ·— ···— · / ${count} / ··—· ·· ·—·· ·', other: '··· ·— ···— · / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· ···· ·— ·—· · / ${count} / ··—· ·· ·—·· ·', other: '··· ···· ·— ·—· · / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '· —··— ·——· ——— ·—· — / ${count} / ··—· ·· ·—·· ·', other: '· —··— ·——· ——— ·—· — / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${count} / ··—· ·· ·—·· ·', other: '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· ·— ···— · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·', other: '··· ·— ···— · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· ···· ·— ·—· · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·', other: '··· ···· ·— ·—· · / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '· —··— ·——· ——— ·—· — / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·', other: '· —··— ·——· ——— ·—· — / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '—·· ——— ·—— —· ·—·· ——— ·— —·· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·', other: '—·· ——— ·—— —· ·—·· ——— ·— —·· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.saveOne' => ({required Object name}) => '··· ·— ···— · / ${name}',
			'operation.export.shareOne' => ({required Object name}) => '··· ···· ·— ·—· · / ${name}',
			'operation.export.exportOne' => ({required Object name}) => '· —··— ·——· ——— ·—· — / ${name}',
			'operation.export.downloadOne' => ({required Object name}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· / ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· — ·— ··· ···· / ${count} / ··—· ·· ·—·· ·', other: '··· — ·— ··· ···· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· — ·— ··· ···· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· ·', other: '··· — ·— ··· ···· / —·—· ——— —— —··· ·· —· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.settingsButton' => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ···',
			'operation.export.settingsTitle' => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ···',
			'operation.export.compactFileNames.title' => '··— ··· · / —·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · / —· ·— —— · ···',
			'operation.export.compactFileNames.descriptionOn' => '··· ···· ——— ·—· — / —· ·— —— · ··· / —··· ··— ·· ·—·· — / ··—· ——— ·—· / ··— ·——· ·—·· ——— ·— —·· · ·—· ··· ——··—— / ·—·· ·· —·— · / —· ————— —·—· ·— ·—·· ·—·· ·——·—· ··— ··· —····— ·———— ··——— ···—— ····— —····— ··——— ————— ··——— —···· ————— ——··· ··——— ——··· ·—·—·— ·— —·· ··',
			'operation.export.compactFileNames.descriptionOff' => '·—· · ·— —·· ·— —··· ·—·· · / —· ·— —— · ··· ——··—— / ·—·· ·· —·— · / ··——— ————— ··——— —···· —····— ————— ——··· —····— ··——— ——··· / —· ————— —·—· ·— ·—·· ·—·· / ·— — / ··— ··· —····— ·———— ··——— ···—— ····— ·—·—·— ·— —·· ··',
			'operation.export.includePrivateData.title' => '·· —· —·—· ·—·· ··— —·· · / ·——· ·—· ·· ···— ·— — · / ·· —· ··—· ———',
			'operation.export.includePrivateData.descriptionOn' => '—· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / ——· ·—· ·· —·· ··· ——·— ··— ·— ·—· · ··· / ·— —· —·· / —· ——— — · ··· / ·— ·—· · / ·· —· —·—· ·—·· ··— —·· · —··',
			'operation.export.includePrivateData.descriptionOff' => '—· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / ——· ·—· ·· —·· ··· ——·— ··— ·— ·—· · ··· / ·— —· —·· / —· ——— — · ··· / ·— ·—· · / ·—·· · ··—· — / ——— ··— —',
			'operation.export.includePrivateData.note' => '— ···· · / ··—· ··— ·—·· ·—·· / ·— —·· ·· ··—· / · —··— ·——· ——— ·—· — / ·— ·—·· ·—— ·— —·—— ··· / ·· —· —·—· ·—·· ··— —·· · ··· / · ···— · ·—· —·—— — ···· ·· —· ——·',
			'operation.export.resultTitle' => '· —··— ·——· ——— ·—· — / —·—· ——— —— ·——· ·—·· · — ·',
			'operation.export.resultFailedTitle' => '· —··— ·——· ——— ·—· — / ··—· ·— ·· ·—·· · —··',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · / — ——— / ${path}', other: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ··· / — ——— / ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ———··· / ${path}', other: '· —··— ·——· ——— ·—· — · —·· / ${count} / ··—· ·· ·—·· · ··· ———··· / ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· ···· ·— ·—· · —·· / ${count} / ··—· ·· ·—·· ·', other: '··· ···· ·— ·—· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${count} / ··—· ·· ·—·· ·', other: '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${count} / ··—· ·· ·—·· · ···', ), 
			'operation.export.exportFailed' => ({required Object error}) => '· —··— ·——· ——— ·—· — / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'operation.export.stash.needsEmailTitle' => '·— —·· —·· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ··—· ·· ·—· ··· —',
			'operation.export.stash.needsEmailBody' => '···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / ··· · —· —·· ··· / —·—— ——— ··— ·—· / ··—· ·· ·—·· · ··· / — ——— / — ···· · / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— ··—· ·· / ·— —·—· —·—· ——— ··— —· — ——··—— / ·— —· —·· / —·—— ——— ··— / ··· ·· ——· —· / ·· —· / ·—— ·· — ···· / ·· — / ·— — / ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ·—·—·— / —·—— ——— ··— ·—· / ·— —·—· —·—· ——— ··— —· — / —·· ——— · ··· —· ’ — / ···· ·— ···— · / ·— / —·—· ——— —· ··—· ·· ·—· —— · —·· / ——— —· · / —·—— · — / — / ·— —·· —·· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / —·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—· ·—·—·—',
			'operation.export.stash.openSyncSettings' => '——— ·——· · —· / —·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—·',
			'operation.export.stash.replaceTitle' => '·—· · —·—· · —· — / ··· — ·— ··· ···· / ·—— ·· ·—·· ·—·· / —··· · / ·—· · ·——· ·—·· ·— —·—· · —··',
			'operation.export.stash.replaceBody' => ({required Object name}) => '—·—— ——— ··— / ··· · —· — / “ ${name} ” / ·—·· · ··· ··· / — ···· ·— —· / —···· / ···· ——— ··— ·—· ··· / ·— ——· ——— / ·— —· —·· / ·· — / ···· ·— ··· —· ’ — / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / —·—— · — ·—·—·— / ··—· ·—· · · / ·— —·—· —·—· ——— ··— —· — ··· / —·— · · ·——· / ——— —· · / ··· — ·— ··· ···· / ·— — / ·— / — ·· —— · ——··—— / ··· ——— / ··· · —· —·· ·· —· ——· / —· ——— ·—— / ·—· · ·——· ·—·· ·— —·—· · ··· / ·· — ·—·—·—',
			'operation.export.stash.replaceConfirm' => '··· · —· —·· / ·— —· —·—— ·—— ·— —·——',
			'operation.export.stash.failedTitle' => '—·—· ——— ··— ·—·· —·· —· ’ — / ··· · —· —·· / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ····',
			'operation.export.stash.sentTitle' => '··· · —· — / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ····',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '—·—— ——— ··— / —·—· ·— —· / ·—· · — ·—· ·· · ···— · / — ···· ·· ··· / ··—· ·· ·—·· · / —··· —·—— / ···— ·· ··· ·· — ·· —· ——· / ** [ ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ](https://stash.ham2k.net) ** / ——— —· / ·— —· —·—— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—', other: '—·—— ——— ··— / —·—· ·— —· / ·—· · — ·—· ·· · ···— · / — ···· · ··· · / ··—· ·· ·—·· · ··· / —··· —·—— / ···— ·· ··· ·· — ·· —· ——· / ** [ ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ](https://stash.ham2k.net) ** / ——— —· / ·— —· —·—— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—', ), 
			'operation.export.stash.mayHaveArrived' => '—· ——— / ·— —· ··· ·—— · ·—· / ··—· ·—· ——— —— / — ···· · / ··· — ·— ··· ···· / — / — ···· · / ··—· ·· ·—·· · / —— ·— —·—— / ···· ·— ···— · / ·— ·—· ·—· ·· ···— · —·· / ·— —· —·—— ·—— ·— —·—— ·—·—·— / —·—· ···· · —·—· —·— / ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — / —··· · ··—· ——— ·—· · / ··· · —· —·· ·· —· ——· / ·— ——· ·— ·· —·',
			'operation.export.stash.notSent' => '—· ——— — / ··· · —· —',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '— ···· ·· ··· / ··—· ·· ·—·· · / —·· ·· —·· —· ’ — / ·— ·—· ·—· ·· ···— · ———···', other: '— ···· · ··· · / ${count} / ··—· ·· ·—·· · ··· / —·· ·· —·· —· ’ — / ·— ·—· ·—· ·· ···— · ———···', ), 
			'operation.export.stash.emailOffer' => '——— ·—· / ··—· ——— ·—· / —·—— ——— ··— ·—· / —·—· ——— —· ···— · —· ·· · —· —·—· · ——··—— / ·—— · / —·—· ·— —· / ··· · —· —·· / —·—— ——— ··— / ·— —· / · —— ·— ·· ·—·· / ·—— ·· — ···· / ·— / —·· ·· ·—· · —·—· — / ·—·· ·· —· —·— ·—·—·—',
			'operation.export.stash.emailMe' => '· —— ·— ·· ·—·· / —— · / ·— / ·—·· ·· —· —·—',
			'operation.export.stash.emailSent' => '·—— · ’ ···— · / · —— ·— ·· ·—·· · —·· / —·—— ——— ··— / ·— / —·· ——— ·—— —· ·—·· ——— ·— —·· / ·—·· ·· —· —·— ·—·—·—',
			'operation.export.stash.emailFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ··· · —· —·· / — ···· · / · —— ·— ·· ·—·· ———··· / ${error}',
			'operation.export.stash.freeTier' => '··—· ·—· · · / ·— —·—· —·—· ——— ··— —· — ··· / —·—· ·— —· / ——— —· ·—·· —·—— / —·— · · ·——· / ——— —· · / ··· — ·— ··· ···· / ·— — / ·— / — ·· —— · ·—·—·— / ··· ··— —··· ··· —·—· ·—· ·· —··· · ·—· ··· / —·—· ·— —· / —·— · · ·——· / ·— ··· / —— ·— —· —·—— / ·— ··· / — ···· · —·—— / ·—— ·— —· — ·—·—·—',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· · —· — / ${count} / ··—· ·· ·—·· · / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·——· ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — —·——·—', other: '··· · —· — / ${count} / ··—· ·· ·—·· · ··· / — ——— / ···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·——· ··· — ·— ··· ···· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — —·——·—', ), 
			'operation.spots.empty' => '—· ——— / ··· ·——· ——— — ··· / —— ·— — —·—· ···· / —·—— ——— ··— ·—· / ··—· ·· ·—·· — · ·—· ···',
			'operation.spots.error' => ({required Object error}) => '··—· ·— ·· ·—·· · —·· / — ——— / ·—·· ——— ·— —·· / ··· ·——· ——— — ··· ———··· / ${error}',
			'operation.spots.unknownBand' => '——— — ···· · ·—·',
			'operation.spots.auto' => '·— ··— — ——— —— ·— — ·· —·—·',
			'operation.spots.autoValue' => ({required Object value}) => '·— ··— — ——— —— ·— — ·· —·—· / —·——· —·—· ··— ·—· ·—· · —· — ·—·· —·—— / ${value} —·——·—',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} / —·——· ·— ··— — ——— —·——·—',
			'operation.spots.any' => '·— —· —·——',
			'operation.spots.allBands' => '·— ·—·· ·—·· / —··· ·— —· —·· ···',
			'operation.spots.allModes' => '·— ·—·· ·—·· / —— ——— —·· · ···',
			'operation.spots.phoneAndCw' => '·——· ···· ——— —· · / ·—··· / —·—· ·——',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ··· ·——· ——— —', other: '${count} / ··· ·——· ——— — ···', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => '··· ···· ——— ·—— ·· —· ——· / ${count} / ——— ··—· / ${total} / ··· ·——· ——— — ···',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} / —— ·· —· ··— — · ···',
			'operation.spots.callsOfNote' => '—·—· ·— ·—·· ·—·· ··· / ——— ··—· / —· ——— — ·',
			'operation.spots.yourSpots' => '—·—— ——— ··— ·—· / ··· ·——· ——— — ···',
			'operation.spots.allSpots' => '·— ·—·· ·—·· / ··· ·——· ——— — ···',
			'operation.spots.continents.af' => '·— ··—· ·—· ·· —·—· ·—',
			'operation.spots.continents.as' => '·— ··· ·· ·—',
			'operation.spots.continents.eu' => '· ··— ·—· ——— ·——· ·',
			'operation.spots.continents.na' => '—· ——— ·—· — ···· / ·— —— · ·—· ·· —·—· ·—',
			'operation.spots.continents.oc' => '——— —·—· · ·— —· ·· ·—',
			'operation.spots.continents.sa' => '··· ——— ··— — ···· / ·— —— · ·—· ·· —·—· ·—',
			'operation.spots.continents.an' => '·— —· — ·— ·—· —·—· — ·· —·—· ·—',
			'operation.spots.filters.title' => '··—· ·· ·—·· — · ·—· / ··· ·——· ——— — ···',
			'operation.spots.filters.band' => '—··· ·— —· —··',
			'operation.spots.filters.mode' => '—— ——— —·· ·',
			'operation.spots.filters.age' => '·— ——· ·',
			'operation.spots.filters.sources' => '··· ——— ··— ·—· —·—· · ···',
			'operation.spots.filters.continent' => '—·—· ——— —· — ·· —· · —· —',
			'operation.spots.filters.sorting' => '··· ——— ·—· — ·· —· ——·',
			'operation.spots.filters.sortByTime' => '—··· —·—— / ··· ·——· ——— — / — ·· —— ·',
			'operation.spots.filters.sortByFrequency' => '—··· —·—— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'operation.spots.filters.sortByWanted' => '—— ——— ··· — / ·—— ·— —· — · —··',
			'operation.spots.filters.groupByBand' => '——· ·—· ——— ··— ·——· / —··· —·—— / —··· ·— —· —··',
			'operation.spots.filters.groupCallsWithNotes' => '——· ·—· ——— ··— ·——· / —·—· ·— ·—·· ·—·· ··· / ·—— ·· — ···· / —· ——— — · ···',
			'operation.spots.filters.alertingOnly' => '——— —· ·—·· —·—— / ··· ·——· ——— — ··· / ·—— ·· — ···· / ·— ·—·· · ·—· — ···',
			'operation.spots.filters.sourceNoReply' => '—· ——— / ·—· · ·——· ·—·· —·——',
			'operation.spots.filters.sourceError' => '· ·—· ·—· ——— ·—·',
			'operation.spots.unavailableTitle' => '··· ·——· ——— — ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} / —·· ·· —·· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·—·—·—',
			'operation.spots.failedTitle' => '··· ·——· ——— — / ··· ——— ··— ·—· —·—· · / · ·—· ·—· ——— ·—·',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} / ·—· · — ··— ·—· —· · —·· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—',
			'operation.spots.slideLogIt' => '·—·· ——— ——· / ·· —',
			'operation.spots.slideIgnore' => '·· ——· —· ——— ·—· ·',
			'operation.spots.slideRestore' => '·—· · ··· — ——— ·—· ·',
			'operation.spots.logConflict.title' => '·—·· ——— ——· ——· ·· —· ——· / ·——· ·— —· · ·—·· / ·· ··· / —··· ··— ··· —·——',
			'operation.spots.logConflict.editingBody' => '—·—— ——— ··— ·————· ·—· · / · —·· ·· — ·· —· ——· / ·— / ·—·· ——— ——· ——· · —·· / —·—· ——— —· — ·— —·—· — ·—·—·— / ·—·· ——— ——· / — ···· ·· ··· / ··· ·——· ——— — / ·· —· ··· — · ·— —·· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ··—· ·· —· ·· ··· ···· / — ···· · / · —·· ·· — ··——··',
			'operation.spots.logConflict.composingBody' => '—·—— ——— ··— ·————· ···— · / ··· — ·— ·—· — · —·· / · —· — · ·—· ·· —· ——· / ·— / —·—· ——— —· — ·— —·—· — ·—·—·— / ·—·· ——— ——· / — ···· ·· ··· / ··· ·——· ——— — / ·· —· ··· — · ·— —·· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ··—· ·· —· ·· ··· ···· / ·—— ···· ·— — / —·—— ——— ··— / ·—— · ·—· · / — —·—— ·——· ·· —· ——· ··——··',
			'operation.spots.logConflict.goBack' => '——· ——— / —··· ·— —·—· —·—',
			'operation.spots.logConflict.clearAndLog' => '—·—· ·—·· · ·— ·—· / ·— —· —·· / ·—·· ——— ——· / ··· ·——· ——— —',
			'operation.import.title' => '·· —— ·——· ——— ·—· — / —·· ·— — ·— / ·· —· — ——— / ——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.import.importAdifAction' => '·· —— ·——· ——— ·—· — / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ·— —·· ·· ··—·',
			'operation.import.settingsButton' => '·—·· ·· ··· — · —· / ··· · — — ·· —· ——· ···',
			'operation.import.settingsTitle' => '·—·· ·· ··· — · —· / ··—· ——— ·—· / ——— — ···· · ·—· / ·— ·——· ·——· ···',
			'operation.import.protocolAddressLabel' => '·— —·· —·· ·—· · ··· ···',
			'operation.import.protocolPortLabel' => '·——· ——— ·—· —',
			'operation.import.protocolPortInvalid' => '· —· — · ·—· / ·— / ·——· ——— ·—· — / —··· · — ·—— · · —· / ·———— / ·— —· —·· / —···· ····· ····· ···—— ·····',
			'operation.import.protocolAddressInvalid' => '· —· — · ·—· / ·— / ···— ·— ·—·· ·· —·· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / —·——· · ·—·—·— ——· ·—·—·— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ——— ·—· / ··——— ···—— ————· ·—·—·— ··——— ···—— ————· ·—·—·— ————— ·—·—·— ··——— —·——·—',
			'operation.import.protocolStatusReceiving' => '·—· · —·—· · ·· ···— ·· —· ——· / —·· ·— — ·—',
			'operation.import.protocolStatusNoData' => '—· ——— / —·· ·— — ·— / ·—· · —·—· · ·· ···— · —·· / ·—· · —·—· · —· — ·—·· —·——',
			'operation.import.protocolBindError' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ··· — ·— ·—· — / ·—·· ·· ··· — · —· ·· —· ——· ———··· / ${error}',
			'operation.import.captureFailed' => ({required Object error}) => '·· —· —·—· ——— —— ·· —· ——· / ——·— ··· ——— ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ··· ·— ···— · —·· / ·— —· —·· / ·— ·—· · / —··· · ·· —· ——· / ·—· · — ·—· ·· · —·· ———··· / ${error}',
			'operation.import.n1mmProtocolName' => '—· ·———— —— —— ·—·—· / —·—· ——— —· — ·— —·—· — / —··· ·—· ——— ·— —·· —·—· ·— ··· —',
			'operation.import.n1mmAddressValue' => '·— —· —·—— / —·——· —··· ·—· ——— ·— —·· —·—· ·— ··· — —·——·—',
			'operation.import.wsjtxProtocolName' => '·—— ··· ·——— — —····— —··— / ··— —·· ·——· / ··· · ·—· ···— · ·—·',
			'operation.import.helpN1mmSetup' => '—·—· ——— —· ··—· ·· ——· / → / —·—· ——— —· ··—· ·· ——· ··— ·—· · / ·——· ——— ·—· — ··· ——··—— / —— ——— —·· · / —·—· ——— —· — ·—· ——— ·—·· … / → / —··· ·—· ——— ·— —·· —·—· ·— ··· — / —·· ·— — ·— / — ·— —··· / → / —·—· ···· · —·—· —·— / ·—··—· · —· ·— —··· ·—·· · / —··· ·—· ——— ·— —·· —·—· ·— ··· — ··· ·—··—· / ··—· ——— ·—· / —·—· ——— —· — ·— —·—· — / ·· —· ··—· ——— ·—·—·— / ··· · — / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / — ——— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ·· ··—· / ·—· ··— —· —· ·· —· ——· / ——— —· / — ···· ·· ··· / ··· ·— —— · / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ——— ·—· / ··——— ····· ····· ·—·—·— ··——— ····· ····· ·—·—·— ··——— ····· ····· ·—·—·— ··——— ····· ····· / — ——— / —··· ·—· ——— ·— —·· —·—· ·— ··· — / ——— —· / — ···· · / —·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ·—·—·—',
			'operation.import.helpWsjtxSetup' => '··—· ·· ·—·· · / → / ··· · — — ·· —· ——· ··· / → / ·—· · ·——· ——— ·—· — ·· —· ——· / — ·— —··· / → / ··— —·· ·——· / ··· · ·—· ···— · ·—· / ··· · —·—· — ·· ——— —· / → / —·—· ···· · —·—· —·— / ·—··—· ·— —·—· —·—· · ·——· — / ··— —·· ·——· / ·—· · ——·— ··— · ··· — ··· ·—··—· ·—·—·— / ··· · — / ··— —·· ·——· / ··· · ·—· ···— · ·—· / — ——— / ·———— ··——— ——··· ·—·—·— ————— ·—·—·— ————— ·—·—·— ·———— / ·· ··—· / ·—· ··— —· —· ·· —· ——· / ——— —· / — ···· ·· ··· / ··· ·— —— · / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ——— ·—· / ·— / —— ··— ·—·· — ·· —·—· ·— ··· — / ·— —·· —·· ·—· · ··· ··· / ··· ··— —·—· ···· / ·— ··· / ··——— ···—— ————· ·—·—·— ··——— ···—— ————· ·—·—·— ————— ·—·—·— ··——— ——··—— / ·— —· —·· / ··— ··· · / — ···· · / ··· ·— —— · / ·— —·· —·· ·—· · ··· ··· / ·· —· / — ···· · / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·— —··· ——— ···— · / ·· —· / — ···· ·· ··· / ·— ·——· ·——· ·—·—·—',
			'operation.import.listenTitle' => '·—·· ·· ··· — · —· / ··—· ——— ·—· / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ——— — ···· · ·—· / ·— ·——· ·——· ···',
			'operation.import.listenDescriptionOnN1mm' => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / —· ·———— —— —— ·—·—·',
			'operation.import.listenDescriptionOnWsjtx' => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / ·—— ··· ·——— — —····— —··—',
			'operation.import.listenDescriptionOnBoth' => '·—·· ·· ··· — · —· ·· —· ——· / ··—· ——— ·—· / —· ·———— —— —— ·—·—· / ·— —· —·· / ·—— ··· ·——— — —····— —··—',
			'operation.import.listenDescriptionOff' => '——— ··—· ··—·',
			'operation.import.addToOperationTitle' => '·— —·· —·· / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'operation.import.addToOperationDescriptionOn' => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ··· / ·— ·—· · / ·— —·· —·· · —·· / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ··· / — ···· · —·—— / ·— ·—· ·—· ·· ···— ·',
			'operation.import.addToOperationDescriptionOff' => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ··· / ·— ·—· · / ···· · ·—·· —·· / ··— —· — ·· ·—·· / —·—— ——— ··— / — ··— ·—· —· / — ···· ·· ··· / ——— —·',
			'operation.import.pendingSectionTitle' => '—·—· ·— ·——· — ··— ·—· · —·· / ——·— ··· ——— ···',
			'operation.import.pendingEmpty' => '—· ——— — ···· ·· —· ——· / —·—· ·— ·——· — ··— ·—· · —·· / —·—— · —',
			'operation.import.stationMismatch' => ({required Object call}) => '·—·· ——— ——· ——· · —·· / ·— ··· / ${call} ——··—— / —· ——— — / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ··· — ·— — ·· ——— —·',
			'operation.import.discardAction' => '—·· ·· ··· —·—· ·— ·—· —··',
			'operation.import.gapDialogTitle' => '·· —· —·—· ·—·· ··— —·· · / · ·— ·—· ·—·· ·· · ·—· / —·—· ·— ·——· — ··— ·—· · ··· ··——··',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} / —— ——— ·—· · / ——·— ··· ——— ··· / ·—— · ·—· · / —·—· ·— ·——· — ··— ·—· · —·· / · ·— ·—· ·—·· ·· · ·—· ——··—— / —··· · ··—· ——— ·—· · / ·— / ——· ·— ·——· / ·· —· / — ···· · / —·· ·— — ·— ·—·—·— / ·· —· —·—· ·—·· ··— —·· · / — ···· · —— / — ——— ——— ··——··',
			'operation.import.gapDialogRecentOnly' => '·——— ··— ··· — / — ···· · / ·—· · —·—· · —· — / ——— —· · ···',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => '·· —· —·—· ·—·· ··— —·· · / ·— ·—·· ·—·· / ${count}',
			'map.outlineIssue.link' => '·· ··· ··· ··— · ··· ··——··',
			'map.outlineIssue.title' => '·—· · ·——· ——— ·—· — / ·— —· / ——— ··— — ·—·· ·· —· · / ·· ··· ··· ··— ·',
			'map.outlineIssue.reference' => '·—— ···· ·· —·—· ···· / ——— ··— — ·—·· ·· —· ·',
			'map.outlineIssue.severity' => '···· ——— ·—— / —··· ·— —·· / ·· ··· / ·· — ··——··',
			'map.outlineIssue.minor' => '—— ·· —· ——— ·—· / —· ·· —',
			'map.outlineIssue.major' => '—··· ·· ——· / —·· · ·— ·—··',
			'map.outlineIssue.explanation' => '·—— ···· ·— — ·————· ··· / ·—— ·—· ——— —· ——· / ·—— ·· — ···· / ·· — ··——··',
			'map.outlineIssue.explanationHint' => '·—— ···· ·— — / — ···· · / ——— ··— — ·—·· ·· —· · / ——· · — ··· / ·—— ·—· ——— —· ——· ——··—— / ·— —· —·· / ·—— ···· · ·—· ·',
			'map.outlineIssue.send' => '··· · —· —··',
			'map.outlineIssue.sending' => '··· · —· —·· ·· —· ——· / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / — / — ···· ·— —· —·— ···',
			'map.outlineIssue.copy' => '—·—· ——— ·——· —·—— / ·—· · ·——· ——— ·—· —',
			'map.outlineIssue.notSent' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ··· · —· —·· / — ···· · / ·—· · ·——· ——— ·—· —',
			'map.outlineIssue.copied' => '·—· · ·——· ——— ·—· — / —·—· ——— ·——· ·· · —··',
			'map.outlineIssue.notCopied' => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·—· ——— ·——· —·—— / — ···· · / ·—· · ·——· ——— ·—· —',
			'map.outlinesDisclaimer' => '——— ··— — ·—·· ·· —· · ··· / ·— ·—· · / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · / ——— —· ·—·· —·—— ·—·—·— / —·· ——— / —·—— ——— ··— ·—· / ——— ·—— —· / ·—· · ··· · ·— ·—· —·—· ···· —·—·——',
			'map.outlinesCredit' => ({required Object sources}) => '——— ··— — ·—·· ·· —· · ··· ———··· / ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => '—··· ——— ··— —· —·· ·— ·—· ·· · ··· ———··· / ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => '··—· ·— —·—· ·· ·—·· ·· — ·· · ··· ———··· / ${sources}',
			'map.fullCredits' => '··—· ··— ·—·· ·—·· / —·· ·— — ·— ··· · — / —·—· ·—· · —·· ·· — ···',
			'map.fewerCredits' => '··—· · ·—— · ·—· / —·—· ·—· · —·· ·· — ···',
			'map.emptyState' => '—· ——— / ——·— ··· ——— / ·—·· ——— —·—· ·— — ·· ——— —· ··· / —·—— · — ·—·—·—\n——·— ··· ——— ··· / ·—— ·· — ···· / ·— / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · ——··—— / ··· — ·— — · ——··—— / ——— ·—· / —·—· ——— ··— —· — ·—· —·—— / ·—— ·· ·—·· ·—·· / ··· ···· ——— ·—— / ··— ·——· / ···· · ·—· · ·—·—·—',
			'map.unavailable' => '— ···· · / —— ·— ·——· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—',
			'map.qthPopupTitle' => ({required Object grid}) => '——·— — ···· ———··· / ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} / —·— ——',
			'map.distanceMiles' => ({required Object distance}) => '${distance} / —— ··',
			'map.flat' => '··—· ·—·· ·— —',
			'map.globe' => '——· ·—·· ——— —··· ·',
			'map.zoomIn' => '——·· ——— ——— —— / ·· —·',
			'map.zoomOut' => '——·· ——— ——— —— / ——— ··— —',
			'map.resetNorth' => '·—· · ··· · — / — ——— / —· ——— ·—· — ···· / ··— ·——·',
			'map.postcard.button' => '——— ·——· · ·—· ·— — ·· ——— —· / ·——· ——— ··· — —·—· ·— ·—· —··',
			'map.postcard.title' => ({required Object title}) => '·——· ——— ··· — —·—· ·— ·—· —·· / ··—· ——— ·—· / ${title}',
			'map.postcard.portrait' => '·——· ——— ·—· — ·—· ·— ·· —',
			'map.postcard.landscape' => '·—·· ·— —· —·· ··· —·—· ·— ·——· ·',
			'map.postcard.square' => '··· ——·— ··— ·— ·—· ·',
			'map.postcard.save' => '··· ·— ···— · …',
			'map.postcard.download' => '—·· ——— ·—— —· ·—·· ——— ·— —··',
			'map.postcard.share' => '··· ···· ·— ·—· ·',
			'map.postcard.copy' => '—·—· ——— ·——· —·——',
			'map.postcard.copied' => '—·—· ——— ·——· ·· · —·· / — ——— / — ···· · / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··',
			'map.postcard.saved' => ({required Object path}) => '··· ·— ···— · —·· / — ——— / ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '··· ·— ···— · —·· / ${count} / ·· —— ·— ——· · ··· / — ——— / ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '··· ·— ···— · —·· / ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} / — / ${names} / ···· ·— —·· / ·— ·—·· ·—· · ·— —·· —·—— / —··· · · —· / ··· ·— ···— · —··',
			'map.postcard.downloadedMany' => ({required Object count}) => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· / ${count} / ·· —— ·— ——· · ··· / — / ·— ·—·· ·—·· ——— ·—— / — ···· · —— / ·· ··—· / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ·— ··· —·— ···',
			'map.postcard.mapLeftOut' => '— ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ·—·· ——— ·— —·· ——··—— / ··· ——— / ·· — / ·—— ·— ··· / ·—·· · ··—· — / ——— ··— —',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} / — / — ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ·—·· ——— ·— —·· ——··—— / ··· ——— / ·· — / ·—— ·— ··· / ·—·· · ··—· — / ——— ··— —',
			'map.postcard.continued' => ({required Object title}) => '${title} / —·——· —·—· ——— —· — ·· —· ··— · —·· —·——·—',
			'map.postcard.previousPage' => '·——· ·—· · ···— ·· ——— ··— ··· / ·——· ·— ——· ·',
			'map.postcard.nextPage' => '—· · —··— — / ·——· ·— ——· ·',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => '·——· ·— ——· · / ${page} / ——— ··—· / ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——·—', other: '${count} / ——·— ···', ), 
			'map.postcard.options' => '·——· ——— ··· — —·—· ·— ·—· —·· / ——— ·——· — ·· ——— —· ···',
			'map.postcard.bandLegend' => '··· ···· ——— ·—— / —··· ·— —· —·· / ·—·· · ——· · —· —··',
			'map.postcard.grayline' => '··· ···· ——— ·—— / ——· ·—· ·— —·—— ·—·· ·· —· ·',
			'map.postcard.sectionsAndOrder' => '··· ··— —— —— ·— ·—· —·—— / ··· · —·—· — ·· ——— —· ··· / ·— —· —·· / ——— ·—· —·· · ·—· ·· —· ——·',
			'map.postcard.sectionDays' => '· ·— —·—· ···· / —·· ·— —·——',
			'map.postcard.reset' => '·—· · ··· · —',
			'map.postcard.failed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —— ·— —·— · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ———··· / ${error}',
			'map.postcard.mapNotReady' => '— ···· · / —— ·— ·——· / —·· ·· —·· —· ·————· — / ··—· ·· —· ·· ··· ···· / ·—·· ——— ·— —·· ·· —· ——· ·—·—·— / —·—· ···· · —·—· —·— / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'map.postcard.saveFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— ···— · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ———··· / ${error}',
			'map.postcard.copyFailed' => '— ···· · / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —·· / —·· ·· —·· —· ·————· — / — ·— —·— · / — ···· · / ·· —— ·— ——· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'map.postcard.shareFailed' => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ···· ·— ·—· · / — ···· · / ·——· ——— ··· — —·—· ·— ·—· —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'map.postcard.fileName' => '·——· ——— ··· — —·—· ·— ·—· —··',
			'mapsView.title' => '—— ·— ·——· ···',
			'mapsView.searchHint' => '··· · ·— ·—· —·—· ···· / ·——· ·— ·—· —·— ··· ——··—— / ··· ··— —— —— ·· — ··· / ·— —· —·· / —— ——— ·—· ·',
			'mapsView.activities' => '·— —·—· — ·· ···— ·· — ·· · ···',
			'mapsView.layers' => '·—·· ·— —·—— · ·—· ···',
			'mapsView.baseMap' => '—··· ·— ··· · / —— ·— ·——·',
			'mapsView.satellite' => '··· ·— — · ·—·· ·—·· ·· — · / —·——· · ··· ·—· ·· —·——·—',
			'mapsView.facilities' => '·——· ·— ·—· —·— / ··—· ·— —·—· ·· ·—·· ·· — ·· · ···',
			'mapsView.boundaries' => '—··· ——— ··— —· —·· ·— ·—· ·· · ···',
			'mapsView.currentLocation' => '—·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— — ·· ——— —·',
			'mapsView.noMatches' => ({required Object text}) => '—· ——— — ···· ·· —· ——· / —— ·— — —·—· ···· · ··· / “ ${text} ”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ·—· · ··—· · ·—· · —· —·—· · / ·— — / ${where}', other: '${count} / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— — / ${where}', ), 
			'mapsView.startOperation' => '··· — ·— ·—· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ·—— ·· — ···· / — ···· · ··· · / ·—· · ··—· · ·—· · —· —·—· · ···',
			'activitiesView.title' => '·— —·—· — ·· ···— ·· — ·· · ···',
			'activitiesView.activitiesCountZero' => '—· ——— / ·— —·—· — ·· ···— ·· — ·· · ··· / ··· · ·—·· · —·—· — · —··',
			'activitiesView.activitiesCountOne' => '·———— / ·— —·—· — ·· ···— ·· — —·——',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} / ·— —·—· — ·· ···— ·· — ·· · ···',
			'activitiesView.empty' => '—· ——— / ·— —·—· — ·· ···— ·· — ·· · ··· / —·—— · — / — / ··— ··· · / ··· ··— ——· ——· · ··· — ·· ——— —· ··· / ·—··· / ··· · ·— ·—· —·—· ···· / —··· · ·—·· ——— ·—— / — ——— / ·— —·· —·· / ——— —· ·',
			'activitiesView.removeActivity' => '·—· · —— ——— ···— ·',
			'activitiesView.openReferenceLink' => ({required Object name}) => '——— ·——· · —· / ${name}',
			'activitiesView.editActivity' => '· —·· ·· — / ·— —·—· — ·· ···— ·· — —·——',
			'activitiesView.manageExtensions' => '—— ·— —· ·— ——· · / · —··— — · —· ··· ·· ——— —· ···',
			'activitiesView.manage' => '—— ·— —· ·— ——· ·',
			'activitiesView.activitiesTitle1' => ({required Object first}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first} / ·— —· —·· / ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· ———··· / ${first} ——··—— / ${second} / ·— —· —·· / ${more} / —— ——— ·—· ·',
			'activitiesView.reference' => '·—· · ··—· · ·—· · —· —·—· ·',
			'activitiesView.invalidReference' => '—· ——— — / ···— ·— ·—·· ·· —··',
			'activitiesView.duplicateReference' => '·— ·—·· ·—· · ·— —·· —·—— / ·— —·· —·· · —··',
			'activitiesView.searchHint' => '··· · ·— ·—· —·—· ···· / —··· —·—— / —· ·— —— · ——··—— / ·—· · ··—· · ·—· · —· —·—· · / ——— ·—· / ·— —· —·—— — ···· ·· —· ——· / · ·—·· ··· · …',
			'activitiesView.noSuggestions' => '—· ——— / —— ·— — —·—· ···· · ···',
			'activitiesView.noSuggestionsHint' => '··· · ·— ·—· —·—· ···· / —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · / —· ·— —— · / ——— ·—· / —· ··— —— —··· · ·—· / ·— —··· ——— ···— ·',
			'activitiesView.noSuggestionsExample' => '—·——· ··—· ——— ·—· / · —··— ·— —— ·——· ·—·· · / ·————· — ·—· ·— ·· ·—·· ·————· / ——— ·—· / ·————· ····— ····· ····· —···· ·————· —·——·—',
			'activitiesView.allOptions' => '·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ···',
			'activitiesView.determiningLocation' => '—·· · — · ·—· —— ·· —· ·· —· ——· / —·—· ··— ·—· ·—· · —· — / ·—·· ——— —·—· ·— — ·· ——— —· …\n·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / ——· ·——· ··· / ··—· ·· —··— / — ——— / ··—· ·· —· —·· / —· · ·— ·—· —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · ···',
			'activitiesView.locationUnavailableTitle' => '·—·· ——— —·—· ·— — ·· ——— —· / —·· ·— — ·— / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'activitiesView.locationDeniedTitle' => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —·· · —· ·· · —··',
			'activitiesView.locationBlockedTitle' => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —··· ·—·· ——— —·—· —·— · —··',
			'activitiesView.noNearbyReason' => '—·—· ·— —· —· ——— — / —·· · — · ·—· —— ·· —· · / —· · ·— ·—· —··· —·—— / ·—· · ··—· · ·—· · —· —·—· · ···',
			'activitiesView.locationManualHint' => ({required Object icon}) => '— ·— ·——· / ${icon} / — ——— / —— ·— —· ··— ·— ·—·· ·—·· —·—— / · —· — · ·—· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— — ·· ——— —· ——··——\n——— ·—· / ·——— ··— ··· — / ··· · ·— ·—· —·—· ···· / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · ··· / —··· —·—— / —· ·— —— ·',
			'activitiesView.locationGrantAction' => '·— ·—·· ·—·· ——— ·—— / ·—·· ——— —·—· ·— — ·· ——— —· / ·— —·—· —·—· · ··· ···',
			'activitiesView.locationSettingsAction' => '——— ·——· · —· / ··· · — — ·· —· ——· ···',
			'activitiesView.locationSettingsUnavailable' => '·— ·—·· ·—·· ——— ·—— / ·—·· ——— —·—· ·— — ·· ——— —· / ·— —·—· —·—· · ··· ··· / ·· —· / —·—— ——— ··— ·—· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···',
			'activitiesView.locationGrantRefused' => '··· — ·· ·—·· ·—·· / —· ——— / ·—·· ——— —·—· ·— — ·· ——— —· / — / — ···· · / ··· —·—— ··· — · —— / ··· ·— ·· —·· / —· ——— / ·— ——· ·— ·· —·',
			'activitiesView.searchUnavailableTitle' => '·— —·—· — ·· ···— ·· — —·—— / ··· · ·— ·—· —·—· ···· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'activitiesView.searchUnavailableReason' => '—· ——— / ·— —·—· — ·· ···— ·· — —·—— / · —··— — · —· ··· ·· ——— —· / —·—· ——— ··— ·—·· —·· / ·—· ··— —· / — ···· · / ··· · ·— ·—· —·—· ···· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—',
			'activitiesView.emptySheet' => '··— ··· · / ··· ··— ——· ——· · ··· — ·· ——— —· ··· / ·—··· / ··· · ·— ·—· —·—· ···· / —··· · ·—·· ——— ·—— / — ——— / ·— —·· —·· / ——— —· ·',
			'activitiesView.exports' => '· —··— ·——· ——— ·—· — ···',
			'activitiesView.exportLogs' => '· —··— ·——· ——— ·—· — / ·—·· ——— ——· ···',
			'activitiesView.tools' => '— ——— ——— ·—·· ···',
			'activitiesView.toolsTitle' => '——— ·——· · ·—· ·— — ·· ——— —· / — ——— ——— ·—·· ···',
			'activitiesView.operationDetails' => '——— ·——· · ·—· ·— — ·· ——— —· / —·· · — ·— ·· ·—·· ···',
			'activitiesView.share' => '··· ···· ·— ·—· ·',
			'activitiesView.archive' => '·— ·—· —·—· ···· ·· ···— ·',
			'activitiesView.deleteOperation' => '—·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·',
			'activitiesView.undeleteOperation' => '··— —· —·· · ·—·· · — · / ——— ·——· · ·—· ·— — ·· ——— —·',
			'activitiesView.alreadySelected' => '·— ·—·· ·—· · ·— —·· —·—— / ··· · ·—·· · —·—· — · —··',
			'activitiesView.selected' => '··· · ·—·· · —·—· — · —··',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} / ——— ··—· / ${count}',
			'activitiesView.previousPick' => '·——· ·—· · ···— ·· ——— ··— ··· / —— ·— — —·—· ····',
			'activitiesView.nextPick' => '—· · —··— — / —— ·— — —·—· ····',
			'activitiesView.retiredReference' => '·—· · — ·· ·—· · —··',
			'activitiesView.enableExtension' => ({required Object name}) => '· —· ·— —··· ·—·· · / ${name}',
			'activitiesView.enableExtensionHint' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / —·—· ··— ·—· ·—· · —· — ·—·· —·—— / · —· ·— —··· ·—·· · —··',
			'activitiesView.enableExtensionForRefHint' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ···· ·— —· —·· ·—·· · ··· / ——— —· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · ··· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / —·—· ··— ·—· ·—· · —· — ·—·· —·—— / · —· ·— —··· ·—·· · —··',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} / ·· ··· / —· ——— — / ·—· ··— —· —· ·· —· ——·',
			'activitiesView.extensionNotRunningHint' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / ···· ·— ··· / —··· · · —· / —·· ·· ··· ·— —··· ·—·· · —·· ——··—— / ——— ·——· · —· / · —··— — · —· ··· ·· ——— —· / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / —— ——— ·—· · / ·· —· ··—· ———',
			'activitiesView.installExtension' => ({required Object name}) => '·· —· ··· — ·— ·—·· ·—·· / ${name}',
			'activitiesView.installExtensionHint' => '— ···· ·· ··· / · —··— — · —· ··· ·· ——— —· / —— ·— — —·—· ···· · ··· / —·—— ——— ··— ·—· / ··· · ·— ·—· —·—· ···· ——··—— / —··· ··— — / ·· — / ·· ··· / —· ——— — / ·· —· ··· — ·— ·—·· ·—·· · —··',
			'activitiesView.onlyCatalogMatches' => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / ·· —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· ·—·—·—\n·· —· ··· — ·— ·—·· ·—·· / — ···· · —— / ·· —· / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—',
			'activitiesView.setupUnavailable' => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—·· ——— ·— —·· / — ···· ·· ··· / ·— —·—· — ·· ···— ·· — —·—— ·————· ··· / ··· · — ··— ·——· / — / — ·—· —·—— / ·— ——· ·— ·· —· / ··—· ·—· ——— —— / —— ·— —· ·— ——· ·',
			'activitiesView.controlsUnavailableTitle' => '·— —·—· — ·· ···— ·· — —·—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'activitiesView.controlsUnavailableReason' => '—·—— ——— ··— ·—· / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— ·—· · / ··· ·— ··—· · ——··—— / —··· ··— — / · —·· ·· — ·· —· ——· / — ···· · —— / ·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—',
			'activitiesView.controlsUnavailableRetry' => '·—· · — ·—· —·——',
			'activitiesView.onlyDisabledMatches' => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / · —··— — · —· ··· ·· ——— —· ··· / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· ·—·—·—\n· —· ·— —··· ·—·· · / — ···· · —— / ·· —· / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—',
			'activitiesView.onlyNotRunningMatches' => '—· ——— / —— ·— — —·—· ···· · ···\n··· ——— —— · / · —··— — · —· ··· ·· ——— —· ··· / — ···· ·— — / —— ·· ——· ···· — / ···· ·— ···— · / ·—· · ··· ··— ·—·· — ··· / ·— ·—· · / —· ——— — / ·—· ··— —· —· ·· —· ——· ·—·—·—\n··· · · / ·— —·—· — ·· ···— ·· — —·—— / — —·—— ·——· · ··· / —··· · ·—·· ——— ·—— ·—·—·—',
			'activitiesView.mapToggle' => '—— ·— ·——·',
			'activitiesView.searchToggle' => '··· · ·— ·—· —·—· ····',
			'activitiesView.addToOperation' => '·— —·· —·· / — ——— / ——— ·——· · ·—· ·— — ·· ——— —·',
			'activitiesView.addToOperationShort' => '·— —·· —·· / — ——— / ——— ·——· ·—·—·—',
			'activitiesView.mapEmptyState' => '—· ——— / ·—· · ··· ··— ·—·· — ··· / — ——— / ··· ···· ——— ·—— / ——— —· / — ···· · / —— ·— ·——·',
			'activitiesView.mapEmptyStateHint' => '··· ·—— ·· — —·—· ···· / —··· ·— —·—· —·— / — ——— / — ···· · / ·—·· ·· ··· — ——··—— / ——— ·—· / ··· · ·— ·—· —·—· ···· / ··—· ——— ·—· / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· ·',
			'activitiesView.imports' => '·· —— ·——· ——— ·—· — ···',
			'loggingControls.timeUtc' => '— ·· —— · / —·——· ··— — —·—· —·——·—',
			'loggingControls.date' => '—·· ·— — ·',
			'loggingControls.now' => '—· ——— ·——',
			'loggingControls.manualTimeSettings' => '—— ·— —· ··— ·— ·—·· / — ·· —— ·',
			'loggingControls.manualTimeIncrement' => '·· —· —·—· ·—· · —— · —· — / ·——· · ·—· / ——·— ··· ———',
			'loggingControls.manualTimeIncrementNone' => '—· ——— —· ·',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / —— ·· —· ··— — ·', other: '${count} / —— ·· —· ··— — · ···', ), 
			'loggingControls.frequency' => '··—· ·—· · ——·— ··— · —· —·—· —·——',
			'loggingControls.mode' => '—— ——— —·· ·',
			'loggingControls.theirCall' => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—··',
			'loggingControls.noteField' => '—· ——— — ·',
			'loggingControls.todoField' => '— ——— —·· ———',
			'loggingControls.sent' => '··· · —· —',
			'loggingControls.rcvd' => '·—· —·—· ···— —··',
			'loggingControls.more' => '—— ——— ·—· ·',
			'loggingControls.revert' => '·—· · ···— · ·—· —',
			'loggingControls.undoDelete' => '··— —· —·· ——— / —·· · ·—·· · — ·',
			'loggingControls.restore' => '·—· · ··· — ——— ·—· ·',
			'loggingControls.wipe' => '·—— ·· ·——· ·',
			'loggingControls.undo' => '··— —· —·· ———',
			'loggingControls.pendingDeleteTapWarning' => '— ·— ·——· / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ——·— ··· ———',
			'loggingControls.pendingDeleteClickWarning' => '—·—· ·—·· ·· —·—· —·— / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ——·— ··· ———',
			'loggingControls.deletedQsoWarning' => '—·· · ·—·· · — · —·· / ——·— ··· ———',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => '— ·— ·——· / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => '—·—· ·—·· ·· —·—· —·— / — ···· · / — ·—· ·— ··· ···· —·—· ·— —· / ——— —· · / —— ——— ·—· · / — ·· —— · / — ——— / —·· · ·—·· · — · / — ···· ·· ··· / ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '—·· · ·—·· · — · —·· / ${kind}',
			'loggingControls.timeControl' => '— ·· —— ·',
			'loggingControls.radioControl' => '·—· ·— —·· ·· ———',
			'loggingControls.powerControl' => '·——· ——— ·—— · ·—·',
			'loggingControls.notesControl' => '—· ——— — · ···',
			'loggingControls.power' => '·——· ——— ·—— · ·—·',
			'loggingControls.powerUnit' => '·——',
			'loggingControls.controlSettings' => '·—·· ——— ——· ——· ·· —· ——· / —·—· ——— —· — ·—· ——— ·—·· ···',
			'loggingControls.spottingControl' => '··· ·——· ——— — — ·· —· ——·',
			'loggingControls.spottingSelfControl' => '··· · ·—·· ··—· —····— ··· ·——· ——— — — ·· —· ——·',
			'loggingControls.spotSelfAt' => ({required Object freq}) => '··· · ·—·· ··—· —····— ··· ·——· ——— — / ·— — / ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => '··· ·——· ——— — / ${call} / ·— — / ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => '— ——— ——— / ·—·· ·— — · / — ——— / ··· ·——· ——— — / ${call}',
			'loggingControls.spotNoFreq' => '··—· ·· ·—· ··· — / ··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ··· ·——· ——— —',
			'loggingControls.spotComment' => '—·—· ——— —— —— · —· —',
			'loggingControls.spottingAutoControl' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— —',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => '·—· · —····— ··· ·——· ——— — / · ···— · ·—· —·—— / ${minutes} / —— ·· —·',
			'loggingControls.spotAutoNext' => ({required Object time}) => '·— ··— — ——— / ·· —· / ${time} ·—·—·— / ··· — ——— ·——· ··——··',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => '·— ··— — ——— / ·· —· / ${minutes} ——',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => '·— ··— — ——— / ·· —· / ${seconds} ···',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => '·— ··— — ——— / ·· —· / ${seconds}',
			'loggingControls.spotAutoNotStarted' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —· ——— — / ··· — ·— ·—· — · —·· ———··· / — ···· · / ··· ·——· ——— — / —·· ·· —·· / —· ——— — / ——· ——— / — ···· ·—· ——— ··— ——· ····',
			'loggingControls.spotAutoMoved' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —· ——— — / ··· — ·— ·—· — · —·· ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ···· ·— —· ——· · —·· / ·—— ···· ·· ·—·· · / ··· ·——· ——— — — ·· —· ——·',
			'loggingControls.spotAutoStopped' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —··',
			'loggingControls.spotAutoLeftFreq' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —·· ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ···· ·— —· ——· · —··',
			'loggingControls.spotAutoNoFreq' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ··· — ——— ·——· ·——· · —·· ———··· / — ···· · / ·—· ·— —·· ·· ——— / ·—· · ·——· ——— ·—· — ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'loggingControls.spotBusy' => '·— —· ——— — ···· · ·—· / ··· ·——· ——— — / ·· ··· / ··· — ·· ·—·· ·—·· / —··· · ·· —· ——· / ··· · —· —',
			'loggingControls.bandOrFreqRequired' => '··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— ·—· / —··· ·— —· —·· / —··· · ··—· ——— ·—· · / ·—·· ——— ——· ——· ·· —· ——·',
			'loggingControls.missingBand' => '—· ——— / —··· ·— —· —··',
			'loggingControls.missingMode' => '—· ——— / —— ——— —·· ·',
			'loggingControls.saveFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— ···— · ———··· / ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —·· · ·—·· · — · ———··· / ${error}',
			'loggingControls.info.noQsos' => '—· ——— / ——·— ··· ——— ··· / —·—— · — ·—·—·— ·—·—·— ·—·—·— / ·—·· · — ·————· ··· / ——· · — / ——— —· / — ···· · / ·— ·· ·—· —·—·——',
			'loggingControls.info.qsoCountOne' => '·———— / ——·— ··· ———',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} / ——·— ··· ——— ···',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} / ·· —· / ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} / ··· ·· —· —·—· · / ·—·· ·— ··· —',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} / ——·— —··—· ···· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— —————',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} / ——·— —··—· ···· / ··—· ——— ·—· / ·—·· ·— ··· — / ·———— ————— —————',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} / — ———',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / — ———',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / — ———',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} / ·— ·—— ·— —·——',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / ·— ·—— ·— —·——',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / ·— ·—— ·— —·——',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer} ———··· / ${notice}',
			'loggingControls.info.noticeDupe' => '—·· ··— ·——· · —·—·——',
			'loggingControls.info.noticeNewBand' => '—· · ·—— / —··· ·— —· —··',
			'loggingControls.info.noticeNewMode' => '—· · ·—— / —— ——— —·· ·',
			'loggingControls.info.noticeNewDXCC' => '—· · ·—— / —·· —··— —·—· —·—·',
			'loggingControls.info.noticeNewState' => '—· · ·—— / ··· — ·— — ·',
			'loggingControls.info.noticeNewProvince' => '—· · ·—— / ·——· ·—· ——— ···— ·· —· —·—· ·',
			'loggingControls.info.noticeNewDay' => '—· · ·—— / —·· ·— —·——',
			'loggingControls.info.noticeNewRef' => '—· · ·—— / ·—· · ··—·',
			'loggingControls.info.noticeNewMult' => '—· · ·—— / —— ··— ·—·· —',
			'loggingControls.info.noticeNewZone' => '—· · ·—— / ——·· ——— —· ·',
			'loggingControls.info.noticeInvalidMode' => '·—— ·—· ——— —· ——· / —— ——— —·· ·',
			'loggingControls.info.noticeInvalidBand' => '·—— ·—· ——— —· ——· / —··· ·— —· —··',
			'loggingControls.info.noticeInvalidCategory' => '—· ——— — / ·—— ——— ·—· —·— ·— —··· ·—·· ·',
			'loggingControls.info.noticeOverTime' => '— ·· —— · / ——— ···— · ·—·',
			'loggingControls.info.noticeWorkedBefore' => '·—— ——— ·—· —·— · —·· / —··· · ··—· ——— ·—· ·',
			'loggingControls.info.noticeNewPark' => '—· · ·—— / ·——· ·— ·—· —·—',
			'loggingControls.info.noticeNewSection' => '—· · ·—— / ··· · —·—· — ·· ——— —·',
			'loggingControls.info.noticeBonusStation' => '—··· ——— —· ··— ··· / ··· — ·— — ·· ——— —· —·—·——',
			'loggingControls.info.noticeMissingExchange' => '—· ——— / · —··— —·—· ···· ·— —· ——· ·',
			'loggingControls.info.noticeInvalidExchange' => '—··· ·— —·· / · —··— —·—· ···· ·— —· ——· ·',
			'loggingControls.info.noticeUnknownEvent' => '··— —· —·— —· ——— ·—— —· / · ···— · —· —',
			'loggingControls.info.noticeIncompleteCall' => '·· —· —·—· ——— —— ·——· ·—·· · — · / —·—· ·— ·—·· ·—·· / — / —· ——— — / ··· —·—· ——— ·—· · —··',
			'loggingControls.info.noticeOurGrid' => '··· · — / ——— ··— ·—· / ——· ·—· ·· —··',
			'loggingControls.info.noticeRareCounty' => '·—· ·— ·—· · / —·—· ——— ··— —· — —·—— —·—·——',
			'loggingControls.info.noticeOurLocation' => '··· · — / ——— ··— ·—· / —·—· ——— ··— —· — —·——',
			'loggingControls.info.noticeShortGrid' => '——· ·—· ·· —·· / — ——— ——— / ··· ···· ——— ·—· —',
			'formChrome.untitled' => '—·——· ··— —· — ·· — ·—·· · —·· —·——·—',
			'formChrome.showMore' => '··· ···· ——— ·—— / —— ——— ·—· ·',
			'formChrome.showAll' => '··· ···· ——— ·—— / ·— ·—·· ·—··',
			'formChrome.showFewer' => '··· ···· ——— ·—— / ··—· · ·—— · ·—·',
			'formChrome.defaults' => '—·· · ··—· ·— ··— ·—·· — ···',
			'formChrome.search' => '··· · ·— ·—· —·—· ····',
			'formChrome.clear' => '—·—· ·—·· · ·— ·—·',
			'formChrome.openPage' => '——— ·——· · —· / ·——· ·— ——· ·',
			'formChrome.connected' => '—·—· ——— —· —· · —·—· — · —··',
			'formChrome.notConnected' => '—· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'formChrome.manage' => '—— ·— —· ·— ——· ·',
			'formChrome.connect' => '—·—· ——— —· —· · —·—· —',
			'formChrome.formTitle' => '··—· ——— ·—· ——',
			'formChrome.addItem' => ({required Object label}) => '·— —·· —·· / ${label}',
			'formChrome.editItem' => ({required Object label}) => '· —·· ·· — / ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => '··· ···· ——— ·—— ·· —· ——· / ${shown} / ——— ··—· / ${total} / —·——· ${selected} / ··· · ·—·· · —·—· — · —·· —·——·—',
			'formChrome.validationError' => ({required Object error}) => '···— ·— ·—·· ·· —·· ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}',
			'formChrome.transformationError' => ({required Object error}) => '— ·—· ·— —· ··· ··—· ——— ·—· —— ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}',
			'formChrome.actionError' => ({required Object error}) => '· ·—· ·—· ——— ·—· ———··· / ${error}',
			'formChrome.removeItem' => '—·· · ·—·· · — ·',
			'formChrome.deleteItemTitle' => ({required Object name}) => '—·· · ·—·· · — · / ${name} ··——··',
			'formChrome.storageUnavailable' => '·—·· ——— ——· ·· —· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'qsoEditForm.title' => '· —·· ·· — / ——·— ··· ———',
			_ => null,
		} ?? switch (path) {
			'qsoEditForm.operatorCall' => '——— ·——· · ·—· ·— — ——— ·—·',
			'qsoEditForm.position' => '·——· ——— ··· ·· — ·· ——— —·',
			'qsoEditForm.theirName' => '—· ·— —— ·',
			'qsoEditForm.theirGrid' => '——· ·—· ·· —··',
			'qsoEditForm.theirState' => '··· — ·— — ·',
			'qsoEditForm.band' => '—··· ·— —· —··',
			'qsoEditForm.notes' => '—· ——— — · ···',
			'qsoEditForm.sectionQso' => '——·— ··· ———',
			'qsoEditForm.sectionTheir' => '— ···· · ·· ·—· / ·· —· ··—· ———',
			'qsoEditForm.sectionOur' => '——— ··— ·—· / ·· —· ··—· ———',
			'qsoEditForm.sectionNotes' => '—· ——— — · ···',
			'qsoEditForm.theirCity' => '—·—· ·· — —·——',
			'qsoEditForm.theirCounty' => '—·—· ——— ··— —· — —·——',
			'qsoEditForm.theirEntity' => '· —· — ·· — —·——',
			'qsoEditForm.theirCqZone' => '—·—· ——·— / ——·· ——— —· ·',
			'qsoEditForm.theirItuZone' => '·· — ··— / ——·· ——— —· ·',
			'qsoEditForm.theirArrlSection' => '·— ·—· ·—· ·—·· / ··· · —·—· — ·· ——— —·',
			'qsoEditForm.theirLat' => '·—·· ·— — ·· — ··— —·· ·',
			'qsoEditForm.theirLon' => '·—·· ——— —· ——· ·· — ··— —·· ·',
			'qsoEditForm.theirPower' => '— ···· · ·· ·—· / ·——· ——— ·—— · ·—·',
			'qsoList.empty' => '—· ——— / ——·— ··· ——— ··· / —·—— · — / — / ·—— ——— ·—· —·— / ··· ——— —— · ——— —· · —·—·——',
			'qsoList.bandOrModeWarning' => '·——· ·—·· · ·— ··· · / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / —··· ·— —· —·· / ·— —· —·· / —— ——— —·· · / ·— ·—· · / —·—· ——— ·—· ·—· · —·—· —',
			'qsoList.today' => '— ——— —·· ·— —·——',
			'qsoList.yesterday' => '—·—— · ··· — · ·—· —·· ·— —·——',
			'qsoList.tomorrow' => '— ——— —— ——— ·—· ·—· ——— ·——',
			'qsoList.find.menuItem' => ({required Object shortcut}) => '··—· ·· —· —·· / ·· —· / ·—·· ——— ——· / —·——· ${shortcut} —·——·—',
			'qsoList.find.menuItemNoShortcut' => '··—· ·· —· —·· / ·· —· / ·—·· ——— ——·',
			'qsoList.find.hint' => '——·— ··· ——— / —· ··— —— —··· · ·—· / ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'qsoList.find.noMatches' => '—· ——— / —— ·— — —·—· ····',
			'qsoList.find.noOperationQsos' => '—· ——— / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsoList.find.noPeriodQsos' => '—· ——— / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ·——· · ·—· ·· ——— —··',
			'qsoList.find.outsideQsosOne' => '·———— / ——·— ··· ——— / ——— ··— — ··· ·· —·· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} / ——·— ··· ——— ··· / ——— ··— — ··· ·· —·· · / ——— ··—· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsoList.find.pastQsosOne' => '·———— / ·——· ·— ··· — / ——·— ··· ———',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} / ·——· ·— ··· — / ——·— ··· ——— ···',
			'loggingPanel.stats' => '——— ·——· · ·—· ·— — ·· ——— —· / ··· — ·— — ···',
			'loggingPanel.scoring' => '··· —·—· ——— ·—· ·· —· ——·',
			'loggingPanel.dxccEntities' => '—·· —··— —·—· —·—· / · —· — ·· — ·· · ···',
			'loggingPanel.statesWorked' => '··· — ·— — · ···',
			'loggingPanel.provincesWorked' => '·——· ·—· ——— ···— ·· —· —·—· · ···',
			'loggingPanel.duplicates' => '—·· ··— ·——· ·—·· ·· —·—· ·— — · ···',
			'callInfo.qrz' => '——·— ·—· ——··',
			'callInfo.showImage' => '··· ···· ——— ·—— / ·· —— ·— ——· ·',
			'callInfo.imageUnavailable' => '·——· ···· ——— — ——— / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'callInfo.photo' => '·——· ···· ——— — ———',
			'callInfo.notes' => '—· ——— — · ···',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} / — ———',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / — ———',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / — ———',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} / ·— ·—— ·— —·——',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} / —·——· ${bearing} ° —·——·— / ·— ·—— ·— —·——',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} / —·——· ${bearing} ° / —··—· / ${reverse} ° —·——·— / ·— ·—— ·— —·——',
			'callInfo.thisOpCountOne' => '·———— / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'callInfo.otherOpsCountOne' => '·———— / ——·— ··· ——— / ·· —· / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ···',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} / ——·— ··· ——— ··· / ·· —· / ——— — ···· · ·—· / ——— ·——· · ·—· ·— — ·· ——— —· ···',
			'callInfo.andMore' => ({required Object count}) => '… / ·— —· —·· / ${count} / —— ——— ·—· ·',
			'callInfo.withCall' => ({required Object call}) => '·—— ·· — ···· / ${call}',
			'callInfo.fromOperation' => ({required Object where}) => '··—· ·—· ——— —— / ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} / ·· —· / ·—·· ·— ··· — / ——··· / —·· ·— —·—— ···',
			'callInfo.history.today' => ({required Object n}) => '${n} / — ——— —·· ·— —·——',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${n} / ——·— ··· ———', other: '${n} / ——·— ··· ——— ···', ), 
			'settings.title' => '··· · — — ·· —· ——· ···',
			'settings.language' => '·—·· ·— —· ——· ··— ·— ——· ·',
			'settings.languageSystem' => ({required Object language}) => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / —·——· ${language} —·——·—',
			'settings.theme.title' => '— ···· · —— · / —— ——— —·· ·',
			'settings.theme.system' => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···',
			'settings.theme.light' => '·—·· ·· ——· ···· —',
			'settings.theme.dark' => '—·· ·— ·—· —·—',
			'settings.themeDescription.system' => '··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···',
			'settings.themeDescription.light' => '·— ·—·· ·—— ·— —·—— ··· / ·· —· / ·—·· ·· ——· ···· — / —— ——— —·· ·',
			'settings.themeDescription.dark' => '·— ·—·· ·—— ·— —·—— ··· / ·· —· / —·· ·— ·—· —·— / —— ——— —·· ·',
			'settings.fontScale' => '··—· ——— —· — / ··· —·—· ·— ·—·· ·',
			'settings.fontScaleOpts.smallestMinusMinus' => '··· —— ·— ·—·· ·—·· · ··· — —····— —····—',
			'settings.fontScaleOpts.smallestMinus' => '··· —— ·— ·—·· ·—·· · ··· — —····—',
			'settings.fontScaleOpts.smallest' => '··· —— ·— ·—·· ·—·· · ··· —',
			'settings.fontScaleOpts.smaller' => '··· —— ·— ·—·· ·—·· · ·—·',
			'settings.fontScaleOpts.normal' => '—· ——— ·—· —— ·— ·—··',
			'settings.fontScaleOpts.larger' => '·—·· ·— ·—· ——· · ·—·',
			'settings.fontScaleOpts.largest' => '·—·· ·— ·—· ——· · ··· —',
			'settings.fontScaleOpts.largestPlus' => '·—·· ·— ·—· ——· · ··· — ·—·—·',
			'settings.fontScaleOpts.largestPlusPlus' => '·—·· ·— ·—· ——· · ··· — ·—·—· ·—·—·',
			'settings.keepDeviceAwake.title' => '—·— · · ·——· / —·· · ···— ·· —·—· · / ·— ·—— ·— —·— ·',
			'settings.keepDeviceAwake.descriptionOn' => '··· — ·— —·—— ·· —· ——· / ·— ·—— ·— —·— · / ·—— ···· ·· ·—·· · / —·—— ——— ··— / ·— ·—· · / ——— —· / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ···— ·· · ·—— / ——— ·—· / ·— / ··· —·—— —· —·—· / ·· ··· / ·· —· / ·——· ·—· ——— ——· ·—· · ··· ···',
			'settings.keepDeviceAwake.descriptionOff' => '··· ·—·· · · ·——· ·· —· ——· / ·— ··· / ··— ··· ··— ·— ·—··',
			'settings.layoutDensity' => '·—·· ·— —·—— ——— ··— — / —·· · —· ··· ·· — —·——',
			'settings.layoutDensityOpts.auto' => '·— ··— — ——— —— ·— — ·· —·—·',
			'settings.layoutDensityOpts.densest' => '—·· · —· ··· · ··· —',
			'settings.layoutDensityOpts.dense' => '—·· · —· ··· ·',
			'settings.layoutDensityOpts.normal' => '—· ——— ·—· —— ·— ·—··',
			'settings.layoutDensityOpts.sparse' => '··· ·——· ·— ·—· ··· ·',
			'settings.layoutDensityOpts.sparsest' => '··· ·——· ·— ·—· ··· · ··· —',
			'settings.layoutDensityClamped' => ({required Object effective}) => '— ···· · / ·—— ·· —· —·· ——— ·—— / ·· ··· / — ——— ——— / ··· ···· ——— ·—· — ——··—— / ··— ··· ·· —· ——· / ${effective}',
			'settings.layoutDensityAtLimit' => '·— ··· / ··—· ·— ·—· / ·— ··· / ·· — / ——· ——— · ···',
			'settings.distanceUnits' => '—·· ·· ··· — ·— —· —·—· · / ··— —· ·· — ···',
			'settings.distanceUnitsOpts.kilometers' => '—·— ·· ·—·· ——— —— · — · ·—· ···',
			'settings.distanceUnitsOpts.miles' => '—— ·· ·—·· · ···',
			'settings.userInterface' => '··— ··· · ·—· / ·· —· — · ·—· ··—· ·— —·—· ·',
			'settings.logging.title' => '·—·· ——— ——· ——· ·· —· ——·',
			'settings.logging.leftieMode.title' => '·—·· · ··—· — ·· · / —— ——— —·· ·',
			'settings.logging.leftieMode.descriptionOn' => '··— ··· ·· —· ——· / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· / ·—·· · ··—· — —····— ···· ·— —· —·· · —·· / ··— ··· · ·—· ···',
			'settings.logging.leftieMode.descriptionOff' => '··— ··· ·· —· ——· / ·—·· ·— —·—— ——— ··— — / ··—· ——— ·—· / ·—· ·· ——· ···· — —····— ···· ·— —· —·· · —·· / ··— ··· · ·—· ···',
			'settings.logging.countryFlags.title' => '—·—· ——— ··— —· — ·—· —·—— / ··—· ·—·· ·— ——· ···',
			'settings.logging.countryFlags.dx' => '··· ···· ——— ·—— / ——— —· ·—·· —·—— / ··—· ——— ·—· / —·· —··— / —·—· ——— —· — ·— —·—· — ···',
			'settings.logging.countryFlags.all' => '··· ···· ——— ·—— / ··—· ·—·· ·— ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / —·—· ——— —· — ·— —·—· — ···',
			'settings.logging.countryFlags.none' => '—·· ——— —· ·————· — / ··· ···· ——— ·—— / ·— —· —·—— / ··—· ·—·· ·— ——· ···',
			'settings.logging.countryFlagsDescription.dx' => '··· ···· ——— ·—— ·· —· ——· / ··—· ·—·· ·— ——· ··· / ——— —· ·—·· —·—— / ··—· ——— ·—· / —·· —··— / —·—· ——— —· — ·— —·—· — ···',
			'settings.logging.countryFlagsDescription.all' => '··· ···· ——— ·—— ·· —· ——· / ··—· ·—·· ·— ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / —·—· ——— —· — ·— —·—· — ···',
			'settings.logging.countryFlagsDescription.none' => '—· ——— — / ··· ···· ——— ·—— ·· —· ——· / ·— —· —·—— / ··—· ·—·· ·— ——· ···',
			'settings.logging.suggestDefaultOperator.title' => '··· ··— ——· ——· · ··· — / ——— ·——· · ·—· ·— — ——— ·—·',
			'settings.logging.suggestDefaultOperator.descriptionOn' => '——— ··—· ··—· · ·—· ·· —· ——· / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / ·—— ···· · —· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ·—· ··— —· ··· / ··— —· —·· · ·—· / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ··· — ·— — ·· ——— —· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'settings.logging.suggestDefaultOperator.descriptionOff' => '·—·· · ·— ···— ·· —· ——· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· / —··· ·—·· ·— —· —·— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··—· ·· ·—·· ·—·· / ·· — / ·· —·',
			'settings.logging.showBearing.title' => '··· ···· ——— ·—— / —··· · ·— ·—· ·· —· ——·',
			'settings.logging.showBearing.descriptionOn' => '··· ···· ——— ·—— ·· —· ——· / · ··· — ·· —— ·— — · —·· / —··· · ·— ·—· ·· —· ——· / — ——— / ··· — ·— — ·· ——— —·',
			'settings.logging.showBearing.descriptionOff' => '—· ——— — / ··· ···· ——— ·—— ·· —· ——· / —··· · ·— ·—· ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·',
			'settings.logging.showReverseBearing.title' => '·— ·—·· ··· ——— / ··· ···· ——— ·—— / ·—· · ···— · ·—· ··· · / —··· · ·— ·—· ·· —· ——·',
			'settings.logging.showReverseBearing.descriptionOn' => '··· ···· ——— ·—— ·· —· ——· / — ···· · / —··· · ·— ·—· ·· —· ——· / ··—· ·—· ——— —— / — ···· · / ··· — ·— — ·· ——— —· / — ——— ——— ——··—— / ·— ··· / ·—··—· ····— ····· ° / —··—· / ··——— ··——— ····· ° ·—··—·',
			'settings.logging.showReverseBearing.descriptionOff' => '——— —· ·—·· —·—— / ··· ···· ——— ·—— ·· —· ——· / — ···· · / —··· · ·— ·—· ·· —· ——· / — ——— / — ···· · / ··· — ·— — ·· ——— —·',
			'settings.logging.switchSentRcvd.title' => '··· ·—— ·· — —·—· ···· / ··· ·· ——· —· ·— ·—·· / ·—· · ·——· ——— ·—· — / ——— ·—· —·· · ·—·',
			'settings.logging.switchSentRcvd.sentFirst' => '··· · —· — / ··—· ·· ·—· ··· — ——··—— / ·—· —·—· ···— —·· / ··· · —·—· ——— —· —··',
			'settings.logging.switchSentRcvd.rcvdFirst' => '·—· —·—· ···— —·· / ··—· ·· ·—· ··· — ——··—— / ··· · —· — / ··· · —·—· ——— —· —··',
			'settings.logging.jumpAfterRST.title' => '·——— ··— —— ·——· / — ——— / —· · —··— — / ··—· ·· · ·—·· —·· / ——— —· / ·—· ··· — / · —· — ·—· —·——',
			'settings.logging.jumpAfterRST.descriptionOn' => '·——— ··— —— ·——· ·· —· ——· / ·— ··—· — · ·—· / ·—· ··· — / ·· ··· / · —· — · ·—· · —··',
			'settings.logging.jumpAfterRST.descriptionOff' => '—· ——— — / ·——— ··— —— ·——· ·· —· ——· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——',
			'settings.logging.defaultReport.title' => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / ·——· ···· ——— —· ·',
			'settings.logging.defaultReport.description' => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / ··· ··· —··· ——··—— / ··—· —— / ——— ·—· / ·— ——',
			'settings.logging.defaultReportCW.title' => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / —·—· ·—— / ·— —· —·· / —·· ·— — ·—',
			'settings.logging.defaultReportCW.description' => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / —·—· ·—— ——··—— / ·—· — — —·—— / ·— —· —·· / ——— — ···· · ·—· / —·· ·— — ·— / —— ——— —·· · ···',
			'settings.logging.defaultReportFT8.title' => '—·· · ··—· ·— ··— ·—·· — / ·—· · ·——· ——— ·—· — / — / ··—· — ———·· / ·— —· —·· / ··—· — ····—',
			'settings.logging.defaultReportFT8.description' => '··— ··· · —·· / ·—— ···· · —· / ··· · —· — / ——— ·—· / ·—· —·—· ···— —·· / ·· ··· / ·—·· · ··—· — / · —— ·——· — —·—— / ——— —· / — ···· · / ··—· — / —— ——— —·· · ···',
			'settings.logging.numbersRow.title' => '—· ··— —— —··· · ·—· ··· / ·—· ——— ·——',
			'settings.logging.numbersRow.description' => '··· ···· ——— ·—— / ·— / ·—· ——— ·—— / ——— ··—· / —· ··— —— —··· · ·—· / —·— · —·—— ··· / ·— —··· ——— ···— · / — ···· · / —·— · —·—— —··· ——— ·— ·—· —·· / ·—— ···· ·· ·—·· · / ·—·· ——— ——· ——· ·· —· ——·',
			'settings.logging.numbersRowExtra.title' => '··· ·—·· ·— ··· ···· / ·— —· —·· / ·——· · ·—· ·· ——— —·· / —·— · —·——',
			'settings.logging.numbersRowExtra.description' => '·— —·· —·· ··· / ·— / —·—· ——— —· — · —··— — ··— ·— ·—·· / —·— · —·—— ———··· / “ —··—· ” / ··—· ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· ——··—— / “ ·—·—·— ” / ··—· ——— ·—· / —· ··— —— —··· · ·—· ···',
			'settings.logging.numbersRowVibrate.title' => '···— ·· —··· ·—· ·— — · / ——— —· / —·— · —·—— / ·——· ·—· · ··· ···',
			'settings.logging.numbersRowVibrate.description' => '···· ·— ·——· — ·· —·—· / ··—· · · —·· —··· ·— —·—· —·— / ·—— ···· · —· / —·—— ——— ··— / — ·— ·——· / ·— / —· ··— —— —··· · ·—· / —·— · —·——',
			'settings.logging.bands' => '·——· ·—· · ··—· · ·—· ·—· · —·· / —··· ·— —· —·· ···',
			'settings.logging.modes' => '·——· ·—· · ··—· · ·—· ·—· · —·· / —— ——— —·· · ···',
			'settings.catServer.title' => '—·—· ·— — / ··· · ·—· ···— · ·—·',
			'settings.catServer.description' => '·— ·—·· ·—·· ——— ·—— / ——— — ···· · ·—· / ·— ·——· ·——· ··· / —·——· ·—— ··· ·——— — —····— —··— ——··—— / ·—·· ——— ——· ——· · ·—· ··· ——··—— / · — —·—· —·——·— / — ——— / —·—· ——— —· — ·—· ——— ·—·· / — ···· · / ·—· ·— —·· ·· ——— / — ···· ·—· ——— ··— ——· ···· / ···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· ·—·—·—',
			'settings.catServer.protocol' => '·——· ·—· ——— — ——— —·—· ——— ·—··',
			'settings.catServer.protocolOpts.off' => '—·· ·· ··· ·— —··· ·—·· · —··',
			'settings.catServer.protocolOpts.rigctld' => '···· ·— —— ·—·· ·· —··· / ·—· ·· ——· —·—· — ·—·· —··',
			'settings.catServer.protocolOpts.flrig' => '··—· ·—·· ·—· ·· ——·',
			'settings.catServer.protocolOpts.hrd' => '···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ®',
			'settings.catServer.protocolOpts.n3fjp' => '—· ···—— ··—· ·——— ·——·',
			'settings.catServer.port' => '·——· ——— ·—· —',
			'settings.catServer.openAccess' => '——— ·——· · —· / ·— —·—· —·—· · ··· ···',
			'settings.catServer.openAccessOn' => '·— —· —·—— / —·—· ——— —— ·——· ··— — · ·—· / ——— —· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— / —·—· ·— —· / —·—· ——— —· —· · —·—· — ·—·—·—',
			'settings.catServer.openAccessOff' => '——— —· ·—·· —·—— / ·— ·——· ·——· ··· / ——— —· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· / —·—· ·— —· / —·—· ——— —· —· · —·—· — ·—·—·—',
			'settings.catServer.off' => '——— ··—· ··—· ·—·—·—',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol} ——··—— / ··· — ·— ·—· — ·· —· ——· …',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} / ——— —· / ·——· ——— ·—· — / ${port} ·—·—·— / —·—· ·—·· ·· · —· — ··· / —·—· ——— —· —· · —·—· — · —·· ———··· / ${clients} ·—·—·—',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} / ——— —· / ·——· ——— ·—· — / ${port} ——··—— / —··· ··— — / —· ——— / —— ·— ·· —· / ···— ··—· ——— / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· ·—·—·—',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— / ·· ··· / ··— ··· ·· —· ——· / ·· — ——··—— / ——— ··—· — · —· / ${protocol} / ·· — ··· · ·—·· ··—· ·—·—·— / —·—· ·—·· ——— ··· · / — ···· ·— — / ·——· ·—· ——— ——· ·—· ·— —— / ——— ·—· / —·—· ···· ——— ——— ··· · / ·— —· ——— — ···· · ·—· / ·——· ——— ·—· — ·—·—·—',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} / —·—· ·— —· —· ——— — / ·—·· ·· ··· — · —· / ——— —· / ·——· ——— ·—· — / ${port} ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· / —·· ——— · ··· / —· ——— — / ·— ·—·· ·—·· ——— ·—— / ·· — ·—·—·— / —·—· ···· ——— ——— ··· · / ·— / ·——· ——— ·—· — / ·— —··· ——— ···— · / ·———— ————— ··——— ····— ·—·—·—',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} / ··· — ——— ·——· ·——· · —·· / ·—·· ·· ··· — · —· ·· —· ——· / ——— —· / ·——· ——— ·—· — / ${port} ·—·—·— / — ·—· —·—— ·· —· ——· / ·— ——· ·— ·· —· …',
			'settings.cluster.title' => '—·· —··— / —·—· ·—·· ··— ··· — · ·—·',
			'settings.cluster.description' => '— ···· · / ··· · ·—· ···— · ·—· / · —··— — · —· ··· ·· ——— —· ··· / ·——· ——— ··· — / ··· ·——· ——— — ··· / — ——— / ·— —· —·· / ·—· · ·— —·· / ··· ·——· ——— — ··· / ··—· ·—· ——— —— ——··—— / ·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / — ···· · / ——— ·——· · ·—· ·— — ——— ·—· ·—·—·—',
			'settings.cluster.server' => '—·—· ·—·· ··— ··· — · ·—· / ··· · ·—· ···— · ·—·',
			'settings.cluster.selectServer' => '··· · ·—·· · —·—· — / ··· · ·—· ···— · ·—·',
			'settings.cluster.serverOther' => '——— — ···· · ·—·',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => '—· ——— / ···· ——— ··· — / · —· — · ·—· · —·· / —·—— · — ——··—— / ··· ——— / ··· ·——· ——— — ··· / ——· ——— / — ——— / ${node}',
			'settings.cluster.customHost' => '··· · ·—· ···— · ·—·',
			'settings.cluster.customPort' => '·——· ——— ·—· —',
			'settings.cluster.password' => '·——· ·— ··· ··· ·—— ——— ·—· —··',
			'settings.cluster.passwordDescription' => '——— —· ·—·· —·—— / ·· ··—· / —· · · —·· · —··',
			'settings.cluster.passwordStored' => ({required Object node}) => '·——· ·— ··· ··· ·—— ——— ·—· —·· / ——— —· / ··—· ·· ·—·· · / ··—· ——— ·—· / ${node}',
			'settings.cluster.scrollback' => '·—·· ·· —· · ··· / —·— · ·——· —',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} / ·—·· ·· —· · ···',
			'settings.cluster.connection' => '—·—· ——— —· —· · —·—· — ·· ——— —·',
			'settings.cluster.statusIdle' => '—· ——— — / —·—· ——— —· —· · —·—· — · —·· ·—·—·— / —·—· ——— —· —· · —·—· — ··· / ·—— ···· · —· / ·— —· / · —··— — · —· ··· ·· ——— —· / —· · · —·· ··· / ·· — ·—·—·— / — ·— ·——· / — ——— / — · ··· — ·—·—·—',
			'settings.cluster.statusConnecting' => ({required Object node}) => '—·—· ——— —· —· · —·—· — ·· —· ——· / — ——— / ${node} …',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${node} / ·— ··· / ${call} ·—·—·—',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / —·—· ——— —· —· · —·—· — / — ——— / ${node} ———··· / ${reason}',
			'settings.cluster.statusUnsupported' => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·· —· / — ···· · / ·—— · —··· / ···— · ·—· ··· ·· ——— —· ·—·—·—',
			'settings.cluster.errors.noCall' => '—· ——— / ——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / — ——— / ·—·· ——— ——· / ·· —· / ·—— ·· — ····',
			'settings.cluster.errors.connectFailed' => '— ···· · / —· ——— —·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —··',
			'settings.cluster.errors.needsPassword' => '— ···· · / —· ——— —·· · / ·— ··· —·— ··· / ··—· ——— ·—· / ·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· ——··—— / ·— —· —·· / —· ——— —· · / ·· ··· / ··· — ——— ·—· · —··',
			'settings.cluster.errors.loginFailed' => '— ···· · / —· ——— —·· · / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· · / ·—·· ——— ——· ·· —·',
			'settings.cluster.errors.disconnected' => '— ···· · / —· ——— —·· · / —·—· ·—·· ——— ··· · —·· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —·',
			'settings.cluster.errors.timeout' => '— ···· · / —· ——— —·· · / —·· ·· —·· / —· ——— — / ·— —· ··· ·—— · ·—·',
			'settings.spotting.title' => '··· ·——· ——— — — ·· —· ——·',
			'settings.spotting.respotInterval' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / · ···— · ·—· —·——',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} / —— ·· —·',
			'settings.spotting.autoRespotByDefault' => '·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / —··· —·—— / —·· · ··—· ·— ··— ·—·· —',
			'settings.spotting.autoRespotByDefaultOn' => '· —· ·— —··· ·—·· · / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— — / ·— ··—· — · ·—· / ·— —· —·—— / ··· ·——· ——— — / ·· ··· / ·——· ——— ··· — · —··',
			'settings.spotting.autoRespotByDefaultOff' => '·—· · ——·— ··— ·· ·—· · / ··— ··· · ·—· / ·— —·—· — ·· ——— —· / — ——— / · —· ·— —··· ·—·· · / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— — — ·· —· ——·',
			'settings.spotting.pulseBeforeRespot' => '·——· ··— ·—·· ··· · / —··· · ··—· ——— ·—· · / · ·— —·—· ···· / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— —',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => '— ···· · / ··· ·——· ——— — — ·· —· ——· / —·—· ···· ·· ·——· / ·——· ··— ·—·· ··· · ··· / —··· ·—·· ··— · / ··—· ——— ·—· / — ···· · / ${seconds} / ··· · —·—· ——— —· —·· ··· / —··· · ··—· ——— ·—· · / · ·— —·—· ···· / ·—· · —····— ··· ·——· ——— —',
			'settings.spotting.pulseBeforeRespotOff' => '—· ——— / ·——· ··— ·—·· ··· ·· —· ——· / —··· · ··—· ——— ·—· · / ·— —· / ·— ··— — ——— / ·—· · —····— ··· ·——· ——— —',
			'settings.radio.title' => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—··',
			'settings.radio.loggingAndCat' => '·—·· ——— ——· ——· ·· —· ——· / ·—··· / —·—· ·— —',
			'settings.radio.tuningSection' => '— ··— —· ·· —· ——·',
			'settings.radio.keyerSection' => '—·— · —·—— · ·—·',
			'settings.radio.servicesSection' => '··· · ·—· ···— ·· —·—· · ···',
			'settings.radio.stationConfigurationSection' => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'settings.radio.moreSettings' => '—— ——— ·—· · / ··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ··· · — — ·· —· ——· ···',
			'settings.radio.units.ms' => '—— ···',
			'settings.radio.units.kHz' => '—·— ···· ——··',
			'settings.radio.units.kHzPerSecond' => '—·— ···· ——·· —··—· ···',
			'settings.radio.units.hz' => '···· ——··',
			'settings.radio.pttKey.title' => '—·—· ——— —· — ·—· ——— ·—·· / ·——· — — / ·—— ·· — ···· / [ ·————· ]',
			'settings.radio.pttKey.descriptionOn' => '·· —· / ·——· ···· ——— —· · / —— ——— —·· · ··· ——··—— / [ ·————· ] / —·— · —·—— ··· / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / [ ·————· ] / ·— ——· ·— ·· —· / ··— —· —·— · —·—— ··· / ·· — ·—·—·— / ·· — / ··— —· —·— · —·—— ··· / —··· —·—— / ·· — ··· · ·—·· ··—· / ·— ··—· — · ·—· / ·— / —— ·· —· ··— — · ·—·—·—',
			'settings.radio.pttKey.descriptionOff' => '— ···· · / [ ·————· ] / —·— · —·—— / —·· ——— · ··· / —· ——— — / —·— · —·—— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—',
			'settings.radio.pttKey.pill' => '— —··—',
			'settings.radio.pttKey.transmitting' => '— ·—· ·— —· ··· —— ·· — — ·· —· ——·',
			'settings.radio.smartVfoSnap.title' => '··· —— ·— ·—· — / ···— ··—· ——— / ··· —· ·— ·——·',
			'settings.radio.smartVfoSnap.descriptionOn' => '·— ··—· — · ·—· / —·—— ——— ··— / ··· — ——— ·——· / — ··— ·—· —· ·· —· ——· / — ···· · / —·· ·· ·— ·—·· ——··—— / ·—· ——— ··— —· —·· ·· —· ——· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ·— / ··· · —· ··· ·· —··· ·—·· · / ··· — · ·——· ·—·—·— / ···— ——— ·· —·—· · / —— ——— —·· · ··· / ——— —· ·—·· —·—— ·—·—·—',
			'settings.radio.smartVfoSnap.descriptionOff' => '··· — ·— —·—— ·· —· ——· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / —·—— ——— ··— / — ··— —· · —·· / ·· — ·—·—·—',
			'settings.radio.snapDebounce.title' => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· · — — ·—·· · / —·· · ·—·· ·— —·——',
			'settings.radio.snapDebounce.description' => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / —·· ·· ·— ·—·· / ···· ·— ··· / — ——— / ··· — ——— ·——· / —··· · ··—· ——— ·—· · / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ——— ··— —· —·· · —·· ·—·—·— / ··· ···· ——— ·—· — · ·—· / ··—· · · ·—·· ··· / ·· —— —— · —·· ·· ·— — · —·—·—· / ·—·· ——— —· ——· · ·—· / ·—·· · ·— ···— · ··· / ·—· ——— ——— —— / ··—· ——— ·—· / ·— / ··· ·—·· ——— ·—— / —— ——— ···— · ·—·—·—',
			'settings.radio.snapLongMove.title' => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ·—·· ——— —· ——· / —— ——— ···— ·',
			'settings.radio.snapLongMove.description' => '—— ——— ···— · / ·— — / ·—·· · ·— ··· — / — ···· ·· ··· / ··—· ·— ·—· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·—· ——— ··— —· —·· ··· / — ——— / ·— / ·—— ···· ——— ·—·· · / —·— ···· ——·· ——··—— / ···· ——— ·—— · ···— · ·—· / ··· ·—·· ——— ·—— ·—·· —·—— / —·—— ——— ··— / ··—· ·· —· ·· ··· ···· · —·· ·—·—·—',
			'settings.radio.snapMinMove.title' => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· —— ·— ·—·· ·—·· · ··· — / —— ——— ···— ·',
			'settings.radio.snapMinMove.description' => '—— ——— ···— · / ·—·· · ··· ··· / — ···· ·— —· / — ···· ·· ··· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / —· ——— — / ·—· ——— ··— —· —·· · —·· ——··—— / ··· ——— / ··—· ·· —· · / — ··— —· ·· —· ——· / ·· ··· / ·—·· · ··—· — / ·— ·—·· ——— —· · ·—·—·—',
			'settings.radio.snapMinSpeed.title' => '··· —— ·— ·—· — / ··· —· ·— ·——· ———··· / ··· ·—·· ——— ·—— · ··· — / —— ——— ···— ·',
			'settings.radio.snapMinSpeed.description' => '— ··— ·—· —· / — ···· · / —·· ·· ·— ·—·· / ··· ·—·· ——— ·—— · ·—· / — ···· ·— —· / — ···· ·· ··· / ·— —· —·· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / —· ——— — / ·—· ——— ··— —· —·· · —·· ——··—— / ··— —· ·—·· · ··· ··· / ·· — / ·—— ·— ··· / ·— / ·—·· ——— —· ——· / —— ——— ···— · ·—·—·—',
			'settings.radio.enterSends.pillOff' => '· ··· —— / ——— ··—· ··—·',
			'settings.radio.enterSends.pillRun' => '· ··· —— / ·—· ··— —·',
			'settings.radio.enterSends.pillSp' => '· ··· —— / ··· ·—··· ·——·',
			'settings.radio.enterSends.field' => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ···',
			'settings.radio.enterSends.off' => '——— ··—· ··—·',
			'settings.radio.enterSends.run' => '·—· ··— —·',
			'settings.radio.enterSends.sp' => '··· ·—··· ·——·',
			'settings.radio.enterSends.semantics' => ({required Object state}) => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· ———··· / ${state} ·—·—·— / — ·— ·——· / — ——— / —·—· ···· ·— —· ——· · ·—·—·—',
			'settings.radio.keyerSpeed.title' => '—·— · —·—— · ·—· / ··· ·——· · · —··',
			'settings.radio.keyerSpeed.unit' => '·—— ·——· ——',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} / ·—— ·——· ——',
			'settings.radio.keyerSpeed.pillUnknown' => '– / ·—— ·——· ——',
			'settings.radio.cwMessages.title' => '—·—· ·—— / —·— · —·—— · ·—· / —— · ··· ··· ·— ——· · ···',
			'settings.radio.cwMessages.notSupported' => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / —·—· ·—— / —·— · —·—— ·· —· ——·',
			'settings.radio.cwMessages.key' => ({required Object n}) => '··—· ${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => '—— · ··· ··· ·— ——· · / —·——· ${n} —·——·—',
			'settings.radio.cwMessages.labelField' => '·—·· ·— —··· · ·—··',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => '··—· ${n} / ·—·· ·— —··· · ·—··',
			'settings.radio.cwMessages.details' => '—·· · — ·— ·· ·—·· ···',
			'settings.radio.cwMessages.empty' => '—·——· · —— ·——· — —·—— —·——·—',
			'settings.radio.cwMessages.sets' => '—— · ··· ··· ·— ——· · / ··· · —',
			'settings.radio.cwMessages.newSet' => '—· · ·—— / ··· · —',
			'settings.radio.cwMessages.renameSet' => '·—· · —· ·— —— · / ··· · —',
			'settings.radio.cwMessages.deleteSet' => '—·· · ·—·· · — · / ··· · —',
			'settings.radio.cwMessages.newSetName' => '—· ·— —— ·',
			'settings.radio.cwMessages.setDefault' => '—·· · ··—· ·— ··— ·—·· —',
			'settings.radio.cwMessages.setPota' => '·——· ——— — ·—',
			'settings.radio.cwMessages.setEsm' => '· ··· —— / —— · ··· ··· ·— ——· · ···',
			'settings.radio.cwMessages.setSaved' => '—— —·—— / —— · ··· ··· ·— ——· · ···',
			'settings.radio.cwMessages.repeat' => '·—· · ·——· · ·— — / —— · ··· ··· ·— ——· · / # ·————',
			'settings.radio.cwMessages.repeatOff' => '—· ———',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => '·— ··—· — · ·—· / ${n} / ··· · —·—· ——— —· —·· ···',
			'settings.radio.cwMessages.repeatWait' => '·—· · ·——· · ·— — ·· —· ——·',
			'settings.radio.cwMessages.keyboard' => '— —·—— ·——· · / — ——— / ··· · —· —··',
			'settings.radio.cwMessages.keyboardField' => '— —·—— ·——· · / — ——— / ··· · —· —··',
			'settings.radio.cwMessages.closeArea' => '—·—· ·—·· ——— ··· · / — ···· · / —·— · —·—— · ·—· / ·— ·—· · ·—',
			'settings.radio.cwMessages.help' => '···· · ·—·· ·——·',
			'settings.radio.cwMessages.helpTitle' => '·—— ·—· ·· — ·· —· ——· / —·—· ·—— / —— · ··· ··· ·— ——· · ···',
			'settings.radio.cwMessages.helpIntro' => '—— · ··· ··· ·— ——· · ··· / —·—· ·— —· / ··— ··· · / — · —— ·——· ·—·· ·— — · ··· / ·—— ·· — ···· / — ···· · / ··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / ···— ·— ·—·· ··— · ··· ———···',
			'settings.radio.cwMessages.helpOpCall' => '—·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'settings.radio.cwMessages.helpQsoCall' => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / — / ·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —·—· ·— ·—·· ·—·· / — ···· ·— — / ·—— ·· ·—·· ·—·· / —··· · / ·—·· ——— ——· ——· · —··',
			'settings.radio.cwMessages.helpQsoFullCall' => '— ···· · ·· ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ——··—— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—·· —·—·—· / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / ·— / ·——· ·— ·—· — ·· ·— ·—··',
			'settings.radio.cwMessages.helpQsoPartial' => '·— / ·——· ·— ·—· — ·· ·— ·—·· / —·—· ·— ·—·· ·—·· —·—·—· / —··· ·—·· ·— —· —·— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ··—· ··— ·—·· ·—·· / ···— ·— ·—·· ·· —·· / —·—· ·— ·—·· ·—··',
			'settings.radio.cwMessages.helpQsoNextCall' => '·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —·—· ·— ·—·· ·—·· / — ···· ·— — / ·—— ·· ·—·· ·—·· / —··· · / ··· · ·—·· · —·—· — · —·· / ··—· ——— ·—· / ·—·· ——— ——· ——· ·· —· ——· / —· · —··— — ——··—— / ·· ··—· / — ···· · ·—· · / ·· ··· / ·— / ···— ·— ·—·· ·· —·· / ··—· ··— ·—·· ·—·· / —·—· ·— ·—·· ·—··',
			'settings.radio.cwMessages.helpQsoNextPartial' => '·· —· / ·— / —··—· —··—· / ··· — ·— —·—· —·— ——··—— / — ···· · / —· · —··— — / ·——· ·— ·—· — ·· ·— ·—·· / ·— ··—· — · ·—· / ·—·· ——— ——· ——· ·· —· ——· / — ···· · / —·—· ··— ·—· ·—· · —· — / —·—· ——— —· — ·— —·—· —',
			'settings.radio.cwMessages.helpQsoName' => '— ···· · ·· ·—· / ··—· ·· ·—· ··· — / —· ·— —— · ——··—— / ·— ··· / — —·—— ·——· · —·· / ——— ·—· / · ·—·· ··· · / ··—· ·—· ——— —— / — ···· · / ·—·· ——— ——— —·— ··— ·——·',
			'settings.radio.cwMessages.helpQsoState' => '— ···· · ·· ·—· / ··· — ·— — · ——··—— / ·— ··· / — —·—— ·——· · —·· / ——— ·—· / · ·—·· ··· · / ··—· ·—· ——— —— / — ···· · / ·—·· ——— ——— —·— ··— ·——·',
			'settings.radio.cwMessages.helpKeyerMsg' => '—— · ··· ··· ·— ——· · / ·———— / ·— ··· / ·· — / ·—— ——— ··— ·—·· —·· / —··· · / ··· · —· — ——··—— / ·· —· ··· ·· —·· · / ·— —· ——— — ···· · ·—· / —— · ··· ··· ·— ——· · ·—·—·— / ···— ·— ·—·· ·· —·· / ··—· ——— ·—· / —— · ··· ··· ·— ——· · ··· / ·———— / — ···· ·—· ——— ··— ——· ···· / ———··',
			'settings.radio.cwMessages.helpQsoRst' => '— ···· · / ·—· · ·——· ——— ·—· — / —·—— ——— ··— / ·— ·—· · / ··· · —· —·· ·· —· ——·',
			'settings.radio.cwMessages.helpQsoSerial' => '—·—— ——— ··— ·—· / ··· · ·—· ·· ·— ·—·· / —· ··— —— —··· · ·—· ——··—— / ·· —· / ·— / —·—· ——— —· — · ··· — / — ···· ·— — / ··· · —· —·· ··· / ——— —· ·',
			'settings.radio.cwMessages.helpPad' => '·——· ·— —·· ··· / ·—— ·· — ···· / ——·· · ·—· ——— ··· / — ——— / — ···· ·— — / —— ·— —· —·—— / —·· ·· ——· ·· — ··· ———··· / ——··· / ·· ··· / ··· · —· — / ·— ··· / ————— ————— ——···',
			'settings.radio.cwMessages.helpCut' => '—·—· ··— — / —· ··— —— —··· · ·—· ··· ——··—— / — / ··—· ——— ·—· / ————— / ·— —· —·· / —· / ··—· ——— ·—· / ————· ———··· / ····· ————· ————· / ·· ··· / ··· · —· — / ·— ··· / ····· —· —·',
			'settings.radio.cwMessages.helpCutDigits' => '—·—· ···· ——— ——— ··· · ··· / — ···· · / —·· ·· ——· ·· — ··· / — ——— / —·—· ··— — ——··—— / ·· —· / ——·— ··— ——— — · ··· / — / ————— / ·· ··· / — ——··—— / ·———— / ·· ··· / ·— ——··—— / ····· / ·· ··· / · ——··—— / ————· / ·· ··· / —·',
			'settings.radio.cwMessages.helpFullExample' => '··—· ··— ·—·· ·—·· / · —··— ·— —— ·——· ·—·· · ———···',
			'settings.radio.cwMessages.helpExample' => '··· · —· —·· ··· / ·—— ·———— ·— ·—— / ····· —· —· / — — ——···',
			'settings.radio.cwMessages.helpEsmIntro' => '·—— ·· — ···· / · —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· / ——— —· ——··—— / · —· — · ·—· / —·— · —·—— ··· / —— · ··· ··· ·— ——· · ··· / —··· —·—— / — ···· · ·· ·—· / ··—· ··— —· —·—· — ·· ——— —· / —·— · —·—— ——··—— / ·— ··· / —· ·———— —— —— / —·· ——— · ··· ·—·—·— / — ···· · / · ··· —— / —— · ··· ··· ·— ——· · ··· / ··· · — / ··· — ·— ·—· — ··· / ·—— ·· — ···· / — ···· · ··· · ———···',
			'settings.radio.cwMessages.helpEsmCq' => '·—· ··— —· —· ·· —· ——· ——··—— / · —· — · ·—· / ·—— ·· — ···· / — ···· · / —·—· ·— ·—·· ·—·· / ··—· ·· · ·—·· —·· / · —— ·——· — —·—— / —·—· ·— ·—·· ·—·· ··· / —·—· ——·—',
			'settings.radio.cwMessages.helpEsmExchange' => '—·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· · ———··· / ·— ··—· — · ·—· / — ···· · ·· ·—· / —·—· ·— ·—·· ·—·· / ·—— ···· · —· / ·—· ··— —· —· ·· —· ——· ——··—— / ·— ··—· — · ·—· / — ···· · —·—— / ·— —· ··· ·—— · ·—· / ·· —· / ··· ·—··· ·——·',
			'settings.radio.cwMessages.helpEsmThanks' => '— ···· ·— —· —·— ··· ——··—— / ——— —· —·—· · / — ···· · / —·—· ——— —· — ·— —·—· — / ···· ·— ··· / ·—·· ——— ——· ——· · —·· ———··· / ·· — ··· / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· ··· / —· ·— —— · / — ···· · / —· · —··— — / —·—· ——— —· — ·— —·—· — ——··—— / —· ——— — / — ···· ·· ··· / ——— —· ·',
			'settings.radio.cwMessages.helpEsmMyCall' => '·· —· / ··· ·—··· ·——· ——··—— / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· / — ——— / — ···· · / ··· — ·— — ·· ——— —· / —·—— ——— ··— / ·— ·—· · / ·— —· ··· ·—— · ·—· ·· —· ——·',
			'settings.radio.cwMessages.helpEsmHisCall' => '·—· ··— —· —· ·· —· ——· ——··—— / — ···· · ·· ·—· / —·—· ·— ·—·· ·—·· / ·— ···· · ·— —·· / ——— ··—· / —·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· ·',
			'settings.radio.cwMessages.helpEsmAgain' => '·— ··· —·— ··· / ·— ——· ·— ·· —· / ·—— ···· · —· / —· ——— — ···· ·· —· ——· / ——— ··—· / — ···· · ·· ·—· / · —··— —·—· ···· ·— —· ——· · / ·—— ·— ··· / —·—· ——— ·——· ·· · —··',
			'settings.radio.cwMessages.helpEsmStackThanks' => '··· ··— ——· ——· · ··· — · —·· / ··—· ···—— / ··—· ——— ·—· / —··—· —··—· / ··· — ·— —·—· —·— ··· ———··· / — ··— / ——· ——— · ··· / ——— ··— — / ·— ··—· — · ·—· / — ···· · / —·—· ——— —· — ·— —·—· — / ·—·· ——— ——· ··· ——··—— / ··· ——— / ·· — / — ···· ·— —· —·— ··· ——··—— / — ···· · —· / —·—· ·— ·—·· ·—·· ··· / — ···· · / —· · —··— — / ··· — ·— —·—· —·— · —·· / ··· — ·— — ·· ——— —· / ·— —· —·· / ··· · —· —·· ··· / —·—— ——— ··— ·—· / · —··— —·—· ···· ·— —· ——· · ——··—— / ——— ·—· / ·— ··· —·— ··· / ·— / ·——· ·— ·—· — ·· ·— ·—·· / —··· ·— —·—· —·— / —·——· — ··— / —·— ·—· ··——·· —·——·— —·—·—· / ·—— ·· — ···· / —· ——— — ···· ·· —· ——· / ·—·· · ··—· — ——··—— / ·——— ··— ··· — / — ··—',
			'settings.radio.voiceMessages.title' => '·——· ···· ——— —· · / —·— · —·—— · ·—· / —— · ··· ··· ·— ——· · ···',
			'settings.radio.voiceMessages.notSupported' => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / ·——· ···· ——— —· · / —— · ··· ··· ·— ——· · ···',
			'settings.radio.voiceMessages.description' => '— ···· ·· ··· / ··— ··· · ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···',
			'settings.radio.voiceMessages.key' => ({required Object n}) => '—— ${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => '···— ——— ·· —·—· · / —— · —— ——— ·—· —·—— / —·——· ${n} —·——·—',
			'settings.radio.voiceMessages.labelField' => '·—·· ·— —··· · ·—··',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => '···— ——— ·· —·—· · / —— · —— ——— ·—· —·—— / ${n} / ·—·· ·— —··· · ·—··',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} / ···',
			'settings.radio.voiceMessages.emptyOnRadio' => '· —— ·——· — —·——',
			'settings.radio.voiceMessages.notMeasured' => '··— —· —·— —· ——— ·—— —· / ·—·· · —· ——· — ····',
			'settings.radio.voiceMessages.playButton' => '·——· ·—·· ·— —·——',
			'settings.radio.voiceMessages.recordButton' => '·—· · —·—· ——— ·—· —··',
			'settings.radio.voiceMessages.stopButton' => '··· — ——— ·——·',
			'settings.radio.voiceMessages.repeat' => '·—· · ·——· · ·— — / —— · ··· ··· ·— ——· · / # ·————',
			'settings.radio.voiceMessages.repeatOff' => '—· ———',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => '·— ··—· — · ·—· / ${n} / ··· · —·—· ——— —· —·· ···',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} / —· ——— — · ··· ———···',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => '— ···· · ··· · / —— · —— ——— ·—· ·· · ··· / ·— ·—· · / ·· —· / ${device} ·————· ··· / ·—· ·— —·· ·· ——— ·—·—·— / — ···· · ·· ·—· / —· ·— —— · ··· / ·— —· —·· / ·—·· · —· ——· — ···· ··· / —··· · ·—·· ——— —· ——· / — ——— / — ···· ·— — / —·· · ···— ·· —·—· · ·—·—·—',
			'settings.radio.voiceMessages.namedOnRadio' => '··· ·— ···— · —·· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ·—— ···· · ·—· · / ·· — ··· / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ··· / ··· · · / ·· — / — ——— ——— ·—·—·—',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => '·—— ·— ·· — / ··—· ——— ·—· / — ···· · / [ ·—· · —·—· ] / ·· —· —·· ·· —·—· ·— — ——— ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / — ···· · —· / ···· ——— ·—·· —·· / — ···· · / ·——· — — / —··· ··— — — ——— —· / ·— —· —·· / ·—· · —·—· ——— ·—· —·· / —·—— ——— ··— ·—· / —— · ··· ··· ·— ——· · ·—·—·— / · —· —·· / ·· — / —··· —·—— / ·——· ·—· · ··· ··· ·· —· ——· / — ···· · / ··· — ——— ·——· / —··· ··— — — ——— —· / ···· · ·—· · / ·· —· / — ···· · / ·— ·——· ·——· / —··· · ··—· ——— ·—· · / ·—· · ·—·· · ·— ··· ·· —· ——· / ·——· — — / — ——— / ·— ···— ——— ·· —·· / ··— —· ·—— ·— —· — · —·· / —·—· ·—·· ·· —·—· —·— ··· ·—·—·—',
			'settings.radio.voiceMessages.recordHelpFt891' => '·—— ·— ·· — / ··—· ——— ·—· / — ···· · / [ ·—· · —·—· ] / ·· —· —·· ·· —·—· ·— — ——— ·—· / — ——— / —··· ·—·· ·· —· —·— / ·— — / ·—·· · ·— ··· — / ··—· ——— ··— ·—· / — ·· —— · ··· ——··—— / — ···· · —· / ···· ——— ·—·· —·· / — ···· · / ·——· — — / —··· ··— — — ——— —· / ·— —· —·· / ·—· · —·—· ——— ·—· —·· / —·—— ——— ··— ·—· / —— · ··· ··· ·— ——· · ·—·—·— / · —· —·· / ·· — / —··· —·—— / ·——· ·—· · ··· ··· ·· —· ——· / — ···· · / ··· — ——— ·——· / —··· ··— — — ——— —· / ···· · ·—· · / ·· —· / — ···· · / ·— ·——· ·——· / —··· · ··—· ——— ·—· · / ·—· · ·—·· · ·— ··· ·· —· ——· / ·——· — — / — ——— / ·— ···— ——— ·· —·· / ··— —· ·—— ·— —· — · —·· / —·—· ·—·· ·· —·—· —·— ··· ·—·—·—',
			'settings.radio.voiceMessages.pill' => '···— ——— ·· —·—· ·',
			'settings.radio.voiceMessages.play' => ({required Object n}) => '·——· ·—·· ·— —·—— / —— · —— ——— ·—· —·—— / ${n}',
			'settings.radio.voiceMessages.stop' => '··· — ——— ·——·',
			'settings.radio.voiceMessages.record' => ({required Object n}) => '·—· · —·—· ——— ·—· —·· / —— · —— ——— ·—· —·—— / ${n}',
			'settings.radio.voiceMessages.stopRecording' => '··· — ——— ·——· / ·—· · —·—· ——— ·—· —·· ·· —· ——·',
			'settings.radio.voiceMessages.playing' => '·——· ·—·· ·— —·—— ·· —· ——· …',
			'settings.radio.voiceMessages.recording' => '·—· · —·—· ——— ·—· —·· ·· —· ——· …',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '·——· ·—·· ·— —·—— ·· —· ——· / ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '·—· · —·—· ——— ·—· —·· ·· —· ——· / ${label}',
			'settings.radio.voiceMessages.doubtful' => '—·· ·· —·· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— / ·· — ··——·· / ·· — / ··· ·— ·· —·· / ·· — / ·—— ·— ··· / ·· —·· ·—·· · / ·—· ·· ——· ···· — / ·— ·—— ·— —·—— ·—·—·—',
			'settings.radio.voiceMessages.recordOnRadio' => '—·—— ——— ··— / ···· ·— ···— · / — ——— / ·—· · —·—· ——— ·—· —·· / — ···· · / —— · —— ——— ·—· ·· · ··· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— / ·· — ··· · ·—·· ··—· ·—·—·—',
			'settings.radio.avoidZeroBeat.title' => '·— ···— ——— ·· —·· / ——·· · ·—· ——— —····— —··· · ·— — ·· —· ——· / ——— —· / ··· ·——· ——— — ···',
			'settings.radio.avoidZeroBeat.descriptionOn' => '·—— ·· — ···· / ·— / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — · —·· ——··—— / — ··— —· ·· —· ——· / ·— / ··—· · ·—— / ···· ——·· / ——— ··—· ··—· / ·— / —·—· ·—— / ··· ·——· ——— — ——··—— / ··· ——— / · ···— · ·—· —·—— ——— —· · / ·— —· ··· ·—— · ·—· ·· —· ——· / ·· — / ·· ··· —· ’ — / —·—· ·— ·—·· ·—·· ·· —· ——· / ——— —· / — ···· · / ··· ·— —— · / —· ——— — · ·—·—·—',
			'settings.radio.avoidZeroBeat.descriptionOff' => '— ··— —· ·· —· ——· / · —··— ·— —·—· — ·—·· —·—— / — ——— / — ···· · / ··· ·——· ——— — — · —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— ·—·—·—',
			'settings.radio.zeroBeatRange.title' => '——·· · ·—· ——— —····— —··· · ·— — ———··· / ·— ···— ——— ·· —·· ·— —· —·—· · / ·—· ·— —· ——· ·',
			'settings.radio.zeroBeatRange.description' => '···· ——— ·—— / ··—· ·— ·—· / ——— ··—· ··—· / — ···· · / ··· ·——· ——— — — · —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ——— / ·—·· ·— —· —·· ——··—— / · ·· — ···· · ·—· / ··· ·· —·· · ·—·—·— / — ···· · / ——— ··—· ··—· ··· · — / ·· ··· / —· · ···— · ·—· / —· · ·— ·—· / ——·· · ·—· ——— / — / — ···· ·— — / ·—— ——— ··— ·—·· —·· / —··· · / ·— / ——·· · ·—· ——— / —··· · ·— — / ·— ——· ·— ·· —· ·—·—·—',
			'settings.help.title' => '···· · ·—·· ·——· / ·—··· / ·—· · ··· ——— ··— ·—· —·—· · ···',
			'settings.help.description' => '—·—· ——— —— —— ··— —· ·· — —·—— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· —',
			'settings.help.forums' => '···· ·— —— ··——— —·— / ··—· ——— ·—· ··— —— ···',
			'settings.help.forumsDescription' => '··—· ·· —· —·· / ···· · ·—·· ·——· ——··—— / ——· ·· ···— · / ··—· · · —·· —··· ·— —·—· —·— ——··—— / —·· ·· ··· —·—· ··— ··· ··· / ·· —·· · ·— ··· …',
			'settings.help.chat' => '···· ·— —— ··——— —·— / —·—· ···· ·— —',
			'settings.help.chatDescription' => '— ···· · / —·· ·· ··· —·—· ——— ·—· —·· / ··· · ·—· ···— · ·—· / ··—· ——— ·—· / ——— ··— ·—· / ——— —· ·—·· ·· —· · / —·—· ——— —— —— ··— —· ·· — —·——',
			'settings.help.youtube' => '···· ·— —— ··——— —·— / —·—— ——— ··— — ··— —··· ·',
			'settings.help.youtubeDescription' => '···— ·· —·· · ——— ··· / ·— —· —·· / ·—·· ·· ···— · / ··· — ·—· · ·— —— ···',
			'settings.help.instagram' => '···· ·— —— ··——— —·— / ·· —· ··· — ·— ——· ·—· ·— ——',
			'settings.help.instagramDescription' => '—··· · —·—· ·— ··— ··· · / —·—— ——— ··— / —·—· ·— —· —· ——— — / ···· ·— ···— · / — ——— ——— / —— ·— —· —·—— / ·——· ···· ——— — ——— ··· …',
			'settings.help.bluesky' => '···· ·— —— ··——— —·— / —··· ·—·· ··— · ··· —·— —·——',
			'settings.help.blueskyDescription' => '··—· ——— ·—·· ·—·· ——— ·—— / ··— ··· / ··—· ——— ·—· / —· · ·—— ··· / ·— —· —·· / ··— ·——· —·· ·— — · ···',
			'settings.help.contact' => '—·—· ——— —· — ·— —·—· — / ··— ···',
			'settings.help.contactDescription' => '···· · ·—·· ·——· ·——·—· ···· ·— —— ··——— —·— ·—·—·— —·—· ——— —— / — / —··· ··— — / — ·—· —·—— / — ···· · / ··—· ——— ·—· ··— —— ··· / ——— ·—· / —·—· ···· ·— — / ··—· ·· ·—· ··· — —·—·——',
			'settings.exports.title' => '· —··— ·——· ——— ·—· — ···',
			'settings.extensionSections.activities' => '·— —·—· — ·· ···— ·· — ·· · ···',
			'settings.extensionSections.hunting' => '···· ··— —· — ·· —· ——·',
			'settings.extensionSections.contests' => '—·—· ——— —· — · ··· — ···',
			'settings.extensionSections.lookups' => '·—·· ——— ——— —·— ··— ·——· ···',
			'settings.extensionSections.dashboard' => '—·· ·— ··· ···· —··· ——— ·— ·—· —··',
			'settings.map.title' => '—— ·— ·——· ···',
			'settings.map.style.title' => '—— ·— ·——· / ··· — —·—— ·—·· ·',
			'settings.map.showCallsigns.title' => '··· ···· ——— ·—— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···',
			'settings.map.showCallsigns.description' => '· ·— —·—· ···· / —·—· ——— —· — ·— —·—· — / ·· ··· / ·— / ·——· ·· ·—·· ·—·· / ·—— ·· — ···· / ·· — ··· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ——··—— / ·· —· / ·· — ··· / —··· ·— —· —·· ·————· ··· / —·—· ——— ·—·· ——— ·—·',
			'settings.map.showGrayline.title' => '··· ···· ——— ·—— / ——· ·—· ·— —·—— ·—·· ·· —· ·',
			'settings.map.showGrayline.description' => '··· ···· ·— —·· · ··· / — ···· · / —· ·· ——· ···· — / ··· ·· —·· · / ——— ··—· / — ···· · / · ·— ·—· — ···· ——··—— / ·—— ·· — ···· / — ·—— ·· ·—·· ·· ——· ···· — / ·— ··· / ·— / ——· ·—· ·— —·· ·· · —· —',
			'settings.map.styleOpts.automatic' => '·— ··— — ——— —— ·— — ·· —·—·',
			'settings.map.styleOpts.liberty' => '·—·· ·· —··· · ·—· — —·——',
			'settings.map.styleOpts.bright' => '—··· ·—· ·· ——· ···· —',
			'settings.map.styleOpts.positron' => '·——· ——— ··· ·· — ·—· ——— —·',
			'settings.map.styleOpts.voyager' => '···— ——— —·—— ·— ——· · ·—·',
			'settings.map.styleOpts.darkMatter' => '—·· ·— ·—· —·— / —— ·— — — · ·—·',
			'settings.privacy.title' => '·——· ·—· ·· ···— ·— —·—· —·——',
			'settings.privacy.shareAppData.title' => '··· ···· ·— ·—· · / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·—',
			'settings.privacy.shareAppData.descriptionOn' => '···· · ·—·· ·——· ·· —· ——· / ··— ··· / ·· —— ·——· ·—· ——— ···— · / — ···· · / ·— ·——· ·——· / —··· —·—— / ··· ···· ·— ·—· ·· —· ——· / ··— ··· ·— ——· · ——··—— / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· ——··—— / —·—· ·—· ·— ··· ···· / ·— —· —·· / ·——· · ·—· ··—· ——— ·—· —— ·— —· —·—· · / —·· ·— — ·—',
			'settings.privacy.shareAppData.descriptionOff' => '—·— · · ·——· ·· —· ——· / ·— ·——· ·——· / ··— ··· ·— ——· · / —·· ·— — ·— / ·——· ·—· ·· ···— ·— — · ·—·—·—\n— ···· · / ···· ·— —— ··——— —·— / — · ·— —— / ·—— ——— —· ·————· — / —··· · / ·— —··· ·—·· · / — ——— / —·· · — · —·—· — / —·—· ·—· ·— ··· ···· · ··· / ——— ·—· / ——— — ···· · ·—· / ·· ··· ··· ··— · ··· ·—·—·—',
			'settings.privacy.shareOpData.title' => '··· ···· ·— ·—· · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·—',
			'settings.privacy.shareOpData.descriptionOn' => '··· ···· ·— ·—· ·· —· ——· / ··· ——— —— · / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·——· ··— —··· ·—·· ·· —·—· ·—·· —·—— / ·— —· —·· / ·—— ·· — ···· / ——— — ···· · ·—· / ··— ··· · ·—· ···',
			'settings.privacy.shareOpData.descriptionOff' => '—·— · · ·——· ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· / —·· ·— — ·— / ·——· ·—· ·· ···— ·— — ·',
			'settings.privacy.privacyPolicy' => '·——· ·—· ·· ···— ·— —·—· —·—— / ·——· ——— ·—·· ·· —·—· —·——',
			'settings.privacy.termsOfService' => '— · ·—· —— ··· / ——— ··—· / ··· · ·—· ···— ·· —·—· ·',
			'settings.operatorCall' => '——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —·',
			'settings.sync.title' => '—·—· ·—·· ——— ··— —·· / ··· —·—— —· —·—·',
			'settings.sync.moreSettings' => '—— ——— ·—· · / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ···',
			'settings.sync.enable' => '· —· ·— —··· ·—·· · / ··· —·—— —· —·—·',
			'settings.sync.deviceKey' => '—·· · ···— ·· —·—· · / —·— · —·——',
			'settings.peers.title' => '·——· · · ·—· / —·· · ···— ·· —·—· · ···',
			'settings.peers.enable' => '—·—· ——— —· —· · —·—· — / — ——— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···',
			'settings.peers.enableDescription' => '·— ·—·· ·—·· ——— ·—— / ··· ···· ·— ·—· ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / ·—·· ——— ——· ——· ·· —· ——· ——··—— / —·—· ·— — / ·— —· —·· / ——· ·——· ··· / ·—— ·· — ···· / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / ——— ···— · ·—· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·—',
			'settings.peers.bleEnable' => '—·—· ——— —· —· · —·—· — / ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ····',
			'settings.peers.bleDescription' => '··— ··· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / — ——— / —·—· ——— —· —· · —·—· — / · ···— · —· / ·· ··—· / — ···· · ·—· · / ·· ··· / —· ——— / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·—',
			'settings.peers.thisDevice' => '— ···· ·· ··· / —·· · ···— ·· —·—· ·',
			'settings.peers.deviceName' => '—· ·— —— ·',
			'settings.peers.deviceNameHint' => '···· ——— ·—— / — ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / ··· · · —· / —··· —·—— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···',
			'settings.peers.pairedDevices' => '·—·· ·· —· —·— · —·· / —·· · ···— ·· —·—· · ···',
			'settings.peers.noPairedDevices' => '—· ——— / —·· · ···— ·· —·—· · ··· / ·—·· ·· —· —·— · —·· / —·—— · — ·—·—·— / — ··— ·—· —· / — ···· ·· ··· / ——— —· ——··—— / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —· · — ·—— ——— ·—· —·— ——··—— / — ——— / ·—·· ·· —· —·— / — ···· · —— ·—·—·—',
			'settings.peers.deviceListProblem' => ({required Object error}) => '—·—· ·— —· ·————· — / ·—· · ·— —·· / —·—— ——— ··— ·—· / ·—·· ·· —· —·— · —·· / —·· · ···— ·· —·—· · ··· ———··· / ${error}',
			'settings.peers.nearby' => '—· · ·— ·—· —··· —·——',
			'settings.peers.connected' => '—·—· ——— —· —· · —·—· — · —··',
			'settings.peers.viaBluetooth' => '···— ·· ·— / —··· ·—·· ··— · — ——— ——— — ····',
			'settings.peers.connecting' => '—·—· ——— —· —· · —·—· — ·· —· ——· …',
			'settings.peers.syncing' => '··· —·—— —· —·—· ·· —· ——· …',
			'settings.peers.waitingForThem' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· ·',
			'settings.peers.notConnected' => '—· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'settings.peers.wantsToPair' => '·—— ·— —· — ··· / — ——— / ··· ···· ·— ·—· · / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'settings.peers.allow' => '·— ·—·· ·—·· ——— ·——',
			'settings.peers.link' => '·—·· ·· —· —·—',
			'settings.peers.reject' => '·—· · ·——— · —·—· —',
			'settings.peers.forget' => '··—· ——— ·—· ——· · —',
			'settings.peers.forgetTitle' => ({required Object name}) => '··—· ——— ·—· ——· · — / ${name} ··——··',
			'settings.peers.forgetBody' => '·· — / ·—— ·· ·—·· ·—·· / ··· — ——— ·——· / ··· —·—— —· —·—· ·· —· ——· / ·—— ·· — ···· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / —·—— ——— ··— / —·—· ·— —· / ·— ·—·· ·—·· ——— ·—— / ·· — / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ——··—— / ·— —· —·· / —·—· ——— —· — ·— —·—· — ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ——— ——· ——· · —·· / ·— ·—· · / —·— · ·——· — ·—·—·—',
			'settings.peers.pairTitle' => ({required Object name}) => '·—·· ·· —· —·— / ·—— ·· — ···· / ${name}',
			'settings.peers.pairBody' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / ——— —· / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— / ·— —· —·· / ·—— ·— —· — ··· / — ——— / —·—· ——— —· —· · —·—· — ·—·—·—',
			'settings.peers.pairBodyBle' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ·· ··· / —· · ·— ·—· —··· —·—— / ·— —· —·· / ·—— ·— —· — ··· / — ——— / —·—· ——— —· —· · —·—· — / ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ·—·—·—',
			'settings.peers.pairIdLabel' => '—·· · ···— ·· —·—· · / ·· —··',
			'settings.peers.pairWarning' => '——— —· ·—·· —·—— / ·—·· ·· —· —·— / ·—— ·· — ···· / —·· · ···— ·· —·—· · ··· / —·—— ——— ··— / ·—· · —·—· ——— ——· —· ·· ··· · ·—·—·— / ·— —· —·—— / —·· · ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —· · — ·—— ——— ·—· —·— / —·—· ·— —· / ··· · —· —·· / ·— / ·—· · ——·— ··— · ··· — ·—·—·—',
			'settings.peers.pairWarningBle' => '——— —· ·—·· —·—— / ·—·· ·· —· —·— / ·—— ·· — ···· / —·· · ···— ·· —·—· · ··· / —·—— ——— ··— / ·—· · —·—· ——— ——· —· ·· ··· · ·—·—·— / ·— —· —·—— / —· · ·— ·—· —··· —·—— / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· · —· —·· / ·— / ·—· · ——·— ··— · ··· — ·—·—·—',
			'settings.peers.problem' => ({required Object error}) => '—·—· ·— —· ·————· — / ·—· · ·— —·—· ···· / — ···· · / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ———··· / ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => '—··· ·—·· ··— · — ——— ——— — ···· ———··· / ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${device}',
			'settings.peers.statusLost' => ({required Object device}) => '·—·· ——— ··· — / —·—· ——— —· —· · —·—· — ·· ——— —· / — ——— / ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => '·——· · · ·—· / —·· · ···— ·· —·—· · ··· ———··· / ${connected} / ——— ··—· / ${linked} / —·—· ——— —· —· · —·—· — · —··',
			'settings.peers.screenEnable' => '··· ···· ·— ·—· · / ··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ···',
			'settings.peers.screenDescription' => '·— ·—·· ·—·· ——— ·—— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / — ——— / ··· ···· ——— ·—— / ··· —·—· ·—· · · —· ··· / ——— ·—· / ·—— ·· —· —·· ——— ·—— ··· / ··—· ·—· ——— —— / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—·',
			'settings.peers.screenSources' => '··· —·—· ·—· · · —· ··· / ·— —· —·· / ·—— ·· —· —·· ——— ·—— ···',
			'settings.peers.screenRefresh' => '·—· · ··—· ·—· · ··· ···· / — ···· · / ·—·· ·· ··· —',
			'settings.peers.screenUnsupportedPlatform' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / —·—· ·— —· ·————· — / ··· ···· ·— ·—· · / ·· — ··· / ··· —·—· ·—· · · —· ·—·—·— / —— ·— —·—· ——— ··· / —·—· ·— —· —·—·—· / · ···— · ·—· —·—— / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· ···· ——— ·—— / ——— —· · / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· ·—·—·—',
			'settings.peers.screenUnsupportedVersion' => '··· ···· ·— ·—· ·· —· ——· / ·— / ··· —·—· ·—· · · —· / —· · · —·· ··· / —— ·— —·—· ——— ··· / ·———— ··——— ·—·—·— ···—— / ——— ·—· / ·—·· ·— — · ·—· ·—·—·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / —·—· ·— —· / ··· — ·· ·—·· ·—·· / ··· ···· ——— ·—— / ·— / ··· —·—· ·—· · · —· / ··· ···· ·— ·—· · —·· / —··· —·—— / ·— —· ——— — ···· · ·—· ·—·—·—',
			'settings.peers.screenNeedsPermission' => '—— ·— —·—· ——— ··· / —· · · —·· ··· / —·—— ——— ··— ·—· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / — ——— / ·—· · —·—· ——— ·—· —·· / — ···· · / ··· —·—· ·—· · · —· / —··· · ··—· ——— ·—· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ··· ···· ·— ·—· · / ——— —· · ·—·—·—',
			'settings.peers.screenGrantPermission' => '·— ··· —·— / ··—· ——— ·—· / ·——· · ·—· —— ·· ··· ··· ·· ——— —·',
			'settings.peers.screenRelaunchAfterGranting' => '·— ·—·· ·—·· ——— ·—— / ·· — / ·· —· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / ··— —· —·· · ·—· / ·——· ·—· ·· ···— ·— —·—· —·—— / ·—··· / ··· · —·—· ··— ·—· ·· — —·—— / → / ··· —·—· ·—· · · —· / ·—· · —·—· ——— ·—· —·· ·· —· ——· ——··—— / — ···· · —· / ——·— ··— ·· — / ·— —· —·· / ·—· · ——— ·——· · —· / — ···· ·· ··· / ·— ·——· ·——· / — / —— ·— —·—· ——— ··· / ——— —· ·—·· —·—— / — · ·—·· ·—·· ··· / ·— —· / ·— ·——· ·——· / ·— —··· ——— ··— — / — ···· · / —·—· ···· ·— —· ——· · / ——— —· / ·· — ··· / —· · —··— — / ·—·· ·— ··— —· —·—· ···· ·—·—·—',
			'settings.peers.screenProblem' => ({required Object error}) => '··· —·—· ·—· · · —· / ··· ···· ·— ·—· ·· —· ——· ———··· / ${error}',
			'settings.peers.screenChooseTitle' => '—·—· ···· ——— ——— ··· · / ·—— ···· ·— — / — ——— / ··· ···· ·— ·—· ·',
			'settings.peers.screenChooseButton' => '—·—· ···· ——— ——— ··· · / ·—— ···· ·— — / — ——— / ··· ···· ·— ·—· · …',
			'settings.peers.screenTabScreens' => '··· —·—· ·—· · · —· ···',
			'settings.peers.screenTabApps' => '·— ·——· ·——· ···',
			'settings.peers.screenTabWindows' => '·—— ·· —· —·· ——— ·—— ···',
			'settings.peers.screenTabEmpty' => '—· ——— — ···· ·· —· ——· / ——— ··—· / — ···· ·· ··· / —·— ·· —· —·· / ·—— ·— ··· / ··—· ——— ··— —· —·· ·—·—·—',
			'settings.peers.screenSharedSummaryNone' => '—· ——— — ···· ·· —· ——· / —·—· ···· ——— ··· · —· / —·—— · — ·—·—·—',
			'settings.peers.screenThisDevice' => '— ···· ·· ··· / —·· · ···— ·· —·—· ·',
			'settings.peers.screenSharedTo' => ({required Object devices}) => '··· ···· ——— ·—— —· / ——— —· / ${devices}',
			'settings.peers.screenSharedToNobody' => '—· ——— — / —··· · ·· —· ——· / ··· ···· ——— ·—— —·',
			'settings.peers.screenStopSharing' => ({required Object name}) => '··· — ——— ·——· / ··· ···· ·— ·—· ·· —· ——· / ${name}',
			'settings.developerMode' => '—·· · ···— · ·—·· ——— ·——· · ·—· / —— ——— —·· ·',
			'settings.syncPanel.configuration' => '··· —·—— —· —·—· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'settings.syncPanel.enableTitle' => '··· —·—— —· —·—· / ·—— ·· — ···· / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—·',
			'settings.syncPanel.enabledDescription' => '—··· ·— —·—· —·— ·· —· ——· / ··— ·——· / ·— —· —·· / ··· —·—— —· —·—· ·· —· ——· / —·—— ——— ··— ·—· / ·—·· ——— ——· / ·— —·—· ·—· ——— ··· ··· / —·· · ···— ·· —·—· · ···',
			'settings.syncPanel.disabledDescription' => '——— ··—· ··—· / — / ··· — ·— —·—— ·· —· ——· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · / ——— —· ·—·· —·——',
			'settings.syncPanel.syncing' => '··· —·—— —· —·—· ·· —· ——·',
			'settings.syncPanel.account' => '·— —·—· —·—· ——— ··— —· —',
			'settings.syncPanel.refresh' => '·—· · ··—· ·—· · ··· ····',
			'settings.syncPanel.switchAccounts' => '··· ·—— ·· — —·—· ···· / ·— —·—· —·—· ——— ··— —· — ···',
			'settings.syncPanel.switchAccountsDescription' => '·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ·— —· ——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· — / ·—— ·· — ···· / ·— / ——·— ·—· / —·—· ——— —·· · / ——— ·—· / · —— ·— ·· ·—··',
			'settings.syncPanel.connectionRequests' => '—·—· ——— —· —· · —·—· — ·· ——— —· / ·—· · ——·— ··— · ··· — ···',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·— / —·· · ···— ·· —·—· · / ·· ··· / ·—— ·— ·· — ·· —· ——· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· —', other: '${n} / —·· · ···— ·· —·—· · ··· / ·— ·—· · / ·—— ·— ·· — ·· —· ——· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· —', ), 
			'settings.syncPanel.accountEmailTitle' => '·— —·—· —·—· ——— ··— —· — / · —— ·— ·· ·—··',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => '—·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / ··· · —· — / — ——— / ${email} ·—·—·— / ——— ·——· · —· / — ···· · / ·—·· ·· —· —·— / — ···· · ·—· · / — ——— / ··—· ·· —· ·· ··· ···· / — ···· · / —·—· ···· ·— —· ——· · ·—·—·—',
			'settings.syncPanel.resendConfirmation' => '·—· · ··· · —· —·· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / · —— ·— ·· ·—··',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => '·—— ·— ·· — ·· —· ——· / ——— —· / ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => '··· · —· — / ·— ——· ·— ·· —· / — ——— / ${email} ·—·—·—',
			'settings.syncPanel.deviceLinked' => '— ···· ·— — / —·· · ···— ·· —·—· · / ·· ··· / —· ——— ·—— / ·—·· ·· —· —·— · —·· / — ——— / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—',
			'settings.syncPanel.checking' => '—·—· ···· · —·—· —·— ·· —· ——· …',
			'settings.syncPanel.notLinked' => '—· ——— — / ·—·· ·· —· —·— · —·· / —·—— · —',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} / —·——· # ${id} —·——·—',
			'settings.syncPanel.replaceDialogTitle' => '·—· · ·——· ·—·· ·— —·—· · / ·—·· ——— —·—· ·— ·—·· / —·· ·— — ·— ··——··',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${n} / ——— ·——· · ·—· ·— — ·· ——— —·', other: '${n} / ——— ·——· · ·—· ·— — ·· ——— —· ···', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${n} / ——·— ··· ———', other: '${n} / ——·— ··· ——— ···', ), 
			'settings.syncPanel.counts' => '··· —·—— —· —·—· · —·· / —·· ·— — ·—',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => '— ···· ·· ··· / —·· · ···— ·· —·—· · ———··· / ${qsos} / · / ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => '·—— ·— ·· — ·· —· ——· / — ——— / ··— ·——· ·—·· ——— ·— —·· ———··· / ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => '··· · ·—· ···— · ·—· ———··· / ${qsos} / · / ${operations}',
			'settings.syncPanel.countsLocalChecking' => '— ···· ·· ··· / —·· · ···— ·· —·—· · ———··· / —·—· ···· · —·—· —·— ·· —· ——· …',
			'settings.syncPanel.countsServerChecking' => '··· · ·—· ···— · ·—· ———··· / —·—· ···· · —·—· —·— ·· —· ——· …',
			'settings.syncPanel.countsServerUnavailable' => '··· · ·—· ···— · ·—· ———··· / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => '— ···· ·· ··· / —··· ·— —·—· —·— ··· / ··— ·——· / ·— —· —·· / —·—· ·—·· · ·— ·—· ··· / ${operations} / ·— —· —·· / ${qsos} / ··—· ·—· ——— —— / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / — ···· · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / —·· ·— — ·— / ·· —· ··· — · ·— —·· ·—·—·— / — ···· · / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ·· —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / —·· ·— — ·— —··· ·— ··· · ·—·—·—',
			'settings.syncPanel.replace' => '·—· · ·——· ·—·· ·— —·—· ·',
			'settings.syncPanel.pendingBannerTitle' => '—· · ·—— / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / ·— —·—· —·—· ——— ··— —· — / —·· · — · —·—· — · —··',
			'settings.syncPanel.pendingBannerBody' => '—·— · · ·——· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·————· ··· / · —··— ·· ··· — ·· —· ——· / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·— —· —·· / ——·— ··· ——— ··· / ·— —· —·· / —— · ·—· ——· · / — ···· · —— / ·· —· — ——— / — ···· · / ·— —·—· —·—· ——— ··— —· — ——··—— / ——— ·—· / ·—· · ·——· ·—·· ·— —·—· · / — ···· · —— / ·—— ·· — ···· / — ···· · / ·— —·—· —·—· ——— ··— —· — ·————· ··· / —·· ·— — ·— / —·——· ·— / —··· ·— —·—· —·— ··— ·——· / ··· — ·— —·—— ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · / · ·· — ···· · ·—· / ·—— ·— —·—— —·——·— ·—·—·—',
			'settings.syncPanel.combine' => '—·—· ——— —— —··· ·· —· ·',
			'settings.syncPanel.authIssueTitle' => '··· —·—— —· —·—· / —·—· ·— —· ·————· — / —·—· ——— —· —· · —·—· —',
			'settings.syncPanel.authIssueText' => '···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / —·— · · ·——· ··· / ·—· · ·——— · —·—· — ·· —· ——· / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·— / —·—· ···· · —·—· —·— / —·—— ——— ··— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·· —· / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ··· ·—·—·—',
			'settings.syncPanel.openSettings' => '——— ·——· · —· / ··· —·—— —· —·—· / ··· · — — ·· —· ——· ···',
			'settings.accounts.title' => '·— —·—· —·—· ——— ··— —· — ··· ——··—— / ··· · ·—· ···— ·· —·—· · ··· / ·—··· / —·· ·— — ·— / ··· ——— ··— ·—· —·—· · ···',
			'settings.accounts.none' => '—· ——— / ·— —·—· — ·· ···— · / · —··— — · —· ··· ·· ——— —· ··· / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — ···',
			'settings.accounts.notConfigured' => '—· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··',
			'settings.accounts.connected' => '—·—· ——— —· —· · —·—· — · —··',
			'settings.accounts.cancelLogin' => '—·—· ·— —· —·—· · ·—·· / ··· ·· ——· —· —····— ·· —·',
			'settings.accounts.openInBrowser' => '——— ·——· · —· / ·· —· / —··· ·—· ——— ·—— ··· · ·—·',
			'settings.accounts.loggedInAs' => ({required Object identity}) => '·—·· ——— ——· ——· · —·· / ·· —· / ·— ··· / ${identity}',
			'settings.accounts.pressSaveToKeep' => '·——· ·—· · ··· ··· / ··· ·— ···— · / — ——— / —·— · · ·——· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — / —·—· ——— —· —· · —·—· — · —·· ·—·—·—',
			'settings.accounts.connectedTo' => ({required Object label}) => '—·—· ——— —· —· · —·—· — · —·· / — ——— / ${label}',
			'settings.accounts.connect' => '—·—· ——— —· —· · —·—· —',
			'settings.accounts.disconnect' => '—·· ·· ··· —·—· ——— —· —· · —·—· —',
			'settings.accounts.connectedAs' => '—·—· ——— —· —· · —·—· — · —·· / ·— ···',
			'settings.accounts.test' => '— · ··· —',
			'settings.accounts.saveFailed' => ({required Object error}) => '··· ·— ···— · / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => '·—·· ——— ——· ·· —· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'settings.accounts.lookupFailed' => '·— —·—· —·—· ——— ··— —· — ··· / ·— ·—· · / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·—· ·· ——· ···· — / —· ——— ·—— / — / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· —',
			'settings.accounts.browserLoginTitle' => '··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / ·—— ·· — ···· / —·—— ——— ··— ·—· / ·—— · —··· / —··· ·—· ——— ·—— ··· · ·—·',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => '·—— ···· · —· / —·—— ——— ··— / ·— ·—· · / —·· ——— —· · ——··—— / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ·—— ·· ·—·· ·—·· / — ·—· —·—— / — ——— / ——— ·——· · —· / ·— / ·—·· ·· —· —·— / ··· — ·— ·—· — ·· —· ——· / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· ·—·—·— / —·—— ——— ··— ·—· / —·· · ··· —·— — ——— ·——· / —— ——— ··· — / ·—·· ·· —·— · ·—·· —·—— / ···· ·— ··· / —· ——— — ···· ·· —· ——· / ·—· · ——· ·· ··· — · ·—· · —·· / — ——— / ——— ·——· · —· / ·· — ——··—— / ··· ——— / —·—· ——— ·——· —·—— / — ···· ·— — / ·—·· ·· —· —·— / —·——· ··—· ·—· ——— —— / — ···· · / ·— —·· —·· ·—· · ··· ··· / —··· ·— ·—· ——··—— / ——— ·—· / ··—· ·—· ——— —— / — ···· · / · ·—· ·—· ——— ·—· / ·——· ·— ——· · / — ···· · / —··· ·—· ——— ·—— ··· · ·—· / ··· ···· ——— ·—— ··· —·——·— / ·— —· —·· / ·——· ·— ··· — · / ·· — / ···· · ·—· · ·—·—·—',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· ·—·—·— / —·—· ——— ·——· —·—— / — ···· · / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·— / —··· · ·—·· ——— ·—— / ·— —· —·· / ——— ·——· · —· / ·· — / —·—— ——— ··— ·—· ··· · ·—·· ··—· ——··—— / — ···· · —· / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·· —· —·— / ·· — / ··· · —· —·· ··· / —·—— ——— ··— / — ——— / —·——· ·· — / ··· — ·— ·—· — ··· / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· —·——·— / ·— —· —·· / ·——· ·— ··· — · / — ···· ·— — / ···· · ·—· · ·—·—·—',
			'settings.accounts.copyLoginLink' => '—·—· ——— ·——· —·—— / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·—',
			'settings.accounts.pastedLinkLabel' => '·——· ·— ··· — · / — ···· · / ·—·· ·· —· —·— / ···· · ·—· ·',
			'settings.accounts.finishLogin' => '··—· ·· —· ·· ··· ···· / ·—·· ——— ——· ·· —·',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => '— ···· ·— — / ·· ··· / —· ——— — / — ···· · / ·—·· ——— ——· ·· —· / ·—·· ·· —· —·— / — / ·· — / ··· ···· ——— ··— ·—·· —·· / ··· — ·— ·—· — / ·—— ·· — ···· / ·—··—· ${prefix} ·—··—· ·—·—·—',
			'settings.accounts.pastedLinkWrongLogin' => '— ···· ·— — / ·—·· ·· —· —·— / —··· · ·—·· ——— —· ——· ··· / — ——— / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ·—·· ——— ——· ·· —· / ·— — — · —— ·——· — ·—·—·— / —·—· ·—·· ——— ··· · / — ···· ·· ··· / ·——· ·— ——· · / ·— —· —·· / —·—· ——— —· —· · —·—· — / ·— ——· ·— ·· —· ·—·—·—',
			'settings.accounts.pastedLinkNoCode' => '— ···· ·— — / ·—·· ·· —· —·— / ···· ·— ··· / —· ——— / ·—·· ——— ——· ·· —· / —·—· ——— —·· · ·—·—·— / ··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / ··—· ·· ·—· ··· — ——··—— / — ···· · —· / —·—· ——— ·——· —·—— / — ···· · / ·—·· ·· —· —·— / ·· — / ··· · —· —·· ··· / —·—— ——— ··— / — ——— ·—·—·—',
			'settings.accounts.pastedLinkMalformed' => '— ···· ·— — / ·—·· ·· —· —·— / ·—·· ——— ——— —·— ··· / —·—· ··— — / ——— ··—· ··—· ·—·—·— / —·—· ——— ·——· —·—— / — ···· · / ·—— ···· ——— ·—·· · / — ···· ·· —· ——· / ·— —· —·· / ·——· ·— ··· — · / ·· — / ·— ——· ·— ·· —· ·—·—·—',
			'settings.accounts.relayLoginWaiting' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—— ——— ··— / — ——— / ··—· ·· —· ·· ··· ···· / ··· ·· ——· —· ·· —· ——· / ·· —· / — / — ···· ·· ··· / ·—— ·· ·—·· ·—·· / —·—· ——— —· — ·· —· ··— · / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·—— / ——— —· —·—· · / —·—— ——— ··— / —·· ——— ·—·—·—',
			'settings.accounts.loginNoResponse' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· —· ·————· — / ···· · ·— ·—· —·· / —··· ·— —·—· —·— / ··—· ·—· ——— —— / — ···· · / ··· ·· ——· —· —····— ·· —· / —·—— · — ·—·—·— / ·· ··—· / —·—— ——— ··— / ·— ·—·· ·—· · ·— —·· —·—— / ··—· ·· —· ·· ··· ···· · —·· / ·· —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· ——··—— / —·—· ·— —· —·—· · ·—·· / ·— —· —·· / — ·—· —·—— / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—',
			'settings.accounts.relayLoginNotOpened' => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / —·—— ——— ··— ·—· / —··· ·—· ——— ·—— ··· · ·—· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·—— ·—·—·— / ··— ··· · / — ···· · / —··· ··— — — ——— —· / —··· · ·—·· ——— ·—— / — ——— / ——— ·——· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·——· ·— ——· · / —·—— ——— ··— ·—· ··· · ·—·· ··—· ·—·—·—',
			'settings.accounts.relayLoginUnavailable' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · ·— —·—· ···· / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —· · · —·· · —·· / — ——— / —·—· ——— —— ·——· ·—·· · — · / — ···· ·· ··· / ·—·· ——— ——· ·· —· ·—·—·— / —·—· ···· · —·—· —·— / —·—— ——— ··— ·—· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'settings.accounts.loginIncompleteResponse' => '— ···· ·— — / ·—·· ——— ——· ·· —· / ·— — — · —— ·——· — / —·· ·· —·· —· ·————· — / —·—· ——— —— ·——· ·—·· · — · / —·—· ——— ·—· ·—· · —·—· — ·—·· —·—— ·—·—·— / ·——· ·—·· · ·— ··· · / — ·—· —·—— / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·—',
			'settings.accounts.noKeyringTitle' => '·— —·—· —·—· ——— ··— —· — / ·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —··',
			'settings.accounts.noKeyringText' => '···· ·— —— ··——— —·— / ·—·· ——— ——· ——· · ·—· / —·—· ·— —· ’ — / ·—· · ·— —·—· ···· / ·— / —·— · —·—— ·—· ·· —· ——· / ··· · ·—· ···— ·· —·—· · / ——— —· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ——··—— / ··· ——— / ·— —·—· —·—· ——— ··— —· — / ·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· — ——— ·—· · —·· / ——— ·—· / ·—· · ·— —·· / — / —·—· ——— —· —· · —·—· — ·· —· ——· / ·— —· / ·— —·—· —·—· ——— ··— —· — / ·—— ·· ·—·· ·—·· / ··—· ·— ·· ·—·· / ··— —· — ·· ·—·· / — ···· ·· ··· / ·· ··· / ··· ——— ·—· — · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / ·— —· —·· / ··· — ·— ·—· — / ** ——· —· ——— —— · —····— —·— · —·—— ·—· ·· —· ——· ** ——··—— / ** —·— ·—— ·— ·—·· ·—·· · — ** / ——— ·—· / ** —·— · · ·——· ·— ··· ··· —··— —·—· ** ——··—— / ——— ·—· / ··— —· ·—·· ——— —·—· —·— / — ···· · / —·— · —·—— ·—· ·· —· ——· / —·—— ——— ··— / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ···— · ——··—— / — ···· · —· / ·—· · ··· — ·— ·—· — ·—·—·— / ·—·· ——— ——· ——· ·· —· ——· ——··—— / · —··— ·——· ——— ·—· — ··· / ·— —· —·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ·— ·—· · / ··— —· ·— ··—· ··—· · —·—· — · —·· —·—·—· / ·—·· ——— ——· / ··· —·—— —· —·—· / ··· — ·— —·—— ··· / ——— ··—· ··—· / ·—— ···· ·· ·—·· · / — ···· ·· ··· / ·—·· ·— ··· — ··· ·—·—·—',
			'settings.accounts.noKeyringInline' => '·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —·· ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ’ ··· / —·— · —·—— ·—· ·· —· ——· / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / ·— —· —·· / ··· — ·— ·—· — / ——· —· ——— —— · —····— —·— · —·—— ·—· ·· —· ——· ——··—— / —·— ·—— ·— ·—·· ·—·· · — / ——— ·—· / —·— · · ·——· ·— ··· ··· —··— —·—· ——··—— / ——— ·—· / ··— —· ·—·· ——— —·—· —·— / — ···· · / ——— —· · / —·—— ——— ··— / ···· ·— ···— · ·—·—·—',
			'settings.accounts.noSecureStorageInline' => '·—·· ——— ——· ·· —· ··· / —·—· ·— —· ’ — / —··· · / ··· ·— ···— · —·· ———··· / — ···· ·· ··· / —·—· ——— —— ·——· ··— — · ·—· ’ ··· / ··· · —·—· ··— ·—· · / ··· — ——— ·—· ·— ——· · / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—',
			'settings.station.title' => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·—··· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—··',
			'settings.station.none' => '—· ——— / · ——·— ··— ·· ·——· —— · —· — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··',
			'settings.station.add' => '·— —·· —··',
			'settings.station.addTitle' => '·— —·· —·· / · ——·— ··— ·· ·——· —— · —· —',
			'settings.station.searchHint' => '··· · ·— ·—· —·—· ···· / · ——·— ··— ·· ·——· —— · —· —',
			'settings.station.noMatches' => '—· ——— / · ——·— ··— ·· ·——· —— · —· — / —— ·— — —·—· ···· · ···',
			'settings.station.detectedEquipment' => '—·· · — · —·—· — · —·· / · ——·— ··— ·· ·——· —— · —· —',
			'settings.station.discoveryUnavailable' => ({required Object error}) => '—·—· ·— —· ·————· — / ·—·· ·· ··· — · —· / ··—· ——— ·—· / ·—· ·— —·· ·· ——— ··· ———··· / ${error}',
			'settings.station.edit' => '· —·· ·· — / · ——·— ··— ·· ·——· —— · —· —',
			'settings.station.name' => '—· ·— —— ·',
			'settings.station.nameDescription' => '·—— ···· ·— — / —·—— ——— ··— / —·—· ·— ·—·· ·—·· / ·· — / — / ·—··—· ·—·· · ··—· — / ·—· ·— —·· ·· ——— ·—··—· ·—·—·— / ——— ·——· — ·· ——— —· ·— ·—·· ·—·—·—',
			'settings.station.transport' => '—·—· ——— —· —· · —·—· — ·· ——— —·',
			'settings.station.host' => '·— —·· —·· ·—· · ··· ···',
			'settings.station.hostDescription' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ···· ——— ··· — —· ·— —— · / ——— ·—· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / —· · — ·—— ——— ·—· —·— ·—·—·—',
			'settings.station.port' => '·——· ——— ·—· —',
			'settings.station.hostRequired' => '·— —· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··',
			_ => null,
		} ?? switch (path) {
			'settings.station.portInvalid' => '·——· ——— ·—· — / —— ··— ··· — / —··· · / —··· · — ·—— · · —· / ·———— / ·— —· —·· / —···· ····· ····· ···—— ·····',
			'settings.station.connect' => '—·—· ——— —· —· · —·—· —',
			'settings.station.disconnect' => '—·· ·· ··· —·—· ——— —· —· · —·—· —',
			'settings.station.remove' => '·—· · —— ——— ···— ·',
			'settings.station.removeTitle' => ({required Object name}) => '·—· · —— ——— ···— · / ${name} ··——··',
			'settings.station.removeMessage' => '— ···· ·· ··· / ——— —· ·—·· —·—— / ·—· · —— ——— ···— · ··· / ·· — / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — ···· · / · ——·— ··— ·· ·——· —— · —· — ·————· ··· / ··· · — — ·· —· ——· ··· / ··· — ·— —·—— / ·— ··· / — ···· · —·—— / ·— ·—· · ·—·—·—',
			'settings.station.unknownType' => ({required Object typeKey}) => '··— —· ·—· · —·—· ——— ——· —· ·· ——·· · —·· / · ——·— ··— ·· ·——· —— · —· — / — —·—— ·——· · / ·—··—· ${typeKey} ·—··—·',
			'settings.station.report' => '·—· · ·——· ——— ·—· —',
			'settings.station.reportTitle' => '·—· · ·——· ——— ·—· — / — ···· ·· ··· / ·—· ·— —·· ·· ———',
			'settings.station.reportIntro' => '— · ·—·· ·—·· / ··— ··· / ·—— ···· ·— — / ·—· ·— —·· ·· ——— / — ···· ·· ··· / ·—· · ·— ·—·· ·—·· —·—— / ·· ··· / ·— —· —·· / ···· ——— ·—— / ·· — / ·—— · —· — ·—·—·— / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / —··· · —·—· ——— —— · ··· / ·— / —·—· ·— ·—· —·· / — ···· · / ···· ·— —— ··——— —·— / — · ·— —— / ·—· · ·— —·· ··· ——··—— / ·— —· —·· / ·—— ···· ·— — / —·—— ——— ··— / ·—— ·—· ·· — · / ·— —··· ——— ··— — / ——· · — — ·· —· ——· / ·· — / ·—— ——— ·—· —·— ·· —· ——· / —— ·— —·—— / · —· —·· / ··— ·——· / ···· · ·—·· ·——· ·· —· ——· / — ···· · / —· · —··— — / ——— ·——· · ·—· ·— — ——— ·—· / ·—— ·· — ···· / — ···· · / ··· ·— —— · / ·—· ·· ——· ·—·—·—',
			'settings.station.reportManufacturer' => '—— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—·',
			'settings.station.reportManufacturerDescription' => '·—— ···· ——— / —— ·— —·— · ··· / ·· — / — / ·· —·—· ——— —— ——··—— / —·—— ·— · ··· ··— ——··—— / —·— · —· ·—— ——— ——— —·· ——··—— / · ·—·· · —·—· ·—· ·— ··—· — …',
			'settings.station.reportManufacturerRequired' => '·— / —— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··',
			'settings.station.reportModel' => '—— ——— —·· · ·—··',
			'settings.station.reportModelDescription' => '— ···· · / —— ——— —·· · ·—·· ——··—— / ·— ··· / — ···· · / ·—· ·— —·· ·· ——— / ·· — ··· · ·—·· ··—· / —·—· ·— ·—·· ·—·· ··· / ·· — / — / ·—··—· ·· —·—· —····— ——··· ···—— ————— ————— ·—··—· ——··—— / ·—··—· ··—· — —····— ————· ————· ·———— ·— ·—··—· ·—·—·—',
			'settings.station.reportModelRequired' => '·— / —— ——— —·· · ·—·· / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··',
			'settings.station.reportOutcome' => '···· ——— ·—— / —·· ·· —·· / ·· — / ——· ——— ··——··',
			'settings.station.reportOutcomeWorks' => '·—— ——— ·—· —·— · —·· / ·—— · ·—·· ·—··',
			'settings.station.reportOutcomeIssues' => '·—— ——— ·—· —·— · —·· ——··—— / ·—— ·· — ···· / ·· ··· ··· ··— · ···',
			'settings.station.reportOutcomeFails' => '—·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— / ·— — / ·— ·—·· ·—··',
			'settings.station.reportOutcomeRequired' => '·——· ·—·· · ·— ··· · / — · ·—·· ·—·· / ··— ··· / ···· ——— ·—— / ·· — / ·—— · —· —',
			'settings.station.reportComments' => '—·—· ——— —— —— · —· — ···',
			'settings.station.reportCommentsPlaceholder' => '·—— ···· ·— — / ·—— ——— ·—· —·— · —·· ——··—— / ·—— ···· ·— — / —·· ·· —·· —· ·————· — ——··—— / ·— —· —·—— — ···· ·· —· ——· / — ···· ·— — / ··· ··— ·—· ·——· ·—· ·· ··· · —·· / —·—— ——— ··— ·—·—·—',
			'settings.station.reportHints' => '— ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / ···· ·· —· — ···',
			'settings.station.reportHintsPlaceholder' => '·—— ·— —· — / — ——— / ··· ··— ——· ——· · ··· — / ··· ——— —— · / — ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / ···· ·· —· — ··· / ··—· ——— ·—· / ——— — ···· · ·—· / ··— ··· · ·—· ··· ··——··',
			'settings.station.reportSend' => '··· · —· —·· / ·—· · ·——· ——— ·—· —',
			'settings.station.reportSending' => '··· · —· —·· ·· —· ——· / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — …',
			'settings.station.reportSent' => ({required Object ref}) => '— ···· ·— —· —·— ··· / — / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / ·—— ·— ··· / ··—· ·· ·—·· · —·· / ·— ··· / ${ref} ·—·—·—',
			'settings.station.reportSentNoRef' => '— ···· ·— —· —·— ··· / — / —·—— ——— ··— ·—· / ·—· · ·——· ——— ·—· — / ·—— ·— ··· / ··· · —· — ·—·—·—',
			'settings.station.reportFailed' => ({required Object error}) => '— ···· · / ·—· · ·——· ——— ·—· — / ·—— ·— ··· —· ·————· — / ··· · —· — ———··· / ${error}',
			'settings.station.troubleshootingNotes' => '— ·—· ——— ··— —··· ·—·· · ··· ···· ——— ——— — ·· —· ——· / —· ——— — · ···',
			'settings.station.mainVfo' => '—— ·— ·· —· / ···— ··—· ———',
			'settings.station.useAsMainVfo' => '··— ··· · / ·— ··· / —— ·— ·· —· / ···— ··—· ———',
			'settings.station.serialPort' => '··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· —',
			'settings.station.serialPortDescription' => '— ···· · / ·——· ——— ·—· — / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·· —· — · ·—· ··—· ·— —·—· · / ·— ·——· ·——· · ·— ·—· ··· / ——— —· ·—·—·—',
			'settings.station.serialPortNone' => '—· ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ··—· ——— ··— —· —··',
			'settings.station.serialPortRequired' => '—·—· ···· ——— ——— ··· · / ·— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· —',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => '·——· ——— ·—· — / ${n} / ——— ··—· / ${total}',
			'settings.station.serialPortSuggested' => '··· ··— ——· ——· · ··· — · —··',
			'settings.station.serialPortJustNow' => '·—· · —·—· · —· — ·—·· —·—— / —·—· ——— —· —· · —·—· — · —··',
			'settings.station.serialDeviceRequest' => '·— —·· —·· / ·— / ··— ··· —··· / —·· · ···— ·· —·—· · …',
			'settings.station.bleDevice' => '—··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· ·',
			'settings.station.bleDeviceDescription' => '— ···· · / ··· · ·—· ·· ·— ·—·· / —··· ·—· ·· —·· ——· · / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ···· ·—· ——— ··— ——· ···· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / ·· —· / ·· — ··· / ·· ——— ··· / —— ——— —·· · / ——— ·—· / ·— / —··· ·—·· · / ··· · ·—· ·· ·— ·—·· / ·— —·· ·— ·——· — · ·—· ·—·—·—',
			'settings.station.bleScan' => '··· —·—· ·— —· / ··—· ——— ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ··· …',
			'settings.station.bleScanNoneFound' => '—· ——— / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ··· / ··—· ——— ··— —· —·· ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / — ···· · / —··· ·—· ·· —·· ——· · / ·· ··· / ——— —· ——··—— / —· · ·— ·—· —··· —·—— ——··—— / ·— —· —·· / ·· —· / ·· — ··· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·——· ·· ——— ··· —·——·— / —— ——— —·· · ·—·—·—',
			'settings.station.bleScanFailed' => ({required Object reason}) => '— ···· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / ··· —·—· ·— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· ··— —· ———··· / ${reason}',
			'settings.station.bleOff' => '—··· ·—·· ··— · — ——— ——— — ···· / ·· ··· / — ··— ·—· —· · —·· / ——— ··—· ··—· ·—·—·—',
			'settings.station.bleDenied' => '—··· ·—·· ··— · — ——— ——— — ···· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / ·—— ·— ··· / —· ——— — / ——· ·—· ·— —· — · —·· ·—·—·— / ·— ·—·· ·—·· ——— ·—— / ·· — / ·· —· / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· ——··—— / — ···· · —· / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'settings.station.bleUnsupported' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ·—·—·—',
			'settings.station.bleStarting' => '—··· ·—·· ··— · — ——— ——— — ···· / ·· ··· / ··· — ·· ·—·· ·—·· / ··· — ·— ·—· — ·· —· ——· / ··— ·——· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—',
			'settings.station.bleConnectFailed' => '—·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ·· — ·————· ··· / ——— —· ——··—— / —· · ·— ·—· —··· —·—— ——··—— / ·— —· —·· / —· ——— — / —·—· ——— —· —· · —·—· — · —·· / — ——— / ·— —· ——— — ···· · ·—· / ·— ·——· ·——· ·—·—·—',
			'settings.station.bleNoSerialService' => ({required Object services}) => '— ···· ·· ··· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / ··· · ·—· ·· ·— ·—·· / ··· · ·—· ···— ·· —·—· · / — ···· · / ·— ·——· ·——· / ·—· · —·—· ——— ——· —· ·· ——·· · ··· ·—·—·— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·· — / ·—— ·· — ···· / ·· — ··· / ··· · ·—· ···— ·· —·—· · ··· ———··· / ${services}',
			'settings.station.baudRate' => '··· ·——· · · —·· / —·——· —··· ·— ··— —·· —·——·—',
			'settings.station.baudRateDescription' => '—— ··— ··· — / —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ·— —· —·· / —· ——— / · ·—· ·—· ——— ·—· ·—·—·—',
			'settings.station.serialRtsHigh' => '···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ····',
			'settings.station.serialRtsHighDescription' => '——— —· ·—·· —·—— / ··—· ——— ·—· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·—· — ··· / —··· · ··—· ——— ·—· · / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / —·—— ·— · ··· ··— / ·—— ·· — ···· / —·—· ·— — / ·—· — ··· / — ··— ·—· —· · —·· / ——— —· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ·— —· —·· / —— ——— ··· — / ···· ——— —— · —····— —— ·— —·· · / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / — ·—· ·— —· ··· —— ·· — ··· ·—·—·—',
			'settings.station.serialDtrHigh' => '···· ——— ·—·· —·· / —·· — ·—· / ···· ·· ——· ····',
			'settings.station.serialDtrHighDescription' => '——— —· ·—·· —·—— / ··—· ——— ·—· / ·— / —·—· ·— — / ·· —· — · ·—· ··—· ·— —·—· · / — ···· ·— — / —·· ·—· ·— ·—— ··· / ·· — ··· / ·——· ——— ·—— · ·—· / ··—· ·—· ——— —— / —·· — ·—· ——··—— / ··· ··— —·—· ···· / ·— ··· / ··· ——— —— · / ·—· ··· —····— ··——— ···—— ··——— / —·—· ·— —··· ·—·· · ··· / ··—· ——— ·—· / — ···· · / ··—· — —····— ———·· ·———— ——··· ·—·—·— / ——— —· / —— ·— —· —·—— / —·—· ·— —··· ·—·· · ··· / —·· — ·—· / —·— · —·—— ··· / —·—· ·—— / ——— ·—· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / — ·—· ·— —· ··· —— ·· — ··· ·—·—·—',
			'settings.station.civAddress' => '·—· ·— —·· ·· ——— / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ···',
			'settings.station.civAddressDescription' => '···· · —··— ——··—— / ·— ··· / ··· ···· ——— ·—— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / —— · —· ··— ·—·—·— / — ···· · / ·· —·—· —····— ——··· ————— ····· / ··· ···· ·· ·——· ··· / ·— ··· / ·— ····— ·—·—·—',
			'settings.station.civAddressInvalid' => '·— / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / ·· ··· / — ·—— ——— / ···· · —··— / —·· ·· ——· ·· — ··· ——··—— / ————— ·———— / — ——— / ··—· ··—·',
			'settings.station.flexSlice' => '··· ·—·· ·· —·—· ·',
			'settings.station.flexSliceDescription' => '·—— ···· ·· —·—· ···· / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·—·· ·· —·—· · ··· / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·—· · ·— —·· ··· / ··—· ·—· ——— —— / ·— —· —·· / — ··— —· · ··· ·—·—·—',
			'settings.station.flexSliceLabel' => ({required Object letter}) => '··· ·—·· ·· —·—· · / ${letter}',
			'settings.station.flexSliceInvalid' => '·——· ·· —·—· —·— / ——— —· · / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·—·· ·· —·—· · ··· ——··—— / ·— / — ···· ·—· ——— ··— ——· ···· / ····',
			'settings.station.flexSliceMissing' => ({required Object letter}) => '··· ·—·· ·· —·—· · / ${letter} / ·· ··· / —· ——— — / ·· —· / ··— ··· · / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — / ·——· ·· —·—· —·— / ·— —· ——— — ···· · ·—· / ··· ·—·· ·· —·—· · ——··—— / ——— ·—· / —·—· ·—· · ·— — · / ·· — / ·· —· / ··· —— ·— ·—· — ··· —·· ·—·',
			'settings.station.channelNotInUse' => '—· ——— — / ·· —· / ··— ··· ·',
			'settings.station.channelHeldByUnknown' => '·· —· / ··— ··· · / —··· —·—— / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— ——',
			'settings.station.flexNoSlices' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ···· ·— ··· / —· ——— — / ·—· · ·——· ——— ·—· — · —·· / ·— —· —·—— / ··· ·—·· ·· —·—· · ··· / — / —·—· ···· · —·—· —·— / — ···· ·— — / ··· —— ·— ·—· — ··· —·· ·—· / ·· ··· / ·—· ··— —· —· ·· —· ——· / ·— —· —·· / — ···· ·— — / — ···· ·· ··· / —·—· ·—·· ·· · —· — / —— ·— —·—— / ··· ··— —··· ··· —·—· ·—· ·· —··· ·',
			'settings.station.spectrumUnsupported' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —· ——— / ··· ·——· · —·—· — ·—· ··— —— / ——— ···— · ·—· / —·—· ·— —',
			'settings.station.spectrumRequiresBaud' => '·—· · ——·— ··— ·· ·—· · ··· / —·—· ·— — / ·— — / ·———— ·———— ····· ··——— ————— ————— / —··· ·——· ···',
			'settings.station.spectrumNoRadio' => '—· ——— / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — · —··',
			'settings.station.spectrumWaiting' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·——· · —·—· — ·—· ··— —— …',
			'settings.station.spectrumUnavailable' => '··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / —· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'settings.station.spectrumNoDaxChannel' => '· ···— · ·—· —·—— / —·· ·— —··— / ·· ——·— / —·—· ···· ·— —· —· · ·—·· / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / ·· —· / ··— ··· ·',
			'settings.station.spectrumNoPanadapter' => '— ···· ·· ··· / ··· ·—·· ·· —·—· · / ···· ·— ··· / —· ——— / ·——· ·— —· ·— —·· ·— ·——· — · ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ———',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => '— ···· · / ·—· ·— —·· ·· ——— / ·—· · ··—· ··— ··· · —·· / ·— / —·· ·— —··— / ·· ——·— / ··· — ·—· · ·— —— / —·——· · ·—· ·—· ——— ·—· / ${code} —·——·—',
			'settings.station.spectrumNoUdp' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·——· · —·—· — ·—· ··— —— / —·· ·— — ·— / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· ·· ··· / —·· · ···— ·· —·—· ·',
			'settings.station.spectrumK4Unavailable' => '—·—· ·— —· —· ——— — / ·—· · —·—· · ·· ···— · / — ···· · / —·— ····— ’ ··· / ·—·· ·— —· / ··· ·——· · —·—· — ·—· ··— —— ·—·—·— / ·—· · — ·—· —·—— ·· —· ——· …',
			'settings.station.spectrumK4RemoteUnavailable' => '—·—· ·— —· —· ——— — / ·—· · —·—· · ·· ···— · / — ···· · / —·— ····— ’ ··· / ·—· · —— ——— — · / ··· ·——· · —·—· — ·—· ··— ——',
			'settings.station.spectrumScopeRefused' => '— ···· · / ·—· ·— —·· ·· ——— / ·—· · ··—· ··— ··· · —·· / ·· — ··· / ··· —·—· ——— ·——· · / —·—· ——— —— —— ·— —· —·· ···',
			'settings.station.spectrumOutOfRange' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· —·—· ——— ·——· · / ·· ··· / ··· · — / ——— ··— — ··· ·· —·· · / — ···· · / ·—· ·— —· ——· · / ·· — / —·—· ·— —· / ··· ···· ——— ·——',
			'settings.station.spectrumBandUnsupported' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· —·—· ——— ·——· · / —·—· ·— —· —· ——— — / —··· · / ··· ···· ——— ·—— —· / ——— —· / — ···· ·· ··· / —··· ·— —· —··',
			'settings.station.spectrumSdrNoRadio' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / — ···· · / ·—·· ·· —· —·— · —·· / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— …',
			'settings.station.spectrumSdrNotConnected' => '— ···· · / ··· —·· ·—· / ·· ··· / —· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'settings.station.spectrumSdrNoIf' => '··· · — / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· —· / — ···· ·· ··· / ··· —·· ·—· ·————· ··· / ··· · — — ·· —· ——· ···',
			'settings.station.sdrRadio' => '··· ···· ——— ·—— ··· / — ···· · / ··· ·——· · —·—· — ·—· ··— —— / ··—· ——— ·—·',
			'settings.station.sdrRadioDescription' => '·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ——— —· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / —·· ·—· ·— ·—— ··· / ··—· ·—· ——— —— / — ···· ·· ··· / ·—· · —·—· · ·· ···— · ·—· / ·· —· ··· — · ·— —·· / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··· —·—· ——— ·——· · ·—·—·—',
			'settings.station.sdrRadioMain' => '— ···· · / —— ·— ·· —· / ·—· ·— —·· ·· ———',
			'settings.station.sdrTuning' => '·— —· — · —· —· ·— / ·· —· ·——· ··— —',
			'settings.station.sdrTuningDescription' => '·—— ···· · ·—· · / — ···· · / ·—· · —·—· · ·· ···— · ·—· ·————· ··· / ··· ·· ——· —· ·— ·—·· / —·—· ——— —— · ··· / ··—· ·—· ——— —— ·—·—·— / ——— —· / ·· — ··· / ——— ·—— —· / ·— —· — · —· —· ·— / ·· — / — ··— —· · ··· / ·· — ··· · ·—·· ··—· / — ——— / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ·—· ·— —·· ·· ——— —·—·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ——— ··— — ·——· ··— — / ·· — / ··· — ·— —·—— ··· / ——— —· / — ···· · / ·· ··—· ·—·—·—',
			'settings.station.sdrTuningIndependent' => '·· — ··· / ——— ·—— —· / ·— —· — · —· —· ·—',
			'settings.station.sdrTuningIfTap' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· ··—· / ——— ··— — ·——· ··— —',
			'settings.station.sdrIfHz' => '·· ··—· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / —·——· ···· ——·· —·——·—',
			'settings.station.sdrIfHzDescription' => '··—· ——— ·—· / ·— —· / ·· ··—· / ——— ··— — ·——· ··— — / ——— —· ·—·· —·—— ———··· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·· ·· ·— ·—·· / ··· ·· — ··· / ·— — / ——— —· / ·· — ··· / ·· ··—· ——··—— / ··· ··— —·—· ···· / ·— ··· / —···· ———·· ···—— ···—— ————— ————— ————— ————— / ——— —· / ·— —· / ··—· — —····— ———·· ·———— ——··· ·—·—·—',
			'settings.station.sdrIfInverted' => '·· ··—· / ·· ··· / ·· —· ···— · ·—· — · —··',
			'settings.station.sdrGainDb' => '——· ·— ·· —· / —·——· —·· —··· —·——·—',
			'settings.station.sdrGainDbDescription' => '·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / — ···· · / ·—· · —·—· · ·· ···— · ·—· ·————· ··· / ·— ··— — ——— —— ·— — ·· —·—· / ——· ·— ·· —· ·—·—·—',
			'settings.station.sdrOffsetHz' => '··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— ··—· ··—· ··· · — / —·——· ···· ——·· —·——·—',
			'settings.station.sdrOffsetHzDescription' => '·— —·· —·· · —·· / — ——— / · ···— · ·—· —·—— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··· · —· — / — ——— / — ···· · / ·—· · —·—· · ·· ···— · ·—· ——··—— / ··—· ——— ·—· / ·— —· / ··— ·——· —·—· ——— —· ···— · ·—· — · ·—· ———··· / ·———— ··——— ····· ————— ————— ————— ————— ————— ————— / ··—· ——— ·—· / ·— / ···· ·— —— / ·· — / ··— ·——· ·—·—·—',
			'settings.station.sdrPpm' => '··—· ·—· · ——·— ··— · —· —·—· —·—— / —·—· ——— ·—· ·—· · —·—· — ·· ——— —· / —·——· ·——· ·——· —— —·——·—',
			'settings.station.rtlDirectSampling' => '—·· ·· ·—· · —·—· — / ··· ·— —— ·——· ·—·· ·· —· ——·',
			'settings.station.rtlDirectSamplingDescription' => '··—· ——— ·—· / ···· ··—· / ——— —· / ·— —· / ·—· — ·—·· —····— ··· —·· ·—· / ···— ···—— / ·—— ·· — ···· ——— ··— — / ·— —· / ··— ·——· —·—· ——— —· ···— · ·—· — · ·—· ·—·—·— / ·— —· / ·—· — ·—·· —····— ··· —·· ·—· / ···— ····— / ·—· · ·— —·—· ···· · ··· / ···· ··—· / ·—— ·· — ···· ——— ··— — / ·· — ·—·—·—',
			'settings.station.rtlDirectSamplingOff' => '——— ··—· ··—·',
			'settings.station.rtlDirectSamplingI' => '·· / —··· ·—· ·— —· —·—· ····',
			'settings.station.rtlDirectSamplingQ' => '——·— / —··· ·—· ·— —· —·—· ····',
			'settings.station.rtlTcpNotAServer' => '— ···· ·· ··· / ·· ··· / —· ——— — / ·— —· / ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—·',
			'settings.station.rtlTcpNotes' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** / ——— —· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / — ···· · / —·· ——— —· ——· ·—·· · / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—\n\n—····— / ** ··· — ·— ·—· — / ·· — ** / ·—— ·· — ···· / `rtl_tcp -a 0.0.0.0` / ··· ——— / ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ··· / —·—· ·— —· / ·—· · ·— —·—· ···· / ·· — —·—·—· / ——— —· / — ···· · / ··· ·— —— · / —— ·— —·—· ···· ·· —· · ——··—— / `rtl_tcp` / ·— ·—·· ——— —· · / ·—— ·· ·—·· ·—·· / —·· ——— ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / ·· — / ·—— ·· — ···· / `-p` ·—·—·—\n—····— / ** ——— —· · / ·——· ·—· ——— ——· ·—· ·— —— / ·— — / ·— / — ·· —— · ———··· ** / ·—· — ·—·· ··——·— — —·—· ·——· / ··· · ·—· ···— · ··· / ·— / ··· ·· —· ——· ·—·· · / —·—· ·—·· ·· · —· — ·—·—·— / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·· ·—·· · / ·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··· ···· ——— ·—— ·· —· ——· ——··—— / ·— —· —·· / ·—·· · — ··· / ——· ——— / ·— / ··—· · ·—— / ··· · —·—· ——— —· —·· ··· / ·— ··—· — · ·—· / ·· — / —·—· ·—·· ——— ··· · ··· ·—·—·—\n—····— / ** ——— —· / ·— —· —·· ·—· ——— ·· —·· ** ——··—— / — ···· · / * ··· —·· ·—· / —·· ·—· ·· ···— · ·—· * / ·— ·——· ·——· / ·—· ··— —· ··· / — ···· · / ··· ·— —— · / ··· · ·—· ···— · ·—· / ——— —· / — ···· · / ·——· ···· ——— —· · ·—·—·—',
			'settings.station.rspTcpNotes' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ·—· ··· ·——· ··——·— — —·—· ·——· / ··· · ·—· ···— · ·—· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** / ——— —· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / — ···· · / ·—· ··· ·——· / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ——··—— / ·—— ·· — ···· / ··· —·· ·—· ·——· ·—·· ·— —·—— ·————· ··· / ·— ·——· ·· / ·· —· ··· — ·— ·—·· ·—·· · —·· / — ···· · ·—· · ·—·—·—\n\n—····— / ** ··· — ·— ·—· — / ·· — ** / ·—— ·· — ···· / `rsp_tcp -a 0.0.0.0` ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / ·· — / ·—— ·· — ···· / `-p` ·—·—·—\n—····— / ** ——— —· · / ·——· ·—· ——— ——· ·—· ·— —— / ·— — / ·— / — ·· —— · ———··· ** / — ···· · / ··· · ·—· ···— · ·—· / — ·— —·— · ··· / ·— / ··· ·· —· ——· ·—·· · / —·—· ·—·· ·· · —· — ·—·—·— / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·· ·—·· · / ·— / ··· ·——· · —·—· — ·—· ··— —— / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··· ···· ——— ·—— ·· —· ——· ·—·—·—',
			'settings.station.n3fjpNoRig' => '—· ···—— ··—· ·——— ·——· / ···· ·— ··· / —· ——— / ·—· ·— —·· ·· ——— / ·· —· — · ·—· ··—· ·— —·—· · / ··· · — / ··— ·——· ——··—— / ··· ——— / — ···· ·· ··· / ··—· ——— ·—·· ·—·· ——— ·—— ··· / ·—— ···· ·— — / ·· ··· / — —·—— ·——· · —·· / ·· —· — ——— / —· ···—— ··—· ·——— ·——· ——··—— / —· ——— — / ·— / ·—· ·— —·· ·· ———',
			'settings.station.winkeyerKeyPort' => '—·— · —·—— / ——— ··— — ·——· ··— —',
			'settings.station.winkeyerKeyPortDescription' => '·—— ···· ·· —·—· ···· / ——— ··—· / — ···· · / —·— · —·—— · ·—· ·————· ··· / — ·—— ——— / ——— ··— — ·——· ··— — / ·——— ·— —·—· —·— ··· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => '·——· ——— ·—· — / ${n}',
			'settings.station.winkeyerPtt' => '··— ··· · / — ···· · / —·— · —·—— · ·—· ·————· ··· / ·——· — —',
			'settings.station.winkeyerPttDescription' => '—·— · —·—— / — ···· · / ·——· — — / ·—·· ·· —· · / ——— —· / — ···· · / ··· ·— —— · / ·——— ·— —·—· —·— ——··—— / ··—· ——— ·—· / ·— —· / ·— —— ·——· ·—·· ·· ··—· ·· · ·—· / ——— ·—· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / —· · · —·· ··· / ·· — ·—·—·— / ·—·· · ·— ···— · / ——— ··—· ··—· / ··—· ——— ·—· / ·— / ·—· ·— —·· ·· ——— / —·— · —·—— · —·· / ——— —· / ·· — ··· / —·— · —·—— / ·——— ·— —·—· —·— ·—·—·—',
			'settings.station.winkeyerNoAnswer' => '—· ——— / ·—— ·· —· —·— · —·—— · ·—· / ·—· · ··· ·——· ——— —· —·· · —·· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· —',
			'settings.station.winkeyerStoppedAnswering' => '— ···· · / ·—— ·· —· —·— · —·—— · ·—· / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·—— ···· ·· ·—·· · / ··· · —· —·· ·· —· ——· —·—·—· / — ···· · / —— · ··· ··· ·— ——· · / ·—— ·— ··· / —·· ·—· ——— ·——· ·——· · —··',
			'settings.station.icomControlPort' => '—·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·—',
			'settings.station.icomControlPortDescription' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— / — / ····· ————— ————— ————— ·———— / ··— —· ·—·· · ··· ··· / —·—· ···· ·— —· ——· · —·· / ·· —· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / ·— —· ——— — ···· · ·—· ·—·—·—',
			'settings.station.icomSerialPort' => '··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·—',
			'settings.station.icomSerialPortDescription' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— / — / ····· ————— ————— ————— ··——— / ··— —· ·—·· · ··· ··· / —·—· ···· ·— —· ——· · —·· / ·· —· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / ·— —· ——— — ···· · ·—· ·—·—·—',
			'settings.station.icomPortsDiffer' => '— ···· · / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / —— ··— ··· — / —·· ·· ··—· ··—· · ·—·',
			'settings.station.radioUser' => '·—· ·— —·· ·· ——— / ··— ··· · ·—· —· ·— —— ·',
			'settings.station.radioPass' => '·—· ·— —·· ·· ——— / ·——· ·— ··· ··· ·—— ——— ·—· —··',
			'settings.station.radioLoginDescription' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / → / ·—· · —— ——— — · / ·—·· ——— ——· ·· —· ——··—— / —· ——— — / —·—— ——— ··— ·—· / ·—— ·· ··—· ·· / ·——· ·— ··· ··· ·—— ——— ·—· —·· ·—·—·—',
			'settings.station.radioUserRequired' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··— ··· · ·—· —· ·— —— · / ·· ··· / ·—· · ——·— ··— ·· ·—· · —··',
			'settings.station.connectFailedBusy' => '—·· · ···— ·· —·—· · / ·· ··· / ·· —· / ··— ··· ·',
			'settings.station.connectFailedDenied' => '·— —·—· —·—· · ··· ··· / —·· · —· ·· · —··',
			'settings.station.connectFailedDevice' => '—·· · ···— ·· —·—· · / —· ——— — / ··—· ——— ··— —· —··',
			'settings.station.connectFailedLines' => '·—· — ··· —··—· —·· — ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ···· · ·—·· —·· / ·— ··· / ··· · — ——··—— / ··· ——— / — ···· · / ·——· ——— ·—· — / ·—— ·— ··· / —·—· ·—·· ——— ··· · —·· ·—·—·— / ·— —· ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— / —— ·— —·—— / ···· ·— ···— · / ·—·· · ··—· — / ···· ·— ·—· —·· ·—— ·— ·—· · / ···· ·— —· —·· ··· ···· ·— —·— ·· —· ——· / ——— —· / — / ··— —· ·——· ·—·· ··— ——· / ·— —· —·· / ·—· · ·——· ·—·· ··— ——· / — ···· · / —·—· ·— —··· ·—·· · ·—·—·—',
			'settings.station.connectFailedNetwork' => '—·—· ·— —· —· ——— — / ··—· ·· —· —·· / — ···· · / ·—· ·— —·· ·· ——— / ——— ···— · ·—· / — ···· · / —· · — ·—— ——— ·—· —·— ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / ·— —·· —·· ·—· · ··· ··· / ·— —· —·· / — ···· ·— — / ·· — ·————· ··· / ·——· ——— ·—— · ·—· · —·· / ——— —· / ·— —· —·· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·—',
			'settings.station.connectFailedTimeout' => '— ···· · / ·—· ·— —·· ·· ——— / —·· ·· —·· —· ·————· — / ·—· · ··· ·——· ——— —· —·· / ·· —· / — ·· —— · ·—·—·— / —·—· ···· · —·—· —·— / ·· — ·————· ··· / ·——· ——— ·—— · ·—· · —·· / ——— —· / ·— —· —·· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·—',
			'settings.station.models.flexRadio' => '··—· ·—·· · —··— ·—· ·— —·· ·· ——— / —·——· ··· —— ·— ·—· — ··· —·· ·—· —·——·—',
			'settings.station.models.ft891' => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ————· ·————',
			'settings.station.models.ft991a' => '—·—— ·— · ··· ··— / ··—· — —····— ————· ————· ·———— —··—· ·—',
			'settings.station.models.ft710' => '—·—— ·— · ··· ··— / ··—· — —····— ——··· ·———— —————',
			'settings.station.models.ftdx10' => '—·—— ·— · ··· ··— / ··—· — —·· —··— ·———— —————',
			'settings.station.models.ftx1' => '—·—— ·— · ··· ··— / ··—· — —··— —····— ·————',
			'settings.station.models.ft817' => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ·———— ——··· / —··—· / ··—· — —····— ———·· ·———— ———··',
			'settings.station.models.ft857' => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ····· ——···',
			'settings.station.models.ft897' => '—·—— ·— · ··· ··— / ··—· — —····— ———·· ————· ——···',
			'settings.station.models.ft450' => '—·—— ·— · ··· ··— / ··—· — —····— ····— ····· ————— / —··—· / ··—· — —····— ····— ····· ————— —··',
			'settings.station.models.q900' => '——· ··— ——— ···· · — · —·—· / ——·— ————· ————— —————',
			'settings.station.models.tenTecEagle' => '— · —· —····— — · —·—· / · ·— ——· ·—·· · / —·——· ····· ————· ————· —·——·—',
			'settings.station.models.tenTecOrion' => '— · —· —····— — · —·—· / ——— ·—· ·· ——— —· / —·——· ····· —···· ····· —·——·—',
			'settings.station.models.tenTecOrionII' => '— · —· —····— — · —·—· / ——— ·—· ·· ——— —· / ·· ·· / —·——· ····· —···· —···· —·——·—',
			'settings.station.models.sotacat' => '··· ——— — ·— —·—· ·— — / —·——· · ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··——— —··—· —·— —··— ···—— —·——·—',
			'settings.station.models.yaesuGeneric' => '—·—— ·— · ··· ··— / —····— / ——· · —· · ·—· ·· —·—·',
			'settings.station.models.icomGeneric' => '·· —·—· ——— —— / —····— / ——· · —· · ·—· ·· —·—·',
			'settings.station.models.kenwoodGeneric' => '—·— · —· ·—— ——— ——— —·· / —····— / ——· · —· · ·—· ·· —·—·',
			'settings.station.models.ts590sg' => '—·— · —· ·—— ——— ——— —·· / — ··· —····— ····· ————· ————— ··· ——·',
			'settings.station.models.ts480' => '—·— · —· ·—— ——— ——— —·· / — ··· —····— ····— ———·· —————',
			'settings.station.models.qmx' => '——·— ·—· ·——· / ·—·· ·— —··· ··· / ——·— —— —··—',
			'settings.station.models.fx4cr' => '—··· ——· ··——— ··—· —··— / ··—· —··— —····— ····— —·—· ·—·',
			'settings.station.models.tx500' => '·—·· ·— —··· ····· ————· ————· / — —··— —····— ····· ————— —————',
			'settings.station.models.tx500mp' => '·—·· ·— —··· ····· ————· ————· / — —··— —····— ····· ————— ————— —— ·——·',
			'settings.station.models.qcx' => '——·— ·—· ·——· / ·—·· ·— —··· ··· / ——·— —·—· —··—',
			'settings.station.models.elecraftGeneric' => '· ·—·· · —·—· ·—· ·— ··—· — / —····— / ——· · —· · ·—· ·· —·—·',
			'settings.station.models.kx2' => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··———',
			'settings.station.models.kx3' => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ···——',
			'settings.station.models.k4' => '· ·—·· · —·—· ·—· ·— ··—· — / —·— ····—',
			'settings.station.models.ic705' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ————— ·····',
			'settings.station.models.ic7300' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ···—— ————— —————',
			'settings.station.models.ic7300mk2' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··———',
			'settings.station.models.ic706mkiig' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ————— —···· —— —·— ·· ·· ——·',
			'settings.station.models.ic7100' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ·———— ————— —————',
			'settings.station.models.ic7610' => '·· —·—· ——— —— / ·· —·—· —····— ——··· —···· ·———— —————',
			'settings.station.models.ic7760' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ——··· —···· —————',
			'settings.station.models.ic9700' => '·· —·—· ——— —— / ·· —·—· —····— ————· ——··· ————— —————',
			'settings.station.models.ic905' => '·· —·—· ——— —— / ·· —·—· —····— ————· ————— ·····',
			'settings.station.models.ic7850' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ———·· ····· —————',
			'settings.station.models.ic7851' => '·· —·—· ——— —— / ·· —·—· —····— ——··· ———·· ····· ·————',
			'settings.station.models.x6100' => '—··— ·· · ——· ··— / —··— —···· ·———— ————— —————',
			'settings.station.models.g90' => '—··— ·· · ——· ··— / ——· ————· —————',
			'settings.station.models.rigctld' => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ·—· ·· ——· —·—· — ·—·· —··',
			'settings.station.models.rigctldNodeName' => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ·—· ·· ——· —·—· — ·—·· —·· —·——·—',
			'settings.station.models.flrig' => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ··—· ·—·· ·—· ·· ——·',
			'settings.station.models.flrigNodeName' => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ··—· ·—·· ·—· ·· ——· —·——·—',
			'settings.station.models.hrd' => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / ···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ®',
			'settings.station.models.hrdNodeName' => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / ···· ·—· —·· —·——·—',
			'settings.station.models.n3fjp' => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / —· ···—— ··—· ·——— ·——·',
			'settings.station.models.n3fjpNodeName' => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / —· ···—— ··—· ·——— ·——· —·——·—',
			'settings.station.models.commander' => '·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· ·—·· · —·· / ···— ·· ·— / —·· —··— ·—·· ·— —··· / —·—· ——— —— —— ·— —· —·· · ·—·',
			'settings.station.models.commanderNodeName' => '—— —·—— / ·—· ·— —·· ·· ——— / —·——· ···— ·· ·— / —·—· ——— —— —— ·— —· —·· · ·—· —·——·—',
			'settings.station.models.antenna' => '·— —· — · —· —· ·—',
			'settings.station.models.key' => '—·—· ·—— / —·— · —·——',
			'settings.station.models.winkeyer' => '·—— ·· —· —·— · —·—— · ·—·',
			'settings.station.models.placeholderRadio' => '——· · —· · ·—· ·· —·—· / ·—· ·— —·· ·· ——— / —·——· ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· —·——·—',
			'settings.station.models.placeholderRadioNodeName' => '—— —·—— / ·—· ·— —·· ·· ———',
			'settings.station.models.antennaGenius' => '····— ——— ···—— ·— / ·— —· — · —· —· ·— / ——· · —· ·· ··— ···',
			'settings.station.models.sierraCoax' => '··· ·· · ·—· ·—· ·— / ·—· ·— —·· ·· ——— / —·—· —··— —····— ·———— / —·—· ——— ·— —··— / ··· ·—— ·· — —·—· ····',
			'settings.station.models.rtlSdr' => '·—· — ·—·· —····— ··· —·· ·—·',
			'settings.station.models.nesdr' => '—· ——— ——— · ·—·· · —·—· / —· · ··· —·· ·—·',
			'settings.station.models.sdrplay' => '··· —·· ·—· ·——· ·—·· ·— —·—— / ·—· ··· ·——·',
			'settings.station.transports.network' => '—· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··',
			'settings.station.transports.secureNetwork' => '··· · —·—· ··— ·—· · / —· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··',
			'settings.station.transports.usbSerial' => '··— ··· —··· / ··· · ·—· ·· ·— ·—··',
			'settings.station.transports.wifi' => '—· · — ·—— ——— ·—· —·— —··—· ·—— ·· ··—· ··',
			'settings.station.transports.bluetoothSerial' => '—··· ·—·· ··— · — ——— ——— — ···· / ··· · ·—· ·· ·— ·—··',
			'settings.station.transports.bleSerial' => '—··· ·—·· ··— · — ——— ——— — ···· / ·—·· ·',
			'settings.station.transports.placeholder' => '·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—·',
			'settings.station.troubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.ft891Troubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ——— ·—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ——— —· ·—·—·— ** / ·—— ·· — ···· / ** —·—· ·— — / ·—· — ··· ** / ——— —· / —·——· ··—· — —····— ———·· ————· ·———— / —— · —· ··— / ** ————— ····· —····— ————— ———·· ** —·——·— ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — / ·—— ···· ·· ·—·· · / ·—· — ··· / ·· ··· / ·—·· ——— ·—— / — / ·· — / —— ·— —·—— / ·— —· ··· ·—— · ·—· / ——— —· —·—· · / ·— ··· / — ···· · / ·——· ——— ·—· — / ——— ·——· · —· ··· ——··—— / — ···· · —· / —· ——— — ···· ·· —· ——· ·—·—·— / ·——· ·· —·—· —·— ·· —· ——· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — / — ··— ·—· —· ··· / ——— —· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / —·— · —·—— ··· / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ———··· / — ··— ·—· —· / —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· —· ··· — · ·— —·· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —·——· —— · —· ··— / ** ————— ····· —····— ————— —···· ** —·——·— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—',
			'settings.station.yaesuBinaryTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.yaesuBinaryTroubleshooting' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ··· ·——· · ·— —·— ··· / —·—— ·— · ··· ··— ·————· ··· / ——— ·—·· —·· · ·—· / ··—· ·· ···— · —····— —··· —·—— — · / —·—· ·— — ——··—— / ·— —· —·· / ·· — / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· / ·— — / ·— ·—·· ·—·· / ·—— ···· · —· / ··· ——— —— · — ···· ·· —· ——· / ·· ··· / ——— ··—· ··—· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** — ···· · / —·—· ·— —··· ·—·· · / —— ··— ··· — / —·—· ——— —· ···— · ·—· — / ·—·· · ···— · ·—·· ··· ·—·—·— ** / — ···· · / —·—· ·— — / ·——— ·— —·—· —·— / ——— —· / — ···· · / —··· ·— —·—· —·— / ·· ··· / —· ——— — / ·—· ··· —····— ··——— ···—— ··——— / ·— —· —·· / —· ——— — / ··— ··· —··· —·—·—· / ·· — / —· · · —·· ··· / ·— / —·—· — —····— —···· ··——— / ——— ·—· / ·— —· / · ——·— ··— ·· ···— ·— ·—·· · —· — / ·— —·· ·— ·——· — · ·—· ·—·—·— / ·— / ·——· ·—·· ·— ·· —· / ·— ··— —·· ·· ——— / ——— ·—· / —·· ·— — ·— / —·—· ·— —··· ·—·· · / ·—— ——— —· ·————· — / ·—— ——— ·—· —·— / ··—· ——— ·—· / —·—· ·— — ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— / —·——· ** # ·———— ····— ** / ——— —· / ·— —· / ··—· — —····— ———·· ·———— ——··· ——··—— / ** # ·———— ————· ** / ——— —· / ·— —· / ··—· — —····— ———·· ····· ——··· / ——— ·—· / ··—· — —····— ———·· ————· ——··· —·——·— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —· ——— — ···· ·· —· ——· / —··· ·— —·—· —·— ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** —· · ···— · ·—· / ·—·· · — / ·— —· —·—— — ···· ·· —· ——· / ·—· ·— ·· ··· · / ·—· — ··· / ——— ·—· / —·· — ·—· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· — ·—·—·— ** / ——— —· / —— ——— ··· — / —·—· ·— —··· ·—·· · ··· / ··—· ——— ·—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· / — ···· ——— ··· · / ·—·· ·· —· · ··· / ·— ·—· · / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·— / ·— —· / ——— ·—·· —·· · ·—· / ·· —· — · ·—· ··—· ·— —·—· · / ·——· ——— ·—— · ·—· · —·· / ··—· ·—· ——— —— / —·· — ·—· / ·· ··· / — ···· · / · —··— —·—· · ·——· — ·· ——— —· ———··· / — ··— ·—· —· / ——— —· / ** ···· ——— ·—·· —·· / —·· — ·—· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / — ···· ·— — / ——— —· · ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —·—— ·— · ··· ··— ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / —·—· ···· ·— ·—· — / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.tenTecTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.tenTecEagleTroubleshooting' => '—····— / ** — ···· · / ··— ··· —··· —····— —··· / ·——· ——— ·—· — / ——— —· / — ···· · / —··· ·— —·—· —·— / ·· ··· / — ···· · / —·—· ·— — / ·—·· ·· —· —·— ·—·—·— ** / — ···· · / ·—· ·— —·· ·· ——— / ··· ···· ——— ·—— ··· / ··— ·——· / ·— ··· / ·— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — —·—·—· / ——— —· / ·—— ·· —· —·· ——— ·—— ··· / ·· — / —· · · —·· ··· / — · —· —····— — · —·—· ·————· ··· / ··— ··· —··· / — ——— / ··— ·— ·—· — / —·· ·—· ·· ···— · ·—· ——··—— / ·—— ···· ·· —·—· ···· / ·— ·——· ·——· · ·— ·—· ··· / ·· —· / —·· · ···— ·· —·—· · / —— ·— —· ·— ——· · ·—· / ·— ··· / ·—··—· ··— ··· —··· / — ——— / ··— ·— ·—· — / —·——· —·—· ——— —— —··— —·——·— ·—··—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ——··—— / ·— —· —·· / ··· ——— / —·· ——— · ··· / — · —· —····— — · —·—· ·————· ··· / ··—· ·· ·—· —— ·—— ·— ·—· · / ··— ·——· —·· ·— — · ·—· ·—·—·—\n—····— / ** ··· · — — ·· —· ——· / — ···· · / ··—· ·· ·—·· — · ·—· / ·—— ·· —·· — ···· / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· / — ·— —·— · ··· / ·· — / ·— ·—— ·— —·—— / ··—· ·—· ——— —— / — ···· · / —··· ·—— / —·— —· ——— —··· ** / ··— —· — ·· ·—·· / — ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— ··—· ··—· / ·— —· —·· / ——— —· / ·— ——· ·— ·· —· ·—·—·— / — ···· ·— — / ·· ··· / ···· ——— ·—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ——— ·—· —·— ··· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — · —· —····— — · —·—· ·————· ··· / ·——· ·—· ——— ——· ·—· ·— —— —— · ·—· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · / ——· ··— ·· —·· · ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ——··—— / ·—— ·· — ···· / — ···· · / ··—· ·· ·—· —— ·—— ·— ·—· · / ···— · ·—· ··· ·· ——— —· / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—',
			'settings.station.tenTecOrionTroubleshooting' => '—····— / ** ··— ··· · / ·— / ··· — ·—· ·— ·· ——· ···· — —····— — ···· ·—· ——— ··— ——· ···· / —·· —··· —····— ————· / ··· · ·—· ·· ·— ·—·· / —·—· ·— —··· ·—·· · ** / — ——— / — ···· · / ··· · ·—· ·· ·— ·—·· / —·· ·— — ·— / ·——· ——— ·—· — ——··—— / —· ——— — / ·— / —· ··— ·—·· ·—·· —····— —— ——— —·· · —— / ——— —· · ·—·—·—\n—····— / ** — ···· ·· ··· / · —· — ·—· —·—— / ···· ——— ·—·· —·· ··· / ·—· — ··· / ···· ·· ——· ···· ** ——··—— / —··· · —·—· ·— ··— ··· · / — ···· · / ——— ·—· ·· ——— —· / ··— ··· · ··· / ·—· — ··· / ·— —· —·· / —·—· — ··· / ·— ··· / ·· — ··· / ···· ·— —· —·· ··· ···· ·— —·— · ·—·—·— / ——— —· / ·— —· / ·· —· — · ·—· ··—· ·— —·—· · / — ···· ·— — / —·— · —·—— ··· / ·——· — — / ··—· ·—· ——— —— / ·—· — ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / — ··— ·—· —· / ——— ··—· ··—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ——··—— / ——— ·—· / — ···· · / ·—· ·— —·· ·· ——— / — ·—· ·— —· ··· —— ·· — ··· / ·— ··· / ··· ——— ——— —· / ·— ··· / — ···· · / ·— ·——· ·——· / —·—· ——— —· —· · —·—· — ··· ·—·—·—\n—····— / ** —·—· ·—— / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· / —· · · —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· —· — · ·—· —· ·— ·—·· / —·— · —·—— · ·—· / ——— —· ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— ··—· ··—· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·· ——· —· ——— ·—· · ··· / ·—— ···· ·— — / — ···· · / ·— ·——· ·——· / ··· · —· —·· ··· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — · —· —····— — · —·—· ·————· ··· / ·——· ·—· ——— ——· ·—· ·— —— —— · ·—· ·————· ··· / ·—· · ··—· · ·—· · —· —·—· · / ——· ··— ·· —·· · / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ·— —· / ——— ·—· ·· ——— —· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ——··—— / ·—— ·· — ···· / — ···· · / ··—· ·· ·—· —— ·—— ·— ·—· · / ···— · ·—· ··· ·· ——— —· / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—',
			'settings.station.tenTecNoCw' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— ·————· ··· / ··—· ·· ·—· —— ·—— ·— ·—· · / —·· ——— · ··· / —· ——— — / — ·— —·— · / —·—· ·—— / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — · —· —····— — · —·—· / ·— —·· —·· · —·· / ·· — / ·· —· / ——— ·—· ·· ——— —· / ··—· ·· ·—· —— ·—— ·— ·—· · / ·———— ·—·—·— ···—— —···· —···· ·—·—·—',
			'settings.station.tenTecKeyerOff' => '— ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·· —· — · ·—· —· ·— ·—·· / —·— · —·—— · ·—· / ·· ··· / ——— ··—· ··—· ——··—— / ··· ——— / ·· — / ·· ——· —· ——— ·—· · ··· / —·—· ·—— / ··· · —· — / ··—· ·—· ——— —— / — ···· · / ·— ·——· ·——· ·—·—·— / — ··— ·—· —· / — ···· · / —·— · —·—— · ·—· / ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·—',
			'settings.station.guohetecTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.guohetecTroubleshooting' => '— ···· · / ——·— ————· ————— ————— / ···· ·— ··· / — ·—— ——— / —·—· ·— — / ·——· ·—· ——— — ——— —·—· ——— ·—·· ··· ——··—— / ·— —· —·· / — ···· ·· ··· / · —· — ·—· —·—— / ··— ··· · ··· / ·· — ··· / —· ·— — ·· ···— · / ——— —· · / ·—· ·— — ···· · ·—· / — ···· ·— —· / — ···· · / ··—· — —····— ———·· ·———— ——··· / ·· —— ·· — ·— — ·· ——— —· ·—·—·— / ·——· ·· —·—· —·— / ** ——· ··— ——— ···· · — · —·—· / ——·— ————· ————— ————— ** / ···· · ·—· · ——··—— / —· ——— — / ·— —· / ··—· — —····— ———·· ·———— ——··· / — / — ···· · / ·· —— ·· — ·— — ·· ——— —· / ··· ··— ·——· ·——· ——— ·—· — ··· / ··—· · ·—— · ·—· / —·—· ——— —— —— ·— —· —·· ··· ——··—— / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / ——— —· · / ·· — / ·· ··· / ··— ··· ·· —· ——· ·—·—·—\n\n—····— / ** — ···· · / ··— ··· —··· —····— —·—· / —·—· ·— —··· ·—·· · / ·· ··· / — ···· · / —·—· ·— — / ·—·· ·· —· —·— ** ——··—— / ·— —· —·· / ·· — / —·—· ——— —· —· · —·—· — ··· / — ···· · / ··· ——— ··— —· —·· / —·—· ·— ·—· —·· / — ——— ——— ·—·—·— / ··· ·——· · · —·· / —·· ——— · ··· / —· ——— — / —— ·— — — · ·—· / ——— —· / ·· — —·—·—· / — ···· · / ·——· ——— ·—· — / ·· ——· —· ——— ·—· · ··· / ·—— ···· ·— — · ···— · ·—· / ·· — / ·· ··· / ··· · — / — ——— ·—·—·—\n—····— / ** —· · ···— · ·—· / ·—·· · — / ·— —· —·—— — ···· ·· —· ——· / ·—· ·— ·· ··· · / ·—· — ··· / ——— ·—· / —·· — ·—· / ——— —· / — ···· ·· ··· / ·——· ——— ·—· — ·—·—·— ** / ——— —· / ·— / ··· · ·—· ·· ·— ·—·· / —·—· ·— —··· ·—·· · / — ···· ——— ··· · / ·—·· ·· —· · ··· / ·— ·—· · / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** ·— / ··· · —·—· ——— —· —·· —····— ——· · —· · ·—· ·— — ·· ——— —· / ·—· ·— —·· ·· ——— / —··· · ···· ·— ···— · ··· / —·· ·· ··—· ··—· · ·—· · —· — ·—·· —·—— ** / ··—· ·—· ——— —— / ·— / ··—· ·· ·—· ··· — ·—·—·— / ·—·· ——— —· ——· / ·——· ·—· · ··· ··· / —— · —· ··— ——··—— / — ···· · —· / ·— —··· ——— ··— — ———··· / ···· ·—— / ··——— ·—·—·— ————— / ·· ··· / — ···· · / ··· · —·—· ——— —· —·· / ——· · —· · ·—· ·— — ·· ——— —· ·—·—·—\n\n— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / — ···· · / —— ·— —· ··— ··—· ·— —·—· — ··— ·—· · ·—· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.yaesuTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.yaesuTroubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** —·—· ·— — / ·—· — ··· / —— ··— ··· — / —··· · / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·— / ···· ·— —· —·· ··· ···· ·— —·— · / ·—·· ·· —· · / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ·—·· ——— ·—— ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / — ···· ·— — / ··· ·— —— · / ·—·· ·· —· · / ·· ··· / ·——· — — ——··—— / ··· ——— / ·—· ·— ·· ··· ·· —· ——· / ·· — / ·—— ——— ··— ·—·· —·· / —·— · —·—— / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ·—·—·— / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — ——··—— / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· / ·· ··· / — ···· · / ·— ·—·· — · ·—· —· ·— — ·· ···— · ·—·—·— / ·—— ···· · ·—· · / — ···· ·— — / ··· · — — ·· —· ——· / ·—·· ·· ···— · ··· / —·· ·· ··—· ··—· · ·—· ··· / —··· —·—— / —— ——— —·· · ·—·· / —·——· —— · —· ··— / ** ————— ····· —····— ————— ———·· ** / ——— —· / ·— —· / ··—· — —····— ———·· ————· ·———— —·——·— ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** —— ——— —·· · ··· / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ··—· — —····— ———·· ————· ·———— ·————· ··· / — ·— —··· ·—·· · ·—·—·— ** / —— ——— ··· — / ——— ··—· / — ···· · / —·—— ·— · ··· ··— / ·—·· ·· —· · / —— ·— — —·—· ···· · ··· / ·· — ——··—— / —··· ··— — / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / —· ··— —— —··· · ·—· ··· / ·· — ··· / —— ——— —·· · ··· / —·· ·· ··—· ··—· · ·—· · —· — ·—·· —·—— / ·—— ·· ·—·· ·—·· / ··· ···· ——— ·—— / ·— —· —·· / ··· · — / — ···· · / ·—— ·—· ——— —· ——· / ——— —· · / ··—· ——— ·—· / — ···· ——— ··· · ·—·—·— / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ··— —· ·— ··—· ··—· · —·—· — · —·· ·—·—·—',
			'settings.station.yaesuRs232Troubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** — ···· · / —·—· ·— — / ·——— ·— —·—· —·— / ·· ··· / ·—· ··· —····— ··——— ···—— ··——— ·—·—·— ** / ·· — / —· · · —·· ··· / ·— / ··— ··· —··· —····— — ——— —····— ··· · ·—· ·· ·— ·—·· / ·— —·· ·— ·——· — · ·—· / ·— —· —·· / ·— / ··· — ·—· ·— ·· ——· ···· — —····— — ···· ·—· ——— ··— ——· ···· / —·· —··· —····— ————· / —·—· ·— —··· ·—·· · / — / ·— / —· ··— ·—·· ·—·· —····— —— ——— —·· · —— / —·—· ·— —··· ·—·· · / ··· ·—— ·— ·——· ··· / — ···· · / ·—·· ·· —· · ··· ——··—— / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ···· · ·— ·—· ··· / ·— / — ···· ·· —· ——· ·—·—·—\n—····— / ** —·—· ·— — / ·—· — ··· / —— ··— ··· — / —··· · / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / ·—— ·· — ···· / ·· — / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ·—— ·— ·· — ··· / ··—· ——— ·—· / ·— / ···· ·— —· —·· ··· ···· ·— —·— · / ·—·· ·· —· · / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ·—·· ——— ·—— / ··— —· ·—·· · ··· ··· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ·· ··· / ——— —· / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / —·· ——— —·—· ··— —— · —· — ·— — ·· ——— —· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ——— —· · / ——— ··—· / — ···· · ··· · / ·—· ·— —·· ·· ——— ··· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.yaesuUsbTroubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ·—· · —·—· · ·· ···— ·· —· ——· / —·—· ——— —— —— ·— —· —·· ··· / —··· ··— — / —· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——· ·—·—·— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··— ··· · / — ···· · / ··—· ·· ·—· ··· — / ——— ··—· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / — ·—— ——— / ··— ··· —··· / ·——· ——— ·—· — ··· ·—·—·— ** / —·—· ·— — / ·· ··· / —· ——— ·—· —— ·— ·—·· ·—·· —·—— / ——— —· / — ···· · / ··—· ·· ·—· ··· — / —·——· — ···· · / ** · —· ···· ·— —· —·—· · —·· ** / —·—· ——— —— / ·——· ——— ·—· — / ——— —· / ·—— ·· —· —·· ——— ·—— ··· —·——·— —·—·—· / — ···· · / ··· · —·—· ——— —· —·· / —·——· ** ··· — ·— —· —·· ·— ·—· —·· ** —·——·— / ·· ··· / ··—· ——— ·—· / ·——· — — / ·— —· —·· / —·— · —·—— ·· —· ——· ·—·—·— / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — / — ···· · / ··—· ·· ·—· ··· — / ·—— ···· · ·—· · ···— · ·—· / ·· — / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·— ·——· ·— ·—· — ·—·—·—\n—····— / ** —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ——— ·—· / ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· / ——— —· ·—·—·— ** / ·—— ·· — ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ** —·—· ·— — / ·—· — ··· ** / —— · —· ··— / ——— —· ——··—— / ·· — / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — / ·—— ···· ·· ·—·· · / ·—· — ··· / ·· ··· / ·—·· ——— ·—— / — / ·· — / —— ·— —·—— / ·— —· ··· ·—— · ·—· / ——— —· —·—· · / ·— ··· / — ···· · / ·——· ——— ·—· — / ——— ·——· · —· ··· ——··—— / — ···· · —· / —· ——— — ···· ·· —· ——· ·—·—·— / ·——· ·· —·—· —·— ·· —· ——· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ——— ·—— —· / ··— ··· —··· / ·——· ——— ·—· — / — ··— ·—· —· ··· / ——— —· / ** ···· ——— ·—·· —·· / ·—· — ··· / ···· ·· ——· ···· ** / ··— —· —·· · ·—· / ·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ··· ·—·—·— / ——— —· / ·— / —·· ·· ——· ·· ·—· ·· ——· ——··—— / ··· ·· ——· —· ·— ·—·· ·· —· —·— / ——— ·—· / —— ——— ··· — / ···· ——— —— · —····— —··· ·—· · ·—— / —·—· ·— —··· ·—·· · ··· / ·—· — ··· / ·· ··· / ·——· — — ——··—— / ·— —· —·· / ···· ——— ·—·· —·· ·· —· ——· / ·· — / ···· ·· ——· ···· / —·— · —·—— ··· / —·—— ——— ··— ·—· / — ·—· ·— —· ··· —— ·· — — · ·—· ———··· / — ··— ·—· —· / —·—· ·— — / ·—· — ··· / ——— ··—· ··—· / ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· —· ··· — · ·— —·· ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ·—· ·— — · / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—',
			'settings.station.k4SerialNotes' => '—·—· ——— —· —· · —·—· — / — ···· · / —·— ····— ’ ··· / ·—· · ·— ·—· / ··— ··· —··· —····— —··· / —·——· ·——· —·—· —·——·— / ··· ——— —·—· —·— · — ·—·—·— / · ·· — ···· · ·—· / ··— ··· —··· —····— ·——· —·—· ·———— / ——— ·—· / ··— ··· —··· —····— ·——· —·—· ··——— / ·—— ——— ·—· —·— ··· / ··—· ——— ·—· / —·—· ·— — —·—·—· / —·—· ···· ——— ——— ··· · / ·— —· / ··— —· ··— ··· · —·· / ·——· ——— ·—· — / ·— —· —·· / —— ·— — —·—· ···· / ·· — ··· / ··· · ·—· ·· ·— ·—·· / ··— ··· —··· —····— ·——· —·—· —· ———··· / —··· ·— ··— —·· / ·—· ·— — · / ··· · — — ·· —· ——· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / ···· ·— ·—·· ——— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / ···—— ———·· ····— ————— ————— —·—·—· / —·—· ···· ·— —· ——· · / ·· — / ·· ··—· / —· · · —·· · —·· ·—·—·— / ·— —· ——— — ···· · ·—· / ·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / —— ··— ··· — / ··— ··· · / — ···· · / ——— — ···· · ·—· / ·——· ——— ·—· — / ——— ·—· / · — ···· · ·—· —· · — ·—·—·—\n\n— ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ——— —· — ·—· ——— ·—·· ··· / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ·· — ··· / —·— · —·—— · ·—· ··· —·—·—· / ·· — / —·· ——— · ··· / —· ——— — / ··· · —· —·· / ·— ··— —·· ·· ——— / — ——— / ···· ·— ·—·· ——— ·—·—·—',
			'settings.station.k4TcpNotes' => '—·—· ——— —· —· · —·—· — / — ···· · / —·— ····— ’ ··· / · — ···· · ·—· —· · — / ··· ——— —·—· —·— · — / — ——— / —·—— ——— ··— ·—· / ·—·· ——— —·—· ·— ·—·· / —· · — ·—— ——— ·—· —·— ·—·—·— / · —· — · ·—· / ·· — ··· / ···· ——— ··· — —· ·— —— · / ——— ·—· / ·· ·——· / ·— —·· —·· ·—· · ··· ··· / ·— —· —·· / —·—· ·— — / ·——· ——— ·—· — / ————· ··——— ————— ————— ·—·—·— / ···· ·— ·—·· ——— / ··— ··· · ··· / — ···· · / ··· ·— —— · / ···· ——— ··· — / ——— —· / ··—· ·· —··— · —·· / ·——· ——— ·—· — / ————· ··——— ————— ·———— / ·—— ···· · —· / ·— / ·——· ·— —· ·— —·· ·— ·——· — · ·—· / ——— ·—· / ·—— ·— — · ·—· ··—· ·— ·—·· ·—·· / ·· ··· / ···— ·· ··· ·· —··· ·—·· · —·—·—· / —·—· ···· ·— —· ——· ·· —· ——· / — ···· · / —·—· ·— — / ·——· ——— ·—· — / —·· ——— · ··· / —· ——— — / —·—· ···· ·— —· ——· · / — ···· · / ··· ·——· · —·—· — ·—· ··— —— / ·——· ——— ·—· — ·—·—·—\n\n— ···· · / ··· ·——· · —·—· — ·—· ··— —— / ··· ···· ——— ·—— ··· / — ···· · / —— ·— ·· —· / ·—· · —·—· · ·· ···— · ·—· ·—·—·— / ·· — ··· / ——·· ——— ——— —— ——··—— / ·—· · ··—· · ·—· · —· —·—· · / ·— —·· ·——— ··— ··· — —— · —· — / ·— —· —·· / ··· ·——· · · —·· / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— ··—· ··—· · —·—· — / ——— —· ·—·· —·—— / ···· ·— ·—·· ——— ’ ··· / —·· ·· ··· ·——· ·—·· ·— —·—— ·—·—·— / ·— ··— —·· ·· ——— / ··· — ·—· · ·— —— ·· —· ——· / ·· ··· / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· ·—·—·—',
			'settings.station.k4PowerTimeout' => '—·— ····— / ·——· ——— ·—— · ·—· / ·—— ·— ··· / —· ——— — / —·—· ···· ·— —· ——· · —·· / —··· · —·—· ·— ··— ··· · / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· —·· / —· ——— — / —·—· ——— —· ··—· ·· ·—· —— / ·· — ··· / ——— ··— — ·——· ··— — / ·—· ·— —· ——· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'settings.station.k4RemoteNotes' => '· —· ·— —··· ·—·· · / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ——— —· / —·—— ——— ··— ·—· / —·— ····— / ·— —· —·· / · —· — · ·—· / ·· — ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· ·—·—·— / —— ·— ·· —· / ·— —· —·· / ··· ··— —··· / ··· ···· ·— ·—· · / ——— —· · / · —· —·—· ·—· —·—— ·——· — · —·· / —·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ——— ·—· / ·—· ·— —·· ·· ——— / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / ··· ·——· · —·—· — ·—· ··— —— ·—·—·— / — ···· · / —·· · ··—· ·— ··— ·—·· — / ·——· ——— ·—· — / ·· ··· / ————· ··——— ————— ····— —·—·—· / · —· — · ·—· / —·—— ——— ··— ·—· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / ·——· ——— ·—· — / ·—— ···· · —· / —·—· ——— —· —· · —·—· — ·· —· ——· / ·—· · —— ——— — · ·—·· —·—— ·—·—·—\n\n·— ··— —·· ·· ——— / ·——· ·—·· ·— —·—— —··· ·— —·—· —·— / ·— —· —·· / —— ·· —·—· ·—· ——— ·——· ···· ——— —· · / ··· — ·—· · ·— —— ·· —· ——· / ·— ·—· · / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· ·—·—·—',
			'settings.station.k4Receiver' => '·—· · —·—· · ·· ···— · ·—·',
			'settings.station.k4ReceiverMain' => '—— ·— ·· —·',
			'settings.station.k4ReceiverSub' => '··· ··— —···',
			'settings.station.k4ReceiverInvalid' => '—·—· ···· ——— ——— ··· · / —— ·— ·· —· / ——— ·—· / ··· ··— —···',
			'settings.station.k4ReceiverAlreadyConfigured' => '— ···· ·— — / ·—· · —·—· · ·· ···— · ·—· / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ··—· ——— ·—· / — ···· ·· ··· / —·— ····—',
			'settings.station.k4SubReceiverOff' => '— ···· · / —·— ····— / ··· ··— —··· / ·—· · —·—· · ·· ···— · ·—· / ·· ··· / ——— ··—· ··—·',
			'settings.station.k4RemotePasswordRequired' => '· —· — · ·—· / — ···· · / —·— ····— ’ ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· / — ——— / —·—· ——— —· —· · —·—· — / ··· · —·—· ··— ·—· · ·—·· —·—— ·—·—·—',
			'settings.station.k4RemoteHandshakeFailed' => '— ···· · / —·— ····— / —·—· ——— ··— ·—·· —·· / —· ——— — / · ··· — ·— —··· ·—·· ·· ··· ···· / ·— / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / —· · — ·—— ——— ·—· —·— / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·— —· —·· / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ··· · — — ·· —· ——· ··· ·—·—·—',
			'settings.station.k4RemoteUnreachable' => '— ···· · / —·— ····— ’ ··· / ··· · —·—· ··— ·—· · / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·— / —·—· ···· · —·—· —·— / ·· — ··· / ·— —·· —·· ·—· · ··· ··· ——··—— / ·——· ——— ·—· — / ·— —· —·· / ·—· · —— ——— — · / ·— —·—· —·—· · ··· ··· / ··· · — — ·· —· ——· ··· ·—·—·—',
			'settings.station.k4PowerRange' => '—·— ····— / ·——· ——— ·—— · ·—· / —— ··— ··· — / —··· · / ————— ·—·—·— ·———— – ·———— ·———— ————— / ·—— ——··—— / ——— ·—· / ————— ·—·—·— ————— ————— ————— ·———— – ————— ·—·—·— ————— ·———— / ·—— / ·—— ···· · —· / — ···· · / — ·—· ·— —· ··· ···— · ·—· — · ·—· / —— ·· ·—·· ·—·· ·· ·—— ·— — — / ——— ··— — ·——· ··— — / ·· ··· / ·— —·—· — ·· ···— · ·—·—·—',
			'settings.station.elecraftTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.elecraftTroubleshooting' => '· ·—·· · —·—· ·—· ·— ··—· — / ·—· ·· ——· ··· / ··· ·——· · ·— —·— / —·— · —· ·—— ——— ——— —·· / —·—· ·— — ——··—— / ·— —· —·· / ·— / —·— —··— ··——— / ·— —· —·· / ·— / —·— —··— ···—— / ···· ·— ···— · / —··· ——— — ···· / —··· · · —· / ·—· ··— —· / — ···· ·· ··· / ·—— ·— —·—— / — / ···— ··—· ——— / ·· —· / —··· ——— — ···· / —·· ·· ·—· · —·—· — ·· ——— —· ··· ——··—— / —— ——— —·· · / ··· ·—— ·· — —·—· ···· ·· —· ——· / ·— —· —·· / —·—· ·—— / ——·· · ·—· ——— —····— —··· · ·— — / ·— ·—·· ·—·· / ·—— ——— ·—· —·— ·· —· ——· ·—·—·—\n\n·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ——··—— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— — · / ··· · — / ··— —· —·· · ·—· / ** ·—· ··· ··——— ···—— ··——— ** / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / ···—— ———·· ····— ————— ————— / ·· ··· / ·—— ···· ·— — / — ···· · ··· · / ··· ···· ·· ·——· / ——— —· ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n\n** ·· ··—· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ·· ——· ···· — / —··· ··— — / — ···· · / —— ——— —·· · / ·· ··· / ·—— ·—· ——— —· ——· ** ——··—— / — · ·—·· ·—·· / ··— ··· ·—·—·— / — ···· · / —·— —··— ··——— / ·— —· —·· / —·— —··— ···—— / · —· — ·—· ·· · ··· / ·—· · ·— —·· / — ···· · / —— ——— —·· · / ··—· ·—· ——— —— / ·— / ·——· ——— ··· ·· — ·· ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ··· — ·— — ··— ··· / ·—· · ·——· ·—·· —·—— / — ···· ·— — / ·—— · / ···· ·— ···— · / ·——· ·· —· —· · —·· / ··—· ·—· ——— —— / — ···· · / ·—· ·· ——· ··· / ·—— · / ···· ·— ···— · / ··· · · —· ——··—— / ·— —· —·· / ·— / ··—· ·· ·—· —— ·—— ·— ·—· · / — ···· ·— — / ·——· ··— — ··· / ·· — / · ·—·· ··· · ·—— ···· · ·—· · / ·· ··· / ··· ——— —— · — ···· ·· —· ——· / ——— —· ·—·· —·—— / ·— / ·—· · ·——· ——— ·—· — / ·—· · ·— —·—· ···· · ··· / ··— ··· / ·— ··· ·—·—·—\n\n— ···· · / —·— ···—— / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· · ·——· ——— ·—· — · —·· / · ·· — ···· · ·—· / ·—— ·— —·—— ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ··· ·— —·—— / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / ·· ··—· / —·—— ——— ··— / ·—· ··— —· / ——— —· · ·—·—·— / ·— / —·— ····— / ···· ·— ··· / ·· — ··· / ——— ·—— —· / · —· — ·—· —·—— ·—·—·—',
			'settings.station.lab599TroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.lab599Troubleshooting' => '— ···· · / — —··— —····— ····· ————— ————— / ·—·· ·· —· · / ··· ·——· · ·— —·— ··· / —·— · —· ·—— ——— ——— —·· / —·—· ·— — ·—·—·— / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·—· · ··—· · ·—· · —· —·—· · ··· / ·—· ·— — ···· · ·—· / — ···· ·— —· / — · ··· — · —·· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / · ·· — ···· · ·—· / ·—— ·— —·—— ·—·—·—\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / ··· · — — ·· —· ——· ——··—— / ————· —···· ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·——· ·· —·—· —·— / — ···· · / —·—· ·— — / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— ** / — ··· —····— ··——— ————— ————— ————— / —·—· ——— ···— · ·—· ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· · ·—·—·— / ·—·· ·— —··· ····· ————· ————· / ·— ·—·· ··· ——— / ·—·· · — ··· / — ···· · / ·— ·——· ·——· / ··· ·—— ·· — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— / — ——— / —·· ·· ——· ·—·—·—\n—····— / ** — ···· ·—· ——— ··— ——· ···· / ·— / ·—·· ·· —· —·— ····· ————— ————— —— ·——· ** ——··—— / ·——· ·—· · ··· ··· / ·— —· —·· / ···· ——— ·—·· —·· / — ···· · / ···— ··—· ——— / —·— —· ——— —··· / ··—· ——— ·—· / ·— —··· ——— ··— — / — ···· ·—· · · / ··· · —·—· ——— —· —·· ··· / — ——— / ···· ·— —· —·· / —·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / — ——— / — ···· · / ·· —· — · ·—· ··—· ·— —·—· · ·—·—·—\n—····— / ** ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ——— —· / ·— / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / — ···· · / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / ·——· ·— ·· ·—· ··· / ·— ··· / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·— —· —·· / ——— —· ·—·· —·—— / ——— —· · / —·—· ·— ·—· ·—· ·· · ··· / —·—· ·— — ·—·—·— / ·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / ··· — ·— —·—— ··· / ··· ·· ·—·· · —· — ——··—— / ·——· ·· —·—· —·— / — ···· · / ——— — ···· · ·—· ·—·—·—\n—····— / ** ——— ···— · ·—· / —··· ·—·· ··— · — ——— ——— — ···· / ·—·· · ** ——··—— / ·— ··· / ——— —· / ·— —· / ·· ·——· ···· ——— —· · / ——— ·—· / ·· ·——· ·— —·· ——··—— / ··· ·—— ·· — —·—· ···· / — ···· · / ·—·· ·· —· —·— ····· ————— ————— —— ·——· / — ——— / ·· — ··· / ·· ——— ··· / —— ——— —·· · / ··—· ·· ·—· ··· — ·—·—·— / ·· —· / ·· — ··· / ——— — ···· · ·—· / —— ——— —·· · ··· / ·· — / —·· ——— · ··· / —· ——— — / ··· ···· ——— ·—— / ··— ·——· / ·· —· / ·— / ··· —·—· ·— —· ·—·—·—',
			'settings.station.kenwoodTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / ··· ···· ——— ·—— ··· / —· ——— / ··—· ·—· · ——·— ··— · —· —·—· —·——',
			'settings.station.kenwoodTroubleshooting' => '— ···· ·· ··· / —·· ·—· ·· ···— · ·—· / ·· ··· / ·——· ·—· ——— ···— · —· / ·— ——· ·— ·· —· ··· — / —·— · —· ·—— ——— ——— —·· ·————· ··· / — ··· —····— ····· ————· ————— ··· ——· / ·— —· —·· / — ··· —····— ····— ———·· ————— ——··—— / ——·— ·—· ·——· / ·—·· ·— —··· ··· ·————· / ——·— —— —··— / ·— —· —·· / ——·— —·—· —··— —····— —— ·· —· ·· ——··—— / ·— —· —·· / · ·—·· · —·—· ·—· ·— ··—· — ·————· ··· / —·— —··— ··——— / ·— —· —·· / —·— —··— ···—— ·—·—·— / — ···· · / ·—· · ··· — / ——— ··—· / — ···· · / ·—·· ·· —· · / ·· ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·—· ·— — / ·—· · ··—· · ·—· · —· —·—· · ··· ——··—— / ··· ——— / ·——· ·—·· · ·— ··· · / ·—· · ·——· ——— ·—· — / ·—— ···· ·— — / ···· ·— ·——· ·——· · —· ··· / · ·· — ···· · ·—· / ·—— ·— —·—— ·—·—·—\n\n·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —·· ——— · ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· ——··—— / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ——— —· · / ——— ··—· ———···\n\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·— — / —— · —· ··— ·—·—·— / ·—— ·· — ···· / ·— / —— ·· ··· —— ·— — —·—· ···· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / ··· · —· —·· ··· / —··· ·— —·—· —·— / ——· ·— ·—· —··· ·— ——· · / ——— ·—· / —· ——— — ···· ·· —· ——· ——··—— / ·— —· —·· / —· · ···— · ·—· / ·— —· / · ·—· ·—· ——— ·—· ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—\n—····— / ** ··· ——— —— · / ·—· ·· ——· ··· / —· · · —·· / —·—· ·— — / · —· ·— —··· ·—·· · —·· ** / ·· —· / — ···· · / —— · —· ··— / —··· · ··—· ——— ·—· · / — ···· · —·—— / ·—· · ··· ·——· ——— —· —·· / ·— — / ·— ·—·· ·—·· ·—·—·—\n\n** ··· · ···— · ·—· ·— ·—·· / ··· —·· ·—· / ··—· ·—· ——— —· — —····— · —· —·· ··· / ··· ·——· · ·— —·— / — ···· ·· ··· / ··· ·— —— · / ·——· ·—· ——— — ——— —·—· ——— ·—·· ** ——··—— / ··· ——— / — ···· ·· ··· / · —· — ·—· —·—— / ·· ··· / ·—— ——— ·—· — ···· / — ·—· —·—— ·· —· ——· / ··—· ——— ·—· / — ···· ——— ··· · / — ——— ——— —·—·—· / · ·—·· · —·—· ·—· ·— ··—· — / ·—· ·· ——· ··· / ·— ·—· · / ·—·· ·· ··· — · —·· / ··· · ·——· ·— ·—· ·— — · ·—·· —·—— ——··—— / ··— —· —·· · ·—· / · ·—·· · —·—· ·—· ·— ··—· — ·—·—·— / ·· ··—· / — ···· · / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· ··· / ·—· ·· ——· ···· — / —··· ··— — / — ···· · / —— ——— —·· · / ·· ··· / ·—— ·—· ——— —· ——· / ——— ·—· / —— ·· ··· ··· ·· —· ——· ——··—— / — ···· ·— — / ·· ··· / — ···· · / ——— —· · / ·——· ·— ·—· — / — ···· ·— — / —·· ·· ··—· ··—· · ·—· ··· / ·— —·—· ·—· ——— ··· ··· / — ···· · / ·—·· ·· —· · / — / — ···· · / ·— ·——· ·——· / ·—— ——— ·—· —·— ··· / ·· — / ——— ··— — / ··—· ·—· ——— —— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··—· ·— ·—·· ·—·· ··· / —··· ·— —·—· —·— / — ——— / ·— ··· —·— ·· —· ——· / —·· ·· ·—· · —·—· — ·—·· —·—— ——··—— / ··· ——— / — ···· · / —— ——— —·· · / —— ·— —·—— / ··· ·· —— ·——· ·—·· —·—— / ·—·· ·— ——· ·—·—·—',
			'settings.station.statusConnected' => '—·—· ——— —· —· · —·—· — · —··',
			'settings.station.statusLost' => '—·· ·· ··· —·—· ——— —· —· · —·—· — · —··',
			'settings.station.notConfigured' => '—· ——— — / —·—· ——— —· ··—· ·· ——· ··— ·—· · —··',
			'settings.station.currentConfiguration' => '—·—· ··— ·—· ·—· · —· — / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'settings.station.currentTransceiver' => '—·—· ··— ·—· ·—· · —· — / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·',
			'settings.station.radioMode' => '·—· ·— —·· ·· ——— / —— ——— —·· ·',
			'settings.station.keyerNotSupported' => '—· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· / —··· —·—— / —·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ———',
			'settings.station.catControlPreferences' => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···',
			'settings.station.chooseTransceiver' => '—·—· ···· ——— ——— ··· · / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·',
			'settings.station.configurationSection' => '—·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'settings.station.noTransceiverSelected' => '—· ——— / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· / ··· · ·—·· · —·—· — · —··',
			'settings.station.makeMainVfo' => ({required Object name}) => '··— ··· · / ${name} / ··—· ——— ·—· / — ···· · / —— ·— ·· —· / ···— ··—· ———',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, zero: '—· ——— / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· ···', one: '${count} / — ·—· ·— —· ··· —·—· · ·· ···— · ·—·', other: '${count} / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· ···', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ·— —· — · —· —· ·—', other: '${count} / ·— —· — · —· —· ·— ···', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——— — ···· · ·—· / —·· · ···— ·· —·—· ·', other: '${count} / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ···', ), 
			'settings.station.equipmentInventory' => '· ——·— ··— ·· ·——· —— · —· — / ·· —· ···— · —· — ——— ·—· —·——',
			'settings.station.equipmentInUse' => '— ·—· ·— —· ··· —·—· · ·· ···— · ·—· / —·—· ——— —· — ·—· ——— ·—·· ···',
			'settings.station.noTransceiver' => '—· ——— —· ·',
			'settings.station.peerRadioNotAvailable' => '—· ——— — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => '——— —· / ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} / ·· ··· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => '— ···· ·· ··· / ·—· ·— —·· ·· ——— / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ——— / ${device} ·—·—·— / ·· — ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— —· —·· / ··· · — — ·· —· ——· ··· / ·— ·—· · / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ——— —· / — ···· ·— — / —·· · ···— ·· —·—· · ·—·—·—',
			'settings.station.antennaInUse' => '·— —· — · —· —· ·— / ·· —· / ··— ··· ·',
			'settings.station.keyInUse' => '—·— · —·—— / ·· —· / ··— ··· ·',
			'settings.station.noneSelected' => '—· ——— —· ·',
			'settings.station.moreSettings' => '—— ——— ·—· · / ··· · — — ·· —· ——· ···',
			'settings.station.icomCivTroubleshootingTitle' => '·· ··—· / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ··· ···· ——— ·—— / ··— ·——· / ··—· ——— ·—· / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ———',
			'settings.station.icomCivTroubleshooting' => '··· · ···— · ·—· ·— ·—·· / ·· —·—· ——— —— / ·—· ·— —·· ·· ——— ··· ——··—— / — ···· · / ·· —·—· —····— ——··· ————— ····· / ·— —— ——— —· ——· / — ···· · —— ——··—— / ·——· ·—· · ··· · —· — / ** — ·—— ——— ** / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·— — / ——— —· —·—· · / —·——· ·· —·—· ——— —— / —·—· ·— ·—·· ·—·· ··· / — ···· · —— / ·——· ——— ·—· — / ·— / ·— —· —·· / ·——· ——— ·—· — / —··· —·——·— ——··—— / —··· ——— — ···· / ··· · — / — ——— / —·—· ·· —····— ···— / —··· —·—— / —·· · ··—· ·— ··— ·—·· — ·—·—·— / —· · ·· — ···· · ·—· / — ···· ·· ··· / ·— ·——· ·——· / —· ——— ·—· / —·—— ——— ··— ·—· / ——— ··· / —·—· ·— —· / — · ·—·· ·—·· / — ···· · —— / ·— ·——· ·— ·—· — / —··· · —·—— ——— —· —·· / — ···· ·— — ———··· / — ···· · / ··· ·— —— · / ··— ··· —··· / ···— · —· —·· ——— ·—· —··—· ·——· ·—· ——— —·· ··— —·—· — / ·· —·· / ·——— ··— ··· — / ··· ···· ——— ·—— ··· / ··— ·——· / — ·—— ·· —·—· · ——··—— / ··· ——— —— · — ·· —— · ··· / —— ·— ·—· —·— · —·· / ·—— ·· — ···· / ·— / `#2` / ··· ··— ··—· ··—· ·· —··— / ···· · ·—· · ·—·—·— / ** ·——· ——— ·—· — / ·— / ·· ··· / ··— ··· ··— ·— ·—·· ·—·· —·—— / — ···· · / ·—· ·· ——· ···· — / ——— —· · ** / — / —· ——— ·—· —— ·— ·—·· ·—·· —·—— / — ···· · / ··—· ·· ·—· ··· — / ——— —· · / —·—— ——— ··— ·—· / ——— ··· / ——— ·—· / —··· ·—· ——— ·—— ··· · ·—· / ·—·· ·· ··· — ··· ——··—— / ·— —· —·· / ·—— ···· · ·—· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·——· ——— ·—· — ··· / ·— ·——· ·— ·—· — / ·· — / —— ·— ·—· —·— ··· / — ···· ·— — / ——— —· · / ·— ··· / ··· ··— ——· ——· · ··· — · —·· ·—·—·— / ·· ··—· / —·—· ——— —— —— ·— —· —·· ··· / ——· ——— / ——— ··— — / ·— —· —·· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ··· ——··—— / — ·—· —·—— / — ···· · / ——— — ···· · ·—· / ·——· ——— ·—· — / —· · —··— — ·—·—·—',
			'settings.station.civAddressTroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ···',
			'settings.station.civAddressTroubleshooting' => '—····— / ** — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ——··—— / —··· ··— — / ·— / ·—· ·· ——· / ··· ···· ·— ·—· ·· —· ——· / ·— / —·—· ·· —····— ···— / —··· ··— ··· / ·· ··· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / — ···· ·— — / ——· · — ··· / —·—· ···· ·— —· ——· · —·· ·—·—·— / ·— / ··—· ·—· ·— —— · / ··· · —· — / — ——— / — ···· · / ·—— ·—· ——— —· ——· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·· ——· —· ——— ·—· · —·· / ·· —· / ··· ·· ·—·· · —· —·—· · ——··—— / ·—— ···· ·· —·—· ···· / ·—·· ——— ——— —·— ··· / · —··— ·— —·—· — ·—·· —·—— / ·—·· ·· —·— · / ·— / —·· · ·— —·· / —·—· ·— —··· ·—·· · ·—·—·—\n—····— / ** ··· ·——· · · —·· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / —··· ·— ··— —·· / ·—· ·— — · / —·——· ——— —· / ··— ··· —··· ——··—— / —·—· ·· —····— ···— / ··— ··· —··· / —··· ·— ··— —·· / ·—· ·— — · —·——·— ·—·—·— / ··· · — / — ···· · / ·—· ·— —·· ·· ——— / — ——— / — ···· · / ··· ·— —— · / —· ··— —— —··· · ·—· / ··· ···· ——— ·—— —· / ···· · ·—· · ——··—— / ** —· ——— — / ·— ··— — ——— ** ·—·—·— / ——— —· / ·— ··— — ——— / ··· ——— —— · / ·—· ·— —·· ·· ——— ··· ——··—— / — ···· · / ·· —·—· —····— ——··· ···—— ————— ————— / ·— —— ——— —· ——· / — ···· · —— ——··—— / —·—· ——— —· —· · —·—· — / ·— —· —·· / — ···· · —· / ··· — ——— ·——· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·— ··—· — · ·—· / ·— / —— ·· —· ··— — · / ——— ·—· / ··· ——— ·—·—·—\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '—····— / ** — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ——··—— / —··· ··— — / ·— / ·—· ·· ——· / ··· ···· ·— ·—· ·· —· ——· / ·— / —·—· ·· —····— ···— / —··· ··— ··· / ·· ··· / · —··— ·— —·—· — ·—·· —·—— / ·—— ···· · ·—· · / — ···· ·— — / ——· · — ··· / —·—· ···· ·— —· ——· · —·· ·—·—·— / ·— / ··—· ·—· ·— —— · / ··· · —· — / — ——— / — ···· · / ·—— ·—· ——— —· ——· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ·· ——· —· ——— ·—· · —·· / ·· —· / ··· ·· ·—·· · —· —·—· · ——··—— / ·—— ···· ·· —·—· ···· / ·—·· ——— ——— —·— ··· / · —··— ·— —·—· — ·—·· —·—— / ·—·· ·· —·— · / ·— / —·· · ·— —·· / —·—· ·— —··· ·—·· · ·—·—·—\n${speed}\n—····— / ** ·— —· ——— — ···· · ·—· / ·— ·——· ·——· / —— ·— —·—— / ···· ——— ·—·· —·· / — ···· · / ·——· ——— ·—· — ** ———··· / ·—— ··· ·——— — —····— —··— ——··—— / ··—· ·—·· —·· ·· ——· ·· / ·— —· —·· / ·—· ·· ——· —·—· — ·—·· —·· / ·— ·—·· ·—·· / —·— · · ·——· / ·· — / ——— ·——· · —· ·—·—·—',
			'settings.station.icomUsbSpeedFollows' => '—····— / ** — ···· · ·—· · / ·· ··· / —· ——— / ··· ·——· · · —·· / — ——— / ··· · — ·—·—·— ** / ——— ···— · ·—· / ··— ··· —··· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ·— ·—·· —·— ··· / ·— — / ·—— ···· ·— — · ···— · ·—· / ··· ·——· · · —·· / — ···· · / —·—· ——— —— ·——· ··— — · ·—· / ··— ··· · ··· ——··—— / ·— —· —·· / — ···· ·· ··· / · —· — ·—· —·—— / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· · ··· / ·———— ·———— ····· ··——— ————— ————— ——··—— / — ···· · / ··· ·——· · · —·· / — ···· · / ··· —·—· ——— ·——· · / —· · · —·· ··· ·—·—·—',
			'settings.station.ic7610UsbSpeed' => '—····— / ** ··· · — / —·—· ·· —····— ···— / ··— ··· —··· / —··· ·— ··— —·· / ·—· ·— — · / — ——— / ·———— ·———— ····· ··——— ————— ————— ** ——··—— / — ···· · / ··· ·——· · · —·· / — ···· ·· ··· / · —· — ·—· —·—— / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· · ··· ——··—— / ··· ·· —· —·—· · / — ···· · / ··· —·—· ——— ·——· · / —· · · —·· ··· / ·· — / — / ** —· ——— — / ·— ··— — ——— ** ·—·—·— / ·— / ·—· ·— —·· ·· ——— / ··· · — / — ——— / ·— —· —·—— / ——— — ···· · ·—· / ··· ·——· · · —·· / ·— —· ··· ·—— · ·—· ··· / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ·—·—·—',
			'settings.station.ic7300Mk2Note' => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··——— ** / ··· ···· ·· ·——· ··· / ——— —· / ·— —·· —·· ·—· · ··· ··· / `B6` ——··—— / —· ——— — / — ···· · / `94` / ·——· ·—· · ··—· ·· ·—·· ·—·· · —·· / ···· · ·—· · / — / ·——· ·· —·—· —·— / — ···· · / ·· —·—· —····— ——··· ···—— ————— ————— / —— —·— ··——— / · —· — ·—· —·—— / ·· —· ··· — · ·— —·· ·—·—·—',
			'settings.station.ic705PortNote' => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ————— ····· ** / ·——· ·—· · ··· · —· — ··· / — ·—— ——— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· ——··—— / —··· ——— — ···· / —· ·— —— · —·· / ·— ··—· — · ·—· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / —·—· ·· —····— ···— / ·· ··· / ——— —· / — ···· · / ** ··—· ·· ·—· ··· — ** / ——— ··—· / — ···· · —— ——··—— / ·—— ···· ·· —·—· ···· / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — / ·—— ···· · ·—· · ···— · ·—· / ·· — / —·—· ·— —· / — · ·—·· ·—·· / — ···· · / — ·—— ——— / ·— ·——· ·— ·—· — ·—·—·—',
			'settings.station.ic7760PortNote' => '\n—····— / — ···· · / ** ·· —·—· —····— ——··· ——··· —···· ————— ** / ··· ·——· · ·— —·— ··· / —·—· ·· —····— ···— / ——— —· / ** ·——· ——— ·—· — / ·— ** / ——— ··—· / — ···· · / — ·—— ——— / ··— ··· —··· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·· — / ·——· ·—· · ··· · —· — ··· ·—·—·—',
			'settings.station.x6100PortNote' => '\n—····— / — ···· · / ** —··— —···· ·———— ————— ————— ** / ··· ·——· · ·— —·— ··· / —·—· ·· —····— ···— / ——— —· / ·· — ··· / ** —·· · ···— ** / ·——· ——— ·—· — / — / — ···· · / ··· · —·—· ——— —· —·· / ——— ··—· / — ···· · / — ·—— ——— / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — ··· / ·· — / ·——· ·—· · ··· · —· — ··· ——··—— / ·— —· —·· / — ···· · / ——— —· · / — ···· · / ·——· ·· —·—· —·— · ·—· / ·——· ——— ·· —· — ··· / ·— — ·—·—·—',
			'settings.station.rigctldTroubleshootingTitle' => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —',
			'settings.station.rigctldTroubleshooting' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— / ** ·—· ·· ——· —·—· — ·—·· —·· / —·· ·— · —— ——— —· / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ···· ·— —— ·—·· ·· —··· ·————· ··· / —··· ·— —·—· —·— · —· —·· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· — ··· / ···· ··— —· —·· ·—· · —·· ··· / ——— ··—· / —— ——— —·· · ·—·· ··· ·—·—·—\n\n—····— / ** — ···· · / —·· ·— · —— ——— —· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** ——··—— / · ·—·—·— ——· ·—·—·— / `rigctld -m 1035 -r /dev/ttyUSB0` ·—·—·— / ··—· ·· —· —·· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ·————· ··· / —— ——— —·· · ·—·· / —· ··— —— —··· · ·—· / ·—— ·· — ···· / `rigctl -l` ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / ··· — ·— ·—· — / ·· — / ·—— ·· — ···· / `-T 0.0.0.0` ———··· / —··· —·—— / —·· · ··—· ·— ··— ·—·· — / ·—· ·· ——· —·—· — ·—·· —·· / ——— —· ·—·· —·—— / ·— —·—· —·—· · ·——· — ··· / —·—· ——— —· —· · —·—· — ·· ——— —· ··· / ··—· ·—· ——— —— / — ···· · / —— ·— —·—· ···· ·· —· · / ·· — / ·—· ··— —· ··· / ——— —· ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ····— ····· ···—— ··——— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / ··· — ·— ·—· — · —·· / — ···· · / —·· ·— · —— ——— —· / ·—— ·· — ···· / `-t` ·—·—·—\n—····— / ——— —· —·—· · / —·—· ——— —· —· · —·—· — · —·· ——··—— / ·— / —— ·· ··· ··· ·· —· ——· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··— ··· ··— ·— ·—·· ·—·· —·—— / —— · ·— —· ··· / — ···· · / —·· ·— · —— ——— —· / ·· — ··· · ·—·· ··—· / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / — · ··· — / ·· — / ·—— ·· — ···· / `rigctl -m 2 f` / ——— —· / — ···· · / —·· ·— · —— ——— —· ·————· ··· / —— ·— —·—· ···· ·· —· · ·—·—·—',
			'settings.station.flrigTroubleshootingTitle' => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —',
			'settings.station.flrigTroubleshooting' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ·— —· / ** ··—· ·—·· ·—· ·· ——· / ·——· ·—· ——— ——· ·—· ·— —— / —·—— ——— ··— / ·—· ··— —· / —·—— ——— ··— ·—· ··· · ·—·· ··—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ··—· ·—·· ·—· ·· ——· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— / ·— —· —·· / ··· ··— ·——· ·——· ——— ·—· — ··· / —— ——— ··· — / —— ·— —·— · ··· / ·— —· —·· / —— ——— —·· · ·—·· ··· ·—·—·—\n\n—····— / ** ··—· ·—·· ·—· ·· ——· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** ——··—— / ·—— ·· — ···· / ·· — ··· / — ·—· ·— —· ··· —·—· · ·· ···— · ·—· / —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ··——— ···—— ····— ····· / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / ·· —· / ··—· ·—·· ·—· ·· ——· ·————· ··· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / —·——· —·—· ——— —· ··—· ·· ——· / → / ··· · — ··— ·——· / → / ··· · ·—· ···— · ·—· —·——·— ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / ··—· ·—·· ·—· ·· ——· ·————· ··· / ··· · ·—· ···— · ·—· / ·· ··· / ·—· · ·— —·—· ···· ·— —··· ·—·· · ·—·—·— / ·· — / ·—·· ·· ··· — · —· ··· / ——— —· / ·— ·—·· ·—·· / ·· —· — · ·—· ··—· ·— —·—· · ··· ——··—— / —··· ··— — / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / —— ·— —·—— / —· ——— — / ·— ——· ·—· · · ·—·—·—\n—····— / ——— —· —·—· · / —·—· ——— —· —· · —·—· — · —·· ——··—— / ·— / —— ·· ··· ··· ·· —· ——· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··— ··· ··— ·— ·—·· ·—·· —·—— / —— · ·— —· ··· / ··—· ·—·· ·—· ·· ——· / ·· — ··· · ·—·· ··—· / —·—· ·— —· —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ··—· ·—·· ·—· ·· ——· ·————· ··· / —·· ·· ··· ·——· ·—·· ·— —·—— / ·· ··· / ··—· ——— ·—·· ·—·· ——— ·—— ·· —· ——· / — ···· · / —·· ·· ·— ·—·· ·—·—·—',
			'settings.station.hrdTroubleshootingTitle' => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —',
			'settings.station.hrdTroubleshooting' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** ···· ·— —— / ·—· ·— —·· ·· ——— / —·· · ·—·· ··— —··— · ·————· ··· / ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· ——··—— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / ···· ·—· —·· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** ·· — ··· / ·· ·——· / ··· · ·—· ···— · ·—· / —— ··— ··· — / —··· · / · —· ·— —··· ·—·· · —·· ·—·—·— ** / ·—· ·· ——· / —·—· ——— —· — ·—· ——— ·—·· / ——— —· ·—·· —·—— / — ·— ·—·· —·— ··· / — ——— / ——— — ···· · ·—· / ·——· ·—· ——— ——· ·—· ·— —— ··· / — ···· ·—· ——— ··— ——· ···· / ·· — ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ——··· ———·· ————— ————· / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / ·· —· / — ···· · / ·· ·——· / ··· · ·—· ···— · ·—· ·————· ··· / ··· · — — ·· —· ——· ··· ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ·—·· · — ··· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / — ···· ·—· ——— ··— ——· ···· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / —·· · ··· —·—· ·—· ·· ·——· — ·· ——— —· ··· / ——— ··—· / ···· ·—· —·· ·————· ··· / ·——· ·—· ——— — ——— —·—· ——— ·—·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / ···· ·—· —·· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.n3fjpTroubleshootingTitle' => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —',
			'settings.station.n3fjpTroubleshooting' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** ·— —· / —· ···—— ··—· ·——— ·——· / ·—·· ——— ——· ——· ·· —· ——· / ·——· ·—· ——— ——· ·—· ·— —— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / —· ···—— ··—· ·——— ·——· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** — ···· · / ·——· ·—· ——— ——· ·—· ·— —— ·————· ··· / ·— ·——· ·· / —— ··— ··· — / —··· · / ——— —· ** ———··· / ··· · — — ·· —· ——· ··· / → / ·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / ·——· ·—· ——— ——· ·—· ·— —— / ·· —· — · ·—· ··—· ·— —·—· · ——··—— / —·—· ···· · —·—· —·— / ** — —·—· ·——· / ·— ·——· ·· / · —· ·— —··· ·—·· · —·· ** ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ·———— ·———— ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — / — ···· · ·—· · ·—·—·—\n—····— / ** —· ···—— ··—· ·——— ·——· / —— ··— ··· — / ···· ·— ···— · / ·— / ·—· ·— —·· ·· ——— / ·· —· — · ·—· ··—· ·— —·—· · / ··· · — / ··— ·——· ** / — ——— / ··—· ——— ·—·· ·—·· ——— ·—— / ——— ·—· / — ··— —· · / — ···· · / ·—· ·— —·· ·· ——— ·—·—·— / ·—— ·· — ···· ——— ··— — / ——— —· · ——··—— / ·· — / ·—· · ·——· ——— ·—· — ··· / ——— —· ·—·· —·—— / ·—— ···· ·— — / ·· ··· / — —·—— ·——· · —·· / ·· —· — ——— / ·· — ··· / · —· — ·—· —·—— / ·—— ·· —· —·· ——— ·—— ·—·—·—\n—····— / —· ···—— ··—· ·——— ·——· / ·—· · ·——· ——— ·—· — ··· / —··· ·— —· —·· ——··—— / —— ——— —·· · / ·— —· —·· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ——— —· ·—·· —·—— ———··· / —· ——— / ·——· ——— ·—— · ·—· ——··—— / —· ——— / — ·—· ·— —· ··· —— ·· — / ··· — ·— — · ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —· ···—— ··—· ·——— ·——· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / ·— ·——· ·· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / —· ···—— ··—· ·——— ·——· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.commanderTroubleshootingTitle' => '·· ··—· / — ···· · / ·— ·——· ·——· / —·—· ·— —· —· ——— — / —·—· ——— —· —· · —·—· —',
			'settings.station.commanderTroubleshooting' => '— ···· ·· ··· / —·—· ——— —· —· · —·—· — ··· / — ——— / ** —·· —··— ·—·· ·— —··· / —·—· ——— —— —— ·— —· —·· · ·—· ——··—— / ·—· ··— —· —· ·· —· ——· / ——— —· / —·—— ——— ··— ·—· / —·—· ——— —— ·——· ··— — · ·—· ** ——··—— / —· ——— — / — ——— / — ···· · / ·—· ·— —·· ·· ——— / —·· ·· ·—· · —·—· — ·—·· —·—— / — / —·—· ——— —— —— ·— —· —·· · ·—· / — ·— ·—·· —·— ··· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n—····— / ** —·—· ——— —— —— ·— —· —·· · ·—· / —— ··— ··· — / ·— ·—·· ·—· · ·— —·· —·—— / —··· · / ·—· ··— —· —· ·· —· ——· ** / ·— —· —·· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** ·· — ··· / —· · — ·—— ——— ·—· —·— / ··· · ·—· ···— ·· —·—· · / —— ··— ··· — / —··· · / ——— —· ** ———··· / — ···· · / ** —· · — / ··· · ·—· ···— ** / —··· ··— — — ——— —· / ·· —· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·— —· · ·—·· / ——— ··—· / —·—· ——— —— —— ·— —· —·· · ·—· ·————· ··· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —· / ·—— ·· —· —·· ——— ·—— ·—·—·—\n—····— / ** ·——· ——— ·—· — ** / ·· ··· / ····· ··——— ————— ————— ··——— ——··—— / — ···· · / — ···· ·· ·—· —·· / ·——· ——— ·—· — / ——— ··—· / — ···· · / —··· ·—·· ——— —·—· —·— / ··· — ·— ·—· — ·· —· ——· / ·— — / —· · — / ··· · ·—· ···— ·————· ··· / ** —··· ·— ··· · / ·——· ——— ·—· — ** / —·——· ····· ··——— ————— ————— ————— / ··— —· ·—·· · ··· ··· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· — —·——·— ·—·—·—\n—····— / ** ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / —— ·— —·—· ···· ·· —· · ** ——··—— / —— ·— —·— · / ··· ··— ·—· · / —·—— ——— ··— ·—· / ··—· ·· ·—· · ·—— ·— ·—·· ·—·· / ·—·· · — ··· / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / — ···· ·—· ——— ··— ——· ···· ·—·—·—\n\n— ···· ·· ··· / · —· — ·—· —·—— / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ··—· ·—· ——— —— / —·—· ——— —— —— ·— —· —·· · ·—· ·————· ··· / ·——· ··— —··· ·—·· ·· ··· ···· · —·· / — —·—· ·——· / —— · ··· ··· ·— ——· · ··· / ·— —· —·· / ···· ·— ··· / —· ——— — / —··· · · —· / ·—· ··— —· / ·— ——· ·— ·· —· ··· — / —·—· ——— —— —— ·— —· —·· · ·—· ·—·—·— / ·· ··—· / ·· — / ···· ·— ·—·· ··—· —····— ·—— ——— ·—· —·— ··· ——··—— / — ···· ·— — / ·· ··· / ·—— ——— ·—· — ···· / ·—· · ·——· ——— ·—· — ·· —· ——· ·—·—·—',
			'settings.station.ic705TroubleshootingTitle' => '·· ··—· / — ···· · / ·—· ·— —·· ·· ——— / —· · ···— · ·—· / ·—· · ··· ·——· ——— —· —·· ···',
			'settings.station.ic705Troubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ···· ·— ··· / ·— / ** ··· ·· —· ——· ·—·· · ** / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··· · ··· ··· ·· ——— —· ·—·—·— / ·—— ···· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·· ··· / ·· ——· —· ——— ·—· · —·· ——··—— / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· · / ·· ··· / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·· — ·—·—·—\n\n—····— / ** —·—· ·—·· ——— ··· · / ·— —· —·—— / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ·—·—·— ** / ·—— ··—· ···— ·· · ·—— / ——— ·—· / ·—· ··· —····— —··· ·— ·———— / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ——— / ···· ——— ·—·· —·· ··· / — ···· ·— — / ——— —· · / ··· · ··· ··· ·· ——— —· ——··—— / ·— —· —·· / — ···· · / ·—·· ——— ——· ·· —· / ···· · ·—· · / ·· ··· / ··· ·· —— ·——· ·—·· —·—— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·· — / —·· ——— · ··· ·—·—·—\n—····— / ** —·—· ···· · —·—· —·— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ·—·—·— ** / ·—— ·—·· ·— —· / —— ··— ··· — / —··· · / ——— —· ——··—— / — ···· · / ·—· ·— —·· ·· ——— / —— ··— ··· — / —··· · / ——— —· / — ···· · / ··· ·— —— · / —· · — ·—— ——— ·—· —·— ——··—— / ·— —· —·· / ·· — ··· / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / —·——· —· · — ·—— ——— ·—· —·— —·——·— / ··—· ··— —· —·—· — ·· ——— —· / —— ··— ··· — / —··· · / · —· ·— —··· ·—·· · —·· ·—·—·—\n—····— / ** — ···· · / ·——· ——— ·—· — ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— ——··—— / ——— ·—· / — ···· · / ·——· ——— ·—· — ··· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / — ···· · —— ·—·—·— / ·— / ·—— ·—· ——— —· ——· / ·——· ——— ·—· — / ·· ··· / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ——··—— / — ···· · / ··· ·— —— · / ·— ··· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·· ··· / ——— ··—· ··—· ·—·—·—\n—····— / ** ·——· ——— ·—— · ·—· —····— —·—· —·—— —·—· ·—·· · / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·—— ·—·· ·— —· ** / ·· ··—· / ·· — / ··· — ·— —·—— ··· / ··· — ··— —·—· —·— ·—·—·— / — ···· ·— — / ·—· · ·—·· ·· ·— —··· ·—·· —·—— / —·—· ·—·· · ·— ·—· ··· / ·— / ··· · ··· ··· ·· ——— —· / ··· — ··— —·—· —·— / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n\n·— / ** ·—— ·—· ——— —· ——· / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·· ··· / ·—· · ··—· ··— ··· · —·· / · —··— ·——· ·—·· ·· —·—· ·· — ·—·· —·—— ** ——··—— / —· ——— — / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ·—·—·— / ·· ··—· / —·—— ——— ··— / ——· ——— — / ···· · ·—· · / ·—· ·— — ···· · ·—· / — ···· ·— —· / ·— / ·—··—· ·—· · ·——— · —·—· — · —·· ·—··—· / —— · ··· ··· ·— ——· · ——··—— / — ···· · / ·——· ·— ··· ··· ·—— ——— ·—· —·· / ·· ··· / —· ——— — / — ···· · / ·——· ·—· ——— —··· ·—·· · —— ·—·—·—',
			'settings.station.icomLanTroubleshooting' => '— ···· · / ·—· ·— —·· ·· ——— / ···· ·— ··· / ·— / ** ··· ·· —· ——· ·—·· · ** / ·—· · —— ——— — · —····— —·—· ——— —· — ·—· ——— ·—·· / ··· · ··· ··· ·· ——— —· ·—·—·— / ·—— ···· · —· / — ···· · / ·—·· ——— ——· ·· —· / ·· ··· / ·· ——· —· ——— ·—· · —·· ——··—— / ··· ——— —— · — ···· ·· —· ——· / · ·—·· ··· · / ·· ··· / ·— ·—·· —— ——— ··· — / ·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·· — ·—·—·—\n\n—····— / ** —·—· ·—·· ——— ··· · / ·— —· —·—— / ——— — ···· · ·—· / —·—· ·—·· ·· · —· — ·—·—·— ** / ·—— ··—· ···— ·· · ·—— ——··—— / ·—· ··· —····— —··· ·— ·———— / ——— ·—· / ·· —·—· ——— —— ·————· ··· / ·—· · —— ——— — · / ··— — ·· ·—·· ·· — —·—— / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / ·—· ·— —·· ·· ——— / ···· ——— ·—·· —·· ··· / — ···· ·— — / ——— —· · / ··· · ··· ··· ·· ——— —· ——··—— / ·— —· —·· / — ···· · / ·—·· ——— ——· ·· —· / ···· · ·—· · / ·· ··· / ··· ·· —— ·——· ·—·· —·—— / ·· ——· —· ——— ·—· · —·· / ·—— ···· ·· ·—·· · / ·· — / —·· ——— · ··· ·—·—·—\n—····— / ** —·—· ···· · —·—· —·— / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —· · — ·—— ——— ·—· —·— / ··· · — — ·· —· ——· ··· ·—·—·— ** / ·· — ··· / ·—·· ·— —· / ·——· ——— ·—· — / —— ··— ··· — / —··· · / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· · / ··· ·— —— · / —· · — ·—— ——— ·—· —·— / ·— ··· / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / ·· — ··· / ** —· · — ·—— ——— ·—· —·— / —·—· ——— —· — ·—· ——— ·—·· ** / —— ··— ··· — / —··· · / ——— —· ——··—— / ·— —· —·· / — ···· · / ··— ··· · ·—· —· ·— —— · / ·— —· —·· / ·——· ·— ··· ··· ·—— ——— ·—· —·· / —— ··— ··· — / —··· · / ··· · — / ··— ·——· / ·— ··· / ·— / —· · — ·—— ——— ·—· —·— / ··— ··· · ·—· / ——— —· / — ···· · / ·—· ·— —·· ·· ——— ·—·—·—\n—····— / ** — ···· · / ·——· ——— ·—· — ··· / —— ··— ··· — / —— ·— — —·—· ···· ** / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ——— —· — ·—· ——— ·—·· / ·——· ——— ·—· — / ·— —· —·· / ··· · ·—· ·· ·— ·—·· / ·——· ——— ·—· — / —·——· ··— —·· ·——· —·——·— ——··—— / ——— ·—· / — ···· · / ·——· ——— ·—· — ··· / ··—· ——— ·—· ·—— ·— ·—· —·· · —·· / — ——— / — ···· · —— ·—·—·— / ·— / ·—— ·—· ——— —· ——· / ·——· ——— ·—· — / ·· ··· / —— · — / ·—— ·· — ···· / ··· ·· ·—·· · —· —·—· · ——··—— / — ···· · / ··· ·— —— · / ·— ··· / ·— / ·—· ·— —·· ·· ——— / — ···· ·— — / ·· ··· / ——— ··—· ··—· ·—·—·—\n—····— / ** ·· ··—· / ·· — / —·—· ——— —· —· · —·—· — ··· / —··· ··— — / —· · ···— · ·—· / ·— —· ··· ·—— · ·—· ··· ** ——··—— / — ···· · / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / ···· · ·—· · / —— ··— ··· — / —— ·— — —·—· ···· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —·—· ·· —····— ···— / ·— —·· —·· ·—· · ··· ··· / —— · —· ··— ·—·—·— / — ···· ·· ··· / · —· — ·—· —·—— / ·——· ·—· · ··—· ·· ·—·· ·—·· ··· / — ···· · / ·— —·· —·· ·—· · ··· ··· / — ···· · / —— ——— —·· · ·—·· / ··· ···· ·· ·——· ··· / ·—— ·· — ···· ·—·—·—\n—····— / ** — ··— ·—· —· / — ···· · / ·—· ·— —·· ·· ——— / ——— ··—· ··—· / ·— —· —·· / ——— —· ** / ·· ··—· / ·· — / ··· — ·— —·—— ··· / ··· — ··— —·—· —·— ·—·—·—',
			'settings.station.statusStale' => '—· ——— — / ·—· · ··· ·——· ——— —· —·· ·· —· ——·',
			'settings.station.statusDisconnected' => '—· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'settings.station.statusConnecting' => '—·—· ——— —· —· · —·—· — ·· —· ——· …',
			'settings.station.statusDisconnecting' => '—·· ·· ··· —·—· ——— —· —· · —·—· — ·· —· ——· …',
			'settings.station.statusError' => '—·—· ——— —· —· · —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —··',
			'settings.station.currentRadioSettings' => '—·—· ··— ·—· ·—· · —· — / ·—· ·— —·· ·· ——— / ··· · — — ·· —· ——· ···',
			'settings.station.notSupportedByThisRadio' => '—· ——— — / ··· ··— ·——· ·——· ——— ·—· — · —·· / —··· —·—— / — ···· ·· ··· / ·—· ·— —·· ·· ———',
			'settings.station.keyerRowLabel' => '—·— · —·—— · ·—·',
			'settings.station.cwMessagesButton' => '—·—· ·——',
			'settings.station.voiceMessagesButton' => '·——· ···· ——— —· ·',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => '···— ——— ·· —·—· · / —·— · —·—— · ·—· ———··· / ${count} / —— · —— ——— ·—· ·· · ··· / ·· —· / — ···· · / ·—· ·— —·· ·· ———',
			'settings.station.antennaBands' => '—··· ·— —· —·· ···',
			'settings.station.antennaType' => '·— —· — · —· —· ·— / — —·—— ·——· ·',
			'settings.station.antennaTypeRequired' => '—·—· ···· ——— ——— ··· · / ·— —· / ·— —· — · —· —· ·— / — —·—— ·——· ·',
			'settings.station.antennaTypes.dipole' => '—·· ·· ·——· ——— ·—·· ·',
			'settings.station.antennaTypes.vertical' => '···— · ·—· — ·· —·—· ·— ·—··',
			'settings.station.antennaTypes.yagiBeam' => '—·—— ·— ——· ·· / —··—· / —··· · ·— ——',
			'settings.station.antennaTypes.loop' => '·—·· ——— ——— ·——·',
			'settings.station.antennaTypes.longWire' => '·—·· ——— —· ——· / ·—— ·· ·—· · / —··—· / · ··—· ···· ·——',
			'settings.station.antennaTypes.other' => '——— — ···· · ·—·',
			'settings.station.keyType' => '—·— · —·—— / — —·—— ·——· ·',
			'settings.station.keyTypeRequired' => '—·—· ···· ——— ——— ··· · / ·— / —·— · —·—— / — —·—— ·——· ·',
			'settings.station.keyTypes.straight' => '··· — ·—· ·— ·· ——· ···· — / —·— · —·——',
			'settings.station.keyTypes.sideswiper' => '··· ·· —·· · ··· ·—— ·· ·——· · ·—·',
			'settings.station.keyTypes.bug' => '—··· ··— ——· / —·——· —— · —·—· ···· ·— —· ·· —·—· ·— ·—·· / ··· · —— ·· —····— ·— ··— — ——— —— ·— — ·· —·—· —·——·—',
			'settings.station.keyTypes.fullyAutomatic' => '··—· ··— ·—·· ·—·· —·—— —····— ·— ··— — ——— —— ·— — ·· —·—· / —·— · —·—— · ·—·',
			'settings.station.keyTypes.singlePaddle' => '··· ·· —· ——· ·—·· · / ·——· ·— —·· —·· ·—·· ·',
			'settings.station.keyTypes.dualPaddle' => '—·· ··— ·— ·—·· / ·——· ·— —·· —·· ·—·· ·',
			'settings.station.keyTypes.computerDriven' => '—·—· ——— —— ·——· ··— — · ·—· / —·· ·—· ·· ···— · —·',
			'settings.station.keyTypes.other' => '——— — ···· · ·—·',
			'settings.station.softwareIntermediaries' => '··· ——— ··—· — ·—— ·— ·—· · / ·· —· — · ·—· —— · —·· ·· ·— ·—· ·· · ···',
			'settings.station.otherBrands' => '——— — ···· · ·—· / —··· ·—· ·— —· —·· ···',
			'settings.station.otherEquipment' => '——— — ···· · ·—· / · ——·— ··— ·· ·——· —— · —· — / —·——· ·— —· — · —· —· ·— ··· ——··—— / —·— · —·—— ··· ——··—— / · — —·—· —·——·—',
			'settings.station.newAntenna' => '—· · ·—— / ·— —· — · —· —· ·—',
			'settings.station.newKey' => '—· · ·—— / —·— · —·——',
			'settings.station.newKeyer' => '·—— ·· —· —·— · —·—— · ·—· / —·——· —·— ·———— · ·—·· / ——— ·—· / —·—· ——— —— ·——· ·— — ·· —··· ·—·· · —·——·—',
			'settings.station.keyViaRadio' => ({required Object radio}) => '—·—· ·— — / —·— · —·—— · ·—· / ·· —· / ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => '—·— · —·—— / ——— —· / ${device}',
			'settings.station.cwKeyerArea' => '—·— · —·—— · ·—· / ·— ·—· · ·—',
			'settings.station.trackStationInfo' => '— ·—· ·— —·—· —·— / ··· — ·— — ·· ——— —· / ·· —· ··—· ——— / ··—· ——— ·—· / · ·— —·—· ···· / ——·— ··· ———',
			'settings.station.includeStationInfoInAdif' => '·· —· —·—· ·—·· ··— —·· · / ·· —· / ·— —·· ·· ··—· / · —··— ·——· ——— ·—· — ···',
			'settings.station.whatToTrack' => '·—— ···· ·— — / — ——— / — ·—· ·— —·—· —·— ··——··',
			'settings.station.trackFieldRig' => '— ·—· ·— —· ··· —·—· · ·· ···— · ·—·',
			'settings.station.trackFieldPower' => '·——· ——— ·—— · ·—·',
			'settings.station.watts' => '·—— ·— — — ···',
			'settings.station.trackFieldAntenna' => '·— —· — · —· —· ·—',
			'settings.station.trackFieldKey' => '—·—· ·—— / —·— · —·——',
			'settings.station.placeholderConnectDelay' => '—·—· ——— —· —· · —·—· — / —·· · ·—·· ·— —·—— / —·——· —— ··· —·——·—',
			'settings.station.placeholderConnectDelayDescription' => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / ··· ·· —— ··— ·—·· ·— — · —·· / ···· ·— —· —·· ··· ···· ·— —·— · / — ·— —·— · ··· ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / —·—· ——— —· —· · —·—· — ··· / ·· —· ··· — ·— —· — ·—·· —·—— ·—·—·—',
			'settings.station.placeholderDropAfter' => '—·· ·—· ——— ·——· / ·— ··—· — · ·—· / —·——· ··· · —·—· ——— —· —·· ··· —·——·—',
			'settings.station.placeholderDropAfterDescription' => '—·—· ·—·· ——— ··· · / — ···· · / —·—· ——— —· —· · —·—· — ·· ——— —· / ——— —· / ·· — ··· / ——— ·—— —· ——··—— / — ——— / · —··— · ·—· —·—· ·· ··· · / — ···· · / ·—· · —·—· ——— —· —· · —·—· — / ·——· ·— — ···· ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / —· · ···— · ·—· / —·· ·—· ——— ·——· ··· ·—·—·—',
			'settings.station.placeholderFailConnect' => '·— ·—·· ·—— ·— —·—— ··· / ··—· ·— ·· ·—·· / — ——— / —·—· ——— —· —· · —·—· —',
			'settings.station.placeholderConnectFailure' => '— ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ·—— ·— ··· / — ——— ·—·· —·· / — ——— / ·—· · ··—· ··— ··· · / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —·',
			'settings.station.placeholderFreq' => '··—· ·—· · ——·— ··— · —· —·—· —·—— / —·——· —·— ···· ——·· —·——·—',
			'settings.station.placeholderFreqDescription' => '·—— ···· · ·—· · / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ··· — ·— ·—· — ··· ·—·—·— / ·· — / ·—· · ·——· ——— ·—· — ··· / —··· ·— —·—· —·— / ·—— ···· ·— — · ···— · ·—· / — ···· · / ·— ·——· ·——· / — ··— —· · ··· / ·· — / — ——— / ·— ··—· — · ·—· ·—— ·— ·—· —·· ··· ·—·—·—',
			'settings.station.placeholderMode' => '—— ——— —·· ·',
			'settings.station.placeholderModeDescription' => '— ···· · / —— ——— —·· · / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / ··· — ·— ·—· — ··· / ——— —· ——··—— / · ·—·—·— ——· ·—·—·— / ··— ··· —··· ——··—— / —·—· ·—— ——··—— / ··—· — ———·· ·—·—·—',
			'settings.station.placeholderPower' => '·——· ——— ·—— · ·—· / —·——· ·—— ·— — — ··· —·——·—',
			'settings.station.placeholderPurpose' => '··— ··· · / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ——— / —·— · · ·——· / — ·—· ·— —·—· —·— / ——— ··—· / ·—— ···· ·· —·—· ···· / ·—· ·· ——· / —·—— ——— ··— ·————· ·—· · / ··— ··· ·· —· ——· / ··—· ——— ·—· / ·—·· ——— ——· ——· ·· —· ——· / ·——· ··— ·—· ·——· ——— ··· · ···',
			'settings.station.placeholderReplyDelay' => '·—· · ·——· ·—·· —·—— / —·· · ·—·· ·— —·—— / —·——· —— ··· —·——·—',
			'settings.station.placeholderReplyDelayDescription' => '···· ——— ·—— / ·—·· ——— —· ——· / — ···· · / ·——· ·—·· ·— —·—· · ···· ——— ·—·· —·· · ·—· / ·—· ·— —·· ·· ——— / — ·— —·— · ··· / — ——— / ·—· · ·——· ——— ·—· — / ·— / —·—· ···· ·— —· ——· · / —··· ·— —·—· —·— ·—·—·— / —··· ·—·· ·— —· —·— / ——— ·—· / ————— / ·—· · ·——· ·—·· ·· · ··· / ·— — / ——— —· —·—· · ·—·—·—',
			'settings.station.cwKeyerField' => '—·—· ·— — / —·—· ·—— / —·— · —·—— · ·—·',
			'settings.station.cwKeyerFieldDescription' => '·—— ···· · — ···· · ·—· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / —·— · —·—— ··· / —·—· ·—— / ··—· ·—· ——— —— / — · —··— — / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ——— ··—· ··—· / ··—· ——— ·—· / ·— / ·—· ·· ——· / — ···· · / ·— ·——· ·——· / —·· ——— · ··· / —· ——— — / —·— —· ——— ·—— ·—·—·—',
			'settings.station.voiceMemories' => '···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···',
			'settings.station.voiceMemoriesDescription' => '···· ——— ·—— / —— ·— —· —·—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / — ···· · / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ————— / ··—· ——— ·—· / —· ——— —· · ·—·—·—',
			'settings.station.voiceMemoriesInvalid' => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· ——··—— / ————— / ——— ·—· / —— ——— ·—· ·',
			'settings.station.yaesuMeterCapture' => '—·—· ·— ·——· — ··— ·—· · / —— · — · ·—· / ·—· · ·— —·· ·· —· ——· ···',
			'settings.station.yaesuBinaryMeterCaptureDescription' => '·—· · ·— —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·——· ——— ·—— · ·—· —····— ——— ··— — ·——· ··— — / —— · — · ·—· / ·— —· —·· / ···· ·· ——· ···· —····— ··· ·—— ·—· / ··—· ·—·· ·— ——· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / ·— —· —·· / ·——· ·—· ·· —· — ··· / — ···· · / ·—· ·— ·—— / ···— ·— ·—·· ··— · ··· / — ——— / — ···· · / ·—·· ——— ——· ·—·—·— / ··—· ——— ·—· / —··· ··— ·· ·—·· —·· ·· —· ——· / — ···· · / ··· —·—· ·— ·—·· · / —·—— ·— · ··· ··— / —·· ——— · ··· / —· ——— — / ·——· ··— —··· ·—·· ·· ··· ···· / — / — ···· · / ···— ·— ·—·· ··— · ··· / ·— ·—· · / —· ——— — / ··· ···· ——— ·—— —· / ·— ··· / —— · — · ·—· ··· ·—·—·—',
			'settings.station.yaesuMeterCaptureDescription' => '·—· · ·— —·· ··· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / ·——· ——— ——··—— / ··· ·—— ·—· / ·— —· —·· / ·— ·—·· —·—· / —— · — · ·—· ··· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / ·— —· —·· / ·——· ·—· ·· —· — ··· / — ···· · / ·—· ·— ·—— / ···— ·— ·—·· ··— · ··· / — ——— / — ···· · / ·—·· ——— ——· ·—·—·— / ··—· ——— ·—· / —··· ··— ·· ·—·· —·· ·· —· ——· / — ···· · / ··· —·—· ·— ·—·· · / —·—— ·— · ··· ··— / —·· ——— · ··· / —· ——— — / ·——· ··— —··· ·—·· ·· ··· ···· / — / — ···· · / ···— ·— ·—·· ··— · ··· / ·— ·—· · / —· ——— — / ··· ···· ——— ·—— —· / ·— ··· / —— · — · ·—· ··· ·—·—·—',
			'settings.station.telemetryInterval' => '—— · — · ·—· / ·—· · ·— —·· ·· —· ——· / ·· —· — · ·—· ···— ·— ·—·· / —·——· —— ··· —·——·—',
			'settings.station.telemetryIntervalDescription' => '···· ——— ·—— / ——— ··—· — · —· / — ——— / ·—· · ·— —·· / — ···· · / ·—· ·— —·· ·· ——— ·————· ··· / —— · — · ·—· ··· / ·—— ···· ·· ·—·· · / ·· — / ·· ··· / — ·—· ·— —· ··· —— ·· — — ·· —· ——· ·—·—·— / ·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / — ···· · / ··—· ·— ··· — · ··· — / — ···· ·· ··· / —·—· ——— —· —· · —·—· — ·· ——— —· / —·—· ·— —· / ···· ·— —· —·· ·—·· · ——··—— / ··— ·——· / — ——— / ··——— ————— ————— / —— ··· ·—·—·—',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· / ——— ··—· / —— ·· ·—·· ·—·· ·· ··· · —·—· ——— —· —·· ··· ——··—— / ${min} / — ——— / ${max}',
			'settings.station.pollInterval' => '·· —·· ·—·· · / ·——· ——— ·—·· ·—·· ·· —· ——· / ·· —· — · ·—· ···— ·— ·—·· / —·——· —— ··· —·——·—',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => '···· ——— ·—— / ——— ··—· — · —· / — ——— / ·— ··· —·— / — ···· · / ·—· ·— —·· ·· ——— / ··—· ——— ·—· / ·· — ··· / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·— —· —·· / —— ——— —·· · / ·—— ···· ·· ·—·· · / —· · ·· — ···· · ·—· / ·· ··· / —·—· ···· ·— —· ——· ·· —· ——· ·—·—·— / ·—·· · ·— ···— · / —··· ·—·· ·— —· —·— / ··—· ——— ·—· / ${fallback} / —— ··· ·—·—·—',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => '·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· / ——— ··—· / —— ·· ·—·· ·—·· ·· ··· · —·—· ——— —· —·· ··· ——··—— / ${min} / — ——— / ${max}',
			'settings.station.advancedSettings' => '·— —·· ···— ·— —· —·—· · —·· / ··· · — — ·· —· ——· ···',
			'settings.station.placeholderSwr' => '··· ·—— ·—· / ·—· · ·— —·· ·· —· ——·',
			'settings.station.placeholderSwrDescription' => '·—— ···· ·— — / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·—· · ·——· ——— ·—· — ··· / ——— —· / ·· — ··· / ··· ·—— ·—· / —— · — · ·—· / ·—— ···· ·· ·—·· · / — ·—· ·— —· ··· —— ·· — — ·· —· ——· ·—·—·— / ·— —··· ——— ···— · / ·———— ·—·—·— ———·· / — ···· · / ·——· ·— —· · ·—·· / ·—— ·— ·—· —· ··· ·—·—·—',
			'settings.station.placeholderSwrInvalid' => '·— / —· ··— —— —··· · ·—· ——··—— / ·———— / ——— ·—· / —— ——— ·—· ·',
			'settings.station.keyerNone' => '—· ——— —· ·',
			'settings.station.cwDialect' => '—·—· ·—— / —·— · —·—— ·· —· ——· / —·· ·· ·— ·—·· · —·—· —',
			'settings.station.cwDialectDescription' => '·—— ···· ·· —·—· ···· / ··· ···· ·— ·——· · / ——— ··—· / — ···· · / —·— —·—— / —·—· ——— —— —— ·— —· —·· / — ···· ·· ··· / ·—· ·— —·· ·· ——— / — ·— —·— · ··· ·—·—·— / —· ——— —· · / —— · ·— —· ··· / —· ——— / —·—· ·—— / —·— · —·—— ·· —· ——· / ——— ···— · ·—· / —·—· ·— — ·—·—·—',
			'settings.station.cwDialectKenwood' => '—·— · —· ·—— ——— ——— —·· / —·——· —·— —·—— ——··—— / ·——· ·— —·· —·· · —·· / — ——— / ··——— ····— —·——·—',
			'settings.station.cwDialectElecraft' => '· ·—·· · —·—· ·—· ·— ··—· — / —·——· —·— —·—— / — · —··— — —·——·—',
			'settings.station.voiceDialect' => '···— ——— ·· —·—· · / —·— · —·—— · ·—· / —·· ·· ·— ·—·· · —·—· —',
			'settings.station.voiceDialectDescription' => '···· ——— ·—— / — ···· ·· ··· / ·—· ·— —·· ·· ——— / ·——· ·—·· ·— —·—— ··· / ·· — ··· / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / —· ——— —· · / —— · ·— —· ··· / —· ——— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ··· / ——— ···— · ·—· / —·—· ·— — ·—·—·— / ·—— ·· — ···· / ·— / —·· ·· ·— ·—·· · —·—· — / ·— —· —·· / —· ——— / —·—· ——— ··— —· — ——··—— / — ···· · / —·· ·· ·— ·—·· · —·—· — ·————· ··· / —·· · ··—· ·— ··— ·—·· — / —·—· ——— ··— —· — / ·— ·——· ·——· ·—·· ·· · ··· ·—·—·—',
			'settings.station.voiceDialectPb' => '—·— · —· ·—— ——— ——— —·· / —·——· ·——· —··· ——··—— / — ··· —····— ····· ————· ————— / ··· — —·—— ·—·· · —·——·—',
			'settings.station.voiceDialectK4' => '· ·—·· · —·—· ·—· ·— ··—· — / —·— ····— / —·——· ·——· —··· / ·— —· —·· / —·· ·— —·——·—',
			'settings.station.voiceDialectKx' => '· ·—·· · —·—· ·—· ·— ··—· — / —·— —··— ··——— —··—· —·— —··— ···—— / —·——· ··· ·—— ·· — —·—· ···· / — ·— ·——· ··· —·——·—',
			'settings.station.placeholderDiagnostic' => '··· ·· —— ··— ·—·· ·— — · —··',
			'settings.station.placeholderWholeNumberInvalid' => '—— ··— ··· — / —··· · / ·— / ·—— ···· ——— ·—·· · / —· ··— —— —··· · ·—· ——··—— / ————— / ——— ·—· / —— ——— ·—· ·',
			'settings.station.placeholderFreqInvalid' => '—— ··— ··· — / —··· · / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ·· —· / —·— ···· ——·· ——··—— / ——· ·—· · ·— — · ·—· / — ···· ·— —· / ——·· · ·—· ———',
			'settings.station.placeholderModeInvalid' => '—— ··— ··· — / —··· · / ·— / —— ——— —·· · / —· ·— —— · ——··—— / · ·—·—·— ——· ·—·—·— / ··— ··· —··· ——··—— / —·—· ·—— ——··—— / ··—· — ———··',
			'settings.station.switchLayout' => '·—·· ·— —·—— ——— ··— —',
			'settings.station.switchLayoutDescription' => '·—— ···· ·· —·—· ···· / ··· ·· —·· · / ——— ··—· / — ···· · / ··· ·—— ·· — —·—· ···· / —·—— ——— ··— ·—· / ·—· ·— —·· ·· ——— ··· / ·— ·—· · / ·——· ·—·· ··— ——· ——· · —·· / ·· —· — ——— ·—·—·—',
			'settings.station.switchLayoutRequired' => '—·—· ···· ——— ——— ··· · / ···· ——— ·—— / — ···· · / ··· ·—— ·· — —·—· ···· / ·· ··· / ·—— ·· ·—· · —··',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => '— ···· · / ··· ·—— ·· — —·—· ···· / ·—· · ··—· ··— ··· · —·· / ·—··—· ${command} ·—··—· / —·——· · ·—· ·—· ——— ·—· / ${code} —·——·—',
			'settings.station.switchBusyTransmitting' => '— ···· ·— — / ·——· ——— ·—· — / ·· ··· / — ·—· ·— —· ··· —— ·· — — ·· —· ——· / — / ·— —· — · —· —· ·— / —· ——— — / —·—· ···· ·— —· ——· · —··',
			'settings.station.switchNoAntenna' => '—· ——— —· ·',
			'settings.station.switchAntennaFor' => ({required Object port}) => '·— —· — · —· —· ·— / ——— —· / ·——· ——— ·—· — / ${port}',
			'settings.station.switchAntennaForDescription' => '·—— ···· ·· —·—· ···· / ——— ··—· / —·—— ——— ··— ·—· / ·— —· — · —· —· ·— ··· / ·· ··· / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· ·· ··· / ·——· ——— ·—· — / ——— —· / — ···· · / ··· ·—— ·· — —·—· ···· ·—·—·—',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} / ·— —· — · —· —· ·— ··· ——··—— / ${radios} / ·—· ·— —·· ·· ——— ···',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} / ·— —· — · —· —· ·— ··· ——··—— / ·———— / ·—· ·— —·· ·· ———',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '·———— / ·— —· — · —· —· ·— ——··—— / ${radios} / ·—· ·— —·· ·· ——— ···',
			'settings.station.switchCommonPort' => '—·—· ——— —— —— ——— —·',
			'settings.station.dcnAddress' => '—·· · ···— ·· —·—· · / ·— —·· —·· ·—· · ··· ···',
			'settings.station.dcnAddressDescription' => '— ···· · / ·— —·· —·· ·—· · ··· ··· / ··· · — / ——— —· / — ···· · / —— ——— —·· ··— ·—·· · ·————· ··· / —·· ·· ·——· / ··· ·—— ·· — —·—· ···· · ··· ·—·—·— / ·— / —·—· ——— ·— —··— / ·—· · ·—·· ·— —·—— / —— ——— —·· ··— ·—·· · / ·—·· · ·— ···— · ··· / — ···· · / ··—· ·— —·—· — ——— ·—· —·—— / ·— — / ··——— ·—·—·—',
			'settings.station.dcnAddressRequired' => '—— ··— ··· — / —··· · / ·— / —·· · ···— ·· —·—· · / ·— —·· —·· ·—· · ··· ··· / ··—· ·—· ——— —— / ·———— / — ——— / ————· ————·',
			'settings.station.switchPortLabel' => ({required Object port}) => '·——· ——— ·—· — / ${port}',
			'settings.station.switchPortAutoHint' => '··—· ——— ·—·· ·—·· ——— ·—— ··· / —··· ·— —· —·· / —·· ·— — ·—',
			'settings.station.switchPortTransmittingHint' => '— ·—· ·— —· ··· —— ·· — — ·· —· ——· / — / —·—· ·— —· —· ——— — / —·—· ···· ·— —· ——· · / —· ——— ·——',
			'settings.station.switchCurrentStateHeader' => '—·—· ··— ·—· ·—· · —· — / ··· — ·— — ·',
			'settings.station.switchCurrentStateDescription' => '·—— ···· ·· —·—· ···· / ·— —· — · —· —· ·— / · ·— —·—· ···· / ·—· ·— —·· ·· ——— / ·——· ——— ·—· — / ·· ··· / ——— —· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·— / —·—· ···· ·— —· ——· · ··· / — ·— —·— · / · ··—· ··—· · —·—· — / ·· —— —— · —·· ·· ·— — · ·—·· —·—— ·—·—·—',
			'settings.station.switchWiringHeader' => '·—— ·· ·—· ·· —· ——·',
			'settings.station.switchPortInhibitedHint' => '— ·—· ·— —· ··· —— ·· — / ·· —· ···· ·· —··· ·· — · —··',
			'settings.station.configUnreadable' => '— ···· ·· ··· / ·—· ·— —·· ·· ——— ·————· ··· / ··· ·— ···— · —·· / ··· · — — ·· —· ——· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ·—·—·— / ——— ·——· · —· / ·· — ··· / ··· · — — ·· —· ——· ··· / ·— —· —·· / · —· — · ·—· / — ···· · —— / ·— ——· ·— ·· —· ——··—— / ——— ·—· / ·—· · —— ——— ···— · / ·· — / ·— —· —·· / ·— —·· —·· / ·· — / —··· ·— —·—· —·— ·—·—·—',
			'settings.station.autoConnectHeld' => '···· ·— ·—·· ——— / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — ···· · / ·—·· ·— ··· — / — ·· —— · / ·· — / —·—· ——— —· —· · —·—· — · —·· / — ——— / — ···· ·· ··· / ·—· ·— —·· ·· ——— ——··—— / ··· ——— / ·· — / —·· ·· —·· / —· ——— — / —·—· ——— —· —· · —·—· — / ——— —· / ·· — ··· / ——— ·—— —· / — ···· ·· ··· / — ·· —— · ·—·—·— / ·——· ·—· · ··· ··· / —·—· ——— —· —· · —·—· — / — ——— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'settings.offlineData.title' => '——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·—',
			'settings.offlineData.noFiles' => '—· ——— / —·· ·— — ·— / ··—· ·· ·—·· · ···',
			'settings.offlineData.noFilesDescription' => '· —· ·— —··· ·—·· · / ·— —·—· — ·· ···— ·· — —·—— / ——— ·—· / ·—·· ——— ——— —·— ··— ·——· / · —··— — · —· ··· ·· ——— —· ··· / — ——— / —·· ——— ·—— —· ·—·· ——— ·— —·· / — ···· · ·· ·—· / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— / ···· · ·—· · ·—·—·—',
			'settings.offlineData.refresh' => '·—· · ··—· ·—· · ··· ····',
			'settings.offlineData.refreshing' => '·—· · ··—· ·—· · ··· ···· ·· —· ——· …',
			'settings.offlineData.updateAll' => '··— ·——· —·· ·— — · / ·— ·—·· ·—··',
			'settings.offlineData.updatingAll' => '··— ·——· —·· ·— — ·· —· ——· / ·— ·—·· ·—·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· …',
			'settings.offlineData.neverDownloaded' => '—· · ···— · ·—· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —··',
			'settings.offlineData.updatedJustNow' => '··— ·——· —·· ·— — · —·· / ·——— ··— ··· — / —· ——— ·——',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '··— ·——· —·· ·— — · —·· / ${days} —·· / ·— ——· ———',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '··— ·——· —·· ·— — · —·· / ${days} —·· / ${hours} ···· / ·— ——· ———',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '··— ·——· —·· ·— — · —·· / ${hours} ···· / ·— ——· ———',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '··— ·——· —·· ·— — · —·· / ${hours} ···· / ${minutes} —— / ·— ——· ———',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '··— ·——· —·· ·— — · —·· / ${minutes} —— / ·— ——· ———',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => '— ···· · / ·—·· ·— ··· — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ···· ·— —·· / ——— —· ·—·· —·—— / ${imported} / ——— ··—· / ${existing} / ·—· · —·—· ——— ·—· —·· ··· / ·— —· —·· / ·—— ·— ··· / —· ——— — / ··— ··· · —·· ·—·—·— / ·—· · ··—· ·—· · ··· ···· / — ——— / ·— —·—· —·—· · ·——· — / ·· — ·—·—·—',
			'settings.offlineData.extensionsSection' => '· —··— — · —· ··· ·· ——— —· ···',
			'settings.profiles.notSet' => '—· ——— — / ··· · —',
			'settings.profiles.personalInfo' => '·——· · ·—· ··· ——— —· ·— ·—·· / ·· —· ··—· ———',
			'settings.profiles.personalInfoNote' => '— ···· ·· ··· / —— ·· ——· ···· — / —··· · / ·· —· —·—· ·—·· ··— —·· · —·· / ·· —· / ——· · —· · ·—· ·— — · —·· / ·—·· ——— ——· ··· / ·—— ···· · —· / ·—· · ·—·· · ···— ·— —· — / ··—· ——— ·—· / ··· ··— —··· —— ·· ··· ··· ·· ——— —· ···',
			'settings.profiles.name' => '—· ·— —— ·',
			'settings.profiles.email' => '· —— ·— ·· ·—··',
			'settings.profiles.club' => '—·—· ·—·· ··— —···',
			'settings.profiles.arrlSection' => '·— ·—· ·—· ·—·· / ··· · —·—· — ·· ——— —·',
			'settings.profiles.racSection' => '·—· ·— —·—· / ··· · —·—· — ·· ——— —·',
			'settings.profiles.section' => '··· · —·—· — ·· ——— —·',
			'settings.search.clear' => '—·—· ·—·· · ·— ·—·',
			'settings.search.hint' => '··· · ·— ·—· —·—· ···· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···',
			'settings.developer.developerModeDescription' => '· —· ·— —··· ·—·· · / —·· · ···— · ·—·· ——— ·——· · ·—· / ·—— ·— ·—· —· ·· —· ——· ··· ——··—— / —·· · —··· ··— ——· / ·—·· ——— ——· ··· ——··—— / ·— —· —·· / — ——— ——— ·—·· ··· ·—·—·—',
			'settings.developer.experiments' => '· —··— ·——· · ·—· ·· —— · —· — ···',
			'settings.developer.showIdleMetrics' => '··· ···· ——— ·—— / ·· —·· ·—·· · / —— · — ·—· ·· —·—· ···',
			'settings.developer.showIdleMetricsDescription' => '··· ···· ——— ·—— / ·· —· / — ···· · / ··· — ·— — ··— ··· / —··· ·— ·—· / ···· ——— ·—— / ·· —·· ·—·· · / — ···· · / · —··— — · —· ··· ·· ——— —· / · —· ——· ·· —· · / ···· ·— ··· / —··· · · —· / ——— ···— · ·—· / — ···· · / ·—·· ·— ··· — / ··· · —·—· ——— —· —·· ·—·—·— / — ·— ·——· / ·· — / ··—· ——— ·—· / — ···· · / ·———— ————— —····— / ·— —· —·· / —···· ————— —····— ··· · —·—· ——— —· —·· / ·— ···— · ·—· ·— ——· · ··· ·—·—·—',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent} % / ·· —·· ·—·· ·',
			'settings.developer.idleMetricsAverages' => '·· —·· ·—·· · / ·— ···— ——· ———···',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds} ··· / ${percent} %',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / · —· ·— —··· ·—·· · —··', other: '${count} / · —· ·— —··· ·—·· · —··', ), 
			'settings.developer.patchTrack' => '—·—· ——— —·· · / ·——· ··— ··· ···· / — ·—· ·— —·—· —·—',
			'settings.developer.patchTrackDescription' => '·—— ···· ·· —·—· ···· / ——— ···— · ·—· —····— — ···· · —····— ·— ·· ·—· / —·—· ——— —·· · / ·——· ··— ··· ···· / ·—· ·· —· ——· / — ···· ·· ··· / —·· · ···— ·· —·—· · / ··—· ——— ·—·· ·—·· ——— ·—— ··· ·—·—·— / —— ——— ·—· · / ·— —·· ···— · —· — ··— ·—· ——— ··— ··· / ·—· ·· —· ——· ··· / ——· · — / ··—· ·· —··— · ··· / · ·— ·—· ·—·· ·· · ·—· ——··—— / ·—·· · ··· ··· / — · ··· — · —·· ·—·—·— / —·—· ——— —·· · / ·——· ··— ··· ···· · ··· / ·— ·——· ·——· ·—·· —·—— / ——— —· / — ···· · / —· · —··— — / ·—· · ··· — ·— ·—· — ·—·—·—',
			'settings.developer.trackStable' => '··· — ·— —··· ·—·· ·',
			'settings.developer.trackUnstable' => '··— —· ··· — ·— —··· ·—·· ·',
			'settings.developer.trackBleeding' => '—··· ·—·· · · —·· ·· —· ——·',
			'settings.developer.checkingTrack' => ({required Object track}) => '—·—· ···· · —·—· —·— ·· —· ——· / ·—··—· ${track} ·—··—· / ··—· ——— ·—· / ·— / —·—· ——— —·· · / ·——· ··— ··· ···· …',
			'settings.developer.patchDownloaded' => '—·—· ——— —·· · / ·——· ··— ··· ···· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· / — / ·—· · ··· — ·— ·—· — / — ···· · / ·— ·——· ·——· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—',
			'settings.developer.noNewPatch' => ({required Object track}) => '—· ——— / —· · ·—— / —·—· ——— —·· · / ·——· ··— ··· ···· / ——— —· / ·—··—· ${track} ·—··—· ·—·—·—',
			'settings.developer.noPatchInstalled' => '—· ——— / —·—· ——— —·· · / ·——· ··— ··· ···· / ·· —· ··· — ·— ·—·· ·—·· · —·· / — / ·—· ··— —· —· ·· —· ——· / — ···· · / ·—· · ·—·· · ·— ··· · / —··· ·· —· ·— ·—· —·—— ·—·—·—',
			'settings.developer.runningPatch' => ({required Object patch}) => '·—· ··— —· —· ·· —· ——· / —·—· ——— —·· · / ·——· ··— ··· ···· / # ${patch} ·—·—·—',
			'settings.developer.deepLinks' => '—·· · · ·——· / ·—·· ·· —· —·— ···',
			'settings.developer.registerUrlSchemes' => '·—· · ——· ·· ··· — · ·—· / ··— ·—· ·—·· / ··· —·—· ···· · —— · ···',
			'settings.developer.registerUrlSchemesDescription' => '·—·· · — / —·—· ——— —— ·—·—·— ···· ·— —— ··——— —·— ———··· —··—· —··—· / ·—·· ·· —· —·— ··· / ——— ·——· · —· / — ···· ·· ··· / —·—· ——— ·——· —·—— / ——— ··—· / — ···· · / ·— ·——· ·——·',
			'settings.developer.registerUrlSchemesDone' => '— ···· ·· ··· / —·—· ——— ·——· —·—— / —· ——— ·—— / ——— ·——· · —· ··· / —·—· ——— —— ·—·—·— ···· ·— —— ··——— —·— ———··· —··—· —··—· / ·—·· ·· —· —·— ···',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ——· ·· ··· — · ·—· ———··· / ${error}',
			'settings.developer.systemInformation' => '··· —·—— ··· — · —— / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·',
			'settings.developer.appVersion' => '·— ·——· ·——· / ···— · ·—· ··· ·· ——— —·',
			'settings.developer.dataFolder' => '—·· ·— — ·— / ··—· ——— ·—·· —·· · ·—·',
			'settings.developer.loading' => '—·——· ·—·· ——— ·— —·· ·· —· ——· … —·——·—',
			'settings.developer.panelLoadFailed' => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—·· ——— ·— —·· / — ···· ·· ··· / ··· · — — ·· —· ——· ··· / ·——· ·— —· · ·—·· ·—·—·—',
			'settings.developer.extDevServer' => '· —··— — · —· ··· ·· ——— —· / —·· · ···— / ··· · ·—· ···— · ·—·',
			'settings.developer.extensionSettings' => '· —··— — · —· ··· ·· ——— —· / ··· · — — ·· —· ——· ···',
			'settings.developer.extDevServerDescription' => '·—·· ——— ·— —·· / · —··— — · —· ··· ·· ——— —· ··· / ··—· ·—· ——— —— / ·— / —·· · ···— / ··· · ·—· ···— · ·—· / ——— —· / —·—— ——— ··— ·—· / —· · — ·—— ——— ·—· —·— / ·· —· ··· — · ·— —·· / ——— ··—· / — ···· · / ——— —· · ··· / —··· ··— ·· ·—·· — / ·· —· — ——— / — ···· · / ·— ·——· ·——· ——··—— / ·— —· —·· / ·—· · ·—·· ——— ·— —·· / — ···· · —— / ·— ··· / —·—— ——— ··— / ··· ·— ···— · ·—·—·—',
			'settings.developer.extDevServerAddress' => '··· · ·—· ···— · ·—· / ·— —·· —·· ·—· · ··· ···',
			'settings.developer.extDevServerHint' => '·———— ————· ··——— ·—·—·— ·———— —···· ———·· ·—·—·— ·———— ·—·—·— ··——— ————— ———··· ———·· ——··· ———·· ——···',
			'settings.developer.extDevServerConnect' => '—·—· ——— —· —· · —·—· —',
			'settings.developer.extDevServerDisconnect' => '—·· ·· ··· —·—· ——— —· —· · —·—· —',
			'settings.developer.extDevServerConnecting' => '—·—· ——— —· —· · —·—· — ·· —· ——· …',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '··· · ·—· ···— ·· —· ——· / ${count} / · —··— — · —· ··· ·· ——— —· ———··· / ${keys}', other: '··· · ·—· ···— ·· —· ——· / ${count} / · —··— — · —· ··· ·· ——— —· ··· ———··· / ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => '—· ——— — / —·—· ——— —· —· · —·—· — · —··',
			'settings.developer.extDevServerReconnect' => '·—· · —·—· ——— —· —· · —·—· — / ·— — / ·—·· ·— ··— —· —·—· ····',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => '·—·· ·— ··· — / ·—· · ·—·· ——— ·— —·· ———··· / ${key} / ·— — / ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / · —··— — · —· ··· ·· ——— —· / ··—· ·— ·· ·—·· ·· —· ——· / — ——— / —··· ··— ·· ·—·· —··', other: '${count} / · —··— — · —· ··· ·· ——— —· ··· / ··—· ·— ·· ·—·· ·· —· ——· / — ——— / —··· ··— ·· ·—·· —··', ), 
			'settings.developer.catalog' => '· —··— — · —· ··· ·· ——— —· / —·—· ·— — ·— ·—·· ——— ——·',
			'settings.developer.catalogDescription' => '·—· · ·— —·· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / ··—· ·—· ——— —— / ·— —· ——— — ···· · ·—· / ··· · ·—· ···— · ·—· / — / ·— / ·—·· ——— —·—· ·— ·—·· / ——— —· · / ·—— ···· ·· ·—·· · / ·—— ——— ·—· —·— ·· —· ——· / ——— —· / — ···· · / —·—· ·— — ·— ·—·· ——— ——· / ·· — ··· · ·—·· ··—· ·—·—·— / · —— ·——· — —·—— / —— · ·— —· ··· / —·—· ·— — ·— ·—·· ——— ——· ·—·—·— ···· ·— —— ··——— —·— ·—·—·— —· · — ·—·—·—',
			'settings.developer.catalogAddress' => '—·—· ·— — ·— ·—·· ——— ——· / ·— —·· —·· ·—· · ··· ···',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => '—·—· ·— — ·— ·—·· ——— ——· / ··· · ·— ·—· —·—· ···· / — ·—· ·— —·—· —·— ···',
			'settings.developer.catalogSearchStable' => '——— —· ·—·· —·—— / ··· — ·— —··· ·—·· ·',
			'settings.developer.catalogSearchUnstable' => '··— —· ··· — ·— —··· ·—·· · / ——— ·—· / —··· · — — · ·—·',
			'settings.developer.catalogSearchBleeding' => '—··· ·—·· · · —·· ·· —· ——· / ——— ·—· / —··· · — — · ·—·',
			'settings.about.notices' => '—· ——— — ·· —·—· · ··· / ·—··· / —— · ··· ··· ·— ——· · ···',
			'settings.about.noticesDescription' => '·— —· —· ——— ··— —· —·—· · —— · —· — ··· / ·— —· —·· / ··· — ·— — ··— ··· / —— · ··· ··· ·— ——· · ···',
			'settings.about.releaseNotes' => '·—· · ·—·· · ·— ··· · / —· ——— — · ···',
			'settings.about.copiedVersion' => '—·—· ——— ·——· ·· · —·· / ···— · ·—· ··· ·· ——— —· / —·· · — ·— ·· ·—·· ··· / — ——— / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··',
			'settings.panels.settings' => '·— ·——· ·——· ·—·· ·· —·—· ·— — ·· ——— —· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···',
			'settings.panels.settingsDescription' => '—— ·— —·— · / — ···· · / ·— ·——· ·——· / ·—— ——— ·—· —·— / ···· ——— ·—— / —·—— ——— ··— / ·—— ·— —· — / ·· —',
			'settings.panels.commonSettings' => '—·—· ——— —— —— ——— —· / ·——· ·—· · ··—· · ·—· · —· —·—· · ···',
			'settings.panels.syncDescription' => '—··· ·— —·—· —·— / ··— ·——· / ·— —· —·· / ··· —·—— —· —·—· / —·—— ——— ··— ·—· / ·—·· ——— ——· ··· / ·— —·—· ·—· ——— ··· ··· / —·· · ···— ·· —·—· · ···',
			'settings.panels.accountsDescription' => '··· · ·—· ···— ·· —·—· · / —·—· ·—· · —·· · —· — ·· ·— ·—·· ··· ——··—— / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— ——··—— / ·— —· —·· / —— ——— ·—· ·',
			'settings.panels.extensions' => '· —··— — · —· ··· ·· ——— —· ··· / ·—··· / ··—· · ·— — ··— ·—· · ···',
			'settings.panels.extensionsDescription' => '·— —·—· — ·· ···— ·· — ·· · ··· ——··—— / —·—· ——— —· — · ··· — ··· ——··—— / —·· ·— ··· ···· —··· ——— ·— ·—· —·· / ·——· ·— —· · ·—·· ··· / ·— —· —·· / —— ——— ·—· · / ··—· · ·— — ··— ·—· · ···',
			'settings.panels.profilesDescription' => '——— ·——· · ·—· ·— — ——— ·—· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·— —· —·· / ··· — ·— — ·· ——— —· / ·——· ·—· ——— ··—· ·· ·—·· ·',
			'settings.panels.stationProfiles' => '··· — ·— — ·· ——— —· / ·——· ·—· ——— ··—· ·· ·—·· · ···',
			'settings.panels.developerSettings' => '—·· · ···— · ·—·· ——— ·——· · ·—· / ··· · — — ·· —· ——· ···',
			'settings.panels.developerSettingsDescription' => '—·· · —··· ··— ——· ——· ·· —· ——· / ·— —· —·· / —·· · ···— · ·—·· ——— ·——· —— · —· — / — ——— ——— ·—·· ···',
			'settings.panels.about' => '·— —··· ——— ··— —',
			'settings.panels.aboutDescription' => '···— · ·—· ··· ·· ——— —· ——··—— / —·—· ·—· · —·· ·· — ··· ——··—— / ·— —· —·· / ·—·· · ——· ·— ·—·· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —·',
			'settings.panels.unavailableTitle' => '··· ——— —— · / ··· · — — ·· —· ——· ··· / ·— ·—· · / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'settings.panels.unavailableText' => '— ···· · / · —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / ··—· ·— ·· ·—·· · —·· / — ——— / ··· — ·— ·—· — ——··—— / ··· ——— / · —··— — · —· ··· ·· ——— —· —····— —·—· ——— —· — ·—· ·· —··· ··— — · —·· / ··· · — — ·· —· ——· ··· / ·— ·—· · / —— ·· ··· ··· ·· —· ——· ·—·—·—',
			'settings.panels.station' => '··· — ·— — ·· ——— —· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'settings.panels.stationDescription' => '—·—· ·— — / —·—· ——— —· — ·—· ——— ·—·· / ·— —· —·· / —— ——— ·—· · / ——— ·——· — ·· ——— —· ···',
			'settings.panels.peers' => '·——· · · ·—· / —·· · ···— ·· —·—· · ···',
			'settings.panels.peersDescription' => '—·—· ——— —· —· · —·—· — / — ——— / ——— — ···· · ·—· / —·· · ···— ·· —·—· · ··· / —· · ·— ·—· —··· —·——',
			'settings.showMoreSettings' => '··· ···· ——— ·—— / —— ——— ·—· · / ··· · — — ·· —· ——· ···',
			'settings.numberFormat' => '—· ··— —— —··· · ·—· / ··—· ——— ·—· —— ·— — — ·· —· ——·',
			'settings.numberFormatOpts.locale' => '··—· ——— ·—·· ·—·· ——— ·—— / ··· —·—— ··· — · —— / ··· · — — ·· —· ——· ···',
			'settings.numberFormatOpts.period' => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· · / ·——· · ·—· ·· ——— —·· / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···',
			'settings.numberFormatOpts.comma' => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· · / —·—· ——— —— —— ·— / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => '··· —·—— ··· — · —— / ··· · — — ·· —· ——· ··· / —·——· ··— ··· ·· —· ——· / ${separator} / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ··· —·——·—',
			'settings.numberFormatDescription.period' => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / ·——· · ·—· ·· ——— —·· / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···',
			'settings.numberFormatDescription.comma' => '·— ·—·· ·—— ·— —·—— ··· / ··— ··· ·· —· ——· / —·—· ——— —— —— ·— / ··—· ——— ·—· / —·· · —·—· ·· —— ·— ·—·· ···',
			'settings.numberFormatSeparators.comma' => '—·—· ——— —— —— ·—',
			'settings.numberFormatSeparators.period' => '·——· · ·—· ·· ——— —··',
			_ => null,
		} ?? switch (path) {
			'settings.gridPrecision' => '——· ·—· ·· —·· / ·——· ·—· · —·—· ·· ··· ·· ——— —·',
			'settings.gridPrecisionOpts.six' => '—···· / —·· ·· ——· ·· — ··· / —·——· ··—· —· ···—— ·———— ·——· ·—· —·——·—',
			'settings.gridPrecisionOpts.eight' => '———·· / —·· ·· ——· ·· — ··· / —·——· ··—· —· ···—— ·———— ·——· ·—· ····· ····· —·——·—',
			'settings.gridPrecisionDescription.six' => '—···· / —·· ·· ——· ·· — ···',
			'settings.gridPrecisionDescription.eight' => '———·· / —·· ·· ——· ·· — ···',
			'commands.enableSyncFirst' => '· —· ·— —··· ·—·· · / ··· —·—— —· —·—· / ·· —· / ··· · — — ·· —· ——· ··· / ··—· ·· ·—· ··· — ·—·—·—',
			'commands.fullResyncStarted' => '··—· ··— ·—·· ·—·· / ·—· · ··· —·—— —· —·—· / ··· — ·— ·—· — · —·· / — / ·—·· ——— —·—· ·— ·—·· / —·· ·— — ·— / ·—— ·— ··· / —··· ·— —·—· —·— · —·· / ··— ·——· / ··—· ·· ·—· ··· — ·—·—·—',
			'commands.noDataFilesMatched' => ({required Object target}) => '—· ——— / —·· ·— — ·— / ··—· ·· ·—·· · ··· / —— ·— — —·—· ···· · —·· / ·—··—· ${target} ·—··—· ·—·—·—',
			'commands.reloadFailed' => ({required Object error}) => '·—· · ·—·· ——— ·— —·· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'commands.reloadingAll' => '·—· · ·—·· ——— ·— —·· ·· —· ——· / ·— ·—·· ·—·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· …',
			'commands.reloadingTarget' => ({required Object target}) => '·—· · ·—·· ——— ·— —·· ·· —· ——· / ${target} / —·· ·— — ·— / ··—· ·· ·—·· · ··· …',
			'commands.unknownExperiment' => ({required Object token}) => '··— —· —·— —· ——— ·—— —· / · —··— ·——· · ·—· ·· —— · —· — / ·—··—· ${token} ·—··—·',
			'commands.experimentEnabled' => ({required Object name}) => '${name} / · —· ·— —··· ·—·· · —··',
			'commands.experimentDisabled' => ({required Object name}) => '${name} / —·· ·· ··· ·— —··· ·—·· · —··',
			'commands.sentryTestSent' => '— · ··· — / · ·—· ·—· ——— ·—· / ·—· · ·——· ——— ·—· — / ··· · —· — / — ——— / ··· · —· — ·—· —·——',
			'commands.idleMetricsEnabled' => '·· —·· ·—·· · / —— · — ·—· ·· —·—· ··· / · —· ·— —··· ·—·· · —·· / ·· —· / — ···· · / ··· — ·— — ··— ··· / —··· ·— ·—·',
			'commands.idleMetricsDisabled' => '·· —·· ·—·· · / —— · — ·—· ·· —·—· ··· / —·· ·· ··· ·— —··· ·—·· · —··',
			'commands.sentryTestLocalOnly' => '··· · —· — ·—· —·—— / ·· ··· / —·· ·· ··· ·— —··· ·—·· · —·· / ·· —· / — ···· ·· ··· / —··· ··— ·· ·—·· —·· / — / — · ··· — / · ·—· ·—· ——— ·—· / ·—·· ——— ——· ——· · —·· / ·—·· ——— —·—· ·— ·—·· ·—·· —·—— / ——— —· ·—·· —·——',
			'commands.noOperationOpen' => '— ···· ·— — / —·—· ——— —— —— ·— —· —·· / —· · · —·· ··· / ·— —· / ——— ·——· · —· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'commands.unknownSegmentKind' => ({required Object kind}) => '—·· ——— —· ·————· — / —·— —· ——— ·—— / ···· ——— ·—— / — ——— / —— ·— ·—· —·— / ·— / ·————· ${kind} ·————·',
			'commands.goUnavailable' => ({required Object place}) => '${place} / ·· ··· —· ·————· — / — ··— ·—· —· · —·· / ——— —· / ·· —· / — ···· ·· ··· / ·— ·——· ·——·',
			'commands.goUnknown' => ({required Object to}) => '—·· ——— —· ·————· — / —·— —· ——— ·—— / ···· ——— ·—— / — ——— / ——· ——— / — ——— / ·————· ${to} ·————·',
			'commands.goBlocked' => '—·—· ·—·· ——— ··· · / — ···· · / ——— ·——· · —· / —·· ·· ·— ·—·· ——— ——· / ··—· ·· ·—· ··· —',
			'commands.operationAlreadyStarted' => '— ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —· / ·— ·—·· ·—· · ·— —·· —·—— / ···· ·— ··· / ·— / ··· — ·— ·—· — / —— ·— ·—· —·— · ·—·',
			'commands.couldNotOpenLocation' => '·— —·· —·· · —·· / — ···· · / —··· ·—· · ·— —·— ——··—— / —··· ··— — / —·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / — ···· · / ·—·· ——— —·—· ·— — ·· ——— —· / ··· —·—· ·—· · · —·',
			'commands.noTestOperations' => '—· ——— / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — ——— / ·——· ··— ·—· ——· ·',
			'commands.purgeTestsUnavailable' => '·——· ··— ·—· ——· · — · ··· — ··· / —· · · —·· ··· / — ——— / ··· ···· ——— ·—— / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·· ·· ·— ·—·· ——— ——· ——··—— / ·—— ···· ·· —·—· ···· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· ·',
			'commands.syncAllUnavailable' => '··· —·—— —· —·—· ·— ·—·· ·—·· / —· · · —·· ··· / — ——— / ··· ···· ——— ·—— / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·· ·· ·— ·—·· ——— ——· ——··—— / ·—— ···· ·· —·—· ···· / ·· ··· —· ·————· — / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ···· · ·—· ·',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —·', other: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ···', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '·——· ··— ·—· ——· · —·· / ${purged} / ——— ··—· / ${total} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ···· · / ·—· · ··· — / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·——· ··— ·—· ——· · — · ··· — ··· / ·— ——· ·— ·· —·',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —·', other: '·——· ··— ·—· ——· · —·· / ${count} / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —·', ), 
			'commands.purgeTestsContactsFailed' => '·——· ··— ·—· ——· · —·· / — ···· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· ——··—— / —··· ··— — / — ···· · / — · ··· — / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· — ···· / —· ——— / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·——· ··— ·—· ——· · — · ··· — ··· / ·— ——· ·— ·· —·',
			'commands.purgeTestsNothingToDo' => '—· ——— — ···· ·· —· ——· / ·—— ·— ··· / ·——· ··— ·—· ——· · —··',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '·—· · —— ——— ···— · —·· / ${removed} / ——— ··—· / ${total} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ···· · / ·—· · ··· — / ··—· ·— ·· ·—·· · —·· —·—·—· / — ·—· —·—— / ·—· · ···— ·· · ·—— / ·— ——· ·— ·· —·',
			'commands.receivedPurgesFailed' => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·—· · —— ——— ···— · / — ···· ——— ··· · / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / — / — ·—· —·—— / ·—· · ···— ·· · ·—— / ·— ——· ·— ·· —·',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· / ·—— ·— ··· / ·—· · —— ——— ···— · —·· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·', other: '${count} / — · ··· — / ——— ·——· · ·—· ·— — ·· ——— —· ··· / ·—— · ·—· · / ·—· · —— ——— ···— · —·· / ——— —· / ·— —· ——— — ···· · ·—· / —·· · ···— ·· —·—· ·', ), 
			'commands.receivedPurgesReview' => '·—· · ···— ·· · ·——',
			'commands.settingOn' => '——— —·',
			'commands.settingOff' => '——— ··—· ··—·',
			'commands.settingEmpty' => '—·——· · —— ·——· — —·—— —·——·—',
			'commands.settingSecretSet' => '—·——· ··· · — —·——·—',
			'commands.settingSecretUnset' => '—·——· —· ——— — / ··· · — —·——·—',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} / ··· · ·—·· · —·—· — · —··',
			'commands.settingExpectsOnOff' => '——— —· / ——— ·—· / ——— ··—· ··—·',
			'commands.settingExpectsOneOf' => ({required Object choices}) => '——— —· · / ——— ··—· ———··· / ${choices}',
			'commands.settingExpectsNumber' => '·— / —· ··— —— —··· · ·—·',
			'commands.settingVanished' => ({required Object label}) => '“ ${label} ” / ·· ··· / —· ——— / ·—·· ——— —· ——· · ·—· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'commands.noCwKeyer' => '—· ——— / —·—· ——— —· —· · —·—· — · —·· / ·—· ·— —·· ·· ——— / —·—· ·— —· / —·— · —·—— / —·—· ·——',
			'commands.noKeyer' => '—· ——— / —·—· ——— —· —· · —·—· — · —·· / ·—· ·— —·· ·· ——— / —·—· ·— —· / —·— · —·—— / —·—· ·—— / ——— ·—· / ·——· ·—·· ·— —·—— / ···— ——— ·· —·—· · / —— · —— ——— ·—· ·· · ···',
			'commands.keyerNeedsOperation' => '——— ·——· · —· / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / — ——— / ··— ··· · / — ···· · / —·—· ·—— / —·— · —·—— · ·—·',
			'commands.keyerExperimentOff' => '—·—· ·—— / —·— · —·—— ·· —· ——· / ·· ··· / ——— ··—· ··—· / — / — ··— ·—· —· / ·· — / ——— —· / ·—— ·· — ···· / · —··— ·——· / —·— · —·—— · ·—·',
			'commands.esmExperimentOff' => '· —· — · ·—· / ··· · —· —·· ··· / —— · ··· ··· ·— ——· · ··· / ·· ··· / ——— ··—· ··—· / — / — ··— ·—· —· / ·· — / ——— —· / ·—— ·· — ···· / · —··— ·——· / · ··· ——',
			'commands.cwSending' => ({required Object text}) => '··· · —· —·· ·· —· ——· / —·—· ·—— ———··· / ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => '—·—· ·—— / —— · ··· ··· ·— ——· · / ··—· ${n} ———··· / ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => '—·—· ·—— / —— · ··· ··· ·— ——· · / ··—· ${n} / ·—— ·— ··· / —· ——— — / ··· · —· — ———··· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / —· ——— — / ·—· · ·— —·· —·——',
			'commands.settingNotStored' => ({required Object label}) => '“ ${label} ” / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· ·— — / ···— ·— ·—·· ··— ·',
			'commandDialog.hint' => '··· · ·— ·—· —·—· ···· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· / ——— ·—· / — —·—— ·——· · / ·— / —·—· ——— —— —— ·— —· —··',
			'commandDialog.noResults' => ({required Object text}) => '—· ——— — ···· ·· —· ——· / —— ·— — —·—· ···· · ··· / “ ${text} ”',
			'commandDialog.sectionCommands' => '—·—· ——— —— —— ·— —· —·· ···',
			'commandDialog.sectionGoTo' => '——· ——— / — ———',
			'commandDialog.sectionOperations' => '——— ·——· · ·—· ·— — ·· ——— —· ···',
			'commandDialog.goHome' => '···· ——— —— ·',
			'commandDialog.goSettings' => '··· · — — ·· —· ——· ···',
			'commandDialog.goNewOperation' => '—· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·',
			'commandDialog.runTyped' => ({required Object text}) => '·—· ··— —· / “ ${text} ”',
			'commandDialog.sectionSuggestions' => '— ·—· —·——',
			'commandDialog.lookingUp' => '·—·· ——— ——— —·— ·· —· ——· / ··— ·——· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· …',
			'commandDialog.blockedByPane' => '—·—· ·— —· —· ——— — / ··— ··· · / —·—· ——— —— —— ·— —· —·· ··· / ·—— ···· ·· ·—·· · / ·— / ·——· ·— —· · ·—·· / ——— ·—· / —·· ·· ·— ·—·· ——— ——· / ·· ··· / ——— ·——· · —·',
			'keyboardShortcuts.title' => '—·— · —·—— —··· ——— ·— ·—· —·· / ··· ···· ——— ·—· — —·—· ··— — ···',
			'keyboardShortcuts.description' => '—·—· ··— ··· — ——— —— ·· ——·· · / —·— · —·—— / —— ·— ·——· ·——· ·· —· ——· ···',
			'keyboardShortcuts.search' => '··· · ·— ·—· —·—· ···· / —·—· ——— —— —— ·— —· —·· ··· / ·— —· —·· / —·— · —·—— ···',
			'keyboardShortcuts.import' => '·· —— ·——· ——— ·—· — …',
			'keyboardShortcuts.export' => '· —··— ·——· ——— ·—· — …',
			'keyboardShortcuts.resetAll' => '·—· · ··· · — / ·— ·—·· ·—··',
			'keyboardShortcuts.resetAllTitle' => '·—· · ··· · — / · ···— · ·—· —·—— / ··· ···· ——— ·—· — —·—· ··— — ··——··',
			'keyboardShortcuts.resetAllBody' => '· ···— · ·—· —·—— / —·—· ——— —— —— ·— —· —·· / ——· ——— · ··· / —··· ·— —·—· —·— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — / —·— · —·—— ··· ——··—— / ·— —· —·· / — ···· · / —·— · —·—— ··· / —··· ——— ··— —· —·· / — ——— / — —·—— ·——· · —·· / —·—· ——— —— —— ·— —· —·· ··· / ·— ·—· · / ·—· · —— ——— ···— · —·· ·—·—·—',
			'keyboardShortcuts.reset' => '·—· · ··· · —',
			'keyboardShortcuts.noKey' => '—· ——— / —·— · —·——',
			'keyboardShortcuts.changed' => '—·—· ···· ·— —· ——· · —··',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} / ·· ··· / ·— ·—·· ··· ——— / —··· ——— ··— —· —·· / — ——— / ${commands}',
			'keyboardShortcuts.groupApp' => '·— ·——· ·——·',
			'keyboardShortcuts.groupKeying' => '—·— · —·—— ·· —· ——·',
			'keyboardShortcuts.groupLogging' => '·—·· ——— ——· ——· ·· —· ——·',
			'keyboardShortcuts.groupCommands' => '—·—· ——— —— —— ·— —· —·· ···',
			'keyboardShortcuts.groupFixed' => '··—· ·· —··— · —·· / —·— · —·—— ···',
			'keyboardShortcuts.contextApp' => '·— —· —·—— ·—— ···· · ·—· ·',
			'keyboardShortcuts.contextLogView' => '——— ·——· · ·—· ·— — ·· ——— —· ——··—— / —·—· ···· ·— ··· ·· —· ——· / ·— —· —·· / ·—·· ——— ——· ··· / ···— ·· · ·—— ···',
			'keyboardShortcuts.contextOperation' => '——— ·——· · ·—· ·— — ·· ——— —· / ···— ·· · ·—— ——··—— / —·— · —·—— ·· —· ——· / ·— / —·—· ·— — / ·—· ·— —·· ·· ———',
			'keyboardShortcuts.contextLogging' => '·· —· / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ·——· ·— —· · ·—··',
			'keyboardShortcuts.addCommand' => '·— —·· —·· / ·— / —·—· ——— —— —— ·— —· —·· …',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => '··— —· —·— —· ——— ·—— —· / —·—· ——— —— —— ·— —· —·· ———··· / ${command}',
			'keyboardShortcuts.command.commandDialog' => '——— ·——· · —· / — ···· · / —·—· ——— —— —— ·— —· —·· / —·· ·· ·— ·—·· ——— ——·',
			'keyboardShortcuts.command.toggleTheme' => '··· ·—— ·· — —·—· ···· / —··· · — ·—— · · —· / ·—·· ·· ——· ···· — / ·— —· —·· / —·· ·— ·—· —·—',
			'keyboardShortcuts.command.toggleLanguage' => '··· ·—— ·· — —·—· ···· / —··· · — ·—— · · —· / · —· ——· ·—·· ·· ··· ···· / ·— —· —·· / ··· ·——· ·— —· ·· ··· ····',
			'keyboardShortcuts.command.fontScaleUp' => '·—·· ·— ·—· ——· · ·—· / — · —··— —',
			'keyboardShortcuts.command.fontScaleDown' => '··· —— ·— ·—·· ·—·· · ·—· / — · —··— —',
			'keyboardShortcuts.command.fontScaleReset' => '—· ——— ·—· —— ·— ·—·· / — · —··— — / ··· ·· ——·· ·',
			'keyboardShortcuts.command.densityLooser' => '·—· ——— ——— —— ·· · ·—· / ·—·· ·— —·—— ——— ··— —',
			'keyboardShortcuts.command.densityDenser' => '—·· · —· ··· · ·—· / ·—·· ·— —·—— ——— ··— —',
			'keyboardShortcuts.command.densityAuto' => '·— ··— — ——— —— ·— — ·· —·—· / ·—·· ·— —·—— ——— ··— — / —·· · —· ··· ·· — —·——',
			'keyboardShortcuts.command.find' => '··—· ·· —· —·· / ·· —· / — ···· · / ·—·· ——— ——·',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => '··· · —· —·· / —— · ··· ··· ·— ——· · / ${n}',
			'keyboardShortcuts.command.keyboardMode' => '—·— · —·—— —··· ——— ·— ·—· —·· / —— ——— —·· · / ——— —· / ——— ·—· / ——— ··—· ··—·',
			'keyboardShortcuts.command.ptt' => '·——· ··— ··· ···· / — ——— / — ·— ·—·· —·—',
			'keyboardShortcuts.command.wipe' => '—·—· ·—·· · ·— ·—· / — ···· · / —·—· ——— —· — ·— —·—· — / —··· · ·· —· ——· / ·—·· ——— ——· ——· · —··',
			'keyboardShortcuts.fixed.callsign' => '— —·—— ·——· ·· —· ——· / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ···',
			'keyboardShortcuts.fixed.escape' => '··· — ——— ·——· / ··· · —· —·· ·· —· ——· ——··—— / —··· ·— —·—· —·— / ——— ··— — / ——— —· · / ··· — · ·——· ——··—— / ——— ·—· / —·—· ·—·· ——— ··· ·',
			'keyboardShortcuts.fixed.enter' => '·—·· ——— ——· / — ···· · / —·—· ——— —· — ·— —·—· —',
			'keyboardShortcuts.fixed.space' => '—· · —··— — / ··—· ·· · ·—·· —··',
			'keyboardShortcuts.fixed.tab' => '—· · —··— — / ——— ·—· / ·——· ·—· · ···— ·· ——— ··— ··· / ··—· ·· · ·—·· —··',
			'keyboardShortcuts.fixed.arrows' => '—— ——— ···— · / —··· · — ·—— · · —· / ··—· ·· · ·—·· —·· ··· ——··—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ·— —· —·· / — ···· · / ·—·· ——— ——·',
			'keyboardShortcuts.fixed.walk' => '·——· ·— ——· · / — ···· ·—· ——— ··— ——· ···· / — ···· · / ·—·· ——— ——· ——··—— / ——— ·—· / ——· ——— / — ——— / ·· — ··· / · —· —·· ···',
			'keyboardShortcuts.fixed.undo' => '— ·— —·— · / —··· ·— —·—· —·— / ·— / ·—— ·· ·——· · / ——— ·—· / ·— / —·· · ·—·· · — ·',
			'keyboardShortcuts.editor.addShortcut' => '·— —·· —·· / ··· ···· ——— ·—· — —·—· ··— —',
			'keyboardShortcuts.editor.listening' => '·——· ·—· · ··· ··· / — ···· · / —·— · —·—— ··· / ··—· ——— ·—· / — ···· · / ··· ···· ——— ·—· — —·—· ··— — …',
			'keyboardShortcuts.editor.listeningHint' => '· ··· —·—· / ··· — ——— ·——· ··· / ·—·· ·· ··· — · —· ·· —· ——·',
			'keyboardShortcuts.editor.add' => '·— —·· —··',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} / —··· · ·—·· ——— —· ——· ··· / — ——— / — ···· · / ·—·· ——— ——· ——· ·· —· ——· / ··—· ·· · ·—·· —·· ··· / ——— ·—· / ·— / —·· ·· ·— ·—·· ——— ——· ——··—— / ·— —· —·· / —·—· ·— —· ’ — / —··· · / —·—· ···· ·— —· ——· · —·· ·—·—·—',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} / ·· ··· / ···· ——— ·—— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· ··· / ·— ·—· · / — —·—— ·——· · —·· ·—·—·— / ···· ——— ·—·· —·· / —·—· —— —·· ——··—— / —·—· — ·—· ·—·· / ——— ·—· / ·— ·—·· — / ·—— ·· — ···· / ·· — ·—·—·—',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => '— ···· · / ··· —·—— ··· — · —— / —— ·— —·—— / — ·— —·— · / ${keys} / —··· · ··—· ——— ·—· · / — ···· · / ·— ·——· ·——· / ··· · · ··· / ·· — ·—·—·—',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ——— —· · / ——— ··—· / — ···· ·· ··· / —·—· ——— —— —— ·— —· —·· ’ ··· / —·— · —·—— ··· ·—·—·—',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => '— ·— —·— · / ${keys} / ··—· ·—· ——— —— / “ ${command} ”',
			'keyboardShortcuts.editor.resetDefault' => '·—· · ··· · — / — ——— / —·· · ··—· ·— ··— ·—·· —',
			'keyboardShortcuts.editor.remove' => '·—· · —— ——— ···— ·',
			'keyboardShortcuts.editor.commandLabel' => '—·—· ——— —— —— ·— —· —··',
			'keyboardShortcuts.editor.commandHint' => '· —· — · ·—· / ·— —· —·—— / ···— ·— ·—·· ·· —·· / —·—· ——— —— —— ·— —· —·· ——··—— / ——— ·—· / —— ··— ·—·· — ·· ·——· ·—·· · / —·—· ——— —— —— ·— —· —·· ··· / ··· · ·——· ·— ·—· ·— — · —·· / —··· —·—— / ·—··—· —·—·—· ·—··—·',
			'keyboardShortcuts.editor.removeCommand' => '·—· · —— ——— ···— · / —·—· ——— —— —— ·— —· —··',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => '—· ——— / —·—· ——— —— —— ·— —· —·· / ·—· · ·— —·· ··· / “ ${text} ”',
			'keyboardShortcuts.editor.noShortcuts' => '—· ——— / —·— · —·—— / —·—— · —',
			'keyboardShortcuts.file.exported' => ({required Object location}) => '··· ···· ——— ·—· — —·—· ··— — ··· / ··· ·— ···— · —·· / — ——— / ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / · —··— ·——· ——— ·—· — / — ···· · / ··· ···· ——— ·—· — —·—· ··— — ··· ———··· / ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· —· ’ — / ——— ·——· · —· / — ···· · / ··—· ·· ·—·· · ———··· / ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} / ·· ··· —· ’ — / ·— / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ·· ·—·· · / — ···· ·· ··· / ·— ·——· ·——· / —·—· ·— —· / ·—· · ·— —·· ———··· / ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => '— ···· · / — · —··— — / ·· ··· —· ’ — / ···— ·— ·—·· ·· —·· / —·—— ·— —— ·—·· / —·——· ·—·· ·· —· · / ${line} —·——·—',
			'keyboardShortcuts.file.problemNotKeysFile' => '·· — / ·· ··· —· ’ — / ·— / ···· ·— —— ··——— —·— / —·— · —·—— —··· ——— ·— ·—· —·· / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ·· ·—·· ·',
			'keyboardShortcuts.file.problemNewerVersion' => '·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· · / ·— ·——· ·——·',
			'keyboardShortcuts.file.problemMalformed' => '·——· ·— ·—· — / ——— ··—· / ·· — / —·· ——— · ··· —· ’ — / ··—· ——— ·—·· ·—·· ——— ·—— / — ···· · / ··· ···· ——— ·—· — —·—· ··— — ··· / ··—· ——— ·—· —— ·— —',
			'keyboardShortcuts.file.problemTooLarge' => '·· — / ·· ··· / — ——— ——— / ·—·· ·— ·—· ——· ·',
			'keyboardShortcuts.file.importTitle' => '·· —— ·——· ——— ·—· — / ··· ···· ——— ·—· — —·—· ··— — ···',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => '·—— ·—· ·· — — · —· / ——— —· / ${platform} ·—·—·—',
			'keyboardShortcuts.file.writtenOnUnknown' => '— ···· · / ··—· ·· ·—·· · / —·· ——— · ··· —· ’ — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / —·— · —·—— —··· ——— ·— ·—· —·· / ·· — / ·—— ·— ··· / ·—— ·—· ·· — — · —· / ——— —· ·—·—·—',
			'keyboardShortcuts.file.translate' => '·—— ···· ·— — / ··· ···· ——— ··— ·—·· —·· / · ·— —·—· ···· / ——— ··—· / — ···· · ··· · / —·— · —·—— ··· / —··· · / ——— —· / — ···· ·· ··· / —·— · —·—— —··· ——— ·— ·—· —·· ··——··',
			'keyboardShortcuts.file.leaveOut' => '·—·· · ·— ···— · / — ···· ——— ··· · / ··· ···· ——— ·—· — —·—· ··— — ··· / ——— ··— —',
			'keyboardShortcuts.file.replace' => '·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / —·—· ——— —· ··—· ·· ——·',
			'keyboardShortcuts.file.replaceHint' => '· ···— · ·—· —·—— / ··· ···· ——— ·—· — —·—· ··— — / —· ——— — / ·· —· / — ···· · / ··—· ·· ·—·· · / ——· ——— · ··· / —··· ·— —·—· —·— / — ——— / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ·—·—·—',
			'keyboardShortcuts.file.merge' => '·— —·· —·· / — ——— / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / —·—· ——— —· ··—· ·· ——·',
			'keyboardShortcuts.file.mergeHint' => '— ···· · / ··—· ·· ·—·· · ’ ··· / ··· ···· ——— ·—· — —·—· ··— — ··· / ·—· · ·——· ·—·· ·— —·—· · / — ···· ·· ··· / —·· · ···— ·· —·—· · ’ ··· / ··—· ——— ·—· / — ···· · / ··· ·— —— · / —·—· ——— —— —— ·— —· —·· ··· ——··—— / ·— —· —·· / — ···· · / ·—· · ··· — / ··· — ·— —·—— ·—·—·—',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => '—· ——— — / —·— —· ——— ·—— —· / ·· —· / — ···· ·· ··· / ···— · ·—· ··· ·· ——— —· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => '—· ——— — / ··· ···· ——— ·—· — —·—· ··— — ··· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => '—·— · —·—— ··· / — ···· · / ·— ·——· ·——· / —·— · · ·——· ··· / ··—· ——— ·—· / ·· — ··· · ·—·· ··—· ——··—— / ··· ——— / ·—·· · ··—· — / ——— ··— — ———··· / ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => '—··· ——— ··— —· —·· / — ——— / —— ——— ·—· · / — ···· ·— —· / ——— —· · / —·—· ——— —— —— ·— —· —·· / ·— ··—· — · ·—· / — ···· · / ·· —— ·——· ——— ·—· — ———··· / ${keys}',
			'keyboardShortcuts.file.importAction' => '·· —— ·——· ——— ·—· —',
			'keyboardShortcuts.file.imported' => '··· ···· ——— ·—· — —·—· ··— — ··· / ·· —— ·——· ——— ·—· — · —··',
			'keyboardShortcuts.modifier.cmd' => '⌘ / —·—· ——— —— —— ·— —· —··',
			'keyboardShortcuts.modifier.ctrl' => '—·—· — ·—· ·—··',
			'keyboardShortcuts.modifier.meta' => '·—— ·· —· —·· ——— ·—— ··· / —··—· / ··· ··— ·——· · ·—·',
			'keyboardShortcuts.platform.macos' => '—— ·— —·—· ——— ···',
			'keyboardShortcuts.platform.ios' => '·· ·——· ·— —·· ——— ···',
			'keyboardShortcuts.platform.windows' => '·—— ·· —· —·· ——— ·—— ···',
			'keyboardShortcuts.platform.linux' => '·—·· ·· —· ··— —··—',
			'keyboardShortcuts.platform.android' => '·— —· —·· ·—· ——— ·· —··',
			'expiredBuild.title' => '— ···· ·· ··· / —··· ··— ·· ·—·· —·· / ···· ·— ··· / · —··— ·——· ·· ·—· · —··',
			'expiredBuild.body' => '·——· ·—·· · ·— ··· · / ···— ·· ··· ·· — / ···· ·— —— ··——— —·— ·—·—·— —·—· ——— —— / ·— —· —·· / ——· · — / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· ·—·—·—',
			'expiredBuild.visit' => '···— ·· ··· ·· — / ···· ·— —— ··——— —·— ·—·—·— —·—· ——— ——',
			'expiredBuild.dismiss' => '—·—· ——— —· — ·· —· ··— · / ·— —· —·—— ·—— ·— —·——',
			'staleness.codePushFloorTitle' => '·— —· / ·· —— ·——· ——— ·—· — ·— —· — / ··— ·——· —·· ·— — · / ·· ··· / ·—— ·— ·· — ·· —· ——·',
			'staleness.codePushFloorBody' => '— ···· ·· ··· / ···— · ·—· ··· ·· ——— —· / ···· ·— ··· / ·— / ··—· ·· —··— / —·—— ——— ··— / —·· ——— —· ·————· — / ···· ·— ···— · / —·—— · — ·—·—·—',
			'staleness.restartToApply' => '·—· · ··· — ·— ·—· — / — ···· · / ·— ·——· ·——· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—',
			'staleness.quitAndReopen' => '——·— ··— ·· — / — ···· · / ·— ·——· ·——· / ·— —· —·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—',
			'staleness.reopenToApply' => '—·—· ·—·· ——— ··· · / — ···· · / ·— ·——· ·——· / ·— —· —·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—',
			'staleness.ignoreForNow' => '·· ——· —· ——— ·—· · / ··—· ——— ·—· / —· ——— ·——',
			'spotting.noQsoYet' => '—· ——— / ——·— ··· ——— / ·—·· ——— ——· ——· · —·· / —·—— · — / — ——— / ··· ·——· ——— — ·—·—·—',
			'spotting.setFrequencyFirst' => '··· · — / ·— / ··—· ·—· · ——·— ··— · —· —·—· —·—— / ··—· ·· ·—· ··· — ·—·—·—',
			'spotting.nothingToSpot' => '—· ——— — ···· ·· —· ——· / — ——— / ··· ·——· ——— — / — / —· ——— / · —··— — · —· ··· ·· ——— —· / ——— ··—· ··—· · ·—· ··· / ··· ·——· ——— — — ·· —· ——· / ···· · ·—· · ·—·—·—',
			'spotting.incompleteCall' => '—·—· ·— —· ·————· — / ··· ·——· ——— — / ·— —· / ·· —· —·—· ——— —— ·——· ·—·· · — · / —·—· ·— ·—·· ·—·· / — / ··—· ·· —· ·· ··· ···· / — ···· · / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ··—· ·· ·—· ··· — ·—·—·—',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} / ··—· ·— ·· ·—·· · —·· ———··· / ${message}',
			'spotting.unknownError' => '··— —· —·— —· ——— ·—— —· / · ·—· ·—· ——— ·—·',
			'spotting.notSent' => '··· ·——· ——— — / —· ——— — / ··· · —· — ·—·—·—',
			'spotting.allSkipped' => '··· ·——· ——— — / —· ——— — / ··· · —· — ———··· / · ···— · ·—· —·—— / ··· ·——· ——— — / ··· ——— ··— ·—· —·—· · / ··· —·— ·· ·——· ·——· · —·· / ·· — ·—·—·—',
			'spotting.notRefreshedOffline' => '—· ——— / —·—· ——— —· —· · —·—· — ·· ——— —· / — / ··· ·——· ——— — ··· / ·—— · ·—· · / —· ——— — / ·—· · ··—· ·—· · ··· ···· · —··',
			'dataFiles.downloading' => '—·· ——— ·—— —· ·—·· ——— ·— —·· ·· —· ——· …',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / —·· ——— ·—— —· ·—·· ——— ·— —·· / ${name}',
			'dataFiles.downloadFailedWebHint' => '— ···· ·· ··· / —·—· ——— ··— ·—·· —·· / —··· · / ·— / —· · — ·—— ——— ·—· —·— / ·· ··· ··· ··— · ——··—— / ——— ·—· / — ···· ·· ··· / ·—·· ·· —· —·— ·————· ··· / ···· ——— ··· — / —— ·— —·—— / —· ——— — / ··· ··— ·——· ·——· ——— ·—· — / —·· ·· ·—· · —·—· — / —·· ——— ·—— —· ·—·· ——— ·— —·· ··· / ··—· ·—· ——— —— / ·— / ·—— · —··· / —··· ·—· ——— ·—— ··· · ·—· ·—·—·— / — ·—· —·—— / — ···· · / —·· · ··· —·— — ——— ·——· / ——— ·—· / —— ——— —··· ·· ·—·· · / ·— ·——· ·——· ——··—— / ——— ·—· / ·— / —·· ·· ··—· ··—· · ·—· · —· — / ···· ——— ··· — ·· —· ——· / ·—·· ——— —·—· ·— — ·· ——— —· ·—·—·—',
			'dataFiles.downloadTimedOut' => '— ···· · / ··· · ·—· ···— · ·—· / — ——— ——— —·— / — ——— ——— / ·—·· ——— —· ——· / — ——— / ·—· · ··· ·——· ——— —· —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} / ·— —· ··· ·—— · ·—· · —·· / ·—— ·· — ···· / ·— —· / · ·—· ·—· ——— ·—· / —·——· ···· — — ·——· / ${status} —·——·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} / —·—· ——— ··— ·—·· —·· —· ·————· — / ·——· ·—· ——— ···— ·· —·· · / — ···· ·· ··· / ··—· ·· ·—·· · / —·——· ···· — — ·——· / ${status} —·——·— ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / ·· — ··· / ·— —·· —·· ·—· · ··· ··· / ·· ··· / ··· — ·· ·—·· ·—·· / ·—· ·· ——· ···· — ·—·—·—',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => '—· ·———— —— —— / ···· ·— ··· / —· ——— / —·—· ·— ·—·· ·—·· / ···· ·· ··· — ——— ·—· —·—— / ··—· ·· ·—·· · / ··—· ——— ·—· / ${stem} ·—·—·—',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => '—· ·———— —— —— ·————· ··· / —·—· ·— ·—·· ·—·· / ···· ·· ··· — ——— ·—· —·—— / —·· ——— ·—— —· ·—·· ——— ·— —·· / ··—· ——— ·—· / ${stem} / —·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '—·—· ——— ··— ·—·· —·· —· ·————· — / ·——· ·—· ——— —·—· · ··· ··· / ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => '— ···· · / —·· ——— ·—— —· ·—·· ——— ·— —·· / ···· ·— —·· / ——— —· ·—·· —·—— / ${imported} / ——— ··—· / — ···· · / ${existing} / ·—· · —·—· ——— ·—· —·· ··· / ——— —· / — ···· ·· ··· / —·· · ···— ·· —·—· · ——··—— / ··· ——— / — ···· · / ——— —· · ··· / ·· — / ·—·· · ··—· — / ——— ··— — / ·—— · ·—· · / —·— · ·——· — ·—·—·— / ·—· · ··—· ·—· · ··· ···· ·· —· ——· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· / › / ——— ··—· ··—· ·—·· ·· —· · / —·· ·— — ·— / ·— —·—· —·—· · ·——· — ··· / ·· — / ·— —· —·—— ·—— ·— —·—— ·—·—·—',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·· —— ·——· ——— ·—· — · —·· / ${count} / ·—· · —·—· ——— ·—· —·· / ··—· ——— ·—· / ${label} ·—·—·—', other: '·· —— ·——· ——— ·—· — · —·· / ${count} / ·—· · —·—· ——— ·—· —·· ··· / ··—· ——— ·—· / ${label} ·—·—·—', ), 
			'dataFiles.importedData' => ({required Object label}) => '·· —— ·——· ——— ·—· — · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${label} ·—·—·—',
			'dataFiles.cleanedUpTitle' => '—·—· ·—·· · ·— —· · —·· / ··— ·——· / · —··— — · —· ··· ·· ——— —· / —·· ·— — ·—',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·—· · —— ——— ···— · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${count} / —·· ·— — ·— / ··—· ·· ·—·· · / ··—· ·—· ——— —— / —·· ·· ··· ·— —··· ·—·· · —·· / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—', other: '·—· · —— ——— ···— · —·· / —·· ·— — ·— / ··—· ——— ·—· / ${count} / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ··—· ·—· ——— —— / —·· ·· ··· ·— —··· ·—·· · —·· / · —··— — · —· ··· ·· ——— —· ··· ·—·—·—', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / —··—· / ${total} / ·—· · —·—· ——— ·—· —·· ···',
			'dataFiles.definitionUnavailable' => '— ···· · / ··—· ·· ·—·· · ·————· ··· / ··· ——— ··— ·—· —·—· · / —·· ·· —·· —· ·————· — / ·——· ·—· ——— ···— ·· —·· · / ·— / —·· · ··—· ·· —· ·· — ·· ——— —· / — / ·· — ··· / · —··— — · —· ··· ·· ——— —· / —— ·— —·—— / —··· · / —— ·· —·· —····— ·—· · ··· — ·— ·—· — / ——— ·—· / —— ·· ··· —·—· ——— —· ··—· ·· ——· ··— ·—· · —·· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·· —· / ·— / —— ——— —— · —· — ·—·—·—',
			'updates.updateAvailable' => '··— ·——· —·· ·— — · / ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'updates.newVersionAvailable' => ({required Object version}) => '·— / —· · ·—— / ···— · ·—· ··· ·· ——— —· / —·——· ${version} —·——·— / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · ·—·—·—',
			'updates.getIt' => '——· · — / ·· —',
			'updates.ok' => '——— —·—',
			'updates.updateReady' => '··— ·——· —·· ·— — · / ·—· · ·— —·· —·——',
			'updates.restartToApply' => '·— —· / ··— ·——· —·· ·— — · / ···· ·— ··· / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· ·—·—·— / ·—· · ··· — ·— ·—· — / — ——— / ·— ·——· ·——· ·—·· —·—— / ·· — ·—·—·—',
			'updates.appliesNextLaunch' => '·— —· / ··— ·——· —·· ·— — · / ···· ·— ··· / —··· · · —· / —·· ——— ·—— —· ·—·· ——— ·— —·· · —·· ·—·—·— / ·· — / ·—— ·· ·—·· ·—·· / ·— ·——· ·——· ·—·· —·—— / — ···· · / —· · —··— — / — ·· —— · / —·—— ——— ··— / ——— ·——· · —· / — ···· · / ·— ·——· ·——· ·—·—·—',
			'updates.restartNow' => '·—· · ··· — ·— ·—· — / —· ——— ·——',
			'updates.reloadToUpdate' => '·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / — ···· ·· ··· / ·——· ·— ——· · / ·· ··· / ·— ···— ·— ·· ·—·· ·— —··· ·—·· · ·—·—·— / ·—· · ·—·· ——— ·— —·· / — ——— / ——· · — / ·· — ·—·—·—',
			'updates.reloadNow' => '·—· · ·—·· ——— ·— —·· / —· ——— ·——',
			'updates.checkForUpdates' => '—·—· ···· · —·—· —·— / ··—· ——— ·—· / ··— ·——· —·· ·— — · ···',
			'updates.checkingForUpdates' => '—·—· ···· · —·—· —·— ·· —· ——· / ··—· ——— ·—· / ··— ·——· —·· ·— — · ··· …',
			'updates.upToDate' => '··— ·——· / — ——— / —·· ·— — ·',
			'updates.automaticChecks' => '—·—· ···· · —·—· —·— / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——',
			'updates.automaticChecksDescription' => '·—·· ——— ——— —·— / ··—· ——— ·—· / —· · ·—— / ···— · ·—· ··· ·· ——— —· ··· / ·· —· / — ···· · / —··· ·— —·—· —·— ——· ·—· ——— ··— —· —·· ——··—— / ··—· ·—· ——— —— / — ···· · / —· · —··— — / — ·· —— · / —·—— ——— ··— / ··· — ·— ·—· — / — ···· · / ·— ·——· ·——·',
			'extensionService.runtimeNotReady' => '· —··— — · —· ··· ·· ——— —· / ·—· ··— —· — ·· —— · / —· ——— — / ·—· · ·— —·· —·—— ·—·—·—',
			'extensionService.testFailed' => ({required Object error}) => '— · ··· — / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => '—·—· ——— —· —· · —·—· — · —·· / ·— ··· / ${identity}',
			'extensionService.invalidFieldConfiguration' => '·· —· ···— ·— ·—·· ·· —·· / ··—· ·· · ·—·· —·· / —·—· ——— —· ··—· ·· ——· ··— ·—· ·— — ·· ——— —·',
			'extensionService.invalidValue' => '·· —· ···— ·— ·—·· ·· —·· / ···— ·— ·—·· ··— ·',
			'extensionService.validationError' => ({required Object error}) => '···— ·— ·—·· ·· —·· ·— — ·· ——— —· / · ·—· ·—· ——— ·—· ———··· / ${error}',
			'extensionService.actionFailed' => ({required Object error}) => '·— —·—· — ·· ——— —· / ··—· ·— ·· ·—·· · —·· ———··· / ${error}',
			'extensionService.commandFailed' => '— ···· · / —·—· ——— —— —— ·— —· —·· / ··—· ·— ·· ·—·· · —·· / — ——— / ·—· ··— —·',
			'extensionService.reportUnavailable' => '·—· · ·——· ——— ·—· — ··· / —·—· ·— —· ·————· — / —··· · / ··· · —· — / ·—· ·· ——· ···· — / —· ——— ·——',
			'extensionService.stashUnavailable' => '···· ·— —— ··——— —·— ’ ··· / ··—· ·· ·—·· · / ··· — ·— ··· ···· / —·—· ·— —· ’ — / —··· · / ·—· · ·— —·—· ···· · —·· / ·—· ·· ——· ···· — / —· ——— ·——',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} / ··· ·——· · —· — / — ——— ——— / —— ··— —·—· ···· / — ·· —— · / ·· —· / ·· — ··· / — ·· —— · ·—· ··· ·—·—·— / — ···· · —·—— ·————· ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name} ·————· ··· / — ·· —— · ·—· ··· / —·— · ·——· — / ··—· ·— ·· ·—·· ·· —· ——· ·—·—·— / — ···· · —·—— ·————· ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} / ——· ——— — / ··· — ··— —·—· —·— / ·· —· / ·— / — ·· —— · ·—· ·—·—·— / ·· — ··· / — ·· —— · ·—· ··· / ·— ·—· · / ··· — ——— ·——· ·——· · —·· / ··— —· — ·· ·—·· / — ···· · / · —··— — · —· ··· ·· ——— —· ··· / ·—· · ··· — ·— ·—· — ·—·—·—',
			'operationLocationScreen.title' => '——— ·——· · ·—· ·— — ·· ——— —· / ·—·· ——— —·—· ·— — ·· ——— —·',
			'operationLocationScreen.selectedLocation' => '··· · ·—·· · —·—· — · —·· / ·—·· ——— —·—· ·— — ·· ——— —·',
			'operationLocationScreen.gridSquare' => '—— ·— ·· —·· · —· ···· · ·— —·· / ——· ·—· ·· —·· / ··· ——·— ··— ·— ·—· · / ·—·· ——— —·—· ·— — ——— ·—·',
			'operationLocationScreen.gridInvalid' => '—· · · —·· ··· / ····— ——··—— / —···· ——··—— / ———·· / ——— ·—· / ·———— ————— / —·—· ···· ·— ·—· ·— —·—· — · ·—· ··· ——··—— / ·—·· ·· —·— · / ··—· —· ···—— ·———— ·——· ·—·',
			'operationLocationScreen.suggestedLocations' => '··· ··— ——· ——· · ··· — · —·· / ·—·· ——— —·—· ·— — ·· ——— —· ···',
			'operationLocationScreen.deviceGps' => '—·· · ···— ·· —·—· · / ——· ·——· ···',
			'operationLocationScreen.peerGps' => ({required Object device}) => '——· ·——· ··· / ··—· ·—· ——— —— / ${device}',
			'operationLocationScreen.locating' => '·—·· ——— —·—· ·— — ·· —· ——· …',
			'operationLocationScreen.gpsUnavailable' => '·—·· ——— —·—· ·— — ·· ——— —· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'operationLocationScreen.permissionDenied' => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —·· · —· ·· · —··',
			'operationLocationScreen.permissionBlocked' => '·—·· ——— —·—· ·— — ·· ——— —· / ·——· · ·—· —— ·· ··· ··· ·· ——— —· / —··· ·—·· ——— —·—· —·— · —··',
			'operationLocationScreen.moreDetails' => '—— ——— ·—· · / —·· · — ·— ·· ·—·· ···',
			'operationLocationScreen.stateOrProvince' => '··· — ·— — · / ——— ·—· / ·——· ·—· ——— ···— ·· —· —·—· · / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—',
			'operationLocationScreen.controlsUnavailableTitle' => '·— —·—· — ·· ···— ·· — —·—— / —·—· ——— —· — ·—· ——— ·—·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· ·',
			'operationLocationScreen.controlsUnavailableReason' => '— ···· · ··· · / ·—· · ··—· · ·—· · —· —·—· · ··· / ·— ·—· · / ··· — ·· ·—·· ·—·· / ··— ··· ·— —··· ·—·· · —·—·—· / — ···· · ·· ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· / ·——— ··— ··· — / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·—· ···· · —·· ·—·—·—',
			'operationLocationScreen.controlsUnavailableRetry' => '·—· · — ·—· —·——',
			'operationLocationScreen.county' => '—·—· ——— ··— —· — —·—— / —·——· ——— ·——· — ·· ——— —· ·— ·—·· —·——·—',
			'versionLabel.version' => ({required Object version}) => '···— · ·—· ··· ·· ——— —· / ${version}',
			'versionLabel.patch' => ({required Object patch}) => '·——· ·— — —·—· ···· / ${patch}',
			'versionLabel.build' => ({required Object build}) => '—··· ··— ·· ·—·· —·· / ${build}',
			'notices.emptyHistory' => '—· ——— / —· ——— — ·· —·—· · ··· / —·—— · —',
			'notices.webStorageInMemory' => '— ···· ·· ··· / —··· ·—· ——— ·—— ··· · ·—· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·——· ·—· ——— ···— ·· —·· · / ·——· · ·—· ··· ·· ··· — · —· — / ··· — ——— ·—· ·— ——· · / — / — ···· · / ·—·· ——— ——· / ·—·· ·· ···— · ··· / ·· —· / —— · —— ——— ·—· —·—— / ——— —· ·—·· —·—— / ·— —· —·· / ·—— ·· ·—·· ·—·· / —··· · / ·—·· ——— ··· — / ·—— ···· · —· / — ···· ·· ··· / — ·— —··· / —·—· ·—·· ——— ··· · ··· ·—·—·— / ··— ··· · / ·— / —·—· ··— ·—· ·—· · —· — / —·—· ···· ·—· ——— —— · ——··—— / ··—· ·· ·—· · ··—· ——— —··— ——··—— / ··· ·— ··—· ·— ·—· ·· / ——— ·—· / · —·· ——· · ·—·—·—',
			'notices.webStorageUnreliable' => '— ···· ·· ··· / —··· ·—· ——— ·—— ··· · ·—· / ·· ··· / ··— ··· ·· —· ——· / ··—· ·— ·—·· ·—·· —··· ·— —·—· —·— / ··· — ——— ·—· ·— ——· · / — ···· ·— — / ·· ··· / —· ——— — / ··· ·— ··—· · / ·—— ·· — ···· / —— ··— ·—·· — ·· ·——· ·—·· · / — ·— —··· ··· / — / —·— · · ·——· / ·— / ··· ·· —· ——· ·—·· · / — ·— —··· / ——— ·——· · —· ——··—— / ·— —· —·· / —·— · · ·——· / ··· —·—— —· —·—· / ——— —· ·—·—·—',
			'notices.logFromNewerBuildTitle' => '— ···· ·· ··· / ·—·· ——— ——· / —· · · —·· ··· / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —·',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => '—·—— ——— ··— ·—· / ·—·· ——— ——· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— ·—·· ——— / —·——· ··· — ——— ·—· ·— ——· · / ···— · ·—· ··· ·· ——— —· / ${storage} —·—·—· / — ···· ·· ··· / ——— —· · / ··— —· —·· · ·—· ··· — ·— —· —·· ··· / ${understood} —·——·— ——··—— / ··· ——— / ·· — / —·—· ·— —· —· ——— — / —··· · / ——— ·——· · —· · —·· ——··—— / ·— —· —·· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· ·—·· ·—·· / —· ——— — / —··· · / ··· ·— ···— · —·· ·—·—·— / ·· —· ··· — ·— ·—·· ·—·· / — ···· · / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ·— ——· ·— ·· —· / — / ——— ·—· ——··—— / ·· ··—· / —·—— ——— ··— / —— · ·— —· — / — ——— / ·—· ··— —· / — ···· ·· ··· / —··· ··— ·· ·—·· —·· ——··—— / ·——· ——— ·· —· — / ·· — / ·— — / ·— / —·· ·· ··—· ··—· · ·—· · —· — / —·· ·— — ·— / ··—· ——— ·—·· —·· · ·—· ·—·—·— / — ···· · / ·—·· ——— ——· / ·· ··· / ·· —· / ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => '—·—— ——— ··— ·—· / ·—·· ——— ——· / ·—— ·— ··· / ·—— ·—· ·· — — · —· / —··· —·—— / ·— / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ——— ··—· / ···· ·— ·—·· ——— / —·——· ··· — ——— ·—· ·— ——· · / ···— · ·—· ··· ·· ——— —· / ${storage} —·—·—· / — ···· ·· ··· / ——— —· · / ··— —· —·· · ·—· ··· — ·— —· —·· ··· / ${understood} —·——·— ——··—— / ··· ——— / ·· — / —·—· ·— —· —· ——— — / —··· · / ——— ·——· · —· · —·· ——··—— / ·— —· —·· / —· · ·—— / —·—· ——— —· — ·— —·—· — ··· / ·—— ·· ·—·· ·—·· / —· ——— — / —··· · / ··· ·— ···— · —·· ·—·—·— / ——— ·——· · —· / — ···· ·· ··· / ·—·· ——— ——· / ·—— ·· — ···· / — ···· ·— — / —· · ·—— · ·—· / ···— · ·—· ··· ·· ——— —· / ·· —· ··· — · ·— —·· ·—·—·—',
			'notices.preferencesRestoredTitle' => '··· · — — ·· —· ——· ··· / ·—· · ··· — ——— ·—· · —·· / ··—· ·—· ——— —— / ·— / —··· ·— —·—· —·— ··— ·——·',
			'notices.preferencesRestored' => '— ···· · / ··· · — — ·· —· ——· ··· / ··—· ·· ·—·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· ——··—— / ··· ——— / ···· ·— ·—·· ——— / ·—· · ··· — ——— ·—· · —·· / — ···· · / ·—·· ·— ··· — / ——· ——— ——— —·· / —·—· ——— ·——· —·—— / ——— ··—· / ·· — ·—·—·— / ·— —· —·—— — ···· ·· —· ——· / —·—— ——— ··— / —·—· ···· ·— —· ——· · —·· / ·· —· / —·—— ——— ··— ·—· / ·——· ·—· · ···— ·· ——— ··— ··· / ··· · ··· ··· ·· ——— —· / —— ·— —·—— / —· · · —·· / ··· · — — ·· —· ——· / ·— ——· ·— ·· —· ·—·—·— / — ···· · / ··— —· ·—· · ·— —·· ·— —··· ·—·· · / ··—· ·· ·—·· · / ·· ··· / —·— · ·——· — / ·— ·—·· ——— —· ——· ··· ·· —·· · / ·· — ——··—— / —· ·— —— · —·· / ··· ···· ·— ·—· · —·· ··——·— ·——· ·—· · ··—· · ·—· · —· —·—· · ··· ·—·—·— —·—· ——— ·—· ·—· ··— ·——· — —····— … ·—·—·— ·——— ··· ——— —· ·—·—·—',
			'notices.preferencesResetTitle' => '··· · — — ·· —· ——· ··· / ·—· · ··· · —',
			'notices.preferencesReset' => '— ···· · / ··· · — — ·· —· ——· ··· / ··—· ·· ·—·· · / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · ·— —·· / ·— —· —·· / — ···· · ·—· · / ·—— ·— ··· / —· ——— / —··· ·— —·—· —·— ··— ·——· / — ——— / ··—· ·— ·—·· ·—·· / —··· ·— —·—· —·— / ——— —· ——··—— / ··· ——— / ···· ·— ·—·· ——— / ··· — ·— ·—· — · —·· / ·—— ·· — ···· / ·· — ··· / —·· · ··—· ·— ··— ·—·· — ··· ·—·—·— / — ···· · / ··— —· ·—· · ·— —·· ·— —··· ·—·· · / ··—· ·· ·—·· · / ·· ··· / —·— · ·——· — / ·· —· / — ···· · / ·— ·——· ·——· ·————· ··· / —·· ·— — ·— / ··—· ——— ·—·· —·· · ·—· ——··—— / —· ·— —— · —·· / ··· ···· ·— ·—· · —·· ··——·— ·——· ·—· · ··—· · ·—· · —· —·—· · ··· ·—·—·— —·—· ——— ·—· ·—· ··— ·——· — —····— … ·—·—·— ·——— ··· ——— —· ·—·—·—',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} / ·—— ·— ··· / —· ——— — / —·—· ——— —· —· · —·—· — · —·· / ·— ··— — ——— —— ·— — ·· —·—· ·— ·—·· ·—·· —·——',
			'notices.autoConnectHeld' => ({required Object name}) => '···· ·— ·—·· ——— / ··· — ——— ·——· ·——· · —·· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — ···· · / ·—·· ·— ··· — / — ·· —— · / ·· — / ··· — ·— ·—· — · —·· / —·—· ——— —· —· · —·—· — ·· —· ——· / — ——— / ${name} ——··—— / ··· ——— / ·· — / ·—·· · ··—· — / ·· — / ·— ·—·· ——— —· · / — ···· ·· ··· / — ·· —— · / ·—· ·— — ···· · ·—· / — ···· ·— —· / ·—· ·· ··· —·— / —·· ——— ·· —· ——· / ·· — / ·— ——· ·— ·· —· ·—·—·— / —·—· ···· · —·—· —·— / — ···· ·— — / — ···· · / ·—· ·— —·· ·· ——— / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— —· / ·— —· —·· / ·· — ··· / —·—· ·— —··· ·—·· · / ·· ··· / ·——· ·—·· ··— ——· ——· · —·· / ·· —· ——··—— / — ···· · —· / ·——· ·—· · ··· ··· / —·—· ——— —· —· · —·—· — / ——— —· / ·· — / ·· —· / ··· · — — ·· —· ——· ··· ·—·—·—',
			'syncAccount.anonymous' => ({required Object id}) => '·— —· ——— —· —·—— —— ——— ··— ··· / ·— —·—· —·—· ——— ··— —· — / —·——· # ${id} —·——·—',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} / —·——· ·——· · —· —·· ·· —· ——· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· —·——·—',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} / —·——· ·——· · —· —·· ·· —· ——· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —····— / # ${id} —·——·—',
			'deepLink.needsAnOperation' => '··· — ·— ·—· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·· ·—· ··· — ——··—— / — ···· · —· / ··· · —· —·· / — ···· ·— — / —·—· ——— —· — ·— —·—· — / ·— ——· ·— ·· —·',
			'deepLink.waitingInOperation' => '— ···· ·— — / —·—· ——— —· — ·— —·—· — / ·· ··· / ·—— ·— ·· — ·· —· ——· / ·· —· / — ···· · / ——— ·——· · ·—· ·— — ·· ——— —· / —··· · ···· ·· —· —·· / — ···· ·· ··· / ··· —·—· ·—· · · —·',
			'deepLink.unknownActivities' => ({required Object refs}) => '— ···· ·· ··· / —·· · ···— ·· —·—· · / ···· ·— ··· / —· ——— / ·— —·—· — ·· ···— ·· — —·—— / ··—· ——— ·—· / ${refs} ——··—— / ··· ——— / — ···· ——— ··· · / ·—· · ··—· · ·—· · —· —·—· · ··· / ·—— · ·—· · / ·—·· · ··—· — / ——— ··—· ··—·',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·—· ···· / —·—— ——— ··— ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· ——··—— / ··· ——— / ${refs} / ·—— ·— ··· / ·—·· · ··—· — / ——— ··—· ··—· / — / — ·—· —·—— / — ···· ·— — / ·—·· ·· —· —·— / ·— ——· ·— ·· —·',
			'confirmDevice.title' => '—·—· ——— —· ··—· ·· ·—· —— / ·— / —·· · ···— ·· —·—· ·',
			'confirmDevice.codePrompt' => '· —· — · ·—· / — ···· · / —·—· ——— —·· · / ··· ···· ——— ·—— —· / ——— —· / — ···· · / —·· · ···— ·· —·—· · / — ···· ·— — / ·—— ·— —· — ··· / — ——— / ·——— ——— ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—',
			'confirmDevice.code' => '—·—· ——— —·· ·',
			'confirmDevice.lookUp' => '·—·· ——— ——— —·— / ··— ·——·',
			'confirmDevice.codeNotFound' => '—· ——— / ·—· · ——·— ··— · ··· — / —— ·— — —·—· ···· · ··· / — ···· ·— — / —·—· ——— —·· · ·—·—·— / —·—· ——— —·· · ··· / · —··— ·——· ·· ·—· · / ·— ··—· — · ·—· / ·———— ————— / —— ·· —· ··— — · ··· / — / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / ··—· ——— ·—· / ·— / ··—· ·—· · ··· ···· / ——— —· · ·—·—·—',
			'confirmDevice.linkExpired' => '— ···· ·— — / ·—·· ·· —· —·— / ···· ·— ··· / · —··— ·——· ·· ·—· · —·· ·—·—·— / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / — ——— / ··· ···· ——— ·—— / ·— / —· · ·—— / ——·— ·—· / —·—· ——— —·· · ·—·—·—',
			'confirmDevice.areYouSure' => ({required Object device}) => '·—·· ·· —· —·— / ${device} / — ——— / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ··——··',
			'confirmDevice.unnamedDevice' => '·— —· / ··— —· —· ·— —— · —·· / —·· · ···— ·· —·—· ·',
			'confirmDevice.grantWarning' => '·· — / ·—— ·· ·—·· ·—·· / —··· · / ·— —··· ·—·· · / — ——— / ·—· · ·— —·· / ·— —· —·· / —·—· ···· ·— —· ——· · / · ···— · ·—· —·—— / ——— ·——· · ·—· ·— — ·· ——— —· / ·— —· —·· / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ·— —·—· —·—· ——— ··— —· — ·—·—·—',
			'confirmDevice.needsSyncTitle' => '— ···· ·· ··· / —·· · ···— ·· —·—· · / —·· ——— · ··· / —· ——— — / ··· —·—— —· —·—· / —·—— · —',
			'confirmDevice.needsSyncText' => '— ··— ·—· —· / ——— —· / ···· ·— —— ··——— —·— / ·—·· ——— ——· / ··—· ·· ·—·· · ·—· / ··· —·—— —· —·—· / ·— —· —·· / ·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ·— —· / ·— —·—· —·—· ——— ··— —· — / —··· · ··—· ——— ·—· · / ·· — / —·—· ·— —· / ·— —·· —— ·· — / ·— —· ——— — ···· · ·—· / ——— —· · ·—·—·—',
			'confirmDevice.malformedRequest' => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / ··· · —· — / ·— / ·—· · ——·— ··— · ··· — / — ···· ·· ··· / ·— ·——· ·——· / —·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·· ·—·—·— / ·— ··· —·— / — ···· · / ——— — ···· · ·—· / —·· · ···— ·· —·—· · / — ——— / — ·—· —·—— / ·— ——· ·— ·· —· ·—·—·—',
			'confirmDevice.linkIt' => '·—·· ·· —· —·— / —·· · ···— ·· —·—· ·',
			'switchAccounts.noAccountDetails' => '—· ——— / ·— —·—· —·—· ——— ··— —· — / —·· · — ·— ·· ·—·· ··· / —·—— · —',
			'switchAccounts.currentAccount' => '—·—· ··— ·—· ·—· · —· — / ·— —·—· —·—· ——— ··— —· —',
			'switchAccounts.otherAccounts' => '——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· — ···',
			'switchAccounts.linkToAnother' => '·—·· ·· —· —·— / — ——— / ·— —· ——— — ···· · ·—· / ·— —·—· —·—· ——— ··— —· —',
			'switchAccounts.linkWithSibling' => '·—·· ·· —· —·— / ·—— ·· — ···· / ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——·',
			'switchAccounts.linkWithPolo' => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —·—· —·—· ——— ··— —· — / ·· —· / ——— ·—·· —·· · ·—· / ···— · ·—· ··· ·· ——— —·',
			'switchAccounts.linkWithSiblingDescription' => '—·—— ——— ··— / ···· ·— ···— · / ·— —· ——— — ···· · ·—· / ···· ·— —— ··——— —·— / ·— ·——· ·——· / ·· —· ··· — ·— ·—·· ·—·· · —·· ·—·—·— / ·—·· ·· —· —·— / ·—— ·· — ···· / — ···· · / ·— —·—· —·—· ——— ··— —· — / ·· —· / ··— ··· · / — ···· · ·—· · ·—·—·—',
			'switchAccounts.siblingPrompt' => ({required Object app}) => '·— ·——· ·——· ·—· ——— ···— · / — ···· · / ·—· · ——·— ··— · ··· — / ·· —· / ${app} ——··—— / — ···· · —· / —·—· ——— —— · / —··· ·— —·—· —·— / ···· · ·—· · ·—·—·—',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '——— ·——· · —· / ${app} / ·— ——· ·— ·· —·',
			'switchAccounts.siblingNoGrant' => '—·· ·· —·· —· ·————· — / ·—— ——— ·—· —·— ··——·· / ——— ·——· · —· / ·· — / ·— ——· ·— ·· —· ——··—— / ——— ·—· / ——· ——— / —··· ·— —·—· —·— / ·— —· —·· / ·—·· ·· —· —·— / ·— —· ——— — ···· · ·—· / ·—— ·— —·—— ·—·—·—',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / ${app} ·—·—·—',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => '— ···· · / ·—·· ·· —· —·— / · —··— ·——· ·· ·—· · —·· / ·— —· —·· / ·— / —· · ·—— / ——— —· · / ·· ··· / ·—· · ·— —·· —·—— / — / ——— ·——· · —· / ${app} / ·— ——· ·— ·· —· ·—·—·—',
			'switchAccounts.tryAgain' => '— ·—· —·—— / ·— ——· ·— ·· —·',
			'switchAccounts.linkWithQr' => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— / ——·— ·—· / —·—· ——— —·· ·',
			'switchAccounts.linkWithQrDescription' => '··· —·—· ·— —· / ·· — / ··—· ·—· ——— —— / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ··— ··· ·· —· ——· / — ···· · / ·— —·—· —·—· ——— ··— —· —',
			'switchAccounts.linkWithEmail' => '·—·· ·· —· —·— / ·—— ·· — ···· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ···',
			'switchAccounts.linkWithEmailDescription' => '—·—· ——— —· ··—· ·· ·—· —— / ·—— ·· — ···· / ·— / —·—· ——— —·· · / ——— ·—· / ·— —· / · —— ·— ·· ·—·· / ·—·· ·· —· —·—',
			'switchAccounts.enterEmailPrompt' => '· —· — · ·—· / — ···· · / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ——— ··—· / — ···· · / ·— —·—· —·—· ——— ··— —· — / —·—— ——— ··— / ·—— ·— —· — / — ···· ·· ··· / —·· · ···— ·· —·—· · / — ——— / ··— ··· · ·—·—·—',
			'switchAccounts.emailAddress' => '· —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ···',
			'switchAccounts.linkAccount' => '·—·· ·· —· —·— / ·— —·—· —·—· ——— ··— —· —',
			'switchAccounts.copiedCode' => '—·—· ——— ·——· ·· · —·· / —·—· ——— —·· · / — ——— / —·—· ·—·· ·· ·——· —··· ——— ·— ·—· —··',
			'switchAccounts.copyCode' => '—·—· ——— ·——· —·—— / —·—· ——— —·· ·',
			'switchAccounts.codePrompt' => ({required Object email}) => '——— ·——· · —· / — ···· · / ···· ·— —— ··——— —·— / ·— ·——· ·——· / ——— —· / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ·· —· —·— · —·· / ·—— ·· — ···· / ${email} / ·— —· —·· / · —· — · ·—· / — ···· ·· ··· / —·—· ——— —·· · / — ——— / ·— ·——· ·——· ·—· ——— ···— · / — ···· · / ·—· · ——·— ··— · ··· — ———···',
			'switchAccounts.waitingForConfirmation' => '·—— ·— ·· — ·· —· ——· / ··—· ——— ·—· / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· …',
			'switchAccounts.sendEmailInstead' => '··· · —· —·· / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / · —— ·— ·· ·—·· / ·· —· ··· — · ·— —··',
			'switchAccounts.emailSent' => ({required Object email}) => '·— —· / · —— ·— ·· ·—·· / ·—— ·— ··· / ··· · —· — / — ——— / ${email} ·—·—·— / ——— ·——· · —· / ·· — / ·— —· —·· / —·—· ——— —· ··—· ·· ·—· —— / — ···· · / ·—· · ——·— ··— · ··· — / — ——— / ·—·· ·· —· —·— / — ···· ·· ··· / —·· · ···— ·· —·—· · ·—·—·—',
			'switchAccounts.resendEmail' => '·—· · ··· · —· —·· / · —— ·— ·· ·—··',
			'switchAccounts.qrPrompt' => '··· —·—· ·— —· / — ···· ·· ··· / ——·— ·—· / —·—· ——— —·· · / ··—· ·—· ——— —— / ·— / —·· · ···— ·· —·—· · / ·— ·—·· ·—· · ·— —·· —·—— / ·—·· ·· —· —·— · —·· / — ——— / — ···· · / ·— —·—· —·—· ——— ··— —· — / —·—— ——— ··— / ·—— ·— —· — / — / ··—· ——— ·—· / · —··— ·— —— ·——· ·—·· · / ·—— ·· — ···· / ···· ·— —— ··——— —·— / ·——· ——— ·—· — ·— —··· ·—·· · / ·—·· ——— ——· ——· · ·—· / ——— —· / —·—— ——— ··— ·—· / ·——· ···· ——— —· · ·—·—·—',
			'switchAccounts.serverUnreachable' => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·—· · ·— —·—· ···· / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'switchAccounts.emailRequired' => '· —· — · ·—· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / — ——— / ·—·· ·· —· —·— ·—·—·—',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => '—· ——— / ·— —·—· —·—· ——— ··— —· — / ··—· ——— ··— —· —·· / ··—· ——— ·—· / ${email} ·—·—·—',
			'switchAccounts.serverRejected' => ({required Object error}) => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / ·—· · ·——— · —·—· — · —·· / — ···· · / ·—· · ——·— ··— · ··· — ———··· / ${error}',
			'switchAccounts.noLinkCode' => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —·· ·· —·· / —· ——— — / ·—· · — ··— ·—· —· / ·— / ·—·· ·· —· —·— / —·—· ——— —·· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'switchAccounts.noConfirmationCode' => '— ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· / —·· ·· —·· / —· ——— — / ··· · —· —·· / ·— / —·—· ——— —· ··—· ·· ·—· —— ·— — ·· ——— —· / —·—· ——— —·· · ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'switchAccounts.switchNotAccepted' => '— ···· ·— — / ·— —·—· —·—· ——— ··— —· — / —·· ·· —·· / —· ——— — / ·— —·—· —·—· · ·——· — / — ···· · / ··· ·—— ·· — —·—· ···· ·—·—·— / — ·—· —·—— / ·—·· ·· —· —·— ·· —· ——· / ·· — / ·—— ·· — ···· / ·— —· / · —— ·— ·· ·—·· / ·— —·· —·· ·—· · ··· ··· / ·· —· ··· — · ·— —·· ·—·—·—',
			'switchAccounts.requestFailed' => '··· ——— —— · — ···· ·· —· ——· / ·—— · —· — / ·—— ·—· ——— —· ——· / — ·— ·—·· —·— ·· —· ——· / — ——— / — ···· · / ··· —·—— —· —·—· / ··· · ·—· ···— · ·—· ·—·—·— / — ·—· —·—— / ·— ——· ·— ·· —· / ·—·· ·— — · ·—· ·—·—·—',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——·— ··· ———', other: '${count} / ——·— ··· ——— ···', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——— ·——· · ·—· ·— — ·· ——— —·', other: '${count} / ——— ·——· · ·—· ·— — ·· ——— —· ···', ), 
			'qsonImport.title' => '·· —— ·——· ——— ·—· — / ——·— ··· ——— —· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsonImport.description' => '—·—· ·—· · ·— — · / ·— / —· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —· / ··—· ·—· ——— —— / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· · ——··—— / ·— ··· / —·· · ···— · ·—·· ——— ·——· · ·—· / —— ——— —·· · / · —··— ·——· ——— ·—· — ··· / ——— —· · / ···· · ·—· · / ——— ·—· / ·· —· / ·——· ——— ·—·· ——— ·—·—·—',
			'qsonImport.dropHint' => '—·· ·—· ——— ·——· / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — / ·· — / ·— ··· / ·— / —· · ·—— / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsonImport.importing' => ({required Object filename}) => '·· —— ·——· ——— ·—· — ·· —· ——· / ${filename} …',
			'qsonImport.failed' => ({required Object filename, required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —— ·——· ——— ·—· — / ${filename} ———··· / ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ——— ·——· · —· / ·— / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· — ———··· / ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} / ·· ··· / —· ——— — / ··— — ··—· —····— ———·· / — · —··— — ——··—— / ··· ——— / ·· — / ·· ··· / —· ——— — / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· ·',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} / ·· ··· / —· ——— — / ·— / ·——— ··· ——— —· / ··—· ·· ·—·· · ——··—— / ··· ——— / ·· — / ·· ··· / —· ——— — / ·— / ——·— ··· ——— —· / ··—· ·· ·—·· ·',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} / —·· ——— · ··· / —· ——— — / ···· ——— ·—·· —·· / ·— / ——·— ··· ——— —· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'qsonImport.busy' => '·— —· / ·· —— ·——· ——— ·—· — / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—· ··— —· —· ·· —· ——· ·—·—·— / ·—— ·— ·· — / ··—· ——— ·—· / ·· — / — ——— / ··—· ·· —· ·· ··· ···· / —··· · ··—· ——— ·—· · / ··· — ·— ·—· — ·· —· ——· / ·— —· ——— — ···· · ·—· ·—·—·—',
			'qsonImport.oneFileOnly' => '—·· ·—· ——— ·——· / ——— —· · / ——·— ··· ——— —· / ··—· ·· ·—·· · / ·— — / ·— / — ·· —— · / — / · ·— —·—· ···· / ——— —· · / ——— ·——· · —· ··· / ·— ··· / ·· — ··· / ——— ·—— —· / ——— ·——· · ·—· ·— — ·· ——— —· ·—·—·—',
			'adifImport.title' => '·· —— ·——· ——— ·—· — / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ·— —·· ·· ··—·',
			'adifImport.reading' => ({required Object filename}) => '·—· · ·— —·· ·· —· ——· / ${filename} …',
			'adifImport.dropHint' => '—·· ·—· ——— ·——· / ·— —· / ·— —·· ·· ··—· / ··—· ·· ·—·· · / — ——— / ·· —— ·——· ——— ·—· —',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ——·— ··· ——— / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· ·', other: '${formatted} / ——·— ··· ——— ··· / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· ·', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ·— ·—·· ·—· · ·— —·· —·—— / ·· —· / —·—— ——— ··— ·—· / ·—·· ——— ——·', other: '${formatted} / ·— ·—·· ·—· · ·— —·· —·—— / ·· —· / —·—— ——— ··— ·—· / ·—·· ——— ——·', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —··', other: '${formatted} / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —··', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / —· · ·—— / —·—· ——— —· — ·— —·—· —', other: '${formatted} / —· · ·—— / —·—· ——— —· — ·— —·—· — ···', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ·—— ·· ·—·· ·—·· / —— · ·—· ——· · / ·—— ·· — ···· / ·— —· / · —··— ·· ··· — ·· —· ——· / —·—· ——— —· — ·— —·—· —', other: '${formatted} / ·—— ·· ·—·· ·—·· / —— · ·—· ——· · / ·—— ·· — ···· / · —··— ·· ··· — ·· —· ——· / —·—· ——— —· — ·— —·—· — ···', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —·· / —·——· —· ——— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· —·——·—', other: '${formatted} / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —·· / —·——· —· ——— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· —·——·—', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / —· · · —·· ··· / ·— / —·—· ·—·· ——— ··· · ·—· / ·—·· ——— ——— —·—', other: '${formatted} / —· · · —·· / ·— / —·—· ·—·· ——— ··· · ·—· / ·—·· ——— ——— —·—', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·—· · ··—· · ·—· · —· —·—· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · —·—· ——— ···— · ·—· · —·· / ··—· ——— ·—· / ${count} / —·—· ——— —· — ·— —·—· —', other: '·—· · ··—· · ·—· · —· —·—· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—· · —·—· ——— ···— · ·—· · —·· / ··—· ——— ·—· / ${formatted} / —·—· ——— —· — ·— —·—· — ···', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${programs} / ·—· · ··—· · ·—· · —· —·—· · ··· / —— ·— —·—— / —··· · / ·· —· —·—· ——— —— ·——· ·—·· · — · / ··—· ——— ·—· / ${count} / —·—· ——— —· — ·— —·—· —', other: '${programs} / ·—· · ··—· · ·—· · —· —·—· · ··· / —— ·— —·—— / —··· · / ·· —· —·—· ——— —— ·——· ·—·· · — · / ··—· ——— ·—· / ${formatted} / —·—· ——— —· — ·— —·—· — ···', ), 
			'adifImport.stackingTypesUnknown' => '—·—· ——— —— —··· ·· —· · —·· / —·—· ——— —· — ·— —·—· — ··· / —— ·— —·—— / ·—·· ——— ··· · / ·— / ·—· · ··—· · ·—· · —· —·—· · / — / — ···· · / ·— —·—· — ·· ···— ·· — ·· · ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / ··· ·— —·—— / ·—— ···· ·· —·—· ···· / — —·—— ·——· · ··· / ··· — ·— —·—· —·— ·—·—·— / —·—· ·— —· —·—· · ·—·· / ·— —· —·· / ·—· · — ·—· —·—— / — ——— / ·— ···— ——— ·· —·· / — ···· ·· ··· ·—·—·—',
			'adifImport.nothingToImport' => '—· ——— — ···· ·· —· ——· / ·· —· / — ···· ·· ··· / ··—· ·· ·—·· · / —·—· ·— —· / —··· · / ·· —— ·——· ——— ·—· — · —··',
			'adifImport.confirm' => '·· —— ·——· ——— ·—· —',
			'adifImport.importing' => ({required Object filename}) => '·· —— ·——· ——— ·—· — ·· —· ——· / ${filename} …',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '·· —— ·——· ——— ·—· — · —·· / ${count} / —·—· ——— —· — ·— —·—· — / ··—· ·—· ——— —— / ${filename}', other: '·· —— ·——· ——— ·—· — · —·· / ${formatted} / —·—· ——— —· — ·— —·—· — ··· / ··—· ·—· ——— —— / ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '—·—· ——— ··— ·—·· —·· / —· ——— — / ·· —— ·——· ——— ·—· — / ${filename} ———··· / ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} / —·· ——— · ··· / —· ——— — / ·—·· ——— ——— —·— / ·—·· ·· —·— · / ·— —· / ·— —·· ·· ··—· / ··—· ·· ·—·· ·',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => '·—— ·— ·—· —· ·· —· ——· ———··· / — ···· ·· ··· / ·— —·· ·· ··—· / ···· ·— ··· / ——·— ··· ——— ··· / ··—· ·—· ——— —— / ${calls} ——··—— / —··· ··— — / — ···· · —·—— / ·—— ·· ·—·· ·—·· / —··· · / ·· —— ·——· ——— ·—· — · —·· / ·— ··· / ${station} / ·· ··—· / —·—— ——— ··— / —·—· ——— —· — ·· —· ··— · ·—·—·—',
			'adifImport.stationCallJoin' => '·— —· —··',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cw'))(count, one: '${count} / ···· ·— ··· / —· ——— / —·· ·— — · / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —··', other: '${formatted} / ···· ·— ···— · / —· ——— / —·· ·— — · / ·— —· —·· / —·—· ·— —· —· ——— — / —··· · / ·· —— ·——· ——— ·—· — · —··', ), 
			'adifImport.activationFound' => ({required Object refs}) => '— ···· ·· ··· / ··—· ·· ·—·· · / ·—· · —·—· ——— ·—· —·· ··· / ·— —· / ·— —·—· — ·· ···— ·— — ·· ——— —· / ——— ··—· / ${refs} ·—·—·—',
			'adifImport.addActivation' => '·— —·· —·· / ·· — / — ——— / — ···· ·· ··· / ——— ·——· · ·—· ·— — ·· ——— —·',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => '——— —· ·—·· —·—— / ${written} / ——— ··—· / ${planned} / —·—· ——— ··— ·—·· —·· / —··· · / ·— ·——· ·——· ·—·· ·· · —·· / — / — ···· · / ·—·· ——— ——· / —·—· ···· ·— —· ——· · —·· / ·—— ···· ·· ·—·· · / —·—— ——— ··— / ·—— · ·—· · / —·· · —·—· ·· —·· ·· —· ——· ·—·—·—',
			'adifImport.busy' => '·— —· / ·· —— ·——· ——— ·—· — / ·· ··· / ·— ·—·· ·—· · ·— —·· —·—— / ·—· ··— —· —· ·· —· ——· ·—·—·— / ·—— ·— ·· — / ··—· ——— ·—· / ·· — / — ——— / ··—· ·· —· ·· ··· ···· / —··· · ··—· ——— ·—· · / ··· — ·— ·—· — ·· —· ——· / ·— —· ——— — ···· · ·—· ·—·—·—',
			'adifImport.oneFileOnly' => '—·· ·—· ——— ·——· / ——— —· · / ·— —·· ·· ··—· / ··—· ·· ·—·· · / ·— — / ·— / — ·· —— · / — / — ···· · / ——— ·—· —·· · ·—· / ··—· ·· ·—·· · ··· / ·— ·—· · / ·· —— ·——· ——— ·—· — · —·· / ·· —· / —·· · —·—· ·· —·· · ··· / ·—— ···· ·· —·—· ···· / —·· ·— — ·— / ·—— ·· —· ··· ·—·—·—',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} / ···· ·— ··· / —— ——— ·—· · / — ···· ·— —· / ${limit} / ——·— ··· ——— ··· ——··—— / — ···· · / —— ——— ··· — / ·— —· / ——— ·——· · ·—· ·— — ·· ——— —· / —·—· ·— —· / ·· —— ·——· ——— ·—· — / ·— — / ·— / — ·· —— · ·—·—·—',
			'offline.statusOffline' => '·· —· — · ·—· —· · — ———··· / ——— ··—· ··—· ·—·· ·· —· ·',
			'offline.statusOnline' => '·· —· — · ·—· —· · — ———··· / —·—· ——— —· —· · —·—· — · —··',
			'offline.noRoute' => '—· ——— / —· · — ·—— ——— ·—· —·— / —·—· ——— —· —· · —·—· — ·· ——— —· / ·— — / ·— ·—·· ·—·· ·—·—·—',
			'offline.unreachable' => '— ···· · / —· · — ·—— ——— ·—· —·— / ·· ··· / ··— ·——· ——··—— / —··· ··— — / —· ——— / ··· · ·—· ···— · ·—· / ·· ··· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / — / ——— ··—· — · —· / ·— / ··· ·· ——· —· —····— ·· —· / ·——· ·— ——· · / ·—— ·— ·· — ·· —· ——· / ·· —· / ·— / —··· ·—· ——— ·—— ··· · ·—· ·—·—·—',
			'offline.reachable' => '·— ·—·· ·—·· / ··· · ·—· ···— ·· —·—· · ··· / ·—· · ··· ·——· ——— —· —·· ·· —· ——· / ·— ··· / · —··— ·——· · —·—· — · —·· ·—·—·—',
			'offline.whatStops' => '·—·· ——— ——— —·— ··— ·——· ··· ——··—— / ··· ·——· ——— — ··· / ·— —· —·· / —·· ·— — ·— / ··—· ·· ·—·· · ··· / ·— ·—· · / ·——· ·— ··— ··· · —·· ·—·—·— / ·—·· ——— ——· ——· ·· —· ——· / ·— —· —·· / —· · ·— ·—· —··· —·—— / ··· —·—— —· —·—· / ·— ·—· · / —· ——— — ·—·—·—',
			'offline.servicesTitle' => '··· · ·—· ···— ·· —·—· · ···',
			'offline.noServices' => '—· ——— / ··· · ·—· ···— ·· —·—· · / ···· ·— ··· / ·—· · ·——· ——— ·—· — · —·· / ·· —· / —·—— · — ·—·—·—',
			'offline.lastSuccess' => ({required Object when}) => '·—·· ·— ··· — / ·—· · ··· ·——· ——— —· —·· · —·· / ${when} / ·— ——· ———',
			'offline.neverSucceeded' => '···· ·— ··· / —· ——— — / ·—· · ··· ·——· ——— —· —·· · —·· / —·—— · —',
			'offline.nextAttempt' => ({required Object when}) => '—· · —··— — / ·— — — · —— ·——· — / ·· —· / ${when}',
			'offline.nextAttemptNow' => '—· · —··— — / ·— — — · —— ·——· — / —·· ··— ·',
			'offline.retry' => '·—· · — ·—· —·—— / —· ——— ·——',
			'offline.retrying' => '— ·—· —·—— ·· —· ——· …',
			'offline.retryReached' => '—··· ·— —·—· —·— / ——— —· ·—·· ·· —· · ·—·—·—',
			'offline.retryUnreachable' => '··· — ·· ·—·· ·—·· / —· ——— / ·—· · ··· ·——· ——— —· ··· · ·—·—·—',
			'offline.retryNotAttempted' => '—· ——— — ···· ·· —· ——· / — ——— / ··· · —· —·· / ·—· ·· ——· ···· — / —· ——— ·—— ·—·—·—',
			'offline.retryThrottled' => '·——— ··— ··· — / — ·—· ·· · —·· / — / ——· ·· ···— · / ·· — / ·— / —— ——— —— · —· — ·—·—·—',
			'offline.retryDisabled' => '··· —·—— —· —·—· / ·· ··· / ··· ·—— ·· — —·—· ···· · —·· / ——— ··—· ··—· ——··—— / ··· ——— / — ···· · ·—· · / ·· ··· / —· ——— — ···· ·· —· ——· / — ——— / ·——· ·—· ——— —··· · / ·—— ·· — ···· ·—·—·—',
			'offline.syncService' => '···· ·— —— ··——— —·— / ·—·· ——— ··—· ·· / ··· —·—— —· —·—·',
			'offline.retryInFlight' => '·— ·—·· ·—· · ·— —·· —·—— / — ·—· —·—— ·· —· ——· / — / ···· ·— —· ——· / ——— —· ·—·—·—',
			'exportSettings.defaultsDescription' => '—··· ·— ··· · / ··· · — — ·· —· ——· ··· / ··—· ——— ·—· / ·— ·—·· ·—·· / · —··— ·——· ——— ·—· — ··· ——··—— / ·—— ·· — ···· / ··· · ·——· ·— ·—· ·— — · / ··—· ·· ·—·· · —· ·— —— · / ·— —· —·· / — ·· — ·—·· · / — · —— ·——· ·—·· ·— — · ··· / ··—· ——— ·—· / ·—· · ··—· · ·—· · —· —·—· · / ·— —·—· — ·· ···— ·· — ·· · ··· / ·— —· —·· / ——— — ···· · ·—· / ·— —·—· — ·· ···— ·· — ·· · ··· ·—·—·— / · ·— —·—· ···· / · —··— ·——· ——— ·—· — / — —·—— ·——· · / —·—· ·— —· / ·——· ·—· ——— ···— ·· —·· · / ·· — ··· / ——— ·—— —· / —·· · ··—· ·— ··— ·—·· — ··· / ——— ·—· / —·—· ··— ··· — ——— —— / ··· · — — ·· —· ——· ··· ·—·—·—',
			'exportSettings.referenceActivities' => '·—· · ··—· · ·—· · —· —·—· · / ·— —·—· — ·· ···— ·· — ·· · ···',
			'exportSettings.otherActivities' => '——— — ···· · ·—· / ·— —·—· — ·· ···— ·· — ·· · ···',
			'exportSettings.adifFields' => '·— —·· ·· ··—· / ··—· ·· · ·—·· —·· ···',
			'exportSettings.loadFailed' => '· —··— ·——· ——— ·—· — / ··· · — — ·· —· ——· ··· / —·—· ——— ··— ·—·· —·· / —· ——— — / —··· · / ·—·· ——— ·— —·· · —·· ·—·—·—',
			'exportSettings.retry' => '·—· · — ·—· —·——',
			'exportSettings.compactFileNamesDescriptionOn' => '—·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · —· ·— —— · ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / —· ————— —·—· ·— ·—·· ·—·· ·——·—· ··— ··· —····— ·———— ··——— ···—— ····— —····— ··——— ————— ··——— —···· ————— ——··· ·———— ····· ·—·—·— ·— —·· ·· ·—·—·—',
			'exportSettings.compactFileNamesDescriptionOff' => '—·· · ··· —·—· ·—· ·· ·——· — ·· ···— · / ··—· ·· ·—·· · —· ·— —— · ··· ——··—— / ··· ··— —·—· ···· / ·— ··· / ··——— ————— ··——— —···· —····— ————— ——··· —····— ·———— ····· / —· ————— —·—· ·— ·—·· ·—·· / ·— — / ··— ··· —····— ·———— ··——— ···—— ····— ·—·—·— ·— —·· ·· ·—·—·—',
			'exportSettings.includePrivateDataDescriptionOn' => '·· —· —·—· ·—·· ··— —·· ·· —· ——· / —· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· ——··—— / —· ——— — · ··· / ·— —· —·· / ·——· ·—· · —·—· ·· ··· · / ·—·· ——— —·—· ·— — ·· ——— —· ··· / ·· —· / ·— —·· ·· ··—· / ··—· ·· ·—·· · ··· ·—·—·—',
			'exportSettings.includePrivateDataDescriptionOff' => '——— —— ·· — — ·· —· ——· / —· ·— —— · ··· ——··—— / ·— —·· —·· ·—· · ··· ··· · ··· ——··—— / · —— ·— ·· ·—·· ··· / ·— —· —·· / —· ——— — · ··· —·—·—· / ·—·· ·· —— ·· — ·· —· ——· / ·—·· ——— —·—· ·— — ·· ——— —· ··· / — ——— / ··· ·· —··— —····— —·—· ···· ·— ·—· ·— —·—· — · ·—· / ——· ·—· ·· —·· ··· ·—·—·—',
			'exportSettings.includeLookupDataDescriptionOn' => '·· —· —·—· ·—·· ··— —·· ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —· / ··—· ·—· ——— —— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· / ··· · ·—· ···— ·· —·—· · ··· ·—·—·—',
			'exportSettings.includeLookupDataDescriptionOff' => '——— —— ·· — — ·· —· ——· / ·· —· ··—· ——— ·—· —— ·— — ·· ——— —· / ··—· ·—· ——— —— / —·—· ·— ·—·· ·—·· ··· ·· ——· —· / ·—·· ——— ——— —·— ··— ·——· / ··· · ·—· ···— ·· —·—· · ··· —·—·—· / —·— · · ·——· ·· —· ——· / —— ·— —· ··— ·— ·—·· ·—·· —·—— / · —· — · ·—· · —·· / ···— ·— ·—·· ··— · ··· ·—·—·—',
			'exportSettings.customTemplatesDescriptionOn' => '—·—— ——— ··— ·—· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / ·— —·—· — ·· ···— · / ·— —· —·· / —·—· ·— —· / —··· · / · —·· ·· — · —·· / —··· · ·—·· ——— ·—— ·—·—·—',
			'exportSettings.customTemplatesDescriptionOff' => '—·· · ··—· ·— ··— ·—·· — / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / ·— —·—· — ·· ···— · ·—·—·— / —·—— ——— ··— ·—· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / ·— ·—· · / —·— · ·——· — / ··—· ——— ·—· / ·—·· ·— — · ·—· ·—·—·—',
			'exportSettings.type' => '· —··— ·——· ——— ·—· — / — —·—— ·——· ·',
			'exportSettings.defaults' => '—·· · ··—· ·— ··— ·—·· — ···',
			'exportSettings.includeLookupData' => '·· —· —·—· ·—·· ··— —·· · / ·—·· ——— ——— —·— ··— ·——· / —·· ·— — ·—',
			'exportSettings.customTemplates' => '—·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ···',
			'exportSettings.filenameTemplate' => '··—· ·· ·—·· · / —· ·— —— · / — · —— ·——· ·—·· ·— — ·',
			'exportSettings.compactFilenameTemplate' => '—·—· ——— —— ·——· ·— —·—· — / ··—· ·· ·—·· · / —· ·— —— · / — · —— ·——· ·—·· ·— — ·',
			'exportSettings.titleTemplate' => '— ·· — ·—·· · / — · —— ·——· ·—·· ·— — ·',
			'exportSettings.adifNotesTemplate' => '·— —·· ·· ··—· / ——·— ··· ——— / —· ——— — · ···',
			'exportSettings.adifCommentTemplate' => '·— —·· ·· ··—· / ——·— ··· ——— / —·—· ——— —— —— · —· — ···',
			'exportSettings.adifQslMessageTemplate' => '·— —·· ·· ··—· / ——·— ··· ·—·· / —— · ··· ··· ·— ——· ·',
			'exportSettings.shared' => '··· · — — ·· —· ——· ··· / ·— ·——· ·——· ·—·· —·—— / — ——— / · ···— · ·—· —·—— / · —··— — · —· ··· ·· ——— —· / ··— ··· ·· —· ——· / — ···· ·· ··· / · —··— ·——· ——— ·—· — / — —·—— ·——· · ·—·—·—',
			'exportSettings.defaultTemplates' => '— ··— ·—· —· / ——— —· / —·—· ··— ··· — ——— —— / — · —— ·——· ·—·· ·— — · ··· / — ——— / · —·· ·· — / — ···· ·· ··· / — —·—— ·——· · ’ ··· / — · —— ·——· ·—·· ·— — · ··· ·—·—·—',
			'templateEditor.previewLabel' => '·——· ·—· · ···— ·· · ·—— ———···',
			'templateEditor.reset' => '·—· · ··· · —',
			'templateEditor.docs' => '— · —— ·——· ·—·· ·— — ·· —· ——· / —·· ——— —·—· ···',
			'templateEditor.preview' => '··· ·— —— ·——· ·—·· · / ·——· ·—· · ···— ·· · ·——',
			'templateEditor.reference' => '— · —— ·——· ·—·· ·— — · / ·—· · ··—· · ·—· · —· —·—· ·',
			'templateEditor.attributes' => '·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ·— — — ·—· ·· —··· ··— — · ···',
			'templateEditor.filters' => '··—· ·· ·—·· — · ·—· ···',
			'templateEditor.flowControl' => '··—· ·—·· ——— ·—— / —·—· ——— —· — ·—· ——— ·—··',
			'templateEditor.unavailable' => '·——· ·—· · ···— ·· · ·—— / ·· ··· / ··— —· ·— ···— ·— ·· ·—·· ·— —··· ·—·· · / ··— —· — ·· ·—·· / · —··— — · —· ··· ·· ——— —· ··· / ·— ·—· · / ·—· · ·— —·· —·—— ·—·—·—',
			'templateEditor.empty' => '—·——· · —— ·——· — —·—— / ——— ··— — ·——· ··— — —·——·—',
			_ => null,
		};
	}
}
