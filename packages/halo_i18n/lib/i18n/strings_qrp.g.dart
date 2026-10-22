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
class TranslationsQrp extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsQrp({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.qrp,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <qrp>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsQrp _root = this; // ignore: unused_field

	@override 
	TranslationsQrp $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsQrp(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$qrp common = _Translations$common$qrp._(_root);
	@override late final _Translations$onboarding$qrp onboarding = _Translations$onboarding$qrp._(_root);
	@override late final _Translations$startScreen$qrp startScreen = _Translations$startScreen$qrp._(_root);
	@override late final _Translations$testerOverlay$qrp testerOverlay = _Translations$testerOverlay$qrp._(_root);
	@override late final _Translations$extensionsPanel$qrp extensionsPanel = _Translations$extensionsPanel$qrp._(_root);
	@override late final _Translations$home$qrp home = _Translations$home$qrp._(_root);
	@override late final _Translations$chase$qrp chase = _Translations$chase$qrp._(_root);
	@override late final _Translations$dialogs$qrp dialogs = _Translations$dialogs$qrp._(_root);
	@override late final _Translations$operation$qrp operation = _Translations$operation$qrp._(_root);
	@override late final _Translations$map$qrp map = _Translations$map$qrp._(_root);
	@override late final _Translations$mapsView$qrp mapsView = _Translations$mapsView$qrp._(_root);
	@override late final _Translations$activitiesView$qrp activitiesView = _Translations$activitiesView$qrp._(_root);
	@override late final _Translations$loggingControls$qrp loggingControls = _Translations$loggingControls$qrp._(_root);
	@override late final _Translations$formChrome$qrp formChrome = _Translations$formChrome$qrp._(_root);
	@override late final _Translations$qsoEditForm$qrp qsoEditForm = _Translations$qsoEditForm$qrp._(_root);
	@override late final _Translations$qsoList$qrp qsoList = _Translations$qsoList$qrp._(_root);
	@override late final _Translations$loggingPanel$qrp loggingPanel = _Translations$loggingPanel$qrp._(_root);
	@override late final _Translations$callInfo$qrp callInfo = _Translations$callInfo$qrp._(_root);
	@override late final _Translations$settings$qrp settings = _Translations$settings$qrp._(_root);
	@override late final _Translations$commands$qrp commands = _Translations$commands$qrp._(_root);
	@override late final _Translations$commandDialog$qrp commandDialog = _Translations$commandDialog$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$qrp keyboardShortcuts = _Translations$keyboardShortcuts$qrp._(_root);
	@override late final _Translations$expiredBuild$qrp expiredBuild = _Translations$expiredBuild$qrp._(_root);
	@override late final _Translations$staleness$qrp staleness = _Translations$staleness$qrp._(_root);
	@override late final _Translations$spotting$qrp spotting = _Translations$spotting$qrp._(_root);
	@override late final _Translations$dataFiles$qrp dataFiles = _Translations$dataFiles$qrp._(_root);
	@override late final _Translations$updates$qrp updates = _Translations$updates$qrp._(_root);
	@override late final _Translations$extensionService$qrp extensionService = _Translations$extensionService$qrp._(_root);
	@override late final _Translations$operationLocationScreen$qrp operationLocationScreen = _Translations$operationLocationScreen$qrp._(_root);
	@override late final _Translations$versionLabel$qrp versionLabel = _Translations$versionLabel$qrp._(_root);
	@override late final _Translations$notices$qrp notices = _Translations$notices$qrp._(_root);
	@override late final _Translations$syncAccount$qrp syncAccount = _Translations$syncAccount$qrp._(_root);
	@override late final _Translations$deepLink$qrp deepLink = _Translations$deepLink$qrp._(_root);
	@override late final _Translations$confirmDevice$qrp confirmDevice = _Translations$confirmDevice$qrp._(_root);
	@override late final _Translations$switchAccounts$qrp switchAccounts = _Translations$switchAccounts$qrp._(_root);
	@override late final _Translations$qsonImport$qrp qsonImport = _Translations$qsonImport$qrp._(_root);
	@override late final _Translations$adifImport$qrp adifImport = _Translations$adifImport$qrp._(_root);
	@override late final _Translations$offline$qrp offline = _Translations$offline$qrp._(_root);
	@override late final _Translations$exportSettings$qrp exportSettings = _Translations$exportSettings$qrp._(_root);
	@override late final _Translations$templateEditor$qrp templateEditor = _Translations$templateEditor$qrp._(_root);
}

// Path: common
class _Translations$common$qrp extends Translations$common$en {
	_Translations$common$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get save => 'save';
	@override String get ok => 'ok';
	@override String get cancel => 'cancel';
	@override String get delete => 'delete';
	@override String get create => 'create';
	@override String get error => 'error';
	@override String get close => 'close';
	@override String get done => 'done';
	@override String get callsign => 'callsign';
	@override String get clear => 'clear';
	@override String get dismiss => 'dismiss';
	@override String get expand => 'expand';
	@override String get collapse => 'collapse';
}

// Path: onboarding
class _Translations$onboarding$qrp extends Translations$onboarding$en {
	_Translations$onboarding$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'welcome to ham2k portable logger!';
	@override String get welcomeTitleDesktop => 'welcome to ham2k power logger!';
	@override String get welcomeBody => 'we have a few questions to help us better suit your needs.';
	@override String get skip => 'skip';
	@override String get kContinue => 'continue';
	@override String get back => 'back';
	@override String get next => 'next';
	@override String get done => 'done';
	@override String get callsignTitle => 'what\'s your callsign?';
	@override String get callsignBody => 'you need an amateur radio operator license in order to find this app useful';
	@override String get callsignLabel => 'operator\'s callsign';
	@override String get alreadyHaveAccount => 'already have an account?';
	@override String get foundSiblingTitle => 'link an existing account?';
	@override String foundSiblingBody({required Object app}) => 'we found ${app} on this device. link this app to the same account and your callsign and logs come across.';
	@override String get foundPoloBody => 'we found an older version of ham2k portable logger on this device. link this app to the same account and your callsign and logs come across.';
	@override String get foundSiblingsBody => 'we found other ham2k apps on this device. link this app to one of their accounts and your callsign and logs come across.';
	@override String linkWithApp({required Object app}) => 'link with ${app}';
	@override String get linkWithPolo => 'link with account in older version';
	@override String get setUpFresh => 'set up fresh';
	@override String get activitiesTitle => 'favorite activities';
	@override String get activitiesBody => 'are you interested in any of these popular activation programs?';
	@override String get activitiesFooter => '(you can find more options in the settings)';
	@override String get activityPota => 'parks on the air';
	@override String get activitySota => 'summits on the air';
	@override String get activityWwff => 'world wide flora & fauna';
	@override String get consentTitle => 'data & privacy';
	@override String get consentUsageBody => 'to help us make the app better, we\'d like to collect performance, crash, and app usage data.';
	@override String get consentUsageLabel => 'share app usage data';
	@override String get consentOperationBody => 'some features might involve sharing your operation data with other users. you can opt-out at any time.';
	@override String get consentOperationLabel => 'share operation data';
	@override String get finishingSetup => 'finishing setup — downloading reference data…';
}

// Path: startScreen
class _Translations$startScreen$qrp extends Translations$startScreen$en {
	_Translations$startScreen$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get credits => 'by ki2d and friends';
}

// Path: testerOverlay
class _Translations$testerOverlay$qrp extends Translations$testerOverlay$en {
	_Translations$testerOverlay$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get tape => 'caution: under construction';
	@override String get warningTitle => 'this app is a work in progress';
	@override String get warningBody => 'most features have uneven surfaces and there are trip hazards all over. please check for updates regularly.';
	@override String whatsNew({required Object build}) => 'what\'s new in build ${build}';
	@override String get thanks => 'thank you for putting your log at risk in order to help us make this app better!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$qrp extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'activities';
	@override String get categoryAward => 'awards';
	@override String get categoryContest => 'contests';
	@override String get categoryLookup => 'callsign lookups';
	@override String get categorySpots => 'spot sources';
	@override String get categoryDashboard => 'dashboard panels';
	@override String get categoryOther => 'other extensions';
	@override String get searchHint => 'search extensions';
	@override String get applying => 'activating extension changes, this may take a moment…';
	@override String get noMatches => 'no extensions match your search';
	@override String get installFromFile => 'install from file…';
	@override String installVersion({required Object version}) => 'version ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'screenshot ${n} of ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'previous screenshot';
	@override String get nextScreenshot => 'next screenshot';
	@override String get screenshotUnavailable => 'screenshot unavailable';
	@override String get canReach => 'this extension can contact';
	@override String canHoldConnection({required Object host}) => '${host}, over a live connection';
	@override String get canHoldLocalConnection => 'devices on your local network, over a live connection';
	@override String get canUseLocation => 'your location';
	@override String get canReadRadio => 'your radio, to read its frequency and mode';
	@override String get canControlRadio => 'your radio, to control it and to transmit with it — tuning, power, cw, voice memories and ptt';
	@override String get canCommandRadioRaw => 'your radio, to send it any command in its own protocol — including ones that transmit or change its settings';
	@override String get canReadCluster => 'the dx cluster, logged in as you, to read what it sends';
	@override String get canSpotCluster => 'the dx cluster, logged in as you, to post spots in your name';
	@override String get canCommandCluster => 'the dx cluster, logged in as you, to send it any command in your name';
	@override String get canSetUserAgent => 'identify itself to servers under its own name';
	@override String get noCapabilities => 'it asks for nothing outside the app.';
	@override String get sandboxNote => 'extensions run sandboxed: no access to your files, and no network beyond what is listed here.';
	@override String get installAction => 'install';
	@override String get updateAction => 'update';
	@override String get installFailed => 'that extension could not be installed';
	@override String get installedBadge => 'installed';
	@override String get uninstallAction => 'remove';
	@override String uninstallTitle({required Object name}) => 'remove ${name}?';
	@override String get uninstallBody => 'this extension and its settings will be removed. your logs will remain untouched.';
	@override String installedMessage({required Object name}) => 'installed ${name}';
	@override String get installDownloading => 'downloading…';
	@override String get installWaiting => 'waiting to install…';
	@override String get installInstalling => 'installing…';
	@override String get installAwaitingApproval => 'waiting for your approval…';
	@override String installAlreadyRunning({required Object name}) => '${name} is already being installed.';
	@override String updatedTo({required Object version}) => 'updated to ${version}';
	@override String installIncomplete({required Object name}) => 'installing ${name} did not finish. it may need installing again.';
	@override String uninstallFailed({required Object name}) => 'could not remove ${name}';
	@override String installedFrom({required Object source}) => 'downloaded from ${source}';
	@override String get dropHint => 'drop a .h2kext extension to install it';
	@override String get dropOneOnly => 'drop one extension at a time.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} returned ${status} for that extension.';
	@override String get downloadTooLarge => 'that download is far too large to be an extension.';
	@override String get downloadNotSecure => 'that download redirected somewhere insecure.';
	@override String get catalogSection => 'catalog';
	@override String get catalogLoading => 'loading the catalog…';
	@override String get catalogUnreachable => 'catalog unreachable';
	@override String get builtIn => 'built in';
	@override String get updateAvailableBadge => 'update available';
	@override String get updatesAvailableTitle => 'extension updates';
	@override String updateAvailableFor({required Object name}) => 'an update is available for ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} and ${count} more need updating.';
	@override String updatesAvailableFor({required Object names}) => '${names} need updating.';
	@override String get pendingUpdatesSection => 'pending updates';
	@override String get updateAllAction => 'update all';
	@override String get updatesUnderWay => 'those updates are already under way.';
	@override String get updatesNothingLeft => 'your extensions are up to date.';
	@override String get updatesNoticeAction => 'more info';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'update ${count} extension?',
		other: 'update ${count} extensions?',
	);
	@override String get upgradeDoneTitle => 'your extensions are ready';
	@override String get upgradeDoneBody => 'they now come from the ham2k extension catalog, so they can be updated without waiting for a new version of the app.';
	@override String upgradeDoneUnserved({required Object names}) => 'not upgraded: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'would not run: ${names}.';
	@override String get upgradeDoneRefusedHint => 'they are still installed and marked in settings › extensions — updating them there will bring them back.';
	@override String get upgradeDoneUnservedHint => 'the catalog has no direct replacement for these, so look there for extensions that cover what you used.';
	@override String get retiredQp => 'qso parties';
	@override String get retiredStateparks => 'state parks events';
	@override String upgradeDoneMissing({required Object count}) => '${count} of your extensions have not arrived yet. they will be downloaded the next time the extension catalog can be reached.';
	@override String get runtimeDeadBody => 'your extensions would not start. restarting the app should bring them back.';
	@override String get refusedTitle => 'some extensions would not run';
	@override String get upgradeBusyTitle => 'still setting up';
	@override String get upgradeRuntimeDeadTitle => 'your extensions are not running';
	@override String get restoreTitle => 'some of your extensions are missing';
	@override String get restoreBody => 'these extensions you installed are not on this device. we can download them again from the ham2k extension catalog:';
	@override String get restoreFromFile => 'installed from a file. install these again from their files, or forget them:';
	@override String get restoreOtherCatalog => 'installed from a different extension catalog, so they are not available here:';
	@override String get restoreForget => 'forget';
	@override String get restoreInstall => 'install';
	@override String get restoreLater => 'later';
	@override String get restoreInstalling => 'installing your extensions…';
	@override String get restoreDoneTitle => 'your extensions are back';
	@override String restoreDoneBody({required Object names}) => 'installed again: ${names}.';
	@override String get restorePartialTitle => 'some extensions could not be installed';
	@override String restoreFailed({required Object names}) => 'could not install: ${names}. we will offer them again next time you open the app.';
	@override String get restoreBusyBody => 'the app is still setting your extensions up. we will offer these again next time you open the app.';
	@override String get restoreRuntimeDeadBody => 'we installed them again, but your extensions would not start. restarting the app should bring them back.';
	@override String revokedTitle({required Object name}) => '${name} was withdrawn';
	@override String get revokedBody => 'the catalog withdrew this version, so it has been disabled.';
	@override String get downloadHashMismatch => 'that download is not the extension the catalog described.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'the catalog has no version ${version} of ${key}.';
	@override String get catalogLinkUnknown => 'that catalog link does not name an extension version.';
	@override String catalogNoRelease({required Object key}) => 'the catalog has no release of ${key} on that track.';
	@override String get installFromLink => 'install from link';
	@override String get unstableReleaseWarning => 'this is an unstable release, which its publisher has not called finished. it may misbehave, and it will keep receiving unstable updates.';
	@override String get bleedingReleaseWarning => 'this is a bleeding-edge release: work in progress that may break or lose its settings. it will keep receiving bleeding-edge updates.';
	@override String get channelUnstable => 'unstable';
	@override String get channelBleeding => 'bleeding';
	@override String get followsUnstable => 'receives unstable and stable releases';
	@override String get followsBleeding => 'receives bleeding-edge, unstable and stable releases';
	@override String get followStableAction => 'follow stable releases only';
	@override String get revokedBadge => 'revoked';
	@override String get refusedBadge => 'did not load';
	@override String get downloadNotHttps => 'that download is not over a secure connection.';
	@override String downloadUnreachable({required Object source}) => '${source} could not be reached for that extension.';
	@override String get detailsAction => 'details';
	@override String get installedFromFile => 'installed from a file';
	@override String get detailsWhatItDoes => 'provides support for';
	@override String get installedPreloaded => 'pre-installed';
	@override String get hookAccount => 'account sign-in';
	@override String get hookCallNotes => 'call notes';
	@override String get hookDataFile => 'offline data';
	@override String get hookExport => 'export';
	@override String get hookLookup => 'callsign lookups';
	@override String get hookScoring => 'scoring';
	@override String get hookSpots => 'spots';
	@override String hookHunting({required Object program}) => 'hunting ${program}';
	@override String hookActivating({required Object program}) => 'activating ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '… and ${count} other extension',
		other: '… and ${count} other extensions',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} extension available',
		other: '${count} extensions available',
	);
}

// Path: home
class _Translations$home$qrp extends Translations$home$en {
	_Translations$home$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'portable logger';
	@override String get newOperation => 'new operation';
	@override String get stationCallsign => 'station callsign';
	@override String get titleOptional => 'title (optional)';
	@override String get emptyList => 'no operations yet. create one to start logging.';
	@override String get quickLookup => 'quick lookup';
	@override late final _Translations$home$nav$qrp nav = _Translations$home$nav$qrp._(_root);
	@override late final _Translations$home$panels$qrp panels = _Translations$home$panels$qrp._(_root);
	@override String get toggleNav => 'show or hide the navigation labels';
	@override late final _Translations$home$logs$qrp logs = _Translations$home$logs$qrp._(_root);
}

// Path: chase
class _Translations$chase$qrp extends Translations$chase$en {
	_Translations$chase$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'chasing';
	@override String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} & more';
	@override late final _Translations$chase$station$qrp station = _Translations$chase$station$qrp._(_root);
	@override late final _Translations$chase$periodInline$qrp periodInline = _Translations$chase$periodInline$qrp._(_root);
	@override late final _Translations$chase$periodStats$qrp periodStats = _Translations$chase$periodStats$qrp._(_root);
	@override late final _Translations$chase$period$qrp period = _Translations$chase$period$qrp._(_root);
	@override late final _Translations$chase$goals$qrp goals = _Translations$chase$goals$qrp._(_root);
	@override late final _Translations$chase$panels$qrp panels = _Translations$chase$panels$qrp._(_root);
	@override late final _Translations$chase$claims$qrp claims = _Translations$chase$claims$qrp._(_root);
	@override late final _Translations$chase$notice$qrp notice = _Translations$chase$notice$qrp._(_root);
	@override late final _Translations$chase$alerts$qrp alerts = _Translations$chase$alerts$qrp._(_root);
	@override String get checklists => 'chasing progress';
	@override late final _Translations$chase$imports$qrp imports = _Translations$chase$imports$qrp._(_root);
}

// Path: dialogs
class _Translations$dialogs$qrp extends Translations$dialogs$en {
	_Translations$dialogs$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'operation details';
	@override String get activities => 'activities';
	@override String get stationCallsign => 'station callsign';
	@override String get multiStationIdentifier => 'multi-station identifier (numbers only)';
	@override String get notes => 'notes';
	@override String get deleteOperationTitle => 'delete operation';
	@override String get purgeTestsTitle => 'purge test operations';
	@override String get purgeTestsBody => 'this permanently deletes these test operations and their qsos. it cannot be undone.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'plus ${count} test contact that belongs to no operation.',
		other: 'plus ${count} test contacts that belong to no operation.',
	);
	@override String get purgeTestsAction => 'purge';
	@override String get syncAllTitle => 'replace this device\'s log?';
	@override String syncAllBody({required Object qsos}) => 'syncall backs up and clears ${qsos} from this device, then downloads the account\'s log again from the server. the backup stays in this device\'s database.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${n} qso has not been synced yet — the server never received it, and it will not come back.',
		other: '${n} qsos have not been synced yet — the server never received them, and they will not come back.',
	);
	@override String get syncAllAction => 'wipe and resync';
	@override String get receivedPurgesTitle => 'test operations removed elsewhere';
	@override String get receivedPurgesBody => 'these were deleted as test operations on another device. remove them here too? this permanently deletes them and their qsos, and cannot be undone.';
	@override String get receivedPurgesAction => 'remove';
	@override late final _Translations$dialogs$callChange$qrp callChange = _Translations$dialogs$callChange$qrp._(_root);
}

// Path: operation
class _Translations$operation$qrp extends Translations$operation$en {
	_Translations$operation$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'this operation is deleted. undelete it to log or make changes.';
	@override late final _Translations$operation$tabs$qrp tabs = _Translations$operation$tabs$qrp._(_root);
	@override late final _Translations$operation$positions$qrp positions = _Translations$operation$positions$qrp._(_root);
	@override String get stationCallsignNone => 'no station callsign';
	@override String get titleNone => 'no title';
	@override String get deleteOperation => 'delete operation';
	@override String get loggingControlsStale => 'activity fields may be out of date — reopen the operation to refresh them';
	@override String get locationNone => 'not set';
	@override String get generalOperation => 'general operation';
	@override String titleFor({required Object value}) => 'for ${value}';
	@override String titleAt({required Object value}) => 'at ${value}';
	@override String segmentNow({required Object description}) => 'now ${description}';
	@override String get testOperationSuffix => 'testing';
	@override late final _Translations$operation$menu$qrp menu = _Translations$operation$menu$qrp._(_root);
	@override late final _Translations$operation$layout$qrp layout = _Translations$operation$layout$qrp._(_root);
	@override late final _Translations$operation$export$qrp export = _Translations$operation$export$qrp._(_root);
	@override late final _Translations$operation$spots$qrp spots = _Translations$operation$spots$qrp._(_root);
	@override late final _Translations$operation$import$qrp import = _Translations$operation$import$qrp._(_root);
}

// Path: map
class _Translations$map$qrp extends Translations$map$en {
	_Translations$map$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$qrp outlineIssue = _Translations$map$outlineIssue$qrp._(_root);
	@override String get outlinesDisclaimer => 'outlines are for reference only. do your own research!';
	@override String outlinesCredit({required Object sources}) => 'outlines: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'boundaries: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'facilities: ${sources}';
	@override String get fullCredits => 'full dataset credits';
	@override String get fewerCredits => 'fewer credits';
	@override String get emptyState => 'no qso locations yet.\nqsos with a grid square, state, or country will show up here.';
	@override String get unavailable => 'the map isn\'t available right now.';
	@override String qthPopupTitle({required Object grid}) => 'qth: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'flat';
	@override String get globe => 'globe';
	@override String get zoomIn => 'zoom in';
	@override String get zoomOut => 'zoom out';
	@override String get resetNorth => 'reset to north up';
	@override late final _Translations$map$postcard$qrp postcard = _Translations$map$postcard$qrp._(_root);
}

// Path: mapsView
class _Translations$mapsView$qrp extends Translations$mapsView$en {
	_Translations$mapsView$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'maps';
	@override String get searchHint => 'search parks, summits and more';
	@override String get activities => 'activities';
	@override String get layers => 'layers';
	@override String get baseMap => 'base map';
	@override String get satellite => 'satellite (esri)';
	@override String get facilities => 'park facilities';
	@override String get boundaries => 'boundaries';
	@override String get currentLocation => 'current location';
	@override String noMatches({required Object text}) => 'nothing matches “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} reference at ${where}',
		other: '${count} references at ${where}',
	);
	@override String get startOperation => 'start an operation with these references';
}

// Path: activitiesView
class _Translations$activitiesView$qrp extends Translations$activitiesView$en {
	_Translations$activitiesView$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'activities';
	@override String get activitiesCountZero => 'no activities selected';
	@override String get activitiesCountOne => '1 activity';
	@override String activitiesCountOther({required Object count}) => '${count} activities';
	@override String get empty => 'no activities yet — use suggestions & search below to add one';
	@override String get removeActivity => 'remove';
	@override String openReferenceLink({required Object name}) => 'open ${name}';
	@override String get editActivity => 'edit activity';
	@override String get manageExtensions => 'manage extensions';
	@override String get manage => 'manage';
	@override String activitiesTitle1({required Object first}) => 'activity types: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'activity types: ${first} and ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'activity types: ${first}, ${second} and ${more} more';
	@override String get reference => 'reference';
	@override String get invalidReference => 'not valid';
	@override String get duplicateReference => 'already added';
	@override String get searchHint => 'search by name, reference or anything else…';
	@override String get noSuggestions => 'no matches';
	@override String get noSuggestionsHint => 'search by reference name or number above';
	@override String get noSuggestionsExample => '(for example \'trail\' or \'4556\')';
	@override String get allOptions => 'activity types';
	@override String get determiningLocation => 'determining current location…\nwaiting for gps fix to find nearby references';
	@override String get locationUnavailableTitle => 'location data not available';
	@override String get locationDeniedTitle => 'location permission denied';
	@override String get locationBlockedTitle => 'location permission blocked';
	@override String get noNearbyReason => 'cannot determine nearby references';
	@override String locationManualHint({required Object icon}) => 'tap ${icon} to manually enter your location,\nor just search for references by name';
	@override String get locationGrantAction => 'allow location access';
	@override String get locationSettingsAction => 'open settings';
	@override String get locationSettingsUnavailable => 'allow location access in your system settings';
	@override String get locationGrantRefused => 'still no location — the system said no again';
	@override String get searchUnavailableTitle => 'activity search unavailable';
	@override String get searchUnavailableReason => 'no activity extension could run the search. try again in a moment.';
	@override String get emptySheet => 'use suggestions & search below to add one';
	@override String get exports => 'exports';
	@override String get exportLogs => 'export logs';
	@override String get tools => 'tools';
	@override String get toolsTitle => 'operation tools';
	@override String get operationDetails => 'operation details';
	@override String get share => 'share';
	@override String get archive => 'archive';
	@override String get deleteOperation => 'delete operation';
	@override String get undeleteOperation => 'undelete operation';
	@override String get alreadySelected => 'already selected';
	@override String get selected => 'selected';
	@override String pickPosition({required Object index, required Object count}) => '${index} of ${count}';
	@override String get previousPick => 'previous match';
	@override String get nextPick => 'next match';
	@override String get retiredReference => 'retired';
	@override String enableExtension({required Object name}) => 'enable ${name}';
	@override String get enableExtensionHint => 'this extension matches your search, but it is not currently enabled';
	@override String get enableExtensionForRefHint => 'this extension handles one of this operation\'s references, but it is not currently enabled';
	@override String extensionNotRunning({required Object name}) => '${name} is not running';
	@override String get extensionNotRunningHint => 'this extension has been disabled, open extension settings for more info';
	@override String installExtension({required Object name}) => 'install ${name}';
	@override String get installExtensionHint => 'this extension matches your search, but it is not installed';
	@override String get onlyCatalogMatches => 'no matches\nsome extensions in the catalog might have results.\ninstall them in activity types below.';
	@override String get setupUnavailable => 'could not load this activity\'s setup — try again from manage';
	@override String get controlsUnavailableTitle => 'activity controls unavailable';
	@override String get controlsUnavailableReason => 'your references are safe, but editing them is unavailable right now.';
	@override String get controlsUnavailableRetry => 'retry';
	@override String get onlyDisabledMatches => 'no matches\nsome available extensions might have results.\nenable them in activity types below.';
	@override String get onlyNotRunningMatches => 'no matches\nsome extensions that might have results are not running.\nsee activity types below.';
	@override String get mapToggle => 'map';
	@override String get searchToggle => 'search';
	@override String get addToOperation => 'add to operation';
	@override String get addToOperationShort => 'add to op.';
	@override String get mapEmptyState => 'no results to show on the map';
	@override String get mapEmptyStateHint => 'switch back to the list, or search for something else';
	@override String get imports => 'imports';
}

// Path: loggingControls
class _Translations$loggingControls$qrp extends Translations$loggingControls$en {
	_Translations$loggingControls$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'time (utc)';
	@override String get date => 'date';
	@override String get now => 'now';
	@override String get manualTimeSettings => 'manual time';
	@override String get manualTimeIncrement => 'increment per qso';
	@override String get manualTimeIncrementNone => 'none';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} minute',
		other: '${count} minutes',
	);
	@override String get frequency => 'frequency';
	@override String get mode => 'mode';
	@override String get theirCall => 'their call';
	@override String get noteField => 'note';
	@override String get todoField => 'todo';
	@override String get sent => 'sent';
	@override String get rcvd => 'rcvd';
	@override String get more => 'more';
	@override String get revert => 'revert';
	@override String get undoDelete => 'undo delete';
	@override String get restore => 'restore';
	@override String get wipe => 'wipe';
	@override String get undo => 'undo';
	@override String get pendingDeleteTapWarning => 'tap the trashcan one more time to delete this qso';
	@override String get pendingDeleteClickWarning => 'click the trashcan one more time to delete this qso';
	@override String get deletedQsoWarning => 'deleted qso';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'tap the trashcan one more time to delete this ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'click the trashcan one more time to delete this ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'deleted ${kind}';
	@override String get timeControl => 'time';
	@override String get radioControl => 'radio';
	@override String get powerControl => 'power';
	@override String get notesControl => 'notes';
	@override String get power => 'power';
	@override String get powerUnit => 'w';
	@override String get controlSettings => 'logging controls';
	@override String get spottingControl => 'spotting';
	@override String get spottingSelfControl => 'self-spotting';
	@override String spotSelfAt({required Object freq}) => 'self-spot at ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'spot ${call} at ${freq}';
	@override String spotTooLate({required Object call}) => 'too late to spot ${call}';
	@override String get spotNoFreq => 'first set a frequency to spot';
	@override String get spotComment => 'comment';
	@override String get spottingAutoControl => 'auto re-spot';
	@override String spotAutoEvery({required Object minutes}) => 're-spot every ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'auto in ${time}. stop?';
	@override String spotAutoInMinutes({required Object minutes}) => 'auto in ${minutes}m';
	@override String spotAutoInSeconds({required Object seconds}) => 'auto in ${seconds}s';
	@override String spotAutoInCount({required Object seconds}) => 'auto in ${seconds}';
	@override String get spotAutoNotStarted => 'auto re-spot not started: the spot did not go through';
	@override String get spotAutoMoved => 'auto re-spot not started: the frequency changed while spotting';
	@override String get spotAutoStopped => 'auto re-spot stopped';
	@override String get spotAutoLeftFreq => 'auto re-spot stopped: the frequency changed';
	@override String get spotAutoNoFreq => 'auto re-spot stopped: the radio reports no frequency';
	@override String get spotBusy => 'another spot is still being sent';
	@override String get bandOrFreqRequired => 'set a frequency or band before logging';
	@override String get missingBand => 'no band';
	@override String get missingMode => 'no mode';
	@override String saveFailed({required Object error}) => 'could not save: ${error}';
	@override String deleteFailed({required Object error}) => 'could not delete: ${error}';
	@override late final _Translations$loggingControls$info$qrp info = _Translations$loggingControls$info$qrp._(_root);
}

// Path: formChrome
class _Translations$formChrome$qrp extends Translations$formChrome$en {
	_Translations$formChrome$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(untitled)';
	@override String get showMore => 'show more';
	@override String get showAll => 'show all';
	@override String get showFewer => 'show fewer';
	@override String get defaults => 'defaults';
	@override String get search => 'search';
	@override String get clear => 'clear';
	@override String get openPage => 'open page';
	@override String get connected => 'connected';
	@override String get notConnected => 'not connected';
	@override String get manage => 'manage';
	@override String get connect => 'connect';
	@override String get formTitle => 'form';
	@override String addItem({required Object label}) => 'add ${label}';
	@override String editItem({required Object label}) => 'edit ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'showing ${shown} of ${total} (${selected} selected)';
	@override String validationError({required Object error}) => 'validation error: ${error}';
	@override String transformationError({required Object error}) => 'transformation error: ${error}';
	@override String actionError({required Object error}) => 'error: ${error}';
	@override String get removeItem => 'delete';
	@override String deleteItemTitle({required Object name}) => 'delete ${name}?';
	@override String get storageUnavailable => 'logins unavailable';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$qrp extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'edit qso';
	@override String get operatorCall => 'operator';
	@override String get position => 'position';
	@override String get theirName => 'name';
	@override String get theirGrid => 'grid';
	@override String get theirState => 'state';
	@override String get band => 'band';
	@override String get notes => 'notes';
	@override String get sectionQso => 'qso';
	@override String get sectionTheir => 'their info';
	@override String get sectionOur => 'our info';
	@override String get sectionNotes => 'notes';
	@override String get theirCity => 'city';
	@override String get theirCounty => 'county';
	@override String get theirEntity => 'entity';
	@override String get theirCqZone => 'cq zone';
	@override String get theirItuZone => 'itu zone';
	@override String get theirArrlSection => 'arrl section';
	@override String get theirLat => 'latitude';
	@override String get theirLon => 'longitude';
	@override String get theirPower => 'their power';
}

// Path: qsoList
class _Translations$qsoList$qrp extends Translations$qsoList$en {
	_Translations$qsoList$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get empty => 'no qsos yet — work someone!';
	@override String get bandOrModeWarning => 'please make sure your band and mode are correct';
	@override String get today => 'today';
	@override String get yesterday => 'yesterday';
	@override String get tomorrow => 'tomorrow';
	@override late final _Translations$qsoList$find$qrp find = _Translations$qsoList$find$qrp._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$qrp extends Translations$loggingPanel$en {
	_Translations$loggingPanel$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get stats => 'operation stats';
	@override String get scoring => 'scoring';
	@override String get dxccEntities => 'dxcc entities';
	@override String get statesWorked => 'states';
	@override String get provincesWorked => 'provinces';
	@override String get duplicates => 'duplicates';
}

// Path: callInfo
class _Translations$callInfo$qrp extends Translations$callInfo$en {
	_Translations$callInfo$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'qrz';
	@override String get showImage => 'show image';
	@override String get imageUnavailable => 'photo unavailable';
	@override String get photo => 'photo';
	@override String get notes => 'notes';
	@override String distanceTo({required Object distance}) => '${distance} to';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to';
	@override String distanceAway({required Object distance}) => '${distance} away';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away';
	@override String get thisOpCountOne => '1 qso in this operation';
	@override String thisOpCountOther({required Object count}) => '${count} qsos in this operation';
	@override String get otherOpsCountOne => '1 qso in other operations';
	@override String otherOpsCountOther({required Object count}) => '${count} qsos in other operations';
	@override String andMore({required Object count}) => '… and ${count} more';
	@override String withCall({required Object call}) => 'with ${call}';
	@override String fromOperation({required Object where}) => 'from ${where}';
	@override late final _Translations$callInfo$history$qrp history = _Translations$callInfo$history$qrp._(_root);
}

// Path: settings
class _Translations$settings$qrp extends Translations$settings$en {
	_Translations$settings$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'settings';
	@override String get language => 'language';
	@override String languageSystem({required Object language}) => 'follow system settings (${language})';
	@override late final _Translations$settings$theme$qrp theme = _Translations$settings$theme$qrp._(_root);
	@override late final _Translations$settings$themeDescription$qrp themeDescription = _Translations$settings$themeDescription$qrp._(_root);
	@override String get fontScale => 'font scale';
	@override late final _Translations$settings$fontScaleOpts$qrp fontScaleOpts = _Translations$settings$fontScaleOpts$qrp._(_root);
	@override late final _Translations$settings$keepDeviceAwake$qrp keepDeviceAwake = _Translations$settings$keepDeviceAwake$qrp._(_root);
	@override String get layoutDensity => 'layout density';
	@override late final _Translations$settings$layoutDensityOpts$qrp layoutDensityOpts = _Translations$settings$layoutDensityOpts$qrp._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'the window is too short, using ${effective}';
	@override String get layoutDensityAtLimit => 'as far as it goes';
	@override String get distanceUnits => 'distance units';
	@override late final _Translations$settings$distanceUnitsOpts$qrp distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$qrp._(_root);
	@override String get userInterface => 'user interface';
	@override late final _Translations$settings$logging$qrp logging = _Translations$settings$logging$qrp._(_root);
	@override late final _Translations$settings$catServer$qrp catServer = _Translations$settings$catServer$qrp._(_root);
	@override late final _Translations$settings$cluster$qrp cluster = _Translations$settings$cluster$qrp._(_root);
	@override late final _Translations$settings$spotting$qrp spotting = _Translations$settings$spotting$qrp._(_root);
	@override late final _Translations$settings$radio$qrp radio = _Translations$settings$radio$qrp._(_root);
	@override late final _Translations$settings$help$qrp help = _Translations$settings$help$qrp._(_root);
	@override late final _Translations$settings$exports$qrp exports = _Translations$settings$exports$qrp._(_root);
	@override late final _Translations$settings$extensionSections$qrp extensionSections = _Translations$settings$extensionSections$qrp._(_root);
	@override late final _Translations$settings$map$qrp map = _Translations$settings$map$qrp._(_root);
	@override late final _Translations$settings$privacy$qrp privacy = _Translations$settings$privacy$qrp._(_root);
	@override String get operatorCall => 'operator callsign';
	@override late final _Translations$settings$sync$qrp sync = _Translations$settings$sync$qrp._(_root);
	@override late final _Translations$settings$peers$qrp peers = _Translations$settings$peers$qrp._(_root);
	@override String get developerMode => 'developer mode';
	@override late final _Translations$settings$syncPanel$qrp syncPanel = _Translations$settings$syncPanel$qrp._(_root);
	@override late final _Translations$settings$accounts$qrp accounts = _Translations$settings$accounts$qrp._(_root);
	@override late final _Translations$settings$station$qrp station = _Translations$settings$station$qrp._(_root);
	@override late final _Translations$settings$offlineData$qrp offlineData = _Translations$settings$offlineData$qrp._(_root);
	@override late final _Translations$settings$profiles$qrp profiles = _Translations$settings$profiles$qrp._(_root);
	@override late final _Translations$settings$search$qrp search = _Translations$settings$search$qrp._(_root);
	@override late final _Translations$settings$developer$qrp developer = _Translations$settings$developer$qrp._(_root);
	@override late final _Translations$settings$about$qrp about = _Translations$settings$about$qrp._(_root);
	@override late final _Translations$settings$panels$qrp panels = _Translations$settings$panels$qrp._(_root);
	@override String get showMoreSettings => 'show more settings';
	@override String get numberFormat => 'number formatting';
	@override late final _Translations$settings$numberFormatOpts$qrp numberFormatOpts = _Translations$settings$numberFormatOpts$qrp._(_root);
	@override late final _Translations$settings$numberFormatDescription$qrp numberFormatDescription = _Translations$settings$numberFormatDescription$qrp._(_root);
	@override late final _Translations$settings$numberFormatSeparators$qrp numberFormatSeparators = _Translations$settings$numberFormatSeparators$qrp._(_root);
	@override String get gridPrecision => 'grid precision';
	@override late final _Translations$settings$gridPrecisionOpts$qrp gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$qrp._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$qrp gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$qrp._(_root);
}

// Path: commands
class _Translations$commands$qrp extends Translations$commands$en {
	_Translations$commands$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'enable sync in settings first.';
	@override String get fullResyncStarted => 'full resync started — local data was backed up first.';
	@override String noDataFilesMatched({required Object target}) => 'no data files matched "${target}".';
	@override String reloadFailed({required Object error}) => 'reload failed: ${error}';
	@override String get reloadingAll => 'reloading all data files…';
	@override String reloadingTarget({required Object target}) => 'reloading ${target} data files…';
	@override String unknownExperiment({required Object token}) => 'unknown experiment "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} enabled';
	@override String experimentDisabled({required Object name}) => '${name} disabled';
	@override String get sentryTestSent => 'test error report sent to sentry';
	@override String get idleMetricsEnabled => 'idle metrics enabled in the status bar';
	@override String get idleMetricsDisabled => 'idle metrics disabled';
	@override String get sentryTestLocalOnly => 'sentry is disabled in this build — test error logged locally only';
	@override String get noOperationOpen => 'that command needs an open operation';
	@override String unknownSegmentKind({required Object kind}) => 'don\'t know how to mark a \'${kind}\'';
	@override String goUnavailable({required Object place}) => '${place} isn\'t turned on in this app';
	@override String goUnknown({required Object to}) => 'don\'t know how to go to \'${to}\'';
	@override String get goBlocked => 'close the open dialog first';
	@override String get operationAlreadyStarted => 'this operation already has a start marker';
	@override String get couldNotOpenLocation => 'added the break, but could not open the location screen';
	@override String get noTestOperations => 'no test operations to purge';
	@override String get purgeTestsUnavailable => 'purgetests needs to show a confirmation dialog, which isn\'t available here';
	@override String get syncAllUnavailable => 'syncall needs to show a confirmation dialog, which isn\'t available here';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'purged ${count} test operation',
		other: 'purged ${count} test operations',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'purged ${purged} of ${total} test operations — the rest failed; try purgetests again';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'purged ${count} test contact with no operation',
		other: 'purged ${count} test contacts with no operation',
	);
	@override String get purgeTestsContactsFailed => 'purged the test operations, but the test contacts with no operation failed; try purgetests again';
	@override String get purgeTestsNothingToDo => 'nothing was purged';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'removed ${removed} of ${total} test operations — the rest failed; try review again';
	@override String get receivedPurgesFailed => 'couldn\'t remove those test operations — try review again';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} test operation was removed on another device',
		other: '${count} test operations were removed on another device',
	);
	@override String get receivedPurgesReview => 'review';
	@override String get settingOn => 'on';
	@override String get settingOff => 'off';
	@override String get settingEmpty => '(empty)';
	@override String get settingSecretSet => '(set)';
	@override String get settingSecretUnset => '(not set)';
	@override String settingSelectedCount({required Object count}) => '${count} selected';
	@override String get settingExpectsOnOff => 'on or off';
	@override String settingExpectsOneOf({required Object choices}) => 'one of: ${choices}';
	@override String get settingExpectsNumber => 'a number';
	@override String settingVanished({required Object label}) => '“${label}” is no longer available';
	@override String get noCwKeyer => 'no connected radio can key cw';
	@override String get noKeyer => 'no connected radio can key cw or play voice memories';
	@override String get keyerNeedsOperation => 'open an operation to use the cw keyer';
	@override String get keyerExperimentOff => 'cw keying is off — turn it on with exp keyer';
	@override String get esmExperimentOff => 'enter sends messages is off — turn it on with exp esm';
	@override String cwSending({required Object text}) => 'sending cw: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'cw message f${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'cw message f${n} was not sent: the extensions are not ready';
	@override String settingNotStored({required Object label}) => '“${label}” did not accept that value';
}

// Path: commandDialog
class _Translations$commandDialog$qrp extends Translations$commandDialog$en {
	_Translations$commandDialog$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get hint => 'search callsigns or type a command';
	@override String noResults({required Object text}) => 'nothing matches “${text}”';
	@override String get sectionCommands => 'commands';
	@override String get sectionGoTo => 'go to';
	@override String get sectionOperations => 'operations';
	@override String get goHome => 'home';
	@override String get goSettings => 'settings';
	@override String get goNewOperation => 'new operation';
	@override String runTyped({required Object text}) => 'run “${text}”';
	@override String get sectionSuggestions => 'try';
	@override String get lookingUp => 'looking up callsign…';
	@override String get blockedByPane => 'cannot use commands while a panel or dialog is open';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$qrp extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'keyboard shortcuts';
	@override String get description => 'customize key mappings';
	@override String get search => 'search commands and keys';
	@override String get import => 'import…';
	@override String get export => 'export…';
	@override String get resetAll => 'reset all';
	@override String get resetAllTitle => 'reset every shortcut?';
	@override String get resetAllBody => 'every command goes back to its default keys, and the keys bound to typed commands are removed.';
	@override String get reset => 'reset';
	@override String get noKey => 'no key';
	@override String get changed => 'changed';
	@override String conflict({required Object keys, required Object commands}) => '${keys} is also bound to ${commands}';
	@override String get groupApp => 'app';
	@override String get groupKeying => 'keying';
	@override String get groupLogging => 'logging';
	@override String get groupCommands => 'commands';
	@override String get groupFixed => 'fixed keys';
	@override String get contextApp => 'anywhere';
	@override String get contextLogView => 'operation, chasing and logs views';
	@override String get contextOperation => 'operation view, keying a cat radio';
	@override String get contextLogging => 'in the logging panel';
	@override String get addCommand => 'add a command…';
	@override String unknownCommand({required Object command}) => 'unknown command: ${command}';
	@override late final _Translations$keyboardShortcuts$command$qrp command = _Translations$keyboardShortcuts$command$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$qrp fixed = _Translations$keyboardShortcuts$fixed$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$editor$qrp editor = _Translations$keyboardShortcuts$editor$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$file$qrp file = _Translations$keyboardShortcuts$file$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$qrp modifier = _Translations$keyboardShortcuts$modifier$qrp._(_root);
	@override late final _Translations$keyboardShortcuts$platform$qrp platform = _Translations$keyboardShortcuts$platform$qrp._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$qrp extends Translations$expiredBuild$en {
	_Translations$expiredBuild$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'this build has expired';
	@override String get body => 'please visit ham2k.com and get a newer version.';
	@override String get visit => 'visit ham2k.com';
	@override String get dismiss => 'continue anyway';
}

// Path: staleness
class _Translations$staleness$qrp extends Translations$staleness$en {
	_Translations$staleness$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'an important update is waiting';
	@override String get codePushFloorBody => 'this version has a fix you don\'t have yet.';
	@override String get restartToApply => 'restart the app to apply it.';
	@override String get quitAndReopen => 'quit the app and open it again to apply it.';
	@override String get reopenToApply => 'close the app and open it again to apply it.';
	@override String get ignoreForNow => 'ignore for now';
}

// Path: spotting
class _Translations$spotting$qrp extends Translations$spotting$en {
	_Translations$spotting$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'no qso logged yet to spot.';
	@override String get setFrequencyFirst => 'set a frequency first.';
	@override String get nothingToSpot => 'nothing to spot — no extension offers spotting here.';
	@override String get incompleteCall => 'can\'t spot an incomplete call — finish the callsign first.';
	@override String spotFailed({required Object source, required Object message}) => '${source} failed: ${message}';
	@override String get unknownError => 'unknown error';
	@override String get notSent => 'spot not sent.';
	@override String get allSkipped => 'spot not sent: every spot source skipped it.';
	@override String get notRefreshedOffline => 'no connection — spots were not refreshed';
}

// Path: dataFiles
class _Translations$dataFiles$qrp extends Translations$dataFiles$en {
	_Translations$dataFiles$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'downloading…';
	@override String downloadFailedTitle({required Object name}) => 'couldn\'t download ${name}';
	@override String get downloadFailedWebHint => 'this could be a network issue, or this link\'s host may not support direct downloads from a web browser. try the desktop or mobile app, or a different hosting location.';
	@override String get downloadTimedOut => 'the server took too long to respond. try again later.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} answered with an error (http ${status}). try again later.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} couldn\'t provide this file (http ${status}). check that its address is still right.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'n1mm has no call history file for ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'n1mm\'s call history download for ${stem} didn\'t work. try again later.';
	@override String processingFailedTitle({required Object name}) => 'couldn\'t process ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'the download had only ${imported} of the ${existing} records on this device, so the ones it left out were kept. refreshing it in settings › offline data accepts it anyway.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'imported ${count} record for ${label}.',
		other: 'imported ${count} records for ${label}.',
	);
	@override String importedData({required Object label}) => 'imported data for ${label}.';
	@override String get cleanedUpTitle => 'cleaned up extension data';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'removed data for ${count} data file from disabled extensions.',
		other: 'removed data for ${count} data files from disabled extensions.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} records';
	@override String get definitionUnavailable => 'the file\'s source didn\'t provide a definition — its extension may be mid-restart or misconfigured. try again in a moment.';
}

// Path: updates
class _Translations$updates$qrp extends Translations$updates$en {
	_Translations$updates$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'update available';
	@override String newVersionAvailable({required Object version}) => 'a new version (${version}) is available.';
	@override String get getIt => 'get it';
	@override String get ok => 'ok';
	@override String get updateReady => 'update ready';
	@override String get restartToApply => 'an update has been downloaded. restart to apply it.';
	@override String get appliesNextLaunch => 'an update has been downloaded. it will apply the next time you open the app.';
	@override String get restartNow => 'restart now';
	@override String get reloadToUpdate => 'a newer version of this page is available. reload to get it.';
	@override String get reloadNow => 'reload now';
	@override String get checkForUpdates => 'check for updates';
	@override String get checkingForUpdates => 'checking for updates…';
	@override String get upToDate => 'up to date';
	@override String get automaticChecks => 'check automatically';
	@override String get automaticChecksDescription => 'look for new versions in the background, from the next time you start the app';
}

// Path: extensionService
class _Translations$extensionService$qrp extends Translations$extensionService$en {
	_Translations$extensionService$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'extension runtime not ready.';
	@override String testFailed({required Object error}) => 'test failed: ${error}';
	@override String connectedAs({required Object identity}) => 'connected as ${identity}';
	@override String get invalidFieldConfiguration => 'invalid field configuration';
	@override String get invalidValue => 'invalid value';
	@override String validationError({required Object error}) => 'validation error: ${error}';
	@override String actionFailed({required Object error}) => 'action failed: ${error}';
	@override String get commandFailed => 'the command failed to run';
	@override String get reportUnavailable => 'reports can\'t be sent right now';
	@override String get stashUnavailable => 'ham2k’s file stash can’t be reached right now';
	@override String timersSuspendedBudget({required Object name}) => '${name} spent too much time in its timers. they\'re stopped until the extensions restart.';
	@override String timersSuspendedFailures({required Object name}) => '${name}\'s timers kept failing. they\'re stopped until the extensions restart.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} got stuck in a timer. its timers are stopped until the extensions restart.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$qrp extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'operation location';
	@override String get selectedLocation => 'selected location';
	@override String get gridSquare => 'maidenhead grid square locator';
	@override String get gridInvalid => 'needs 4, 6, 8 or 10 characters, like fn31pr';
	@override String get suggestedLocations => 'suggested locations';
	@override String get deviceGps => 'device gps';
	@override String peerGps({required Object device}) => 'gps from ${device}';
	@override String get locating => 'locating…';
	@override String get gpsUnavailable => 'location unavailable';
	@override String get permissionDenied => 'location permission denied';
	@override String get permissionBlocked => 'location permission blocked';
	@override String get moreDetails => 'more details';
	@override String get stateOrProvince => 'state or province (optional)';
	@override String get controlsUnavailableTitle => 'activity controls unavailable';
	@override String get controlsUnavailableReason => 'these references are still usable; their activities just could not be reached.';
	@override String get controlsUnavailableRetry => 'retry';
	@override String get county => 'county (optional)';
}

// Path: versionLabel
class _Translations$versionLabel$qrp extends Translations$versionLabel$en {
	_Translations$versionLabel$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'version ${version}';
	@override String patch({required Object patch}) => 'patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$qrp extends Translations$notices$en {
	_Translations$notices$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'no notices yet';
	@override String get webStorageInMemory => 'this browser could not provide persistent storage — the log lives in memory only and will be lost when this tab closes. use a current chrome, firefox, safari or edge.';
	@override String get webStorageUnreliable => 'this browser is using fallback storage that is not safe with multiple tabs — keep a single tab open, and keep sync on.';
	@override String get logFromNewerBuildTitle => 'this log needs a newer version';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'your log was written by a newer version of halo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. install the newer version again — or, if you meant to run this build, point it at a different data folder. the log is in ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'your log was written by a newer version of halo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. open this log with that newer version instead.';
	@override String get preferencesRestoredTitle => 'settings restored from a backup';
	@override String get preferencesRestored => 'the settings file could not be read, so halo restored the last good copy of it. anything you changed in your previous session may need setting again. the unreadable file is kept alongside it, named shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'settings reset';
	@override String get preferencesReset => 'the settings file could not be read and there was no backup to fall back on, so halo started with its defaults. the unreadable file is kept in the app\'s data folder, named shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} was not connected automatically';
	@override String autoConnectHeld({required Object name}) => 'halo stopped responding the last time it started connecting to ${name}, so it left it alone this time rather than risk doing it again. check that the radio is switched on and its cable is plugged in, then press connect on it in settings.';
}

// Path: syncAccount
class _Translations$syncAccount$qrp extends Translations$syncAccount$en {
	_Translations$syncAccount$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'anonymous account (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (pending confirmation)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (pending confirmation - #${id})';
}

// Path: deepLink
class _Translations$deepLink$qrp extends Translations$deepLink$en {
	_Translations$deepLink$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'start an operation first, then send that contact again';
	@override String get waitingInOperation => 'that contact is waiting in the operation behind this screen';
	@override String unknownActivities({required Object refs}) => 'this device has no activity for ${refs}, so those references were left off';
	@override String activitiesUnavailable({required Object refs}) => 'could not reach your activities, so ${refs} was left off — try that link again';
}

// Path: confirmDevice
class _Translations$confirmDevice$qrp extends Translations$confirmDevice$en {
	_Translations$confirmDevice$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'confirm a device';
	@override String get codePrompt => 'enter the code shown on the device that wants to join this account.';
	@override String get code => 'code';
	@override String get lookUp => 'look up';
	@override String get codeNotFound => 'no request matches that code. codes expire after 10 minutes — ask the other device for a fresh one.';
	@override String get linkExpired => 'that link has expired. ask the other device to show a new qr code.';
	@override String areYouSure({required Object device}) => 'link ${device} to this account?';
	@override String get unnamedDevice => 'an unnamed device';
	@override String get grantWarning => 'it will be able to read and change every operation and qso in this account.';
	@override String get needsSyncTitle => 'this device does not sync yet';
	@override String get needsSyncText => 'turn on ham2k log filer sync and link this device to an account before it can admit another one.';
	@override String get malformedRequest => 'the sync server sent a request this app could not read. ask the other device to try again.';
	@override String get linkIt => 'link device';
}

// Path: switchAccounts
class _Translations$switchAccounts$qrp extends Translations$switchAccounts$en {
	_Translations$switchAccounts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'no account details yet';
	@override String get currentAccount => 'current account';
	@override String get otherAccounts => 'other accounts';
	@override String get linkToAnother => 'link to another account';
	@override String get linkWithSibling => 'link with other ham2k app';
	@override String get linkWithPolo => 'link with account in older version';
	@override String get linkWithSiblingDescription => 'you have another ham2k app installed. link with the account in use there.';
	@override String siblingPrompt({required Object app}) => 'approve the request in ${app}, then come back here.';
	@override String openSiblingAgain({required Object app}) => 'open ${app} again';
	@override String get siblingNoGrant => 'didn\'t work? open it again, or go back and link another way.';
	@override String siblingOpenFailed({required Object app}) => 'could not open ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'the link expired and a new one is ready — open ${app} again.';
	@override String get tryAgain => 'try again';
	@override String get linkWithQr => 'link with a qr code';
	@override String get linkWithQrDescription => 'scan it from a device already using the account';
	@override String get linkWithEmail => 'link with an email address';
	@override String get linkWithEmailDescription => 'confirm with a code or an email link';
	@override String get enterEmailPrompt => 'enter the email address of the account you want this device to use.';
	@override String get emailAddress => 'email address';
	@override String get linkAccount => 'link account';
	@override String get copiedCode => 'copied code to clipboard';
	@override String get copyCode => 'copy code';
	@override String codePrompt({required Object email}) => 'open the ham2k app on a device already linked with ${email} and enter this code to approve the request:';
	@override String get waitingForConfirmation => 'waiting for confirmation…';
	@override String get sendEmailInstead => 'send a confirmation email instead';
	@override String emailSent({required Object email}) => 'an email was sent to ${email}. open it and confirm the request to link this device.';
	@override String get resendEmail => 'resend email';
	@override String get qrPrompt => 'scan this qr code from a device already linked to the account you want — for example with ham2k portable logger on your phone.';
	@override String get serverUnreachable => 'could not reach the sync server. try again later.';
	@override String get emailRequired => 'enter an email address to link.';
	@override String noAccountForEmail({required Object email}) => 'no account found for ${email}.';
	@override String serverRejected({required Object error}) => 'the sync server rejected the request: ${error}';
	@override String get noLinkCode => 'the sync server did not return a link code. try again later.';
	@override String get noConfirmationCode => 'the sync server did not send a confirmation code. try again later.';
	@override String get switchNotAccepted => 'that account did not accept the switch. try linking it with an email address instead.';
	@override String get requestFailed => 'something went wrong talking to the sync server. try again later.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} qso',
		other: '${count} qsos',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} operation',
		other: '${count} operations',
	);
}

// Path: qsonImport
class _Translations$qsonImport$qrp extends Translations$qsonImport$en {
	_Translations$qsonImport$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'import qson operation';
	@override String get description => 'create a new operation from a qson file, as developer mode exports one here or in polo.';
	@override String get dropHint => 'drop a qson file to import it as a new operation';
	@override String importing({required Object filename}) => 'importing ${filename}…';
	@override String failed({required Object filename, required Object error}) => 'could not import ${filename}: ${error}';
	@override String pickerFailed({required Object error}) => 'could not open a file to import: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} is not utf-8 text, so it is not a qson file';
	@override String notJson({required Object filename}) => '${filename} is not a json file, so it is not a qson file';
	@override String notOperation({required Object filename}) => '${filename} does not hold a qson operation';
	@override String get busy => 'an import is already running. wait for it to finish before starting another.';
	@override String get oneFileOnly => 'drop one qson file at a time — each one opens as its own operation.';
}

// Path: adifImport
class _Translations$adifImport$qrp extends Translations$adifImport$en {
	_Translations$adifImport$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'import qsos from adif';
	@override String reading({required Object filename}) => 'reading ${filename}…';
	@override String get dropHint => 'drop an adif file to import';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} qso in this file',
		other: '${formatted} qsos in this file',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} already in your log',
		other: '${formatted} already in your log',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} will be imported',
		other: '${formatted} will be imported',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} new contact',
		other: '${formatted} new contacts',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} will merge with an existing contact',
		other: '${formatted} will merge with existing contacts',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} cannot be imported (no callsign)',
		other: '${formatted} cannot be imported (no callsign)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} needs a closer look',
		other: '${formatted} need a closer look',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'references could not be recovered for ${count} contact',
		other: 'references could not be recovered for ${formatted} contacts',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${programs} references may be incomplete for ${count} contact',
		other: '${programs} references may be incomplete for ${formatted} contacts',
	);
	@override String get stackingTypesUnknown => 'combined contacts may lose a reference — the activities could not say which types stack. cancel and retry to avoid this.';
	@override String get nothingToImport => 'nothing in this file can be imported';
	@override String get confirm => 'import';
	@override String importing({required Object filename}) => 'importing ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'imported ${count} contact from ${filename}',
		other: 'imported ${formatted} contacts from ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'could not import ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} does not look like an adif file';
	@override String stationWarning({required Object calls, required Object station}) => 'warning: this adif has qsos from ${calls}, but they will be imported as ${station} if you continue.';
	@override String get stationCallJoin => ' and ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} has no date and cannot be imported',
		other: '${formatted} have no date and cannot be imported',
	);
	@override String activationFound({required Object refs}) => 'this file records an activation of ${refs}.';
	@override String get addActivation => 'add it to this operation';
	@override String shortfall({required Object written, required Object planned}) => 'only ${written} of ${planned} could be applied — the log changed while you were deciding.';
	@override String get busy => 'an import is already running. wait for it to finish before starting another.';
	@override String get oneFileOnly => 'drop one adif file at a time — the order files are imported in decides which data wins.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} has more than ${limit} qsos, the most an operation can import at a time.';
}

// Path: offline
class _Translations$offline$qrp extends Translations$offline$en {
	_Translations$offline$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'internet: offline';
	@override String get statusOnline => 'internet: connected';
	@override String get noRoute => 'no network connection at all.';
	@override String get unreachable => 'the network is up, but no server is responding — often a sign-in page waiting in a browser.';
	@override String get reachable => 'all services responding as expected.';
	@override String get whatStops => 'lookups, spots and data files are paused. logging and nearby sync are not.';
	@override String get servicesTitle => 'services';
	@override String get noServices => 'no service has reported in yet.';
	@override String lastSuccess({required Object when}) => 'last responded ${when} ago';
	@override String get neverSucceeded => 'has not responded yet';
	@override String nextAttempt({required Object when}) => 'next attempt in ${when}';
	@override String get nextAttemptNow => 'next attempt due';
	@override String get retry => 'retry now';
	@override String get retrying => 'trying…';
	@override String get retryReached => 'back online.';
	@override String get retryUnreachable => 'still no response.';
	@override String get retryNotAttempted => 'nothing to send right now.';
	@override String get retryThrottled => 'just tried — give it a moment.';
	@override String get retryDisabled => 'sync is switched off, so there is nothing to probe with.';
	@override String get syncService => 'ham2k lofi sync';
	@override String get retryInFlight => 'already trying — hang on.';
}

// Path: exportSettings
class _Translations$exportSettings$qrp extends Translations$exportSettings$en {
	_Translations$exportSettings$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'base settings for all exports, with separate filename and title templates for reference activities and other activities. each export type can provide its own defaults or custom settings.';
	@override String get referenceActivities => 'reference activities';
	@override String get otherActivities => 'other activities';
	@override String get adifFields => 'adif fields';
	@override String get loadFailed => 'export settings could not be loaded.';
	@override String get retry => 'retry';
	@override String get compactFileNamesDescriptionOn => 'compact filenames, such as n0call@us-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'descriptive filenames, such as 2026-07-15 n0call at us-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'including names, addresses, emails, notes and precise locations in adif files.';
	@override String get includePrivateDataDescriptionOff => 'omitting names, addresses, emails and notes; limiting locations to six-character grids.';
	@override String get includeLookupDataDescriptionOn => 'including information from callsign lookup services.';
	@override String get includeLookupDataDescriptionOff => 'omitting information from callsign lookup services; keeping manually entered values.';
	@override String get customTemplatesDescriptionOn => 'your custom templates are active and can be edited below.';
	@override String get customTemplatesDescriptionOff => 'default templates are active. your custom templates are kept for later.';
	@override String get type => 'export type';
	@override String get defaults => 'defaults';
	@override String get includeLookupData => 'include lookup data';
	@override String get customTemplates => 'custom templates';
	@override String get filenameTemplate => 'file name template';
	@override String get compactFilenameTemplate => 'compact file name template';
	@override String get titleTemplate => 'title template';
	@override String get adifNotesTemplate => 'adif qso notes';
	@override String get adifCommentTemplate => 'adif qso comments';
	@override String get adifQslMessageTemplate => 'adif qsl message';
	@override String get shared => 'settings apply to every extension using this export type.';
	@override String get defaultTemplates => 'turn on custom templates to edit this type’s templates.';
}

// Path: templateEditor
class _Translations$templateEditor$qrp extends Translations$templateEditor$en {
	_Translations$templateEditor$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'preview:';
	@override String get reset => 'reset';
	@override String get docs => 'templating docs';
	@override String get preview => 'sample preview';
	@override String get reference => 'template reference';
	@override String get attributes => 'available attributes';
	@override String get filters => 'filters';
	@override String get flowControl => 'flow control';
	@override String get unavailable => 'preview is unavailable until extensions are ready.';
	@override String get empty => '(empty output)';
}

// Path: home.nav
class _Translations$home$nav$qrp extends Translations$home$nav$en {
	_Translations$home$nav$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get operations => 'operations';
	@override String get chase => 'chasing';
	@override String get logs => 'logs';
	@override String get maps => 'maps';
	@override String get settings => 'settings';
}

// Path: home.panels
class _Translations$home$panels$qrp extends Translations$home$panels$en {
	_Translations$home$panels$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get operations => 'operation list';
	@override String get operationsDescription => 'your operations, most recent first.';
	@override String get version => 'current version';
	@override String get versionDescription => 'the ham2k mark, this app’s name and which build you are running.';
}

// Path: home.logs
class _Translations$home$logs$qrp extends Translations$home$logs$en {
	_Translations$home$logs$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'logs';
	@override String get titleFor => 'logs for';
	@override String get emptyCallsigns => 'no qsos logged yet';
	@override String emptyQsos({required Object call}) => 'no qsos for ${call}';
	@override String get mapNoSelection => 'select a qso to see it on the map';
	@override String get searchHint => 'search callsign or name';
	@override String get noSearchMatches => 'no qsos match your search';
	@override String get titleAll => 'all logs';
	@override String get allCallsigns => 'all callsigns';
	@override String get noOperation => 'not part of an operation';
	@override String get unsavedTitle => 'unsaved changes';
	@override String get unsavedBody => 'this qso has changes you haven’t saved.';
	@override String get pendingDeleteBody => 'this qso is marked for deletion.';
	@override String get editGone => 'not saved: that qso is no longer in this log.';
	@override String get discard => 'discard';
	@override late final _Translations$home$logs$sheet$qrp sheet = _Translations$home$logs$sheet$qrp._(_root);
	@override late final _Translations$home$logs$groupBy$qrp groupBy = _Translations$home$logs$groupBy$qrp._(_root);
	@override late final _Translations$home$logs$period$qrp period = _Translations$home$logs$period$qrp._(_root);
	@override late final _Translations$home$logs$periodTitle$qrp periodTitle = _Translations$home$logs$periodTitle$qrp._(_root);
	@override late final _Translations$home$logs$columns$qrp columns = _Translations$home$logs$columns$qrp._(_root);
	@override late final _Translations$home$logs$panels$qrp panels = _Translations$home$logs$panels$qrp._(_root);
	@override late final _Translations$home$logs$import$qrp import = _Translations$home$logs$import$qrp._(_root);
}

// Path: chase.station
class _Translations$chase$station$qrp extends Translations$chase$station$en {
	_Translations$chase$station$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'chasing station';
	@override String get stationLabel => 'station: ';
	@override String get operatorLabel => 'op: ';
	@override String get noLocation => 'no location';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$qrp extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get today => 'today';
	@override String get thisWeek => 'this week';
	@override String get last14Days => 'in the last 14 days';
	@override String get thisMonth => 'this month';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$qrp extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get today => 'stats for today';
	@override String get thisWeek => 'stats for this week';
	@override String get last14Days => 'stats for last 14 days';
	@override String get thisMonth => 'stats for this month';
}

// Path: chase.period
class _Translations$chase$period$qrp extends Translations$chase$period$en {
	_Translations$chase$period$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get today => 'today';
	@override String get thisWeek => 'this week';
	@override String get last14Days => 'last 14 days';
	@override String get thisMonth => 'this month';
}

// Path: chase.goals
class _Translations$chase$goals$qrp extends Translations$chase$goals$en {
	_Translations$chase$goals$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'chasing goals';
	@override String remove({required Object name}) => 'stop chasing ${name}';
	@override String get extensionsTitle => 'more chasing programs';
}

// Path: chase.panels
class _Translations$chase$panels$qrp extends Translations$chase$panels$en {
	_Translations$chase$panels$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get logging => 'qsos';
	@override String get loggingDescription => 'logging controls above the qsos chased in the period.';
	@override String get info => 'info';
	@override String get infoDescription => 'the callsign being logged, or the period\'s stats.';
	@override String get spots => 'spots';
	@override String get spotsDescription => 'stations spotted on the air, ready to chase.';
	@override String get map => 'map';
	@override String get mapDescription => 'the period\'s qsos and the station being logged.';
}

// Path: chase.claims
class _Translations$chase$claims$qrp extends Translations$chase$claims$en {
	_Translations$chase$claims$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get checking => 'checking qsos for chasing';
	@override String rebuilding({required Object program}) => 'checking the log for ${program}';
	@override String progress({required Object done, required Object total}) => '${done} of ${total} qsos';
}

// Path: chase.notice
class _Translations$chase$notice$qrp extends Translations$chase$notice$en {
	_Translations$chase$notice$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'new ${program}';
	@override String newRefGuess({required Object program}) => 'probably new ${program}';
	@override String newBand({required Object program}) => 'new ${program} band';
	@override String newBandGuess({required Object program}) => 'probably new ${program} band';
	@override String newMode({required Object program}) => 'new ${program} mode';
	@override String newModeGuess({required Object program}) => 'probably new ${program} mode';
	@override String unconfirmed({required Object program}) => '${program} unconfirmed';
}

// Path: chase.alerts
class _Translations$chase$alerts$qrp extends Translations$chase$alerts$en {
	_Translations$chase$alerts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'alerts';
	@override String get newRef => 'new reference';
	@override String get newBand => 'new band';
	@override String get newMode => 'new mode';
	@override String get unconfirmed => 'unconfirmed';
}

// Path: chase.imports
class _Translations$chase$imports$qrp extends Translations$chase$imports$en {
	_Translations$chase$imports$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'import ${label}';
	@override String pickTitle({required Object file}) => 'import ${file} as';
	@override String get dropHint => 'drop a file to import it into a chasing program';
	@override String done({required Object count, required Object program, required Object file}) => 'imported ${count} ${program} entries from ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'imported ${count} ${program} entries from ${file}, skipped ${skipped} it could not read';
	@override String nothing({required Object file, required Object program}) => '${file} has nothing ${program} can import';
	@override String failed({required Object program, required Object file}) => '${program} could not read ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} could not read any of the ${skipped} records in ${file}';
	@override String noProgram({required Object file}) => 'no chasing program imports ${file}';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$qrp extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'invalid callsign: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'invalid callsigns: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} has operated so far. ${typed} will be recorded for new contacts.';
	@override String operatorNoneSoFar({required Object typed}) => 'no operator recorded so far. ${typed} will be recorded for new contacts.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'this operation already has contacts by ${calls}. ${typed} will only be recorded for new ones.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'also record ${typed} as the operator of the contact already logged',
		other: 'also record ${typed} as the operator of all ${count} contacts already logged',
	);
	@override String get operatorSeveralStations => 'when using multiple stations over the air, there\'s no support for separate operators';
	@override String get contactsUnreadable => 'this operation\'s contacts could not be read, so changing a callsign here won\'t offer to update them';
	@override String restampFailed({required Object error}) => 'the contacts already logged could not be updated, so no changes were made: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} of ${planned} contacts were updated — the rest are no longer in this operation';
}

// Path: operation.tabs
class _Translations$operation$tabs$qrp extends Translations$operation$tabs$en {
	_Translations$operation$tabs$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} qsos';
	@override String get info => 'info';
	@override String get spots => 'spots';
	@override String get map => 'map';
	@override String get qsosPlain => 'qsos';
	@override String get clock => 'clock';
	@override String get weather => 'weather';
	@override String get website => 'web site';
	@override String get remoteScreen => 'remote screen';
	@override String get solar => 'solar';
	@override String get radio => 'radio';
	@override String get summaries => 'operation summaries';
}

// Path: operation.positions
class _Translations$operation$positions$qrp extends Translations$operation$positions$en {
	_Translations$operation$positions$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'no other operating positions are sharing this operation yet.';
	@override String positionLabel({required Object number}) => 'pos: ${number}';
	@override String operatorLabel({required Object call}) => 'op: ${call}';
	@override String get unnamedPosition => 'another position';
	@override String get thisDevice => 'our operating position';
	@override String get nameIn => ' in ';
	@override String get panelTitle => 'positions';
	@override String get panelDescription => 'what every operating position sharing this operation is logging right now.';
}

// Path: operation.menu
class _Translations$operation$menu$qrp extends Translations$operation$menu$en {
	_Translations$operation$menu$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'show rst fields';
	@override String get showStateField => 'show state field';
	@override String get showGridField => 'show grid field';
	@override String get showDeletedQsos => 'show deleted qsos';
	@override String get showDeletedOps => 'show deleted operations';
	@override String get showQsoNumbers => 'show qso numbers';
	@override String get lookupAllQsos => 'lookup all qsos';
	@override String get loggingSettingsTitle => 'logging settings';
	@override String get mapSettingsTitle => 'map settings';
	@override String get actionsSection => 'actions';
}

// Path: operation.layout
class _Translations$operation$layout$qrp extends Translations$operation$layout$en {
	_Translations$operation$layout$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'add a panel';
	@override String get availableSection => 'available panels';
	@override String panelSettings({required Object panel}) => '${panel} settings';
	@override String get panelSettingsAction => 'panel settings';
	@override String get viewName => 'operation view';
	@override String get viewOptions => 'view layout options';
	@override String get viewTitleBuiltIn => 'this view is built into the app, and so is its name';
	@override String get resetOptions => 'restore defaults';
	@override String get removePane => 'remove';
	@override String resetPaneConfirm({required Object panel}) => 'restore ${panel} to its defaults?';
	@override String get resetPaneConfirmBody => 'its title, header and size go back to the defaults. the rest of the layout stays as it is.';
	@override String get resetViewConfirm => 'restore this view to its default layout?';
	@override String get resetViewConfirmBody => 'the panels go back to their default arrangement, and the view\'s options and every panel\'s go back to the defaults.';
	@override String paneOptionsTitle({required Object panel}) => '${panel} layout settings';
	@override String get paneTitle => 'title';
	@override String get paneShowHeader => 'show header';
	@override String get paneShowHeaderTabset => 'always shown while this pane shares a group — the header is how the others are reached';
	@override String get paneInherit => 'same as the app';
	@override String get searchHint => 'search panels';
	@override String get noPanelsMatch => 'no panel matches your search.';
	@override String get nothingToAdd => 'this view already has all possible panels';
	@override String addPanel({required Object panel}) => 'add ${panel}';
	@override String showPreview({required Object panel}) => 'preview ${panel}';
	@override String missingExtension({required Object name}) => 'extension "${name}" is missing';
	@override String get missingExtensionEnable => 'enable';
	@override String get missingExtensionInstall => 'install…';
	@override String get missingExtensionWontRun => 'this version won’t run. update it in settings › extensions.';
	@override String get missingExtensionUnavailable => 'not available in this app';
	@override String get missingExtensionNotInCatalog => 'not in the catalog';
	@override String get missingExtensionCatalogUnreachable => 'couldn’t reach the catalog. try again';
	@override String get missingExtensionFailed => 'that didn’t work. try again';
	@override String get previewUnavailable => 'this panel\'s preview image could not be shown.';
	@override String get nestedPaneTitle => 'more';
	@override late final _Translations$operation$layout$layouts$qrp layouts = _Translations$operation$layout$layouts$qrp._(_root);
	@override String get editLayout => 'edit layout';
	@override String get saveLayout => 'save layout';
	@override String get revertLayout => 'discard layout changes';
	@override String get done => 'done';
	@override String get layoutUnreadableTitle => 'layout couldn\'t be read';
	@override String get layoutUnreadableBody => 'your saved layout could not be read, so the default arrangement is showing instead. it won\'t be saved over your original until you choose to keep it.';
	@override String get layoutUnreadableAction => 'use this layout';
	@override String panelRenderFailed({required Object panel}) => '${panel} could not be displayed';
	@override String get panelRenderRetry => 'try again';
	@override String get panelActionFailed => 'that panel action failed. try again.';
	@override late final _Translations$operation$layout$panels$qrp panels = _Translations$operation$layout$panels$qrp._(_root);
	@override String get htmlPanelUnsupported => 'this panel needs a web view, which this platform does not provide';
	@override String get htmlPanelUnsupportedOnWeb => 'this panel needs a sandbox the web version cannot provide';
}

// Path: operation.export
class _Translations$operation$export$qrp extends Translations$operation$export$en {
	_Translations$operation$export$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'operation exports';
	@override String get syncedOperation => 'operation is synced';
	@override String get unsyncedOperation => 'operation has unsynced changes';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} qso in this operation',
		other: '${count} qsos in this operation',
	);
	@override String qsosSynced({required Object total}) => 'all ${total} qsos are synced';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} of ${total} qsos pending sync';
	@override String eventsSynced({required Object total}) => '${total} event markers synced';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} of ${total} event markers pending';
	@override String get loading => 'loading export options…';
	@override String get noOptions => 'no export formats available (extension runtime still starting?)';
	@override String get nothingLogged => 'nothing to export yet — this operation has no qsos.';
	@override String get share => 'share';
	@override String get nothingSelected => 'nothing selected';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'save ${count} file',
		other: 'save ${count} files',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'share ${count} file',
		other: 'share ${count} files',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'export ${count} file',
		other: 'export ${count} files',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'download ${count} file',
		other: 'download ${count} files',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'save combined ${count} file',
		other: 'save combined ${count} files',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'share combined ${count} file',
		other: 'share combined ${count} files',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'export combined ${count} file',
		other: 'export combined ${count} files',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'download combined ${count} file',
		other: 'download combined ${count} files',
	);
	@override String saveOne({required Object name}) => 'save ${name}';
	@override String shareOne({required Object name}) => 'share ${name}';
	@override String exportOne({required Object name}) => 'export ${name}';
	@override String downloadOne({required Object name}) => 'download ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'stash ${count} file',
		other: 'stash ${count} files',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'stash combined ${count} file',
		other: 'stash combined ${count} files',
	);
	@override String get settingsButton => 'export settings';
	@override String get settingsTitle => 'export settings';
	@override late final _Translations$operation$export$compactFileNames$qrp compactFileNames = _Translations$operation$export$compactFileNames$qrp._(_root);
	@override late final _Translations$operation$export$includePrivateData$qrp includePrivateData = _Translations$operation$export$includePrivateData$qrp._(_root);
	@override String get resultTitle => 'export complete';
	@override String get resultFailedTitle => 'export failed';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'exported ${count} file to ${path}',
		other: 'exported ${count} files to ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'exported ${count} file: ${path}',
		other: 'exported ${count} files: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'shared ${count} file',
		other: 'shared ${count} files',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'downloaded ${count} file',
		other: 'downloaded ${count} files',
	);
	@override String exportFailed({required Object error}) => 'export failed: ${error}';
	@override late final _Translations$operation$export$stash$qrp stash = _Translations$operation$export$stash$qrp._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$qrp extends Translations$operation$spots$en {
	_Translations$operation$spots$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get empty => 'no spots match your filters';
	@override String error({required Object error}) => 'failed to load spots: ${error}';
	@override String get unknownBand => 'other';
	@override String get auto => 'automatic';
	@override String autoValue({required Object value}) => 'automatic (currently ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'any';
	@override String get allBands => 'all bands';
	@override String get allModes => 'all modes';
	@override String get phoneAndCw => 'phone & cw';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'showing ${count} of ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutes';
	@override String get callsOfNote => 'calls of note';
	@override String get yourSpots => 'your spots';
	@override String get allSpots => 'all spots';
	@override late final _Translations$operation$spots$continents$qrp continents = _Translations$operation$spots$continents$qrp._(_root);
	@override late final _Translations$operation$spots$filters$qrp filters = _Translations$operation$spots$filters$qrp._(_root);
	@override String get unavailableTitle => 'spots unavailable';
	@override String unavailableText({required Object sources}) => '${sources} did not respond.';
	@override String get failedTitle => 'spot source error';
	@override String failedText({required Object sources}) => '${sources} returned an error.';
	@override String get slideLogIt => 'log it';
	@override String get slideIgnore => 'ignore';
	@override String get slideRestore => 'restore';
	@override late final _Translations$operation$spots$logConflict$qrp logConflict = _Translations$operation$spots$logConflict$qrp._(_root);
}

// Path: operation.import
class _Translations$operation$import$qrp extends Translations$operation$import$en {
	_Translations$operation$import$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'import data into operation';
	@override String get importAdifAction => 'import qsos from adif';
	@override String get settingsButton => 'listen settings';
	@override String get settingsTitle => 'listen for other apps';
	@override String get protocolAddressLabel => 'address';
	@override String get protocolPortLabel => 'port';
	@override String get protocolPortInvalid => 'enter a port between 1 and 65535';
	@override String get protocolAddressInvalid => 'enter a valid ip address (e.g. 127.0.0.1 or 239.239.0.2)';
	@override String get protocolStatusReceiving => 'receiving data';
	@override String get protocolStatusNoData => 'no data received recently';
	@override String protocolBindError({required Object error}) => 'couldn\'t start listening: ${error}';
	@override String captureFailed({required Object error}) => 'incoming qsos could not be saved and are being retried: ${error}';
	@override String get n1mmProtocolName => 'n1mm+ contact broadcast';
	@override String get n1mmAddressValue => 'any (broadcast)';
	@override String get wsjtxProtocolName => 'wsjt-x udp server';
	@override String get helpN1mmSetup => 'config → configure ports, mode control… → broadcast data tab → check "enable broadcasts" for contact info. set ip address to 127.0.0.1 if running on this same computer, or 255.255.255.255 to broadcast on the current local network.';
	@override String get helpWsjtxSetup => 'file → settings → reporting tab → udp server section → check "accept udp requests". set udp server to 127.0.0.1 if running on this same computer, or a multicast address such as 239.239.0.2, and use the same address in the configuration above in this app.';
	@override String get listenTitle => 'listen for qsos from other apps';
	@override String get listenDescriptionOnN1mm => 'listening for n1mm+';
	@override String get listenDescriptionOnWsjtx => 'listening for wsjt-x';
	@override String get listenDescriptionOnBoth => 'listening for n1mm+ and wsjt-x';
	@override String get listenDescriptionOff => 'off';
	@override String get addToOperationTitle => 'add to this operation';
	@override String get addToOperationDescriptionOn => 'captured qsos are added to this operation as they arrive';
	@override String get addToOperationDescriptionOff => 'captured qsos are held until you turn this on';
	@override String get pendingSectionTitle => 'captured qsos';
	@override String get pendingEmpty => 'nothing captured yet';
	@override String stationMismatch({required Object call}) => 'logged as ${call}, not this operation\'s station';
	@override String get discardAction => 'discard';
	@override String get gapDialogTitle => 'include earlier captures?';
	@override String gapDialogBody({required Object count}) => '${count} more qsos were captured earlier, before a gap in the data. include them too?';
	@override String get gapDialogRecentOnly => 'just the recent ones';
	@override String gapDialogIncludeAll({required Object count}) => 'include all ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$qrp extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get link => 'issues?';
	@override String get title => 'report an outline issue';
	@override String get reference => 'which outline';
	@override String get severity => 'how bad is it?';
	@override String get minor => 'minor nit';
	@override String get major => 'big deal';
	@override String get explanation => 'what\'s wrong with it?';
	@override String get explanationHint => 'what the outline gets wrong, and where';
	@override String get send => 'send';
	@override String get sending => 'sending your report — thanks';
	@override String get copy => 'copy report';
	@override String get notSent => 'couldn\'t send the report';
	@override String get copied => 'report copied';
	@override String get notCopied => 'couldn\'t copy the report';
}

// Path: map.postcard
class _Translations$map$postcard$qrp extends Translations$map$postcard$en {
	_Translations$map$postcard$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get button => 'operation postcard';
	@override String title({required Object title}) => 'postcard for ${title}';
	@override String get portrait => 'portrait';
	@override String get landscape => 'landscape';
	@override String get square => 'square';
	@override String get save => 'save…';
	@override String get download => 'download';
	@override String get share => 'share';
	@override String get copy => 'copy';
	@override String get copied => 'copied to the clipboard';
	@override String saved({required Object path}) => 'saved to ${path}';
	@override String downloaded({required Object name}) => 'downloaded ${name}';
	@override String savedMany({required Object count, required Object path}) => 'saved ${count} images to ${path}';
	@override String savedFiles({required Object names}) => 'saved ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} had already been saved';
	@override String downloadedMany({required Object count}) => 'downloading ${count} images — allow them if the browser asks';
	@override String get mapLeftOut => 'the map didn\'t load, so it was left out';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — the map didn\'t load, so it was left out';
	@override String continued({required Object title}) => '${title} (continued)';
	@override String get previousPage => 'previous page';
	@override String get nextPage => 'next page';
	@override String pageOf({required Object page, required Object count}) => 'page ${page} of ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} q',
		other: '${count} qs',
	);
	@override String get options => 'postcard options';
	@override String get bandLegend => 'show band legend';
	@override String get grayline => 'show grayline';
	@override String get sectionsAndOrder => 'summary sections and ordering';
	@override String get sectionDays => 'each day';
	@override String get reset => 'reset';
	@override String failed({required Object error}) => 'could not make the postcard: ${error}';
	@override String get mapNotReady => 'the map didn\'t finish loading. check the connection and try again.';
	@override String saveFailed({required Object error}) => 'could not save the postcard: ${error}';
	@override String get copyFailed => 'the clipboard didn\'t take the image. try again.';
	@override String get shareFailed => 'could not share the postcard. try again.';
	@override String get fileName => 'postcard';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$qrp extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'no qsos yet... let\'s get on the air!';
	@override String get qsoCountOne => '1 qso';
	@override String qsoCountOther({required Object count}) => '${count} qsos';
	@override String qsosInTime({required Object count, required Object time}) => '${count} in ${time}';
	@override String sinceLast({required Object time}) => '${time} since last';
	@override String ratePer10({required Object rate}) => '${rate} q/h for last 10';
	@override String ratePer100({required Object rate}) => '${rate} q/h for last 100';
	@override String distanceTo({required Object distance}) => '${distance} to';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to';
	@override String distanceAway({required Object distance}) => '${distance} away';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'dupe!';
	@override String get noticeNewBand => 'new band';
	@override String get noticeNewMode => 'new mode';
	@override String get noticeNewDXCC => 'new dxcc';
	@override String get noticeNewState => 'new state';
	@override String get noticeNewProvince => 'new province';
	@override String get noticeNewDay => 'new day';
	@override String get noticeNewRef => 'new ref';
	@override String get noticeNewMult => 'new mult';
	@override String get noticeNewZone => 'new zone';
	@override String get noticeInvalidMode => 'wrong mode';
	@override String get noticeInvalidBand => 'wrong band';
	@override String get noticeInvalidCategory => 'not workable';
	@override String get noticeOverTime => 'time over';
	@override String get noticeWorkedBefore => 'worked before';
	@override String get noticeNewPark => 'new park';
	@override String get noticeNewSection => 'new section';
	@override String get noticeBonusStation => 'bonus station!';
	@override String get noticeMissingExchange => 'no exchange';
	@override String get noticeInvalidExchange => 'bad exchange';
	@override String get noticeUnknownEvent => 'unknown event';
	@override String get noticeIncompleteCall => 'incomplete call — not scored';
	@override String get noticeOurGrid => 'set our grid';
	@override String get noticeRareCounty => 'rare county!';
	@override String get noticeOurLocation => 'set our county';
	@override String get noticeShortGrid => 'grid too short';
}

// Path: qsoList.find
class _Translations$qsoList$find$qrp extends Translations$qsoList$find$en {
	_Translations$qsoList$find$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'find in log (${shortcut})';
	@override String get menuItemNoShortcut => 'find in log';
	@override String get hint => 'qso number or callsign';
	@override String get noMatches => 'no match';
	@override String get noOperationQsos => 'no qsos in this operation';
	@override String get noPeriodQsos => 'no qsos in this period';
	@override String get outsideQsosOne => '1 qso outside of this operation';
	@override String outsideQsosOther({required Object count}) => '${count} qsos outside of this operation';
	@override String get pastQsosOne => '1 past qso';
	@override String pastQsosOther({required Object count}) => '${count} past qsos';
}

// Path: callInfo.history
class _Translations$callInfo$history$qrp extends Translations$callInfo$history$en {
	_Translations$callInfo$history$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} in last 7 days';
	@override String today({required Object n}) => '${n} today';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${n} qso',
		other: '${n} qsos',
	);
}

// Path: settings.theme
class _Translations$settings$theme$qrp extends Translations$settings$theme$en {
	_Translations$settings$theme$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'theme mode';
	@override String get system => 'follow system settings';
	@override String get light => 'light';
	@override String get dark => 'dark';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$qrp extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get system => 'following system settings';
	@override String get light => 'always in light mode';
	@override String get dark => 'always in dark mode';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$qrp extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'smallest--';
	@override String get smallestMinus => 'smallest-';
	@override String get smallest => 'smallest';
	@override String get smaller => 'smaller';
	@override String get normal => 'normal';
	@override String get larger => 'larger';
	@override String get largest => 'largest';
	@override String get largestPlus => 'largest+';
	@override String get largestPlusPlus => 'largest++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$qrp extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'keep device awake';
	@override String get descriptionOn => 'staying awake while you are on the logging view or a sync is in progress';
	@override String get descriptionOff => 'sleeping as usual';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$qrp extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get auto => 'automatic';
	@override String get densest => 'densest';
	@override String get dense => 'dense';
	@override String get normal => 'normal';
	@override String get sparse => 'sparse';
	@override String get sparsest => 'sparsest';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$qrp extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'kilometers';
	@override String get miles => 'miles';
}

// Path: settings.logging
class _Translations$settings$logging$qrp extends Translations$settings$logging$en {
	_Translations$settings$logging$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'logging';
	@override late final _Translations$settings$logging$leftieMode$qrp leftieMode = _Translations$settings$logging$leftieMode$qrp._(_root);
	@override late final _Translations$settings$logging$countryFlags$qrp countryFlags = _Translations$settings$logging$countryFlags$qrp._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$qrp countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$qrp._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$qrp suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$qrp._(_root);
	@override late final _Translations$settings$logging$showBearing$qrp showBearing = _Translations$settings$logging$showBearing$qrp._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$qrp showReverseBearing = _Translations$settings$logging$showReverseBearing$qrp._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$qrp switchSentRcvd = _Translations$settings$logging$switchSentRcvd$qrp._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$qrp jumpAfterRST = _Translations$settings$logging$jumpAfterRST$qrp._(_root);
	@override late final _Translations$settings$logging$defaultReport$qrp defaultReport = _Translations$settings$logging$defaultReport$qrp._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$qrp defaultReportCW = _Translations$settings$logging$defaultReportCW$qrp._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$qrp defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$qrp._(_root);
	@override late final _Translations$settings$logging$numbersRow$qrp numbersRow = _Translations$settings$logging$numbersRow$qrp._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$qrp numbersRowExtra = _Translations$settings$logging$numbersRowExtra$qrp._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$qrp numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$qrp._(_root);
	@override String get bands => 'preferred bands';
	@override String get modes => 'preferred modes';
}

// Path: settings.catServer
class _Translations$settings$catServer$qrp extends Translations$settings$catServer$en {
	_Translations$settings$catServer$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'cat server';
	@override String get description => 'allow other apps (wsjt-x, loggers, etc) to control the radio through ham2k logger.';
	@override String get protocol => 'protocol';
	@override late final _Translations$settings$catServer$protocolOpts$qrp protocolOpts = _Translations$settings$catServer$protocolOpts$qrp._(_root);
	@override String get port => 'port';
	@override String get openAccess => 'open access';
	@override String get openAccessOn => 'any computer on the local network can connect.';
	@override String get openAccessOff => 'only apps on this computer can connect.';
	@override String get off => 'off.';
	@override String starting({required Object protocol}) => '${protocol}, starting…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} on port ${port}. clients connected: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} on port ${port}, but no main vfo radio is connected.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} cannot listen on port ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: another program is using it, often ${protocol} itself. close that program or choose another port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: this computer does not allow it. choose a port above 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} stopped listening on port ${port}. trying again…';
}

// Path: settings.cluster
class _Translations$settings$cluster$qrp extends Translations$settings$cluster$en {
	_Translations$settings$cluster$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'dx cluster';
	@override String get description => 'the server extensions post spots to and read spots from, logged in as the operator.';
	@override String get server => 'cluster server';
	@override String get selectServer => 'select server';
	@override String get serverOther => 'other';
	@override String serverOtherIncomplete({required Object node}) => 'no host entered yet, so spots go to ${node}';
	@override String get customHost => 'server';
	@override String get customPort => 'port';
	@override String get password => 'password';
	@override String get passwordDescription => 'only if needed';
	@override String passwordStored({required Object node}) => 'password on file for ${node}';
	@override String get scrollback => 'lines kept';
	@override String scrollbackOpt({required Object count}) => '${count} lines';
	@override String get connection => 'connection';
	@override String get statusIdle => 'not connected. connects when an extension needs it. tap to test.';
	@override String statusConnecting({required Object node}) => 'connecting to ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'connected to ${node} as ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'could not connect to ${node}: ${reason}';
	@override String get statusUnsupported => 'not available in the web version.';
	@override late final _Translations$settings$cluster$errors$qrp errors = _Translations$settings$cluster$errors$qrp._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$qrp extends Translations$settings$spotting$en {
	_Translations$settings$spotting$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'spotting';
	@override String get respotInterval => 'auto re-spot every';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'auto re-spot by default';
	@override String get autoRespotByDefaultOn => 'enable auto re-spot after any spot is posted';
	@override String get autoRespotByDefaultOff => 'require user action to enable auto re-spotting';
	@override String get pulseBeforeRespot => 'pulse before each auto re-spot';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'the spotting chip pulses blue for the ${seconds} seconds before each re-spot';
	@override String get pulseBeforeRespotOff => 'no pulsing before an auto re-spot';
}

// Path: settings.radio
class _Translations$settings$radio$qrp extends Translations$settings$radio$en {
	_Translations$settings$radio$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'cat control';
	@override String get loggingAndCat => 'logging & cat';
	@override String get tuningSection => 'tuning';
	@override String get keyerSection => 'keyer';
	@override String get servicesSection => 'services';
	@override String get stationConfigurationSection => 'station configuration';
	@override String get moreSettings => 'more station configuration settings';
	@override late final _Translations$settings$radio$units$qrp units = _Translations$settings$radio$units$qrp._(_root);
	@override late final _Translations$settings$radio$pttKey$qrp pttKey = _Translations$settings$radio$pttKey$qrp._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$qrp smartVfoSnap = _Translations$settings$radio$smartVfoSnap$qrp._(_root);
	@override late final _Translations$settings$radio$snapDebounce$qrp snapDebounce = _Translations$settings$radio$snapDebounce$qrp._(_root);
	@override late final _Translations$settings$radio$snapLongMove$qrp snapLongMove = _Translations$settings$radio$snapLongMove$qrp._(_root);
	@override late final _Translations$settings$radio$snapMinMove$qrp snapMinMove = _Translations$settings$radio$snapMinMove$qrp._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$qrp snapMinSpeed = _Translations$settings$radio$snapMinSpeed$qrp._(_root);
	@override late final _Translations$settings$radio$enterSends$qrp enterSends = _Translations$settings$radio$enterSends$qrp._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$qrp keyerSpeed = _Translations$settings$radio$keyerSpeed$qrp._(_root);
	@override late final _Translations$settings$radio$cwMessages$qrp cwMessages = _Translations$settings$radio$cwMessages$qrp._(_root);
	@override late final _Translations$settings$radio$voiceMessages$qrp voiceMessages = _Translations$settings$radio$voiceMessages$qrp._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$qrp avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$qrp._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$qrp zeroBeatRange = _Translations$settings$radio$zeroBeatRange$qrp._(_root);
}

// Path: settings.help
class _Translations$settings$help$qrp extends Translations$settings$help$en {
	_Translations$settings$help$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'help & resources';
	@override String get description => 'community and support';
	@override String get forums => 'ham2k forums';
	@override String get forumsDescription => 'find help, give feedback, discuss ideas…';
	@override String get chat => 'ham2k chat';
	@override String get chatDescription => 'the discord server for our online community';
	@override String get youtube => 'ham2k youtube';
	@override String get youtubeDescription => 'videos and live streams';
	@override String get instagram => 'ham2k instagram';
	@override String get instagramDescription => 'because you cannot have too many photos…';
	@override String get bluesky => 'ham2k bluesky';
	@override String get blueskyDescription => 'follow us for news and updates';
	@override String get contact => 'contact us';
	@override String get contactDescription => 'help@ham2k.com — but try the forums or chat first!';
}

// Path: settings.exports
class _Translations$settings$exports$qrp extends Translations$settings$exports$en {
	_Translations$settings$exports$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'exports';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$qrp extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get activities => 'activities';
	@override String get hunting => 'hunting';
	@override String get contests => 'contests';
	@override String get lookups => 'lookups';
	@override String get dashboard => 'dashboard';
}

// Path: settings.map
class _Translations$settings$map$qrp extends Translations$settings$map$en {
	_Translations$settings$map$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'maps';
	@override late final _Translations$settings$map$style$qrp style = _Translations$settings$map$style$qrp._(_root);
	@override late final _Translations$settings$map$showCallsigns$qrp showCallsigns = _Translations$settings$map$showCallsigns$qrp._(_root);
	@override late final _Translations$settings$map$showGrayline$qrp showGrayline = _Translations$settings$map$showGrayline$qrp._(_root);
	@override late final _Translations$settings$map$styleOpts$qrp styleOpts = _Translations$settings$map$styleOpts$qrp._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$qrp extends Translations$settings$privacy$en {
	_Translations$settings$privacy$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'privacy';
	@override late final _Translations$settings$privacy$shareAppData$qrp shareAppData = _Translations$settings$privacy$shareAppData$qrp._(_root);
	@override late final _Translations$settings$privacy$shareOpData$qrp shareOpData = _Translations$settings$privacy$shareOpData$qrp._(_root);
	@override String get privacyPolicy => 'privacy policy';
	@override String get termsOfService => 'terms of service';
}

// Path: settings.sync
class _Translations$settings$sync$qrp extends Translations$settings$sync$en {
	_Translations$settings$sync$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'cloud sync';
	@override String get moreSettings => 'more sync settings';
	@override String get enable => 'enable sync';
	@override String get deviceKey => 'device key';
}

// Path: settings.peers
class _Translations$settings$peers$qrp extends Translations$settings$peers$en {
	_Translations$settings$peers$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'peer devices';
	@override String get enable => 'connect to other devices';
	@override String get enableDescription => 'allow sharing operations, logging, cat and gps with other devices over the local network';
	@override String get bleEnable => 'connect over bluetooth';
	@override String get bleDescription => 'use bluetooth le to connect even if there is no local network';
	@override String get thisDevice => 'this device';
	@override String get deviceName => 'name';
	@override String get deviceNameHint => 'how this device is seen by other devices';
	@override String get pairedDevices => 'linked devices';
	@override String get noPairedDevices => 'no devices linked yet. turn this on, on another device on this network, to link them.';
	@override String deviceListProblem({required Object error}) => 'can\'t read your linked devices: ${error}';
	@override String get nearby => 'nearby';
	@override String get connected => 'connected';
	@override String get viaBluetooth => 'via bluetooth';
	@override String get connecting => 'connecting…';
	@override String get syncing => 'syncing…';
	@override String get waitingForThem => 'waiting for the other device';
	@override String get notConnected => 'not connected';
	@override String get wantsToPair => 'wants to share this operation';
	@override String get allow => 'allow';
	@override String get link => 'link';
	@override String get reject => 'reject';
	@override String get forget => 'forget';
	@override String forgetTitle({required Object name}) => 'forget ${name}?';
	@override String get forgetBody => 'it will stop syncing with this device. you can allow it again later, and contacts already logged are kept.';
	@override String pairTitle({required Object name}) => 'link with ${name}';
	@override String get pairBody => 'this device is on your local network and wants to connect.';
	@override String get pairBodyBle => 'this device is nearby and wants to connect over bluetooth le.';
	@override String get pairIdLabel => 'device id';
	@override String get pairWarning => 'only link with devices you recognise. any device on this network can send a request.';
	@override String get pairWarningBle => 'only link with devices you recognise. any nearby device can send a request.';
	@override String problem({required Object error}) => 'can\'t reach the local network: ${error}';
	@override String bleProblem({required Object error}) => 'bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'connected to ${device}';
	@override String statusLost({required Object device}) => 'lost connection to ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'peer devices: ${connected} of ${linked} connected';
	@override String get screenEnable => 'share screens and windows';
	@override String get screenDescription => 'allow other devices to show screens or windows from this computer';
	@override String get screenSources => 'screens and windows';
	@override String get screenRefresh => 'refresh the list';
	@override String get screenUnsupportedPlatform => 'this device can\'t share its screen. macos can; every device can show one shared by another.';
	@override String get screenUnsupportedVersion => 'sharing a screen needs macos 12.3 or later. this device can still show a screen shared by another.';
	@override String get screenNeedsPermission => 'macos needs your permission to record the screen before this app can share one.';
	@override String get screenGrantPermission => 'ask for permission';
	@override String get screenRelaunchAfterGranting => 'allow it in system settings under privacy & security → screen recording, then quit and reopen this app — macos only tells an app about the change on its next launch.';
	@override String screenProblem({required Object error}) => 'screen sharing: ${error}';
	@override String get screenChooseTitle => 'choose what to share';
	@override String get screenChooseButton => 'choose what to share…';
	@override String get screenTabScreens => 'screens';
	@override String get screenTabApps => 'apps';
	@override String get screenTabWindows => 'windows';
	@override String get screenTabEmpty => 'nothing of this kind was found.';
	@override String get screenSharedSummaryNone => 'nothing chosen yet.';
	@override String get screenThisDevice => 'this device';
	@override String screenSharedTo({required Object devices}) => 'shown on ${devices}';
	@override String get screenSharedToNobody => 'not being shown';
	@override String screenStopSharing({required Object name}) => 'stop sharing ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$qrp extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'sync configuration';
	@override String get enableTitle => 'sync with ham2k log filer';
	@override String get enabledDescription => 'backing up and syncing your log across devices';
	@override String get disabledDescription => 'off — staying on this device only';
	@override String get syncing => 'syncing';
	@override String get account => 'account';
	@override String get refresh => 'refresh';
	@override String get switchAccounts => 'switch accounts';
	@override String get switchAccountsDescription => 'link this device to another account with a qr code or email';
	@override String get connectionRequests => 'connection requests';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'a device is waiting to join this account',
		other: '${n} devices are waiting to join this account',
	);
	@override String get accountEmailTitle => 'account email';
	@override String accountEmailSent({required Object email}) => 'confirmation sent to ${email}. open the link there to finish the change.';
	@override String get resendConfirmation => 'resend confirmation email';
	@override String resendConfirmationDescription({required Object email}) => 'waiting on ${email}';
	@override String accountEmailResent({required Object email}) => 'sent again to ${email}.';
	@override String get deviceLinked => 'that device is now linked to this account.';
	@override String get checking => 'checking…';
	@override String get notLinked => 'not linked yet';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'replace local data?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${n} operation',
		other: '${n} operations',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${n} qso',
		other: '${n} qsos',
	);
	@override String get counts => 'synced data';
	@override String countsLocal({required Object qsos, required Object operations}) => 'this device: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'waiting to upload: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'this device: checking…';
	@override String get countsServerChecking => 'server: checking…';
	@override String get countsServerUnavailable => 'server: not available';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'this backs up and clears ${operations} and ${qsos} from this device, then downloads the account\'s data instead. the backup stays in this device\'s database.';
	@override String get replace => 'replace';
	@override String get pendingBannerTitle => 'new ham2k log filer account detected';
	@override String get pendingBannerBody => 'keep this device\'s existing operations and qsos and merge them into the account, or replace them with the account\'s data (a backup stays on this device either way).';
	@override String get combine => 'combine';
	@override String get authIssueTitle => 'sync can\'t connect';
	@override String get authIssueText => 'ham2k log filer keeps rejecting this device. check your callsign in sync settings.';
	@override String get openSettings => 'open sync settings';
}

// Path: settings.accounts
class _Translations$settings$accounts$qrp extends Translations$settings$accounts$en {
	_Translations$settings$accounts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'accounts, services & data sources';
	@override String get none => 'no active extensions with accounts';
	@override String get notConfigured => 'not configured';
	@override String get connected => 'connected';
	@override String get cancelLogin => 'cancel sign-in';
	@override String get openInBrowser => 'open in browser';
	@override String loggedInAs({required Object identity}) => 'logged in as ${identity}';
	@override String get pressSaveToKeep => 'press save to keep this account connected.';
	@override String connectedTo({required Object label}) => 'connected to ${label}';
	@override String get connect => 'connect';
	@override String get disconnect => 'disconnect';
	@override String get connectedAs => 'connected as';
	@override String get test => 'test';
	@override String saveFailed({required Object error}) => 'save failed: ${error}';
	@override String loginFailed({required Object error}) => 'login failed: ${error}';
	@override String get lookupFailed => 'accounts are unavailable right now — try again in a moment';
	@override String get browserLoginTitle => 'finish signing in with your web browser';
	@override String browserLoginSteps({required Object prefix}) => 'when you are done, the browser will try to open a link starting with "${prefix}". your desktop most likely has nothing registered to open it, so copy that link (from the address bar, or from the error page the browser shows) and paste it here.';
	@override String browserLoginNotOpened({required Object prefix}) => 'ham2k logger could not open your browser. copy the login link below and open it yourself, then copy the link it sends you to (it starts with "${prefix}") and paste that here.';
	@override String get copyLoginLink => 'copy login link';
	@override String get pastedLinkLabel => 'paste the link here';
	@override String get finishLogin => 'finish login';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'that is not the login link — it should start with "${prefix}".';
	@override String get pastedLinkWrongLogin => 'that link belongs to a different login attempt. close this page and connect again.';
	@override String get pastedLinkNoCode => 'that link has no login code. finish signing in first, then copy the link it sends you to.';
	@override String get pastedLinkMalformed => 'that link looks cut off. copy the whole thing and paste it again.';
	@override String get relayLoginWaiting => 'waiting for you to finish signing in — this will continue automatically once you do.';
	@override String get loginNoResponse => 'this device hasn\'t heard back from the sign-in yet. if you already finished in your browser, cancel and try connecting again.';
	@override String get relayLoginNotOpened => 'ham2k logger could not open your browser automatically. use the button below to open the login page yourself.';
	@override String get relayLoginUnavailable => 'couldn\'t reach the sync server needed to complete this login. check your connection and try again.';
	@override String get loginIncompleteResponse => 'that login attempt didn\'t complete correctly. please try connecting again.';
	@override String get noKeyringTitle => 'account logins can’t be saved';
	@override String get noKeyringText => 'ham2k logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. install and start **gnome-keyring**, **kwallet** or **keepassxc**, or unlock the keyring you already have, then restart. logging, exports and data files are unaffected; log sync stays off while this lasts.';
	@override String get noKeyringInline => 'logins can’t be saved: this computer’s keyring can’t be reached. install and start gnome-keyring, kwallet or keepassxc, or unlock the one you have.';
	@override String get noSecureStorageInline => 'logins can’t be saved: this computer’s secure storage can’t be reached.';
}

// Path: settings.station
class _Translations$settings$station$qrp extends Translations$settings$station$en {
	_Translations$settings$station$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'station configuration & cat control';
	@override String get none => 'no equipment configured';
	@override String get add => 'add';
	@override String get addTitle => 'add equipment';
	@override String get searchHint => 'search equipment';
	@override String get noMatches => 'no equipment matches';
	@override String get detectedEquipment => 'detected equipment';
	@override String discoveryUnavailable({required Object error}) => 'can\'t listen for radios: ${error}';
	@override String get edit => 'edit equipment';
	@override String get name => 'name';
	@override String get nameDescription => 'what you call it — "left radio". optional.';
	@override String get transport => 'connection';
	@override String get host => 'address';
	@override String get hostDescription => 'the radio\'s hostname or ip address on your network.';
	@override String get port => 'port';
	@override String get hostRequired => 'an address is required';
	@override String get portInvalid => 'port must be between 1 and 65535';
	@override String get connect => 'connect';
	@override String get disconnect => 'disconnect';
	@override String get remove => 'remove';
	@override String removeTitle({required Object name}) => 'remove ${name}?';
	@override String get removeMessage => 'this only removes it from the app. the equipment\'s settings stay as they are.';
	@override String unknownType({required Object typeKey}) => 'unrecognized equipment type "${typeKey}"';
	@override String get report => 'report';
	@override String get reportTitle => 'report this radio';
	@override String get reportIntro => 'tell us what radio this really is and how it went. your report becomes a card the ham2k team reads, and what you write about getting it working may end up helping the next operator with the same rig.';
	@override String get reportManufacturer => 'manufacturer';
	@override String get reportManufacturerDescription => 'who makes it — icom, yaesu, kenwood, elecraft…';
	@override String get reportManufacturerRequired => 'a manufacturer is required';
	@override String get reportModel => 'model';
	@override String get reportModelDescription => 'the model, as the radio itself calls it — "ic-7300", "ft-991a".';
	@override String get reportModelRequired => 'a model is required';
	@override String get reportOutcome => 'how did it go?';
	@override String get reportOutcomeWorks => 'worked well';
	@override String get reportOutcomeIssues => 'worked, with issues';
	@override String get reportOutcomeFails => 'didn\'t work at all';
	@override String get reportOutcomeRequired => 'please tell us how it went';
	@override String get reportComments => 'comments';
	@override String get reportCommentsPlaceholder => 'what worked, what didn\'t, anything that surprised you.';
	@override String get reportHints => 'troubleshooting hints';
	@override String get reportHintsPlaceholder => 'want to suggest some troubleshooting hints for other users?';
	@override String get reportSend => 'send report';
	@override String get reportSending => 'sending your report…';
	@override String reportSent({required Object ref}) => 'thanks — your report was filed as ${ref}.';
	@override String get reportSentNoRef => 'thanks — your report was sent.';
	@override String reportFailed({required Object error}) => 'the report wasn\'t sent: ${error}';
	@override String get troubleshootingNotes => 'troubleshooting notes';
	@override String get mainVfo => 'main vfo';
	@override String get useAsMainVfo => 'use as main vfo';
	@override String get serialPort => 'serial port';
	@override String get serialPortDescription => 'the port the radio\'s cat interface appears on.';
	@override String get serialPortNone => 'no serial ports found';
	@override String get serialPortRequired => 'choose a serial port';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} of ${total}';
	@override String get serialPortSuggested => 'suggested';
	@override String get serialPortJustNow => 'recently connected';
	@override String get serialDeviceRequest => 'add a usb device…';
	@override String get bleDevice => 'bluetooth le device';
	@override String get bleDeviceDescription => 'the serial bridge your radio is connected through, such as a link500mp in its ios mode or a ble serial adapter.';
	@override String get bleScan => 'scan for bluetooth le devices…';
	@override String get bleScanNoneFound => 'no bluetooth le devices found. check that the bridge is on, nearby, and in its bluetooth le (ios) mode.';
	@override String bleScanFailed({required Object reason}) => 'the bluetooth le scan could not run: ${reason}';
	@override String get bleOff => 'bluetooth is turned off.';
	@override String get bleDenied => 'bluetooth permission was not granted. allow it in system settings, then try again.';
	@override String get bleUnsupported => 'this device has no bluetooth le.';
	@override String get bleStarting => 'bluetooth is still starting up. try again in a moment.';
	@override String get bleConnectFailed => 'cannot reach the bluetooth le device. check that it\'s on, nearby, and not connected to another app.';
	@override String bleNoSerialService({required Object services}) => 'this bluetooth le device has no serial service the app recognizes. please report it with its services: ${services}';
	@override String get baudRate => 'speed (baud)';
	@override String get baudRateDescription => 'must match the radio\'s cat menu. with a mismatch, the radio sends back garbage and no error.';
	@override String get serialRtsHigh => 'hold rts high';
	@override String get serialRtsHighDescription => 'only for a radio that waits for rts before responding, such as a yaesu with cat rts turned on. on a digirig, signalink and most home-made cables rts is ptt, and holding it high transmits.';
	@override String get serialDtrHigh => 'hold dtr high';
	@override String get serialDtrHighDescription => 'only for a cat interface that draws its power from dtr, such as some rs-232 cables for the ft-817. on many cables dtr keys cw or ptt, and holding it high transmits.';
	@override String get civAddress => 'radio ci-v address';
	@override String get civAddressDescription => 'hex, as shown in the radio\'s ci-v menu. the ic-705 ships as a4.';
	@override String get civAddressInvalid => 'a ci-v address is two hex digits, 01 to ff';
	@override String get flexSlice => 'slice';
	@override String get flexSliceDescription => 'which of the radio\'s slices this connection reads from and tunes.';
	@override String flexSliceLabel({required Object letter}) => 'slice ${letter}';
	@override String get flexSliceInvalid => 'pick one of the radio\'s slices, a through h';
	@override String flexSliceMissing({required Object letter}) => 'slice ${letter} is not in use on this radio — pick another slice, or create it in smartsdr';
	@override String get channelNotInUse => 'not in use';
	@override String get channelHeldByUnknown => 'in use by another program';
	@override String get flexNoSlices => 'this radio has not reported any slices — check that smartsdr is running and that this client may subscribe';
	@override String get spectrumUnsupported => 'this radio sends no spectrum over cat';
	@override String get spectrumRequiresBaud => 'requires cat at 115200 bps';
	@override String get spectrumNoRadio => 'no radio connected';
	@override String get spectrumWaiting => 'waiting for the radio\'s spectrum…';
	@override String get spectrumUnavailable => 'spectrum display is not available';
	@override String get spectrumNoDaxChannel => 'every dax iq channel on this radio is in use';
	@override String get spectrumNoPanadapter => 'this slice has no panadapter on the radio';
	@override String spectrumStreamRefused({required Object code}) => 'the radio refused a dax iq stream (error ${code})';
	@override String get spectrumNoUdp => 'the radio\'s spectrum data cannot reach this device';
	@override String get spectrumK4Unavailable => 'cannot receive the k4’s lan spectrum. retrying…';
	@override String get spectrumK4RemoteUnavailable => 'cannot receive the k4’s remote spectrum';
	@override String get spectrumScopeRefused => 'the radio refused its scope commands';
	@override String get spectrumOutOfRange => 'the radio\'s scope is set outside the range it can show';
	@override String get spectrumBandUnsupported => 'the radio\'s scope cannot be shown on this band';
	@override String get spectrumSdrNoRadio => 'waiting for the linked radio\'s frequency…';
	@override String get spectrumSdrNotConnected => 'the sdr is not connected';
	@override String get spectrumSdrNoIf => 'set the radio\'s if frequency in this sdr\'s settings';
	@override String get sdrRadio => 'shows the spectrum for';
	@override String get sdrRadioDescription => 'a spectrum display on this radio draws from this receiver instead of the radio\'s own scope.';
	@override String get sdrRadioMain => 'the main radio';
	@override String get sdrTuning => 'antenna input';
	@override String get sdrTuningDescription => 'where the receiver\'s signal comes from. on its own antenna it tunes itself to follow the radio; on the radio\'s if output it stays on the if.';
	@override String get sdrTuningIndependent => 'its own antenna';
	@override String get sdrTuningIfTap => 'the radio\'s if output';
	@override String get sdrIfHz => 'if frequency (hz)';
	@override String get sdrIfHzDescription => 'for an if output only: the frequency the radio\'s dial sits at on its if, such as 68330000 on an ft-817.';
	@override String get sdrIfInverted => 'if is inverted';
	@override String get sdrGainDb => 'gain (db)';
	@override String get sdrGainDbDescription => 'leave blank for the receiver\'s automatic gain.';
	@override String get sdrOffsetHz => 'frequency offset (hz)';
	@override String get sdrOffsetHzDescription => 'added to every frequency sent to the receiver, for an upconverter: 125000000 for a ham it up.';
	@override String get sdrPpm => 'frequency correction (ppm)';
	@override String get rtlDirectSampling => 'direct sampling';
	@override String get rtlDirectSamplingDescription => 'for hf on an rtl-sdr v3 without an upconverter. an rtl-sdr v4 reaches hf without it.';
	@override String get rtlDirectSamplingOff => 'off';
	@override String get rtlDirectSamplingI => 'i branch';
	@override String get rtlDirectSamplingQ => 'q branch';
	@override String get rtlTcpNotAServer => 'this is not an rtl_tcp server';
	@override String get rtlTcpNotes => 'this connects to an **rtl_tcp server you run yourself** on the computer the dongle is plugged into.\n\n- **start it** with `rtl_tcp -a 0.0.0.0` so other machines can reach it; on the same machine, `rtl_tcp` alone will do.\n- **port** is 1234 unless you started it with `-p`.\n- **one program at a time:** rtl_tcp serves a single client. the app connects only while a spectrum display is showing, and lets go a few seconds after it closes.\n- **on android**, the *sdr driver* app runs the same server on the phone.';
	@override String get rspTcpNotes => 'this connects to an **rsp_tcp server you run yourself** on the computer the rsp is plugged into, with sdrplay\'s api installed there.\n\n- **start it** with `rsp_tcp -a 0.0.0.0`.\n- **port** is 1234 unless you started it with `-p`.\n- **one program at a time:** the server takes a single client. the app connects only while a spectrum display is showing.';
	@override String get n3fjpNoRig => 'n3fjp has no radio interface set up, so this follows what is typed into n3fjp, not a radio';
	@override String get winkeyerKeyPort => 'key output';
	@override String get winkeyerKeyPortDescription => 'which of the keyer\'s two output jacks your radio is plugged into.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'port ${n}';
	@override String get winkeyerPtt => 'use the keyer\'s ptt';
	@override String get winkeyerPttDescription => 'key the ptt line on the same jack, for an amplifier or a radio that needs it. leave off for a radio keyed on its key jack.';
	@override String get winkeyerNoAnswer => 'no winkeyer responded on this port';
	@override String get winkeyerStoppedAnswering => 'the winkeyer stopped responding while sending; the message was dropped';
	@override String get icomControlPort => 'control port (udp)';
	@override String get icomControlPortDescription => 'the radio\'s control port (udp) — 50001 unless changed in its network settings, or forwarded to another.';
	@override String get icomSerialPort => 'serial port (udp)';
	@override String get icomSerialPortDescription => 'the radio\'s serial port (udp) — 50002 unless changed in its network settings, or forwarded to another.';
	@override String get icomPortsDiffer => 'the control and serial ports must differ';
	@override String get radioUser => 'radio username';
	@override String get radioPass => 'radio password';
	@override String get radioLoginDescription => 'the radio\'s network → remote login, not your wifi password.';
	@override String get radioUserRequired => 'the radio\'s remote-control username is required';
	@override String get connectFailedBusy => 'device is in use';
	@override String get connectFailedDenied => 'access denied';
	@override String get connectFailedDevice => 'device not found';
	@override String get connectFailedLines => 'rts/dtr could not be held as set, so the port was closed. another program may have left hardware handshaking on — unplug and replug the cable.';
	@override String get connectFailedNetwork => 'cannot find the radio over the network. check its address and that it\'s powered on and reachable.';
	@override String get connectFailedTimeout => 'the radio didn\'t respond in time. check it\'s powered on and reachable.';
	@override late final _Translations$settings$station$models$qrp models = _Translations$settings$station$models$qrp._(_root);
	@override late final _Translations$settings$station$transports$qrp transports = _Translations$settings$station$transports$qrp._(_root);
	@override String get troubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get ft891Troubleshooting => 'the radio is receiving commands but not responding. almost always one of:\n\n- **cat rts off at the radio, or hold rts high on.** with **cat rts** on (ft-891 menu **05-08**), the radio stays silent while rts is low — it may answer once as the port opens, then nothing. picking the radio\'s own usb port turns on **hold rts high** under advanced settings. on a digirig, signalink or most home-brew cables rts is ptt, and holding it high keys your transmitter: turn cat rts off at the radio instead.\n- **speed must match** the radio\'s cat rate (menu **05-06**). with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.';
	@override String get yaesuBinaryTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get yaesuBinaryTroubleshooting => 'this radio speaks yaesu\'s older five-byte cat, and it does not respond at all when something is off. almost always one of:\n\n- **the cable must convert levels.** the cat jack on the back is not rs-232 and not usb; it needs a ct-62 or an equivalent adapter. a plain audio or data cable won\'t work for cat.\n- **speed must match** the radio\'s cat rate menu (**#14** on an ft-817, **#19** on an ft-857 or ft-897). with a mismatch, the radio sends nothing back, and never an error.\n- **never let anything raise rts or dtr on this port.** on most cables for these radios those lines are ptt and keying. an older interface powered from dtr is the exception: turn on **hold dtr high** under advanced settings for that one.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis driver was written from yaesu\'s published cat chart and has not been run against one of these radios. if it half-works, that is worth reporting.';
	@override String get tenTecTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get tenTecEagleTroubleshooting => '- **the usb-b port on the back is the cat link.** the radio shows up as a usb serial port; on windows it needs ten-tec\'s usb to uart driver, which appears in device manager as "usb to uart (comx)".\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open, and so does ten-tec\'s firmware updater.\n- **setting the filter width from the app takes it away from the bw knob** until the radio is switched off and on again. that is how the radio works.\n\nthis driver was written from ten-tec\'s programmer\'s reference guide. if it half-works, that is worth reporting, with the firmware version from the radio\'s menu.';
	@override String get tenTecOrionTroubleshooting => '- **use a straight-through db-9 serial cable** to the serial data port, not a null-modem one.\n- **this entry holds rts high**, because the orion uses rts and cts as its handshake. on an interface that keys ptt from rts, such as a digirig, turn off hold rts high under advanced settings, or the radio transmits as soon as the app connects.\n- **cw from the app needs the radio\'s internal keyer on.** with it off, the radio ignores what the app sends.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis driver was written from ten-tec\'s programmer\'s reference guide and has not been run against an orion. if it half-works, that is worth reporting, with the firmware version from the radio\'s menu.';
	@override String get tenTecNoCw => 'this radio\'s firmware does not take cw from the app. ten-tec added it in orion firmware 1.366.';
	@override String get tenTecKeyerOff => 'the radio\'s internal keyer is off, so it ignores cw sent from the app. turn the keyer on in the radio\'s menu.';
	@override String get guohetecTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get guohetecTroubleshooting => 'the q900 has two cat protocols, and this entry uses its native one rather than the ft-817 imitation. pick **guohetec q900** here, not an ft-817 — the imitation supports fewer commands, and the radio does not say which one it is using.\n\n- **the usb-c cable is the cat link**, and it connects the sound card too. speed does not matter on it; the port ignores whatever it is set to.\n- **never let anything raise rts or dtr on this port.** on a serial cable those lines are ptt and keying.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **a second-generation radio behaves differently** from a first. long press menu, then about: hw 2.0 is the second generation.\n\nthis driver was written from the manufacturer\'s published protocol and has not been run against one of these radios. if it half-works, that is worth reporting.';
	@override String get yaesuTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get yaesuTroubleshooting => 'the radio is receiving commands but not responding. almost always one of:\n\n- **cat rts must be off at the radio.** with it on, the radio waits for a handshake line the app keeps low. on a digirig, signalink or most home-brew cables that same line is ptt, so raising it would key your transmitter. on the radio\'s own usb port, **hold rts high** under advanced settings is the alternative. where that setting lives differs by model (menu **05-08** on an ft-891).\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **modes follow the ft-891\'s table.** most of the yaesu line matches it, but a radio that numbers its modes differently will show and set the wrong one for those. the frequency is unaffected.';
	@override String get yaesuRs232Troubleshooting => 'the radio is receiving commands but not responding. almost always one of:\n\n- **the cat jack is rs-232.** it needs a usb-to-serial adapter and a straight-through db-9 cable — a null-modem cable swaps the lines, and the radio never hears a thing.\n- **cat rts must be off at the radio.** with it on, the radio waits for a handshake line the app keeps low unless **hold rts high** is on under advanced settings.\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis entry was written from published cat documentation and has not been run against one of these radios. if it half-works, that is worth reporting.';
	@override String get yaesuUsbTroubleshooting => 'the radio is receiving commands but not responding. almost always one of:\n\n- **use the first of the radio\'s two usb ports.** cat is normally on the first (the **enhanced** com port on windows); the second (**standard**) is for ptt and keying. the picker points at the first wherever it can tell the two apart.\n- **cat rts off at the radio, or hold rts high on.** with the radio\'s **cat rts** menu on, it stays silent while rts is low — it may answer once as the port opens, then nothing. picking the radio\'s own usb port turns on **hold rts high** under advanced settings. on a digirig, signalink or most home-brew cables rts is ptt, and holding it high keys your transmitter: turn cat rts off at the radio instead.\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.';
	@override String get k4SerialNotes => 'connect the k4’s rear usb-b (pc) socket. either usb-pc1 or usb-pc2 works for cat; choose an unused port and match its serial usb-pcn: baud rate setting on the radio. halo prefills 38400; change it if needed. another application must use the other port or ethernet.\n\nthis connection controls the radio and its keyers; it does not send audio to halo.';
	@override String get k4TcpNotes => 'connect the k4’s ethernet socket to your local network. enter its hostname or ip address and cat port 9200. halo uses the same host on fixed port 9201 when a panadapter or waterfall is visible; changing the cat port does not change the spectrum port.\n\nthe spectrum shows the main receiver. its zoom, reference adjustment and speed controls affect only halo’s display. audio streaming is not supported.';
	@override String get k4PowerTimeout => 'k4 power was not changed because the radio did not confirm its output range. try again.';
	@override String get k4RemoteNotes => 'enable remote access on your k4 and enter its network password. main and sub share one encrypted connection for radio control and spectrum. the default port is 9204; enter your forwarded port when connecting remotely.\n\naudio playback and microphone streaming are not supported.';
	@override String get k4Receiver => 'receiver';
	@override String get k4ReceiverMain => 'main';
	@override String get k4ReceiverSub => 'sub';
	@override String get k4ReceiverInvalid => 'choose main or sub';
	@override String get k4ReceiverAlreadyConfigured => 'that receiver is already configured for this k4';
	@override String get k4SubReceiverOff => 'the k4 sub receiver is off';
	@override String get k4RemotePasswordRequired => 'enter the k4’s network password to connect securely.';
	@override String get k4RemoteHandshakeFailed => 'the k4 could not establish a secure connection. check its network password and remote access settings.';
	@override String get k4RemoteUnreachable => 'the k4’s secure connection could not be reached. check its address, port and remote access settings.';
	@override String get k4PowerRange => 'k4 power must be 0.1–110 w, or 0.0001–0.01 w when the transverter milliwatt output is active.';
	@override String get elecraftTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get elecraftTroubleshooting => 'elecraft rigs speak kenwood cat, and a kx2 and a kx3 have both been run this way — vfo in both directions, mode switching and cw zero-beat all working.\n\nif the radio does not respond, almost always one of:\n\n- **speed must match** the rate set under **rs232** in the radio\'s menu. 38400 is what these ship on. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\n**if the frequency is right but the mode is wrong**, tell us. the kx2 and kx3 entries read the mode from a position in the radio\'s status reply that we have pinned from the rigs we have seen, and a firmware that puts it elsewhere is something only a report reaches us as.\n\nthe k3 has not been reported either way, so please say what happens if you run one. a k4 has its own entry.';
	@override String get lab599TroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get lab599Troubleshooting => 'the tx-500 line speaks kenwood cat. written from published references rather than tested on the radio, so please report what happens either way.\n\n- **speed must match** the radio\'s cat setting, 9600 unless you changed it. with a mismatch the radio sends back garbage or nothing, and never an error.\n- **pick the cat protocol on the radio.** ts-2000 covers frequency and mode. lab599 also lets the app switch the radio to dig.\n- **through a link500mp**, press and hold the vfo knob for about three seconds to hand cat control to the interface.\n- **over bluetooth on a computer**, the link500mp pairs as two serial ports and only one carries cat. if the radio stays silent, pick the other.\n- **over bluetooth le**, as on an iphone or ipad, switch the link500mp to its ios mode first. in its other modes it does not show up in a scan.';
	@override String get kenwoodTroubleshootingTitle => 'if the radio connects but shows no frequency';
	@override String get kenwoodTroubleshooting => 'this driver is proven against kenwood\'s ts-590sg and ts-480, qrp labs\' qmx and qcx-mini, and elecraft\'s kx2 and kx3. the rest of the line is written from published cat references, so please report what happens either way.\n\nif the radio does not respond, almost always one of:\n\n- **speed must match** the radio\'s cat menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **some rigs need cat enabled** in the menu before they respond at all.\n\n**several sdr front-ends speak this same protocol**, so this entry is worth trying for those too; elecraft rigs are listed separately, under elecraft. if the frequency is right but the mode is wrong or missing, that is the one part that differs across the line — the app works it out from the radio and falls back to asking directly, so the mode may simply lag.';
	@override String get statusConnected => 'connected';
	@override String get statusLost => 'disconnected';
	@override String get notConfigured => 'not configured';
	@override String get currentConfiguration => 'current configuration';
	@override String get currentTransceiver => 'current transceiver';
	@override String get radioMode => 'radio mode';
	@override String get keyerNotSupported => 'not supported by current radio';
	@override String get catControlPreferences => 'cat control preferences';
	@override String get chooseTransceiver => 'choose transceiver';
	@override String get configurationSection => 'configuration';
	@override String get noTransceiverSelected => 'no transceiver selected';
	@override String makeMainVfo({required Object name}) => 'use ${name} for the main vfo';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		zero: 'no transceivers',
		one: '${count} transceiver',
		other: '${count} transceivers',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} antenna',
		other: '${count} antennas',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} other device',
		other: '${count} other devices',
	);
	@override String get equipmentInventory => 'equipment inventory';
	@override String get equipmentInUse => 'transceiver controls';
	@override String get noTransceiver => 'none';
	@override String get peerRadioNotAvailable => 'not available';
	@override String peerRadioOnDevice({required Object device}) => 'on ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} is on another device';
	@override String peerRadioElsewhereMessage({required Object device}) => 'this radio is connected to ${device}. its connection and settings are configured on that device.';
	@override String get antennaInUse => 'antenna in use';
	@override String get keyInUse => 'key in use';
	@override String get noneSelected => 'none';
	@override String get moreSettings => 'more settings';
	@override String get icomCivTroubleshootingTitle => 'if two serial ports show up for the same radio';
	@override String get icomCivTroubleshooting => 'several icom radios, the ic-705 among them, present **two** usb serial ports at once (icom calls them port a and port b), both set to ci-v by default. neither this app nor your os can tell them apart beyond that: the same usb vendor/product id just shows up twice, sometimes marked with a `#2` suffix here. **port a is usually the right one** — normally the first one your os or browser lists, and where this app can tell the two ports apart it marks that one as suggested. if commands go out and the radio never responds, try the other port next.';
	@override String get civAddressTroubleshootingTitle => 'if the radio never responds';
	@override String get civAddressTroubleshooting => '- **the ci-v address must match** the radio\'s menu. this entry prefills the address the model ships with, but a rig sharing a ci-v bus is exactly where that gets changed. a frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n- **speed must match** the radio\'s ci-v baud rate (on usb, ci-v usb baud rate). set the radio to the same number shown here, **not auto**. on auto some radios, the ic-7300 among them, connect and then stop responding after a minute or so.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **the ci-v address must match** the radio\'s menu. this entry prefills the address the model ships with, but a rig sharing a ci-v bus is exactly where that gets changed. a frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n${speed}\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.';
	@override String get icomUsbSpeedFollows => '- **there is no speed to set.** over usb this radio talks at whatever speed the computer uses, and this entry always uses 115200, the speed the scope needs.';
	@override String get ic7610UsbSpeed => '- **set ci-v usb baud rate to 115200**, the speed this entry always uses, since the scope needs it — **not auto**. a radio set to any other speed answers with silence.';
	@override String get ic7300Mk2Note => '\n- the **ic-7300 mk2** ships on address `B6`, not the `94` prefilled here — pick the ic-7300 mk2 entry instead.';
	@override String get ic705PortNote => '\n- the **ic-705** presents two usb serial ports, both named after the radio. ci-v is on the **first** of them, which the picker points at wherever it can tell the two apart.';
	@override String get ic7760PortNote => '\n- the **ic-7760** speaks ci-v on **port a** of the two usb serial ports it presents.';
	@override String get x6100PortNote => '\n- the **x6100** speaks ci-v on its **dev** port — the second of the two serial ports it presents, and the one the picker points at.';
	@override String get rigctldTroubleshootingTitle => 'if the app cannot connect';
	@override String get rigctldTroubleshooting => 'this connects to a **rigctld daemon you run yourself**, not to the radio directly — hamlib\'s backend talks to the radio and supports hundreds of models.\n\n- **the daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. find your radio\'s model number with `rigctl -l`.\n- **from another machine**, start it with `-T 0.0.0.0`: by default rigctld only accepts connections from the machine it runs on.\n- **port** is 4532 unless you started the daemon with `-t`.\n- once connected, a missing frequency usually means the daemon itself cannot reach the radio. test it with `rigctl -m 2 f` on the daemon\'s machine.';
	@override String get flrigTroubleshootingTitle => 'if the app cannot connect';
	@override String get flrigTroubleshooting => 'this connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **port** is 12345 unless you changed it in flrig\'s configuration (config → setup → server).\n- **from another machine**, make sure flrig\'s server is reachable. it listens on all interfaces, but your firewall may not agree.\n- once connected, a missing frequency usually means flrig itself cannot reach the radio. check that flrig\'s display is following the dial.';
	@override String get hrdTroubleshootingTitle => 'if the app cannot connect';
	@override String get hrdTroubleshooting => 'this connects to **ham radio deluxe\'s rig control, running on your computer**, not to the radio directly — hrd talks to the radio.\n\n- **rig control must already be running** and connected to the radio.\n- **its ip server must be enabled.** rig control only talks to other programs through it.\n- **port** is 7809 unless you changed it in the ip server\'s settings.\n- **from another machine**, make sure your firewall lets the connection through.\n\nthis entry was written from published descriptions of hrd\'s protocol and has not been run against hrd. if it half-works, that is worth reporting.';
	@override String get n3fjpTroubleshootingTitle => 'if the app cannot connect';
	@override String get n3fjpTroubleshooting => 'this connects to **an n3fjp logging program running on your computer**, not to the radio directly — n3fjp talks to the radio.\n\n- **the program\'s api must be on**: settings → application program interface, check **tcp api enabled**.\n- **port** is 1100 unless you changed it there.\n- **n3fjp must have a radio interface set up** to follow or tune the radio. without one, it reports only what is typed into its entry window.\n- n3fjp reports band, mode and frequency only: no power, no transmit state.\n\nthis entry was written from n3fjp\'s published api and has not been run against n3fjp. if it half-works, that is worth reporting.';
	@override String get commanderTroubleshootingTitle => 'if the app cannot connect';
	@override String get commanderTroubleshooting => 'this connects to **dxlab commander, running on your computer**, not to the radio directly — commander talks to the radio.\n\n- **commander must already be running** and connected to the radio.\n- **its network service must be on**: the **net serv** button in the radio panel of commander\'s configuration window.\n- **port** is 52002, the third port of the block starting at net serv\'s **base port** (52000 unless you changed it).\n- **from another machine**, make sure your firewall lets the connection through.\n\nthis entry was written from commander\'s published tcp messages and has not been run against commander. if it half-works, that is worth reporting.';
	@override String get ic705TroubleshootingTitle => 'if the radio never responds';
	@override String get ic705Troubleshooting => 'the radio has a **single** remote-control session. when the login is ignored, something else is almost always using it.\n\n- **close any other client.** wfview or rs-ba1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **check the radio\'s network settings.** wlan must be on, the radio must be on the same network, and its remote-control (network) function must be enabled.\n- **the ports must match** the radio\'s control port and serial port (udp), or the ports forwarded to them. a wrong port is met with silence, the same as a radio that is off.\n- **power-cycle the radio\'s wlan** if it stays stuck. that reliably clears a session stuck on the radio.\n\na **wrong password is refused explicitly**, not met with silence. if you got here rather than a "rejected" message, the password is not the problem.';
	@override String get icomLanTroubleshooting => 'the radio has a **single** remote-control session. when the login is ignored, something else is almost always using it.\n\n- **close any other client.** wfview, rs-ba1 or icom\'s remote utility connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **check the radio\'s network settings.** its lan port must be connected to the same network as this device, its **network control** must be on, and the username and password must be set up as a network user on the radio.\n- **the ports must match** the radio\'s control port and serial port (udp), or the ports forwarded to them. a wrong port is met with silence, the same as a radio that is off.\n- **if it connects but never answers**, the ci-v address here must match the radio\'s ci-v address menu. this entry prefills the address the model ships with.\n- **turn the radio off and on** if it stays stuck.';
	@override String get statusStale => 'not responding';
	@override String get statusDisconnected => 'not connected';
	@override String get statusConnecting => 'connecting…';
	@override String get statusDisconnecting => 'disconnecting…';
	@override String get statusError => 'connection failed';
	@override String get currentRadioSettings => 'current radio settings';
	@override String get notSupportedByThisRadio => 'not supported by this radio';
	@override String get keyerRowLabel => 'keyer';
	@override String get cwMessagesButton => 'cw';
	@override String get voiceMessagesButton => 'phone';
	@override String voiceKeyerAvailable({required Object count}) => 'voice keyer: ${count} memories in the radio';
	@override String get antennaBands => 'bands';
	@override String get antennaType => 'antenna type';
	@override String get antennaTypeRequired => 'choose an antenna type';
	@override late final _Translations$settings$station$antennaTypes$qrp antennaTypes = _Translations$settings$station$antennaTypes$qrp._(_root);
	@override String get keyType => 'key type';
	@override String get keyTypeRequired => 'choose a key type';
	@override late final _Translations$settings$station$keyTypes$qrp keyTypes = _Translations$settings$station$keyTypes$qrp._(_root);
	@override String get softwareIntermediaries => 'software intermediaries';
	@override String get otherBrands => 'other brands';
	@override String get otherEquipment => 'other equipment (antennas, keys, etc)';
	@override String get newAntenna => 'new antenna';
	@override String get newKey => 'new key';
	@override String get newKeyer => 'winkeyer (k1el or compatible)';
	@override String keyViaRadio({required Object radio}) => 'cat keyer in ${radio}';
	@override String keyOnDevice({required Object device}) => 'key on ${device}';
	@override String get cwKeyerArea => 'keyer area';
	@override String get trackStationInfo => 'track station info for each qso';
	@override String get includeStationInfoInAdif => 'include in adif exports';
	@override String get whatToTrack => 'what to track?';
	@override String get trackFieldRig => 'transceiver';
	@override String get trackFieldPower => 'power';
	@override String get watts => 'watts';
	@override String get trackFieldAntenna => 'antenna';
	@override String get trackFieldKey => 'cw key';
	@override String get placeholderConnectDelay => 'connect delay (ms)';
	@override String get placeholderConnectDelayDescription => 'how long the simulated handshake takes. blank or 0 connects instantly.';
	@override String get placeholderDropAfter => 'drop after (seconds)';
	@override String get placeholderDropAfterDescription => 'close the connection on its own, to exercise the reconnect path. blank or 0 never drops.';
	@override String get placeholderFailConnect => 'always fail to connect';
	@override String get placeholderConnectFailure => 'the placeholder radio was told to refuse this connection';
	@override String get placeholderFreq => 'frequency (khz)';
	@override String get placeholderFreqDescription => 'where the placeholder radio starts. it reports back whatever the app tunes it to afterwards.';
	@override String get placeholderMode => 'mode';
	@override String get placeholderModeDescription => 'the mode the placeholder radio starts on, e.g. usb, cw, ft8.';
	@override String get placeholderPower => 'power (watts)';
	@override String get placeholderPurpose => 'use this radio to keep track of which rig you\'re using for logging purposes';
	@override String get placeholderReplyDelay => 'reply delay (ms)';
	@override String get placeholderReplyDelayDescription => 'how long the placeholder radio takes to report a change back. blank or 0 replies at once.';
	@override String get cwKeyerField => 'cat cw keyer';
	@override String get cwKeyerFieldDescription => 'whether this radio keys cw from text over cat. off for a rig the app does not know.';
	@override String get voiceMemories => 'voice memories';
	@override String get voiceMemoriesDescription => 'how many voice memories the radio plays over cat. 0 for none.';
	@override String get voiceMemoriesInvalid => 'a whole number, 0 or more';
	@override String get yaesuMeterCapture => 'capture meter readings';
	@override String get yaesuBinaryMeterCaptureDescription => 'reads the radio\'s power-output meter and high-swr flag while transmitting and prints the raw values to the log. for building the scale yaesu does not publish — the values are not shown as meters.';
	@override String get yaesuMeterCaptureDescription => 'reads the radio\'s po, swr and alc meters while transmitting and prints the raw values to the log. for building the scale yaesu does not publish — the values are not shown as meters.';
	@override String get telemetryInterval => 'meter reading interval (ms)';
	@override String get telemetryIntervalDescription => 'how often to read the radio\'s meters while it is transmitting. leave blank for the fastest this connection can handle, up to 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'a whole number of milliseconds, ${min} to ${max}';
	@override String get pollInterval => 'idle polling interval (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'how often to ask the radio for its frequency and mode while neither is changing. leave blank for ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'a whole number of milliseconds, ${min} to ${max}';
	@override String get advancedSettings => 'advanced settings';
	@override String get placeholderSwr => 'swr reading';
	@override String get placeholderSwrDescription => 'what this radio reports on its swr meter while transmitting. above 1.8 the panel warns.';
	@override String get placeholderSwrInvalid => 'a number, 1 or more';
	@override String get keyerNone => 'none';
	@override String get cwDialect => 'cw keying dialect';
	@override String get cwDialectDescription => 'which shape of the ky command this radio takes. none means no cw keying over cat.';
	@override String get cwDialectKenwood => 'kenwood (ky, padded to 24)';
	@override String get cwDialectElecraft => 'elecraft (ky text)';
	@override String get voiceDialect => 'voice keyer dialect';
	@override String get voiceDialectDescription => 'how this radio plays its voice memories over cat. none means no voice memories over cat. with a dialect and no count, the dialect\'s default count applies.';
	@override String get voiceDialectPb => 'kenwood (pb, ts-590 style)';
	@override String get voiceDialectK4 => 'elecraft k4 (pb and da)';
	@override String get voiceDialectKx => 'elecraft kx2/kx3 (switch taps)';
	@override String get placeholderDiagnostic => 'simulated';
	@override String get placeholderWholeNumberInvalid => 'must be a whole number, 0 or more';
	@override String get placeholderFreqInvalid => 'must be a frequency in khz, greater than zero';
	@override String get placeholderModeInvalid => 'must be a mode name, e.g. usb, cw, ft8';
	@override String get switchLayout => 'layout';
	@override String get switchLayoutDescription => 'which side of the switch your radios are plugged into.';
	@override String get switchLayoutRequired => 'choose how the switch is wired';
	@override String switchCommandRefused({required Object command, required Object code}) => 'the switch refused "${command}" (error ${code})';
	@override String get switchBusyTransmitting => 'that port is transmitting — antenna not changed';
	@override String get switchNoAntenna => 'none';
	@override String switchAntennaFor({required Object port}) => 'antenna on port ${port}';
	@override String get switchAntennaForDescription => 'which of your antennas is connected to this port on the switch.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antennas, ${radios} radios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antennas, 1 radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antenna, ${radios} radios';
	@override String get switchCommonPort => 'common';
	@override String get dcnAddress => 'device address';
	@override String get dcnAddressDescription => 'the address set on the module\'s dip switches. a coax relay module leaves the factory at 2.';
	@override String get dcnAddressRequired => 'must be a device address from 1 to 99';
	@override String switchPortLabel({required Object port}) => 'port ${port}';
	@override String get switchPortAutoHint => 'follows band data';
	@override String get switchPortTransmittingHint => 'transmitting — cannot change now';
	@override String get switchCurrentStateHeader => 'current state';
	@override String get switchCurrentStateDescription => 'which antenna each radio port is on right now. changes take effect immediately.';
	@override String get switchWiringHeader => 'wiring';
	@override String get switchPortInhibitedHint => 'transmit inhibited';
	@override String get configUnreadable => 'this radio\'s saved settings could not be read. open its settings and enter them again, or remove it and add it back.';
	@override String get autoConnectHeld => 'halo stopped responding the last time it connected to this radio, so it did not connect on its own this time. press connect to try again.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$qrp extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'offline data';
	@override String get noFiles => 'no data files';
	@override String get noFilesDescription => 'enable activity or lookup extensions to download their offline data here.';
	@override String get refresh => 'refresh';
	@override String get refreshing => 'refreshing…';
	@override String get updateAll => 'update all';
	@override String get updatingAll => 'updating all data files…';
	@override String get neverDownloaded => 'never downloaded';
	@override String get updatedJustNow => 'updated just now';
	@override String updatedDaysAgo({required Object days}) => 'updated ${days}d ago';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'updated ${days}d ${hours}h ago';
	@override String updatedHoursAgo({required Object hours}) => 'updated ${hours}h ago';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'updated ${hours}h ${minutes}m ago';
	@override String updatedMinutesAgo({required Object minutes}) => 'updated ${minutes}m ago';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'the last download had only ${imported} of ${existing} records and was not used. refresh to accept it.';
	@override String get extensionsSection => 'extensions';
}

// Path: settings.profiles
class _Translations$settings$profiles$qrp extends Translations$settings$profiles$en {
	_Translations$settings$profiles$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'not set';
	@override String get personalInfo => 'personal info';
	@override String get personalInfoNote => 'this might be included in generated logs when relevant for submissions';
	@override String get name => 'name';
	@override String get email => 'email';
	@override String get club => 'club';
	@override String get arrlSection => 'arrl section';
	@override String get racSection => 'rac section';
	@override String get section => 'section';
}

// Path: settings.search
class _Translations$settings$search$qrp extends Translations$settings$search$en {
	_Translations$settings$search$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get clear => 'clear';
	@override String get hint => 'search preferences';
}

// Path: settings.developer
class _Translations$settings$developer$qrp extends Translations$settings$developer$en {
	_Translations$settings$developer$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'enable developer warnings, debug logs, and tools.';
	@override String get experiments => 'experiments';
	@override String get showIdleMetrics => 'show idle metrics';
	@override String get showIdleMetricsDescription => 'show in the status bar how idle the extension engine has been over the last second. tap it for the 10- and 60-second averages.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% idle';
	@override String get idleMetricsAverages => 'idle avg:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} enabled',
		other: '${count} enabled',
	);
	@override String get patchTrack => 'code push track';
	@override String get patchTrackDescription => 'which over-the-air code push ring this device follows. more adventurous rings get fixes earlier, less tested. code pushes apply on the next restart.';
	@override String get trackStable => 'stable';
	@override String get trackUnstable => 'unstable';
	@override String get trackBleeding => 'bleeding';
	@override String checkingTrack({required Object track}) => 'checking "${track}" for a code push…';
	@override String get patchDownloaded => 'code push downloaded — restart the app to apply it.';
	@override String noNewPatch({required Object track}) => 'no new code push on "${track}".';
	@override String get noPatchInstalled => 'no code push installed — running the release binary.';
	@override String runningPatch({required Object patch}) => 'running code push #${patch}.';
	@override String get deepLinks => 'deep links';
	@override String get registerUrlSchemes => 'register url schemes';
	@override String get registerUrlSchemesDescription => 'let com.ham2k:// links open this copy of the app';
	@override String get registerUrlSchemesDone => 'this copy now opens com.ham2k:// links';
	@override String registerUrlSchemesFailed({required Object error}) => 'could not register: ${error}';
	@override String get systemInformation => 'system information';
	@override String get appVersion => 'app version';
	@override String get dataFolder => 'data folder';
	@override String get loading => '(loading…)';
	@override String get panelLoadFailed => 'could not load this settings panel.';
	@override String get extDevServer => 'extension dev server';
	@override String get extensionSettings => 'extension settings';
	@override String get extDevServerDescription => 'load extensions from a dev server on your network instead of the ones built into the app, and reload them as you save.';
	@override String get extDevServerAddress => 'server address';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'connect';
	@override String get extDevServerDisconnect => 'disconnect';
	@override String get extDevServerConnecting => 'connecting…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'serving ${count} extension: ${keys}',
		other: 'serving ${count} extensions: ${keys}',
	);
	@override String get extDevServerDisconnected => 'not connected';
	@override String get extDevServerReconnect => 'reconnect at launch';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'last reload: ${key} at ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} extension failing to build',
		other: '${count} extensions failing to build',
	);
	@override String get catalog => 'extension catalog';
	@override String get catalogDescription => 'read the catalog from another server — a local one while working on the catalog itself. empty means catalog.ham2k.net.';
	@override String get catalogAddress => 'catalog address';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'catalog search tracks';
	@override String get catalogSearchStable => 'only stable';
	@override String get catalogSearchUnstable => 'unstable or better';
	@override String get catalogSearchBleeding => 'bleeding or better';
}

// Path: settings.about
class _Translations$settings$about$qrp extends Translations$settings$about$en {
	_Translations$settings$about$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get notices => 'notices & messages';
	@override String get noticesDescription => 'announcements and status messages';
	@override String get releaseNotes => 'release notes';
	@override String get copiedVersion => 'copied version details to clipboard';
}

// Path: settings.panels
class _Translations$settings$panels$qrp extends Translations$settings$panels$en {
	_Translations$settings$panels$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get settings => 'application preferences';
	@override String get settingsDescription => 'make the app work how you want it';
	@override String get commonSettings => 'common preferences';
	@override String get syncDescription => 'back up and sync your logs across devices';
	@override String get accountsDescription => 'service credentials, offline data, and more';
	@override String get extensions => 'extensions & features';
	@override String get extensionsDescription => 'activities, contests, dashboard panels and more features';
	@override String get profilesDescription => 'operator callsign and station profile';
	@override String get stationProfiles => 'station profiles';
	@override String get developerSettings => 'developer settings';
	@override String get developerSettingsDescription => 'debugging and development tools';
	@override String get about => 'about';
	@override String get aboutDescription => 'version, credits, and legal information';
	@override String get unavailableTitle => 'some settings are unavailable';
	@override String get unavailableText => 'the extension runtime failed to start, so extension-contributed settings are missing.';
	@override String get station => 'station configuration';
	@override String get stationDescription => 'cat control and more options';
	@override String get peers => 'peer devices';
	@override String get peersDescription => 'connect to other devices nearby';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$qrp extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get locale => 'follow system settings';
	@override String get period => 'always use period for decimals';
	@override String get comma => 'always use comma for decimals';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$qrp extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => 'system settings (using ${separator} for decimals)';
	@override String get period => 'always using period for decimals';
	@override String get comma => 'always using comma for decimals';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$qrp extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get comma => 'comma';
	@override String get period => 'period';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$qrp extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get six => '6 digits (fn31pr)';
	@override String get eight => '8 digits (fn31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$qrp extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get six => '6 digits';
	@override String get eight => '8 digits';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$qrp extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'open the command dialog';
	@override String get toggleTheme => 'switch between light and dark';
	@override String get toggleLanguage => 'switch between english and spanish';
	@override String get fontScaleUp => 'larger text';
	@override String get fontScaleDown => 'smaller text';
	@override String get fontScaleReset => 'normal text size';
	@override String get densityLooser => 'roomier layout';
	@override String get densityDenser => 'denser layout';
	@override String get densityAuto => 'automatic layout density';
	@override String get find => 'find in the log';
	@override String keyerMessage({required Object n}) => 'send message ${n}';
	@override String get keyboardMode => 'keyboard mode on or off';
	@override String get ptt => 'push to talk';
	@override String get wipe => 'clear the contact being logged';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$qrp extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'typing callsigns';
	@override String get escape => 'stop sending, back out one step, or close';
	@override String get enter => 'log the contact';
	@override String get space => 'next field';
	@override String get tab => 'next or previous field';
	@override String get arrows => 'move between fields, controls and the log';
	@override String get walk => 'page through the log, or go to its ends';
	@override String get undo => 'take back a wipe or a delete';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$qrp extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'add shortcut';
	@override String get listening => 'press the keys for the shortcut…';
	@override String get listeningHint => 'esc stops listening';
	@override String get add => 'add';
	@override String refusedFixed({required Object keys}) => '${keys} belongs to the logging fields or a dialog, and can’t be changed.';
	@override String refusedCallsign({required Object keys}) => '${keys} is how callsigns are typed. hold cmd, ctrl or alt with it.';
	@override String reserved({required Object keys}) => 'the system may take ${keys} before the app sees it.';
	@override String already({required Object keys}) => '${keys} is already one of this command’s keys.';
	@override String takeIt({required Object keys, required Object command}) => 'take ${keys} from “${command}”';
	@override String get resetDefault => 'reset to default';
	@override String get remove => 'remove';
	@override String get commandLabel => 'command';
	@override String get commandHint => 'enter any valid command, or multiple commands separated by ";"';
	@override String get removeCommand => 'remove command';
	@override String commandUnknown({required Object text}) => 'no command reads “${text}”';
	@override String get noShortcuts => 'no key yet';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$qrp extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'shortcuts saved to ${location}';
	@override String exportFailed({required Object error}) => 'couldn’t export the shortcuts: ${error}';
	@override String importPickerFailed({required Object error}) => 'couldn’t open the file: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} isn’t a shortcuts file this app can read: ${problem}';
	@override String problemNotYaml({required Object line}) => 'the text isn’t valid yaml (line ${line})';
	@override String get problemNotKeysFile => 'it isn’t a ham2k keyboard shortcuts file';
	@override String get problemNewerVersion => 'it was written by a newer version of the app';
	@override String get problemMalformed => 'part of it doesn’t follow the shortcuts format';
	@override String get problemTooLarge => 'it is too large';
	@override String get importTitle => 'import shortcuts';
	@override String writtenOn({required Object platform}) => 'written on ${platform}.';
	@override String get writtenOnUnknown => 'the file doesn’t say which keyboard it was written on.';
	@override String get translate => 'what should each of these keys be on this keyboard?';
	@override String get leaveOut => 'leave those shortcuts out';
	@override String get replace => 'replace this device’s config';
	@override String get replaceHint => 'every shortcut not in the file goes back to its default.';
	@override String get merge => 'add to this device’s config';
	@override String get mergeHint => 'the file’s shortcuts replace this device’s for the same commands, and the rest stay.';
	@override String unknown({required Object commands}) => 'not known in this version, so left out: ${commands}';
	@override String unreadableChords({required Object chords}) => 'not shortcuts, so left out: ${chords}';
	@override String refusedChords({required Object chords}) => 'keys the app keeps for itself, so left out: ${chords}';
	@override String conflicts({required Object keys}) => 'bound to more than one command after the import: ${keys}';
	@override String get importAction => 'import';
	@override String get imported => 'shortcuts imported';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$qrp extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ command';
	@override String get ctrl => 'ctrl';
	@override String get meta => 'windows / super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$qrp extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macos';
	@override String get ios => 'ipados';
	@override String get windows => 'windows';
	@override String get linux => 'linux';
	@override String get android => 'android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$qrp extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'station callsigns';
	@override String get groupBy => 'group by';
	@override String get period => 'time period';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$qrp extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get none => 'not grouped';
	@override String get date => 'date';
	@override String get dx => 'dx';
	@override String get unknownContinent => 'unknown continent';
	@override String get unknownEntity => 'unknown entity';
	@override String get unknownDate => 'no date';
}

// Path: home.logs.period
class _Translations$home$logs$period$qrp extends Translations$home$logs$period$en {
	_Translations$home$logs$period$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'this month';
	@override String get last3Months => 'last 3 months';
	@override String get thisYear => 'this year';
	@override String get lastYear => 'last year';
	@override String get allTime => 'all time';
	@override String get custom => 'custom range';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$qrp extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => 'in ${span}';
	@override String get custom => 'custom range';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$qrp extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get date => 'date';
	@override String get time => 'time';
	@override String get freq => 'frequency';
	@override String get mode => 'mode';
	@override String get call => 'call';
	@override String get name => 'name';
	@override String get station => 'station';
	@override String get band => 'band';
	@override String get sent => 'sent';
	@override String get rcvd => 'rcvd';
	@override String get grid => 'grid';
	@override String get state => 'state';
	@override String get country => 'country';
	@override String get refs => 'refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$qrp extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'qso log';
	@override String get qsosDescription => 'the selected callsign\'s qsos, across every operation.';
	@override String get info => 'info';
	@override String get infoDescription => 'total qso count, or the selected qso\'s callsign lookup.';
	@override String get map => 'map';
	@override String get mapDescription => 'the selected qso\'s location.';
}

// Path: home.logs.import
class _Translations$home$logs$import$qrp extends Translations$home$logs$import$en {
	_Translations$home$logs$import$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'callsigns: ${calls}';
	@override String get skippedOne => '1 record could not be read';
	@override String skippedOther({required Object count}) => '${count} records could not be read';
	@override String get readingTitle => 'reading adif file…';
	@override String get checkingTitle => 'checking for duplicates…';
	@override String get importingTitle => 'importing qsos…';
	@override String readingDetail({required Object kb}) => '${kb} kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} of ${total} checked';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} imported, out of ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$qrp extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'default';
	@override String untitledName({required Object number}) => 'layout ${number}';
	@override String switcherLabel({required Object name}) => 'layout: ${name}';
	@override String get menuNew => 'new…';
	@override String get menuExport => 'export…';
	@override String get menuImport => 'import…';
	@override String get menuTitle => 'layouts';
	@override String get newTitle => 'new layout';
	@override String get editTitle => 'edit layout';
	@override String get edit => 'edit';
	@override String get duplicateCurrent => 'duplicate current layout';
	@override String get startFromDefault => 'start from the default layout';
	@override String get nameLabel => 'name';
	@override String get descriptionLabel => 'description';
	@override String get create => 'create';
	@override String leaveEditTitle({required Object name}) => 'save changes to "${name}"?';
	@override String get leaveEditBody => 'this layout has changes you haven’t saved.';
	@override String get discard => 'discard';
	@override String get deleteTitle => 'delete this layout?';
	@override String deleteBody({required Object name}) => 'are you sure you want to delete this "${name}" layout?';
	@override String get exportTitle => 'export layout';
	@override String get exportPick => 'panels to export';
	@override String get tabSet => 'tab set';
	@override String get exportAction => 'export';
	@override String exported({required Object location}) => 'layout saved to ${location}';
	@override String exportFailed({required Object error}) => 'couldn\'t export the layout: ${error}';
	@override String get importTitle => 'import layout';
	@override String importFromOtherView({required Object view}) => 'made for the ${view} view: panels only that view has are left out.';
	@override String get viewHome => 'home';
	@override String get viewOperation => 'operation';
	@override String get viewLogs => 'logs';
	@override String get viewChase => 'chasing';
	@override String get importAsNew => 'as a new layout';
	@override String get importReplace => 'in place of this layout';
	@override String get importAdd => 'added to this layout';
	@override String get importAddHint => 'the panels arrive in a new column on the right.';
	@override String get importPick => 'panels to import';
	@override String get importReplaceSettings => 'replace the settings of panels already set up here';
	@override String get importAction => 'import';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} isn\'t a layout this app can read: ${problem}';
	@override String problemNotYaml({required Object line}) => 'the text isn’t valid yaml (line ${line})';
	@override String get problemNotLayoutFile => 'it isn’t a ham2k layout file';
	@override String get problemNewerVersion => 'it was written by a newer version of the app';
	@override String get problemNoArrangement => 'it holds no arrangement';
	@override String get problemMalformed => 'part of it doesn’t follow the layout format';
	@override String get problemTooLarge => 'it is too large';
	@override String importPickerFailed({required Object error}) => 'couldn\'t open the file: ${error}';
	@override String importFailed({required Object error}) => 'couldn\'t import the layout: ${error}';
	@override String duplicateFailed({required Object error}) => 'couldn\'t copy the layout: ${error}';
	@override String get importNothing => 'no panel picked, so nothing was imported.';
	@override String importSkipped({required Object panels}) => 'left out: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'kept ${panels}: the small-screen arrangement can’t do without it.';
	@override String get notOffered => 'not available in this view';
	@override String get alreadyPlaced => 'already in this layout';
	@override String needsExtension({required Object name}) => 'needs ${name}';
	@override String get listRecoveredTitle => 'layout names couldn’t be read';
	@override String get listRecoveredBody => 'this view’s list of layouts could not be read. every layout is still here, numbered in place of its name.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$qrp extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'the log and the entry fields';
	@override String get infoDescription => 'what we know about the station being worked';
	@override String get spotsDescription => 'spots from the clusters and activity programs';
	@override String get mapDescription => 'where the contacts are';
	@override String get summariesDescription => 'the operation\'s stats and scores, in the sections and order you pick';
	@override String get summariesSections => 'sections and order';
	@override String get summariesDays => 'each day';
	@override String get summariesReset => 'show all';
	@override String get summariesAllHidden => 'every section is hidden. pick the ones to show in this panel\'s settings.';
	@override String get clockDescription => 'a clock face, in any time zone';
	@override String get clockFace => 'face';
	@override String get clockFaceLcd => 'lcd';
	@override String get clockFaceAnalog => 'analog';
	@override String get clockZone => 'time zone';
	@override String get clockZoneUtc => 'utc';
	@override String get clockZoneDevice => 'this device';
	@override String get clockShowSeconds => 'show seconds';
	@override String get weatherDescription => 'conditions now and for the next eight hours, where you\'re operating';
	@override String get weatherUseOperationLocation => 'use the operation\'s location';
	@override String get weatherLocation => 'location';
	@override String get weatherLocationDescription => 'a grid square (fn31pr) or lat,lon. ignored while \'use the operation\'s location\' is checked.';
	@override String get weatherNoLocation => 'no location set. give this panel a location in its settings, or place it inside an operation that has one.';
	@override String weatherBadLocation({required Object location}) => 'couldn\'t read the location ${location}. use a grid square like fn31pr, or 42.36,-71.06.';
	@override String get weatherUnreachable => 'couldn\'t reach open-meteo — no network? will try again shortly.';
	@override String get weatherUnreadable => 'open-meteo responded, but not with anything readable. will try again shortly.';
	@override String weatherGusts({required Object speed}) => 'gusts ${speed}';
	@override String get panelAgeNow => 'just now';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} min ago',
		other: '${count} min ago',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: '${count} hr ago',
		other: '${count} hrs ago',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$qrp weatherConditions = _Translations$operation$layout$panels$weatherConditions$qrp._(_root);
	@override String get websiteDescription => 'a web page of your choosing, in a pane';
	@override String get websiteUrl => 'address';
	@override String get websiteRefresh => 'refresh';
	@override String get websiteRefreshNever => 'never';
	@override String get websiteRefresh1 => 'every minute';
	@override String get websiteRefresh5 => 'every 5 minutes';
	@override String get websiteRefresh15 => 'every 15 minutes';
	@override String get websiteTitle => 'panel name';
	@override String get websiteRefreshNow => 'refresh now';
	@override String get websiteNoUrl => 'no address yet. open this panel’s settings to choose a page.';
	@override String get websiteBadUrl => 'that doesn’t look like a web address. it needs to start with https://';
	@override String get websiteNotHttps => 'only https:// addresses can be shown here.';
	@override String get websiteUnsupported => 'web pages can’t be shown in a panel on this system.';
	@override String get websiteOpenExternally => 'open in browser';
	@override String websiteLoadFailed({required Object reason}) => 'couldn’t load the page: ${reason}';
	@override String get remoteScreenDescription => 'a screen, app or window shared by another of your devices.';
	@override String get remoteScreenTarget => 'screen';
	@override String get remoteScreenChoose => 'choose a screen…';
	@override String get remoteScreenPickerTitle => 'shared screens';
	@override String get remoteScreenPickerEmpty => 'none of your devices is sharing a screen. turn share screens and windows on under settings → peer devices, on the device you want to see.';
	@override String get remoteScreenUnset => 'no screen chosen. open this panel\'s settings to pick one your other devices are sharing.';
	@override String get remoteScreenConnecting => 'connecting…';
	@override String get remoteScreenPeerAway => 'that device isn\'t connected right now.';
	@override String get remoteScreenNotOffered => 'that device stopped sharing this screen.';
	@override String get remoteScreenNoListener => 'that device can\'t accept connections — check its firewall.';
	@override String get remoteScreenNoLan => 'screens are only shared over the local network, not bluetooth.';
	@override String get remoteScreenRefused => 'that device wouldn\'t share this screen.';
	@override String get remoteScreenSettings => 'panel settings';
	@override String get remoteScreenAdjust => 'adjust view';
	@override String get remoteScreenDetail => 'detail';
	@override String get remoteScreenDetailStandard => 'standard';
	@override String get remoteScreenDetailHigh => 'high';
	@override String get remoteScreenDetailMaximum => 'maximum';
	@override String get remoteScreenAdjustDone => 'ok';
	@override String get remoteScreenZoomIn => 'zoom in';
	@override String get remoteScreenZoomOut => 'zoom out';
	@override String get remoteScreenStopped => 'that screen or window is no longer being shown.';
	@override String get remoteScreenCaptureFailed => 'that device couldn\'t capture that screen — it may need screen recording permission.';
	@override String get remoteScreenNoAnswer => 'that device didn\'t respond. it may not have screen sharing turned on.';
	@override String get remoteScreenNoMedia => 'couldn\'t open a connection for the picture. check the firewall on this device.';
	@override String get solarDescription => 'solar and geomagnetic conditions, with band-by-band propagation';
	@override String get solarUnreachable => 'couldn\'t reach hamqsl.com — no network? will try again shortly.';
	@override String get solarUnreadable => 'hamqsl.com responded, but not with a reading we could use. will try again shortly.';
	@override String get solarAIndex => 'a';
	@override String get solarKIndex => 'kp';
	@override String get solarBandDay => 'day';
	@override String get solarBandNight => 'night';
	@override String get solarBandGood => 'good';
	@override String get solarBandFair => 'fair';
	@override String get solarBandPoor => 'poor';
	@override String solarSources({required Object primary, required Object secondary}) => 'sources: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'the connection is struggling — skipping frames.';
	@override String get remoteScreenStalled => 'frames stopped getting through — this connection may be too slow.';
	@override String get radioDescription => 'a radio\'s front panel — frequency, mode and power, under cat control';
	@override String get radioStyle => 'style';
	@override String get radioStyleLcd => 'lcd';
	@override String get radioStyleModern => 'modern';
	@override String get radioRadio => 'radio';
	@override String radioAutoNamed({required Object name}) => 'vfo a — ${name}';
	@override String get radioAutoNone => 'vfo a — no radio designated';
	@override String get radioNoRadio => 'no radio to show. pick one in this panel\'s settings, or add one under station configuration.';
	@override String get radioNotConfigured => 'this radio is not configured yet. choose its port or address under station configuration.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'radio not connected';
	@override String get radioWatts => 'w';
	@override String get radioConnect => 'connect this radio';
	@override String get radioDisconnect => 'disconnect this radio';
	@override String get radioStale => 'no data';
	@override String get radioTransmitting => 'tx';
	@override String get radioSwr => 'swr';
	@override String get radioAlc => 'alc';
	@override String get radioVolts => 'v';
	@override String get radioSwrHigh => 'high swr';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$qrp extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'use compact file names';
	@override String get descriptionOn => 'short names built for uploaders, like n0call@us-1234-20260727.adi';
	@override String get descriptionOff => 'readable names, like 2026-07-27 n0call at us-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$qrp extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'include private info';
	@override String get descriptionOn => 'names, addresses, emails, gridsquares and notes are included';
	@override String get descriptionOff => 'names, addresses, emails, gridsquares and notes are left out';
	@override String get note => 'the full adif export always includes everything';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$qrp extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'add an email address first';
	@override String get needsEmailBody => 'ham2k’s file stash sends your files to the email address on your lofi account, and you sign in with it at stash.ham2k.net. your account doesn’t have a confirmed one yet — add it in settings › cloud sync.';
	@override String get openSyncSettings => 'open cloud sync';
	@override String get replaceTitle => 'recent stash will be replaced';
	@override String replaceBody({required Object name}) => 'you sent “${name}” less than 6 hours ago and it hasn’t been downloaded yet. free accounts keep one stash at a time, so sending now replaces it.';
	@override String get replaceConfirm => 'send anyway';
	@override String get failedTitle => 'couldn’t send to ham2k’s file stash';
	@override String get sentTitle => 'sent to ham2k’s file stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'you can retrieve this file by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.',
		other: 'you can retrieve these files by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.',
	);
	@override String get mayHaveArrived => 'no answer from the stash — the file may have arrived anyway. check stash.ham2k.net before sending again';
	@override String get notSent => 'not sent';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'this file didn’t arrive:',
		other: 'these ${count} files didn’t arrive:',
	);
	@override String get emailOffer => 'or for your convenience, we can send you an email with a direct link.';
	@override String get emailMe => 'email me a link';
	@override String get emailSent => 'we’ve emailed you a download link.';
	@override String emailFailed({required Object error}) => 'couldn’t send the email: ${error}';
	@override String get freeTier => 'free accounts can only keep one stash at a time. subscribers can keep as many as they want.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count,
		one: 'sent ${count} file to ham2k’s file stash (stash.ham2k.net)',
		other: 'sent ${count} files to ham2k’s file stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$qrp extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get af => 'africa';
	@override String get as => 'asia';
	@override String get eu => 'europe';
	@override String get na => 'north america';
	@override String get oc => 'oceania';
	@override String get sa => 'south america';
	@override String get an => 'antarctica';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$qrp extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'filter spots';
	@override String get band => 'band';
	@override String get mode => 'mode';
	@override String get age => 'age';
	@override String get sources => 'sources';
	@override String get continent => 'continent';
	@override String get sorting => 'sorting';
	@override String get sortByTime => 'by spot time';
	@override String get sortByFrequency => 'by frequency';
	@override String get sortByWanted => 'most wanted';
	@override String get groupByBand => 'group by band';
	@override String get groupCallsWithNotes => 'group calls with notes';
	@override String get alertingOnly => 'only spots with alerts';
	@override String get sourceNoReply => 'no reply';
	@override String get sourceError => 'error';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$qrp extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'logging panel is busy';
	@override String get editingBody => 'you\'re editing a logged contact. log this spot instead, or go back and finish the edit?';
	@override String get composingBody => 'you\'ve started entering a contact. log this spot instead, or go back and finish what you were typing?';
	@override String get goBack => 'go back';
	@override String get clearAndLog => 'clear and log spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$qrp extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'leftie mode';
	@override String get descriptionOn => 'using layout for left-handed users';
	@override String get descriptionOff => 'using layout for right-handed users';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$qrp extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'country flags';
	@override String get dx => 'show only for dx contacts';
	@override String get all => 'show flags for all contacts';
	@override String get none => 'don\'t show any flags';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$qrp extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get dx => 'showing flags only for dx contacts';
	@override String get all => 'showing flags for all contacts';
	@override String get none => 'not showing any flags';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$qrp extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'suggest operator';
	@override String get descriptionOn => 'offering your callsign as the operator when an operation runs under a different station callsign';
	@override String get descriptionOff => 'leaving the operator blank unless you fill it in';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$qrp extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'show bearing';
	@override String get descriptionOn => 'showing estimated bearing to station';
	@override String get descriptionOff => 'not showing bearing information';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$qrp extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'also show reverse bearing';
	@override String get descriptionOn => 'showing the bearing from the station too, as "45° / 225°"';
	@override String get descriptionOff => 'only showing the bearing to the station';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$qrp extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'switch signal report order';
	@override String get sentFirst => 'sent first, rcvd second';
	@override String get rcvdFirst => 'rcvd first, sent second';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$qrp extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'jump to next field on rst entry';
	@override String get descriptionOn => 'jumping after rst is entered';
	@override String get descriptionOff => 'not jumping automatically';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$qrp extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'default report — phone';
	@override String get description => 'used when sent or rcvd is left empty on ssb, fm or am';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$qrp extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'default report — cw and data';
	@override String get description => 'used when sent or rcvd is left empty on cw, rtty and other data modes';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$qrp extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'default report — ft8 and ft4';
	@override String get description => 'used when sent or rcvd is left empty on the ft modes';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$qrp extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'numbers row';
	@override String get description => 'show a row of number keys above the keyboard while logging';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$qrp extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'slash and period key';
	@override String get description => 'adds a contextual key: “/” for callsigns, “.” for numbers';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$qrp extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'vibrate on key press';
	@override String get description => 'haptic feedback when you tap a number key';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$qrp extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get off => 'disabled';
	@override String get rigctld => 'hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'ham radio deluxe®';
	@override String get n3fjp => 'n3fjp';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$qrp extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'no operator callsign to log in with';
	@override String get connectFailed => 'the node could not be reached';
	@override String get needsPassword => 'the node asks for a password, and none is stored';
	@override String get loginFailed => 'the node did not accept the login';
	@override String get disconnected => 'the node closed the connection';
	@override String get timeout => 'the node did not answer';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$qrp extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'khz';
	@override String get kHzPerSecond => 'khz/s';
	@override String get hz => 'hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$qrp extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'control ptt with [\']';
	@override String get descriptionOn => 'in phone modes, [\'] keys the radio and [\'] again unkeys it. it unkeys by itself after a minute.';
	@override String get descriptionOff => 'the [\'] key does not key the radio.';
	@override String get pill => 'tx';
	@override String get transmitting => 'transmitting';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$qrp extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'smart vfo snap';
	@override String get descriptionOn => 'after you stop turning the dial, rounding the frequency to a sensible step. voice modes only.';
	@override String get descriptionOff => 'staying exactly where you tuned it.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$qrp extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'smart snap: settle delay';
	@override String get description => 'how long the dial has to stop before the frequency is rounded. shorter feels immediate; longer leaves room for a slow move.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$qrp extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'smart snap: long move';
	@override String get description => 'move at least this far and the frequency rounds to a whole khz, however slowly you finished.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$qrp extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'smart snap: smallest move';
	@override String get description => 'move less than this and the frequency is not rounded, so fine tuning is left alone.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$qrp extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'smart snap: slowest move';
	@override String get description => 'turn the dial slower than this and the frequency is not rounded, unless it was a long move.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$qrp extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'esm off';
	@override String get pillRun => 'esm run';
	@override String get pillSp => 'esm s&p';
	@override String get field => 'enter sends messages';
	@override String get off => 'off';
	@override String get run => 'run';
	@override String get sp => 's&p';
	@override String semantics({required Object state}) => 'enter sends messages: ${state}. tap to change.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$qrp extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'keyer speed';
	@override String get unit => 'wpm';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$qrp extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'cw keyer messages';
	@override String get notSupported => 'current radio does not support cw keying';
	@override String key({required Object n}) => 'f${n}';
	@override String messageTitle({required Object n}) => 'message (${n})';
	@override String get labelField => 'label';
	@override String labelKey({required Object n}) => 'f${n} label';
	@override String get details => 'details';
	@override String get empty => '(empty)';
	@override String get sets => 'message set';
	@override String get newSet => 'new set';
	@override String get renameSet => 'rename set';
	@override String get deleteSet => 'delete set';
	@override String get newSetName => 'name';
	@override String get setDefault => 'default';
	@override String get setPota => 'pota';
	@override String get setEsm => 'esm messages';
	@override String get setSaved => 'my messages';
	@override String get repeat => 'repeat message #1';
	@override String get repeatOff => 'no';
	@override String repeatAfter({required Object n}) => 'after ${n} seconds';
	@override String get repeatWait => 'repeating';
	@override String get keyboard => 'type to send';
	@override String get keyboardField => 'type to send';
	@override String get closeArea => 'close the keyer area';
	@override String get help => 'help';
	@override String get helpTitle => 'writing cw messages';
	@override String get helpIntro => 'messages can use templates with the following values:';
	@override String get helpOpCall => 'your callsign';
	@override String get helpQsoCall => 'their callsign — in a // stack, the call that will be logged';
	@override String get helpQsoFullCall => 'their callsign, if there is a valid call; blank for a partial';
	@override String get helpQsoPartial => 'a partial call; blank if there is a full valid call';
	@override String get helpQsoNextCall => 'in a // stack, the call that will be selected for logging next, if there is a valid full call';
	@override String get helpQsoNextPartial => 'in a // stack, the next partial after logging the current contact';
	@override String get helpQsoName => 'their first name, as typed or else from the lookup';
	@override String get helpQsoState => 'their state, as typed or else from the lookup';
	@override String get helpKeyerMsg => 'message 1 as it would be sent, inside another message. valid for messages 1 through 8';
	@override String get helpQsoRst => 'the report you are sending';
	@override String get helpQsoSerial => 'your serial number, in a contest that sends one';
	@override String get helpPad => 'pads with zeros to that many digits: 7 is sent as 007';
	@override String get helpCut => 'cut numbers, t for 0 and n for 9: 599 is sent as 5nn';
	@override String get helpCutDigits => 'chooses the digits to cut, in quotes — 0 is t, 1 is a, 5 is e, 9 is n';
	@override String get helpFullExample => 'full example:';
	@override String get helpExample => 'sends w1aw 5nn tt7';
	@override String get helpEsmIntro => 'with enter sends messages on, enter keys messages by their function key, as n1mm does. the esm messages set starts with these:';
	@override String get helpEsmCq => 'running, enter with the call field empty calls cq';
	@override String get helpEsmExchange => 'your exchange: after their call when running, after they answer in s&p';
	@override String get helpEsmThanks => 'thanks, once the contact has logged: its placeholders name the next contact, not this one';
	@override String get helpEsmMyCall => 'in s&p, your call to the station you are answering';
	@override String get helpEsmHisCall => 'running, their call ahead of your exchange';
	@override String get helpEsmAgain => 'asks again when nothing of their exchange was copied';
	@override String get helpEsmStackThanks => 'suggested f3 for // stacks: tu goes out after the contact logs, so it thanks, then calls the next stacked station and sends your exchange, or asks a partial back (tu kr?); with nothing left, just tu';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$qrp extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'phone keyer messages';
	@override String get notSupported => 'current radio does not support phone messages';
	@override String get description => 'this uses the radio\'s voice memories';
	@override String key({required Object n}) => 'm${n}';
	@override String messageTitle({required Object n}) => 'voice memory (${n})';
	@override String get labelField => 'label';
	@override String labelKey({required Object n}) => 'voice memory ${n} label';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'empty';
	@override String get notMeasured => 'unknown length';
	@override String get playButton => 'play';
	@override String get recordButton => 'record';
	@override String get stopButton => 'stop';
	@override String get repeat => 'repeat message #1';
	@override String get repeatOff => 'no';
	@override String repeatAfter({required Object n}) => 'after ${n} seconds';
	@override String recordHelpTitle({required Object model}) => '${model} notes:';
	@override String namedOnDevice({required Object device}) => 'these memories are in ${device}\'s radio. their names and lengths belong to that device.';
	@override String get namedOnRadio => 'saved in the radio, where its other clients see it too.';
	@override String get recordHelpYaesuDvs => 'wait for the [rec] indicator on the radio, then hold the ptt button and record your message. end it by pressing the stop button here in the app before releasing ptt to avoid unwanted clicks.';
	@override String get recordHelpFt891 => 'wait for the [rec] indicator to blink at least four times, then hold the ptt button and record your message. end it by pressing the stop button here in the app before releasing ptt to avoid unwanted clicks.';
	@override String get pill => 'voice';
	@override String play({required Object n}) => 'play memory ${n}';
	@override String get stop => 'stop';
	@override String record({required Object n}) => 'record memory ${n}';
	@override String get stopRecording => 'stop recording';
	@override String get playing => 'playing…';
	@override String get recording => 'recording…';
	@override String playingMemory({required Object label}) => 'playing ${label}';
	@override String recordingMemory({required Object label}) => 'recording ${label}';
	@override String get doubtful => 'did the radio play it? it said it was idle right away.';
	@override String get recordOnRadio => 'you have to record the memories on the radio itself.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$qrp extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'avoid zero-beating on spots';
	@override String get descriptionOn => 'with a radio connected, tuning a few hz off a cw spot, so everyone answering it isn’t calling on the same note.';
	@override String get descriptionOff => 'tuning exactly to the spotted frequency.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$qrp extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'zero-beat: avoidance range';
	@override String get description => 'how far off the spotted frequency to land, either side. the offset is never near zero — that would be a zero beat again.';
}

// Path: settings.map.style
class _Translations$settings$map$style$qrp extends Translations$settings$map$style$en {
	_Translations$settings$map$style$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'map style';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$qrp extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'show callsigns';
	@override String get description => 'each contact is a pill with its callsign, in its band\'s color';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$qrp extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'show grayline';
	@override String get description => 'shades the night side of the earth, with twilight as a gradient';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$qrp extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'automatic';
	@override String get liberty => 'liberty';
	@override String get bright => 'bright';
	@override String get positron => 'positron';
	@override String get voyager => 'voyager';
	@override String get darkMatter => 'dark matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$qrp extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'share app usage data';
	@override String get descriptionOn => 'helping us improve the app by sharing usage, configuration, crash and performance data';
	@override String get descriptionOff => 'keeping app usage data private.\nthe ham2k team won\'t be able to detect crashes or other issues.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$qrp extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get title => 'share operation data';
	@override String get descriptionOn => 'sharing some operation data publicly and with other users';
	@override String get descriptionOff => 'keeping operation data private';
}

// Path: settings.station.models
class _Translations$settings$station$models$qrp extends Translations$settings$station$models$en {
	_Translations$settings$station$models$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get flexRadio => 'flexradio (smartsdr)';
	@override String get ft891 => 'yaesu ft-891';
	@override String get ft991a => 'yaesu ft-991/a';
	@override String get ft710 => 'yaesu ft-710';
	@override String get ftdx10 => 'yaesu ftdx10';
	@override String get ftx1 => 'yaesu ftx-1';
	@override String get ft817 => 'yaesu ft-817 / ft-818';
	@override String get ft857 => 'yaesu ft-857';
	@override String get ft897 => 'yaesu ft-897';
	@override String get ft450 => 'yaesu ft-450 / ft-450d';
	@override String get q900 => 'guohetec q900';
	@override String get tenTecEagle => 'ten-tec eagle (599)';
	@override String get tenTecOrion => 'ten-tec orion (565)';
	@override String get tenTecOrionII => 'ten-tec orion ii (566)';
	@override String get sotacat => 'sotacat (elecraft kx2/kx3)';
	@override String get yaesuGeneric => 'yaesu - generic';
	@override String get icomGeneric => 'icom - generic';
	@override String get kenwoodGeneric => 'kenwood - generic';
	@override String get ts590sg => 'kenwood ts-590sg';
	@override String get ts480 => 'kenwood ts-480';
	@override String get qmx => 'qrp labs qmx';
	@override String get fx4cr => 'bg2fx fx-4cr';
	@override String get tx500 => 'lab599 tx-500';
	@override String get tx500mp => 'lab599 tx-500mp';
	@override String get qcx => 'qrp labs qcx';
	@override String get elecraftGeneric => 'elecraft - generic';
	@override String get kx2 => 'elecraft kx2';
	@override String get kx3 => 'elecraft kx3';
	@override String get k4 => 'elecraft k4';
	@override String get ic705 => 'icom ic-705';
	@override String get ic7300 => 'icom ic-7300';
	@override String get ic7300mk2 => 'icom ic-7300 mk2';
	@override String get ic706mkiig => 'icom ic-706mkiig';
	@override String get ic7100 => 'icom ic-7100';
	@override String get ic7610 => 'icom ic-7610';
	@override String get ic7760 => 'icom ic-7760';
	@override String get ic9700 => 'icom ic-9700';
	@override String get ic905 => 'icom ic-905';
	@override String get ic7850 => 'icom ic-7850';
	@override String get ic7851 => 'icom ic-7851';
	@override String get x6100 => 'xiegu x6100';
	@override String get g90 => 'xiegu g90';
	@override String get rigctld => 'radio controlled via rigctld';
	@override String get rigctldNodeName => 'my radio (via rigctld)';
	@override String get flrig => 'radio controlled via flrig';
	@override String get flrigNodeName => 'my radio (via flrig)';
	@override String get hrd => 'radio controlled via ham radio deluxe®';
	@override String get hrdNodeName => 'my radio (via hrd)';
	@override String get n3fjp => 'radio controlled via n3fjp';
	@override String get n3fjpNodeName => 'my radio (via n3fjp)';
	@override String get commander => 'radio controlled via dxlab commander';
	@override String get commanderNodeName => 'my radio (via commander)';
	@override String get antenna => 'antenna';
	@override String get key => 'cw key';
	@override String get winkeyer => 'winkeyer';
	@override String get placeholderRadio => 'generic radio (placeholder)';
	@override String get placeholderRadioNodeName => 'my radio';
	@override String get antennaGenius => '4o3a antenna genius';
	@override String get sierraCoax => 'sierra radio cx-1 coax switch';
	@override String get rtlSdr => 'rtl-sdr';
	@override String get nesdr => 'nooelec nesdr';
	@override String get sdrplay => 'sdrplay rsp';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$qrp extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get network => 'network/wifi';
	@override String get secureNetwork => 'secure network/wifi';
	@override String get usbSerial => 'usb serial';
	@override String get wifi => 'network/wifi';
	@override String get bluetoothSerial => 'bluetooth serial';
	@override String get bleSerial => 'bluetooth le';
	@override String get placeholder => 'placeholder';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$qrp extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'dipole';
	@override String get vertical => 'vertical';
	@override String get yagiBeam => 'yagi / beam';
	@override String get loop => 'loop';
	@override String get longWire => 'long wire / efhw';
	@override String get other => 'other';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$qrp extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get straight => 'straight key';
	@override String get sideswiper => 'sideswiper';
	@override String get bug => 'bug (mechanical semi-automatic)';
	@override String get fullyAutomatic => 'fully-automatic keyer';
	@override String get singlePaddle => 'single paddle';
	@override String get dualPaddle => 'dual paddle';
	@override String get computerDriven => 'computer driven';
	@override String get other => 'other';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$qrp extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$qrp._(TranslationsQrp root) : this._root = root, super.internal(root);

	final TranslationsQrp _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'unknown';
	@override String get sunny => 'sunny';
	@override String get clear => 'clear';
	@override String get mainlySunny => 'mainly sunny';
	@override String get mainlyClear => 'mainly clear';
	@override String get partlyCloudy => 'partly cloudy';
	@override String get cloudy => 'cloudy';
	@override String get foggy => 'foggy';
	@override String get rimeFog => 'rime fog';
	@override String get lightDrizzle => 'light drizzle';
	@override String get drizzle => 'drizzle';
	@override String get heavyDrizzle => 'heavy drizzle';
	@override String get lightFreezingDrizzle => 'light freezing drizzle';
	@override String get freezingDrizzle => 'freezing drizzle';
	@override String get lightRain => 'light rain';
	@override String get rain => 'rain';
	@override String get heavyRain => 'heavy rain';
	@override String get lightFreezingRain => 'light freezing rain';
	@override String get freezingRain => 'freezing rain';
	@override String get lightSnow => 'light snow';
	@override String get snow => 'snow';
	@override String get heavySnow => 'heavy snow';
	@override String get snowGrains => 'snow grains';
	@override String get lightShowers => 'light showers';
	@override String get showers => 'showers';
	@override String get heavyShowers => 'heavy showers';
	@override String get lightSnowShowers => 'light snow showers';
	@override String get snowShowers => 'snow showers';
	@override String get thunderstorm => 'thunderstorm';
	@override String get lightThunderstormsWithHail => 'light thunderstorms with hail';
	@override String get thunderstormWithHail => 'thunderstorm with hail';
}

/// The flat map containing all translations for locale <qrp>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsQrp {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'save',
			'common.ok' => 'ok',
			'common.cancel' => 'cancel',
			'common.delete' => 'delete',
			'common.create' => 'create',
			'common.error' => 'error',
			'common.close' => 'close',
			'common.done' => 'done',
			'common.callsign' => 'callsign',
			'common.clear' => 'clear',
			'common.dismiss' => 'dismiss',
			'common.expand' => 'expand',
			'common.collapse' => 'collapse',
			'onboarding.welcomeTitle' => 'welcome to ham2k portable logger!',
			'onboarding.welcomeTitleDesktop' => 'welcome to ham2k power logger!',
			'onboarding.welcomeBody' => 'we have a few questions to help us better suit your needs.',
			'onboarding.skip' => 'skip',
			'onboarding.kContinue' => 'continue',
			'onboarding.back' => 'back',
			'onboarding.next' => 'next',
			'onboarding.done' => 'done',
			'onboarding.callsignTitle' => 'what\'s your callsign?',
			'onboarding.callsignBody' => 'you need an amateur radio operator license in order to find this app useful',
			'onboarding.callsignLabel' => 'operator\'s callsign',
			'onboarding.alreadyHaveAccount' => 'already have an account?',
			'onboarding.foundSiblingTitle' => 'link an existing account?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'we found ${app} on this device. link this app to the same account and your callsign and logs come across.',
			'onboarding.foundPoloBody' => 'we found an older version of ham2k portable logger on this device. link this app to the same account and your callsign and logs come across.',
			'onboarding.foundSiblingsBody' => 'we found other ham2k apps on this device. link this app to one of their accounts and your callsign and logs come across.',
			'onboarding.linkWithApp' => ({required Object app}) => 'link with ${app}',
			'onboarding.linkWithPolo' => 'link with account in older version',
			'onboarding.setUpFresh' => 'set up fresh',
			'onboarding.activitiesTitle' => 'favorite activities',
			'onboarding.activitiesBody' => 'are you interested in any of these popular activation programs?',
			'onboarding.activitiesFooter' => '(you can find more options in the settings)',
			'onboarding.activityPota' => 'parks on the air',
			'onboarding.activitySota' => 'summits on the air',
			'onboarding.activityWwff' => 'world wide flora & fauna',
			'onboarding.consentTitle' => 'data & privacy',
			'onboarding.consentUsageBody' => 'to help us make the app better, we\'d like to collect performance, crash, and app usage data.',
			'onboarding.consentUsageLabel' => 'share app usage data',
			'onboarding.consentOperationBody' => 'some features might involve sharing your operation data with other users. you can opt-out at any time.',
			'onboarding.consentOperationLabel' => 'share operation data',
			'onboarding.finishingSetup' => 'finishing setup — downloading reference data…',
			'startScreen.credits' => 'by ki2d and friends',
			'testerOverlay.tape' => 'caution: under construction',
			'testerOverlay.warningTitle' => 'this app is a work in progress',
			'testerOverlay.warningBody' => 'most features have uneven surfaces and there are trip hazards all over. please check for updates regularly.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'what\'s new in build ${build}',
			'testerOverlay.thanks' => 'thank you for putting your log at risk in order to help us make this app better!',
			'extensionsPanel.categoryActivity' => 'activities',
			'extensionsPanel.categoryAward' => 'awards',
			'extensionsPanel.categoryContest' => 'contests',
			'extensionsPanel.categoryLookup' => 'callsign lookups',
			'extensionsPanel.categorySpots' => 'spot sources',
			'extensionsPanel.categoryDashboard' => 'dashboard panels',
			'extensionsPanel.categoryOther' => 'other extensions',
			'extensionsPanel.searchHint' => 'search extensions',
			'extensionsPanel.applying' => 'activating extension changes, this may take a moment…',
			'extensionsPanel.noMatches' => 'no extensions match your search',
			'extensionsPanel.installFromFile' => 'install from file…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'version ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'screenshot ${n} of ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'previous screenshot',
			'extensionsPanel.nextScreenshot' => 'next screenshot',
			'extensionsPanel.screenshotUnavailable' => 'screenshot unavailable',
			'extensionsPanel.canReach' => 'this extension can contact',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, over a live connection',
			'extensionsPanel.canHoldLocalConnection' => 'devices on your local network, over a live connection',
			'extensionsPanel.canUseLocation' => 'your location',
			'extensionsPanel.canReadRadio' => 'your radio, to read its frequency and mode',
			'extensionsPanel.canControlRadio' => 'your radio, to control it and to transmit with it — tuning, power, cw, voice memories and ptt',
			'extensionsPanel.canCommandRadioRaw' => 'your radio, to send it any command in its own protocol — including ones that transmit or change its settings',
			'extensionsPanel.canReadCluster' => 'the dx cluster, logged in as you, to read what it sends',
			'extensionsPanel.canSpotCluster' => 'the dx cluster, logged in as you, to post spots in your name',
			'extensionsPanel.canCommandCluster' => 'the dx cluster, logged in as you, to send it any command in your name',
			'extensionsPanel.canSetUserAgent' => 'identify itself to servers under its own name',
			'extensionsPanel.noCapabilities' => 'it asks for nothing outside the app.',
			'extensionsPanel.sandboxNote' => 'extensions run sandboxed: no access to your files, and no network beyond what is listed here.',
			'extensionsPanel.installAction' => 'install',
			'extensionsPanel.updateAction' => 'update',
			'extensionsPanel.installFailed' => 'that extension could not be installed',
			'extensionsPanel.installedBadge' => 'installed',
			'extensionsPanel.uninstallAction' => 'remove',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'remove ${name}?',
			'extensionsPanel.uninstallBody' => 'this extension and its settings will be removed. your logs will remain untouched.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'installed ${name}',
			'extensionsPanel.installDownloading' => 'downloading…',
			'extensionsPanel.installWaiting' => 'waiting to install…',
			'extensionsPanel.installInstalling' => 'installing…',
			'extensionsPanel.installAwaitingApproval' => 'waiting for your approval…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} is already being installed.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'updated to ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'installing ${name} did not finish. it may need installing again.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'could not remove ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'downloaded from ${source}',
			'extensionsPanel.dropHint' => 'drop a .h2kext extension to install it',
			'extensionsPanel.dropOneOnly' => 'drop one extension at a time.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} returned ${status} for that extension.',
			'extensionsPanel.downloadTooLarge' => 'that download is far too large to be an extension.',
			'extensionsPanel.downloadNotSecure' => 'that download redirected somewhere insecure.',
			'extensionsPanel.catalogSection' => 'catalog',
			'extensionsPanel.catalogLoading' => 'loading the catalog…',
			'extensionsPanel.catalogUnreachable' => 'catalog unreachable',
			'extensionsPanel.builtIn' => 'built in',
			'extensionsPanel.updateAvailableBadge' => 'update available',
			'extensionsPanel.updatesAvailableTitle' => 'extension updates',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'an update is available for ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} and ${count} more need updating.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} need updating.',
			'extensionsPanel.pendingUpdatesSection' => 'pending updates',
			'extensionsPanel.updateAllAction' => 'update all',
			'extensionsPanel.updatesUnderWay' => 'those updates are already under way.',
			'extensionsPanel.updatesNothingLeft' => 'your extensions are up to date.',
			'extensionsPanel.updatesNoticeAction' => 'more info',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'update ${count} extension?', other: 'update ${count} extensions?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'your extensions are ready',
			'extensionsPanel.upgradeDoneBody' => 'they now come from the ham2k extension catalog, so they can be updated without waiting for a new version of the app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'not upgraded: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'would not run: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'they are still installed and marked in settings › extensions — updating them there will bring them back.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'the catalog has no direct replacement for these, so look there for extensions that cover what you used.',
			'extensionsPanel.retiredQp' => 'qso parties',
			'extensionsPanel.retiredStateparks' => 'state parks events',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} of your extensions have not arrived yet. they will be downloaded the next time the extension catalog can be reached.',
			'extensionsPanel.runtimeDeadBody' => 'your extensions would not start. restarting the app should bring them back.',
			'extensionsPanel.refusedTitle' => 'some extensions would not run',
			'extensionsPanel.upgradeBusyTitle' => 'still setting up',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'your extensions are not running',
			'extensionsPanel.restoreTitle' => 'some of your extensions are missing',
			'extensionsPanel.restoreBody' => 'these extensions you installed are not on this device. we can download them again from the ham2k extension catalog:',
			'extensionsPanel.restoreFromFile' => 'installed from a file. install these again from their files, or forget them:',
			'extensionsPanel.restoreOtherCatalog' => 'installed from a different extension catalog, so they are not available here:',
			'extensionsPanel.restoreForget' => 'forget',
			'extensionsPanel.restoreInstall' => 'install',
			'extensionsPanel.restoreLater' => 'later',
			'extensionsPanel.restoreInstalling' => 'installing your extensions…',
			'extensionsPanel.restoreDoneTitle' => 'your extensions are back',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'installed again: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'some extensions could not be installed',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'could not install: ${names}. we will offer them again next time you open the app.',
			'extensionsPanel.restoreBusyBody' => 'the app is still setting your extensions up. we will offer these again next time you open the app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'we installed them again, but your extensions would not start. restarting the app should bring them back.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} was withdrawn',
			'extensionsPanel.revokedBody' => 'the catalog withdrew this version, so it has been disabled.',
			'extensionsPanel.downloadHashMismatch' => 'that download is not the extension the catalog described.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'the catalog has no version ${version} of ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'that catalog link does not name an extension version.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'the catalog has no release of ${key} on that track.',
			'extensionsPanel.installFromLink' => 'install from link',
			'extensionsPanel.unstableReleaseWarning' => 'this is an unstable release, which its publisher has not called finished. it may misbehave, and it will keep receiving unstable updates.',
			'extensionsPanel.bleedingReleaseWarning' => 'this is a bleeding-edge release: work in progress that may break or lose its settings. it will keep receiving bleeding-edge updates.',
			'extensionsPanel.channelUnstable' => 'unstable',
			'extensionsPanel.channelBleeding' => 'bleeding',
			'extensionsPanel.followsUnstable' => 'receives unstable and stable releases',
			'extensionsPanel.followsBleeding' => 'receives bleeding-edge, unstable and stable releases',
			'extensionsPanel.followStableAction' => 'follow stable releases only',
			'extensionsPanel.revokedBadge' => 'revoked',
			'extensionsPanel.refusedBadge' => 'did not load',
			'extensionsPanel.downloadNotHttps' => 'that download is not over a secure connection.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} could not be reached for that extension.',
			'extensionsPanel.detailsAction' => 'details',
			'extensionsPanel.installedFromFile' => 'installed from a file',
			'extensionsPanel.detailsWhatItDoes' => 'provides support for',
			'extensionsPanel.installedPreloaded' => 'pre-installed',
			'extensionsPanel.hookAccount' => 'account sign-in',
			'extensionsPanel.hookCallNotes' => 'call notes',
			'extensionsPanel.hookDataFile' => 'offline data',
			'extensionsPanel.hookExport' => 'export',
			'extensionsPanel.hookLookup' => 'callsign lookups',
			'extensionsPanel.hookScoring' => 'scoring',
			'extensionsPanel.hookSpots' => 'spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'hunting ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'activating ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '… and ${count} other extension', other: '… and ${count} other extensions', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} extension available', other: '${count} extensions available', ), 
			'home.title' => 'portable logger',
			'home.newOperation' => 'new operation',
			'home.stationCallsign' => 'station callsign',
			'home.titleOptional' => 'title (optional)',
			'home.emptyList' => 'no operations yet. create one to start logging.',
			'home.quickLookup' => 'quick lookup',
			'home.nav.operations' => 'operations',
			'home.nav.chase' => 'chasing',
			'home.nav.logs' => 'logs',
			'home.nav.maps' => 'maps',
			'home.nav.settings' => 'settings',
			'home.panels.operations' => 'operation list',
			'home.panels.operationsDescription' => 'your operations, most recent first.',
			'home.panels.version' => 'current version',
			'home.panels.versionDescription' => 'the ham2k mark, this app’s name and which build you are running.',
			'home.toggleNav' => 'show or hide the navigation labels',
			'home.logs.title' => 'logs',
			'home.logs.titleFor' => 'logs for',
			'home.logs.emptyCallsigns' => 'no qsos logged yet',
			'home.logs.emptyQsos' => ({required Object call}) => 'no qsos for ${call}',
			'home.logs.mapNoSelection' => 'select a qso to see it on the map',
			'home.logs.searchHint' => 'search callsign or name',
			'home.logs.noSearchMatches' => 'no qsos match your search',
			'home.logs.titleAll' => 'all logs',
			'home.logs.allCallsigns' => 'all callsigns',
			'home.logs.noOperation' => 'not part of an operation',
			'home.logs.unsavedTitle' => 'unsaved changes',
			'home.logs.unsavedBody' => 'this qso has changes you haven’t saved.',
			'home.logs.pendingDeleteBody' => 'this qso is marked for deletion.',
			'home.logs.editGone' => 'not saved: that qso is no longer in this log.',
			'home.logs.discard' => 'discard',
			'home.logs.sheet.callsigns' => 'station callsigns',
			'home.logs.sheet.groupBy' => 'group by',
			'home.logs.sheet.period' => 'time period',
			'home.logs.groupBy.none' => 'not grouped',
			'home.logs.groupBy.date' => 'date',
			'home.logs.groupBy.dx' => 'dx',
			'home.logs.groupBy.unknownContinent' => 'unknown continent',
			'home.logs.groupBy.unknownEntity' => 'unknown entity',
			'home.logs.groupBy.unknownDate' => 'no date',
			'home.logs.period.thisMonth' => 'this month',
			'home.logs.period.last3Months' => 'last 3 months',
			'home.logs.period.thisYear' => 'this year',
			'home.logs.period.lastYear' => 'last year',
			'home.logs.period.allTime' => 'all time',
			'home.logs.period.custom' => 'custom range',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'in ${span}',
			'home.logs.periodTitle.custom' => 'custom range',
			'home.logs.columns.date' => 'date',
			'home.logs.columns.time' => 'time',
			'home.logs.columns.freq' => 'frequency',
			'home.logs.columns.mode' => 'mode',
			'home.logs.columns.call' => 'call',
			'home.logs.columns.name' => 'name',
			'home.logs.columns.station' => 'station',
			'home.logs.columns.band' => 'band',
			'home.logs.columns.sent' => 'sent',
			'home.logs.columns.rcvd' => 'rcvd',
			'home.logs.columns.grid' => 'grid',
			'home.logs.columns.state' => 'state',
			'home.logs.columns.country' => 'country',
			'home.logs.columns.refs' => 'refs',
			'home.logs.panels.qsos' => 'qso log',
			'home.logs.panels.qsosDescription' => 'the selected callsign\'s qsos, across every operation.',
			'home.logs.panels.info' => 'info',
			'home.logs.panels.infoDescription' => 'total qso count, or the selected qso\'s callsign lookup.',
			'home.logs.panels.map' => 'map',
			'home.logs.panels.mapDescription' => 'the selected qso\'s location.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'callsigns: ${calls}',
			'home.logs.import.skippedOne' => '1 record could not be read',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} records could not be read',
			'home.logs.import.readingTitle' => 'reading adif file…',
			'home.logs.import.checkingTitle' => 'checking for duplicates…',
			'home.logs.import.importingTitle' => 'importing qsos…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} of ${total} checked',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} imported, out of ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'chasing',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} & more',
			'chase.station.title' => 'chasing station',
			'chase.station.stationLabel' => 'station: ',
			'chase.station.operatorLabel' => 'op: ',
			'chase.station.noLocation' => 'no location',
			'chase.periodInline.today' => 'today',
			'chase.periodInline.thisWeek' => 'this week',
			'chase.periodInline.last14Days' => 'in the last 14 days',
			'chase.periodInline.thisMonth' => 'this month',
			'chase.periodStats.today' => 'stats for today',
			'chase.periodStats.thisWeek' => 'stats for this week',
			'chase.periodStats.last14Days' => 'stats for last 14 days',
			'chase.periodStats.thisMonth' => 'stats for this month',
			'chase.period.today' => 'today',
			'chase.period.thisWeek' => 'this week',
			'chase.period.last14Days' => 'last 14 days',
			'chase.period.thisMonth' => 'this month',
			'chase.goals.title' => 'chasing goals',
			'chase.goals.remove' => ({required Object name}) => 'stop chasing ${name}',
			'chase.goals.extensionsTitle' => 'more chasing programs',
			'chase.panels.logging' => 'qsos',
			'chase.panels.loggingDescription' => 'logging controls above the qsos chased in the period.',
			'chase.panels.info' => 'info',
			'chase.panels.infoDescription' => 'the callsign being logged, or the period\'s stats.',
			'chase.panels.spots' => 'spots',
			'chase.panels.spotsDescription' => 'stations spotted on the air, ready to chase.',
			'chase.panels.map' => 'map',
			'chase.panels.mapDescription' => 'the period\'s qsos and the station being logged.',
			'chase.claims.checking' => 'checking qsos for chasing',
			'chase.claims.rebuilding' => ({required Object program}) => 'checking the log for ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} of ${total} qsos',
			'chase.notice.newRef' => ({required Object program}) => 'new ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'probably new ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'new ${program} band',
			'chase.notice.newBandGuess' => ({required Object program}) => 'probably new ${program} band',
			'chase.notice.newMode' => ({required Object program}) => 'new ${program} mode',
			'chase.notice.newModeGuess' => ({required Object program}) => 'probably new ${program} mode',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} unconfirmed',
			'chase.alerts.title' => 'alerts',
			'chase.alerts.newRef' => 'new reference',
			'chase.alerts.newBand' => 'new band',
			'chase.alerts.newMode' => 'new mode',
			'chase.alerts.unconfirmed' => 'unconfirmed',
			'chase.checklists' => 'chasing progress',
			'chase.imports.importFrom' => ({required Object label}) => 'import ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'import ${file} as',
			'chase.imports.dropHint' => 'drop a file to import it into a chasing program',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'imported ${count} ${program} entries from ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'imported ${count} ${program} entries from ${file}, skipped ${skipped} it could not read',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} has nothing ${program} can import',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} could not read ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} could not read any of the ${skipped} records in ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'no chasing program imports ${file}',
			'dialogs.operationDetails' => 'operation details',
			'dialogs.activities' => 'activities',
			'dialogs.stationCallsign' => 'station callsign',
			'dialogs.multiStationIdentifier' => 'multi-station identifier (numbers only)',
			'dialogs.notes' => 'notes',
			'dialogs.deleteOperationTitle' => 'delete operation',
			'dialogs.purgeTestsTitle' => 'purge test operations',
			'dialogs.purgeTestsBody' => 'this permanently deletes these test operations and their qsos. it cannot be undone.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'plus ${count} test contact that belongs to no operation.', other: 'plus ${count} test contacts that belong to no operation.', ), 
			'dialogs.purgeTestsAction' => 'purge',
			'dialogs.syncAllTitle' => 'replace this device\'s log?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'syncall backs up and clears ${qsos} from this device, then downloads the account\'s log again from the server. the backup stays in this device\'s database.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${n} qso has not been synced yet — the server never received it, and it will not come back.', other: '${n} qsos have not been synced yet — the server never received them, and they will not come back.', ), 
			'dialogs.syncAllAction' => 'wipe and resync',
			'dialogs.receivedPurgesTitle' => 'test operations removed elsewhere',
			'dialogs.receivedPurgesBody' => 'these were deleted as test operations on another device. remove them here too? this permanently deletes them and their qsos, and cannot be undone.',
			'dialogs.receivedPurgesAction' => 'remove',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'invalid callsign: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'invalid callsigns: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} has operated so far. ${typed} will be recorded for new contacts.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'no operator recorded so far. ${typed} will be recorded for new contacts.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'this operation already has contacts by ${calls}. ${typed} will only be recorded for new ones.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'also record ${typed} as the operator of the contact already logged', other: 'also record ${typed} as the operator of all ${count} contacts already logged', ), 
			'dialogs.callChange.operatorSeveralStations' => 'when using multiple stations over the air, there\'s no support for separate operators',
			'dialogs.callChange.contactsUnreadable' => 'this operation\'s contacts could not be read, so changing a callsign here won\'t offer to update them',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'the contacts already logged could not be updated, so no changes were made: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} of ${planned} contacts were updated — the rest are no longer in this operation',
			'operation.deletedReadOnly' => 'this operation is deleted. undelete it to log or make changes.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} qsos',
			'operation.tabs.info' => 'info',
			'operation.tabs.spots' => 'spots',
			'operation.tabs.map' => 'map',
			'operation.tabs.qsosPlain' => 'qsos',
			'operation.tabs.clock' => 'clock',
			'operation.tabs.weather' => 'weather',
			'operation.tabs.website' => 'web site',
			'operation.tabs.remoteScreen' => 'remote screen',
			'operation.tabs.solar' => 'solar',
			'operation.tabs.radio' => 'radio',
			'operation.tabs.summaries' => 'operation summaries',
			'operation.positions.nobodyYet' => 'no other operating positions are sharing this operation yet.',
			'operation.positions.positionLabel' => ({required Object number}) => 'pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'op: ${call}',
			'operation.positions.unnamedPosition' => 'another position',
			'operation.positions.thisDevice' => 'our operating position',
			'operation.positions.nameIn' => ' in ',
			'operation.positions.panelTitle' => 'positions',
			'operation.positions.panelDescription' => 'what every operating position sharing this operation is logging right now.',
			'operation.stationCallsignNone' => 'no station callsign',
			'operation.titleNone' => 'no title',
			'operation.deleteOperation' => 'delete operation',
			'operation.loggingControlsStale' => 'activity fields may be out of date — reopen the operation to refresh them',
			'operation.locationNone' => 'not set',
			'operation.generalOperation' => 'general operation',
			'operation.titleFor' => ({required Object value}) => 'for ${value}',
			'operation.titleAt' => ({required Object value}) => 'at ${value}',
			'operation.segmentNow' => ({required Object description}) => 'now ${description}',
			'operation.testOperationSuffix' => 'testing',
			'operation.menu.showRstFields' => 'show rst fields',
			'operation.menu.showStateField' => 'show state field',
			'operation.menu.showGridField' => 'show grid field',
			'operation.menu.showDeletedQsos' => 'show deleted qsos',
			'operation.menu.showDeletedOps' => 'show deleted operations',
			'operation.menu.showQsoNumbers' => 'show qso numbers',
			'operation.menu.lookupAllQsos' => 'lookup all qsos',
			'operation.menu.loggingSettingsTitle' => 'logging settings',
			'operation.menu.mapSettingsTitle' => 'map settings',
			'operation.menu.actionsSection' => 'actions',
			'operation.layout.title' => 'add a panel',
			'operation.layout.availableSection' => 'available panels',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} settings',
			'operation.layout.panelSettingsAction' => 'panel settings',
			'operation.layout.viewName' => 'operation view',
			'operation.layout.viewOptions' => 'view layout options',
			'operation.layout.viewTitleBuiltIn' => 'this view is built into the app, and so is its name',
			'operation.layout.resetOptions' => 'restore defaults',
			'operation.layout.removePane' => 'remove',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'restore ${panel} to its defaults?',
			'operation.layout.resetPaneConfirmBody' => 'its title, header and size go back to the defaults. the rest of the layout stays as it is.',
			'operation.layout.resetViewConfirm' => 'restore this view to its default layout?',
			'operation.layout.resetViewConfirmBody' => 'the panels go back to their default arrangement, and the view\'s options and every panel\'s go back to the defaults.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} layout settings',
			'operation.layout.paneTitle' => 'title',
			'operation.layout.paneShowHeader' => 'show header',
			'operation.layout.paneShowHeaderTabset' => 'always shown while this pane shares a group — the header is how the others are reached',
			'operation.layout.paneInherit' => 'same as the app',
			'operation.layout.searchHint' => 'search panels',
			'operation.layout.noPanelsMatch' => 'no panel matches your search.',
			'operation.layout.nothingToAdd' => 'this view already has all possible panels',
			'operation.layout.addPanel' => ({required Object panel}) => 'add ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'preview ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'extension "${name}" is missing',
			'operation.layout.missingExtensionEnable' => 'enable',
			'operation.layout.missingExtensionInstall' => 'install…',
			'operation.layout.missingExtensionWontRun' => 'this version won’t run. update it in settings › extensions.',
			'operation.layout.missingExtensionUnavailable' => 'not available in this app',
			'operation.layout.missingExtensionNotInCatalog' => 'not in the catalog',
			'operation.layout.missingExtensionCatalogUnreachable' => 'couldn’t reach the catalog. try again',
			'operation.layout.missingExtensionFailed' => 'that didn’t work. try again',
			'operation.layout.previewUnavailable' => 'this panel\'s preview image could not be shown.',
			'operation.layout.nestedPaneTitle' => 'more',
			'operation.layout.layouts.defaultName' => 'default',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'layout ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'layout: ${name}',
			'operation.layout.layouts.menuNew' => 'new…',
			'operation.layout.layouts.menuExport' => 'export…',
			'operation.layout.layouts.menuImport' => 'import…',
			'operation.layout.layouts.menuTitle' => 'layouts',
			'operation.layout.layouts.newTitle' => 'new layout',
			'operation.layout.layouts.editTitle' => 'edit layout',
			'operation.layout.layouts.edit' => 'edit',
			'operation.layout.layouts.duplicateCurrent' => 'duplicate current layout',
			'operation.layout.layouts.startFromDefault' => 'start from the default layout',
			'operation.layout.layouts.nameLabel' => 'name',
			'operation.layout.layouts.descriptionLabel' => 'description',
			'operation.layout.layouts.create' => 'create',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'save changes to "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'this layout has changes you haven’t saved.',
			'operation.layout.layouts.discard' => 'discard',
			'operation.layout.layouts.deleteTitle' => 'delete this layout?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'are you sure you want to delete this "${name}" layout?',
			'operation.layout.layouts.exportTitle' => 'export layout',
			'operation.layout.layouts.exportPick' => 'panels to export',
			'operation.layout.layouts.tabSet' => 'tab set',
			'operation.layout.layouts.exportAction' => 'export',
			'operation.layout.layouts.exported' => ({required Object location}) => 'layout saved to ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'couldn\'t export the layout: ${error}',
			'operation.layout.layouts.importTitle' => 'import layout',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'made for the ${view} view: panels only that view has are left out.',
			'operation.layout.layouts.viewHome' => 'home',
			'operation.layout.layouts.viewOperation' => 'operation',
			'operation.layout.layouts.viewLogs' => 'logs',
			'operation.layout.layouts.viewChase' => 'chasing',
			'operation.layout.layouts.importAsNew' => 'as a new layout',
			'operation.layout.layouts.importReplace' => 'in place of this layout',
			'operation.layout.layouts.importAdd' => 'added to this layout',
			'operation.layout.layouts.importAddHint' => 'the panels arrive in a new column on the right.',
			'operation.layout.layouts.importPick' => 'panels to import',
			'operation.layout.layouts.importReplaceSettings' => 'replace the settings of panels already set up here',
			'operation.layout.layouts.importAction' => 'import',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} isn\'t a layout this app can read: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'the text isn’t valid yaml (line ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'it isn’t a ham2k layout file',
			'operation.layout.layouts.problemNewerVersion' => 'it was written by a newer version of the app',
			'operation.layout.layouts.problemNoArrangement' => 'it holds no arrangement',
			'operation.layout.layouts.problemMalformed' => 'part of it doesn’t follow the layout format',
			'operation.layout.layouts.problemTooLarge' => 'it is too large',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'couldn\'t open the file: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'couldn\'t import the layout: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'couldn\'t copy the layout: ${error}',
			'operation.layout.layouts.importNothing' => 'no panel picked, so nothing was imported.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'left out: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'kept ${panels}: the small-screen arrangement can’t do without it.',
			'operation.layout.layouts.notOffered' => 'not available in this view',
			'operation.layout.layouts.alreadyPlaced' => 'already in this layout',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'needs ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'layout names couldn’t be read',
			'operation.layout.layouts.listRecoveredBody' => 'this view’s list of layouts could not be read. every layout is still here, numbered in place of its name.',
			'operation.layout.editLayout' => 'edit layout',
			'operation.layout.saveLayout' => 'save layout',
			'operation.layout.revertLayout' => 'discard layout changes',
			'operation.layout.done' => 'done',
			'operation.layout.layoutUnreadableTitle' => 'layout couldn\'t be read',
			'operation.layout.layoutUnreadableBody' => 'your saved layout could not be read, so the default arrangement is showing instead. it won\'t be saved over your original until you choose to keep it.',
			'operation.layout.layoutUnreadableAction' => 'use this layout',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} could not be displayed',
			'operation.layout.panelRenderRetry' => 'try again',
			'operation.layout.panelActionFailed' => 'that panel action failed. try again.',
			'operation.layout.panels.loggingDescription' => 'the log and the entry fields',
			'operation.layout.panels.infoDescription' => 'what we know about the station being worked',
			'operation.layout.panels.spotsDescription' => 'spots from the clusters and activity programs',
			'operation.layout.panels.mapDescription' => 'where the contacts are',
			'operation.layout.panels.summariesDescription' => 'the operation\'s stats and scores, in the sections and order you pick',
			'operation.layout.panels.summariesSections' => 'sections and order',
			'operation.layout.panels.summariesDays' => 'each day',
			'operation.layout.panels.summariesReset' => 'show all',
			'operation.layout.panels.summariesAllHidden' => 'every section is hidden. pick the ones to show in this panel\'s settings.',
			'operation.layout.panels.clockDescription' => 'a clock face, in any time zone',
			'operation.layout.panels.clockFace' => 'face',
			'operation.layout.panels.clockFaceLcd' => 'lcd',
			'operation.layout.panels.clockFaceAnalog' => 'analog',
			'operation.layout.panels.clockZone' => 'time zone',
			'operation.layout.panels.clockZoneUtc' => 'utc',
			'operation.layout.panels.clockZoneDevice' => 'this device',
			'operation.layout.panels.clockShowSeconds' => 'show seconds',
			'operation.layout.panels.weatherDescription' => 'conditions now and for the next eight hours, where you\'re operating',
			'operation.layout.panels.weatherUseOperationLocation' => 'use the operation\'s location',
			'operation.layout.panels.weatherLocation' => 'location',
			'operation.layout.panels.weatherLocationDescription' => 'a grid square (fn31pr) or lat,lon. ignored while \'use the operation\'s location\' is checked.',
			'operation.layout.panels.weatherNoLocation' => 'no location set. give this panel a location in its settings, or place it inside an operation that has one.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'couldn\'t read the location ${location}. use a grid square like fn31pr, or 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'couldn\'t reach open-meteo — no network? will try again shortly.',
			'operation.layout.panels.weatherUnreadable' => 'open-meteo responded, but not with anything readable. will try again shortly.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'gusts ${speed}',
			'operation.layout.panels.panelAgeNow' => 'just now',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} min ago', other: '${count} min ago', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} hr ago', other: '${count} hrs ago', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'unknown',
			'operation.layout.panels.weatherConditions.sunny' => 'sunny',
			'operation.layout.panels.weatherConditions.clear' => 'clear',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'mainly sunny',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'mainly clear',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'partly cloudy',
			'operation.layout.panels.weatherConditions.cloudy' => 'cloudy',
			'operation.layout.panels.weatherConditions.foggy' => 'foggy',
			'operation.layout.panels.weatherConditions.rimeFog' => 'rime fog',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'light drizzle',
			'operation.layout.panels.weatherConditions.drizzle' => 'drizzle',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'heavy drizzle',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'light freezing drizzle',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'freezing drizzle',
			'operation.layout.panels.weatherConditions.lightRain' => 'light rain',
			'operation.layout.panels.weatherConditions.rain' => 'rain',
			'operation.layout.panels.weatherConditions.heavyRain' => 'heavy rain',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'light freezing rain',
			'operation.layout.panels.weatherConditions.freezingRain' => 'freezing rain',
			'operation.layout.panels.weatherConditions.lightSnow' => 'light snow',
			'operation.layout.panels.weatherConditions.snow' => 'snow',
			'operation.layout.panels.weatherConditions.heavySnow' => 'heavy snow',
			'operation.layout.panels.weatherConditions.snowGrains' => 'snow grains',
			'operation.layout.panels.weatherConditions.lightShowers' => 'light showers',
			'operation.layout.panels.weatherConditions.showers' => 'showers',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'heavy showers',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'light snow showers',
			'operation.layout.panels.weatherConditions.snowShowers' => 'snow showers',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'thunderstorm',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'light thunderstorms with hail',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'thunderstorm with hail',
			'operation.layout.panels.websiteDescription' => 'a web page of your choosing, in a pane',
			'operation.layout.panels.websiteUrl' => 'address',
			'operation.layout.panels.websiteRefresh' => 'refresh',
			'operation.layout.panels.websiteRefreshNever' => 'never',
			'operation.layout.panels.websiteRefresh1' => 'every minute',
			'operation.layout.panels.websiteRefresh5' => 'every 5 minutes',
			'operation.layout.panels.websiteRefresh15' => 'every 15 minutes',
			'operation.layout.panels.websiteTitle' => 'panel name',
			'operation.layout.panels.websiteRefreshNow' => 'refresh now',
			'operation.layout.panels.websiteNoUrl' => 'no address yet. open this panel’s settings to choose a page.',
			'operation.layout.panels.websiteBadUrl' => 'that doesn’t look like a web address. it needs to start with https://',
			'operation.layout.panels.websiteNotHttps' => 'only https:// addresses can be shown here.',
			'operation.layout.panels.websiteUnsupported' => 'web pages can’t be shown in a panel on this system.',
			'operation.layout.panels.websiteOpenExternally' => 'open in browser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'couldn’t load the page: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'a screen, app or window shared by another of your devices.',
			'operation.layout.panels.remoteScreenTarget' => 'screen',
			'operation.layout.panels.remoteScreenChoose' => 'choose a screen…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'shared screens',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'none of your devices is sharing a screen. turn share screens and windows on under settings → peer devices, on the device you want to see.',
			'operation.layout.panels.remoteScreenUnset' => 'no screen chosen. open this panel\'s settings to pick one your other devices are sharing.',
			'operation.layout.panels.remoteScreenConnecting' => 'connecting…',
			'operation.layout.panels.remoteScreenPeerAway' => 'that device isn\'t connected right now.',
			'operation.layout.panels.remoteScreenNotOffered' => 'that device stopped sharing this screen.',
			'operation.layout.panels.remoteScreenNoListener' => 'that device can\'t accept connections — check its firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'screens are only shared over the local network, not bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'that device wouldn\'t share this screen.',
			'operation.layout.panels.remoteScreenSettings' => 'panel settings',
			'operation.layout.panels.remoteScreenAdjust' => 'adjust view',
			'operation.layout.panels.remoteScreenDetail' => 'detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'high',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'maximum',
			'operation.layout.panels.remoteScreenAdjustDone' => 'ok',
			'operation.layout.panels.remoteScreenZoomIn' => 'zoom in',
			'operation.layout.panels.remoteScreenZoomOut' => 'zoom out',
			'operation.layout.panels.remoteScreenStopped' => 'that screen or window is no longer being shown.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'that device couldn\'t capture that screen — it may need screen recording permission.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'that device didn\'t respond. it may not have screen sharing turned on.',
			'operation.layout.panels.remoteScreenNoMedia' => 'couldn\'t open a connection for the picture. check the firewall on this device.',
			'operation.layout.panels.solarDescription' => 'solar and geomagnetic conditions, with band-by-band propagation',
			'operation.layout.panels.solarUnreachable' => 'couldn\'t reach hamqsl.com — no network? will try again shortly.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com responded, but not with a reading we could use. will try again shortly.',
			'operation.layout.panels.solarAIndex' => 'a',
			'operation.layout.panels.solarKIndex' => 'kp',
			'operation.layout.panels.solarBandDay' => 'day',
			'operation.layout.panels.solarBandNight' => 'night',
			'operation.layout.panels.solarBandGood' => 'good',
			'operation.layout.panels.solarBandFair' => 'fair',
			'operation.layout.panels.solarBandPoor' => 'poor',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'sources: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'the connection is struggling — skipping frames.',
			'operation.layout.panels.remoteScreenStalled' => 'frames stopped getting through — this connection may be too slow.',
			'operation.layout.panels.radioDescription' => 'a radio\'s front panel — frequency, mode and power, under cat control',
			'operation.layout.panels.radioStyle' => 'style',
			'operation.layout.panels.radioStyleLcd' => 'lcd',
			'operation.layout.panels.radioStyleModern' => 'modern',
			'operation.layout.panels.radioRadio' => 'radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'vfo a — ${name}',
			'operation.layout.panels.radioAutoNone' => 'vfo a — no radio designated',
			'operation.layout.panels.radioNoRadio' => 'no radio to show. pick one in this panel\'s settings, or add one under station configuration.',
			'operation.layout.panels.radioNotConfigured' => 'this radio is not configured yet. choose its port or address under station configuration.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'radio not connected',
			'operation.layout.panels.radioWatts' => 'w',
			'operation.layout.panels.radioConnect' => 'connect this radio',
			'operation.layout.panels.radioDisconnect' => 'disconnect this radio',
			'operation.layout.panels.radioStale' => 'no data',
			'operation.layout.panels.radioTransmitting' => 'tx',
			'operation.layout.panels.radioSwr' => 'swr',
			'operation.layout.panels.radioAlc' => 'alc',
			'operation.layout.panels.radioVolts' => 'v',
			'operation.layout.panels.radioSwrHigh' => 'high swr',
			'operation.layout.htmlPanelUnsupported' => 'this panel needs a web view, which this platform does not provide',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'this panel needs a sandbox the web version cannot provide',
			'operation.export.title' => 'operation exports',
			'operation.export.syncedOperation' => 'operation is synced',
			'operation.export.unsyncedOperation' => 'operation has unsynced changes',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} qso in this operation', other: '${count} qsos in this operation', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'all ${total} qsos are synced',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} of ${total} qsos pending sync',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} event markers synced',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} of ${total} event markers pending',
			'operation.export.loading' => 'loading export options…',
			'operation.export.noOptions' => 'no export formats available (extension runtime still starting?)',
			'operation.export.nothingLogged' => 'nothing to export yet — this operation has no qsos.',
			'operation.export.share' => 'share',
			'operation.export.nothingSelected' => 'nothing selected',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'save ${count} file', other: 'save ${count} files', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'share ${count} file', other: 'share ${count} files', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'export ${count} file', other: 'export ${count} files', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'download ${count} file', other: 'download ${count} files', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'save combined ${count} file', other: 'save combined ${count} files', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'share combined ${count} file', other: 'share combined ${count} files', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'export combined ${count} file', other: 'export combined ${count} files', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'download combined ${count} file', other: 'download combined ${count} files', ), 
			'operation.export.saveOne' => ({required Object name}) => 'save ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'share ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'export ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'download ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'stash ${count} file', other: 'stash ${count} files', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'stash combined ${count} file', other: 'stash combined ${count} files', ), 
			'operation.export.settingsButton' => 'export settings',
			'operation.export.settingsTitle' => 'export settings',
			'operation.export.compactFileNames.title' => 'use compact file names',
			'operation.export.compactFileNames.descriptionOn' => 'short names built for uploaders, like n0call@us-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'readable names, like 2026-07-27 n0call at us-1234.adi',
			'operation.export.includePrivateData.title' => 'include private info',
			'operation.export.includePrivateData.descriptionOn' => 'names, addresses, emails, gridsquares and notes are included',
			'operation.export.includePrivateData.descriptionOff' => 'names, addresses, emails, gridsquares and notes are left out',
			'operation.export.includePrivateData.note' => 'the full adif export always includes everything',
			'operation.export.resultTitle' => 'export complete',
			'operation.export.resultFailedTitle' => 'export failed',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'exported ${count} file to ${path}', other: 'exported ${count} files to ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'exported ${count} file: ${path}', other: 'exported ${count} files: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'shared ${count} file', other: 'shared ${count} files', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'downloaded ${count} file', other: 'downloaded ${count} files', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'export failed: ${error}',
			'operation.export.stash.needsEmailTitle' => 'add an email address first',
			'operation.export.stash.needsEmailBody' => 'ham2k’s file stash sends your files to the email address on your lofi account, and you sign in with it at stash.ham2k.net. your account doesn’t have a confirmed one yet — add it in settings › cloud sync.',
			'operation.export.stash.openSyncSettings' => 'open cloud sync',
			'operation.export.stash.replaceTitle' => 'recent stash will be replaced',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'you sent “${name}” less than 6 hours ago and it hasn’t been downloaded yet. free accounts keep one stash at a time, so sending now replaces it.',
			'operation.export.stash.replaceConfirm' => 'send anyway',
			'operation.export.stash.failedTitle' => 'couldn’t send to ham2k’s file stash',
			'operation.export.stash.sentTitle' => 'sent to ham2k’s file stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'you can retrieve this file by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.', other: 'you can retrieve these files by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.', ), 
			'operation.export.stash.mayHaveArrived' => 'no answer from the stash — the file may have arrived anyway. check stash.ham2k.net before sending again',
			'operation.export.stash.notSent' => 'not sent',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'this file didn’t arrive:', other: 'these ${count} files didn’t arrive:', ), 
			'operation.export.stash.emailOffer' => 'or for your convenience, we can send you an email with a direct link.',
			'operation.export.stash.emailMe' => 'email me a link',
			'operation.export.stash.emailSent' => 'we’ve emailed you a download link.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'couldn’t send the email: ${error}',
			'operation.export.stash.freeTier' => 'free accounts can only keep one stash at a time. subscribers can keep as many as they want.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'sent ${count} file to ham2k’s file stash (stash.ham2k.net)', other: 'sent ${count} files to ham2k’s file stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'no spots match your filters',
			'operation.spots.error' => ({required Object error}) => 'failed to load spots: ${error}',
			'operation.spots.unknownBand' => 'other',
			'operation.spots.auto' => 'automatic',
			'operation.spots.autoValue' => ({required Object value}) => 'automatic (currently ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'any',
			'operation.spots.allBands' => 'all bands',
			'operation.spots.allModes' => 'all modes',
			'operation.spots.phoneAndCw' => 'phone & cw',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'showing ${count} of ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutes',
			'operation.spots.callsOfNote' => 'calls of note',
			'operation.spots.yourSpots' => 'your spots',
			'operation.spots.allSpots' => 'all spots',
			'operation.spots.continents.af' => 'africa',
			'operation.spots.continents.as' => 'asia',
			'operation.spots.continents.eu' => 'europe',
			'operation.spots.continents.na' => 'north america',
			'operation.spots.continents.oc' => 'oceania',
			'operation.spots.continents.sa' => 'south america',
			'operation.spots.continents.an' => 'antarctica',
			'operation.spots.filters.title' => 'filter spots',
			'operation.spots.filters.band' => 'band',
			'operation.spots.filters.mode' => 'mode',
			'operation.spots.filters.age' => 'age',
			'operation.spots.filters.sources' => 'sources',
			'operation.spots.filters.continent' => 'continent',
			'operation.spots.filters.sorting' => 'sorting',
			'operation.spots.filters.sortByTime' => 'by spot time',
			'operation.spots.filters.sortByFrequency' => 'by frequency',
			'operation.spots.filters.sortByWanted' => 'most wanted',
			'operation.spots.filters.groupByBand' => 'group by band',
			'operation.spots.filters.groupCallsWithNotes' => 'group calls with notes',
			'operation.spots.filters.alertingOnly' => 'only spots with alerts',
			'operation.spots.filters.sourceNoReply' => 'no reply',
			'operation.spots.filters.sourceError' => 'error',
			'operation.spots.unavailableTitle' => 'spots unavailable',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} did not respond.',
			'operation.spots.failedTitle' => 'spot source error',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} returned an error.',
			'operation.spots.slideLogIt' => 'log it',
			'operation.spots.slideIgnore' => 'ignore',
			'operation.spots.slideRestore' => 'restore',
			'operation.spots.logConflict.title' => 'logging panel is busy',
			'operation.spots.logConflict.editingBody' => 'you\'re editing a logged contact. log this spot instead, or go back and finish the edit?',
			'operation.spots.logConflict.composingBody' => 'you\'ve started entering a contact. log this spot instead, or go back and finish what you were typing?',
			'operation.spots.logConflict.goBack' => 'go back',
			'operation.spots.logConflict.clearAndLog' => 'clear and log spot',
			'operation.import.title' => 'import data into operation',
			'operation.import.importAdifAction' => 'import qsos from adif',
			'operation.import.settingsButton' => 'listen settings',
			'operation.import.settingsTitle' => 'listen for other apps',
			'operation.import.protocolAddressLabel' => 'address',
			'operation.import.protocolPortLabel' => 'port',
			'operation.import.protocolPortInvalid' => 'enter a port between 1 and 65535',
			'operation.import.protocolAddressInvalid' => 'enter a valid ip address (e.g. 127.0.0.1 or 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'receiving data',
			'operation.import.protocolStatusNoData' => 'no data received recently',
			'operation.import.protocolBindError' => ({required Object error}) => 'couldn\'t start listening: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'incoming qsos could not be saved and are being retried: ${error}',
			'operation.import.n1mmProtocolName' => 'n1mm+ contact broadcast',
			'operation.import.n1mmAddressValue' => 'any (broadcast)',
			'operation.import.wsjtxProtocolName' => 'wsjt-x udp server',
			'operation.import.helpN1mmSetup' => 'config → configure ports, mode control… → broadcast data tab → check "enable broadcasts" for contact info. set ip address to 127.0.0.1 if running on this same computer, or 255.255.255.255 to broadcast on the current local network.',
			'operation.import.helpWsjtxSetup' => 'file → settings → reporting tab → udp server section → check "accept udp requests". set udp server to 127.0.0.1 if running on this same computer, or a multicast address such as 239.239.0.2, and use the same address in the configuration above in this app.',
			'operation.import.listenTitle' => 'listen for qsos from other apps',
			'operation.import.listenDescriptionOnN1mm' => 'listening for n1mm+',
			'operation.import.listenDescriptionOnWsjtx' => 'listening for wsjt-x',
			'operation.import.listenDescriptionOnBoth' => 'listening for n1mm+ and wsjt-x',
			'operation.import.listenDescriptionOff' => 'off',
			'operation.import.addToOperationTitle' => 'add to this operation',
			'operation.import.addToOperationDescriptionOn' => 'captured qsos are added to this operation as they arrive',
			'operation.import.addToOperationDescriptionOff' => 'captured qsos are held until you turn this on',
			'operation.import.pendingSectionTitle' => 'captured qsos',
			'operation.import.pendingEmpty' => 'nothing captured yet',
			'operation.import.stationMismatch' => ({required Object call}) => 'logged as ${call}, not this operation\'s station',
			'operation.import.discardAction' => 'discard',
			'operation.import.gapDialogTitle' => 'include earlier captures?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} more qsos were captured earlier, before a gap in the data. include them too?',
			'operation.import.gapDialogRecentOnly' => 'just the recent ones',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'include all ${count}',
			'map.outlineIssue.link' => 'issues?',
			'map.outlineIssue.title' => 'report an outline issue',
			'map.outlineIssue.reference' => 'which outline',
			'map.outlineIssue.severity' => 'how bad is it?',
			'map.outlineIssue.minor' => 'minor nit',
			'map.outlineIssue.major' => 'big deal',
			'map.outlineIssue.explanation' => 'what\'s wrong with it?',
			'map.outlineIssue.explanationHint' => 'what the outline gets wrong, and where',
			'map.outlineIssue.send' => 'send',
			'map.outlineIssue.sending' => 'sending your report — thanks',
			'map.outlineIssue.copy' => 'copy report',
			'map.outlineIssue.notSent' => 'couldn\'t send the report',
			'map.outlineIssue.copied' => 'report copied',
			'map.outlineIssue.notCopied' => 'couldn\'t copy the report',
			'map.outlinesDisclaimer' => 'outlines are for reference only. do your own research!',
			'map.outlinesCredit' => ({required Object sources}) => 'outlines: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'boundaries: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'facilities: ${sources}',
			'map.fullCredits' => 'full dataset credits',
			'map.fewerCredits' => 'fewer credits',
			'map.emptyState' => 'no qso locations yet.\nqsos with a grid square, state, or country will show up here.',
			'map.unavailable' => 'the map isn\'t available right now.',
			'map.qthPopupTitle' => ({required Object grid}) => 'qth: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'flat',
			'map.globe' => 'globe',
			'map.zoomIn' => 'zoom in',
			'map.zoomOut' => 'zoom out',
			'map.resetNorth' => 'reset to north up',
			'map.postcard.button' => 'operation postcard',
			'map.postcard.title' => ({required Object title}) => 'postcard for ${title}',
			'map.postcard.portrait' => 'portrait',
			'map.postcard.landscape' => 'landscape',
			'map.postcard.square' => 'square',
			'map.postcard.save' => 'save…',
			'map.postcard.download' => 'download',
			'map.postcard.share' => 'share',
			'map.postcard.copy' => 'copy',
			'map.postcard.copied' => 'copied to the clipboard',
			'map.postcard.saved' => ({required Object path}) => 'saved to ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'downloaded ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'saved ${count} images to ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'saved ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} had already been saved',
			'map.postcard.downloadedMany' => ({required Object count}) => 'downloading ${count} images — allow them if the browser asks',
			'map.postcard.mapLeftOut' => 'the map didn\'t load, so it was left out',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — the map didn\'t load, so it was left out',
			'map.postcard.continued' => ({required Object title}) => '${title} (continued)',
			'map.postcard.previousPage' => 'previous page',
			'map.postcard.nextPage' => 'next page',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'page ${page} of ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} q', other: '${count} qs', ), 
			'map.postcard.options' => 'postcard options',
			'map.postcard.bandLegend' => 'show band legend',
			'map.postcard.grayline' => 'show grayline',
			'map.postcard.sectionsAndOrder' => 'summary sections and ordering',
			'map.postcard.sectionDays' => 'each day',
			'map.postcard.reset' => 'reset',
			'map.postcard.failed' => ({required Object error}) => 'could not make the postcard: ${error}',
			'map.postcard.mapNotReady' => 'the map didn\'t finish loading. check the connection and try again.',
			'map.postcard.saveFailed' => ({required Object error}) => 'could not save the postcard: ${error}',
			'map.postcard.copyFailed' => 'the clipboard didn\'t take the image. try again.',
			'map.postcard.shareFailed' => 'could not share the postcard. try again.',
			'map.postcard.fileName' => 'postcard',
			'mapsView.title' => 'maps',
			'mapsView.searchHint' => 'search parks, summits and more',
			'mapsView.activities' => 'activities',
			'mapsView.layers' => 'layers',
			'mapsView.baseMap' => 'base map',
			'mapsView.satellite' => 'satellite (esri)',
			'mapsView.facilities' => 'park facilities',
			'mapsView.boundaries' => 'boundaries',
			'mapsView.currentLocation' => 'current location',
			'mapsView.noMatches' => ({required Object text}) => 'nothing matches “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} reference at ${where}', other: '${count} references at ${where}', ), 
			'mapsView.startOperation' => 'start an operation with these references',
			'activitiesView.title' => 'activities',
			'activitiesView.activitiesCountZero' => 'no activities selected',
			'activitiesView.activitiesCountOne' => '1 activity',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} activities',
			'activitiesView.empty' => 'no activities yet — use suggestions & search below to add one',
			'activitiesView.removeActivity' => 'remove',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'open ${name}',
			'activitiesView.editActivity' => 'edit activity',
			'activitiesView.manageExtensions' => 'manage extensions',
			'activitiesView.manage' => 'manage',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'activity types: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'activity types: ${first} and ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'activity types: ${first}, ${second} and ${more} more',
			'activitiesView.reference' => 'reference',
			'activitiesView.invalidReference' => 'not valid',
			'activitiesView.duplicateReference' => 'already added',
			'activitiesView.searchHint' => 'search by name, reference or anything else…',
			'activitiesView.noSuggestions' => 'no matches',
			'activitiesView.noSuggestionsHint' => 'search by reference name or number above',
			'activitiesView.noSuggestionsExample' => '(for example \'trail\' or \'4556\')',
			'activitiesView.allOptions' => 'activity types',
			'activitiesView.determiningLocation' => 'determining current location…\nwaiting for gps fix to find nearby references',
			'activitiesView.locationUnavailableTitle' => 'location data not available',
			'activitiesView.locationDeniedTitle' => 'location permission denied',
			'activitiesView.locationBlockedTitle' => 'location permission blocked',
			'activitiesView.noNearbyReason' => 'cannot determine nearby references',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'tap ${icon} to manually enter your location,\nor just search for references by name',
			'activitiesView.locationGrantAction' => 'allow location access',
			'activitiesView.locationSettingsAction' => 'open settings',
			'activitiesView.locationSettingsUnavailable' => 'allow location access in your system settings',
			'activitiesView.locationGrantRefused' => 'still no location — the system said no again',
			'activitiesView.searchUnavailableTitle' => 'activity search unavailable',
			'activitiesView.searchUnavailableReason' => 'no activity extension could run the search. try again in a moment.',
			'activitiesView.emptySheet' => 'use suggestions & search below to add one',
			'activitiesView.exports' => 'exports',
			'activitiesView.exportLogs' => 'export logs',
			'activitiesView.tools' => 'tools',
			'activitiesView.toolsTitle' => 'operation tools',
			'activitiesView.operationDetails' => 'operation details',
			'activitiesView.share' => 'share',
			'activitiesView.archive' => 'archive',
			'activitiesView.deleteOperation' => 'delete operation',
			'activitiesView.undeleteOperation' => 'undelete operation',
			'activitiesView.alreadySelected' => 'already selected',
			'activitiesView.selected' => 'selected',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} of ${count}',
			'activitiesView.previousPick' => 'previous match',
			'activitiesView.nextPick' => 'next match',
			'activitiesView.retiredReference' => 'retired',
			'activitiesView.enableExtension' => ({required Object name}) => 'enable ${name}',
			'activitiesView.enableExtensionHint' => 'this extension matches your search, but it is not currently enabled',
			'activitiesView.enableExtensionForRefHint' => 'this extension handles one of this operation\'s references, but it is not currently enabled',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} is not running',
			'activitiesView.extensionNotRunningHint' => 'this extension has been disabled, open extension settings for more info',
			'activitiesView.installExtension' => ({required Object name}) => 'install ${name}',
			'activitiesView.installExtensionHint' => 'this extension matches your search, but it is not installed',
			'activitiesView.onlyCatalogMatches' => 'no matches\nsome extensions in the catalog might have results.\ninstall them in activity types below.',
			'activitiesView.setupUnavailable' => 'could not load this activity\'s setup — try again from manage',
			'activitiesView.controlsUnavailableTitle' => 'activity controls unavailable',
			'activitiesView.controlsUnavailableReason' => 'your references are safe, but editing them is unavailable right now.',
			'activitiesView.controlsUnavailableRetry' => 'retry',
			'activitiesView.onlyDisabledMatches' => 'no matches\nsome available extensions might have results.\nenable them in activity types below.',
			'activitiesView.onlyNotRunningMatches' => 'no matches\nsome extensions that might have results are not running.\nsee activity types below.',
			'activitiesView.mapToggle' => 'map',
			'activitiesView.searchToggle' => 'search',
			'activitiesView.addToOperation' => 'add to operation',
			'activitiesView.addToOperationShort' => 'add to op.',
			'activitiesView.mapEmptyState' => 'no results to show on the map',
			'activitiesView.mapEmptyStateHint' => 'switch back to the list, or search for something else',
			'activitiesView.imports' => 'imports',
			'loggingControls.timeUtc' => 'time (utc)',
			'loggingControls.date' => 'date',
			'loggingControls.now' => 'now',
			'loggingControls.manualTimeSettings' => 'manual time',
			'loggingControls.manualTimeIncrement' => 'increment per qso',
			'loggingControls.manualTimeIncrementNone' => 'none',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} minute', other: '${count} minutes', ), 
			'loggingControls.frequency' => 'frequency',
			'loggingControls.mode' => 'mode',
			'loggingControls.theirCall' => 'their call',
			'loggingControls.noteField' => 'note',
			'loggingControls.todoField' => 'todo',
			'loggingControls.sent' => 'sent',
			'loggingControls.rcvd' => 'rcvd',
			'loggingControls.more' => 'more',
			'loggingControls.revert' => 'revert',
			'loggingControls.undoDelete' => 'undo delete',
			'loggingControls.restore' => 'restore',
			'loggingControls.wipe' => 'wipe',
			'loggingControls.undo' => 'undo',
			'loggingControls.pendingDeleteTapWarning' => 'tap the trashcan one more time to delete this qso',
			'loggingControls.pendingDeleteClickWarning' => 'click the trashcan one more time to delete this qso',
			'loggingControls.deletedQsoWarning' => 'deleted qso',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'tap the trashcan one more time to delete this ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'click the trashcan one more time to delete this ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'deleted ${kind}',
			'loggingControls.timeControl' => 'time',
			'loggingControls.radioControl' => 'radio',
			'loggingControls.powerControl' => 'power',
			'loggingControls.notesControl' => 'notes',
			'loggingControls.power' => 'power',
			'loggingControls.powerUnit' => 'w',
			'loggingControls.controlSettings' => 'logging controls',
			'loggingControls.spottingControl' => 'spotting',
			'loggingControls.spottingSelfControl' => 'self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'self-spot at ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'spot ${call} at ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'too late to spot ${call}',
			'loggingControls.spotNoFreq' => 'first set a frequency to spot',
			'loggingControls.spotComment' => 'comment',
			'loggingControls.spottingAutoControl' => 'auto re-spot',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 're-spot every ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'auto in ${time}. stop?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'auto in ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'auto in ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'auto in ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'auto re-spot not started: the spot did not go through',
			'loggingControls.spotAutoMoved' => 'auto re-spot not started: the frequency changed while spotting',
			'loggingControls.spotAutoStopped' => 'auto re-spot stopped',
			'loggingControls.spotAutoLeftFreq' => 'auto re-spot stopped: the frequency changed',
			'loggingControls.spotAutoNoFreq' => 'auto re-spot stopped: the radio reports no frequency',
			'loggingControls.spotBusy' => 'another spot is still being sent',
			'loggingControls.bandOrFreqRequired' => 'set a frequency or band before logging',
			'loggingControls.missingBand' => 'no band',
			'loggingControls.missingMode' => 'no mode',
			'loggingControls.saveFailed' => ({required Object error}) => 'could not save: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'could not delete: ${error}',
			'loggingControls.info.noQsos' => 'no qsos yet... let\'s get on the air!',
			'loggingControls.info.qsoCountOne' => '1 qso',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} qsos',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} since last',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} q/h for last 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} q/h for last 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} to',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} away',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'dupe!',
			'loggingControls.info.noticeNewBand' => 'new band',
			'loggingControls.info.noticeNewMode' => 'new mode',
			'loggingControls.info.noticeNewDXCC' => 'new dxcc',
			'loggingControls.info.noticeNewState' => 'new state',
			'loggingControls.info.noticeNewProvince' => 'new province',
			'loggingControls.info.noticeNewDay' => 'new day',
			'loggingControls.info.noticeNewRef' => 'new ref',
			'loggingControls.info.noticeNewMult' => 'new mult',
			'loggingControls.info.noticeNewZone' => 'new zone',
			'loggingControls.info.noticeInvalidMode' => 'wrong mode',
			'loggingControls.info.noticeInvalidBand' => 'wrong band',
			'loggingControls.info.noticeInvalidCategory' => 'not workable',
			'loggingControls.info.noticeOverTime' => 'time over',
			'loggingControls.info.noticeWorkedBefore' => 'worked before',
			'loggingControls.info.noticeNewPark' => 'new park',
			'loggingControls.info.noticeNewSection' => 'new section',
			'loggingControls.info.noticeBonusStation' => 'bonus station!',
			'loggingControls.info.noticeMissingExchange' => 'no exchange',
			'loggingControls.info.noticeInvalidExchange' => 'bad exchange',
			'loggingControls.info.noticeUnknownEvent' => 'unknown event',
			'loggingControls.info.noticeIncompleteCall' => 'incomplete call — not scored',
			'loggingControls.info.noticeOurGrid' => 'set our grid',
			'loggingControls.info.noticeRareCounty' => 'rare county!',
			'loggingControls.info.noticeOurLocation' => 'set our county',
			'loggingControls.info.noticeShortGrid' => 'grid too short',
			'formChrome.untitled' => '(untitled)',
			'formChrome.showMore' => 'show more',
			'formChrome.showAll' => 'show all',
			'formChrome.showFewer' => 'show fewer',
			'formChrome.defaults' => 'defaults',
			'formChrome.search' => 'search',
			'formChrome.clear' => 'clear',
			'formChrome.openPage' => 'open page',
			'formChrome.connected' => 'connected',
			'formChrome.notConnected' => 'not connected',
			'formChrome.manage' => 'manage',
			'formChrome.connect' => 'connect',
			'formChrome.formTitle' => 'form',
			'formChrome.addItem' => ({required Object label}) => 'add ${label}',
			'formChrome.editItem' => ({required Object label}) => 'edit ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'showing ${shown} of ${total} (${selected} selected)',
			'formChrome.validationError' => ({required Object error}) => 'validation error: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'transformation error: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'error: ${error}',
			'formChrome.removeItem' => 'delete',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'delete ${name}?',
			'formChrome.storageUnavailable' => 'logins unavailable',
			'qsoEditForm.title' => 'edit qso',
			_ => null,
		} ?? switch (path) {
			'qsoEditForm.operatorCall' => 'operator',
			'qsoEditForm.position' => 'position',
			'qsoEditForm.theirName' => 'name',
			'qsoEditForm.theirGrid' => 'grid',
			'qsoEditForm.theirState' => 'state',
			'qsoEditForm.band' => 'band',
			'qsoEditForm.notes' => 'notes',
			'qsoEditForm.sectionQso' => 'qso',
			'qsoEditForm.sectionTheir' => 'their info',
			'qsoEditForm.sectionOur' => 'our info',
			'qsoEditForm.sectionNotes' => 'notes',
			'qsoEditForm.theirCity' => 'city',
			'qsoEditForm.theirCounty' => 'county',
			'qsoEditForm.theirEntity' => 'entity',
			'qsoEditForm.theirCqZone' => 'cq zone',
			'qsoEditForm.theirItuZone' => 'itu zone',
			'qsoEditForm.theirArrlSection' => 'arrl section',
			'qsoEditForm.theirLat' => 'latitude',
			'qsoEditForm.theirLon' => 'longitude',
			'qsoEditForm.theirPower' => 'their power',
			'qsoList.empty' => 'no qsos yet — work someone!',
			'qsoList.bandOrModeWarning' => 'please make sure your band and mode are correct',
			'qsoList.today' => 'today',
			'qsoList.yesterday' => 'yesterday',
			'qsoList.tomorrow' => 'tomorrow',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'find in log (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'find in log',
			'qsoList.find.hint' => 'qso number or callsign',
			'qsoList.find.noMatches' => 'no match',
			'qsoList.find.noOperationQsos' => 'no qsos in this operation',
			'qsoList.find.noPeriodQsos' => 'no qsos in this period',
			'qsoList.find.outsideQsosOne' => '1 qso outside of this operation',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} qsos outside of this operation',
			'qsoList.find.pastQsosOne' => '1 past qso',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} past qsos',
			'loggingPanel.stats' => 'operation stats',
			'loggingPanel.scoring' => 'scoring',
			'loggingPanel.dxccEntities' => 'dxcc entities',
			'loggingPanel.statesWorked' => 'states',
			'loggingPanel.provincesWorked' => 'provinces',
			'loggingPanel.duplicates' => 'duplicates',
			'callInfo.qrz' => 'qrz',
			'callInfo.showImage' => 'show image',
			'callInfo.imageUnavailable' => 'photo unavailable',
			'callInfo.photo' => 'photo',
			'callInfo.notes' => 'notes',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} to',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} away',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away',
			'callInfo.thisOpCountOne' => '1 qso in this operation',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} qsos in this operation',
			'callInfo.otherOpsCountOne' => '1 qso in other operations',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} qsos in other operations',
			'callInfo.andMore' => ({required Object count}) => '… and ${count} more',
			'callInfo.withCall' => ({required Object call}) => 'with ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'from ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} in last 7 days',
			'callInfo.history.today' => ({required Object n}) => '${n} today',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${n} qso', other: '${n} qsos', ), 
			'settings.title' => 'settings',
			'settings.language' => 'language',
			'settings.languageSystem' => ({required Object language}) => 'follow system settings (${language})',
			'settings.theme.title' => 'theme mode',
			'settings.theme.system' => 'follow system settings',
			'settings.theme.light' => 'light',
			'settings.theme.dark' => 'dark',
			'settings.themeDescription.system' => 'following system settings',
			'settings.themeDescription.light' => 'always in light mode',
			'settings.themeDescription.dark' => 'always in dark mode',
			'settings.fontScale' => 'font scale',
			'settings.fontScaleOpts.smallestMinusMinus' => 'smallest--',
			'settings.fontScaleOpts.smallestMinus' => 'smallest-',
			'settings.fontScaleOpts.smallest' => 'smallest',
			'settings.fontScaleOpts.smaller' => 'smaller',
			'settings.fontScaleOpts.normal' => 'normal',
			'settings.fontScaleOpts.larger' => 'larger',
			'settings.fontScaleOpts.largest' => 'largest',
			'settings.fontScaleOpts.largestPlus' => 'largest+',
			'settings.fontScaleOpts.largestPlusPlus' => 'largest++',
			'settings.keepDeviceAwake.title' => 'keep device awake',
			'settings.keepDeviceAwake.descriptionOn' => 'staying awake while you are on the logging view or a sync is in progress',
			'settings.keepDeviceAwake.descriptionOff' => 'sleeping as usual',
			'settings.layoutDensity' => 'layout density',
			'settings.layoutDensityOpts.auto' => 'automatic',
			'settings.layoutDensityOpts.densest' => 'densest',
			'settings.layoutDensityOpts.dense' => 'dense',
			'settings.layoutDensityOpts.normal' => 'normal',
			'settings.layoutDensityOpts.sparse' => 'sparse',
			'settings.layoutDensityOpts.sparsest' => 'sparsest',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'the window is too short, using ${effective}',
			'settings.layoutDensityAtLimit' => 'as far as it goes',
			'settings.distanceUnits' => 'distance units',
			'settings.distanceUnitsOpts.kilometers' => 'kilometers',
			'settings.distanceUnitsOpts.miles' => 'miles',
			'settings.userInterface' => 'user interface',
			'settings.logging.title' => 'logging',
			'settings.logging.leftieMode.title' => 'leftie mode',
			'settings.logging.leftieMode.descriptionOn' => 'using layout for left-handed users',
			'settings.logging.leftieMode.descriptionOff' => 'using layout for right-handed users',
			'settings.logging.countryFlags.title' => 'country flags',
			'settings.logging.countryFlags.dx' => 'show only for dx contacts',
			'settings.logging.countryFlags.all' => 'show flags for all contacts',
			'settings.logging.countryFlags.none' => 'don\'t show any flags',
			'settings.logging.countryFlagsDescription.dx' => 'showing flags only for dx contacts',
			'settings.logging.countryFlagsDescription.all' => 'showing flags for all contacts',
			'settings.logging.countryFlagsDescription.none' => 'not showing any flags',
			'settings.logging.suggestDefaultOperator.title' => 'suggest operator',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'offering your callsign as the operator when an operation runs under a different station callsign',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'leaving the operator blank unless you fill it in',
			'settings.logging.showBearing.title' => 'show bearing',
			'settings.logging.showBearing.descriptionOn' => 'showing estimated bearing to station',
			'settings.logging.showBearing.descriptionOff' => 'not showing bearing information',
			'settings.logging.showReverseBearing.title' => 'also show reverse bearing',
			'settings.logging.showReverseBearing.descriptionOn' => 'showing the bearing from the station too, as "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'only showing the bearing to the station',
			'settings.logging.switchSentRcvd.title' => 'switch signal report order',
			'settings.logging.switchSentRcvd.sentFirst' => 'sent first, rcvd second',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'rcvd first, sent second',
			'settings.logging.jumpAfterRST.title' => 'jump to next field on rst entry',
			'settings.logging.jumpAfterRST.descriptionOn' => 'jumping after rst is entered',
			'settings.logging.jumpAfterRST.descriptionOff' => 'not jumping automatically',
			'settings.logging.defaultReport.title' => 'default report — phone',
			'settings.logging.defaultReport.description' => 'used when sent or rcvd is left empty on ssb, fm or am',
			'settings.logging.defaultReportCW.title' => 'default report — cw and data',
			'settings.logging.defaultReportCW.description' => 'used when sent or rcvd is left empty on cw, rtty and other data modes',
			'settings.logging.defaultReportFT8.title' => 'default report — ft8 and ft4',
			'settings.logging.defaultReportFT8.description' => 'used when sent or rcvd is left empty on the ft modes',
			'settings.logging.numbersRow.title' => 'numbers row',
			'settings.logging.numbersRow.description' => 'show a row of number keys above the keyboard while logging',
			'settings.logging.numbersRowExtra.title' => 'slash and period key',
			'settings.logging.numbersRowExtra.description' => 'adds a contextual key: “/” for callsigns, “.” for numbers',
			'settings.logging.numbersRowVibrate.title' => 'vibrate on key press',
			'settings.logging.numbersRowVibrate.description' => 'haptic feedback when you tap a number key',
			'settings.logging.bands' => 'preferred bands',
			'settings.logging.modes' => 'preferred modes',
			'settings.catServer.title' => 'cat server',
			'settings.catServer.description' => 'allow other apps (wsjt-x, loggers, etc) to control the radio through ham2k logger.',
			'settings.catServer.protocol' => 'protocol',
			'settings.catServer.protocolOpts.off' => 'disabled',
			'settings.catServer.protocolOpts.rigctld' => 'hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'ham radio deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'n3fjp',
			'settings.catServer.port' => 'port',
			'settings.catServer.openAccess' => 'open access',
			'settings.catServer.openAccessOn' => 'any computer on the local network can connect.',
			'settings.catServer.openAccessOff' => 'only apps on this computer can connect.',
			'settings.catServer.off' => 'off.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, starting…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} on port ${port}. clients connected: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} on port ${port}, but no main vfo radio is connected.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} cannot listen on port ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: another program is using it, often ${protocol} itself. close that program or choose another port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: this computer does not allow it. choose a port above 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} stopped listening on port ${port}. trying again…',
			'settings.cluster.title' => 'dx cluster',
			'settings.cluster.description' => 'the server extensions post spots to and read spots from, logged in as the operator.',
			'settings.cluster.server' => 'cluster server',
			'settings.cluster.selectServer' => 'select server',
			'settings.cluster.serverOther' => 'other',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'no host entered yet, so spots go to ${node}',
			'settings.cluster.customHost' => 'server',
			'settings.cluster.customPort' => 'port',
			'settings.cluster.password' => 'password',
			'settings.cluster.passwordDescription' => 'only if needed',
			'settings.cluster.passwordStored' => ({required Object node}) => 'password on file for ${node}',
			'settings.cluster.scrollback' => 'lines kept',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} lines',
			'settings.cluster.connection' => 'connection',
			'settings.cluster.statusIdle' => 'not connected. connects when an extension needs it. tap to test.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'connecting to ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'connected to ${node} as ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'could not connect to ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'not available in the web version.',
			'settings.cluster.errors.noCall' => 'no operator callsign to log in with',
			'settings.cluster.errors.connectFailed' => 'the node could not be reached',
			'settings.cluster.errors.needsPassword' => 'the node asks for a password, and none is stored',
			'settings.cluster.errors.loginFailed' => 'the node did not accept the login',
			'settings.cluster.errors.disconnected' => 'the node closed the connection',
			'settings.cluster.errors.timeout' => 'the node did not answer',
			'settings.spotting.title' => 'spotting',
			'settings.spotting.respotInterval' => 'auto re-spot every',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'auto re-spot by default',
			'settings.spotting.autoRespotByDefaultOn' => 'enable auto re-spot after any spot is posted',
			'settings.spotting.autoRespotByDefaultOff' => 'require user action to enable auto re-spotting',
			'settings.spotting.pulseBeforeRespot' => 'pulse before each auto re-spot',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'the spotting chip pulses blue for the ${seconds} seconds before each re-spot',
			'settings.spotting.pulseBeforeRespotOff' => 'no pulsing before an auto re-spot',
			'settings.radio.title' => 'cat control',
			'settings.radio.loggingAndCat' => 'logging & cat',
			'settings.radio.tuningSection' => 'tuning',
			'settings.radio.keyerSection' => 'keyer',
			'settings.radio.servicesSection' => 'services',
			'settings.radio.stationConfigurationSection' => 'station configuration',
			'settings.radio.moreSettings' => 'more station configuration settings',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'khz',
			'settings.radio.units.kHzPerSecond' => 'khz/s',
			'settings.radio.units.hz' => 'hz',
			'settings.radio.pttKey.title' => 'control ptt with [\']',
			'settings.radio.pttKey.descriptionOn' => 'in phone modes, [\'] keys the radio and [\'] again unkeys it. it unkeys by itself after a minute.',
			'settings.radio.pttKey.descriptionOff' => 'the [\'] key does not key the radio.',
			'settings.radio.pttKey.pill' => 'tx',
			'settings.radio.pttKey.transmitting' => 'transmitting',
			'settings.radio.smartVfoSnap.title' => 'smart vfo snap',
			'settings.radio.smartVfoSnap.descriptionOn' => 'after you stop turning the dial, rounding the frequency to a sensible step. voice modes only.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'staying exactly where you tuned it.',
			'settings.radio.snapDebounce.title' => 'smart snap: settle delay',
			'settings.radio.snapDebounce.description' => 'how long the dial has to stop before the frequency is rounded. shorter feels immediate; longer leaves room for a slow move.',
			'settings.radio.snapLongMove.title' => 'smart snap: long move',
			'settings.radio.snapLongMove.description' => 'move at least this far and the frequency rounds to a whole khz, however slowly you finished.',
			'settings.radio.snapMinMove.title' => 'smart snap: smallest move',
			'settings.radio.snapMinMove.description' => 'move less than this and the frequency is not rounded, so fine tuning is left alone.',
			'settings.radio.snapMinSpeed.title' => 'smart snap: slowest move',
			'settings.radio.snapMinSpeed.description' => 'turn the dial slower than this and the frequency is not rounded, unless it was a long move.',
			'settings.radio.enterSends.pillOff' => 'esm off',
			'settings.radio.enterSends.pillRun' => 'esm run',
			'settings.radio.enterSends.pillSp' => 'esm s&p',
			'settings.radio.enterSends.field' => 'enter sends messages',
			'settings.radio.enterSends.off' => 'off',
			'settings.radio.enterSends.run' => 'run',
			'settings.radio.enterSends.sp' => 's&p',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'enter sends messages: ${state}. tap to change.',
			'settings.radio.keyerSpeed.title' => 'keyer speed',
			'settings.radio.keyerSpeed.unit' => 'wpm',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'cw keyer messages',
			'settings.radio.cwMessages.notSupported' => 'current radio does not support cw keying',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'f${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'message (${n})',
			'settings.radio.cwMessages.labelField' => 'label',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'f${n} label',
			'settings.radio.cwMessages.details' => 'details',
			'settings.radio.cwMessages.empty' => '(empty)',
			'settings.radio.cwMessages.sets' => 'message set',
			'settings.radio.cwMessages.newSet' => 'new set',
			'settings.radio.cwMessages.renameSet' => 'rename set',
			'settings.radio.cwMessages.deleteSet' => 'delete set',
			'settings.radio.cwMessages.newSetName' => 'name',
			'settings.radio.cwMessages.setDefault' => 'default',
			'settings.radio.cwMessages.setPota' => 'pota',
			'settings.radio.cwMessages.setEsm' => 'esm messages',
			'settings.radio.cwMessages.setSaved' => 'my messages',
			'settings.radio.cwMessages.repeat' => 'repeat message #1',
			'settings.radio.cwMessages.repeatOff' => 'no',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'after ${n} seconds',
			'settings.radio.cwMessages.repeatWait' => 'repeating',
			'settings.radio.cwMessages.keyboard' => 'type to send',
			'settings.radio.cwMessages.keyboardField' => 'type to send',
			'settings.radio.cwMessages.closeArea' => 'close the keyer area',
			'settings.radio.cwMessages.help' => 'help',
			'settings.radio.cwMessages.helpTitle' => 'writing cw messages',
			'settings.radio.cwMessages.helpIntro' => 'messages can use templates with the following values:',
			'settings.radio.cwMessages.helpOpCall' => 'your callsign',
			'settings.radio.cwMessages.helpQsoCall' => 'their callsign — in a // stack, the call that will be logged',
			'settings.radio.cwMessages.helpQsoFullCall' => 'their callsign, if there is a valid call; blank for a partial',
			'settings.radio.cwMessages.helpQsoPartial' => 'a partial call; blank if there is a full valid call',
			'settings.radio.cwMessages.helpQsoNextCall' => 'in a // stack, the call that will be selected for logging next, if there is a valid full call',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'in a // stack, the next partial after logging the current contact',
			'settings.radio.cwMessages.helpQsoName' => 'their first name, as typed or else from the lookup',
			'settings.radio.cwMessages.helpQsoState' => 'their state, as typed or else from the lookup',
			'settings.radio.cwMessages.helpKeyerMsg' => 'message 1 as it would be sent, inside another message. valid for messages 1 through 8',
			'settings.radio.cwMessages.helpQsoRst' => 'the report you are sending',
			'settings.radio.cwMessages.helpQsoSerial' => 'your serial number, in a contest that sends one',
			'settings.radio.cwMessages.helpPad' => 'pads with zeros to that many digits: 7 is sent as 007',
			'settings.radio.cwMessages.helpCut' => 'cut numbers, t for 0 and n for 9: 599 is sent as 5nn',
			'settings.radio.cwMessages.helpCutDigits' => 'chooses the digits to cut, in quotes — 0 is t, 1 is a, 5 is e, 9 is n',
			'settings.radio.cwMessages.helpFullExample' => 'full example:',
			'settings.radio.cwMessages.helpExample' => 'sends w1aw 5nn tt7',
			'settings.radio.cwMessages.helpEsmIntro' => 'with enter sends messages on, enter keys messages by their function key, as n1mm does. the esm messages set starts with these:',
			'settings.radio.cwMessages.helpEsmCq' => 'running, enter with the call field empty calls cq',
			'settings.radio.cwMessages.helpEsmExchange' => 'your exchange: after their call when running, after they answer in s&p',
			'settings.radio.cwMessages.helpEsmThanks' => 'thanks, once the contact has logged: its placeholders name the next contact, not this one',
			'settings.radio.cwMessages.helpEsmMyCall' => 'in s&p, your call to the station you are answering',
			'settings.radio.cwMessages.helpEsmHisCall' => 'running, their call ahead of your exchange',
			'settings.radio.cwMessages.helpEsmAgain' => 'asks again when nothing of their exchange was copied',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'suggested f3 for // stacks: tu goes out after the contact logs, so it thanks, then calls the next stacked station and sends your exchange, or asks a partial back (tu kr?); with nothing left, just tu',
			'settings.radio.voiceMessages.title' => 'phone keyer messages',
			'settings.radio.voiceMessages.notSupported' => 'current radio does not support phone messages',
			'settings.radio.voiceMessages.description' => 'this uses the radio\'s voice memories',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'm${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'voice memory (${n})',
			'settings.radio.voiceMessages.labelField' => 'label',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'voice memory ${n} label',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'empty',
			'settings.radio.voiceMessages.notMeasured' => 'unknown length',
			'settings.radio.voiceMessages.playButton' => 'play',
			'settings.radio.voiceMessages.recordButton' => 'record',
			'settings.radio.voiceMessages.stopButton' => 'stop',
			'settings.radio.voiceMessages.repeat' => 'repeat message #1',
			'settings.radio.voiceMessages.repeatOff' => 'no',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'after ${n} seconds',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} notes:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'these memories are in ${device}\'s radio. their names and lengths belong to that device.',
			'settings.radio.voiceMessages.namedOnRadio' => 'saved in the radio, where its other clients see it too.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'wait for the [rec] indicator on the radio, then hold the ptt button and record your message. end it by pressing the stop button here in the app before releasing ptt to avoid unwanted clicks.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'wait for the [rec] indicator to blink at least four times, then hold the ptt button and record your message. end it by pressing the stop button here in the app before releasing ptt to avoid unwanted clicks.',
			'settings.radio.voiceMessages.pill' => 'voice',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'play memory ${n}',
			'settings.radio.voiceMessages.stop' => 'stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'record memory ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'stop recording',
			'settings.radio.voiceMessages.playing' => 'playing…',
			'settings.radio.voiceMessages.recording' => 'recording…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'playing ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'recording ${label}',
			'settings.radio.voiceMessages.doubtful' => 'did the radio play it? it said it was idle right away.',
			'settings.radio.voiceMessages.recordOnRadio' => 'you have to record the memories on the radio itself.',
			'settings.radio.avoidZeroBeat.title' => 'avoid zero-beating on spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'with a radio connected, tuning a few hz off a cw spot, so everyone answering it isn’t calling on the same note.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'tuning exactly to the spotted frequency.',
			'settings.radio.zeroBeatRange.title' => 'zero-beat: avoidance range',
			'settings.radio.zeroBeatRange.description' => 'how far off the spotted frequency to land, either side. the offset is never near zero — that would be a zero beat again.',
			'settings.help.title' => 'help & resources',
			'settings.help.description' => 'community and support',
			'settings.help.forums' => 'ham2k forums',
			'settings.help.forumsDescription' => 'find help, give feedback, discuss ideas…',
			'settings.help.chat' => 'ham2k chat',
			'settings.help.chatDescription' => 'the discord server for our online community',
			'settings.help.youtube' => 'ham2k youtube',
			'settings.help.youtubeDescription' => 'videos and live streams',
			'settings.help.instagram' => 'ham2k instagram',
			'settings.help.instagramDescription' => 'because you cannot have too many photos…',
			'settings.help.bluesky' => 'ham2k bluesky',
			'settings.help.blueskyDescription' => 'follow us for news and updates',
			'settings.help.contact' => 'contact us',
			'settings.help.contactDescription' => 'help@ham2k.com — but try the forums or chat first!',
			'settings.exports.title' => 'exports',
			'settings.extensionSections.activities' => 'activities',
			'settings.extensionSections.hunting' => 'hunting',
			'settings.extensionSections.contests' => 'contests',
			'settings.extensionSections.lookups' => 'lookups',
			'settings.extensionSections.dashboard' => 'dashboard',
			'settings.map.title' => 'maps',
			'settings.map.style.title' => 'map style',
			'settings.map.showCallsigns.title' => 'show callsigns',
			'settings.map.showCallsigns.description' => 'each contact is a pill with its callsign, in its band\'s color',
			'settings.map.showGrayline.title' => 'show grayline',
			'settings.map.showGrayline.description' => 'shades the night side of the earth, with twilight as a gradient',
			'settings.map.styleOpts.automatic' => 'automatic',
			'settings.map.styleOpts.liberty' => 'liberty',
			'settings.map.styleOpts.bright' => 'bright',
			'settings.map.styleOpts.positron' => 'positron',
			'settings.map.styleOpts.voyager' => 'voyager',
			'settings.map.styleOpts.darkMatter' => 'dark matter',
			'settings.privacy.title' => 'privacy',
			'settings.privacy.shareAppData.title' => 'share app usage data',
			'settings.privacy.shareAppData.descriptionOn' => 'helping us improve the app by sharing usage, configuration, crash and performance data',
			'settings.privacy.shareAppData.descriptionOff' => 'keeping app usage data private.\nthe ham2k team won\'t be able to detect crashes or other issues.',
			'settings.privacy.shareOpData.title' => 'share operation data',
			'settings.privacy.shareOpData.descriptionOn' => 'sharing some operation data publicly and with other users',
			'settings.privacy.shareOpData.descriptionOff' => 'keeping operation data private',
			'settings.privacy.privacyPolicy' => 'privacy policy',
			'settings.privacy.termsOfService' => 'terms of service',
			'settings.operatorCall' => 'operator callsign',
			'settings.sync.title' => 'cloud sync',
			'settings.sync.moreSettings' => 'more sync settings',
			'settings.sync.enable' => 'enable sync',
			'settings.sync.deviceKey' => 'device key',
			'settings.peers.title' => 'peer devices',
			'settings.peers.enable' => 'connect to other devices',
			'settings.peers.enableDescription' => 'allow sharing operations, logging, cat and gps with other devices over the local network',
			'settings.peers.bleEnable' => 'connect over bluetooth',
			'settings.peers.bleDescription' => 'use bluetooth le to connect even if there is no local network',
			'settings.peers.thisDevice' => 'this device',
			'settings.peers.deviceName' => 'name',
			'settings.peers.deviceNameHint' => 'how this device is seen by other devices',
			'settings.peers.pairedDevices' => 'linked devices',
			'settings.peers.noPairedDevices' => 'no devices linked yet. turn this on, on another device on this network, to link them.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'can\'t read your linked devices: ${error}',
			'settings.peers.nearby' => 'nearby',
			'settings.peers.connected' => 'connected',
			'settings.peers.viaBluetooth' => 'via bluetooth',
			'settings.peers.connecting' => 'connecting…',
			'settings.peers.syncing' => 'syncing…',
			'settings.peers.waitingForThem' => 'waiting for the other device',
			'settings.peers.notConnected' => 'not connected',
			'settings.peers.wantsToPair' => 'wants to share this operation',
			'settings.peers.allow' => 'allow',
			'settings.peers.link' => 'link',
			'settings.peers.reject' => 'reject',
			'settings.peers.forget' => 'forget',
			'settings.peers.forgetTitle' => ({required Object name}) => 'forget ${name}?',
			'settings.peers.forgetBody' => 'it will stop syncing with this device. you can allow it again later, and contacts already logged are kept.',
			'settings.peers.pairTitle' => ({required Object name}) => 'link with ${name}',
			'settings.peers.pairBody' => 'this device is on your local network and wants to connect.',
			'settings.peers.pairBodyBle' => 'this device is nearby and wants to connect over bluetooth le.',
			'settings.peers.pairIdLabel' => 'device id',
			'settings.peers.pairWarning' => 'only link with devices you recognise. any device on this network can send a request.',
			'settings.peers.pairWarningBle' => 'only link with devices you recognise. any nearby device can send a request.',
			'settings.peers.problem' => ({required Object error}) => 'can\'t reach the local network: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'connected to ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'lost connection to ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'peer devices: ${connected} of ${linked} connected',
			'settings.peers.screenEnable' => 'share screens and windows',
			'settings.peers.screenDescription' => 'allow other devices to show screens or windows from this computer',
			'settings.peers.screenSources' => 'screens and windows',
			'settings.peers.screenRefresh' => 'refresh the list',
			'settings.peers.screenUnsupportedPlatform' => 'this device can\'t share its screen. macos can; every device can show one shared by another.',
			'settings.peers.screenUnsupportedVersion' => 'sharing a screen needs macos 12.3 or later. this device can still show a screen shared by another.',
			'settings.peers.screenNeedsPermission' => 'macos needs your permission to record the screen before this app can share one.',
			'settings.peers.screenGrantPermission' => 'ask for permission',
			'settings.peers.screenRelaunchAfterGranting' => 'allow it in system settings under privacy & security → screen recording, then quit and reopen this app — macos only tells an app about the change on its next launch.',
			'settings.peers.screenProblem' => ({required Object error}) => 'screen sharing: ${error}',
			'settings.peers.screenChooseTitle' => 'choose what to share',
			'settings.peers.screenChooseButton' => 'choose what to share…',
			'settings.peers.screenTabScreens' => 'screens',
			'settings.peers.screenTabApps' => 'apps',
			'settings.peers.screenTabWindows' => 'windows',
			'settings.peers.screenTabEmpty' => 'nothing of this kind was found.',
			'settings.peers.screenSharedSummaryNone' => 'nothing chosen yet.',
			'settings.peers.screenThisDevice' => 'this device',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'shown on ${devices}',
			'settings.peers.screenSharedToNobody' => 'not being shown',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'stop sharing ${name}',
			'settings.developerMode' => 'developer mode',
			'settings.syncPanel.configuration' => 'sync configuration',
			'settings.syncPanel.enableTitle' => 'sync with ham2k log filer',
			'settings.syncPanel.enabledDescription' => 'backing up and syncing your log across devices',
			'settings.syncPanel.disabledDescription' => 'off — staying on this device only',
			'settings.syncPanel.syncing' => 'syncing',
			'settings.syncPanel.account' => 'account',
			'settings.syncPanel.refresh' => 'refresh',
			'settings.syncPanel.switchAccounts' => 'switch accounts',
			'settings.syncPanel.switchAccountsDescription' => 'link this device to another account with a qr code or email',
			'settings.syncPanel.connectionRequests' => 'connection requests',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'a device is waiting to join this account', other: '${n} devices are waiting to join this account', ), 
			'settings.syncPanel.accountEmailTitle' => 'account email',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'confirmation sent to ${email}. open the link there to finish the change.',
			'settings.syncPanel.resendConfirmation' => 'resend confirmation email',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'waiting on ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'sent again to ${email}.',
			'settings.syncPanel.deviceLinked' => 'that device is now linked to this account.',
			'settings.syncPanel.checking' => 'checking…',
			'settings.syncPanel.notLinked' => 'not linked yet',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'replace local data?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${n} operation', other: '${n} operations', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${n} qso', other: '${n} qsos', ), 
			'settings.syncPanel.counts' => 'synced data',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'this device: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'waiting to upload: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'this device: checking…',
			'settings.syncPanel.countsServerChecking' => 'server: checking…',
			'settings.syncPanel.countsServerUnavailable' => 'server: not available',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'this backs up and clears ${operations} and ${qsos} from this device, then downloads the account\'s data instead. the backup stays in this device\'s database.',
			'settings.syncPanel.replace' => 'replace',
			'settings.syncPanel.pendingBannerTitle' => 'new ham2k log filer account detected',
			'settings.syncPanel.pendingBannerBody' => 'keep this device\'s existing operations and qsos and merge them into the account, or replace them with the account\'s data (a backup stays on this device either way).',
			'settings.syncPanel.combine' => 'combine',
			'settings.syncPanel.authIssueTitle' => 'sync can\'t connect',
			'settings.syncPanel.authIssueText' => 'ham2k log filer keeps rejecting this device. check your callsign in sync settings.',
			'settings.syncPanel.openSettings' => 'open sync settings',
			'settings.accounts.title' => 'accounts, services & data sources',
			'settings.accounts.none' => 'no active extensions with accounts',
			'settings.accounts.notConfigured' => 'not configured',
			'settings.accounts.connected' => 'connected',
			'settings.accounts.cancelLogin' => 'cancel sign-in',
			'settings.accounts.openInBrowser' => 'open in browser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'logged in as ${identity}',
			'settings.accounts.pressSaveToKeep' => 'press save to keep this account connected.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'connected to ${label}',
			'settings.accounts.connect' => 'connect',
			'settings.accounts.disconnect' => 'disconnect',
			'settings.accounts.connectedAs' => 'connected as',
			'settings.accounts.test' => 'test',
			'settings.accounts.saveFailed' => ({required Object error}) => 'save failed: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'login failed: ${error}',
			'settings.accounts.lookupFailed' => 'accounts are unavailable right now — try again in a moment',
			'settings.accounts.browserLoginTitle' => 'finish signing in with your web browser',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'when you are done, the browser will try to open a link starting with "${prefix}". your desktop most likely has nothing registered to open it, so copy that link (from the address bar, or from the error page the browser shows) and paste it here.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'ham2k logger could not open your browser. copy the login link below and open it yourself, then copy the link it sends you to (it starts with "${prefix}") and paste that here.',
			'settings.accounts.copyLoginLink' => 'copy login link',
			'settings.accounts.pastedLinkLabel' => 'paste the link here',
			'settings.accounts.finishLogin' => 'finish login',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'that is not the login link — it should start with "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'that link belongs to a different login attempt. close this page and connect again.',
			'settings.accounts.pastedLinkNoCode' => 'that link has no login code. finish signing in first, then copy the link it sends you to.',
			'settings.accounts.pastedLinkMalformed' => 'that link looks cut off. copy the whole thing and paste it again.',
			'settings.accounts.relayLoginWaiting' => 'waiting for you to finish signing in — this will continue automatically once you do.',
			'settings.accounts.loginNoResponse' => 'this device hasn\'t heard back from the sign-in yet. if you already finished in your browser, cancel and try connecting again.',
			'settings.accounts.relayLoginNotOpened' => 'ham2k logger could not open your browser automatically. use the button below to open the login page yourself.',
			'settings.accounts.relayLoginUnavailable' => 'couldn\'t reach the sync server needed to complete this login. check your connection and try again.',
			'settings.accounts.loginIncompleteResponse' => 'that login attempt didn\'t complete correctly. please try connecting again.',
			'settings.accounts.noKeyringTitle' => 'account logins can’t be saved',
			'settings.accounts.noKeyringText' => 'ham2k logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. install and start **gnome-keyring**, **kwallet** or **keepassxc**, or unlock the keyring you already have, then restart. logging, exports and data files are unaffected; log sync stays off while this lasts.',
			'settings.accounts.noKeyringInline' => 'logins can’t be saved: this computer’s keyring can’t be reached. install and start gnome-keyring, kwallet or keepassxc, or unlock the one you have.',
			'settings.accounts.noSecureStorageInline' => 'logins can’t be saved: this computer’s secure storage can’t be reached.',
			'settings.station.title' => 'station configuration & cat control',
			'settings.station.none' => 'no equipment configured',
			'settings.station.add' => 'add',
			'settings.station.addTitle' => 'add equipment',
			'settings.station.searchHint' => 'search equipment',
			'settings.station.noMatches' => 'no equipment matches',
			'settings.station.detectedEquipment' => 'detected equipment',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'can\'t listen for radios: ${error}',
			'settings.station.edit' => 'edit equipment',
			'settings.station.name' => 'name',
			'settings.station.nameDescription' => 'what you call it — "left radio". optional.',
			'settings.station.transport' => 'connection',
			'settings.station.host' => 'address',
			'settings.station.hostDescription' => 'the radio\'s hostname or ip address on your network.',
			'settings.station.port' => 'port',
			'settings.station.hostRequired' => 'an address is required',
			_ => null,
		} ?? switch (path) {
			'settings.station.portInvalid' => 'port must be between 1 and 65535',
			'settings.station.connect' => 'connect',
			'settings.station.disconnect' => 'disconnect',
			'settings.station.remove' => 'remove',
			'settings.station.removeTitle' => ({required Object name}) => 'remove ${name}?',
			'settings.station.removeMessage' => 'this only removes it from the app. the equipment\'s settings stay as they are.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'unrecognized equipment type "${typeKey}"',
			'settings.station.report' => 'report',
			'settings.station.reportTitle' => 'report this radio',
			'settings.station.reportIntro' => 'tell us what radio this really is and how it went. your report becomes a card the ham2k team reads, and what you write about getting it working may end up helping the next operator with the same rig.',
			'settings.station.reportManufacturer' => 'manufacturer',
			'settings.station.reportManufacturerDescription' => 'who makes it — icom, yaesu, kenwood, elecraft…',
			'settings.station.reportManufacturerRequired' => 'a manufacturer is required',
			'settings.station.reportModel' => 'model',
			'settings.station.reportModelDescription' => 'the model, as the radio itself calls it — "ic-7300", "ft-991a".',
			'settings.station.reportModelRequired' => 'a model is required',
			'settings.station.reportOutcome' => 'how did it go?',
			'settings.station.reportOutcomeWorks' => 'worked well',
			'settings.station.reportOutcomeIssues' => 'worked, with issues',
			'settings.station.reportOutcomeFails' => 'didn\'t work at all',
			'settings.station.reportOutcomeRequired' => 'please tell us how it went',
			'settings.station.reportComments' => 'comments',
			'settings.station.reportCommentsPlaceholder' => 'what worked, what didn\'t, anything that surprised you.',
			'settings.station.reportHints' => 'troubleshooting hints',
			'settings.station.reportHintsPlaceholder' => 'want to suggest some troubleshooting hints for other users?',
			'settings.station.reportSend' => 'send report',
			'settings.station.reportSending' => 'sending your report…',
			'settings.station.reportSent' => ({required Object ref}) => 'thanks — your report was filed as ${ref}.',
			'settings.station.reportSentNoRef' => 'thanks — your report was sent.',
			'settings.station.reportFailed' => ({required Object error}) => 'the report wasn\'t sent: ${error}',
			'settings.station.troubleshootingNotes' => 'troubleshooting notes',
			'settings.station.mainVfo' => 'main vfo',
			'settings.station.useAsMainVfo' => 'use as main vfo',
			'settings.station.serialPort' => 'serial port',
			'settings.station.serialPortDescription' => 'the port the radio\'s cat interface appears on.',
			'settings.station.serialPortNone' => 'no serial ports found',
			'settings.station.serialPortRequired' => 'choose a serial port',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} of ${total}',
			'settings.station.serialPortSuggested' => 'suggested',
			'settings.station.serialPortJustNow' => 'recently connected',
			'settings.station.serialDeviceRequest' => 'add a usb device…',
			'settings.station.bleDevice' => 'bluetooth le device',
			'settings.station.bleDeviceDescription' => 'the serial bridge your radio is connected through, such as a link500mp in its ios mode or a ble serial adapter.',
			'settings.station.bleScan' => 'scan for bluetooth le devices…',
			'settings.station.bleScanNoneFound' => 'no bluetooth le devices found. check that the bridge is on, nearby, and in its bluetooth le (ios) mode.',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'the bluetooth le scan could not run: ${reason}',
			'settings.station.bleOff' => 'bluetooth is turned off.',
			'settings.station.bleDenied' => 'bluetooth permission was not granted. allow it in system settings, then try again.',
			'settings.station.bleUnsupported' => 'this device has no bluetooth le.',
			'settings.station.bleStarting' => 'bluetooth is still starting up. try again in a moment.',
			'settings.station.bleConnectFailed' => 'cannot reach the bluetooth le device. check that it\'s on, nearby, and not connected to another app.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'this bluetooth le device has no serial service the app recognizes. please report it with its services: ${services}',
			'settings.station.baudRate' => 'speed (baud)',
			'settings.station.baudRateDescription' => 'must match the radio\'s cat menu. with a mismatch, the radio sends back garbage and no error.',
			'settings.station.serialRtsHigh' => 'hold rts high',
			'settings.station.serialRtsHighDescription' => 'only for a radio that waits for rts before responding, such as a yaesu with cat rts turned on. on a digirig, signalink and most home-made cables rts is ptt, and holding it high transmits.',
			'settings.station.serialDtrHigh' => 'hold dtr high',
			'settings.station.serialDtrHighDescription' => 'only for a cat interface that draws its power from dtr, such as some rs-232 cables for the ft-817. on many cables dtr keys cw or ptt, and holding it high transmits.',
			'settings.station.civAddress' => 'radio ci-v address',
			'settings.station.civAddressDescription' => 'hex, as shown in the radio\'s ci-v menu. the ic-705 ships as a4.',
			'settings.station.civAddressInvalid' => 'a ci-v address is two hex digits, 01 to ff',
			'settings.station.flexSlice' => 'slice',
			'settings.station.flexSliceDescription' => 'which of the radio\'s slices this connection reads from and tunes.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'slice ${letter}',
			'settings.station.flexSliceInvalid' => 'pick one of the radio\'s slices, a through h',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'slice ${letter} is not in use on this radio — pick another slice, or create it in smartsdr',
			'settings.station.channelNotInUse' => 'not in use',
			'settings.station.channelHeldByUnknown' => 'in use by another program',
			'settings.station.flexNoSlices' => 'this radio has not reported any slices — check that smartsdr is running and that this client may subscribe',
			'settings.station.spectrumUnsupported' => 'this radio sends no spectrum over cat',
			'settings.station.spectrumRequiresBaud' => 'requires cat at 115200 bps',
			'settings.station.spectrumNoRadio' => 'no radio connected',
			'settings.station.spectrumWaiting' => 'waiting for the radio\'s spectrum…',
			'settings.station.spectrumUnavailable' => 'spectrum display is not available',
			'settings.station.spectrumNoDaxChannel' => 'every dax iq channel on this radio is in use',
			'settings.station.spectrumNoPanadapter' => 'this slice has no panadapter on the radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'the radio refused a dax iq stream (error ${code})',
			'settings.station.spectrumNoUdp' => 'the radio\'s spectrum data cannot reach this device',
			'settings.station.spectrumK4Unavailable' => 'cannot receive the k4’s lan spectrum. retrying…',
			'settings.station.spectrumK4RemoteUnavailable' => 'cannot receive the k4’s remote spectrum',
			'settings.station.spectrumScopeRefused' => 'the radio refused its scope commands',
			'settings.station.spectrumOutOfRange' => 'the radio\'s scope is set outside the range it can show',
			'settings.station.spectrumBandUnsupported' => 'the radio\'s scope cannot be shown on this band',
			'settings.station.spectrumSdrNoRadio' => 'waiting for the linked radio\'s frequency…',
			'settings.station.spectrumSdrNotConnected' => 'the sdr is not connected',
			'settings.station.spectrumSdrNoIf' => 'set the radio\'s if frequency in this sdr\'s settings',
			'settings.station.sdrRadio' => 'shows the spectrum for',
			'settings.station.sdrRadioDescription' => 'a spectrum display on this radio draws from this receiver instead of the radio\'s own scope.',
			'settings.station.sdrRadioMain' => 'the main radio',
			'settings.station.sdrTuning' => 'antenna input',
			'settings.station.sdrTuningDescription' => 'where the receiver\'s signal comes from. on its own antenna it tunes itself to follow the radio; on the radio\'s if output it stays on the if.',
			'settings.station.sdrTuningIndependent' => 'its own antenna',
			'settings.station.sdrTuningIfTap' => 'the radio\'s if output',
			'settings.station.sdrIfHz' => 'if frequency (hz)',
			'settings.station.sdrIfHzDescription' => 'for an if output only: the frequency the radio\'s dial sits at on its if, such as 68330000 on an ft-817.',
			'settings.station.sdrIfInverted' => 'if is inverted',
			'settings.station.sdrGainDb' => 'gain (db)',
			'settings.station.sdrGainDbDescription' => 'leave blank for the receiver\'s automatic gain.',
			'settings.station.sdrOffsetHz' => 'frequency offset (hz)',
			'settings.station.sdrOffsetHzDescription' => 'added to every frequency sent to the receiver, for an upconverter: 125000000 for a ham it up.',
			'settings.station.sdrPpm' => 'frequency correction (ppm)',
			'settings.station.rtlDirectSampling' => 'direct sampling',
			'settings.station.rtlDirectSamplingDescription' => 'for hf on an rtl-sdr v3 without an upconverter. an rtl-sdr v4 reaches hf without it.',
			'settings.station.rtlDirectSamplingOff' => 'off',
			'settings.station.rtlDirectSamplingI' => 'i branch',
			'settings.station.rtlDirectSamplingQ' => 'q branch',
			'settings.station.rtlTcpNotAServer' => 'this is not an rtl_tcp server',
			'settings.station.rtlTcpNotes' => 'this connects to an **rtl_tcp server you run yourself** on the computer the dongle is plugged into.\n\n- **start it** with `rtl_tcp -a 0.0.0.0` so other machines can reach it; on the same machine, `rtl_tcp` alone will do.\n- **port** is 1234 unless you started it with `-p`.\n- **one program at a time:** rtl_tcp serves a single client. the app connects only while a spectrum display is showing, and lets go a few seconds after it closes.\n- **on android**, the *sdr driver* app runs the same server on the phone.',
			'settings.station.rspTcpNotes' => 'this connects to an **rsp_tcp server you run yourself** on the computer the rsp is plugged into, with sdrplay\'s api installed there.\n\n- **start it** with `rsp_tcp -a 0.0.0.0`.\n- **port** is 1234 unless you started it with `-p`.\n- **one program at a time:** the server takes a single client. the app connects only while a spectrum display is showing.',
			'settings.station.n3fjpNoRig' => 'n3fjp has no radio interface set up, so this follows what is typed into n3fjp, not a radio',
			'settings.station.winkeyerKeyPort' => 'key output',
			'settings.station.winkeyerKeyPortDescription' => 'which of the keyer\'s two output jacks your radio is plugged into.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'port ${n}',
			'settings.station.winkeyerPtt' => 'use the keyer\'s ptt',
			'settings.station.winkeyerPttDescription' => 'key the ptt line on the same jack, for an amplifier or a radio that needs it. leave off for a radio keyed on its key jack.',
			'settings.station.winkeyerNoAnswer' => 'no winkeyer responded on this port',
			'settings.station.winkeyerStoppedAnswering' => 'the winkeyer stopped responding while sending; the message was dropped',
			'settings.station.icomControlPort' => 'control port (udp)',
			'settings.station.icomControlPortDescription' => 'the radio\'s control port (udp) — 50001 unless changed in its network settings, or forwarded to another.',
			'settings.station.icomSerialPort' => 'serial port (udp)',
			'settings.station.icomSerialPortDescription' => 'the radio\'s serial port (udp) — 50002 unless changed in its network settings, or forwarded to another.',
			'settings.station.icomPortsDiffer' => 'the control and serial ports must differ',
			'settings.station.radioUser' => 'radio username',
			'settings.station.radioPass' => 'radio password',
			'settings.station.radioLoginDescription' => 'the radio\'s network → remote login, not your wifi password.',
			'settings.station.radioUserRequired' => 'the radio\'s remote-control username is required',
			'settings.station.connectFailedBusy' => 'device is in use',
			'settings.station.connectFailedDenied' => 'access denied',
			'settings.station.connectFailedDevice' => 'device not found',
			'settings.station.connectFailedLines' => 'rts/dtr could not be held as set, so the port was closed. another program may have left hardware handshaking on — unplug and replug the cable.',
			'settings.station.connectFailedNetwork' => 'cannot find the radio over the network. check its address and that it\'s powered on and reachable.',
			'settings.station.connectFailedTimeout' => 'the radio didn\'t respond in time. check it\'s powered on and reachable.',
			'settings.station.models.flexRadio' => 'flexradio (smartsdr)',
			'settings.station.models.ft891' => 'yaesu ft-891',
			'settings.station.models.ft991a' => 'yaesu ft-991/a',
			'settings.station.models.ft710' => 'yaesu ft-710',
			'settings.station.models.ftdx10' => 'yaesu ftdx10',
			'settings.station.models.ftx1' => 'yaesu ftx-1',
			'settings.station.models.ft817' => 'yaesu ft-817 / ft-818',
			'settings.station.models.ft857' => 'yaesu ft-857',
			'settings.station.models.ft897' => 'yaesu ft-897',
			'settings.station.models.ft450' => 'yaesu ft-450 / ft-450d',
			'settings.station.models.q900' => 'guohetec q900',
			'settings.station.models.tenTecEagle' => 'ten-tec eagle (599)',
			'settings.station.models.tenTecOrion' => 'ten-tec orion (565)',
			'settings.station.models.tenTecOrionII' => 'ten-tec orion ii (566)',
			'settings.station.models.sotacat' => 'sotacat (elecraft kx2/kx3)',
			'settings.station.models.yaesuGeneric' => 'yaesu - generic',
			'settings.station.models.icomGeneric' => 'icom - generic',
			'settings.station.models.kenwoodGeneric' => 'kenwood - generic',
			'settings.station.models.ts590sg' => 'kenwood ts-590sg',
			'settings.station.models.ts480' => 'kenwood ts-480',
			'settings.station.models.qmx' => 'qrp labs qmx',
			'settings.station.models.fx4cr' => 'bg2fx fx-4cr',
			'settings.station.models.tx500' => 'lab599 tx-500',
			'settings.station.models.tx500mp' => 'lab599 tx-500mp',
			'settings.station.models.qcx' => 'qrp labs qcx',
			'settings.station.models.elecraftGeneric' => 'elecraft - generic',
			'settings.station.models.kx2' => 'elecraft kx2',
			'settings.station.models.kx3' => 'elecraft kx3',
			'settings.station.models.k4' => 'elecraft k4',
			'settings.station.models.ic705' => 'icom ic-705',
			'settings.station.models.ic7300' => 'icom ic-7300',
			'settings.station.models.ic7300mk2' => 'icom ic-7300 mk2',
			'settings.station.models.ic706mkiig' => 'icom ic-706mkiig',
			'settings.station.models.ic7100' => 'icom ic-7100',
			'settings.station.models.ic7610' => 'icom ic-7610',
			'settings.station.models.ic7760' => 'icom ic-7760',
			'settings.station.models.ic9700' => 'icom ic-9700',
			'settings.station.models.ic905' => 'icom ic-905',
			'settings.station.models.ic7850' => 'icom ic-7850',
			'settings.station.models.ic7851' => 'icom ic-7851',
			'settings.station.models.x6100' => 'xiegu x6100',
			'settings.station.models.g90' => 'xiegu g90',
			'settings.station.models.rigctld' => 'radio controlled via rigctld',
			'settings.station.models.rigctldNodeName' => 'my radio (via rigctld)',
			'settings.station.models.flrig' => 'radio controlled via flrig',
			'settings.station.models.flrigNodeName' => 'my radio (via flrig)',
			'settings.station.models.hrd' => 'radio controlled via ham radio deluxe®',
			'settings.station.models.hrdNodeName' => 'my radio (via hrd)',
			'settings.station.models.n3fjp' => 'radio controlled via n3fjp',
			'settings.station.models.n3fjpNodeName' => 'my radio (via n3fjp)',
			'settings.station.models.commander' => 'radio controlled via dxlab commander',
			'settings.station.models.commanderNodeName' => 'my radio (via commander)',
			'settings.station.models.antenna' => 'antenna',
			'settings.station.models.key' => 'cw key',
			'settings.station.models.winkeyer' => 'winkeyer',
			'settings.station.models.placeholderRadio' => 'generic radio (placeholder)',
			'settings.station.models.placeholderRadioNodeName' => 'my radio',
			'settings.station.models.antennaGenius' => '4o3a antenna genius',
			'settings.station.models.sierraCoax' => 'sierra radio cx-1 coax switch',
			'settings.station.models.rtlSdr' => 'rtl-sdr',
			'settings.station.models.nesdr' => 'nooelec nesdr',
			'settings.station.models.sdrplay' => 'sdrplay rsp',
			'settings.station.transports.network' => 'network/wifi',
			'settings.station.transports.secureNetwork' => 'secure network/wifi',
			'settings.station.transports.usbSerial' => 'usb serial',
			'settings.station.transports.wifi' => 'network/wifi',
			'settings.station.transports.bluetoothSerial' => 'bluetooth serial',
			'settings.station.transports.bleSerial' => 'bluetooth le',
			'settings.station.transports.placeholder' => 'placeholder',
			'settings.station.troubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.ft891Troubleshooting' => 'the radio is receiving commands but not responding. almost always one of:\n\n- **cat rts off at the radio, or hold rts high on.** with **cat rts** on (ft-891 menu **05-08**), the radio stays silent while rts is low — it may answer once as the port opens, then nothing. picking the radio\'s own usb port turns on **hold rts high** under advanced settings. on a digirig, signalink or most home-brew cables rts is ptt, and holding it high keys your transmitter: turn cat rts off at the radio instead.\n- **speed must match** the radio\'s cat rate (menu **05-06**). with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.yaesuBinaryTroubleshooting' => 'this radio speaks yaesu\'s older five-byte cat, and it does not respond at all when something is off. almost always one of:\n\n- **the cable must convert levels.** the cat jack on the back is not rs-232 and not usb; it needs a ct-62 or an equivalent adapter. a plain audio or data cable won\'t work for cat.\n- **speed must match** the radio\'s cat rate menu (**#14** on an ft-817, **#19** on an ft-857 or ft-897). with a mismatch, the radio sends nothing back, and never an error.\n- **never let anything raise rts or dtr on this port.** on most cables for these radios those lines are ptt and keying. an older interface powered from dtr is the exception: turn on **hold dtr high** under advanced settings for that one.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis driver was written from yaesu\'s published cat chart and has not been run against one of these radios. if it half-works, that is worth reporting.',
			'settings.station.tenTecTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.tenTecEagleTroubleshooting' => '- **the usb-b port on the back is the cat link.** the radio shows up as a usb serial port; on windows it needs ten-tec\'s usb to uart driver, which appears in device manager as "usb to uart (comx)".\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open, and so does ten-tec\'s firmware updater.\n- **setting the filter width from the app takes it away from the bw knob** until the radio is switched off and on again. that is how the radio works.\n\nthis driver was written from ten-tec\'s programmer\'s reference guide. if it half-works, that is worth reporting, with the firmware version from the radio\'s menu.',
			'settings.station.tenTecOrionTroubleshooting' => '- **use a straight-through db-9 serial cable** to the serial data port, not a null-modem one.\n- **this entry holds rts high**, because the orion uses rts and cts as its handshake. on an interface that keys ptt from rts, such as a digirig, turn off hold rts high under advanced settings, or the radio transmits as soon as the app connects.\n- **cw from the app needs the radio\'s internal keyer on.** with it off, the radio ignores what the app sends.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis driver was written from ten-tec\'s programmer\'s reference guide and has not been run against an orion. if it half-works, that is worth reporting, with the firmware version from the radio\'s menu.',
			'settings.station.tenTecNoCw' => 'this radio\'s firmware does not take cw from the app. ten-tec added it in orion firmware 1.366.',
			'settings.station.tenTecKeyerOff' => 'the radio\'s internal keyer is off, so it ignores cw sent from the app. turn the keyer on in the radio\'s menu.',
			'settings.station.guohetecTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.guohetecTroubleshooting' => 'the q900 has two cat protocols, and this entry uses its native one rather than the ft-817 imitation. pick **guohetec q900** here, not an ft-817 — the imitation supports fewer commands, and the radio does not say which one it is using.\n\n- **the usb-c cable is the cat link**, and it connects the sound card too. speed does not matter on it; the port ignores whatever it is set to.\n- **never let anything raise rts or dtr on this port.** on a serial cable those lines are ptt and keying.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **a second-generation radio behaves differently** from a first. long press menu, then about: hw 2.0 is the second generation.\n\nthis driver was written from the manufacturer\'s published protocol and has not been run against one of these radios. if it half-works, that is worth reporting.',
			'settings.station.yaesuTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.yaesuTroubleshooting' => 'the radio is receiving commands but not responding. almost always one of:\n\n- **cat rts must be off at the radio.** with it on, the radio waits for a handshake line the app keeps low. on a digirig, signalink or most home-brew cables that same line is ptt, so raising it would key your transmitter. on the radio\'s own usb port, **hold rts high** under advanced settings is the alternative. where that setting lives differs by model (menu **05-08** on an ft-891).\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **modes follow the ft-891\'s table.** most of the yaesu line matches it, but a radio that numbers its modes differently will show and set the wrong one for those. the frequency is unaffected.',
			'settings.station.yaesuRs232Troubleshooting' => 'the radio is receiving commands but not responding. almost always one of:\n\n- **the cat jack is rs-232.** it needs a usb-to-serial adapter and a straight-through db-9 cable — a null-modem cable swaps the lines, and the radio never hears a thing.\n- **cat rts must be off at the radio.** with it on, the radio waits for a handshake line the app keeps low unless **hold rts high** is on under advanced settings.\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\nthis entry was written from published cat documentation and has not been run against one of these radios. if it half-works, that is worth reporting.',
			'settings.station.yaesuUsbTroubleshooting' => 'the radio is receiving commands but not responding. almost always one of:\n\n- **use the first of the radio\'s two usb ports.** cat is normally on the first (the **enhanced** com port on windows); the second (**standard**) is for ptt and keying. the picker points at the first wherever it can tell the two apart.\n- **cat rts off at the radio, or hold rts high on.** with the radio\'s **cat rts** menu on, it stays silent while rts is low — it may answer once as the port opens, then nothing. picking the radio\'s own usb port turns on **hold rts high** under advanced settings. on a digirig, signalink or most home-brew cables rts is ptt, and holding it high keys your transmitter: turn cat rts off at the radio instead.\n- **speed must match** the radio\'s cat rate menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.',
			'settings.station.k4SerialNotes' => 'connect the k4’s rear usb-b (pc) socket. either usb-pc1 or usb-pc2 works for cat; choose an unused port and match its serial usb-pcn: baud rate setting on the radio. halo prefills 38400; change it if needed. another application must use the other port or ethernet.\n\nthis connection controls the radio and its keyers; it does not send audio to halo.',
			'settings.station.k4TcpNotes' => 'connect the k4’s ethernet socket to your local network. enter its hostname or ip address and cat port 9200. halo uses the same host on fixed port 9201 when a panadapter or waterfall is visible; changing the cat port does not change the spectrum port.\n\nthe spectrum shows the main receiver. its zoom, reference adjustment and speed controls affect only halo’s display. audio streaming is not supported.',
			'settings.station.k4PowerTimeout' => 'k4 power was not changed because the radio did not confirm its output range. try again.',
			'settings.station.k4RemoteNotes' => 'enable remote access on your k4 and enter its network password. main and sub share one encrypted connection for radio control and spectrum. the default port is 9204; enter your forwarded port when connecting remotely.\n\naudio playback and microphone streaming are not supported.',
			'settings.station.k4Receiver' => 'receiver',
			'settings.station.k4ReceiverMain' => 'main',
			'settings.station.k4ReceiverSub' => 'sub',
			'settings.station.k4ReceiverInvalid' => 'choose main or sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'that receiver is already configured for this k4',
			'settings.station.k4SubReceiverOff' => 'the k4 sub receiver is off',
			'settings.station.k4RemotePasswordRequired' => 'enter the k4’s network password to connect securely.',
			'settings.station.k4RemoteHandshakeFailed' => 'the k4 could not establish a secure connection. check its network password and remote access settings.',
			'settings.station.k4RemoteUnreachable' => 'the k4’s secure connection could not be reached. check its address, port and remote access settings.',
			'settings.station.k4PowerRange' => 'k4 power must be 0.1–110 w, or 0.0001–0.01 w when the transverter milliwatt output is active.',
			'settings.station.elecraftTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.elecraftTroubleshooting' => 'elecraft rigs speak kenwood cat, and a kx2 and a kx3 have both been run this way — vfo in both directions, mode switching and cw zero-beat all working.\n\nif the radio does not respond, almost always one of:\n\n- **speed must match** the rate set under **rs232** in the radio\'s menu. 38400 is what these ship on. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n\n**if the frequency is right but the mode is wrong**, tell us. the kx2 and kx3 entries read the mode from a position in the radio\'s status reply that we have pinned from the rigs we have seen, and a firmware that puts it elsewhere is something only a report reaches us as.\n\nthe k3 has not been reported either way, so please say what happens if you run one. a k4 has its own entry.',
			'settings.station.lab599TroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.lab599Troubleshooting' => 'the tx-500 line speaks kenwood cat. written from published references rather than tested on the radio, so please report what happens either way.\n\n- **speed must match** the radio\'s cat setting, 9600 unless you changed it. with a mismatch the radio sends back garbage or nothing, and never an error.\n- **pick the cat protocol on the radio.** ts-2000 covers frequency and mode. lab599 also lets the app switch the radio to dig.\n- **through a link500mp**, press and hold the vfo knob for about three seconds to hand cat control to the interface.\n- **over bluetooth on a computer**, the link500mp pairs as two serial ports and only one carries cat. if the radio stays silent, pick the other.\n- **over bluetooth le**, as on an iphone or ipad, switch the link500mp to its ios mode first. in its other modes it does not show up in a scan.',
			'settings.station.kenwoodTroubleshootingTitle' => 'if the radio connects but shows no frequency',
			'settings.station.kenwoodTroubleshooting' => 'this driver is proven against kenwood\'s ts-590sg and ts-480, qrp labs\' qmx and qcx-mini, and elecraft\'s kx2 and kx3. the rest of the line is written from published cat references, so please report what happens either way.\n\nif the radio does not respond, almost always one of:\n\n- **speed must match** the radio\'s cat menu. with a mismatch, the radio sends back garbage or nothing, and never an error.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.\n- **some rigs need cat enabled** in the menu before they respond at all.\n\n**several sdr front-ends speak this same protocol**, so this entry is worth trying for those too; elecraft rigs are listed separately, under elecraft. if the frequency is right but the mode is wrong or missing, that is the one part that differs across the line — the app works it out from the radio and falls back to asking directly, so the mode may simply lag.',
			'settings.station.statusConnected' => 'connected',
			'settings.station.statusLost' => 'disconnected',
			'settings.station.notConfigured' => 'not configured',
			'settings.station.currentConfiguration' => 'current configuration',
			'settings.station.currentTransceiver' => 'current transceiver',
			'settings.station.radioMode' => 'radio mode',
			'settings.station.keyerNotSupported' => 'not supported by current radio',
			'settings.station.catControlPreferences' => 'cat control preferences',
			'settings.station.chooseTransceiver' => 'choose transceiver',
			'settings.station.configurationSection' => 'configuration',
			'settings.station.noTransceiverSelected' => 'no transceiver selected',
			'settings.station.makeMainVfo' => ({required Object name}) => 'use ${name} for the main vfo',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, zero: 'no transceivers', one: '${count} transceiver', other: '${count} transceivers', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} antenna', other: '${count} antennas', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} other device', other: '${count} other devices', ), 
			'settings.station.equipmentInventory' => 'equipment inventory',
			'settings.station.equipmentInUse' => 'transceiver controls',
			'settings.station.noTransceiver' => 'none',
			'settings.station.peerRadioNotAvailable' => 'not available',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'on ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} is on another device',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'this radio is connected to ${device}. its connection and settings are configured on that device.',
			'settings.station.antennaInUse' => 'antenna in use',
			'settings.station.keyInUse' => 'key in use',
			'settings.station.noneSelected' => 'none',
			'settings.station.moreSettings' => 'more settings',
			'settings.station.icomCivTroubleshootingTitle' => 'if two serial ports show up for the same radio',
			'settings.station.icomCivTroubleshooting' => 'several icom radios, the ic-705 among them, present **two** usb serial ports at once (icom calls them port a and port b), both set to ci-v by default. neither this app nor your os can tell them apart beyond that: the same usb vendor/product id just shows up twice, sometimes marked with a `#2` suffix here. **port a is usually the right one** — normally the first one your os or browser lists, and where this app can tell the two ports apart it marks that one as suggested. if commands go out and the radio never responds, try the other port next.',
			'settings.station.civAddressTroubleshootingTitle' => 'if the radio never responds',
			'settings.station.civAddressTroubleshooting' => '- **the ci-v address must match** the radio\'s menu. this entry prefills the address the model ships with, but a rig sharing a ci-v bus is exactly where that gets changed. a frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n- **speed must match** the radio\'s ci-v baud rate (on usb, ci-v usb baud rate). set the radio to the same number shown here, **not auto**. on auto some radios, the ic-7300 among them, connect and then stop responding after a minute or so.\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **the ci-v address must match** the radio\'s menu. this entry prefills the address the model ships with, but a rig sharing a ci-v bus is exactly where that gets changed. a frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n${speed}\n- **another app may hold the port**: wsjt-x, fldigi and rigctld all keep it open.',
			'settings.station.icomUsbSpeedFollows' => '- **there is no speed to set.** over usb this radio talks at whatever speed the computer uses, and this entry always uses 115200, the speed the scope needs.',
			'settings.station.ic7610UsbSpeed' => '- **set ci-v usb baud rate to 115200**, the speed this entry always uses, since the scope needs it — **not auto**. a radio set to any other speed answers with silence.',
			'settings.station.ic7300Mk2Note' => '\n- the **ic-7300 mk2** ships on address `B6`, not the `94` prefilled here — pick the ic-7300 mk2 entry instead.',
			'settings.station.ic705PortNote' => '\n- the **ic-705** presents two usb serial ports, both named after the radio. ci-v is on the **first** of them, which the picker points at wherever it can tell the two apart.',
			'settings.station.ic7760PortNote' => '\n- the **ic-7760** speaks ci-v on **port a** of the two usb serial ports it presents.',
			'settings.station.x6100PortNote' => '\n- the **x6100** speaks ci-v on its **dev** port — the second of the two serial ports it presents, and the one the picker points at.',
			'settings.station.rigctldTroubleshootingTitle' => 'if the app cannot connect',
			'settings.station.rigctldTroubleshooting' => 'this connects to a **rigctld daemon you run yourself**, not to the radio directly — hamlib\'s backend talks to the radio and supports hundreds of models.\n\n- **the daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. find your radio\'s model number with `rigctl -l`.\n- **from another machine**, start it with `-T 0.0.0.0`: by default rigctld only accepts connections from the machine it runs on.\n- **port** is 4532 unless you started the daemon with `-t`.\n- once connected, a missing frequency usually means the daemon itself cannot reach the radio. test it with `rigctl -m 2 f` on the daemon\'s machine.',
			'settings.station.flrigTroubleshootingTitle' => 'if the app cannot connect',
			'settings.station.flrigTroubleshooting' => 'this connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **port** is 12345 unless you changed it in flrig\'s configuration (config → setup → server).\n- **from another machine**, make sure flrig\'s server is reachable. it listens on all interfaces, but your firewall may not agree.\n- once connected, a missing frequency usually means flrig itself cannot reach the radio. check that flrig\'s display is following the dial.',
			'settings.station.hrdTroubleshootingTitle' => 'if the app cannot connect',
			'settings.station.hrdTroubleshooting' => 'this connects to **ham radio deluxe\'s rig control, running on your computer**, not to the radio directly — hrd talks to the radio.\n\n- **rig control must already be running** and connected to the radio.\n- **its ip server must be enabled.** rig control only talks to other programs through it.\n- **port** is 7809 unless you changed it in the ip server\'s settings.\n- **from another machine**, make sure your firewall lets the connection through.\n\nthis entry was written from published descriptions of hrd\'s protocol and has not been run against hrd. if it half-works, that is worth reporting.',
			'settings.station.n3fjpTroubleshootingTitle' => 'if the app cannot connect',
			'settings.station.n3fjpTroubleshooting' => 'this connects to **an n3fjp logging program running on your computer**, not to the radio directly — n3fjp talks to the radio.\n\n- **the program\'s api must be on**: settings → application program interface, check **tcp api enabled**.\n- **port** is 1100 unless you changed it there.\n- **n3fjp must have a radio interface set up** to follow or tune the radio. without one, it reports only what is typed into its entry window.\n- n3fjp reports band, mode and frequency only: no power, no transmit state.\n\nthis entry was written from n3fjp\'s published api and has not been run against n3fjp. if it half-works, that is worth reporting.',
			'settings.station.commanderTroubleshootingTitle' => 'if the app cannot connect',
			'settings.station.commanderTroubleshooting' => 'this connects to **dxlab commander, running on your computer**, not to the radio directly — commander talks to the radio.\n\n- **commander must already be running** and connected to the radio.\n- **its network service must be on**: the **net serv** button in the radio panel of commander\'s configuration window.\n- **port** is 52002, the third port of the block starting at net serv\'s **base port** (52000 unless you changed it).\n- **from another machine**, make sure your firewall lets the connection through.\n\nthis entry was written from commander\'s published tcp messages and has not been run against commander. if it half-works, that is worth reporting.',
			'settings.station.ic705TroubleshootingTitle' => 'if the radio never responds',
			'settings.station.ic705Troubleshooting' => 'the radio has a **single** remote-control session. when the login is ignored, something else is almost always using it.\n\n- **close any other client.** wfview or rs-ba1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **check the radio\'s network settings.** wlan must be on, the radio must be on the same network, and its remote-control (network) function must be enabled.\n- **the ports must match** the radio\'s control port and serial port (udp), or the ports forwarded to them. a wrong port is met with silence, the same as a radio that is off.\n- **power-cycle the radio\'s wlan** if it stays stuck. that reliably clears a session stuck on the radio.\n\na **wrong password is refused explicitly**, not met with silence. if you got here rather than a "rejected" message, the password is not the problem.',
			'settings.station.icomLanTroubleshooting' => 'the radio has a **single** remote-control session. when the login is ignored, something else is almost always using it.\n\n- **close any other client.** wfview, rs-ba1 or icom\'s remote utility connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **check the radio\'s network settings.** its lan port must be connected to the same network as this device, its **network control** must be on, and the username and password must be set up as a network user on the radio.\n- **the ports must match** the radio\'s control port and serial port (udp), or the ports forwarded to them. a wrong port is met with silence, the same as a radio that is off.\n- **if it connects but never answers**, the ci-v address here must match the radio\'s ci-v address menu. this entry prefills the address the model ships with.\n- **turn the radio off and on** if it stays stuck.',
			'settings.station.statusStale' => 'not responding',
			'settings.station.statusDisconnected' => 'not connected',
			'settings.station.statusConnecting' => 'connecting…',
			'settings.station.statusDisconnecting' => 'disconnecting…',
			'settings.station.statusError' => 'connection failed',
			'settings.station.currentRadioSettings' => 'current radio settings',
			'settings.station.notSupportedByThisRadio' => 'not supported by this radio',
			'settings.station.keyerRowLabel' => 'keyer',
			'settings.station.cwMessagesButton' => 'cw',
			'settings.station.voiceMessagesButton' => 'phone',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'voice keyer: ${count} memories in the radio',
			'settings.station.antennaBands' => 'bands',
			'settings.station.antennaType' => 'antenna type',
			'settings.station.antennaTypeRequired' => 'choose an antenna type',
			'settings.station.antennaTypes.dipole' => 'dipole',
			'settings.station.antennaTypes.vertical' => 'vertical',
			'settings.station.antennaTypes.yagiBeam' => 'yagi / beam',
			'settings.station.antennaTypes.loop' => 'loop',
			'settings.station.antennaTypes.longWire' => 'long wire / efhw',
			'settings.station.antennaTypes.other' => 'other',
			'settings.station.keyType' => 'key type',
			'settings.station.keyTypeRequired' => 'choose a key type',
			'settings.station.keyTypes.straight' => 'straight key',
			'settings.station.keyTypes.sideswiper' => 'sideswiper',
			'settings.station.keyTypes.bug' => 'bug (mechanical semi-automatic)',
			'settings.station.keyTypes.fullyAutomatic' => 'fully-automatic keyer',
			'settings.station.keyTypes.singlePaddle' => 'single paddle',
			'settings.station.keyTypes.dualPaddle' => 'dual paddle',
			'settings.station.keyTypes.computerDriven' => 'computer driven',
			'settings.station.keyTypes.other' => 'other',
			'settings.station.softwareIntermediaries' => 'software intermediaries',
			'settings.station.otherBrands' => 'other brands',
			'settings.station.otherEquipment' => 'other equipment (antennas, keys, etc)',
			'settings.station.newAntenna' => 'new antenna',
			'settings.station.newKey' => 'new key',
			'settings.station.newKeyer' => 'winkeyer (k1el or compatible)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'cat keyer in ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'key on ${device}',
			'settings.station.cwKeyerArea' => 'keyer area',
			'settings.station.trackStationInfo' => 'track station info for each qso',
			'settings.station.includeStationInfoInAdif' => 'include in adif exports',
			'settings.station.whatToTrack' => 'what to track?',
			'settings.station.trackFieldRig' => 'transceiver',
			'settings.station.trackFieldPower' => 'power',
			'settings.station.watts' => 'watts',
			'settings.station.trackFieldAntenna' => 'antenna',
			'settings.station.trackFieldKey' => 'cw key',
			'settings.station.placeholderConnectDelay' => 'connect delay (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'how long the simulated handshake takes. blank or 0 connects instantly.',
			'settings.station.placeholderDropAfter' => 'drop after (seconds)',
			'settings.station.placeholderDropAfterDescription' => 'close the connection on its own, to exercise the reconnect path. blank or 0 never drops.',
			'settings.station.placeholderFailConnect' => 'always fail to connect',
			'settings.station.placeholderConnectFailure' => 'the placeholder radio was told to refuse this connection',
			'settings.station.placeholderFreq' => 'frequency (khz)',
			'settings.station.placeholderFreqDescription' => 'where the placeholder radio starts. it reports back whatever the app tunes it to afterwards.',
			'settings.station.placeholderMode' => 'mode',
			'settings.station.placeholderModeDescription' => 'the mode the placeholder radio starts on, e.g. usb, cw, ft8.',
			'settings.station.placeholderPower' => 'power (watts)',
			'settings.station.placeholderPurpose' => 'use this radio to keep track of which rig you\'re using for logging purposes',
			'settings.station.placeholderReplyDelay' => 'reply delay (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'how long the placeholder radio takes to report a change back. blank or 0 replies at once.',
			'settings.station.cwKeyerField' => 'cat cw keyer',
			'settings.station.cwKeyerFieldDescription' => 'whether this radio keys cw from text over cat. off for a rig the app does not know.',
			'settings.station.voiceMemories' => 'voice memories',
			'settings.station.voiceMemoriesDescription' => 'how many voice memories the radio plays over cat. 0 for none.',
			'settings.station.voiceMemoriesInvalid' => 'a whole number, 0 or more',
			'settings.station.yaesuMeterCapture' => 'capture meter readings',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'reads the radio\'s power-output meter and high-swr flag while transmitting and prints the raw values to the log. for building the scale yaesu does not publish — the values are not shown as meters.',
			'settings.station.yaesuMeterCaptureDescription' => 'reads the radio\'s po, swr and alc meters while transmitting and prints the raw values to the log. for building the scale yaesu does not publish — the values are not shown as meters.',
			'settings.station.telemetryInterval' => 'meter reading interval (ms)',
			'settings.station.telemetryIntervalDescription' => 'how often to read the radio\'s meters while it is transmitting. leave blank for the fastest this connection can handle, up to 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'a whole number of milliseconds, ${min} to ${max}',
			'settings.station.pollInterval' => 'idle polling interval (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'how often to ask the radio for its frequency and mode while neither is changing. leave blank for ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'a whole number of milliseconds, ${min} to ${max}',
			'settings.station.advancedSettings' => 'advanced settings',
			'settings.station.placeholderSwr' => 'swr reading',
			'settings.station.placeholderSwrDescription' => 'what this radio reports on its swr meter while transmitting. above 1.8 the panel warns.',
			'settings.station.placeholderSwrInvalid' => 'a number, 1 or more',
			'settings.station.keyerNone' => 'none',
			'settings.station.cwDialect' => 'cw keying dialect',
			'settings.station.cwDialectDescription' => 'which shape of the ky command this radio takes. none means no cw keying over cat.',
			'settings.station.cwDialectKenwood' => 'kenwood (ky, padded to 24)',
			'settings.station.cwDialectElecraft' => 'elecraft (ky text)',
			'settings.station.voiceDialect' => 'voice keyer dialect',
			'settings.station.voiceDialectDescription' => 'how this radio plays its voice memories over cat. none means no voice memories over cat. with a dialect and no count, the dialect\'s default count applies.',
			'settings.station.voiceDialectPb' => 'kenwood (pb, ts-590 style)',
			'settings.station.voiceDialectK4' => 'elecraft k4 (pb and da)',
			'settings.station.voiceDialectKx' => 'elecraft kx2/kx3 (switch taps)',
			'settings.station.placeholderDiagnostic' => 'simulated',
			'settings.station.placeholderWholeNumberInvalid' => 'must be a whole number, 0 or more',
			'settings.station.placeholderFreqInvalid' => 'must be a frequency in khz, greater than zero',
			'settings.station.placeholderModeInvalid' => 'must be a mode name, e.g. usb, cw, ft8',
			'settings.station.switchLayout' => 'layout',
			'settings.station.switchLayoutDescription' => 'which side of the switch your radios are plugged into.',
			'settings.station.switchLayoutRequired' => 'choose how the switch is wired',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'the switch refused "${command}" (error ${code})',
			'settings.station.switchBusyTransmitting' => 'that port is transmitting — antenna not changed',
			'settings.station.switchNoAntenna' => 'none',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'antenna on port ${port}',
			'settings.station.switchAntennaForDescription' => 'which of your antennas is connected to this port on the switch.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antennas, ${radios} radios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antennas, 1 radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antenna, ${radios} radios',
			'settings.station.switchCommonPort' => 'common',
			'settings.station.dcnAddress' => 'device address',
			'settings.station.dcnAddressDescription' => 'the address set on the module\'s dip switches. a coax relay module leaves the factory at 2.',
			'settings.station.dcnAddressRequired' => 'must be a device address from 1 to 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'port ${port}',
			'settings.station.switchPortAutoHint' => 'follows band data',
			'settings.station.switchPortTransmittingHint' => 'transmitting — cannot change now',
			'settings.station.switchCurrentStateHeader' => 'current state',
			'settings.station.switchCurrentStateDescription' => 'which antenna each radio port is on right now. changes take effect immediately.',
			'settings.station.switchWiringHeader' => 'wiring',
			'settings.station.switchPortInhibitedHint' => 'transmit inhibited',
			'settings.station.configUnreadable' => 'this radio\'s saved settings could not be read. open its settings and enter them again, or remove it and add it back.',
			'settings.station.autoConnectHeld' => 'halo stopped responding the last time it connected to this radio, so it did not connect on its own this time. press connect to try again.',
			'settings.offlineData.title' => 'offline data',
			'settings.offlineData.noFiles' => 'no data files',
			'settings.offlineData.noFilesDescription' => 'enable activity or lookup extensions to download their offline data here.',
			'settings.offlineData.refresh' => 'refresh',
			'settings.offlineData.refreshing' => 'refreshing…',
			'settings.offlineData.updateAll' => 'update all',
			'settings.offlineData.updatingAll' => 'updating all data files…',
			'settings.offlineData.neverDownloaded' => 'never downloaded',
			'settings.offlineData.updatedJustNow' => 'updated just now',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'updated ${days}d ago',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'updated ${days}d ${hours}h ago',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'updated ${hours}h ago',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'updated ${hours}h ${minutes}m ago',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'updated ${minutes}m ago',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'the last download had only ${imported} of ${existing} records and was not used. refresh to accept it.',
			'settings.offlineData.extensionsSection' => 'extensions',
			'settings.profiles.notSet' => 'not set',
			'settings.profiles.personalInfo' => 'personal info',
			'settings.profiles.personalInfoNote' => 'this might be included in generated logs when relevant for submissions',
			'settings.profiles.name' => 'name',
			'settings.profiles.email' => 'email',
			'settings.profiles.club' => 'club',
			'settings.profiles.arrlSection' => 'arrl section',
			'settings.profiles.racSection' => 'rac section',
			'settings.profiles.section' => 'section',
			'settings.search.clear' => 'clear',
			'settings.search.hint' => 'search preferences',
			'settings.developer.developerModeDescription' => 'enable developer warnings, debug logs, and tools.',
			'settings.developer.experiments' => 'experiments',
			'settings.developer.showIdleMetrics' => 'show idle metrics',
			'settings.developer.showIdleMetricsDescription' => 'show in the status bar how idle the extension engine has been over the last second. tap it for the 10- and 60-second averages.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% idle',
			'settings.developer.idleMetricsAverages' => 'idle avg:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} enabled', other: '${count} enabled', ), 
			'settings.developer.patchTrack' => 'code push track',
			'settings.developer.patchTrackDescription' => 'which over-the-air code push ring this device follows. more adventurous rings get fixes earlier, less tested. code pushes apply on the next restart.',
			'settings.developer.trackStable' => 'stable',
			'settings.developer.trackUnstable' => 'unstable',
			'settings.developer.trackBleeding' => 'bleeding',
			'settings.developer.checkingTrack' => ({required Object track}) => 'checking "${track}" for a code push…',
			'settings.developer.patchDownloaded' => 'code push downloaded — restart the app to apply it.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'no new code push on "${track}".',
			'settings.developer.noPatchInstalled' => 'no code push installed — running the release binary.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'running code push #${patch}.',
			'settings.developer.deepLinks' => 'deep links',
			'settings.developer.registerUrlSchemes' => 'register url schemes',
			'settings.developer.registerUrlSchemesDescription' => 'let com.ham2k:// links open this copy of the app',
			'settings.developer.registerUrlSchemesDone' => 'this copy now opens com.ham2k:// links',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'could not register: ${error}',
			'settings.developer.systemInformation' => 'system information',
			'settings.developer.appVersion' => 'app version',
			'settings.developer.dataFolder' => 'data folder',
			'settings.developer.loading' => '(loading…)',
			'settings.developer.panelLoadFailed' => 'could not load this settings panel.',
			'settings.developer.extDevServer' => 'extension dev server',
			'settings.developer.extensionSettings' => 'extension settings',
			'settings.developer.extDevServerDescription' => 'load extensions from a dev server on your network instead of the ones built into the app, and reload them as you save.',
			'settings.developer.extDevServerAddress' => 'server address',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'connect',
			'settings.developer.extDevServerDisconnect' => 'disconnect',
			'settings.developer.extDevServerConnecting' => 'connecting…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'serving ${count} extension: ${keys}', other: 'serving ${count} extensions: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'not connected',
			'settings.developer.extDevServerReconnect' => 'reconnect at launch',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'last reload: ${key} at ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} extension failing to build', other: '${count} extensions failing to build', ), 
			'settings.developer.catalog' => 'extension catalog',
			'settings.developer.catalogDescription' => 'read the catalog from another server — a local one while working on the catalog itself. empty means catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'catalog address',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'catalog search tracks',
			'settings.developer.catalogSearchStable' => 'only stable',
			'settings.developer.catalogSearchUnstable' => 'unstable or better',
			'settings.developer.catalogSearchBleeding' => 'bleeding or better',
			'settings.about.notices' => 'notices & messages',
			'settings.about.noticesDescription' => 'announcements and status messages',
			'settings.about.releaseNotes' => 'release notes',
			'settings.about.copiedVersion' => 'copied version details to clipboard',
			'settings.panels.settings' => 'application preferences',
			'settings.panels.settingsDescription' => 'make the app work how you want it',
			'settings.panels.commonSettings' => 'common preferences',
			'settings.panels.syncDescription' => 'back up and sync your logs across devices',
			'settings.panels.accountsDescription' => 'service credentials, offline data, and more',
			'settings.panels.extensions' => 'extensions & features',
			'settings.panels.extensionsDescription' => 'activities, contests, dashboard panels and more features',
			'settings.panels.profilesDescription' => 'operator callsign and station profile',
			'settings.panels.stationProfiles' => 'station profiles',
			'settings.panels.developerSettings' => 'developer settings',
			'settings.panels.developerSettingsDescription' => 'debugging and development tools',
			'settings.panels.about' => 'about',
			'settings.panels.aboutDescription' => 'version, credits, and legal information',
			'settings.panels.unavailableTitle' => 'some settings are unavailable',
			'settings.panels.unavailableText' => 'the extension runtime failed to start, so extension-contributed settings are missing.',
			'settings.panels.station' => 'station configuration',
			'settings.panels.stationDescription' => 'cat control and more options',
			'settings.panels.peers' => 'peer devices',
			'settings.panels.peersDescription' => 'connect to other devices nearby',
			'settings.showMoreSettings' => 'show more settings',
			'settings.numberFormat' => 'number formatting',
			'settings.numberFormatOpts.locale' => 'follow system settings',
			'settings.numberFormatOpts.period' => 'always use period for decimals',
			'settings.numberFormatOpts.comma' => 'always use comma for decimals',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => 'system settings (using ${separator} for decimals)',
			'settings.numberFormatDescription.period' => 'always using period for decimals',
			'settings.numberFormatDescription.comma' => 'always using comma for decimals',
			'settings.numberFormatSeparators.comma' => 'comma',
			'settings.numberFormatSeparators.period' => 'period',
			_ => null,
		} ?? switch (path) {
			'settings.gridPrecision' => 'grid precision',
			'settings.gridPrecisionOpts.six' => '6 digits (fn31pr)',
			'settings.gridPrecisionOpts.eight' => '8 digits (fn31pr55)',
			'settings.gridPrecisionDescription.six' => '6 digits',
			'settings.gridPrecisionDescription.eight' => '8 digits',
			'commands.enableSyncFirst' => 'enable sync in settings first.',
			'commands.fullResyncStarted' => 'full resync started — local data was backed up first.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'no data files matched "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'reload failed: ${error}',
			'commands.reloadingAll' => 'reloading all data files…',
			'commands.reloadingTarget' => ({required Object target}) => 'reloading ${target} data files…',
			'commands.unknownExperiment' => ({required Object token}) => 'unknown experiment "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} enabled',
			'commands.experimentDisabled' => ({required Object name}) => '${name} disabled',
			'commands.sentryTestSent' => 'test error report sent to sentry',
			'commands.idleMetricsEnabled' => 'idle metrics enabled in the status bar',
			'commands.idleMetricsDisabled' => 'idle metrics disabled',
			'commands.sentryTestLocalOnly' => 'sentry is disabled in this build — test error logged locally only',
			'commands.noOperationOpen' => 'that command needs an open operation',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'don\'t know how to mark a \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} isn\'t turned on in this app',
			'commands.goUnknown' => ({required Object to}) => 'don\'t know how to go to \'${to}\'',
			'commands.goBlocked' => 'close the open dialog first',
			'commands.operationAlreadyStarted' => 'this operation already has a start marker',
			'commands.couldNotOpenLocation' => 'added the break, but could not open the location screen',
			'commands.noTestOperations' => 'no test operations to purge',
			'commands.purgeTestsUnavailable' => 'purgetests needs to show a confirmation dialog, which isn\'t available here',
			'commands.syncAllUnavailable' => 'syncall needs to show a confirmation dialog, which isn\'t available here',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'purged ${count} test operation', other: 'purged ${count} test operations', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'purged ${purged} of ${total} test operations — the rest failed; try purgetests again',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'purged ${count} test contact with no operation', other: 'purged ${count} test contacts with no operation', ), 
			'commands.purgeTestsContactsFailed' => 'purged the test operations, but the test contacts with no operation failed; try purgetests again',
			'commands.purgeTestsNothingToDo' => 'nothing was purged',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'removed ${removed} of ${total} test operations — the rest failed; try review again',
			'commands.receivedPurgesFailed' => 'couldn\'t remove those test operations — try review again',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} test operation was removed on another device', other: '${count} test operations were removed on another device', ), 
			'commands.receivedPurgesReview' => 'review',
			'commands.settingOn' => 'on',
			'commands.settingOff' => 'off',
			'commands.settingEmpty' => '(empty)',
			'commands.settingSecretSet' => '(set)',
			'commands.settingSecretUnset' => '(not set)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selected',
			'commands.settingExpectsOnOff' => 'on or off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'one of: ${choices}',
			'commands.settingExpectsNumber' => 'a number',
			'commands.settingVanished' => ({required Object label}) => '“${label}” is no longer available',
			'commands.noCwKeyer' => 'no connected radio can key cw',
			'commands.noKeyer' => 'no connected radio can key cw or play voice memories',
			'commands.keyerNeedsOperation' => 'open an operation to use the cw keyer',
			'commands.keyerExperimentOff' => 'cw keying is off — turn it on with exp keyer',
			'commands.esmExperimentOff' => 'enter sends messages is off — turn it on with exp esm',
			'commands.cwSending' => ({required Object text}) => 'sending cw: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'cw message f${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'cw message f${n} was not sent: the extensions are not ready',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” did not accept that value',
			'commandDialog.hint' => 'search callsigns or type a command',
			'commandDialog.noResults' => ({required Object text}) => 'nothing matches “${text}”',
			'commandDialog.sectionCommands' => 'commands',
			'commandDialog.sectionGoTo' => 'go to',
			'commandDialog.sectionOperations' => 'operations',
			'commandDialog.goHome' => 'home',
			'commandDialog.goSettings' => 'settings',
			'commandDialog.goNewOperation' => 'new operation',
			'commandDialog.runTyped' => ({required Object text}) => 'run “${text}”',
			'commandDialog.sectionSuggestions' => 'try',
			'commandDialog.lookingUp' => 'looking up callsign…',
			'commandDialog.blockedByPane' => 'cannot use commands while a panel or dialog is open',
			'keyboardShortcuts.title' => 'keyboard shortcuts',
			'keyboardShortcuts.description' => 'customize key mappings',
			'keyboardShortcuts.search' => 'search commands and keys',
			'keyboardShortcuts.import' => 'import…',
			'keyboardShortcuts.export' => 'export…',
			'keyboardShortcuts.resetAll' => 'reset all',
			'keyboardShortcuts.resetAllTitle' => 'reset every shortcut?',
			'keyboardShortcuts.resetAllBody' => 'every command goes back to its default keys, and the keys bound to typed commands are removed.',
			'keyboardShortcuts.reset' => 'reset',
			'keyboardShortcuts.noKey' => 'no key',
			'keyboardShortcuts.changed' => 'changed',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} is also bound to ${commands}',
			'keyboardShortcuts.groupApp' => 'app',
			'keyboardShortcuts.groupKeying' => 'keying',
			'keyboardShortcuts.groupLogging' => 'logging',
			'keyboardShortcuts.groupCommands' => 'commands',
			'keyboardShortcuts.groupFixed' => 'fixed keys',
			'keyboardShortcuts.contextApp' => 'anywhere',
			'keyboardShortcuts.contextLogView' => 'operation, chasing and logs views',
			'keyboardShortcuts.contextOperation' => 'operation view, keying a cat radio',
			'keyboardShortcuts.contextLogging' => 'in the logging panel',
			'keyboardShortcuts.addCommand' => 'add a command…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'unknown command: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'open the command dialog',
			'keyboardShortcuts.command.toggleTheme' => 'switch between light and dark',
			'keyboardShortcuts.command.toggleLanguage' => 'switch between english and spanish',
			'keyboardShortcuts.command.fontScaleUp' => 'larger text',
			'keyboardShortcuts.command.fontScaleDown' => 'smaller text',
			'keyboardShortcuts.command.fontScaleReset' => 'normal text size',
			'keyboardShortcuts.command.densityLooser' => 'roomier layout',
			'keyboardShortcuts.command.densityDenser' => 'denser layout',
			'keyboardShortcuts.command.densityAuto' => 'automatic layout density',
			'keyboardShortcuts.command.find' => 'find in the log',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'send message ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'keyboard mode on or off',
			'keyboardShortcuts.command.ptt' => 'push to talk',
			'keyboardShortcuts.command.wipe' => 'clear the contact being logged',
			'keyboardShortcuts.fixed.callsign' => 'typing callsigns',
			'keyboardShortcuts.fixed.escape' => 'stop sending, back out one step, or close',
			'keyboardShortcuts.fixed.enter' => 'log the contact',
			'keyboardShortcuts.fixed.space' => 'next field',
			'keyboardShortcuts.fixed.tab' => 'next or previous field',
			'keyboardShortcuts.fixed.arrows' => 'move between fields, controls and the log',
			'keyboardShortcuts.fixed.walk' => 'page through the log, or go to its ends',
			'keyboardShortcuts.fixed.undo' => 'take back a wipe or a delete',
			'keyboardShortcuts.editor.addShortcut' => 'add shortcut',
			'keyboardShortcuts.editor.listening' => 'press the keys for the shortcut…',
			'keyboardShortcuts.editor.listeningHint' => 'esc stops listening',
			'keyboardShortcuts.editor.add' => 'add',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} belongs to the logging fields or a dialog, and can’t be changed.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} is how callsigns are typed. hold cmd, ctrl or alt with it.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'the system may take ${keys} before the app sees it.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} is already one of this command’s keys.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'take ${keys} from “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'reset to default',
			'keyboardShortcuts.editor.remove' => 'remove',
			'keyboardShortcuts.editor.commandLabel' => 'command',
			'keyboardShortcuts.editor.commandHint' => 'enter any valid command, or multiple commands separated by ";"',
			'keyboardShortcuts.editor.removeCommand' => 'remove command',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'no command reads “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'no key yet',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'shortcuts saved to ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'couldn’t export the shortcuts: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'couldn’t open the file: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} isn’t a shortcuts file this app can read: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'the text isn’t valid yaml (line ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'it isn’t a ham2k keyboard shortcuts file',
			'keyboardShortcuts.file.problemNewerVersion' => 'it was written by a newer version of the app',
			'keyboardShortcuts.file.problemMalformed' => 'part of it doesn’t follow the shortcuts format',
			'keyboardShortcuts.file.problemTooLarge' => 'it is too large',
			'keyboardShortcuts.file.importTitle' => 'import shortcuts',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'written on ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'the file doesn’t say which keyboard it was written on.',
			'keyboardShortcuts.file.translate' => 'what should each of these keys be on this keyboard?',
			'keyboardShortcuts.file.leaveOut' => 'leave those shortcuts out',
			'keyboardShortcuts.file.replace' => 'replace this device’s config',
			'keyboardShortcuts.file.replaceHint' => 'every shortcut not in the file goes back to its default.',
			'keyboardShortcuts.file.merge' => 'add to this device’s config',
			'keyboardShortcuts.file.mergeHint' => 'the file’s shortcuts replace this device’s for the same commands, and the rest stay.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'not known in this version, so left out: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'not shortcuts, so left out: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'keys the app keeps for itself, so left out: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'bound to more than one command after the import: ${keys}',
			'keyboardShortcuts.file.importAction' => 'import',
			'keyboardShortcuts.file.imported' => 'shortcuts imported',
			'keyboardShortcuts.modifier.cmd' => '⌘ command',
			'keyboardShortcuts.modifier.ctrl' => 'ctrl',
			'keyboardShortcuts.modifier.meta' => 'windows / super',
			'keyboardShortcuts.platform.macos' => 'macos',
			'keyboardShortcuts.platform.ios' => 'ipados',
			'keyboardShortcuts.platform.windows' => 'windows',
			'keyboardShortcuts.platform.linux' => 'linux',
			'keyboardShortcuts.platform.android' => 'android',
			'expiredBuild.title' => 'this build has expired',
			'expiredBuild.body' => 'please visit ham2k.com and get a newer version.',
			'expiredBuild.visit' => 'visit ham2k.com',
			'expiredBuild.dismiss' => 'continue anyway',
			'staleness.codePushFloorTitle' => 'an important update is waiting',
			'staleness.codePushFloorBody' => 'this version has a fix you don\'t have yet.',
			'staleness.restartToApply' => 'restart the app to apply it.',
			'staleness.quitAndReopen' => 'quit the app and open it again to apply it.',
			'staleness.reopenToApply' => 'close the app and open it again to apply it.',
			'staleness.ignoreForNow' => 'ignore for now',
			'spotting.noQsoYet' => 'no qso logged yet to spot.',
			'spotting.setFrequencyFirst' => 'set a frequency first.',
			'spotting.nothingToSpot' => 'nothing to spot — no extension offers spotting here.',
			'spotting.incompleteCall' => 'can\'t spot an incomplete call — finish the callsign first.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} failed: ${message}',
			'spotting.unknownError' => 'unknown error',
			'spotting.notSent' => 'spot not sent.',
			'spotting.allSkipped' => 'spot not sent: every spot source skipped it.',
			'spotting.notRefreshedOffline' => 'no connection — spots were not refreshed',
			'dataFiles.downloading' => 'downloading…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'couldn\'t download ${name}',
			'dataFiles.downloadFailedWebHint' => 'this could be a network issue, or this link\'s host may not support direct downloads from a web browser. try the desktop or mobile app, or a different hosting location.',
			'dataFiles.downloadTimedOut' => 'the server took too long to respond. try again later.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} answered with an error (http ${status}). try again later.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} couldn\'t provide this file (http ${status}). check that its address is still right.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'n1mm has no call history file for ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'n1mm\'s call history download for ${stem} didn\'t work. try again later.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'couldn\'t process ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'the download had only ${imported} of the ${existing} records on this device, so the ones it left out were kept. refreshing it in settings › offline data accepts it anyway.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'imported ${count} record for ${label}.', other: 'imported ${count} records for ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'imported data for ${label}.',
			'dataFiles.cleanedUpTitle' => 'cleaned up extension data',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'removed data for ${count} data file from disabled extensions.', other: 'removed data for ${count} data files from disabled extensions.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} records',
			'dataFiles.definitionUnavailable' => 'the file\'s source didn\'t provide a definition — its extension may be mid-restart or misconfigured. try again in a moment.',
			'updates.updateAvailable' => 'update available',
			'updates.newVersionAvailable' => ({required Object version}) => 'a new version (${version}) is available.',
			'updates.getIt' => 'get it',
			'updates.ok' => 'ok',
			'updates.updateReady' => 'update ready',
			'updates.restartToApply' => 'an update has been downloaded. restart to apply it.',
			'updates.appliesNextLaunch' => 'an update has been downloaded. it will apply the next time you open the app.',
			'updates.restartNow' => 'restart now',
			'updates.reloadToUpdate' => 'a newer version of this page is available. reload to get it.',
			'updates.reloadNow' => 'reload now',
			'updates.checkForUpdates' => 'check for updates',
			'updates.checkingForUpdates' => 'checking for updates…',
			'updates.upToDate' => 'up to date',
			'updates.automaticChecks' => 'check automatically',
			'updates.automaticChecksDescription' => 'look for new versions in the background, from the next time you start the app',
			'extensionService.runtimeNotReady' => 'extension runtime not ready.',
			'extensionService.testFailed' => ({required Object error}) => 'test failed: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'connected as ${identity}',
			'extensionService.invalidFieldConfiguration' => 'invalid field configuration',
			'extensionService.invalidValue' => 'invalid value',
			'extensionService.validationError' => ({required Object error}) => 'validation error: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'action failed: ${error}',
			'extensionService.commandFailed' => 'the command failed to run',
			'extensionService.reportUnavailable' => 'reports can\'t be sent right now',
			'extensionService.stashUnavailable' => 'ham2k’s file stash can’t be reached right now',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} spent too much time in its timers. they\'re stopped until the extensions restart.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name}\'s timers kept failing. they\'re stopped until the extensions restart.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} got stuck in a timer. its timers are stopped until the extensions restart.',
			'operationLocationScreen.title' => 'operation location',
			'operationLocationScreen.selectedLocation' => 'selected location',
			'operationLocationScreen.gridSquare' => 'maidenhead grid square locator',
			'operationLocationScreen.gridInvalid' => 'needs 4, 6, 8 or 10 characters, like fn31pr',
			'operationLocationScreen.suggestedLocations' => 'suggested locations',
			'operationLocationScreen.deviceGps' => 'device gps',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'gps from ${device}',
			'operationLocationScreen.locating' => 'locating…',
			'operationLocationScreen.gpsUnavailable' => 'location unavailable',
			'operationLocationScreen.permissionDenied' => 'location permission denied',
			'operationLocationScreen.permissionBlocked' => 'location permission blocked',
			'operationLocationScreen.moreDetails' => 'more details',
			'operationLocationScreen.stateOrProvince' => 'state or province (optional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'activity controls unavailable',
			'operationLocationScreen.controlsUnavailableReason' => 'these references are still usable; their activities just could not be reached.',
			'operationLocationScreen.controlsUnavailableRetry' => 'retry',
			'operationLocationScreen.county' => 'county (optional)',
			'versionLabel.version' => ({required Object version}) => 'version ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'no notices yet',
			'notices.webStorageInMemory' => 'this browser could not provide persistent storage — the log lives in memory only and will be lost when this tab closes. use a current chrome, firefox, safari or edge.',
			'notices.webStorageUnreliable' => 'this browser is using fallback storage that is not safe with multiple tabs — keep a single tab open, and keep sync on.',
			'notices.logFromNewerBuildTitle' => 'this log needs a newer version',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'your log was written by a newer version of halo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. install the newer version again — or, if you meant to run this build, point it at a different data folder. the log is in ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'your log was written by a newer version of halo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. open this log with that newer version instead.',
			'notices.preferencesRestoredTitle' => 'settings restored from a backup',
			'notices.preferencesRestored' => 'the settings file could not be read, so halo restored the last good copy of it. anything you changed in your previous session may need setting again. the unreadable file is kept alongside it, named shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'settings reset',
			'notices.preferencesReset' => 'the settings file could not be read and there was no backup to fall back on, so halo started with its defaults. the unreadable file is kept in the app\'s data folder, named shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} was not connected automatically',
			'notices.autoConnectHeld' => ({required Object name}) => 'halo stopped responding the last time it started connecting to ${name}, so it left it alone this time rather than risk doing it again. check that the radio is switched on and its cable is plugged in, then press connect on it in settings.',
			'syncAccount.anonymous' => ({required Object id}) => 'anonymous account (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (pending confirmation)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (pending confirmation - #${id})',
			'deepLink.needsAnOperation' => 'start an operation first, then send that contact again',
			'deepLink.waitingInOperation' => 'that contact is waiting in the operation behind this screen',
			'deepLink.unknownActivities' => ({required Object refs}) => 'this device has no activity for ${refs}, so those references were left off',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'could not reach your activities, so ${refs} was left off — try that link again',
			'confirmDevice.title' => 'confirm a device',
			'confirmDevice.codePrompt' => 'enter the code shown on the device that wants to join this account.',
			'confirmDevice.code' => 'code',
			'confirmDevice.lookUp' => 'look up',
			'confirmDevice.codeNotFound' => 'no request matches that code. codes expire after 10 minutes — ask the other device for a fresh one.',
			'confirmDevice.linkExpired' => 'that link has expired. ask the other device to show a new qr code.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'link ${device} to this account?',
			'confirmDevice.unnamedDevice' => 'an unnamed device',
			'confirmDevice.grantWarning' => 'it will be able to read and change every operation and qso in this account.',
			'confirmDevice.needsSyncTitle' => 'this device does not sync yet',
			'confirmDevice.needsSyncText' => 'turn on ham2k log filer sync and link this device to an account before it can admit another one.',
			'confirmDevice.malformedRequest' => 'the sync server sent a request this app could not read. ask the other device to try again.',
			'confirmDevice.linkIt' => 'link device',
			'switchAccounts.noAccountDetails' => 'no account details yet',
			'switchAccounts.currentAccount' => 'current account',
			'switchAccounts.otherAccounts' => 'other accounts',
			'switchAccounts.linkToAnother' => 'link to another account',
			'switchAccounts.linkWithSibling' => 'link with other ham2k app',
			'switchAccounts.linkWithPolo' => 'link with account in older version',
			'switchAccounts.linkWithSiblingDescription' => 'you have another ham2k app installed. link with the account in use there.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'approve the request in ${app}, then come back here.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'open ${app} again',
			'switchAccounts.siblingNoGrant' => 'didn\'t work? open it again, or go back and link another way.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'could not open ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'the link expired and a new one is ready — open ${app} again.',
			'switchAccounts.tryAgain' => 'try again',
			'switchAccounts.linkWithQr' => 'link with a qr code',
			'switchAccounts.linkWithQrDescription' => 'scan it from a device already using the account',
			'switchAccounts.linkWithEmail' => 'link with an email address',
			'switchAccounts.linkWithEmailDescription' => 'confirm with a code or an email link',
			'switchAccounts.enterEmailPrompt' => 'enter the email address of the account you want this device to use.',
			'switchAccounts.emailAddress' => 'email address',
			'switchAccounts.linkAccount' => 'link account',
			'switchAccounts.copiedCode' => 'copied code to clipboard',
			'switchAccounts.copyCode' => 'copy code',
			'switchAccounts.codePrompt' => ({required Object email}) => 'open the ham2k app on a device already linked with ${email} and enter this code to approve the request:',
			'switchAccounts.waitingForConfirmation' => 'waiting for confirmation…',
			'switchAccounts.sendEmailInstead' => 'send a confirmation email instead',
			'switchAccounts.emailSent' => ({required Object email}) => 'an email was sent to ${email}. open it and confirm the request to link this device.',
			'switchAccounts.resendEmail' => 'resend email',
			'switchAccounts.qrPrompt' => 'scan this qr code from a device already linked to the account you want — for example with ham2k portable logger on your phone.',
			'switchAccounts.serverUnreachable' => 'could not reach the sync server. try again later.',
			'switchAccounts.emailRequired' => 'enter an email address to link.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'no account found for ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'the sync server rejected the request: ${error}',
			'switchAccounts.noLinkCode' => 'the sync server did not return a link code. try again later.',
			'switchAccounts.noConfirmationCode' => 'the sync server did not send a confirmation code. try again later.',
			'switchAccounts.switchNotAccepted' => 'that account did not accept the switch. try linking it with an email address instead.',
			'switchAccounts.requestFailed' => 'something went wrong talking to the sync server. try again later.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} qso', other: '${count} qsos', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} operation', other: '${count} operations', ), 
			'qsonImport.title' => 'import qson operation',
			'qsonImport.description' => 'create a new operation from a qson file, as developer mode exports one here or in polo.',
			'qsonImport.dropHint' => 'drop a qson file to import it as a new operation',
			'qsonImport.importing' => ({required Object filename}) => 'importing ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'could not import ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'could not open a file to import: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} is not utf-8 text, so it is not a qson file',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} is not a json file, so it is not a qson file',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} does not hold a qson operation',
			'qsonImport.busy' => 'an import is already running. wait for it to finish before starting another.',
			'qsonImport.oneFileOnly' => 'drop one qson file at a time — each one opens as its own operation.',
			'adifImport.title' => 'import qsos from adif',
			'adifImport.reading' => ({required Object filename}) => 'reading ${filename}…',
			'adifImport.dropHint' => 'drop an adif file to import',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} qso in this file', other: '${formatted} qsos in this file', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} already in your log', other: '${formatted} already in your log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} will be imported', other: '${formatted} will be imported', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} new contact', other: '${formatted} new contacts', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} will merge with an existing contact', other: '${formatted} will merge with existing contacts', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} cannot be imported (no callsign)', other: '${formatted} cannot be imported (no callsign)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} needs a closer look', other: '${formatted} need a closer look', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'references could not be recovered for ${count} contact', other: 'references could not be recovered for ${formatted} contacts', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${programs} references may be incomplete for ${count} contact', other: '${programs} references may be incomplete for ${formatted} contacts', ), 
			'adifImport.stackingTypesUnknown' => 'combined contacts may lose a reference — the activities could not say which types stack. cancel and retry to avoid this.',
			'adifImport.nothingToImport' => 'nothing in this file can be imported',
			'adifImport.confirm' => 'import',
			'adifImport.importing' => ({required Object filename}) => 'importing ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: 'imported ${count} contact from ${filename}', other: 'imported ${formatted} contacts from ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'could not import ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} does not look like an adif file',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'warning: this adif has qsos from ${calls}, but they will be imported as ${station} if you continue.',
			'adifImport.stationCallJoin' => ' and ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qrp'))(count, one: '${count} has no date and cannot be imported', other: '${formatted} have no date and cannot be imported', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'this file records an activation of ${refs}.',
			'adifImport.addActivation' => 'add it to this operation',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'only ${written} of ${planned} could be applied — the log changed while you were deciding.',
			'adifImport.busy' => 'an import is already running. wait for it to finish before starting another.',
			'adifImport.oneFileOnly' => 'drop one adif file at a time — the order files are imported in decides which data wins.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} has more than ${limit} qsos, the most an operation can import at a time.',
			'offline.statusOffline' => 'internet: offline',
			'offline.statusOnline' => 'internet: connected',
			'offline.noRoute' => 'no network connection at all.',
			'offline.unreachable' => 'the network is up, but no server is responding — often a sign-in page waiting in a browser.',
			'offline.reachable' => 'all services responding as expected.',
			'offline.whatStops' => 'lookups, spots and data files are paused. logging and nearby sync are not.',
			'offline.servicesTitle' => 'services',
			'offline.noServices' => 'no service has reported in yet.',
			'offline.lastSuccess' => ({required Object when}) => 'last responded ${when} ago',
			'offline.neverSucceeded' => 'has not responded yet',
			'offline.nextAttempt' => ({required Object when}) => 'next attempt in ${when}',
			'offline.nextAttemptNow' => 'next attempt due',
			'offline.retry' => 'retry now',
			'offline.retrying' => 'trying…',
			'offline.retryReached' => 'back online.',
			'offline.retryUnreachable' => 'still no response.',
			'offline.retryNotAttempted' => 'nothing to send right now.',
			'offline.retryThrottled' => 'just tried — give it a moment.',
			'offline.retryDisabled' => 'sync is switched off, so there is nothing to probe with.',
			'offline.syncService' => 'ham2k lofi sync',
			'offline.retryInFlight' => 'already trying — hang on.',
			'exportSettings.defaultsDescription' => 'base settings for all exports, with separate filename and title templates for reference activities and other activities. each export type can provide its own defaults or custom settings.',
			'exportSettings.referenceActivities' => 'reference activities',
			'exportSettings.otherActivities' => 'other activities',
			'exportSettings.adifFields' => 'adif fields',
			'exportSettings.loadFailed' => 'export settings could not be loaded.',
			'exportSettings.retry' => 'retry',
			'exportSettings.compactFileNamesDescriptionOn' => 'compact filenames, such as n0call@us-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'descriptive filenames, such as 2026-07-15 n0call at us-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'including names, addresses, emails, notes and precise locations in adif files.',
			'exportSettings.includePrivateDataDescriptionOff' => 'omitting names, addresses, emails and notes; limiting locations to six-character grids.',
			'exportSettings.includeLookupDataDescriptionOn' => 'including information from callsign lookup services.',
			'exportSettings.includeLookupDataDescriptionOff' => 'omitting information from callsign lookup services; keeping manually entered values.',
			'exportSettings.customTemplatesDescriptionOn' => 'your custom templates are active and can be edited below.',
			'exportSettings.customTemplatesDescriptionOff' => 'default templates are active. your custom templates are kept for later.',
			'exportSettings.type' => 'export type',
			'exportSettings.defaults' => 'defaults',
			'exportSettings.includeLookupData' => 'include lookup data',
			'exportSettings.customTemplates' => 'custom templates',
			'exportSettings.filenameTemplate' => 'file name template',
			'exportSettings.compactFilenameTemplate' => 'compact file name template',
			'exportSettings.titleTemplate' => 'title template',
			'exportSettings.adifNotesTemplate' => 'adif qso notes',
			'exportSettings.adifCommentTemplate' => 'adif qso comments',
			'exportSettings.adifQslMessageTemplate' => 'adif qsl message',
			'exportSettings.shared' => 'settings apply to every extension using this export type.',
			'exportSettings.defaultTemplates' => 'turn on custom templates to edit this type’s templates.',
			'templateEditor.previewLabel' => 'preview:',
			'templateEditor.reset' => 'reset',
			'templateEditor.docs' => 'templating docs',
			'templateEditor.preview' => 'sample preview',
			'templateEditor.reference' => 'template reference',
			'templateEditor.attributes' => 'available attributes',
			'templateEditor.filters' => 'filters',
			'templateEditor.flowControl' => 'flow control',
			'templateEditor.unavailable' => 'preview is unavailable until extensions are ready.',
			'templateEditor.empty' => '(empty output)',
			_ => null,
		};
	}
}
