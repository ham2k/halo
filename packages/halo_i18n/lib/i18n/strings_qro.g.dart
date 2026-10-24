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
class TranslationsQro extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsQro({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.qro,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <qro>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsQro _root = this; // ignore: unused_field

	@override 
	TranslationsQro $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsQro(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$qro common = _Translations$common$qro._(_root);
	@override late final _Translations$onboarding$qro onboarding = _Translations$onboarding$qro._(_root);
	@override late final _Translations$startScreen$qro startScreen = _Translations$startScreen$qro._(_root);
	@override late final _Translations$testerOverlay$qro testerOverlay = _Translations$testerOverlay$qro._(_root);
	@override late final _Translations$extensionsPanel$qro extensionsPanel = _Translations$extensionsPanel$qro._(_root);
	@override late final _Translations$home$qro home = _Translations$home$qro._(_root);
	@override late final _Translations$chase$qro chase = _Translations$chase$qro._(_root);
	@override late final _Translations$dialogs$qro dialogs = _Translations$dialogs$qro._(_root);
	@override late final _Translations$operation$qro operation = _Translations$operation$qro._(_root);
	@override late final _Translations$map$qro map = _Translations$map$qro._(_root);
	@override late final _Translations$mapsView$qro mapsView = _Translations$mapsView$qro._(_root);
	@override late final _Translations$activitiesView$qro activitiesView = _Translations$activitiesView$qro._(_root);
	@override late final _Translations$loggingControls$qro loggingControls = _Translations$loggingControls$qro._(_root);
	@override late final _Translations$formChrome$qro formChrome = _Translations$formChrome$qro._(_root);
	@override late final _Translations$qsoEditForm$qro qsoEditForm = _Translations$qsoEditForm$qro._(_root);
	@override late final _Translations$qsoList$qro qsoList = _Translations$qsoList$qro._(_root);
	@override late final _Translations$loggingPanel$qro loggingPanel = _Translations$loggingPanel$qro._(_root);
	@override late final _Translations$callInfo$qro callInfo = _Translations$callInfo$qro._(_root);
	@override late final _Translations$settings$qro settings = _Translations$settings$qro._(_root);
	@override late final _Translations$commands$qro commands = _Translations$commands$qro._(_root);
	@override late final _Translations$commandDialog$qro commandDialog = _Translations$commandDialog$qro._(_root);
	@override late final _Translations$keyboardShortcuts$qro keyboardShortcuts = _Translations$keyboardShortcuts$qro._(_root);
	@override late final _Translations$expiredBuild$qro expiredBuild = _Translations$expiredBuild$qro._(_root);
	@override late final _Translations$staleness$qro staleness = _Translations$staleness$qro._(_root);
	@override late final _Translations$spotting$qro spotting = _Translations$spotting$qro._(_root);
	@override late final _Translations$dataFiles$qro dataFiles = _Translations$dataFiles$qro._(_root);
	@override late final _Translations$updates$qro updates = _Translations$updates$qro._(_root);
	@override late final _Translations$extensionService$qro extensionService = _Translations$extensionService$qro._(_root);
	@override late final _Translations$operationLocationScreen$qro operationLocationScreen = _Translations$operationLocationScreen$qro._(_root);
	@override late final _Translations$versionLabel$qro versionLabel = _Translations$versionLabel$qro._(_root);
	@override late final _Translations$notices$qro notices = _Translations$notices$qro._(_root);
	@override late final _Translations$syncAccount$qro syncAccount = _Translations$syncAccount$qro._(_root);
	@override late final _Translations$deepLink$qro deepLink = _Translations$deepLink$qro._(_root);
	@override late final _Translations$confirmDevice$qro confirmDevice = _Translations$confirmDevice$qro._(_root);
	@override late final _Translations$switchAccounts$qro switchAccounts = _Translations$switchAccounts$qro._(_root);
	@override late final _Translations$qsonImport$qro qsonImport = _Translations$qsonImport$qro._(_root);
	@override late final _Translations$adifImport$qro adifImport = _Translations$adifImport$qro._(_root);
	@override late final _Translations$offline$qro offline = _Translations$offline$qro._(_root);
	@override late final _Translations$exportSettings$qro exportSettings = _Translations$exportSettings$qro._(_root);
	@override late final _Translations$templateEditor$qro templateEditor = _Translations$templateEditor$qro._(_root);
}

// Path: common
class _Translations$common$qro extends Translations$common$en {
	_Translations$common$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get save => 'SAVE';
	@override String get ok => 'OK';
	@override String get cancel => 'CANCEL';
	@override String get delete => 'DELETE';
	@override String get create => 'CREATE';
	@override String get error => 'ERROR';
	@override String get close => 'CLOSE';
	@override String get done => 'DONE';
	@override String get callsign => 'CALLSIGN';
	@override String get clear => 'CLEAR';
	@override String get dismiss => 'DISMISS';
	@override String get expand => 'EXPAND';
	@override String get collapse => 'COLLAPSE';
}

// Path: onboarding
class _Translations$onboarding$qro extends Translations$onboarding$en {
	_Translations$onboarding$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'WELCOME TO HAM2K PORTABLE LOGGER!';
	@override String get welcomeTitleDesktop => 'WELCOME TO HAM2K POWER LOGGER!';
	@override String get welcomeBody => 'WE HAVE A FEW QUESTIONS TO HELP US BETTER SUIT YOUR NEEDS.';
	@override String get skip => 'SKIP';
	@override String get kContinue => 'CONTINUE';
	@override String get back => 'BACK';
	@override String get next => 'NEXT';
	@override String get done => 'DONE';
	@override String get callsignTitle => 'WHAT\'S YOUR CALLSIGN?';
	@override String get callsignBody => 'YOU NEED AN AMATEUR RADIO OPERATOR LICENSE IN ORDER TO FIND THIS APP USEFUL';
	@override String get callsignLabel => 'OPERATOR\'S CALLSIGN';
	@override String get alreadyHaveAccount => 'ALREADY HAVE AN ACCOUNT?';
	@override String get foundSiblingTitle => 'LINK AN EXISTING ACCOUNT?';
	@override String foundSiblingBody({required Object app}) => 'WE FOUND ${app} ON THIS DEVICE. LINK THIS APP TO THE SAME ACCOUNT AND YOUR CALLSIGN AND LOGS COME ACROSS.';
	@override String get foundPoloBody => 'WE FOUND AN OLDER VERSION OF HAM2K PORTABLE LOGGER ON THIS DEVICE. LINK THIS APP TO THE SAME ACCOUNT AND YOUR CALLSIGN AND LOGS COME ACROSS.';
	@override String get foundSiblingsBody => 'WE FOUND OTHER HAM2K APPS ON THIS DEVICE. LINK THIS APP TO ONE OF THEIR ACCOUNTS AND YOUR CALLSIGN AND LOGS COME ACROSS.';
	@override String linkWithApp({required Object app}) => 'LINK WITH ${app}';
	@override String get linkWithPolo => 'LINK WITH ACCOUNT IN OLDER VERSION';
	@override String get setUpFresh => 'SET UP FRESH';
	@override String get activitiesTitle => 'FAVORITE ACTIVITIES';
	@override String get activitiesBody => 'ARE YOU INTERESTED IN ANY OF THESE POPULAR ACTIVATION PROGRAMS?';
	@override String get activitiesFooter => '(YOU CAN FIND MORE OPTIONS IN THE SETTINGS)';
	@override String get activityPota => 'PARKS ON THE AIR';
	@override String get activitySota => 'SUMMITS ON THE AIR';
	@override String get activityWwff => 'WORLD WIDE FLORA & FAUNA';
	@override String get consentTitle => 'DATA & PRIVACY';
	@override String get consentUsageBody => 'TO HELP US MAKE THE APP BETTER, WE\'D LIKE TO COLLECT PERFORMANCE, CRASH, AND APP USAGE DATA.';
	@override String get consentUsageLabel => 'SHARE APP USAGE DATA';
	@override String get consentOperationBody => 'SOME FEATURES MIGHT INVOLVE SHARING YOUR OPERATION DATA WITH OTHER USERS. YOU CAN OPT-OUT AT ANY TIME.';
	@override String get consentOperationLabel => 'SHARE OPERATION DATA';
	@override String get finishingSetup => 'FINISHING SETUP — DOWNLOADING REFERENCE DATA…';
}

// Path: startScreen
class _Translations$startScreen$qro extends Translations$startScreen$en {
	_Translations$startScreen$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get credits => 'BY KI2D AND FRIENDS';
}

// Path: testerOverlay
class _Translations$testerOverlay$qro extends Translations$testerOverlay$en {
	_Translations$testerOverlay$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get tape => 'CAUTION: UNDER CONSTRUCTION';
	@override String get warningTitle => 'THIS APP IS A WORK IN PROGRESS';
	@override String get warningBody => 'MOST FEATURES HAVE UNEVEN SURFACES AND THERE ARE TRIP HAZARDS ALL OVER. PLEASE CHECK FOR UPDATES REGULARLY.';
	@override String whatsNew({required Object build}) => 'WHAT\'S NEW IN BUILD ${build}';
	@override String get thanks => 'THANK YOU FOR PUTTING YOUR LOG AT RISK IN ORDER TO HELP US MAKE THIS APP BETTER!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$qro extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'ACTIVITIES';
	@override String get categoryAward => 'AWARDS';
	@override String get categoryContest => 'CONTESTS';
	@override String get categoryLookup => 'CALLSIGN LOOKUPS';
	@override String get categorySpots => 'SPOT SOURCES';
	@override String get categoryDashboard => 'DASHBOARD PANELS';
	@override String get categoryOther => 'OTHER EXTENSIONS';
	@override String get searchHint => 'SEARCH EXTENSIONS';
	@override String get applying => 'ACTIVATING EXTENSION CHANGES, THIS MAY TAKE A MOMENT…';
	@override String get noMatches => 'NO EXTENSIONS MATCH YOUR SEARCH';
	@override String get installFromFile => 'INSTALL FROM FILE…';
	@override String installVersion({required Object version}) => 'VERSION ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'SCREENSHOT ${n} OF ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'PREVIOUS SCREENSHOT';
	@override String get nextScreenshot => 'NEXT SCREENSHOT';
	@override String get screenshotUnavailable => 'SCREENSHOT UNAVAILABLE';
	@override String get canReach => 'THIS EXTENSION CAN CONTACT';
	@override String canHoldConnection({required Object host}) => '${host}, OVER A LIVE CONNECTION';
	@override String get canHoldLocalConnection => 'DEVICES ON YOUR LOCAL NETWORK, OVER A LIVE CONNECTION';
	@override String get canUseLocation => 'YOUR LOCATION';
	@override String get canReadRadio => 'YOUR RADIO, TO READ ITS FREQUENCY AND MODE';
	@override String get canControlRadio => 'YOUR RADIO, TO CONTROL IT AND TO TRANSMIT WITH IT — TUNING, POWER, CW, VOICE MEMORIES AND PTT';
	@override String get canCommandRadioRaw => 'YOUR RADIO, TO SEND IT ANY COMMAND IN ITS OWN PROTOCOL — INCLUDING ONES THAT TRANSMIT OR CHANGE ITS SETTINGS';
	@override String get canReadCluster => 'THE DX CLUSTER, LOGGED IN AS YOU, TO READ WHAT IT SENDS';
	@override String get canSpotCluster => 'THE DX CLUSTER, LOGGED IN AS YOU, TO POST SPOTS IN YOUR NAME';
	@override String get canCommandCluster => 'THE DX CLUSTER, LOGGED IN AS YOU, TO SEND IT ANY COMMAND IN YOUR NAME';
	@override String get canSetUserAgent => 'IDENTIFY ITSELF TO SERVERS UNDER ITS OWN NAME';
	@override String get noCapabilities => 'IT ASKS FOR NOTHING OUTSIDE THE APP.';
	@override String get sandboxNote => 'EXTENSIONS RUN SANDBOXED: NO ACCESS TO YOUR FILES, AND NO NETWORK BEYOND WHAT IS LISTED HERE.';
	@override String get installAction => 'INSTALL';
	@override String get updateAction => 'UPDATE';
	@override String get installFailed => 'THAT EXTENSION COULD NOT BE INSTALLED';
	@override String get installedBadge => 'INSTALLED';
	@override String get uninstallAction => 'REMOVE';
	@override String uninstallTitle({required Object name}) => 'REMOVE ${name}?';
	@override String get uninstallBody => 'THIS EXTENSION AND ITS SETTINGS WILL BE REMOVED. YOUR LOGS WILL REMAIN UNTOUCHED.';
	@override String installedMessage({required Object name}) => 'INSTALLED ${name}';
	@override String get installDownloading => 'DOWNLOADING…';
	@override String get installWaiting => 'WAITING TO INSTALL…';
	@override String get installInstalling => 'INSTALLING…';
	@override String get installAwaitingApproval => 'WAITING FOR YOUR APPROVAL…';
	@override String installAlreadyRunning({required Object name}) => '${name} IS ALREADY BEING INSTALLED.';
	@override String updatedTo({required Object version}) => 'UPDATED TO ${version}';
	@override String installIncomplete({required Object name}) => 'INSTALLING ${name} DID NOT FINISH. IT MAY NEED INSTALLING AGAIN.';
	@override String uninstallFailed({required Object name}) => 'COULD NOT REMOVE ${name}';
	@override String installedFrom({required Object source}) => 'DOWNLOADED FROM ${source}';
	@override String get dropHint => 'DROP A .H2KEXT EXTENSION TO INSTALL IT';
	@override String get dropOneOnly => 'DROP ONE EXTENSION AT A TIME.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} RETURNED ${status} FOR THAT EXTENSION.';
	@override String get downloadTooLarge => 'THAT DOWNLOAD IS FAR TOO LARGE TO BE AN EXTENSION.';
	@override String get downloadNotSecure => 'THAT DOWNLOAD REDIRECTED SOMEWHERE INSECURE.';
	@override String get catalogSection => 'CATALOG';
	@override String get catalogLoading => 'LOADING THE CATALOG…';
	@override String get catalogUnreachable => 'CATALOG UNREACHABLE';
	@override String get builtIn => 'BUILT IN';
	@override String get updateAvailableBadge => 'UPDATE AVAILABLE';
	@override String get updatesAvailableTitle => 'EXTENSION UPDATES';
	@override String updateAvailableFor({required Object name}) => 'AN UPDATE IS AVAILABLE FOR ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} AND ${count} MORE NEED UPDATING.';
	@override String updatesAvailableFor({required Object names}) => '${names} NEED UPDATING.';
	@override String get pendingUpdatesSection => 'PENDING UPDATES';
	@override String get updateAllAction => 'UPDATE ALL';
	@override String get updatesUnderWay => 'THOSE UPDATES ARE ALREADY UNDER WAY.';
	@override String get updatesNothingLeft => 'YOUR EXTENSIONS ARE UP TO DATE.';
	@override String get updatesNoticeAction => 'MORE INFO';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'UPDATE ${count} EXTENSION?',
		other: 'UPDATE ${count} EXTENSIONS?',
	);
	@override String get upgradeDoneTitle => 'YOUR EXTENSIONS ARE READY';
	@override String get upgradeDoneBody => 'THEY NOW COME FROM THE HAM2K EXTENSION CATALOG, SO THEY CAN BE UPDATED WITHOUT WAITING FOR A NEW VERSION OF THE APP.';
	@override String upgradeDoneUnserved({required Object names}) => 'NOT UPGRADED: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'WOULD NOT RUN: ${names}.';
	@override String get upgradeDoneRefusedHint => 'THEY ARE STILL INSTALLED AND MARKED IN SETTINGS › EXTENSIONS — UPDATING THEM THERE WILL BRING THEM BACK.';
	@override String get upgradeDoneUnservedHint => 'THE CATALOG HAS NO DIRECT REPLACEMENT FOR THESE, SO LOOK THERE FOR EXTENSIONS THAT COVER WHAT YOU USED.';
	@override String get retiredQp => 'QSO PARTIES';
	@override String get retiredStateparks => 'STATE PARKS EVENTS';
	@override String upgradeDoneMissing({required Object count}) => '${count} OF YOUR EXTENSIONS HAVE NOT ARRIVED YET. THEY WILL BE DOWNLOADED THE NEXT TIME THE EXTENSION CATALOG CAN BE REACHED.';
	@override String get runtimeDeadBody => 'YOUR EXTENSIONS WOULD NOT START. RESTARTING THE APP SHOULD BRING THEM BACK.';
	@override String get refusedTitle => 'SOME EXTENSIONS WOULD NOT RUN';
	@override String get upgradeBusyTitle => 'STILL SETTING UP';
	@override String get upgradeRuntimeDeadTitle => 'YOUR EXTENSIONS ARE NOT RUNNING';
	@override String get restoreTitle => 'SOME OF YOUR EXTENSIONS ARE MISSING';
	@override String get restoreBody => 'THESE EXTENSIONS YOU INSTALLED ARE NOT ON THIS DEVICE. WE CAN DOWNLOAD THEM AGAIN FROM THE HAM2K EXTENSION CATALOG:';
	@override String get restoreFromFile => 'INSTALLED FROM A FILE. INSTALL THESE AGAIN FROM THEIR FILES, OR FORGET THEM:';
	@override String get restoreOtherCatalog => 'INSTALLED FROM A DIFFERENT EXTENSION CATALOG, SO THEY ARE NOT AVAILABLE HERE:';
	@override String get restoreForget => 'FORGET';
	@override String get restoreInstall => 'INSTALL';
	@override String get restoreLater => 'LATER';
	@override String get restoreInstalling => 'INSTALLING YOUR EXTENSIONS…';
	@override String get restoreDoneTitle => 'YOUR EXTENSIONS ARE BACK';
	@override String restoreDoneBody({required Object names}) => 'INSTALLED AGAIN: ${names}.';
	@override String get restorePartialTitle => 'SOME EXTENSIONS COULD NOT BE INSTALLED';
	@override String restoreFailed({required Object names}) => 'COULD NOT INSTALL: ${names}. WE WILL OFFER THEM AGAIN NEXT TIME YOU OPEN THE APP.';
	@override String get restoreBusyBody => 'THE APP IS STILL SETTING YOUR EXTENSIONS UP. WE WILL OFFER THESE AGAIN NEXT TIME YOU OPEN THE APP.';
	@override String get restoreRuntimeDeadBody => 'WE INSTALLED THEM AGAIN, BUT YOUR EXTENSIONS WOULD NOT START. RESTARTING THE APP SHOULD BRING THEM BACK.';
	@override String revokedTitle({required Object name}) => '${name} WAS WITHDRAWN';
	@override String get revokedBody => 'THE CATALOG WITHDREW THIS VERSION, SO IT HAS BEEN DISABLED.';
	@override String get downloadHashMismatch => 'THAT DOWNLOAD IS NOT THE EXTENSION THE CATALOG DESCRIBED.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'THE CATALOG HAS NO VERSION ${version} OF ${key}.';
	@override String get catalogLinkUnknown => 'THAT CATALOG LINK DOES NOT NAME AN EXTENSION VERSION.';
	@override String catalogNoRelease({required Object key}) => 'THE CATALOG HAS NO RELEASE OF ${key} ON THAT TRACK.';
	@override String get installFromLink => 'INSTALL FROM LINK';
	@override String get unstableReleaseWarning => 'THIS IS AN UNSTABLE RELEASE, WHICH ITS PUBLISHER HAS NOT CALLED FINISHED. IT MAY MISBEHAVE, AND IT WILL KEEP RECEIVING UNSTABLE UPDATES.';
	@override String get bleedingReleaseWarning => 'THIS IS A BLEEDING-EDGE RELEASE: WORK IN PROGRESS THAT MAY BREAK OR LOSE ITS SETTINGS. IT WILL KEEP RECEIVING BLEEDING-EDGE UPDATES.';
	@override String get channelUnstable => 'UNSTABLE';
	@override String get channelBleeding => 'BLEEDING';
	@override String get followsUnstable => 'RECEIVES UNSTABLE AND STABLE RELEASES';
	@override String get followsBleeding => 'RECEIVES BLEEDING-EDGE, UNSTABLE AND STABLE RELEASES';
	@override String get followStableAction => 'FOLLOW STABLE RELEASES ONLY';
	@override String get revokedBadge => 'REVOKED';
	@override String get refusedBadge => 'DID NOT LOAD';
	@override String get downloadNotHttps => 'THAT DOWNLOAD IS NOT OVER A SECURE CONNECTION.';
	@override String downloadUnreachable({required Object source}) => '${source} COULD NOT BE REACHED FOR THAT EXTENSION.';
	@override String get detailsAction => 'DETAILS';
	@override String get installedFromFile => 'INSTALLED FROM A FILE';
	@override String get detailsWhatItDoes => 'PROVIDES SUPPORT FOR';
	@override String get installedPreloaded => 'PRE-INSTALLED';
	@override String get hookAccount => 'ACCOUNT SIGN-IN';
	@override String get hookCallNotes => 'CALL NOTES';
	@override String get hookDataFile => 'OFFLINE DATA';
	@override String get hookExport => 'EXPORT';
	@override String get hookLookup => 'CALLSIGN LOOKUPS';
	@override String get hookScoring => 'SCORING';
	@override String get hookSpots => 'SPOTS';
	@override String hookHunting({required Object program}) => 'HUNTING ${program}';
	@override String hookActivating({required Object program}) => 'ACTIVATING ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '… AND ${count} OTHER EXTENSION',
		other: '… AND ${count} OTHER EXTENSIONS',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} EXTENSION AVAILABLE',
		other: '${count} EXTENSIONS AVAILABLE',
	);
}

// Path: home
class _Translations$home$qro extends Translations$home$en {
	_Translations$home$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'PORTABLE LOGGER';
	@override String get newOperation => 'NEW OPERATION';
	@override String get stationCallsign => 'STATION CALLSIGN';
	@override String get titleOptional => 'TITLE (OPTIONAL)';
	@override String get emptyList => 'NO OPERATIONS YET. CREATE ONE TO START LOGGING.';
	@override String get quickLookup => 'QUICK LOOKUP';
	@override late final _Translations$home$nav$qro nav = _Translations$home$nav$qro._(_root);
	@override late final _Translations$home$panels$qro panels = _Translations$home$panels$qro._(_root);
	@override String get toggleNav => 'SHOW OR HIDE THE NAVIGATION LABELS';
	@override late final _Translations$home$logs$qro logs = _Translations$home$logs$qro._(_root);
}

// Path: chase
class _Translations$chase$qro extends Translations$chase$en {
	_Translations$chase$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'OP';
	@override String get chasing => 'CHASING';
	@override String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} & MORE';
	@override late final _Translations$chase$station$qro station = _Translations$chase$station$qro._(_root);
	@override late final _Translations$chase$periodInline$qro periodInline = _Translations$chase$periodInline$qro._(_root);
	@override late final _Translations$chase$periodStats$qro periodStats = _Translations$chase$periodStats$qro._(_root);
	@override late final _Translations$chase$period$qro period = _Translations$chase$period$qro._(_root);
	@override late final _Translations$chase$goals$qro goals = _Translations$chase$goals$qro._(_root);
	@override late final _Translations$chase$panels$qro panels = _Translations$chase$panels$qro._(_root);
	@override late final _Translations$chase$claims$qro claims = _Translations$chase$claims$qro._(_root);
	@override late final _Translations$chase$notice$qro notice = _Translations$chase$notice$qro._(_root);
	@override late final _Translations$chase$alerts$qro alerts = _Translations$chase$alerts$qro._(_root);
	@override String get checklists => 'CHASING PROGRESS';
	@override late final _Translations$chase$imports$qro imports = _Translations$chase$imports$qro._(_root);
}

// Path: dialogs
class _Translations$dialogs$qro extends Translations$dialogs$en {
	_Translations$dialogs$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'OPERATION DETAILS';
	@override String get activities => 'ACTIVITIES';
	@override String get stationCallsign => 'STATION CALLSIGN';
	@override String get multiStationIdentifier => 'MULTI-STATION IDENTIFIER (NUMBERS ONLY)';
	@override String get notes => 'NOTES';
	@override String get deleteOperationTitle => 'DELETE OPERATION';
	@override String get purgeTestsTitle => 'PURGE TEST OPERATIONS';
	@override String get purgeTestsBody => 'THIS PERMANENTLY DELETES THESE TEST OPERATIONS AND THEIR QSOS. IT CANNOT BE UNDONE.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'PLUS ${count} TEST CONTACT THAT BELONGS TO NO OPERATION.',
		other: 'PLUS ${count} TEST CONTACTS THAT BELONG TO NO OPERATION.',
	);
	@override String get purgeTestsAction => 'PURGE';
	@override String get syncAllTitle => 'REPLACE THIS DEVICE\'S LOG?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL BACKS UP AND CLEARS ${qsos} FROM THIS DEVICE, THEN DOWNLOADS THE ACCOUNT\'S LOG AGAIN FROM THE SERVER. THE BACKUP STAYS IN THIS DEVICE\'S DATABASE.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${n} QSO HAS NOT BEEN SYNCED YET — THE SERVER NEVER RECEIVED IT, AND IT WILL NOT COME BACK.',
		other: '${n} QSOS HAVE NOT BEEN SYNCED YET — THE SERVER NEVER RECEIVED THEM, AND THEY WILL NOT COME BACK.',
	);
	@override String get syncAllAction => 'WIPE AND RESYNC';
	@override String get receivedPurgesTitle => 'TEST OPERATIONS REMOVED ELSEWHERE';
	@override String get receivedPurgesBody => 'THESE WERE DELETED AS TEST OPERATIONS ON ANOTHER DEVICE. REMOVE THEM HERE TOO? THIS PERMANENTLY DELETES THEM AND THEIR QSOS, AND CANNOT BE UNDONE.';
	@override String get receivedPurgesAction => 'REMOVE';
	@override late final _Translations$dialogs$callChange$qro callChange = _Translations$dialogs$callChange$qro._(_root);
}

// Path: operation
class _Translations$operation$qro extends Translations$operation$en {
	_Translations$operation$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'THIS OPERATION IS DELETED. UNDELETE IT TO LOG OR MAKE CHANGES.';
	@override late final _Translations$operation$tabs$qro tabs = _Translations$operation$tabs$qro._(_root);
	@override late final _Translations$operation$positions$qro positions = _Translations$operation$positions$qro._(_root);
	@override String get stationCallsignNone => 'NO STATION CALLSIGN';
	@override String get titleNone => 'NO TITLE';
	@override String get deleteOperation => 'DELETE OPERATION';
	@override String get loggingControlsStale => 'ACTIVITY FIELDS MAY BE OUT OF DATE — REOPEN THE OPERATION TO REFRESH THEM';
	@override String get locationNone => 'NOT SET';
	@override String get generalOperation => 'GENERAL OPERATION';
	@override String titleFor({required Object value}) => 'FOR ${value}';
	@override String titleAt({required Object value}) => 'AT ${value}';
	@override String segmentNow({required Object description}) => 'NOW ${description}';
	@override String get testOperationSuffix => 'TESTING';
	@override late final _Translations$operation$menu$qro menu = _Translations$operation$menu$qro._(_root);
	@override late final _Translations$operation$layout$qro layout = _Translations$operation$layout$qro._(_root);
	@override late final _Translations$operation$export$qro export = _Translations$operation$export$qro._(_root);
	@override late final _Translations$operation$spots$qro spots = _Translations$operation$spots$qro._(_root);
	@override late final _Translations$operation$import$qro import = _Translations$operation$import$qro._(_root);
}

// Path: map
class _Translations$map$qro extends Translations$map$en {
	_Translations$map$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$qro outlineIssue = _Translations$map$outlineIssue$qro._(_root);
	@override String get outlinesDisclaimer => 'OUTLINES ARE FOR REFERENCE ONLY. DO YOUR OWN RESEARCH!';
	@override String outlinesCredit({required Object sources}) => 'OUTLINES: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'BOUNDARIES: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'FACILITIES: ${sources}';
	@override String get fullCredits => 'FULL DATASET CREDITS';
	@override String get fewerCredits => 'FEWER CREDITS';
	@override String get emptyState => 'NO QSO LOCATIONS YET.\nQSOS WITH A GRID SQUARE, STATE, OR COUNTRY WILL SHOW UP HERE.';
	@override String get unavailable => 'THE MAP ISN\'T AVAILABLE RIGHT NOW.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} KM';
	@override String distanceMiles({required Object distance}) => '${distance} MI';
	@override String get flat => 'FLAT';
	@override String get globe => 'GLOBE';
	@override String get zoomIn => 'ZOOM IN';
	@override String get zoomOut => 'ZOOM OUT';
	@override String get resetNorth => 'RESET TO NORTH UP';
	@override late final _Translations$map$postcard$qro postcard = _Translations$map$postcard$qro._(_root);
}

// Path: mapsView
class _Translations$mapsView$qro extends Translations$mapsView$en {
	_Translations$mapsView$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'MAPS';
	@override String get searchHint => 'SEARCH PARKS, SUMMITS AND MORE';
	@override String get activities => 'ACTIVITIES';
	@override String get layers => 'LAYERS';
	@override String get baseMap => 'BASE MAP';
	@override String get satellite => 'SATELLITE (ESRI)';
	@override String get facilities => 'PARK FACILITIES';
	@override String get boundaries => 'BOUNDARIES';
	@override String get currentLocation => 'CURRENT LOCATION';
	@override String noMatches({required Object text}) => 'NOTHING MATCHES “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} REFERENCE AT ${where}',
		other: '${count} REFERENCES AT ${where}',
	);
	@override String get startOperation => 'START AN OPERATION WITH THESE REFERENCES';
}

// Path: activitiesView
class _Translations$activitiesView$qro extends Translations$activitiesView$en {
	_Translations$activitiesView$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ACTIVITIES';
	@override String get activitiesCountZero => 'NO ACTIVITIES SELECTED';
	@override String get activitiesCountOne => '1 ACTIVITY';
	@override String activitiesCountOther({required Object count}) => '${count} ACTIVITIES';
	@override String get empty => 'NO ACTIVITIES YET — USE SUGGESTIONS & SEARCH BELOW TO ADD ONE';
	@override String get removeActivity => 'REMOVE';
	@override String openReferenceLink({required Object name}) => 'OPEN ${name}';
	@override String get editActivity => 'EDIT ACTIVITY';
	@override String get manageExtensions => 'MANAGE EXTENSIONS';
	@override String get manage => 'MANAGE';
	@override String activitiesTitle1({required Object first}) => 'ACTIVITY TYPES: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'ACTIVITY TYPES: ${first} AND ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'ACTIVITY TYPES: ${first}, ${second} AND ${more} MORE';
	@override String get reference => 'REFERENCE';
	@override String get invalidReference => 'NOT VALID';
	@override String get duplicateReference => 'ALREADY ADDED';
	@override String get searchHint => 'SEARCH BY NAME, REFERENCE OR ANYTHING ELSE…';
	@override String get noSuggestions => 'NO MATCHES';
	@override String get noSuggestionsHint => 'SEARCH BY REFERENCE NAME OR NUMBER ABOVE';
	@override String get noSuggestionsExample => '(FOR EXAMPLE \'TRAIL\' OR \'4556\')';
	@override String get allOptions => 'ACTIVITY TYPES';
	@override String get determiningLocation => 'DETERMINING CURRENT LOCATION…\nWAITING FOR GPS FIX TO FIND NEARBY REFERENCES';
	@override String get locationUnavailableTitle => 'LOCATION DATA NOT AVAILABLE';
	@override String get locationDeniedTitle => 'LOCATION PERMISSION DENIED';
	@override String get locationBlockedTitle => 'LOCATION PERMISSION BLOCKED';
	@override String get noNearbyReason => 'CANNOT DETERMINE NEARBY REFERENCES';
	@override String locationManualHint({required Object icon}) => 'TAP ${icon} TO MANUALLY ENTER YOUR LOCATION,\nOR JUST SEARCH FOR REFERENCES BY NAME';
	@override String get locationGrantAction => 'ALLOW LOCATION ACCESS';
	@override String get locationSettingsAction => 'OPEN SETTINGS';
	@override String get locationSettingsUnavailable => 'ALLOW LOCATION ACCESS IN YOUR SYSTEM SETTINGS';
	@override String get locationGrantRefused => 'STILL NO LOCATION — THE SYSTEM SAID NO AGAIN';
	@override String get searchUnavailableTitle => 'ACTIVITY SEARCH UNAVAILABLE';
	@override String get searchUnavailableReason => 'NO ACTIVITY EXTENSION COULD RUN THE SEARCH. TRY AGAIN IN A MOMENT.';
	@override String get emptySheet => 'USE SUGGESTIONS & SEARCH BELOW TO ADD ONE';
	@override String get exports => 'EXPORTS';
	@override String get exportLogs => 'EXPORT LOGS';
	@override String get tools => 'TOOLS';
	@override String get toolsTitle => 'OPERATION TOOLS';
	@override String get operationDetails => 'OPERATION DETAILS';
	@override String get share => 'SHARE';
	@override String get archive => 'ARCHIVE';
	@override String get deleteOperation => 'DELETE OPERATION';
	@override String get undeleteOperation => 'UNDELETE OPERATION';
	@override String get alreadySelected => 'ALREADY SELECTED';
	@override String get selected => 'SELECTED';
	@override String pickPosition({required Object index, required Object count}) => '${index} OF ${count}';
	@override String get previousPick => 'PREVIOUS MATCH';
	@override String get nextPick => 'NEXT MATCH';
	@override String get retiredReference => 'RETIRED';
	@override String enableExtension({required Object name}) => 'ENABLE ${name}';
	@override String get enableExtensionHint => 'THIS EXTENSION MATCHES YOUR SEARCH, BUT IT IS NOT CURRENTLY ENABLED';
	@override String get enableExtensionForRefHint => 'THIS EXTENSION HANDLES ONE OF THIS OPERATION\'S REFERENCES, BUT IT IS NOT CURRENTLY ENABLED';
	@override String extensionNotRunning({required Object name}) => '${name} IS NOT RUNNING';
	@override String get extensionNotRunningHint => 'THIS EXTENSION HAS BEEN DISABLED, OPEN EXTENSION SETTINGS FOR MORE INFO';
	@override String installExtension({required Object name}) => 'INSTALL ${name}';
	@override String get installExtensionHint => 'THIS EXTENSION MATCHES YOUR SEARCH, BUT IT IS NOT INSTALLED';
	@override String get onlyCatalogMatches => 'NO MATCHES\nSOME EXTENSIONS IN THE CATALOG MIGHT HAVE RESULTS.\nINSTALL THEM IN ACTIVITY TYPES BELOW.';
	@override String get setupUnavailable => 'COULD NOT LOAD THIS ACTIVITY\'S SETUP — TRY AGAIN FROM MANAGE';
	@override String get controlsUnavailableTitle => 'ACTIVITY CONTROLS UNAVAILABLE';
	@override String get controlsUnavailableReason => 'YOUR REFERENCES ARE SAFE, BUT EDITING THEM IS UNAVAILABLE RIGHT NOW.';
	@override String get controlsUnavailableRetry => 'RETRY';
	@override String get onlyDisabledMatches => 'NO MATCHES\nSOME AVAILABLE EXTENSIONS MIGHT HAVE RESULTS.\nENABLE THEM IN ACTIVITY TYPES BELOW.';
	@override String get onlyNotRunningMatches => 'NO MATCHES\nSOME EXTENSIONS THAT MIGHT HAVE RESULTS ARE NOT RUNNING.\nSEE ACTIVITY TYPES BELOW.';
	@override String get mapToggle => 'MAP';
	@override String get searchToggle => 'SEARCH';
	@override String get addToOperation => 'ADD TO OPERATION';
	@override String get addToOperationShort => 'ADD TO OP.';
	@override String get mapEmptyState => 'NO RESULTS TO SHOW ON THE MAP';
	@override String get mapEmptyStateHint => 'SWITCH BACK TO THE LIST, OR SEARCH FOR SOMETHING ELSE';
	@override String get imports => 'IMPORTS';
}

// Path: loggingControls
class _Translations$loggingControls$qro extends Translations$loggingControls$en {
	_Translations$loggingControls$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'TIME (UTC)';
	@override String get date => 'DATE';
	@override String get now => 'NOW';
	@override String get manualTimeSettings => 'MANUAL TIME';
	@override String get manualTimeIncrement => 'INCREMENT PER QSO';
	@override String get manualTimeIncrementNone => 'NONE';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} MINUTE',
		other: '${count} MINUTES',
	);
	@override String get frequency => 'FREQUENCY';
	@override String get mode => 'MODE';
	@override String get theirCall => 'THEIR CALL';
	@override String get noteField => 'NOTE';
	@override String get todoField => 'TODO';
	@override String get sent => 'SENT';
	@override String get rcvd => 'RCVD';
	@override String get more => 'MORE';
	@override String get revert => 'REVERT';
	@override String get undoDelete => 'UNDO DELETE';
	@override String get restore => 'RESTORE';
	@override String get wipe => 'WIPE';
	@override String get undo => 'UNDO';
	@override String get pendingDeleteTapWarning => 'TAP THE TRASHCAN ONE MORE TIME TO DELETE THIS QSO';
	@override String get pendingDeleteClickWarning => 'CLICK THE TRASHCAN ONE MORE TIME TO DELETE THIS QSO';
	@override String get deletedQsoWarning => 'DELETED QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'TAP THE TRASHCAN ONE MORE TIME TO DELETE THIS ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'CLICK THE TRASHCAN ONE MORE TIME TO DELETE THIS ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'DELETED ${kind}';
	@override String get timeControl => 'TIME';
	@override String get radioControl => 'RADIO';
	@override String get powerControl => 'POWER';
	@override String get notesControl => 'NOTES';
	@override String get power => 'POWER';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'LOGGING CONTROLS';
	@override String get spottingControl => 'SPOTTING';
	@override String get spottingSelfControl => 'SELF-SPOTTING';
	@override String spotSelfAt({required Object freq}) => 'SELF-SPOT AT ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'SPOT ${call} AT ${freq}';
	@override String spotTooLate({required Object call}) => 'TOO LATE TO SPOT ${call}';
	@override String get spotNoFreq => 'FIRST SET A FREQUENCY TO SPOT';
	@override String get spotComment => 'COMMENT';
	@override String get spottingAutoControl => 'AUTO RE-SPOT';
	@override String spotAutoEvery({required Object minutes}) => 'RE-SPOT EVERY ${minutes} MIN';
	@override String spotAutoNext({required Object time}) => 'AUTO IN ${time}. STOP?';
	@override String spotAutoInMinutes({required Object minutes}) => 'AUTO IN ${minutes}M';
	@override String spotAutoInSeconds({required Object seconds}) => 'AUTO IN ${seconds}S';
	@override String spotAutoInCount({required Object seconds}) => 'AUTO IN ${seconds}';
	@override String get spotAutoNotStarted => 'AUTO RE-SPOT NOT STARTED: THE SPOT DID NOT GO THROUGH';
	@override String get spotAutoMoved => 'AUTO RE-SPOT NOT STARTED: THE FREQUENCY CHANGED WHILE SPOTTING';
	@override String get spotAutoStopped => 'AUTO RE-SPOT STOPPED';
	@override String get spotAutoLeftFreq => 'AUTO RE-SPOT STOPPED: THE FREQUENCY CHANGED';
	@override String get spotAutoNoFreq => 'AUTO RE-SPOT STOPPED: THE RADIO REPORTS NO FREQUENCY';
	@override String get spotBusy => 'ANOTHER SPOT IS STILL BEING SENT';
	@override String get bandOrFreqRequired => 'SET A FREQUENCY OR BAND BEFORE LOGGING';
	@override String get missingBand => 'NO BAND';
	@override String get missingMode => 'NO MODE';
	@override String saveFailed({required Object error}) => 'COULD NOT SAVE: ${error}';
	@override String deleteFailed({required Object error}) => 'COULD NOT DELETE: ${error}';
	@override late final _Translations$loggingControls$info$qro info = _Translations$loggingControls$info$qro._(_root);
}

// Path: formChrome
class _Translations$formChrome$qro extends Translations$formChrome$en {
	_Translations$formChrome$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(UNTITLED)';
	@override String get showMore => 'SHOW MORE';
	@override String get showAll => 'SHOW ALL';
	@override String get showFewer => 'SHOW FEWER';
	@override String get defaults => 'DEFAULTS';
	@override String get search => 'SEARCH';
	@override String get clear => 'CLEAR';
	@override String get openPage => 'OPEN PAGE';
	@override String get connected => 'CONNECTED';
	@override String get notConnected => 'NOT CONNECTED';
	@override String get manage => 'MANAGE';
	@override String get connect => 'CONNECT';
	@override String get formTitle => 'FORM';
	@override String addItem({required Object label}) => 'ADD ${label}';
	@override String editItem({required Object label}) => 'EDIT ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'SHOWING ${shown} OF ${total} (${selected} SELECTED)';
	@override String validationError({required Object error}) => 'VALIDATION ERROR: ${error}';
	@override String transformationError({required Object error}) => 'TRANSFORMATION ERROR: ${error}';
	@override String actionError({required Object error}) => 'ERROR: ${error}';
	@override String get removeItem => 'DELETE';
	@override String deleteItemTitle({required Object name}) => 'DELETE ${name}?';
	@override String get storageUnavailable => 'LOGINS UNAVAILABLE';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$qro extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'EDIT QSO';
	@override String get operatorCall => 'OPERATOR';
	@override String get position => 'POSITION';
	@override String get theirName => 'NAME';
	@override String get theirGrid => 'GRID';
	@override String get theirState => 'STATE';
	@override String get band => 'BAND';
	@override String get notes => 'NOTES';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'THEIR INFO';
	@override String get sectionOur => 'OUR INFO';
	@override String get sectionNotes => 'NOTES';
	@override String get theirCity => 'CITY';
	@override String get theirCounty => 'COUNTY';
	@override String get theirEntity => 'ENTITY';
	@override String get theirCqZone => 'CQ ZONE';
	@override String get theirItuZone => 'ITU ZONE';
	@override String get theirArrlSection => 'ARRL SECTION';
	@override String get theirLat => 'LATITUDE';
	@override String get theirLon => 'LONGITUDE';
	@override String get theirPower => 'THEIR POWER';
}

// Path: qsoList
class _Translations$qsoList$qro extends Translations$qsoList$en {
	_Translations$qsoList$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get empty => 'NO QSOS YET — WORK SOMEONE!';
	@override String get bandOrModeWarning => 'PLEASE MAKE SURE YOUR BAND AND MODE ARE CORRECT';
	@override String get today => 'TODAY';
	@override String get yesterday => 'YESTERDAY';
	@override String get tomorrow => 'TOMORROW';
	@override late final _Translations$qsoList$find$qro find = _Translations$qsoList$find$qro._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$qro extends Translations$loggingPanel$en {
	_Translations$loggingPanel$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get stats => 'OPERATION STATS';
	@override String get scoring => 'SCORING';
	@override String get dxccEntities => 'DXCC ENTITIES';
	@override String get statesWorked => 'STATES';
	@override String get provincesWorked => 'PROVINCES';
	@override String get duplicates => 'DUPLICATES';
}

// Path: callInfo
class _Translations$callInfo$qro extends Translations$callInfo$en {
	_Translations$callInfo$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'SHOW IMAGE';
	@override String get imageUnavailable => 'PHOTO UNAVAILABLE';
	@override String get photo => 'PHOTO';
	@override String get notes => 'NOTES';
	@override String distanceTo({required Object distance}) => '${distance} TO';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) TO';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) TO';
	@override String distanceAway({required Object distance}) => '${distance} AWAY';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) AWAY';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) AWAY';
	@override String get thisOpCountOne => '1 QSO IN THIS OPERATION';
	@override String thisOpCountOther({required Object count}) => '${count} QSOS IN THIS OPERATION';
	@override String get otherOpsCountOne => '1 QSO IN OTHER OPERATIONS';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOS IN OTHER OPERATIONS';
	@override String andMore({required Object count}) => '… AND ${count} MORE';
	@override String withCall({required Object call}) => 'WITH ${call}';
	@override String fromOperation({required Object where}) => 'FROM ${where}';
	@override late final _Translations$callInfo$history$qro history = _Translations$callInfo$history$qro._(_root);
}

// Path: settings
class _Translations$settings$qro extends Translations$settings$en {
	_Translations$settings$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SETTINGS';
	@override String get language => 'LANGUAGE';
	@override String languageSystem({required Object language}) => 'FOLLOW SYSTEM SETTINGS (${language})';
	@override late final _Translations$settings$theme$qro theme = _Translations$settings$theme$qro._(_root);
	@override late final _Translations$settings$themeDescription$qro themeDescription = _Translations$settings$themeDescription$qro._(_root);
	@override String get fontScale => 'FONT SCALE';
	@override late final _Translations$settings$fontScaleOpts$qro fontScaleOpts = _Translations$settings$fontScaleOpts$qro._(_root);
	@override late final _Translations$settings$keepDeviceAwake$qro keepDeviceAwake = _Translations$settings$keepDeviceAwake$qro._(_root);
	@override String get layoutDensity => 'LAYOUT DENSITY';
	@override late final _Translations$settings$layoutDensityOpts$qro layoutDensityOpts = _Translations$settings$layoutDensityOpts$qro._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'THE WINDOW IS TOO SHORT, USING ${effective}';
	@override String get layoutDensityAtLimit => 'AS FAR AS IT GOES';
	@override String get distanceUnits => 'DISTANCE UNITS';
	@override late final _Translations$settings$distanceUnitsOpts$qro distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$qro._(_root);
	@override String get userInterface => 'USER INTERFACE';
	@override late final _Translations$settings$logging$qro logging = _Translations$settings$logging$qro._(_root);
	@override late final _Translations$settings$catServer$qro catServer = _Translations$settings$catServer$qro._(_root);
	@override late final _Translations$settings$cluster$qro cluster = _Translations$settings$cluster$qro._(_root);
	@override late final _Translations$settings$spotting$qro spotting = _Translations$settings$spotting$qro._(_root);
	@override late final _Translations$settings$radio$qro radio = _Translations$settings$radio$qro._(_root);
	@override late final _Translations$settings$help$qro help = _Translations$settings$help$qro._(_root);
	@override late final _Translations$settings$exports$qro exports = _Translations$settings$exports$qro._(_root);
	@override late final _Translations$settings$extensionSections$qro extensionSections = _Translations$settings$extensionSections$qro._(_root);
	@override late final _Translations$settings$map$qro map = _Translations$settings$map$qro._(_root);
	@override late final _Translations$settings$privacy$qro privacy = _Translations$settings$privacy$qro._(_root);
	@override String get operatorCall => 'OPERATOR CALLSIGN';
	@override late final _Translations$settings$sync$qro sync = _Translations$settings$sync$qro._(_root);
	@override late final _Translations$settings$peers$qro peers = _Translations$settings$peers$qro._(_root);
	@override String get developerMode => 'DEVELOPER MODE';
	@override late final _Translations$settings$syncPanel$qro syncPanel = _Translations$settings$syncPanel$qro._(_root);
	@override late final _Translations$settings$accounts$qro accounts = _Translations$settings$accounts$qro._(_root);
	@override late final _Translations$settings$station$qro station = _Translations$settings$station$qro._(_root);
	@override late final _Translations$settings$offlineData$qro offlineData = _Translations$settings$offlineData$qro._(_root);
	@override late final _Translations$settings$profiles$qro profiles = _Translations$settings$profiles$qro._(_root);
	@override late final _Translations$settings$search$qro search = _Translations$settings$search$qro._(_root);
	@override late final _Translations$settings$developer$qro developer = _Translations$settings$developer$qro._(_root);
	@override late final _Translations$settings$about$qro about = _Translations$settings$about$qro._(_root);
	@override late final _Translations$settings$panels$qro panels = _Translations$settings$panels$qro._(_root);
	@override String get showMoreSettings => 'SHOW MORE SETTINGS';
	@override String get numberFormat => 'NUMBER FORMATTING';
	@override late final _Translations$settings$numberFormatOpts$qro numberFormatOpts = _Translations$settings$numberFormatOpts$qro._(_root);
	@override late final _Translations$settings$numberFormatDescription$qro numberFormatDescription = _Translations$settings$numberFormatDescription$qro._(_root);
	@override late final _Translations$settings$numberFormatSeparators$qro numberFormatSeparators = _Translations$settings$numberFormatSeparators$qro._(_root);
	@override String get gridPrecision => 'GRID PRECISION';
	@override late final _Translations$settings$gridPrecisionOpts$qro gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$qro._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$qro gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$qro._(_root);
}

// Path: commands
class _Translations$commands$qro extends Translations$commands$en {
	_Translations$commands$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'ENABLE SYNC IN SETTINGS FIRST.';
	@override String get fullResyncStarted => 'FULL RESYNC STARTED — LOCAL DATA WAS BACKED UP FIRST.';
	@override String noDataFilesMatched({required Object target}) => 'NO DATA FILES MATCHED "${target}".';
	@override String reloadFailed({required Object error}) => 'RELOAD FAILED: ${error}';
	@override String get reloadingAll => 'RELOADING ALL DATA FILES…';
	@override String reloadingTarget({required Object target}) => 'RELOADING ${target} DATA FILES…';
	@override String unknownExperiment({required Object token}) => 'UNKNOWN EXPERIMENT "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} ENABLED';
	@override String experimentDisabled({required Object name}) => '${name} DISABLED';
	@override String get sentryTestSent => 'TEST ERROR REPORT SENT TO SENTRY';
	@override String get idleMetricsEnabled => 'IDLE METRICS ENABLED IN THE STATUS BAR';
	@override String get idleMetricsDisabled => 'IDLE METRICS DISABLED';
	@override String get sentryTestLocalOnly => 'SENTRY IS DISABLED IN THIS BUILD — TEST ERROR LOGGED LOCALLY ONLY';
	@override String get noOperationOpen => 'THAT COMMAND NEEDS AN OPEN OPERATION';
	@override String unknownSegmentKind({required Object kind}) => 'DON\'T KNOW HOW TO MARK A \'${kind}\'';
	@override String goUnavailable({required Object place}) => '${place} ISN\'T TURNED ON IN THIS APP';
	@override String goUnknown({required Object to}) => 'DON\'T KNOW HOW TO GO TO \'${to}\'';
	@override String get goBlocked => 'CLOSE THE OPEN DIALOG FIRST';
	@override String get operationAlreadyStarted => 'THIS OPERATION ALREADY HAS A START MARKER';
	@override String get couldNotOpenLocation => 'ADDED THE BREAK, BUT COULD NOT OPEN THE LOCATION SCREEN';
	@override String get noTestOperations => 'NO TEST OPERATIONS TO PURGE';
	@override String get purgeTestsUnavailable => 'PURGETESTS NEEDS TO SHOW A CONFIRMATION DIALOG, WHICH ISN\'T AVAILABLE HERE';
	@override String get syncAllUnavailable => 'SYNCALL NEEDS TO SHOW A CONFIRMATION DIALOG, WHICH ISN\'T AVAILABLE HERE';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'PURGED ${count} TEST OPERATION',
		other: 'PURGED ${count} TEST OPERATIONS',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'PURGED ${purged} OF ${total} TEST OPERATIONS — THE REST FAILED; TRY PURGETESTS AGAIN';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'PURGED ${count} TEST CONTACT WITH NO OPERATION',
		other: 'PURGED ${count} TEST CONTACTS WITH NO OPERATION',
	);
	@override String get purgeTestsContactsFailed => 'PURGED THE TEST OPERATIONS, BUT THE TEST CONTACTS WITH NO OPERATION FAILED; TRY PURGETESTS AGAIN';
	@override String get purgeTestsNothingToDo => 'NOTHING WAS PURGED';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'REMOVED ${removed} OF ${total} TEST OPERATIONS — THE REST FAILED; TRY REVIEW AGAIN';
	@override String get receivedPurgesFailed => 'COULDN\'T REMOVE THOSE TEST OPERATIONS — TRY REVIEW AGAIN';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} TEST OPERATION WAS REMOVED ON ANOTHER DEVICE',
		other: '${count} TEST OPERATIONS WERE REMOVED ON ANOTHER DEVICE',
	);
	@override String get receivedPurgesReview => 'REVIEW';
	@override String get settingOn => 'ON';
	@override String get settingOff => 'OFF';
	@override String get settingEmpty => '(EMPTY)';
	@override String get settingSecretSet => '(SET)';
	@override String get settingSecretUnset => '(NOT SET)';
	@override String settingSelectedCount({required Object count}) => '${count} SELECTED';
	@override String get settingExpectsOnOff => 'ON OR OFF';
	@override String settingExpectsOneOf({required Object choices}) => 'ONE OF: ${choices}';
	@override String get settingExpectsNumber => 'A NUMBER';
	@override String settingVanished({required Object label}) => '“${label}” IS NO LONGER AVAILABLE';
	@override String get noCwKeyer => 'NO CONNECTED RADIO CAN KEY CW';
	@override String get noKeyer => 'NO CONNECTED RADIO CAN KEY CW OR PLAY VOICE MEMORIES';
	@override String get keyerNeedsOperation => 'OPEN AN OPERATION TO USE THE CW KEYER';
	@override String get keyerExperimentOff => 'CW KEYING IS OFF — TURN IT ON WITH EXP KEYER';
	@override String get esmExperimentOff => 'ENTER SENDS MESSAGES IS OFF — TURN IT ON WITH EXP ESM';
	@override String cwSending({required Object text}) => 'SENDING CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW MESSAGE F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW MESSAGE F${n} WAS NOT SENT: THE EXTENSIONS ARE NOT READY';
	@override String settingNotStored({required Object label}) => '“${label}” DID NOT ACCEPT THAT VALUE';
}

// Path: commandDialog
class _Translations$commandDialog$qro extends Translations$commandDialog$en {
	_Translations$commandDialog$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get hint => 'SEARCH CALLSIGNS OR TYPE A COMMAND';
	@override String noResults({required Object text}) => 'NOTHING MATCHES “${text}”';
	@override String get sectionCommands => 'COMMANDS';
	@override String get sectionGoTo => 'GO TO';
	@override String get sectionOperations => 'OPERATIONS';
	@override String get goHome => 'HOME';
	@override String get goSettings => 'SETTINGS';
	@override String get goNewOperation => 'NEW OPERATION';
	@override String runTyped({required Object text}) => 'RUN “${text}”';
	@override String get sectionSuggestions => 'TRY';
	@override String get lookingUp => 'LOOKING UP CALLSIGN…';
	@override String get blockedByPane => 'CANNOT USE COMMANDS WHILE A PANEL OR DIALOG IS OPEN';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$qro extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'KEYBOARD SHORTCUTS';
	@override String get description => 'CUSTOMIZE KEY MAPPINGS';
	@override String get search => 'SEARCH COMMANDS AND KEYS';
	@override String get import => 'IMPORT…';
	@override String get export => 'EXPORT…';
	@override String get resetAll => 'RESET ALL';
	@override String get resetAllTitle => 'RESET EVERY SHORTCUT?';
	@override String get resetAllBody => 'EVERY COMMAND GOES BACK TO ITS DEFAULT KEYS, AND THE KEYS BOUND TO TYPED COMMANDS ARE REMOVED.';
	@override String get reset => 'RESET';
	@override String get noKey => 'NO KEY';
	@override String get changed => 'CHANGED';
	@override String conflict({required Object keys, required Object commands}) => '${keys} IS ALSO BOUND TO ${commands}';
	@override String get groupApp => 'APP';
	@override String get groupKeying => 'KEYING';
	@override String get groupLogging => 'LOGGING';
	@override String get groupCommands => 'COMMANDS';
	@override String get groupFixed => 'FIXED KEYS';
	@override String get contextApp => 'ANYWHERE';
	@override String get contextLogView => 'OPERATION, CHASING AND LOGS VIEWS';
	@override String get contextOperation => 'OPERATION VIEW, KEYING A CAT RADIO';
	@override String get contextLogging => 'IN THE LOGGING PANEL';
	@override String get addCommand => 'ADD A COMMAND…';
	@override String unknownCommand({required Object command}) => 'UNKNOWN COMMAND: ${command}';
	@override late final _Translations$keyboardShortcuts$command$qro command = _Translations$keyboardShortcuts$command$qro._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$qro fixed = _Translations$keyboardShortcuts$fixed$qro._(_root);
	@override late final _Translations$keyboardShortcuts$editor$qro editor = _Translations$keyboardShortcuts$editor$qro._(_root);
	@override late final _Translations$keyboardShortcuts$file$qro file = _Translations$keyboardShortcuts$file$qro._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$qro modifier = _Translations$keyboardShortcuts$modifier$qro._(_root);
	@override late final _Translations$keyboardShortcuts$platform$qro platform = _Translations$keyboardShortcuts$platform$qro._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$qro extends Translations$expiredBuild$en {
	_Translations$expiredBuild$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'THIS BUILD HAS EXPIRED';
	@override String get body => 'PLEASE VISIT HAM2K.COM AND GET A NEWER VERSION.';
	@override String get visit => 'VISIT HAM2K.COM';
	@override String get dismiss => 'CONTINUE ANYWAY';
}

// Path: staleness
class _Translations$staleness$qro extends Translations$staleness$en {
	_Translations$staleness$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'AN IMPORTANT UPDATE IS WAITING';
	@override String get codePushFloorBody => 'THIS VERSION HAS A FIX YOU DON\'T HAVE YET.';
	@override String get restartToApply => 'RESTART THE APP TO APPLY IT.';
	@override String get quitAndReopen => 'QUIT THE APP AND OPEN IT AGAIN TO APPLY IT.';
	@override String get reopenToApply => 'CLOSE THE APP AND OPEN IT AGAIN TO APPLY IT.';
	@override String get ignoreForNow => 'IGNORE FOR NOW';
}

// Path: spotting
class _Translations$spotting$qro extends Translations$spotting$en {
	_Translations$spotting$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'NO QSO LOGGED YET TO SPOT.';
	@override String get setFrequencyFirst => 'SET A FREQUENCY FIRST.';
	@override String get nothingToSpot => 'NOTHING TO SPOT — NO EXTENSION OFFERS SPOTTING HERE.';
	@override String get incompleteCall => 'CAN\'T SPOT AN INCOMPLETE CALL — FINISH THE CALLSIGN FIRST.';
	@override String spotFailed({required Object source, required Object message}) => '${source} FAILED: ${message}';
	@override String get unknownError => 'UNKNOWN ERROR';
	@override String get notSent => 'SPOT NOT SENT.';
	@override String get allSkipped => 'SPOT NOT SENT: EVERY SPOT SOURCE SKIPPED IT.';
	@override String get notRefreshedOffline => 'NO CONNECTION — SPOTS WERE NOT REFRESHED';
}

// Path: dataFiles
class _Translations$dataFiles$qro extends Translations$dataFiles$en {
	_Translations$dataFiles$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'DOWNLOADING…';
	@override String downloadFailedTitle({required Object name}) => 'COULDN\'T DOWNLOAD ${name}';
	@override String get downloadFailedWebHint => 'THIS COULD BE A NETWORK ISSUE, OR THIS LINK\'S HOST MAY NOT SUPPORT DIRECT DOWNLOADS FROM A WEB BROWSER. TRY THE DESKTOP OR MOBILE APP, OR A DIFFERENT HOSTING LOCATION.';
	@override String get downloadTimedOut => 'THE SERVER TOOK TOO LONG TO RESPOND. TRY AGAIN LATER.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} ANSWERED WITH AN ERROR (HTTP ${status}). TRY AGAIN LATER.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} COULDN\'T PROVIDE THIS FILE (HTTP ${status}). CHECK THAT ITS ADDRESS IS STILL RIGHT.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM HAS NO CALL HISTORY FILE FOR ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'N1MM\'S CALL HISTORY DOWNLOAD FOR ${stem} DIDN\'T WORK. TRY AGAIN LATER.';
	@override String processingFailedTitle({required Object name}) => 'COULDN\'T PROCESS ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'THE DOWNLOAD HAD ONLY ${imported} OF THE ${existing} RECORDS ON THIS DEVICE, SO THE ONES IT LEFT OUT WERE KEPT. REFRESHING IT IN SETTINGS › OFFLINE DATA ACCEPTS IT ANYWAY.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'IMPORTED ${count} RECORD FOR ${label}.',
		other: 'IMPORTED ${count} RECORDS FOR ${label}.',
	);
	@override String importedData({required Object label}) => 'IMPORTED DATA FOR ${label}.';
	@override String get cleanedUpTitle => 'CLEANED UP EXTENSION DATA';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'REMOVED DATA FOR ${count} DATA FILE FROM DISABLED EXTENSIONS.',
		other: 'REMOVED DATA FOR ${count} DATA FILES FROM DISABLED EXTENSIONS.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} RECORDS';
	@override String get definitionUnavailable => 'THE FILE\'S SOURCE DIDN\'T PROVIDE A DEFINITION — ITS EXTENSION MAY BE MID-RESTART OR MISCONFIGURED. TRY AGAIN IN A MOMENT.';
}

// Path: updates
class _Translations$updates$qro extends Translations$updates$en {
	_Translations$updates$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'UPDATE AVAILABLE';
	@override String newVersionAvailable({required Object version}) => 'A NEW VERSION (${version}) IS AVAILABLE.';
	@override String get getIt => 'GET IT';
	@override String get ok => 'OK';
	@override String get updateReady => 'UPDATE READY';
	@override String get restartToApply => 'AN UPDATE HAS BEEN DOWNLOADED. RESTART TO APPLY IT.';
	@override String get appliesNextLaunch => 'AN UPDATE HAS BEEN DOWNLOADED. IT WILL APPLY THE NEXT TIME YOU OPEN THE APP.';
	@override String get restartNow => 'RESTART NOW';
	@override String get reloadToUpdate => 'A NEWER VERSION OF THIS PAGE IS AVAILABLE. RELOAD TO GET IT.';
	@override String get reloadNow => 'RELOAD NOW';
	@override String get checkForUpdates => 'CHECK FOR UPDATES';
	@override String get checkingForUpdates => 'CHECKING FOR UPDATES…';
	@override String get upToDate => 'UP TO DATE';
	@override String get automaticChecks => 'CHECK AUTOMATICALLY';
	@override String get automaticChecksDescription => 'LOOK FOR NEW VERSIONS IN THE BACKGROUND, FROM THE NEXT TIME YOU START THE APP';
}

// Path: extensionService
class _Translations$extensionService$qro extends Translations$extensionService$en {
	_Translations$extensionService$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'EXTENSION RUNTIME NOT READY.';
	@override String testFailed({required Object error}) => 'TEST FAILED: ${error}';
	@override String connectedAs({required Object identity}) => 'CONNECTED AS ${identity}';
	@override String get invalidFieldConfiguration => 'INVALID FIELD CONFIGURATION';
	@override String get invalidValue => 'INVALID VALUE';
	@override String validationError({required Object error}) => 'VALIDATION ERROR: ${error}';
	@override String actionFailed({required Object error}) => 'ACTION FAILED: ${error}';
	@override String get commandFailed => 'THE COMMAND FAILED TO RUN';
	@override String get reportUnavailable => 'REPORTS CAN\'T BE SENT RIGHT NOW';
	@override String get stashUnavailable => 'HAM2K’S FILE STASH CAN’T BE REACHED RIGHT NOW';
	@override String timersSuspendedBudget({required Object name}) => '${name} SPENT TOO MUCH TIME IN ITS TIMERS. THEY\'RE STOPPED UNTIL THE EXTENSIONS RESTART.';
	@override String timersSuspendedFailures({required Object name}) => '${name}\'S TIMERS KEPT FAILING. THEY\'RE STOPPED UNTIL THE EXTENSIONS RESTART.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} GOT STUCK IN A TIMER. ITS TIMERS ARE STOPPED UNTIL THE EXTENSIONS RESTART.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$qro extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'OPERATION LOCATION';
	@override String get selectedLocation => 'SELECTED LOCATION';
	@override String get gridSquare => 'MAIDENHEAD GRID SQUARE LOCATOR';
	@override String get gridInvalid => 'NEEDS 4, 6, 8 OR 10 CHARACTERS, LIKE FN31PR';
	@override String get suggestedLocations => 'SUGGESTED LOCATIONS';
	@override String get deviceGps => 'DEVICE GPS';
	@override String peerGps({required Object device}) => 'GPS FROM ${device}';
	@override String get locating => 'LOCATING…';
	@override String get gpsUnavailable => 'LOCATION UNAVAILABLE';
	@override String get permissionDenied => 'LOCATION PERMISSION DENIED';
	@override String get permissionBlocked => 'LOCATION PERMISSION BLOCKED';
	@override String get moreDetails => 'MORE DETAILS';
	@override String get stateOrProvince => 'STATE OR PROVINCE (OPTIONAL)';
	@override String get controlsUnavailableTitle => 'ACTIVITY CONTROLS UNAVAILABLE';
	@override String get controlsUnavailableReason => 'THESE REFERENCES ARE STILL USABLE; THEIR ACTIVITIES JUST COULD NOT BE REACHED.';
	@override String get controlsUnavailableRetry => 'RETRY';
	@override String get county => 'COUNTY (OPTIONAL)';
}

// Path: versionLabel
class _Translations$versionLabel$qro extends Translations$versionLabel$en {
	_Translations$versionLabel$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'VERSION ${version}';
	@override String patch({required Object patch}) => 'PATCH ${patch}';
	@override String build({required Object build}) => 'BUILD ${build}';
}

// Path: notices
class _Translations$notices$qro extends Translations$notices$en {
	_Translations$notices$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'NO NOTICES YET';
	@override String get webStorageInMemory => 'THIS BROWSER COULD NOT PROVIDE PERSISTENT STORAGE — THE LOG LIVES IN MEMORY ONLY AND WILL BE LOST WHEN THIS TAB CLOSES. USE A CURRENT CHROME, FIREFOX, SAFARI OR EDGE.';
	@override String get webStorageUnreliable => 'THIS BROWSER IS USING FALLBACK STORAGE THAT IS NOT SAFE WITH MULTIPLE TABS — KEEP A SINGLE TAB OPEN, AND KEEP SYNC ON.';
	@override String get logFromNewerBuildTitle => 'THIS LOG NEEDS A NEWER VERSION';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'YOUR LOG WAS WRITTEN BY A NEWER VERSION OF HALO (STORAGE VERSION ${storage}; THIS ONE UNDERSTANDS ${understood}), SO IT CANNOT BE OPENED, AND NEW CONTACTS WILL NOT BE SAVED. INSTALL THE NEWER VERSION AGAIN — OR, IF YOU MEANT TO RUN THIS BUILD, POINT IT AT A DIFFERENT DATA FOLDER. THE LOG IS IN ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'YOUR LOG WAS WRITTEN BY A NEWER VERSION OF HALO (STORAGE VERSION ${storage}; THIS ONE UNDERSTANDS ${understood}), SO IT CANNOT BE OPENED, AND NEW CONTACTS WILL NOT BE SAVED. OPEN THIS LOG WITH THAT NEWER VERSION INSTEAD.';
	@override String get preferencesRestoredTitle => 'SETTINGS RESTORED FROM A BACKUP';
	@override String get preferencesRestored => 'THE SETTINGS FILE COULD NOT BE READ, SO HALO RESTORED THE LAST GOOD COPY OF IT. ANYTHING YOU CHANGED IN YOUR PREVIOUS SESSION MAY NEED SETTING AGAIN. THE UNREADABLE FILE IS KEPT ALONGSIDE IT, NAMED SHARED_PREFERENCES.CORRUPT-….JSON.';
	@override String get preferencesResetTitle => 'SETTINGS RESET';
	@override String get preferencesReset => 'THE SETTINGS FILE COULD NOT BE READ AND THERE WAS NO BACKUP TO FALL BACK ON, SO HALO STARTED WITH ITS DEFAULTS. THE UNREADABLE FILE IS KEPT IN THE APP\'S DATA FOLDER, NAMED SHARED_PREFERENCES.CORRUPT-….JSON.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} WAS NOT CONNECTED AUTOMATICALLY';
	@override String autoConnectHeld({required Object name}) => 'HALO STOPPED RESPONDING THE LAST TIME IT STARTED CONNECTING TO ${name}, SO IT LEFT IT ALONE THIS TIME RATHER THAN RISK DOING IT AGAIN. CHECK THAT THE RADIO IS SWITCHED ON AND ITS CABLE IS PLUGGED IN, THEN PRESS CONNECT ON IT IN SETTINGS.';
}

// Path: syncAccount
class _Translations$syncAccount$qro extends Translations$syncAccount$en {
	_Translations$syncAccount$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'ANONYMOUS ACCOUNT (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (PENDING CONFIRMATION)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (PENDING CONFIRMATION - #${id})';
}

// Path: deepLink
class _Translations$deepLink$qro extends Translations$deepLink$en {
	_Translations$deepLink$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'START AN OPERATION FIRST, THEN SEND THAT CONTACT AGAIN';
	@override String get waitingInOperation => 'THAT CONTACT IS WAITING IN THE OPERATION BEHIND THIS SCREEN';
	@override String unknownActivities({required Object refs}) => 'THIS DEVICE HAS NO ACTIVITY FOR ${refs}, SO THOSE REFERENCES WERE LEFT OFF';
	@override String activitiesUnavailable({required Object refs}) => 'COULD NOT REACH YOUR ACTIVITIES, SO ${refs} WAS LEFT OFF — TRY THAT LINK AGAIN';
}

// Path: confirmDevice
class _Translations$confirmDevice$qro extends Translations$confirmDevice$en {
	_Translations$confirmDevice$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CONFIRM A DEVICE';
	@override String get codePrompt => 'ENTER THE CODE SHOWN ON THE DEVICE THAT WANTS TO JOIN THIS ACCOUNT.';
	@override String get code => 'CODE';
	@override String get lookUp => 'LOOK UP';
	@override String get codeNotFound => 'NO REQUEST MATCHES THAT CODE. CODES EXPIRE AFTER 10 MINUTES — ASK THE OTHER DEVICE FOR A FRESH ONE.';
	@override String get linkExpired => 'THAT LINK HAS EXPIRED. ASK THE OTHER DEVICE TO SHOW A NEW QR CODE.';
	@override String areYouSure({required Object device}) => 'LINK ${device} TO THIS ACCOUNT?';
	@override String get unnamedDevice => 'AN UNNAMED DEVICE';
	@override String get grantWarning => 'IT WILL BE ABLE TO READ AND CHANGE EVERY OPERATION AND QSO IN THIS ACCOUNT.';
	@override String get needsSyncTitle => 'THIS DEVICE DOES NOT SYNC YET';
	@override String get needsSyncText => 'TURN ON HAM2K LOG FILER SYNC AND LINK THIS DEVICE TO AN ACCOUNT BEFORE IT CAN ADMIT ANOTHER ONE.';
	@override String get malformedRequest => 'THE SYNC SERVER SENT A REQUEST THIS APP COULD NOT READ. ASK THE OTHER DEVICE TO TRY AGAIN.';
	@override String get linkIt => 'LINK DEVICE';
}

// Path: switchAccounts
class _Translations$switchAccounts$qro extends Translations$switchAccounts$en {
	_Translations$switchAccounts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'NO ACCOUNT DETAILS YET';
	@override String get currentAccount => 'CURRENT ACCOUNT';
	@override String get otherAccounts => 'OTHER ACCOUNTS';
	@override String get linkToAnother => 'LINK TO ANOTHER ACCOUNT';
	@override String get linkWithSibling => 'LINK WITH OTHER HAM2K APP';
	@override String get linkWithPolo => 'LINK WITH ACCOUNT IN OLDER VERSION';
	@override String get linkWithSiblingDescription => 'YOU HAVE ANOTHER HAM2K APP INSTALLED. LINK WITH THE ACCOUNT IN USE THERE.';
	@override String siblingPrompt({required Object app}) => 'APPROVE THE REQUEST IN ${app}, THEN COME BACK HERE.';
	@override String openSiblingAgain({required Object app}) => 'OPEN ${app} AGAIN';
	@override String get siblingNoGrant => 'DIDN\'T WORK? OPEN IT AGAIN, OR GO BACK AND LINK ANOTHER WAY.';
	@override String siblingOpenFailed({required Object app}) => 'COULD NOT OPEN ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'THE LINK EXPIRED AND A NEW ONE IS READY — OPEN ${app} AGAIN.';
	@override String get tryAgain => 'TRY AGAIN';
	@override String get linkWithQr => 'LINK WITH A QR CODE';
	@override String get linkWithQrDescription => 'SCAN IT FROM A DEVICE ALREADY USING THE ACCOUNT';
	@override String get linkWithEmail => 'LINK WITH AN EMAIL ADDRESS';
	@override String get linkWithEmailDescription => 'CONFIRM WITH A CODE OR AN EMAIL LINK';
	@override String get enterEmailPrompt => 'ENTER THE EMAIL ADDRESS OF THE ACCOUNT YOU WANT THIS DEVICE TO USE.';
	@override String get emailAddress => 'EMAIL ADDRESS';
	@override String get linkAccount => 'LINK ACCOUNT';
	@override String get copiedCode => 'COPIED CODE TO CLIPBOARD';
	@override String get copyCode => 'COPY CODE';
	@override String codePrompt({required Object email}) => 'OPEN THE HAM2K APP ON A DEVICE ALREADY LINKED WITH ${email} AND ENTER THIS CODE TO APPROVE THE REQUEST:';
	@override String get waitingForConfirmation => 'WAITING FOR CONFIRMATION…';
	@override String get sendEmailInstead => 'SEND A CONFIRMATION EMAIL INSTEAD';
	@override String emailSent({required Object email}) => 'AN EMAIL WAS SENT TO ${email}. OPEN IT AND CONFIRM THE REQUEST TO LINK THIS DEVICE.';
	@override String get resendEmail => 'RESEND EMAIL';
	@override String get qrPrompt => 'SCAN THIS QR CODE FROM A DEVICE ALREADY LINKED TO THE ACCOUNT YOU WANT — FOR EXAMPLE WITH HAM2K PORTABLE LOGGER ON YOUR PHONE.';
	@override String get serverUnreachable => 'COULD NOT REACH THE SYNC SERVER. TRY AGAIN LATER.';
	@override String get emailRequired => 'ENTER AN EMAIL ADDRESS TO LINK.';
	@override String noAccountForEmail({required Object email}) => 'NO ACCOUNT FOUND FOR ${email}.';
	@override String serverRejected({required Object error}) => 'THE SYNC SERVER REJECTED THE REQUEST: ${error}';
	@override String get noLinkCode => 'THE SYNC SERVER DID NOT RETURN A LINK CODE. TRY AGAIN LATER.';
	@override String get noConfirmationCode => 'THE SYNC SERVER DID NOT SEND A CONFIRMATION CODE. TRY AGAIN LATER.';
	@override String get switchNotAccepted => 'THAT ACCOUNT DID NOT ACCEPT THE SWITCH. TRY LINKING IT WITH AN EMAIL ADDRESS INSTEAD.';
	@override String get requestFailed => 'SOMETHING WENT WRONG TALKING TO THE SYNC SERVER. TRY AGAIN LATER.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} QSO',
		other: '${count} QSOS',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} OPERATION',
		other: '${count} OPERATIONS',
	);
}

// Path: qsonImport
class _Translations$qsonImport$qro extends Translations$qsonImport$en {
	_Translations$qsonImport$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'IMPORT QSON OPERATION';
	@override String get description => 'CREATE A NEW OPERATION FROM A QSON FILE, AS DEVELOPER MODE EXPORTS ONE HERE OR IN POLO.';
	@override String get dropHint => 'DROP A QSON FILE TO IMPORT IT AS A NEW OPERATION';
	@override String importing({required Object filename}) => 'IMPORTING ${filename}…';
	@override String failed({required Object filename, required Object error}) => 'COULD NOT IMPORT ${filename}: ${error}';
	@override String pickerFailed({required Object error}) => 'COULD NOT OPEN A FILE TO IMPORT: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} IS NOT UTF-8 TEXT, SO IT IS NOT A QSON FILE';
	@override String notJson({required Object filename}) => '${filename} IS NOT A JSON FILE, SO IT IS NOT A QSON FILE';
	@override String notOperation({required Object filename}) => '${filename} DOES NOT HOLD A QSON OPERATION';
	@override String get busy => 'AN IMPORT IS ALREADY RUNNING. WAIT FOR IT TO FINISH BEFORE STARTING ANOTHER.';
	@override String get oneFileOnly => 'DROP ONE QSON FILE AT A TIME — EACH ONE OPENS AS ITS OWN OPERATION.';
}

// Path: adifImport
class _Translations$adifImport$qro extends Translations$adifImport$en {
	_Translations$adifImport$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'IMPORT QSOS FROM ADIF';
	@override String reading({required Object filename}) => 'READING ${filename}…';
	@override String get dropHint => 'DROP AN ADIF FILE TO IMPORT';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} QSO IN THIS FILE',
		other: '${formatted} QSOS IN THIS FILE',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} ALREADY IN YOUR LOG',
		other: '${formatted} ALREADY IN YOUR LOG',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} WILL BE IMPORTED',
		other: '${formatted} WILL BE IMPORTED',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} NEW CONTACT',
		other: '${formatted} NEW CONTACTS',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} WILL MERGE WITH AN EXISTING CONTACT',
		other: '${formatted} WILL MERGE WITH EXISTING CONTACTS',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} CANNOT BE IMPORTED (NO CALLSIGN)',
		other: '${formatted} CANNOT BE IMPORTED (NO CALLSIGN)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} NEEDS A CLOSER LOOK',
		other: '${formatted} NEED A CLOSER LOOK',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'REFERENCES COULD NOT BE RECOVERED FOR ${count} CONTACT',
		other: 'REFERENCES COULD NOT BE RECOVERED FOR ${formatted} CONTACTS',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${programs} REFERENCES MAY BE INCOMPLETE FOR ${count} CONTACT',
		other: '${programs} REFERENCES MAY BE INCOMPLETE FOR ${formatted} CONTACTS',
	);
	@override String get stackingTypesUnknown => 'COMBINED CONTACTS MAY LOSE A REFERENCE — THE ACTIVITIES COULD NOT SAY WHICH TYPES STACK. CANCEL AND RETRY TO AVOID THIS.';
	@override String get nothingToImport => 'NOTHING IN THIS FILE CAN BE IMPORTED';
	@override String get confirm => 'IMPORT';
	@override String importing({required Object filename}) => 'IMPORTING ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'IMPORTED ${count} CONTACT FROM ${filename}',
		other: 'IMPORTED ${formatted} CONTACTS FROM ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'COULD NOT IMPORT ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} DOES NOT LOOK LIKE AN ADIF FILE';
	@override String stationWarning({required Object calls, required Object station}) => 'WARNING: THIS ADIF HAS QSOS FROM ${calls}, BUT THEY WILL BE IMPORTED AS ${station} IF YOU CONTINUE.';
	@override String get stationCallJoin => ' AND ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} HAS NO DATE AND CANNOT BE IMPORTED',
		other: '${formatted} HAVE NO DATE AND CANNOT BE IMPORTED',
	);
	@override String activationFound({required Object refs}) => 'THIS FILE RECORDS AN ACTIVATION OF ${refs}.';
	@override String get addActivation => 'ADD IT TO THIS OPERATION';
	@override String shortfall({required Object written, required Object planned}) => 'ONLY ${written} OF ${planned} COULD BE APPLIED — THE LOG CHANGED WHILE YOU WERE DECIDING.';
	@override String get busy => 'AN IMPORT IS ALREADY RUNNING. WAIT FOR IT TO FINISH BEFORE STARTING ANOTHER.';
	@override String get oneFileOnly => 'DROP ONE ADIF FILE AT A TIME — THE ORDER FILES ARE IMPORTED IN DECIDES WHICH DATA WINS.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} HAS MORE THAN ${limit} QSOS, THE MOST AN OPERATION CAN IMPORT AT A TIME.';
}

// Path: offline
class _Translations$offline$qro extends Translations$offline$en {
	_Translations$offline$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'INTERNET: OFFLINE';
	@override String get statusOnline => 'INTERNET: CONNECTED';
	@override String get noRoute => 'NO NETWORK CONNECTION AT ALL.';
	@override String get unreachable => 'THE NETWORK IS UP, BUT NO SERVER IS RESPONDING — OFTEN A SIGN-IN PAGE WAITING IN A BROWSER.';
	@override String get reachable => 'ALL SERVICES RESPONDING AS EXPECTED.';
	@override String get whatStops => 'LOOKUPS, SPOTS AND DATA FILES ARE PAUSED. LOGGING AND NEARBY SYNC ARE NOT.';
	@override String get servicesTitle => 'SERVICES';
	@override String get noServices => 'NO SERVICE HAS REPORTED IN YET.';
	@override String lastSuccess({required Object when}) => 'LAST RESPONDED ${when} AGO';
	@override String get neverSucceeded => 'HAS NOT RESPONDED YET';
	@override String nextAttempt({required Object when}) => 'NEXT ATTEMPT IN ${when}';
	@override String get nextAttemptNow => 'NEXT ATTEMPT DUE';
	@override String get retry => 'RETRY NOW';
	@override String get retrying => 'TRYING…';
	@override String get retryReached => 'BACK ONLINE.';
	@override String get retryUnreachable => 'STILL NO RESPONSE.';
	@override String get retryNotAttempted => 'NOTHING TO SEND RIGHT NOW.';
	@override String get retryThrottled => 'JUST TRIED — GIVE IT A MOMENT.';
	@override String get retryDisabled => 'SYNC IS SWITCHED OFF, SO THERE IS NOTHING TO PROBE WITH.';
	@override String get syncService => 'HAM2K LOFI SYNC';
	@override String get retryInFlight => 'ALREADY TRYING — HANG ON.';
}

// Path: exportSettings
class _Translations$exportSettings$qro extends Translations$exportSettings$en {
	_Translations$exportSettings$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'BASE SETTINGS FOR ALL EXPORTS, WITH SEPARATE FILENAME AND TITLE TEMPLATES FOR REFERENCE ACTIVITIES AND OTHER ACTIVITIES. EACH EXPORT TYPE CAN PROVIDE ITS OWN DEFAULTS OR CUSTOM SETTINGS.';
	@override String get referenceActivities => 'REFERENCE ACTIVITIES';
	@override String get otherActivities => 'OTHER ACTIVITIES';
	@override String get adifFields => 'ADIF FIELDS';
	@override String get loadFailed => 'EXPORT SETTINGS COULD NOT BE LOADED.';
	@override String get retry => 'RETRY';
	@override String get compactFileNamesDescriptionOn => 'COMPACT FILENAMES, SUCH AS N0CALL@US-1234-20260715.ADI.';
	@override String get compactFileNamesDescriptionOff => 'DESCRIPTIVE FILENAMES, SUCH AS 2026-07-15 N0CALL AT US-1234.ADI.';
	@override String get includePrivateDataDescriptionOn => 'INCLUDING NAMES, ADDRESSES, EMAILS, NOTES AND PRECISE LOCATIONS IN ADIF FILES.';
	@override String get includePrivateDataDescriptionOff => 'OMITTING NAMES, ADDRESSES, EMAILS AND NOTES; LIMITING LOCATIONS TO SIX-CHARACTER GRIDS.';
	@override String get includeLookupDataDescriptionOn => 'INCLUDING INFORMATION FROM CALLSIGN LOOKUP SERVICES.';
	@override String get includeLookupDataDescriptionOff => 'OMITTING INFORMATION FROM CALLSIGN LOOKUP SERVICES; KEEPING MANUALLY ENTERED VALUES.';
	@override String get customTemplatesDescriptionOn => 'YOUR CUSTOM TEMPLATES ARE ACTIVE AND CAN BE EDITED BELOW.';
	@override String get customTemplatesDescriptionOff => 'DEFAULT TEMPLATES ARE ACTIVE. YOUR CUSTOM TEMPLATES ARE KEPT FOR LATER.';
	@override String get type => 'EXPORT TYPE';
	@override String get defaults => 'DEFAULTS';
	@override String get includeLookupData => 'INCLUDE LOOKUP DATA';
	@override String get customTemplates => 'CUSTOM TEMPLATES';
	@override String get filenameTemplate => 'FILE NAME TEMPLATE';
	@override String get compactFilenameTemplate => 'COMPACT FILE NAME TEMPLATE';
	@override String get titleTemplate => 'TITLE TEMPLATE';
	@override String get adifNotesTemplate => 'ADIF QSO NOTES';
	@override String get adifCommentTemplate => 'ADIF QSO COMMENTS';
	@override String get adifQslMessageTemplate => 'ADIF QSL MESSAGE';
	@override String get shared => 'SETTINGS APPLY TO EVERY EXTENSION USING THIS EXPORT TYPE.';
	@override String get defaultTemplates => 'TURN ON CUSTOM TEMPLATES TO EDIT THIS TYPE’S TEMPLATES.';
}

// Path: templateEditor
class _Translations$templateEditor$qro extends Translations$templateEditor$en {
	_Translations$templateEditor$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'PREVIEW:';
	@override String get reset => 'RESET';
	@override String get docs => 'TEMPLATING DOCS';
	@override String get preview => 'SAMPLE PREVIEW';
	@override String get reference => 'TEMPLATE REFERENCE';
	@override String get attributes => 'AVAILABLE ATTRIBUTES';
	@override String get filters => 'FILTERS';
	@override String get flowControl => 'FLOW CONTROL';
	@override String get unavailable => 'PREVIEW IS UNAVAILABLE UNTIL EXTENSIONS ARE READY.';
	@override String get empty => '(EMPTY OUTPUT)';
}

// Path: home.nav
class _Translations$home$nav$qro extends Translations$home$nav$en {
	_Translations$home$nav$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get operations => 'OPERATIONS';
	@override String get chase => 'CHASING';
	@override String get logs => 'LOGS';
	@override String get maps => 'MAPS';
	@override String get settings => 'SETTINGS';
}

// Path: home.panels
class _Translations$home$panels$qro extends Translations$home$panels$en {
	_Translations$home$panels$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get operations => 'OPERATION LIST';
	@override String get operationsDescription => 'YOUR OPERATIONS, MOST RECENT FIRST.';
	@override String get version => 'CURRENT VERSION';
	@override String get versionDescription => 'THE HAM2K MARK, THIS APP’S NAME AND WHICH BUILD YOU ARE RUNNING.';
}

// Path: home.logs
class _Translations$home$logs$qro extends Translations$home$logs$en {
	_Translations$home$logs$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'LOGS';
	@override String get titleFor => 'LOGS FOR';
	@override String get emptyCallsigns => 'NO QSOS LOGGED YET';
	@override String emptyQsos({required Object call}) => 'NO QSOS FOR ${call}';
	@override String get mapNoSelection => 'SELECT A QSO TO SEE IT ON THE MAP';
	@override String get searchHint => 'SEARCH CALLSIGN OR NAME';
	@override String get noSearchMatches => 'NO QSOS MATCH YOUR SEARCH';
	@override String get titleAll => 'ALL LOGS';
	@override String get allCallsigns => 'ALL CALLSIGNS';
	@override String get noOperation => 'NOT PART OF AN OPERATION';
	@override String get unsavedTitle => 'UNSAVED CHANGES';
	@override String get unsavedBody => 'THIS QSO HAS CHANGES YOU HAVEN’T SAVED.';
	@override String get pendingDeleteBody => 'THIS QSO IS MARKED FOR DELETION.';
	@override String get editGone => 'NOT SAVED: THAT QSO IS NO LONGER IN THIS LOG.';
	@override String get discard => 'DISCARD';
	@override late final _Translations$home$logs$sheet$qro sheet = _Translations$home$logs$sheet$qro._(_root);
	@override late final _Translations$home$logs$groupBy$qro groupBy = _Translations$home$logs$groupBy$qro._(_root);
	@override late final _Translations$home$logs$period$qro period = _Translations$home$logs$period$qro._(_root);
	@override late final _Translations$home$logs$periodTitle$qro periodTitle = _Translations$home$logs$periodTitle$qro._(_root);
	@override late final _Translations$home$logs$columns$qro columns = _Translations$home$logs$columns$qro._(_root);
	@override late final _Translations$home$logs$panels$qro panels = _Translations$home$logs$panels$qro._(_root);
	@override late final _Translations$home$logs$import$qro import = _Translations$home$logs$import$qro._(_root);
}

// Path: chase.station
class _Translations$chase$station$qro extends Translations$chase$station$en {
	_Translations$chase$station$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CHASING STATION';
	@override String get stationLabel => 'STATION: ';
	@override String get operatorLabel => 'OP: ';
	@override String get noLocation => 'NO LOCATION';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$qro extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get today => 'TODAY';
	@override String get thisWeek => 'THIS WEEK';
	@override String get last14Days => 'IN THE LAST 14 DAYS';
	@override String get thisMonth => 'THIS MONTH';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$qro extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get today => 'STATS FOR TODAY';
	@override String get thisWeek => 'STATS FOR THIS WEEK';
	@override String get last14Days => 'STATS FOR LAST 14 DAYS';
	@override String get thisMonth => 'STATS FOR THIS MONTH';
}

// Path: chase.period
class _Translations$chase$period$qro extends Translations$chase$period$en {
	_Translations$chase$period$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get today => 'TODAY';
	@override String get thisWeek => 'THIS WEEK';
	@override String get last14Days => 'LAST 14 DAYS';
	@override String get thisMonth => 'THIS MONTH';
}

// Path: chase.goals
class _Translations$chase$goals$qro extends Translations$chase$goals$en {
	_Translations$chase$goals$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CHASING GOALS';
	@override String remove({required Object name}) => 'STOP CHASING ${name}';
	@override String get extensionsTitle => 'MORE CHASING PROGRAMS';
}

// Path: chase.panels
class _Translations$chase$panels$qro extends Translations$chase$panels$en {
	_Translations$chase$panels$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOS';
	@override String get loggingDescription => 'LOGGING CONTROLS ABOVE THE QSOS CHASED IN THE PERIOD.';
	@override String get info => 'INFO';
	@override String get infoDescription => 'THE CALLSIGN BEING LOGGED, OR THE PERIOD\'S STATS.';
	@override String get spots => 'SPOTS';
	@override String get spotsDescription => 'STATIONS SPOTTED ON THE AIR, READY TO CHASE.';
	@override String get map => 'MAP';
	@override String get mapDescription => 'THE PERIOD\'S QSOS AND THE STATION BEING LOGGED.';
}

// Path: chase.claims
class _Translations$chase$claims$qro extends Translations$chase$claims$en {
	_Translations$chase$claims$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get checking => 'CHECKING QSOS FOR CHASING';
	@override String rebuilding({required Object program}) => 'CHECKING THE LOG FOR ${program}';
	@override String progress({required Object done, required Object total}) => '${done} OF ${total} QSOS';
}

// Path: chase.notice
class _Translations$chase$notice$qro extends Translations$chase$notice$en {
	_Translations$chase$notice$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'NEW ${program}';
	@override String newRefGuess({required Object program}) => 'PROBABLY NEW ${program}';
	@override String newBand({required Object program}) => 'NEW ${program} BAND';
	@override String newBandGuess({required Object program}) => 'PROBABLY NEW ${program} BAND';
	@override String newMode({required Object program}) => 'NEW ${program} MODE';
	@override String newModeGuess({required Object program}) => 'PROBABLY NEW ${program} MODE';
	@override String unconfirmed({required Object program}) => '${program} UNCONFIRMED';
}

// Path: chase.alerts
class _Translations$chase$alerts$qro extends Translations$chase$alerts$en {
	_Translations$chase$alerts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ALERTS';
	@override String get newRef => 'NEW REFERENCE';
	@override String get newBand => 'NEW BAND';
	@override String get newMode => 'NEW MODE';
	@override String get unconfirmed => 'UNCONFIRMED';
}

// Path: chase.imports
class _Translations$chase$imports$qro extends Translations$chase$imports$en {
	_Translations$chase$imports$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'IMPORT ${label}';
	@override String pickTitle({required Object file}) => 'IMPORT ${file} AS';
	@override String get dropHint => 'DROP A FILE TO IMPORT IT INTO A CHASING PROGRAM';
	@override String done({required Object count, required Object program, required Object file}) => 'IMPORTED ${count} ${program} ENTRIES FROM ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'IMPORTED ${count} ${program} ENTRIES FROM ${file}, SKIPPED ${skipped} IT COULD NOT READ';
	@override String nothing({required Object file, required Object program}) => '${file} HAS NOTHING ${program} CAN IMPORT';
	@override String failed({required Object program, required Object file}) => '${program} COULD NOT READ ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} COULD NOT READ ANY OF THE ${skipped} RECORDS IN ${file}';
	@override String noProgram({required Object file}) => 'NO CHASING PROGRAM IMPORTS ${file}';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$qro extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'INVALID CALLSIGN: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'INVALID CALLSIGNS: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} HAS OPERATED SO FAR. ${typed} WILL BE RECORDED FOR NEW CONTACTS.';
	@override String operatorNoneSoFar({required Object typed}) => 'NO OPERATOR RECORDED SO FAR. ${typed} WILL BE RECORDED FOR NEW CONTACTS.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'THIS OPERATION ALREADY HAS CONTACTS BY ${calls}. ${typed} WILL ONLY BE RECORDED FOR NEW ONES.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'ALSO RECORD ${typed} AS THE OPERATOR OF THE CONTACT ALREADY LOGGED',
		other: 'ALSO RECORD ${typed} AS THE OPERATOR OF ALL ${count} CONTACTS ALREADY LOGGED',
	);
	@override String get operatorSeveralStations => 'WHEN USING MULTIPLE STATIONS OVER THE AIR, THERE\'S NO SUPPORT FOR SEPARATE OPERATORS';
	@override String get contactsUnreadable => 'THIS OPERATION\'S CONTACTS COULD NOT BE READ, SO CHANGING A CALLSIGN HERE WON\'T OFFER TO UPDATE THEM';
	@override String restampFailed({required Object error}) => 'THE CONTACTS ALREADY LOGGED COULD NOT BE UPDATED, SO NO CHANGES WERE MADE: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} OF ${planned} CONTACTS WERE UPDATED — THE REST ARE NO LONGER IN THIS OPERATION';
}

// Path: operation.tabs
class _Translations$operation$tabs$qro extends Translations$operation$tabs$en {
	_Translations$operation$tabs$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOS';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'MAP';
	@override String get qsosPlain => 'QSOS';
	@override String get clock => 'CLOCK';
	@override String get weather => 'WEATHER';
	@override String get website => 'WEB SITE';
	@override String get remoteScreen => 'REMOTE SCREEN';
	@override String get solar => 'SOLAR';
	@override String get radio => 'RADIO';
	@override String get summaries => 'OPERATION SUMMARIES';
}

// Path: operation.positions
class _Translations$operation$positions$qro extends Translations$operation$positions$en {
	_Translations$operation$positions$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'NO OTHER OPERATING POSITIONS ARE SHARING THIS OPERATION YET.';
	@override String positionLabel({required Object number}) => 'POS: ${number}';
	@override String operatorLabel({required Object call}) => 'OP: ${call}';
	@override String get unnamedPosition => 'ANOTHER POSITION';
	@override String get thisDevice => 'OUR OPERATING POSITION';
	@override String get nameIn => ' IN ';
	@override String get panelTitle => 'POSITIONS';
	@override String get panelDescription => 'WHAT EVERY OPERATING POSITION SHARING THIS OPERATION IS LOGGING RIGHT NOW.';
}

// Path: operation.menu
class _Translations$operation$menu$qro extends Translations$operation$menu$en {
	_Translations$operation$menu$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'SHOW RST FIELDS';
	@override String get showStateField => 'SHOW STATE FIELD';
	@override String get showGridField => 'SHOW GRID FIELD';
	@override String get showDeletedQsos => 'SHOW DELETED QSOS';
	@override String get showDeletedOps => 'SHOW DELETED OPERATIONS';
	@override String get showQsoNumbers => 'SHOW QSO NUMBERS';
	@override String get lookupAllQsos => 'LOOKUP ALL QSOS';
	@override String get loggingSettingsTitle => 'LOGGING SETTINGS';
	@override String get mapSettingsTitle => 'MAP SETTINGS';
	@override String get actionsSection => 'ACTIONS';
}

// Path: operation.layout
class _Translations$operation$layout$qro extends Translations$operation$layout$en {
	_Translations$operation$layout$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ADD A PANEL';
	@override String get availableSection => 'AVAILABLE PANELS';
	@override String panelSettings({required Object panel}) => '${panel} SETTINGS';
	@override String get panelSettingsAction => 'PANEL SETTINGS';
	@override String get viewName => 'OPERATION VIEW';
	@override String get viewOptions => 'VIEW LAYOUT OPTIONS';
	@override String get viewTitleBuiltIn => 'THIS VIEW IS BUILT INTO THE APP, AND SO IS ITS NAME';
	@override String get resetOptions => 'RESTORE DEFAULTS';
	@override String get removePane => 'REMOVE';
	@override String resetPaneConfirm({required Object panel}) => 'RESTORE ${panel} TO ITS DEFAULTS?';
	@override String get resetPaneConfirmBody => 'ITS TITLE, HEADER AND SIZE GO BACK TO THE DEFAULTS. THE REST OF THE LAYOUT STAYS AS IT IS.';
	@override String get resetViewConfirm => 'RESTORE THIS VIEW TO ITS DEFAULT LAYOUT?';
	@override String get resetViewConfirmBody => 'THE PANELS GO BACK TO THEIR DEFAULT ARRANGEMENT, AND THE VIEW\'S OPTIONS AND EVERY PANEL\'S GO BACK TO THE DEFAULTS.';
	@override String paneOptionsTitle({required Object panel}) => '${panel} LAYOUT SETTINGS';
	@override String get paneTitle => 'TITLE';
	@override String get paneShowHeader => 'SHOW HEADER';
	@override String get paneShowHeaderTabset => 'ALWAYS SHOWN WHILE THIS PANE SHARES A GROUP — THE HEADER IS HOW THE OTHERS ARE REACHED';
	@override String get paneInherit => 'SAME AS THE APP';
	@override String get searchHint => 'SEARCH PANELS';
	@override String get noPanelsMatch => 'NO PANEL MATCHES YOUR SEARCH.';
	@override String get nothingToAdd => 'THIS VIEW ALREADY HAS ALL POSSIBLE PANELS';
	@override String addPanel({required Object panel}) => 'ADD ${panel}';
	@override String showPreview({required Object panel}) => 'PREVIEW ${panel}';
	@override String missingExtension({required Object name}) => 'EXTENSION "${name}" IS MISSING';
	@override String get missingExtensionEnable => 'ENABLE';
	@override String get missingExtensionInstall => 'INSTALL…';
	@override String get missingExtensionWontRun => 'THIS VERSION WON’T RUN. UPDATE IT IN SETTINGS › EXTENSIONS.';
	@override String get missingExtensionUnavailable => 'NOT AVAILABLE IN THIS APP';
	@override String get missingExtensionNotInCatalog => 'NOT IN THE CATALOG';
	@override String get missingExtensionCatalogUnreachable => 'COULDN’T REACH THE CATALOG. TRY AGAIN';
	@override String get missingExtensionFailed => 'THAT DIDN’T WORK. TRY AGAIN';
	@override String get previewUnavailable => 'THIS PANEL\'S PREVIEW IMAGE COULD NOT BE SHOWN.';
	@override String get nestedPaneTitle => 'MORE';
	@override late final _Translations$operation$layout$layouts$qro layouts = _Translations$operation$layout$layouts$qro._(_root);
	@override String get editLayout => 'EDIT LAYOUT';
	@override String get saveLayout => 'SAVE LAYOUT';
	@override String get revertLayout => 'DISCARD LAYOUT CHANGES';
	@override String get done => 'DONE';
	@override String get layoutUnreadableTitle => 'LAYOUT COULDN\'T BE READ';
	@override String get layoutUnreadableBody => 'YOUR SAVED LAYOUT COULD NOT BE READ, SO THE DEFAULT ARRANGEMENT IS SHOWING INSTEAD. IT WON\'T BE SAVED OVER YOUR ORIGINAL UNTIL YOU CHOOSE TO KEEP IT.';
	@override String get layoutUnreadableAction => 'USE THIS LAYOUT';
	@override String panelRenderFailed({required Object panel}) => '${panel} COULD NOT BE DISPLAYED';
	@override String get panelRenderRetry => 'TRY AGAIN';
	@override String get panelActionFailed => 'THAT PANEL ACTION FAILED. TRY AGAIN.';
	@override late final _Translations$operation$layout$panels$qro panels = _Translations$operation$layout$panels$qro._(_root);
	@override String get htmlPanelUnsupported => 'THIS PANEL NEEDS A WEB VIEW, WHICH THIS PLATFORM DOES NOT PROVIDE';
	@override String get htmlPanelUnsupportedOnWeb => 'THIS PANEL NEEDS A SANDBOX THE WEB VERSION CANNOT PROVIDE';
}

// Path: operation.export
class _Translations$operation$export$qro extends Translations$operation$export$en {
	_Translations$operation$export$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'OPERATION EXPORTS';
	@override String get syncedOperation => 'OPERATION IS SYNCED';
	@override String get unsyncedOperation => 'OPERATION HAS UNSYNCED CHANGES';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} QSO IN THIS OPERATION',
		other: '${count} QSOS IN THIS OPERATION',
	);
	@override String qsosSynced({required Object total}) => 'ALL ${total} QSOS ARE SYNCED';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} OF ${total} QSOS PENDING SYNC';
	@override String eventsSynced({required Object total}) => '${total} EVENT MARKERS SYNCED';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} OF ${total} EVENT MARKERS PENDING';
	@override String get loading => 'LOADING EXPORT OPTIONS…';
	@override String get noOptions => 'NO EXPORT FORMATS AVAILABLE (EXTENSION RUNTIME STILL STARTING?)';
	@override String get nothingLogged => 'NOTHING TO EXPORT YET — THIS OPERATION HAS NO QSOS.';
	@override String get share => 'SHARE';
	@override String get nothingSelected => 'NOTHING SELECTED';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SAVE ${count} FILE',
		other: 'SAVE ${count} FILES',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SHARE ${count} FILE',
		other: 'SHARE ${count} FILES',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'EXPORT ${count} FILE',
		other: 'EXPORT ${count} FILES',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'DOWNLOAD ${count} FILE',
		other: 'DOWNLOAD ${count} FILES',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SAVE COMBINED ${count} FILE',
		other: 'SAVE COMBINED ${count} FILES',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SHARE COMBINED ${count} FILE',
		other: 'SHARE COMBINED ${count} FILES',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'EXPORT COMBINED ${count} FILE',
		other: 'EXPORT COMBINED ${count} FILES',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'DOWNLOAD COMBINED ${count} FILE',
		other: 'DOWNLOAD COMBINED ${count} FILES',
	);
	@override String saveOne({required Object name}) => 'SAVE ${name}';
	@override String shareOne({required Object name}) => 'SHARE ${name}';
	@override String exportOne({required Object name}) => 'EXPORT ${name}';
	@override String downloadOne({required Object name}) => 'DOWNLOAD ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'STASH ${count} FILE',
		other: 'STASH ${count} FILES',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'STASH COMBINED ${count} FILE',
		other: 'STASH COMBINED ${count} FILES',
	);
	@override String get settingsButton => 'EXPORT SETTINGS';
	@override String get settingsTitle => 'EXPORT SETTINGS';
	@override late final _Translations$operation$export$compactFileNames$qro compactFileNames = _Translations$operation$export$compactFileNames$qro._(_root);
	@override late final _Translations$operation$export$includePrivateData$qro includePrivateData = _Translations$operation$export$includePrivateData$qro._(_root);
	@override String get resultTitle => 'EXPORT COMPLETE';
	@override String get resultFailedTitle => 'EXPORT FAILED';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'EXPORTED ${count} FILE TO ${path}',
		other: 'EXPORTED ${count} FILES TO ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'EXPORTED ${count} FILE: ${path}',
		other: 'EXPORTED ${count} FILES: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SHARED ${count} FILE',
		other: 'SHARED ${count} FILES',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'DOWNLOADED ${count} FILE',
		other: 'DOWNLOADED ${count} FILES',
	);
	@override String exportFailed({required Object error}) => 'EXPORT FAILED: ${error}';
	@override late final _Translations$operation$export$stash$qro stash = _Translations$operation$export$stash$qro._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$qro extends Translations$operation$spots$en {
	_Translations$operation$spots$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get empty => 'NO SPOTS MATCH YOUR FILTERS';
	@override String error({required Object error}) => 'FAILED TO LOAD SPOTS: ${error}';
	@override String get unknownBand => 'OTHER';
	@override String get auto => 'AUTOMATIC';
	@override String autoValue({required Object value}) => 'AUTOMATIC (CURRENTLY ${value})';
	@override String valueAuto({required Object value}) => '${value} (AUTO)';
	@override String get any => 'ANY';
	@override String get allBands => 'ALL BANDS';
	@override String get allModes => 'ALL MODES';
	@override String get phoneAndCw => 'PHONE & CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} SPOT',
		other: '${count} SPOTS',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'SHOWING ${count} OF ${total} SPOTS';
	@override String ageMinutes({required Object minutes}) => '${minutes} MINUTES';
	@override String get callsOfNote => 'CALLS OF NOTE';
	@override String get yourSpots => 'YOUR SPOTS';
	@override String get allSpots => 'ALL SPOTS';
	@override late final _Translations$operation$spots$continents$qro continents = _Translations$operation$spots$continents$qro._(_root);
	@override late final _Translations$operation$spots$filters$qro filters = _Translations$operation$spots$filters$qro._(_root);
	@override String get unavailableTitle => 'SPOTS UNAVAILABLE';
	@override String unavailableText({required Object sources}) => '${sources} DID NOT RESPOND.';
	@override String get failedTitle => 'SPOT SOURCE ERROR';
	@override String failedText({required Object sources}) => '${sources} RETURNED AN ERROR.';
	@override String get slideLogIt => 'LOG IT';
	@override String get slideIgnore => 'IGNORE';
	@override String get slideRestore => 'RESTORE';
	@override late final _Translations$operation$spots$logConflict$qro logConflict = _Translations$operation$spots$logConflict$qro._(_root);
}

// Path: operation.import
class _Translations$operation$import$qro extends Translations$operation$import$en {
	_Translations$operation$import$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'IMPORT DATA INTO OPERATION';
	@override String get importAdifAction => 'IMPORT QSOS FROM ADIF';
	@override String get settingsButton => 'LISTEN SETTINGS';
	@override String get settingsTitle => 'LISTEN FOR OTHER APPS';
	@override String get protocolAddressLabel => 'ADDRESS';
	@override String get protocolPortLabel => 'PORT';
	@override String get protocolPortInvalid => 'ENTER A PORT BETWEEN 1 AND 65535';
	@override String get protocolAddressInvalid => 'ENTER A VALID IP ADDRESS (E.G. 127.0.0.1 OR 239.239.0.2)';
	@override String get protocolStatusReceiving => 'RECEIVING DATA';
	@override String get protocolStatusNoData => 'NO DATA RECEIVED RECENTLY';
	@override String protocolBindError({required Object error}) => 'COULDN\'T START LISTENING: ${error}';
	@override String captureFailed({required Object error}) => 'INCOMING QSOS COULD NOT BE SAVED AND ARE BEING RETRIED: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ CONTACT BROADCAST';
	@override String get n1mmAddressValue => 'ANY (BROADCAST)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP SERVER';
	@override String get helpN1mmSetup => 'CONFIG → CONFIGURE PORTS, MODE CONTROL… → BROADCAST DATA TAB → CHECK "ENABLE BROADCASTS" FOR CONTACT INFO. SET IP ADDRESS TO 127.0.0.1 IF RUNNING ON THIS SAME COMPUTER, OR 255.255.255.255 TO BROADCAST ON THE CURRENT LOCAL NETWORK.';
	@override String get helpWsjtxSetup => 'FILE → SETTINGS → REPORTING TAB → UDP SERVER SECTION → CHECK "ACCEPT UDP REQUESTS". SET UDP SERVER TO 127.0.0.1 IF RUNNING ON THIS SAME COMPUTER, OR A MULTICAST ADDRESS SUCH AS 239.239.0.2, AND USE THE SAME ADDRESS IN THE CONFIGURATION ABOVE IN THIS APP.';
	@override String get listenTitle => 'LISTEN FOR QSOS FROM OTHER APPS';
	@override String get listenDescriptionOnN1mm => 'LISTENING FOR N1MM+';
	@override String get listenDescriptionOnWsjtx => 'LISTENING FOR WSJT-X';
	@override String get listenDescriptionOnBoth => 'LISTENING FOR N1MM+ AND WSJT-X';
	@override String get listenDescriptionOff => 'OFF';
	@override String get addToOperationTitle => 'ADD TO THIS OPERATION';
	@override String get addToOperationDescriptionOn => 'CAPTURED QSOS ARE ADDED TO THIS OPERATION AS THEY ARRIVE';
	@override String get addToOperationDescriptionOff => 'CAPTURED QSOS ARE HELD UNTIL YOU TURN THIS ON';
	@override String get pendingSectionTitle => 'CAPTURED QSOS';
	@override String get pendingEmpty => 'NOTHING CAPTURED YET';
	@override String stationMismatch({required Object call}) => 'LOGGED AS ${call}, NOT THIS OPERATION\'S STATION';
	@override String get discardAction => 'DISCARD';
	@override String get gapDialogTitle => 'INCLUDE EARLIER CAPTURES?';
	@override String gapDialogBody({required Object count}) => '${count} MORE QSOS WERE CAPTURED EARLIER, BEFORE A GAP IN THE DATA. INCLUDE THEM TOO?';
	@override String get gapDialogRecentOnly => 'JUST THE RECENT ONES';
	@override String gapDialogIncludeAll({required Object count}) => 'INCLUDE ALL ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$qro extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get link => 'ISSUES?';
	@override String get title => 'REPORT AN OUTLINE ISSUE';
	@override String get reference => 'WHICH OUTLINE';
	@override String get severity => 'HOW BAD IS IT?';
	@override String get minor => 'MINOR NIT';
	@override String get major => 'BIG DEAL';
	@override String get explanation => 'WHAT\'S WRONG WITH IT?';
	@override String get explanationHint => 'WHAT THE OUTLINE GETS WRONG, AND WHERE';
	@override String get send => 'SEND';
	@override String get sending => 'SENDING YOUR REPORT — THANKS';
	@override String get copy => 'COPY REPORT';
	@override String get notSent => 'COULDN\'T SEND THE REPORT';
	@override String get copied => 'REPORT COPIED';
	@override String get notCopied => 'COULDN\'T COPY THE REPORT';
}

// Path: map.postcard
class _Translations$map$postcard$qro extends Translations$map$postcard$en {
	_Translations$map$postcard$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get button => 'OPERATION POSTCARD';
	@override String title({required Object title}) => 'POSTCARD FOR ${title}';
	@override String get portrait => 'PORTRAIT';
	@override String get landscape => 'LANDSCAPE';
	@override String get square => 'SQUARE';
	@override String get save => 'SAVE…';
	@override String get download => 'DOWNLOAD';
	@override String get share => 'SHARE';
	@override String get copy => 'COPY';
	@override String get copied => 'COPIED TO THE CLIPBOARD';
	@override String saved({required Object path}) => 'SAVED TO ${path}';
	@override String downloaded({required Object name}) => 'DOWNLOADED ${name}';
	@override String savedMany({required Object count, required Object path}) => 'SAVED ${count} IMAGES TO ${path}';
	@override String savedFiles({required Object names}) => 'SAVED ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} HAD ALREADY BEEN SAVED';
	@override String downloadedMany({required Object count}) => 'DOWNLOADING ${count} IMAGES — ALLOW THEM IF THE BROWSER ASKS';
	@override String get mapLeftOut => 'THE MAP DIDN\'T LOAD, SO IT WAS LEFT OUT';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — THE MAP DIDN\'T LOAD, SO IT WAS LEFT OUT';
	@override String continued({required Object title}) => '${title} (CONTINUED)';
	@override String get previousPage => 'PREVIOUS PAGE';
	@override String get nextPage => 'NEXT PAGE';
	@override String pageOf({required Object page, required Object count}) => 'PAGE ${page} OF ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} Q',
		other: '${count} QS',
	);
	@override String get options => 'POSTCARD OPTIONS';
	@override String get bandLegend => 'SHOW BAND LEGEND';
	@override String get grayline => 'SHOW GRAYLINE';
	@override String get sectionsAndOrder => 'SUMMARY SECTIONS AND ORDERING';
	@override String get sectionDays => 'EACH DAY';
	@override String get reset => 'RESET';
	@override String failed({required Object error}) => 'COULD NOT MAKE THE POSTCARD: ${error}';
	@override String get mapNotReady => 'THE MAP DIDN\'T FINISH LOADING. CHECK THE CONNECTION AND TRY AGAIN.';
	@override String saveFailed({required Object error}) => 'COULD NOT SAVE THE POSTCARD: ${error}';
	@override String get copyFailed => 'THE CLIPBOARD DIDN\'T TAKE THE IMAGE. TRY AGAIN.';
	@override String get shareFailed => 'COULD NOT SHARE THE POSTCARD. TRY AGAIN.';
	@override String get fileName => 'POSTCARD';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$qro extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'NO QSOS YET... LET\'S GET ON THE AIR!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOS';
	@override String qsosInTime({required Object count, required Object time}) => '${count} IN ${time}';
	@override String sinceLast({required Object time}) => '${time} SINCE LAST';
	@override String ratePer10({required Object rate}) => '${rate} Q/H FOR LAST 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/H FOR LAST 100';
	@override String distanceTo({required Object distance}) => '${distance} TO';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) TO';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) TO';
	@override String distanceAway({required Object distance}) => '${distance} AWAY';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) AWAY';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) AWAY';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'DUPE!';
	@override String get noticeNewBand => 'NEW BAND';
	@override String get noticeNewMode => 'NEW MODE';
	@override String get noticeNewDXCC => 'NEW DXCC';
	@override String get noticeNewState => 'NEW STATE';
	@override String get noticeNewProvince => 'NEW PROVINCE';
	@override String get noticeNewDay => 'NEW DAY';
	@override String get noticeNewRef => 'NEW REF';
	@override String get noticeNewMult => 'NEW MULT';
	@override String get noticeNewZone => 'NEW ZONE';
	@override String get noticeInvalidMode => 'WRONG MODE';
	@override String get noticeInvalidBand => 'WRONG BAND';
	@override String get noticeInvalidCategory => 'NOT WORKABLE';
	@override String get noticeOverTime => 'TIME OVER';
	@override String get noticeWorkedBefore => 'WORKED BEFORE';
	@override String get noticeNewPark => 'NEW PARK';
	@override String get noticeNewSection => 'NEW SECTION';
	@override String get noticeBonusStation => 'BONUS STATION!';
	@override String get noticeMissingExchange => 'NO EXCHANGE';
	@override String get noticeInvalidExchange => 'BAD EXCHANGE';
	@override String get noticeUnknownEvent => 'UNKNOWN EVENT';
	@override String get noticeIncompleteCall => 'INCOMPLETE CALL — NOT SCORED';
	@override String get noticeOurGrid => 'SET OUR GRID';
	@override String get noticeRareCounty => 'RARE COUNTY!';
	@override String get noticeOurLocation => 'SET OUR COUNTY';
	@override String get noticeShortGrid => 'GRID TOO SHORT';
}

// Path: qsoList.find
class _Translations$qsoList$find$qro extends Translations$qsoList$find$en {
	_Translations$qsoList$find$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'FIND IN LOG (${shortcut})';
	@override String get menuItemNoShortcut => 'FIND IN LOG';
	@override String get hint => 'QSO NUMBER OR CALLSIGN';
	@override String get noMatches => 'NO MATCH';
	@override String get noOperationQsos => 'NO QSOS IN THIS OPERATION';
	@override String get noPeriodQsos => 'NO QSOS IN THIS PERIOD';
	@override String get outsideQsosOne => '1 QSO OUTSIDE OF THIS OPERATION';
	@override String outsideQsosOther({required Object count}) => '${count} QSOS OUTSIDE OF THIS OPERATION';
	@override String get pastQsosOne => '1 PAST QSO';
	@override String pastQsosOther({required Object count}) => '${count} PAST QSOS';
}

// Path: callInfo.history
class _Translations$callInfo$history$qro extends Translations$callInfo$history$en {
	_Translations$callInfo$history$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} IN LAST 7 DAYS';
	@override String today({required Object n}) => '${n} TODAY';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${n} QSO',
		other: '${n} QSOS',
	);
}

// Path: settings.theme
class _Translations$settings$theme$qro extends Translations$settings$theme$en {
	_Translations$settings$theme$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'THEME MODE';
	@override String get system => 'FOLLOW SYSTEM SETTINGS';
	@override String get light => 'LIGHT';
	@override String get dark => 'DARK';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$qro extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get system => 'FOLLOWING SYSTEM SETTINGS';
	@override String get light => 'ALWAYS IN LIGHT MODE';
	@override String get dark => 'ALWAYS IN DARK MODE';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$qro extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'SMALLEST--';
	@override String get smallestMinus => 'SMALLEST-';
	@override String get smallest => 'SMALLEST';
	@override String get smaller => 'SMALLER';
	@override String get normal => 'NORMAL';
	@override String get larger => 'LARGER';
	@override String get largest => 'LARGEST';
	@override String get largestPlus => 'LARGEST+';
	@override String get largestPlusPlus => 'LARGEST++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$qro extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'KEEP DEVICE AWAKE';
	@override String get descriptionOn => 'STAYING AWAKE WHILE YOU ARE ON THE LOGGING VIEW OR A SYNC IS IN PROGRESS';
	@override String get descriptionOff => 'SLEEPING AS USUAL';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$qro extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get auto => 'AUTOMATIC';
	@override String get densest => 'DENSEST';
	@override String get dense => 'DENSE';
	@override String get normal => 'NORMAL';
	@override String get sparse => 'SPARSE';
	@override String get sparsest => 'SPARSEST';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$qro extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'KILOMETERS';
	@override String get miles => 'MILES';
}

// Path: settings.logging
class _Translations$settings$logging$qro extends Translations$settings$logging$en {
	_Translations$settings$logging$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'LOGGING';
	@override late final _Translations$settings$logging$leftieMode$qro leftieMode = _Translations$settings$logging$leftieMode$qro._(_root);
	@override late final _Translations$settings$logging$countryFlags$qro countryFlags = _Translations$settings$logging$countryFlags$qro._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$qro countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$qro._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$qro suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$qro._(_root);
	@override late final _Translations$settings$logging$showBearing$qro showBearing = _Translations$settings$logging$showBearing$qro._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$qro showReverseBearing = _Translations$settings$logging$showReverseBearing$qro._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$qro switchSentRcvd = _Translations$settings$logging$switchSentRcvd$qro._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$qro jumpAfterRST = _Translations$settings$logging$jumpAfterRST$qro._(_root);
	@override late final _Translations$settings$logging$defaultReport$qro defaultReport = _Translations$settings$logging$defaultReport$qro._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$qro defaultReportCW = _Translations$settings$logging$defaultReportCW$qro._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$qro defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$qro._(_root);
	@override late final _Translations$settings$logging$numbersRow$qro numbersRow = _Translations$settings$logging$numbersRow$qro._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$qro numbersRowExtra = _Translations$settings$logging$numbersRowExtra$qro._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$qro numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$qro._(_root);
	@override String get bands => 'PREFERRED BANDS';
	@override String get modes => 'PREFERRED MODES';
}

// Path: settings.catServer
class _Translations$settings$catServer$qro extends Translations$settings$catServer$en {
	_Translations$settings$catServer$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT SERVER';
	@override String get description => 'ALLOW OTHER APPS (WSJT-X, LOGGERS, ETC) TO CONTROL THE RADIO THROUGH HAM2K LOGGER.';
	@override String get protocol => 'PROTOCOL';
	@override late final _Translations$settings$catServer$protocolOpts$qro protocolOpts = _Translations$settings$catServer$protocolOpts$qro._(_root);
	@override String get port => 'PORT';
	@override String get openAccess => 'OPEN ACCESS';
	@override String get openAccessOn => 'ANY COMPUTER ON THE LOCAL NETWORK CAN CONNECT.';
	@override String get openAccessOff => 'ONLY APPS ON THIS COMPUTER CAN CONNECT.';
	@override String get off => 'OFF.';
	@override String starting({required Object protocol}) => '${protocol}, STARTING…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} ON PORT ${port}. CLIENTS CONNECTED: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} ON PORT ${port}, BUT NO MAIN VFO RADIO IS CONNECTED.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} CANNOT LISTEN ON PORT ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} CANNOT LISTEN ON PORT ${port}: ANOTHER PROGRAM IS USING IT, OFTEN ${protocol} ITSELF. CLOSE THAT PROGRAM OR CHOOSE ANOTHER PORT.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} CANNOT LISTEN ON PORT ${port}: THIS COMPUTER DOES NOT ALLOW IT. CHOOSE A PORT ABOVE 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} STOPPED LISTENING ON PORT ${port}. TRYING AGAIN…';
}

// Path: settings.cluster
class _Translations$settings$cluster$qro extends Translations$settings$cluster$en {
	_Translations$settings$cluster$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'DX CLUSTER';
	@override String get description => 'THE SERVER EXTENSIONS POST SPOTS TO AND READ SPOTS FROM, LOGGED IN AS THE OPERATOR.';
	@override String get server => 'CLUSTER SERVER';
	@override String get selectServer => 'SELECT SERVER';
	@override String get serverOther => 'OTHER';
	@override String serverOtherIncomplete({required Object node}) => 'NO HOST ENTERED YET, SO SPOTS GO TO ${node}';
	@override String get customHost => 'SERVER';
	@override String get customPort => 'PORT';
	@override String get password => 'PASSWORD';
	@override String get passwordDescription => 'ONLY IF NEEDED';
	@override String passwordStored({required Object node}) => 'PASSWORD ON FILE FOR ${node}';
	@override String get scrollback => 'LINES KEPT';
	@override String scrollbackOpt({required Object count}) => '${count} LINES';
	@override String get connection => 'CONNECTION';
	@override String get statusIdle => 'NOT CONNECTED. CONNECTS WHEN AN EXTENSION NEEDS IT. TAP TO TEST.';
	@override String statusConnecting({required Object node}) => 'CONNECTING TO ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'CONNECTED TO ${node} AS ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'COULD NOT CONNECT TO ${node}: ${reason}';
	@override String get statusUnsupported => 'NOT AVAILABLE IN THE WEB VERSION.';
	@override late final _Translations$settings$cluster$errors$qro errors = _Translations$settings$cluster$errors$qro._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$qro extends Translations$settings$spotting$en {
	_Translations$settings$spotting$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SPOTTING';
	@override String get respotInterval => 'AUTO RE-SPOT EVERY';
	@override String minutes({required Object minutes}) => '${minutes} MIN';
	@override String get autoRespotByDefault => 'AUTO RE-SPOT BY DEFAULT';
	@override String get autoRespotByDefaultOn => 'ENABLE AUTO RE-SPOT AFTER ANY SPOT IS POSTED';
	@override String get autoRespotByDefaultOff => 'REQUIRE USER ACTION TO ENABLE AUTO RE-SPOTTING';
	@override String get pulseBeforeRespot => 'PULSE BEFORE EACH AUTO RE-SPOT';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'THE SPOTTING CHIP PULSES BLUE FOR THE ${seconds} SECONDS BEFORE EACH RE-SPOT';
	@override String get pulseBeforeRespotOff => 'NO PULSING BEFORE AN AUTO RE-SPOT';
}

// Path: settings.radio
class _Translations$settings$radio$qro extends Translations$settings$radio$en {
	_Translations$settings$radio$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT CONTROL';
	@override String get loggingAndCat => 'LOGGING & CAT';
	@override String get tuningSection => 'TUNING';
	@override String get keyerSection => 'KEYER';
	@override String get servicesSection => 'SERVICES';
	@override String get stationConfigurationSection => 'STATION CONFIGURATION';
	@override String get moreSettings => 'MORE STATION CONFIGURATION SETTINGS';
	@override late final _Translations$settings$radio$units$qro units = _Translations$settings$radio$units$qro._(_root);
	@override late final _Translations$settings$radio$pttKey$qro pttKey = _Translations$settings$radio$pttKey$qro._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$qro smartVfoSnap = _Translations$settings$radio$smartVfoSnap$qro._(_root);
	@override late final _Translations$settings$radio$snapDebounce$qro snapDebounce = _Translations$settings$radio$snapDebounce$qro._(_root);
	@override late final _Translations$settings$radio$snapLongMove$qro snapLongMove = _Translations$settings$radio$snapLongMove$qro._(_root);
	@override late final _Translations$settings$radio$snapMinMove$qro snapMinMove = _Translations$settings$radio$snapMinMove$qro._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$qro snapMinSpeed = _Translations$settings$radio$snapMinSpeed$qro._(_root);
	@override late final _Translations$settings$radio$enterSends$qro enterSends = _Translations$settings$radio$enterSends$qro._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$qro keyerSpeed = _Translations$settings$radio$keyerSpeed$qro._(_root);
	@override late final _Translations$settings$radio$cwMessages$qro cwMessages = _Translations$settings$radio$cwMessages$qro._(_root);
	@override late final _Translations$settings$radio$voiceMessages$qro voiceMessages = _Translations$settings$radio$voiceMessages$qro._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$qro avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$qro._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$qro zeroBeatRange = _Translations$settings$radio$zeroBeatRange$qro._(_root);
}

// Path: settings.help
class _Translations$settings$help$qro extends Translations$settings$help$en {
	_Translations$settings$help$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'HELP & RESOURCES';
	@override String get description => 'COMMUNITY AND SUPPORT';
	@override String get forums => 'HAM2K FORUMS';
	@override String get forumsDescription => 'FIND HELP, GIVE FEEDBACK, DISCUSS IDEAS…';
	@override String get chat => 'HAM2K CHAT';
	@override String get chatDescription => 'THE DISCORD SERVER FOR OUR ONLINE COMMUNITY';
	@override String get youtube => 'HAM2K YOUTUBE';
	@override String get youtubeDescription => 'VIDEOS AND LIVE STREAMS';
	@override String get instagram => 'HAM2K INSTAGRAM';
	@override String get instagramDescription => 'BECAUSE YOU CANNOT HAVE TOO MANY PHOTOS…';
	@override String get bluesky => 'HAM2K BLUESKY';
	@override String get blueskyDescription => 'FOLLOW US FOR NEWS AND UPDATES';
	@override String get contact => 'CONTACT US';
	@override String get contactDescription => 'HELP@HAM2K.COM — BUT TRY THE FORUMS OR CHAT FIRST!';
}

// Path: settings.exports
class _Translations$settings$exports$qro extends Translations$settings$exports$en {
	_Translations$settings$exports$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'EXPORTS';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$qro extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get activities => 'ACTIVITIES';
	@override String get hunting => 'HUNTING';
	@override String get contests => 'CONTESTS';
	@override String get lookups => 'LOOKUPS';
	@override String get dashboard => 'DASHBOARD';
}

// Path: settings.map
class _Translations$settings$map$qro extends Translations$settings$map$en {
	_Translations$settings$map$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'MAPS';
	@override late final _Translations$settings$map$style$qro style = _Translations$settings$map$style$qro._(_root);
	@override late final _Translations$settings$map$showCallsigns$qro showCallsigns = _Translations$settings$map$showCallsigns$qro._(_root);
	@override late final _Translations$settings$map$showGrayline$qro showGrayline = _Translations$settings$map$showGrayline$qro._(_root);
	@override late final _Translations$settings$map$styleOpts$qro styleOpts = _Translations$settings$map$styleOpts$qro._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$qro extends Translations$settings$privacy$en {
	_Translations$settings$privacy$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'PRIVACY';
	@override late final _Translations$settings$privacy$shareAppData$qro shareAppData = _Translations$settings$privacy$shareAppData$qro._(_root);
	@override late final _Translations$settings$privacy$shareOpData$qro shareOpData = _Translations$settings$privacy$shareOpData$qro._(_root);
	@override String get privacyPolicy => 'PRIVACY POLICY';
	@override String get termsOfService => 'TERMS OF SERVICE';
}

// Path: settings.sync
class _Translations$settings$sync$qro extends Translations$settings$sync$en {
	_Translations$settings$sync$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CLOUD SYNC';
	@override String get moreSettings => 'MORE SYNC SETTINGS';
	@override String get enable => 'ENABLE SYNC';
	@override String get deviceKey => 'DEVICE KEY';
}

// Path: settings.peers
class _Translations$settings$peers$qro extends Translations$settings$peers$en {
	_Translations$settings$peers$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'PEER DEVICES';
	@override String get enable => 'CONNECT TO OTHER DEVICES';
	@override String get enableDescription => 'ALLOW SHARING OPERATIONS, LOGGING, CAT AND GPS WITH OTHER DEVICES OVER THE LOCAL NETWORK';
	@override String get bleEnable => 'CONNECT OVER BLUETOOTH';
	@override String get bleDescription => 'USE BLUETOOTH LE TO CONNECT EVEN IF THERE IS NO LOCAL NETWORK';
	@override String get thisDevice => 'THIS DEVICE';
	@override String get deviceName => 'NAME';
	@override String get deviceNameHint => 'HOW THIS DEVICE IS SEEN BY OTHER DEVICES';
	@override String get pairedDevices => 'LINKED DEVICES';
	@override String get noPairedDevices => 'NO DEVICES LINKED YET. TURN THIS ON, ON ANOTHER DEVICE ON THIS NETWORK, TO LINK THEM.';
	@override String deviceListProblem({required Object error}) => 'CAN\'T READ YOUR LINKED DEVICES: ${error}';
	@override String get nearby => 'NEARBY';
	@override String get connected => 'CONNECTED';
	@override String get viaBluetooth => 'VIA BLUETOOTH';
	@override String get connecting => 'CONNECTING…';
	@override String get syncing => 'SYNCING…';
	@override String get waitingForThem => 'WAITING FOR THE OTHER DEVICE';
	@override String get notConnected => 'NOT CONNECTED';
	@override String get wantsToPair => 'WANTS TO SHARE THIS OPERATION';
	@override String get allow => 'ALLOW';
	@override String get link => 'LINK';
	@override String get reject => 'REJECT';
	@override String get forget => 'FORGET';
	@override String forgetTitle({required Object name}) => 'FORGET ${name}?';
	@override String get forgetBody => 'IT WILL STOP SYNCING WITH THIS DEVICE. YOU CAN ALLOW IT AGAIN LATER, AND CONTACTS ALREADY LOGGED ARE KEPT.';
	@override String pairTitle({required Object name}) => 'LINK WITH ${name}';
	@override String get pairBody => 'THIS DEVICE IS ON YOUR LOCAL NETWORK AND WANTS TO CONNECT.';
	@override String get pairBodyBle => 'THIS DEVICE IS NEARBY AND WANTS TO CONNECT OVER BLUETOOTH LE.';
	@override String get pairIdLabel => 'DEVICE ID';
	@override String get pairWarning => 'ONLY LINK WITH DEVICES YOU RECOGNISE. ANY DEVICE ON THIS NETWORK CAN SEND A REQUEST.';
	@override String get pairWarningBle => 'ONLY LINK WITH DEVICES YOU RECOGNISE. ANY NEARBY DEVICE CAN SEND A REQUEST.';
	@override String problem({required Object error}) => 'CAN\'T REACH THE LOCAL NETWORK: ${error}';
	@override String bleProblem({required Object error}) => 'BLUETOOTH: ${error}';
	@override String statusConnected({required Object device}) => 'CONNECTED TO ${device}';
	@override String statusLost({required Object device}) => 'LOST CONNECTION TO ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'PEER DEVICES: ${connected} OF ${linked} CONNECTED';
	@override String get screenEnable => 'SHARE SCREENS AND WINDOWS';
	@override String get screenDescription => 'ALLOW OTHER DEVICES TO SHOW SCREENS OR WINDOWS FROM THIS COMPUTER';
	@override String get screenSources => 'SCREENS AND WINDOWS';
	@override String get screenRefresh => 'REFRESH THE LIST';
	@override String get screenUnsupportedPlatform => 'THIS DEVICE CAN\'T SHARE ITS SCREEN. MACOS CAN; EVERY DEVICE CAN SHOW ONE SHARED BY ANOTHER.';
	@override String get screenUnsupportedVersion => 'SHARING A SCREEN NEEDS MACOS 12.3 OR LATER. THIS DEVICE CAN STILL SHOW A SCREEN SHARED BY ANOTHER.';
	@override String get screenNeedsPermission => 'MACOS NEEDS YOUR PERMISSION TO RECORD THE SCREEN BEFORE THIS APP CAN SHARE ONE.';
	@override String get screenGrantPermission => 'ASK FOR PERMISSION';
	@override String get screenRelaunchAfterGranting => 'ALLOW IT IN SYSTEM SETTINGS UNDER PRIVACY & SECURITY → SCREEN RECORDING, THEN QUIT AND REOPEN THIS APP — MACOS ONLY TELLS AN APP ABOUT THE CHANGE ON ITS NEXT LAUNCH.';
	@override String screenProblem({required Object error}) => 'SCREEN SHARING: ${error}';
	@override String get screenChooseTitle => 'CHOOSE WHAT TO SHARE';
	@override String get screenChooseButton => 'CHOOSE WHAT TO SHARE…';
	@override String get screenTabScreens => 'SCREENS';
	@override String get screenTabApps => 'APPS';
	@override String get screenTabWindows => 'WINDOWS';
	@override String get screenTabEmpty => 'NOTHING OF THIS KIND WAS FOUND.';
	@override String get screenSharedSummaryNone => 'NOTHING CHOSEN YET.';
	@override String get screenThisDevice => 'THIS DEVICE';
	@override String screenSharedTo({required Object devices}) => 'SHOWN ON ${devices}';
	@override String get screenSharedToNobody => 'NOT BEING SHOWN';
	@override String screenStopSharing({required Object name}) => 'STOP SHARING ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$qro extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'SYNC CONFIGURATION';
	@override String get enableTitle => 'SYNC WITH HAM2K LOG FILER';
	@override String get enabledDescription => 'BACKING UP AND SYNCING YOUR LOG ACROSS DEVICES';
	@override String get disabledDescription => 'OFF — STAYING ON THIS DEVICE ONLY';
	@override String get syncing => 'SYNCING';
	@override String get account => 'ACCOUNT';
	@override String get refresh => 'REFRESH';
	@override String get switchAccounts => 'SWITCH ACCOUNTS';
	@override String get switchAccountsDescription => 'LINK THIS DEVICE TO ANOTHER ACCOUNT WITH A QR CODE OR EMAIL';
	@override String get connectionRequests => 'CONNECTION REQUESTS';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'A DEVICE IS WAITING TO JOIN THIS ACCOUNT',
		other: '${n} DEVICES ARE WAITING TO JOIN THIS ACCOUNT',
	);
	@override String get accountEmailTitle => 'ACCOUNT EMAIL';
	@override String accountEmailSent({required Object email}) => 'CONFIRMATION SENT TO ${email}. OPEN THE LINK THERE TO FINISH THE CHANGE.';
	@override String get resendConfirmation => 'RESEND CONFIRMATION EMAIL';
	@override String resendConfirmationDescription({required Object email}) => 'WAITING ON ${email}';
	@override String accountEmailResent({required Object email}) => 'SENT AGAIN TO ${email}.';
	@override String get deviceLinked => 'THAT DEVICE IS NOW LINKED TO THIS ACCOUNT.';
	@override String get checking => 'CHECKING…';
	@override String get notLinked => 'NOT LINKED YET';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'REPLACE LOCAL DATA?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${n} OPERATION',
		other: '${n} OPERATIONS',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${n} QSO',
		other: '${n} QSOS',
	);
	@override String get counts => 'SYNCED DATA';
	@override String countsLocal({required Object qsos, required Object operations}) => 'THIS DEVICE: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'WAITING TO UPLOAD: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'SERVER: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'THIS DEVICE: CHECKING…';
	@override String get countsServerChecking => 'SERVER: CHECKING…';
	@override String get countsServerUnavailable => 'SERVER: NOT AVAILABLE';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'THIS BACKS UP AND CLEARS ${operations} AND ${qsos} FROM THIS DEVICE, THEN DOWNLOADS THE ACCOUNT\'S DATA INSTEAD. THE BACKUP STAYS IN THIS DEVICE\'S DATABASE.';
	@override String get replace => 'REPLACE';
	@override String get pendingBannerTitle => 'NEW HAM2K LOG FILER ACCOUNT DETECTED';
	@override String get pendingBannerBody => 'KEEP THIS DEVICE\'S EXISTING OPERATIONS AND QSOS AND MERGE THEM INTO THE ACCOUNT, OR REPLACE THEM WITH THE ACCOUNT\'S DATA (A BACKUP STAYS ON THIS DEVICE EITHER WAY).';
	@override String get combine => 'COMBINE';
	@override String get authIssueTitle => 'SYNC CAN\'T CONNECT';
	@override String get authIssueText => 'HAM2K LOG FILER KEEPS REJECTING THIS DEVICE. CHECK YOUR CALLSIGN IN SYNC SETTINGS.';
	@override String get openSettings => 'OPEN SYNC SETTINGS';
}

// Path: settings.accounts
class _Translations$settings$accounts$qro extends Translations$settings$accounts$en {
	_Translations$settings$accounts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ACCOUNTS, SERVICES & DATA SOURCES';
	@override String get none => 'NO ACTIVE EXTENSIONS WITH ACCOUNTS';
	@override String get notConfigured => 'NOT CONFIGURED';
	@override String get connected => 'CONNECTED';
	@override String get cancelLogin => 'CANCEL SIGN-IN';
	@override String get openInBrowser => 'OPEN IN BROWSER';
	@override String loggedInAs({required Object identity}) => 'LOGGED IN AS ${identity}';
	@override String get pressSaveToKeep => 'PRESS SAVE TO KEEP THIS ACCOUNT CONNECTED.';
	@override String connectedTo({required Object label}) => 'CONNECTED TO ${label}';
	@override String get connect => 'CONNECT';
	@override String get disconnect => 'DISCONNECT';
	@override String get connectedAs => 'CONNECTED AS';
	@override String get test => 'TEST';
	@override String saveFailed({required Object error}) => 'SAVE FAILED: ${error}';
	@override String loginFailed({required Object error}) => 'LOGIN FAILED: ${error}';
	@override String get lookupFailed => 'ACCOUNTS ARE UNAVAILABLE RIGHT NOW — TRY AGAIN IN A MOMENT';
	@override String get browserLoginTitle => 'FINISH SIGNING IN WITH YOUR WEB BROWSER';
	@override String browserLoginSteps({required Object prefix}) => 'WHEN YOU ARE DONE, THE BROWSER WILL TRY TO OPEN A LINK STARTING WITH "${prefix}". YOUR DESKTOP MOST LIKELY HAS NOTHING REGISTERED TO OPEN IT, SO COPY THAT LINK (FROM THE ADDRESS BAR, OR FROM THE ERROR PAGE THE BROWSER SHOWS) AND PASTE IT HERE.';
	@override String browserLoginNotOpened({required Object prefix}) => 'HAM2K LOGGER COULD NOT OPEN YOUR BROWSER. COPY THE LOGIN LINK BELOW AND OPEN IT YOURSELF, THEN COPY THE LINK IT SENDS YOU TO (IT STARTS WITH "${prefix}") AND PASTE THAT HERE.';
	@override String get copyLoginLink => 'COPY LOGIN LINK';
	@override String get pastedLinkLabel => 'PASTE THE LINK HERE';
	@override String get finishLogin => 'FINISH LOGIN';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'THAT IS NOT THE LOGIN LINK — IT SHOULD START WITH "${prefix}".';
	@override String get pastedLinkWrongLogin => 'THAT LINK BELONGS TO A DIFFERENT LOGIN ATTEMPT. CLOSE THIS PAGE AND CONNECT AGAIN.';
	@override String get pastedLinkNoCode => 'THAT LINK HAS NO LOGIN CODE. FINISH SIGNING IN FIRST, THEN COPY THE LINK IT SENDS YOU TO.';
	@override String get pastedLinkMalformed => 'THAT LINK LOOKS CUT OFF. COPY THE WHOLE THING AND PASTE IT AGAIN.';
	@override String get relayLoginWaiting => 'WAITING FOR YOU TO FINISH SIGNING IN — THIS WILL CONTINUE AUTOMATICALLY ONCE YOU DO.';
	@override String get loginNoResponse => 'THIS DEVICE HASN\'T HEARD BACK FROM THE SIGN-IN YET. IF YOU ALREADY FINISHED IN YOUR BROWSER, CANCEL AND TRY CONNECTING AGAIN.';
	@override String get relayLoginNotOpened => 'HAM2K LOGGER COULD NOT OPEN YOUR BROWSER AUTOMATICALLY. USE THE BUTTON BELOW TO OPEN THE LOGIN PAGE YOURSELF.';
	@override String get relayLoginUnavailable => 'COULDN\'T REACH THE SYNC SERVER NEEDED TO COMPLETE THIS LOGIN. CHECK YOUR CONNECTION AND TRY AGAIN.';
	@override String get loginIncompleteResponse => 'THAT LOGIN ATTEMPT DIDN\'T COMPLETE CORRECTLY. PLEASE TRY CONNECTING AGAIN.';
	@override String get noKeyringTitle => 'ACCOUNT LOGINS CAN’T BE SAVED';
	@override String get noKeyringText => 'HAM2K LOGGER CAN’T REACH A KEYRING SERVICE ON THIS COMPUTER, SO ACCOUNT LOGINS CAN’T BE STORED OR READ — CONNECTING AN ACCOUNT WILL FAIL UNTIL THIS IS SORTED. INSTALL AND START **GNOME-KEYRING**, **KWALLET** OR **KEEPASSXC**, OR UNLOCK THE KEYRING YOU ALREADY HAVE, THEN RESTART. LOGGING, EXPORTS AND DATA FILES ARE UNAFFECTED; LOG SYNC STAYS OFF WHILE THIS LASTS.';
	@override String get noKeyringInline => 'LOGINS CAN’T BE SAVED: THIS COMPUTER’S KEYRING CAN’T BE REACHED. INSTALL AND START GNOME-KEYRING, KWALLET OR KEEPASSXC, OR UNLOCK THE ONE YOU HAVE.';
	@override String get noSecureStorageInline => 'LOGINS CAN’T BE SAVED: THIS COMPUTER’S SECURE STORAGE CAN’T BE REACHED.';
}

// Path: settings.station
class _Translations$settings$station$qro extends Translations$settings$station$en {
	_Translations$settings$station$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'STATION CONFIGURATION & CAT CONTROL';
	@override String get none => 'NO EQUIPMENT CONFIGURED';
	@override String get add => 'ADD';
	@override String get addTitle => 'ADD EQUIPMENT';
	@override String get searchHint => 'SEARCH EQUIPMENT';
	@override String get noMatches => 'NO EQUIPMENT MATCHES';
	@override String get detectedEquipment => 'DETECTED EQUIPMENT';
	@override String discoveryUnavailable({required Object error}) => 'CAN\'T LISTEN FOR RADIOS: ${error}';
	@override String get edit => 'EDIT EQUIPMENT';
	@override String get name => 'NAME';
	@override String get nameDescription => 'WHAT YOU CALL IT — "LEFT RADIO". OPTIONAL.';
	@override String get transport => 'CONNECTION';
	@override String get host => 'ADDRESS';
	@override String get hostDescription => 'THE RADIO\'S HOSTNAME OR IP ADDRESS ON YOUR NETWORK.';
	@override String get port => 'PORT';
	@override String get hostRequired => 'AN ADDRESS IS REQUIRED';
	@override String get portInvalid => 'PORT MUST BE BETWEEN 1 AND 65535';
	@override String get connect => 'CONNECT';
	@override String get disconnect => 'DISCONNECT';
	@override String get remove => 'REMOVE';
	@override String removeTitle({required Object name}) => 'REMOVE ${name}?';
	@override String get removeMessage => 'THIS ONLY REMOVES IT FROM THE APP. THE EQUIPMENT\'S SETTINGS STAY AS THEY ARE.';
	@override String unknownType({required Object typeKey}) => 'UNRECOGNIZED EQUIPMENT TYPE "${typeKey}"';
	@override String get report => 'REPORT';
	@override String get reportTitle => 'REPORT THIS RADIO';
	@override String get reportIntro => 'TELL US WHAT RADIO THIS REALLY IS AND HOW IT WENT. YOUR REPORT BECOMES A CARD THE HAM2K TEAM READS, AND WHAT YOU WRITE ABOUT GETTING IT WORKING MAY END UP HELPING THE NEXT OPERATOR WITH THE SAME RIG.';
	@override String get reportManufacturer => 'MANUFACTURER';
	@override String get reportManufacturerDescription => 'WHO MAKES IT — ICOM, YAESU, KENWOOD, ELECRAFT…';
	@override String get reportManufacturerRequired => 'A MANUFACTURER IS REQUIRED';
	@override String get reportModel => 'MODEL';
	@override String get reportModelDescription => 'THE MODEL, AS THE RADIO ITSELF CALLS IT — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'A MODEL IS REQUIRED';
	@override String get reportOutcome => 'HOW DID IT GO?';
	@override String get reportOutcomeWorks => 'WORKED WELL';
	@override String get reportOutcomeIssues => 'WORKED, WITH ISSUES';
	@override String get reportOutcomeFails => 'DIDN\'T WORK AT ALL';
	@override String get reportOutcomeRequired => 'PLEASE TELL US HOW IT WENT';
	@override String get reportComments => 'COMMENTS';
	@override String get reportCommentsPlaceholder => 'WHAT WORKED, WHAT DIDN\'T, ANYTHING THAT SURPRISED YOU.';
	@override String get reportHints => 'TROUBLESHOOTING HINTS';
	@override String get reportHintsPlaceholder => 'WANT TO SUGGEST SOME TROUBLESHOOTING HINTS FOR OTHER USERS?';
	@override String get reportSend => 'SEND REPORT';
	@override String get reportSending => 'SENDING YOUR REPORT…';
	@override String reportSent({required Object ref}) => 'THANKS — YOUR REPORT WAS FILED AS ${ref}.';
	@override String get reportSentNoRef => 'THANKS — YOUR REPORT WAS SENT.';
	@override String reportFailed({required Object error}) => 'THE REPORT WASN\'T SENT: ${error}';
	@override String get troubleshootingNotes => 'TROUBLESHOOTING NOTES';
	@override String get mainVfo => 'MAIN VFO';
	@override String get useAsMainVfo => 'USE AS MAIN VFO';
	@override String get serialPort => 'SERIAL PORT';
	@override String get serialPortDescription => 'THE PORT THE RADIO\'S CAT INTERFACE APPEARS ON.';
	@override String get serialPortNone => 'NO SERIAL PORTS FOUND';
	@override String get serialPortRequired => 'CHOOSE A SERIAL PORT';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'PORT ${n} OF ${total}';
	@override String get serialPortSuggested => 'SUGGESTED';
	@override String get serialPortJustNow => 'RECENTLY CONNECTED';
	@override String get serialDeviceRequest => 'ADD A USB DEVICE…';
	@override String get bleDevice => 'BLUETOOTH LE DEVICE';
	@override String get bleDeviceDescription => 'THE SERIAL BRIDGE YOUR RADIO IS CONNECTED THROUGH, SUCH AS A LINK500MP IN ITS IOS MODE OR A BLE SERIAL ADAPTER.';
	@override String get bleScan => 'SCAN FOR BLUETOOTH LE DEVICES…';
	@override String get bleScanNoneFound => 'NO BLUETOOTH LE DEVICES FOUND. CHECK THAT THE BRIDGE IS ON, NEARBY, AND IN ITS BLUETOOTH LE (IOS) MODE.';
	@override String bleScanFailed({required Object reason}) => 'THE BLUETOOTH LE SCAN COULD NOT RUN: ${reason}';
	@override String get bleOff => 'BLUETOOTH IS TURNED OFF.';
	@override String get bleDenied => 'BLUETOOTH PERMISSION WAS NOT GRANTED. ALLOW IT IN SYSTEM SETTINGS, THEN TRY AGAIN.';
	@override String get bleUnsupported => 'THIS DEVICE HAS NO BLUETOOTH LE.';
	@override String get bleStarting => 'BLUETOOTH IS STILL STARTING UP. TRY AGAIN IN A MOMENT.';
	@override String get bleConnectFailed => 'CANNOT REACH THE BLUETOOTH LE DEVICE. CHECK THAT IT\'S ON, NEARBY, AND NOT CONNECTED TO ANOTHER APP.';
	@override String bleNoSerialService({required Object services}) => 'THIS BLUETOOTH LE DEVICE HAS NO SERIAL SERVICE THE APP RECOGNIZES. PLEASE REPORT IT WITH ITS SERVICES: ${services}';
	@override String get baudRate => 'SPEED (BAUD)';
	@override String get baudRateDescription => 'MUST MATCH THE RADIO\'S CAT MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE AND NO ERROR.';
	@override String get serialRtsHigh => 'HOLD RTS HIGH';
	@override String get serialRtsHighDescription => 'ONLY FOR A RADIO THAT WAITS FOR RTS BEFORE RESPONDING, SUCH AS A YAESU WITH CAT RTS TURNED ON. ON A DIGIRIG, SIGNALINK AND MOST HOME-MADE CABLES RTS IS PTT, AND HOLDING IT HIGH TRANSMITS.';
	@override String get serialDtrHigh => 'HOLD DTR HIGH';
	@override String get serialDtrHighDescription => 'ONLY FOR A CAT INTERFACE THAT DRAWS ITS POWER FROM DTR, SUCH AS SOME RS-232 CABLES FOR THE FT-817. ON MANY CABLES DTR KEYS CW OR PTT, AND HOLDING IT HIGH TRANSMITS.';
	@override String get civAddress => 'RADIO CI-V ADDRESS';
	@override String get civAddressDescription => 'HEX, AS SHOWN IN THE RADIO\'S CI-V MENU. THE IC-705 SHIPS AS A4.';
	@override String get civAddressInvalid => 'A CI-V ADDRESS IS TWO HEX DIGITS, 01 TO FF';
	@override String get flexSlice => 'SLICE';
	@override String get flexSliceDescription => 'WHICH OF THE RADIO\'S SLICES THIS CONNECTION READS FROM AND TUNES.';
	@override String flexSliceLabel({required Object letter}) => 'SLICE ${letter}';
	@override String get flexSliceInvalid => 'PICK ONE OF THE RADIO\'S SLICES, A THROUGH H';
	@override String flexSliceMissing({required Object letter}) => 'SLICE ${letter} IS NOT IN USE ON THIS RADIO — PICK ANOTHER SLICE, OR CREATE IT IN SMARTSDR';
	@override String get channelNotInUse => 'NOT IN USE';
	@override String get channelHeldByUnknown => 'IN USE BY ANOTHER PROGRAM';
	@override String get flexNoSlices => 'THIS RADIO HAS NOT REPORTED ANY SLICES — CHECK THAT SMARTSDR IS RUNNING AND THAT THIS CLIENT MAY SUBSCRIBE';
	@override String get spectrumUnsupported => 'THIS RADIO SENDS NO SPECTRUM OVER CAT';
	@override String get spectrumRequiresBaud => 'REQUIRES CAT AT 115200 BPS';
	@override String get spectrumNoRadio => 'NO RADIO CONNECTED';
	@override String get spectrumWaiting => 'WAITING FOR THE RADIO\'S SPECTRUM…';
	@override String get spectrumUnavailable => 'SPECTRUM DISPLAY IS NOT AVAILABLE';
	@override String get spectrumNoDaxChannel => 'EVERY DAX IQ CHANNEL ON THIS RADIO IS IN USE';
	@override String get spectrumNoPanadapter => 'THIS SLICE HAS NO PANADAPTER ON THE RADIO';
	@override String spectrumStreamRefused({required Object code}) => 'THE RADIO REFUSED A DAX IQ STREAM (ERROR ${code})';
	@override String get spectrumNoUdp => 'THE RADIO\'S SPECTRUM DATA CANNOT REACH THIS DEVICE';
	@override String get spectrumK4Unavailable => 'CANNOT RECEIVE THE K4’S LAN SPECTRUM. RETRYING…';
	@override String get spectrumK4RemoteUnavailable => 'CANNOT RECEIVE THE K4’S REMOTE SPECTRUM';
	@override String get spectrumScopeRefused => 'THE RADIO REFUSED ITS SCOPE COMMANDS';
	@override String get spectrumOutOfRange => 'THE RADIO\'S SCOPE IS SET OUTSIDE THE RANGE IT CAN SHOW';
	@override String get spectrumBandUnsupported => 'THE RADIO\'S SCOPE CANNOT BE SHOWN ON THIS BAND';
	@override String get spectrumSdrNoRadio => 'WAITING FOR THE LINKED RADIO\'S FREQUENCY…';
	@override String get spectrumSdrNotConnected => 'THE SDR IS NOT CONNECTED';
	@override String get spectrumSdrNoIf => 'SET THE RADIO\'S IF FREQUENCY IN THIS SDR\'S SETTINGS';
	@override String get sdrRadio => 'SHOWS THE SPECTRUM FOR';
	@override String get sdrRadioDescription => 'A SPECTRUM DISPLAY ON THIS RADIO DRAWS FROM THIS RECEIVER INSTEAD OF THE RADIO\'S OWN SCOPE.';
	@override String get sdrRadioMain => 'THE MAIN RADIO';
	@override String get sdrTuning => 'ANTENNA INPUT';
	@override String get sdrTuningDescription => 'WHERE THE RECEIVER\'S SIGNAL COMES FROM. ON ITS OWN ANTENNA IT TUNES ITSELF TO FOLLOW THE RADIO; ON THE RADIO\'S IF OUTPUT IT STAYS ON THE IF.';
	@override String get sdrTuningIndependent => 'ITS OWN ANTENNA';
	@override String get sdrTuningIfTap => 'THE RADIO\'S IF OUTPUT';
	@override String get sdrIfHz => 'IF FREQUENCY (HZ)';
	@override String get sdrIfHzDescription => 'FOR AN IF OUTPUT ONLY: THE FREQUENCY THE RADIO\'S DIAL SITS AT ON ITS IF, SUCH AS 68330000 ON AN FT-817.';
	@override String get sdrIfInverted => 'IF IS INVERTED';
	@override String get sdrGainDb => 'GAIN (DB)';
	@override String get sdrGainDbDescription => 'LEAVE BLANK FOR THE RECEIVER\'S AUTOMATIC GAIN.';
	@override String get sdrOffsetHz => 'FREQUENCY OFFSET (HZ)';
	@override String get sdrOffsetHzDescription => 'ADDED TO EVERY FREQUENCY SENT TO THE RECEIVER, FOR AN UPCONVERTER: 125000000 FOR A HAM IT UP.';
	@override String get sdrPpm => 'FREQUENCY CORRECTION (PPM)';
	@override String get rtlDirectSampling => 'DIRECT SAMPLING';
	@override String get rtlDirectSamplingDescription => 'FOR HF ON AN RTL-SDR V3 WITHOUT AN UPCONVERTER. AN RTL-SDR V4 REACHES HF WITHOUT IT.';
	@override String get rtlDirectSamplingOff => 'OFF';
	@override String get rtlDirectSamplingI => 'I BRANCH';
	@override String get rtlDirectSamplingQ => 'Q BRANCH';
	@override String get rtlTcpNotAServer => 'THIS IS NOT AN RTL_TCP SERVER';
	@override String get rtlTcpNotes => 'THIS CONNECTS TO AN **RTL_TCP SERVER YOU RUN YOURSELF** ON THE COMPUTER THE DONGLE IS PLUGGED INTO.\n\n- **START IT** WITH `rtl_tcp -a 0.0.0.0` SO OTHER MACHINES CAN REACH IT; ON THE SAME MACHINE, `rtl_tcp` ALONE WILL DO.\n- **PORT** IS 1234 UNLESS YOU STARTED IT WITH `-p`.\n- **ONE PROGRAM AT A TIME:** RTL_TCP SERVES A SINGLE CLIENT. THE APP CONNECTS ONLY WHILE A SPECTRUM DISPLAY IS SHOWING, AND LETS GO A FEW SECONDS AFTER IT CLOSES.\n- **ON ANDROID**, THE *SDR DRIVER* APP RUNS THE SAME SERVER ON THE PHONE.';
	@override String get rspTcpNotes => 'THIS CONNECTS TO AN **RSP_TCP SERVER YOU RUN YOURSELF** ON THE COMPUTER THE RSP IS PLUGGED INTO, WITH SDRPLAY\'S API INSTALLED THERE.\n\n- **START IT** WITH `rsp_tcp -a 0.0.0.0`.\n- **PORT** IS 1234 UNLESS YOU STARTED IT WITH `-p`.\n- **ONE PROGRAM AT A TIME:** THE SERVER TAKES A SINGLE CLIENT. THE APP CONNECTS ONLY WHILE A SPECTRUM DISPLAY IS SHOWING.';
	@override String get n3fjpNoRig => 'N3FJP HAS NO RADIO INTERFACE SET UP, SO THIS FOLLOWS WHAT IS TYPED INTO N3FJP, NOT A RADIO';
	@override String get winkeyerKeyPort => 'KEY OUTPUT';
	@override String get winkeyerKeyPortDescription => 'WHICH OF THE KEYER\'S TWO OUTPUT JACKS YOUR RADIO IS PLUGGED INTO.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'PORT ${n}';
	@override String get winkeyerPtt => 'USE THE KEYER\'S PTT';
	@override String get winkeyerPttDescription => 'KEY THE PTT LINE ON THE SAME JACK, FOR AN AMPLIFIER OR A RADIO THAT NEEDS IT. LEAVE OFF FOR A RADIO KEYED ON ITS KEY JACK.';
	@override String get winkeyerNoAnswer => 'NO WINKEYER RESPONDED ON THIS PORT';
	@override String get winkeyerStoppedAnswering => 'THE WINKEYER STOPPED RESPONDING WHILE SENDING; THE MESSAGE WAS DROPPED';
	@override String get icomControlPort => 'CONTROL PORT (UDP)';
	@override String get icomControlPortDescription => 'THE RADIO\'S CONTROL PORT (UDP) — 50001 UNLESS CHANGED IN ITS NETWORK SETTINGS, OR FORWARDED TO ANOTHER.';
	@override String get icomSerialPort => 'SERIAL PORT (UDP)';
	@override String get icomSerialPortDescription => 'THE RADIO\'S SERIAL PORT (UDP) — 50002 UNLESS CHANGED IN ITS NETWORK SETTINGS, OR FORWARDED TO ANOTHER.';
	@override String get icomPortsDiffer => 'THE CONTROL AND SERIAL PORTS MUST DIFFER';
	@override String get radioUser => 'RADIO USERNAME';
	@override String get radioPass => 'RADIO PASSWORD';
	@override String get radioLoginDescription => 'THE RADIO\'S NETWORK → REMOTE LOGIN, NOT YOUR WIFI PASSWORD.';
	@override String get radioUserRequired => 'THE RADIO\'S REMOTE-CONTROL USERNAME IS REQUIRED';
	@override String get connectFailedBusy => 'DEVICE IS IN USE';
	@override String get connectFailedDenied => 'ACCESS DENIED';
	@override String get connectFailedDevice => 'DEVICE NOT FOUND';
	@override String get connectFailedLines => 'RTS/DTR COULD NOT BE HELD AS SET, SO THE PORT WAS CLOSED. ANOTHER PROGRAM MAY HAVE LEFT HARDWARE HANDSHAKING ON — UNPLUG AND REPLUG THE CABLE.';
	@override String get connectFailedNetwork => 'CANNOT FIND THE RADIO OVER THE NETWORK. CHECK ITS ADDRESS AND THAT IT\'S POWERED ON AND REACHABLE.';
	@override String get connectFailedTimeout => 'THE RADIO DIDN\'T RESPOND IN TIME. CHECK IT\'S POWERED ON AND REACHABLE.';
	@override late final _Translations$settings$station$models$qro models = _Translations$settings$station$models$qro._(_root);
	@override late final _Translations$settings$station$transports$qro transports = _Translations$settings$station$transports$qro._(_root);
	@override String get troubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get ft891Troubleshooting => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **CAT RTS OFF AT THE RADIO, OR HOLD RTS HIGH ON.** WITH **CAT RTS** ON (FT-891 MENU **05-08**), THE RADIO STAYS SILENT WHILE RTS IS LOW — IT MAY ANSWER ONCE AS THE PORT OPENS, THEN NOTHING. PICKING THE RADIO\'S OWN USB PORT TURNS ON **HOLD RTS HIGH** UNDER ADVANCED SETTINGS. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES RTS IS PTT, AND HOLDING IT HIGH KEYS YOUR TRANSMITTER: TURN CAT RTS OFF AT THE RADIO INSTEAD.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE (MENU **05-06**). WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.';
	@override String get yaesuBinaryTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get yaesuBinaryTroubleshooting => 'THIS RADIO SPEAKS YAESU\'S OLDER FIVE-BYTE CAT, AND IT DOES NOT RESPOND AT ALL WHEN SOMETHING IS OFF. ALMOST ALWAYS ONE OF:\n\n- **THE CABLE MUST CONVERT LEVELS.** THE CAT JACK ON THE BACK IS NOT RS-232 AND NOT USB; IT NEEDS A CT-62 OR AN EQUIVALENT ADAPTER. A PLAIN AUDIO OR DATA CABLE WON\'T WORK FOR CAT.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU (**#14** ON AN FT-817, **#19** ON AN FT-857 OR FT-897). WITH A MISMATCH, THE RADIO SENDS NOTHING BACK, AND NEVER AN ERROR.\n- **NEVER LET ANYTHING RAISE RTS OR DTR ON THIS PORT.** ON MOST CABLES FOR THESE RADIOS THOSE LINES ARE PTT AND KEYING. AN OLDER INTERFACE POWERED FROM DTR IS THE EXCEPTION: TURN ON **HOLD DTR HIGH** UNDER ADVANCED SETTINGS FOR THAT ONE.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS DRIVER WAS WRITTEN FROM YAESU\'S PUBLISHED CAT CHART AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get tenTecTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get tenTecEagleTroubleshooting => '- **THE USB-B PORT ON THE BACK IS THE CAT LINK.** THE RADIO SHOWS UP AS A USB SERIAL PORT; ON WINDOWS IT NEEDS TEN-TEC\'S USB TO UART DRIVER, WHICH APPEARS IN DEVICE MANAGER AS "USB TO UART (COMX)".\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN, AND SO DOES TEN-TEC\'S FIRMWARE UPDATER.\n- **SETTING THE FILTER WIDTH FROM THE APP TAKES IT AWAY FROM THE BW KNOB** UNTIL THE RADIO IS SWITCHED OFF AND ON AGAIN. THAT IS HOW THE RADIO WORKS.\n\nTHIS DRIVER WAS WRITTEN FROM TEN-TEC\'S PROGRAMMER\'S REFERENCE GUIDE. IF IT HALF-WORKS, THAT IS WORTH REPORTING, WITH THE FIRMWARE VERSION FROM THE RADIO\'S MENU.';
	@override String get tenTecOrionTroubleshooting => '- **USE A STRAIGHT-THROUGH DB-9 SERIAL CABLE** TO THE SERIAL DATA PORT, NOT A NULL-MODEM ONE.\n- **THIS ENTRY HOLDS RTS HIGH**, BECAUSE THE ORION USES RTS AND CTS AS ITS HANDSHAKE. ON AN INTERFACE THAT KEYS PTT FROM RTS, SUCH AS A DIGIRIG, TURN OFF HOLD RTS HIGH UNDER ADVANCED SETTINGS, OR THE RADIO TRANSMITS AS SOON AS THE APP CONNECTS.\n- **CW FROM THE APP NEEDS THE RADIO\'S INTERNAL KEYER ON.** WITH IT OFF, THE RADIO IGNORES WHAT THE APP SENDS.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS DRIVER WAS WRITTEN FROM TEN-TEC\'S PROGRAMMER\'S REFERENCE GUIDE AND HAS NOT BEEN RUN AGAINST AN ORION. IF IT HALF-WORKS, THAT IS WORTH REPORTING, WITH THE FIRMWARE VERSION FROM THE RADIO\'S MENU.';
	@override String get tenTecNoCw => 'THIS RADIO\'S FIRMWARE DOES NOT TAKE CW FROM THE APP. TEN-TEC ADDED IT IN ORION FIRMWARE 1.366.';
	@override String get tenTecKeyerOff => 'THE RADIO\'S INTERNAL KEYER IS OFF, SO IT IGNORES CW SENT FROM THE APP. TURN THE KEYER ON IN THE RADIO\'S MENU.';
	@override String get guohetecTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get guohetecTroubleshooting => 'THE Q900 HAS TWO CAT PROTOCOLS, AND THIS ENTRY USES ITS NATIVE ONE RATHER THAN THE FT-817 IMITATION. PICK **GUOHETEC Q900** HERE, NOT AN FT-817 — THE IMITATION SUPPORTS FEWER COMMANDS, AND THE RADIO DOES NOT SAY WHICH ONE IT IS USING.\n\n- **THE USB-C CABLE IS THE CAT LINK**, AND IT CONNECTS THE SOUND CARD TOO. SPEED DOES NOT MATTER ON IT; THE PORT IGNORES WHATEVER IT IS SET TO.\n- **NEVER LET ANYTHING RAISE RTS OR DTR ON THIS PORT.** ON A SERIAL CABLE THOSE LINES ARE PTT AND KEYING.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **A SECOND-GENERATION RADIO BEHAVES DIFFERENTLY** FROM A FIRST. LONG PRESS MENU, THEN ABOUT: HW 2.0 IS THE SECOND GENERATION.\n\nTHIS DRIVER WAS WRITTEN FROM THE MANUFACTURER\'S PUBLISHED PROTOCOL AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get yaesuTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get yaesuTroubleshooting => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **CAT RTS MUST BE OFF AT THE RADIO.** WITH IT ON, THE RADIO WAITS FOR A HANDSHAKE LINE THE APP KEEPS LOW. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES THAT SAME LINE IS PTT, SO RAISING IT WOULD KEY YOUR TRANSMITTER. ON THE RADIO\'S OWN USB PORT, **HOLD RTS HIGH** UNDER ADVANCED SETTINGS IS THE ALTERNATIVE. WHERE THAT SETTING LIVES DIFFERS BY MODEL (MENU **05-08** ON AN FT-891).\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **MODES FOLLOW THE FT-891\'S TABLE.** MOST OF THE YAESU LINE MATCHES IT, BUT A RADIO THAT NUMBERS ITS MODES DIFFERENTLY WILL SHOW AND SET THE WRONG ONE FOR THOSE. THE FREQUENCY IS UNAFFECTED.';
	@override String get yaesuRs232Troubleshooting => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **THE CAT JACK IS RS-232.** IT NEEDS A USB-TO-SERIAL ADAPTER AND A STRAIGHT-THROUGH DB-9 CABLE — A NULL-MODEM CABLE SWAPS THE LINES, AND THE RADIO NEVER HEARS A THING.\n- **CAT RTS MUST BE OFF AT THE RADIO.** WITH IT ON, THE RADIO WAITS FOR A HANDSHAKE LINE THE APP KEEPS LOW UNLESS **HOLD RTS HIGH** IS ON UNDER ADVANCED SETTINGS.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS ENTRY WAS WRITTEN FROM PUBLISHED CAT DOCUMENTATION AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get yaesuUsbTroubleshooting => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **USE THE FIRST OF THE RADIO\'S TWO USB PORTS.** CAT IS NORMALLY ON THE FIRST (THE **ENHANCED** COM PORT ON WINDOWS); THE SECOND (**STANDARD**) IS FOR PTT AND KEYING. THE PICKER POINTS AT THE FIRST WHEREVER IT CAN TELL THE TWO APART.\n- **CAT RTS OFF AT THE RADIO, OR HOLD RTS HIGH ON.** WITH THE RADIO\'S **CAT RTS** MENU ON, IT STAYS SILENT WHILE RTS IS LOW — IT MAY ANSWER ONCE AS THE PORT OPENS, THEN NOTHING. PICKING THE RADIO\'S OWN USB PORT TURNS ON **HOLD RTS HIGH** UNDER ADVANCED SETTINGS. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES RTS IS PTT, AND HOLDING IT HIGH KEYS YOUR TRANSMITTER: TURN CAT RTS OFF AT THE RADIO INSTEAD.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.';
	@override String get k4SerialNotes => 'CONNECT THE K4’S REAR USB-B (PC) SOCKET. EITHER USB-PC1 OR USB-PC2 WORKS FOR CAT; CHOOSE AN UNUSED PORT AND MATCH ITS SERIAL USB-PCN: BAUD RATE SETTING ON THE RADIO. HALO PREFILLS 38400; CHANGE IT IF NEEDED. ANOTHER APPLICATION MUST USE THE OTHER PORT OR ETHERNET.\n\nTHIS CONNECTION CONTROLS THE RADIO AND ITS KEYERS; IT DOES NOT SEND AUDIO TO HALO.';
	@override String get k4TcpNotes => 'CONNECT THE K4’S ETHERNET SOCKET TO YOUR LOCAL NETWORK. ENTER ITS HOSTNAME OR IP ADDRESS AND CAT PORT 9200. HALO USES THE SAME HOST ON FIXED PORT 9201 WHEN A PANADAPTER OR WATERFALL IS VISIBLE; CHANGING THE CAT PORT DOES NOT CHANGE THE SPECTRUM PORT.\n\nTHE SPECTRUM SHOWS THE MAIN RECEIVER. ITS ZOOM, REFERENCE ADJUSTMENT AND SPEED CONTROLS AFFECT ONLY HALO’S DISPLAY. AUDIO STREAMING IS NOT SUPPORTED.';
	@override String get k4PowerTimeout => 'K4 POWER WAS NOT CHANGED BECAUSE THE RADIO DID NOT CONFIRM ITS OUTPUT RANGE. TRY AGAIN.';
	@override String get k4RemoteNotes => 'ENABLE REMOTE ACCESS ON YOUR K4 AND ENTER ITS NETWORK PASSWORD. MAIN AND SUB SHARE ONE ENCRYPTED CONNECTION FOR RADIO CONTROL AND SPECTRUM. THE DEFAULT PORT IS 9204; ENTER YOUR FORWARDED PORT WHEN CONNECTING REMOTELY.\n\nAUDIO PLAYBACK AND MICROPHONE STREAMING ARE NOT SUPPORTED.';
	@override String get k4Receiver => 'RECEIVER';
	@override String get k4ReceiverMain => 'MAIN';
	@override String get k4ReceiverSub => 'SUB';
	@override String get k4ReceiverInvalid => 'CHOOSE MAIN OR SUB';
	@override String get k4ReceiverAlreadyConfigured => 'THAT RECEIVER IS ALREADY CONFIGURED FOR THIS K4';
	@override String get k4SubReceiverOff => 'THE K4 SUB RECEIVER IS OFF';
	@override String get k4RemotePasswordRequired => 'ENTER THE K4’S NETWORK PASSWORD TO CONNECT SECURELY.';
	@override String get k4RemoteHandshakeFailed => 'THE K4 COULD NOT ESTABLISH A SECURE CONNECTION. CHECK ITS NETWORK PASSWORD AND REMOTE ACCESS SETTINGS.';
	@override String get k4RemoteUnreachable => 'THE K4’S SECURE CONNECTION COULD NOT BE REACHED. CHECK ITS ADDRESS, PORT AND REMOTE ACCESS SETTINGS.';
	@override String get k4PowerRange => 'K4 POWER MUST BE 0.1–110 W, OR 0.0001–0.01 W WHEN THE TRANSVERTER MILLIWATT OUTPUT IS ACTIVE.';
	@override String get elecraftTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get elecraftTroubleshooting => 'ELECRAFT RIGS SPEAK KENWOOD CAT, AND A KX2 AND A KX3 HAVE BOTH BEEN RUN THIS WAY — VFO IN BOTH DIRECTIONS, MODE SWITCHING AND CW ZERO-BEAT ALL WORKING.\n\nIF THE RADIO DOES NOT RESPOND, ALMOST ALWAYS ONE OF:\n\n- **SPEED MUST MATCH** THE RATE SET UNDER **RS232** IN THE RADIO\'S MENU. 38400 IS WHAT THESE SHIP ON. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\n**IF THE FREQUENCY IS RIGHT BUT THE MODE IS WRONG**, TELL US. THE KX2 AND KX3 ENTRIES READ THE MODE FROM A POSITION IN THE RADIO\'S STATUS REPLY THAT WE HAVE PINNED FROM THE RIGS WE HAVE SEEN, AND A FIRMWARE THAT PUTS IT ELSEWHERE IS SOMETHING ONLY A REPORT REACHES US AS.\n\nTHE K3 HAS NOT BEEN REPORTED EITHER WAY, SO PLEASE SAY WHAT HAPPENS IF YOU RUN ONE. A K4 HAS ITS OWN ENTRY.';
	@override String get lab599TroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get lab599Troubleshooting => 'THE TX-500 LINE SPEAKS KENWOOD CAT. WRITTEN FROM PUBLISHED REFERENCES RATHER THAN TESTED ON THE RADIO, SO PLEASE REPORT WHAT HAPPENS EITHER WAY.\n\n- **SPEED MUST MATCH** THE RADIO\'S CAT SETTING, 9600 UNLESS YOU CHANGED IT. WITH A MISMATCH THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **PICK THE CAT PROTOCOL ON THE RADIO.** TS-2000 COVERS FREQUENCY AND MODE. LAB599 ALSO LETS THE APP SWITCH THE RADIO TO DIG.\n- **THROUGH A LINK500MP**, PRESS AND HOLD THE VFO KNOB FOR ABOUT THREE SECONDS TO HAND CAT CONTROL TO THE INTERFACE.\n- **OVER BLUETOOTH ON A COMPUTER**, THE LINK500MP PAIRS AS TWO SERIAL PORTS AND ONLY ONE CARRIES CAT. IF THE RADIO STAYS SILENT, PICK THE OTHER.\n- **OVER BLUETOOTH LE**, AS ON AN IPHONE OR IPAD, SWITCH THE LINK500MP TO ITS IOS MODE FIRST. IN ITS OTHER MODES IT DOES NOT SHOW UP IN A SCAN.';
	@override String get kenwoodTroubleshootingTitle => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY';
	@override String get kenwoodTroubleshooting => 'THIS DRIVER IS PROVEN AGAINST KENWOOD\'S TS-590SG AND TS-480, QRP LABS\' QMX AND QCX-MINI, AND ELECRAFT\'S KX2 AND KX3. THE REST OF THE LINE IS WRITTEN FROM PUBLISHED CAT REFERENCES, SO PLEASE REPORT WHAT HAPPENS EITHER WAY.\n\nIF THE RADIO DOES NOT RESPOND, ALMOST ALWAYS ONE OF:\n\n- **SPEED MUST MATCH** THE RADIO\'S CAT MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **SOME RIGS NEED CAT ENABLED** IN THE MENU BEFORE THEY RESPOND AT ALL.\n\n**SEVERAL SDR FRONT-ENDS SPEAK THIS SAME PROTOCOL**, SO THIS ENTRY IS WORTH TRYING FOR THOSE TOO; ELECRAFT RIGS ARE LISTED SEPARATELY, UNDER ELECRAFT. IF THE FREQUENCY IS RIGHT BUT THE MODE IS WRONG OR MISSING, THAT IS THE ONE PART THAT DIFFERS ACROSS THE LINE — THE APP WORKS IT OUT FROM THE RADIO AND FALLS BACK TO ASKING DIRECTLY, SO THE MODE MAY SIMPLY LAG.';
	@override String get statusConnected => 'CONNECTED';
	@override String get statusLost => 'DISCONNECTED';
	@override String get notConfigured => 'NOT CONFIGURED';
	@override String get currentConfiguration => 'CURRENT CONFIGURATION';
	@override String get currentTransceiver => 'CURRENT TRANSCEIVER';
	@override String get radioMode => 'RADIO MODE';
	@override String get keyerNotSupported => 'NOT SUPPORTED BY CURRENT RADIO';
	@override String get catControlPreferences => 'CAT CONTROL PREFERENCES';
	@override String get chooseTransceiver => 'CHOOSE TRANSCEIVER';
	@override String get configurationSection => 'CONFIGURATION';
	@override String get noTransceiverSelected => 'NO TRANSCEIVER SELECTED';
	@override String makeMainVfo({required Object name}) => 'USE ${name} FOR THE MAIN VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		zero: 'NO TRANSCEIVERS',
		one: '${count} TRANSCEIVER',
		other: '${count} TRANSCEIVERS',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} ANTENNA',
		other: '${count} ANTENNAS',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} OTHER DEVICE',
		other: '${count} OTHER DEVICES',
	);
	@override String get equipmentInventory => 'EQUIPMENT INVENTORY';
	@override String get equipmentInUse => 'TRANSCEIVER CONTROLS';
	@override String get noTransceiver => 'NONE';
	@override String get peerRadioNotAvailable => 'NOT AVAILABLE';
	@override String peerRadioOnDevice({required Object device}) => 'ON ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} IS ON ANOTHER DEVICE';
	@override String peerRadioElsewhereMessage({required Object device}) => 'THIS RADIO IS CONNECTED TO ${device}. ITS CONNECTION AND SETTINGS ARE CONFIGURED ON THAT DEVICE.';
	@override String get antennaInUse => 'ANTENNA IN USE';
	@override String get keyInUse => 'KEY IN USE';
	@override String get noneSelected => 'NONE';
	@override String get moreSettings => 'MORE SETTINGS';
	@override String get icomCivTroubleshootingTitle => 'IF TWO SERIAL PORTS SHOW UP FOR THE SAME RADIO';
	@override String get icomCivTroubleshooting => 'SEVERAL ICOM RADIOS, THE IC-705 AMONG THEM, PRESENT **TWO** USB SERIAL PORTS AT ONCE (ICOM CALLS THEM PORT A AND PORT B), BOTH SET TO CI-V BY DEFAULT. NEITHER THIS APP NOR YOUR OS CAN TELL THEM APART BEYOND THAT: THE SAME USB VENDOR/PRODUCT ID JUST SHOWS UP TWICE, SOMETIMES MARKED WITH A `#2` SUFFIX HERE. **PORT A IS USUALLY THE RIGHT ONE** — NORMALLY THE FIRST ONE YOUR OS OR BROWSER LISTS, AND WHERE THIS APP CAN TELL THE TWO PORTS APART IT MARKS THAT ONE AS SUGGESTED. IF COMMANDS GO OUT AND THE RADIO NEVER RESPONDS, TRY THE OTHER PORT NEXT.';
	@override String get civAddressTroubleshootingTitle => 'IF THE RADIO NEVER RESPONDS';
	@override String get civAddressTroubleshooting => '- **THE CI-V ADDRESS MUST MATCH** THE RADIO\'S MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH, BUT A RIG SHARING A CI-V BUS IS EXACTLY WHERE THAT GETS CHANGED. A FRAME SENT TO THE WRONG ADDRESS IS IGNORED IN SILENCE, WHICH LOOKS EXACTLY LIKE A DEAD CABLE.\n- **SPEED MUST MATCH** THE RADIO\'S CI-V BAUD RATE (ON USB, CI-V USB BAUD RATE). SET THE RADIO TO THE SAME NUMBER SHOWN HERE, **NOT AUTO**. ON AUTO SOME RADIOS, THE IC-7300 AMONG THEM, CONNECT AND THEN STOP RESPONDING AFTER A MINUTE OR SO.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **THE CI-V ADDRESS MUST MATCH** THE RADIO\'S MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH, BUT A RIG SHARING A CI-V BUS IS EXACTLY WHERE THAT GETS CHANGED. A FRAME SENT TO THE WRONG ADDRESS IS IGNORED IN SILENCE, WHICH LOOKS EXACTLY LIKE A DEAD CABLE.\n${speed}\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.';
	@override String get icomUsbSpeedFollows => '- **THERE IS NO SPEED TO SET.** OVER USB THIS RADIO TALKS AT WHATEVER SPEED THE COMPUTER USES, AND THIS ENTRY ALWAYS USES 115200, THE SPEED THE SCOPE NEEDS.';
	@override String get ic7610UsbSpeed => '- **SET CI-V USB BAUD RATE TO 115200**, THE SPEED THIS ENTRY ALWAYS USES, SINCE THE SCOPE NEEDS IT — **NOT AUTO**. A RADIO SET TO ANY OTHER SPEED ANSWERS WITH SILENCE.';
	@override String get ic7300Mk2Note => '\n- THE **IC-7300 MK2** SHIPS ON ADDRESS `B6`, NOT THE `94` PREFILLED HERE — PICK THE IC-7300 MK2 ENTRY INSTEAD.';
	@override String get ic705PortNote => '\n- THE **IC-705** PRESENTS TWO USB SERIAL PORTS, BOTH NAMED AFTER THE RADIO. CI-V IS ON THE **FIRST** OF THEM, WHICH THE PICKER POINTS AT WHEREVER IT CAN TELL THE TWO APART.';
	@override String get ic7760PortNote => '\n- THE **IC-7760** SPEAKS CI-V ON **PORT A** OF THE TWO USB SERIAL PORTS IT PRESENTS.';
	@override String get x6100PortNote => '\n- THE **X6100** SPEAKS CI-V ON ITS **DEV** PORT — THE SECOND OF THE TWO SERIAL PORTS IT PRESENTS, AND THE ONE THE PICKER POINTS AT.';
	@override String get rigctldTroubleshootingTitle => 'IF THE APP CANNOT CONNECT';
	@override String get rigctldTroubleshooting => 'THIS CONNECTS TO A **RIGCTLD DAEMON YOU RUN YOURSELF**, NOT TO THE RADIO DIRECTLY — HAMLIB\'S BACKEND TALKS TO THE RADIO AND SUPPORTS HUNDREDS OF MODELS.\n\n- **THE DAEMON MUST ALREADY BE RUNNING**, E.G. `rigctld -m 1035 -r /dev/ttyUSB0`. FIND YOUR RADIO\'S MODEL NUMBER WITH `rigctl -l`.\n- **FROM ANOTHER MACHINE**, START IT WITH `-T 0.0.0.0`: BY DEFAULT RIGCTLD ONLY ACCEPTS CONNECTIONS FROM THE MACHINE IT RUNS ON.\n- **PORT** IS 4532 UNLESS YOU STARTED THE DAEMON WITH `-t`.\n- ONCE CONNECTED, A MISSING FREQUENCY USUALLY MEANS THE DAEMON ITSELF CANNOT REACH THE RADIO. TEST IT WITH `rigctl -m 2 f` ON THE DAEMON\'S MACHINE.';
	@override String get flrigTroubleshootingTitle => 'IF THE APP CANNOT CONNECT';
	@override String get flrigTroubleshooting => 'THIS CONNECTS TO AN **FLRIG PROGRAM YOU RUN YOURSELF**, NOT TO THE RADIO DIRECTLY — FLRIG TALKS TO THE RADIO AND SUPPORTS MOST MAKES AND MODELS.\n\n- **FLRIG MUST ALREADY BE RUNNING**, WITH ITS TRANSCEIVER CONFIGURED AND CONNECTED.\n- **PORT** IS 12345 UNLESS YOU CHANGED IT IN FLRIG\'S CONFIGURATION (CONFIG → SETUP → SERVER).\n- **FROM ANOTHER MACHINE**, MAKE SURE FLRIG\'S SERVER IS REACHABLE. IT LISTENS ON ALL INTERFACES, BUT YOUR FIREWALL MAY NOT AGREE.\n- ONCE CONNECTED, A MISSING FREQUENCY USUALLY MEANS FLRIG ITSELF CANNOT REACH THE RADIO. CHECK THAT FLRIG\'S DISPLAY IS FOLLOWING THE DIAL.';
	@override String get hrdTroubleshootingTitle => 'IF THE APP CANNOT CONNECT';
	@override String get hrdTroubleshooting => 'THIS CONNECTS TO **HAM RADIO DELUXE\'S RIG CONTROL, RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — HRD TALKS TO THE RADIO.\n\n- **RIG CONTROL MUST ALREADY BE RUNNING** AND CONNECTED TO THE RADIO.\n- **ITS IP SERVER MUST BE ENABLED.** RIG CONTROL ONLY TALKS TO OTHER PROGRAMS THROUGH IT.\n- **PORT** IS 7809 UNLESS YOU CHANGED IT IN THE IP SERVER\'S SETTINGS.\n- **FROM ANOTHER MACHINE**, MAKE SURE YOUR FIREWALL LETS THE CONNECTION THROUGH.\n\nTHIS ENTRY WAS WRITTEN FROM PUBLISHED DESCRIPTIONS OF HRD\'S PROTOCOL AND HAS NOT BEEN RUN AGAINST HRD. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get n3fjpTroubleshootingTitle => 'IF THE APP CANNOT CONNECT';
	@override String get n3fjpTroubleshooting => 'THIS CONNECTS TO **AN N3FJP LOGGING PROGRAM RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — N3FJP TALKS TO THE RADIO.\n\n- **THE PROGRAM\'S API MUST BE ON**: SETTINGS → APPLICATION PROGRAM INTERFACE, CHECK **TCP API ENABLED**.\n- **PORT** IS 1100 UNLESS YOU CHANGED IT THERE.\n- **N3FJP MUST HAVE A RADIO INTERFACE SET UP** TO FOLLOW OR TUNE THE RADIO. WITHOUT ONE, IT REPORTS ONLY WHAT IS TYPED INTO ITS ENTRY WINDOW.\n- N3FJP REPORTS BAND, MODE AND FREQUENCY ONLY: NO POWER, NO TRANSMIT STATE.\n\nTHIS ENTRY WAS WRITTEN FROM N3FJP\'S PUBLISHED API AND HAS NOT BEEN RUN AGAINST N3FJP. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get commanderTroubleshootingTitle => 'IF THE APP CANNOT CONNECT';
	@override String get commanderTroubleshooting => 'THIS CONNECTS TO **DXLAB COMMANDER, RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — COMMANDER TALKS TO THE RADIO.\n\n- **COMMANDER MUST ALREADY BE RUNNING** AND CONNECTED TO THE RADIO.\n- **ITS NETWORK SERVICE MUST BE ON**: THE **NET SERV** BUTTON IN THE RADIO PANEL OF COMMANDER\'S CONFIGURATION WINDOW.\n- **PORT** IS 52002, THE THIRD PORT OF THE BLOCK STARTING AT NET SERV\'S **BASE PORT** (52000 UNLESS YOU CHANGED IT).\n- **FROM ANOTHER MACHINE**, MAKE SURE YOUR FIREWALL LETS THE CONNECTION THROUGH.\n\nTHIS ENTRY WAS WRITTEN FROM COMMANDER\'S PUBLISHED TCP MESSAGES AND HAS NOT BEEN RUN AGAINST COMMANDER. IF IT HALF-WORKS, THAT IS WORTH REPORTING.';
	@override String get ic705TroubleshootingTitle => 'IF THE RADIO NEVER RESPONDS';
	@override String get ic705Troubleshooting => 'THE RADIO HAS A **SINGLE** REMOTE-CONTROL SESSION. WHEN THE LOGIN IS IGNORED, SOMETHING ELSE IS ALMOST ALWAYS USING IT.\n\n- **CLOSE ANY OTHER CLIENT.** WFVIEW OR RS-BA1 CONNECTED TO THE SAME RADIO HOLDS THAT ONE SESSION, AND THE LOGIN HERE IS SIMPLY IGNORED WHILE IT DOES.\n- **CHECK THE RADIO\'S NETWORK SETTINGS.** WLAN MUST BE ON, THE RADIO MUST BE ON THE SAME NETWORK, AND ITS REMOTE-CONTROL (NETWORK) FUNCTION MUST BE ENABLED.\n- **THE PORTS MUST MATCH** THE RADIO\'S CONTROL PORT AND SERIAL PORT (UDP), OR THE PORTS FORWARDED TO THEM. A WRONG PORT IS MET WITH SILENCE, THE SAME AS A RADIO THAT IS OFF.\n- **POWER-CYCLE THE RADIO\'S WLAN** IF IT STAYS STUCK. THAT RELIABLY CLEARS A SESSION STUCK ON THE RADIO.\n\nA **WRONG PASSWORD IS REFUSED EXPLICITLY**, NOT MET WITH SILENCE. IF YOU GOT HERE RATHER THAN A "REJECTED" MESSAGE, THE PASSWORD IS NOT THE PROBLEM.';
	@override String get icomLanTroubleshooting => 'THE RADIO HAS A **SINGLE** REMOTE-CONTROL SESSION. WHEN THE LOGIN IS IGNORED, SOMETHING ELSE IS ALMOST ALWAYS USING IT.\n\n- **CLOSE ANY OTHER CLIENT.** WFVIEW, RS-BA1 OR ICOM\'S REMOTE UTILITY CONNECTED TO THE SAME RADIO HOLDS THAT ONE SESSION, AND THE LOGIN HERE IS SIMPLY IGNORED WHILE IT DOES.\n- **CHECK THE RADIO\'S NETWORK SETTINGS.** ITS LAN PORT MUST BE CONNECTED TO THE SAME NETWORK AS THIS DEVICE, ITS **NETWORK CONTROL** MUST BE ON, AND THE USERNAME AND PASSWORD MUST BE SET UP AS A NETWORK USER ON THE RADIO.\n- **THE PORTS MUST MATCH** THE RADIO\'S CONTROL PORT AND SERIAL PORT (UDP), OR THE PORTS FORWARDED TO THEM. A WRONG PORT IS MET WITH SILENCE, THE SAME AS A RADIO THAT IS OFF.\n- **IF IT CONNECTS BUT NEVER ANSWERS**, THE CI-V ADDRESS HERE MUST MATCH THE RADIO\'S CI-V ADDRESS MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH.\n- **TURN THE RADIO OFF AND ON** IF IT STAYS STUCK.';
	@override String get statusStale => 'NOT RESPONDING';
	@override String get statusDisconnected => 'NOT CONNECTED';
	@override String get statusConnecting => 'CONNECTING…';
	@override String get statusDisconnecting => 'DISCONNECTING…';
	@override String get statusError => 'CONNECTION FAILED';
	@override String get currentRadioSettings => 'CURRENT RADIO SETTINGS';
	@override String get notSupportedByThisRadio => 'NOT SUPPORTED BY THIS RADIO';
	@override String get keyerRowLabel => 'KEYER';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'PHONE';
	@override String voiceKeyerAvailable({required Object count}) => 'VOICE KEYER: ${count} MEMORIES IN THE RADIO';
	@override String get antennaBands => 'BANDS';
	@override String get antennaType => 'ANTENNA TYPE';
	@override String get antennaTypeRequired => 'CHOOSE AN ANTENNA TYPE';
	@override late final _Translations$settings$station$antennaTypes$qro antennaTypes = _Translations$settings$station$antennaTypes$qro._(_root);
	@override String get keyType => 'KEY TYPE';
	@override String get keyTypeRequired => 'CHOOSE A KEY TYPE';
	@override late final _Translations$settings$station$keyTypes$qro keyTypes = _Translations$settings$station$keyTypes$qro._(_root);
	@override String get softwareIntermediaries => 'SOFTWARE INTERMEDIARIES';
	@override String get otherBrands => 'OTHER BRANDS';
	@override String get otherEquipment => 'OTHER EQUIPMENT (ANTENNAS, KEYS, ETC)';
	@override String get newAntenna => 'NEW ANTENNA';
	@override String get newKey => 'NEW KEY';
	@override String get newKeyer => 'WINKEYER (K1EL OR COMPATIBLE)';
	@override String keyViaRadio({required Object radio}) => 'CAT KEYER IN ${radio}';
	@override String keyOnDevice({required Object device}) => 'KEY ON ${device}';
	@override String get cwKeyerArea => 'KEYER AREA';
	@override String get trackStationInfo => 'TRACK STATION INFO FOR EACH QSO';
	@override String get includeStationInfoInAdif => 'INCLUDE IN ADIF EXPORTS';
	@override String get whatToTrack => 'WHAT TO TRACK?';
	@override String get trackFieldRig => 'TRANSCEIVER';
	@override String get trackFieldPower => 'POWER';
	@override String get watts => 'WATTS';
	@override String get trackFieldAntenna => 'ANTENNA';
	@override String get trackFieldKey => 'CW KEY';
	@override String get placeholderConnectDelay => 'CONNECT DELAY (MS)';
	@override String get placeholderConnectDelayDescription => 'HOW LONG THE SIMULATED HANDSHAKE TAKES. BLANK OR 0 CONNECTS INSTANTLY.';
	@override String get placeholderDropAfter => 'DROP AFTER (SECONDS)';
	@override String get placeholderDropAfterDescription => 'CLOSE THE CONNECTION ON ITS OWN, TO EXERCISE THE RECONNECT PATH. BLANK OR 0 NEVER DROPS.';
	@override String get placeholderFailConnect => 'ALWAYS FAIL TO CONNECT';
	@override String get placeholderConnectFailure => 'THE PLACEHOLDER RADIO WAS TOLD TO REFUSE THIS CONNECTION';
	@override String get placeholderFreq => 'FREQUENCY (KHZ)';
	@override String get placeholderFreqDescription => 'WHERE THE PLACEHOLDER RADIO STARTS. IT REPORTS BACK WHATEVER THE APP TUNES IT TO AFTERWARDS.';
	@override String get placeholderMode => 'MODE';
	@override String get placeholderModeDescription => 'THE MODE THE PLACEHOLDER RADIO STARTS ON, E.G. USB, CW, FT8.';
	@override String get placeholderPower => 'POWER (WATTS)';
	@override String get placeholderPurpose => 'USE THIS RADIO TO KEEP TRACK OF WHICH RIG YOU\'RE USING FOR LOGGING PURPOSES';
	@override String get placeholderReplyDelay => 'REPLY DELAY (MS)';
	@override String get placeholderReplyDelayDescription => 'HOW LONG THE PLACEHOLDER RADIO TAKES TO REPORT A CHANGE BACK. BLANK OR 0 REPLIES AT ONCE.';
	@override String get cwKeyerField => 'CAT CW KEYER';
	@override String get cwKeyerFieldDescription => 'WHETHER THIS RADIO KEYS CW FROM TEXT OVER CAT. OFF FOR A RIG THE APP DOES NOT KNOW.';
	@override String get voiceMemories => 'VOICE MEMORIES';
	@override String get voiceMemoriesDescription => 'HOW MANY VOICE MEMORIES THE RADIO PLAYS OVER CAT. 0 FOR NONE.';
	@override String get voiceMemoriesInvalid => 'A WHOLE NUMBER, 0 OR MORE';
	@override String get yaesuMeterCapture => 'CAPTURE METER READINGS';
	@override String get yaesuBinaryMeterCaptureDescription => 'READS THE RADIO\'S POWER-OUTPUT METER AND HIGH-SWR FLAG WHILE TRANSMITTING AND PRINTS THE RAW VALUES TO THE LOG. FOR BUILDING THE SCALE YAESU DOES NOT PUBLISH — THE VALUES ARE NOT SHOWN AS METERS.';
	@override String get yaesuMeterCaptureDescription => 'READS THE RADIO\'S PO, SWR AND ALC METERS WHILE TRANSMITTING AND PRINTS THE RAW VALUES TO THE LOG. FOR BUILDING THE SCALE YAESU DOES NOT PUBLISH — THE VALUES ARE NOT SHOWN AS METERS.';
	@override String get telemetryInterval => 'METER READING INTERVAL (MS)';
	@override String get telemetryIntervalDescription => 'HOW OFTEN TO READ THE RADIO\'S METERS WHILE IT IS TRANSMITTING. LEAVE BLANK FOR THE FASTEST THIS CONNECTION CAN HANDLE, UP TO 200 MS.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'A WHOLE NUMBER OF MILLISECONDS, ${min} TO ${max}';
	@override String get pollInterval => 'IDLE POLLING INTERVAL (MS)';
	@override String pollIntervalDescription({required Object fallback}) => 'HOW OFTEN TO ASK THE RADIO FOR ITS FREQUENCY AND MODE WHILE NEITHER IS CHANGING. LEAVE BLANK FOR ${fallback} MS.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'A WHOLE NUMBER OF MILLISECONDS, ${min} TO ${max}';
	@override String get advancedSettings => 'ADVANCED SETTINGS';
	@override String get placeholderSwr => 'SWR READING';
	@override String get placeholderSwrDescription => 'WHAT THIS RADIO REPORTS ON ITS SWR METER WHILE TRANSMITTING. ABOVE 1.8 THE PANEL WARNS.';
	@override String get placeholderSwrInvalid => 'A NUMBER, 1 OR MORE';
	@override String get keyerNone => 'NONE';
	@override String get cwDialect => 'CW KEYING DIALECT';
	@override String get cwDialectDescription => 'WHICH SHAPE OF THE KY COMMAND THIS RADIO TAKES. NONE MEANS NO CW KEYING OVER CAT.';
	@override String get cwDialectKenwood => 'KENWOOD (KY, PADDED TO 24)';
	@override String get cwDialectElecraft => 'ELECRAFT (KY TEXT)';
	@override String get voiceDialect => 'VOICE KEYER DIALECT';
	@override String get voiceDialectDescription => 'HOW THIS RADIO PLAYS ITS VOICE MEMORIES OVER CAT. NONE MEANS NO VOICE MEMORIES OVER CAT. WITH A DIALECT AND NO COUNT, THE DIALECT\'S DEFAULT COUNT APPLIES.';
	@override String get voiceDialectPb => 'KENWOOD (PB, TS-590 STYLE)';
	@override String get voiceDialectK4 => 'ELECRAFT K4 (PB AND DA)';
	@override String get voiceDialectKx => 'ELECRAFT KX2/KX3 (SWITCH TAPS)';
	@override String get placeholderDiagnostic => 'SIMULATED';
	@override String get placeholderWholeNumberInvalid => 'MUST BE A WHOLE NUMBER, 0 OR MORE';
	@override String get placeholderFreqInvalid => 'MUST BE A FREQUENCY IN KHZ, GREATER THAN ZERO';
	@override String get placeholderModeInvalid => 'MUST BE A MODE NAME, E.G. USB, CW, FT8';
	@override String get switchLayout => 'LAYOUT';
	@override String get switchLayoutDescription => 'WHICH SIDE OF THE SWITCH YOUR RADIOS ARE PLUGGED INTO.';
	@override String get switchLayoutRequired => 'CHOOSE HOW THE SWITCH IS WIRED';
	@override String switchCommandRefused({required Object command, required Object code}) => 'THE SWITCH REFUSED "${command}" (ERROR ${code})';
	@override String get switchBusyTransmitting => 'THAT PORT IS TRANSMITTING — ANTENNA NOT CHANGED';
	@override String get switchNoAntenna => 'NONE';
	@override String switchAntennaFor({required Object port}) => 'ANTENNA ON PORT ${port}';
	@override String get switchAntennaForDescription => 'WHICH OF YOUR ANTENNAS IS CONNECTED TO THIS PORT ON THE SWITCH.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} ANTENNAS, ${radios} RADIOS';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} ANTENNAS, 1 RADIO';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 ANTENNA, ${radios} RADIOS';
	@override String get switchCommonPort => 'COMMON';
	@override String get dcnAddress => 'DEVICE ADDRESS';
	@override String get dcnAddressDescription => 'THE ADDRESS SET ON THE MODULE\'S DIP SWITCHES. A COAX RELAY MODULE LEAVES THE FACTORY AT 2.';
	@override String get dcnAddressRequired => 'MUST BE A DEVICE ADDRESS FROM 1 TO 99';
	@override String switchPortLabel({required Object port}) => 'PORT ${port}';
	@override String get switchPortAutoHint => 'FOLLOWS BAND DATA';
	@override String get switchPortTransmittingHint => 'TRANSMITTING — CANNOT CHANGE NOW';
	@override String get switchCurrentStateHeader => 'CURRENT STATE';
	@override String get switchCurrentStateDescription => 'WHICH ANTENNA EACH RADIO PORT IS ON RIGHT NOW. CHANGES TAKE EFFECT IMMEDIATELY.';
	@override String get switchWiringHeader => 'WIRING';
	@override String get switchPortInhibitedHint => 'TRANSMIT INHIBITED';
	@override String get configUnreadable => 'THIS RADIO\'S SAVED SETTINGS COULD NOT BE READ. OPEN ITS SETTINGS AND ENTER THEM AGAIN, OR REMOVE IT AND ADD IT BACK.';
	@override String get autoConnectHeld => 'HALO STOPPED RESPONDING THE LAST TIME IT CONNECTED TO THIS RADIO, SO IT DID NOT CONNECT ON ITS OWN THIS TIME. PRESS CONNECT TO TRY AGAIN.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$qro extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'OFFLINE DATA';
	@override String get noFiles => 'NO DATA FILES';
	@override String get noFilesDescription => 'ENABLE ACTIVITY OR LOOKUP EXTENSIONS TO DOWNLOAD THEIR OFFLINE DATA HERE.';
	@override String get refresh => 'REFRESH';
	@override String get refreshing => 'REFRESHING…';
	@override String get updateAll => 'UPDATE ALL';
	@override String get updatingAll => 'UPDATING ALL DATA FILES…';
	@override String get neverDownloaded => 'NEVER DOWNLOADED';
	@override String get updatedJustNow => 'UPDATED JUST NOW';
	@override String updatedDaysAgo({required Object days}) => 'UPDATED ${days}D AGO';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'UPDATED ${days}D ${hours}H AGO';
	@override String updatedHoursAgo({required Object hours}) => 'UPDATED ${hours}H AGO';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'UPDATED ${hours}H ${minutes}M AGO';
	@override String updatedMinutesAgo({required Object minutes}) => 'UPDATED ${minutes}M AGO';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'THE LAST DOWNLOAD HAD ONLY ${imported} OF ${existing} RECORDS AND WAS NOT USED. REFRESH TO ACCEPT IT.';
	@override String get extensionsSection => 'EXTENSIONS';
}

// Path: settings.profiles
class _Translations$settings$profiles$qro extends Translations$settings$profiles$en {
	_Translations$settings$profiles$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'NOT SET';
	@override String get personalInfo => 'PERSONAL INFO';
	@override String get personalInfoNote => 'THIS MIGHT BE INCLUDED IN GENERATED LOGS WHEN RELEVANT FOR SUBMISSIONS';
	@override String get name => 'NAME';
	@override String get email => 'EMAIL';
	@override String get club => 'CLUB';
	@override String get arrlSection => 'ARRL SECTION';
	@override String get racSection => 'RAC SECTION';
	@override String get section => 'SECTION';
}

// Path: settings.search
class _Translations$settings$search$qro extends Translations$settings$search$en {
	_Translations$settings$search$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get clear => 'CLEAR';
	@override String get hint => 'SEARCH PREFERENCES';
}

// Path: settings.developer
class _Translations$settings$developer$qro extends Translations$settings$developer$en {
	_Translations$settings$developer$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'ENABLE DEVELOPER WARNINGS, DEBUG LOGS, AND TOOLS.';
	@override String get experiments => 'EXPERIMENTS';
	@override String get showIdleMetrics => 'SHOW IDLE METRICS';
	@override String get showIdleMetricsDescription => 'SHOW IN THE STATUS BAR HOW IDLE THE EXTENSION ENGINE HAS BEEN OVER THE LAST SECOND. TAP IT FOR THE 10- AND 60-SECOND AVERAGES.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% IDLE';
	@override String get idleMetricsAverages => 'IDLE AVG:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}S ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} ENABLED',
		other: '${count} ENABLED',
	);
	@override String get patchTrack => 'CODE PUSH TRACK';
	@override String get patchTrackDescription => 'WHICH OVER-THE-AIR CODE PUSH RING THIS DEVICE FOLLOWS. MORE ADVENTUROUS RINGS GET FIXES EARLIER, LESS TESTED. CODE PUSHES APPLY ON THE NEXT RESTART.';
	@override String get trackStable => 'STABLE';
	@override String get trackUnstable => 'UNSTABLE';
	@override String get trackBleeding => 'BLEEDING';
	@override String checkingTrack({required Object track}) => 'CHECKING "${track}" FOR A CODE PUSH…';
	@override String get patchDownloaded => 'CODE PUSH DOWNLOADED — RESTART THE APP TO APPLY IT.';
	@override String noNewPatch({required Object track}) => 'NO NEW CODE PUSH ON "${track}".';
	@override String get noPatchInstalled => 'NO CODE PUSH INSTALLED — RUNNING THE RELEASE BINARY.';
	@override String runningPatch({required Object patch}) => 'RUNNING CODE PUSH #${patch}.';
	@override String get deepLinks => 'DEEP LINKS';
	@override String get registerUrlSchemes => 'REGISTER URL SCHEMES';
	@override String get registerUrlSchemesDescription => 'LET COM.HAM2K:// LINKS OPEN THIS COPY OF THE APP';
	@override String get registerUrlSchemesDone => 'THIS COPY NOW OPENS COM.HAM2K:// LINKS';
	@override String registerUrlSchemesFailed({required Object error}) => 'COULD NOT REGISTER: ${error}';
	@override String get systemInformation => 'SYSTEM INFORMATION';
	@override String get appVersion => 'APP VERSION';
	@override String get dataFolder => 'DATA FOLDER';
	@override String get loading => '(LOADING…)';
	@override String get panelLoadFailed => 'COULD NOT LOAD THIS SETTINGS PANEL.';
	@override String get extDevServer => 'EXTENSION DEV SERVER';
	@override String get extensionSettings => 'EXTENSION SETTINGS';
	@override String get extDevServerDescription => 'LOAD EXTENSIONS FROM A DEV SERVER ON YOUR NETWORK INSTEAD OF THE ONES BUILT INTO THE APP, AND RELOAD THEM AS YOU SAVE.';
	@override String get extDevServerAddress => 'SERVER ADDRESS';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'CONNECT';
	@override String get extDevServerDisconnect => 'DISCONNECT';
	@override String get extDevServerConnecting => 'CONNECTING…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SERVING ${count} EXTENSION: ${keys}',
		other: 'SERVING ${count} EXTENSIONS: ${keys}',
	);
	@override String get extDevServerDisconnected => 'NOT CONNECTED';
	@override String get extDevServerReconnect => 'RECONNECT AT LAUNCH';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'LAST RELOAD: ${key} AT ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} EXTENSION FAILING TO BUILD',
		other: '${count} EXTENSIONS FAILING TO BUILD',
	);
	@override String get catalog => 'EXTENSION CATALOG';
	@override String get catalogDescription => 'READ THE CATALOG FROM ANOTHER SERVER — A LOCAL ONE WHILE WORKING ON THE CATALOG ITSELF. EMPTY MEANS CATALOG.HAM2K.NET.';
	@override String get catalogAddress => 'CATALOG ADDRESS';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'CATALOG SEARCH TRACKS';
	@override String get catalogSearchStable => 'ONLY STABLE';
	@override String get catalogSearchUnstable => 'UNSTABLE OR BETTER';
	@override String get catalogSearchBleeding => 'BLEEDING OR BETTER';
}

// Path: settings.about
class _Translations$settings$about$qro extends Translations$settings$about$en {
	_Translations$settings$about$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get notices => 'NOTICES & MESSAGES';
	@override String get noticesDescription => 'ANNOUNCEMENTS AND STATUS MESSAGES';
	@override String get releaseNotes => 'RELEASE NOTES';
	@override String get copiedVersion => 'COPIED VERSION DETAILS TO CLIPBOARD';
}

// Path: settings.panels
class _Translations$settings$panels$qro extends Translations$settings$panels$en {
	_Translations$settings$panels$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get settings => 'APPLICATION PREFERENCES';
	@override String get settingsDescription => 'MAKE THE APP WORK HOW YOU WANT IT';
	@override String get commonSettings => 'COMMON PREFERENCES';
	@override String get syncDescription => 'BACK UP AND SYNC YOUR LOGS ACROSS DEVICES';
	@override String get accountsDescription => 'SERVICE CREDENTIALS, OFFLINE DATA, AND MORE';
	@override String get extensions => 'EXTENSIONS & FEATURES';
	@override String get extensionsDescription => 'ACTIVITIES, CONTESTS, DASHBOARD PANELS AND MORE FEATURES';
	@override String get profilesDescription => 'OPERATOR CALLSIGN AND STATION PROFILE';
	@override String get stationProfiles => 'STATION PROFILES';
	@override String get developerSettings => 'DEVELOPER SETTINGS';
	@override String get developerSettingsDescription => 'DEBUGGING AND DEVELOPMENT TOOLS';
	@override String get about => 'ABOUT';
	@override String get aboutDescription => 'VERSION, CREDITS, AND LEGAL INFORMATION';
	@override String get unavailableTitle => 'SOME SETTINGS ARE UNAVAILABLE';
	@override String get unavailableText => 'THE EXTENSION RUNTIME FAILED TO START, SO EXTENSION-CONTRIBUTED SETTINGS ARE MISSING.';
	@override String get station => 'STATION CONFIGURATION';
	@override String get stationDescription => 'CAT CONTROL AND MORE OPTIONS';
	@override String get peers => 'PEER DEVICES';
	@override String get peersDescription => 'CONNECT TO OTHER DEVICES NEARBY';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$qro extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get locale => 'FOLLOW SYSTEM SETTINGS';
	@override String get period => 'ALWAYS USE PERIOD FOR DECIMALS';
	@override String get comma => 'ALWAYS USE COMMA FOR DECIMALS';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$qro extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => 'SYSTEM SETTINGS (USING ${separator} FOR DECIMALS)';
	@override String get period => 'ALWAYS USING PERIOD FOR DECIMALS';
	@override String get comma => 'ALWAYS USING COMMA FOR DECIMALS';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$qro extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get comma => 'COMMA';
	@override String get period => 'PERIOD';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$qro extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get six => '6 DIGITS (FN31PR)';
	@override String get eight => '8 DIGITS (FN31PR55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$qro extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get six => '6 DIGITS';
	@override String get eight => '8 DIGITS';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$qro extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'OPEN THE COMMAND DIALOG';
	@override String get toggleTheme => 'SWITCH BETWEEN LIGHT AND DARK';
	@override String get toggleLanguage => 'SWITCH BETWEEN ENGLISH AND SPANISH';
	@override String get fontScaleUp => 'LARGER TEXT';
	@override String get fontScaleDown => 'SMALLER TEXT';
	@override String get fontScaleReset => 'NORMAL TEXT SIZE';
	@override String get densityLooser => 'ROOMIER LAYOUT';
	@override String get densityDenser => 'DENSER LAYOUT';
	@override String get densityAuto => 'AUTOMATIC LAYOUT DENSITY';
	@override String get find => 'FIND IN THE LOG';
	@override String keyerMessage({required Object n}) => 'SEND MESSAGE ${n}';
	@override String get keyboardMode => 'KEYBOARD MODE ON OR OFF';
	@override String get ptt => 'PUSH TO TALK';
	@override String get wipe => 'CLEAR THE CONTACT BEING LOGGED';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$qro extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'TYPING CALLSIGNS';
	@override String get escape => 'STOP SENDING, BACK OUT ONE STEP, OR CLOSE';
	@override String get enter => 'LOG THE CONTACT';
	@override String get space => 'NEXT FIELD';
	@override String get tab => 'NEXT OR PREVIOUS FIELD';
	@override String get arrows => 'MOVE BETWEEN FIELDS, CONTROLS AND THE LOG';
	@override String get walk => 'PAGE THROUGH THE LOG, OR GO TO ITS ENDS';
	@override String get undo => 'TAKE BACK A WIPE OR A DELETE';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$qro extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'ADD SHORTCUT';
	@override String get listening => 'PRESS THE KEYS FOR THE SHORTCUT…';
	@override String get listeningHint => 'ESC STOPS LISTENING';
	@override String get add => 'ADD';
	@override String refusedFixed({required Object keys}) => '${keys} BELONGS TO THE LOGGING FIELDS OR A DIALOG, AND CAN’T BE CHANGED.';
	@override String refusedCallsign({required Object keys}) => '${keys} IS HOW CALLSIGNS ARE TYPED. HOLD CMD, CTRL OR ALT WITH IT.';
	@override String reserved({required Object keys}) => 'THE SYSTEM MAY TAKE ${keys} BEFORE THE APP SEES IT.';
	@override String already({required Object keys}) => '${keys} IS ALREADY ONE OF THIS COMMAND’S KEYS.';
	@override String takeIt({required Object keys, required Object command}) => 'TAKE ${keys} FROM “${command}”';
	@override String get resetDefault => 'RESET TO DEFAULT';
	@override String get remove => 'REMOVE';
	@override String get commandLabel => 'COMMAND';
	@override String get commandHint => 'ENTER ANY VALID COMMAND, OR MULTIPLE COMMANDS SEPARATED BY ";"';
	@override String get removeCommand => 'REMOVE COMMAND';
	@override String commandUnknown({required Object text}) => 'NO COMMAND READS “${text}”';
	@override String get noShortcuts => 'NO KEY YET';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$qro extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'SHORTCUTS SAVED TO ${location}';
	@override String exportFailed({required Object error}) => 'COULDN’T EXPORT THE SHORTCUTS: ${error}';
	@override String importPickerFailed({required Object error}) => 'COULDN’T OPEN THE FILE: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} ISN’T A SHORTCUTS FILE THIS APP CAN READ: ${problem}';
	@override String problemNotYaml({required Object line}) => 'THE TEXT ISN’T VALID YAML (LINE ${line})';
	@override String get problemNotKeysFile => 'IT ISN’T A HAM2K KEYBOARD SHORTCUTS FILE';
	@override String get problemNewerVersion => 'IT WAS WRITTEN BY A NEWER VERSION OF THE APP';
	@override String get problemMalformed => 'PART OF IT DOESN’T FOLLOW THE SHORTCUTS FORMAT';
	@override String get problemTooLarge => 'IT IS TOO LARGE';
	@override String get importTitle => 'IMPORT SHORTCUTS';
	@override String writtenOn({required Object platform}) => 'WRITTEN ON ${platform}.';
	@override String get writtenOnUnknown => 'THE FILE DOESN’T SAY WHICH KEYBOARD IT WAS WRITTEN ON.';
	@override String get translate => 'WHAT SHOULD EACH OF THESE KEYS BE ON THIS KEYBOARD?';
	@override String get leaveOut => 'LEAVE THOSE SHORTCUTS OUT';
	@override String get replace => 'REPLACE THIS DEVICE’S CONFIG';
	@override String get replaceHint => 'EVERY SHORTCUT NOT IN THE FILE GOES BACK TO ITS DEFAULT.';
	@override String get merge => 'ADD TO THIS DEVICE’S CONFIG';
	@override String get mergeHint => 'THE FILE’S SHORTCUTS REPLACE THIS DEVICE’S FOR THE SAME COMMANDS, AND THE REST STAY.';
	@override String unknown({required Object commands}) => 'NOT KNOWN IN THIS VERSION, SO LEFT OUT: ${commands}';
	@override String unreadableChords({required Object chords}) => 'NOT SHORTCUTS, SO LEFT OUT: ${chords}';
	@override String refusedChords({required Object chords}) => 'KEYS THE APP KEEPS FOR ITSELF, SO LEFT OUT: ${chords}';
	@override String conflicts({required Object keys}) => 'BOUND TO MORE THAN ONE COMMAND AFTER THE IMPORT: ${keys}';
	@override String get importAction => 'IMPORT';
	@override String get imported => 'SHORTCUTS IMPORTED';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$qro extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ COMMAND';
	@override String get ctrl => 'CTRL';
	@override String get meta => 'WINDOWS / SUPER';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$qro extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get macos => 'MACOS';
	@override String get ios => 'IPADOS';
	@override String get windows => 'WINDOWS';
	@override String get linux => 'LINUX';
	@override String get android => 'ANDROID';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$qro extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'STATION CALLSIGNS';
	@override String get groupBy => 'GROUP BY';
	@override String get period => 'TIME PERIOD';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$qro extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get none => 'NOT GROUPED';
	@override String get date => 'DATE';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'UNKNOWN CONTINENT';
	@override String get unknownEntity => 'UNKNOWN ENTITY';
	@override String get unknownDate => 'NO DATE';
}

// Path: home.logs.period
class _Translations$home$logs$period$qro extends Translations$home$logs$period$en {
	_Translations$home$logs$period$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'THIS MONTH';
	@override String get last3Months => 'LAST 3 MONTHS';
	@override String get thisYear => 'THIS YEAR';
	@override String get lastYear => 'LAST YEAR';
	@override String get allTime => 'ALL TIME';
	@override String get custom => 'CUSTOM RANGE';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$qro extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => 'IN ${span}';
	@override String get custom => 'CUSTOM RANGE';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$qro extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get date => 'DATE';
	@override String get time => 'TIME';
	@override String get freq => 'FREQUENCY';
	@override String get mode => 'MODE';
	@override String get call => 'CALL';
	@override String get name => 'NAME';
	@override String get station => 'STATION';
	@override String get band => 'BAND';
	@override String get sent => 'SENT';
	@override String get rcvd => 'RCVD';
	@override String get grid => 'GRID';
	@override String get state => 'STATE';
	@override String get country => 'COUNTRY';
	@override String get refs => 'REFS';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$qro extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO LOG';
	@override String get qsosDescription => 'THE SELECTED CALLSIGN\'S QSOS, ACROSS EVERY OPERATION.';
	@override String get info => 'INFO';
	@override String get infoDescription => 'TOTAL QSO COUNT, OR THE SELECTED QSO\'S CALLSIGN LOOKUP.';
	@override String get map => 'MAP';
	@override String get mapDescription => 'THE SELECTED QSO\'S LOCATION.';
}

// Path: home.logs.import
class _Translations$home$logs$import$qro extends Translations$home$logs$import$en {
	_Translations$home$logs$import$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'CALLSIGNS: ${calls}';
	@override String get skippedOne => '1 RECORD COULD NOT BE READ';
	@override String skippedOther({required Object count}) => '${count} RECORDS COULD NOT BE READ';
	@override String get readingTitle => 'READING ADIF FILE…';
	@override String get checkingTitle => 'CHECKING FOR DUPLICATES…';
	@override String get importingTitle => 'IMPORTING QSOS…';
	@override String readingDetail({required Object kb}) => '${kb} KB';
	@override String checkingDetail({required Object done, required Object total}) => '${done} OF ${total} CHECKED';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} IMPORTED, OUT OF ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$qro extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'DEFAULT';
	@override String untitledName({required Object number}) => 'LAYOUT ${number}';
	@override String switcherLabel({required Object name}) => 'LAYOUT: ${name}';
	@override String get menuNew => 'NEW…';
	@override String get menuExport => 'EXPORT…';
	@override String get menuImport => 'IMPORT…';
	@override String get menuTitle => 'LAYOUTS';
	@override String get newTitle => 'NEW LAYOUT';
	@override String get editTitle => 'EDIT LAYOUT';
	@override String get edit => 'EDIT';
	@override String get duplicateCurrent => 'DUPLICATE CURRENT LAYOUT';
	@override String get startFromDefault => 'START FROM THE DEFAULT LAYOUT';
	@override String get nameLabel => 'NAME';
	@override String get descriptionLabel => 'DESCRIPTION';
	@override String get create => 'CREATE';
	@override String leaveEditTitle({required Object name}) => 'SAVE CHANGES TO "${name}"?';
	@override String get leaveEditBody => 'THIS LAYOUT HAS CHANGES YOU HAVEN’T SAVED.';
	@override String get discard => 'DISCARD';
	@override String get deleteTitle => 'DELETE THIS LAYOUT?';
	@override String deleteBody({required Object name}) => 'ARE YOU SURE YOU WANT TO DELETE THIS "${name}" LAYOUT?';
	@override String get exportTitle => 'EXPORT LAYOUT';
	@override String get exportPick => 'PANELS TO EXPORT';
	@override String get tabSet => 'TAB SET';
	@override String get exportAction => 'EXPORT';
	@override String exported({required Object location}) => 'LAYOUT SAVED TO ${location}';
	@override String exportFailed({required Object error}) => 'COULDN\'T EXPORT THE LAYOUT: ${error}';
	@override String get importTitle => 'IMPORT LAYOUT';
	@override String importFromOtherView({required Object view}) => 'MADE FOR THE ${view} VIEW: PANELS ONLY THAT VIEW HAS ARE LEFT OUT.';
	@override String get viewHome => 'HOME';
	@override String get viewOperation => 'OPERATION';
	@override String get viewLogs => 'LOGS';
	@override String get viewChase => 'CHASING';
	@override String get importAsNew => 'AS A NEW LAYOUT';
	@override String get importReplace => 'IN PLACE OF THIS LAYOUT';
	@override String get importAdd => 'ADDED TO THIS LAYOUT';
	@override String get importAddHint => 'THE PANELS ARRIVE IN A NEW COLUMN ON THE RIGHT.';
	@override String get importPick => 'PANELS TO IMPORT';
	@override String get importReplaceSettings => 'REPLACE THE SETTINGS OF PANELS ALREADY SET UP HERE';
	@override String get importAction => 'IMPORT';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} ISN\'T A LAYOUT THIS APP CAN READ: ${problem}';
	@override String problemNotYaml({required Object line}) => 'THE TEXT ISN’T VALID YAML (LINE ${line})';
	@override String get problemNotLayoutFile => 'IT ISN’T A HAM2K LAYOUT FILE';
	@override String get problemNewerVersion => 'IT WAS WRITTEN BY A NEWER VERSION OF THE APP';
	@override String get problemNoArrangement => 'IT HOLDS NO ARRANGEMENT';
	@override String get problemMalformed => 'PART OF IT DOESN’T FOLLOW THE LAYOUT FORMAT';
	@override String get problemTooLarge => 'IT IS TOO LARGE';
	@override String importPickerFailed({required Object error}) => 'COULDN\'T OPEN THE FILE: ${error}';
	@override String importFailed({required Object error}) => 'COULDN\'T IMPORT THE LAYOUT: ${error}';
	@override String duplicateFailed({required Object error}) => 'COULDN\'T COPY THE LAYOUT: ${error}';
	@override String get importNothing => 'NO PANEL PICKED, SO NOTHING WAS IMPORTED.';
	@override String importSkipped({required Object panels}) => 'LEFT OUT: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'KEPT ${panels}: THE SMALL-SCREEN ARRANGEMENT CAN’T DO WITHOUT IT.';
	@override String get notOffered => 'NOT AVAILABLE IN THIS VIEW';
	@override String get alreadyPlaced => 'ALREADY IN THIS LAYOUT';
	@override String needsExtension({required Object name}) => 'NEEDS ${name}';
	@override String get listRecoveredTitle => 'LAYOUT NAMES COULDN’T BE READ';
	@override String get listRecoveredBody => 'THIS VIEW’S LIST OF LAYOUTS COULD NOT BE READ. EVERY LAYOUT IS STILL HERE, NUMBERED IN PLACE OF ITS NAME.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$qro extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'THE LOG AND THE ENTRY FIELDS';
	@override String get infoDescription => 'WHAT WE KNOW ABOUT THE STATION BEING WORKED';
	@override String get spotsDescription => 'SPOTS FROM THE CLUSTERS AND ACTIVITY PROGRAMS';
	@override String get mapDescription => 'WHERE THE CONTACTS ARE';
	@override String get summariesDescription => 'THE OPERATION\'S STATS AND SCORES, IN THE SECTIONS AND ORDER YOU PICK';
	@override String get summariesSections => 'SECTIONS AND ORDER';
	@override String get summariesDays => 'EACH DAY';
	@override String get summariesReset => 'SHOW ALL';
	@override String get summariesAllHidden => 'EVERY SECTION IS HIDDEN. PICK THE ONES TO SHOW IN THIS PANEL\'S SETTINGS.';
	@override String get clockDescription => 'A CLOCK FACE, IN ANY TIME ZONE';
	@override String get clockFace => 'FACE';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'ANALOG';
	@override String get clockZone => 'TIME ZONE';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'THIS DEVICE';
	@override String get clockShowSeconds => 'SHOW SECONDS';
	@override String get weatherDescription => 'CONDITIONS NOW AND FOR THE NEXT EIGHT HOURS, WHERE YOU\'RE OPERATING';
	@override String get weatherUseOperationLocation => 'USE THE OPERATION\'S LOCATION';
	@override String get weatherLocation => 'LOCATION';
	@override String get weatherLocationDescription => 'A GRID SQUARE (FN31PR) OR LAT,LON. IGNORED WHILE \'USE THE OPERATION\'S LOCATION\' IS CHECKED.';
	@override String get weatherNoLocation => 'NO LOCATION SET. GIVE THIS PANEL A LOCATION IN ITS SETTINGS, OR PLACE IT INSIDE AN OPERATION THAT HAS ONE.';
	@override String weatherBadLocation({required Object location}) => 'COULDN\'T READ THE LOCATION ${location}. USE A GRID SQUARE LIKE FN31PR, OR 42.36,-71.06.';
	@override String get weatherUnreachable => 'COULDN\'T REACH OPEN-METEO — NO NETWORK? WILL TRY AGAIN SHORTLY.';
	@override String get weatherUnreadable => 'OPEN-METEO RESPONDED, BUT NOT WITH ANYTHING READABLE. WILL TRY AGAIN SHORTLY.';
	@override String weatherGusts({required Object speed}) => 'GUSTS ${speed}';
	@override String get panelAgeNow => 'JUST NOW';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} MIN AGO',
		other: '${count} MIN AGO',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: '${count} HR AGO',
		other: '${count} HRS AGO',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$qro weatherConditions = _Translations$operation$layout$panels$weatherConditions$qro._(_root);
	@override String get websiteDescription => 'A WEB PAGE OF YOUR CHOOSING, IN A PANE';
	@override String get websiteUrl => 'ADDRESS';
	@override String get websiteRefresh => 'REFRESH';
	@override String get websiteRefreshNever => 'NEVER';
	@override String get websiteRefresh1 => 'EVERY MINUTE';
	@override String get websiteRefresh5 => 'EVERY 5 MINUTES';
	@override String get websiteRefresh15 => 'EVERY 15 MINUTES';
	@override String get websiteTitle => 'PANEL NAME';
	@override String get websiteRefreshNow => 'REFRESH NOW';
	@override String get websiteNoUrl => 'NO ADDRESS YET. OPEN THIS PANEL’S SETTINGS TO CHOOSE A PAGE.';
	@override String get websiteBadUrl => 'THAT DOESN’T LOOK LIKE A WEB ADDRESS. IT NEEDS TO START WITH HTTPS://';
	@override String get websiteNotHttps => 'ONLY HTTPS:// ADDRESSES CAN BE SHOWN HERE.';
	@override String get websiteUnsupported => 'WEB PAGES CAN’T BE SHOWN IN A PANEL ON THIS SYSTEM.';
	@override String get websiteOpenExternally => 'OPEN IN BROWSER';
	@override String websiteLoadFailed({required Object reason}) => 'COULDN’T LOAD THE PAGE: ${reason}';
	@override String get remoteScreenDescription => 'A SCREEN, APP OR WINDOW SHARED BY ANOTHER OF YOUR DEVICES.';
	@override String get remoteScreenTarget => 'SCREEN';
	@override String get remoteScreenChoose => 'CHOOSE A SCREEN…';
	@override String get remoteScreenPickerTitle => 'SHARED SCREENS';
	@override String get remoteScreenPickerEmpty => 'NONE OF YOUR DEVICES IS SHARING A SCREEN. TURN SHARE SCREENS AND WINDOWS ON UNDER SETTINGS → PEER DEVICES, ON THE DEVICE YOU WANT TO SEE.';
	@override String get remoteScreenUnset => 'NO SCREEN CHOSEN. OPEN THIS PANEL\'S SETTINGS TO PICK ONE YOUR OTHER DEVICES ARE SHARING.';
	@override String get remoteScreenConnecting => 'CONNECTING…';
	@override String get remoteScreenPeerAway => 'THAT DEVICE ISN\'T CONNECTED RIGHT NOW.';
	@override String get remoteScreenNotOffered => 'THAT DEVICE STOPPED SHARING THIS SCREEN.';
	@override String get remoteScreenNoListener => 'THAT DEVICE CAN\'T ACCEPT CONNECTIONS — CHECK ITS FIREWALL.';
	@override String get remoteScreenNoLan => 'SCREENS ARE ONLY SHARED OVER THE LOCAL NETWORK, NOT BLUETOOTH.';
	@override String get remoteScreenRefused => 'THAT DEVICE WOULDN\'T SHARE THIS SCREEN.';
	@override String get remoteScreenSettings => 'PANEL SETTINGS';
	@override String get remoteScreenAdjust => 'ADJUST VIEW';
	@override String get remoteScreenDetail => 'DETAIL';
	@override String get remoteScreenDetailStandard => 'STANDARD';
	@override String get remoteScreenDetailHigh => 'HIGH';
	@override String get remoteScreenDetailMaximum => 'MAXIMUM';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'ZOOM IN';
	@override String get remoteScreenZoomOut => 'ZOOM OUT';
	@override String get remoteScreenStopped => 'THAT SCREEN OR WINDOW IS NO LONGER BEING SHOWN.';
	@override String get remoteScreenCaptureFailed => 'THAT DEVICE COULDN\'T CAPTURE THAT SCREEN — IT MAY NEED SCREEN RECORDING PERMISSION.';
	@override String get remoteScreenNoAnswer => 'THAT DEVICE DIDN\'T RESPOND. IT MAY NOT HAVE SCREEN SHARING TURNED ON.';
	@override String get remoteScreenNoMedia => 'COULDN\'T OPEN A CONNECTION FOR THE PICTURE. CHECK THE FIREWALL ON THIS DEVICE.';
	@override String get solarDescription => 'SOLAR AND GEOMAGNETIC CONDITIONS, WITH BAND-BY-BAND PROPAGATION';
	@override String get solarUnreachable => 'COULDN\'T REACH HAMQSL.COM — NO NETWORK? WILL TRY AGAIN SHORTLY.';
	@override String get solarUnreadable => 'HAMQSL.COM RESPONDED, BUT NOT WITH A READING WE COULD USE. WILL TRY AGAIN SHORTLY.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'KP';
	@override String get solarBandDay => 'DAY';
	@override String get solarBandNight => 'NIGHT';
	@override String get solarBandGood => 'GOOD';
	@override String get solarBandFair => 'FAIR';
	@override String get solarBandPoor => 'POOR';
	@override String solarSources({required Object primary, required Object secondary}) => 'SOURCES: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'THE CONNECTION IS STRUGGLING — SKIPPING FRAMES.';
	@override String get remoteScreenStalled => 'FRAMES STOPPED GETTING THROUGH — THIS CONNECTION MAY BE TOO SLOW.';
	@override String get radioDescription => 'A RADIO\'S FRONT PANEL — FREQUENCY, MODE AND POWER, UNDER CAT CONTROL';
	@override String get radioStyle => 'STYLE';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'MODERN';
	@override String get radioRadio => 'RADIO';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — NO RADIO DESIGNATED';
	@override String get radioNoRadio => 'NO RADIO TO SHOW. PICK ONE IN THIS PANEL\'S SETTINGS, OR ADD ONE UNDER STATION CONFIGURATION.';
	@override String get radioNotConfigured => 'THIS RADIO IS NOT CONFIGURED YET. CHOOSE ITS PORT OR ADDRESS UNDER STATION CONFIGURATION.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'RADIO NOT CONNECTED';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'CONNECT THIS RADIO';
	@override String get radioDisconnect => 'DISCONNECT THIS RADIO';
	@override String get radioStale => 'NO DATA';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'HIGH SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$qro extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'USE COMPACT FILE NAMES';
	@override String get descriptionOn => 'SHORT NAMES BUILT FOR UPLOADERS, LIKE N0CALL@US-1234-20260727.ADI';
	@override String get descriptionOff => 'READABLE NAMES, LIKE 2026-07-27 N0CALL AT US-1234.ADI';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$qro extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'INCLUDE PRIVATE INFO';
	@override String get descriptionOn => 'NAMES, ADDRESSES, EMAILS, GRIDSQUARES AND NOTES ARE INCLUDED';
	@override String get descriptionOff => 'NAMES, ADDRESSES, EMAILS, GRIDSQUARES AND NOTES ARE LEFT OUT';
	@override String get note => 'THE FULL ADIF EXPORT ALWAYS INCLUDES EVERYTHING';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$qro extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'ADD AN EMAIL ADDRESS FIRST';
	@override String get needsEmailBody => 'HAM2K’S FILE STASH SENDS YOUR FILES TO THE EMAIL ADDRESS ON YOUR LOFI ACCOUNT, AND YOU SIGN IN WITH IT AT STASH.HAM2K.NET. YOUR ACCOUNT DOESN’T HAVE A CONFIRMED ONE YET — ADD IT IN SETTINGS › CLOUD SYNC.';
	@override String get openSyncSettings => 'OPEN CLOUD SYNC';
	@override String get replaceTitle => 'RECENT STASH WILL BE REPLACED';
	@override String replaceBody({required Object name}) => 'YOU SENT “${name}” LESS THAN 6 HOURS AGO AND IT HASN’T BEEN DOWNLOADED YET. FREE ACCOUNTS KEEP ONE STASH AT A TIME, SO SENDING NOW REPLACES IT.';
	@override String get replaceConfirm => 'SEND ANYWAY';
	@override String get failedTitle => 'COULDN’T SEND TO HAM2K’S FILE STASH';
	@override String get sentTitle => 'SENT TO HAM2K’S FILE STASH';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'YOU CAN RETRIEVE THIS FILE BY VISITING **[STASH.HAM2K.NET](https://stash.ham2k.net)** ON ANY BROWSER.',
		other: 'YOU CAN RETRIEVE THESE FILES BY VISITING **[STASH.HAM2K.NET](https://stash.ham2k.net)** ON ANY BROWSER.',
	);
	@override String get mayHaveArrived => 'NO ANSWER FROM THE STASH — THE FILE MAY HAVE ARRIVED ANYWAY. CHECK STASH.HAM2K.NET BEFORE SENDING AGAIN';
	@override String get notSent => 'NOT SENT';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'THIS FILE DIDN’T ARRIVE:',
		other: 'THESE ${count} FILES DIDN’T ARRIVE:',
	);
	@override String get emailOffer => 'OR FOR YOUR CONVENIENCE, WE CAN SEND YOU AN EMAIL WITH A DIRECT LINK.';
	@override String get emailMe => 'EMAIL ME A LINK';
	@override String get emailSent => 'WE’VE EMAILED YOU A DOWNLOAD LINK.';
	@override String emailFailed({required Object error}) => 'COULDN’T SEND THE EMAIL: ${error}';
	@override String get freeTier => 'FREE ACCOUNTS CAN ONLY KEEP ONE STASH AT A TIME. SUBSCRIBERS CAN KEEP AS MANY AS THEY WANT.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count,
		one: 'SENT ${count} FILE TO HAM2K’S FILE STASH (STASH.HAM2K.NET)',
		other: 'SENT ${count} FILES TO HAM2K’S FILE STASH (STASH.HAM2K.NET)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$qro extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get af => 'AFRICA';
	@override String get as => 'ASIA';
	@override String get eu => 'EUROPE';
	@override String get na => 'NORTH AMERICA';
	@override String get oc => 'OCEANIA';
	@override String get sa => 'SOUTH AMERICA';
	@override String get an => 'ANTARCTICA';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$qro extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'FILTER SPOTS';
	@override String get band => 'BAND';
	@override String get mode => 'MODE';
	@override String get age => 'AGE';
	@override String get sources => 'SOURCES';
	@override String get continent => 'CONTINENT';
	@override String get sorting => 'SORTING';
	@override String get sortByTime => 'BY SPOT TIME';
	@override String get sortByFrequency => 'BY FREQUENCY';
	@override String get sortByWanted => 'MOST WANTED';
	@override String get groupByBand => 'GROUP BY BAND';
	@override String get groupCallsWithNotes => 'GROUP CALLS WITH NOTES';
	@override String get alertingOnly => 'ONLY SPOTS WITH ALERTS';
	@override String get sourceNoReply => 'NO REPLY';
	@override String get sourceError => 'ERROR';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$qro extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'LOGGING PANEL IS BUSY';
	@override String get editingBody => 'YOU\'RE EDITING A LOGGED CONTACT. LOG THIS SPOT INSTEAD, OR GO BACK AND FINISH THE EDIT?';
	@override String get composingBody => 'YOU\'VE STARTED ENTERING A CONTACT. LOG THIS SPOT INSTEAD, OR GO BACK AND FINISH WHAT YOU WERE TYPING?';
	@override String get goBack => 'GO BACK';
	@override String get clearAndLog => 'CLEAR AND LOG SPOT';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$qro extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'LEFTIE MODE';
	@override String get descriptionOn => 'USING LAYOUT FOR LEFT-HANDED USERS';
	@override String get descriptionOff => 'USING LAYOUT FOR RIGHT-HANDED USERS';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$qro extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'COUNTRY FLAGS';
	@override String get dx => 'SHOW ONLY FOR DX CONTACTS';
	@override String get all => 'SHOW FLAGS FOR ALL CONTACTS';
	@override String get none => 'DON\'T SHOW ANY FLAGS';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$qro extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get dx => 'SHOWING FLAGS ONLY FOR DX CONTACTS';
	@override String get all => 'SHOWING FLAGS FOR ALL CONTACTS';
	@override String get none => 'NOT SHOWING ANY FLAGS';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$qro extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SUGGEST OPERATOR';
	@override String get descriptionOn => 'OFFERING YOUR CALLSIGN AS THE OPERATOR WHEN AN OPERATION RUNS UNDER A DIFFERENT STATION CALLSIGN';
	@override String get descriptionOff => 'LEAVING THE OPERATOR BLANK UNLESS YOU FILL IT IN';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$qro extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SHOW BEARING';
	@override String get descriptionOn => 'SHOWING ESTIMATED BEARING TO STATION';
	@override String get descriptionOff => 'NOT SHOWING BEARING INFORMATION';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$qro extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ALSO SHOW REVERSE BEARING';
	@override String get descriptionOn => 'SHOWING THE BEARING FROM THE STATION TOO, AS "45° / 225°"';
	@override String get descriptionOff => 'ONLY SHOWING THE BEARING TO THE STATION';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$qro extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SWITCH SIGNAL REPORT ORDER';
	@override String get sentFirst => 'SENT FIRST, RCVD SECOND';
	@override String get rcvdFirst => 'RCVD FIRST, SENT SECOND';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$qro extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'JUMP TO NEXT FIELD ON RST ENTRY';
	@override String get descriptionOn => 'JUMPING AFTER RST IS ENTERED';
	@override String get descriptionOff => 'NOT JUMPING AUTOMATICALLY';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$qro extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'DEFAULT REPORT — PHONE';
	@override String get description => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON SSB, FM OR AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$qro extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'DEFAULT REPORT — CW AND DATA';
	@override String get description => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON CW, RTTY AND OTHER DATA MODES';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$qro extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'DEFAULT REPORT — FT8 AND FT4';
	@override String get description => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON THE FT MODES';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$qro extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'NUMBERS ROW';
	@override String get description => 'SHOW A ROW OF NUMBER KEYS ABOVE THE KEYBOARD WHILE LOGGING';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$qro extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SLASH AND PERIOD KEY';
	@override String get description => 'ADDS A CONTEXTUAL KEY: “/” FOR CALLSIGNS, “.” FOR NUMBERS';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$qro extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'VIBRATE ON KEY PRESS';
	@override String get description => 'HAPTIC FEEDBACK WHEN YOU TAP A NUMBER KEY';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$qro extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get off => 'DISABLED';
	@override String get rigctld => 'HAMLIB RIGCTLD';
	@override String get flrig => 'FLRIG';
	@override String get hrd => 'HAM RADIO DELUXE®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$qro extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'NO OPERATOR CALLSIGN TO LOG IN WITH';
	@override String get connectFailed => 'THE NODE COULD NOT BE REACHED';
	@override String get needsPassword => 'THE NODE ASKS FOR A PASSWORD, AND NONE IS STORED';
	@override String get loginFailed => 'THE NODE DID NOT ACCEPT THE LOGIN';
	@override String get disconnected => 'THE NODE CLOSED THE CONNECTION';
	@override String get timeout => 'THE NODE DID NOT ANSWER';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$qro extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get ms => 'MS';
	@override String get kHz => 'KHZ';
	@override String get kHzPerSecond => 'KHZ/S';
	@override String get hz => 'HZ';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$qro extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CONTROL PTT WITH [\']';
	@override String get descriptionOn => 'IN PHONE MODES, [\'] KEYS THE RADIO AND [\'] AGAIN UNKEYS IT. IT UNKEYS BY ITSELF AFTER A MINUTE.';
	@override String get descriptionOff => 'THE [\'] KEY DOES NOT KEY THE RADIO.';
	@override String get pill => 'TX';
	@override String get transmitting => 'TRANSMITTING';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$qro extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SMART VFO SNAP';
	@override String get descriptionOn => 'AFTER YOU STOP TURNING THE DIAL, ROUNDING THE FREQUENCY TO A SENSIBLE STEP. VOICE MODES ONLY.';
	@override String get descriptionOff => 'STAYING EXACTLY WHERE YOU TUNED IT.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$qro extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SMART SNAP: SETTLE DELAY';
	@override String get description => 'HOW LONG THE DIAL HAS TO STOP BEFORE THE FREQUENCY IS ROUNDED. SHORTER FEELS IMMEDIATE; LONGER LEAVES ROOM FOR A SLOW MOVE.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$qro extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SMART SNAP: LONG MOVE';
	@override String get description => 'MOVE AT LEAST THIS FAR AND THE FREQUENCY ROUNDS TO A WHOLE KHZ, HOWEVER SLOWLY YOU FINISHED.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$qro extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SMART SNAP: SMALLEST MOVE';
	@override String get description => 'MOVE LESS THAN THIS AND THE FREQUENCY IS NOT ROUNDED, SO FINE TUNING IS LEFT ALONE.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$qro extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SMART SNAP: SLOWEST MOVE';
	@override String get description => 'TURN THE DIAL SLOWER THAN THIS AND THE FREQUENCY IS NOT ROUNDED, UNLESS IT WAS A LONG MOVE.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$qro extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM OFF';
	@override String get pillRun => 'ESM RUN';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'ENTER SENDS MESSAGES';
	@override String get off => 'OFF';
	@override String get run => 'RUN';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'ENTER SENDS MESSAGES: ${state}. TAP TO CHANGE.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$qro extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'KEYER SPEED';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} WPM';
	@override String get pillUnknown => '– WPM';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$qro extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW KEYER MESSAGES';
	@override String get notSupported => 'CURRENT RADIO DOES NOT SUPPORT CW KEYING';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'MESSAGE (${n})';
	@override String get labelField => 'LABEL';
	@override String labelKey({required Object n}) => 'F${n} LABEL';
	@override String get details => 'DETAILS';
	@override String get empty => '(EMPTY)';
	@override String get sets => 'MESSAGE SET';
	@override String get newSet => 'NEW SET';
	@override String get renameSet => 'RENAME SET';
	@override String get deleteSet => 'DELETE SET';
	@override String get newSetName => 'NAME';
	@override String get setDefault => 'DEFAULT';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM MESSAGES';
	@override String get setSaved => 'MY MESSAGES';
	@override String get repeat => 'REPEAT MESSAGE #1';
	@override String get repeatOff => 'NO';
	@override String repeatAfter({required Object n}) => 'AFTER ${n} SECONDS';
	@override String get repeatWait => 'REPEATING';
	@override String get keyboard => 'TYPE TO SEND';
	@override String get keyboardField => 'TYPE TO SEND';
	@override String get closeArea => 'CLOSE THE KEYER AREA';
	@override String get help => 'HELP';
	@override String get helpTitle => 'WRITING CW MESSAGES';
	@override String get helpIntro => 'MESSAGES CAN USE TEMPLATES WITH THE FOLLOWING VALUES:';
	@override String get helpOpCall => 'YOUR CALLSIGN';
	@override String get helpQsoCall => 'THEIR CALLSIGN — IN A // STACK, THE CALL THAT WILL BE LOGGED';
	@override String get helpQsoFullCall => 'THEIR CALLSIGN, IF THERE IS A VALID CALL; BLANK FOR A PARTIAL';
	@override String get helpQsoPartial => 'A PARTIAL CALL; BLANK IF THERE IS A FULL VALID CALL';
	@override String get helpQsoNextCall => 'IN A // STACK, THE CALL THAT WILL BE SELECTED FOR LOGGING NEXT, IF THERE IS A VALID FULL CALL';
	@override String get helpQsoNextPartial => 'IN A // STACK, THE NEXT PARTIAL AFTER LOGGING THE CURRENT CONTACT';
	@override String get helpQsoName => 'THEIR FIRST NAME, AS TYPED OR ELSE FROM THE LOOKUP';
	@override String get helpQsoState => 'THEIR STATE, AS TYPED OR ELSE FROM THE LOOKUP';
	@override String get helpKeyerMsg => 'MESSAGE 1 AS IT WOULD BE SENT, INSIDE ANOTHER MESSAGE. VALID FOR MESSAGES 1 THROUGH 8';
	@override String get helpQsoRst => 'THE REPORT YOU ARE SENDING';
	@override String get helpQsoSerial => 'YOUR SERIAL NUMBER, IN A CONTEST THAT SENDS ONE';
	@override String get helpPad => 'PADS WITH ZEROS TO THAT MANY DIGITS: 7 IS SENT AS 007';
	@override String get helpCut => 'CUT NUMBERS, T FOR 0 AND N FOR 9: 599 IS SENT AS 5NN';
	@override String get helpCutDigits => 'CHOOSES THE DIGITS TO CUT, IN QUOTES — 0 IS T, 1 IS A, 5 IS E, 9 IS N';
	@override String get helpFullExample => 'FULL EXAMPLE:';
	@override String get helpExample => 'SENDS W1AW 5NN TT7';
	@override String get helpEsmIntro => 'WITH ENTER SENDS MESSAGES ON, ENTER KEYS MESSAGES BY THEIR FUNCTION KEY, AS N1MM DOES. THE ESM MESSAGES SET STARTS WITH THESE:';
	@override String get helpEsmCq => 'RUNNING, ENTER WITH THE CALL FIELD EMPTY CALLS CQ';
	@override String get helpEsmExchange => 'YOUR EXCHANGE: AFTER THEIR CALL WHEN RUNNING, AFTER THEY ANSWER IN S&P';
	@override String get helpEsmThanks => 'THANKS, ONCE THE CONTACT HAS LOGGED: ITS PLACEHOLDERS NAME THE NEXT CONTACT, NOT THIS ONE';
	@override String get helpEsmMyCall => 'IN S&P, YOUR CALL TO THE STATION YOU ARE ANSWERING';
	@override String get helpEsmHisCall => 'RUNNING, THEIR CALL AHEAD OF YOUR EXCHANGE';
	@override String get helpEsmAgain => 'ASKS AGAIN WHEN NOTHING OF THEIR EXCHANGE WAS COPIED';
	@override String get helpEsmStackThanks => 'SUGGESTED F3 FOR // STACKS: TU GOES OUT AFTER THE CONTACT LOGS, SO IT THANKS, THEN CALLS THE NEXT STACKED STATION AND SENDS YOUR EXCHANGE, OR ASKS A PARTIAL BACK (TU KR?); WITH NOTHING LEFT, JUST TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$qro extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'PHONE KEYER MESSAGES';
	@override String get notSupported => 'CURRENT RADIO DOES NOT SUPPORT PHONE MESSAGES';
	@override String get description => 'THIS USES THE RADIO\'S VOICE MEMORIES';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'VOICE MEMORY (${n})';
	@override String get labelField => 'LABEL';
	@override String labelKey({required Object n}) => 'VOICE MEMORY ${n} LABEL';
	@override String durationSeconds({required Object n}) => '${n} S';
	@override String get emptyOnRadio => 'EMPTY';
	@override String get notMeasured => 'UNKNOWN LENGTH';
	@override String get playButton => 'PLAY';
	@override String get recordButton => 'RECORD';
	@override String get stopButton => 'STOP';
	@override String get repeat => 'REPEAT MESSAGE #1';
	@override String get repeatOff => 'NO';
	@override String repeatAfter({required Object n}) => 'AFTER ${n} SECONDS';
	@override String recordHelpTitle({required Object model}) => '${model} NOTES:';
	@override String namedOnDevice({required Object device}) => 'THESE MEMORIES ARE IN ${device}\'S RADIO. THEIR NAMES AND LENGTHS BELONG TO THAT DEVICE.';
	@override String get namedOnRadio => 'SAVED IN THE RADIO, WHERE ITS OTHER CLIENTS SEE IT TOO.';
	@override String get recordHelpYaesuDvs => 'WAIT FOR THE [REC] INDICATOR ON THE RADIO, THEN HOLD THE PTT BUTTON AND RECORD YOUR MESSAGE. END IT BY PRESSING THE STOP BUTTON HERE IN THE APP BEFORE RELEASING PTT TO AVOID UNWANTED CLICKS.';
	@override String get recordHelpFt891 => 'WAIT FOR THE [REC] INDICATOR TO BLINK AT LEAST FOUR TIMES, THEN HOLD THE PTT BUTTON AND RECORD YOUR MESSAGE. END IT BY PRESSING THE STOP BUTTON HERE IN THE APP BEFORE RELEASING PTT TO AVOID UNWANTED CLICKS.';
	@override String get pill => 'VOICE';
	@override String play({required Object n}) => 'PLAY MEMORY ${n}';
	@override String get stop => 'STOP';
	@override String record({required Object n}) => 'RECORD MEMORY ${n}';
	@override String get stopRecording => 'STOP RECORDING';
	@override String get playing => 'PLAYING…';
	@override String get recording => 'RECORDING…';
	@override String playingMemory({required Object label}) => 'PLAYING ${label}';
	@override String recordingMemory({required Object label}) => 'RECORDING ${label}';
	@override String get doubtful => 'DID THE RADIO PLAY IT? IT SAID IT WAS IDLE RIGHT AWAY.';
	@override String get recordOnRadio => 'YOU HAVE TO RECORD THE MEMORIES ON THE RADIO ITSELF.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$qro extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'AVOID ZERO-BEATING ON SPOTS';
	@override String get descriptionOn => 'WITH A RADIO CONNECTED, TUNING A FEW HZ OFF A CW SPOT, SO EVERYONE ANSWERING IT ISN’T CALLING ON THE SAME NOTE.';
	@override String get descriptionOff => 'TUNING EXACTLY TO THE SPOTTED FREQUENCY.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$qro extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'ZERO-BEAT: AVOIDANCE RANGE';
	@override String get description => 'HOW FAR OFF THE SPOTTED FREQUENCY TO LAND, EITHER SIDE. THE OFFSET IS NEVER NEAR ZERO — THAT WOULD BE A ZERO BEAT AGAIN.';
}

// Path: settings.map.style
class _Translations$settings$map$style$qro extends Translations$settings$map$style$en {
	_Translations$settings$map$style$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'MAP STYLE';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$qro extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SHOW CALLSIGNS';
	@override String get description => 'EACH CONTACT IS A PILL WITH ITS CALLSIGN, IN ITS BAND\'S COLOR';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$qro extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SHOW GRAYLINE';
	@override String get description => 'SHADES THE NIGHT SIDE OF THE EARTH, WITH TWILIGHT AS A GRADIENT';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$qro extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'AUTOMATIC';
	@override String get liberty => 'LIBERTY';
	@override String get bright => 'BRIGHT';
	@override String get positron => 'POSITRON';
	@override String get voyager => 'VOYAGER';
	@override String get darkMatter => 'DARK MATTER';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$qro extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SHARE APP USAGE DATA';
	@override String get descriptionOn => 'HELPING US IMPROVE THE APP BY SHARING USAGE, CONFIGURATION, CRASH AND PERFORMANCE DATA';
	@override String get descriptionOff => 'KEEPING APP USAGE DATA PRIVATE.\nTHE HAM2K TEAM WON\'T BE ABLE TO DETECT CRASHES OR OTHER ISSUES.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$qro extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get title => 'SHARE OPERATION DATA';
	@override String get descriptionOn => 'SHARING SOME OPERATION DATA PUBLICLY AND WITH OTHER USERS';
	@override String get descriptionOff => 'KEEPING OPERATION DATA PRIVATE';
}

// Path: settings.station.models
class _Translations$settings$station$models$qro extends Translations$settings$station$models$en {
	_Translations$settings$station$models$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get flexRadio => 'FLEXRADIO (SMARTSDR)';
	@override String get ft891 => 'YAESU FT-891';
	@override String get ft991a => 'YAESU FT-991/A';
	@override String get ft710 => 'YAESU FT-710';
	@override String get ftdx10 => 'YAESU FTDX10';
	@override String get ftx1 => 'YAESU FTX-1';
	@override String get ft817 => 'YAESU FT-817 / FT-818';
	@override String get ft857 => 'YAESU FT-857';
	@override String get ft897 => 'YAESU FT-897';
	@override String get ft450 => 'YAESU FT-450 / FT-450D';
	@override String get q900 => 'GUOHETEC Q900';
	@override String get tenTecEagle => 'TEN-TEC EAGLE (599)';
	@override String get tenTecOrion => 'TEN-TEC ORION (565)';
	@override String get tenTecOrionII => 'TEN-TEC ORION II (566)';
	@override String get sotacat => 'SOTACAT (ELECRAFT KX2/KX3)';
	@override String get yaesuGeneric => 'YAESU - GENERIC';
	@override String get icomGeneric => 'ICOM - GENERIC';
	@override String get kenwoodGeneric => 'KENWOOD - GENERIC';
	@override String get ts590sg => 'KENWOOD TS-590SG';
	@override String get ts480 => 'KENWOOD TS-480';
	@override String get qmx => 'QRP LABS QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'LAB599 TX-500';
	@override String get tx500mp => 'LAB599 TX-500MP';
	@override String get qcx => 'QRP LABS QCX';
	@override String get elecraftGeneric => 'ELECRAFT - GENERIC';
	@override String get kx2 => 'ELECRAFT KX2';
	@override String get kx3 => 'ELECRAFT KX3';
	@override String get k4 => 'ELECRAFT K4';
	@override String get ic705 => 'ICOM IC-705';
	@override String get ic7300 => 'ICOM IC-7300';
	@override String get ic7300mk2 => 'ICOM IC-7300 MK2';
	@override String get ic706mkiig => 'ICOM IC-706MKIIG';
	@override String get ic7100 => 'ICOM IC-7100';
	@override String get ic7610 => 'ICOM IC-7610';
	@override String get ic7760 => 'ICOM IC-7760';
	@override String get ic9700 => 'ICOM IC-9700';
	@override String get ic905 => 'ICOM IC-905';
	@override String get ic7850 => 'ICOM IC-7850';
	@override String get ic7851 => 'ICOM IC-7851';
	@override String get x6100 => 'XIEGU X6100';
	@override String get g90 => 'XIEGU G90';
	@override String get rigctld => 'RADIO CONTROLLED VIA RIGCTLD';
	@override String get rigctldNodeName => 'MY RADIO (VIA RIGCTLD)';
	@override String get flrig => 'RADIO CONTROLLED VIA FLRIG';
	@override String get flrigNodeName => 'MY RADIO (VIA FLRIG)';
	@override String get hrd => 'RADIO CONTROLLED VIA HAM RADIO DELUXE®';
	@override String get hrdNodeName => 'MY RADIO (VIA HRD)';
	@override String get n3fjp => 'RADIO CONTROLLED VIA N3FJP';
	@override String get n3fjpNodeName => 'MY RADIO (VIA N3FJP)';
	@override String get commander => 'RADIO CONTROLLED VIA DXLAB COMMANDER';
	@override String get commanderNodeName => 'MY RADIO (VIA COMMANDER)';
	@override String get antenna => 'ANTENNA';
	@override String get key => 'CW KEY';
	@override String get winkeyer => 'WINKEYER';
	@override String get placeholderRadio => 'GENERIC RADIO (PLACEHOLDER)';
	@override String get placeholderRadioNodeName => 'MY RADIO';
	@override String get antennaGenius => '4O3A ANTENNA GENIUS';
	@override String get sierraCoax => 'SIERRA RADIO CX-1 COAX SWITCH';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'NOOELEC NESDR';
	@override String get sdrplay => 'SDRPLAY RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$qro extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get network => 'NETWORK/WIFI';
	@override String get secureNetwork => 'SECURE NETWORK/WIFI';
	@override String get usbSerial => 'USB SERIAL';
	@override String get wifi => 'NETWORK/WIFI';
	@override String get bluetoothSerial => 'BLUETOOTH SERIAL';
	@override String get bleSerial => 'BLUETOOTH LE';
	@override String get placeholder => 'PLACEHOLDER';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$qro extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'DIPOLE';
	@override String get vertical => 'VERTICAL';
	@override String get yagiBeam => 'YAGI / BEAM';
	@override String get loop => 'LOOP';
	@override String get longWire => 'LONG WIRE / EFHW';
	@override String get other => 'OTHER';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$qro extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get straight => 'STRAIGHT KEY';
	@override String get sideswiper => 'SIDESWIPER';
	@override String get bug => 'BUG (MECHANICAL SEMI-AUTOMATIC)';
	@override String get fullyAutomatic => 'FULLY-AUTOMATIC KEYER';
	@override String get singlePaddle => 'SINGLE PADDLE';
	@override String get dualPaddle => 'DUAL PADDLE';
	@override String get computerDriven => 'COMPUTER DRIVEN';
	@override String get other => 'OTHER';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$qro extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$qro._(TranslationsQro root) : this._root = root, super.internal(root);

	final TranslationsQro _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'UNKNOWN';
	@override String get sunny => 'SUNNY';
	@override String get clear => 'CLEAR';
	@override String get mainlySunny => 'MAINLY SUNNY';
	@override String get mainlyClear => 'MAINLY CLEAR';
	@override String get partlyCloudy => 'PARTLY CLOUDY';
	@override String get cloudy => 'CLOUDY';
	@override String get foggy => 'FOGGY';
	@override String get rimeFog => 'RIME FOG';
	@override String get lightDrizzle => 'LIGHT DRIZZLE';
	@override String get drizzle => 'DRIZZLE';
	@override String get heavyDrizzle => 'HEAVY DRIZZLE';
	@override String get lightFreezingDrizzle => 'LIGHT FREEZING DRIZZLE';
	@override String get freezingDrizzle => 'FREEZING DRIZZLE';
	@override String get lightRain => 'LIGHT RAIN';
	@override String get rain => 'RAIN';
	@override String get heavyRain => 'HEAVY RAIN';
	@override String get lightFreezingRain => 'LIGHT FREEZING RAIN';
	@override String get freezingRain => 'FREEZING RAIN';
	@override String get lightSnow => 'LIGHT SNOW';
	@override String get snow => 'SNOW';
	@override String get heavySnow => 'HEAVY SNOW';
	@override String get snowGrains => 'SNOW GRAINS';
	@override String get lightShowers => 'LIGHT SHOWERS';
	@override String get showers => 'SHOWERS';
	@override String get heavyShowers => 'HEAVY SHOWERS';
	@override String get lightSnowShowers => 'LIGHT SNOW SHOWERS';
	@override String get snowShowers => 'SNOW SHOWERS';
	@override String get thunderstorm => 'THUNDERSTORM';
	@override String get lightThunderstormsWithHail => 'LIGHT THUNDERSTORMS WITH HAIL';
	@override String get thunderstormWithHail => 'THUNDERSTORM WITH HAIL';
}

/// The flat map containing all translations for locale <qro>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsQro {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'SAVE',
			'common.ok' => 'OK',
			'common.cancel' => 'CANCEL',
			'common.delete' => 'DELETE',
			'common.create' => 'CREATE',
			'common.error' => 'ERROR',
			'common.close' => 'CLOSE',
			'common.done' => 'DONE',
			'common.callsign' => 'CALLSIGN',
			'common.clear' => 'CLEAR',
			'common.dismiss' => 'DISMISS',
			'common.expand' => 'EXPAND',
			'common.collapse' => 'COLLAPSE',
			'onboarding.welcomeTitle' => 'WELCOME TO HAM2K PORTABLE LOGGER!',
			'onboarding.welcomeTitleDesktop' => 'WELCOME TO HAM2K POWER LOGGER!',
			'onboarding.welcomeBody' => 'WE HAVE A FEW QUESTIONS TO HELP US BETTER SUIT YOUR NEEDS.',
			'onboarding.skip' => 'SKIP',
			'onboarding.kContinue' => 'CONTINUE',
			'onboarding.back' => 'BACK',
			'onboarding.next' => 'NEXT',
			'onboarding.done' => 'DONE',
			'onboarding.callsignTitle' => 'WHAT\'S YOUR CALLSIGN?',
			'onboarding.callsignBody' => 'YOU NEED AN AMATEUR RADIO OPERATOR LICENSE IN ORDER TO FIND THIS APP USEFUL',
			'onboarding.callsignLabel' => 'OPERATOR\'S CALLSIGN',
			'onboarding.alreadyHaveAccount' => 'ALREADY HAVE AN ACCOUNT?',
			'onboarding.foundSiblingTitle' => 'LINK AN EXISTING ACCOUNT?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'WE FOUND ${app} ON THIS DEVICE. LINK THIS APP TO THE SAME ACCOUNT AND YOUR CALLSIGN AND LOGS COME ACROSS.',
			'onboarding.foundPoloBody' => 'WE FOUND AN OLDER VERSION OF HAM2K PORTABLE LOGGER ON THIS DEVICE. LINK THIS APP TO THE SAME ACCOUNT AND YOUR CALLSIGN AND LOGS COME ACROSS.',
			'onboarding.foundSiblingsBody' => 'WE FOUND OTHER HAM2K APPS ON THIS DEVICE. LINK THIS APP TO ONE OF THEIR ACCOUNTS AND YOUR CALLSIGN AND LOGS COME ACROSS.',
			'onboarding.linkWithApp' => ({required Object app}) => 'LINK WITH ${app}',
			'onboarding.linkWithPolo' => 'LINK WITH ACCOUNT IN OLDER VERSION',
			'onboarding.setUpFresh' => 'SET UP FRESH',
			'onboarding.activitiesTitle' => 'FAVORITE ACTIVITIES',
			'onboarding.activitiesBody' => 'ARE YOU INTERESTED IN ANY OF THESE POPULAR ACTIVATION PROGRAMS?',
			'onboarding.activitiesFooter' => '(YOU CAN FIND MORE OPTIONS IN THE SETTINGS)',
			'onboarding.activityPota' => 'PARKS ON THE AIR',
			'onboarding.activitySota' => 'SUMMITS ON THE AIR',
			'onboarding.activityWwff' => 'WORLD WIDE FLORA & FAUNA',
			'onboarding.consentTitle' => 'DATA & PRIVACY',
			'onboarding.consentUsageBody' => 'TO HELP US MAKE THE APP BETTER, WE\'D LIKE TO COLLECT PERFORMANCE, CRASH, AND APP USAGE DATA.',
			'onboarding.consentUsageLabel' => 'SHARE APP USAGE DATA',
			'onboarding.consentOperationBody' => 'SOME FEATURES MIGHT INVOLVE SHARING YOUR OPERATION DATA WITH OTHER USERS. YOU CAN OPT-OUT AT ANY TIME.',
			'onboarding.consentOperationLabel' => 'SHARE OPERATION DATA',
			'onboarding.finishingSetup' => 'FINISHING SETUP — DOWNLOADING REFERENCE DATA…',
			'startScreen.credits' => 'BY KI2D AND FRIENDS',
			'testerOverlay.tape' => 'CAUTION: UNDER CONSTRUCTION',
			'testerOverlay.warningTitle' => 'THIS APP IS A WORK IN PROGRESS',
			'testerOverlay.warningBody' => 'MOST FEATURES HAVE UNEVEN SURFACES AND THERE ARE TRIP HAZARDS ALL OVER. PLEASE CHECK FOR UPDATES REGULARLY.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'WHAT\'S NEW IN BUILD ${build}',
			'testerOverlay.thanks' => 'THANK YOU FOR PUTTING YOUR LOG AT RISK IN ORDER TO HELP US MAKE THIS APP BETTER!',
			'extensionsPanel.categoryActivity' => 'ACTIVITIES',
			'extensionsPanel.categoryAward' => 'AWARDS',
			'extensionsPanel.categoryContest' => 'CONTESTS',
			'extensionsPanel.categoryLookup' => 'CALLSIGN LOOKUPS',
			'extensionsPanel.categorySpots' => 'SPOT SOURCES',
			'extensionsPanel.categoryDashboard' => 'DASHBOARD PANELS',
			'extensionsPanel.categoryOther' => 'OTHER EXTENSIONS',
			'extensionsPanel.searchHint' => 'SEARCH EXTENSIONS',
			'extensionsPanel.applying' => 'ACTIVATING EXTENSION CHANGES, THIS MAY TAKE A MOMENT…',
			'extensionsPanel.noMatches' => 'NO EXTENSIONS MATCH YOUR SEARCH',
			'extensionsPanel.installFromFile' => 'INSTALL FROM FILE…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'VERSION ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'SCREENSHOT ${n} OF ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'PREVIOUS SCREENSHOT',
			'extensionsPanel.nextScreenshot' => 'NEXT SCREENSHOT',
			'extensionsPanel.screenshotUnavailable' => 'SCREENSHOT UNAVAILABLE',
			'extensionsPanel.canReach' => 'THIS EXTENSION CAN CONTACT',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, OVER A LIVE CONNECTION',
			'extensionsPanel.canHoldLocalConnection' => 'DEVICES ON YOUR LOCAL NETWORK, OVER A LIVE CONNECTION',
			'extensionsPanel.canUseLocation' => 'YOUR LOCATION',
			'extensionsPanel.canReadRadio' => 'YOUR RADIO, TO READ ITS FREQUENCY AND MODE',
			'extensionsPanel.canControlRadio' => 'YOUR RADIO, TO CONTROL IT AND TO TRANSMIT WITH IT — TUNING, POWER, CW, VOICE MEMORIES AND PTT',
			'extensionsPanel.canCommandRadioRaw' => 'YOUR RADIO, TO SEND IT ANY COMMAND IN ITS OWN PROTOCOL — INCLUDING ONES THAT TRANSMIT OR CHANGE ITS SETTINGS',
			'extensionsPanel.canReadCluster' => 'THE DX CLUSTER, LOGGED IN AS YOU, TO READ WHAT IT SENDS',
			'extensionsPanel.canSpotCluster' => 'THE DX CLUSTER, LOGGED IN AS YOU, TO POST SPOTS IN YOUR NAME',
			'extensionsPanel.canCommandCluster' => 'THE DX CLUSTER, LOGGED IN AS YOU, TO SEND IT ANY COMMAND IN YOUR NAME',
			'extensionsPanel.canSetUserAgent' => 'IDENTIFY ITSELF TO SERVERS UNDER ITS OWN NAME',
			'extensionsPanel.noCapabilities' => 'IT ASKS FOR NOTHING OUTSIDE THE APP.',
			'extensionsPanel.sandboxNote' => 'EXTENSIONS RUN SANDBOXED: NO ACCESS TO YOUR FILES, AND NO NETWORK BEYOND WHAT IS LISTED HERE.',
			'extensionsPanel.installAction' => 'INSTALL',
			'extensionsPanel.updateAction' => 'UPDATE',
			'extensionsPanel.installFailed' => 'THAT EXTENSION COULD NOT BE INSTALLED',
			'extensionsPanel.installedBadge' => 'INSTALLED',
			'extensionsPanel.uninstallAction' => 'REMOVE',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'REMOVE ${name}?',
			'extensionsPanel.uninstallBody' => 'THIS EXTENSION AND ITS SETTINGS WILL BE REMOVED. YOUR LOGS WILL REMAIN UNTOUCHED.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'INSTALLED ${name}',
			'extensionsPanel.installDownloading' => 'DOWNLOADING…',
			'extensionsPanel.installWaiting' => 'WAITING TO INSTALL…',
			'extensionsPanel.installInstalling' => 'INSTALLING…',
			'extensionsPanel.installAwaitingApproval' => 'WAITING FOR YOUR APPROVAL…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} IS ALREADY BEING INSTALLED.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'UPDATED TO ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'INSTALLING ${name} DID NOT FINISH. IT MAY NEED INSTALLING AGAIN.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'COULD NOT REMOVE ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'DOWNLOADED FROM ${source}',
			'extensionsPanel.dropHint' => 'DROP A .H2KEXT EXTENSION TO INSTALL IT',
			'extensionsPanel.dropOneOnly' => 'DROP ONE EXTENSION AT A TIME.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} RETURNED ${status} FOR THAT EXTENSION.',
			'extensionsPanel.downloadTooLarge' => 'THAT DOWNLOAD IS FAR TOO LARGE TO BE AN EXTENSION.',
			'extensionsPanel.downloadNotSecure' => 'THAT DOWNLOAD REDIRECTED SOMEWHERE INSECURE.',
			'extensionsPanel.catalogSection' => 'CATALOG',
			'extensionsPanel.catalogLoading' => 'LOADING THE CATALOG…',
			'extensionsPanel.catalogUnreachable' => 'CATALOG UNREACHABLE',
			'extensionsPanel.builtIn' => 'BUILT IN',
			'extensionsPanel.updateAvailableBadge' => 'UPDATE AVAILABLE',
			'extensionsPanel.updatesAvailableTitle' => 'EXTENSION UPDATES',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'AN UPDATE IS AVAILABLE FOR ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} AND ${count} MORE NEED UPDATING.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} NEED UPDATING.',
			'extensionsPanel.pendingUpdatesSection' => 'PENDING UPDATES',
			'extensionsPanel.updateAllAction' => 'UPDATE ALL',
			'extensionsPanel.updatesUnderWay' => 'THOSE UPDATES ARE ALREADY UNDER WAY.',
			'extensionsPanel.updatesNothingLeft' => 'YOUR EXTENSIONS ARE UP TO DATE.',
			'extensionsPanel.updatesNoticeAction' => 'MORE INFO',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'UPDATE ${count} EXTENSION?', other: 'UPDATE ${count} EXTENSIONS?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'YOUR EXTENSIONS ARE READY',
			'extensionsPanel.upgradeDoneBody' => 'THEY NOW COME FROM THE HAM2K EXTENSION CATALOG, SO THEY CAN BE UPDATED WITHOUT WAITING FOR A NEW VERSION OF THE APP.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'NOT UPGRADED: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'WOULD NOT RUN: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'THEY ARE STILL INSTALLED AND MARKED IN SETTINGS › EXTENSIONS — UPDATING THEM THERE WILL BRING THEM BACK.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'THE CATALOG HAS NO DIRECT REPLACEMENT FOR THESE, SO LOOK THERE FOR EXTENSIONS THAT COVER WHAT YOU USED.',
			'extensionsPanel.retiredQp' => 'QSO PARTIES',
			'extensionsPanel.retiredStateparks' => 'STATE PARKS EVENTS',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} OF YOUR EXTENSIONS HAVE NOT ARRIVED YET. THEY WILL BE DOWNLOADED THE NEXT TIME THE EXTENSION CATALOG CAN BE REACHED.',
			'extensionsPanel.runtimeDeadBody' => 'YOUR EXTENSIONS WOULD NOT START. RESTARTING THE APP SHOULD BRING THEM BACK.',
			'extensionsPanel.refusedTitle' => 'SOME EXTENSIONS WOULD NOT RUN',
			'extensionsPanel.upgradeBusyTitle' => 'STILL SETTING UP',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'YOUR EXTENSIONS ARE NOT RUNNING',
			'extensionsPanel.restoreTitle' => 'SOME OF YOUR EXTENSIONS ARE MISSING',
			'extensionsPanel.restoreBody' => 'THESE EXTENSIONS YOU INSTALLED ARE NOT ON THIS DEVICE. WE CAN DOWNLOAD THEM AGAIN FROM THE HAM2K EXTENSION CATALOG:',
			'extensionsPanel.restoreFromFile' => 'INSTALLED FROM A FILE. INSTALL THESE AGAIN FROM THEIR FILES, OR FORGET THEM:',
			'extensionsPanel.restoreOtherCatalog' => 'INSTALLED FROM A DIFFERENT EXTENSION CATALOG, SO THEY ARE NOT AVAILABLE HERE:',
			'extensionsPanel.restoreForget' => 'FORGET',
			'extensionsPanel.restoreInstall' => 'INSTALL',
			'extensionsPanel.restoreLater' => 'LATER',
			'extensionsPanel.restoreInstalling' => 'INSTALLING YOUR EXTENSIONS…',
			'extensionsPanel.restoreDoneTitle' => 'YOUR EXTENSIONS ARE BACK',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'INSTALLED AGAIN: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'SOME EXTENSIONS COULD NOT BE INSTALLED',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'COULD NOT INSTALL: ${names}. WE WILL OFFER THEM AGAIN NEXT TIME YOU OPEN THE APP.',
			'extensionsPanel.restoreBusyBody' => 'THE APP IS STILL SETTING YOUR EXTENSIONS UP. WE WILL OFFER THESE AGAIN NEXT TIME YOU OPEN THE APP.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'WE INSTALLED THEM AGAIN, BUT YOUR EXTENSIONS WOULD NOT START. RESTARTING THE APP SHOULD BRING THEM BACK.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} WAS WITHDRAWN',
			'extensionsPanel.revokedBody' => 'THE CATALOG WITHDREW THIS VERSION, SO IT HAS BEEN DISABLED.',
			'extensionsPanel.downloadHashMismatch' => 'THAT DOWNLOAD IS NOT THE EXTENSION THE CATALOG DESCRIBED.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'THE CATALOG HAS NO VERSION ${version} OF ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'THAT CATALOG LINK DOES NOT NAME AN EXTENSION VERSION.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'THE CATALOG HAS NO RELEASE OF ${key} ON THAT TRACK.',
			'extensionsPanel.installFromLink' => 'INSTALL FROM LINK',
			'extensionsPanel.unstableReleaseWarning' => 'THIS IS AN UNSTABLE RELEASE, WHICH ITS PUBLISHER HAS NOT CALLED FINISHED. IT MAY MISBEHAVE, AND IT WILL KEEP RECEIVING UNSTABLE UPDATES.',
			'extensionsPanel.bleedingReleaseWarning' => 'THIS IS A BLEEDING-EDGE RELEASE: WORK IN PROGRESS THAT MAY BREAK OR LOSE ITS SETTINGS. IT WILL KEEP RECEIVING BLEEDING-EDGE UPDATES.',
			'extensionsPanel.channelUnstable' => 'UNSTABLE',
			'extensionsPanel.channelBleeding' => 'BLEEDING',
			'extensionsPanel.followsUnstable' => 'RECEIVES UNSTABLE AND STABLE RELEASES',
			'extensionsPanel.followsBleeding' => 'RECEIVES BLEEDING-EDGE, UNSTABLE AND STABLE RELEASES',
			'extensionsPanel.followStableAction' => 'FOLLOW STABLE RELEASES ONLY',
			'extensionsPanel.revokedBadge' => 'REVOKED',
			'extensionsPanel.refusedBadge' => 'DID NOT LOAD',
			'extensionsPanel.downloadNotHttps' => 'THAT DOWNLOAD IS NOT OVER A SECURE CONNECTION.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} COULD NOT BE REACHED FOR THAT EXTENSION.',
			'extensionsPanel.detailsAction' => 'DETAILS',
			'extensionsPanel.installedFromFile' => 'INSTALLED FROM A FILE',
			'extensionsPanel.detailsWhatItDoes' => 'PROVIDES SUPPORT FOR',
			'extensionsPanel.installedPreloaded' => 'PRE-INSTALLED',
			'extensionsPanel.hookAccount' => 'ACCOUNT SIGN-IN',
			'extensionsPanel.hookCallNotes' => 'CALL NOTES',
			'extensionsPanel.hookDataFile' => 'OFFLINE DATA',
			'extensionsPanel.hookExport' => 'EXPORT',
			'extensionsPanel.hookLookup' => 'CALLSIGN LOOKUPS',
			'extensionsPanel.hookScoring' => 'SCORING',
			'extensionsPanel.hookSpots' => 'SPOTS',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'HUNTING ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'ACTIVATING ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '… AND ${count} OTHER EXTENSION', other: '… AND ${count} OTHER EXTENSIONS', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} EXTENSION AVAILABLE', other: '${count} EXTENSIONS AVAILABLE', ), 
			'home.title' => 'PORTABLE LOGGER',
			'home.newOperation' => 'NEW OPERATION',
			'home.stationCallsign' => 'STATION CALLSIGN',
			'home.titleOptional' => 'TITLE (OPTIONAL)',
			'home.emptyList' => 'NO OPERATIONS YET. CREATE ONE TO START LOGGING.',
			'home.quickLookup' => 'QUICK LOOKUP',
			'home.nav.operations' => 'OPERATIONS',
			'home.nav.chase' => 'CHASING',
			'home.nav.logs' => 'LOGS',
			'home.nav.maps' => 'MAPS',
			'home.nav.settings' => 'SETTINGS',
			'home.panels.operations' => 'OPERATION LIST',
			'home.panels.operationsDescription' => 'YOUR OPERATIONS, MOST RECENT FIRST.',
			'home.panels.version' => 'CURRENT VERSION',
			'home.panels.versionDescription' => 'THE HAM2K MARK, THIS APP’S NAME AND WHICH BUILD YOU ARE RUNNING.',
			'home.toggleNav' => 'SHOW OR HIDE THE NAVIGATION LABELS',
			'home.logs.title' => 'LOGS',
			'home.logs.titleFor' => 'LOGS FOR',
			'home.logs.emptyCallsigns' => 'NO QSOS LOGGED YET',
			'home.logs.emptyQsos' => ({required Object call}) => 'NO QSOS FOR ${call}',
			'home.logs.mapNoSelection' => 'SELECT A QSO TO SEE IT ON THE MAP',
			'home.logs.searchHint' => 'SEARCH CALLSIGN OR NAME',
			'home.logs.noSearchMatches' => 'NO QSOS MATCH YOUR SEARCH',
			'home.logs.titleAll' => 'ALL LOGS',
			'home.logs.allCallsigns' => 'ALL CALLSIGNS',
			'home.logs.noOperation' => 'NOT PART OF AN OPERATION',
			'home.logs.unsavedTitle' => 'UNSAVED CHANGES',
			'home.logs.unsavedBody' => 'THIS QSO HAS CHANGES YOU HAVEN’T SAVED.',
			'home.logs.pendingDeleteBody' => 'THIS QSO IS MARKED FOR DELETION.',
			'home.logs.editGone' => 'NOT SAVED: THAT QSO IS NO LONGER IN THIS LOG.',
			'home.logs.discard' => 'DISCARD',
			'home.logs.sheet.callsigns' => 'STATION CALLSIGNS',
			'home.logs.sheet.groupBy' => 'GROUP BY',
			'home.logs.sheet.period' => 'TIME PERIOD',
			'home.logs.groupBy.none' => 'NOT GROUPED',
			'home.logs.groupBy.date' => 'DATE',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'UNKNOWN CONTINENT',
			'home.logs.groupBy.unknownEntity' => 'UNKNOWN ENTITY',
			'home.logs.groupBy.unknownDate' => 'NO DATE',
			'home.logs.period.thisMonth' => 'THIS MONTH',
			'home.logs.period.last3Months' => 'LAST 3 MONTHS',
			'home.logs.period.thisYear' => 'THIS YEAR',
			'home.logs.period.lastYear' => 'LAST YEAR',
			'home.logs.period.allTime' => 'ALL TIME',
			'home.logs.period.custom' => 'CUSTOM RANGE',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'IN ${span}',
			'home.logs.periodTitle.custom' => 'CUSTOM RANGE',
			'home.logs.columns.date' => 'DATE',
			'home.logs.columns.time' => 'TIME',
			'home.logs.columns.freq' => 'FREQUENCY',
			'home.logs.columns.mode' => 'MODE',
			'home.logs.columns.call' => 'CALL',
			'home.logs.columns.name' => 'NAME',
			'home.logs.columns.station' => 'STATION',
			'home.logs.columns.band' => 'BAND',
			'home.logs.columns.sent' => 'SENT',
			'home.logs.columns.rcvd' => 'RCVD',
			'home.logs.columns.grid' => 'GRID',
			'home.logs.columns.state' => 'STATE',
			'home.logs.columns.country' => 'COUNTRY',
			'home.logs.columns.refs' => 'REFS',
			'home.logs.panels.qsos' => 'QSO LOG',
			'home.logs.panels.qsosDescription' => 'THE SELECTED CALLSIGN\'S QSOS, ACROSS EVERY OPERATION.',
			'home.logs.panels.info' => 'INFO',
			'home.logs.panels.infoDescription' => 'TOTAL QSO COUNT, OR THE SELECTED QSO\'S CALLSIGN LOOKUP.',
			'home.logs.panels.map' => 'MAP',
			'home.logs.panels.mapDescription' => 'THE SELECTED QSO\'S LOCATION.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'CALLSIGNS: ${calls}',
			'home.logs.import.skippedOne' => '1 RECORD COULD NOT BE READ',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} RECORDS COULD NOT BE READ',
			'home.logs.import.readingTitle' => 'READING ADIF FILE…',
			'home.logs.import.checkingTitle' => 'CHECKING FOR DUPLICATES…',
			'home.logs.import.importingTitle' => 'IMPORTING QSOS…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} KB',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} OF ${total} CHECKED',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} IMPORTED, OUT OF ${total}',
			'chase.operatorPrefix' => 'OP',
			'chase.chasing' => 'CHASING',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} & MORE',
			'chase.station.title' => 'CHASING STATION',
			'chase.station.stationLabel' => 'STATION: ',
			'chase.station.operatorLabel' => 'OP: ',
			'chase.station.noLocation' => 'NO LOCATION',
			'chase.periodInline.today' => 'TODAY',
			'chase.periodInline.thisWeek' => 'THIS WEEK',
			'chase.periodInline.last14Days' => 'IN THE LAST 14 DAYS',
			'chase.periodInline.thisMonth' => 'THIS MONTH',
			'chase.periodStats.today' => 'STATS FOR TODAY',
			'chase.periodStats.thisWeek' => 'STATS FOR THIS WEEK',
			'chase.periodStats.last14Days' => 'STATS FOR LAST 14 DAYS',
			'chase.periodStats.thisMonth' => 'STATS FOR THIS MONTH',
			'chase.period.today' => 'TODAY',
			'chase.period.thisWeek' => 'THIS WEEK',
			'chase.period.last14Days' => 'LAST 14 DAYS',
			'chase.period.thisMonth' => 'THIS MONTH',
			'chase.goals.title' => 'CHASING GOALS',
			'chase.goals.remove' => ({required Object name}) => 'STOP CHASING ${name}',
			'chase.goals.extensionsTitle' => 'MORE CHASING PROGRAMS',
			'chase.panels.logging' => 'QSOS',
			'chase.panels.loggingDescription' => 'LOGGING CONTROLS ABOVE THE QSOS CHASED IN THE PERIOD.',
			'chase.panels.info' => 'INFO',
			'chase.panels.infoDescription' => 'THE CALLSIGN BEING LOGGED, OR THE PERIOD\'S STATS.',
			'chase.panels.spots' => 'SPOTS',
			'chase.panels.spotsDescription' => 'STATIONS SPOTTED ON THE AIR, READY TO CHASE.',
			'chase.panels.map' => 'MAP',
			'chase.panels.mapDescription' => 'THE PERIOD\'S QSOS AND THE STATION BEING LOGGED.',
			'chase.claims.checking' => 'CHECKING QSOS FOR CHASING',
			'chase.claims.rebuilding' => ({required Object program}) => 'CHECKING THE LOG FOR ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} OF ${total} QSOS',
			'chase.notice.newRef' => ({required Object program}) => 'NEW ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'PROBABLY NEW ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'NEW ${program} BAND',
			'chase.notice.newBandGuess' => ({required Object program}) => 'PROBABLY NEW ${program} BAND',
			'chase.notice.newMode' => ({required Object program}) => 'NEW ${program} MODE',
			'chase.notice.newModeGuess' => ({required Object program}) => 'PROBABLY NEW ${program} MODE',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} UNCONFIRMED',
			'chase.alerts.title' => 'ALERTS',
			'chase.alerts.newRef' => 'NEW REFERENCE',
			'chase.alerts.newBand' => 'NEW BAND',
			'chase.alerts.newMode' => 'NEW MODE',
			'chase.alerts.unconfirmed' => 'UNCONFIRMED',
			'chase.checklists' => 'CHASING PROGRESS',
			'chase.imports.importFrom' => ({required Object label}) => 'IMPORT ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'IMPORT ${file} AS',
			'chase.imports.dropHint' => 'DROP A FILE TO IMPORT IT INTO A CHASING PROGRAM',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'IMPORTED ${count} ${program} ENTRIES FROM ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'IMPORTED ${count} ${program} ENTRIES FROM ${file}, SKIPPED ${skipped} IT COULD NOT READ',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} HAS NOTHING ${program} CAN IMPORT',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} COULD NOT READ ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} COULD NOT READ ANY OF THE ${skipped} RECORDS IN ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'NO CHASING PROGRAM IMPORTS ${file}',
			'dialogs.operationDetails' => 'OPERATION DETAILS',
			'dialogs.activities' => 'ACTIVITIES',
			'dialogs.stationCallsign' => 'STATION CALLSIGN',
			'dialogs.multiStationIdentifier' => 'MULTI-STATION IDENTIFIER (NUMBERS ONLY)',
			'dialogs.notes' => 'NOTES',
			'dialogs.deleteOperationTitle' => 'DELETE OPERATION',
			'dialogs.purgeTestsTitle' => 'PURGE TEST OPERATIONS',
			'dialogs.purgeTestsBody' => 'THIS PERMANENTLY DELETES THESE TEST OPERATIONS AND THEIR QSOS. IT CANNOT BE UNDONE.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'PLUS ${count} TEST CONTACT THAT BELONGS TO NO OPERATION.', other: 'PLUS ${count} TEST CONTACTS THAT BELONG TO NO OPERATION.', ), 
			'dialogs.purgeTestsAction' => 'PURGE',
			'dialogs.syncAllTitle' => 'REPLACE THIS DEVICE\'S LOG?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL BACKS UP AND CLEARS ${qsos} FROM THIS DEVICE, THEN DOWNLOADS THE ACCOUNT\'S LOG AGAIN FROM THE SERVER. THE BACKUP STAYS IN THIS DEVICE\'S DATABASE.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${n} QSO HAS NOT BEEN SYNCED YET — THE SERVER NEVER RECEIVED IT, AND IT WILL NOT COME BACK.', other: '${n} QSOS HAVE NOT BEEN SYNCED YET — THE SERVER NEVER RECEIVED THEM, AND THEY WILL NOT COME BACK.', ), 
			'dialogs.syncAllAction' => 'WIPE AND RESYNC',
			'dialogs.receivedPurgesTitle' => 'TEST OPERATIONS REMOVED ELSEWHERE',
			'dialogs.receivedPurgesBody' => 'THESE WERE DELETED AS TEST OPERATIONS ON ANOTHER DEVICE. REMOVE THEM HERE TOO? THIS PERMANENTLY DELETES THEM AND THEIR QSOS, AND CANNOT BE UNDONE.',
			'dialogs.receivedPurgesAction' => 'REMOVE',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'INVALID CALLSIGN: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'INVALID CALLSIGNS: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} HAS OPERATED SO FAR. ${typed} WILL BE RECORDED FOR NEW CONTACTS.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'NO OPERATOR RECORDED SO FAR. ${typed} WILL BE RECORDED FOR NEW CONTACTS.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'THIS OPERATION ALREADY HAS CONTACTS BY ${calls}. ${typed} WILL ONLY BE RECORDED FOR NEW ONES.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'ALSO RECORD ${typed} AS THE OPERATOR OF THE CONTACT ALREADY LOGGED', other: 'ALSO RECORD ${typed} AS THE OPERATOR OF ALL ${count} CONTACTS ALREADY LOGGED', ), 
			'dialogs.callChange.operatorSeveralStations' => 'WHEN USING MULTIPLE STATIONS OVER THE AIR, THERE\'S NO SUPPORT FOR SEPARATE OPERATORS',
			'dialogs.callChange.contactsUnreadable' => 'THIS OPERATION\'S CONTACTS COULD NOT BE READ, SO CHANGING A CALLSIGN HERE WON\'T OFFER TO UPDATE THEM',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'THE CONTACTS ALREADY LOGGED COULD NOT BE UPDATED, SO NO CHANGES WERE MADE: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} OF ${planned} CONTACTS WERE UPDATED — THE REST ARE NO LONGER IN THIS OPERATION',
			'operation.deletedReadOnly' => 'THIS OPERATION IS DELETED. UNDELETE IT TO LOG OR MAKE CHANGES.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOS',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.tabs.qsosPlain' => 'QSOS',
			'operation.tabs.clock' => 'CLOCK',
			'operation.tabs.weather' => 'WEATHER',
			'operation.tabs.website' => 'WEB SITE',
			'operation.tabs.remoteScreen' => 'REMOTE SCREEN',
			'operation.tabs.solar' => 'SOLAR',
			'operation.tabs.radio' => 'RADIO',
			'operation.tabs.summaries' => 'OPERATION SUMMARIES',
			'operation.positions.nobodyYet' => 'NO OTHER OPERATING POSITIONS ARE SHARING THIS OPERATION YET.',
			'operation.positions.positionLabel' => ({required Object number}) => 'POS: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'OP: ${call}',
			'operation.positions.unnamedPosition' => 'ANOTHER POSITION',
			'operation.positions.thisDevice' => 'OUR OPERATING POSITION',
			'operation.positions.nameIn' => ' IN ',
			'operation.positions.panelTitle' => 'POSITIONS',
			'operation.positions.panelDescription' => 'WHAT EVERY OPERATING POSITION SHARING THIS OPERATION IS LOGGING RIGHT NOW.',
			'operation.stationCallsignNone' => 'NO STATION CALLSIGN',
			'operation.titleNone' => 'NO TITLE',
			'operation.deleteOperation' => 'DELETE OPERATION',
			'operation.loggingControlsStale' => 'ACTIVITY FIELDS MAY BE OUT OF DATE — REOPEN THE OPERATION TO REFRESH THEM',
			'operation.locationNone' => 'NOT SET',
			'operation.generalOperation' => 'GENERAL OPERATION',
			'operation.titleFor' => ({required Object value}) => 'FOR ${value}',
			'operation.titleAt' => ({required Object value}) => 'AT ${value}',
			'operation.segmentNow' => ({required Object description}) => 'NOW ${description}',
			'operation.testOperationSuffix' => 'TESTING',
			'operation.menu.showRstFields' => 'SHOW RST FIELDS',
			'operation.menu.showStateField' => 'SHOW STATE FIELD',
			'operation.menu.showGridField' => 'SHOW GRID FIELD',
			'operation.menu.showDeletedQsos' => 'SHOW DELETED QSOS',
			'operation.menu.showDeletedOps' => 'SHOW DELETED OPERATIONS',
			'operation.menu.showQsoNumbers' => 'SHOW QSO NUMBERS',
			'operation.menu.lookupAllQsos' => 'LOOKUP ALL QSOS',
			'operation.menu.loggingSettingsTitle' => 'LOGGING SETTINGS',
			'operation.menu.mapSettingsTitle' => 'MAP SETTINGS',
			'operation.menu.actionsSection' => 'ACTIONS',
			'operation.layout.title' => 'ADD A PANEL',
			'operation.layout.availableSection' => 'AVAILABLE PANELS',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} SETTINGS',
			'operation.layout.panelSettingsAction' => 'PANEL SETTINGS',
			'operation.layout.viewName' => 'OPERATION VIEW',
			'operation.layout.viewOptions' => 'VIEW LAYOUT OPTIONS',
			'operation.layout.viewTitleBuiltIn' => 'THIS VIEW IS BUILT INTO THE APP, AND SO IS ITS NAME',
			'operation.layout.resetOptions' => 'RESTORE DEFAULTS',
			'operation.layout.removePane' => 'REMOVE',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'RESTORE ${panel} TO ITS DEFAULTS?',
			'operation.layout.resetPaneConfirmBody' => 'ITS TITLE, HEADER AND SIZE GO BACK TO THE DEFAULTS. THE REST OF THE LAYOUT STAYS AS IT IS.',
			'operation.layout.resetViewConfirm' => 'RESTORE THIS VIEW TO ITS DEFAULT LAYOUT?',
			'operation.layout.resetViewConfirmBody' => 'THE PANELS GO BACK TO THEIR DEFAULT ARRANGEMENT, AND THE VIEW\'S OPTIONS AND EVERY PANEL\'S GO BACK TO THE DEFAULTS.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} LAYOUT SETTINGS',
			'operation.layout.paneTitle' => 'TITLE',
			'operation.layout.paneShowHeader' => 'SHOW HEADER',
			'operation.layout.paneShowHeaderTabset' => 'ALWAYS SHOWN WHILE THIS PANE SHARES A GROUP — THE HEADER IS HOW THE OTHERS ARE REACHED',
			'operation.layout.paneInherit' => 'SAME AS THE APP',
			'operation.layout.searchHint' => 'SEARCH PANELS',
			'operation.layout.noPanelsMatch' => 'NO PANEL MATCHES YOUR SEARCH.',
			'operation.layout.nothingToAdd' => 'THIS VIEW ALREADY HAS ALL POSSIBLE PANELS',
			'operation.layout.addPanel' => ({required Object panel}) => 'ADD ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'PREVIEW ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'EXTENSION "${name}" IS MISSING',
			'operation.layout.missingExtensionEnable' => 'ENABLE',
			'operation.layout.missingExtensionInstall' => 'INSTALL…',
			'operation.layout.missingExtensionWontRun' => 'THIS VERSION WON’T RUN. UPDATE IT IN SETTINGS › EXTENSIONS.',
			'operation.layout.missingExtensionUnavailable' => 'NOT AVAILABLE IN THIS APP',
			'operation.layout.missingExtensionNotInCatalog' => 'NOT IN THE CATALOG',
			'operation.layout.missingExtensionCatalogUnreachable' => 'COULDN’T REACH THE CATALOG. TRY AGAIN',
			'operation.layout.missingExtensionFailed' => 'THAT DIDN’T WORK. TRY AGAIN',
			'operation.layout.previewUnavailable' => 'THIS PANEL\'S PREVIEW IMAGE COULD NOT BE SHOWN.',
			'operation.layout.nestedPaneTitle' => 'MORE',
			'operation.layout.layouts.defaultName' => 'DEFAULT',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'LAYOUT ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'LAYOUT: ${name}',
			'operation.layout.layouts.menuNew' => 'NEW…',
			'operation.layout.layouts.menuExport' => 'EXPORT…',
			'operation.layout.layouts.menuImport' => 'IMPORT…',
			'operation.layout.layouts.menuTitle' => 'LAYOUTS',
			'operation.layout.layouts.newTitle' => 'NEW LAYOUT',
			'operation.layout.layouts.editTitle' => 'EDIT LAYOUT',
			'operation.layout.layouts.edit' => 'EDIT',
			'operation.layout.layouts.duplicateCurrent' => 'DUPLICATE CURRENT LAYOUT',
			'operation.layout.layouts.startFromDefault' => 'START FROM THE DEFAULT LAYOUT',
			'operation.layout.layouts.nameLabel' => 'NAME',
			'operation.layout.layouts.descriptionLabel' => 'DESCRIPTION',
			'operation.layout.layouts.create' => 'CREATE',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'SAVE CHANGES TO "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'THIS LAYOUT HAS CHANGES YOU HAVEN’T SAVED.',
			'operation.layout.layouts.discard' => 'DISCARD',
			'operation.layout.layouts.deleteTitle' => 'DELETE THIS LAYOUT?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'ARE YOU SURE YOU WANT TO DELETE THIS "${name}" LAYOUT?',
			'operation.layout.layouts.exportTitle' => 'EXPORT LAYOUT',
			'operation.layout.layouts.exportPick' => 'PANELS TO EXPORT',
			'operation.layout.layouts.tabSet' => 'TAB SET',
			'operation.layout.layouts.exportAction' => 'EXPORT',
			'operation.layout.layouts.exported' => ({required Object location}) => 'LAYOUT SAVED TO ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'COULDN\'T EXPORT THE LAYOUT: ${error}',
			'operation.layout.layouts.importTitle' => 'IMPORT LAYOUT',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'MADE FOR THE ${view} VIEW: PANELS ONLY THAT VIEW HAS ARE LEFT OUT.',
			'operation.layout.layouts.viewHome' => 'HOME',
			'operation.layout.layouts.viewOperation' => 'OPERATION',
			'operation.layout.layouts.viewLogs' => 'LOGS',
			'operation.layout.layouts.viewChase' => 'CHASING',
			'operation.layout.layouts.importAsNew' => 'AS A NEW LAYOUT',
			'operation.layout.layouts.importReplace' => 'IN PLACE OF THIS LAYOUT',
			'operation.layout.layouts.importAdd' => 'ADDED TO THIS LAYOUT',
			'operation.layout.layouts.importAddHint' => 'THE PANELS ARRIVE IN A NEW COLUMN ON THE RIGHT.',
			'operation.layout.layouts.importPick' => 'PANELS TO IMPORT',
			'operation.layout.layouts.importReplaceSettings' => 'REPLACE THE SETTINGS OF PANELS ALREADY SET UP HERE',
			'operation.layout.layouts.importAction' => 'IMPORT',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} ISN\'T A LAYOUT THIS APP CAN READ: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'THE TEXT ISN’T VALID YAML (LINE ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'IT ISN’T A HAM2K LAYOUT FILE',
			'operation.layout.layouts.problemNewerVersion' => 'IT WAS WRITTEN BY A NEWER VERSION OF THE APP',
			'operation.layout.layouts.problemNoArrangement' => 'IT HOLDS NO ARRANGEMENT',
			'operation.layout.layouts.problemMalformed' => 'PART OF IT DOESN’T FOLLOW THE LAYOUT FORMAT',
			'operation.layout.layouts.problemTooLarge' => 'IT IS TOO LARGE',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'COULDN\'T OPEN THE FILE: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'COULDN\'T IMPORT THE LAYOUT: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'COULDN\'T COPY THE LAYOUT: ${error}',
			'operation.layout.layouts.importNothing' => 'NO PANEL PICKED, SO NOTHING WAS IMPORTED.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'LEFT OUT: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'KEPT ${panels}: THE SMALL-SCREEN ARRANGEMENT CAN’T DO WITHOUT IT.',
			'operation.layout.layouts.notOffered' => 'NOT AVAILABLE IN THIS VIEW',
			'operation.layout.layouts.alreadyPlaced' => 'ALREADY IN THIS LAYOUT',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'NEEDS ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'LAYOUT NAMES COULDN’T BE READ',
			'operation.layout.layouts.listRecoveredBody' => 'THIS VIEW’S LIST OF LAYOUTS COULD NOT BE READ. EVERY LAYOUT IS STILL HERE, NUMBERED IN PLACE OF ITS NAME.',
			'operation.layout.editLayout' => 'EDIT LAYOUT',
			'operation.layout.saveLayout' => 'SAVE LAYOUT',
			'operation.layout.revertLayout' => 'DISCARD LAYOUT CHANGES',
			'operation.layout.done' => 'DONE',
			'operation.layout.layoutUnreadableTitle' => 'LAYOUT COULDN\'T BE READ',
			'operation.layout.layoutUnreadableBody' => 'YOUR SAVED LAYOUT COULD NOT BE READ, SO THE DEFAULT ARRANGEMENT IS SHOWING INSTEAD. IT WON\'T BE SAVED OVER YOUR ORIGINAL UNTIL YOU CHOOSE TO KEEP IT.',
			'operation.layout.layoutUnreadableAction' => 'USE THIS LAYOUT',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} COULD NOT BE DISPLAYED',
			'operation.layout.panelRenderRetry' => 'TRY AGAIN',
			'operation.layout.panelActionFailed' => 'THAT PANEL ACTION FAILED. TRY AGAIN.',
			'operation.layout.panels.loggingDescription' => 'THE LOG AND THE ENTRY FIELDS',
			'operation.layout.panels.infoDescription' => 'WHAT WE KNOW ABOUT THE STATION BEING WORKED',
			'operation.layout.panels.spotsDescription' => 'SPOTS FROM THE CLUSTERS AND ACTIVITY PROGRAMS',
			'operation.layout.panels.mapDescription' => 'WHERE THE CONTACTS ARE',
			'operation.layout.panels.summariesDescription' => 'THE OPERATION\'S STATS AND SCORES, IN THE SECTIONS AND ORDER YOU PICK',
			'operation.layout.panels.summariesSections' => 'SECTIONS AND ORDER',
			'operation.layout.panels.summariesDays' => 'EACH DAY',
			'operation.layout.panels.summariesReset' => 'SHOW ALL',
			'operation.layout.panels.summariesAllHidden' => 'EVERY SECTION IS HIDDEN. PICK THE ONES TO SHOW IN THIS PANEL\'S SETTINGS.',
			'operation.layout.panels.clockDescription' => 'A CLOCK FACE, IN ANY TIME ZONE',
			'operation.layout.panels.clockFace' => 'FACE',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'ANALOG',
			'operation.layout.panels.clockZone' => 'TIME ZONE',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'THIS DEVICE',
			'operation.layout.panels.clockShowSeconds' => 'SHOW SECONDS',
			'operation.layout.panels.weatherDescription' => 'CONDITIONS NOW AND FOR THE NEXT EIGHT HOURS, WHERE YOU\'RE OPERATING',
			'operation.layout.panels.weatherUseOperationLocation' => 'USE THE OPERATION\'S LOCATION',
			'operation.layout.panels.weatherLocation' => 'LOCATION',
			'operation.layout.panels.weatherLocationDescription' => 'A GRID SQUARE (FN31PR) OR LAT,LON. IGNORED WHILE \'USE THE OPERATION\'S LOCATION\' IS CHECKED.',
			'operation.layout.panels.weatherNoLocation' => 'NO LOCATION SET. GIVE THIS PANEL A LOCATION IN ITS SETTINGS, OR PLACE IT INSIDE AN OPERATION THAT HAS ONE.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'COULDN\'T READ THE LOCATION ${location}. USE A GRID SQUARE LIKE FN31PR, OR 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'COULDN\'T REACH OPEN-METEO — NO NETWORK? WILL TRY AGAIN SHORTLY.',
			'operation.layout.panels.weatherUnreadable' => 'OPEN-METEO RESPONDED, BUT NOT WITH ANYTHING READABLE. WILL TRY AGAIN SHORTLY.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'GUSTS ${speed}',
			'operation.layout.panels.panelAgeNow' => 'JUST NOW',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} MIN AGO', other: '${count} MIN AGO', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} HR AGO', other: '${count} HRS AGO', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'UNKNOWN',
			'operation.layout.panels.weatherConditions.sunny' => 'SUNNY',
			'operation.layout.panels.weatherConditions.clear' => 'CLEAR',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'MAINLY SUNNY',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'MAINLY CLEAR',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'PARTLY CLOUDY',
			'operation.layout.panels.weatherConditions.cloudy' => 'CLOUDY',
			'operation.layout.panels.weatherConditions.foggy' => 'FOGGY',
			'operation.layout.panels.weatherConditions.rimeFog' => 'RIME FOG',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'LIGHT DRIZZLE',
			'operation.layout.panels.weatherConditions.drizzle' => 'DRIZZLE',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'HEAVY DRIZZLE',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'LIGHT FREEZING DRIZZLE',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'FREEZING DRIZZLE',
			'operation.layout.panels.weatherConditions.lightRain' => 'LIGHT RAIN',
			'operation.layout.panels.weatherConditions.rain' => 'RAIN',
			'operation.layout.panels.weatherConditions.heavyRain' => 'HEAVY RAIN',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'LIGHT FREEZING RAIN',
			'operation.layout.panels.weatherConditions.freezingRain' => 'FREEZING RAIN',
			'operation.layout.panels.weatherConditions.lightSnow' => 'LIGHT SNOW',
			'operation.layout.panels.weatherConditions.snow' => 'SNOW',
			'operation.layout.panels.weatherConditions.heavySnow' => 'HEAVY SNOW',
			'operation.layout.panels.weatherConditions.snowGrains' => 'SNOW GRAINS',
			'operation.layout.panels.weatherConditions.lightShowers' => 'LIGHT SHOWERS',
			'operation.layout.panels.weatherConditions.showers' => 'SHOWERS',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'HEAVY SHOWERS',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'LIGHT SNOW SHOWERS',
			'operation.layout.panels.weatherConditions.snowShowers' => 'SNOW SHOWERS',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'THUNDERSTORM',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'LIGHT THUNDERSTORMS WITH HAIL',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'THUNDERSTORM WITH HAIL',
			'operation.layout.panels.websiteDescription' => 'A WEB PAGE OF YOUR CHOOSING, IN A PANE',
			'operation.layout.panels.websiteUrl' => 'ADDRESS',
			'operation.layout.panels.websiteRefresh' => 'REFRESH',
			'operation.layout.panels.websiteRefreshNever' => 'NEVER',
			'operation.layout.panels.websiteRefresh1' => 'EVERY MINUTE',
			'operation.layout.panels.websiteRefresh5' => 'EVERY 5 MINUTES',
			'operation.layout.panels.websiteRefresh15' => 'EVERY 15 MINUTES',
			'operation.layout.panels.websiteTitle' => 'PANEL NAME',
			'operation.layout.panels.websiteRefreshNow' => 'REFRESH NOW',
			'operation.layout.panels.websiteNoUrl' => 'NO ADDRESS YET. OPEN THIS PANEL’S SETTINGS TO CHOOSE A PAGE.',
			'operation.layout.panels.websiteBadUrl' => 'THAT DOESN’T LOOK LIKE A WEB ADDRESS. IT NEEDS TO START WITH HTTPS://',
			'operation.layout.panels.websiteNotHttps' => 'ONLY HTTPS:// ADDRESSES CAN BE SHOWN HERE.',
			'operation.layout.panels.websiteUnsupported' => 'WEB PAGES CAN’T BE SHOWN IN A PANEL ON THIS SYSTEM.',
			'operation.layout.panels.websiteOpenExternally' => 'OPEN IN BROWSER',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'COULDN’T LOAD THE PAGE: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'A SCREEN, APP OR WINDOW SHARED BY ANOTHER OF YOUR DEVICES.',
			'operation.layout.panels.remoteScreenTarget' => 'SCREEN',
			'operation.layout.panels.remoteScreenChoose' => 'CHOOSE A SCREEN…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'SHARED SCREENS',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'NONE OF YOUR DEVICES IS SHARING A SCREEN. TURN SHARE SCREENS AND WINDOWS ON UNDER SETTINGS → PEER DEVICES, ON THE DEVICE YOU WANT TO SEE.',
			'operation.layout.panels.remoteScreenUnset' => 'NO SCREEN CHOSEN. OPEN THIS PANEL\'S SETTINGS TO PICK ONE YOUR OTHER DEVICES ARE SHARING.',
			'operation.layout.panels.remoteScreenConnecting' => 'CONNECTING…',
			'operation.layout.panels.remoteScreenPeerAway' => 'THAT DEVICE ISN\'T CONNECTED RIGHT NOW.',
			'operation.layout.panels.remoteScreenNotOffered' => 'THAT DEVICE STOPPED SHARING THIS SCREEN.',
			'operation.layout.panels.remoteScreenNoListener' => 'THAT DEVICE CAN\'T ACCEPT CONNECTIONS — CHECK ITS FIREWALL.',
			'operation.layout.panels.remoteScreenNoLan' => 'SCREENS ARE ONLY SHARED OVER THE LOCAL NETWORK, NOT BLUETOOTH.',
			'operation.layout.panels.remoteScreenRefused' => 'THAT DEVICE WOULDN\'T SHARE THIS SCREEN.',
			'operation.layout.panels.remoteScreenSettings' => 'PANEL SETTINGS',
			'operation.layout.panels.remoteScreenAdjust' => 'ADJUST VIEW',
			'operation.layout.panels.remoteScreenDetail' => 'DETAIL',
			'operation.layout.panels.remoteScreenDetailStandard' => 'STANDARD',
			'operation.layout.panels.remoteScreenDetailHigh' => 'HIGH',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'MAXIMUM',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'ZOOM IN',
			'operation.layout.panels.remoteScreenZoomOut' => 'ZOOM OUT',
			'operation.layout.panels.remoteScreenStopped' => 'THAT SCREEN OR WINDOW IS NO LONGER BEING SHOWN.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'THAT DEVICE COULDN\'T CAPTURE THAT SCREEN — IT MAY NEED SCREEN RECORDING PERMISSION.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'THAT DEVICE DIDN\'T RESPOND. IT MAY NOT HAVE SCREEN SHARING TURNED ON.',
			'operation.layout.panels.remoteScreenNoMedia' => 'COULDN\'T OPEN A CONNECTION FOR THE PICTURE. CHECK THE FIREWALL ON THIS DEVICE.',
			'operation.layout.panels.solarDescription' => 'SOLAR AND GEOMAGNETIC CONDITIONS, WITH BAND-BY-BAND PROPAGATION',
			'operation.layout.panels.solarUnreachable' => 'COULDN\'T REACH HAMQSL.COM — NO NETWORK? WILL TRY AGAIN SHORTLY.',
			'operation.layout.panels.solarUnreadable' => 'HAMQSL.COM RESPONDED, BUT NOT WITH A READING WE COULD USE. WILL TRY AGAIN SHORTLY.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'KP',
			'operation.layout.panels.solarBandDay' => 'DAY',
			'operation.layout.panels.solarBandNight' => 'NIGHT',
			'operation.layout.panels.solarBandGood' => 'GOOD',
			'operation.layout.panels.solarBandFair' => 'FAIR',
			'operation.layout.panels.solarBandPoor' => 'POOR',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'SOURCES: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'THE CONNECTION IS STRUGGLING — SKIPPING FRAMES.',
			'operation.layout.panels.remoteScreenStalled' => 'FRAMES STOPPED GETTING THROUGH — THIS CONNECTION MAY BE TOO SLOW.',
			'operation.layout.panels.radioDescription' => 'A RADIO\'S FRONT PANEL — FREQUENCY, MODE AND POWER, UNDER CAT CONTROL',
			'operation.layout.panels.radioStyle' => 'STYLE',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'MODERN',
			'operation.layout.panels.radioRadio' => 'RADIO',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — NO RADIO DESIGNATED',
			'operation.layout.panels.radioNoRadio' => 'NO RADIO TO SHOW. PICK ONE IN THIS PANEL\'S SETTINGS, OR ADD ONE UNDER STATION CONFIGURATION.',
			'operation.layout.panels.radioNotConfigured' => 'THIS RADIO IS NOT CONFIGURED YET. CHOOSE ITS PORT OR ADDRESS UNDER STATION CONFIGURATION.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'RADIO NOT CONNECTED',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'CONNECT THIS RADIO',
			'operation.layout.panels.radioDisconnect' => 'DISCONNECT THIS RADIO',
			'operation.layout.panels.radioStale' => 'NO DATA',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'HIGH SWR',
			'operation.layout.htmlPanelUnsupported' => 'THIS PANEL NEEDS A WEB VIEW, WHICH THIS PLATFORM DOES NOT PROVIDE',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'THIS PANEL NEEDS A SANDBOX THE WEB VERSION CANNOT PROVIDE',
			'operation.export.title' => 'OPERATION EXPORTS',
			'operation.export.syncedOperation' => 'OPERATION IS SYNCED',
			'operation.export.unsyncedOperation' => 'OPERATION HAS UNSYNCED CHANGES',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} QSO IN THIS OPERATION', other: '${count} QSOS IN THIS OPERATION', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'ALL ${total} QSOS ARE SYNCED',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} OF ${total} QSOS PENDING SYNC',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} EVENT MARKERS SYNCED',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} OF ${total} EVENT MARKERS PENDING',
			'operation.export.loading' => 'LOADING EXPORT OPTIONS…',
			'operation.export.noOptions' => 'NO EXPORT FORMATS AVAILABLE (EXTENSION RUNTIME STILL STARTING?)',
			'operation.export.nothingLogged' => 'NOTHING TO EXPORT YET — THIS OPERATION HAS NO QSOS.',
			'operation.export.share' => 'SHARE',
			'operation.export.nothingSelected' => 'NOTHING SELECTED',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SAVE ${count} FILE', other: 'SAVE ${count} FILES', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SHARE ${count} FILE', other: 'SHARE ${count} FILES', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'EXPORT ${count} FILE', other: 'EXPORT ${count} FILES', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'DOWNLOAD ${count} FILE', other: 'DOWNLOAD ${count} FILES', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SAVE COMBINED ${count} FILE', other: 'SAVE COMBINED ${count} FILES', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SHARE COMBINED ${count} FILE', other: 'SHARE COMBINED ${count} FILES', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'EXPORT COMBINED ${count} FILE', other: 'EXPORT COMBINED ${count} FILES', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'DOWNLOAD COMBINED ${count} FILE', other: 'DOWNLOAD COMBINED ${count} FILES', ), 
			'operation.export.saveOne' => ({required Object name}) => 'SAVE ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'SHARE ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'EXPORT ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'DOWNLOAD ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'STASH ${count} FILE', other: 'STASH ${count} FILES', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'STASH COMBINED ${count} FILE', other: 'STASH COMBINED ${count} FILES', ), 
			'operation.export.settingsButton' => 'EXPORT SETTINGS',
			'operation.export.settingsTitle' => 'EXPORT SETTINGS',
			'operation.export.compactFileNames.title' => 'USE COMPACT FILE NAMES',
			'operation.export.compactFileNames.descriptionOn' => 'SHORT NAMES BUILT FOR UPLOADERS, LIKE N0CALL@US-1234-20260727.ADI',
			'operation.export.compactFileNames.descriptionOff' => 'READABLE NAMES, LIKE 2026-07-27 N0CALL AT US-1234.ADI',
			'operation.export.includePrivateData.title' => 'INCLUDE PRIVATE INFO',
			'operation.export.includePrivateData.descriptionOn' => 'NAMES, ADDRESSES, EMAILS, GRIDSQUARES AND NOTES ARE INCLUDED',
			'operation.export.includePrivateData.descriptionOff' => 'NAMES, ADDRESSES, EMAILS, GRIDSQUARES AND NOTES ARE LEFT OUT',
			'operation.export.includePrivateData.note' => 'THE FULL ADIF EXPORT ALWAYS INCLUDES EVERYTHING',
			'operation.export.resultTitle' => 'EXPORT COMPLETE',
			'operation.export.resultFailedTitle' => 'EXPORT FAILED',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'EXPORTED ${count} FILE TO ${path}', other: 'EXPORTED ${count} FILES TO ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'EXPORTED ${count} FILE: ${path}', other: 'EXPORTED ${count} FILES: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SHARED ${count} FILE', other: 'SHARED ${count} FILES', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'DOWNLOADED ${count} FILE', other: 'DOWNLOADED ${count} FILES', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'EXPORT FAILED: ${error}',
			'operation.export.stash.needsEmailTitle' => 'ADD AN EMAIL ADDRESS FIRST',
			'operation.export.stash.needsEmailBody' => 'HAM2K’S FILE STASH SENDS YOUR FILES TO THE EMAIL ADDRESS ON YOUR LOFI ACCOUNT, AND YOU SIGN IN WITH IT AT STASH.HAM2K.NET. YOUR ACCOUNT DOESN’T HAVE A CONFIRMED ONE YET — ADD IT IN SETTINGS › CLOUD SYNC.',
			'operation.export.stash.openSyncSettings' => 'OPEN CLOUD SYNC',
			'operation.export.stash.replaceTitle' => 'RECENT STASH WILL BE REPLACED',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'YOU SENT “${name}” LESS THAN 6 HOURS AGO AND IT HASN’T BEEN DOWNLOADED YET. FREE ACCOUNTS KEEP ONE STASH AT A TIME, SO SENDING NOW REPLACES IT.',
			'operation.export.stash.replaceConfirm' => 'SEND ANYWAY',
			'operation.export.stash.failedTitle' => 'COULDN’T SEND TO HAM2K’S FILE STASH',
			'operation.export.stash.sentTitle' => 'SENT TO HAM2K’S FILE STASH',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'YOU CAN RETRIEVE THIS FILE BY VISITING **[STASH.HAM2K.NET](https://stash.ham2k.net)** ON ANY BROWSER.', other: 'YOU CAN RETRIEVE THESE FILES BY VISITING **[STASH.HAM2K.NET](https://stash.ham2k.net)** ON ANY BROWSER.', ), 
			'operation.export.stash.mayHaveArrived' => 'NO ANSWER FROM THE STASH — THE FILE MAY HAVE ARRIVED ANYWAY. CHECK STASH.HAM2K.NET BEFORE SENDING AGAIN',
			'operation.export.stash.notSent' => 'NOT SENT',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'THIS FILE DIDN’T ARRIVE:', other: 'THESE ${count} FILES DIDN’T ARRIVE:', ), 
			'operation.export.stash.emailOffer' => 'OR FOR YOUR CONVENIENCE, WE CAN SEND YOU AN EMAIL WITH A DIRECT LINK.',
			'operation.export.stash.emailMe' => 'EMAIL ME A LINK',
			'operation.export.stash.emailSent' => 'WE’VE EMAILED YOU A DOWNLOAD LINK.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'COULDN’T SEND THE EMAIL: ${error}',
			'operation.export.stash.freeTier' => 'FREE ACCOUNTS CAN ONLY KEEP ONE STASH AT A TIME. SUBSCRIBERS CAN KEEP AS MANY AS THEY WANT.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SENT ${count} FILE TO HAM2K’S FILE STASH (STASH.HAM2K.NET)', other: 'SENT ${count} FILES TO HAM2K’S FILE STASH (STASH.HAM2K.NET)', ), 
			'operation.spots.empty' => 'NO SPOTS MATCH YOUR FILTERS',
			'operation.spots.error' => ({required Object error}) => 'FAILED TO LOAD SPOTS: ${error}',
			'operation.spots.unknownBand' => 'OTHER',
			'operation.spots.auto' => 'AUTOMATIC',
			'operation.spots.autoValue' => ({required Object value}) => 'AUTOMATIC (CURRENTLY ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (AUTO)',
			'operation.spots.any' => 'ANY',
			'operation.spots.allBands' => 'ALL BANDS',
			'operation.spots.allModes' => 'ALL MODES',
			'operation.spots.phoneAndCw' => 'PHONE & CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} SPOT', other: '${count} SPOTS', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'SHOWING ${count} OF ${total} SPOTS',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} MINUTES',
			'operation.spots.callsOfNote' => 'CALLS OF NOTE',
			'operation.spots.yourSpots' => 'YOUR SPOTS',
			'operation.spots.allSpots' => 'ALL SPOTS',
			'operation.spots.continents.af' => 'AFRICA',
			'operation.spots.continents.as' => 'ASIA',
			'operation.spots.continents.eu' => 'EUROPE',
			'operation.spots.continents.na' => 'NORTH AMERICA',
			'operation.spots.continents.oc' => 'OCEANIA',
			'operation.spots.continents.sa' => 'SOUTH AMERICA',
			'operation.spots.continents.an' => 'ANTARCTICA',
			'operation.spots.filters.title' => 'FILTER SPOTS',
			'operation.spots.filters.band' => 'BAND',
			'operation.spots.filters.mode' => 'MODE',
			'operation.spots.filters.age' => 'AGE',
			'operation.spots.filters.sources' => 'SOURCES',
			'operation.spots.filters.continent' => 'CONTINENT',
			'operation.spots.filters.sorting' => 'SORTING',
			'operation.spots.filters.sortByTime' => 'BY SPOT TIME',
			'operation.spots.filters.sortByFrequency' => 'BY FREQUENCY',
			'operation.spots.filters.sortByWanted' => 'MOST WANTED',
			'operation.spots.filters.groupByBand' => 'GROUP BY BAND',
			'operation.spots.filters.groupCallsWithNotes' => 'GROUP CALLS WITH NOTES',
			'operation.spots.filters.alertingOnly' => 'ONLY SPOTS WITH ALERTS',
			'operation.spots.filters.sourceNoReply' => 'NO REPLY',
			'operation.spots.filters.sourceError' => 'ERROR',
			'operation.spots.unavailableTitle' => 'SPOTS UNAVAILABLE',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} DID NOT RESPOND.',
			'operation.spots.failedTitle' => 'SPOT SOURCE ERROR',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} RETURNED AN ERROR.',
			'operation.spots.slideLogIt' => 'LOG IT',
			'operation.spots.slideIgnore' => 'IGNORE',
			'operation.spots.slideRestore' => 'RESTORE',
			'operation.spots.logConflict.title' => 'LOGGING PANEL IS BUSY',
			'operation.spots.logConflict.editingBody' => 'YOU\'RE EDITING A LOGGED CONTACT. LOG THIS SPOT INSTEAD, OR GO BACK AND FINISH THE EDIT?',
			'operation.spots.logConflict.composingBody' => 'YOU\'VE STARTED ENTERING A CONTACT. LOG THIS SPOT INSTEAD, OR GO BACK AND FINISH WHAT YOU WERE TYPING?',
			'operation.spots.logConflict.goBack' => 'GO BACK',
			'operation.spots.logConflict.clearAndLog' => 'CLEAR AND LOG SPOT',
			'operation.import.title' => 'IMPORT DATA INTO OPERATION',
			'operation.import.importAdifAction' => 'IMPORT QSOS FROM ADIF',
			'operation.import.settingsButton' => 'LISTEN SETTINGS',
			'operation.import.settingsTitle' => 'LISTEN FOR OTHER APPS',
			'operation.import.protocolAddressLabel' => 'ADDRESS',
			'operation.import.protocolPortLabel' => 'PORT',
			'operation.import.protocolPortInvalid' => 'ENTER A PORT BETWEEN 1 AND 65535',
			'operation.import.protocolAddressInvalid' => 'ENTER A VALID IP ADDRESS (E.G. 127.0.0.1 OR 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'RECEIVING DATA',
			'operation.import.protocolStatusNoData' => 'NO DATA RECEIVED RECENTLY',
			'operation.import.protocolBindError' => ({required Object error}) => 'COULDN\'T START LISTENING: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'INCOMING QSOS COULD NOT BE SAVED AND ARE BEING RETRIED: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ CONTACT BROADCAST',
			'operation.import.n1mmAddressValue' => 'ANY (BROADCAST)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP SERVER',
			'operation.import.helpN1mmSetup' => 'CONFIG → CONFIGURE PORTS, MODE CONTROL… → BROADCAST DATA TAB → CHECK "ENABLE BROADCASTS" FOR CONTACT INFO. SET IP ADDRESS TO 127.0.0.1 IF RUNNING ON THIS SAME COMPUTER, OR 255.255.255.255 TO BROADCAST ON THE CURRENT LOCAL NETWORK.',
			'operation.import.helpWsjtxSetup' => 'FILE → SETTINGS → REPORTING TAB → UDP SERVER SECTION → CHECK "ACCEPT UDP REQUESTS". SET UDP SERVER TO 127.0.0.1 IF RUNNING ON THIS SAME COMPUTER, OR A MULTICAST ADDRESS SUCH AS 239.239.0.2, AND USE THE SAME ADDRESS IN THE CONFIGURATION ABOVE IN THIS APP.',
			'operation.import.listenTitle' => 'LISTEN FOR QSOS FROM OTHER APPS',
			'operation.import.listenDescriptionOnN1mm' => 'LISTENING FOR N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'LISTENING FOR WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'LISTENING FOR N1MM+ AND WSJT-X',
			'operation.import.listenDescriptionOff' => 'OFF',
			'operation.import.addToOperationTitle' => 'ADD TO THIS OPERATION',
			'operation.import.addToOperationDescriptionOn' => 'CAPTURED QSOS ARE ADDED TO THIS OPERATION AS THEY ARRIVE',
			'operation.import.addToOperationDescriptionOff' => 'CAPTURED QSOS ARE HELD UNTIL YOU TURN THIS ON',
			'operation.import.pendingSectionTitle' => 'CAPTURED QSOS',
			'operation.import.pendingEmpty' => 'NOTHING CAPTURED YET',
			'operation.import.stationMismatch' => ({required Object call}) => 'LOGGED AS ${call}, NOT THIS OPERATION\'S STATION',
			'operation.import.discardAction' => 'DISCARD',
			'operation.import.gapDialogTitle' => 'INCLUDE EARLIER CAPTURES?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} MORE QSOS WERE CAPTURED EARLIER, BEFORE A GAP IN THE DATA. INCLUDE THEM TOO?',
			'operation.import.gapDialogRecentOnly' => 'JUST THE RECENT ONES',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'INCLUDE ALL ${count}',
			'map.outlineIssue.link' => 'ISSUES?',
			'map.outlineIssue.title' => 'REPORT AN OUTLINE ISSUE',
			'map.outlineIssue.reference' => 'WHICH OUTLINE',
			'map.outlineIssue.severity' => 'HOW BAD IS IT?',
			'map.outlineIssue.minor' => 'MINOR NIT',
			'map.outlineIssue.major' => 'BIG DEAL',
			'map.outlineIssue.explanation' => 'WHAT\'S WRONG WITH IT?',
			'map.outlineIssue.explanationHint' => 'WHAT THE OUTLINE GETS WRONG, AND WHERE',
			'map.outlineIssue.send' => 'SEND',
			'map.outlineIssue.sending' => 'SENDING YOUR REPORT — THANKS',
			'map.outlineIssue.copy' => 'COPY REPORT',
			'map.outlineIssue.notSent' => 'COULDN\'T SEND THE REPORT',
			'map.outlineIssue.copied' => 'REPORT COPIED',
			'map.outlineIssue.notCopied' => 'COULDN\'T COPY THE REPORT',
			'map.outlinesDisclaimer' => 'OUTLINES ARE FOR REFERENCE ONLY. DO YOUR OWN RESEARCH!',
			'map.outlinesCredit' => ({required Object sources}) => 'OUTLINES: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'BOUNDARIES: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'FACILITIES: ${sources}',
			'map.fullCredits' => 'FULL DATASET CREDITS',
			'map.fewerCredits' => 'FEWER CREDITS',
			'map.emptyState' => 'NO QSO LOCATIONS YET.\nQSOS WITH A GRID SQUARE, STATE, OR COUNTRY WILL SHOW UP HERE.',
			'map.unavailable' => 'THE MAP ISN\'T AVAILABLE RIGHT NOW.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} KM',
			'map.distanceMiles' => ({required Object distance}) => '${distance} MI',
			'map.flat' => 'FLAT',
			'map.globe' => 'GLOBE',
			'map.zoomIn' => 'ZOOM IN',
			'map.zoomOut' => 'ZOOM OUT',
			'map.resetNorth' => 'RESET TO NORTH UP',
			'map.postcard.button' => 'OPERATION POSTCARD',
			'map.postcard.title' => ({required Object title}) => 'POSTCARD FOR ${title}',
			'map.postcard.portrait' => 'PORTRAIT',
			'map.postcard.landscape' => 'LANDSCAPE',
			'map.postcard.square' => 'SQUARE',
			'map.postcard.save' => 'SAVE…',
			'map.postcard.download' => 'DOWNLOAD',
			'map.postcard.share' => 'SHARE',
			'map.postcard.copy' => 'COPY',
			'map.postcard.copied' => 'COPIED TO THE CLIPBOARD',
			'map.postcard.saved' => ({required Object path}) => 'SAVED TO ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'DOWNLOADED ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'SAVED ${count} IMAGES TO ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'SAVED ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} HAD ALREADY BEEN SAVED',
			'map.postcard.downloadedMany' => ({required Object count}) => 'DOWNLOADING ${count} IMAGES — ALLOW THEM IF THE BROWSER ASKS',
			'map.postcard.mapLeftOut' => 'THE MAP DIDN\'T LOAD, SO IT WAS LEFT OUT',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — THE MAP DIDN\'T LOAD, SO IT WAS LEFT OUT',
			'map.postcard.continued' => ({required Object title}) => '${title} (CONTINUED)',
			'map.postcard.previousPage' => 'PREVIOUS PAGE',
			'map.postcard.nextPage' => 'NEXT PAGE',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'PAGE ${page} OF ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} Q', other: '${count} QS', ), 
			'map.postcard.options' => 'POSTCARD OPTIONS',
			'map.postcard.bandLegend' => 'SHOW BAND LEGEND',
			'map.postcard.grayline' => 'SHOW GRAYLINE',
			'map.postcard.sectionsAndOrder' => 'SUMMARY SECTIONS AND ORDERING',
			'map.postcard.sectionDays' => 'EACH DAY',
			'map.postcard.reset' => 'RESET',
			'map.postcard.failed' => ({required Object error}) => 'COULD NOT MAKE THE POSTCARD: ${error}',
			'map.postcard.mapNotReady' => 'THE MAP DIDN\'T FINISH LOADING. CHECK THE CONNECTION AND TRY AGAIN.',
			'map.postcard.saveFailed' => ({required Object error}) => 'COULD NOT SAVE THE POSTCARD: ${error}',
			'map.postcard.copyFailed' => 'THE CLIPBOARD DIDN\'T TAKE THE IMAGE. TRY AGAIN.',
			'map.postcard.shareFailed' => 'COULD NOT SHARE THE POSTCARD. TRY AGAIN.',
			'map.postcard.fileName' => 'POSTCARD',
			'mapsView.title' => 'MAPS',
			'mapsView.searchHint' => 'SEARCH PARKS, SUMMITS AND MORE',
			'mapsView.activities' => 'ACTIVITIES',
			'mapsView.layers' => 'LAYERS',
			'mapsView.baseMap' => 'BASE MAP',
			'mapsView.satellite' => 'SATELLITE (ESRI)',
			'mapsView.facilities' => 'PARK FACILITIES',
			'mapsView.boundaries' => 'BOUNDARIES',
			'mapsView.currentLocation' => 'CURRENT LOCATION',
			'mapsView.noMatches' => ({required Object text}) => 'NOTHING MATCHES “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} REFERENCE AT ${where}', other: '${count} REFERENCES AT ${where}', ), 
			'mapsView.startOperation' => 'START AN OPERATION WITH THESE REFERENCES',
			'activitiesView.title' => 'ACTIVITIES',
			'activitiesView.activitiesCountZero' => 'NO ACTIVITIES SELECTED',
			'activitiesView.activitiesCountOne' => '1 ACTIVITY',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} ACTIVITIES',
			'activitiesView.empty' => 'NO ACTIVITIES YET — USE SUGGESTIONS & SEARCH BELOW TO ADD ONE',
			'activitiesView.removeActivity' => 'REMOVE',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'OPEN ${name}',
			'activitiesView.editActivity' => 'EDIT ACTIVITY',
			'activitiesView.manageExtensions' => 'MANAGE EXTENSIONS',
			'activitiesView.manage' => 'MANAGE',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'ACTIVITY TYPES: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'ACTIVITY TYPES: ${first} AND ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'ACTIVITY TYPES: ${first}, ${second} AND ${more} MORE',
			'activitiesView.reference' => 'REFERENCE',
			'activitiesView.invalidReference' => 'NOT VALID',
			'activitiesView.duplicateReference' => 'ALREADY ADDED',
			'activitiesView.searchHint' => 'SEARCH BY NAME, REFERENCE OR ANYTHING ELSE…',
			'activitiesView.noSuggestions' => 'NO MATCHES',
			'activitiesView.noSuggestionsHint' => 'SEARCH BY REFERENCE NAME OR NUMBER ABOVE',
			'activitiesView.noSuggestionsExample' => '(FOR EXAMPLE \'TRAIL\' OR \'4556\')',
			'activitiesView.allOptions' => 'ACTIVITY TYPES',
			'activitiesView.determiningLocation' => 'DETERMINING CURRENT LOCATION…\nWAITING FOR GPS FIX TO FIND NEARBY REFERENCES',
			'activitiesView.locationUnavailableTitle' => 'LOCATION DATA NOT AVAILABLE',
			'activitiesView.locationDeniedTitle' => 'LOCATION PERMISSION DENIED',
			'activitiesView.locationBlockedTitle' => 'LOCATION PERMISSION BLOCKED',
			'activitiesView.noNearbyReason' => 'CANNOT DETERMINE NEARBY REFERENCES',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'TAP ${icon} TO MANUALLY ENTER YOUR LOCATION,\nOR JUST SEARCH FOR REFERENCES BY NAME',
			'activitiesView.locationGrantAction' => 'ALLOW LOCATION ACCESS',
			'activitiesView.locationSettingsAction' => 'OPEN SETTINGS',
			'activitiesView.locationSettingsUnavailable' => 'ALLOW LOCATION ACCESS IN YOUR SYSTEM SETTINGS',
			'activitiesView.locationGrantRefused' => 'STILL NO LOCATION — THE SYSTEM SAID NO AGAIN',
			'activitiesView.searchUnavailableTitle' => 'ACTIVITY SEARCH UNAVAILABLE',
			'activitiesView.searchUnavailableReason' => 'NO ACTIVITY EXTENSION COULD RUN THE SEARCH. TRY AGAIN IN A MOMENT.',
			'activitiesView.emptySheet' => 'USE SUGGESTIONS & SEARCH BELOW TO ADD ONE',
			'activitiesView.exports' => 'EXPORTS',
			'activitiesView.exportLogs' => 'EXPORT LOGS',
			'activitiesView.tools' => 'TOOLS',
			'activitiesView.toolsTitle' => 'OPERATION TOOLS',
			'activitiesView.operationDetails' => 'OPERATION DETAILS',
			'activitiesView.share' => 'SHARE',
			'activitiesView.archive' => 'ARCHIVE',
			'activitiesView.deleteOperation' => 'DELETE OPERATION',
			'activitiesView.undeleteOperation' => 'UNDELETE OPERATION',
			'activitiesView.alreadySelected' => 'ALREADY SELECTED',
			'activitiesView.selected' => 'SELECTED',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} OF ${count}',
			'activitiesView.previousPick' => 'PREVIOUS MATCH',
			'activitiesView.nextPick' => 'NEXT MATCH',
			'activitiesView.retiredReference' => 'RETIRED',
			'activitiesView.enableExtension' => ({required Object name}) => 'ENABLE ${name}',
			'activitiesView.enableExtensionHint' => 'THIS EXTENSION MATCHES YOUR SEARCH, BUT IT IS NOT CURRENTLY ENABLED',
			'activitiesView.enableExtensionForRefHint' => 'THIS EXTENSION HANDLES ONE OF THIS OPERATION\'S REFERENCES, BUT IT IS NOT CURRENTLY ENABLED',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} IS NOT RUNNING',
			'activitiesView.extensionNotRunningHint' => 'THIS EXTENSION HAS BEEN DISABLED, OPEN EXTENSION SETTINGS FOR MORE INFO',
			'activitiesView.installExtension' => ({required Object name}) => 'INSTALL ${name}',
			'activitiesView.installExtensionHint' => 'THIS EXTENSION MATCHES YOUR SEARCH, BUT IT IS NOT INSTALLED',
			'activitiesView.onlyCatalogMatches' => 'NO MATCHES\nSOME EXTENSIONS IN THE CATALOG MIGHT HAVE RESULTS.\nINSTALL THEM IN ACTIVITY TYPES BELOW.',
			'activitiesView.setupUnavailable' => 'COULD NOT LOAD THIS ACTIVITY\'S SETUP — TRY AGAIN FROM MANAGE',
			'activitiesView.controlsUnavailableTitle' => 'ACTIVITY CONTROLS UNAVAILABLE',
			'activitiesView.controlsUnavailableReason' => 'YOUR REFERENCES ARE SAFE, BUT EDITING THEM IS UNAVAILABLE RIGHT NOW.',
			'activitiesView.controlsUnavailableRetry' => 'RETRY',
			'activitiesView.onlyDisabledMatches' => 'NO MATCHES\nSOME AVAILABLE EXTENSIONS MIGHT HAVE RESULTS.\nENABLE THEM IN ACTIVITY TYPES BELOW.',
			'activitiesView.onlyNotRunningMatches' => 'NO MATCHES\nSOME EXTENSIONS THAT MIGHT HAVE RESULTS ARE NOT RUNNING.\nSEE ACTIVITY TYPES BELOW.',
			'activitiesView.mapToggle' => 'MAP',
			'activitiesView.searchToggle' => 'SEARCH',
			'activitiesView.addToOperation' => 'ADD TO OPERATION',
			'activitiesView.addToOperationShort' => 'ADD TO OP.',
			'activitiesView.mapEmptyState' => 'NO RESULTS TO SHOW ON THE MAP',
			'activitiesView.mapEmptyStateHint' => 'SWITCH BACK TO THE LIST, OR SEARCH FOR SOMETHING ELSE',
			'activitiesView.imports' => 'IMPORTS',
			'loggingControls.timeUtc' => 'TIME (UTC)',
			'loggingControls.date' => 'DATE',
			'loggingControls.now' => 'NOW',
			'loggingControls.manualTimeSettings' => 'MANUAL TIME',
			'loggingControls.manualTimeIncrement' => 'INCREMENT PER QSO',
			'loggingControls.manualTimeIncrementNone' => 'NONE',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} MINUTE', other: '${count} MINUTES', ), 
			'loggingControls.frequency' => 'FREQUENCY',
			'loggingControls.mode' => 'MODE',
			'loggingControls.theirCall' => 'THEIR CALL',
			'loggingControls.noteField' => 'NOTE',
			'loggingControls.todoField' => 'TODO',
			'loggingControls.sent' => 'SENT',
			'loggingControls.rcvd' => 'RCVD',
			'loggingControls.more' => 'MORE',
			'loggingControls.revert' => 'REVERT',
			'loggingControls.undoDelete' => 'UNDO DELETE',
			'loggingControls.restore' => 'RESTORE',
			'loggingControls.wipe' => 'WIPE',
			'loggingControls.undo' => 'UNDO',
			'loggingControls.pendingDeleteTapWarning' => 'TAP THE TRASHCAN ONE MORE TIME TO DELETE THIS QSO',
			'loggingControls.pendingDeleteClickWarning' => 'CLICK THE TRASHCAN ONE MORE TIME TO DELETE THIS QSO',
			'loggingControls.deletedQsoWarning' => 'DELETED QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'TAP THE TRASHCAN ONE MORE TIME TO DELETE THIS ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'CLICK THE TRASHCAN ONE MORE TIME TO DELETE THIS ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'DELETED ${kind}',
			'loggingControls.timeControl' => 'TIME',
			'loggingControls.radioControl' => 'RADIO',
			'loggingControls.powerControl' => 'POWER',
			'loggingControls.notesControl' => 'NOTES',
			'loggingControls.power' => 'POWER',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'LOGGING CONTROLS',
			'loggingControls.spottingControl' => 'SPOTTING',
			'loggingControls.spottingSelfControl' => 'SELF-SPOTTING',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'SELF-SPOT AT ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'SPOT ${call} AT ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'TOO LATE TO SPOT ${call}',
			'loggingControls.spotNoFreq' => 'FIRST SET A FREQUENCY TO SPOT',
			'loggingControls.spotComment' => 'COMMENT',
			'loggingControls.spottingAutoControl' => 'AUTO RE-SPOT',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'RE-SPOT EVERY ${minutes} MIN',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'AUTO IN ${time}. STOP?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'AUTO IN ${minutes}M',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'AUTO IN ${seconds}S',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'AUTO IN ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'AUTO RE-SPOT NOT STARTED: THE SPOT DID NOT GO THROUGH',
			'loggingControls.spotAutoMoved' => 'AUTO RE-SPOT NOT STARTED: THE FREQUENCY CHANGED WHILE SPOTTING',
			'loggingControls.spotAutoStopped' => 'AUTO RE-SPOT STOPPED',
			'loggingControls.spotAutoLeftFreq' => 'AUTO RE-SPOT STOPPED: THE FREQUENCY CHANGED',
			'loggingControls.spotAutoNoFreq' => 'AUTO RE-SPOT STOPPED: THE RADIO REPORTS NO FREQUENCY',
			'loggingControls.spotBusy' => 'ANOTHER SPOT IS STILL BEING SENT',
			'loggingControls.bandOrFreqRequired' => 'SET A FREQUENCY OR BAND BEFORE LOGGING',
			'loggingControls.missingBand' => 'NO BAND',
			'loggingControls.missingMode' => 'NO MODE',
			'loggingControls.saveFailed' => ({required Object error}) => 'COULD NOT SAVE: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'COULD NOT DELETE: ${error}',
			'loggingControls.info.noQsos' => 'NO QSOS YET... LET\'S GET ON THE AIR!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOS',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} IN ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} SINCE LAST',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/H FOR LAST 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/H FOR LAST 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} TO',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) TO',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) TO',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} AWAY',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) AWAY',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) AWAY',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'DUPE!',
			'loggingControls.info.noticeNewBand' => 'NEW BAND',
			'loggingControls.info.noticeNewMode' => 'NEW MODE',
			'loggingControls.info.noticeNewDXCC' => 'NEW DXCC',
			'loggingControls.info.noticeNewState' => 'NEW STATE',
			'loggingControls.info.noticeNewProvince' => 'NEW PROVINCE',
			'loggingControls.info.noticeNewDay' => 'NEW DAY',
			'loggingControls.info.noticeNewRef' => 'NEW REF',
			'loggingControls.info.noticeNewMult' => 'NEW MULT',
			'loggingControls.info.noticeNewZone' => 'NEW ZONE',
			'loggingControls.info.noticeInvalidMode' => 'WRONG MODE',
			'loggingControls.info.noticeInvalidBand' => 'WRONG BAND',
			'loggingControls.info.noticeInvalidCategory' => 'NOT WORKABLE',
			'loggingControls.info.noticeOverTime' => 'TIME OVER',
			'loggingControls.info.noticeWorkedBefore' => 'WORKED BEFORE',
			'loggingControls.info.noticeNewPark' => 'NEW PARK',
			'loggingControls.info.noticeNewSection' => 'NEW SECTION',
			'loggingControls.info.noticeBonusStation' => 'BONUS STATION!',
			'loggingControls.info.noticeMissingExchange' => 'NO EXCHANGE',
			'loggingControls.info.noticeInvalidExchange' => 'BAD EXCHANGE',
			'loggingControls.info.noticeUnknownEvent' => 'UNKNOWN EVENT',
			'loggingControls.info.noticeIncompleteCall' => 'INCOMPLETE CALL — NOT SCORED',
			'loggingControls.info.noticeOurGrid' => 'SET OUR GRID',
			'loggingControls.info.noticeRareCounty' => 'RARE COUNTY!',
			'loggingControls.info.noticeOurLocation' => 'SET OUR COUNTY',
			'loggingControls.info.noticeShortGrid' => 'GRID TOO SHORT',
			'formChrome.untitled' => '(UNTITLED)',
			'formChrome.showMore' => 'SHOW MORE',
			'formChrome.showAll' => 'SHOW ALL',
			'formChrome.showFewer' => 'SHOW FEWER',
			'formChrome.defaults' => 'DEFAULTS',
			'formChrome.search' => 'SEARCH',
			'formChrome.clear' => 'CLEAR',
			'formChrome.openPage' => 'OPEN PAGE',
			'formChrome.connected' => 'CONNECTED',
			'formChrome.notConnected' => 'NOT CONNECTED',
			'formChrome.manage' => 'MANAGE',
			'formChrome.connect' => 'CONNECT',
			'formChrome.formTitle' => 'FORM',
			'formChrome.addItem' => ({required Object label}) => 'ADD ${label}',
			'formChrome.editItem' => ({required Object label}) => 'EDIT ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'SHOWING ${shown} OF ${total} (${selected} SELECTED)',
			'formChrome.validationError' => ({required Object error}) => 'VALIDATION ERROR: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'TRANSFORMATION ERROR: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'ERROR: ${error}',
			'formChrome.removeItem' => 'DELETE',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'DELETE ${name}?',
			'formChrome.storageUnavailable' => 'LOGINS UNAVAILABLE',
			'qsoEditForm.title' => 'EDIT QSO',
			_ => null,
		} ?? switch (path) {
			'qsoEditForm.operatorCall' => 'OPERATOR',
			'qsoEditForm.position' => 'POSITION',
			'qsoEditForm.theirName' => 'NAME',
			'qsoEditForm.theirGrid' => 'GRID',
			'qsoEditForm.theirState' => 'STATE',
			'qsoEditForm.band' => 'BAND',
			'qsoEditForm.notes' => 'NOTES',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'THEIR INFO',
			'qsoEditForm.sectionOur' => 'OUR INFO',
			'qsoEditForm.sectionNotes' => 'NOTES',
			'qsoEditForm.theirCity' => 'CITY',
			'qsoEditForm.theirCounty' => 'COUNTY',
			'qsoEditForm.theirEntity' => 'ENTITY',
			'qsoEditForm.theirCqZone' => 'CQ ZONE',
			'qsoEditForm.theirItuZone' => 'ITU ZONE',
			'qsoEditForm.theirArrlSection' => 'ARRL SECTION',
			'qsoEditForm.theirLat' => 'LATITUDE',
			'qsoEditForm.theirLon' => 'LONGITUDE',
			'qsoEditForm.theirPower' => 'THEIR POWER',
			'qsoList.empty' => 'NO QSOS YET — WORK SOMEONE!',
			'qsoList.bandOrModeWarning' => 'PLEASE MAKE SURE YOUR BAND AND MODE ARE CORRECT',
			'qsoList.today' => 'TODAY',
			'qsoList.yesterday' => 'YESTERDAY',
			'qsoList.tomorrow' => 'TOMORROW',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'FIND IN LOG (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'FIND IN LOG',
			'qsoList.find.hint' => 'QSO NUMBER OR CALLSIGN',
			'qsoList.find.noMatches' => 'NO MATCH',
			'qsoList.find.noOperationQsos' => 'NO QSOS IN THIS OPERATION',
			'qsoList.find.noPeriodQsos' => 'NO QSOS IN THIS PERIOD',
			'qsoList.find.outsideQsosOne' => '1 QSO OUTSIDE OF THIS OPERATION',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSOS OUTSIDE OF THIS OPERATION',
			'qsoList.find.pastQsosOne' => '1 PAST QSO',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} PAST QSOS',
			'loggingPanel.stats' => 'OPERATION STATS',
			'loggingPanel.scoring' => 'SCORING',
			'loggingPanel.dxccEntities' => 'DXCC ENTITIES',
			'loggingPanel.statesWorked' => 'STATES',
			'loggingPanel.provincesWorked' => 'PROVINCES',
			'loggingPanel.duplicates' => 'DUPLICATES',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'SHOW IMAGE',
			'callInfo.imageUnavailable' => 'PHOTO UNAVAILABLE',
			'callInfo.photo' => 'PHOTO',
			'callInfo.notes' => 'NOTES',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} TO',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) TO',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) TO',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} AWAY',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) AWAY',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) AWAY',
			'callInfo.thisOpCountOne' => '1 QSO IN THIS OPERATION',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOS IN THIS OPERATION',
			'callInfo.otherOpsCountOne' => '1 QSO IN OTHER OPERATIONS',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOS IN OTHER OPERATIONS',
			'callInfo.andMore' => ({required Object count}) => '… AND ${count} MORE',
			'callInfo.withCall' => ({required Object call}) => 'WITH ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'FROM ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} IN LAST 7 DAYS',
			'callInfo.history.today' => ({required Object n}) => '${n} TODAY',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${n} QSO', other: '${n} QSOS', ), 
			'settings.title' => 'SETTINGS',
			'settings.language' => 'LANGUAGE',
			'settings.languageSystem' => ({required Object language}) => 'FOLLOW SYSTEM SETTINGS (${language})',
			'settings.theme.title' => 'THEME MODE',
			'settings.theme.system' => 'FOLLOW SYSTEM SETTINGS',
			'settings.theme.light' => 'LIGHT',
			'settings.theme.dark' => 'DARK',
			'settings.themeDescription.system' => 'FOLLOWING SYSTEM SETTINGS',
			'settings.themeDescription.light' => 'ALWAYS IN LIGHT MODE',
			'settings.themeDescription.dark' => 'ALWAYS IN DARK MODE',
			'settings.fontScale' => 'FONT SCALE',
			'settings.fontScaleOpts.smallestMinusMinus' => 'SMALLEST--',
			'settings.fontScaleOpts.smallestMinus' => 'SMALLEST-',
			'settings.fontScaleOpts.smallest' => 'SMALLEST',
			'settings.fontScaleOpts.smaller' => 'SMALLER',
			'settings.fontScaleOpts.normal' => 'NORMAL',
			'settings.fontScaleOpts.larger' => 'LARGER',
			'settings.fontScaleOpts.largest' => 'LARGEST',
			'settings.fontScaleOpts.largestPlus' => 'LARGEST+',
			'settings.fontScaleOpts.largestPlusPlus' => 'LARGEST++',
			'settings.keepDeviceAwake.title' => 'KEEP DEVICE AWAKE',
			'settings.keepDeviceAwake.descriptionOn' => 'STAYING AWAKE WHILE YOU ARE ON THE LOGGING VIEW OR A SYNC IS IN PROGRESS',
			'settings.keepDeviceAwake.descriptionOff' => 'SLEEPING AS USUAL',
			'settings.layoutDensity' => 'LAYOUT DENSITY',
			'settings.layoutDensityOpts.auto' => 'AUTOMATIC',
			'settings.layoutDensityOpts.densest' => 'DENSEST',
			'settings.layoutDensityOpts.dense' => 'DENSE',
			'settings.layoutDensityOpts.normal' => 'NORMAL',
			'settings.layoutDensityOpts.sparse' => 'SPARSE',
			'settings.layoutDensityOpts.sparsest' => 'SPARSEST',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'THE WINDOW IS TOO SHORT, USING ${effective}',
			'settings.layoutDensityAtLimit' => 'AS FAR AS IT GOES',
			'settings.distanceUnits' => 'DISTANCE UNITS',
			'settings.distanceUnitsOpts.kilometers' => 'KILOMETERS',
			'settings.distanceUnitsOpts.miles' => 'MILES',
			'settings.userInterface' => 'USER INTERFACE',
			'settings.logging.title' => 'LOGGING',
			'settings.logging.leftieMode.title' => 'LEFTIE MODE',
			'settings.logging.leftieMode.descriptionOn' => 'USING LAYOUT FOR LEFT-HANDED USERS',
			'settings.logging.leftieMode.descriptionOff' => 'USING LAYOUT FOR RIGHT-HANDED USERS',
			'settings.logging.countryFlags.title' => 'COUNTRY FLAGS',
			'settings.logging.countryFlags.dx' => 'SHOW ONLY FOR DX CONTACTS',
			'settings.logging.countryFlags.all' => 'SHOW FLAGS FOR ALL CONTACTS',
			'settings.logging.countryFlags.none' => 'DON\'T SHOW ANY FLAGS',
			'settings.logging.countryFlagsDescription.dx' => 'SHOWING FLAGS ONLY FOR DX CONTACTS',
			'settings.logging.countryFlagsDescription.all' => 'SHOWING FLAGS FOR ALL CONTACTS',
			'settings.logging.countryFlagsDescription.none' => 'NOT SHOWING ANY FLAGS',
			'settings.logging.suggestDefaultOperator.title' => 'SUGGEST OPERATOR',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'OFFERING YOUR CALLSIGN AS THE OPERATOR WHEN AN OPERATION RUNS UNDER A DIFFERENT STATION CALLSIGN',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'LEAVING THE OPERATOR BLANK UNLESS YOU FILL IT IN',
			'settings.logging.showBearing.title' => 'SHOW BEARING',
			'settings.logging.showBearing.descriptionOn' => 'SHOWING ESTIMATED BEARING TO STATION',
			'settings.logging.showBearing.descriptionOff' => 'NOT SHOWING BEARING INFORMATION',
			'settings.logging.showReverseBearing.title' => 'ALSO SHOW REVERSE BEARING',
			'settings.logging.showReverseBearing.descriptionOn' => 'SHOWING THE BEARING FROM THE STATION TOO, AS "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'ONLY SHOWING THE BEARING TO THE STATION',
			'settings.logging.switchSentRcvd.title' => 'SWITCH SIGNAL REPORT ORDER',
			'settings.logging.switchSentRcvd.sentFirst' => 'SENT FIRST, RCVD SECOND',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'RCVD FIRST, SENT SECOND',
			'settings.logging.jumpAfterRST.title' => 'JUMP TO NEXT FIELD ON RST ENTRY',
			'settings.logging.jumpAfterRST.descriptionOn' => 'JUMPING AFTER RST IS ENTERED',
			'settings.logging.jumpAfterRST.descriptionOff' => 'NOT JUMPING AUTOMATICALLY',
			'settings.logging.defaultReport.title' => 'DEFAULT REPORT — PHONE',
			'settings.logging.defaultReport.description' => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON SSB, FM OR AM',
			'settings.logging.defaultReportCW.title' => 'DEFAULT REPORT — CW AND DATA',
			'settings.logging.defaultReportCW.description' => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON CW, RTTY AND OTHER DATA MODES',
			'settings.logging.defaultReportFT8.title' => 'DEFAULT REPORT — FT8 AND FT4',
			'settings.logging.defaultReportFT8.description' => 'USED WHEN SENT OR RCVD IS LEFT EMPTY ON THE FT MODES',
			'settings.logging.numbersRow.title' => 'NUMBERS ROW',
			'settings.logging.numbersRow.description' => 'SHOW A ROW OF NUMBER KEYS ABOVE THE KEYBOARD WHILE LOGGING',
			'settings.logging.numbersRowExtra.title' => 'SLASH AND PERIOD KEY',
			'settings.logging.numbersRowExtra.description' => 'ADDS A CONTEXTUAL KEY: “/” FOR CALLSIGNS, “.” FOR NUMBERS',
			'settings.logging.numbersRowVibrate.title' => 'VIBRATE ON KEY PRESS',
			'settings.logging.numbersRowVibrate.description' => 'HAPTIC FEEDBACK WHEN YOU TAP A NUMBER KEY',
			'settings.logging.bands' => 'PREFERRED BANDS',
			'settings.logging.modes' => 'PREFERRED MODES',
			'settings.catServer.title' => 'CAT SERVER',
			'settings.catServer.description' => 'ALLOW OTHER APPS (WSJT-X, LOGGERS, ETC) TO CONTROL THE RADIO THROUGH HAM2K LOGGER.',
			'settings.catServer.protocol' => 'PROTOCOL',
			'settings.catServer.protocolOpts.off' => 'DISABLED',
			'settings.catServer.protocolOpts.rigctld' => 'HAMLIB RIGCTLD',
			'settings.catServer.protocolOpts.flrig' => 'FLRIG',
			'settings.catServer.protocolOpts.hrd' => 'HAM RADIO DELUXE®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'PORT',
			'settings.catServer.openAccess' => 'OPEN ACCESS',
			'settings.catServer.openAccessOn' => 'ANY COMPUTER ON THE LOCAL NETWORK CAN CONNECT.',
			'settings.catServer.openAccessOff' => 'ONLY APPS ON THIS COMPUTER CAN CONNECT.',
			'settings.catServer.off' => 'OFF.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, STARTING…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} ON PORT ${port}. CLIENTS CONNECTED: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} ON PORT ${port}, BUT NO MAIN VFO RADIO IS CONNECTED.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} CANNOT LISTEN ON PORT ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} CANNOT LISTEN ON PORT ${port}: ANOTHER PROGRAM IS USING IT, OFTEN ${protocol} ITSELF. CLOSE THAT PROGRAM OR CHOOSE ANOTHER PORT.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} CANNOT LISTEN ON PORT ${port}: THIS COMPUTER DOES NOT ALLOW IT. CHOOSE A PORT ABOVE 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} STOPPED LISTENING ON PORT ${port}. TRYING AGAIN…',
			'settings.cluster.title' => 'DX CLUSTER',
			'settings.cluster.description' => 'THE SERVER EXTENSIONS POST SPOTS TO AND READ SPOTS FROM, LOGGED IN AS THE OPERATOR.',
			'settings.cluster.server' => 'CLUSTER SERVER',
			'settings.cluster.selectServer' => 'SELECT SERVER',
			'settings.cluster.serverOther' => 'OTHER',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'NO HOST ENTERED YET, SO SPOTS GO TO ${node}',
			'settings.cluster.customHost' => 'SERVER',
			'settings.cluster.customPort' => 'PORT',
			'settings.cluster.password' => 'PASSWORD',
			'settings.cluster.passwordDescription' => 'ONLY IF NEEDED',
			'settings.cluster.passwordStored' => ({required Object node}) => 'PASSWORD ON FILE FOR ${node}',
			'settings.cluster.scrollback' => 'LINES KEPT',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} LINES',
			'settings.cluster.connection' => 'CONNECTION',
			'settings.cluster.statusIdle' => 'NOT CONNECTED. CONNECTS WHEN AN EXTENSION NEEDS IT. TAP TO TEST.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'CONNECTING TO ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'CONNECTED TO ${node} AS ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'COULD NOT CONNECT TO ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'NOT AVAILABLE IN THE WEB VERSION.',
			'settings.cluster.errors.noCall' => 'NO OPERATOR CALLSIGN TO LOG IN WITH',
			'settings.cluster.errors.connectFailed' => 'THE NODE COULD NOT BE REACHED',
			'settings.cluster.errors.needsPassword' => 'THE NODE ASKS FOR A PASSWORD, AND NONE IS STORED',
			'settings.cluster.errors.loginFailed' => 'THE NODE DID NOT ACCEPT THE LOGIN',
			'settings.cluster.errors.disconnected' => 'THE NODE CLOSED THE CONNECTION',
			'settings.cluster.errors.timeout' => 'THE NODE DID NOT ANSWER',
			'settings.spotting.title' => 'SPOTTING',
			'settings.spotting.respotInterval' => 'AUTO RE-SPOT EVERY',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} MIN',
			'settings.spotting.autoRespotByDefault' => 'AUTO RE-SPOT BY DEFAULT',
			'settings.spotting.autoRespotByDefaultOn' => 'ENABLE AUTO RE-SPOT AFTER ANY SPOT IS POSTED',
			'settings.spotting.autoRespotByDefaultOff' => 'REQUIRE USER ACTION TO ENABLE AUTO RE-SPOTTING',
			'settings.spotting.pulseBeforeRespot' => 'PULSE BEFORE EACH AUTO RE-SPOT',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'THE SPOTTING CHIP PULSES BLUE FOR THE ${seconds} SECONDS BEFORE EACH RE-SPOT',
			'settings.spotting.pulseBeforeRespotOff' => 'NO PULSING BEFORE AN AUTO RE-SPOT',
			'settings.radio.title' => 'CAT CONTROL',
			'settings.radio.loggingAndCat' => 'LOGGING & CAT',
			'settings.radio.tuningSection' => 'TUNING',
			'settings.radio.keyerSection' => 'KEYER',
			'settings.radio.servicesSection' => 'SERVICES',
			'settings.radio.stationConfigurationSection' => 'STATION CONFIGURATION',
			'settings.radio.moreSettings' => 'MORE STATION CONFIGURATION SETTINGS',
			'settings.radio.units.ms' => 'MS',
			'settings.radio.units.kHz' => 'KHZ',
			'settings.radio.units.kHzPerSecond' => 'KHZ/S',
			'settings.radio.units.hz' => 'HZ',
			'settings.radio.pttKey.title' => 'CONTROL PTT WITH [\']',
			'settings.radio.pttKey.descriptionOn' => 'IN PHONE MODES, [\'] KEYS THE RADIO AND [\'] AGAIN UNKEYS IT. IT UNKEYS BY ITSELF AFTER A MINUTE.',
			'settings.radio.pttKey.descriptionOff' => 'THE [\'] KEY DOES NOT KEY THE RADIO.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'TRANSMITTING',
			'settings.radio.smartVfoSnap.title' => 'SMART VFO SNAP',
			'settings.radio.smartVfoSnap.descriptionOn' => 'AFTER YOU STOP TURNING THE DIAL, ROUNDING THE FREQUENCY TO A SENSIBLE STEP. VOICE MODES ONLY.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'STAYING EXACTLY WHERE YOU TUNED IT.',
			'settings.radio.snapDebounce.title' => 'SMART SNAP: SETTLE DELAY',
			'settings.radio.snapDebounce.description' => 'HOW LONG THE DIAL HAS TO STOP BEFORE THE FREQUENCY IS ROUNDED. SHORTER FEELS IMMEDIATE; LONGER LEAVES ROOM FOR A SLOW MOVE.',
			'settings.radio.snapLongMove.title' => 'SMART SNAP: LONG MOVE',
			'settings.radio.snapLongMove.description' => 'MOVE AT LEAST THIS FAR AND THE FREQUENCY ROUNDS TO A WHOLE KHZ, HOWEVER SLOWLY YOU FINISHED.',
			'settings.radio.snapMinMove.title' => 'SMART SNAP: SMALLEST MOVE',
			'settings.radio.snapMinMove.description' => 'MOVE LESS THAN THIS AND THE FREQUENCY IS NOT ROUNDED, SO FINE TUNING IS LEFT ALONE.',
			'settings.radio.snapMinSpeed.title' => 'SMART SNAP: SLOWEST MOVE',
			'settings.radio.snapMinSpeed.description' => 'TURN THE DIAL SLOWER THAN THIS AND THE FREQUENCY IS NOT ROUNDED, UNLESS IT WAS A LONG MOVE.',
			'settings.radio.enterSends.pillOff' => 'ESM OFF',
			'settings.radio.enterSends.pillRun' => 'ESM RUN',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'ENTER SENDS MESSAGES',
			'settings.radio.enterSends.off' => 'OFF',
			'settings.radio.enterSends.run' => 'RUN',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'ENTER SENDS MESSAGES: ${state}. TAP TO CHANGE.',
			'settings.radio.keyerSpeed.title' => 'KEYER SPEED',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerSpeed.pillUnknown' => '– WPM',
			'settings.radio.cwMessages.title' => 'CW KEYER MESSAGES',
			'settings.radio.cwMessages.notSupported' => 'CURRENT RADIO DOES NOT SUPPORT CW KEYING',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'MESSAGE (${n})',
			'settings.radio.cwMessages.labelField' => 'LABEL',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n} LABEL',
			'settings.radio.cwMessages.details' => 'DETAILS',
			'settings.radio.cwMessages.empty' => '(EMPTY)',
			'settings.radio.cwMessages.sets' => 'MESSAGE SET',
			'settings.radio.cwMessages.newSet' => 'NEW SET',
			'settings.radio.cwMessages.renameSet' => 'RENAME SET',
			'settings.radio.cwMessages.deleteSet' => 'DELETE SET',
			'settings.radio.cwMessages.newSetName' => 'NAME',
			'settings.radio.cwMessages.setDefault' => 'DEFAULT',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM MESSAGES',
			'settings.radio.cwMessages.setSaved' => 'MY MESSAGES',
			'settings.radio.cwMessages.repeat' => 'REPEAT MESSAGE #1',
			'settings.radio.cwMessages.repeatOff' => 'NO',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'AFTER ${n} SECONDS',
			'settings.radio.cwMessages.repeatWait' => 'REPEATING',
			'settings.radio.cwMessages.keyboard' => 'TYPE TO SEND',
			'settings.radio.cwMessages.keyboardField' => 'TYPE TO SEND',
			'settings.radio.cwMessages.closeArea' => 'CLOSE THE KEYER AREA',
			'settings.radio.cwMessages.help' => 'HELP',
			'settings.radio.cwMessages.helpTitle' => 'WRITING CW MESSAGES',
			'settings.radio.cwMessages.helpIntro' => 'MESSAGES CAN USE TEMPLATES WITH THE FOLLOWING VALUES:',
			'settings.radio.cwMessages.helpOpCall' => 'YOUR CALLSIGN',
			'settings.radio.cwMessages.helpQsoCall' => 'THEIR CALLSIGN — IN A // STACK, THE CALL THAT WILL BE LOGGED',
			'settings.radio.cwMessages.helpQsoFullCall' => 'THEIR CALLSIGN, IF THERE IS A VALID CALL; BLANK FOR A PARTIAL',
			'settings.radio.cwMessages.helpQsoPartial' => 'A PARTIAL CALL; BLANK IF THERE IS A FULL VALID CALL',
			'settings.radio.cwMessages.helpQsoNextCall' => 'IN A // STACK, THE CALL THAT WILL BE SELECTED FOR LOGGING NEXT, IF THERE IS A VALID FULL CALL',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'IN A // STACK, THE NEXT PARTIAL AFTER LOGGING THE CURRENT CONTACT',
			'settings.radio.cwMessages.helpQsoName' => 'THEIR FIRST NAME, AS TYPED OR ELSE FROM THE LOOKUP',
			'settings.radio.cwMessages.helpQsoState' => 'THEIR STATE, AS TYPED OR ELSE FROM THE LOOKUP',
			'settings.radio.cwMessages.helpKeyerMsg' => 'MESSAGE 1 AS IT WOULD BE SENT, INSIDE ANOTHER MESSAGE. VALID FOR MESSAGES 1 THROUGH 8',
			'settings.radio.cwMessages.helpQsoRst' => 'THE REPORT YOU ARE SENDING',
			'settings.radio.cwMessages.helpQsoSerial' => 'YOUR SERIAL NUMBER, IN A CONTEST THAT SENDS ONE',
			'settings.radio.cwMessages.helpPad' => 'PADS WITH ZEROS TO THAT MANY DIGITS: 7 IS SENT AS 007',
			'settings.radio.cwMessages.helpCut' => 'CUT NUMBERS, T FOR 0 AND N FOR 9: 599 IS SENT AS 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'CHOOSES THE DIGITS TO CUT, IN QUOTES — 0 IS T, 1 IS A, 5 IS E, 9 IS N',
			'settings.radio.cwMessages.helpFullExample' => 'FULL EXAMPLE:',
			'settings.radio.cwMessages.helpExample' => 'SENDS W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'WITH ENTER SENDS MESSAGES ON, ENTER KEYS MESSAGES BY THEIR FUNCTION KEY, AS N1MM DOES. THE ESM MESSAGES SET STARTS WITH THESE:',
			'settings.radio.cwMessages.helpEsmCq' => 'RUNNING, ENTER WITH THE CALL FIELD EMPTY CALLS CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'YOUR EXCHANGE: AFTER THEIR CALL WHEN RUNNING, AFTER THEY ANSWER IN S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'THANKS, ONCE THE CONTACT HAS LOGGED: ITS PLACEHOLDERS NAME THE NEXT CONTACT, NOT THIS ONE',
			'settings.radio.cwMessages.helpEsmMyCall' => 'IN S&P, YOUR CALL TO THE STATION YOU ARE ANSWERING',
			'settings.radio.cwMessages.helpEsmHisCall' => 'RUNNING, THEIR CALL AHEAD OF YOUR EXCHANGE',
			'settings.radio.cwMessages.helpEsmAgain' => 'ASKS AGAIN WHEN NOTHING OF THEIR EXCHANGE WAS COPIED',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'SUGGESTED F3 FOR // STACKS: TU GOES OUT AFTER THE CONTACT LOGS, SO IT THANKS, THEN CALLS THE NEXT STACKED STATION AND SENDS YOUR EXCHANGE, OR ASKS A PARTIAL BACK (TU KR?); WITH NOTHING LEFT, JUST TU',
			'settings.radio.voiceMessages.title' => 'PHONE KEYER MESSAGES',
			'settings.radio.voiceMessages.notSupported' => 'CURRENT RADIO DOES NOT SUPPORT PHONE MESSAGES',
			'settings.radio.voiceMessages.description' => 'THIS USES THE RADIO\'S VOICE MEMORIES',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'VOICE MEMORY (${n})',
			'settings.radio.voiceMessages.labelField' => 'LABEL',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'VOICE MEMORY ${n} LABEL',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} S',
			'settings.radio.voiceMessages.emptyOnRadio' => 'EMPTY',
			'settings.radio.voiceMessages.notMeasured' => 'UNKNOWN LENGTH',
			'settings.radio.voiceMessages.playButton' => 'PLAY',
			'settings.radio.voiceMessages.recordButton' => 'RECORD',
			'settings.radio.voiceMessages.stopButton' => 'STOP',
			'settings.radio.voiceMessages.repeat' => 'REPEAT MESSAGE #1',
			'settings.radio.voiceMessages.repeatOff' => 'NO',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'AFTER ${n} SECONDS',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} NOTES:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'THESE MEMORIES ARE IN ${device}\'S RADIO. THEIR NAMES AND LENGTHS BELONG TO THAT DEVICE.',
			'settings.radio.voiceMessages.namedOnRadio' => 'SAVED IN THE RADIO, WHERE ITS OTHER CLIENTS SEE IT TOO.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'WAIT FOR THE [REC] INDICATOR ON THE RADIO, THEN HOLD THE PTT BUTTON AND RECORD YOUR MESSAGE. END IT BY PRESSING THE STOP BUTTON HERE IN THE APP BEFORE RELEASING PTT TO AVOID UNWANTED CLICKS.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'WAIT FOR THE [REC] INDICATOR TO BLINK AT LEAST FOUR TIMES, THEN HOLD THE PTT BUTTON AND RECORD YOUR MESSAGE. END IT BY PRESSING THE STOP BUTTON HERE IN THE APP BEFORE RELEASING PTT TO AVOID UNWANTED CLICKS.',
			'settings.radio.voiceMessages.pill' => 'VOICE',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'PLAY MEMORY ${n}',
			'settings.radio.voiceMessages.stop' => 'STOP',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'RECORD MEMORY ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'STOP RECORDING',
			'settings.radio.voiceMessages.playing' => 'PLAYING…',
			'settings.radio.voiceMessages.recording' => 'RECORDING…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'PLAYING ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'RECORDING ${label}',
			'settings.radio.voiceMessages.doubtful' => 'DID THE RADIO PLAY IT? IT SAID IT WAS IDLE RIGHT AWAY.',
			'settings.radio.voiceMessages.recordOnRadio' => 'YOU HAVE TO RECORD THE MEMORIES ON THE RADIO ITSELF.',
			'settings.radio.avoidZeroBeat.title' => 'AVOID ZERO-BEATING ON SPOTS',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'WITH A RADIO CONNECTED, TUNING A FEW HZ OFF A CW SPOT, SO EVERYONE ANSWERING IT ISN’T CALLING ON THE SAME NOTE.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'TUNING EXACTLY TO THE SPOTTED FREQUENCY.',
			'settings.radio.zeroBeatRange.title' => 'ZERO-BEAT: AVOIDANCE RANGE',
			'settings.radio.zeroBeatRange.description' => 'HOW FAR OFF THE SPOTTED FREQUENCY TO LAND, EITHER SIDE. THE OFFSET IS NEVER NEAR ZERO — THAT WOULD BE A ZERO BEAT AGAIN.',
			'settings.help.title' => 'HELP & RESOURCES',
			'settings.help.description' => 'COMMUNITY AND SUPPORT',
			'settings.help.forums' => 'HAM2K FORUMS',
			'settings.help.forumsDescription' => 'FIND HELP, GIVE FEEDBACK, DISCUSS IDEAS…',
			'settings.help.chat' => 'HAM2K CHAT',
			'settings.help.chatDescription' => 'THE DISCORD SERVER FOR OUR ONLINE COMMUNITY',
			'settings.help.youtube' => 'HAM2K YOUTUBE',
			'settings.help.youtubeDescription' => 'VIDEOS AND LIVE STREAMS',
			'settings.help.instagram' => 'HAM2K INSTAGRAM',
			'settings.help.instagramDescription' => 'BECAUSE YOU CANNOT HAVE TOO MANY PHOTOS…',
			'settings.help.bluesky' => 'HAM2K BLUESKY',
			'settings.help.blueskyDescription' => 'FOLLOW US FOR NEWS AND UPDATES',
			'settings.help.contact' => 'CONTACT US',
			'settings.help.contactDescription' => 'HELP@HAM2K.COM — BUT TRY THE FORUMS OR CHAT FIRST!',
			'settings.exports.title' => 'EXPORTS',
			'settings.extensionSections.activities' => 'ACTIVITIES',
			'settings.extensionSections.hunting' => 'HUNTING',
			'settings.extensionSections.contests' => 'CONTESTS',
			'settings.extensionSections.lookups' => 'LOOKUPS',
			'settings.extensionSections.dashboard' => 'DASHBOARD',
			'settings.map.title' => 'MAPS',
			'settings.map.style.title' => 'MAP STYLE',
			'settings.map.showCallsigns.title' => 'SHOW CALLSIGNS',
			'settings.map.showCallsigns.description' => 'EACH CONTACT IS A PILL WITH ITS CALLSIGN, IN ITS BAND\'S COLOR',
			'settings.map.showGrayline.title' => 'SHOW GRAYLINE',
			'settings.map.showGrayline.description' => 'SHADES THE NIGHT SIDE OF THE EARTH, WITH TWILIGHT AS A GRADIENT',
			'settings.map.styleOpts.automatic' => 'AUTOMATIC',
			'settings.map.styleOpts.liberty' => 'LIBERTY',
			'settings.map.styleOpts.bright' => 'BRIGHT',
			'settings.map.styleOpts.positron' => 'POSITRON',
			'settings.map.styleOpts.voyager' => 'VOYAGER',
			'settings.map.styleOpts.darkMatter' => 'DARK MATTER',
			'settings.privacy.title' => 'PRIVACY',
			'settings.privacy.shareAppData.title' => 'SHARE APP USAGE DATA',
			'settings.privacy.shareAppData.descriptionOn' => 'HELPING US IMPROVE THE APP BY SHARING USAGE, CONFIGURATION, CRASH AND PERFORMANCE DATA',
			'settings.privacy.shareAppData.descriptionOff' => 'KEEPING APP USAGE DATA PRIVATE.\nTHE HAM2K TEAM WON\'T BE ABLE TO DETECT CRASHES OR OTHER ISSUES.',
			'settings.privacy.shareOpData.title' => 'SHARE OPERATION DATA',
			'settings.privacy.shareOpData.descriptionOn' => 'SHARING SOME OPERATION DATA PUBLICLY AND WITH OTHER USERS',
			'settings.privacy.shareOpData.descriptionOff' => 'KEEPING OPERATION DATA PRIVATE',
			'settings.privacy.privacyPolicy' => 'PRIVACY POLICY',
			'settings.privacy.termsOfService' => 'TERMS OF SERVICE',
			'settings.operatorCall' => 'OPERATOR CALLSIGN',
			'settings.sync.title' => 'CLOUD SYNC',
			'settings.sync.moreSettings' => 'MORE SYNC SETTINGS',
			'settings.sync.enable' => 'ENABLE SYNC',
			'settings.sync.deviceKey' => 'DEVICE KEY',
			'settings.peers.title' => 'PEER DEVICES',
			'settings.peers.enable' => 'CONNECT TO OTHER DEVICES',
			'settings.peers.enableDescription' => 'ALLOW SHARING OPERATIONS, LOGGING, CAT AND GPS WITH OTHER DEVICES OVER THE LOCAL NETWORK',
			'settings.peers.bleEnable' => 'CONNECT OVER BLUETOOTH',
			'settings.peers.bleDescription' => 'USE BLUETOOTH LE TO CONNECT EVEN IF THERE IS NO LOCAL NETWORK',
			'settings.peers.thisDevice' => 'THIS DEVICE',
			'settings.peers.deviceName' => 'NAME',
			'settings.peers.deviceNameHint' => 'HOW THIS DEVICE IS SEEN BY OTHER DEVICES',
			'settings.peers.pairedDevices' => 'LINKED DEVICES',
			'settings.peers.noPairedDevices' => 'NO DEVICES LINKED YET. TURN THIS ON, ON ANOTHER DEVICE ON THIS NETWORK, TO LINK THEM.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'CAN\'T READ YOUR LINKED DEVICES: ${error}',
			'settings.peers.nearby' => 'NEARBY',
			'settings.peers.connected' => 'CONNECTED',
			'settings.peers.viaBluetooth' => 'VIA BLUETOOTH',
			'settings.peers.connecting' => 'CONNECTING…',
			'settings.peers.syncing' => 'SYNCING…',
			'settings.peers.waitingForThem' => 'WAITING FOR THE OTHER DEVICE',
			'settings.peers.notConnected' => 'NOT CONNECTED',
			'settings.peers.wantsToPair' => 'WANTS TO SHARE THIS OPERATION',
			'settings.peers.allow' => 'ALLOW',
			'settings.peers.link' => 'LINK',
			'settings.peers.reject' => 'REJECT',
			'settings.peers.forget' => 'FORGET',
			'settings.peers.forgetTitle' => ({required Object name}) => 'FORGET ${name}?',
			'settings.peers.forgetBody' => 'IT WILL STOP SYNCING WITH THIS DEVICE. YOU CAN ALLOW IT AGAIN LATER, AND CONTACTS ALREADY LOGGED ARE KEPT.',
			'settings.peers.pairTitle' => ({required Object name}) => 'LINK WITH ${name}',
			'settings.peers.pairBody' => 'THIS DEVICE IS ON YOUR LOCAL NETWORK AND WANTS TO CONNECT.',
			'settings.peers.pairBodyBle' => 'THIS DEVICE IS NEARBY AND WANTS TO CONNECT OVER BLUETOOTH LE.',
			'settings.peers.pairIdLabel' => 'DEVICE ID',
			'settings.peers.pairWarning' => 'ONLY LINK WITH DEVICES YOU RECOGNISE. ANY DEVICE ON THIS NETWORK CAN SEND A REQUEST.',
			'settings.peers.pairWarningBle' => 'ONLY LINK WITH DEVICES YOU RECOGNISE. ANY NEARBY DEVICE CAN SEND A REQUEST.',
			'settings.peers.problem' => ({required Object error}) => 'CAN\'T REACH THE LOCAL NETWORK: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'BLUETOOTH: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'CONNECTED TO ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'LOST CONNECTION TO ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'PEER DEVICES: ${connected} OF ${linked} CONNECTED',
			'settings.peers.screenEnable' => 'SHARE SCREENS AND WINDOWS',
			'settings.peers.screenDescription' => 'ALLOW OTHER DEVICES TO SHOW SCREENS OR WINDOWS FROM THIS COMPUTER',
			'settings.peers.screenSources' => 'SCREENS AND WINDOWS',
			'settings.peers.screenRefresh' => 'REFRESH THE LIST',
			'settings.peers.screenUnsupportedPlatform' => 'THIS DEVICE CAN\'T SHARE ITS SCREEN. MACOS CAN; EVERY DEVICE CAN SHOW ONE SHARED BY ANOTHER.',
			'settings.peers.screenUnsupportedVersion' => 'SHARING A SCREEN NEEDS MACOS 12.3 OR LATER. THIS DEVICE CAN STILL SHOW A SCREEN SHARED BY ANOTHER.',
			'settings.peers.screenNeedsPermission' => 'MACOS NEEDS YOUR PERMISSION TO RECORD THE SCREEN BEFORE THIS APP CAN SHARE ONE.',
			'settings.peers.screenGrantPermission' => 'ASK FOR PERMISSION',
			'settings.peers.screenRelaunchAfterGranting' => 'ALLOW IT IN SYSTEM SETTINGS UNDER PRIVACY & SECURITY → SCREEN RECORDING, THEN QUIT AND REOPEN THIS APP — MACOS ONLY TELLS AN APP ABOUT THE CHANGE ON ITS NEXT LAUNCH.',
			'settings.peers.screenProblem' => ({required Object error}) => 'SCREEN SHARING: ${error}',
			'settings.peers.screenChooseTitle' => 'CHOOSE WHAT TO SHARE',
			'settings.peers.screenChooseButton' => 'CHOOSE WHAT TO SHARE…',
			'settings.peers.screenTabScreens' => 'SCREENS',
			'settings.peers.screenTabApps' => 'APPS',
			'settings.peers.screenTabWindows' => 'WINDOWS',
			'settings.peers.screenTabEmpty' => 'NOTHING OF THIS KIND WAS FOUND.',
			'settings.peers.screenSharedSummaryNone' => 'NOTHING CHOSEN YET.',
			'settings.peers.screenThisDevice' => 'THIS DEVICE',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'SHOWN ON ${devices}',
			'settings.peers.screenSharedToNobody' => 'NOT BEING SHOWN',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'STOP SHARING ${name}',
			'settings.developerMode' => 'DEVELOPER MODE',
			'settings.syncPanel.configuration' => 'SYNC CONFIGURATION',
			'settings.syncPanel.enableTitle' => 'SYNC WITH HAM2K LOG FILER',
			'settings.syncPanel.enabledDescription' => 'BACKING UP AND SYNCING YOUR LOG ACROSS DEVICES',
			'settings.syncPanel.disabledDescription' => 'OFF — STAYING ON THIS DEVICE ONLY',
			'settings.syncPanel.syncing' => 'SYNCING',
			'settings.syncPanel.account' => 'ACCOUNT',
			'settings.syncPanel.refresh' => 'REFRESH',
			'settings.syncPanel.switchAccounts' => 'SWITCH ACCOUNTS',
			'settings.syncPanel.switchAccountsDescription' => 'LINK THIS DEVICE TO ANOTHER ACCOUNT WITH A QR CODE OR EMAIL',
			'settings.syncPanel.connectionRequests' => 'CONNECTION REQUESTS',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'A DEVICE IS WAITING TO JOIN THIS ACCOUNT', other: '${n} DEVICES ARE WAITING TO JOIN THIS ACCOUNT', ), 
			'settings.syncPanel.accountEmailTitle' => 'ACCOUNT EMAIL',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'CONFIRMATION SENT TO ${email}. OPEN THE LINK THERE TO FINISH THE CHANGE.',
			'settings.syncPanel.resendConfirmation' => 'RESEND CONFIRMATION EMAIL',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'WAITING ON ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'SENT AGAIN TO ${email}.',
			'settings.syncPanel.deviceLinked' => 'THAT DEVICE IS NOW LINKED TO THIS ACCOUNT.',
			'settings.syncPanel.checking' => 'CHECKING…',
			'settings.syncPanel.notLinked' => 'NOT LINKED YET',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'REPLACE LOCAL DATA?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${n} OPERATION', other: '${n} OPERATIONS', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${n} QSO', other: '${n} QSOS', ), 
			'settings.syncPanel.counts' => 'SYNCED DATA',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'THIS DEVICE: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'WAITING TO UPLOAD: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'SERVER: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'THIS DEVICE: CHECKING…',
			'settings.syncPanel.countsServerChecking' => 'SERVER: CHECKING…',
			'settings.syncPanel.countsServerUnavailable' => 'SERVER: NOT AVAILABLE',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'THIS BACKS UP AND CLEARS ${operations} AND ${qsos} FROM THIS DEVICE, THEN DOWNLOADS THE ACCOUNT\'S DATA INSTEAD. THE BACKUP STAYS IN THIS DEVICE\'S DATABASE.',
			'settings.syncPanel.replace' => 'REPLACE',
			'settings.syncPanel.pendingBannerTitle' => 'NEW HAM2K LOG FILER ACCOUNT DETECTED',
			'settings.syncPanel.pendingBannerBody' => 'KEEP THIS DEVICE\'S EXISTING OPERATIONS AND QSOS AND MERGE THEM INTO THE ACCOUNT, OR REPLACE THEM WITH THE ACCOUNT\'S DATA (A BACKUP STAYS ON THIS DEVICE EITHER WAY).',
			'settings.syncPanel.combine' => 'COMBINE',
			'settings.syncPanel.authIssueTitle' => 'SYNC CAN\'T CONNECT',
			'settings.syncPanel.authIssueText' => 'HAM2K LOG FILER KEEPS REJECTING THIS DEVICE. CHECK YOUR CALLSIGN IN SYNC SETTINGS.',
			'settings.syncPanel.openSettings' => 'OPEN SYNC SETTINGS',
			'settings.accounts.title' => 'ACCOUNTS, SERVICES & DATA SOURCES',
			'settings.accounts.none' => 'NO ACTIVE EXTENSIONS WITH ACCOUNTS',
			'settings.accounts.notConfigured' => 'NOT CONFIGURED',
			'settings.accounts.connected' => 'CONNECTED',
			'settings.accounts.cancelLogin' => 'CANCEL SIGN-IN',
			'settings.accounts.openInBrowser' => 'OPEN IN BROWSER',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'LOGGED IN AS ${identity}',
			'settings.accounts.pressSaveToKeep' => 'PRESS SAVE TO KEEP THIS ACCOUNT CONNECTED.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'CONNECTED TO ${label}',
			'settings.accounts.connect' => 'CONNECT',
			'settings.accounts.disconnect' => 'DISCONNECT',
			'settings.accounts.connectedAs' => 'CONNECTED AS',
			'settings.accounts.test' => 'TEST',
			'settings.accounts.saveFailed' => ({required Object error}) => 'SAVE FAILED: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'LOGIN FAILED: ${error}',
			'settings.accounts.lookupFailed' => 'ACCOUNTS ARE UNAVAILABLE RIGHT NOW — TRY AGAIN IN A MOMENT',
			'settings.accounts.browserLoginTitle' => 'FINISH SIGNING IN WITH YOUR WEB BROWSER',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'WHEN YOU ARE DONE, THE BROWSER WILL TRY TO OPEN A LINK STARTING WITH "${prefix}". YOUR DESKTOP MOST LIKELY HAS NOTHING REGISTERED TO OPEN IT, SO COPY THAT LINK (FROM THE ADDRESS BAR, OR FROM THE ERROR PAGE THE BROWSER SHOWS) AND PASTE IT HERE.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'HAM2K LOGGER COULD NOT OPEN YOUR BROWSER. COPY THE LOGIN LINK BELOW AND OPEN IT YOURSELF, THEN COPY THE LINK IT SENDS YOU TO (IT STARTS WITH "${prefix}") AND PASTE THAT HERE.',
			'settings.accounts.copyLoginLink' => 'COPY LOGIN LINK',
			'settings.accounts.pastedLinkLabel' => 'PASTE THE LINK HERE',
			'settings.accounts.finishLogin' => 'FINISH LOGIN',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'THAT IS NOT THE LOGIN LINK — IT SHOULD START WITH "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'THAT LINK BELONGS TO A DIFFERENT LOGIN ATTEMPT. CLOSE THIS PAGE AND CONNECT AGAIN.',
			'settings.accounts.pastedLinkNoCode' => 'THAT LINK HAS NO LOGIN CODE. FINISH SIGNING IN FIRST, THEN COPY THE LINK IT SENDS YOU TO.',
			'settings.accounts.pastedLinkMalformed' => 'THAT LINK LOOKS CUT OFF. COPY THE WHOLE THING AND PASTE IT AGAIN.',
			'settings.accounts.relayLoginWaiting' => 'WAITING FOR YOU TO FINISH SIGNING IN — THIS WILL CONTINUE AUTOMATICALLY ONCE YOU DO.',
			'settings.accounts.loginNoResponse' => 'THIS DEVICE HASN\'T HEARD BACK FROM THE SIGN-IN YET. IF YOU ALREADY FINISHED IN YOUR BROWSER, CANCEL AND TRY CONNECTING AGAIN.',
			'settings.accounts.relayLoginNotOpened' => 'HAM2K LOGGER COULD NOT OPEN YOUR BROWSER AUTOMATICALLY. USE THE BUTTON BELOW TO OPEN THE LOGIN PAGE YOURSELF.',
			'settings.accounts.relayLoginUnavailable' => 'COULDN\'T REACH THE SYNC SERVER NEEDED TO COMPLETE THIS LOGIN. CHECK YOUR CONNECTION AND TRY AGAIN.',
			'settings.accounts.loginIncompleteResponse' => 'THAT LOGIN ATTEMPT DIDN\'T COMPLETE CORRECTLY. PLEASE TRY CONNECTING AGAIN.',
			'settings.accounts.noKeyringTitle' => 'ACCOUNT LOGINS CAN’T BE SAVED',
			'settings.accounts.noKeyringText' => 'HAM2K LOGGER CAN’T REACH A KEYRING SERVICE ON THIS COMPUTER, SO ACCOUNT LOGINS CAN’T BE STORED OR READ — CONNECTING AN ACCOUNT WILL FAIL UNTIL THIS IS SORTED. INSTALL AND START **GNOME-KEYRING**, **KWALLET** OR **KEEPASSXC**, OR UNLOCK THE KEYRING YOU ALREADY HAVE, THEN RESTART. LOGGING, EXPORTS AND DATA FILES ARE UNAFFECTED; LOG SYNC STAYS OFF WHILE THIS LASTS.',
			'settings.accounts.noKeyringInline' => 'LOGINS CAN’T BE SAVED: THIS COMPUTER’S KEYRING CAN’T BE REACHED. INSTALL AND START GNOME-KEYRING, KWALLET OR KEEPASSXC, OR UNLOCK THE ONE YOU HAVE.',
			'settings.accounts.noSecureStorageInline' => 'LOGINS CAN’T BE SAVED: THIS COMPUTER’S SECURE STORAGE CAN’T BE REACHED.',
			'settings.station.title' => 'STATION CONFIGURATION & CAT CONTROL',
			'settings.station.none' => 'NO EQUIPMENT CONFIGURED',
			'settings.station.add' => 'ADD',
			'settings.station.addTitle' => 'ADD EQUIPMENT',
			'settings.station.searchHint' => 'SEARCH EQUIPMENT',
			'settings.station.noMatches' => 'NO EQUIPMENT MATCHES',
			'settings.station.detectedEquipment' => 'DETECTED EQUIPMENT',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'CAN\'T LISTEN FOR RADIOS: ${error}',
			'settings.station.edit' => 'EDIT EQUIPMENT',
			'settings.station.name' => 'NAME',
			'settings.station.nameDescription' => 'WHAT YOU CALL IT — "LEFT RADIO". OPTIONAL.',
			'settings.station.transport' => 'CONNECTION',
			'settings.station.host' => 'ADDRESS',
			'settings.station.hostDescription' => 'THE RADIO\'S HOSTNAME OR IP ADDRESS ON YOUR NETWORK.',
			'settings.station.port' => 'PORT',
			'settings.station.hostRequired' => 'AN ADDRESS IS REQUIRED',
			_ => null,
		} ?? switch (path) {
			'settings.station.portInvalid' => 'PORT MUST BE BETWEEN 1 AND 65535',
			'settings.station.connect' => 'CONNECT',
			'settings.station.disconnect' => 'DISCONNECT',
			'settings.station.remove' => 'REMOVE',
			'settings.station.removeTitle' => ({required Object name}) => 'REMOVE ${name}?',
			'settings.station.removeMessage' => 'THIS ONLY REMOVES IT FROM THE APP. THE EQUIPMENT\'S SETTINGS STAY AS THEY ARE.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'UNRECOGNIZED EQUIPMENT TYPE "${typeKey}"',
			'settings.station.report' => 'REPORT',
			'settings.station.reportTitle' => 'REPORT THIS RADIO',
			'settings.station.reportIntro' => 'TELL US WHAT RADIO THIS REALLY IS AND HOW IT WENT. YOUR REPORT BECOMES A CARD THE HAM2K TEAM READS, AND WHAT YOU WRITE ABOUT GETTING IT WORKING MAY END UP HELPING THE NEXT OPERATOR WITH THE SAME RIG.',
			'settings.station.reportManufacturer' => 'MANUFACTURER',
			'settings.station.reportManufacturerDescription' => 'WHO MAKES IT — ICOM, YAESU, KENWOOD, ELECRAFT…',
			'settings.station.reportManufacturerRequired' => 'A MANUFACTURER IS REQUIRED',
			'settings.station.reportModel' => 'MODEL',
			'settings.station.reportModelDescription' => 'THE MODEL, AS THE RADIO ITSELF CALLS IT — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'A MODEL IS REQUIRED',
			'settings.station.reportOutcome' => 'HOW DID IT GO?',
			'settings.station.reportOutcomeWorks' => 'WORKED WELL',
			'settings.station.reportOutcomeIssues' => 'WORKED, WITH ISSUES',
			'settings.station.reportOutcomeFails' => 'DIDN\'T WORK AT ALL',
			'settings.station.reportOutcomeRequired' => 'PLEASE TELL US HOW IT WENT',
			'settings.station.reportComments' => 'COMMENTS',
			'settings.station.reportCommentsPlaceholder' => 'WHAT WORKED, WHAT DIDN\'T, ANYTHING THAT SURPRISED YOU.',
			'settings.station.reportHints' => 'TROUBLESHOOTING HINTS',
			'settings.station.reportHintsPlaceholder' => 'WANT TO SUGGEST SOME TROUBLESHOOTING HINTS FOR OTHER USERS?',
			'settings.station.reportSend' => 'SEND REPORT',
			'settings.station.reportSending' => 'SENDING YOUR REPORT…',
			'settings.station.reportSent' => ({required Object ref}) => 'THANKS — YOUR REPORT WAS FILED AS ${ref}.',
			'settings.station.reportSentNoRef' => 'THANKS — YOUR REPORT WAS SENT.',
			'settings.station.reportFailed' => ({required Object error}) => 'THE REPORT WASN\'T SENT: ${error}',
			'settings.station.troubleshootingNotes' => 'TROUBLESHOOTING NOTES',
			'settings.station.mainVfo' => 'MAIN VFO',
			'settings.station.useAsMainVfo' => 'USE AS MAIN VFO',
			'settings.station.serialPort' => 'SERIAL PORT',
			'settings.station.serialPortDescription' => 'THE PORT THE RADIO\'S CAT INTERFACE APPEARS ON.',
			'settings.station.serialPortNone' => 'NO SERIAL PORTS FOUND',
			'settings.station.serialPortRequired' => 'CHOOSE A SERIAL PORT',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'PORT ${n} OF ${total}',
			'settings.station.serialPortSuggested' => 'SUGGESTED',
			'settings.station.serialPortJustNow' => 'RECENTLY CONNECTED',
			'settings.station.serialDeviceRequest' => 'ADD A USB DEVICE…',
			'settings.station.bleDevice' => 'BLUETOOTH LE DEVICE',
			'settings.station.bleDeviceDescription' => 'THE SERIAL BRIDGE YOUR RADIO IS CONNECTED THROUGH, SUCH AS A LINK500MP IN ITS IOS MODE OR A BLE SERIAL ADAPTER.',
			'settings.station.bleScan' => 'SCAN FOR BLUETOOTH LE DEVICES…',
			'settings.station.bleScanNoneFound' => 'NO BLUETOOTH LE DEVICES FOUND. CHECK THAT THE BRIDGE IS ON, NEARBY, AND IN ITS BLUETOOTH LE (IOS) MODE.',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'THE BLUETOOTH LE SCAN COULD NOT RUN: ${reason}',
			'settings.station.bleOff' => 'BLUETOOTH IS TURNED OFF.',
			'settings.station.bleDenied' => 'BLUETOOTH PERMISSION WAS NOT GRANTED. ALLOW IT IN SYSTEM SETTINGS, THEN TRY AGAIN.',
			'settings.station.bleUnsupported' => 'THIS DEVICE HAS NO BLUETOOTH LE.',
			'settings.station.bleStarting' => 'BLUETOOTH IS STILL STARTING UP. TRY AGAIN IN A MOMENT.',
			'settings.station.bleConnectFailed' => 'CANNOT REACH THE BLUETOOTH LE DEVICE. CHECK THAT IT\'S ON, NEARBY, AND NOT CONNECTED TO ANOTHER APP.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'THIS BLUETOOTH LE DEVICE HAS NO SERIAL SERVICE THE APP RECOGNIZES. PLEASE REPORT IT WITH ITS SERVICES: ${services}',
			'settings.station.baudRate' => 'SPEED (BAUD)',
			'settings.station.baudRateDescription' => 'MUST MATCH THE RADIO\'S CAT MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE AND NO ERROR.',
			'settings.station.serialRtsHigh' => 'HOLD RTS HIGH',
			'settings.station.serialRtsHighDescription' => 'ONLY FOR A RADIO THAT WAITS FOR RTS BEFORE RESPONDING, SUCH AS A YAESU WITH CAT RTS TURNED ON. ON A DIGIRIG, SIGNALINK AND MOST HOME-MADE CABLES RTS IS PTT, AND HOLDING IT HIGH TRANSMITS.',
			'settings.station.serialDtrHigh' => 'HOLD DTR HIGH',
			'settings.station.serialDtrHighDescription' => 'ONLY FOR A CAT INTERFACE THAT DRAWS ITS POWER FROM DTR, SUCH AS SOME RS-232 CABLES FOR THE FT-817. ON MANY CABLES DTR KEYS CW OR PTT, AND HOLDING IT HIGH TRANSMITS.',
			'settings.station.civAddress' => 'RADIO CI-V ADDRESS',
			'settings.station.civAddressDescription' => 'HEX, AS SHOWN IN THE RADIO\'S CI-V MENU. THE IC-705 SHIPS AS A4.',
			'settings.station.civAddressInvalid' => 'A CI-V ADDRESS IS TWO HEX DIGITS, 01 TO FF',
			'settings.station.flexSlice' => 'SLICE',
			'settings.station.flexSliceDescription' => 'WHICH OF THE RADIO\'S SLICES THIS CONNECTION READS FROM AND TUNES.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'SLICE ${letter}',
			'settings.station.flexSliceInvalid' => 'PICK ONE OF THE RADIO\'S SLICES, A THROUGH H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'SLICE ${letter} IS NOT IN USE ON THIS RADIO — PICK ANOTHER SLICE, OR CREATE IT IN SMARTSDR',
			'settings.station.channelNotInUse' => 'NOT IN USE',
			'settings.station.channelHeldByUnknown' => 'IN USE BY ANOTHER PROGRAM',
			'settings.station.flexNoSlices' => 'THIS RADIO HAS NOT REPORTED ANY SLICES — CHECK THAT SMARTSDR IS RUNNING AND THAT THIS CLIENT MAY SUBSCRIBE',
			'settings.station.spectrumUnsupported' => 'THIS RADIO SENDS NO SPECTRUM OVER CAT',
			'settings.station.spectrumRequiresBaud' => 'REQUIRES CAT AT 115200 BPS',
			'settings.station.spectrumNoRadio' => 'NO RADIO CONNECTED',
			'settings.station.spectrumWaiting' => 'WAITING FOR THE RADIO\'S SPECTRUM…',
			'settings.station.spectrumUnavailable' => 'SPECTRUM DISPLAY IS NOT AVAILABLE',
			'settings.station.spectrumNoDaxChannel' => 'EVERY DAX IQ CHANNEL ON THIS RADIO IS IN USE',
			'settings.station.spectrumNoPanadapter' => 'THIS SLICE HAS NO PANADAPTER ON THE RADIO',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'THE RADIO REFUSED A DAX IQ STREAM (ERROR ${code})',
			'settings.station.spectrumNoUdp' => 'THE RADIO\'S SPECTRUM DATA CANNOT REACH THIS DEVICE',
			'settings.station.spectrumK4Unavailable' => 'CANNOT RECEIVE THE K4’S LAN SPECTRUM. RETRYING…',
			'settings.station.spectrumK4RemoteUnavailable' => 'CANNOT RECEIVE THE K4’S REMOTE SPECTRUM',
			'settings.station.spectrumScopeRefused' => 'THE RADIO REFUSED ITS SCOPE COMMANDS',
			'settings.station.spectrumOutOfRange' => 'THE RADIO\'S SCOPE IS SET OUTSIDE THE RANGE IT CAN SHOW',
			'settings.station.spectrumBandUnsupported' => 'THE RADIO\'S SCOPE CANNOT BE SHOWN ON THIS BAND',
			'settings.station.spectrumSdrNoRadio' => 'WAITING FOR THE LINKED RADIO\'S FREQUENCY…',
			'settings.station.spectrumSdrNotConnected' => 'THE SDR IS NOT CONNECTED',
			'settings.station.spectrumSdrNoIf' => 'SET THE RADIO\'S IF FREQUENCY IN THIS SDR\'S SETTINGS',
			'settings.station.sdrRadio' => 'SHOWS THE SPECTRUM FOR',
			'settings.station.sdrRadioDescription' => 'A SPECTRUM DISPLAY ON THIS RADIO DRAWS FROM THIS RECEIVER INSTEAD OF THE RADIO\'S OWN SCOPE.',
			'settings.station.sdrRadioMain' => 'THE MAIN RADIO',
			'settings.station.sdrTuning' => 'ANTENNA INPUT',
			'settings.station.sdrTuningDescription' => 'WHERE THE RECEIVER\'S SIGNAL COMES FROM. ON ITS OWN ANTENNA IT TUNES ITSELF TO FOLLOW THE RADIO; ON THE RADIO\'S IF OUTPUT IT STAYS ON THE IF.',
			'settings.station.sdrTuningIndependent' => 'ITS OWN ANTENNA',
			'settings.station.sdrTuningIfTap' => 'THE RADIO\'S IF OUTPUT',
			'settings.station.sdrIfHz' => 'IF FREQUENCY (HZ)',
			'settings.station.sdrIfHzDescription' => 'FOR AN IF OUTPUT ONLY: THE FREQUENCY THE RADIO\'S DIAL SITS AT ON ITS IF, SUCH AS 68330000 ON AN FT-817.',
			'settings.station.sdrIfInverted' => 'IF IS INVERTED',
			'settings.station.sdrGainDb' => 'GAIN (DB)',
			'settings.station.sdrGainDbDescription' => 'LEAVE BLANK FOR THE RECEIVER\'S AUTOMATIC GAIN.',
			'settings.station.sdrOffsetHz' => 'FREQUENCY OFFSET (HZ)',
			'settings.station.sdrOffsetHzDescription' => 'ADDED TO EVERY FREQUENCY SENT TO THE RECEIVER, FOR AN UPCONVERTER: 125000000 FOR A HAM IT UP.',
			'settings.station.sdrPpm' => 'FREQUENCY CORRECTION (PPM)',
			'settings.station.rtlDirectSampling' => 'DIRECT SAMPLING',
			'settings.station.rtlDirectSamplingDescription' => 'FOR HF ON AN RTL-SDR V3 WITHOUT AN UPCONVERTER. AN RTL-SDR V4 REACHES HF WITHOUT IT.',
			'settings.station.rtlDirectSamplingOff' => 'OFF',
			'settings.station.rtlDirectSamplingI' => 'I BRANCH',
			'settings.station.rtlDirectSamplingQ' => 'Q BRANCH',
			'settings.station.rtlTcpNotAServer' => 'THIS IS NOT AN RTL_TCP SERVER',
			'settings.station.rtlTcpNotes' => 'THIS CONNECTS TO AN **RTL_TCP SERVER YOU RUN YOURSELF** ON THE COMPUTER THE DONGLE IS PLUGGED INTO.\n\n- **START IT** WITH `rtl_tcp -a 0.0.0.0` SO OTHER MACHINES CAN REACH IT; ON THE SAME MACHINE, `rtl_tcp` ALONE WILL DO.\n- **PORT** IS 1234 UNLESS YOU STARTED IT WITH `-p`.\n- **ONE PROGRAM AT A TIME:** RTL_TCP SERVES A SINGLE CLIENT. THE APP CONNECTS ONLY WHILE A SPECTRUM DISPLAY IS SHOWING, AND LETS GO A FEW SECONDS AFTER IT CLOSES.\n- **ON ANDROID**, THE *SDR DRIVER* APP RUNS THE SAME SERVER ON THE PHONE.',
			'settings.station.rspTcpNotes' => 'THIS CONNECTS TO AN **RSP_TCP SERVER YOU RUN YOURSELF** ON THE COMPUTER THE RSP IS PLUGGED INTO, WITH SDRPLAY\'S API INSTALLED THERE.\n\n- **START IT** WITH `rsp_tcp -a 0.0.0.0`.\n- **PORT** IS 1234 UNLESS YOU STARTED IT WITH `-p`.\n- **ONE PROGRAM AT A TIME:** THE SERVER TAKES A SINGLE CLIENT. THE APP CONNECTS ONLY WHILE A SPECTRUM DISPLAY IS SHOWING.',
			'settings.station.n3fjpNoRig' => 'N3FJP HAS NO RADIO INTERFACE SET UP, SO THIS FOLLOWS WHAT IS TYPED INTO N3FJP, NOT A RADIO',
			'settings.station.winkeyerKeyPort' => 'KEY OUTPUT',
			'settings.station.winkeyerKeyPortDescription' => 'WHICH OF THE KEYER\'S TWO OUTPUT JACKS YOUR RADIO IS PLUGGED INTO.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'PORT ${n}',
			'settings.station.winkeyerPtt' => 'USE THE KEYER\'S PTT',
			'settings.station.winkeyerPttDescription' => 'KEY THE PTT LINE ON THE SAME JACK, FOR AN AMPLIFIER OR A RADIO THAT NEEDS IT. LEAVE OFF FOR A RADIO KEYED ON ITS KEY JACK.',
			'settings.station.winkeyerNoAnswer' => 'NO WINKEYER RESPONDED ON THIS PORT',
			'settings.station.winkeyerStoppedAnswering' => 'THE WINKEYER STOPPED RESPONDING WHILE SENDING; THE MESSAGE WAS DROPPED',
			'settings.station.icomControlPort' => 'CONTROL PORT (UDP)',
			'settings.station.icomControlPortDescription' => 'THE RADIO\'S CONTROL PORT (UDP) — 50001 UNLESS CHANGED IN ITS NETWORK SETTINGS, OR FORWARDED TO ANOTHER.',
			'settings.station.icomSerialPort' => 'SERIAL PORT (UDP)',
			'settings.station.icomSerialPortDescription' => 'THE RADIO\'S SERIAL PORT (UDP) — 50002 UNLESS CHANGED IN ITS NETWORK SETTINGS, OR FORWARDED TO ANOTHER.',
			'settings.station.icomPortsDiffer' => 'THE CONTROL AND SERIAL PORTS MUST DIFFER',
			'settings.station.radioUser' => 'RADIO USERNAME',
			'settings.station.radioPass' => 'RADIO PASSWORD',
			'settings.station.radioLoginDescription' => 'THE RADIO\'S NETWORK → REMOTE LOGIN, NOT YOUR WIFI PASSWORD.',
			'settings.station.radioUserRequired' => 'THE RADIO\'S REMOTE-CONTROL USERNAME IS REQUIRED',
			'settings.station.connectFailedBusy' => 'DEVICE IS IN USE',
			'settings.station.connectFailedDenied' => 'ACCESS DENIED',
			'settings.station.connectFailedDevice' => 'DEVICE NOT FOUND',
			'settings.station.connectFailedLines' => 'RTS/DTR COULD NOT BE HELD AS SET, SO THE PORT WAS CLOSED. ANOTHER PROGRAM MAY HAVE LEFT HARDWARE HANDSHAKING ON — UNPLUG AND REPLUG THE CABLE.',
			'settings.station.connectFailedNetwork' => 'CANNOT FIND THE RADIO OVER THE NETWORK. CHECK ITS ADDRESS AND THAT IT\'S POWERED ON AND REACHABLE.',
			'settings.station.connectFailedTimeout' => 'THE RADIO DIDN\'T RESPOND IN TIME. CHECK IT\'S POWERED ON AND REACHABLE.',
			'settings.station.models.flexRadio' => 'FLEXRADIO (SMARTSDR)',
			'settings.station.models.ft891' => 'YAESU FT-891',
			'settings.station.models.ft991a' => 'YAESU FT-991/A',
			'settings.station.models.ft710' => 'YAESU FT-710',
			'settings.station.models.ftdx10' => 'YAESU FTDX10',
			'settings.station.models.ftx1' => 'YAESU FTX-1',
			'settings.station.models.ft817' => 'YAESU FT-817 / FT-818',
			'settings.station.models.ft857' => 'YAESU FT-857',
			'settings.station.models.ft897' => 'YAESU FT-897',
			'settings.station.models.ft450' => 'YAESU FT-450 / FT-450D',
			'settings.station.models.q900' => 'GUOHETEC Q900',
			'settings.station.models.tenTecEagle' => 'TEN-TEC EAGLE (599)',
			'settings.station.models.tenTecOrion' => 'TEN-TEC ORION (565)',
			'settings.station.models.tenTecOrionII' => 'TEN-TEC ORION II (566)',
			'settings.station.models.sotacat' => 'SOTACAT (ELECRAFT KX2/KX3)',
			'settings.station.models.yaesuGeneric' => 'YAESU - GENERIC',
			'settings.station.models.icomGeneric' => 'ICOM - GENERIC',
			'settings.station.models.kenwoodGeneric' => 'KENWOOD - GENERIC',
			'settings.station.models.ts590sg' => 'KENWOOD TS-590SG',
			'settings.station.models.ts480' => 'KENWOOD TS-480',
			'settings.station.models.qmx' => 'QRP LABS QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'LAB599 TX-500',
			'settings.station.models.tx500mp' => 'LAB599 TX-500MP',
			'settings.station.models.qcx' => 'QRP LABS QCX',
			'settings.station.models.elecraftGeneric' => 'ELECRAFT - GENERIC',
			'settings.station.models.kx2' => 'ELECRAFT KX2',
			'settings.station.models.kx3' => 'ELECRAFT KX3',
			'settings.station.models.k4' => 'ELECRAFT K4',
			'settings.station.models.ic705' => 'ICOM IC-705',
			'settings.station.models.ic7300' => 'ICOM IC-7300',
			'settings.station.models.ic7300mk2' => 'ICOM IC-7300 MK2',
			'settings.station.models.ic706mkiig' => 'ICOM IC-706MKIIG',
			'settings.station.models.ic7100' => 'ICOM IC-7100',
			'settings.station.models.ic7610' => 'ICOM IC-7610',
			'settings.station.models.ic7760' => 'ICOM IC-7760',
			'settings.station.models.ic9700' => 'ICOM IC-9700',
			'settings.station.models.ic905' => 'ICOM IC-905',
			'settings.station.models.ic7850' => 'ICOM IC-7850',
			'settings.station.models.ic7851' => 'ICOM IC-7851',
			'settings.station.models.x6100' => 'XIEGU X6100',
			'settings.station.models.g90' => 'XIEGU G90',
			'settings.station.models.rigctld' => 'RADIO CONTROLLED VIA RIGCTLD',
			'settings.station.models.rigctldNodeName' => 'MY RADIO (VIA RIGCTLD)',
			'settings.station.models.flrig' => 'RADIO CONTROLLED VIA FLRIG',
			'settings.station.models.flrigNodeName' => 'MY RADIO (VIA FLRIG)',
			'settings.station.models.hrd' => 'RADIO CONTROLLED VIA HAM RADIO DELUXE®',
			'settings.station.models.hrdNodeName' => 'MY RADIO (VIA HRD)',
			'settings.station.models.n3fjp' => 'RADIO CONTROLLED VIA N3FJP',
			'settings.station.models.n3fjpNodeName' => 'MY RADIO (VIA N3FJP)',
			'settings.station.models.commander' => 'RADIO CONTROLLED VIA DXLAB COMMANDER',
			'settings.station.models.commanderNodeName' => 'MY RADIO (VIA COMMANDER)',
			'settings.station.models.antenna' => 'ANTENNA',
			'settings.station.models.key' => 'CW KEY',
			'settings.station.models.winkeyer' => 'WINKEYER',
			'settings.station.models.placeholderRadio' => 'GENERIC RADIO (PLACEHOLDER)',
			'settings.station.models.placeholderRadioNodeName' => 'MY RADIO',
			'settings.station.models.antennaGenius' => '4O3A ANTENNA GENIUS',
			'settings.station.models.sierraCoax' => 'SIERRA RADIO CX-1 COAX SWITCH',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'NOOELEC NESDR',
			'settings.station.models.sdrplay' => 'SDRPLAY RSP',
			'settings.station.transports.network' => 'NETWORK/WIFI',
			'settings.station.transports.secureNetwork' => 'SECURE NETWORK/WIFI',
			'settings.station.transports.usbSerial' => 'USB SERIAL',
			'settings.station.transports.wifi' => 'NETWORK/WIFI',
			'settings.station.transports.bluetoothSerial' => 'BLUETOOTH SERIAL',
			'settings.station.transports.bleSerial' => 'BLUETOOTH LE',
			'settings.station.transports.placeholder' => 'PLACEHOLDER',
			'settings.station.troubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.ft891Troubleshooting' => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **CAT RTS OFF AT THE RADIO, OR HOLD RTS HIGH ON.** WITH **CAT RTS** ON (FT-891 MENU **05-08**), THE RADIO STAYS SILENT WHILE RTS IS LOW — IT MAY ANSWER ONCE AS THE PORT OPENS, THEN NOTHING. PICKING THE RADIO\'S OWN USB PORT TURNS ON **HOLD RTS HIGH** UNDER ADVANCED SETTINGS. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES RTS IS PTT, AND HOLDING IT HIGH KEYS YOUR TRANSMITTER: TURN CAT RTS OFF AT THE RADIO INSTEAD.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE (MENU **05-06**). WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.yaesuBinaryTroubleshooting' => 'THIS RADIO SPEAKS YAESU\'S OLDER FIVE-BYTE CAT, AND IT DOES NOT RESPOND AT ALL WHEN SOMETHING IS OFF. ALMOST ALWAYS ONE OF:\n\n- **THE CABLE MUST CONVERT LEVELS.** THE CAT JACK ON THE BACK IS NOT RS-232 AND NOT USB; IT NEEDS A CT-62 OR AN EQUIVALENT ADAPTER. A PLAIN AUDIO OR DATA CABLE WON\'T WORK FOR CAT.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU (**#14** ON AN FT-817, **#19** ON AN FT-857 OR FT-897). WITH A MISMATCH, THE RADIO SENDS NOTHING BACK, AND NEVER AN ERROR.\n- **NEVER LET ANYTHING RAISE RTS OR DTR ON THIS PORT.** ON MOST CABLES FOR THESE RADIOS THOSE LINES ARE PTT AND KEYING. AN OLDER INTERFACE POWERED FROM DTR IS THE EXCEPTION: TURN ON **HOLD DTR HIGH** UNDER ADVANCED SETTINGS FOR THAT ONE.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS DRIVER WAS WRITTEN FROM YAESU\'S PUBLISHED CAT CHART AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.tenTecTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.tenTecEagleTroubleshooting' => '- **THE USB-B PORT ON THE BACK IS THE CAT LINK.** THE RADIO SHOWS UP AS A USB SERIAL PORT; ON WINDOWS IT NEEDS TEN-TEC\'S USB TO UART DRIVER, WHICH APPEARS IN DEVICE MANAGER AS "USB TO UART (COMX)".\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN, AND SO DOES TEN-TEC\'S FIRMWARE UPDATER.\n- **SETTING THE FILTER WIDTH FROM THE APP TAKES IT AWAY FROM THE BW KNOB** UNTIL THE RADIO IS SWITCHED OFF AND ON AGAIN. THAT IS HOW THE RADIO WORKS.\n\nTHIS DRIVER WAS WRITTEN FROM TEN-TEC\'S PROGRAMMER\'S REFERENCE GUIDE. IF IT HALF-WORKS, THAT IS WORTH REPORTING, WITH THE FIRMWARE VERSION FROM THE RADIO\'S MENU.',
			'settings.station.tenTecOrionTroubleshooting' => '- **USE A STRAIGHT-THROUGH DB-9 SERIAL CABLE** TO THE SERIAL DATA PORT, NOT A NULL-MODEM ONE.\n- **THIS ENTRY HOLDS RTS HIGH**, BECAUSE THE ORION USES RTS AND CTS AS ITS HANDSHAKE. ON AN INTERFACE THAT KEYS PTT FROM RTS, SUCH AS A DIGIRIG, TURN OFF HOLD RTS HIGH UNDER ADVANCED SETTINGS, OR THE RADIO TRANSMITS AS SOON AS THE APP CONNECTS.\n- **CW FROM THE APP NEEDS THE RADIO\'S INTERNAL KEYER ON.** WITH IT OFF, THE RADIO IGNORES WHAT THE APP SENDS.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS DRIVER WAS WRITTEN FROM TEN-TEC\'S PROGRAMMER\'S REFERENCE GUIDE AND HAS NOT BEEN RUN AGAINST AN ORION. IF IT HALF-WORKS, THAT IS WORTH REPORTING, WITH THE FIRMWARE VERSION FROM THE RADIO\'S MENU.',
			'settings.station.tenTecNoCw' => 'THIS RADIO\'S FIRMWARE DOES NOT TAKE CW FROM THE APP. TEN-TEC ADDED IT IN ORION FIRMWARE 1.366.',
			'settings.station.tenTecKeyerOff' => 'THE RADIO\'S INTERNAL KEYER IS OFF, SO IT IGNORES CW SENT FROM THE APP. TURN THE KEYER ON IN THE RADIO\'S MENU.',
			'settings.station.guohetecTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.guohetecTroubleshooting' => 'THE Q900 HAS TWO CAT PROTOCOLS, AND THIS ENTRY USES ITS NATIVE ONE RATHER THAN THE FT-817 IMITATION. PICK **GUOHETEC Q900** HERE, NOT AN FT-817 — THE IMITATION SUPPORTS FEWER COMMANDS, AND THE RADIO DOES NOT SAY WHICH ONE IT IS USING.\n\n- **THE USB-C CABLE IS THE CAT LINK**, AND IT CONNECTS THE SOUND CARD TOO. SPEED DOES NOT MATTER ON IT; THE PORT IGNORES WHATEVER IT IS SET TO.\n- **NEVER LET ANYTHING RAISE RTS OR DTR ON THIS PORT.** ON A SERIAL CABLE THOSE LINES ARE PTT AND KEYING.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **A SECOND-GENERATION RADIO BEHAVES DIFFERENTLY** FROM A FIRST. LONG PRESS MENU, THEN ABOUT: HW 2.0 IS THE SECOND GENERATION.\n\nTHIS DRIVER WAS WRITTEN FROM THE MANUFACTURER\'S PUBLISHED PROTOCOL AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.yaesuTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.yaesuTroubleshooting' => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **CAT RTS MUST BE OFF AT THE RADIO.** WITH IT ON, THE RADIO WAITS FOR A HANDSHAKE LINE THE APP KEEPS LOW. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES THAT SAME LINE IS PTT, SO RAISING IT WOULD KEY YOUR TRANSMITTER. ON THE RADIO\'S OWN USB PORT, **HOLD RTS HIGH** UNDER ADVANCED SETTINGS IS THE ALTERNATIVE. WHERE THAT SETTING LIVES DIFFERS BY MODEL (MENU **05-08** ON AN FT-891).\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **MODES FOLLOW THE FT-891\'S TABLE.** MOST OF THE YAESU LINE MATCHES IT, BUT A RADIO THAT NUMBERS ITS MODES DIFFERENTLY WILL SHOW AND SET THE WRONG ONE FOR THOSE. THE FREQUENCY IS UNAFFECTED.',
			'settings.station.yaesuRs232Troubleshooting' => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **THE CAT JACK IS RS-232.** IT NEEDS A USB-TO-SERIAL ADAPTER AND A STRAIGHT-THROUGH DB-9 CABLE — A NULL-MODEM CABLE SWAPS THE LINES, AND THE RADIO NEVER HEARS A THING.\n- **CAT RTS MUST BE OFF AT THE RADIO.** WITH IT ON, THE RADIO WAITS FOR A HANDSHAKE LINE THE APP KEEPS LOW UNLESS **HOLD RTS HIGH** IS ON UNDER ADVANCED SETTINGS.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\nTHIS ENTRY WAS WRITTEN FROM PUBLISHED CAT DOCUMENTATION AND HAS NOT BEEN RUN AGAINST ONE OF THESE RADIOS. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.yaesuUsbTroubleshooting' => 'THE RADIO IS RECEIVING COMMANDS BUT NOT RESPONDING. ALMOST ALWAYS ONE OF:\n\n- **USE THE FIRST OF THE RADIO\'S TWO USB PORTS.** CAT IS NORMALLY ON THE FIRST (THE **ENHANCED** COM PORT ON WINDOWS); THE SECOND (**STANDARD**) IS FOR PTT AND KEYING. THE PICKER POINTS AT THE FIRST WHEREVER IT CAN TELL THE TWO APART.\n- **CAT RTS OFF AT THE RADIO, OR HOLD RTS HIGH ON.** WITH THE RADIO\'S **CAT RTS** MENU ON, IT STAYS SILENT WHILE RTS IS LOW — IT MAY ANSWER ONCE AS THE PORT OPENS, THEN NOTHING. PICKING THE RADIO\'S OWN USB PORT TURNS ON **HOLD RTS HIGH** UNDER ADVANCED SETTINGS. ON A DIGIRIG, SIGNALINK OR MOST HOME-BREW CABLES RTS IS PTT, AND HOLDING IT HIGH KEYS YOUR TRANSMITTER: TURN CAT RTS OFF AT THE RADIO INSTEAD.\n- **SPEED MUST MATCH** THE RADIO\'S CAT RATE MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.',
			'settings.station.k4SerialNotes' => 'CONNECT THE K4’S REAR USB-B (PC) SOCKET. EITHER USB-PC1 OR USB-PC2 WORKS FOR CAT; CHOOSE AN UNUSED PORT AND MATCH ITS SERIAL USB-PCN: BAUD RATE SETTING ON THE RADIO. HALO PREFILLS 38400; CHANGE IT IF NEEDED. ANOTHER APPLICATION MUST USE THE OTHER PORT OR ETHERNET.\n\nTHIS CONNECTION CONTROLS THE RADIO AND ITS KEYERS; IT DOES NOT SEND AUDIO TO HALO.',
			'settings.station.k4TcpNotes' => 'CONNECT THE K4’S ETHERNET SOCKET TO YOUR LOCAL NETWORK. ENTER ITS HOSTNAME OR IP ADDRESS AND CAT PORT 9200. HALO USES THE SAME HOST ON FIXED PORT 9201 WHEN A PANADAPTER OR WATERFALL IS VISIBLE; CHANGING THE CAT PORT DOES NOT CHANGE THE SPECTRUM PORT.\n\nTHE SPECTRUM SHOWS THE MAIN RECEIVER. ITS ZOOM, REFERENCE ADJUSTMENT AND SPEED CONTROLS AFFECT ONLY HALO’S DISPLAY. AUDIO STREAMING IS NOT SUPPORTED.',
			'settings.station.k4PowerTimeout' => 'K4 POWER WAS NOT CHANGED BECAUSE THE RADIO DID NOT CONFIRM ITS OUTPUT RANGE. TRY AGAIN.',
			'settings.station.k4RemoteNotes' => 'ENABLE REMOTE ACCESS ON YOUR K4 AND ENTER ITS NETWORK PASSWORD. MAIN AND SUB SHARE ONE ENCRYPTED CONNECTION FOR RADIO CONTROL AND SPECTRUM. THE DEFAULT PORT IS 9204; ENTER YOUR FORWARDED PORT WHEN CONNECTING REMOTELY.\n\nAUDIO PLAYBACK AND MICROPHONE STREAMING ARE NOT SUPPORTED.',
			'settings.station.k4Receiver' => 'RECEIVER',
			'settings.station.k4ReceiverMain' => 'MAIN',
			'settings.station.k4ReceiverSub' => 'SUB',
			'settings.station.k4ReceiverInvalid' => 'CHOOSE MAIN OR SUB',
			'settings.station.k4ReceiverAlreadyConfigured' => 'THAT RECEIVER IS ALREADY CONFIGURED FOR THIS K4',
			'settings.station.k4SubReceiverOff' => 'THE K4 SUB RECEIVER IS OFF',
			'settings.station.k4RemotePasswordRequired' => 'ENTER THE K4’S NETWORK PASSWORD TO CONNECT SECURELY.',
			'settings.station.k4RemoteHandshakeFailed' => 'THE K4 COULD NOT ESTABLISH A SECURE CONNECTION. CHECK ITS NETWORK PASSWORD AND REMOTE ACCESS SETTINGS.',
			'settings.station.k4RemoteUnreachable' => 'THE K4’S SECURE CONNECTION COULD NOT BE REACHED. CHECK ITS ADDRESS, PORT AND REMOTE ACCESS SETTINGS.',
			'settings.station.k4PowerRange' => 'K4 POWER MUST BE 0.1–110 W, OR 0.0001–0.01 W WHEN THE TRANSVERTER MILLIWATT OUTPUT IS ACTIVE.',
			'settings.station.elecraftTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.elecraftTroubleshooting' => 'ELECRAFT RIGS SPEAK KENWOOD CAT, AND A KX2 AND A KX3 HAVE BOTH BEEN RUN THIS WAY — VFO IN BOTH DIRECTIONS, MODE SWITCHING AND CW ZERO-BEAT ALL WORKING.\n\nIF THE RADIO DOES NOT RESPOND, ALMOST ALWAYS ONE OF:\n\n- **SPEED MUST MATCH** THE RATE SET UNDER **RS232** IN THE RADIO\'S MENU. 38400 IS WHAT THESE SHIP ON. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n\n**IF THE FREQUENCY IS RIGHT BUT THE MODE IS WRONG**, TELL US. THE KX2 AND KX3 ENTRIES READ THE MODE FROM A POSITION IN THE RADIO\'S STATUS REPLY THAT WE HAVE PINNED FROM THE RIGS WE HAVE SEEN, AND A FIRMWARE THAT PUTS IT ELSEWHERE IS SOMETHING ONLY A REPORT REACHES US AS.\n\nTHE K3 HAS NOT BEEN REPORTED EITHER WAY, SO PLEASE SAY WHAT HAPPENS IF YOU RUN ONE. A K4 HAS ITS OWN ENTRY.',
			'settings.station.lab599TroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.lab599Troubleshooting' => 'THE TX-500 LINE SPEAKS KENWOOD CAT. WRITTEN FROM PUBLISHED REFERENCES RATHER THAN TESTED ON THE RADIO, SO PLEASE REPORT WHAT HAPPENS EITHER WAY.\n\n- **SPEED MUST MATCH** THE RADIO\'S CAT SETTING, 9600 UNLESS YOU CHANGED IT. WITH A MISMATCH THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **PICK THE CAT PROTOCOL ON THE RADIO.** TS-2000 COVERS FREQUENCY AND MODE. LAB599 ALSO LETS THE APP SWITCH THE RADIO TO DIG.\n- **THROUGH A LINK500MP**, PRESS AND HOLD THE VFO KNOB FOR ABOUT THREE SECONDS TO HAND CAT CONTROL TO THE INTERFACE.\n- **OVER BLUETOOTH ON A COMPUTER**, THE LINK500MP PAIRS AS TWO SERIAL PORTS AND ONLY ONE CARRIES CAT. IF THE RADIO STAYS SILENT, PICK THE OTHER.\n- **OVER BLUETOOTH LE**, AS ON AN IPHONE OR IPAD, SWITCH THE LINK500MP TO ITS IOS MODE FIRST. IN ITS OTHER MODES IT DOES NOT SHOW UP IN A SCAN.',
			'settings.station.kenwoodTroubleshootingTitle' => 'IF THE RADIO CONNECTS BUT SHOWS NO FREQUENCY',
			'settings.station.kenwoodTroubleshooting' => 'THIS DRIVER IS PROVEN AGAINST KENWOOD\'S TS-590SG AND TS-480, QRP LABS\' QMX AND QCX-MINI, AND ELECRAFT\'S KX2 AND KX3. THE REST OF THE LINE IS WRITTEN FROM PUBLISHED CAT REFERENCES, SO PLEASE REPORT WHAT HAPPENS EITHER WAY.\n\nIF THE RADIO DOES NOT RESPOND, ALMOST ALWAYS ONE OF:\n\n- **SPEED MUST MATCH** THE RADIO\'S CAT MENU. WITH A MISMATCH, THE RADIO SENDS BACK GARBAGE OR NOTHING, AND NEVER AN ERROR.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.\n- **SOME RIGS NEED CAT ENABLED** IN THE MENU BEFORE THEY RESPOND AT ALL.\n\n**SEVERAL SDR FRONT-ENDS SPEAK THIS SAME PROTOCOL**, SO THIS ENTRY IS WORTH TRYING FOR THOSE TOO; ELECRAFT RIGS ARE LISTED SEPARATELY, UNDER ELECRAFT. IF THE FREQUENCY IS RIGHT BUT THE MODE IS WRONG OR MISSING, THAT IS THE ONE PART THAT DIFFERS ACROSS THE LINE — THE APP WORKS IT OUT FROM THE RADIO AND FALLS BACK TO ASKING DIRECTLY, SO THE MODE MAY SIMPLY LAG.',
			'settings.station.statusConnected' => 'CONNECTED',
			'settings.station.statusLost' => 'DISCONNECTED',
			'settings.station.notConfigured' => 'NOT CONFIGURED',
			'settings.station.currentConfiguration' => 'CURRENT CONFIGURATION',
			'settings.station.currentTransceiver' => 'CURRENT TRANSCEIVER',
			'settings.station.radioMode' => 'RADIO MODE',
			'settings.station.keyerNotSupported' => 'NOT SUPPORTED BY CURRENT RADIO',
			'settings.station.catControlPreferences' => 'CAT CONTROL PREFERENCES',
			'settings.station.chooseTransceiver' => 'CHOOSE TRANSCEIVER',
			'settings.station.configurationSection' => 'CONFIGURATION',
			'settings.station.noTransceiverSelected' => 'NO TRANSCEIVER SELECTED',
			'settings.station.makeMainVfo' => ({required Object name}) => 'USE ${name} FOR THE MAIN VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, zero: 'NO TRANSCEIVERS', one: '${count} TRANSCEIVER', other: '${count} TRANSCEIVERS', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} ANTENNA', other: '${count} ANTENNAS', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} OTHER DEVICE', other: '${count} OTHER DEVICES', ), 
			'settings.station.equipmentInventory' => 'EQUIPMENT INVENTORY',
			'settings.station.equipmentInUse' => 'TRANSCEIVER CONTROLS',
			'settings.station.noTransceiver' => 'NONE',
			'settings.station.peerRadioNotAvailable' => 'NOT AVAILABLE',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'ON ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} IS ON ANOTHER DEVICE',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'THIS RADIO IS CONNECTED TO ${device}. ITS CONNECTION AND SETTINGS ARE CONFIGURED ON THAT DEVICE.',
			'settings.station.antennaInUse' => 'ANTENNA IN USE',
			'settings.station.keyInUse' => 'KEY IN USE',
			'settings.station.noneSelected' => 'NONE',
			'settings.station.moreSettings' => 'MORE SETTINGS',
			'settings.station.icomCivTroubleshootingTitle' => 'IF TWO SERIAL PORTS SHOW UP FOR THE SAME RADIO',
			'settings.station.icomCivTroubleshooting' => 'SEVERAL ICOM RADIOS, THE IC-705 AMONG THEM, PRESENT **TWO** USB SERIAL PORTS AT ONCE (ICOM CALLS THEM PORT A AND PORT B), BOTH SET TO CI-V BY DEFAULT. NEITHER THIS APP NOR YOUR OS CAN TELL THEM APART BEYOND THAT: THE SAME USB VENDOR/PRODUCT ID JUST SHOWS UP TWICE, SOMETIMES MARKED WITH A `#2` SUFFIX HERE. **PORT A IS USUALLY THE RIGHT ONE** — NORMALLY THE FIRST ONE YOUR OS OR BROWSER LISTS, AND WHERE THIS APP CAN TELL THE TWO PORTS APART IT MARKS THAT ONE AS SUGGESTED. IF COMMANDS GO OUT AND THE RADIO NEVER RESPONDS, TRY THE OTHER PORT NEXT.',
			'settings.station.civAddressTroubleshootingTitle' => 'IF THE RADIO NEVER RESPONDS',
			'settings.station.civAddressTroubleshooting' => '- **THE CI-V ADDRESS MUST MATCH** THE RADIO\'S MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH, BUT A RIG SHARING A CI-V BUS IS EXACTLY WHERE THAT GETS CHANGED. A FRAME SENT TO THE WRONG ADDRESS IS IGNORED IN SILENCE, WHICH LOOKS EXACTLY LIKE A DEAD CABLE.\n- **SPEED MUST MATCH** THE RADIO\'S CI-V BAUD RATE (ON USB, CI-V USB BAUD RATE). SET THE RADIO TO THE SAME NUMBER SHOWN HERE, **NOT AUTO**. ON AUTO SOME RADIOS, THE IC-7300 AMONG THEM, CONNECT AND THEN STOP RESPONDING AFTER A MINUTE OR SO.\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **THE CI-V ADDRESS MUST MATCH** THE RADIO\'S MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH, BUT A RIG SHARING A CI-V BUS IS EXACTLY WHERE THAT GETS CHANGED. A FRAME SENT TO THE WRONG ADDRESS IS IGNORED IN SILENCE, WHICH LOOKS EXACTLY LIKE A DEAD CABLE.\n${speed}\n- **ANOTHER APP MAY HOLD THE PORT**: WSJT-X, FLDIGI AND RIGCTLD ALL KEEP IT OPEN.',
			'settings.station.icomUsbSpeedFollows' => '- **THERE IS NO SPEED TO SET.** OVER USB THIS RADIO TALKS AT WHATEVER SPEED THE COMPUTER USES, AND THIS ENTRY ALWAYS USES 115200, THE SPEED THE SCOPE NEEDS.',
			'settings.station.ic7610UsbSpeed' => '- **SET CI-V USB BAUD RATE TO 115200**, THE SPEED THIS ENTRY ALWAYS USES, SINCE THE SCOPE NEEDS IT — **NOT AUTO**. A RADIO SET TO ANY OTHER SPEED ANSWERS WITH SILENCE.',
			'settings.station.ic7300Mk2Note' => '\n- THE **IC-7300 MK2** SHIPS ON ADDRESS `B6`, NOT THE `94` PREFILLED HERE — PICK THE IC-7300 MK2 ENTRY INSTEAD.',
			'settings.station.ic705PortNote' => '\n- THE **IC-705** PRESENTS TWO USB SERIAL PORTS, BOTH NAMED AFTER THE RADIO. CI-V IS ON THE **FIRST** OF THEM, WHICH THE PICKER POINTS AT WHEREVER IT CAN TELL THE TWO APART.',
			'settings.station.ic7760PortNote' => '\n- THE **IC-7760** SPEAKS CI-V ON **PORT A** OF THE TWO USB SERIAL PORTS IT PRESENTS.',
			'settings.station.x6100PortNote' => '\n- THE **X6100** SPEAKS CI-V ON ITS **DEV** PORT — THE SECOND OF THE TWO SERIAL PORTS IT PRESENTS, AND THE ONE THE PICKER POINTS AT.',
			'settings.station.rigctldTroubleshootingTitle' => 'IF THE APP CANNOT CONNECT',
			'settings.station.rigctldTroubleshooting' => 'THIS CONNECTS TO A **RIGCTLD DAEMON YOU RUN YOURSELF**, NOT TO THE RADIO DIRECTLY — HAMLIB\'S BACKEND TALKS TO THE RADIO AND SUPPORTS HUNDREDS OF MODELS.\n\n- **THE DAEMON MUST ALREADY BE RUNNING**, E.G. `rigctld -m 1035 -r /dev/ttyUSB0`. FIND YOUR RADIO\'S MODEL NUMBER WITH `rigctl -l`.\n- **FROM ANOTHER MACHINE**, START IT WITH `-T 0.0.0.0`: BY DEFAULT RIGCTLD ONLY ACCEPTS CONNECTIONS FROM THE MACHINE IT RUNS ON.\n- **PORT** IS 4532 UNLESS YOU STARTED THE DAEMON WITH `-t`.\n- ONCE CONNECTED, A MISSING FREQUENCY USUALLY MEANS THE DAEMON ITSELF CANNOT REACH THE RADIO. TEST IT WITH `rigctl -m 2 f` ON THE DAEMON\'S MACHINE.',
			'settings.station.flrigTroubleshootingTitle' => 'IF THE APP CANNOT CONNECT',
			'settings.station.flrigTroubleshooting' => 'THIS CONNECTS TO AN **FLRIG PROGRAM YOU RUN YOURSELF**, NOT TO THE RADIO DIRECTLY — FLRIG TALKS TO THE RADIO AND SUPPORTS MOST MAKES AND MODELS.\n\n- **FLRIG MUST ALREADY BE RUNNING**, WITH ITS TRANSCEIVER CONFIGURED AND CONNECTED.\n- **PORT** IS 12345 UNLESS YOU CHANGED IT IN FLRIG\'S CONFIGURATION (CONFIG → SETUP → SERVER).\n- **FROM ANOTHER MACHINE**, MAKE SURE FLRIG\'S SERVER IS REACHABLE. IT LISTENS ON ALL INTERFACES, BUT YOUR FIREWALL MAY NOT AGREE.\n- ONCE CONNECTED, A MISSING FREQUENCY USUALLY MEANS FLRIG ITSELF CANNOT REACH THE RADIO. CHECK THAT FLRIG\'S DISPLAY IS FOLLOWING THE DIAL.',
			'settings.station.hrdTroubleshootingTitle' => 'IF THE APP CANNOT CONNECT',
			'settings.station.hrdTroubleshooting' => 'THIS CONNECTS TO **HAM RADIO DELUXE\'S RIG CONTROL, RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — HRD TALKS TO THE RADIO.\n\n- **RIG CONTROL MUST ALREADY BE RUNNING** AND CONNECTED TO THE RADIO.\n- **ITS IP SERVER MUST BE ENABLED.** RIG CONTROL ONLY TALKS TO OTHER PROGRAMS THROUGH IT.\n- **PORT** IS 7809 UNLESS YOU CHANGED IT IN THE IP SERVER\'S SETTINGS.\n- **FROM ANOTHER MACHINE**, MAKE SURE YOUR FIREWALL LETS THE CONNECTION THROUGH.\n\nTHIS ENTRY WAS WRITTEN FROM PUBLISHED DESCRIPTIONS OF HRD\'S PROTOCOL AND HAS NOT BEEN RUN AGAINST HRD. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.n3fjpTroubleshootingTitle' => 'IF THE APP CANNOT CONNECT',
			'settings.station.n3fjpTroubleshooting' => 'THIS CONNECTS TO **AN N3FJP LOGGING PROGRAM RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — N3FJP TALKS TO THE RADIO.\n\n- **THE PROGRAM\'S API MUST BE ON**: SETTINGS → APPLICATION PROGRAM INTERFACE, CHECK **TCP API ENABLED**.\n- **PORT** IS 1100 UNLESS YOU CHANGED IT THERE.\n- **N3FJP MUST HAVE A RADIO INTERFACE SET UP** TO FOLLOW OR TUNE THE RADIO. WITHOUT ONE, IT REPORTS ONLY WHAT IS TYPED INTO ITS ENTRY WINDOW.\n- N3FJP REPORTS BAND, MODE AND FREQUENCY ONLY: NO POWER, NO TRANSMIT STATE.\n\nTHIS ENTRY WAS WRITTEN FROM N3FJP\'S PUBLISHED API AND HAS NOT BEEN RUN AGAINST N3FJP. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.commanderTroubleshootingTitle' => 'IF THE APP CANNOT CONNECT',
			'settings.station.commanderTroubleshooting' => 'THIS CONNECTS TO **DXLAB COMMANDER, RUNNING ON YOUR COMPUTER**, NOT TO THE RADIO DIRECTLY — COMMANDER TALKS TO THE RADIO.\n\n- **COMMANDER MUST ALREADY BE RUNNING** AND CONNECTED TO THE RADIO.\n- **ITS NETWORK SERVICE MUST BE ON**: THE **NET SERV** BUTTON IN THE RADIO PANEL OF COMMANDER\'S CONFIGURATION WINDOW.\n- **PORT** IS 52002, THE THIRD PORT OF THE BLOCK STARTING AT NET SERV\'S **BASE PORT** (52000 UNLESS YOU CHANGED IT).\n- **FROM ANOTHER MACHINE**, MAKE SURE YOUR FIREWALL LETS THE CONNECTION THROUGH.\n\nTHIS ENTRY WAS WRITTEN FROM COMMANDER\'S PUBLISHED TCP MESSAGES AND HAS NOT BEEN RUN AGAINST COMMANDER. IF IT HALF-WORKS, THAT IS WORTH REPORTING.',
			'settings.station.ic705TroubleshootingTitle' => 'IF THE RADIO NEVER RESPONDS',
			'settings.station.ic705Troubleshooting' => 'THE RADIO HAS A **SINGLE** REMOTE-CONTROL SESSION. WHEN THE LOGIN IS IGNORED, SOMETHING ELSE IS ALMOST ALWAYS USING IT.\n\n- **CLOSE ANY OTHER CLIENT.** WFVIEW OR RS-BA1 CONNECTED TO THE SAME RADIO HOLDS THAT ONE SESSION, AND THE LOGIN HERE IS SIMPLY IGNORED WHILE IT DOES.\n- **CHECK THE RADIO\'S NETWORK SETTINGS.** WLAN MUST BE ON, THE RADIO MUST BE ON THE SAME NETWORK, AND ITS REMOTE-CONTROL (NETWORK) FUNCTION MUST BE ENABLED.\n- **THE PORTS MUST MATCH** THE RADIO\'S CONTROL PORT AND SERIAL PORT (UDP), OR THE PORTS FORWARDED TO THEM. A WRONG PORT IS MET WITH SILENCE, THE SAME AS A RADIO THAT IS OFF.\n- **POWER-CYCLE THE RADIO\'S WLAN** IF IT STAYS STUCK. THAT RELIABLY CLEARS A SESSION STUCK ON THE RADIO.\n\nA **WRONG PASSWORD IS REFUSED EXPLICITLY**, NOT MET WITH SILENCE. IF YOU GOT HERE RATHER THAN A "REJECTED" MESSAGE, THE PASSWORD IS NOT THE PROBLEM.',
			'settings.station.icomLanTroubleshooting' => 'THE RADIO HAS A **SINGLE** REMOTE-CONTROL SESSION. WHEN THE LOGIN IS IGNORED, SOMETHING ELSE IS ALMOST ALWAYS USING IT.\n\n- **CLOSE ANY OTHER CLIENT.** WFVIEW, RS-BA1 OR ICOM\'S REMOTE UTILITY CONNECTED TO THE SAME RADIO HOLDS THAT ONE SESSION, AND THE LOGIN HERE IS SIMPLY IGNORED WHILE IT DOES.\n- **CHECK THE RADIO\'S NETWORK SETTINGS.** ITS LAN PORT MUST BE CONNECTED TO THE SAME NETWORK AS THIS DEVICE, ITS **NETWORK CONTROL** MUST BE ON, AND THE USERNAME AND PASSWORD MUST BE SET UP AS A NETWORK USER ON THE RADIO.\n- **THE PORTS MUST MATCH** THE RADIO\'S CONTROL PORT AND SERIAL PORT (UDP), OR THE PORTS FORWARDED TO THEM. A WRONG PORT IS MET WITH SILENCE, THE SAME AS A RADIO THAT IS OFF.\n- **IF IT CONNECTS BUT NEVER ANSWERS**, THE CI-V ADDRESS HERE MUST MATCH THE RADIO\'S CI-V ADDRESS MENU. THIS ENTRY PREFILLS THE ADDRESS THE MODEL SHIPS WITH.\n- **TURN THE RADIO OFF AND ON** IF IT STAYS STUCK.',
			'settings.station.statusStale' => 'NOT RESPONDING',
			'settings.station.statusDisconnected' => 'NOT CONNECTED',
			'settings.station.statusConnecting' => 'CONNECTING…',
			'settings.station.statusDisconnecting' => 'DISCONNECTING…',
			'settings.station.statusError' => 'CONNECTION FAILED',
			'settings.station.currentRadioSettings' => 'CURRENT RADIO SETTINGS',
			'settings.station.notSupportedByThisRadio' => 'NOT SUPPORTED BY THIS RADIO',
			'settings.station.keyerRowLabel' => 'KEYER',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'PHONE',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'VOICE KEYER: ${count} MEMORIES IN THE RADIO',
			'settings.station.antennaBands' => 'BANDS',
			'settings.station.antennaType' => 'ANTENNA TYPE',
			'settings.station.antennaTypeRequired' => 'CHOOSE AN ANTENNA TYPE',
			'settings.station.antennaTypes.dipole' => 'DIPOLE',
			'settings.station.antennaTypes.vertical' => 'VERTICAL',
			'settings.station.antennaTypes.yagiBeam' => 'YAGI / BEAM',
			'settings.station.antennaTypes.loop' => 'LOOP',
			'settings.station.antennaTypes.longWire' => 'LONG WIRE / EFHW',
			'settings.station.antennaTypes.other' => 'OTHER',
			'settings.station.keyType' => 'KEY TYPE',
			'settings.station.keyTypeRequired' => 'CHOOSE A KEY TYPE',
			'settings.station.keyTypes.straight' => 'STRAIGHT KEY',
			'settings.station.keyTypes.sideswiper' => 'SIDESWIPER',
			'settings.station.keyTypes.bug' => 'BUG (MECHANICAL SEMI-AUTOMATIC)',
			'settings.station.keyTypes.fullyAutomatic' => 'FULLY-AUTOMATIC KEYER',
			'settings.station.keyTypes.singlePaddle' => 'SINGLE PADDLE',
			'settings.station.keyTypes.dualPaddle' => 'DUAL PADDLE',
			'settings.station.keyTypes.computerDriven' => 'COMPUTER DRIVEN',
			'settings.station.keyTypes.other' => 'OTHER',
			'settings.station.softwareIntermediaries' => 'SOFTWARE INTERMEDIARIES',
			'settings.station.otherBrands' => 'OTHER BRANDS',
			'settings.station.otherEquipment' => 'OTHER EQUIPMENT (ANTENNAS, KEYS, ETC)',
			'settings.station.newAntenna' => 'NEW ANTENNA',
			'settings.station.newKey' => 'NEW KEY',
			'settings.station.newKeyer' => 'WINKEYER (K1EL OR COMPATIBLE)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT KEYER IN ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'KEY ON ${device}',
			'settings.station.cwKeyerArea' => 'KEYER AREA',
			'settings.station.trackStationInfo' => 'TRACK STATION INFO FOR EACH QSO',
			'settings.station.includeStationInfoInAdif' => 'INCLUDE IN ADIF EXPORTS',
			'settings.station.whatToTrack' => 'WHAT TO TRACK?',
			'settings.station.trackFieldRig' => 'TRANSCEIVER',
			'settings.station.trackFieldPower' => 'POWER',
			'settings.station.watts' => 'WATTS',
			'settings.station.trackFieldAntenna' => 'ANTENNA',
			'settings.station.trackFieldKey' => 'CW KEY',
			'settings.station.placeholderConnectDelay' => 'CONNECT DELAY (MS)',
			'settings.station.placeholderConnectDelayDescription' => 'HOW LONG THE SIMULATED HANDSHAKE TAKES. BLANK OR 0 CONNECTS INSTANTLY.',
			'settings.station.placeholderDropAfter' => 'DROP AFTER (SECONDS)',
			'settings.station.placeholderDropAfterDescription' => 'CLOSE THE CONNECTION ON ITS OWN, TO EXERCISE THE RECONNECT PATH. BLANK OR 0 NEVER DROPS.',
			'settings.station.placeholderFailConnect' => 'ALWAYS FAIL TO CONNECT',
			'settings.station.placeholderConnectFailure' => 'THE PLACEHOLDER RADIO WAS TOLD TO REFUSE THIS CONNECTION',
			'settings.station.placeholderFreq' => 'FREQUENCY (KHZ)',
			'settings.station.placeholderFreqDescription' => 'WHERE THE PLACEHOLDER RADIO STARTS. IT REPORTS BACK WHATEVER THE APP TUNES IT TO AFTERWARDS.',
			'settings.station.placeholderMode' => 'MODE',
			'settings.station.placeholderModeDescription' => 'THE MODE THE PLACEHOLDER RADIO STARTS ON, E.G. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'POWER (WATTS)',
			'settings.station.placeholderPurpose' => 'USE THIS RADIO TO KEEP TRACK OF WHICH RIG YOU\'RE USING FOR LOGGING PURPOSES',
			'settings.station.placeholderReplyDelay' => 'REPLY DELAY (MS)',
			'settings.station.placeholderReplyDelayDescription' => 'HOW LONG THE PLACEHOLDER RADIO TAKES TO REPORT A CHANGE BACK. BLANK OR 0 REPLIES AT ONCE.',
			'settings.station.cwKeyerField' => 'CAT CW KEYER',
			'settings.station.cwKeyerFieldDescription' => 'WHETHER THIS RADIO KEYS CW FROM TEXT OVER CAT. OFF FOR A RIG THE APP DOES NOT KNOW.',
			'settings.station.voiceMemories' => 'VOICE MEMORIES',
			'settings.station.voiceMemoriesDescription' => 'HOW MANY VOICE MEMORIES THE RADIO PLAYS OVER CAT. 0 FOR NONE.',
			'settings.station.voiceMemoriesInvalid' => 'A WHOLE NUMBER, 0 OR MORE',
			'settings.station.yaesuMeterCapture' => 'CAPTURE METER READINGS',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'READS THE RADIO\'S POWER-OUTPUT METER AND HIGH-SWR FLAG WHILE TRANSMITTING AND PRINTS THE RAW VALUES TO THE LOG. FOR BUILDING THE SCALE YAESU DOES NOT PUBLISH — THE VALUES ARE NOT SHOWN AS METERS.',
			'settings.station.yaesuMeterCaptureDescription' => 'READS THE RADIO\'S PO, SWR AND ALC METERS WHILE TRANSMITTING AND PRINTS THE RAW VALUES TO THE LOG. FOR BUILDING THE SCALE YAESU DOES NOT PUBLISH — THE VALUES ARE NOT SHOWN AS METERS.',
			'settings.station.telemetryInterval' => 'METER READING INTERVAL (MS)',
			'settings.station.telemetryIntervalDescription' => 'HOW OFTEN TO READ THE RADIO\'S METERS WHILE IT IS TRANSMITTING. LEAVE BLANK FOR THE FASTEST THIS CONNECTION CAN HANDLE, UP TO 200 MS.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'A WHOLE NUMBER OF MILLISECONDS, ${min} TO ${max}',
			'settings.station.pollInterval' => 'IDLE POLLING INTERVAL (MS)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'HOW OFTEN TO ASK THE RADIO FOR ITS FREQUENCY AND MODE WHILE NEITHER IS CHANGING. LEAVE BLANK FOR ${fallback} MS.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'A WHOLE NUMBER OF MILLISECONDS, ${min} TO ${max}',
			'settings.station.advancedSettings' => 'ADVANCED SETTINGS',
			'settings.station.placeholderSwr' => 'SWR READING',
			'settings.station.placeholderSwrDescription' => 'WHAT THIS RADIO REPORTS ON ITS SWR METER WHILE TRANSMITTING. ABOVE 1.8 THE PANEL WARNS.',
			'settings.station.placeholderSwrInvalid' => 'A NUMBER, 1 OR MORE',
			'settings.station.keyerNone' => 'NONE',
			'settings.station.cwDialect' => 'CW KEYING DIALECT',
			'settings.station.cwDialectDescription' => 'WHICH SHAPE OF THE KY COMMAND THIS RADIO TAKES. NONE MEANS NO CW KEYING OVER CAT.',
			'settings.station.cwDialectKenwood' => 'KENWOOD (KY, PADDED TO 24)',
			'settings.station.cwDialectElecraft' => 'ELECRAFT (KY TEXT)',
			'settings.station.voiceDialect' => 'VOICE KEYER DIALECT',
			'settings.station.voiceDialectDescription' => 'HOW THIS RADIO PLAYS ITS VOICE MEMORIES OVER CAT. NONE MEANS NO VOICE MEMORIES OVER CAT. WITH A DIALECT AND NO COUNT, THE DIALECT\'S DEFAULT COUNT APPLIES.',
			'settings.station.voiceDialectPb' => 'KENWOOD (PB, TS-590 STYLE)',
			'settings.station.voiceDialectK4' => 'ELECRAFT K4 (PB AND DA)',
			'settings.station.voiceDialectKx' => 'ELECRAFT KX2/KX3 (SWITCH TAPS)',
			'settings.station.placeholderDiagnostic' => 'SIMULATED',
			'settings.station.placeholderWholeNumberInvalid' => 'MUST BE A WHOLE NUMBER, 0 OR MORE',
			'settings.station.placeholderFreqInvalid' => 'MUST BE A FREQUENCY IN KHZ, GREATER THAN ZERO',
			'settings.station.placeholderModeInvalid' => 'MUST BE A MODE NAME, E.G. USB, CW, FT8',
			'settings.station.switchLayout' => 'LAYOUT',
			'settings.station.switchLayoutDescription' => 'WHICH SIDE OF THE SWITCH YOUR RADIOS ARE PLUGGED INTO.',
			'settings.station.switchLayoutRequired' => 'CHOOSE HOW THE SWITCH IS WIRED',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'THE SWITCH REFUSED "${command}" (ERROR ${code})',
			'settings.station.switchBusyTransmitting' => 'THAT PORT IS TRANSMITTING — ANTENNA NOT CHANGED',
			'settings.station.switchNoAntenna' => 'NONE',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'ANTENNA ON PORT ${port}',
			'settings.station.switchAntennaForDescription' => 'WHICH OF YOUR ANTENNAS IS CONNECTED TO THIS PORT ON THE SWITCH.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} ANTENNAS, ${radios} RADIOS',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} ANTENNAS, 1 RADIO',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 ANTENNA, ${radios} RADIOS',
			'settings.station.switchCommonPort' => 'COMMON',
			'settings.station.dcnAddress' => 'DEVICE ADDRESS',
			'settings.station.dcnAddressDescription' => 'THE ADDRESS SET ON THE MODULE\'S DIP SWITCHES. A COAX RELAY MODULE LEAVES THE FACTORY AT 2.',
			'settings.station.dcnAddressRequired' => 'MUST BE A DEVICE ADDRESS FROM 1 TO 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'PORT ${port}',
			'settings.station.switchPortAutoHint' => 'FOLLOWS BAND DATA',
			'settings.station.switchPortTransmittingHint' => 'TRANSMITTING — CANNOT CHANGE NOW',
			'settings.station.switchCurrentStateHeader' => 'CURRENT STATE',
			'settings.station.switchCurrentStateDescription' => 'WHICH ANTENNA EACH RADIO PORT IS ON RIGHT NOW. CHANGES TAKE EFFECT IMMEDIATELY.',
			'settings.station.switchWiringHeader' => 'WIRING',
			'settings.station.switchPortInhibitedHint' => 'TRANSMIT INHIBITED',
			'settings.station.configUnreadable' => 'THIS RADIO\'S SAVED SETTINGS COULD NOT BE READ. OPEN ITS SETTINGS AND ENTER THEM AGAIN, OR REMOVE IT AND ADD IT BACK.',
			'settings.station.autoConnectHeld' => 'HALO STOPPED RESPONDING THE LAST TIME IT CONNECTED TO THIS RADIO, SO IT DID NOT CONNECT ON ITS OWN THIS TIME. PRESS CONNECT TO TRY AGAIN.',
			'settings.offlineData.title' => 'OFFLINE DATA',
			'settings.offlineData.noFiles' => 'NO DATA FILES',
			'settings.offlineData.noFilesDescription' => 'ENABLE ACTIVITY OR LOOKUP EXTENSIONS TO DOWNLOAD THEIR OFFLINE DATA HERE.',
			'settings.offlineData.refresh' => 'REFRESH',
			'settings.offlineData.refreshing' => 'REFRESHING…',
			'settings.offlineData.updateAll' => 'UPDATE ALL',
			'settings.offlineData.updatingAll' => 'UPDATING ALL DATA FILES…',
			'settings.offlineData.neverDownloaded' => 'NEVER DOWNLOADED',
			'settings.offlineData.updatedJustNow' => 'UPDATED JUST NOW',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'UPDATED ${days}D AGO',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'UPDATED ${days}D ${hours}H AGO',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'UPDATED ${hours}H AGO',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'UPDATED ${hours}H ${minutes}M AGO',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'UPDATED ${minutes}M AGO',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'THE LAST DOWNLOAD HAD ONLY ${imported} OF ${existing} RECORDS AND WAS NOT USED. REFRESH TO ACCEPT IT.',
			'settings.offlineData.extensionsSection' => 'EXTENSIONS',
			'settings.profiles.notSet' => 'NOT SET',
			'settings.profiles.personalInfo' => 'PERSONAL INFO',
			'settings.profiles.personalInfoNote' => 'THIS MIGHT BE INCLUDED IN GENERATED LOGS WHEN RELEVANT FOR SUBMISSIONS',
			'settings.profiles.name' => 'NAME',
			'settings.profiles.email' => 'EMAIL',
			'settings.profiles.club' => 'CLUB',
			'settings.profiles.arrlSection' => 'ARRL SECTION',
			'settings.profiles.racSection' => 'RAC SECTION',
			'settings.profiles.section' => 'SECTION',
			'settings.search.clear' => 'CLEAR',
			'settings.search.hint' => 'SEARCH PREFERENCES',
			'settings.developer.developerModeDescription' => 'ENABLE DEVELOPER WARNINGS, DEBUG LOGS, AND TOOLS.',
			'settings.developer.experiments' => 'EXPERIMENTS',
			'settings.developer.showIdleMetrics' => 'SHOW IDLE METRICS',
			'settings.developer.showIdleMetricsDescription' => 'SHOW IN THE STATUS BAR HOW IDLE THE EXTENSION ENGINE HAS BEEN OVER THE LAST SECOND. TAP IT FOR THE 10- AND 60-SECOND AVERAGES.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% IDLE',
			'settings.developer.idleMetricsAverages' => 'IDLE AVG:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}S ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} ENABLED', other: '${count} ENABLED', ), 
			'settings.developer.patchTrack' => 'CODE PUSH TRACK',
			'settings.developer.patchTrackDescription' => 'WHICH OVER-THE-AIR CODE PUSH RING THIS DEVICE FOLLOWS. MORE ADVENTUROUS RINGS GET FIXES EARLIER, LESS TESTED. CODE PUSHES APPLY ON THE NEXT RESTART.',
			'settings.developer.trackStable' => 'STABLE',
			'settings.developer.trackUnstable' => 'UNSTABLE',
			'settings.developer.trackBleeding' => 'BLEEDING',
			'settings.developer.checkingTrack' => ({required Object track}) => 'CHECKING "${track}" FOR A CODE PUSH…',
			'settings.developer.patchDownloaded' => 'CODE PUSH DOWNLOADED — RESTART THE APP TO APPLY IT.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'NO NEW CODE PUSH ON "${track}".',
			'settings.developer.noPatchInstalled' => 'NO CODE PUSH INSTALLED — RUNNING THE RELEASE BINARY.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'RUNNING CODE PUSH #${patch}.',
			'settings.developer.deepLinks' => 'DEEP LINKS',
			'settings.developer.registerUrlSchemes' => 'REGISTER URL SCHEMES',
			'settings.developer.registerUrlSchemesDescription' => 'LET COM.HAM2K:// LINKS OPEN THIS COPY OF THE APP',
			'settings.developer.registerUrlSchemesDone' => 'THIS COPY NOW OPENS COM.HAM2K:// LINKS',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'COULD NOT REGISTER: ${error}',
			'settings.developer.systemInformation' => 'SYSTEM INFORMATION',
			'settings.developer.appVersion' => 'APP VERSION',
			'settings.developer.dataFolder' => 'DATA FOLDER',
			'settings.developer.loading' => '(LOADING…)',
			'settings.developer.panelLoadFailed' => 'COULD NOT LOAD THIS SETTINGS PANEL.',
			'settings.developer.extDevServer' => 'EXTENSION DEV SERVER',
			'settings.developer.extensionSettings' => 'EXTENSION SETTINGS',
			'settings.developer.extDevServerDescription' => 'LOAD EXTENSIONS FROM A DEV SERVER ON YOUR NETWORK INSTEAD OF THE ONES BUILT INTO THE APP, AND RELOAD THEM AS YOU SAVE.',
			'settings.developer.extDevServerAddress' => 'SERVER ADDRESS',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'CONNECT',
			'settings.developer.extDevServerDisconnect' => 'DISCONNECT',
			'settings.developer.extDevServerConnecting' => 'CONNECTING…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'SERVING ${count} EXTENSION: ${keys}', other: 'SERVING ${count} EXTENSIONS: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'NOT CONNECTED',
			'settings.developer.extDevServerReconnect' => 'RECONNECT AT LAUNCH',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'LAST RELOAD: ${key} AT ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} EXTENSION FAILING TO BUILD', other: '${count} EXTENSIONS FAILING TO BUILD', ), 
			'settings.developer.catalog' => 'EXTENSION CATALOG',
			'settings.developer.catalogDescription' => 'READ THE CATALOG FROM ANOTHER SERVER — A LOCAL ONE WHILE WORKING ON THE CATALOG ITSELF. EMPTY MEANS CATALOG.HAM2K.NET.',
			'settings.developer.catalogAddress' => 'CATALOG ADDRESS',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'CATALOG SEARCH TRACKS',
			'settings.developer.catalogSearchStable' => 'ONLY STABLE',
			'settings.developer.catalogSearchUnstable' => 'UNSTABLE OR BETTER',
			'settings.developer.catalogSearchBleeding' => 'BLEEDING OR BETTER',
			'settings.about.notices' => 'NOTICES & MESSAGES',
			'settings.about.noticesDescription' => 'ANNOUNCEMENTS AND STATUS MESSAGES',
			'settings.about.releaseNotes' => 'RELEASE NOTES',
			'settings.about.copiedVersion' => 'COPIED VERSION DETAILS TO CLIPBOARD',
			'settings.panels.settings' => 'APPLICATION PREFERENCES',
			'settings.panels.settingsDescription' => 'MAKE THE APP WORK HOW YOU WANT IT',
			'settings.panels.commonSettings' => 'COMMON PREFERENCES',
			'settings.panels.syncDescription' => 'BACK UP AND SYNC YOUR LOGS ACROSS DEVICES',
			'settings.panels.accountsDescription' => 'SERVICE CREDENTIALS, OFFLINE DATA, AND MORE',
			'settings.panels.extensions' => 'EXTENSIONS & FEATURES',
			'settings.panels.extensionsDescription' => 'ACTIVITIES, CONTESTS, DASHBOARD PANELS AND MORE FEATURES',
			'settings.panels.profilesDescription' => 'OPERATOR CALLSIGN AND STATION PROFILE',
			'settings.panels.stationProfiles' => 'STATION PROFILES',
			'settings.panels.developerSettings' => 'DEVELOPER SETTINGS',
			'settings.panels.developerSettingsDescription' => 'DEBUGGING AND DEVELOPMENT TOOLS',
			'settings.panels.about' => 'ABOUT',
			'settings.panels.aboutDescription' => 'VERSION, CREDITS, AND LEGAL INFORMATION',
			'settings.panels.unavailableTitle' => 'SOME SETTINGS ARE UNAVAILABLE',
			'settings.panels.unavailableText' => 'THE EXTENSION RUNTIME FAILED TO START, SO EXTENSION-CONTRIBUTED SETTINGS ARE MISSING.',
			'settings.panels.station' => 'STATION CONFIGURATION',
			'settings.panels.stationDescription' => 'CAT CONTROL AND MORE OPTIONS',
			'settings.panels.peers' => 'PEER DEVICES',
			'settings.panels.peersDescription' => 'CONNECT TO OTHER DEVICES NEARBY',
			'settings.showMoreSettings' => 'SHOW MORE SETTINGS',
			'settings.numberFormat' => 'NUMBER FORMATTING',
			'settings.numberFormatOpts.locale' => 'FOLLOW SYSTEM SETTINGS',
			'settings.numberFormatOpts.period' => 'ALWAYS USE PERIOD FOR DECIMALS',
			'settings.numberFormatOpts.comma' => 'ALWAYS USE COMMA FOR DECIMALS',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => 'SYSTEM SETTINGS (USING ${separator} FOR DECIMALS)',
			'settings.numberFormatDescription.period' => 'ALWAYS USING PERIOD FOR DECIMALS',
			'settings.numberFormatDescription.comma' => 'ALWAYS USING COMMA FOR DECIMALS',
			'settings.numberFormatSeparators.comma' => 'COMMA',
			'settings.numberFormatSeparators.period' => 'PERIOD',
			_ => null,
		} ?? switch (path) {
			'settings.gridPrecision' => 'GRID PRECISION',
			'settings.gridPrecisionOpts.six' => '6 DIGITS (FN31PR)',
			'settings.gridPrecisionOpts.eight' => '8 DIGITS (FN31PR55)',
			'settings.gridPrecisionDescription.six' => '6 DIGITS',
			'settings.gridPrecisionDescription.eight' => '8 DIGITS',
			'commands.enableSyncFirst' => 'ENABLE SYNC IN SETTINGS FIRST.',
			'commands.fullResyncStarted' => 'FULL RESYNC STARTED — LOCAL DATA WAS BACKED UP FIRST.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'NO DATA FILES MATCHED "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'RELOAD FAILED: ${error}',
			'commands.reloadingAll' => 'RELOADING ALL DATA FILES…',
			'commands.reloadingTarget' => ({required Object target}) => 'RELOADING ${target} DATA FILES…',
			'commands.unknownExperiment' => ({required Object token}) => 'UNKNOWN EXPERIMENT "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} ENABLED',
			'commands.experimentDisabled' => ({required Object name}) => '${name} DISABLED',
			'commands.sentryTestSent' => 'TEST ERROR REPORT SENT TO SENTRY',
			'commands.idleMetricsEnabled' => 'IDLE METRICS ENABLED IN THE STATUS BAR',
			'commands.idleMetricsDisabled' => 'IDLE METRICS DISABLED',
			'commands.sentryTestLocalOnly' => 'SENTRY IS DISABLED IN THIS BUILD — TEST ERROR LOGGED LOCALLY ONLY',
			'commands.noOperationOpen' => 'THAT COMMAND NEEDS AN OPEN OPERATION',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'DON\'T KNOW HOW TO MARK A \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} ISN\'T TURNED ON IN THIS APP',
			'commands.goUnknown' => ({required Object to}) => 'DON\'T KNOW HOW TO GO TO \'${to}\'',
			'commands.goBlocked' => 'CLOSE THE OPEN DIALOG FIRST',
			'commands.operationAlreadyStarted' => 'THIS OPERATION ALREADY HAS A START MARKER',
			'commands.couldNotOpenLocation' => 'ADDED THE BREAK, BUT COULD NOT OPEN THE LOCATION SCREEN',
			'commands.noTestOperations' => 'NO TEST OPERATIONS TO PURGE',
			'commands.purgeTestsUnavailable' => 'PURGETESTS NEEDS TO SHOW A CONFIRMATION DIALOG, WHICH ISN\'T AVAILABLE HERE',
			'commands.syncAllUnavailable' => 'SYNCALL NEEDS TO SHOW A CONFIRMATION DIALOG, WHICH ISN\'T AVAILABLE HERE',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'PURGED ${count} TEST OPERATION', other: 'PURGED ${count} TEST OPERATIONS', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'PURGED ${purged} OF ${total} TEST OPERATIONS — THE REST FAILED; TRY PURGETESTS AGAIN',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'PURGED ${count} TEST CONTACT WITH NO OPERATION', other: 'PURGED ${count} TEST CONTACTS WITH NO OPERATION', ), 
			'commands.purgeTestsContactsFailed' => 'PURGED THE TEST OPERATIONS, BUT THE TEST CONTACTS WITH NO OPERATION FAILED; TRY PURGETESTS AGAIN',
			'commands.purgeTestsNothingToDo' => 'NOTHING WAS PURGED',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'REMOVED ${removed} OF ${total} TEST OPERATIONS — THE REST FAILED; TRY REVIEW AGAIN',
			'commands.receivedPurgesFailed' => 'COULDN\'T REMOVE THOSE TEST OPERATIONS — TRY REVIEW AGAIN',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} TEST OPERATION WAS REMOVED ON ANOTHER DEVICE', other: '${count} TEST OPERATIONS WERE REMOVED ON ANOTHER DEVICE', ), 
			'commands.receivedPurgesReview' => 'REVIEW',
			'commands.settingOn' => 'ON',
			'commands.settingOff' => 'OFF',
			'commands.settingEmpty' => '(EMPTY)',
			'commands.settingSecretSet' => '(SET)',
			'commands.settingSecretUnset' => '(NOT SET)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} SELECTED',
			'commands.settingExpectsOnOff' => 'ON OR OFF',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'ONE OF: ${choices}',
			'commands.settingExpectsNumber' => 'A NUMBER',
			'commands.settingVanished' => ({required Object label}) => '“${label}” IS NO LONGER AVAILABLE',
			'commands.noCwKeyer' => 'NO CONNECTED RADIO CAN KEY CW',
			'commands.noKeyer' => 'NO CONNECTED RADIO CAN KEY CW OR PLAY VOICE MEMORIES',
			'commands.keyerNeedsOperation' => 'OPEN AN OPERATION TO USE THE CW KEYER',
			'commands.keyerExperimentOff' => 'CW KEYING IS OFF — TURN IT ON WITH EXP KEYER',
			'commands.esmExperimentOff' => 'ENTER SENDS MESSAGES IS OFF — TURN IT ON WITH EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'SENDING CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW MESSAGE F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW MESSAGE F${n} WAS NOT SENT: THE EXTENSIONS ARE NOT READY',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” DID NOT ACCEPT THAT VALUE',
			'commandDialog.hint' => 'SEARCH CALLSIGNS OR TYPE A COMMAND',
			'commandDialog.noResults' => ({required Object text}) => 'NOTHING MATCHES “${text}”',
			'commandDialog.sectionCommands' => 'COMMANDS',
			'commandDialog.sectionGoTo' => 'GO TO',
			'commandDialog.sectionOperations' => 'OPERATIONS',
			'commandDialog.goHome' => 'HOME',
			'commandDialog.goSettings' => 'SETTINGS',
			'commandDialog.goNewOperation' => 'NEW OPERATION',
			'commandDialog.runTyped' => ({required Object text}) => 'RUN “${text}”',
			'commandDialog.sectionSuggestions' => 'TRY',
			'commandDialog.lookingUp' => 'LOOKING UP CALLSIGN…',
			'commandDialog.blockedByPane' => 'CANNOT USE COMMANDS WHILE A PANEL OR DIALOG IS OPEN',
			'keyboardShortcuts.title' => 'KEYBOARD SHORTCUTS',
			'keyboardShortcuts.description' => 'CUSTOMIZE KEY MAPPINGS',
			'keyboardShortcuts.search' => 'SEARCH COMMANDS AND KEYS',
			'keyboardShortcuts.import' => 'IMPORT…',
			'keyboardShortcuts.export' => 'EXPORT…',
			'keyboardShortcuts.resetAll' => 'RESET ALL',
			'keyboardShortcuts.resetAllTitle' => 'RESET EVERY SHORTCUT?',
			'keyboardShortcuts.resetAllBody' => 'EVERY COMMAND GOES BACK TO ITS DEFAULT KEYS, AND THE KEYS BOUND TO TYPED COMMANDS ARE REMOVED.',
			'keyboardShortcuts.reset' => 'RESET',
			'keyboardShortcuts.noKey' => 'NO KEY',
			'keyboardShortcuts.changed' => 'CHANGED',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} IS ALSO BOUND TO ${commands}',
			'keyboardShortcuts.groupApp' => 'APP',
			'keyboardShortcuts.groupKeying' => 'KEYING',
			'keyboardShortcuts.groupLogging' => 'LOGGING',
			'keyboardShortcuts.groupCommands' => 'COMMANDS',
			'keyboardShortcuts.groupFixed' => 'FIXED KEYS',
			'keyboardShortcuts.contextApp' => 'ANYWHERE',
			'keyboardShortcuts.contextLogView' => 'OPERATION, CHASING AND LOGS VIEWS',
			'keyboardShortcuts.contextOperation' => 'OPERATION VIEW, KEYING A CAT RADIO',
			'keyboardShortcuts.contextLogging' => 'IN THE LOGGING PANEL',
			'keyboardShortcuts.addCommand' => 'ADD A COMMAND…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'UNKNOWN COMMAND: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'OPEN THE COMMAND DIALOG',
			'keyboardShortcuts.command.toggleTheme' => 'SWITCH BETWEEN LIGHT AND DARK',
			'keyboardShortcuts.command.toggleLanguage' => 'SWITCH BETWEEN ENGLISH AND SPANISH',
			'keyboardShortcuts.command.fontScaleUp' => 'LARGER TEXT',
			'keyboardShortcuts.command.fontScaleDown' => 'SMALLER TEXT',
			'keyboardShortcuts.command.fontScaleReset' => 'NORMAL TEXT SIZE',
			'keyboardShortcuts.command.densityLooser' => 'ROOMIER LAYOUT',
			'keyboardShortcuts.command.densityDenser' => 'DENSER LAYOUT',
			'keyboardShortcuts.command.densityAuto' => 'AUTOMATIC LAYOUT DENSITY',
			'keyboardShortcuts.command.find' => 'FIND IN THE LOG',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'SEND MESSAGE ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'KEYBOARD MODE ON OR OFF',
			'keyboardShortcuts.command.ptt' => 'PUSH TO TALK',
			'keyboardShortcuts.command.wipe' => 'CLEAR THE CONTACT BEING LOGGED',
			'keyboardShortcuts.fixed.callsign' => 'TYPING CALLSIGNS',
			'keyboardShortcuts.fixed.escape' => 'STOP SENDING, BACK OUT ONE STEP, OR CLOSE',
			'keyboardShortcuts.fixed.enter' => 'LOG THE CONTACT',
			'keyboardShortcuts.fixed.space' => 'NEXT FIELD',
			'keyboardShortcuts.fixed.tab' => 'NEXT OR PREVIOUS FIELD',
			'keyboardShortcuts.fixed.arrows' => 'MOVE BETWEEN FIELDS, CONTROLS AND THE LOG',
			'keyboardShortcuts.fixed.walk' => 'PAGE THROUGH THE LOG, OR GO TO ITS ENDS',
			'keyboardShortcuts.fixed.undo' => 'TAKE BACK A WIPE OR A DELETE',
			'keyboardShortcuts.editor.addShortcut' => 'ADD SHORTCUT',
			'keyboardShortcuts.editor.listening' => 'PRESS THE KEYS FOR THE SHORTCUT…',
			'keyboardShortcuts.editor.listeningHint' => 'ESC STOPS LISTENING',
			'keyboardShortcuts.editor.add' => 'ADD',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} BELONGS TO THE LOGGING FIELDS OR A DIALOG, AND CAN’T BE CHANGED.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} IS HOW CALLSIGNS ARE TYPED. HOLD CMD, CTRL OR ALT WITH IT.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'THE SYSTEM MAY TAKE ${keys} BEFORE THE APP SEES IT.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} IS ALREADY ONE OF THIS COMMAND’S KEYS.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'TAKE ${keys} FROM “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'RESET TO DEFAULT',
			'keyboardShortcuts.editor.remove' => 'REMOVE',
			'keyboardShortcuts.editor.commandLabel' => 'COMMAND',
			'keyboardShortcuts.editor.commandHint' => 'ENTER ANY VALID COMMAND, OR MULTIPLE COMMANDS SEPARATED BY ";"',
			'keyboardShortcuts.editor.removeCommand' => 'REMOVE COMMAND',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'NO COMMAND READS “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'NO KEY YET',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'SHORTCUTS SAVED TO ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'COULDN’T EXPORT THE SHORTCUTS: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'COULDN’T OPEN THE FILE: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} ISN’T A SHORTCUTS FILE THIS APP CAN READ: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'THE TEXT ISN’T VALID YAML (LINE ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'IT ISN’T A HAM2K KEYBOARD SHORTCUTS FILE',
			'keyboardShortcuts.file.problemNewerVersion' => 'IT WAS WRITTEN BY A NEWER VERSION OF THE APP',
			'keyboardShortcuts.file.problemMalformed' => 'PART OF IT DOESN’T FOLLOW THE SHORTCUTS FORMAT',
			'keyboardShortcuts.file.problemTooLarge' => 'IT IS TOO LARGE',
			'keyboardShortcuts.file.importTitle' => 'IMPORT SHORTCUTS',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'WRITTEN ON ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'THE FILE DOESN’T SAY WHICH KEYBOARD IT WAS WRITTEN ON.',
			'keyboardShortcuts.file.translate' => 'WHAT SHOULD EACH OF THESE KEYS BE ON THIS KEYBOARD?',
			'keyboardShortcuts.file.leaveOut' => 'LEAVE THOSE SHORTCUTS OUT',
			'keyboardShortcuts.file.replace' => 'REPLACE THIS DEVICE’S CONFIG',
			'keyboardShortcuts.file.replaceHint' => 'EVERY SHORTCUT NOT IN THE FILE GOES BACK TO ITS DEFAULT.',
			'keyboardShortcuts.file.merge' => 'ADD TO THIS DEVICE’S CONFIG',
			'keyboardShortcuts.file.mergeHint' => 'THE FILE’S SHORTCUTS REPLACE THIS DEVICE’S FOR THE SAME COMMANDS, AND THE REST STAY.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'NOT KNOWN IN THIS VERSION, SO LEFT OUT: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'NOT SHORTCUTS, SO LEFT OUT: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'KEYS THE APP KEEPS FOR ITSELF, SO LEFT OUT: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'BOUND TO MORE THAN ONE COMMAND AFTER THE IMPORT: ${keys}',
			'keyboardShortcuts.file.importAction' => 'IMPORT',
			'keyboardShortcuts.file.imported' => 'SHORTCUTS IMPORTED',
			'keyboardShortcuts.modifier.cmd' => '⌘ COMMAND',
			'keyboardShortcuts.modifier.ctrl' => 'CTRL',
			'keyboardShortcuts.modifier.meta' => 'WINDOWS / SUPER',
			'keyboardShortcuts.platform.macos' => 'MACOS',
			'keyboardShortcuts.platform.ios' => 'IPADOS',
			'keyboardShortcuts.platform.windows' => 'WINDOWS',
			'keyboardShortcuts.platform.linux' => 'LINUX',
			'keyboardShortcuts.platform.android' => 'ANDROID',
			'expiredBuild.title' => 'THIS BUILD HAS EXPIRED',
			'expiredBuild.body' => 'PLEASE VISIT HAM2K.COM AND GET A NEWER VERSION.',
			'expiredBuild.visit' => 'VISIT HAM2K.COM',
			'expiredBuild.dismiss' => 'CONTINUE ANYWAY',
			'staleness.codePushFloorTitle' => 'AN IMPORTANT UPDATE IS WAITING',
			'staleness.codePushFloorBody' => 'THIS VERSION HAS A FIX YOU DON\'T HAVE YET.',
			'staleness.restartToApply' => 'RESTART THE APP TO APPLY IT.',
			'staleness.quitAndReopen' => 'QUIT THE APP AND OPEN IT AGAIN TO APPLY IT.',
			'staleness.reopenToApply' => 'CLOSE THE APP AND OPEN IT AGAIN TO APPLY IT.',
			'staleness.ignoreForNow' => 'IGNORE FOR NOW',
			'spotting.noQsoYet' => 'NO QSO LOGGED YET TO SPOT.',
			'spotting.setFrequencyFirst' => 'SET A FREQUENCY FIRST.',
			'spotting.nothingToSpot' => 'NOTHING TO SPOT — NO EXTENSION OFFERS SPOTTING HERE.',
			'spotting.incompleteCall' => 'CAN\'T SPOT AN INCOMPLETE CALL — FINISH THE CALLSIGN FIRST.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} FAILED: ${message}',
			'spotting.unknownError' => 'UNKNOWN ERROR',
			'spotting.notSent' => 'SPOT NOT SENT.',
			'spotting.allSkipped' => 'SPOT NOT SENT: EVERY SPOT SOURCE SKIPPED IT.',
			'spotting.notRefreshedOffline' => 'NO CONNECTION — SPOTS WERE NOT REFRESHED',
			'dataFiles.downloading' => 'DOWNLOADING…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'COULDN\'T DOWNLOAD ${name}',
			'dataFiles.downloadFailedWebHint' => 'THIS COULD BE A NETWORK ISSUE, OR THIS LINK\'S HOST MAY NOT SUPPORT DIRECT DOWNLOADS FROM A WEB BROWSER. TRY THE DESKTOP OR MOBILE APP, OR A DIFFERENT HOSTING LOCATION.',
			'dataFiles.downloadTimedOut' => 'THE SERVER TOOK TOO LONG TO RESPOND. TRY AGAIN LATER.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} ANSWERED WITH AN ERROR (HTTP ${status}). TRY AGAIN LATER.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} COULDN\'T PROVIDE THIS FILE (HTTP ${status}). CHECK THAT ITS ADDRESS IS STILL RIGHT.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM HAS NO CALL HISTORY FILE FOR ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'N1MM\'S CALL HISTORY DOWNLOAD FOR ${stem} DIDN\'T WORK. TRY AGAIN LATER.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'COULDN\'T PROCESS ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'THE DOWNLOAD HAD ONLY ${imported} OF THE ${existing} RECORDS ON THIS DEVICE, SO THE ONES IT LEFT OUT WERE KEPT. REFRESHING IT IN SETTINGS › OFFLINE DATA ACCEPTS IT ANYWAY.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'IMPORTED ${count} RECORD FOR ${label}.', other: 'IMPORTED ${count} RECORDS FOR ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'IMPORTED DATA FOR ${label}.',
			'dataFiles.cleanedUpTitle' => 'CLEANED UP EXTENSION DATA',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'REMOVED DATA FOR ${count} DATA FILE FROM DISABLED EXTENSIONS.', other: 'REMOVED DATA FOR ${count} DATA FILES FROM DISABLED EXTENSIONS.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} RECORDS',
			'dataFiles.definitionUnavailable' => 'THE FILE\'S SOURCE DIDN\'T PROVIDE A DEFINITION — ITS EXTENSION MAY BE MID-RESTART OR MISCONFIGURED. TRY AGAIN IN A MOMENT.',
			'updates.updateAvailable' => 'UPDATE AVAILABLE',
			'updates.newVersionAvailable' => ({required Object version}) => 'A NEW VERSION (${version}) IS AVAILABLE.',
			'updates.getIt' => 'GET IT',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'UPDATE READY',
			'updates.restartToApply' => 'AN UPDATE HAS BEEN DOWNLOADED. RESTART TO APPLY IT.',
			'updates.appliesNextLaunch' => 'AN UPDATE HAS BEEN DOWNLOADED. IT WILL APPLY THE NEXT TIME YOU OPEN THE APP.',
			'updates.restartNow' => 'RESTART NOW',
			'updates.reloadToUpdate' => 'A NEWER VERSION OF THIS PAGE IS AVAILABLE. RELOAD TO GET IT.',
			'updates.reloadNow' => 'RELOAD NOW',
			'updates.checkForUpdates' => 'CHECK FOR UPDATES',
			'updates.checkingForUpdates' => 'CHECKING FOR UPDATES…',
			'updates.upToDate' => 'UP TO DATE',
			'updates.automaticChecks' => 'CHECK AUTOMATICALLY',
			'updates.automaticChecksDescription' => 'LOOK FOR NEW VERSIONS IN THE BACKGROUND, FROM THE NEXT TIME YOU START THE APP',
			'extensionService.runtimeNotReady' => 'EXTENSION RUNTIME NOT READY.',
			'extensionService.testFailed' => ({required Object error}) => 'TEST FAILED: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'CONNECTED AS ${identity}',
			'extensionService.invalidFieldConfiguration' => 'INVALID FIELD CONFIGURATION',
			'extensionService.invalidValue' => 'INVALID VALUE',
			'extensionService.validationError' => ({required Object error}) => 'VALIDATION ERROR: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'ACTION FAILED: ${error}',
			'extensionService.commandFailed' => 'THE COMMAND FAILED TO RUN',
			'extensionService.reportUnavailable' => 'REPORTS CAN\'T BE SENT RIGHT NOW',
			'extensionService.stashUnavailable' => 'HAM2K’S FILE STASH CAN’T BE REACHED RIGHT NOW',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} SPENT TOO MUCH TIME IN ITS TIMERS. THEY\'RE STOPPED UNTIL THE EXTENSIONS RESTART.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name}\'S TIMERS KEPT FAILING. THEY\'RE STOPPED UNTIL THE EXTENSIONS RESTART.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} GOT STUCK IN A TIMER. ITS TIMERS ARE STOPPED UNTIL THE EXTENSIONS RESTART.',
			'operationLocationScreen.title' => 'OPERATION LOCATION',
			'operationLocationScreen.selectedLocation' => 'SELECTED LOCATION',
			'operationLocationScreen.gridSquare' => 'MAIDENHEAD GRID SQUARE LOCATOR',
			'operationLocationScreen.gridInvalid' => 'NEEDS 4, 6, 8 OR 10 CHARACTERS, LIKE FN31PR',
			'operationLocationScreen.suggestedLocations' => 'SUGGESTED LOCATIONS',
			'operationLocationScreen.deviceGps' => 'DEVICE GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS FROM ${device}',
			'operationLocationScreen.locating' => 'LOCATING…',
			'operationLocationScreen.gpsUnavailable' => 'LOCATION UNAVAILABLE',
			'operationLocationScreen.permissionDenied' => 'LOCATION PERMISSION DENIED',
			'operationLocationScreen.permissionBlocked' => 'LOCATION PERMISSION BLOCKED',
			'operationLocationScreen.moreDetails' => 'MORE DETAILS',
			'operationLocationScreen.stateOrProvince' => 'STATE OR PROVINCE (OPTIONAL)',
			'operationLocationScreen.controlsUnavailableTitle' => 'ACTIVITY CONTROLS UNAVAILABLE',
			'operationLocationScreen.controlsUnavailableReason' => 'THESE REFERENCES ARE STILL USABLE; THEIR ACTIVITIES JUST COULD NOT BE REACHED.',
			'operationLocationScreen.controlsUnavailableRetry' => 'RETRY',
			'operationLocationScreen.county' => 'COUNTY (OPTIONAL)',
			'versionLabel.version' => ({required Object version}) => 'VERSION ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'PATCH ${patch}',
			'versionLabel.build' => ({required Object build}) => 'BUILD ${build}',
			'notices.emptyHistory' => 'NO NOTICES YET',
			'notices.webStorageInMemory' => 'THIS BROWSER COULD NOT PROVIDE PERSISTENT STORAGE — THE LOG LIVES IN MEMORY ONLY AND WILL BE LOST WHEN THIS TAB CLOSES. USE A CURRENT CHROME, FIREFOX, SAFARI OR EDGE.',
			'notices.webStorageUnreliable' => 'THIS BROWSER IS USING FALLBACK STORAGE THAT IS NOT SAFE WITH MULTIPLE TABS — KEEP A SINGLE TAB OPEN, AND KEEP SYNC ON.',
			'notices.logFromNewerBuildTitle' => 'THIS LOG NEEDS A NEWER VERSION',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'YOUR LOG WAS WRITTEN BY A NEWER VERSION OF HALO (STORAGE VERSION ${storage}; THIS ONE UNDERSTANDS ${understood}), SO IT CANNOT BE OPENED, AND NEW CONTACTS WILL NOT BE SAVED. INSTALL THE NEWER VERSION AGAIN — OR, IF YOU MEANT TO RUN THIS BUILD, POINT IT AT A DIFFERENT DATA FOLDER. THE LOG IS IN ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'YOUR LOG WAS WRITTEN BY A NEWER VERSION OF HALO (STORAGE VERSION ${storage}; THIS ONE UNDERSTANDS ${understood}), SO IT CANNOT BE OPENED, AND NEW CONTACTS WILL NOT BE SAVED. OPEN THIS LOG WITH THAT NEWER VERSION INSTEAD.',
			'notices.preferencesRestoredTitle' => 'SETTINGS RESTORED FROM A BACKUP',
			'notices.preferencesRestored' => 'THE SETTINGS FILE COULD NOT BE READ, SO HALO RESTORED THE LAST GOOD COPY OF IT. ANYTHING YOU CHANGED IN YOUR PREVIOUS SESSION MAY NEED SETTING AGAIN. THE UNREADABLE FILE IS KEPT ALONGSIDE IT, NAMED SHARED_PREFERENCES.CORRUPT-….JSON.',
			'notices.preferencesResetTitle' => 'SETTINGS RESET',
			'notices.preferencesReset' => 'THE SETTINGS FILE COULD NOT BE READ AND THERE WAS NO BACKUP TO FALL BACK ON, SO HALO STARTED WITH ITS DEFAULTS. THE UNREADABLE FILE IS KEPT IN THE APP\'S DATA FOLDER, NAMED SHARED_PREFERENCES.CORRUPT-….JSON.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} WAS NOT CONNECTED AUTOMATICALLY',
			'notices.autoConnectHeld' => ({required Object name}) => 'HALO STOPPED RESPONDING THE LAST TIME IT STARTED CONNECTING TO ${name}, SO IT LEFT IT ALONE THIS TIME RATHER THAN RISK DOING IT AGAIN. CHECK THAT THE RADIO IS SWITCHED ON AND ITS CABLE IS PLUGGED IN, THEN PRESS CONNECT ON IT IN SETTINGS.',
			'syncAccount.anonymous' => ({required Object id}) => 'ANONYMOUS ACCOUNT (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (PENDING CONFIRMATION)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (PENDING CONFIRMATION - #${id})',
			'deepLink.needsAnOperation' => 'START AN OPERATION FIRST, THEN SEND THAT CONTACT AGAIN',
			'deepLink.waitingInOperation' => 'THAT CONTACT IS WAITING IN THE OPERATION BEHIND THIS SCREEN',
			'deepLink.unknownActivities' => ({required Object refs}) => 'THIS DEVICE HAS NO ACTIVITY FOR ${refs}, SO THOSE REFERENCES WERE LEFT OFF',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'COULD NOT REACH YOUR ACTIVITIES, SO ${refs} WAS LEFT OFF — TRY THAT LINK AGAIN',
			'confirmDevice.title' => 'CONFIRM A DEVICE',
			'confirmDevice.codePrompt' => 'ENTER THE CODE SHOWN ON THE DEVICE THAT WANTS TO JOIN THIS ACCOUNT.',
			'confirmDevice.code' => 'CODE',
			'confirmDevice.lookUp' => 'LOOK UP',
			'confirmDevice.codeNotFound' => 'NO REQUEST MATCHES THAT CODE. CODES EXPIRE AFTER 10 MINUTES — ASK THE OTHER DEVICE FOR A FRESH ONE.',
			'confirmDevice.linkExpired' => 'THAT LINK HAS EXPIRED. ASK THE OTHER DEVICE TO SHOW A NEW QR CODE.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'LINK ${device} TO THIS ACCOUNT?',
			'confirmDevice.unnamedDevice' => 'AN UNNAMED DEVICE',
			'confirmDevice.grantWarning' => 'IT WILL BE ABLE TO READ AND CHANGE EVERY OPERATION AND QSO IN THIS ACCOUNT.',
			'confirmDevice.needsSyncTitle' => 'THIS DEVICE DOES NOT SYNC YET',
			'confirmDevice.needsSyncText' => 'TURN ON HAM2K LOG FILER SYNC AND LINK THIS DEVICE TO AN ACCOUNT BEFORE IT CAN ADMIT ANOTHER ONE.',
			'confirmDevice.malformedRequest' => 'THE SYNC SERVER SENT A REQUEST THIS APP COULD NOT READ. ASK THE OTHER DEVICE TO TRY AGAIN.',
			'confirmDevice.linkIt' => 'LINK DEVICE',
			'switchAccounts.noAccountDetails' => 'NO ACCOUNT DETAILS YET',
			'switchAccounts.currentAccount' => 'CURRENT ACCOUNT',
			'switchAccounts.otherAccounts' => 'OTHER ACCOUNTS',
			'switchAccounts.linkToAnother' => 'LINK TO ANOTHER ACCOUNT',
			'switchAccounts.linkWithSibling' => 'LINK WITH OTHER HAM2K APP',
			'switchAccounts.linkWithPolo' => 'LINK WITH ACCOUNT IN OLDER VERSION',
			'switchAccounts.linkWithSiblingDescription' => 'YOU HAVE ANOTHER HAM2K APP INSTALLED. LINK WITH THE ACCOUNT IN USE THERE.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'APPROVE THE REQUEST IN ${app}, THEN COME BACK HERE.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'OPEN ${app} AGAIN',
			'switchAccounts.siblingNoGrant' => 'DIDN\'T WORK? OPEN IT AGAIN, OR GO BACK AND LINK ANOTHER WAY.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'COULD NOT OPEN ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'THE LINK EXPIRED AND A NEW ONE IS READY — OPEN ${app} AGAIN.',
			'switchAccounts.tryAgain' => 'TRY AGAIN',
			'switchAccounts.linkWithQr' => 'LINK WITH A QR CODE',
			'switchAccounts.linkWithQrDescription' => 'SCAN IT FROM A DEVICE ALREADY USING THE ACCOUNT',
			'switchAccounts.linkWithEmail' => 'LINK WITH AN EMAIL ADDRESS',
			'switchAccounts.linkWithEmailDescription' => 'CONFIRM WITH A CODE OR AN EMAIL LINK',
			'switchAccounts.enterEmailPrompt' => 'ENTER THE EMAIL ADDRESS OF THE ACCOUNT YOU WANT THIS DEVICE TO USE.',
			'switchAccounts.emailAddress' => 'EMAIL ADDRESS',
			'switchAccounts.linkAccount' => 'LINK ACCOUNT',
			'switchAccounts.copiedCode' => 'COPIED CODE TO CLIPBOARD',
			'switchAccounts.copyCode' => 'COPY CODE',
			'switchAccounts.codePrompt' => ({required Object email}) => 'OPEN THE HAM2K APP ON A DEVICE ALREADY LINKED WITH ${email} AND ENTER THIS CODE TO APPROVE THE REQUEST:',
			'switchAccounts.waitingForConfirmation' => 'WAITING FOR CONFIRMATION…',
			'switchAccounts.sendEmailInstead' => 'SEND A CONFIRMATION EMAIL INSTEAD',
			'switchAccounts.emailSent' => ({required Object email}) => 'AN EMAIL WAS SENT TO ${email}. OPEN IT AND CONFIRM THE REQUEST TO LINK THIS DEVICE.',
			'switchAccounts.resendEmail' => 'RESEND EMAIL',
			'switchAccounts.qrPrompt' => 'SCAN THIS QR CODE FROM A DEVICE ALREADY LINKED TO THE ACCOUNT YOU WANT — FOR EXAMPLE WITH HAM2K PORTABLE LOGGER ON YOUR PHONE.',
			'switchAccounts.serverUnreachable' => 'COULD NOT REACH THE SYNC SERVER. TRY AGAIN LATER.',
			'switchAccounts.emailRequired' => 'ENTER AN EMAIL ADDRESS TO LINK.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'NO ACCOUNT FOUND FOR ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'THE SYNC SERVER REJECTED THE REQUEST: ${error}',
			'switchAccounts.noLinkCode' => 'THE SYNC SERVER DID NOT RETURN A LINK CODE. TRY AGAIN LATER.',
			'switchAccounts.noConfirmationCode' => 'THE SYNC SERVER DID NOT SEND A CONFIRMATION CODE. TRY AGAIN LATER.',
			'switchAccounts.switchNotAccepted' => 'THAT ACCOUNT DID NOT ACCEPT THE SWITCH. TRY LINKING IT WITH AN EMAIL ADDRESS INSTEAD.',
			'switchAccounts.requestFailed' => 'SOMETHING WENT WRONG TALKING TO THE SYNC SERVER. TRY AGAIN LATER.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} QSO', other: '${count} QSOS', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} OPERATION', other: '${count} OPERATIONS', ), 
			'qsonImport.title' => 'IMPORT QSON OPERATION',
			'qsonImport.description' => 'CREATE A NEW OPERATION FROM A QSON FILE, AS DEVELOPER MODE EXPORTS ONE HERE OR IN POLO.',
			'qsonImport.dropHint' => 'DROP A QSON FILE TO IMPORT IT AS A NEW OPERATION',
			'qsonImport.importing' => ({required Object filename}) => 'IMPORTING ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'COULD NOT IMPORT ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'COULD NOT OPEN A FILE TO IMPORT: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} IS NOT UTF-8 TEXT, SO IT IS NOT A QSON FILE',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} IS NOT A JSON FILE, SO IT IS NOT A QSON FILE',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} DOES NOT HOLD A QSON OPERATION',
			'qsonImport.busy' => 'AN IMPORT IS ALREADY RUNNING. WAIT FOR IT TO FINISH BEFORE STARTING ANOTHER.',
			'qsonImport.oneFileOnly' => 'DROP ONE QSON FILE AT A TIME — EACH ONE OPENS AS ITS OWN OPERATION.',
			'adifImport.title' => 'IMPORT QSOS FROM ADIF',
			'adifImport.reading' => ({required Object filename}) => 'READING ${filename}…',
			'adifImport.dropHint' => 'DROP AN ADIF FILE TO IMPORT',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} QSO IN THIS FILE', other: '${formatted} QSOS IN THIS FILE', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} ALREADY IN YOUR LOG', other: '${formatted} ALREADY IN YOUR LOG', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} WILL BE IMPORTED', other: '${formatted} WILL BE IMPORTED', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} NEW CONTACT', other: '${formatted} NEW CONTACTS', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} WILL MERGE WITH AN EXISTING CONTACT', other: '${formatted} WILL MERGE WITH EXISTING CONTACTS', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} CANNOT BE IMPORTED (NO CALLSIGN)', other: '${formatted} CANNOT BE IMPORTED (NO CALLSIGN)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} NEEDS A CLOSER LOOK', other: '${formatted} NEED A CLOSER LOOK', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'REFERENCES COULD NOT BE RECOVERED FOR ${count} CONTACT', other: 'REFERENCES COULD NOT BE RECOVERED FOR ${formatted} CONTACTS', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${programs} REFERENCES MAY BE INCOMPLETE FOR ${count} CONTACT', other: '${programs} REFERENCES MAY BE INCOMPLETE FOR ${formatted} CONTACTS', ), 
			'adifImport.stackingTypesUnknown' => 'COMBINED CONTACTS MAY LOSE A REFERENCE — THE ACTIVITIES COULD NOT SAY WHICH TYPES STACK. CANCEL AND RETRY TO AVOID THIS.',
			'adifImport.nothingToImport' => 'NOTHING IN THIS FILE CAN BE IMPORTED',
			'adifImport.confirm' => 'IMPORT',
			'adifImport.importing' => ({required Object filename}) => 'IMPORTING ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: 'IMPORTED ${count} CONTACT FROM ${filename}', other: 'IMPORTED ${formatted} CONTACTS FROM ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'COULD NOT IMPORT ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} DOES NOT LOOK LIKE AN ADIF FILE',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'WARNING: THIS ADIF HAS QSOS FROM ${calls}, BUT THEY WILL BE IMPORTED AS ${station} IF YOU CONTINUE.',
			'adifImport.stationCallJoin' => ' AND ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('qro'))(count, one: '${count} HAS NO DATE AND CANNOT BE IMPORTED', other: '${formatted} HAVE NO DATE AND CANNOT BE IMPORTED', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'THIS FILE RECORDS AN ACTIVATION OF ${refs}.',
			'adifImport.addActivation' => 'ADD IT TO THIS OPERATION',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'ONLY ${written} OF ${planned} COULD BE APPLIED — THE LOG CHANGED WHILE YOU WERE DECIDING.',
			'adifImport.busy' => 'AN IMPORT IS ALREADY RUNNING. WAIT FOR IT TO FINISH BEFORE STARTING ANOTHER.',
			'adifImport.oneFileOnly' => 'DROP ONE ADIF FILE AT A TIME — THE ORDER FILES ARE IMPORTED IN DECIDES WHICH DATA WINS.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} HAS MORE THAN ${limit} QSOS, THE MOST AN OPERATION CAN IMPORT AT A TIME.',
			'offline.statusOffline' => 'INTERNET: OFFLINE',
			'offline.statusOnline' => 'INTERNET: CONNECTED',
			'offline.noRoute' => 'NO NETWORK CONNECTION AT ALL.',
			'offline.unreachable' => 'THE NETWORK IS UP, BUT NO SERVER IS RESPONDING — OFTEN A SIGN-IN PAGE WAITING IN A BROWSER.',
			'offline.reachable' => 'ALL SERVICES RESPONDING AS EXPECTED.',
			'offline.whatStops' => 'LOOKUPS, SPOTS AND DATA FILES ARE PAUSED. LOGGING AND NEARBY SYNC ARE NOT.',
			'offline.servicesTitle' => 'SERVICES',
			'offline.noServices' => 'NO SERVICE HAS REPORTED IN YET.',
			'offline.lastSuccess' => ({required Object when}) => 'LAST RESPONDED ${when} AGO',
			'offline.neverSucceeded' => 'HAS NOT RESPONDED YET',
			'offline.nextAttempt' => ({required Object when}) => 'NEXT ATTEMPT IN ${when}',
			'offline.nextAttemptNow' => 'NEXT ATTEMPT DUE',
			'offline.retry' => 'RETRY NOW',
			'offline.retrying' => 'TRYING…',
			'offline.retryReached' => 'BACK ONLINE.',
			'offline.retryUnreachable' => 'STILL NO RESPONSE.',
			'offline.retryNotAttempted' => 'NOTHING TO SEND RIGHT NOW.',
			'offline.retryThrottled' => 'JUST TRIED — GIVE IT A MOMENT.',
			'offline.retryDisabled' => 'SYNC IS SWITCHED OFF, SO THERE IS NOTHING TO PROBE WITH.',
			'offline.syncService' => 'HAM2K LOFI SYNC',
			'offline.retryInFlight' => 'ALREADY TRYING — HANG ON.',
			'exportSettings.defaultsDescription' => 'BASE SETTINGS FOR ALL EXPORTS, WITH SEPARATE FILENAME AND TITLE TEMPLATES FOR REFERENCE ACTIVITIES AND OTHER ACTIVITIES. EACH EXPORT TYPE CAN PROVIDE ITS OWN DEFAULTS OR CUSTOM SETTINGS.',
			'exportSettings.referenceActivities' => 'REFERENCE ACTIVITIES',
			'exportSettings.otherActivities' => 'OTHER ACTIVITIES',
			'exportSettings.adifFields' => 'ADIF FIELDS',
			'exportSettings.loadFailed' => 'EXPORT SETTINGS COULD NOT BE LOADED.',
			'exportSettings.retry' => 'RETRY',
			'exportSettings.compactFileNamesDescriptionOn' => 'COMPACT FILENAMES, SUCH AS N0CALL@US-1234-20260715.ADI.',
			'exportSettings.compactFileNamesDescriptionOff' => 'DESCRIPTIVE FILENAMES, SUCH AS 2026-07-15 N0CALL AT US-1234.ADI.',
			'exportSettings.includePrivateDataDescriptionOn' => 'INCLUDING NAMES, ADDRESSES, EMAILS, NOTES AND PRECISE LOCATIONS IN ADIF FILES.',
			'exportSettings.includePrivateDataDescriptionOff' => 'OMITTING NAMES, ADDRESSES, EMAILS AND NOTES; LIMITING LOCATIONS TO SIX-CHARACTER GRIDS.',
			'exportSettings.includeLookupDataDescriptionOn' => 'INCLUDING INFORMATION FROM CALLSIGN LOOKUP SERVICES.',
			'exportSettings.includeLookupDataDescriptionOff' => 'OMITTING INFORMATION FROM CALLSIGN LOOKUP SERVICES; KEEPING MANUALLY ENTERED VALUES.',
			'exportSettings.customTemplatesDescriptionOn' => 'YOUR CUSTOM TEMPLATES ARE ACTIVE AND CAN BE EDITED BELOW.',
			'exportSettings.customTemplatesDescriptionOff' => 'DEFAULT TEMPLATES ARE ACTIVE. YOUR CUSTOM TEMPLATES ARE KEPT FOR LATER.',
			'exportSettings.type' => 'EXPORT TYPE',
			'exportSettings.defaults' => 'DEFAULTS',
			'exportSettings.includeLookupData' => 'INCLUDE LOOKUP DATA',
			'exportSettings.customTemplates' => 'CUSTOM TEMPLATES',
			'exportSettings.filenameTemplate' => 'FILE NAME TEMPLATE',
			'exportSettings.compactFilenameTemplate' => 'COMPACT FILE NAME TEMPLATE',
			'exportSettings.titleTemplate' => 'TITLE TEMPLATE',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO NOTES',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO COMMENTS',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL MESSAGE',
			'exportSettings.shared' => 'SETTINGS APPLY TO EVERY EXTENSION USING THIS EXPORT TYPE.',
			'exportSettings.defaultTemplates' => 'TURN ON CUSTOM TEMPLATES TO EDIT THIS TYPE’S TEMPLATES.',
			'templateEditor.previewLabel' => 'PREVIEW:',
			'templateEditor.reset' => 'RESET',
			'templateEditor.docs' => 'TEMPLATING DOCS',
			'templateEditor.preview' => 'SAMPLE PREVIEW',
			'templateEditor.reference' => 'TEMPLATE REFERENCE',
			'templateEditor.attributes' => 'AVAILABLE ATTRIBUTES',
			'templateEditor.filters' => 'FILTERS',
			'templateEditor.flowControl' => 'FLOW CONTROL',
			'templateEditor.unavailable' => 'PREVIEW IS UNAVAILABLE UNTIL EXTENSIONS ARE READY.',
			'templateEditor.empty' => '(EMPTY OUTPUT)',
			_ => null,
		};
	}
}
