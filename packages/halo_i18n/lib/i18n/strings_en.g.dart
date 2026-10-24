///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$onboarding$en onboarding = Translations$onboarding$en.internal(_root);
	late final Translations$startScreen$en startScreen = Translations$startScreen$en.internal(_root);
	late final Translations$testerOverlay$en testerOverlay = Translations$testerOverlay$en.internal(_root);
	late final Translations$extensionsPanel$en extensionsPanel = Translations$extensionsPanel$en.internal(_root);
	late final Translations$home$en home = Translations$home$en.internal(_root);
	late final Translations$chase$en chase = Translations$chase$en.internal(_root);
	late final Translations$dialogs$en dialogs = Translations$dialogs$en.internal(_root);
	late final Translations$operation$en operation = Translations$operation$en.internal(_root);
	late final Translations$map$en map = Translations$map$en.internal(_root);
	late final Translations$mapsView$en mapsView = Translations$mapsView$en.internal(_root);
	late final Translations$activitiesView$en activitiesView = Translations$activitiesView$en.internal(_root);
	late final Translations$loggingControls$en loggingControls = Translations$loggingControls$en.internal(_root);
	late final Translations$formChrome$en formChrome = Translations$formChrome$en.internal(_root);
	late final Translations$qsoEditForm$en qsoEditForm = Translations$qsoEditForm$en.internal(_root);
	late final Translations$qsoList$en qsoList = Translations$qsoList$en.internal(_root);
	late final Translations$loggingPanel$en loggingPanel = Translations$loggingPanel$en.internal(_root);
	late final Translations$callInfo$en callInfo = Translations$callInfo$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
	late final Translations$commands$en commands = Translations$commands$en.internal(_root);
	late final Translations$commandDialog$en commandDialog = Translations$commandDialog$en.internal(_root);
	late final Translations$keyboardShortcuts$en keyboardShortcuts = Translations$keyboardShortcuts$en.internal(_root);
	late final Translations$expiredBuild$en expiredBuild = Translations$expiredBuild$en.internal(_root);
	late final Translations$staleness$en staleness = Translations$staleness$en.internal(_root);
	late final Translations$spotting$en spotting = Translations$spotting$en.internal(_root);
	late final Translations$dataFiles$en dataFiles = Translations$dataFiles$en.internal(_root);
	late final Translations$updates$en updates = Translations$updates$en.internal(_root);
	late final Translations$extensionService$en extensionService = Translations$extensionService$en.internal(_root);
	late final Translations$operationLocationScreen$en operationLocationScreen = Translations$operationLocationScreen$en.internal(_root);
	late final Translations$versionLabel$en versionLabel = Translations$versionLabel$en.internal(_root);
	late final Translations$notices$en notices = Translations$notices$en.internal(_root);
	late final Translations$syncAccount$en syncAccount = Translations$syncAccount$en.internal(_root);
	late final Translations$deepLink$en deepLink = Translations$deepLink$en.internal(_root);
	late final Translations$confirmDevice$en confirmDevice = Translations$confirmDevice$en.internal(_root);
	late final Translations$switchAccounts$en switchAccounts = Translations$switchAccounts$en.internal(_root);
	late final Translations$qsonImport$en qsonImport = Translations$qsonImport$en.internal(_root);
	late final Translations$adifImport$en adifImport = Translations$adifImport$en.internal(_root);
	late final Translations$offline$en offline = Translations$offline$en.internal(_root);
	late final Translations$exportSettings$en exportSettings = Translations$exportSettings$en.internal(_root);
	late final Translations$templateEditor$en templateEditor = Translations$templateEditor$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'OK'
	String get ok => 'OK';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Done'
	String get done => 'Done';

	/// en: 'Callsign'
	String get callsign => 'Callsign';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Dismiss'
	String get dismiss => 'Dismiss';

	/// en: 'Expand'
	String get expand => 'Expand';

	/// en: 'Collapse'
	String get collapse => 'Collapse';
}

// Path: onboarding
class Translations$onboarding$en {
	Translations$onboarding$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Welcome to Ham2K Portable Logger!'
	String get welcomeTitle => 'Welcome to Ham2K Portable Logger!';

	/// en: 'Welcome to Ham2K Power Logger!'
	String get welcomeTitleDesktop => 'Welcome to Ham2K Power Logger!';

	/// en: 'We have a few questions to help us better suit your needs.'
	String get welcomeBody => 'We have a few questions to help us better suit your needs.';

	/// en: 'Skip'
	String get skip => 'Skip';

	/// en: 'Continue'
	String get kContinue => 'Continue';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Next'
	String get next => 'Next';

	/// en: 'Done'
	String get done => 'Done';

	/// en: 'What's your callsign?'
	String get callsignTitle => 'What\'s your callsign?';

	/// en: 'You need an Amateur Radio Operator License in order to find this app useful'
	String get callsignBody => 'You need an Amateur Radio Operator License in order to find this app useful';

	/// en: 'Operator's Callsign'
	String get callsignLabel => 'Operator\'s Callsign';

	/// en: 'Already have an account?'
	String get alreadyHaveAccount => 'Already have an account?';

	/// en: 'Link an existing account?'
	String get foundSiblingTitle => 'Link an existing account?';

	/// en: 'We found ${app} on this device. Link this app to the same account and your callsign and logs come across.'
	String foundSiblingBody({required Object app}) => 'We found ${app} on this device. Link this app to the same account and your callsign and logs come across.';

	/// en: 'We found an older version of Ham2K Portable Logger on this device. Link this app to the same account and your callsign and logs come across.'
	String get foundPoloBody => 'We found an older version of Ham2K Portable Logger on this device. Link this app to the same account and your callsign and logs come across.';

	/// en: 'We found other Ham2K apps on this device. Link this app to one of their accounts and your callsign and logs come across.'
	String get foundSiblingsBody => 'We found other Ham2K apps on this device. Link this app to one of their accounts and your callsign and logs come across.';

	/// en: 'Link with ${app}'
	String linkWithApp({required Object app}) => 'Link with ${app}';

	/// en: 'Link with account in older version'
	String get linkWithPolo => 'Link with account in older version';

	/// en: 'Set up fresh'
	String get setUpFresh => 'Set up fresh';

	/// en: 'Favorite Activities'
	String get activitiesTitle => 'Favorite Activities';

	/// en: 'Are you interested in any of these popular activation programs?'
	String get activitiesBody => 'Are you interested in any of these popular activation programs?';

	/// en: '(You can find more options in the Settings)'
	String get activitiesFooter => '(You can find more options in the Settings)';

	/// en: 'Parks On The Air'
	String get activityPota => 'Parks On The Air';

	/// en: 'Summits On The Air'
	String get activitySota => 'Summits On The Air';

	/// en: 'World Wide Flora & Fauna'
	String get activityWwff => 'World Wide Flora & Fauna';

	/// en: 'Data & Privacy'
	String get consentTitle => 'Data & Privacy';

	/// en: 'To help us make the app better, we'd like to collect performance, crash, and app usage data.'
	String get consentUsageBody => 'To help us make the app better, we\'d like to collect performance, crash, and app usage data.';

	/// en: 'Share app usage data'
	String get consentUsageLabel => 'Share app usage data';

	/// en: 'Some features might involve sharing your operation data with other users. You can opt-out at any time.'
	String get consentOperationBody => 'Some features might involve sharing your operation data with other users. You can opt-out at any time.';

	/// en: 'Share Operation Data'
	String get consentOperationLabel => 'Share Operation Data';

	/// en: 'Finishing setup — downloading reference data…'
	String get finishingSetup => 'Finishing setup — downloading reference data…';
}

// Path: startScreen
class Translations$startScreen$en {
	Translations$startScreen$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'by KI2D and friends'
	String get credits => 'by KI2D and friends';
}

// Path: testerOverlay
class Translations$testerOverlay$en {
	Translations$testerOverlay$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'CAUTION: UNDER CONSTRUCTION'
	String get tape => 'CAUTION: UNDER CONSTRUCTION';

	/// en: 'This app is a work in progress'
	String get warningTitle => 'This app is a work in progress';

	/// en: 'Most features have uneven surfaces and there are trip hazards all over. Please check for updates regularly.'
	String get warningBody => 'Most features have uneven surfaces and there are trip hazards all over. Please check for updates regularly.';

	/// en: 'What's new in build ${build}'
	String whatsNew({required Object build}) => 'What\'s new in build ${build}';

	/// en: 'Thank you for putting your log at risk in order to help us make this app better!'
	String get thanks => 'Thank you for putting your log at risk in order to help us make this app better!';
}

// Path: extensionsPanel
class Translations$extensionsPanel$en {
	Translations$extensionsPanel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get categoryActivity => 'Activities';

	/// en: 'Awards'
	String get categoryAward => 'Awards';

	/// en: 'Contests'
	String get categoryContest => 'Contests';

	/// en: 'Callsign Lookups'
	String get categoryLookup => 'Callsign Lookups';

	/// en: 'Spot Sources'
	String get categorySpots => 'Spot Sources';

	/// en: 'Dashboard Panels'
	String get categoryDashboard => 'Dashboard Panels';

	/// en: 'Other Extensions'
	String get categoryOther => 'Other Extensions';

	/// en: 'Search extensions'
	String get searchHint => 'Search extensions';

	/// en: 'Activating extension changes, this may take a moment…'
	String get applying => 'Activating extension changes, this may take a moment…';

	/// en: 'No extensions match your search'
	String get noMatches => 'No extensions match your search';

	/// en: 'Install from file…'
	String get installFromFile => 'Install from file…';

	/// en: 'Version ${version}'
	String installVersion({required Object version}) => 'Version ${version}';

	/// en: 'Screenshot ${n} of ${count}'
	String screenshotLabel({required Object n, required Object count}) => 'Screenshot ${n} of ${count}';

	/// en: '+${count}'
	String moreScreenshots({required Object count}) => '+${count}';

	/// en: 'Previous screenshot'
	String get previousScreenshot => 'Previous screenshot';

	/// en: 'Next screenshot'
	String get nextScreenshot => 'Next screenshot';

	/// en: 'Screenshot unavailable'
	String get screenshotUnavailable => 'Screenshot unavailable';

	/// en: 'This extension can contact'
	String get canReach => 'This extension can contact';

	/// en: '${host}, over a live connection'
	String canHoldConnection({required Object host}) => '${host}, over a live connection';

	/// en: 'Devices on your local network, over a live connection'
	String get canHoldLocalConnection => 'Devices on your local network, over a live connection';

	/// en: 'Your location'
	String get canUseLocation => 'Your location';

	/// en: 'Your radio, to read its frequency and mode'
	String get canReadRadio => 'Your radio, to read its frequency and mode';

	/// en: 'Your radio, to control it and to transmit with it — tuning, power, CW, voice memories and PTT'
	String get canControlRadio => 'Your radio, to control it and to transmit with it — tuning, power, CW, voice memories and PTT';

	/// en: 'Your radio, to send it any command in its own protocol — including ones that transmit or change its settings'
	String get canCommandRadioRaw => 'Your radio, to send it any command in its own protocol — including ones that transmit or change its settings';

	/// en: 'The DX cluster, logged in as you, to read what it sends'
	String get canReadCluster => 'The DX cluster, logged in as you, to read what it sends';

	/// en: 'The DX cluster, logged in as you, to post spots in your name'
	String get canSpotCluster => 'The DX cluster, logged in as you, to post spots in your name';

	/// en: 'The DX cluster, logged in as you, to send it any command in your name'
	String get canCommandCluster => 'The DX cluster, logged in as you, to send it any command in your name';

	/// en: 'Identify itself to servers under its own name'
	String get canSetUserAgent => 'Identify itself to servers under its own name';

	/// en: 'It asks for nothing outside the app.'
	String get noCapabilities => 'It asks for nothing outside the app.';

	/// en: 'Extensions run sandboxed: no access to your files, and no network beyond what is listed here.'
	String get sandboxNote => 'Extensions run sandboxed: no access to your files, and no network beyond what is listed here.';

	/// en: 'Install'
	String get installAction => 'Install';

	/// en: 'Update'
	String get updateAction => 'Update';

	/// en: 'That extension could not be installed'
	String get installFailed => 'That extension could not be installed';

	/// en: 'Installed'
	String get installedBadge => 'Installed';

	/// en: 'Remove'
	String get uninstallAction => 'Remove';

	/// en: 'Remove ${name}?'
	String uninstallTitle({required Object name}) => 'Remove ${name}?';

	/// en: 'This extension and its settings will be removed. Your logs will remain untouched.'
	String get uninstallBody => 'This extension and its settings will be removed. Your logs will remain untouched.';

	/// en: 'Installed ${name}'
	String installedMessage({required Object name}) => 'Installed ${name}';

	/// en: 'Downloading…'
	String get installDownloading => 'Downloading…';

	/// en: 'Waiting to install…'
	String get installWaiting => 'Waiting to install…';

	/// en: 'Installing…'
	String get installInstalling => 'Installing…';

	/// en: 'Waiting for your approval…'
	String get installAwaitingApproval => 'Waiting for your approval…';

	/// en: '${name} is already being installed.'
	String installAlreadyRunning({required Object name}) => '${name} is already being installed.';

	/// en: 'Updated to ${version}'
	String updatedTo({required Object version}) => 'Updated to ${version}';

	/// en: 'Installing ${name} did not finish. It may need installing again.'
	String installIncomplete({required Object name}) => 'Installing ${name} did not finish. It may need installing again.';

	/// en: 'Could not remove ${name}'
	String uninstallFailed({required Object name}) => 'Could not remove ${name}';

	/// en: 'Downloaded from ${source}'
	String installedFrom({required Object source}) => 'Downloaded from ${source}';

	/// en: 'Drop a .h2kext extension to install it'
	String get dropHint => 'Drop a .h2kext extension to install it';

	/// en: 'Drop one extension at a time.'
	String get dropOneOnly => 'Drop one extension at a time.';

	/// en: '${source} returned ${status} for that extension.'
	String downloadFailed({required Object source, required Object status}) => '${source} returned ${status} for that extension.';

	/// en: 'That download is far too large to be an extension.'
	String get downloadTooLarge => 'That download is far too large to be an extension.';

	/// en: 'That download redirected somewhere insecure.'
	String get downloadNotSecure => 'That download redirected somewhere insecure.';

	/// en: 'Catalog'
	String get catalogSection => 'Catalog';

	/// en: 'Loading the catalog…'
	String get catalogLoading => 'Loading the catalog…';

	/// en: 'Catalog unreachable'
	String get catalogUnreachable => 'Catalog unreachable';

	/// en: 'Built in'
	String get builtIn => 'Built in';

	/// en: 'Update available'
	String get updateAvailableBadge => 'Update available';

	/// en: 'Extension updates'
	String get updatesAvailableTitle => 'Extension updates';

	/// en: 'An update is available for ${name}.'
	String updateAvailableFor({required Object name}) => 'An update is available for ${name}.';

	/// en: '${names} and ${count} more need updating.'
	String updatesAvailable({required Object names, required Object count}) => '${names} and ${count} more need updating.';

	/// en: '${names} need updating.'
	String updatesAvailableFor({required Object names}) => '${names} need updating.';

	/// en: 'Pending Updates'
	String get pendingUpdatesSection => 'Pending Updates';

	/// en: 'Update all'
	String get updateAllAction => 'Update all';

	/// en: 'Those updates are already under way.'
	String get updatesUnderWay => 'Those updates are already under way.';

	/// en: 'Your extensions are up to date.'
	String get updatesNothingLeft => 'Your extensions are up to date.';

	/// en: 'More info'
	String get updatesNoticeAction => 'More info';

	/// en: '(one) {Update ${count} extension?} (other) {Update ${count} extensions?}'
	String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Update ${count} extension?',
		other: 'Update ${count} extensions?',
	);

	/// en: 'Your extensions are ready'
	String get upgradeDoneTitle => 'Your extensions are ready';

	/// en: 'They now come from the Ham2K extension catalog, so they can be updated without waiting for a new version of the app.'
	String get upgradeDoneBody => 'They now come from the Ham2K extension catalog, so they can be updated without waiting for a new version of the app.';

	/// en: 'Not upgraded: ${names}.'
	String upgradeDoneUnserved({required Object names}) => 'Not upgraded: ${names}.';

	/// en: 'Would not run: ${names}.'
	String upgradeDoneRefused({required Object names}) => 'Would not run: ${names}.';

	/// en: 'They are still installed and marked in Settings › Extensions — updating them there will bring them back.'
	String get upgradeDoneRefusedHint => 'They are still installed and marked in Settings › Extensions — updating them there will bring them back.';

	/// en: 'The catalog has no direct replacement for these, so look there for extensions that cover what you used.'
	String get upgradeDoneUnservedHint => 'The catalog has no direct replacement for these, so look there for extensions that cover what you used.';

	/// en: 'QSO Parties'
	String get retiredQp => 'QSO Parties';

	/// en: 'State Parks Events'
	String get retiredStateparks => 'State Parks Events';

	/// en: '${count} of your extensions have not arrived yet. They will be downloaded the next time the extension catalog can be reached.'
	String upgradeDoneMissing({required Object count}) => '${count} of your extensions have not arrived yet. They will be downloaded the next time the extension catalog can be reached.';

	/// en: 'Your extensions would not start. Restarting the app should bring them back.'
	String get runtimeDeadBody => 'Your extensions would not start. Restarting the app should bring them back.';

	/// en: 'Some extensions would not run'
	String get refusedTitle => 'Some extensions would not run';

	/// en: 'Still setting up'
	String get upgradeBusyTitle => 'Still setting up';

	/// en: 'Your extensions are not running'
	String get upgradeRuntimeDeadTitle => 'Your extensions are not running';

	/// en: 'Some of your extensions are missing'
	String get restoreTitle => 'Some of your extensions are missing';

	/// en: 'These extensions you installed are not on this device. We can download them again from the Ham2K extension catalog:'
	String get restoreBody => 'These extensions you installed are not on this device. We can download them again from the Ham2K extension catalog:';

	/// en: 'Installed from a file. Install these again from their files, or forget them:'
	String get restoreFromFile => 'Installed from a file. Install these again from their files, or forget them:';

	/// en: 'Installed from a different extension catalog, so they are not available here:'
	String get restoreOtherCatalog => 'Installed from a different extension catalog, so they are not available here:';

	/// en: 'Forget'
	String get restoreForget => 'Forget';

	/// en: 'Install'
	String get restoreInstall => 'Install';

	/// en: 'Later'
	String get restoreLater => 'Later';

	/// en: 'Installing your extensions…'
	String get restoreInstalling => 'Installing your extensions…';

	/// en: 'Your extensions are back'
	String get restoreDoneTitle => 'Your extensions are back';

	/// en: 'Installed again: ${names}.'
	String restoreDoneBody({required Object names}) => 'Installed again: ${names}.';

	/// en: 'Some extensions could not be installed'
	String get restorePartialTitle => 'Some extensions could not be installed';

	/// en: 'Could not install: ${names}. We will offer them again next time you open the app.'
	String restoreFailed({required Object names}) => 'Could not install: ${names}. We will offer them again next time you open the app.';

	/// en: 'The app is still setting your extensions up. We will offer these again next time you open the app.'
	String get restoreBusyBody => 'The app is still setting your extensions up. We will offer these again next time you open the app.';

	/// en: 'We installed them again, but your extensions would not start. Restarting the app should bring them back.'
	String get restoreRuntimeDeadBody => 'We installed them again, but your extensions would not start. Restarting the app should bring them back.';

	/// en: '${name} was withdrawn'
	String revokedTitle({required Object name}) => '${name} was withdrawn';

	/// en: 'The catalog withdrew this version, so it has been disabled.'
	String get revokedBody => 'The catalog withdrew this version, so it has been disabled.';

	/// en: 'That download is not the extension the catalog described.'
	String get downloadHashMismatch => 'That download is not the extension the catalog described.';

	/// en: 'The catalog has no version ${version} of ${key}.'
	String catalogVersionUnknown({required Object version, required Object key}) => 'The catalog has no version ${version} of ${key}.';

	/// en: 'That catalog link does not name an extension version.'
	String get catalogLinkUnknown => 'That catalog link does not name an extension version.';

	/// en: 'The catalog has no release of ${key} on that track.'
	String catalogNoRelease({required Object key}) => 'The catalog has no release of ${key} on that track.';

	/// en: 'Install from link'
	String get installFromLink => 'Install from link';

	/// en: 'This is an unstable release, which its publisher has not called finished. It may misbehave, and it will keep receiving unstable updates.'
	String get unstableReleaseWarning => 'This is an unstable release, which its publisher has not called finished. It may misbehave, and it will keep receiving unstable updates.';

	/// en: 'This is a bleeding-edge release: work in progress that may break or lose its settings. It will keep receiving bleeding-edge updates.'
	String get bleedingReleaseWarning => 'This is a bleeding-edge release: work in progress that may break or lose its settings. It will keep receiving bleeding-edge updates.';

	/// en: 'Unstable'
	String get channelUnstable => 'Unstable';

	/// en: 'Bleeding'
	String get channelBleeding => 'Bleeding';

	/// en: 'Receives unstable and stable releases'
	String get followsUnstable => 'Receives unstable and stable releases';

	/// en: 'Receives bleeding-edge, unstable and stable releases'
	String get followsBleeding => 'Receives bleeding-edge, unstable and stable releases';

	/// en: 'Follow stable releases only'
	String get followStableAction => 'Follow stable releases only';

	/// en: 'Revoked'
	String get revokedBadge => 'Revoked';

	/// en: 'Did not load'
	String get refusedBadge => 'Did not load';

	/// en: 'That download is not over a secure connection.'
	String get downloadNotHttps => 'That download is not over a secure connection.';

	/// en: '${source} could not be reached for that extension.'
	String downloadUnreachable({required Object source}) => '${source} could not be reached for that extension.';

	/// en: 'Details'
	String get detailsAction => 'Details';

	/// en: 'Installed from a file'
	String get installedFromFile => 'Installed from a file';

	/// en: 'Provides support for'
	String get detailsWhatItDoes => 'Provides support for';

	/// en: 'Pre-installed'
	String get installedPreloaded => 'Pre-installed';

	/// en: 'Account sign-in'
	String get hookAccount => 'Account sign-in';

	/// en: 'Call notes'
	String get hookCallNotes => 'Call notes';

	/// en: 'Offline data'
	String get hookDataFile => 'Offline data';

	/// en: 'Export'
	String get hookExport => 'Export';

	/// en: 'Callsign lookups'
	String get hookLookup => 'Callsign lookups';

	/// en: 'Scoring'
	String get hookScoring => 'Scoring';

	/// en: 'Spots'
	String get hookSpots => 'Spots';

	/// en: 'Hunting ${program}'
	String hookHunting({required Object program}) => 'Hunting ${program}';

	/// en: 'Activating ${program}'
	String hookActivating({required Object program}) => 'Activating ${program}';

	/// en: '(one) {… and ${count} other extension} (other) {… and ${count} other extensions}'
	String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '… and ${count} other extension',
		other: '… and ${count} other extensions',
	);

	/// en: '(one) {${count} extension available} (other) {${count} extensions available}'
	String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} extension available',
		other: '${count} extensions available',
	);
}

// Path: home
class Translations$home$en {
	Translations$home$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Portable Logger'
	String get title => 'Portable Logger';

	/// en: 'New operation'
	String get newOperation => 'New operation';

	/// en: 'Station callsign'
	String get stationCallsign => 'Station callsign';

	/// en: 'Title (optional)'
	String get titleOptional => 'Title (optional)';

	/// en: 'No operations yet. Create one to start logging.'
	String get emptyList => 'No operations yet. Create one to start logging.';

	/// en: 'Quick Lookup'
	String get quickLookup => 'Quick Lookup';

	late final Translations$home$nav$en nav = Translations$home$nav$en.internal(_root);
	late final Translations$home$panels$en panels = Translations$home$panels$en.internal(_root);

	/// en: 'Show or hide the navigation labels'
	String get toggleNav => 'Show or hide the navigation labels';

	late final Translations$home$logs$en logs = Translations$home$logs$en.internal(_root);
}

// Path: chase
class Translations$chase$en {
	Translations$chase$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'op'
	String get operatorPrefix => 'op';

	/// en: 'chasing'
	String get chasing => 'chasing';

	/// en: '${first} & ${second}'
	String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';

	/// en: '${first}, ${second} & more'
	String goalsMore({required Object first, required Object second}) => '${first}, ${second} & more';

	late final Translations$chase$station$en station = Translations$chase$station$en.internal(_root);
	late final Translations$chase$periodInline$en periodInline = Translations$chase$periodInline$en.internal(_root);
	late final Translations$chase$periodStats$en periodStats = Translations$chase$periodStats$en.internal(_root);
	late final Translations$chase$period$en period = Translations$chase$period$en.internal(_root);
	late final Translations$chase$goals$en goals = Translations$chase$goals$en.internal(_root);
	late final Translations$chase$panels$en panels = Translations$chase$panels$en.internal(_root);
	late final Translations$chase$claims$en claims = Translations$chase$claims$en.internal(_root);
	late final Translations$chase$notice$en notice = Translations$chase$notice$en.internal(_root);
	late final Translations$chase$alerts$en alerts = Translations$chase$alerts$en.internal(_root);

	/// en: 'Chasing Progress'
	String get checklists => 'Chasing Progress';

	late final Translations$chase$imports$en imports = Translations$chase$imports$en.internal(_root);
}

// Path: dialogs
class Translations$dialogs$en {
	Translations$dialogs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation details'
	String get operationDetails => 'Operation details';

	/// en: 'Activities'
	String get activities => 'Activities';

	/// en: 'Station Callsign'
	String get stationCallsign => 'Station Callsign';

	/// en: 'Multi-station identifier (numbers only)'
	String get multiStationIdentifier => 'Multi-station identifier (numbers only)';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'Delete Operation'
	String get deleteOperationTitle => 'Delete Operation';

	/// en: 'Purge Test Operations'
	String get purgeTestsTitle => 'Purge Test Operations';

	/// en: 'This permanently deletes these Test Operations and their QSOs. It cannot be undone.'
	String get purgeTestsBody => 'This permanently deletes these Test Operations and their QSOs. It cannot be undone.';

	/// en: '(one) {Plus ${count} test contact that belongs to no operation.} (other) {Plus ${count} test contacts that belong to no operation.}'
	String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Plus ${count} test contact that belongs to no operation.',
		other: 'Plus ${count} test contacts that belong to no operation.',
	);

	/// en: 'Purge'
	String get purgeTestsAction => 'Purge';

	/// en: 'Replace this device's log?'
	String get syncAllTitle => 'Replace this device\'s log?';

	/// en: 'SYNCALL backs up and clears ${qsos} from this device, then downloads the account's log again from the server. The backup stays in this device's database.'
	String syncAllBody({required Object qsos}) => 'SYNCALL backs up and clears ${qsos} from this device, then downloads the account\'s log again from the server. The backup stays in this device\'s database.';

	/// en: '(one) {${n} QSO has not been synced yet — the server never received it, and it will NOT come back.} (other) {${n} QSOs have not been synced yet — the server never received them, and they will NOT come back.}'
	String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} QSO has not been synced yet — the server never received it, and it will NOT come back.',
		other: '${n} QSOs have not been synced yet — the server never received them, and they will NOT come back.',
	);

	/// en: 'Wipe and Resync'
	String get syncAllAction => 'Wipe and Resync';

	/// en: 'Test Operations Removed Elsewhere'
	String get receivedPurgesTitle => 'Test Operations Removed Elsewhere';

	/// en: 'These were deleted as Test Operations on another device. Remove them here too? This permanently deletes them and their QSOs, and cannot be undone.'
	String get receivedPurgesBody => 'These were deleted as Test Operations on another device. Remove them here too? This permanently deletes them and their QSOs, and cannot be undone.';

	/// en: 'Remove'
	String get receivedPurgesAction => 'Remove';

	late final Translations$dialogs$callChange$en callChange = Translations$dialogs$callChange$en.internal(_root);
}

// Path: operation
class Translations$operation$en {
	Translations$operation$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This operation is deleted. Undelete it to log or make changes.'
	String get deletedReadOnly => 'This operation is deleted. Undelete it to log or make changes.';

	late final Translations$operation$tabs$en tabs = Translations$operation$tabs$en.internal(_root);
	late final Translations$operation$positions$en positions = Translations$operation$positions$en.internal(_root);

	/// en: 'No station callsign'
	String get stationCallsignNone => 'No station callsign';

	/// en: 'No title'
	String get titleNone => 'No title';

	/// en: 'Delete operation'
	String get deleteOperation => 'Delete operation';

	/// en: 'Activity fields may be out of date — reopen the operation to refresh them'
	String get loggingControlsStale => 'Activity fields may be out of date — reopen the operation to refresh them';

	/// en: 'Not set'
	String get locationNone => 'Not set';

	/// en: 'General Operation'
	String get generalOperation => 'General Operation';

	/// en: 'for ${value}'
	String titleFor({required Object value}) => 'for ${value}';

	/// en: 'at ${value}'
	String titleAt({required Object value}) => 'at ${value}';

	/// en: 'Now ${description}'
	String segmentNow({required Object description}) => 'Now ${description}';

	/// en: 'Testing'
	String get testOperationSuffix => 'Testing';

	late final Translations$operation$menu$en menu = Translations$operation$menu$en.internal(_root);
	late final Translations$operation$layout$en layout = Translations$operation$layout$en.internal(_root);
	late final Translations$operation$export$en export = Translations$operation$export$en.internal(_root);
	late final Translations$operation$spots$en spots = Translations$operation$spots$en.internal(_root);
	late final Translations$operation$import$en import = Translations$operation$import$en.internal(_root);
}

// Path: map
class Translations$map$en {
	Translations$map$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$map$outlineIssue$en outlineIssue = Translations$map$outlineIssue$en.internal(_root);

	/// en: 'Outlines are for reference only. Do your own research!'
	String get outlinesDisclaimer => 'Outlines are for reference only. Do your own research!';

	/// en: 'Outlines: ${sources}'
	String outlinesCredit({required Object sources}) => 'Outlines: ${sources}';

	/// en: 'Boundaries: ${sources}'
	String boundariesCredit({required Object sources}) => 'Boundaries: ${sources}';

	/// en: 'Facilities: ${sources}'
	String facilitiesCredit({required Object sources}) => 'Facilities: ${sources}';

	/// en: 'Full dataset credits'
	String get fullCredits => 'Full dataset credits';

	/// en: 'Fewer credits'
	String get fewerCredits => 'Fewer credits';

	/// en: 'No QSO locations yet. QSOs with a grid square, state, or country will show up here.'
	String get emptyState => 'No QSO locations yet.\nQSOs with a grid square, state, or country will show up here.';

	/// en: 'The map isn't available right now.'
	String get unavailable => 'The map isn\'t available right now.';

	/// en: 'QTH: ${grid}'
	String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';

	/// en: '${distance} km'
	String distanceKm({required Object distance}) => '${distance} km';

	/// en: '${distance} mi'
	String distanceMiles({required Object distance}) => '${distance} mi';

	/// en: 'Flat'
	String get flat => 'Flat';

	/// en: 'Globe'
	String get globe => 'Globe';

	/// en: 'Zoom in'
	String get zoomIn => 'Zoom in';

	/// en: 'Zoom out'
	String get zoomOut => 'Zoom out';

	/// en: 'Reset to north up'
	String get resetNorth => 'Reset to north up';

	late final Translations$map$postcard$en postcard = Translations$map$postcard$en.internal(_root);
}

// Path: mapsView
class Translations$mapsView$en {
	Translations$mapsView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Maps'
	String get title => 'Maps';

	/// en: 'Search parks, summits and more'
	String get searchHint => 'Search parks, summits and more';

	/// en: 'Activities'
	String get activities => 'Activities';

	/// en: 'Layers'
	String get layers => 'Layers';

	/// en: 'Base map'
	String get baseMap => 'Base map';

	/// en: 'Satellite (Esri)'
	String get satellite => 'Satellite (Esri)';

	/// en: 'Park facilities'
	String get facilities => 'Park facilities';

	/// en: 'Boundaries'
	String get boundaries => 'Boundaries';

	/// en: 'Current location'
	String get currentLocation => 'Current location';

	/// en: 'Nothing matches “${text}”'
	String noMatches({required Object text}) => 'Nothing matches “${text}”';

	/// en: '(one) {${count} Reference at ${where}} (other) {${count} References at ${where}}'
	String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Reference at ${where}',
		other: '${count} References at ${where}',
	);

	/// en: 'Start an operation with these references'
	String get startOperation => 'Start an operation with these references';
}

// Path: activitiesView
class Translations$activitiesView$en {
	Translations$activitiesView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get title => 'Activities';

	/// en: 'No Activities Selected'
	String get activitiesCountZero => 'No Activities Selected';

	/// en: '1 Activity'
	String get activitiesCountOne => '1 Activity';

	/// en: '${count} Activities'
	String activitiesCountOther({required Object count}) => '${count} Activities';

	/// en: 'No activities yet — use Suggestions & Search below to add one'
	String get empty => 'No activities yet — use Suggestions & Search below to add one';

	/// en: 'Remove'
	String get removeActivity => 'Remove';

	/// en: 'Open ${name}'
	String openReferenceLink({required Object name}) => 'Open ${name}';

	/// en: 'Edit activity'
	String get editActivity => 'Edit activity';

	/// en: 'Manage Extensions'
	String get manageExtensions => 'Manage Extensions';

	/// en: 'Manage'
	String get manage => 'Manage';

	/// en: 'Activity Types: ${first}'
	String activitiesTitle1({required Object first}) => 'Activity Types: ${first}';

	/// en: 'Activity Types: ${first} and ${second}'
	String activitiesTitle2({required Object first, required Object second}) => 'Activity Types: ${first} and ${second}';

	/// en: 'Activity Types: ${first}, ${second} and ${more} more'
	String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Activity Types: ${first}, ${second} and ${more} more';

	/// en: 'Reference'
	String get reference => 'Reference';

	/// en: 'Not valid'
	String get invalidReference => 'Not valid';

	/// en: 'Already added'
	String get duplicateReference => 'Already added';

	/// en: 'Search by name, reference or anything else…'
	String get searchHint => 'Search by name, reference or anything else…';

	/// en: 'No matches'
	String get noSuggestions => 'No matches';

	/// en: 'Search by reference name or number above'
	String get noSuggestionsHint => 'Search by reference name or number above';

	/// en: '(for example 'trail' or '4556')'
	String get noSuggestionsExample => '(for example \'trail\' or \'4556\')';

	/// en: 'Activity Types'
	String get allOptions => 'Activity Types';

	/// en: 'Determining current location… Waiting for GPS fix to find nearby references'
	String get determiningLocation => 'Determining current location…\nWaiting for GPS fix to find nearby references';

	/// en: 'Location data not available'
	String get locationUnavailableTitle => 'Location data not available';

	/// en: 'Location permission denied'
	String get locationDeniedTitle => 'Location permission denied';

	/// en: 'Location permission blocked'
	String get locationBlockedTitle => 'Location permission blocked';

	/// en: 'Cannot determine nearby references'
	String get noNearbyReason => 'Cannot determine nearby references';

	/// en: 'Tap ${icon} to manually enter your location, or just search for references by name'
	String locationManualHint({required Object icon}) => 'Tap ${icon} to manually enter your location,\nor just search for references by name';

	/// en: 'Allow location access'
	String get locationGrantAction => 'Allow location access';

	/// en: 'Open Settings'
	String get locationSettingsAction => 'Open Settings';

	/// en: 'Allow location access in your system settings'
	String get locationSettingsUnavailable => 'Allow location access in your system settings';

	/// en: 'Still no location — the system said no again'
	String get locationGrantRefused => 'Still no location — the system said no again';

	/// en: 'Activity search unavailable'
	String get searchUnavailableTitle => 'Activity search unavailable';

	/// en: 'No activity extension could run the search. Try again in a moment.'
	String get searchUnavailableReason => 'No activity extension could run the search. Try again in a moment.';

	/// en: 'Use suggestions & search below to add one'
	String get emptySheet => 'Use suggestions & search below to add one';

	/// en: 'Exports'
	String get exports => 'Exports';

	/// en: 'Export Logs'
	String get exportLogs => 'Export Logs';

	/// en: 'Tools'
	String get tools => 'Tools';

	/// en: 'Operation Tools'
	String get toolsTitle => 'Operation Tools';

	/// en: 'Operation Details'
	String get operationDetails => 'Operation Details';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Delete Operation'
	String get deleteOperation => 'Delete Operation';

	/// en: 'Undelete Operation'
	String get undeleteOperation => 'Undelete Operation';

	/// en: 'Already selected'
	String get alreadySelected => 'Already selected';

	/// en: 'Selected'
	String get selected => 'Selected';

	/// en: '${index} of ${count}'
	String pickPosition({required Object index, required Object count}) => '${index} of ${count}';

	/// en: 'Previous match'
	String get previousPick => 'Previous match';

	/// en: 'Next match'
	String get nextPick => 'Next match';

	/// en: 'Retired'
	String get retiredReference => 'Retired';

	/// en: 'Enable ${name}'
	String enableExtension({required Object name}) => 'Enable ${name}';

	/// en: 'This extension matches your search, but it is not currently enabled'
	String get enableExtensionHint => 'This extension matches your search, but it is not currently enabled';

	/// en: 'This extension handles one of this operation's references, but it is not currently enabled'
	String get enableExtensionForRefHint => 'This extension handles one of this operation\'s references, but it is not currently enabled';

	/// en: '${name} is not running'
	String extensionNotRunning({required Object name}) => '${name} is not running';

	/// en: 'This extension has been disabled, open Extension Settings for more info'
	String get extensionNotRunningHint => 'This extension has been disabled, open Extension Settings for more info';

	/// en: 'Install ${name}'
	String installExtension({required Object name}) => 'Install ${name}';

	/// en: 'This extension matches your search, but it is not installed'
	String get installExtensionHint => 'This extension matches your search, but it is not installed';

	/// en: 'No matches Some extensions in the catalog might have results. Install them in Activity Types below.'
	String get onlyCatalogMatches => 'No matches\nSome extensions in the catalog might have results.\nInstall them in Activity Types below.';

	/// en: 'Could not load this activity's setup — try again from Manage'
	String get setupUnavailable => 'Could not load this activity\'s setup — try again from Manage';

	/// en: 'Activity controls unavailable'
	String get controlsUnavailableTitle => 'Activity controls unavailable';

	/// en: 'Your references are safe, but editing them is unavailable right now.'
	String get controlsUnavailableReason => 'Your references are safe, but editing them is unavailable right now.';

	/// en: 'Retry'
	String get controlsUnavailableRetry => 'Retry';

	/// en: 'No matches Some available extensions might have results. Enable them in Activity Types below.'
	String get onlyDisabledMatches => 'No matches\nSome available extensions might have results.\nEnable them in Activity Types below.';

	/// en: 'No matches Some extensions that might have results are not running. See Activity Types below.'
	String get onlyNotRunningMatches => 'No matches\nSome extensions that might have results are not running.\nSee Activity Types below.';

	/// en: 'Map'
	String get mapToggle => 'Map';

	/// en: 'Search'
	String get searchToggle => 'Search';

	/// en: 'Add to Operation'
	String get addToOperation => 'Add to Operation';

	/// en: 'Add to Op.'
	String get addToOperationShort => 'Add to Op.';

	/// en: 'No results to show on the map'
	String get mapEmptyState => 'No results to show on the map';

	/// en: 'Switch back to the list, or search for something else'
	String get mapEmptyStateHint => 'Switch back to the list, or search for something else';

	/// en: 'Imports'
	String get imports => 'Imports';
}

// Path: loggingControls
class Translations$loggingControls$en {
	Translations$loggingControls$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Time (UTC)'
	String get timeUtc => 'Time (UTC)';

	/// en: 'Date'
	String get date => 'Date';

	/// en: 'Now'
	String get now => 'Now';

	/// en: 'Manual Time'
	String get manualTimeSettings => 'Manual Time';

	/// en: 'Increment per QSO'
	String get manualTimeIncrement => 'Increment per QSO';

	/// en: 'None'
	String get manualTimeIncrementNone => 'None';

	/// en: '(one) {${count} minute} (other) {${count} minutes}'
	String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} minute',
		other: '${count} minutes',
	);

	/// en: 'Frequency'
	String get frequency => 'Frequency';

	/// en: 'Mode'
	String get mode => 'Mode';

	/// en: 'Their call'
	String get theirCall => 'Their call';

	/// en: 'Note'
	String get noteField => 'Note';

	/// en: 'Todo'
	String get todoField => 'Todo';

	/// en: 'Sent'
	String get sent => 'Sent';

	/// en: 'Rcvd'
	String get rcvd => 'Rcvd';

	/// en: 'More'
	String get more => 'More';

	/// en: 'Revert'
	String get revert => 'Revert';

	/// en: 'Undo delete'
	String get undoDelete => 'Undo delete';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'Wipe'
	String get wipe => 'Wipe';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'Tap the trashcan one more time to delete this QSO'
	String get pendingDeleteTapWarning => 'Tap the trashcan one more time to delete this QSO';

	/// en: 'Click the trashcan one more time to delete this QSO'
	String get pendingDeleteClickWarning => 'Click the trashcan one more time to delete this QSO';

	/// en: 'Deleted QSO'
	String get deletedQsoWarning => 'Deleted QSO';

	/// en: 'Tap the trashcan one more time to delete this ${kind}'
	String pendingDeleteEventTapWarning({required Object kind}) => 'Tap the trashcan one more time to delete this ${kind}';

	/// en: 'Click the trashcan one more time to delete this ${kind}'
	String pendingDeleteEventClickWarning({required Object kind}) => 'Click the trashcan one more time to delete this ${kind}';

	/// en: 'Deleted ${kind}'
	String deletedEventWarning({required Object kind}) => 'Deleted ${kind}';

	/// en: 'Time'
	String get timeControl => 'Time';

	/// en: 'Radio'
	String get radioControl => 'Radio';

	/// en: 'Power'
	String get powerControl => 'Power';

	/// en: 'Notes'
	String get notesControl => 'Notes';

	/// en: 'Power'
	String get power => 'Power';

	/// en: 'W'
	String get powerUnit => 'W';

	/// en: 'Logging Controls'
	String get controlSettings => 'Logging Controls';

	/// en: 'Spotting'
	String get spottingControl => 'Spotting';

	/// en: 'Self-spotting'
	String get spottingSelfControl => 'Self-spotting';

	/// en: 'Self-spot at ${freq}'
	String spotSelfAt({required Object freq}) => 'Self-spot at ${freq}';

	/// en: 'Spot ${call} at ${freq}'
	String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} at ${freq}';

	/// en: 'Too late to spot ${call}'
	String spotTooLate({required Object call}) => 'Too late to spot ${call}';

	/// en: 'First set a frequency to spot'
	String get spotNoFreq => 'First set a frequency to spot';

	/// en: 'Comment'
	String get spotComment => 'Comment';

	/// en: 'Auto re-spot'
	String get spottingAutoControl => 'Auto re-spot';

	/// en: 'Re-spot every ${minutes} min'
	String spotAutoEvery({required Object minutes}) => 'Re-spot every ${minutes} min';

	/// en: 'Auto in ${time}. Stop?'
	String spotAutoNext({required Object time}) => 'Auto in ${time}. Stop?';

	/// en: 'Auto in ${minutes}m'
	String spotAutoInMinutes({required Object minutes}) => 'Auto in ${minutes}m';

	/// en: 'Auto in ${seconds}s'
	String spotAutoInSeconds({required Object seconds}) => 'Auto in ${seconds}s';

	/// en: 'Auto in ${seconds}'
	String spotAutoInCount({required Object seconds}) => 'Auto in ${seconds}';

	/// en: 'Auto re-spot not started: the spot did not go through'
	String get spotAutoNotStarted => 'Auto re-spot not started: the spot did not go through';

	/// en: 'Auto re-spot not started: the frequency changed while spotting'
	String get spotAutoMoved => 'Auto re-spot not started: the frequency changed while spotting';

	/// en: 'Auto re-spot stopped'
	String get spotAutoStopped => 'Auto re-spot stopped';

	/// en: 'Auto re-spot stopped: the frequency changed'
	String get spotAutoLeftFreq => 'Auto re-spot stopped: the frequency changed';

	/// en: 'Auto re-spot stopped: the radio reports no frequency'
	String get spotAutoNoFreq => 'Auto re-spot stopped: the radio reports no frequency';

	/// en: 'Another spot is still being sent'
	String get spotBusy => 'Another spot is still being sent';

	/// en: 'Set a frequency or band before logging'
	String get bandOrFreqRequired => 'Set a frequency or band before logging';

	/// en: 'No Band'
	String get missingBand => 'No Band';

	/// en: 'No Mode'
	String get missingMode => 'No Mode';

	/// en: 'Could not save: ${error}'
	String saveFailed({required Object error}) => 'Could not save: ${error}';

	/// en: 'Could not delete: ${error}'
	String deleteFailed({required Object error}) => 'Could not delete: ${error}';

	late final Translations$loggingControls$info$en info = Translations$loggingControls$info$en.internal(_root);
}

// Path: formChrome
class Translations$formChrome$en {
	Translations$formChrome$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '(untitled)'
	String get untitled => '(untitled)';

	/// en: 'Show more'
	String get showMore => 'Show more';

	/// en: 'Show all'
	String get showAll => 'Show all';

	/// en: 'Show fewer'
	String get showFewer => 'Show fewer';

	/// en: 'Defaults'
	String get defaults => 'Defaults';

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Open page'
	String get openPage => 'Open page';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'Not Connected'
	String get notConnected => 'Not Connected';

	/// en: 'Manage'
	String get manage => 'Manage';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Form'
	String get formTitle => 'Form';

	/// en: 'Add ${label}'
	String addItem({required Object label}) => 'Add ${label}';

	/// en: 'Edit ${label}'
	String editItem({required Object label}) => 'Edit ${label}';

	/// en: 'Showing ${shown} of ${total} (${selected} selected)'
	String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Showing ${shown} of ${total} (${selected} selected)';

	/// en: 'Validation error: ${error}'
	String validationError({required Object error}) => 'Validation error: ${error}';

	/// en: 'Transformation error: ${error}'
	String transformationError({required Object error}) => 'Transformation error: ${error}';

	/// en: 'Error: ${error}'
	String actionError({required Object error}) => 'Error: ${error}';

	/// en: 'Delete'
	String get removeItem => 'Delete';

	/// en: 'Delete ${name}?'
	String deleteItemTitle({required Object name}) => 'Delete ${name}?';

	/// en: 'Logins unavailable'
	String get storageUnavailable => 'Logins unavailable';
}

// Path: qsoEditForm
class Translations$qsoEditForm$en {
	Translations$qsoEditForm$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Edit QSO'
	String get title => 'Edit QSO';

	/// en: 'Operator'
	String get operatorCall => 'Operator';

	/// en: 'Position'
	String get position => 'Position';

	/// en: 'Name'
	String get theirName => 'Name';

	/// en: 'Grid'
	String get theirGrid => 'Grid';

	/// en: 'State'
	String get theirState => 'State';

	/// en: 'Band'
	String get band => 'Band';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'QSO'
	String get sectionQso => 'QSO';

	/// en: 'Their info'
	String get sectionTheir => 'Their info';

	/// en: 'Our info'
	String get sectionOur => 'Our info';

	/// en: 'Notes'
	String get sectionNotes => 'Notes';

	/// en: 'City'
	String get theirCity => 'City';

	/// en: 'County'
	String get theirCounty => 'County';

	/// en: 'Entity'
	String get theirEntity => 'Entity';

	/// en: 'CQ Zone'
	String get theirCqZone => 'CQ Zone';

	/// en: 'ITU Zone'
	String get theirItuZone => 'ITU Zone';

	/// en: 'ARRL Section'
	String get theirArrlSection => 'ARRL Section';

	/// en: 'Latitude'
	String get theirLat => 'Latitude';

	/// en: 'Longitude'
	String get theirLon => 'Longitude';

	/// en: 'Their power'
	String get theirPower => 'Their power';
}

// Path: qsoList
class Translations$qsoList$en {
	Translations$qsoList$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No QSOs yet — work someone!'
	String get empty => 'No QSOs yet — work someone!';

	/// en: 'Please make sure your band and mode are correct'
	String get bandOrModeWarning => 'Please make sure your band and mode are correct';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'Tomorrow'
	String get tomorrow => 'Tomorrow';

	late final Translations$qsoList$find$en find = Translations$qsoList$find$en.internal(_root);
}

// Path: loggingPanel
class Translations$loggingPanel$en {
	Translations$loggingPanel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation Stats'
	String get stats => 'Operation Stats';

	/// en: 'Scoring'
	String get scoring => 'Scoring';

	/// en: 'DXCC entities'
	String get dxccEntities => 'DXCC entities';

	/// en: 'States'
	String get statesWorked => 'States';

	/// en: 'Provinces'
	String get provincesWorked => 'Provinces';

	/// en: 'Duplicates'
	String get duplicates => 'Duplicates';
}

// Path: callInfo
class Translations$callInfo$en {
	Translations$callInfo$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'QRZ'
	String get qrz => 'QRZ';

	/// en: 'Show Image'
	String get showImage => 'Show Image';

	/// en: 'Photo unavailable'
	String get imageUnavailable => 'Photo unavailable';

	/// en: 'Photo'
	String get photo => 'Photo';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: '${distance} to'
	String distanceTo({required Object distance}) => '${distance} to';

	/// en: '${distance} (${bearing}°) to'
	String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to';

	/// en: '${distance} (${bearing}° / ${reverse}°) to'
	String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to';

	/// en: '${distance} away'
	String distanceAway({required Object distance}) => '${distance} away';

	/// en: '${distance} (${bearing}°) away'
	String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';

	/// en: '${distance} (${bearing}° / ${reverse}°) away'
	String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away';

	/// en: '1 QSO in this operation'
	String get thisOpCountOne => '1 QSO in this operation';

	/// en: '${count} QSOs in this operation'
	String thisOpCountOther({required Object count}) => '${count} QSOs in this operation';

	/// en: '1 QSO in other operations'
	String get otherOpsCountOne => '1 QSO in other operations';

	/// en: '${count} QSOs in other operations'
	String otherOpsCountOther({required Object count}) => '${count} QSOs in other operations';

	/// en: '… and ${count} more'
	String andMore({required Object count}) => '… and ${count} more';

	/// en: 'with ${call}'
	String withCall({required Object call}) => 'with ${call}';

	/// en: 'from ${where}'
	String fromOperation({required Object where}) => 'from ${where}';

	late final Translations$callInfo$history$en history = Translations$callInfo$history$en.internal(_root);
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get title => 'Settings';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'Follow system settings (${language})'
	String languageSystem({required Object language}) => 'Follow system settings (${language})';

	late final Translations$settings$theme$en theme = Translations$settings$theme$en.internal(_root);
	late final Translations$settings$themeDescription$en themeDescription = Translations$settings$themeDescription$en.internal(_root);

	/// en: 'Font Scale'
	String get fontScale => 'Font Scale';

	late final Translations$settings$fontScaleOpts$en fontScaleOpts = Translations$settings$fontScaleOpts$en.internal(_root);
	late final Translations$settings$keepDeviceAwake$en keepDeviceAwake = Translations$settings$keepDeviceAwake$en.internal(_root);

	/// en: 'Layout Density'
	String get layoutDensity => 'Layout Density';

	late final Translations$settings$layoutDensityOpts$en layoutDensityOpts = Translations$settings$layoutDensityOpts$en.internal(_root);

	/// en: 'the window is too short, using ${effective}'
	String layoutDensityClamped({required Object effective}) => 'the window is too short, using ${effective}';

	/// en: 'as far as it goes'
	String get layoutDensityAtLimit => 'as far as it goes';

	/// en: 'Distance Units'
	String get distanceUnits => 'Distance Units';

	late final Translations$settings$distanceUnitsOpts$en distanceUnitsOpts = Translations$settings$distanceUnitsOpts$en.internal(_root);

	/// en: 'User Interface'
	String get userInterface => 'User Interface';

	late final Translations$settings$logging$en logging = Translations$settings$logging$en.internal(_root);
	late final Translations$settings$catServer$en catServer = Translations$settings$catServer$en.internal(_root);
	late final Translations$settings$cluster$en cluster = Translations$settings$cluster$en.internal(_root);
	late final Translations$settings$spotting$en spotting = Translations$settings$spotting$en.internal(_root);
	late final Translations$settings$radio$en radio = Translations$settings$radio$en.internal(_root);
	late final Translations$settings$help$en help = Translations$settings$help$en.internal(_root);
	late final Translations$settings$exports$en exports = Translations$settings$exports$en.internal(_root);
	late final Translations$settings$extensionSections$en extensionSections = Translations$settings$extensionSections$en.internal(_root);
	late final Translations$settings$map$en map = Translations$settings$map$en.internal(_root);
	late final Translations$settings$privacy$en privacy = Translations$settings$privacy$en.internal(_root);

	/// en: 'Operator Callsign'
	String get operatorCall => 'Operator Callsign';

	late final Translations$settings$sync$en sync = Translations$settings$sync$en.internal(_root);
	late final Translations$settings$peers$en peers = Translations$settings$peers$en.internal(_root);

	/// en: 'Developer Mode'
	String get developerMode => 'Developer Mode';

	late final Translations$settings$syncPanel$en syncPanel = Translations$settings$syncPanel$en.internal(_root);
	late final Translations$settings$accounts$en accounts = Translations$settings$accounts$en.internal(_root);
	late final Translations$settings$station$en station = Translations$settings$station$en.internal(_root);
	late final Translations$settings$offlineData$en offlineData = Translations$settings$offlineData$en.internal(_root);
	late final Translations$settings$profiles$en profiles = Translations$settings$profiles$en.internal(_root);
	late final Translations$settings$search$en search = Translations$settings$search$en.internal(_root);
	late final Translations$settings$developer$en developer = Translations$settings$developer$en.internal(_root);
	late final Translations$settings$about$en about = Translations$settings$about$en.internal(_root);
	late final Translations$settings$panels$en panels = Translations$settings$panels$en.internal(_root);

	/// en: 'Show more settings'
	String get showMoreSettings => 'Show more settings';

	/// en: 'Number Formatting'
	String get numberFormat => 'Number Formatting';

	late final Translations$settings$numberFormatOpts$en numberFormatOpts = Translations$settings$numberFormatOpts$en.internal(_root);
	late final Translations$settings$numberFormatDescription$en numberFormatDescription = Translations$settings$numberFormatDescription$en.internal(_root);
	late final Translations$settings$numberFormatSeparators$en numberFormatSeparators = Translations$settings$numberFormatSeparators$en.internal(_root);

	/// en: 'Grid Precision'
	String get gridPrecision => 'Grid Precision';

	late final Translations$settings$gridPrecisionOpts$en gridPrecisionOpts = Translations$settings$gridPrecisionOpts$en.internal(_root);
	late final Translations$settings$gridPrecisionDescription$en gridPrecisionDescription = Translations$settings$gridPrecisionDescription$en.internal(_root);
}

// Path: commands
class Translations$commands$en {
	Translations$commands$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Enable sync in Settings first.'
	String get enableSyncFirst => 'Enable sync in Settings first.';

	/// en: 'Full resync started — local data was backed up first.'
	String get fullResyncStarted => 'Full resync started — local data was backed up first.';

	/// en: 'No data files matched "${target}".'
	String noDataFilesMatched({required Object target}) => 'No data files matched "${target}".';

	/// en: 'Reload failed: ${error}'
	String reloadFailed({required Object error}) => 'Reload failed: ${error}';

	/// en: 'Reloading all data files…'
	String get reloadingAll => 'Reloading all data files…';

	/// en: 'Reloading ${target} data files…'
	String reloadingTarget({required Object target}) => 'Reloading ${target} data files…';

	/// en: 'Unknown experiment "${token}"'
	String unknownExperiment({required Object token}) => 'Unknown experiment "${token}"';

	/// en: '${name} enabled'
	String experimentEnabled({required Object name}) => '${name} enabled';

	/// en: '${name} disabled'
	String experimentDisabled({required Object name}) => '${name} disabled';

	/// en: 'Test error report sent to Sentry'
	String get sentryTestSent => 'Test error report sent to Sentry';

	/// en: 'Idle metrics enabled in the status bar'
	String get idleMetricsEnabled => 'Idle metrics enabled in the status bar';

	/// en: 'Idle metrics disabled'
	String get idleMetricsDisabled => 'Idle metrics disabled';

	/// en: 'Sentry is disabled in this build — test error logged locally only'
	String get sentryTestLocalOnly => 'Sentry is disabled in this build — test error logged locally only';

	/// en: 'That command needs an open operation'
	String get noOperationOpen => 'That command needs an open operation';

	/// en: 'Don't know how to mark a '${kind}''
	String unknownSegmentKind({required Object kind}) => 'Don\'t know how to mark a \'${kind}\'';

	/// en: '${place} isn't turned on in this app'
	String goUnavailable({required Object place}) => '${place} isn\'t turned on in this app';

	/// en: 'Don't know how to go to '${to}''
	String goUnknown({required Object to}) => 'Don\'t know how to go to \'${to}\'';

	/// en: 'Close the open dialog first'
	String get goBlocked => 'Close the open dialog first';

	/// en: 'This operation already has a start marker'
	String get operationAlreadyStarted => 'This operation already has a start marker';

	/// en: 'Added the break, but could not open the location screen'
	String get couldNotOpenLocation => 'Added the break, but could not open the location screen';

	/// en: 'No Test Operations to purge'
	String get noTestOperations => 'No Test Operations to purge';

	/// en: 'PURGETESTS needs to show a confirmation dialog, which isn't available here'
	String get purgeTestsUnavailable => 'PURGETESTS needs to show a confirmation dialog, which isn\'t available here';

	/// en: 'SYNCALL needs to show a confirmation dialog, which isn't available here'
	String get syncAllUnavailable => 'SYNCALL needs to show a confirmation dialog, which isn\'t available here';

	/// en: '(one) {Purged ${count} Test Operation} (other) {Purged ${count} Test Operations}'
	String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Purged ${count} Test Operation',
		other: 'Purged ${count} Test Operations',
	);

	/// en: 'Purged ${purged} of ${total} Test Operations — the rest failed; try PURGETESTS again'
	String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Purged ${purged} of ${total} Test Operations — the rest failed; try PURGETESTS again';

	/// en: '(one) {Purged ${count} test contact with no operation} (other) {Purged ${count} test contacts with no operation}'
	String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Purged ${count} test contact with no operation',
		other: 'Purged ${count} test contacts with no operation',
	);

	/// en: 'Purged the Test Operations, but the test contacts with no operation failed; try PURGETESTS again'
	String get purgeTestsContactsFailed => 'Purged the Test Operations, but the test contacts with no operation failed; try PURGETESTS again';

	/// en: 'Nothing was purged'
	String get purgeTestsNothingToDo => 'Nothing was purged';

	/// en: 'Removed ${removed} of ${total} Test Operations — the rest failed; try Review again'
	String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Removed ${removed} of ${total} Test Operations — the rest failed; try Review again';

	/// en: 'Couldn't remove those Test Operations — try Review again'
	String get receivedPurgesFailed => 'Couldn\'t remove those Test Operations — try Review again';

	/// en: '(one) {${count} Test Operation was removed on another device} (other) {${count} Test Operations were removed on another device}'
	String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Test Operation was removed on another device',
		other: '${count} Test Operations were removed on another device',
	);

	/// en: 'Review'
	String get receivedPurgesReview => 'Review';

	/// en: 'On'
	String get settingOn => 'On';

	/// en: 'Off'
	String get settingOff => 'Off';

	/// en: '(empty)'
	String get settingEmpty => '(empty)';

	/// en: '(set)'
	String get settingSecretSet => '(set)';

	/// en: '(not set)'
	String get settingSecretUnset => '(not set)';

	/// en: '${count} selected'
	String settingSelectedCount({required Object count}) => '${count} selected';

	/// en: 'on or off'
	String get settingExpectsOnOff => 'on or off';

	/// en: 'one of: ${choices}'
	String settingExpectsOneOf({required Object choices}) => 'one of: ${choices}';

	/// en: 'a number'
	String get settingExpectsNumber => 'a number';

	/// en: '“${label}” is no longer available'
	String settingVanished({required Object label}) => '“${label}” is no longer available';

	/// en: 'No connected radio can key CW'
	String get noCwKeyer => 'No connected radio can key CW';

	/// en: 'No connected radio can key CW or play voice memories'
	String get noKeyer => 'No connected radio can key CW or play voice memories';

	/// en: 'Open an operation to use the CW keyer'
	String get keyerNeedsOperation => 'Open an operation to use the CW keyer';

	/// en: 'CW keying is off — turn it on with EXP KEYER'
	String get keyerExperimentOff => 'CW keying is off — turn it on with EXP KEYER';

	/// en: 'Enter Sends Messages is off — turn it on with EXP ESM'
	String get esmExperimentOff => 'Enter Sends Messages is off — turn it on with EXP ESM';

	/// en: 'Sending CW: $text'
	String cwSending({required Object text}) => 'Sending CW: ${text}';

	/// en: 'CW message F$n: $error'
	String cwMessageError({required Object n, required Object error}) => 'CW message F${n}: ${error}';

	/// en: 'CW message F$n was not sent: the extensions are not ready'
	String cwMessageNotRendered({required Object n}) => 'CW message F${n} was not sent: the extensions are not ready';

	/// en: '“${label}” did not accept that value'
	String settingNotStored({required Object label}) => '“${label}” did not accept that value';
}

// Path: commandDialog
class Translations$commandDialog$en {
	Translations$commandDialog$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search callsigns or type a command'
	String get hint => 'Search callsigns or type a command';

	/// en: 'Nothing matches “${text}”'
	String noResults({required Object text}) => 'Nothing matches “${text}”';

	/// en: 'Commands'
	String get sectionCommands => 'Commands';

	/// en: 'Go to'
	String get sectionGoTo => 'Go to';

	/// en: 'Operations'
	String get sectionOperations => 'Operations';

	/// en: 'Home'
	String get goHome => 'Home';

	/// en: 'Settings'
	String get goSettings => 'Settings';

	/// en: 'New operation'
	String get goNewOperation => 'New operation';

	/// en: 'Run “${text}”'
	String runTyped({required Object text}) => 'Run “${text}”';

	/// en: 'Try'
	String get sectionSuggestions => 'Try';

	/// en: 'Looking up callsign…'
	String get lookingUp => 'Looking up callsign…';

	/// en: 'Cannot use commands while a panel or dialog is open'
	String get blockedByPane => 'Cannot use commands while a panel or dialog is open';
}

// Path: keyboardShortcuts
class Translations$keyboardShortcuts$en {
	Translations$keyboardShortcuts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Keyboard Shortcuts'
	String get title => 'Keyboard Shortcuts';

	/// en: 'Customize key mappings'
	String get description => 'Customize key mappings';

	/// en: 'Search commands and keys'
	String get search => 'Search commands and keys';

	/// en: 'Import…'
	String get import => 'Import…';

	/// en: 'Export…'
	String get export => 'Export…';

	/// en: 'Reset All'
	String get resetAll => 'Reset All';

	/// en: 'Reset every shortcut?'
	String get resetAllTitle => 'Reset every shortcut?';

	/// en: 'Every command goes back to its default keys, and the keys bound to typed commands are removed.'
	String get resetAllBody => 'Every command goes back to its default keys, and the keys bound to typed commands are removed.';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'No key'
	String get noKey => 'No key';

	/// en: 'Changed'
	String get changed => 'Changed';

	/// en: '${keys} is also bound to ${commands}'
	String conflict({required Object keys, required Object commands}) => '${keys} is also bound to ${commands}';

	/// en: 'App'
	String get groupApp => 'App';

	/// en: 'Keying'
	String get groupKeying => 'Keying';

	/// en: 'Logging'
	String get groupLogging => 'Logging';

	/// en: 'Commands'
	String get groupCommands => 'Commands';

	/// en: 'Fixed Keys'
	String get groupFixed => 'Fixed Keys';

	/// en: 'Anywhere'
	String get contextApp => 'Anywhere';

	/// en: 'Operation, Chasing and Logs views'
	String get contextLogView => 'Operation, Chasing and Logs views';

	/// en: 'Operation view, keying a CAT radio'
	String get contextOperation => 'Operation view, keying a CAT radio';

	/// en: 'In the logging panel'
	String get contextLogging => 'In the logging panel';

	/// en: 'Add a Command…'
	String get addCommand => 'Add a Command…';

	/// en: 'Unknown command: ${command}'
	String unknownCommand({required Object command}) => 'Unknown command: ${command}';

	late final Translations$keyboardShortcuts$command$en command = Translations$keyboardShortcuts$command$en.internal(_root);
	late final Translations$keyboardShortcuts$fixed$en fixed = Translations$keyboardShortcuts$fixed$en.internal(_root);
	late final Translations$keyboardShortcuts$editor$en editor = Translations$keyboardShortcuts$editor$en.internal(_root);
	late final Translations$keyboardShortcuts$file$en file = Translations$keyboardShortcuts$file$en.internal(_root);
	late final Translations$keyboardShortcuts$modifier$en modifier = Translations$keyboardShortcuts$modifier$en.internal(_root);
	late final Translations$keyboardShortcuts$platform$en platform = Translations$keyboardShortcuts$platform$en.internal(_root);
}

// Path: expiredBuild
class Translations$expiredBuild$en {
	Translations$expiredBuild$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This build has expired'
	String get title => 'This build has expired';

	/// en: 'Please visit ham2k.com and get a newer version.'
	String get body => 'Please visit ham2k.com and get a newer version.';

	/// en: 'Visit ham2k.com'
	String get visit => 'Visit ham2k.com';

	/// en: 'Continue anyway'
	String get dismiss => 'Continue anyway';
}

// Path: staleness
class Translations$staleness$en {
	Translations$staleness$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'An important update is waiting'
	String get codePushFloorTitle => 'An important update is waiting';

	/// en: 'This version has a fix you don't have yet.'
	String get codePushFloorBody => 'This version has a fix you don\'t have yet.';

	/// en: 'Restart the app to apply it.'
	String get restartToApply => 'Restart the app to apply it.';

	/// en: 'Quit the app and open it again to apply it.'
	String get quitAndReopen => 'Quit the app and open it again to apply it.';

	/// en: 'Close the app and open it again to apply it.'
	String get reopenToApply => 'Close the app and open it again to apply it.';

	/// en: 'Ignore for now'
	String get ignoreForNow => 'Ignore for now';
}

// Path: spotting
class Translations$spotting$en {
	Translations$spotting$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No QSO logged yet to spot.'
	String get noQsoYet => 'No QSO logged yet to spot.';

	/// en: 'Set a frequency first.'
	String get setFrequencyFirst => 'Set a frequency first.';

	/// en: 'Nothing to spot — no extension offers spotting here.'
	String get nothingToSpot => 'Nothing to spot — no extension offers spotting here.';

	/// en: 'Can't spot an incomplete call — finish the callsign first.'
	String get incompleteCall => 'Can\'t spot an incomplete call — finish the callsign first.';

	/// en: '${source} failed: ${message}'
	String spotFailed({required Object source, required Object message}) => '${source} failed: ${message}';

	/// en: 'unknown error'
	String get unknownError => 'unknown error';

	/// en: 'Spot not sent.'
	String get notSent => 'Spot not sent.';

	/// en: 'Spot not sent: every spot source skipped it.'
	String get allSkipped => 'Spot not sent: every spot source skipped it.';

	/// en: 'No connection — spots were not refreshed'
	String get notRefreshedOffline => 'No connection — spots were not refreshed';
}

// Path: dataFiles
class Translations$dataFiles$en {
	Translations$dataFiles$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Downloading…'
	String get downloading => 'Downloading…';

	/// en: 'Couldn't download ${name}'
	String downloadFailedTitle({required Object name}) => 'Couldn\'t download ${name}';

	/// en: 'This could be a network issue, or this link's host may not support direct downloads from a web browser. Try the desktop or mobile app, or a different hosting location.'
	String get downloadFailedWebHint => 'This could be a network issue, or this link\'s host may not support direct downloads from a web browser. Try the desktop or mobile app, or a different hosting location.';

	/// en: 'The server took too long to respond. Try again later.'
	String get downloadTimedOut => 'The server took too long to respond. Try again later.';

	/// en: '${host} answered with an error (HTTP ${status}). Try again later.'
	String downloadServerError({required Object host, required Object status}) => '${host} answered with an error (HTTP ${status}). Try again later.';

	/// en: '${host} couldn't provide this file (HTTP ${status}). Check that its address is still right.'
	String downloadNotAvailable({required Object host, required Object status}) => '${host} couldn\'t provide this file (HTTP ${status}). Check that its address is still right.';

	/// en: 'N1MM has no call history file for ${stem}.'
	String n1mmHistoryNoMatch({required Object stem}) => 'N1MM has no call history file for ${stem}.';

	/// en: 'N1MM's call history download for ${stem} didn't work. Try again later.'
	String n1mmHistoryUnavailable({required Object stem}) => 'N1MM\'s call history download for ${stem} didn\'t work. Try again later.';

	/// en: 'Couldn't process ${name}'
	String processingFailedTitle({required Object name}) => 'Couldn\'t process ${name}';

	/// en: 'The download had only ${imported} of the ${existing} records on this device, so the ones it left out were kept. Refreshing it in Settings › Offline Data accepts it anyway.'
	String importTooSmall({required Object imported, required Object existing}) => 'The download had only ${imported} of the ${existing} records on this device, so the ones it left out were kept. Refreshing it in Settings › Offline Data accepts it anyway.';

	/// en: '(one) {Imported ${count} record for ${label}.} (other) {Imported ${count} records for ${label}.}'
	String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Imported ${count} record for ${label}.',
		other: 'Imported ${count} records for ${label}.',
	);

	/// en: 'Imported data for ${label}.'
	String importedData({required Object label}) => 'Imported data for ${label}.';

	/// en: 'Cleaned up extension data'
	String get cleanedUpTitle => 'Cleaned up extension data';

	/// en: '(one) {Removed data for ${count} data file from disabled extensions.} (other) {Removed data for ${count} data files from disabled extensions.}'
	String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Removed data for ${count} data file from disabled extensions.',
		other: 'Removed data for ${count} data files from disabled extensions.',
	);

	/// en: '${end} / ${total} records'
	String recordsProgress({required Object end, required Object total}) => '${end} / ${total} records';

	/// en: 'The file's source didn't provide a definition — its extension may be mid-restart or misconfigured. Try again in a moment.'
	String get definitionUnavailable => 'The file\'s source didn\'t provide a definition — its extension may be mid-restart or misconfigured. Try again in a moment.';
}

// Path: updates
class Translations$updates$en {
	Translations$updates$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Update available'
	String get updateAvailable => 'Update available';

	/// en: 'A new version (${version}) is available.'
	String newVersionAvailable({required Object version}) => 'A new version (${version}) is available.';

	/// en: 'Get it'
	String get getIt => 'Get it';

	/// en: 'OK'
	String get ok => 'OK';

	/// en: 'Update ready'
	String get updateReady => 'Update ready';

	/// en: 'An update has been downloaded. Restart to apply it.'
	String get restartToApply => 'An update has been downloaded. Restart to apply it.';

	/// en: 'An update has been downloaded. It will apply the next time you open the app.'
	String get appliesNextLaunch => 'An update has been downloaded. It will apply the next time you open the app.';

	/// en: 'Restart now'
	String get restartNow => 'Restart now';

	/// en: 'A newer version of this page is available. Reload to get it.'
	String get reloadToUpdate => 'A newer version of this page is available. Reload to get it.';

	/// en: 'Reload now'
	String get reloadNow => 'Reload now';

	/// en: 'Check for Updates'
	String get checkForUpdates => 'Check for Updates';

	/// en: 'Checking for updates…'
	String get checkingForUpdates => 'Checking for updates…';

	/// en: 'Up to date'
	String get upToDate => 'Up to date';

	/// en: 'Check automatically'
	String get automaticChecks => 'Check automatically';

	/// en: 'Look for new versions in the background, from the next time you start the app'
	String get automaticChecksDescription => 'Look for new versions in the background, from the next time you start the app';
}

// Path: extensionService
class Translations$extensionService$en {
	Translations$extensionService$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Extension runtime not ready.'
	String get runtimeNotReady => 'Extension runtime not ready.';

	/// en: 'Test failed: ${error}'
	String testFailed({required Object error}) => 'Test failed: ${error}';

	/// en: 'Connected as ${identity}'
	String connectedAs({required Object identity}) => 'Connected as ${identity}';

	/// en: 'Invalid field configuration'
	String get invalidFieldConfiguration => 'Invalid field configuration';

	/// en: 'Invalid value'
	String get invalidValue => 'Invalid value';

	/// en: 'Validation error: ${error}'
	String validationError({required Object error}) => 'Validation error: ${error}';

	/// en: 'Action failed: ${error}'
	String actionFailed({required Object error}) => 'Action failed: ${error}';

	/// en: 'The command failed to run'
	String get commandFailed => 'The command failed to run';

	/// en: 'Reports can't be sent right now'
	String get reportUnavailable => 'Reports can\'t be sent right now';

	/// en: 'Ham2K’s File Stash can’t be reached right now'
	String get stashUnavailable => 'Ham2K’s File Stash can’t be reached right now';

	/// en: '${name} spent too much time in its timers. They're stopped until the extensions restart.'
	String timersSuspendedBudget({required Object name}) => '${name} spent too much time in its timers. They\'re stopped until the extensions restart.';

	/// en: '${name}'s timers kept failing. They're stopped until the extensions restart.'
	String timersSuspendedFailures({required Object name}) => '${name}\'s timers kept failing. They\'re stopped until the extensions restart.';

	/// en: '${name} got stuck in a timer. Its timers are stopped until the extensions restart.'
	String timersSuspendedInterrupted({required Object name}) => '${name} got stuck in a timer. Its timers are stopped until the extensions restart.';
}

// Path: operationLocationScreen
class Translations$operationLocationScreen$en {
	Translations$operationLocationScreen$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation Location'
	String get title => 'Operation Location';

	/// en: 'Selected Location'
	String get selectedLocation => 'Selected Location';

	/// en: 'Maidenhead Grid Square Locator'
	String get gridSquare => 'Maidenhead Grid Square Locator';

	/// en: 'Needs 4, 6, 8 or 10 characters, like FN31pr'
	String get gridInvalid => 'Needs 4, 6, 8 or 10 characters, like FN31pr';

	/// en: 'Suggested Locations'
	String get suggestedLocations => 'Suggested Locations';

	/// en: 'Device GPS'
	String get deviceGps => 'Device GPS';

	/// en: 'GPS from ${device}'
	String peerGps({required Object device}) => 'GPS from ${device}';

	/// en: 'Locating…'
	String get locating => 'Locating…';

	/// en: 'Location unavailable'
	String get gpsUnavailable => 'Location unavailable';

	/// en: 'Location permission denied'
	String get permissionDenied => 'Location permission denied';

	/// en: 'Location permission blocked'
	String get permissionBlocked => 'Location permission blocked';

	/// en: 'More Details'
	String get moreDetails => 'More Details';

	/// en: 'State or Province (optional)'
	String get stateOrProvince => 'State or Province (optional)';

	/// en: 'Activity controls unavailable'
	String get controlsUnavailableTitle => 'Activity controls unavailable';

	/// en: 'These references are still usable; their activities just could not be reached.'
	String get controlsUnavailableReason => 'These references are still usable; their activities just could not be reached.';

	/// en: 'Retry'
	String get controlsUnavailableRetry => 'Retry';

	/// en: 'County (optional)'
	String get county => 'County (optional)';
}

// Path: versionLabel
class Translations$versionLabel$en {
	Translations$versionLabel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Version ${version}'
	String version({required Object version}) => 'Version ${version}';

	/// en: 'Patch ${patch}'
	String patch({required Object patch}) => 'Patch ${patch}';

	/// en: 'build ${build}'
	String build({required Object build}) => 'build ${build}';
}

// Path: notices
class Translations$notices$en {
	Translations$notices$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No notices yet'
	String get emptyHistory => 'No notices yet';

	/// en: 'This browser could not provide persistent storage — the log lives in memory only and will be LOST when this tab closes. Use a current Chrome, Firefox, Safari or Edge.'
	String get webStorageInMemory => 'This browser could not provide persistent storage — the log lives in memory only and will be LOST when this tab closes. Use a current Chrome, Firefox, Safari or Edge.';

	/// en: 'This browser is using fallback storage that is not safe with multiple tabs — keep a single tab open, and keep sync on.'
	String get webStorageUnreliable => 'This browser is using fallback storage that is not safe with multiple tabs — keep a single tab open, and keep sync on.';

	/// en: 'This log needs a newer version'
	String get logFromNewerBuildTitle => 'This log needs a newer version';

	/// en: 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Install the newer version again — or, if you meant to run this build, point it at a different data folder. The log is in ${location}'
	String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Install the newer version again — or, if you meant to run this build, point it at a different data folder. The log is in ${location}';

	/// en: 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Open this log with that newer version instead.'
	String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Open this log with that newer version instead.';

	/// en: 'Settings restored from a backup'
	String get preferencesRestoredTitle => 'Settings restored from a backup';

	/// en: 'The settings file could not be read, so HaLo restored the last good copy of it. Anything you changed in your previous session may need setting again. The unreadable file is kept alongside it, named shared_preferences.corrupt-….json.'
	String get preferencesRestored => 'The settings file could not be read, so HaLo restored the last good copy of it. Anything you changed in your previous session may need setting again. The unreadable file is kept alongside it, named shared_preferences.corrupt-….json.';

	/// en: 'Settings reset'
	String get preferencesResetTitle => 'Settings reset';

	/// en: 'The settings file could not be read and there was no backup to fall back on, so HaLo started with its defaults. The unreadable file is kept in the app's data folder, named shared_preferences.corrupt-….json.'
	String get preferencesReset => 'The settings file could not be read and there was no backup to fall back on, so HaLo started with its defaults. The unreadable file is kept in the app\'s data folder, named shared_preferences.corrupt-….json.';

	/// en: '${name} was not connected automatically'
	String autoConnectHeldTitle({required Object name}) => '${name} was not connected automatically';

	/// en: 'HaLo stopped responding the last time it started connecting to ${name}, so it left it alone this time rather than risk doing it again. Check that the radio is switched on and its cable is plugged in, then press Connect on it in Settings.'
	String autoConnectHeld({required Object name}) => 'HaLo stopped responding the last time it started connecting to ${name}, so it left it alone this time rather than risk doing it again. Check that the radio is switched on and its cable is plugged in, then press Connect on it in Settings.';
}

// Path: syncAccount
class Translations$syncAccount$en {
	Translations$syncAccount$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Anonymous Account (#${id})'
	String anonymous({required Object id}) => 'Anonymous Account (#${id})';

	/// en: '${email} (pending confirmation)'
	String pendingConfirmation({required Object email}) => '${email} (pending confirmation)';

	/// en: '${email} (pending confirmation - #${id})'
	String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (pending confirmation - #${id})';
}

// Path: deepLink
class Translations$deepLink$en {
	Translations$deepLink$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Start an operation first, then send that contact again'
	String get needsAnOperation => 'Start an operation first, then send that contact again';

	/// en: 'That contact is waiting in the operation behind this screen'
	String get waitingInOperation => 'That contact is waiting in the operation behind this screen';

	/// en: 'This device has no activity for $refs, so those references were left off'
	String unknownActivities({required Object refs}) => 'This device has no activity for ${refs}, so those references were left off';

	/// en: 'Could not reach your activities, so $refs was left off — try that link again'
	String activitiesUnavailable({required Object refs}) => 'Could not reach your activities, so ${refs} was left off — try that link again';
}

// Path: confirmDevice
class Translations$confirmDevice$en {
	Translations$confirmDevice$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Confirm a Device'
	String get title => 'Confirm a Device';

	/// en: 'Enter the code shown on the device that wants to join this account.'
	String get codePrompt => 'Enter the code shown on the device that wants to join this account.';

	/// en: 'Code'
	String get code => 'Code';

	/// en: 'Look Up'
	String get lookUp => 'Look Up';

	/// en: 'No request matches that code. Codes expire after 10 minutes — ask the other device for a fresh one.'
	String get codeNotFound => 'No request matches that code. Codes expire after 10 minutes — ask the other device for a fresh one.';

	/// en: 'That link has expired. Ask the other device to show a new QR code.'
	String get linkExpired => 'That link has expired. Ask the other device to show a new QR code.';

	/// en: 'Link ${device} to this account?'
	String areYouSure({required Object device}) => 'Link ${device} to this account?';

	/// en: 'an unnamed device'
	String get unnamedDevice => 'an unnamed device';

	/// en: 'It will be able to read and change every operation and QSO in this account.'
	String get grantWarning => 'It will be able to read and change every operation and QSO in this account.';

	/// en: 'This device does not sync yet'
	String get needsSyncTitle => 'This device does not sync yet';

	/// en: 'Turn on Ham2K Log Filer sync and link this device to an account before it can admit another one.'
	String get needsSyncText => 'Turn on Ham2K Log Filer sync and link this device to an account before it can admit another one.';

	/// en: 'The sync server sent a request this app could not read. Ask the other device to try again.'
	String get malformedRequest => 'The sync server sent a request this app could not read. Ask the other device to try again.';

	/// en: 'Link Device'
	String get linkIt => 'Link Device';
}

// Path: switchAccounts
class Translations$switchAccounts$en {
	Translations$switchAccounts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No account details yet'
	String get noAccountDetails => 'No account details yet';

	/// en: 'Current account'
	String get currentAccount => 'Current account';

	/// en: 'Other accounts'
	String get otherAccounts => 'Other accounts';

	/// en: 'Link to another account'
	String get linkToAnother => 'Link to another account';

	/// en: 'Link with other Ham2K App'
	String get linkWithSibling => 'Link with other Ham2K App';

	/// en: 'Link with account in older version'
	String get linkWithPolo => 'Link with account in older version';

	/// en: 'You have another Ham2K app installed. Link with the account in use there.'
	String get linkWithSiblingDescription => 'You have another Ham2K app installed. Link with the account in use there.';

	/// en: 'Approve the request in ${app}, then come back here.'
	String siblingPrompt({required Object app}) => 'Approve the request in ${app}, then come back here.';

	/// en: 'Open ${app} again'
	String openSiblingAgain({required Object app}) => 'Open ${app} again';

	/// en: 'Didn't work? Open it again, or go back and link another way.'
	String get siblingNoGrant => 'Didn\'t work? Open it again, or go back and link another way.';

	/// en: 'Could not open ${app}.'
	String siblingOpenFailed({required Object app}) => 'Could not open ${app}.';

	/// en: 'The link expired and a new one is ready — open ${app} again.'
	String siblingLinkRenewed({required Object app}) => 'The link expired and a new one is ready — open ${app} again.';

	/// en: 'Try again'
	String get tryAgain => 'Try again';

	/// en: 'Link with a QR code'
	String get linkWithQr => 'Link with a QR code';

	/// en: 'Scan it from a device already using the account'
	String get linkWithQrDescription => 'Scan it from a device already using the account';

	/// en: 'Link with an email address'
	String get linkWithEmail => 'Link with an email address';

	/// en: 'Confirm with a code or an email link'
	String get linkWithEmailDescription => 'Confirm with a code or an email link';

	/// en: 'Enter the email address of the account you want this device to use.'
	String get enterEmailPrompt => 'Enter the email address of the account you want this device to use.';

	/// en: 'Email address'
	String get emailAddress => 'Email address';

	/// en: 'Link account'
	String get linkAccount => 'Link account';

	/// en: 'Copied code to clipboard'
	String get copiedCode => 'Copied code to clipboard';

	/// en: 'Copy code'
	String get copyCode => 'Copy code';

	/// en: 'Open the Ham2K app on a device already linked with ${email} and enter this code to approve the request:'
	String codePrompt({required Object email}) => 'Open the Ham2K app on a device already linked with ${email} and enter this code to approve the request:';

	/// en: 'Waiting for confirmation…'
	String get waitingForConfirmation => 'Waiting for confirmation…';

	/// en: 'Send a confirmation email instead'
	String get sendEmailInstead => 'Send a confirmation email instead';

	/// en: 'An email was sent to ${email}. Open it and confirm the request to link this device.'
	String emailSent({required Object email}) => 'An email was sent to ${email}. Open it and confirm the request to link this device.';

	/// en: 'Resend email'
	String get resendEmail => 'Resend email';

	/// en: 'Scan this QR code from a device already linked to the account you want — for example with Ham2K Portable Logger on your phone.'
	String get qrPrompt => 'Scan this QR code from a device already linked to the account you want — for example with Ham2K Portable Logger on your phone.';

	/// en: 'Could not reach the sync server. Try again later.'
	String get serverUnreachable => 'Could not reach the sync server. Try again later.';

	/// en: 'Enter an email address to link.'
	String get emailRequired => 'Enter an email address to link.';

	/// en: 'No account found for ${email}.'
	String noAccountForEmail({required Object email}) => 'No account found for ${email}.';

	/// en: 'The sync server rejected the request: ${error}'
	String serverRejected({required Object error}) => 'The sync server rejected the request: ${error}';

	/// en: 'The sync server did not return a link code. Try again later.'
	String get noLinkCode => 'The sync server did not return a link code. Try again later.';

	/// en: 'The sync server did not send a confirmation code. Try again later.'
	String get noConfirmationCode => 'The sync server did not send a confirmation code. Try again later.';

	/// en: 'That account did not accept the switch. Try linking it with an email address instead.'
	String get switchNotAccepted => 'That account did not accept the switch. Try linking it with an email address instead.';

	/// en: 'Something went wrong talking to the sync server. Try again later.'
	String get requestFailed => 'Something went wrong talking to the sync server. Try again later.';

	/// en: '(one) {${count} QSO} (other) {${count} QSOs}'
	String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);

	/// en: '(one) {${count} operation} (other) {${count} operations}'
	String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} operation',
		other: '${count} operations',
	);
}

// Path: qsonImport
class Translations$qsonImport$en {
	Translations$qsonImport$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Import QSON Operation'
	String get title => 'Import QSON Operation';

	/// en: 'Create a new operation from a QSON file, as Developer Mode exports one here or in PoLo.'
	String get description => 'Create a new operation from a QSON file, as Developer Mode exports one here or in PoLo.';

	/// en: 'Drop a QSON file to import it as a new operation'
	String get dropHint => 'Drop a QSON file to import it as a new operation';

	/// en: 'Importing ${filename}…'
	String importing({required Object filename}) => 'Importing ${filename}…';

	/// en: 'Could not import ${filename}: ${error}'
	String failed({required Object filename, required Object error}) => 'Could not import ${filename}: ${error}';

	/// en: 'Could not open a file to import: ${error}'
	String pickerFailed({required Object error}) => 'Could not open a file to import: ${error}';

	/// en: '${filename} is not UTF-8 text, so it is not a QSON file'
	String notUtf8({required Object filename}) => '${filename} is not UTF-8 text, so it is not a QSON file';

	/// en: '${filename} is not a JSON file, so it is not a QSON file'
	String notJson({required Object filename}) => '${filename} is not a JSON file, so it is not a QSON file';

	/// en: '${filename} does not hold a QSON operation'
	String notOperation({required Object filename}) => '${filename} does not hold a QSON operation';

	/// en: 'An import is already running. Wait for it to finish before starting another.'
	String get busy => 'An import is already running. Wait for it to finish before starting another.';

	/// en: 'Drop one QSON file at a time — each one opens as its own operation.'
	String get oneFileOnly => 'Drop one QSON file at a time — each one opens as its own operation.';
}

// Path: adifImport
class Translations$adifImport$en {
	Translations$adifImport$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Import QSOs from ADIF'
	String get title => 'Import QSOs from ADIF';

	/// en: 'Reading ${filename}…'
	String reading({required Object filename}) => 'Reading ${filename}…';

	/// en: 'Drop an ADIF file to import'
	String get dropHint => 'Drop an ADIF file to import';

	/// en: '(one) {${count} QSO in this file} (other) {${formatted} QSOs in this file}'
	String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} QSO in this file',
		other: '${formatted} QSOs in this file',
	);

	/// en: '(one) {${count} already in your log} (other) {${formatted} already in your log}'
	String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} already in your log',
		other: '${formatted} already in your log',
	);

	/// en: '(one) {${count} will be imported} (other) {${formatted} will be imported}'
	String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} will be imported',
		other: '${formatted} will be imported',
	);

	/// en: '(one) {${count} new contact} (other) {${formatted} new contacts}'
	String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} new contact',
		other: '${formatted} new contacts',
	);

	/// en: '(one) {${count} will merge with an existing contact} (other) {${formatted} will merge with existing contacts}'
	String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} will merge with an existing contact',
		other: '${formatted} will merge with existing contacts',
	);

	/// en: '(one) {${count} cannot be imported (no callsign)} (other) {${formatted} cannot be imported (no callsign)}'
	String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} cannot be imported (no callsign)',
		other: '${formatted} cannot be imported (no callsign)',
	);

	/// en: '(one) {${count} needs a closer look} (other) {${formatted} need a closer look}'
	String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} needs a closer look',
		other: '${formatted} need a closer look',
	);

	/// en: '(one) {References could not be recovered for ${count} contact} (other) {References could not be recovered for ${formatted} contacts}'
	String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'References could not be recovered for ${count} contact',
		other: 'References could not be recovered for ${formatted} contacts',
	);

	/// en: '(one) {${programs} references may be incomplete for ${count} contact} (other) {${programs} references may be incomplete for ${formatted} contacts}'
	String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${programs} references may be incomplete for ${count} contact',
		other: '${programs} references may be incomplete for ${formatted} contacts',
	);

	/// en: 'Combined contacts may lose a reference — the activities could not say which types stack. Cancel and retry to avoid this.'
	String get stackingTypesUnknown => 'Combined contacts may lose a reference — the activities could not say which types stack. Cancel and retry to avoid this.';

	/// en: 'Nothing in this file can be imported'
	String get nothingToImport => 'Nothing in this file can be imported';

	/// en: 'Import'
	String get confirm => 'Import';

	/// en: 'Importing ${filename}…'
	String importing({required Object filename}) => 'Importing ${filename}…';

	/// en: '(one) {Imported ${count} contact from ${filename}} (other) {Imported ${formatted} contacts from ${filename}}'
	String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Imported ${count} contact from ${filename}',
		other: 'Imported ${formatted} contacts from ${filename}',
	);

	/// en: 'Could not import ${filename}: ${error}'
	String failed({required Object filename, required Object error}) => 'Could not import ${filename}: ${error}';

	/// en: '${filename} does not look like an ADIF file'
	String notAdif({required Object filename}) => '${filename} does not look like an ADIF file';

	/// en: 'Warning: this ADIF has QSOs from ${calls}, but they will be imported as ${station} if you continue.'
	String stationWarning({required Object calls, required Object station}) => 'Warning: this ADIF has QSOs from ${calls}, but they will be imported as ${station} if you continue.';

	/// en: ' and '
	String get stationCallJoin => ' and ';

	/// en: '(one) {${count} has no date and cannot be imported} (other) {${formatted} have no date and cannot be imported}'
	String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} has no date and cannot be imported',
		other: '${formatted} have no date and cannot be imported',
	);

	/// en: 'This file records an activation of ${refs}.'
	String activationFound({required Object refs}) => 'This file records an activation of ${refs}.';

	/// en: 'Add it to this operation'
	String get addActivation => 'Add it to this operation';

	/// en: 'Only ${written} of ${planned} could be applied — the log changed while you were deciding.'
	String shortfall({required Object written, required Object planned}) => 'Only ${written} of ${planned} could be applied — the log changed while you were deciding.';

	/// en: 'An import is already running. Wait for it to finish before starting another.'
	String get busy => 'An import is already running. Wait for it to finish before starting another.';

	/// en: 'Drop one ADIF file at a time — the order files are imported in decides which data wins.'
	String get oneFileOnly => 'Drop one ADIF file at a time — the order files are imported in decides which data wins.';

	/// en: '${filename} has more than ${limit} QSOs, the most an operation can import at a time.'
	String tooMany({required Object filename, required Object limit}) => '${filename} has more than ${limit} QSOs, the most an operation can import at a time.';
}

// Path: offline
class Translations$offline$en {
	Translations$offline$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Internet: OFFLINE'
	String get statusOffline => 'Internet: OFFLINE';

	/// en: 'Internet: connected'
	String get statusOnline => 'Internet: connected';

	/// en: 'No network connection at all.'
	String get noRoute => 'No network connection at all.';

	/// en: 'The network is up, but no server is responding — often a sign-in page waiting in a browser.'
	String get unreachable => 'The network is up, but no server is responding — often a sign-in page waiting in a browser.';

	/// en: 'All services responding as expected.'
	String get reachable => 'All services responding as expected.';

	/// en: 'Lookups, spots and data files are paused. Logging and nearby sync are not.'
	String get whatStops => 'Lookups, spots and data files are paused. Logging and nearby sync are not.';

	/// en: 'Services'
	String get servicesTitle => 'Services';

	/// en: 'No service has reported in yet.'
	String get noServices => 'No service has reported in yet.';

	/// en: 'Last responded ${when} ago'
	String lastSuccess({required Object when}) => 'Last responded ${when} ago';

	/// en: 'Has not responded yet'
	String get neverSucceeded => 'Has not responded yet';

	/// en: 'Next attempt in ${when}'
	String nextAttempt({required Object when}) => 'Next attempt in ${when}';

	/// en: 'Next attempt due'
	String get nextAttemptNow => 'Next attempt due';

	/// en: 'Retry now'
	String get retry => 'Retry now';

	/// en: 'Trying…'
	String get retrying => 'Trying…';

	/// en: 'Back online.'
	String get retryReached => 'Back online.';

	/// en: 'Still no response.'
	String get retryUnreachable => 'Still no response.';

	/// en: 'Nothing to send right now.'
	String get retryNotAttempted => 'Nothing to send right now.';

	/// en: 'Just tried — give it a moment.'
	String get retryThrottled => 'Just tried — give it a moment.';

	/// en: 'Sync is switched off, so there is nothing to probe with.'
	String get retryDisabled => 'Sync is switched off, so there is nothing to probe with.';

	/// en: 'Ham2K LoFi sync'
	String get syncService => 'Ham2K LoFi sync';

	/// en: 'Already trying — hang on.'
	String get retryInFlight => 'Already trying — hang on.';
}

// Path: exportSettings
class Translations$exportSettings$en {
	Translations$exportSettings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Base settings for all exports, with separate filename and title templates for reference activities and other activities. Each export type can provide its own defaults or custom settings.'
	String get defaultsDescription => 'Base settings for all exports, with separate filename and title templates for reference activities and other activities. Each export type can provide its own defaults or custom settings.';

	/// en: 'Reference Activities'
	String get referenceActivities => 'Reference Activities';

	/// en: 'Other Activities'
	String get otherActivities => 'Other Activities';

	/// en: 'ADIF Fields'
	String get adifFields => 'ADIF Fields';

	/// en: 'Export settings could not be loaded.'
	String get loadFailed => 'Export settings could not be loaded.';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Compact filenames, such as N0CALL@US-1234-20260715.adi.'
	String get compactFileNamesDescriptionOn => 'Compact filenames, such as N0CALL@US-1234-20260715.adi.';

	/// en: 'Descriptive filenames, such as 2026-07-15 N0CALL at US-1234.adi.'
	String get compactFileNamesDescriptionOff => 'Descriptive filenames, such as 2026-07-15 N0CALL at US-1234.adi.';

	/// en: 'Including names, addresses, emails, notes and precise locations in ADIF files.'
	String get includePrivateDataDescriptionOn => 'Including names, addresses, emails, notes and precise locations in ADIF files.';

	/// en: 'Omitting names, addresses, emails and notes; limiting locations to six-character grids.'
	String get includePrivateDataDescriptionOff => 'Omitting names, addresses, emails and notes; limiting locations to six-character grids.';

	/// en: 'Including information from callsign lookup services.'
	String get includeLookupDataDescriptionOn => 'Including information from callsign lookup services.';

	/// en: 'Omitting information from callsign lookup services; keeping manually entered values.'
	String get includeLookupDataDescriptionOff => 'Omitting information from callsign lookup services; keeping manually entered values.';

	/// en: 'Your custom templates are active and can be edited below.'
	String get customTemplatesDescriptionOn => 'Your custom templates are active and can be edited below.';

	/// en: 'Default templates are active. Your custom templates are kept for later.'
	String get customTemplatesDescriptionOff => 'Default templates are active. Your custom templates are kept for later.';

	/// en: 'Export type'
	String get type => 'Export type';

	/// en: 'Defaults'
	String get defaults => 'Defaults';

	/// en: 'Include lookup data'
	String get includeLookupData => 'Include lookup data';

	/// en: 'Custom templates'
	String get customTemplates => 'Custom templates';

	/// en: 'File name template'
	String get filenameTemplate => 'File name template';

	/// en: 'Compact file name template'
	String get compactFilenameTemplate => 'Compact file name template';

	/// en: 'Title template'
	String get titleTemplate => 'Title template';

	/// en: 'ADIF QSO Notes'
	String get adifNotesTemplate => 'ADIF QSO Notes';

	/// en: 'ADIF QSO Comments'
	String get adifCommentTemplate => 'ADIF QSO Comments';

	/// en: 'ADIF QSL Message'
	String get adifQslMessageTemplate => 'ADIF QSL Message';

	/// en: 'Settings apply to every extension using this export type.'
	String get shared => 'Settings apply to every extension using this export type.';

	/// en: 'Turn on Custom templates to edit this type’s templates.'
	String get defaultTemplates => 'Turn on Custom templates to edit this type’s templates.';
}

// Path: templateEditor
class Translations$templateEditor$en {
	Translations$templateEditor$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Preview:'
	String get previewLabel => 'Preview:';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Templating Docs'
	String get docs => 'Templating Docs';

	/// en: 'Sample preview'
	String get preview => 'Sample preview';

	/// en: 'Template reference'
	String get reference => 'Template reference';

	/// en: 'Available Attributes'
	String get attributes => 'Available Attributes';

	/// en: 'Filters'
	String get filters => 'Filters';

	/// en: 'Flow Control'
	String get flowControl => 'Flow Control';

	/// en: 'Preview is unavailable until extensions are ready.'
	String get unavailable => 'Preview is unavailable until extensions are ready.';

	/// en: '(empty output)'
	String get empty => '(empty output)';
}

// Path: home.nav
class Translations$home$nav$en {
	Translations$home$nav$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operations'
	String get operations => 'Operations';

	/// en: 'Chasing'
	String get chase => 'Chasing';

	/// en: 'Logs'
	String get logs => 'Logs';

	/// en: 'Maps'
	String get maps => 'Maps';

	/// en: 'Settings'
	String get settings => 'Settings';
}

// Path: home.panels
class Translations$home$panels$en {
	Translations$home$panels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation List'
	String get operations => 'Operation List';

	/// en: 'Your operations, most recent first.'
	String get operationsDescription => 'Your operations, most recent first.';

	/// en: 'Current Version'
	String get version => 'Current Version';

	/// en: 'The Ham2K mark, this app’s name and which build you are running.'
	String get versionDescription => 'The Ham2K mark, this app’s name and which build you are running.';
}

// Path: home.logs
class Translations$home$logs$en {
	Translations$home$logs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Logs'
	String get title => 'Logs';

	/// en: 'Logs for'
	String get titleFor => 'Logs for';

	/// en: 'No QSOs logged yet'
	String get emptyCallsigns => 'No QSOs logged yet';

	/// en: 'No QSOs for ${call}'
	String emptyQsos({required Object call}) => 'No QSOs for ${call}';

	/// en: 'Select a QSO to see it on the map'
	String get mapNoSelection => 'Select a QSO to see it on the map';

	/// en: 'Search callsign or name'
	String get searchHint => 'Search callsign or name';

	/// en: 'No QSOs match your search'
	String get noSearchMatches => 'No QSOs match your search';

	/// en: 'All Logs'
	String get titleAll => 'All Logs';

	/// en: 'All callsigns'
	String get allCallsigns => 'All callsigns';

	/// en: 'Not part of an operation'
	String get noOperation => 'Not part of an operation';

	/// en: 'Unsaved changes'
	String get unsavedTitle => 'Unsaved changes';

	/// en: 'This QSO has changes you haven’t saved.'
	String get unsavedBody => 'This QSO has changes you haven’t saved.';

	/// en: 'This QSO is marked for deletion.'
	String get pendingDeleteBody => 'This QSO is marked for deletion.';

	/// en: 'Not saved: that QSO is no longer in this log.'
	String get editGone => 'Not saved: that QSO is no longer in this log.';

	/// en: 'Discard'
	String get discard => 'Discard';

	late final Translations$home$logs$sheet$en sheet = Translations$home$logs$sheet$en.internal(_root);
	late final Translations$home$logs$groupBy$en groupBy = Translations$home$logs$groupBy$en.internal(_root);
	late final Translations$home$logs$period$en period = Translations$home$logs$period$en.internal(_root);
	late final Translations$home$logs$periodTitle$en periodTitle = Translations$home$logs$periodTitle$en.internal(_root);
	late final Translations$home$logs$columns$en columns = Translations$home$logs$columns$en.internal(_root);
	late final Translations$home$logs$panels$en panels = Translations$home$logs$panels$en.internal(_root);
	late final Translations$home$logs$import$en import = Translations$home$logs$import$en.internal(_root);
}

// Path: chase.station
class Translations$chase$station$en {
	Translations$chase$station$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Chasing Station'
	String get title => 'Chasing Station';

	/// en: 'Station: '
	String get stationLabel => 'Station: ';

	/// en: 'Op: '
	String get operatorLabel => 'Op: ';

	/// en: 'No location'
	String get noLocation => 'No location';
}

// Path: chase.periodInline
class Translations$chase$periodInline$en {
	Translations$chase$periodInline$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'today'
	String get today => 'today';

	/// en: 'this week'
	String get thisWeek => 'this week';

	/// en: 'in the last 14 days'
	String get last14Days => 'in the last 14 days';

	/// en: 'this month'
	String get thisMonth => 'this month';
}

// Path: chase.periodStats
class Translations$chase$periodStats$en {
	Translations$chase$periodStats$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Stats for today'
	String get today => 'Stats for today';

	/// en: 'Stats for this week'
	String get thisWeek => 'Stats for this week';

	/// en: 'Stats for last 14 days'
	String get last14Days => 'Stats for last 14 days';

	/// en: 'Stats for this month'
	String get thisMonth => 'Stats for this month';
}

// Path: chase.period
class Translations$chase$period$en {
	Translations$chase$period$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'This Week'
	String get thisWeek => 'This Week';

	/// en: 'Last 14 Days'
	String get last14Days => 'Last 14 Days';

	/// en: 'This Month'
	String get thisMonth => 'This Month';
}

// Path: chase.goals
class Translations$chase$goals$en {
	Translations$chase$goals$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Chasing Goals'
	String get title => 'Chasing Goals';

	/// en: 'Stop chasing ${name}'
	String remove({required Object name}) => 'Stop chasing ${name}';

	/// en: 'More chasing programs'
	String get extensionsTitle => 'More chasing programs';
}

// Path: chase.panels
class Translations$chase$panels$en {
	Translations$chase$panels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'QSOs'
	String get logging => 'QSOs';

	/// en: 'Logging controls above the QSOs chased in the period.'
	String get loggingDescription => 'Logging controls above the QSOs chased in the period.';

	/// en: 'Info'
	String get info => 'Info';

	/// en: 'The callsign being logged, or the period's stats.'
	String get infoDescription => 'The callsign being logged, or the period\'s stats.';

	/// en: 'Spots'
	String get spots => 'Spots';

	/// en: 'Stations spotted on the air, ready to chase.'
	String get spotsDescription => 'Stations spotted on the air, ready to chase.';

	/// en: 'Map'
	String get map => 'Map';

	/// en: 'The period's QSOs and the station being logged.'
	String get mapDescription => 'The period\'s QSOs and the station being logged.';
}

// Path: chase.claims
class Translations$chase$claims$en {
	Translations$chase$claims$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Checking QSOs for chasing'
	String get checking => 'Checking QSOs for chasing';

	/// en: 'Checking the log for ${program}'
	String rebuilding({required Object program}) => 'Checking the log for ${program}';

	/// en: '${done} of ${total} QSOs'
	String progress({required Object done, required Object total}) => '${done} of ${total} QSOs';
}

// Path: chase.notice
class Translations$chase$notice$en {
	Translations$chase$notice$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New ${program}'
	String newRef({required Object program}) => 'New ${program}';

	/// en: 'Probably new ${program}'
	String newRefGuess({required Object program}) => 'Probably new ${program}';

	/// en: 'New ${program} band'
	String newBand({required Object program}) => 'New ${program} band';

	/// en: 'Probably new ${program} band'
	String newBandGuess({required Object program}) => 'Probably new ${program} band';

	/// en: 'New ${program} mode'
	String newMode({required Object program}) => 'New ${program} mode';

	/// en: 'Probably new ${program} mode'
	String newModeGuess({required Object program}) => 'Probably new ${program} mode';

	/// en: '${program} unconfirmed'
	String unconfirmed({required Object program}) => '${program} unconfirmed';
}

// Path: chase.alerts
class Translations$chase$alerts$en {
	Translations$chase$alerts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Alerts'
	String get title => 'Alerts';

	/// en: 'New reference'
	String get newRef => 'New reference';

	/// en: 'New band'
	String get newBand => 'New band';

	/// en: 'New mode'
	String get newMode => 'New mode';

	/// en: 'Unconfirmed'
	String get unconfirmed => 'Unconfirmed';
}

// Path: chase.imports
class Translations$chase$imports$en {
	Translations$chase$imports$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Import ${label}'
	String importFrom({required Object label}) => 'Import ${label}';

	/// en: 'Import ${file} as'
	String pickTitle({required Object file}) => 'Import ${file} as';

	/// en: 'Drop a file to import it into a chasing program'
	String get dropHint => 'Drop a file to import it into a chasing program';

	/// en: 'Imported ${count} ${program} entries from ${file}'
	String done({required Object count, required Object program, required Object file}) => 'Imported ${count} ${program} entries from ${file}';

	/// en: 'Imported ${count} ${program} entries from ${file}, skipped ${skipped} it could not read'
	String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'Imported ${count} ${program} entries from ${file}, skipped ${skipped} it could not read';

	/// en: '${file} has nothing ${program} can import'
	String nothing({required Object file, required Object program}) => '${file} has nothing ${program} can import';

	/// en: '${program} could not read ${file}'
	String failed({required Object program, required Object file}) => '${program} could not read ${file}';

	/// en: '${program} could not read any of the ${skipped} records in ${file}'
	String unreadable({required Object program, required Object skipped, required Object file}) => '${program} could not read any of the ${skipped} records in ${file}';

	/// en: 'No chasing program imports ${file}'
	String noProgram({required Object file}) => 'No chasing program imports ${file}';
}

// Path: dialogs.callChange
class Translations$dialogs$callChange$en {
	Translations$dialogs$callChange$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Invalid callsign: ${call}'
	String invalidCallsign({required Object call}) => 'Invalid callsign: ${call}';

	/// en: 'Invalid callsigns: ${calls}'
	String invalidCallsigns({required Object calls}) => 'Invalid callsigns: ${calls}';

	/// en: '${previous} has operated so far. ${typed} will be recorded for new contacts.'
	String operatorSoFar({required Object previous, required Object typed}) => '${previous} has operated so far. ${typed} will be recorded for new contacts.';

	/// en: 'No operator recorded so far. ${typed} will be recorded for new contacts.'
	String operatorNoneSoFar({required Object typed}) => 'No operator recorded so far. ${typed} will be recorded for new contacts.';

	/// en: 'This operation already has contacts by ${calls}. ${typed} will only be recorded for new ones.'
	String operatorSeveral({required Object calls, required Object typed}) => 'This operation already has contacts by ${calls}. ${typed} will only be recorded for new ones.';

	/// en: '(one) {Also record ${typed} as the operator of the contact already logged} (other) {Also record ${typed} as the operator of all ${count} contacts already logged}'
	String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Also record ${typed} as the operator of the contact already logged',
		other: 'Also record ${typed} as the operator of all ${count} contacts already logged',
	);

	/// en: 'When using multiple stations over the air, there's no support for separate operators'
	String get operatorSeveralStations => 'When using multiple stations over the air, there\'s no support for separate operators';

	/// en: 'This operation's contacts could not be read, so changing a callsign here won't offer to update them'
	String get contactsUnreadable => 'This operation\'s contacts could not be read, so changing a callsign here won\'t offer to update them';

	/// en: 'The contacts already logged could not be updated, so no changes were made: ${error}'
	String restampFailed({required Object error}) => 'The contacts already logged could not be updated, so no changes were made: ${error}';

	/// en: '${written} of ${planned} contacts were updated — the rest are no longer in this operation'
	String restampShortfall({required Object written, required Object planned}) => '${written} of ${planned} contacts were updated — the rest are no longer in this operation';
}

// Path: operation.tabs
class Translations$operation$tabs$en {
	Translations$operation$tabs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '${count} QSOs'
	String qsos({required Object count}) => '${count} QSOs';

	/// en: 'INFO'
	String get info => 'INFO';

	/// en: 'SPOTS'
	String get spots => 'SPOTS';

	/// en: 'MAP'
	String get map => 'MAP';

	/// en: 'QSOs'
	String get qsosPlain => 'QSOs';

	/// en: 'Clock'
	String get clock => 'Clock';

	/// en: 'Weather'
	String get weather => 'Weather';

	/// en: 'Web Site'
	String get website => 'Web Site';

	/// en: 'Remote Screen'
	String get remoteScreen => 'Remote Screen';

	/// en: 'Solar'
	String get solar => 'Solar';

	/// en: 'Radio'
	String get radio => 'Radio';

	/// en: 'Operation Summaries'
	String get summaries => 'Operation Summaries';
}

// Path: operation.positions
class Translations$operation$positions$en {
	Translations$operation$positions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No other operating positions are sharing this operation yet.'
	String get nobodyYet => 'No other operating positions are sharing this operation yet.';

	/// en: 'Pos: $number'
	String positionLabel({required Object number}) => 'Pos: ${number}';

	/// en: 'Op: $call'
	String operatorLabel({required Object call}) => 'Op: ${call}';

	/// en: 'Another position'
	String get unnamedPosition => 'Another position';

	/// en: 'Our operating position'
	String get thisDevice => 'Our operating position';

	/// en: ' in '
	String get nameIn => ' in ';

	/// en: 'Positions'
	String get panelTitle => 'Positions';

	/// en: 'What every operating position sharing this operation is logging right now.'
	String get panelDescription => 'What every operating position sharing this operation is logging right now.';
}

// Path: operation.menu
class Translations$operation$menu$en {
	Translations$operation$menu$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show RST fields'
	String get showRstFields => 'Show RST fields';

	/// en: 'Show State field'
	String get showStateField => 'Show State field';

	/// en: 'Show Grid field'
	String get showGridField => 'Show Grid field';

	/// en: 'Show deleted QSOs'
	String get showDeletedQsos => 'Show deleted QSOs';

	/// en: 'Show deleted operations'
	String get showDeletedOps => 'Show deleted operations';

	/// en: 'Show QSO Numbers'
	String get showQsoNumbers => 'Show QSO Numbers';

	/// en: 'Lookup all QSOs'
	String get lookupAllQsos => 'Lookup all QSOs';

	/// en: 'Logging Settings'
	String get loggingSettingsTitle => 'Logging Settings';

	/// en: 'Map Settings'
	String get mapSettingsTitle => 'Map Settings';

	/// en: 'Actions'
	String get actionsSection => 'Actions';
}

// Path: operation.layout
class Translations$operation$layout$en {
	Translations$operation$layout$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Add a Panel'
	String get title => 'Add a Panel';

	/// en: 'Available panels'
	String get availableSection => 'Available panels';

	/// en: '${panel} settings'
	String panelSettings({required Object panel}) => '${panel} settings';

	/// en: 'Panel Settings'
	String get panelSettingsAction => 'Panel Settings';

	/// en: 'Operation View'
	String get viewName => 'Operation View';

	/// en: 'View layout options'
	String get viewOptions => 'View layout options';

	/// en: 'This view is built into the app, and so is its name'
	String get viewTitleBuiltIn => 'This view is built into the app, and so is its name';

	/// en: 'Restore Defaults'
	String get resetOptions => 'Restore Defaults';

	/// en: 'Remove'
	String get removePane => 'Remove';

	/// en: 'Restore ${panel} to its defaults?'
	String resetPaneConfirm({required Object panel}) => 'Restore ${panel} to its defaults?';

	/// en: 'Its title, header and size go back to the defaults. The rest of the layout stays as it is.'
	String get resetPaneConfirmBody => 'Its title, header and size go back to the defaults. The rest of the layout stays as it is.';

	/// en: 'Restore this view to its default layout?'
	String get resetViewConfirm => 'Restore this view to its default layout?';

	/// en: 'The panels go back to their default arrangement, and the view's options and every panel's go back to the defaults.'
	String get resetViewConfirmBody => 'The panels go back to their default arrangement, and the view\'s options and every panel\'s go back to the defaults.';

	/// en: '${panel} Layout Settings'
	String paneOptionsTitle({required Object panel}) => '${panel} Layout Settings';

	/// en: 'Title'
	String get paneTitle => 'Title';

	/// en: 'Show header'
	String get paneShowHeader => 'Show header';

	/// en: 'Always shown while this pane shares a group — the header is how the others are reached'
	String get paneShowHeaderTabset => 'Always shown while this pane shares a group — the header is how the others are reached';

	/// en: 'Same as the app'
	String get paneInherit => 'Same as the app';

	/// en: 'Search panels'
	String get searchHint => 'Search panels';

	/// en: 'No panel matches your search.'
	String get noPanelsMatch => 'No panel matches your search.';

	/// en: 'This view already has all possible panels'
	String get nothingToAdd => 'This view already has all possible panels';

	/// en: 'Add ${panel}'
	String addPanel({required Object panel}) => 'Add ${panel}';

	/// en: 'Preview ${panel}'
	String showPreview({required Object panel}) => 'Preview ${panel}';

	/// en: 'Extension "${name}" is missing'
	String missingExtension({required Object name}) => 'Extension "${name}" is missing';

	/// en: 'Enable'
	String get missingExtensionEnable => 'Enable';

	/// en: 'Install…'
	String get missingExtensionInstall => 'Install…';

	/// en: 'This version won’t run. Update it in Settings › Extensions.'
	String get missingExtensionWontRun => 'This version won’t run. Update it in Settings › Extensions.';

	/// en: 'Not available in this app'
	String get missingExtensionUnavailable => 'Not available in this app';

	/// en: 'Not in the catalog'
	String get missingExtensionNotInCatalog => 'Not in the catalog';

	/// en: 'Couldn’t reach the catalog. Try again'
	String get missingExtensionCatalogUnreachable => 'Couldn’t reach the catalog. Try again';

	/// en: 'That didn’t work. Try again'
	String get missingExtensionFailed => 'That didn’t work. Try again';

	/// en: 'This panel's preview image could not be shown.'
	String get previewUnavailable => 'This panel\'s preview image could not be shown.';

	/// en: 'More'
	String get nestedPaneTitle => 'More';

	late final Translations$operation$layout$layouts$en layouts = Translations$operation$layout$layouts$en.internal(_root);

	/// en: 'Edit Layout'
	String get editLayout => 'Edit Layout';

	/// en: 'Save Layout'
	String get saveLayout => 'Save Layout';

	/// en: 'Discard layout changes'
	String get revertLayout => 'Discard layout changes';

	/// en: 'Done'
	String get done => 'Done';

	/// en: 'Layout couldn't be read'
	String get layoutUnreadableTitle => 'Layout couldn\'t be read';

	/// en: 'Your saved layout could not be read, so the default arrangement is showing instead. It won't be saved over your original until you choose to keep it.'
	String get layoutUnreadableBody => 'Your saved layout could not be read, so the default arrangement is showing instead. It won\'t be saved over your original until you choose to keep it.';

	/// en: 'Use this layout'
	String get layoutUnreadableAction => 'Use this layout';

	/// en: '${panel} could not be displayed'
	String panelRenderFailed({required Object panel}) => '${panel} could not be displayed';

	/// en: 'Try again'
	String get panelRenderRetry => 'Try again';

	/// en: 'That panel action failed. Try again.'
	String get panelActionFailed => 'That panel action failed. Try again.';

	late final Translations$operation$layout$panels$en panels = Translations$operation$layout$panels$en.internal(_root);

	/// en: 'This panel needs a web view, which this platform does not provide'
	String get htmlPanelUnsupported => 'This panel needs a web view, which this platform does not provide';

	/// en: 'This panel needs a sandbox the web version cannot provide'
	String get htmlPanelUnsupportedOnWeb => 'This panel needs a sandbox the web version cannot provide';
}

// Path: operation.export
class Translations$operation$export$en {
	Translations$operation$export$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation Exports'
	String get title => 'Operation Exports';

	/// en: 'Operation is synced'
	String get syncedOperation => 'Operation is synced';

	/// en: 'Operation has unsynced changes'
	String get unsyncedOperation => 'Operation has unsynced changes';

	/// en: '(one) {${count} QSO in this operation} (other) {${count} QSOs in this operation}'
	String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} QSO in this operation',
		other: '${count} QSOs in this operation',
	);

	/// en: 'All ${total} QSOs are synced'
	String qsosSynced({required Object total}) => 'All ${total} QSOs are synced';

	/// en: '${pending} of ${total} QSOs pending sync'
	String qsosPending({required Object pending, required Object total}) => '${pending} of ${total} QSOs pending sync';

	/// en: '${total} event markers synced'
	String eventsSynced({required Object total}) => '${total} event markers synced';

	/// en: '${pending} of ${total} event markers pending'
	String eventsPending({required Object pending, required Object total}) => '${pending} of ${total} event markers pending';

	/// en: 'Loading export options…'
	String get loading => 'Loading export options…';

	/// en: 'No export formats available (extension runtime still starting?)'
	String get noOptions => 'No export formats available (extension runtime still starting?)';

	/// en: 'Nothing to export yet — this operation has no QSOs.'
	String get nothingLogged => 'Nothing to export yet — this operation has no QSOs.';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Nothing selected'
	String get nothingSelected => 'Nothing selected';

	/// en: '(one) {Save ${count} file} (other) {Save ${count} files}'
	String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Save ${count} file',
		other: 'Save ${count} files',
	);

	/// en: '(one) {Share ${count} file} (other) {Share ${count} files}'
	String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Share ${count} file',
		other: 'Share ${count} files',
	);

	/// en: '(one) {Export ${count} file} (other) {Export ${count} files}'
	String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Export ${count} file',
		other: 'Export ${count} files',
	);

	/// en: '(one) {Download ${count} file} (other) {Download ${count} files}'
	String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Download ${count} file',
		other: 'Download ${count} files',
	);

	/// en: '(one) {Save combined ${count} file} (other) {Save combined ${count} files}'
	String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Save combined ${count} file',
		other: 'Save combined ${count} files',
	);

	/// en: '(one) {Share combined ${count} file} (other) {Share combined ${count} files}'
	String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Share combined ${count} file',
		other: 'Share combined ${count} files',
	);

	/// en: '(one) {Export combined ${count} file} (other) {Export combined ${count} files}'
	String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Export combined ${count} file',
		other: 'Export combined ${count} files',
	);

	/// en: '(one) {Download combined ${count} file} (other) {Download combined ${count} files}'
	String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Download combined ${count} file',
		other: 'Download combined ${count} files',
	);

	/// en: 'Save ${name}'
	String saveOne({required Object name}) => 'Save ${name}';

	/// en: 'Share ${name}'
	String shareOne({required Object name}) => 'Share ${name}';

	/// en: 'Export ${name}'
	String exportOne({required Object name}) => 'Export ${name}';

	/// en: 'Download ${name}'
	String downloadOne({required Object name}) => 'Download ${name}';

	/// en: '(one) {Stash ${count} file} (other) {Stash ${count} files}'
	String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Stash ${count} file',
		other: 'Stash ${count} files',
	);

	/// en: '(one) {Stash combined ${count} file} (other) {Stash combined ${count} files}'
	String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Stash combined ${count} file',
		other: 'Stash combined ${count} files',
	);

	/// en: 'Export settings'
	String get settingsButton => 'Export settings';

	/// en: 'Export Settings'
	String get settingsTitle => 'Export Settings';

	late final Translations$operation$export$compactFileNames$en compactFileNames = Translations$operation$export$compactFileNames$en.internal(_root);
	late final Translations$operation$export$includePrivateData$en includePrivateData = Translations$operation$export$includePrivateData$en.internal(_root);

	/// en: 'Export complete'
	String get resultTitle => 'Export complete';

	/// en: 'Export failed'
	String get resultFailedTitle => 'Export failed';

	/// en: '(one) {Exported ${count} file to ${path}} (other) {Exported ${count} files to ${path}}'
	String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Exported ${count} file to ${path}',
		other: 'Exported ${count} files to ${path}',
	);

	/// en: '(one) {Exported ${count} file: ${path}} (other) {Exported ${count} files: ${path}}'
	String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Exported ${count} file: ${path}',
		other: 'Exported ${count} files: ${path}',
	);

	/// en: '(one) {Shared ${count} file} (other) {Shared ${count} files}'
	String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Shared ${count} file',
		other: 'Shared ${count} files',
	);

	/// en: '(one) {Downloaded ${count} file} (other) {Downloaded ${count} files}'
	String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Downloaded ${count} file',
		other: 'Downloaded ${count} files',
	);

	/// en: 'Export failed: ${error}'
	String exportFailed({required Object error}) => 'Export failed: ${error}';

	late final Translations$operation$export$stash$en stash = Translations$operation$export$stash$en.internal(_root);
}

// Path: operation.spots
class Translations$operation$spots$en {
	Translations$operation$spots$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No spots match your filters'
	String get empty => 'No spots match your filters';

	/// en: 'Failed to load spots: ${error}'
	String error({required Object error}) => 'Failed to load spots: ${error}';

	/// en: 'Other'
	String get unknownBand => 'Other';

	/// en: 'Automatic'
	String get auto => 'Automatic';

	/// en: 'Automatic (Currently ${value})'
	String autoValue({required Object value}) => 'Automatic (Currently ${value})';

	/// en: '${value} (Auto)'
	String valueAuto({required Object value}) => '${value} (Auto)';

	/// en: 'Any'
	String get any => 'Any';

	/// en: 'All Bands'
	String get allBands => 'All Bands';

	/// en: 'All Modes'
	String get allModes => 'All Modes';

	/// en: 'Phone & CW'
	String get phoneAndCw => 'Phone & CW';

	/// en: '(one) {${count} spot} (other) {${count} spots}'
	String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);

	/// en: 'Showing ${count} of ${total} spots'
	String spotsCountFiltered({required Object count, required Object total}) => 'Showing ${count} of ${total} spots';

	/// en: '${minutes} minutes'
	String ageMinutes({required Object minutes}) => '${minutes} minutes';

	/// en: 'Calls of Note'
	String get callsOfNote => 'Calls of Note';

	/// en: 'Your Spots'
	String get yourSpots => 'Your Spots';

	/// en: 'All Spots'
	String get allSpots => 'All Spots';

	late final Translations$operation$spots$continents$en continents = Translations$operation$spots$continents$en.internal(_root);
	late final Translations$operation$spots$filters$en filters = Translations$operation$spots$filters$en.internal(_root);

	/// en: 'Spots unavailable'
	String get unavailableTitle => 'Spots unavailable';

	/// en: '${sources} did not respond.'
	String unavailableText({required Object sources}) => '${sources} did not respond.';

	/// en: 'Spot source error'
	String get failedTitle => 'Spot source error';

	/// en: '${sources} returned an error.'
	String failedText({required Object sources}) => '${sources} returned an error.';

	/// en: 'Log it'
	String get slideLogIt => 'Log it';

	/// en: 'Ignore'
	String get slideIgnore => 'Ignore';

	/// en: 'Restore'
	String get slideRestore => 'Restore';

	late final Translations$operation$spots$logConflict$en logConflict = Translations$operation$spots$logConflict$en.internal(_root);
}

// Path: operation.import
class Translations$operation$import$en {
	Translations$operation$import$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Import Data into Operation'
	String get title => 'Import Data into Operation';

	/// en: 'Import QSOs from ADIF'
	String get importAdifAction => 'Import QSOs from ADIF';

	/// en: 'Listen settings'
	String get settingsButton => 'Listen settings';

	/// en: 'Listen for Other Apps'
	String get settingsTitle => 'Listen for Other Apps';

	/// en: 'Address'
	String get protocolAddressLabel => 'Address';

	/// en: 'Port'
	String get protocolPortLabel => 'Port';

	/// en: 'Enter a port between 1 and 65535'
	String get protocolPortInvalid => 'Enter a port between 1 and 65535';

	/// en: 'Enter a valid IP address (e.g. 127.0.0.1 or 239.239.0.2)'
	String get protocolAddressInvalid => 'Enter a valid IP address (e.g. 127.0.0.1 or 239.239.0.2)';

	/// en: 'Receiving data'
	String get protocolStatusReceiving => 'Receiving data';

	/// en: 'No data received recently'
	String get protocolStatusNoData => 'No data received recently';

	/// en: 'Couldn't start listening: ${error}'
	String protocolBindError({required Object error}) => 'Couldn\'t start listening: ${error}';

	/// en: 'Incoming QSOs could not be saved and are being retried: ${error}'
	String captureFailed({required Object error}) => 'Incoming QSOs could not be saved and are being retried: ${error}';

	/// en: 'N1MM+ Contact Broadcast'
	String get n1mmProtocolName => 'N1MM+ Contact Broadcast';

	/// en: 'Any (broadcast)'
	String get n1mmAddressValue => 'Any (broadcast)';

	/// en: 'WSJT-X UDP Server'
	String get wsjtxProtocolName => 'WSJT-X UDP Server';

	/// en: 'Config → Configure Ports, Mode Control… → Broadcast Data tab → check "Enable Broadcasts" for contact info. Set IP address to 127.0.0.1 if running on this same computer, or 255.255.255.255 to broadcast on the current local network.'
	String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Broadcast Data tab → check "Enable Broadcasts" for contact info. Set IP address to 127.0.0.1 if running on this same computer, or 255.255.255.255 to broadcast on the current local network.';

	/// en: 'File → Settings → Reporting tab → UDP Server section → check "Accept UDP requests". Set UDP Server to 127.0.0.1 if running on this same computer, or a multicast address such as 239.239.0.2, and use the same address in the configuration above in this app.'
	String get helpWsjtxSetup => 'File → Settings → Reporting tab → UDP Server section → check "Accept UDP requests". Set UDP Server to 127.0.0.1 if running on this same computer, or a multicast address such as 239.239.0.2, and use the same address in the configuration above in this app.';

	/// en: 'Listen for QSOs from other apps'
	String get listenTitle => 'Listen for QSOs from other apps';

	/// en: 'Listening for N1MM+'
	String get listenDescriptionOnN1mm => 'Listening for N1MM+';

	/// en: 'Listening for WSJT-X'
	String get listenDescriptionOnWsjtx => 'Listening for WSJT-X';

	/// en: 'Listening for N1MM+ and WSJT-X'
	String get listenDescriptionOnBoth => 'Listening for N1MM+ and WSJT-X';

	/// en: 'Off'
	String get listenDescriptionOff => 'Off';

	/// en: 'Add to this operation'
	String get addToOperationTitle => 'Add to this operation';

	/// en: 'Captured QSOs are added to this operation as they arrive'
	String get addToOperationDescriptionOn => 'Captured QSOs are added to this operation as they arrive';

	/// en: 'Captured QSOs are held until you turn this on'
	String get addToOperationDescriptionOff => 'Captured QSOs are held until you turn this on';

	/// en: 'Captured QSOs'
	String get pendingSectionTitle => 'Captured QSOs';

	/// en: 'Nothing captured yet'
	String get pendingEmpty => 'Nothing captured yet';

	/// en: 'Logged as ${call}, not this operation's station'
	String stationMismatch({required Object call}) => 'Logged as ${call}, not this operation\'s station';

	/// en: 'Discard'
	String get discardAction => 'Discard';

	/// en: 'Include earlier captures?'
	String get gapDialogTitle => 'Include earlier captures?';

	/// en: '${count} more QSOs were captured earlier, before a gap in the data. Include them too?'
	String gapDialogBody({required Object count}) => '${count} more QSOs were captured earlier, before a gap in the data. Include them too?';

	/// en: 'Just the recent ones'
	String get gapDialogRecentOnly => 'Just the recent ones';

	/// en: 'Include all ${count}'
	String gapDialogIncludeAll({required Object count}) => 'Include all ${count}';
}

// Path: map.outlineIssue
class Translations$map$outlineIssue$en {
	Translations$map$outlineIssue$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Issues?'
	String get link => 'Issues?';

	/// en: 'Report an outline issue'
	String get title => 'Report an outline issue';

	/// en: 'Which outline'
	String get reference => 'Which outline';

	/// en: 'How bad is it?'
	String get severity => 'How bad is it?';

	/// en: 'Minor nit'
	String get minor => 'Minor nit';

	/// en: 'Big deal'
	String get major => 'Big deal';

	/// en: 'What's wrong with it?'
	String get explanation => 'What\'s wrong with it?';

	/// en: 'What the outline gets wrong, and where'
	String get explanationHint => 'What the outline gets wrong, and where';

	/// en: 'Send'
	String get send => 'Send';

	/// en: 'Sending your report — thanks'
	String get sending => 'Sending your report — thanks';

	/// en: 'Copy report'
	String get copy => 'Copy report';

	/// en: 'Couldn't send the report'
	String get notSent => 'Couldn\'t send the report';

	/// en: 'Report copied'
	String get copied => 'Report copied';

	/// en: 'Couldn't copy the report'
	String get notCopied => 'Couldn\'t copy the report';
}

// Path: map.postcard
class Translations$map$postcard$en {
	Translations$map$postcard$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Operation Postcard'
	String get button => 'Operation Postcard';

	/// en: 'Postcard for ${title}'
	String title({required Object title}) => 'Postcard for ${title}';

	/// en: 'Portrait'
	String get portrait => 'Portrait';

	/// en: 'Landscape'
	String get landscape => 'Landscape';

	/// en: 'Square'
	String get square => 'Square';

	/// en: 'Save…'
	String get save => 'Save…';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Copied to the clipboard'
	String get copied => 'Copied to the clipboard';

	/// en: 'Saved to ${path}'
	String saved({required Object path}) => 'Saved to ${path}';

	/// en: 'Downloaded ${name}'
	String downloaded({required Object name}) => 'Downloaded ${name}';

	/// en: 'Saved ${count} images to ${path}'
	String savedMany({required Object count, required Object path}) => 'Saved ${count} images to ${path}';

	/// en: 'Saved ${names}'
	String savedFiles({required Object names}) => 'Saved ${names}';

	/// en: '${error} — ${names} had already been saved'
	String savePartial({required Object error, required Object names}) => '${error} — ${names} had already been saved';

	/// en: 'Downloading ${count} images — allow them if the browser asks'
	String downloadedMany({required Object count}) => 'Downloading ${count} images — allow them if the browser asks';

	/// en: 'The map didn't load, so it was left out'
	String get mapLeftOut => 'The map didn\'t load, so it was left out';

	/// en: '${outcome} — the map didn't load, so it was left out'
	String withMapLeftOut({required Object outcome}) => '${outcome} — the map didn\'t load, so it was left out';

	/// en: '${title} (continued)'
	String continued({required Object title}) => '${title} (continued)';

	/// en: 'Previous page'
	String get previousPage => 'Previous page';

	/// en: 'Next page'
	String get nextPage => 'Next page';

	/// en: 'Page ${page} of ${count}'
	String pageOf({required Object page, required Object count}) => 'Page ${page} of ${count}';

	/// en: '(one) {${count} Q} (other) {${count} Qs}'
	String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Q',
		other: '${count} Qs',
	);

	/// en: 'Postcard Options'
	String get options => 'Postcard Options';

	/// en: 'Show band legend'
	String get bandLegend => 'Show band legend';

	/// en: 'Show grayline'
	String get grayline => 'Show grayline';

	/// en: 'Summary Sections and Ordering'
	String get sectionsAndOrder => 'Summary Sections and Ordering';

	/// en: 'Each day'
	String get sectionDays => 'Each day';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Could not make the postcard: ${error}'
	String failed({required Object error}) => 'Could not make the postcard: ${error}';

	/// en: 'The map didn't finish loading. Check the connection and try again.'
	String get mapNotReady => 'The map didn\'t finish loading. Check the connection and try again.';

	/// en: 'Could not save the postcard: ${error}'
	String saveFailed({required Object error}) => 'Could not save the postcard: ${error}';

	/// en: 'The clipboard didn't take the image. Try again.'
	String get copyFailed => 'The clipboard didn\'t take the image. Try again.';

	/// en: 'Could not share the postcard. Try again.'
	String get shareFailed => 'Could not share the postcard. Try again.';

	/// en: 'postcard'
	String get fileName => 'postcard';
}

// Path: loggingControls.info
class Translations$loggingControls$info$en {
	Translations$loggingControls$info$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No QSOs yet... let's get on the air!'
	String get noQsos => 'No QSOs yet... let\'s get on the air!';

	/// en: '1 QSO'
	String get qsoCountOne => '1 QSO';

	/// en: '${count} QSOs'
	String qsoCountOther({required Object count}) => '${count} QSOs';

	/// en: '${count} in ${time}'
	String qsosInTime({required Object count, required Object time}) => '${count} in ${time}';

	/// en: '${time} since last'
	String sinceLast({required Object time}) => '${time} since last';

	/// en: '${rate} Q/h for last 10'
	String ratePer10({required Object rate}) => '${rate} Q/h for last 10';

	/// en: '${rate} Q/h for last 100'
	String ratePer100({required Object rate}) => '${rate} Q/h for last 100';

	/// en: '${distance} to'
	String distanceTo({required Object distance}) => '${distance} to';

	/// en: '${distance} (${bearing}°) to'
	String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to';

	/// en: '${distance} (${bearing}° / ${reverse}°) to'
	String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to';

	/// en: '${distance} away'
	String distanceAway({required Object distance}) => '${distance} away';

	/// en: '${distance} (${bearing}°) away'
	String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';

	/// en: '${distance} (${bearing}° / ${reverse}°) away'
	String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away';

	/// en: '${scorer}: ${notice}'
	String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';

	/// en: 'Dupe!'
	String get noticeDupe => 'Dupe!';

	/// en: 'New Band'
	String get noticeNewBand => 'New Band';

	/// en: 'New Mode'
	String get noticeNewMode => 'New Mode';

	/// en: 'New DXCC'
	String get noticeNewDXCC => 'New DXCC';

	/// en: 'New State'
	String get noticeNewState => 'New State';

	/// en: 'New Province'
	String get noticeNewProvince => 'New Province';

	/// en: 'New Day'
	String get noticeNewDay => 'New Day';

	/// en: 'New Ref'
	String get noticeNewRef => 'New Ref';

	/// en: 'New Mult'
	String get noticeNewMult => 'New Mult';

	/// en: 'New Zone'
	String get noticeNewZone => 'New Zone';

	/// en: 'Wrong Mode'
	String get noticeInvalidMode => 'Wrong Mode';

	/// en: 'Wrong Band'
	String get noticeInvalidBand => 'Wrong Band';

	/// en: 'Not Workable'
	String get noticeInvalidCategory => 'Not Workable';

	/// en: 'Time Over'
	String get noticeOverTime => 'Time Over';

	/// en: 'Worked Before'
	String get noticeWorkedBefore => 'Worked Before';

	/// en: 'New Park'
	String get noticeNewPark => 'New Park';

	/// en: 'New Section'
	String get noticeNewSection => 'New Section';

	/// en: 'Bonus Station!'
	String get noticeBonusStation => 'Bonus Station!';

	/// en: 'No Exchange'
	String get noticeMissingExchange => 'No Exchange';

	/// en: 'Bad Exchange'
	String get noticeInvalidExchange => 'Bad Exchange';

	/// en: 'Unknown Event'
	String get noticeUnknownEvent => 'Unknown Event';

	/// en: 'Incomplete Call — Not Scored'
	String get noticeIncompleteCall => 'Incomplete Call — Not Scored';

	/// en: 'Set Our Grid'
	String get noticeOurGrid => 'Set Our Grid';

	/// en: 'Rare County!'
	String get noticeRareCounty => 'Rare County!';

	/// en: 'Set Our County'
	String get noticeOurLocation => 'Set Our County';

	/// en: 'Grid Too Short'
	String get noticeShortGrid => 'Grid Too Short';
}

// Path: qsoList.find
class Translations$qsoList$find$en {
	Translations$qsoList$find$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Find in Log (${shortcut})'
	String menuItem({required Object shortcut}) => 'Find in Log (${shortcut})';

	/// en: 'Find in Log'
	String get menuItemNoShortcut => 'Find in Log';

	/// en: 'QSO number or callsign'
	String get hint => 'QSO number or callsign';

	/// en: 'No match'
	String get noMatches => 'No match';

	/// en: 'No QSOs in this operation'
	String get noOperationQsos => 'No QSOs in this operation';

	/// en: 'No QSOs in this period'
	String get noPeriodQsos => 'No QSOs in this period';

	/// en: '1 QSO outside of this operation'
	String get outsideQsosOne => '1 QSO outside of this operation';

	/// en: '${count} QSOs outside of this operation'
	String outsideQsosOther({required Object count}) => '${count} QSOs outside of this operation';

	/// en: '1 past QSO'
	String get pastQsosOne => '1 past QSO';

	/// en: '${count} past QSOs'
	String pastQsosOther({required Object count}) => '${count} past QSOs';
}

// Path: callInfo.history
class Translations$callInfo$history$en {
	Translations$callInfo$history$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '${n} in last 7 days'
	String last7days({required Object n}) => '${n} in last 7 days';

	/// en: '${n} today'
	String today({required Object n}) => '${n} today';

	/// en: '(one) {${n} QSO} (other) {${n} QSOs}'
	String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class Translations$settings$theme$en {
	Translations$settings$theme$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Theme Mode'
	String get title => 'Theme Mode';

	/// en: 'Follow system settings'
	String get system => 'Follow system settings';

	/// en: 'Light'
	String get light => 'Light';

	/// en: 'Dark'
	String get dark => 'Dark';
}

// Path: settings.themeDescription
class Translations$settings$themeDescription$en {
	Translations$settings$themeDescription$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Following system settings'
	String get system => 'Following system settings';

	/// en: 'Always in Light Mode'
	String get light => 'Always in Light Mode';

	/// en: 'Always in Dark Mode'
	String get dark => 'Always in Dark Mode';
}

// Path: settings.fontScaleOpts
class Translations$settings$fontScaleOpts$en {
	Translations$settings$fontScaleOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smallest--'
	String get smallestMinusMinus => 'Smallest--';

	/// en: 'Smallest-'
	String get smallestMinus => 'Smallest-';

	/// en: 'Smallest'
	String get smallest => 'Smallest';

	/// en: 'Smaller'
	String get smaller => 'Smaller';

	/// en: 'Normal'
	String get normal => 'Normal';

	/// en: 'Larger'
	String get larger => 'Larger';

	/// en: 'Largest'
	String get largest => 'Largest';

	/// en: 'Largest+'
	String get largestPlus => 'Largest+';

	/// en: 'Largest++'
	String get largestPlusPlus => 'Largest++';
}

// Path: settings.keepDeviceAwake
class Translations$settings$keepDeviceAwake$en {
	Translations$settings$keepDeviceAwake$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Keep Device Awake'
	String get title => 'Keep Device Awake';

	/// en: 'Staying awake while you are on the logging view or a sync is in progress'
	String get descriptionOn => 'Staying awake while you are on the logging view or a sync is in progress';

	/// en: 'Sleeping as usual'
	String get descriptionOff => 'Sleeping as usual';
}

// Path: settings.layoutDensityOpts
class Translations$settings$layoutDensityOpts$en {
	Translations$settings$layoutDensityOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Automatic'
	String get auto => 'Automatic';

	/// en: 'Densest'
	String get densest => 'Densest';

	/// en: 'Dense'
	String get dense => 'Dense';

	/// en: 'Normal'
	String get normal => 'Normal';

	/// en: 'Sparse'
	String get sparse => 'Sparse';

	/// en: 'Sparsest'
	String get sparsest => 'Sparsest';
}

// Path: settings.distanceUnitsOpts
class Translations$settings$distanceUnitsOpts$en {
	Translations$settings$distanceUnitsOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Kilometers'
	String get kilometers => 'Kilometers';

	/// en: 'Miles'
	String get miles => 'Miles';
}

// Path: settings.logging
class Translations$settings$logging$en {
	Translations$settings$logging$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Logging'
	String get title => 'Logging';

	late final Translations$settings$logging$leftieMode$en leftieMode = Translations$settings$logging$leftieMode$en.internal(_root);
	late final Translations$settings$logging$countryFlags$en countryFlags = Translations$settings$logging$countryFlags$en.internal(_root);
	late final Translations$settings$logging$countryFlagsDescription$en countryFlagsDescription = Translations$settings$logging$countryFlagsDescription$en.internal(_root);
	late final Translations$settings$logging$suggestDefaultOperator$en suggestDefaultOperator = Translations$settings$logging$suggestDefaultOperator$en.internal(_root);
	late final Translations$settings$logging$showBearing$en showBearing = Translations$settings$logging$showBearing$en.internal(_root);
	late final Translations$settings$logging$showReverseBearing$en showReverseBearing = Translations$settings$logging$showReverseBearing$en.internal(_root);
	late final Translations$settings$logging$switchSentRcvd$en switchSentRcvd = Translations$settings$logging$switchSentRcvd$en.internal(_root);
	late final Translations$settings$logging$jumpAfterRST$en jumpAfterRST = Translations$settings$logging$jumpAfterRST$en.internal(_root);
	late final Translations$settings$logging$defaultReport$en defaultReport = Translations$settings$logging$defaultReport$en.internal(_root);
	late final Translations$settings$logging$defaultReportCW$en defaultReportCW = Translations$settings$logging$defaultReportCW$en.internal(_root);
	late final Translations$settings$logging$defaultReportFT8$en defaultReportFT8 = Translations$settings$logging$defaultReportFT8$en.internal(_root);
	late final Translations$settings$logging$numbersRow$en numbersRow = Translations$settings$logging$numbersRow$en.internal(_root);
	late final Translations$settings$logging$numbersRowExtra$en numbersRowExtra = Translations$settings$logging$numbersRowExtra$en.internal(_root);
	late final Translations$settings$logging$numbersRowVibrate$en numbersRowVibrate = Translations$settings$logging$numbersRowVibrate$en.internal(_root);

	/// en: 'Preferred Bands'
	String get bands => 'Preferred Bands';

	/// en: 'Preferred Modes'
	String get modes => 'Preferred Modes';
}

// Path: settings.catServer
class Translations$settings$catServer$en {
	Translations$settings$catServer$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'CAT Server'
	String get title => 'CAT Server';

	/// en: 'Allow other apps (WSJT-X, loggers, etc) to control the radio through Ham2K Logger.'
	String get description => 'Allow other apps (WSJT-X, loggers, etc) to control the radio through Ham2K Logger.';

	/// en: 'Protocol'
	String get protocol => 'Protocol';

	late final Translations$settings$catServer$protocolOpts$en protocolOpts = Translations$settings$catServer$protocolOpts$en.internal(_root);

	/// en: 'Port'
	String get port => 'Port';

	/// en: 'Open access'
	String get openAccess => 'Open access';

	/// en: 'Any computer on the local network can connect.'
	String get openAccessOn => 'Any computer on the local network can connect.';

	/// en: 'Only apps on this computer can connect.'
	String get openAccessOff => 'Only apps on this computer can connect.';

	/// en: 'Off.'
	String get off => 'Off.';

	/// en: '$protocol, starting…'
	String starting({required Object protocol}) => '${protocol}, starting…';

	/// en: '$protocol on port $port. Clients connected: $clients.'
	String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} on port ${port}. Clients connected: ${clients}.';

	/// en: '$protocol on port $port, but no Main VFO radio is connected.'
	String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} on port ${port}, but no Main VFO radio is connected.';

	/// en: '$protocol cannot listen on port $port: $error'
	String failed({required Object protocol, required Object port, required Object error}) => '${protocol} cannot listen on port ${port}: ${error}';

	/// en: '$protocol cannot listen on port $port: another program is using it, often $protocol itself. Close that program or choose another port.'
	String portInUse({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: another program is using it, often ${protocol} itself. Close that program or choose another port.';

	/// en: '$protocol cannot listen on port $port: this computer does not allow it. Choose a port above 1024.'
	String portDenied({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: this computer does not allow it. Choose a port above 1024.';

	/// en: '$protocol stopped listening on port $port. Trying again…'
	String stopped({required Object protocol, required Object port}) => '${protocol} stopped listening on port ${port}. Trying again…';
}

// Path: settings.cluster
class Translations$settings$cluster$en {
	Translations$settings$cluster$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'DX Cluster'
	String get title => 'DX Cluster';

	/// en: 'The server extensions post spots to and read spots from, logged in as the operator.'
	String get description => 'The server extensions post spots to and read spots from, logged in as the operator.';

	/// en: 'Cluster Server'
	String get server => 'Cluster Server';

	/// en: 'Select Server'
	String get selectServer => 'Select Server';

	/// en: 'Other'
	String get serverOther => 'Other';

	/// en: 'No host entered yet, so spots go to $node'
	String serverOtherIncomplete({required Object node}) => 'No host entered yet, so spots go to ${node}';

	/// en: 'Server'
	String get customHost => 'Server';

	/// en: 'Port'
	String get customPort => 'Port';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Only if needed'
	String get passwordDescription => 'Only if needed';

	/// en: 'Password on file for $node'
	String passwordStored({required Object node}) => 'Password on file for ${node}';

	/// en: 'Lines kept'
	String get scrollback => 'Lines kept';

	/// en: '$count lines'
	String scrollbackOpt({required Object count}) => '${count} lines';

	/// en: 'Connection'
	String get connection => 'Connection';

	/// en: 'Not connected. Connects when an extension needs it. Tap to test.'
	String get statusIdle => 'Not connected. Connects when an extension needs it. Tap to test.';

	/// en: 'Connecting to $node…'
	String statusConnecting({required Object node}) => 'Connecting to ${node}…';

	/// en: 'Connected to $node as $call.'
	String statusConnected({required Object node, required Object call}) => 'Connected to ${node} as ${call}.';

	/// en: 'Could not connect to $node: $reason'
	String statusFailed({required Object node, required Object reason}) => 'Could not connect to ${node}: ${reason}';

	/// en: 'Not available in the web version.'
	String get statusUnsupported => 'Not available in the web version.';

	late final Translations$settings$cluster$errors$en errors = Translations$settings$cluster$errors$en.internal(_root);
}

// Path: settings.spotting
class Translations$settings$spotting$en {
	Translations$settings$spotting$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Spotting'
	String get title => 'Spotting';

	/// en: 'Auto re-spot every'
	String get respotInterval => 'Auto re-spot every';

	/// en: '${minutes} min'
	String minutes({required Object minutes}) => '${minutes} min';

	/// en: 'Auto re-spot by default'
	String get autoRespotByDefault => 'Auto re-spot by default';

	/// en: 'Enable auto re-spot after any spot is posted'
	String get autoRespotByDefaultOn => 'Enable auto re-spot after any spot is posted';

	/// en: 'Require user action to enable auto re-spotting'
	String get autoRespotByDefaultOff => 'Require user action to enable auto re-spotting';

	/// en: 'Pulse before each auto re-spot'
	String get pulseBeforeRespot => 'Pulse before each auto re-spot';

	/// en: 'The Spotting chip pulses blue for the ${seconds} seconds before each re-spot'
	String pulseBeforeRespotOn({required Object seconds}) => 'The Spotting chip pulses blue for the ${seconds} seconds before each re-spot';

	/// en: 'No pulsing before an auto re-spot'
	String get pulseBeforeRespotOff => 'No pulsing before an auto re-spot';
}

// Path: settings.radio
class Translations$settings$radio$en {
	Translations$settings$radio$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'CAT Control'
	String get title => 'CAT Control';

	/// en: 'Logging & CAT'
	String get loggingAndCat => 'Logging & CAT';

	/// en: 'Tuning'
	String get tuningSection => 'Tuning';

	/// en: 'Keyer'
	String get keyerSection => 'Keyer';

	/// en: 'Services'
	String get servicesSection => 'Services';

	/// en: 'Station Configuration'
	String get stationConfigurationSection => 'Station Configuration';

	/// en: 'More station configuration settings'
	String get moreSettings => 'More station configuration settings';

	late final Translations$settings$radio$units$en units = Translations$settings$radio$units$en.internal(_root);
	late final Translations$settings$radio$pttKey$en pttKey = Translations$settings$radio$pttKey$en.internal(_root);
	late final Translations$settings$radio$smartVfoSnap$en smartVfoSnap = Translations$settings$radio$smartVfoSnap$en.internal(_root);
	late final Translations$settings$radio$snapDebounce$en snapDebounce = Translations$settings$radio$snapDebounce$en.internal(_root);
	late final Translations$settings$radio$snapLongMove$en snapLongMove = Translations$settings$radio$snapLongMove$en.internal(_root);
	late final Translations$settings$radio$snapMinMove$en snapMinMove = Translations$settings$radio$snapMinMove$en.internal(_root);
	late final Translations$settings$radio$snapMinSpeed$en snapMinSpeed = Translations$settings$radio$snapMinSpeed$en.internal(_root);
	late final Translations$settings$radio$enterSends$en enterSends = Translations$settings$radio$enterSends$en.internal(_root);
	late final Translations$settings$radio$keyerSpeed$en keyerSpeed = Translations$settings$radio$keyerSpeed$en.internal(_root);
	late final Translations$settings$radio$cwMessages$en cwMessages = Translations$settings$radio$cwMessages$en.internal(_root);
	late final Translations$settings$radio$voiceMessages$en voiceMessages = Translations$settings$radio$voiceMessages$en.internal(_root);
	late final Translations$settings$radio$avoidZeroBeat$en avoidZeroBeat = Translations$settings$radio$avoidZeroBeat$en.internal(_root);
	late final Translations$settings$radio$zeroBeatRange$en zeroBeatRange = Translations$settings$radio$zeroBeatRange$en.internal(_root);
}

// Path: settings.help
class Translations$settings$help$en {
	Translations$settings$help$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Help & Resources'
	String get title => 'Help & Resources';

	/// en: 'Community and support'
	String get description => 'Community and support';

	/// en: 'Ham2K Forums'
	String get forums => 'Ham2K Forums';

	/// en: 'Find help, give feedback, discuss ideas…'
	String get forumsDescription => 'Find help, give feedback, discuss ideas…';

	/// en: 'Ham2K Chat'
	String get chat => 'Ham2K Chat';

	/// en: 'The Discord server for our online community'
	String get chatDescription => 'The Discord server for our online community';

	/// en: 'Ham2K YouTube'
	String get youtube => 'Ham2K YouTube';

	/// en: 'Videos and live streams'
	String get youtubeDescription => 'Videos and live streams';

	/// en: 'Ham2K Instagram'
	String get instagram => 'Ham2K Instagram';

	/// en: 'Because you cannot have too many photos…'
	String get instagramDescription => 'Because you cannot have too many photos…';

	/// en: 'Ham2K BlueSky'
	String get bluesky => 'Ham2K BlueSky';

	/// en: 'Follow us for news and updates'
	String get blueskyDescription => 'Follow us for news and updates';

	/// en: 'Contact Us'
	String get contact => 'Contact Us';

	/// en: 'help@ham2k.com — but try the Forums or Chat first!'
	String get contactDescription => 'help@ham2k.com — but try the Forums or Chat first!';
}

// Path: settings.exports
class Translations$settings$exports$en {
	Translations$settings$exports$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Exports'
	String get title => 'Exports';
}

// Path: settings.extensionSections
class Translations$settings$extensionSections$en {
	Translations$settings$extensionSections$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get activities => 'Activities';

	/// en: 'Hunting'
	String get hunting => 'Hunting';

	/// en: 'Contests'
	String get contests => 'Contests';

	/// en: 'Lookups'
	String get lookups => 'Lookups';

	/// en: 'Dashboard'
	String get dashboard => 'Dashboard';
}

// Path: settings.map
class Translations$settings$map$en {
	Translations$settings$map$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Maps'
	String get title => 'Maps';

	late final Translations$settings$map$style$en style = Translations$settings$map$style$en.internal(_root);
	late final Translations$settings$map$showCallsigns$en showCallsigns = Translations$settings$map$showCallsigns$en.internal(_root);
	late final Translations$settings$map$showGrayline$en showGrayline = Translations$settings$map$showGrayline$en.internal(_root);
	late final Translations$settings$map$styleOpts$en styleOpts = Translations$settings$map$styleOpts$en.internal(_root);
}

// Path: settings.privacy
class Translations$settings$privacy$en {
	Translations$settings$privacy$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Privacy'
	String get title => 'Privacy';

	late final Translations$settings$privacy$shareAppData$en shareAppData = Translations$settings$privacy$shareAppData$en.internal(_root);
	late final Translations$settings$privacy$shareOpData$en shareOpData = Translations$settings$privacy$shareOpData$en.internal(_root);

	/// en: 'Privacy Policy'
	String get privacyPolicy => 'Privacy Policy';

	/// en: 'Terms of Service'
	String get termsOfService => 'Terms of Service';
}

// Path: settings.sync
class Translations$settings$sync$en {
	Translations$settings$sync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cloud Sync'
	String get title => 'Cloud Sync';

	/// en: 'More sync settings'
	String get moreSettings => 'More sync settings';

	/// en: 'Enable Sync'
	String get enable => 'Enable Sync';

	/// en: 'Device Key'
	String get deviceKey => 'Device Key';
}

// Path: settings.peers
class Translations$settings$peers$en {
	Translations$settings$peers$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Peer Devices'
	String get title => 'Peer Devices';

	/// en: 'Connect to other devices'
	String get enable => 'Connect to other devices';

	/// en: 'Allow sharing operations, logging, CAT and GPS with other devices over the local network'
	String get enableDescription => 'Allow sharing operations, logging, CAT and GPS with other devices over the local network';

	/// en: 'Connect over Bluetooth'
	String get bleEnable => 'Connect over Bluetooth';

	/// en: 'Use Bluetooth LE to connect even if there is no local network'
	String get bleDescription => 'Use Bluetooth LE to connect even if there is no local network';

	/// en: 'This Device'
	String get thisDevice => 'This Device';

	/// en: 'Name'
	String get deviceName => 'Name';

	/// en: 'How this device is seen by other devices'
	String get deviceNameHint => 'How this device is seen by other devices';

	/// en: 'Linked Devices'
	String get pairedDevices => 'Linked Devices';

	/// en: 'No devices linked yet. Turn this on, on another device on this network, to link them.'
	String get noPairedDevices => 'No devices linked yet. Turn this on, on another device on this network, to link them.';

	/// en: 'Can't read your linked devices: ${error}'
	String deviceListProblem({required Object error}) => 'Can\'t read your linked devices: ${error}';

	/// en: 'Nearby'
	String get nearby => 'Nearby';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'via Bluetooth'
	String get viaBluetooth => 'via Bluetooth';

	/// en: 'Connecting…'
	String get connecting => 'Connecting…';

	/// en: 'Syncing…'
	String get syncing => 'Syncing…';

	/// en: 'Waiting for the other device'
	String get waitingForThem => 'Waiting for the other device';

	/// en: 'Not connected'
	String get notConnected => 'Not connected';

	/// en: 'wants to share this operation'
	String get wantsToPair => 'wants to share this operation';

	/// en: 'Allow'
	String get allow => 'Allow';

	/// en: 'Link'
	String get link => 'Link';

	/// en: 'Reject'
	String get reject => 'Reject';

	/// en: 'Forget'
	String get forget => 'Forget';

	/// en: 'Forget ${name}?'
	String forgetTitle({required Object name}) => 'Forget ${name}?';

	/// en: 'It will stop syncing with this device. You can allow it again later, and contacts already logged are kept.'
	String get forgetBody => 'It will stop syncing with this device. You can allow it again later, and contacts already logged are kept.';

	/// en: 'Link with ${name}'
	String pairTitle({required Object name}) => 'Link with ${name}';

	/// en: 'This device is on your local network and wants to connect.'
	String get pairBody => 'This device is on your local network and wants to connect.';

	/// en: 'This device is nearby and wants to connect over Bluetooth LE.'
	String get pairBodyBle => 'This device is nearby and wants to connect over Bluetooth LE.';

	/// en: 'Device ID'
	String get pairIdLabel => 'Device ID';

	/// en: 'Only link with devices you recognise. Any device on this network can send a request.'
	String get pairWarning => 'Only link with devices you recognise. Any device on this network can send a request.';

	/// en: 'Only link with devices you recognise. Any nearby device can send a request.'
	String get pairWarningBle => 'Only link with devices you recognise. Any nearby device can send a request.';

	/// en: 'Can't reach the local network: ${error}'
	String problem({required Object error}) => 'Can\'t reach the local network: ${error}';

	/// en: 'Bluetooth: ${error}'
	String bleProblem({required Object error}) => 'Bluetooth: ${error}';

	/// en: 'Connected to ${device}'
	String statusConnected({required Object device}) => 'Connected to ${device}';

	/// en: 'Lost connection to ${device}'
	String statusLost({required Object device}) => 'Lost connection to ${device}';

	/// en: 'Peer Devices: ${connected} of ${linked} connected'
	String statusPerma({required Object connected, required Object linked}) => 'Peer Devices: ${connected} of ${linked} connected';

	/// en: 'Share screens and windows'
	String get screenEnable => 'Share screens and windows';

	/// en: 'Allow other devices to show screens or windows from this computer'
	String get screenDescription => 'Allow other devices to show screens or windows from this computer';

	/// en: 'Screens and Windows'
	String get screenSources => 'Screens and Windows';

	/// en: 'Refresh the list'
	String get screenRefresh => 'Refresh the list';

	/// en: 'This device can't share its screen. macOS can; every device can show one shared by another.'
	String get screenUnsupportedPlatform => 'This device can\'t share its screen. macOS can; every device can show one shared by another.';

	/// en: 'Sharing a screen needs macOS 12.3 or later. This device can still show a screen shared by another.'
	String get screenUnsupportedVersion => 'Sharing a screen needs macOS 12.3 or later. This device can still show a screen shared by another.';

	/// en: 'macOS needs your permission to record the screen before this app can share one.'
	String get screenNeedsPermission => 'macOS needs your permission to record the screen before this app can share one.';

	/// en: 'Ask for permission'
	String get screenGrantPermission => 'Ask for permission';

	/// en: 'Allow it in System Settings under Privacy & Security → Screen Recording, then quit and reopen this app — macOS only tells an app about the change on its next launch.'
	String get screenRelaunchAfterGranting => 'Allow it in System Settings under Privacy & Security → Screen Recording, then quit and reopen this app — macOS only tells an app about the change on its next launch.';

	/// en: 'Screen sharing: ${error}'
	String screenProblem({required Object error}) => 'Screen sharing: ${error}';

	/// en: 'Choose What to Share'
	String get screenChooseTitle => 'Choose What to Share';

	/// en: 'Choose what to share…'
	String get screenChooseButton => 'Choose what to share…';

	/// en: 'Screens'
	String get screenTabScreens => 'Screens';

	/// en: 'Apps'
	String get screenTabApps => 'Apps';

	/// en: 'Windows'
	String get screenTabWindows => 'Windows';

	/// en: 'Nothing of this kind was found.'
	String get screenTabEmpty => 'Nothing of this kind was found.';

	/// en: 'Nothing chosen yet.'
	String get screenSharedSummaryNone => 'Nothing chosen yet.';

	/// en: 'This device'
	String get screenThisDevice => 'This device';

	/// en: 'Shown on ${devices}'
	String screenSharedTo({required Object devices}) => 'Shown on ${devices}';

	/// en: 'Not being shown'
	String get screenSharedToNobody => 'Not being shown';

	/// en: 'Stop sharing ${name}'
	String screenStopSharing({required Object name}) => 'Stop sharing ${name}';
}

// Path: settings.syncPanel
class Translations$settings$syncPanel$en {
	Translations$settings$syncPanel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sync Configuration'
	String get configuration => 'Sync Configuration';

	/// en: 'Sync with Ham2K Log Filer'
	String get enableTitle => 'Sync with Ham2K Log Filer';

	/// en: 'Backing up and syncing your log across devices'
	String get enabledDescription => 'Backing up and syncing your log across devices';

	/// en: 'Off — staying on this device only'
	String get disabledDescription => 'Off — staying on this device only';

	/// en: 'Syncing'
	String get syncing => 'Syncing';

	/// en: 'Account'
	String get account => 'Account';

	/// en: 'Refresh'
	String get refresh => 'Refresh';

	/// en: 'Switch Accounts'
	String get switchAccounts => 'Switch Accounts';

	/// en: 'Link this device to another account with a QR code or email'
	String get switchAccountsDescription => 'Link this device to another account with a QR code or email';

	/// en: 'Connection Requests'
	String get connectionRequests => 'Connection Requests';

	/// en: '(one) {A device is waiting to join this account} (other) {${n} devices are waiting to join this account}'
	String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'A device is waiting to join this account',
		other: '${n} devices are waiting to join this account',
	);

	/// en: 'Account email'
	String get accountEmailTitle => 'Account email';

	/// en: 'Confirmation sent to ${email}. Open the link there to finish the change.'
	String accountEmailSent({required Object email}) => 'Confirmation sent to ${email}. Open the link there to finish the change.';

	/// en: 'Resend Confirmation Email'
	String get resendConfirmation => 'Resend Confirmation Email';

	/// en: 'Waiting on ${email}'
	String resendConfirmationDescription({required Object email}) => 'Waiting on ${email}';

	/// en: 'Sent again to ${email}.'
	String accountEmailResent({required Object email}) => 'Sent again to ${email}.';

	/// en: 'That device is now linked to this account.'
	String get deviceLinked => 'That device is now linked to this account.';

	/// en: 'Checking…'
	String get checking => 'Checking…';

	/// en: 'Not linked yet'
	String get notLinked => 'Not linked yet';

	/// en: '${account} (#${id})'
	String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';

	/// en: 'Replace local data?'
	String get replaceDialogTitle => 'Replace local data?';

	/// en: '(one) {${n} operation} (other) {${n} operations}'
	String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} operation',
		other: '${n} operations',
	);

	/// en: '(one) {${n} QSO} (other) {${n} QSOs}'
	String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);

	/// en: 'Synced Data'
	String get counts => 'Synced Data';

	/// en: 'This device: ${qsos} · ${operations}'
	String countsLocal({required Object qsos, required Object operations}) => 'This device: ${qsos} · ${operations}';

	/// en: 'Waiting to upload: ${items}'
	String countsPending({required Object items}) => 'Waiting to upload: ${items}';

	/// en: 'Server: ${qsos} · ${operations}'
	String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';

	/// en: 'This device: checking…'
	String get countsLocalChecking => 'This device: checking…';

	/// en: 'Server: checking…'
	String get countsServerChecking => 'Server: checking…';

	/// en: 'Server: not available'
	String get countsServerUnavailable => 'Server: not available';

	/// en: 'This backs up and clears ${operations} and ${qsos} from this device, then downloads the account's data instead. The backup stays in this device's database.'
	String replaceDialogBody({required Object operations, required Object qsos}) => 'This backs up and clears ${operations} and ${qsos} from this device, then downloads the account\'s data instead. The backup stays in this device\'s database.';

	/// en: 'Replace'
	String get replace => 'Replace';

	/// en: 'New Ham2K Log Filer account detected'
	String get pendingBannerTitle => 'New Ham2K Log Filer account detected';

	/// en: 'Keep this device's existing operations and QSOs and merge them into the account, or replace them with the account's data (a backup stays on this device either way).'
	String get pendingBannerBody => 'Keep this device\'s existing operations and QSOs and merge them into the account, or replace them with the account\'s data (a backup stays on this device either way).';

	/// en: 'Combine'
	String get combine => 'Combine';

	/// en: 'Sync can't connect'
	String get authIssueTitle => 'Sync can\'t connect';

	/// en: 'Ham2K Log Filer keeps rejecting this device. Check your callsign in Sync settings.'
	String get authIssueText => 'Ham2K Log Filer keeps rejecting this device. Check your callsign in Sync settings.';

	/// en: 'Open Sync settings'
	String get openSettings => 'Open Sync settings';
}

// Path: settings.accounts
class Translations$settings$accounts$en {
	Translations$settings$accounts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Accounts, Services & Data Sources'
	String get title => 'Accounts, Services & Data Sources';

	/// en: 'No active extensions with accounts'
	String get none => 'No active extensions with accounts';

	/// en: 'Not configured'
	String get notConfigured => 'Not configured';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'Cancel sign-in'
	String get cancelLogin => 'Cancel sign-in';

	/// en: 'Open in Browser'
	String get openInBrowser => 'Open in Browser';

	/// en: 'Logged in as ${identity}'
	String loggedInAs({required Object identity}) => 'Logged in as ${identity}';

	/// en: 'Press Save to keep this account connected.'
	String get pressSaveToKeep => 'Press Save to keep this account connected.';

	/// en: 'Connected to ${label}'
	String connectedTo({required Object label}) => 'Connected to ${label}';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';

	/// en: 'Connected as'
	String get connectedAs => 'Connected as';

	/// en: 'Test'
	String get test => 'Test';

	/// en: 'Save failed: ${error}'
	String saveFailed({required Object error}) => 'Save failed: ${error}';

	/// en: 'Login failed: ${error}'
	String loginFailed({required Object error}) => 'Login failed: ${error}';

	/// en: 'Accounts are unavailable right now — try again in a moment'
	String get lookupFailed => 'Accounts are unavailable right now — try again in a moment';

	/// en: 'Finish signing in with your web browser'
	String get browserLoginTitle => 'Finish signing in with your web browser';

	/// en: 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link (from the address bar, or from the error page the browser shows) and paste it here.'
	String browserLoginSteps({required Object prefix}) => 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link (from the address bar, or from the error page the browser shows) and paste it here.';

	/// en: 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to (it starts with "${prefix}") and paste that here.'
	String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to (it starts with "${prefix}") and paste that here.';

	/// en: 'Copy login link'
	String get copyLoginLink => 'Copy login link';

	/// en: 'Paste the link here'
	String get pastedLinkLabel => 'Paste the link here';

	/// en: 'Finish Login'
	String get finishLogin => 'Finish Login';

	/// en: 'That is not the login link — it should start with "${prefix}".'
	String pastedLinkNotARedirect({required Object prefix}) => 'That is not the login link — it should start with "${prefix}".';

	/// en: 'That link belongs to a different login attempt. Close this page and connect again.'
	String get pastedLinkWrongLogin => 'That link belongs to a different login attempt. Close this page and connect again.';

	/// en: 'That link has no login code. Finish signing in first, then copy the link it sends you to.'
	String get pastedLinkNoCode => 'That link has no login code. Finish signing in first, then copy the link it sends you to.';

	/// en: 'That link looks cut off. Copy the whole thing and paste it again.'
	String get pastedLinkMalformed => 'That link looks cut off. Copy the whole thing and paste it again.';

	/// en: 'Waiting for you to finish signing in — this will continue automatically once you do.'
	String get relayLoginWaiting => 'Waiting for you to finish signing in — this will continue automatically once you do.';

	/// en: 'This device hasn't heard back from the sign-in yet. If you already finished in your browser, cancel and try connecting again.'
	String get loginNoResponse => 'This device hasn\'t heard back from the sign-in yet. If you already finished in your browser, cancel and try connecting again.';

	/// en: 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.'
	String get relayLoginNotOpened => 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.';

	/// en: 'Couldn't reach the sync server needed to complete this login. Check your connection and try again.'
	String get relayLoginUnavailable => 'Couldn\'t reach the sync server needed to complete this login. Check your connection and try again.';

	/// en: 'That login attempt didn't complete correctly. Please try connecting again.'
	String get loginIncompleteResponse => 'That login attempt didn\'t complete correctly. Please try connecting again.';

	/// en: 'Account logins can’t be saved'
	String get noKeyringTitle => 'Account logins can’t be saved';

	/// en: 'Ham2K Logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. Install and start **gnome-keyring**, **KWallet** or **KeePassXC**, or unlock the keyring you already have, then restart. Logging, exports and data files are unaffected; log sync stays off while this lasts.'
	String get noKeyringText => 'Ham2K Logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. Install and start **gnome-keyring**, **KWallet** or **KeePassXC**, or unlock the keyring you already have, then restart. Logging, exports and data files are unaffected; log sync stays off while this lasts.';

	/// en: 'Logins can’t be saved: this computer’s keyring can’t be reached. Install and start gnome-keyring, KWallet or KeePassXC, or unlock the one you have.'
	String get noKeyringInline => 'Logins can’t be saved: this computer’s keyring can’t be reached. Install and start gnome-keyring, KWallet or KeePassXC, or unlock the one you have.';

	/// en: 'Logins can’t be saved: this computer’s secure storage can’t be reached.'
	String get noSecureStorageInline => 'Logins can’t be saved: this computer’s secure storage can’t be reached.';
}

// Path: settings.station
class Translations$settings$station$en {
	Translations$settings$station$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Station Configuration & CAT Control'
	String get title => 'Station Configuration & CAT Control';

	/// en: 'No equipment configured'
	String get none => 'No equipment configured';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Add equipment'
	String get addTitle => 'Add equipment';

	/// en: 'Search equipment'
	String get searchHint => 'Search equipment';

	/// en: 'No equipment matches'
	String get noMatches => 'No equipment matches';

	/// en: 'Detected Equipment'
	String get detectedEquipment => 'Detected Equipment';

	/// en: 'Can't listen for radios: ${error}'
	String discoveryUnavailable({required Object error}) => 'Can\'t listen for radios: ${error}';

	/// en: 'Edit equipment'
	String get edit => 'Edit equipment';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'What you call it — "Left Radio". Optional.'
	String get nameDescription => 'What you call it — "Left Radio". Optional.';

	/// en: 'Connection'
	String get transport => 'Connection';

	/// en: 'Address'
	String get host => 'Address';

	/// en: 'The radio's hostname or IP address on your network.'
	String get hostDescription => 'The radio\'s hostname or IP address on your network.';

	/// en: 'Port'
	String get port => 'Port';

	/// en: 'An address is required'
	String get hostRequired => 'An address is required';

	/// en: 'Port must be between 1 and 65535'
	String get portInvalid => 'Port must be between 1 and 65535';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Remove ${name}?'
	String removeTitle({required Object name}) => 'Remove ${name}?';

	/// en: 'This only removes it from the app. The equipment's settings stay as they are.'
	String get removeMessage => 'This only removes it from the app. The equipment\'s settings stay as they are.';

	/// en: 'Unrecognized equipment type "${typeKey}"'
	String unknownType({required Object typeKey}) => 'Unrecognized equipment type "${typeKey}"';

	/// en: 'Report'
	String get report => 'Report';

	/// en: 'Report this radio'
	String get reportTitle => 'Report this radio';

	/// en: 'Tell us what radio this really is and how it went. Your report becomes a card the Ham2K team reads, and what you write about getting it working may end up helping the next operator with the same rig.'
	String get reportIntro => 'Tell us what radio this really is and how it went. Your report becomes a card the Ham2K team reads, and what you write about getting it working may end up helping the next operator with the same rig.';

	/// en: 'Manufacturer'
	String get reportManufacturer => 'Manufacturer';

	/// en: 'Who makes it — Icom, Yaesu, Kenwood, Elecraft…'
	String get reportManufacturerDescription => 'Who makes it — Icom, Yaesu, Kenwood, Elecraft…';

	/// en: 'A manufacturer is required'
	String get reportManufacturerRequired => 'A manufacturer is required';

	/// en: 'Model'
	String get reportModel => 'Model';

	/// en: 'The model, as the radio itself calls it — "IC-7300", "FT-991A".'
	String get reportModelDescription => 'The model, as the radio itself calls it — "IC-7300", "FT-991A".';

	/// en: 'A model is required'
	String get reportModelRequired => 'A model is required';

	/// en: 'How did it go?'
	String get reportOutcome => 'How did it go?';

	/// en: 'Worked well'
	String get reportOutcomeWorks => 'Worked well';

	/// en: 'Worked, with issues'
	String get reportOutcomeIssues => 'Worked, with issues';

	/// en: 'Didn't work at all'
	String get reportOutcomeFails => 'Didn\'t work at all';

	/// en: 'Please tell us how it went'
	String get reportOutcomeRequired => 'Please tell us how it went';

	/// en: 'Comments'
	String get reportComments => 'Comments';

	/// en: 'What worked, what didn't, anything that surprised you.'
	String get reportCommentsPlaceholder => 'What worked, what didn\'t, anything that surprised you.';

	/// en: 'Troubleshooting hints'
	String get reportHints => 'Troubleshooting hints';

	/// en: 'Want to suggest some troubleshooting hints for other users?'
	String get reportHintsPlaceholder => 'Want to suggest some troubleshooting hints for other users?';

	/// en: 'Send report'
	String get reportSend => 'Send report';

	/// en: 'Sending your report…'
	String get reportSending => 'Sending your report…';

	/// en: 'Thanks — your report was filed as ${ref}.'
	String reportSent({required Object ref}) => 'Thanks — your report was filed as ${ref}.';

	/// en: 'Thanks — your report was sent.'
	String get reportSentNoRef => 'Thanks — your report was sent.';

	/// en: 'The report wasn't sent: ${error}'
	String reportFailed({required Object error}) => 'The report wasn\'t sent: ${error}';

	/// en: 'Troubleshooting Notes'
	String get troubleshootingNotes => 'Troubleshooting Notes';

	/// en: 'Main VFO'
	String get mainVfo => 'Main VFO';

	/// en: 'Use as Main VFO'
	String get useAsMainVfo => 'Use as Main VFO';

	/// en: 'Serial port'
	String get serialPort => 'Serial port';

	/// en: 'The port the radio's CAT interface appears on.'
	String get serialPortDescription => 'The port the radio\'s CAT interface appears on.';

	/// en: 'No serial ports found'
	String get serialPortNone => 'No serial ports found';

	/// en: 'Choose a serial port'
	String get serialPortRequired => 'Choose a serial port';

	/// en: 'port $n of $total'
	String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} of ${total}';

	/// en: 'suggested'
	String get serialPortSuggested => 'suggested';

	/// en: 'Recently connected'
	String get serialPortJustNow => 'Recently connected';

	/// en: 'Add a USB device…'
	String get serialDeviceRequest => 'Add a USB device…';

	/// en: 'Bluetooth LE device'
	String get bleDevice => 'Bluetooth LE device';

	/// en: 'The serial bridge your radio is connected through, such as a LiNK500MP in its iOS mode or a BLE serial adapter.'
	String get bleDeviceDescription => 'The serial bridge your radio is connected through, such as a LiNK500MP in its iOS mode or a BLE serial adapter.';

	/// en: 'Scan for Bluetooth LE devices…'
	String get bleScan => 'Scan for Bluetooth LE devices…';

	/// en: 'No Bluetooth LE devices found. Check that the bridge is on, nearby, and in its Bluetooth LE (iOS) mode.'
	String get bleScanNoneFound => 'No Bluetooth LE devices found. Check that the bridge is on, nearby, and in its Bluetooth LE (iOS) mode.';

	/// en: 'The Bluetooth LE scan could not run: ${reason}'
	String bleScanFailed({required Object reason}) => 'The Bluetooth LE scan could not run: ${reason}';

	/// en: 'Bluetooth is turned off.'
	String get bleOff => 'Bluetooth is turned off.';

	/// en: 'Bluetooth permission was not granted. Allow it in system settings, then try again.'
	String get bleDenied => 'Bluetooth permission was not granted. Allow it in system settings, then try again.';

	/// en: 'This device has no Bluetooth LE.'
	String get bleUnsupported => 'This device has no Bluetooth LE.';

	/// en: 'Bluetooth is still starting up. Try again in a moment.'
	String get bleStarting => 'Bluetooth is still starting up. Try again in a moment.';

	/// en: 'Cannot reach the Bluetooth LE device. Check that it's on, nearby, and not connected to another app.'
	String get bleConnectFailed => 'Cannot reach the Bluetooth LE device. Check that it\'s on, nearby, and not connected to another app.';

	/// en: 'This Bluetooth LE device has no serial service the app recognizes. Please report it with its services: ${services}'
	String bleNoSerialService({required Object services}) => 'This Bluetooth LE device has no serial service the app recognizes. Please report it with its services: ${services}';

	/// en: 'Speed (baud)'
	String get baudRate => 'Speed (baud)';

	/// en: 'Must match the radio's CAT menu. With a mismatch, the radio sends back garbage and no error.'
	String get baudRateDescription => 'Must match the radio\'s CAT menu. With a mismatch, the radio sends back garbage and no error.';

	/// en: 'Hold RTS high'
	String get serialRtsHigh => 'Hold RTS high';

	/// en: 'Only for a radio that waits for RTS before responding, such as a Yaesu with CAT RTS turned on. On a Digirig, SignaLink and most home-made cables RTS is PTT, and holding it high transmits.'
	String get serialRtsHighDescription => 'Only for a radio that waits for RTS before responding, such as a Yaesu with CAT RTS turned on. On a Digirig, SignaLink and most home-made cables RTS is PTT, and holding it high transmits.';

	/// en: 'Hold DTR high'
	String get serialDtrHigh => 'Hold DTR high';

	/// en: 'Only for a CAT interface that draws its power from DTR, such as some RS-232 cables for the FT-817. On many cables DTR keys CW or PTT, and holding it high transmits.'
	String get serialDtrHighDescription => 'Only for a CAT interface that draws its power from DTR, such as some RS-232 cables for the FT-817. On many cables DTR keys CW or PTT, and holding it high transmits.';

	/// en: 'Radio CI-V address'
	String get civAddress => 'Radio CI-V address';

	/// en: 'Hex, as shown in the radio's CI-V menu. The IC-705 ships as A4.'
	String get civAddressDescription => 'Hex, as shown in the radio\'s CI-V menu. The IC-705 ships as A4.';

	/// en: 'A CI-V address is two hex digits, 01 to FF'
	String get civAddressInvalid => 'A CI-V address is two hex digits, 01 to FF';

	/// en: 'Slice'
	String get flexSlice => 'Slice';

	/// en: 'Which of the radio's slices this connection reads from and tunes.'
	String get flexSliceDescription => 'Which of the radio\'s slices this connection reads from and tunes.';

	/// en: 'Slice ${letter}'
	String flexSliceLabel({required Object letter}) => 'Slice ${letter}';

	/// en: 'Pick one of the radio's slices, A through H'
	String get flexSliceInvalid => 'Pick one of the radio\'s slices, A through H';

	/// en: 'Slice ${letter} is not in use on this radio — pick another slice, or create it in SmartSDR'
	String flexSliceMissing({required Object letter}) => 'Slice ${letter} is not in use on this radio — pick another slice, or create it in SmartSDR';

	/// en: 'not in use'
	String get channelNotInUse => 'not in use';

	/// en: 'in use by another program'
	String get channelHeldByUnknown => 'in use by another program';

	/// en: 'This radio has not reported any slices — check that SmartSDR is running and that this client may subscribe'
	String get flexNoSlices => 'This radio has not reported any slices — check that SmartSDR is running and that this client may subscribe';

	/// en: 'This radio sends no spectrum over CAT'
	String get spectrumUnsupported => 'This radio sends no spectrum over CAT';

	/// en: 'Requires CAT at 115200 bps'
	String get spectrumRequiresBaud => 'Requires CAT at 115200 bps';

	/// en: 'No radio connected'
	String get spectrumNoRadio => 'No radio connected';

	/// en: 'Waiting for the radio's spectrum…'
	String get spectrumWaiting => 'Waiting for the radio\'s spectrum…';

	/// en: 'Spectrum display is not available'
	String get spectrumUnavailable => 'Spectrum display is not available';

	/// en: 'Every DAX IQ channel on this radio is in use'
	String get spectrumNoDaxChannel => 'Every DAX IQ channel on this radio is in use';

	/// en: 'This slice has no panadapter on the radio'
	String get spectrumNoPanadapter => 'This slice has no panadapter on the radio';

	/// en: 'The radio refused a DAX IQ stream (error ${code})'
	String spectrumStreamRefused({required Object code}) => 'The radio refused a DAX IQ stream (error ${code})';

	/// en: 'The radio's spectrum data cannot reach this device'
	String get spectrumNoUdp => 'The radio\'s spectrum data cannot reach this device';

	/// en: 'Cannot receive the K4’s LAN spectrum. Retrying…'
	String get spectrumK4Unavailable => 'Cannot receive the K4’s LAN spectrum. Retrying…';

	/// en: 'Cannot receive the K4’s remote spectrum'
	String get spectrumK4RemoteUnavailable => 'Cannot receive the K4’s remote spectrum';

	/// en: 'The radio refused its scope commands'
	String get spectrumScopeRefused => 'The radio refused its scope commands';

	/// en: 'The radio's scope is set outside the range it can show'
	String get spectrumOutOfRange => 'The radio\'s scope is set outside the range it can show';

	/// en: 'The radio's scope cannot be shown on this band'
	String get spectrumBandUnsupported => 'The radio\'s scope cannot be shown on this band';

	/// en: 'Waiting for the linked radio's frequency…'
	String get spectrumSdrNoRadio => 'Waiting for the linked radio\'s frequency…';

	/// en: 'The SDR is not connected'
	String get spectrumSdrNotConnected => 'The SDR is not connected';

	/// en: 'Set the radio's IF frequency in this SDR's settings'
	String get spectrumSdrNoIf => 'Set the radio\'s IF frequency in this SDR\'s settings';

	/// en: 'Shows the spectrum for'
	String get sdrRadio => 'Shows the spectrum for';

	/// en: 'A spectrum display on this radio draws from this receiver instead of the radio's own scope.'
	String get sdrRadioDescription => 'A spectrum display on this radio draws from this receiver instead of the radio\'s own scope.';

	/// en: 'The Main radio'
	String get sdrRadioMain => 'The Main radio';

	/// en: 'Antenna input'
	String get sdrTuning => 'Antenna input';

	/// en: 'Where the receiver's signal comes from. On its own antenna it tunes itself to follow the radio; on the radio's IF output it stays on the IF.'
	String get sdrTuningDescription => 'Where the receiver\'s signal comes from. On its own antenna it tunes itself to follow the radio; on the radio\'s IF output it stays on the IF.';

	/// en: 'Its own antenna'
	String get sdrTuningIndependent => 'Its own antenna';

	/// en: 'The radio's IF output'
	String get sdrTuningIfTap => 'The radio\'s IF output';

	/// en: 'IF frequency (Hz)'
	String get sdrIfHz => 'IF frequency (Hz)';

	/// en: 'For an IF output only: the frequency the radio's dial sits at on its IF, such as 68330000 on an FT-817.'
	String get sdrIfHzDescription => 'For an IF output only: the frequency the radio\'s dial sits at on its IF, such as 68330000 on an FT-817.';

	/// en: 'IF is inverted'
	String get sdrIfInverted => 'IF is inverted';

	/// en: 'Gain (dB)'
	String get sdrGainDb => 'Gain (dB)';

	/// en: 'Leave blank for the receiver's automatic gain.'
	String get sdrGainDbDescription => 'Leave blank for the receiver\'s automatic gain.';

	/// en: 'Frequency offset (Hz)'
	String get sdrOffsetHz => 'Frequency offset (Hz)';

	/// en: 'Added to every frequency sent to the receiver, for an upconverter: 125000000 for a Ham It Up.'
	String get sdrOffsetHzDescription => 'Added to every frequency sent to the receiver, for an upconverter: 125000000 for a Ham It Up.';

	/// en: 'Frequency correction (ppm)'
	String get sdrPpm => 'Frequency correction (ppm)';

	/// en: 'Direct sampling'
	String get rtlDirectSampling => 'Direct sampling';

	/// en: 'For HF on an RTL-SDR V3 without an upconverter. An RTL-SDR V4 reaches HF without it.'
	String get rtlDirectSamplingDescription => 'For HF on an RTL-SDR V3 without an upconverter. An RTL-SDR V4 reaches HF without it.';

	/// en: 'Off'
	String get rtlDirectSamplingOff => 'Off';

	/// en: 'I branch'
	String get rtlDirectSamplingI => 'I branch';

	/// en: 'Q branch'
	String get rtlDirectSamplingQ => 'Q branch';

	/// en: 'This is not an rtl_tcp server'
	String get rtlTcpNotAServer => 'This is not an rtl_tcp server';

	/// en: 'This connects to an **rtl_tcp server you run yourself** on the computer the dongle is plugged into. - **Start it** with `rtl_tcp -a 0.0.0.0` so other machines can reach it; on the same machine, `rtl_tcp` alone will do. - **Port** is 1234 unless you started it with `-p`. - **One program at a time:** rtl_tcp serves a single client. The app connects only while a spectrum display is showing, and lets go a few seconds after it closes. - **On Android**, the *SDR driver* app runs the same server on the phone.'
	String get rtlTcpNotes => 'This connects to an **rtl_tcp server you run yourself** on the computer the dongle is plugged into.\n\n- **Start it** with `rtl_tcp -a 0.0.0.0` so other machines can reach it; on the same machine, `rtl_tcp` alone will do.\n- **Port** is 1234 unless you started it with `-p`.\n- **One program at a time:** rtl_tcp serves a single client. The app connects only while a spectrum display is showing, and lets go a few seconds after it closes.\n- **On Android**, the *SDR driver* app runs the same server on the phone.';

	/// en: 'This connects to an **rsp_tcp server you run yourself** on the computer the RSP is plugged into, with SDRplay's API installed there. - **Start it** with `rsp_tcp -a 0.0.0.0`. - **Port** is 1234 unless you started it with `-p`. - **One program at a time:** the server takes a single client. The app connects only while a spectrum display is showing.'
	String get rspTcpNotes => 'This connects to an **rsp_tcp server you run yourself** on the computer the RSP is plugged into, with SDRplay\'s API installed there.\n\n- **Start it** with `rsp_tcp -a 0.0.0.0`.\n- **Port** is 1234 unless you started it with `-p`.\n- **One program at a time:** the server takes a single client. The app connects only while a spectrum display is showing.';

	/// en: 'N3FJP has no radio interface set up, so this follows what is typed into N3FJP, not a radio'
	String get n3fjpNoRig => 'N3FJP has no radio interface set up, so this follows what is typed into N3FJP, not a radio';

	/// en: 'Key output'
	String get winkeyerKeyPort => 'Key output';

	/// en: 'Which of the keyer's two output jacks your radio is plugged into.'
	String get winkeyerKeyPortDescription => 'Which of the keyer\'s two output jacks your radio is plugged into.';

	/// en: 'Port ${n}'
	String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';

	/// en: 'Use the keyer's PTT'
	String get winkeyerPtt => 'Use the keyer\'s PTT';

	/// en: 'Key the PTT line on the same jack, for an amplifier or a radio that needs it. Leave off for a radio keyed on its key jack.'
	String get winkeyerPttDescription => 'Key the PTT line on the same jack, for an amplifier or a radio that needs it. Leave off for a radio keyed on its key jack.';

	/// en: 'No WinKeyer responded on this port'
	String get winkeyerNoAnswer => 'No WinKeyer responded on this port';

	/// en: 'The WinKeyer stopped responding while sending; the message was dropped'
	String get winkeyerStoppedAnswering => 'The WinKeyer stopped responding while sending; the message was dropped';

	/// en: 'Control port (UDP)'
	String get icomControlPort => 'Control port (UDP)';

	/// en: 'The radio's Control Port (UDP) — 50001 unless changed in its network settings, or forwarded to another.'
	String get icomControlPortDescription => 'The radio\'s Control Port (UDP) — 50001 unless changed in its network settings, or forwarded to another.';

	/// en: 'Serial port (UDP)'
	String get icomSerialPort => 'Serial port (UDP)';

	/// en: 'The radio's Serial Port (UDP) — 50002 unless changed in its network settings, or forwarded to another.'
	String get icomSerialPortDescription => 'The radio\'s Serial Port (UDP) — 50002 unless changed in its network settings, or forwarded to another.';

	/// en: 'The control and serial ports must differ'
	String get icomPortsDiffer => 'The control and serial ports must differ';

	/// en: 'Radio username'
	String get radioUser => 'Radio username';

	/// en: 'Radio password'
	String get radioPass => 'Radio password';

	/// en: 'The radio's Network → Remote login, not your WiFi password.'
	String get radioLoginDescription => 'The radio\'s Network → Remote login, not your WiFi password.';

	/// en: 'The radio's remote-control username is required'
	String get radioUserRequired => 'The radio\'s remote-control username is required';

	/// en: 'Device is in use'
	String get connectFailedBusy => 'Device is in use';

	/// en: 'Access denied'
	String get connectFailedDenied => 'Access denied';

	/// en: 'Device not found'
	String get connectFailedDevice => 'Device not found';

	/// en: 'RTS/DTR could not be held as set, so the port was closed. Another program may have left hardware handshaking on — unplug and replug the cable.'
	String get connectFailedLines => 'RTS/DTR could not be held as set, so the port was closed. Another program may have left hardware handshaking on — unplug and replug the cable.';

	/// en: 'Cannot find the radio over the network. Check its address and that it's powered on and reachable.'
	String get connectFailedNetwork => 'Cannot find the radio over the network. Check its address and that it\'s powered on and reachable.';

	/// en: 'The radio didn't respond in time. Check it's powered on and reachable.'
	String get connectFailedTimeout => 'The radio didn\'t respond in time. Check it\'s powered on and reachable.';

	late final Translations$settings$station$models$en models = Translations$settings$station$models$en.internal(_root);
	late final Translations$settings$station$transports$en transports = Translations$settings$station$transports$en.internal(_root);

	/// en: 'If the radio connects but shows no frequency'
	String get troubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'The radio is receiving commands but not responding. Almost always one of: - **CAT RTS off at the radio, or Hold RTS high on.** With **CAT RTS** on (FT-891 menu **05-08**), the radio stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio's own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead. - **Speed must match** the radio's CAT RATE (menu **05-06**). With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.'
	String get ft891Troubleshooting => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **CAT RTS off at the radio, or Hold RTS high on.** With **CAT RTS** on (FT-891 menu **05-08**), the radio stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio\'s own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead.\n- **Speed must match** the radio\'s CAT RATE (menu **05-06**). With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.';

	/// en: 'If the radio connects but shows no frequency'
	String get yaesuBinaryTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'This radio speaks Yaesu's older five-byte CAT, and it does not respond at all when something is off. Almost always one of: - **The cable must convert levels.** The CAT jack on the back is not RS-232 and not USB; it needs a CT-62 or an equivalent adapter. A plain audio or data cable won't work for CAT. - **Speed must match** the radio's CAT RATE menu (**#14** on an FT-817, **#19** on an FT-857 or FT-897). With a mismatch, the radio sends nothing back, and never an error. - **Never let anything raise RTS or DTR on this port.** On most cables for these radios those lines are PTT and keying. An older interface powered from DTR is the exception: turn on **Hold DTR high** under Advanced Settings for that one. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. This driver was written from Yaesu's published CAT chart and has not been run against one of these radios. If it half-works, that is worth reporting.'
	String get yaesuBinaryTroubleshooting => 'This radio speaks Yaesu\'s older five-byte CAT, and it does not respond at all when something is off. Almost always one of:\n\n- **The cable must convert levels.** The CAT jack on the back is not RS-232 and not USB; it needs a CT-62 or an equivalent adapter. A plain audio or data cable won\'t work for CAT.\n- **Speed must match** the radio\'s CAT RATE menu (**#14** on an FT-817, **#19** on an FT-857 or FT-897). With a mismatch, the radio sends nothing back, and never an error.\n- **Never let anything raise RTS or DTR on this port.** On most cables for these radios those lines are PTT and keying. An older interface powered from DTR is the exception: turn on **Hold DTR high** under Advanced Settings for that one.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis driver was written from Yaesu\'s published CAT chart and has not been run against one of these radios. If it half-works, that is worth reporting.';

	/// en: 'If the radio connects but shows no frequency'
	String get tenTecTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: '- **The USB-B port on the back is the CAT link.** The radio shows up as a USB serial port; on Windows it needs Ten-Tec's USB to UART driver, which appears in Device Manager as "USB to UART (COMx)". - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open, and so does Ten-Tec's firmware updater. - **Setting the filter width from the app takes it away from the BW knob** until the radio is switched off and on again. That is how the radio works. This driver was written from Ten-Tec's programmer's reference guide. If it half-works, that is worth reporting, with the firmware version from the radio's menu.'
	String get tenTecEagleTroubleshooting => '- **The USB-B port on the back is the CAT link.** The radio shows up as a USB serial port; on Windows it needs Ten-Tec\'s USB to UART driver, which appears in Device Manager as "USB to UART (COMx)".\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open, and so does Ten-Tec\'s firmware updater.\n- **Setting the filter width from the app takes it away from the BW knob** until the radio is switched off and on again. That is how the radio works.\n\nThis driver was written from Ten-Tec\'s programmer\'s reference guide. If it half-works, that is worth reporting, with the firmware version from the radio\'s menu.';

	/// en: '- **Use a straight-through DB-9 serial cable** to the SERIAL DATA port, not a null-modem one. - **This entry holds RTS high**, because the Orion uses RTS and CTS as its handshake. On an interface that keys PTT from RTS, such as a Digirig, turn off Hold RTS high under Advanced Settings, or the radio transmits as soon as the app connects. - **CW from the app needs the radio's internal keyer on.** With it off, the radio ignores what the app sends. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. This driver was written from Ten-Tec's programmer's reference guide and has not been run against an Orion. If it half-works, that is worth reporting, with the firmware version from the radio's menu.'
	String get tenTecOrionTroubleshooting => '- **Use a straight-through DB-9 serial cable** to the SERIAL DATA port, not a null-modem one.\n- **This entry holds RTS high**, because the Orion uses RTS and CTS as its handshake. On an interface that keys PTT from RTS, such as a Digirig, turn off Hold RTS high under Advanced Settings, or the radio transmits as soon as the app connects.\n- **CW from the app needs the radio\'s internal keyer on.** With it off, the radio ignores what the app sends.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis driver was written from Ten-Tec\'s programmer\'s reference guide and has not been run against an Orion. If it half-works, that is worth reporting, with the firmware version from the radio\'s menu.';

	/// en: 'This radio's firmware does not take CW from the app. Ten-Tec added it in Orion firmware 1.366.'
	String get tenTecNoCw => 'This radio\'s firmware does not take CW from the app. Ten-Tec added it in Orion firmware 1.366.';

	/// en: 'The radio's internal keyer is off, so it ignores CW sent from the app. Turn the keyer on in the radio's menu.'
	String get tenTecKeyerOff => 'The radio\'s internal keyer is off, so it ignores CW sent from the app. Turn the keyer on in the radio\'s menu.';

	/// en: 'If the radio connects but shows no frequency'
	String get guohetecTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'The Q900 has two CAT protocols, and this entry uses its native one rather than the FT-817 imitation. Pick **Guohetec Q900** here, not an FT-817 — the imitation supports fewer commands, and the radio does not say which one it is using. - **The USB-C cable is the CAT link**, and it connects the sound card too. Speed does not matter on it; the port ignores whatever it is set to. - **Never let anything raise RTS or DTR on this port.** On a serial cable those lines are PTT and keying. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. - **A second-generation radio behaves differently** from a first. Long press Menu, then About: HW 2.0 is the second generation. This driver was written from the manufacturer's published protocol and has not been run against one of these radios. If it half-works, that is worth reporting.'
	String get guohetecTroubleshooting => 'The Q900 has two CAT protocols, and this entry uses its native one rather than the FT-817 imitation. Pick **Guohetec Q900** here, not an FT-817 — the imitation supports fewer commands, and the radio does not say which one it is using.\n\n- **The USB-C cable is the CAT link**, and it connects the sound card too. Speed does not matter on it; the port ignores whatever it is set to.\n- **Never let anything raise RTS or DTR on this port.** On a serial cable those lines are PTT and keying.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **A second-generation radio behaves differently** from a first. Long press Menu, then About: HW 2.0 is the second generation.\n\nThis driver was written from the manufacturer\'s published protocol and has not been run against one of these radios. If it half-works, that is worth reporting.';

	/// en: 'If the radio connects but shows no frequency'
	String get yaesuTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'The radio is receiving commands but not responding. Almost always one of: - **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low. On a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter. On the radio's own USB port, **Hold RTS high** under Advanced Settings is the alternative. Where that setting lives differs by model (menu **05-08** on an FT-891). - **Speed must match** the radio's CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. - **Modes follow the FT-891's table.** Most of the Yaesu line matches it, but a radio that numbers its modes differently will show and set the wrong one for those. The frequency is unaffected.'
	String get yaesuTroubleshooting => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low. On a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter. On the radio\'s own USB port, **Hold RTS high** under Advanced Settings is the alternative. Where that setting lives differs by model (menu **05-08** on an FT-891).\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **Modes follow the FT-891\'s table.** Most of the Yaesu line matches it, but a radio that numbers its modes differently will show and set the wrong one for those. The frequency is unaffected.';

	/// en: 'The radio is receiving commands but not responding. Almost always one of: - **The CAT jack is RS-232.** It needs a USB-to-serial adapter and a straight-through DB-9 cable — a null-modem cable swaps the lines, and the radio never hears a thing. - **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low unless **Hold RTS high** is on under Advanced Settings. - **Speed must match** the radio's CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. This entry was written from published CAT documentation and has not been run against one of these radios. If it half-works, that is worth reporting.'
	String get yaesuRs232Troubleshooting => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **The CAT jack is RS-232.** It needs a USB-to-serial adapter and a straight-through DB-9 cable — a null-modem cable swaps the lines, and the radio never hears a thing.\n- **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low unless **Hold RTS high** is on under Advanced Settings.\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis entry was written from published CAT documentation and has not been run against one of these radios. If it half-works, that is worth reporting.';

	/// en: 'The radio is receiving commands but not responding. Almost always one of: - **Use the first of the radio's two USB ports.** CAT is normally on the first (the **Enhanced** COM port on Windows); the second (**Standard**) is for PTT and keying. The picker points at the first wherever it can tell the two apart. - **CAT RTS off at the radio, or Hold RTS high on.** With the radio's **CAT RTS** menu on, it stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio's own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead. - **Speed must match** the radio's CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.'
	String get yaesuUsbTroubleshooting => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **Use the first of the radio\'s two USB ports.** CAT is normally on the first (the **Enhanced** COM port on Windows); the second (**Standard**) is for PTT and keying. The picker points at the first wherever it can tell the two apart.\n- **CAT RTS off at the radio, or Hold RTS high on.** With the radio\'s **CAT RTS** menu on, it stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio\'s own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead.\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.';

	/// en: 'Connect the K4’s rear USB-B (PC) socket. Either USB-PC1 or USB-PC2 works for CAT; choose an unused port and match its Serial USB-PCn: Baud Rate setting on the radio. HaLo prefills 38400; change it if needed. Another application must use the other port or Ethernet. This connection controls the radio and its keyers; it does not send audio to HaLo.'
	String get k4SerialNotes => 'Connect the K4’s rear USB-B (PC) socket. Either USB-PC1 or USB-PC2 works for CAT; choose an unused port and match its Serial USB-PCn: Baud Rate setting on the radio. HaLo prefills 38400; change it if needed. Another application must use the other port or Ethernet.\n\nThis connection controls the radio and its keyers; it does not send audio to HaLo.';

	/// en: 'Connect the K4’s Ethernet socket to your local network. Enter its hostname or IP address and CAT port 9200. HaLo uses the same host on fixed port 9201 when a panadapter or waterfall is visible; changing the CAT port does not change the spectrum port. The spectrum shows the main receiver. Its zoom, reference adjustment and speed controls affect only HaLo’s display. Audio streaming is not supported.'
	String get k4TcpNotes => 'Connect the K4’s Ethernet socket to your local network. Enter its hostname or IP address and CAT port 9200. HaLo uses the same host on fixed port 9201 when a panadapter or waterfall is visible; changing the CAT port does not change the spectrum port.\n\nThe spectrum shows the main receiver. Its zoom, reference adjustment and speed controls affect only HaLo’s display. Audio streaming is not supported.';

	/// en: 'K4 power was not changed because the radio did not confirm its output range. Try again.'
	String get k4PowerTimeout => 'K4 power was not changed because the radio did not confirm its output range. Try again.';

	/// en: 'Enable remote access on your K4 and enter its network password. Main and Sub share one encrypted connection for radio control and spectrum. The default port is 9204; enter your forwarded port when connecting remotely. Audio playback and microphone streaming are not supported.'
	String get k4RemoteNotes => 'Enable remote access on your K4 and enter its network password. Main and Sub share one encrypted connection for radio control and spectrum. The default port is 9204; enter your forwarded port when connecting remotely.\n\nAudio playback and microphone streaming are not supported.';

	/// en: 'Receiver'
	String get k4Receiver => 'Receiver';

	/// en: 'Main'
	String get k4ReceiverMain => 'Main';

	/// en: 'Sub'
	String get k4ReceiverSub => 'Sub';

	/// en: 'Choose Main or Sub'
	String get k4ReceiverInvalid => 'Choose Main or Sub';

	/// en: 'That receiver is already configured for this K4'
	String get k4ReceiverAlreadyConfigured => 'That receiver is already configured for this K4';

	/// en: 'The K4 sub receiver is off'
	String get k4SubReceiverOff => 'The K4 sub receiver is off';

	/// en: 'Enter the K4’s network password to connect securely.'
	String get k4RemotePasswordRequired => 'Enter the K4’s network password to connect securely.';

	/// en: 'The K4 could not establish a secure connection. Check its network password and remote access settings.'
	String get k4RemoteHandshakeFailed => 'The K4 could not establish a secure connection. Check its network password and remote access settings.';

	/// en: 'The K4’s secure connection could not be reached. Check its address, port and remote access settings.'
	String get k4RemoteUnreachable => 'The K4’s secure connection could not be reached. Check its address, port and remote access settings.';

	/// en: 'K4 power must be 0.1–110 W, or 0.0001–0.01 W when the transverter milliwatt output is active.'
	String get k4PowerRange => 'K4 power must be 0.1–110 W, or 0.0001–0.01 W when the transverter milliwatt output is active.';

	/// en: 'If the radio connects but shows no frequency'
	String get elecraftTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'Elecraft rigs speak Kenwood CAT, and a KX2 and a KX3 have both been run this way — VFO in both directions, mode switching and CW zero-beat all working. If the radio does not respond, almost always one of: - **Speed must match** the rate set under **RS232** in the radio's menu. 38400 is what these ship on. With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. **If the frequency is right but the mode is wrong**, tell us. The KX2 and KX3 entries read the mode from a position in the radio's status reply that we have pinned from the rigs we have seen, and a firmware that puts it elsewhere is something only a report reaches us as. The K3 has not been reported either way, so please say what happens if you run one. A K4 has its own entry.'
	String get elecraftTroubleshooting => 'Elecraft rigs speak Kenwood CAT, and a KX2 and a KX3 have both been run this way — VFO in both directions, mode switching and CW zero-beat all working.\n\nIf the radio does not respond, almost always one of:\n\n- **Speed must match** the rate set under **RS232** in the radio\'s menu. 38400 is what these ship on. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\n**If the frequency is right but the mode is wrong**, tell us. The KX2 and KX3 entries read the mode from a position in the radio\'s status reply that we have pinned from the rigs we have seen, and a firmware that puts it elsewhere is something only a report reaches us as.\n\nThe K3 has not been reported either way, so please say what happens if you run one. A K4 has its own entry.';

	/// en: 'If the radio connects but shows no frequency'
	String get lab599TroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'The TX-500 line speaks Kenwood CAT. Written from published references rather than tested on the radio, so please report what happens either way. - **Speed must match** the radio's CAT setting, 9600 unless you changed it. With a mismatch the radio sends back garbage or nothing, and never an error. - **Pick the CAT protocol on the radio.** TS-2000 covers frequency and mode. LAB599 also lets the app switch the radio to DIG. - **Through a LiNK500MP**, press and hold the VFO knob for about three seconds to hand CAT control to the interface. - **Over Bluetooth on a computer**, the LiNK500MP pairs as two serial ports and only one carries CAT. If the radio stays silent, pick the other. - **Over Bluetooth LE**, as on an iPhone or iPad, switch the LiNK500MP to its iOS mode first. In its other modes it does not show up in a scan.'
	String get lab599Troubleshooting => 'The TX-500 line speaks Kenwood CAT. Written from published references rather than tested on the radio, so please report what happens either way.\n\n- **Speed must match** the radio\'s CAT setting, 9600 unless you changed it. With a mismatch the radio sends back garbage or nothing, and never an error.\n- **Pick the CAT protocol on the radio.** TS-2000 covers frequency and mode. LAB599 also lets the app switch the radio to DIG.\n- **Through a LiNK500MP**, press and hold the VFO knob for about three seconds to hand CAT control to the interface.\n- **Over Bluetooth on a computer**, the LiNK500MP pairs as two serial ports and only one carries CAT. If the radio stays silent, pick the other.\n- **Over Bluetooth LE**, as on an iPhone or iPad, switch the LiNK500MP to its iOS mode first. In its other modes it does not show up in a scan.';

	/// en: 'If the radio connects but shows no frequency'
	String get kenwoodTroubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'This driver is proven against Kenwood's TS-590SG and TS-480, QRP Labs' QMX and QCX-mini, and Elecraft's KX2 and KX3. The rest of the line is written from published CAT references, so please report what happens either way. If the radio does not respond, almost always one of: - **Speed must match** the radio's CAT menu. With a mismatch, the radio sends back garbage or nothing, and never an error. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open. - **Some rigs need CAT enabled** in the menu before they respond at all. **Several SDR front-ends speak this same protocol**, so this entry is worth trying for those too; Elecraft rigs are listed separately, under Elecraft. If the frequency is right but the mode is wrong or missing, that is the one part that differs across the line — the app works it out from the radio and falls back to asking directly, so the mode may simply lag.'
	String get kenwoodTroubleshooting => 'This driver is proven against Kenwood\'s TS-590SG and TS-480, QRP Labs\' QMX and QCX-mini, and Elecraft\'s KX2 and KX3. The rest of the line is written from published CAT references, so please report what happens either way.\n\nIf the radio does not respond, almost always one of:\n\n- **Speed must match** the radio\'s CAT menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **Some rigs need CAT enabled** in the menu before they respond at all.\n\n**Several SDR front-ends speak this same protocol**, so this entry is worth trying for those too; Elecraft rigs are listed separately, under Elecraft. If the frequency is right but the mode is wrong or missing, that is the one part that differs across the line — the app works it out from the radio and falls back to asking directly, so the mode may simply lag.';

	/// en: 'Connected'
	String get statusConnected => 'Connected';

	/// en: 'Disconnected'
	String get statusLost => 'Disconnected';

	/// en: 'Not configured'
	String get notConfigured => 'Not configured';

	/// en: 'Current Configuration'
	String get currentConfiguration => 'Current Configuration';

	/// en: 'Current Transceiver'
	String get currentTransceiver => 'Current Transceiver';

	/// en: 'Radio Mode'
	String get radioMode => 'Radio Mode';

	/// en: 'Not supported by current radio'
	String get keyerNotSupported => 'Not supported by current radio';

	/// en: 'CAT Control Preferences'
	String get catControlPreferences => 'CAT Control Preferences';

	/// en: 'Choose transceiver'
	String get chooseTransceiver => 'Choose transceiver';

	/// en: 'Configuration'
	String get configurationSection => 'Configuration';

	/// en: 'No transceiver selected'
	String get noTransceiverSelected => 'No transceiver selected';

	/// en: 'Use ${name} for the Main VFO'
	String makeMainVfo({required Object name}) => 'Use ${name} for the Main VFO';

	/// en: '(zero) {No transceivers} (one) {${count} transceiver} (other) {${count} transceivers}'
	String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		zero: 'No transceivers',
		one: '${count} transceiver',
		other: '${count} transceivers',
	);

	/// en: '(one) {${count} antenna} (other) {${count} antennas}'
	String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} antenna',
		other: '${count} antennas',
	);

	/// en: '(one) {${count} other device} (other) {${count} other devices}'
	String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} other device',
		other: '${count} other devices',
	);

	/// en: 'Equipment Inventory'
	String get equipmentInventory => 'Equipment Inventory';

	/// en: 'Transceiver Controls'
	String get equipmentInUse => 'Transceiver Controls';

	/// en: 'None'
	String get noTransceiver => 'None';

	/// en: 'Not available'
	String get peerRadioNotAvailable => 'Not available';

	/// en: 'On ${device}'
	String peerRadioOnDevice({required Object device}) => 'On ${device}';

	/// en: '${radio} is on another device'
	String peerRadioElsewhereTitle({required Object radio}) => '${radio} is on another device';

	/// en: 'This radio is connected to ${device}. Its connection and settings are configured on that device.'
	String peerRadioElsewhereMessage({required Object device}) => 'This radio is connected to ${device}. Its connection and settings are configured on that device.';

	/// en: 'Antenna in Use'
	String get antennaInUse => 'Antenna in Use';

	/// en: 'Key in Use'
	String get keyInUse => 'Key in Use';

	/// en: 'None'
	String get noneSelected => 'None';

	/// en: 'More Settings'
	String get moreSettings => 'More Settings';

	/// en: 'If two serial ports show up for the same radio'
	String get icomCivTroubleshootingTitle => 'If two serial ports show up for the same radio';

	/// en: 'Several Icom radios, the IC-705 among them, present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that: the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists, and where this app can tell the two ports apart it marks that one as suggested. If commands go out and the radio never responds, try the other port next.'
	String get icomCivTroubleshooting => 'Several Icom radios, the IC-705 among them, present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that: the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists, and where this app can tell the two ports apart it marks that one as suggested. If commands go out and the radio never responds, try the other port next.';

	/// en: 'If the radio never responds'
	String get civAddressTroubleshootingTitle => 'If the radio never responds';

	/// en: '- **The CI-V address must match** the radio's menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable. - **Speed must match** the radio's CI-V BAUD RATE (on USB, CI-V USB Baud Rate). Set the radio to the same number shown here, **not Auto**. On Auto some radios, the IC-7300 among them, connect and then stop responding after a minute or so. - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.'
	String get civAddressTroubleshooting => '- **The CI-V address must match** the radio\'s menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n- **Speed must match** the radio\'s CI-V BAUD RATE (on USB, CI-V USB Baud Rate). Set the radio to the same number shown here, **not Auto**. On Auto some radios, the IC-7300 among them, connect and then stop responding after a minute or so.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.';

	/// en: '- **The CI-V address must match** the radio's menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable. ${speed} - **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.'
	String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **The CI-V address must match** the radio\'s menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n${speed}\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.';

	/// en: '- **There is no speed to set.** Over USB this radio talks at whatever speed the computer uses, and this entry always uses 115200, the speed the scope needs.'
	String get icomUsbSpeedFollows => '- **There is no speed to set.** Over USB this radio talks at whatever speed the computer uses, and this entry always uses 115200, the speed the scope needs.';

	/// en: '- **Set CI-V USB Baud Rate to 115200**, the speed this entry always uses, since the scope needs it — **not Auto**. A radio set to any other speed answers with silence.'
	String get ic7610UsbSpeed => '- **Set CI-V USB Baud Rate to 115200**, the speed this entry always uses, since the scope needs it — **not Auto**. A radio set to any other speed answers with silence.';

	/// en: ' - The **IC-7300 MK2** ships on address `B6`, not the `94` prefilled here — pick the IC-7300 MK2 entry instead.'
	String get ic7300Mk2Note => '\n- The **IC-7300 MK2** ships on address `B6`, not the `94` prefilled here — pick the IC-7300 MK2 entry instead.';

	/// en: ' - The **IC-705** presents two USB serial ports, both named after the radio. CI-V is on the **first** of them, which the picker points at wherever it can tell the two apart.'
	String get ic705PortNote => '\n- The **IC-705** presents two USB serial ports, both named after the radio. CI-V is on the **first** of them, which the picker points at wherever it can tell the two apart.';

	/// en: ' - The **IC-7760** speaks CI-V on **Port A** of the two USB serial ports it presents.'
	String get ic7760PortNote => '\n- The **IC-7760** speaks CI-V on **Port A** of the two USB serial ports it presents.';

	/// en: ' - The **X6100** speaks CI-V on its **DEV** port — the second of the two serial ports it presents, and the one the picker points at.'
	String get x6100PortNote => '\n- The **X6100** speaks CI-V on its **DEV** port — the second of the two serial ports it presents, and the one the picker points at.';

	/// en: 'If the app cannot connect'
	String get rigctldTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib's backend talks to the radio and supports hundreds of models. - **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio's model number with `rigctl -l`. - **From another machine**, start it with `-T 0.0.0.0`: by default rigctld only accepts connections from the machine it runs on. - **Port** is 4532 unless you started the daemon with `-t`. - Once connected, a missing frequency usually means the daemon itself cannot reach the radio. Test it with `rigctl -m 2 f` on the daemon's machine.'
	String get rigctldTroubleshooting => 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib\'s backend talks to the radio and supports hundreds of models.\n\n- **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio\'s model number with `rigctl -l`.\n- **From another machine**, start it with `-T 0.0.0.0`: by default rigctld only accepts connections from the machine it runs on.\n- **Port** is 4532 unless you started the daemon with `-t`.\n- Once connected, a missing frequency usually means the daemon itself cannot reach the radio. Test it with `rigctl -m 2 f` on the daemon\'s machine.';

	/// en: 'If the app cannot connect'
	String get flrigTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models. - **flrig must already be running**, with its transceiver configured and connected. - **Port** is 12345 unless you changed it in flrig's configuration (Config → Setup → Server). - **From another machine**, make sure flrig's server is reachable. It listens on all interfaces, but your firewall may not agree. - Once connected, a missing frequency usually means flrig itself cannot reach the radio. Check that flrig's display is following the dial.'
	String get flrigTroubleshooting => 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **Port** is 12345 unless you changed it in flrig\'s configuration (Config → Setup → Server).\n- **From another machine**, make sure flrig\'s server is reachable. It listens on all interfaces, but your firewall may not agree.\n- Once connected, a missing frequency usually means flrig itself cannot reach the radio. Check that flrig\'s display is following the dial.';

	/// en: 'If the app cannot connect'
	String get hrdTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to **Ham Radio Deluxe's Rig Control, running on your computer**, not to the radio directly — HRD talks to the radio. - **Rig Control must already be running** and connected to the radio. - **Its IP server must be enabled.** Rig Control only talks to other programs through it. - **Port** is 7809 unless you changed it in the IP server's settings. - **From another machine**, make sure your firewall lets the connection through. This entry was written from published descriptions of HRD's protocol and has not been run against HRD. If it half-works, that is worth reporting.'
	String get hrdTroubleshooting => 'This connects to **Ham Radio Deluxe\'s Rig Control, running on your computer**, not to the radio directly — HRD talks to the radio.\n\n- **Rig Control must already be running** and connected to the radio.\n- **Its IP server must be enabled.** Rig Control only talks to other programs through it.\n- **Port** is 7809 unless you changed it in the IP server\'s settings.\n- **From another machine**, make sure your firewall lets the connection through.\n\nThis entry was written from published descriptions of HRD\'s protocol and has not been run against HRD. If it half-works, that is worth reporting.';

	/// en: 'If the app cannot connect'
	String get n3fjpTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to **an N3FJP logging program running on your computer**, not to the radio directly — N3FJP talks to the radio. - **The program's API must be on**: Settings → Application Program Interface, check **TCP API Enabled**. - **Port** is 1100 unless you changed it there. - **N3FJP must have a radio interface set up** to follow or tune the radio. Without one, it reports only what is typed into its entry window. - N3FJP reports band, mode and frequency only: no power, no transmit state. This entry was written from N3FJP's published API and has not been run against N3FJP. If it half-works, that is worth reporting.'
	String get n3fjpTroubleshooting => 'This connects to **an N3FJP logging program running on your computer**, not to the radio directly — N3FJP talks to the radio.\n\n- **The program\'s API must be on**: Settings → Application Program Interface, check **TCP API Enabled**.\n- **Port** is 1100 unless you changed it there.\n- **N3FJP must have a radio interface set up** to follow or tune the radio. Without one, it reports only what is typed into its entry window.\n- N3FJP reports band, mode and frequency only: no power, no transmit state.\n\nThis entry was written from N3FJP\'s published API and has not been run against N3FJP. If it half-works, that is worth reporting.';

	/// en: 'If the app cannot connect'
	String get commanderTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to **DXLab Commander, running on your computer**, not to the radio directly — Commander talks to the radio. - **Commander must already be running** and connected to the radio. - **Its network service must be on**: the **Net Serv** button in the Radio panel of Commander's Configuration window. - **Port** is 52002, the third port of the block starting at Net Serv's **Base Port** (52000 unless you changed it). - **From another machine**, make sure your firewall lets the connection through. This entry was written from Commander's published TCP messages and has not been run against Commander. If it half-works, that is worth reporting.'
	String get commanderTroubleshooting => 'This connects to **DXLab Commander, running on your computer**, not to the radio directly — Commander talks to the radio.\n\n- **Commander must already be running** and connected to the radio.\n- **Its network service must be on**: the **Net Serv** button in the Radio panel of Commander\'s Configuration window.\n- **Port** is 52002, the third port of the block starting at Net Serv\'s **Base Port** (52000 unless you changed it).\n- **From another machine**, make sure your firewall lets the connection through.\n\nThis entry was written from Commander\'s published TCP messages and has not been run against Commander. If it half-works, that is worth reporting.';

	/// en: 'If the radio never responds'
	String get ic705TroubleshootingTitle => 'If the radio never responds';

	/// en: 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it. - **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does. - **Check the radio's network settings.** WLAN must be on, the radio must be on the same network, and its remote-control (Network) function must be enabled. - **The ports must match** the radio's Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off. - **Power-cycle the radio's WLAN** if it stays stuck. That reliably clears a session stuck on the radio. A **wrong password is refused explicitly**, not met with silence. If you got here rather than a "rejected" message, the password is not the problem.'
	String get ic705Troubleshooting => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings.** WLAN must be on, the radio must be on the same network, and its remote-control (Network) function must be enabled.\n- **The ports must match** the radio\'s Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off.\n- **Power-cycle the radio\'s WLAN** if it stays stuck. That reliably clears a session stuck on the radio.\n\nA **wrong password is refused explicitly**, not met with silence. If you got here rather than a "rejected" message, the password is not the problem.';

	/// en: 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it. - **Close any other client.** wfview, RS-BA1 or Icom's Remote Utility connected to the same radio holds that one session, and the login here is simply ignored while it does. - **Check the radio's network settings.** Its LAN port must be connected to the same network as this device, its **Network Control** must be on, and the username and password must be set up as a network user on the radio. - **The ports must match** the radio's Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off. - **If it connects but never answers**, the CI-V address here must match the radio's CI-V ADDRESS menu. This entry prefills the address the model ships with. - **Turn the radio off and on** if it stays stuck.'
	String get icomLanTroubleshooting => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview, RS-BA1 or Icom\'s Remote Utility connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings.** Its LAN port must be connected to the same network as this device, its **Network Control** must be on, and the username and password must be set up as a network user on the radio.\n- **The ports must match** the radio\'s Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off.\n- **If it connects but never answers**, the CI-V address here must match the radio\'s CI-V ADDRESS menu. This entry prefills the address the model ships with.\n- **Turn the radio off and on** if it stays stuck.';

	/// en: 'Not responding'
	String get statusStale => 'Not responding';

	/// en: 'Not connected'
	String get statusDisconnected => 'Not connected';

	/// en: 'Connecting…'
	String get statusConnecting => 'Connecting…';

	/// en: 'Disconnecting…'
	String get statusDisconnecting => 'Disconnecting…';

	/// en: 'Connection failed'
	String get statusError => 'Connection failed';

	/// en: 'Current radio settings'
	String get currentRadioSettings => 'Current radio settings';

	/// en: 'Not supported by this radio'
	String get notSupportedByThisRadio => 'Not supported by this radio';

	/// en: 'Keyer'
	String get keyerRowLabel => 'Keyer';

	/// en: 'CW'
	String get cwMessagesButton => 'CW';

	/// en: 'Phone'
	String get voiceMessagesButton => 'Phone';

	/// en: 'Voice keyer: $count memories in the radio'
	String voiceKeyerAvailable({required Object count}) => 'Voice keyer: ${count} memories in the radio';

	/// en: 'Bands'
	String get antennaBands => 'Bands';

	/// en: 'Antenna type'
	String get antennaType => 'Antenna type';

	/// en: 'Choose an antenna type'
	String get antennaTypeRequired => 'Choose an antenna type';

	late final Translations$settings$station$antennaTypes$en antennaTypes = Translations$settings$station$antennaTypes$en.internal(_root);

	/// en: 'Key type'
	String get keyType => 'Key type';

	/// en: 'Choose a key type'
	String get keyTypeRequired => 'Choose a key type';

	late final Translations$settings$station$keyTypes$en keyTypes = Translations$settings$station$keyTypes$en.internal(_root);

	/// en: 'Software Intermediaries'
	String get softwareIntermediaries => 'Software Intermediaries';

	/// en: 'Other Brands'
	String get otherBrands => 'Other Brands';

	/// en: 'Other Equipment (Antennas, Keys, etc)'
	String get otherEquipment => 'Other Equipment (Antennas, Keys, etc)';

	/// en: 'New Antenna'
	String get newAntenna => 'New Antenna';

	/// en: 'New Key'
	String get newKey => 'New Key';

	/// en: 'WinKeyer (K1EL or compatible)'
	String get newKeyer => 'WinKeyer (K1EL or compatible)';

	/// en: 'CAT Keyer in $radio'
	String keyViaRadio({required Object radio}) => 'CAT Keyer in ${radio}';

	/// en: 'Key on $device'
	String keyOnDevice({required Object device}) => 'Key on ${device}';

	/// en: 'Keyer area'
	String get cwKeyerArea => 'Keyer area';

	/// en: 'Track Station Info for each QSO'
	String get trackStationInfo => 'Track Station Info for each QSO';

	/// en: 'Include in ADIF exports'
	String get includeStationInfoInAdif => 'Include in ADIF exports';

	/// en: 'What to track?'
	String get whatToTrack => 'What to track?';

	/// en: 'Transceiver'
	String get trackFieldRig => 'Transceiver';

	/// en: 'Power'
	String get trackFieldPower => 'Power';

	/// en: 'Watts'
	String get watts => 'Watts';

	/// en: 'Antenna'
	String get trackFieldAntenna => 'Antenna';

	/// en: 'CW Key'
	String get trackFieldKey => 'CW Key';

	/// en: 'Connect delay (ms)'
	String get placeholderConnectDelay => 'Connect delay (ms)';

	/// en: 'How long the simulated handshake takes. Blank or 0 connects instantly.'
	String get placeholderConnectDelayDescription => 'How long the simulated handshake takes. Blank or 0 connects instantly.';

	/// en: 'Drop after (seconds)'
	String get placeholderDropAfter => 'Drop after (seconds)';

	/// en: 'Close the connection on its own, to exercise the reconnect path. Blank or 0 never drops.'
	String get placeholderDropAfterDescription => 'Close the connection on its own, to exercise the reconnect path. Blank or 0 never drops.';

	/// en: 'Always fail to connect'
	String get placeholderFailConnect => 'Always fail to connect';

	/// en: 'The placeholder radio was told to refuse this connection'
	String get placeholderConnectFailure => 'The placeholder radio was told to refuse this connection';

	/// en: 'Frequency (kHz)'
	String get placeholderFreq => 'Frequency (kHz)';

	/// en: 'Where the placeholder radio starts. It reports back whatever the app tunes it to afterwards.'
	String get placeholderFreqDescription => 'Where the placeholder radio starts. It reports back whatever the app tunes it to afterwards.';

	/// en: 'Mode'
	String get placeholderMode => 'Mode';

	/// en: 'The mode the placeholder radio starts on, e.g. USB, CW, FT8.'
	String get placeholderModeDescription => 'The mode the placeholder radio starts on, e.g. USB, CW, FT8.';

	/// en: 'Power (watts)'
	String get placeholderPower => 'Power (watts)';

	/// en: 'Use this radio to keep track of which rig you're using for logging purposes'
	String get placeholderPurpose => 'Use this radio to keep track of which rig you\'re using for logging purposes';

	/// en: 'Reply delay (ms)'
	String get placeholderReplyDelay => 'Reply delay (ms)';

	/// en: 'How long the placeholder radio takes to report a change back. Blank or 0 replies at once.'
	String get placeholderReplyDelayDescription => 'How long the placeholder radio takes to report a change back. Blank or 0 replies at once.';

	/// en: 'CAT CW keyer'
	String get cwKeyerField => 'CAT CW keyer';

	/// en: 'Whether this radio keys CW from text over CAT. Off for a rig the app does not know.'
	String get cwKeyerFieldDescription => 'Whether this radio keys CW from text over CAT. Off for a rig the app does not know.';

	/// en: 'Voice memories'
	String get voiceMemories => 'Voice memories';

	/// en: 'How many voice memories the radio plays over CAT. 0 for none.'
	String get voiceMemoriesDescription => 'How many voice memories the radio plays over CAT. 0 for none.';

	/// en: 'A whole number, 0 or more'
	String get voiceMemoriesInvalid => 'A whole number, 0 or more';

	/// en: 'Capture meter readings'
	String get yaesuMeterCapture => 'Capture meter readings';

	/// en: 'Reads the radio's power-output meter and high-SWR flag while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.'
	String get yaesuBinaryMeterCaptureDescription => 'Reads the radio\'s power-output meter and high-SWR flag while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.';

	/// en: 'Reads the radio's PO, SWR and ALC meters while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.'
	String get yaesuMeterCaptureDescription => 'Reads the radio\'s PO, SWR and ALC meters while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.';

	/// en: 'Meter reading interval (ms)'
	String get telemetryInterval => 'Meter reading interval (ms)';

	/// en: 'How often to read the radio's meters while it is transmitting. Leave blank for the fastest this connection can handle, up to 200 ms.'
	String get telemetryIntervalDescription => 'How often to read the radio\'s meters while it is transmitting. Leave blank for the fastest this connection can handle, up to 200 ms.';

	/// en: 'A whole number of milliseconds, ${min} to ${max}'
	String telemetryIntervalInvalid({required Object min, required Object max}) => 'A whole number of milliseconds, ${min} to ${max}';

	/// en: 'Idle polling interval (ms)'
	String get pollInterval => 'Idle polling interval (ms)';

	/// en: 'How often to ask the radio for its frequency and mode while neither is changing. Leave blank for ${fallback} ms.'
	String pollIntervalDescription({required Object fallback}) => 'How often to ask the radio for its frequency and mode while neither is changing. Leave blank for ${fallback} ms.';

	/// en: 'A whole number of milliseconds, ${min} to ${max}'
	String pollIntervalInvalid({required Object min, required Object max}) => 'A whole number of milliseconds, ${min} to ${max}';

	/// en: 'Advanced Settings'
	String get advancedSettings => 'Advanced Settings';

	/// en: 'SWR reading'
	String get placeholderSwr => 'SWR reading';

	/// en: 'What this radio reports on its SWR meter while transmitting. Above 1.8 the panel warns.'
	String get placeholderSwrDescription => 'What this radio reports on its SWR meter while transmitting. Above 1.8 the panel warns.';

	/// en: 'A number, 1 or more'
	String get placeholderSwrInvalid => 'A number, 1 or more';

	/// en: 'None'
	String get keyerNone => 'None';

	/// en: 'CW keying dialect'
	String get cwDialect => 'CW keying dialect';

	/// en: 'Which shape of the KY command this radio takes. None means no CW keying over CAT.'
	String get cwDialectDescription => 'Which shape of the KY command this radio takes. None means no CW keying over CAT.';

	/// en: 'Kenwood (KY, padded to 24)'
	String get cwDialectKenwood => 'Kenwood (KY, padded to 24)';

	/// en: 'Elecraft (KY text)'
	String get cwDialectElecraft => 'Elecraft (KY text)';

	/// en: 'Voice keyer dialect'
	String get voiceDialect => 'Voice keyer dialect';

	/// en: 'How this radio plays its voice memories over CAT. None means no voice memories over CAT. With a dialect and no count, the dialect's default count applies.'
	String get voiceDialectDescription => 'How this radio plays its voice memories over CAT. None means no voice memories over CAT. With a dialect and no count, the dialect\'s default count applies.';

	/// en: 'Kenwood (PB, TS-590 style)'
	String get voiceDialectPb => 'Kenwood (PB, TS-590 style)';

	/// en: 'Elecraft K4 (PB and DA)'
	String get voiceDialectK4 => 'Elecraft K4 (PB and DA)';

	/// en: 'Elecraft KX2/KX3 (switch taps)'
	String get voiceDialectKx => 'Elecraft KX2/KX3 (switch taps)';

	/// en: 'Simulated'
	String get placeholderDiagnostic => 'Simulated';

	/// en: 'Must be a whole number, 0 or more'
	String get placeholderWholeNumberInvalid => 'Must be a whole number, 0 or more';

	/// en: 'Must be a frequency in kHz, greater than zero'
	String get placeholderFreqInvalid => 'Must be a frequency in kHz, greater than zero';

	/// en: 'Must be a mode name, e.g. USB, CW, FT8'
	String get placeholderModeInvalid => 'Must be a mode name, e.g. USB, CW, FT8';

	/// en: 'Layout'
	String get switchLayout => 'Layout';

	/// en: 'Which side of the switch your radios are plugged into.'
	String get switchLayoutDescription => 'Which side of the switch your radios are plugged into.';

	/// en: 'Choose how the switch is wired'
	String get switchLayoutRequired => 'Choose how the switch is wired';

	/// en: 'The switch refused "$command" (error $code)'
	String switchCommandRefused({required Object command, required Object code}) => 'The switch refused "${command}" (error ${code})';

	/// en: 'That port is transmitting — antenna not changed'
	String get switchBusyTransmitting => 'That port is transmitting — antenna not changed';

	/// en: 'None'
	String get switchNoAntenna => 'None';

	/// en: 'Antenna on port $port'
	String switchAntennaFor({required Object port}) => 'Antenna on port ${port}';

	/// en: 'Which of your antennas is connected to this port on the switch.'
	String get switchAntennaForDescription => 'Which of your antennas is connected to this port on the switch.';

	/// en: '$antennas Antennas, $radios Radios'
	String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} Antennas, ${radios} Radios';

	/// en: '$antennas Antennas, 1 Radio'
	String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} Antennas, 1 Radio';

	/// en: '1 Antenna, $radios Radios'
	String switchLayoutSidesOneAntenna({required Object radios}) => '1 Antenna, ${radios} Radios';

	/// en: 'Common'
	String get switchCommonPort => 'Common';

	/// en: 'Device address'
	String get dcnAddress => 'Device address';

	/// en: 'The address set on the module's DIP switches. A coax relay module leaves the factory at 2.'
	String get dcnAddressDescription => 'The address set on the module\'s DIP switches. A coax relay module leaves the factory at 2.';

	/// en: 'Must be a device address from 1 to 99'
	String get dcnAddressRequired => 'Must be a device address from 1 to 99';

	/// en: 'Port $port'
	String switchPortLabel({required Object port}) => 'Port ${port}';

	/// en: 'follows band data'
	String get switchPortAutoHint => 'follows band data';

	/// en: 'transmitting — cannot change now'
	String get switchPortTransmittingHint => 'transmitting — cannot change now';

	/// en: 'Current State'
	String get switchCurrentStateHeader => 'Current State';

	/// en: 'Which antenna each radio port is on right now. Changes take effect immediately.'
	String get switchCurrentStateDescription => 'Which antenna each radio port is on right now. Changes take effect immediately.';

	/// en: 'Wiring'
	String get switchWiringHeader => 'Wiring';

	/// en: 'transmit inhibited'
	String get switchPortInhibitedHint => 'transmit inhibited';

	/// en: 'This radio's saved settings could not be read. Open its settings and enter them again, or remove it and add it back.'
	String get configUnreadable => 'This radio\'s saved settings could not be read. Open its settings and enter them again, or remove it and add it back.';

	/// en: 'HaLo stopped responding the last time it connected to this radio, so it did not connect on its own this time. Press Connect to try again.'
	String get autoConnectHeld => 'HaLo stopped responding the last time it connected to this radio, so it did not connect on its own this time. Press Connect to try again.';
}

// Path: settings.offlineData
class Translations$settings$offlineData$en {
	Translations$settings$offlineData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Offline Data'
	String get title => 'Offline Data';

	/// en: 'No data files'
	String get noFiles => 'No data files';

	/// en: 'Enable activity or lookup extensions to download their offline data here.'
	String get noFilesDescription => 'Enable activity or lookup extensions to download their offline data here.';

	/// en: 'Refresh'
	String get refresh => 'Refresh';

	/// en: 'Refreshing…'
	String get refreshing => 'Refreshing…';

	/// en: 'Update All'
	String get updateAll => 'Update All';

	/// en: 'Updating all data files…'
	String get updatingAll => 'Updating all data files…';

	/// en: 'Never downloaded'
	String get neverDownloaded => 'Never downloaded';

	/// en: 'Updated just now'
	String get updatedJustNow => 'Updated just now';

	/// en: 'Updated ${days}d ago'
	String updatedDaysAgo({required Object days}) => 'Updated ${days}d ago';

	/// en: 'Updated ${days}d ${hours}h ago'
	String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Updated ${days}d ${hours}h ago';

	/// en: 'Updated ${hours}h ago'
	String updatedHoursAgo({required Object hours}) => 'Updated ${hours}h ago';

	/// en: 'Updated ${hours}h ${minutes}m ago'
	String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Updated ${hours}h ${minutes}m ago';

	/// en: 'Updated ${minutes}m ago'
	String updatedMinutesAgo({required Object minutes}) => 'Updated ${minutes}m ago';

	/// en: 'The last download had only ${imported} of ${existing} records and was not used. Refresh to accept it.'
	String lastDownloadRefused({required Object imported, required Object existing}) => 'The last download had only ${imported} of ${existing} records and was not used. Refresh to accept it.';

	/// en: 'Extensions'
	String get extensionsSection => 'Extensions';
}

// Path: settings.profiles
class Translations$settings$profiles$en {
	Translations$settings$profiles$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Not set'
	String get notSet => 'Not set';

	/// en: 'Personal Info'
	String get personalInfo => 'Personal Info';

	/// en: 'This might be included in generated logs when relevant for submissions'
	String get personalInfoNote => 'This might be included in generated logs when relevant for submissions';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Email'
	String get email => 'Email';

	/// en: 'Club'
	String get club => 'Club';

	/// en: 'ARRL Section'
	String get arrlSection => 'ARRL Section';

	/// en: 'RAC Section'
	String get racSection => 'RAC Section';

	/// en: 'Section'
	String get section => 'Section';
}

// Path: settings.search
class Translations$settings$search$en {
	Translations$settings$search$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Search preferences'
	String get hint => 'Search preferences';
}

// Path: settings.developer
class Translations$settings$developer$en {
	Translations$settings$developer$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Enable developer warnings, debug logs, and tools.'
	String get developerModeDescription => 'Enable developer warnings, debug logs, and tools.';

	/// en: 'Experiments'
	String get experiments => 'Experiments';

	/// en: 'Show idle metrics'
	String get showIdleMetrics => 'Show idle metrics';

	/// en: 'Show in the status bar how idle the extension engine has been over the last second. Tap it for the 10- and 60-second averages.'
	String get showIdleMetricsDescription => 'Show in the status bar how idle the extension engine has been over the last second. Tap it for the 10- and 60-second averages.';

	/// en: '${percent}% idle'
	String idleMetricsReadout({required Object percent}) => '${percent}% idle';

	/// en: 'Idle avg:'
	String get idleMetricsAverages => 'Idle avg:';

	/// en: '${seconds}s ${percent}%'
	String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';

	/// en: '(one) {${count} enabled} (other) {${count} enabled}'
	String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} enabled',
		other: '${count} enabled',
	);

	/// en: 'Code Push Track'
	String get patchTrack => 'Code Push Track';

	/// en: 'Which over-the-air code push ring this device follows. More adventurous rings get fixes earlier, less tested. Code pushes apply on the next restart.'
	String get patchTrackDescription => 'Which over-the-air code push ring this device follows. More adventurous rings get fixes earlier, less tested. Code pushes apply on the next restart.';

	/// en: 'Stable'
	String get trackStable => 'Stable';

	/// en: 'Unstable'
	String get trackUnstable => 'Unstable';

	/// en: 'Bleeding'
	String get trackBleeding => 'Bleeding';

	/// en: 'Checking "${track}" for a code push…'
	String checkingTrack({required Object track}) => 'Checking "${track}" for a code push…';

	/// en: 'Code push downloaded — restart the app to apply it.'
	String get patchDownloaded => 'Code push downloaded — restart the app to apply it.';

	/// en: 'No new code push on "${track}".'
	String noNewPatch({required Object track}) => 'No new code push on "${track}".';

	/// en: 'No code push installed — running the release binary.'
	String get noPatchInstalled => 'No code push installed — running the release binary.';

	/// en: 'Running code push #${patch}.'
	String runningPatch({required Object patch}) => 'Running code push #${patch}.';

	/// en: 'Deep links'
	String get deepLinks => 'Deep links';

	/// en: 'Register URL schemes'
	String get registerUrlSchemes => 'Register URL schemes';

	/// en: 'Let com.ham2k:// links open this copy of the app'
	String get registerUrlSchemesDescription => 'Let com.ham2k:// links open this copy of the app';

	/// en: 'This copy now opens com.ham2k:// links'
	String get registerUrlSchemesDone => 'This copy now opens com.ham2k:// links';

	/// en: 'Could not register: $error'
	String registerUrlSchemesFailed({required Object error}) => 'Could not register: ${error}';

	/// en: 'System Information'
	String get systemInformation => 'System Information';

	/// en: 'App Version'
	String get appVersion => 'App Version';

	/// en: 'Data Folder'
	String get dataFolder => 'Data Folder';

	/// en: '(loading…)'
	String get loading => '(loading…)';

	/// en: 'Could not load this settings panel.'
	String get panelLoadFailed => 'Could not load this settings panel.';

	/// en: 'Extension Dev Server'
	String get extDevServer => 'Extension Dev Server';

	/// en: 'Extension Settings'
	String get extensionSettings => 'Extension Settings';

	/// en: 'Load extensions from a dev server on your network instead of the ones built into the app, and reload them as you save.'
	String get extDevServerDescription => 'Load extensions from a dev server on your network instead of the ones built into the app, and reload them as you save.';

	/// en: 'Server address'
	String get extDevServerAddress => 'Server address';

	/// en: '192.168.1.20:8787'
	String get extDevServerHint => '192.168.1.20:8787';

	/// en: 'Connect'
	String get extDevServerConnect => 'Connect';

	/// en: 'Disconnect'
	String get extDevServerDisconnect => 'Disconnect';

	/// en: 'Connecting…'
	String get extDevServerConnecting => 'Connecting…';

	/// en: '(one) {Serving ${count} extension: ${keys}} (other) {Serving ${count} extensions: ${keys}}'
	String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Serving ${count} extension: ${keys}',
		other: 'Serving ${count} extensions: ${keys}',
	);

	/// en: 'Not connected'
	String get extDevServerDisconnected => 'Not connected';

	/// en: 'Reconnect at launch'
	String get extDevServerReconnect => 'Reconnect at launch';

	/// en: 'Last reload: ${key} at ${time}'
	String extDevServerLastReload({required Object key, required Object time}) => 'Last reload: ${key} at ${time}';

	/// en: '(one) {${count} extension failing to build} (other) {${count} extensions failing to build}'
	String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} extension failing to build',
		other: '${count} extensions failing to build',
	);

	/// en: 'Extension Catalog'
	String get catalog => 'Extension Catalog';

	/// en: 'Read the catalog from another server — a local one while working on the catalog itself. Empty means catalog.ham2k.net.'
	String get catalogDescription => 'Read the catalog from another server — a local one while working on the catalog itself. Empty means catalog.ham2k.net.';

	/// en: 'Catalog address'
	String get catalogAddress => 'Catalog address';

	/// en: 'http://localhost:8787'
	String get catalogHint => 'http://localhost:8787';

	/// en: 'Catalog Search Tracks'
	String get catalogSearchTracks => 'Catalog Search Tracks';

	/// en: 'Only Stable'
	String get catalogSearchStable => 'Only Stable';

	/// en: 'Unstable or better'
	String get catalogSearchUnstable => 'Unstable or better';

	/// en: 'Bleeding or better'
	String get catalogSearchBleeding => 'Bleeding or better';
}

// Path: settings.about
class Translations$settings$about$en {
	Translations$settings$about$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Notices & Messages'
	String get notices => 'Notices & Messages';

	/// en: 'Announcements and status messages'
	String get noticesDescription => 'Announcements and status messages';

	/// en: 'Release Notes'
	String get releaseNotes => 'Release Notes';

	/// en: 'Copied version details to clipboard'
	String get copiedVersion => 'Copied version details to clipboard';
}

// Path: settings.panels
class Translations$settings$panels$en {
	Translations$settings$panels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Application Preferences'
	String get settings => 'Application Preferences';

	/// en: 'Make the app work how you want it'
	String get settingsDescription => 'Make the app work how you want it';

	/// en: 'Common Preferences'
	String get commonSettings => 'Common Preferences';

	/// en: 'Back up and sync your logs across devices'
	String get syncDescription => 'Back up and sync your logs across devices';

	/// en: 'Service credentials, offline data, and more'
	String get accountsDescription => 'Service credentials, offline data, and more';

	/// en: 'Extensions & Features'
	String get extensions => 'Extensions & Features';

	/// en: 'Activities, Contests, Dashboard Panels and more features'
	String get extensionsDescription => 'Activities, Contests, Dashboard Panels and more features';

	/// en: 'Operator callsign and station profile'
	String get profilesDescription => 'Operator callsign and station profile';

	/// en: 'Station Profiles'
	String get stationProfiles => 'Station Profiles';

	/// en: 'Developer Settings'
	String get developerSettings => 'Developer Settings';

	/// en: 'Debugging and development tools'
	String get developerSettingsDescription => 'Debugging and development tools';

	/// en: 'About'
	String get about => 'About';

	/// en: 'Version, credits, and legal information'
	String get aboutDescription => 'Version, credits, and legal information';

	/// en: 'Some settings are unavailable'
	String get unavailableTitle => 'Some settings are unavailable';

	/// en: 'The extension runtime failed to start, so extension-contributed settings are missing.'
	String get unavailableText => 'The extension runtime failed to start, so extension-contributed settings are missing.';

	/// en: 'Station Configuration'
	String get station => 'Station Configuration';

	/// en: 'CAT control and more options'
	String get stationDescription => 'CAT control and more options';

	/// en: 'Peer Devices'
	String get peers => 'Peer Devices';

	/// en: 'Connect to other devices nearby'
	String get peersDescription => 'Connect to other devices nearby';
}

// Path: settings.numberFormatOpts
class Translations$settings$numberFormatOpts$en {
	Translations$settings$numberFormatOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Follow system settings'
	String get locale => 'Follow system settings';

	/// en: 'Always use period for decimals'
	String get period => 'Always use period for decimals';

	/// en: 'Always use comma for decimals'
	String get comma => 'Always use comma for decimals';
}

// Path: settings.numberFormatDescription
class Translations$settings$numberFormatDescription$en {
	Translations$settings$numberFormatDescription$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System settings (using ${separator} for decimals)'
	String locale({required Object separator}) => 'System settings (using ${separator} for decimals)';

	/// en: 'Always using period for decimals'
	String get period => 'Always using period for decimals';

	/// en: 'Always using comma for decimals'
	String get comma => 'Always using comma for decimals';
}

// Path: settings.numberFormatSeparators
class Translations$settings$numberFormatSeparators$en {
	Translations$settings$numberFormatSeparators$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'comma'
	String get comma => 'comma';

	/// en: 'period'
	String get period => 'period';
}

// Path: settings.gridPrecisionOpts
class Translations$settings$gridPrecisionOpts$en {
	Translations$settings$gridPrecisionOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '6 digits (FN31pr)'
	String get six => '6 digits (FN31pr)';

	/// en: '8 digits (FN31pr55)'
	String get eight => '8 digits (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class Translations$settings$gridPrecisionDescription$en {
	Translations$settings$gridPrecisionDescription$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '6 digits'
	String get six => '6 digits';

	/// en: '8 digits'
	String get eight => '8 digits';
}

// Path: keyboardShortcuts.command
class Translations$keyboardShortcuts$command$en {
	Translations$keyboardShortcuts$command$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Open the command dialog'
	String get commandDialog => 'Open the command dialog';

	/// en: 'Switch between light and dark'
	String get toggleTheme => 'Switch between light and dark';

	/// en: 'Switch between English and Spanish'
	String get toggleLanguage => 'Switch between English and Spanish';

	/// en: 'Larger text'
	String get fontScaleUp => 'Larger text';

	/// en: 'Smaller text'
	String get fontScaleDown => 'Smaller text';

	/// en: 'Normal text size'
	String get fontScaleReset => 'Normal text size';

	/// en: 'Roomier layout'
	String get densityLooser => 'Roomier layout';

	/// en: 'Denser layout'
	String get densityDenser => 'Denser layout';

	/// en: 'Automatic layout density'
	String get densityAuto => 'Automatic layout density';

	/// en: 'Find in the log'
	String get find => 'Find in the log';

	/// en: 'Send message ${n}'
	String keyerMessage({required Object n}) => 'Send message ${n}';

	/// en: 'Keyboard mode on or off'
	String get keyboardMode => 'Keyboard mode on or off';

	/// en: 'Push to talk'
	String get ptt => 'Push to talk';

	/// en: 'Clear the contact being logged'
	String get wipe => 'Clear the contact being logged';
}

// Path: keyboardShortcuts.fixed
class Translations$keyboardShortcuts$fixed$en {
	Translations$keyboardShortcuts$fixed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Typing callsigns'
	String get callsign => 'Typing callsigns';

	/// en: 'Stop sending, back out one step, or close'
	String get escape => 'Stop sending, back out one step, or close';

	/// en: 'Log the contact'
	String get enter => 'Log the contact';

	/// en: 'Next field'
	String get space => 'Next field';

	/// en: 'Next or previous field'
	String get tab => 'Next or previous field';

	/// en: 'Move between fields, controls and the log'
	String get arrows => 'Move between fields, controls and the log';

	/// en: 'Page through the log, or go to its ends'
	String get walk => 'Page through the log, or go to its ends';

	/// en: 'Take back a wipe or a delete'
	String get undo => 'Take back a wipe or a delete';
}

// Path: keyboardShortcuts.editor
class Translations$keyboardShortcuts$editor$en {
	Translations$keyboardShortcuts$editor$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Add Shortcut'
	String get addShortcut => 'Add Shortcut';

	/// en: 'Press the keys for the shortcut…'
	String get listening => 'Press the keys for the shortcut…';

	/// en: 'Esc stops listening'
	String get listeningHint => 'Esc stops listening';

	/// en: 'Add'
	String get add => 'Add';

	/// en: '${keys} belongs to the logging fields or a dialog, and can’t be changed.'
	String refusedFixed({required Object keys}) => '${keys} belongs to the logging fields or a dialog, and can’t be changed.';

	/// en: '${keys} is how callsigns are typed. Hold Cmd, Ctrl or Alt with it.'
	String refusedCallsign({required Object keys}) => '${keys} is how callsigns are typed. Hold Cmd, Ctrl or Alt with it.';

	/// en: 'The system may take ${keys} before the app sees it.'
	String reserved({required Object keys}) => 'The system may take ${keys} before the app sees it.';

	/// en: '${keys} is already one of this command’s keys.'
	String already({required Object keys}) => '${keys} is already one of this command’s keys.';

	/// en: 'Take ${keys} from “${command}”'
	String takeIt({required Object keys, required Object command}) => 'Take ${keys} from “${command}”';

	/// en: 'Reset to Default'
	String get resetDefault => 'Reset to Default';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Command'
	String get commandLabel => 'Command';

	/// en: 'Enter any valid command, or multiple commands separated by ";"'
	String get commandHint => 'Enter any valid command, or multiple commands separated by ";"';

	/// en: 'Remove Command'
	String get removeCommand => 'Remove Command';

	/// en: 'No command reads “${text}”'
	String commandUnknown({required Object text}) => 'No command reads “${text}”';

	/// en: 'No key yet'
	String get noShortcuts => 'No key yet';
}

// Path: keyboardShortcuts.file
class Translations$keyboardShortcuts$file$en {
	Translations$keyboardShortcuts$file$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shortcuts saved to ${location}'
	String exported({required Object location}) => 'Shortcuts saved to ${location}';

	/// en: 'Couldn’t export the shortcuts: ${error}'
	String exportFailed({required Object error}) => 'Couldn’t export the shortcuts: ${error}';

	/// en: 'Couldn’t open the file: ${error}'
	String importPickerFailed({required Object error}) => 'Couldn’t open the file: ${error}';

	/// en: '${filename} isn’t a shortcuts file this app can read: ${problem}'
	String importUnreadable({required Object filename, required Object problem}) => '${filename} isn’t a shortcuts file this app can read: ${problem}';

	/// en: 'the text isn’t valid YAML (line ${line})'
	String problemNotYaml({required Object line}) => 'the text isn’t valid YAML (line ${line})';

	/// en: 'it isn’t a Ham2K keyboard shortcuts file'
	String get problemNotKeysFile => 'it isn’t a Ham2K keyboard shortcuts file';

	/// en: 'it was written by a newer version of the app'
	String get problemNewerVersion => 'it was written by a newer version of the app';

	/// en: 'part of it doesn’t follow the shortcuts format'
	String get problemMalformed => 'part of it doesn’t follow the shortcuts format';

	/// en: 'it is too large'
	String get problemTooLarge => 'it is too large';

	/// en: 'Import Shortcuts'
	String get importTitle => 'Import Shortcuts';

	/// en: 'Written on ${platform}.'
	String writtenOn({required Object platform}) => 'Written on ${platform}.';

	/// en: 'The file doesn’t say which keyboard it was written on.'
	String get writtenOnUnknown => 'The file doesn’t say which keyboard it was written on.';

	/// en: 'What should each of these keys be on this keyboard?'
	String get translate => 'What should each of these keys be on this keyboard?';

	/// en: 'Leave those shortcuts out'
	String get leaveOut => 'Leave those shortcuts out';

	/// en: 'Replace this device’s config'
	String get replace => 'Replace this device’s config';

	/// en: 'Every shortcut not in the file goes back to its default.'
	String get replaceHint => 'Every shortcut not in the file goes back to its default.';

	/// en: 'Add to this device’s config'
	String get merge => 'Add to this device’s config';

	/// en: 'The file’s shortcuts replace this device’s for the same commands, and the rest stay.'
	String get mergeHint => 'The file’s shortcuts replace this device’s for the same commands, and the rest stay.';

	/// en: 'Not known in this version, so left out: ${commands}'
	String unknown({required Object commands}) => 'Not known in this version, so left out: ${commands}';

	/// en: 'Not shortcuts, so left out: ${chords}'
	String unreadableChords({required Object chords}) => 'Not shortcuts, so left out: ${chords}';

	/// en: 'Keys the app keeps for itself, so left out: ${chords}'
	String refusedChords({required Object chords}) => 'Keys the app keeps for itself, so left out: ${chords}';

	/// en: 'Bound to more than one command after the import: ${keys}'
	String conflicts({required Object keys}) => 'Bound to more than one command after the import: ${keys}';

	/// en: 'Import'
	String get importAction => 'Import';

	/// en: 'Shortcuts imported'
	String get imported => 'Shortcuts imported';
}

// Path: keyboardShortcuts.modifier
class Translations$keyboardShortcuts$modifier$en {
	Translations$keyboardShortcuts$modifier$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '⌘ Command'
	String get cmd => '⌘ Command';

	/// en: 'Ctrl'
	String get ctrl => 'Ctrl';

	/// en: 'Windows / Super'
	String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class Translations$keyboardShortcuts$platform$en {
	Translations$keyboardShortcuts$platform$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'macOS'
	String get macos => 'macOS';

	/// en: 'iPadOS'
	String get ios => 'iPadOS';

	/// en: 'Windows'
	String get windows => 'Windows';

	/// en: 'Linux'
	String get linux => 'Linux';

	/// en: 'Android'
	String get android => 'Android';
}

// Path: home.logs.sheet
class Translations$home$logs$sheet$en {
	Translations$home$logs$sheet$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Station Callsigns'
	String get callsigns => 'Station Callsigns';

	/// en: 'Group By'
	String get groupBy => 'Group By';

	/// en: 'Time Period'
	String get period => 'Time Period';
}

// Path: home.logs.groupBy
class Translations$home$logs$groupBy$en {
	Translations$home$logs$groupBy$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Not grouped'
	String get none => 'Not grouped';

	/// en: 'Date'
	String get date => 'Date';

	/// en: 'DX'
	String get dx => 'DX';

	/// en: 'Unknown continent'
	String get unknownContinent => 'Unknown continent';

	/// en: 'Unknown entity'
	String get unknownEntity => 'Unknown entity';

	/// en: 'No date'
	String get unknownDate => 'No date';
}

// Path: home.logs.period
class Translations$home$logs$period$en {
	Translations$home$logs$period$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This month'
	String get thisMonth => 'This month';

	/// en: 'Last 3 months'
	String get last3Months => 'Last 3 months';

	/// en: 'This year'
	String get thisYear => 'This year';

	/// en: 'Last year'
	String get lastYear => 'Last year';

	/// en: 'All time'
	String get allTime => 'All time';

	/// en: 'Custom range'
	String get custom => 'Custom range';
}

// Path: home.logs.periodTitle
class Translations$home$logs$periodTitle$en {
	Translations$home$logs$periodTitle$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'in ${span}'
	String inSpan({required Object span}) => 'in ${span}';

	/// en: 'Custom Range'
	String get custom => 'Custom Range';
}

// Path: home.logs.columns
class Translations$home$logs$columns$en {
	Translations$home$logs$columns$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Date'
	String get date => 'Date';

	/// en: 'Time'
	String get time => 'Time';

	/// en: 'Frequency'
	String get freq => 'Frequency';

	/// en: 'Mode'
	String get mode => 'Mode';

	/// en: 'Call'
	String get call => 'Call';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Station'
	String get station => 'Station';

	/// en: 'Band'
	String get band => 'Band';

	/// en: 'Sent'
	String get sent => 'Sent';

	/// en: 'Rcvd'
	String get rcvd => 'Rcvd';

	/// en: 'Grid'
	String get grid => 'Grid';

	/// en: 'State'
	String get state => 'State';

	/// en: 'Country'
	String get country => 'Country';

	/// en: 'Refs'
	String get refs => 'Refs';
}

// Path: home.logs.panels
class Translations$home$logs$panels$en {
	Translations$home$logs$panels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'QSO Log'
	String get qsos => 'QSO Log';

	/// en: 'The selected callsign's QSOs, across every operation.'
	String get qsosDescription => 'The selected callsign\'s QSOs, across every operation.';

	/// en: 'Info'
	String get info => 'Info';

	/// en: 'Total QSO count, or the selected QSO's callsign lookup.'
	String get infoDescription => 'Total QSO count, or the selected QSO\'s callsign lookup.';

	/// en: 'Map'
	String get map => 'Map';

	/// en: 'The selected QSO's location.'
	String get mapDescription => 'The selected QSO\'s location.';
}

// Path: home.logs.import
class Translations$home$logs$import$en {
	Translations$home$logs$import$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Callsigns: ${calls}'
	String callsigns({required Object calls}) => 'Callsigns: ${calls}';

	/// en: '1 record could not be read'
	String get skippedOne => '1 record could not be read';

	/// en: '${count} records could not be read'
	String skippedOther({required Object count}) => '${count} records could not be read';

	/// en: 'Reading ADIF file…'
	String get readingTitle => 'Reading ADIF file…';

	/// en: 'Checking for duplicates…'
	String get checkingTitle => 'Checking for duplicates…';

	/// en: 'Importing QSOs…'
	String get importingTitle => 'Importing QSOs…';

	/// en: '${kb} Kb'
	String readingDetail({required Object kb}) => '${kb} Kb';

	/// en: '${done} of ${total} checked'
	String checkingDetail({required Object done, required Object total}) => '${done} of ${total} checked';

	/// en: '${imported} imported, out of ${total}'
	String importingDetail({required Object imported, required Object total}) => '${imported} imported, out of ${total}';
}

// Path: operation.layout.layouts
class Translations$operation$layout$layouts$en {
	Translations$operation$layout$layouts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default'
	String get defaultName => 'Default';

	/// en: 'Layout ${number}'
	String untitledName({required Object number}) => 'Layout ${number}';

	/// en: 'Layout: ${name}'
	String switcherLabel({required Object name}) => 'Layout: ${name}';

	/// en: 'New…'
	String get menuNew => 'New…';

	/// en: 'Export…'
	String get menuExport => 'Export…';

	/// en: 'Import…'
	String get menuImport => 'Import…';

	/// en: 'Layouts'
	String get menuTitle => 'Layouts';

	/// en: 'New Layout'
	String get newTitle => 'New Layout';

	/// en: 'Edit Layout'
	String get editTitle => 'Edit Layout';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Duplicate current layout'
	String get duplicateCurrent => 'Duplicate current layout';

	/// en: 'Start from the default layout'
	String get startFromDefault => 'Start from the default layout';

	/// en: 'Name'
	String get nameLabel => 'Name';

	/// en: 'Description'
	String get descriptionLabel => 'Description';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Save changes to "${name}"?'
	String leaveEditTitle({required Object name}) => 'Save changes to "${name}"?';

	/// en: 'This layout has changes you haven’t saved.'
	String get leaveEditBody => 'This layout has changes you haven’t saved.';

	/// en: 'Discard'
	String get discard => 'Discard';

	/// en: 'Delete this layout?'
	String get deleteTitle => 'Delete this layout?';

	/// en: 'Are you sure you want to delete this "${name}" Layout?'
	String deleteBody({required Object name}) => 'Are you sure you want to delete this "${name}" Layout?';

	/// en: 'Export Layout'
	String get exportTitle => 'Export Layout';

	/// en: 'Panels to export'
	String get exportPick => 'Panels to export';

	/// en: 'Tab Set'
	String get tabSet => 'Tab Set';

	/// en: 'Export'
	String get exportAction => 'Export';

	/// en: 'Layout saved to ${location}'
	String exported({required Object location}) => 'Layout saved to ${location}';

	/// en: 'Couldn't export the layout: ${error}'
	String exportFailed({required Object error}) => 'Couldn\'t export the layout: ${error}';

	/// en: 'Import Layout'
	String get importTitle => 'Import Layout';

	/// en: 'Made for the ${view} view: panels only that view has are left out.'
	String importFromOtherView({required Object view}) => 'Made for the ${view} view: panels only that view has are left out.';

	/// en: 'Home'
	String get viewHome => 'Home';

	/// en: 'Operation'
	String get viewOperation => 'Operation';

	/// en: 'Logs'
	String get viewLogs => 'Logs';

	/// en: 'Chasing'
	String get viewChase => 'Chasing';

	/// en: 'As a new layout'
	String get importAsNew => 'As a new layout';

	/// en: 'In place of this layout'
	String get importReplace => 'In place of this layout';

	/// en: 'Added to this layout'
	String get importAdd => 'Added to this layout';

	/// en: 'The panels arrive in a new column on the right.'
	String get importAddHint => 'The panels arrive in a new column on the right.';

	/// en: 'Panels to import'
	String get importPick => 'Panels to import';

	/// en: 'Replace the settings of panels already set up here'
	String get importReplaceSettings => 'Replace the settings of panels already set up here';

	/// en: 'Import'
	String get importAction => 'Import';

	/// en: '${filename} isn't a layout this app can read: ${problem}'
	String importUnreadable({required Object filename, required Object problem}) => '${filename} isn\'t a layout this app can read: ${problem}';

	/// en: 'the text isn’t valid YAML (line ${line})'
	String problemNotYaml({required Object line}) => 'the text isn’t valid YAML (line ${line})';

	/// en: 'it isn’t a Ham2K layout file'
	String get problemNotLayoutFile => 'it isn’t a Ham2K layout file';

	/// en: 'it was written by a newer version of the app'
	String get problemNewerVersion => 'it was written by a newer version of the app';

	/// en: 'it holds no arrangement'
	String get problemNoArrangement => 'it holds no arrangement';

	/// en: 'part of it doesn’t follow the layout format'
	String get problemMalformed => 'part of it doesn’t follow the layout format';

	/// en: 'it is too large'
	String get problemTooLarge => 'it is too large';

	/// en: 'Couldn't open the file: ${error}'
	String importPickerFailed({required Object error}) => 'Couldn\'t open the file: ${error}';

	/// en: 'Couldn't import the layout: ${error}'
	String importFailed({required Object error}) => 'Couldn\'t import the layout: ${error}';

	/// en: 'Couldn't copy the layout: ${error}'
	String duplicateFailed({required Object error}) => 'Couldn\'t copy the layout: ${error}';

	/// en: 'No panel picked, so nothing was imported.'
	String get importNothing => 'No panel picked, so nothing was imported.';

	/// en: 'Left out: ${panels}'
	String importSkipped({required Object panels}) => 'Left out: ${panels}';

	/// en: 'Kept ${panels}: the small-screen arrangement can’t do without it.'
	String importKeptPinned({required Object panels}) => 'Kept ${panels}: the small-screen arrangement can’t do without it.';

	/// en: 'Not available in this view'
	String get notOffered => 'Not available in this view';

	/// en: 'Already in this layout'
	String get alreadyPlaced => 'Already in this layout';

	/// en: 'Needs ${name}'
	String needsExtension({required Object name}) => 'Needs ${name}';

	/// en: 'Layout names couldn’t be read'
	String get listRecoveredTitle => 'Layout names couldn’t be read';

	/// en: 'This view’s list of layouts could not be read. Every layout is still here, numbered in place of its name.'
	String get listRecoveredBody => 'This view’s list of layouts could not be read. Every layout is still here, numbered in place of its name.';
}

// Path: operation.layout.panels
class Translations$operation$layout$panels$en {
	Translations$operation$layout$panels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'The log and the entry fields'
	String get loggingDescription => 'The log and the entry fields';

	/// en: 'What we know about the station being worked'
	String get infoDescription => 'What we know about the station being worked';

	/// en: 'Spots from the clusters and activity programs'
	String get spotsDescription => 'Spots from the clusters and activity programs';

	/// en: 'Where the contacts are'
	String get mapDescription => 'Where the contacts are';

	/// en: 'The operation's stats and scores, in the sections and order you pick'
	String get summariesDescription => 'The operation\'s stats and scores, in the sections and order you pick';

	/// en: 'Sections and Order'
	String get summariesSections => 'Sections and Order';

	/// en: 'Each day'
	String get summariesDays => 'Each day';

	/// en: 'Show all'
	String get summariesReset => 'Show all';

	/// en: 'Every section is hidden. Pick the ones to show in this panel's settings.'
	String get summariesAllHidden => 'Every section is hidden. Pick the ones to show in this panel\'s settings.';

	/// en: 'A clock face, in any time zone'
	String get clockDescription => 'A clock face, in any time zone';

	/// en: 'Face'
	String get clockFace => 'Face';

	/// en: 'LCD'
	String get clockFaceLcd => 'LCD';

	/// en: 'Analog'
	String get clockFaceAnalog => 'Analog';

	/// en: 'Time Zone'
	String get clockZone => 'Time Zone';

	/// en: 'UTC'
	String get clockZoneUtc => 'UTC';

	/// en: 'This device'
	String get clockZoneDevice => 'This device';

	/// en: 'Show seconds'
	String get clockShowSeconds => 'Show seconds';

	/// en: 'Conditions now and for the next eight hours, where you're operating'
	String get weatherDescription => 'Conditions now and for the next eight hours, where you\'re operating';

	/// en: 'Use the operation's location'
	String get weatherUseOperationLocation => 'Use the operation\'s location';

	/// en: 'Location'
	String get weatherLocation => 'Location';

	/// en: 'A grid square (FN31pr) or lat,lon. Ignored while 'Use the operation's location' is checked.'
	String get weatherLocationDescription => 'A grid square (FN31pr) or lat,lon. Ignored while \'Use the operation\'s location\' is checked.';

	/// en: 'No location set. Give this panel a location in its settings, or place it inside an operation that has one.'
	String get weatherNoLocation => 'No location set. Give this panel a location in its settings, or place it inside an operation that has one.';

	/// en: 'Couldn't read the location ${location}. Use a grid square like FN31pr, or 42.36,-71.06.'
	String weatherBadLocation({required Object location}) => 'Couldn\'t read the location ${location}. Use a grid square like FN31pr, or 42.36,-71.06.';

	/// en: 'Couldn't reach Open-Meteo — no network? Will try again shortly.'
	String get weatherUnreachable => 'Couldn\'t reach Open-Meteo — no network? Will try again shortly.';

	/// en: 'Open-Meteo responded, but not with anything readable. Will try again shortly.'
	String get weatherUnreadable => 'Open-Meteo responded, but not with anything readable. Will try again shortly.';

	/// en: 'gusts ${speed}'
	String weatherGusts({required Object speed}) => 'gusts ${speed}';

	/// en: 'just now'
	String get panelAgeNow => 'just now';

	/// en: '(one) {${count} min ago} (other) {${count} min ago}'
	String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} min ago',
		other: '${count} min ago',
	);

	/// en: '(one) {${count} hr ago} (other) {${count} hrs ago}'
	String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} hr ago',
		other: '${count} hrs ago',
	);

	late final Translations$operation$layout$panels$weatherConditions$en weatherConditions = Translations$operation$layout$panels$weatherConditions$en.internal(_root);

	/// en: 'A web page of your choosing, in a pane'
	String get websiteDescription => 'A web page of your choosing, in a pane';

	/// en: 'Address'
	String get websiteUrl => 'Address';

	/// en: 'Refresh'
	String get websiteRefresh => 'Refresh';

	/// en: 'Never'
	String get websiteRefreshNever => 'Never';

	/// en: 'Every minute'
	String get websiteRefresh1 => 'Every minute';

	/// en: 'Every 5 minutes'
	String get websiteRefresh5 => 'Every 5 minutes';

	/// en: 'Every 15 minutes'
	String get websiteRefresh15 => 'Every 15 minutes';

	/// en: 'Panel Name'
	String get websiteTitle => 'Panel Name';

	/// en: 'Refresh Now'
	String get websiteRefreshNow => 'Refresh Now';

	/// en: 'No address yet. Open this panel’s settings to choose a page.'
	String get websiteNoUrl => 'No address yet. Open this panel’s settings to choose a page.';

	/// en: 'That doesn’t look like a web address. It needs to start with https://'
	String get websiteBadUrl => 'That doesn’t look like a web address. It needs to start with https://';

	/// en: 'Only https:// addresses can be shown here.'
	String get websiteNotHttps => 'Only https:// addresses can be shown here.';

	/// en: 'Web pages can’t be shown in a panel on this system.'
	String get websiteUnsupported => 'Web pages can’t be shown in a panel on this system.';

	/// en: 'Open in Browser'
	String get websiteOpenExternally => 'Open in Browser';

	/// en: 'Couldn’t load the page: ${reason}'
	String websiteLoadFailed({required Object reason}) => 'Couldn’t load the page: ${reason}';

	/// en: 'A screen, app or window shared by another of your devices.'
	String get remoteScreenDescription => 'A screen, app or window shared by another of your devices.';

	/// en: 'Screen'
	String get remoteScreenTarget => 'Screen';

	/// en: 'Choose a screen…'
	String get remoteScreenChoose => 'Choose a screen…';

	/// en: 'Shared Screens'
	String get remoteScreenPickerTitle => 'Shared Screens';

	/// en: 'None of your devices is sharing a screen. Turn Share screens and windows on under Settings → Peer Devices, on the device you want to see.'
	String get remoteScreenPickerEmpty => 'None of your devices is sharing a screen. Turn Share screens and windows on under Settings → Peer Devices, on the device you want to see.';

	/// en: 'No screen chosen. Open this panel's settings to pick one your other devices are sharing.'
	String get remoteScreenUnset => 'No screen chosen. Open this panel\'s settings to pick one your other devices are sharing.';

	/// en: 'Connecting…'
	String get remoteScreenConnecting => 'Connecting…';

	/// en: 'That device isn't connected right now.'
	String get remoteScreenPeerAway => 'That device isn\'t connected right now.';

	/// en: 'That device stopped sharing this screen.'
	String get remoteScreenNotOffered => 'That device stopped sharing this screen.';

	/// en: 'That device can't accept connections — check its firewall.'
	String get remoteScreenNoListener => 'That device can\'t accept connections — check its firewall.';

	/// en: 'Screens are only shared over the local network, not Bluetooth.'
	String get remoteScreenNoLan => 'Screens are only shared over the local network, not Bluetooth.';

	/// en: 'That device wouldn't share this screen.'
	String get remoteScreenRefused => 'That device wouldn\'t share this screen.';

	/// en: 'Panel settings'
	String get remoteScreenSettings => 'Panel settings';

	/// en: 'Adjust View'
	String get remoteScreenAdjust => 'Adjust View';

	/// en: 'Detail'
	String get remoteScreenDetail => 'Detail';

	/// en: 'Standard'
	String get remoteScreenDetailStandard => 'Standard';

	/// en: 'High'
	String get remoteScreenDetailHigh => 'High';

	/// en: 'Maximum'
	String get remoteScreenDetailMaximum => 'Maximum';

	/// en: 'OK'
	String get remoteScreenAdjustDone => 'OK';

	/// en: 'Zoom in'
	String get remoteScreenZoomIn => 'Zoom in';

	/// en: 'Zoom out'
	String get remoteScreenZoomOut => 'Zoom out';

	/// en: 'That screen or window is no longer being shown.'
	String get remoteScreenStopped => 'That screen or window is no longer being shown.';

	/// en: 'That device couldn't capture that screen — it may need Screen Recording permission.'
	String get remoteScreenCaptureFailed => 'That device couldn\'t capture that screen — it may need Screen Recording permission.';

	/// en: 'That device didn't respond. It may not have screen sharing turned on.'
	String get remoteScreenNoAnswer => 'That device didn\'t respond. It may not have screen sharing turned on.';

	/// en: 'Couldn't open a connection for the picture. Check the firewall on this device.'
	String get remoteScreenNoMedia => 'Couldn\'t open a connection for the picture. Check the firewall on this device.';

	/// en: 'Solar and geomagnetic conditions, with band-by-band propagation'
	String get solarDescription => 'Solar and geomagnetic conditions, with band-by-band propagation';

	/// en: 'Couldn't reach hamqsl.com — no network? Will try again shortly.'
	String get solarUnreachable => 'Couldn\'t reach hamqsl.com — no network? Will try again shortly.';

	/// en: 'hamqsl.com responded, but not with a reading we could use. Will try again shortly.'
	String get solarUnreadable => 'hamqsl.com responded, but not with a reading we could use. Will try again shortly.';

	/// en: 'A'
	String get solarAIndex => 'A';

	/// en: 'Kp'
	String get solarKIndex => 'Kp';

	/// en: 'Day'
	String get solarBandDay => 'Day';

	/// en: 'Night'
	String get solarBandNight => 'Night';

	/// en: 'Good'
	String get solarBandGood => 'Good';

	/// en: 'Fair'
	String get solarBandFair => 'Fair';

	/// en: 'Poor'
	String get solarBandPoor => 'Poor';

	/// en: 'Sources: ${primary}, ${secondary}'
	String solarSources({required Object primary, required Object secondary}) => 'Sources: ${primary}, ${secondary}';

	/// en: 'The connection is struggling — skipping frames.'
	String get remoteScreenDegraded => 'The connection is struggling — skipping frames.';

	/// en: 'Frames stopped getting through — this connection may be too slow.'
	String get remoteScreenStalled => 'Frames stopped getting through — this connection may be too slow.';

	/// en: 'A radio's front panel — frequency, mode and power, under CAT control'
	String get radioDescription => 'A radio\'s front panel — frequency, mode and power, under CAT control';

	/// en: 'Style'
	String get radioStyle => 'Style';

	/// en: 'LCD'
	String get radioStyleLcd => 'LCD';

	/// en: 'Modern'
	String get radioStyleModern => 'Modern';

	/// en: 'Radio'
	String get radioRadio => 'Radio';

	/// en: 'VFO A — ${name}'
	String radioAutoNamed({required Object name}) => 'VFO A — ${name}';

	/// en: 'VFO A — no radio designated'
	String get radioAutoNone => 'VFO A — no radio designated';

	/// en: 'No radio to show. Pick one in this panel's settings, or add one under Station Configuration.'
	String get radioNoRadio => 'No radio to show. Pick one in this panel\'s settings, or add one under Station Configuration.';

	/// en: 'This radio is not configured yet. Choose its port or address under Station Configuration.'
	String get radioNotConfigured => 'This radio is not configured yet. Choose its port or address under Station Configuration.';

	/// en: '—'
	String get radioNoFrequency => '—';

	/// en: 'Radio not connected'
	String get radioOff => 'Radio not connected';

	/// en: 'W'
	String get radioWatts => 'W';

	/// en: 'Connect this radio'
	String get radioConnect => 'Connect this radio';

	/// en: 'Disconnect this radio'
	String get radioDisconnect => 'Disconnect this radio';

	/// en: 'NO DATA'
	String get radioStale => 'NO DATA';

	/// en: 'TX'
	String get radioTransmitting => 'TX';

	/// en: 'SWR'
	String get radioSwr => 'SWR';

	/// en: 'ALC'
	String get radioAlc => 'ALC';

	/// en: 'V'
	String get radioVolts => 'V';

	/// en: 'high SWR'
	String get radioSwrHigh => 'high SWR';
}

// Path: operation.export.compactFileNames
class Translations$operation$export$compactFileNames$en {
	Translations$operation$export$compactFileNames$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Use compact file names'
	String get title => 'Use compact file names';

	/// en: 'Short names built for uploaders, like N0CALL@US-1234-20260727.adi'
	String get descriptionOn => 'Short names built for uploaders, like N0CALL@US-1234-20260727.adi';

	/// en: 'Readable names, like 2026-07-27 N0CALL at US-1234.adi'
	String get descriptionOff => 'Readable names, like 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class Translations$operation$export$includePrivateData$en {
	Translations$operation$export$includePrivateData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Include private info'
	String get title => 'Include private info';

	/// en: 'Names, addresses, emails, gridsquares and notes are included'
	String get descriptionOn => 'Names, addresses, emails, gridsquares and notes are included';

	/// en: 'Names, addresses, emails, gridsquares and notes are left out'
	String get descriptionOff => 'Names, addresses, emails, gridsquares and notes are left out';

	/// en: 'The Full ADIF Export always includes everything'
	String get note => 'The Full ADIF Export always includes everything';
}

// Path: operation.export.stash
class Translations$operation$export$stash$en {
	Translations$operation$export$stash$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Add an email address first'
	String get needsEmailTitle => 'Add an email address first';

	/// en: 'Ham2K’s File Stash sends your files to the email address on your LoFi account, and you sign in with it at stash.ham2k.net. Your account doesn’t have a confirmed one yet — add it in Settings › Cloud Sync.'
	String get needsEmailBody => 'Ham2K’s File Stash sends your files to the email address on your LoFi account, and you sign in with it at stash.ham2k.net. Your account doesn’t have a confirmed one yet — add it in Settings › Cloud Sync.';

	/// en: 'Open Cloud Sync'
	String get openSyncSettings => 'Open Cloud Sync';

	/// en: 'Recent stash will be replaced'
	String get replaceTitle => 'Recent stash will be replaced';

	/// en: 'You sent “${name}” less than 6 hours ago and it hasn’t been downloaded yet. Free accounts keep one stash at a time, so sending now replaces it.'
	String replaceBody({required Object name}) => 'You sent “${name}” less than 6 hours ago and it hasn’t been downloaded yet. Free accounts keep one stash at a time, so sending now replaces it.';

	/// en: 'Send Anyway'
	String get replaceConfirm => 'Send Anyway';

	/// en: 'Couldn’t send to Ham2K’s File Stash'
	String get failedTitle => 'Couldn’t send to Ham2K’s File Stash';

	/// en: 'Sent to Ham2K’s File Stash'
	String get sentTitle => 'Sent to Ham2K’s File Stash';

	/// en: '(one) {You can retrieve this file by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.} (other) {You can retrieve these files by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.}'
	String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'You can retrieve this file by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.',
		other: 'You can retrieve these files by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.',
	);

	/// en: 'No answer from the stash — the file may have arrived anyway. Check stash.ham2k.net before sending again'
	String get mayHaveArrived => 'No answer from the stash — the file may have arrived anyway. Check stash.ham2k.net before sending again';

	/// en: 'not sent'
	String get notSent => 'not sent';

	/// en: '(one) {This file didn’t arrive:} (other) {These ${count} files didn’t arrive:}'
	String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'This file didn’t arrive:',
		other: 'These ${count} files didn’t arrive:',
	);

	/// en: 'Or for your convenience, we can send you an email with a direct link.'
	String get emailOffer => 'Or for your convenience, we can send you an email with a direct link.';

	/// en: 'Email Me a Link'
	String get emailMe => 'Email Me a Link';

	/// en: 'We’ve emailed you a download link.'
	String get emailSent => 'We’ve emailed you a download link.';

	/// en: 'Couldn’t send the email: ${error}'
	String emailFailed({required Object error}) => 'Couldn’t send the email: ${error}';

	/// en: 'Free accounts can only keep one stash at a time. Subscribers can keep as many as they want.'
	String get freeTier => 'Free accounts can only keep one stash at a time. Subscribers can keep as many as they want.';

	/// en: '(one) {Sent ${count} file to Ham2K’s File Stash (stash.ham2k.net)} (other) {Sent ${count} files to Ham2K’s File Stash (stash.ham2k.net)}'
	String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: 'Sent ${count} file to Ham2K’s File Stash (stash.ham2k.net)',
		other: 'Sent ${count} files to Ham2K’s File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class Translations$operation$spots$continents$en {
	Translations$operation$spots$continents$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Africa'
	String get af => 'Africa';

	/// en: 'Asia'
	String get as => 'Asia';

	/// en: 'Europe'
	String get eu => 'Europe';

	/// en: 'North America'
	String get na => 'North America';

	/// en: 'Oceania'
	String get oc => 'Oceania';

	/// en: 'South America'
	String get sa => 'South America';

	/// en: 'Antarctica'
	String get an => 'Antarctica';
}

// Path: operation.spots.filters
class Translations$operation$spots$filters$en {
	Translations$operation$spots$filters$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Filter Spots'
	String get title => 'Filter Spots';

	/// en: 'Band'
	String get band => 'Band';

	/// en: 'Mode'
	String get mode => 'Mode';

	/// en: 'Age'
	String get age => 'Age';

	/// en: 'Sources'
	String get sources => 'Sources';

	/// en: 'Continent'
	String get continent => 'Continent';

	/// en: 'Sorting'
	String get sorting => 'Sorting';

	/// en: 'By Spot Time'
	String get sortByTime => 'By Spot Time';

	/// en: 'By Frequency'
	String get sortByFrequency => 'By Frequency';

	/// en: 'Most Wanted'
	String get sortByWanted => 'Most Wanted';

	/// en: 'Group by Band'
	String get groupByBand => 'Group by Band';

	/// en: 'Group Calls with Notes'
	String get groupCallsWithNotes => 'Group Calls with Notes';

	/// en: 'Only Spots with Alerts'
	String get alertingOnly => 'Only Spots with Alerts';

	/// en: 'No reply'
	String get sourceNoReply => 'No reply';

	/// en: 'Error'
	String get sourceError => 'Error';
}

// Path: operation.spots.logConflict
class Translations$operation$spots$logConflict$en {
	Translations$operation$spots$logConflict$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Logging panel is busy'
	String get title => 'Logging panel is busy';

	/// en: 'You're editing a logged contact. Log this spot instead, or go back and finish the edit?'
	String get editingBody => 'You\'re editing a logged contact. Log this spot instead, or go back and finish the edit?';

	/// en: 'You've started entering a contact. Log this spot instead, or go back and finish what you were typing?'
	String get composingBody => 'You\'ve started entering a contact. Log this spot instead, or go back and finish what you were typing?';

	/// en: 'Go back'
	String get goBack => 'Go back';

	/// en: 'Clear and log spot'
	String get clearAndLog => 'Clear and log spot';
}

// Path: settings.logging.leftieMode
class Translations$settings$logging$leftieMode$en {
	Translations$settings$logging$leftieMode$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Leftie Mode'
	String get title => 'Leftie Mode';

	/// en: 'Using layout for left-handed users'
	String get descriptionOn => 'Using layout for left-handed users';

	/// en: 'Using layout for right-handed users'
	String get descriptionOff => 'Using layout for right-handed users';
}

// Path: settings.logging.countryFlags
class Translations$settings$logging$countryFlags$en {
	Translations$settings$logging$countryFlags$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Country Flags'
	String get title => 'Country Flags';

	/// en: 'Show only for DX contacts'
	String get dx => 'Show only for DX contacts';

	/// en: 'Show flags for all contacts'
	String get all => 'Show flags for all contacts';

	/// en: 'Don't show any flags'
	String get none => 'Don\'t show any flags';
}

// Path: settings.logging.countryFlagsDescription
class Translations$settings$logging$countryFlagsDescription$en {
	Translations$settings$logging$countryFlagsDescription$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Showing flags only for DX contacts'
	String get dx => 'Showing flags only for DX contacts';

	/// en: 'Showing flags for all contacts'
	String get all => 'Showing flags for all contacts';

	/// en: 'Not showing any flags'
	String get none => 'Not showing any flags';
}

// Path: settings.logging.suggestDefaultOperator
class Translations$settings$logging$suggestDefaultOperator$en {
	Translations$settings$logging$suggestDefaultOperator$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Suggest Operator'
	String get title => 'Suggest Operator';

	/// en: 'Offering your callsign as the operator when an operation runs under a different station callsign'
	String get descriptionOn => 'Offering your callsign as the operator when an operation runs under a different station callsign';

	/// en: 'Leaving the operator blank unless you fill it in'
	String get descriptionOff => 'Leaving the operator blank unless you fill it in';
}

// Path: settings.logging.showBearing
class Translations$settings$logging$showBearing$en {
	Translations$settings$logging$showBearing$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show Bearing'
	String get title => 'Show Bearing';

	/// en: 'Showing estimated bearing to station'
	String get descriptionOn => 'Showing estimated bearing to station';

	/// en: 'Not showing bearing information'
	String get descriptionOff => 'Not showing bearing information';
}

// Path: settings.logging.showReverseBearing
class Translations$settings$logging$showReverseBearing$en {
	Translations$settings$logging$showReverseBearing$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Also show reverse bearing'
	String get title => 'Also show reverse bearing';

	/// en: 'Showing the bearing from the station too, as "45° / 225°"'
	String get descriptionOn => 'Showing the bearing from the station too, as "45° / 225°"';

	/// en: 'Only showing the bearing to the station'
	String get descriptionOff => 'Only showing the bearing to the station';
}

// Path: settings.logging.switchSentRcvd
class Translations$settings$logging$switchSentRcvd$en {
	Translations$settings$logging$switchSentRcvd$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Switch signal report order'
	String get title => 'Switch signal report order';

	/// en: 'Sent first, Rcvd second'
	String get sentFirst => 'Sent first, Rcvd second';

	/// en: 'Rcvd first, Sent second'
	String get rcvdFirst => 'Rcvd first, Sent second';
}

// Path: settings.logging.jumpAfterRST
class Translations$settings$logging$jumpAfterRST$en {
	Translations$settings$logging$jumpAfterRST$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Jump to next field on RST entry'
	String get title => 'Jump to next field on RST entry';

	/// en: 'Jumping after RST is entered'
	String get descriptionOn => 'Jumping after RST is entered';

	/// en: 'Not jumping automatically'
	String get descriptionOff => 'Not jumping automatically';
}

// Path: settings.logging.defaultReport
class Translations$settings$logging$defaultReport$en {
	Translations$settings$logging$defaultReport$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default report — Phone'
	String get title => 'Default report — Phone';

	/// en: 'Used when Sent or Rcvd is left empty on SSB, FM or AM'
	String get description => 'Used when Sent or Rcvd is left empty on SSB, FM or AM';
}

// Path: settings.logging.defaultReportCW
class Translations$settings$logging$defaultReportCW$en {
	Translations$settings$logging$defaultReportCW$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default report — CW and data'
	String get title => 'Default report — CW and data';

	/// en: 'Used when Sent or Rcvd is left empty on CW, RTTY and other data modes'
	String get description => 'Used when Sent or Rcvd is left empty on CW, RTTY and other data modes';
}

// Path: settings.logging.defaultReportFT8
class Translations$settings$logging$defaultReportFT8$en {
	Translations$settings$logging$defaultReportFT8$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default report — FT8 and FT4'
	String get title => 'Default report — FT8 and FT4';

	/// en: 'Used when Sent or Rcvd is left empty on the FT modes'
	String get description => 'Used when Sent or Rcvd is left empty on the FT modes';
}

// Path: settings.logging.numbersRow
class Translations$settings$logging$numbersRow$en {
	Translations$settings$logging$numbersRow$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Numbers Row'
	String get title => 'Numbers Row';

	/// en: 'Show a row of number keys above the keyboard while logging'
	String get description => 'Show a row of number keys above the keyboard while logging';
}

// Path: settings.logging.numbersRowExtra
class Translations$settings$logging$numbersRowExtra$en {
	Translations$settings$logging$numbersRowExtra$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Slash and period key'
	String get title => 'Slash and period key';

	/// en: 'Adds a contextual key: “/” for callsigns, “.” for numbers'
	String get description => 'Adds a contextual key: “/” for callsigns, “.” for numbers';
}

// Path: settings.logging.numbersRowVibrate
class Translations$settings$logging$numbersRowVibrate$en {
	Translations$settings$logging$numbersRowVibrate$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Vibrate on key press'
	String get title => 'Vibrate on key press';

	/// en: 'Haptic feedback when you tap a number key'
	String get description => 'Haptic feedback when you tap a number key';
}

// Path: settings.catServer.protocolOpts
class Translations$settings$catServer$protocolOpts$en {
	Translations$settings$catServer$protocolOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Disabled'
	String get off => 'Disabled';

	/// en: 'Hamlib rigctld'
	String get rigctld => 'Hamlib rigctld';

	/// en: 'flrig'
	String get flrig => 'flrig';

	/// en: 'Ham Radio Deluxe®'
	String get hrd => 'Ham Radio Deluxe®';

	/// en: 'N3FJP'
	String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class Translations$settings$cluster$errors$en {
	Translations$settings$cluster$errors$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'no operator callsign to log in with'
	String get noCall => 'no operator callsign to log in with';

	/// en: 'the node could not be reached'
	String get connectFailed => 'the node could not be reached';

	/// en: 'the node asks for a password, and none is stored'
	String get needsPassword => 'the node asks for a password, and none is stored';

	/// en: 'the node did not accept the login'
	String get loginFailed => 'the node did not accept the login';

	/// en: 'the node closed the connection'
	String get disconnected => 'the node closed the connection';

	/// en: 'the node did not answer'
	String get timeout => 'the node did not answer';
}

// Path: settings.radio.units
class Translations$settings$radio$units$en {
	Translations$settings$radio$units$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'ms'
	String get ms => 'ms';

	/// en: 'kHz'
	String get kHz => 'kHz';

	/// en: 'kHz/s'
	String get kHzPerSecond => 'kHz/s';

	/// en: 'Hz'
	String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class Translations$settings$radio$pttKey$en {
	Translations$settings$radio$pttKey$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Control PTT with [']'
	String get title => 'Control PTT with [\']';

	/// en: 'In Phone modes, ['] keys the radio and ['] again unkeys it. It unkeys by itself after a minute.'
	String get descriptionOn => 'In Phone modes, [\'] keys the radio and [\'] again unkeys it. It unkeys by itself after a minute.';

	/// en: 'The ['] key does not key the radio.'
	String get descriptionOff => 'The [\'] key does not key the radio.';

	/// en: 'TX'
	String get pill => 'TX';

	/// en: 'Transmitting'
	String get transmitting => 'Transmitting';
}

// Path: settings.radio.smartVfoSnap
class Translations$settings$radio$smartVfoSnap$en {
	Translations$settings$radio$smartVfoSnap$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart VFO Snap'
	String get title => 'Smart VFO Snap';

	/// en: 'After you stop turning the dial, rounding the frequency to a sensible step. Voice modes only.'
	String get descriptionOn => 'After you stop turning the dial, rounding the frequency to a sensible step. Voice modes only.';

	/// en: 'Staying exactly where you tuned it.'
	String get descriptionOff => 'Staying exactly where you tuned it.';
}

// Path: settings.radio.snapDebounce
class Translations$settings$radio$snapDebounce$en {
	Translations$settings$radio$snapDebounce$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart Snap: Settle delay'
	String get title => 'Smart Snap: Settle delay';

	/// en: 'How long the dial has to stop before the frequency is rounded. Shorter feels immediate; longer leaves room for a slow move.'
	String get description => 'How long the dial has to stop before the frequency is rounded. Shorter feels immediate; longer leaves room for a slow move.';
}

// Path: settings.radio.snapLongMove
class Translations$settings$radio$snapLongMove$en {
	Translations$settings$radio$snapLongMove$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart Snap: Long move'
	String get title => 'Smart Snap: Long move';

	/// en: 'Move at least this far and the frequency rounds to a whole kHz, however slowly you finished.'
	String get description => 'Move at least this far and the frequency rounds to a whole kHz, however slowly you finished.';
}

// Path: settings.radio.snapMinMove
class Translations$settings$radio$snapMinMove$en {
	Translations$settings$radio$snapMinMove$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart Snap: Smallest move'
	String get title => 'Smart Snap: Smallest move';

	/// en: 'Move less than this and the frequency is not rounded, so fine tuning is left alone.'
	String get description => 'Move less than this and the frequency is not rounded, so fine tuning is left alone.';
}

// Path: settings.radio.snapMinSpeed
class Translations$settings$radio$snapMinSpeed$en {
	Translations$settings$radio$snapMinSpeed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart Snap: Slowest move'
	String get title => 'Smart Snap: Slowest move';

	/// en: 'Turn the dial slower than this and the frequency is not rounded, unless it was a long move.'
	String get description => 'Turn the dial slower than this and the frequency is not rounded, unless it was a long move.';
}

// Path: settings.radio.enterSends
class Translations$settings$radio$enterSends$en {
	Translations$settings$radio$enterSends$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'ESM Off'
	String get pillOff => 'ESM Off';

	/// en: 'ESM Run'
	String get pillRun => 'ESM Run';

	/// en: 'ESM S&P'
	String get pillSp => 'ESM S&P';

	/// en: 'Enter sends messages'
	String get field => 'Enter sends messages';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Run'
	String get run => 'Run';

	/// en: 'S&P'
	String get sp => 'S&P';

	/// en: 'Enter Sends Messages: $state. Tap to change.'
	String semantics({required Object state}) => 'Enter Sends Messages: ${state}. Tap to change.';
}

// Path: settings.radio.keyerSpeed
class Translations$settings$radio$keyerSpeed$en {
	Translations$settings$radio$keyerSpeed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Keyer speed'
	String get title => 'Keyer speed';

	/// en: 'WPM'
	String get unit => 'WPM';

	/// en: '$wpm wpm'
	String pill({required Object wpm}) => '${wpm} wpm';

	/// en: '– wpm'
	String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class Translations$settings$radio$cwMessages$en {
	Translations$settings$radio$cwMessages$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'CW Keyer Messages'
	String get title => 'CW Keyer Messages';

	/// en: 'Current radio does not support CW keying'
	String get notSupported => 'Current radio does not support CW keying';

	/// en: 'F$n'
	String key({required Object n}) => 'F${n}';

	/// en: 'Message ($n)'
	String messageTitle({required Object n}) => 'Message (${n})';

	/// en: 'Label'
	String get labelField => 'Label';

	/// en: 'F$n label'
	String labelKey({required Object n}) => 'F${n} label';

	/// en: 'Details'
	String get details => 'Details';

	/// en: '(empty)'
	String get empty => '(empty)';

	/// en: 'Message Set'
	String get sets => 'Message Set';

	/// en: 'New Set'
	String get newSet => 'New Set';

	/// en: 'Rename Set'
	String get renameSet => 'Rename Set';

	/// en: 'Delete Set'
	String get deleteSet => 'Delete Set';

	/// en: 'Name'
	String get newSetName => 'Name';

	/// en: 'Default'
	String get setDefault => 'Default';

	/// en: 'POTA'
	String get setPota => 'POTA';

	/// en: 'ESM Messages'
	String get setEsm => 'ESM Messages';

	/// en: 'My Messages'
	String get setSaved => 'My Messages';

	/// en: 'Repeat Message #1'
	String get repeat => 'Repeat Message #1';

	/// en: 'No'
	String get repeatOff => 'No';

	/// en: 'After $n seconds'
	String repeatAfter({required Object n}) => 'After ${n} seconds';

	/// en: 'Repeating'
	String get repeatWait => 'Repeating';

	/// en: 'Type to send'
	String get keyboard => 'Type to send';

	/// en: 'Type to send'
	String get keyboardField => 'Type to send';

	/// en: 'Close the keyer area'
	String get closeArea => 'Close the keyer area';

	/// en: 'Help'
	String get help => 'Help';

	/// en: 'Writing CW Messages'
	String get helpTitle => 'Writing CW Messages';

	/// en: 'Messages can use templates with the following values:'
	String get helpIntro => 'Messages can use templates with the following values:';

	/// en: 'Your callsign'
	String get helpOpCall => 'Your callsign';

	/// en: 'Their callsign — in a // stack, the call that will be logged'
	String get helpQsoCall => 'Their callsign — in a // stack, the call that will be logged';

	/// en: 'Their callsign, if there is a valid call; blank for a partial'
	String get helpQsoFullCall => 'Their callsign, if there is a valid call; blank for a partial';

	/// en: 'A partial call; blank if there is a full valid call'
	String get helpQsoPartial => 'A partial call; blank if there is a full valid call';

	/// en: 'In a // stack, the call that will be selected for logging next, if there is a valid full call'
	String get helpQsoNextCall => 'In a // stack, the call that will be selected for logging next, if there is a valid full call';

	/// en: 'In a // stack, the next partial after logging the current contact'
	String get helpQsoNextPartial => 'In a // stack, the next partial after logging the current contact';

	/// en: 'Their first name, as typed or else from the lookup'
	String get helpQsoName => 'Their first name, as typed or else from the lookup';

	/// en: 'Their state, as typed or else from the lookup'
	String get helpQsoState => 'Their state, as typed or else from the lookup';

	/// en: 'Message 1 as it would be sent, inside another message. Valid for messages 1 through 8'
	String get helpKeyerMsg => 'Message 1 as it would be sent, inside another message. Valid for messages 1 through 8';

	/// en: 'The report you are sending'
	String get helpQsoRst => 'The report you are sending';

	/// en: 'Your serial number, in a contest that sends one'
	String get helpQsoSerial => 'Your serial number, in a contest that sends one';

	/// en: 'Pads with zeros to that many digits: 7 is sent as 007'
	String get helpPad => 'Pads with zeros to that many digits: 7 is sent as 007';

	/// en: 'Cut numbers, T for 0 and N for 9: 599 is sent as 5NN'
	String get helpCut => 'Cut numbers, T for 0 and N for 9: 599 is sent as 5NN';

	/// en: 'Chooses the digits to cut, in quotes — 0 is T, 1 is A, 5 is E, 9 is N'
	String get helpCutDigits => 'Chooses the digits to cut, in quotes — 0 is T, 1 is A, 5 is E, 9 is N';

	/// en: 'Full example:'
	String get helpFullExample => 'Full example:';

	/// en: 'Sends W1AW 5NN TT7'
	String get helpExample => 'Sends W1AW 5NN TT7';

	/// en: 'With Enter Sends Messages on, Enter keys messages by their function key, as N1MM does. The ESM Messages set starts with these:'
	String get helpEsmIntro => 'With Enter Sends Messages on, Enter keys messages by their function key, as N1MM does. The ESM Messages set starts with these:';

	/// en: 'Running, Enter with the call field empty calls CQ'
	String get helpEsmCq => 'Running, Enter with the call field empty calls CQ';

	/// en: 'Your exchange: after their call when running, after they answer in S&P'
	String get helpEsmExchange => 'Your exchange: after their call when running, after they answer in S&P';

	/// en: 'Thanks, once the contact has logged: its placeholders name the next contact, not this one'
	String get helpEsmThanks => 'Thanks, once the contact has logged: its placeholders name the next contact, not this one';

	/// en: 'In S&P, your call to the station you are answering'
	String get helpEsmMyCall => 'In S&P, your call to the station you are answering';

	/// en: 'Running, their call ahead of your exchange'
	String get helpEsmHisCall => 'Running, their call ahead of your exchange';

	/// en: 'Asks again when nothing of their exchange was copied'
	String get helpEsmAgain => 'Asks again when nothing of their exchange was copied';

	/// en: 'Suggested F3 for // stacks: TU goes out after the contact logs, so it thanks, then calls the next stacked station and sends your exchange, or asks a partial back (TU KR?); with nothing left, just TU'
	String get helpEsmStackThanks => 'Suggested F3 for // stacks: TU goes out after the contact logs, so it thanks, then calls the next stacked station and sends your exchange, or asks a partial back (TU KR?); with nothing left, just TU';
}

// Path: settings.radio.voiceMessages
class Translations$settings$radio$voiceMessages$en {
	Translations$settings$radio$voiceMessages$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Phone Keyer Messages'
	String get title => 'Phone Keyer Messages';

	/// en: 'Current radio does not support Phone messages'
	String get notSupported => 'Current radio does not support Phone messages';

	/// en: 'This uses the radio's voice memories'
	String get description => 'This uses the radio\'s voice memories';

	/// en: 'M$n'
	String key({required Object n}) => 'M${n}';

	/// en: 'Voice memory ($n)'
	String messageTitle({required Object n}) => 'Voice memory (${n})';

	/// en: 'Label'
	String get labelField => 'Label';

	/// en: 'Voice memory $n label'
	String labelKey({required Object n}) => 'Voice memory ${n} label';

	/// en: '$n s'
	String durationSeconds({required Object n}) => '${n} s';

	/// en: 'Empty'
	String get emptyOnRadio => 'Empty';

	/// en: 'Unknown length'
	String get notMeasured => 'Unknown length';

	/// en: 'Play'
	String get playButton => 'Play';

	/// en: 'Record'
	String get recordButton => 'Record';

	/// en: 'Stop'
	String get stopButton => 'Stop';

	/// en: 'Repeat Message #1'
	String get repeat => 'Repeat Message #1';

	/// en: 'No'
	String get repeatOff => 'No';

	/// en: 'After $n seconds'
	String repeatAfter({required Object n}) => 'After ${n} seconds';

	/// en: '$model Notes:'
	String recordHelpTitle({required Object model}) => '${model} Notes:';

	/// en: 'These memories are in $device's radio. Their names and lengths belong to that device.'
	String namedOnDevice({required Object device}) => 'These memories are in ${device}\'s radio. Their names and lengths belong to that device.';

	/// en: 'Saved in the radio, where its other clients see it too.'
	String get namedOnRadio => 'Saved in the radio, where its other clients see it too.';

	/// en: 'Wait for the [REC] indicator on the radio, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.'
	String get recordHelpYaesuDvs => 'Wait for the [REC] indicator on the radio, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.';

	/// en: 'Wait for the [REC] indicator to blink at least four times, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.'
	String get recordHelpFt891 => 'Wait for the [REC] indicator to blink at least four times, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.';

	/// en: 'Voice'
	String get pill => 'Voice';

	/// en: 'Play memory $n'
	String play({required Object n}) => 'Play memory ${n}';

	/// en: 'Stop'
	String get stop => 'Stop';

	/// en: 'Record memory $n'
	String record({required Object n}) => 'Record memory ${n}';

	/// en: 'Stop recording'
	String get stopRecording => 'Stop recording';

	/// en: 'Playing…'
	String get playing => 'Playing…';

	/// en: 'Recording…'
	String get recording => 'Recording…';

	/// en: 'Playing $label'
	String playingMemory({required Object label}) => 'Playing ${label}';

	/// en: 'Recording $label'
	String recordingMemory({required Object label}) => 'Recording ${label}';

	/// en: 'Did the radio play it? It said it was idle right away.'
	String get doubtful => 'Did the radio play it? It said it was idle right away.';

	/// en: 'You have to record the memories on the radio itself.'
	String get recordOnRadio => 'You have to record the memories on the radio itself.';
}

// Path: settings.radio.avoidZeroBeat
class Translations$settings$radio$avoidZeroBeat$en {
	Translations$settings$radio$avoidZeroBeat$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Avoid Zero-Beating on Spots'
	String get title => 'Avoid Zero-Beating on Spots';

	/// en: 'With a radio connected, tuning a few Hz off a CW spot, so everyone answering it isn’t calling on the same note.'
	String get descriptionOn => 'With a radio connected, tuning a few Hz off a CW spot, so everyone answering it isn’t calling on the same note.';

	/// en: 'Tuning exactly to the spotted frequency.'
	String get descriptionOff => 'Tuning exactly to the spotted frequency.';
}

// Path: settings.radio.zeroBeatRange
class Translations$settings$radio$zeroBeatRange$en {
	Translations$settings$radio$zeroBeatRange$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Zero-Beat: Avoidance range'
	String get title => 'Zero-Beat: Avoidance range';

	/// en: 'How far off the spotted frequency to land, either side. The offset is never near zero — that would be a zero beat again.'
	String get description => 'How far off the spotted frequency to land, either side. The offset is never near zero — that would be a zero beat again.';
}

// Path: settings.map.style
class Translations$settings$map$style$en {
	Translations$settings$map$style$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Map Style'
	String get title => 'Map Style';
}

// Path: settings.map.showCallsigns
class Translations$settings$map$showCallsigns$en {
	Translations$settings$map$showCallsigns$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show Callsigns'
	String get title => 'Show Callsigns';

	/// en: 'Each contact is a pill with its callsign, in its band's color'
	String get description => 'Each contact is a pill with its callsign, in its band\'s color';
}

// Path: settings.map.showGrayline
class Translations$settings$map$showGrayline$en {
	Translations$settings$map$showGrayline$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show Grayline'
	String get title => 'Show Grayline';

	/// en: 'Shades the night side of the Earth, with twilight as a gradient'
	String get description => 'Shades the night side of the Earth, with twilight as a gradient';
}

// Path: settings.map.styleOpts
class Translations$settings$map$styleOpts$en {
	Translations$settings$map$styleOpts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Automatic'
	String get automatic => 'Automatic';

	/// en: 'Liberty'
	String get liberty => 'Liberty';

	/// en: 'Bright'
	String get bright => 'Bright';

	/// en: 'Positron'
	String get positron => 'Positron';

	/// en: 'Voyager'
	String get voyager => 'Voyager';

	/// en: 'Dark Matter'
	String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class Translations$settings$privacy$shareAppData$en {
	Translations$settings$privacy$shareAppData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share app usage data'
	String get title => 'Share app usage data';

	/// en: 'Helping us improve the app by sharing usage, configuration, crash and performance data'
	String get descriptionOn => 'Helping us improve the app by sharing usage, configuration, crash and performance data';

	/// en: 'Keeping app usage data private. The Ham2K team won't be able to detect crashes or other issues.'
	String get descriptionOff => 'Keeping app usage data private.\nThe Ham2K team won\'t be able to detect crashes or other issues.';
}

// Path: settings.privacy.shareOpData
class Translations$settings$privacy$shareOpData$en {
	Translations$settings$privacy$shareOpData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share operation data'
	String get title => 'Share operation data';

	/// en: 'Sharing some operation data publicly and with other users'
	String get descriptionOn => 'Sharing some operation data publicly and with other users';

	/// en: 'Keeping operation data private'
	String get descriptionOff => 'Keeping operation data private';
}

// Path: settings.station.models
class Translations$settings$station$models$en {
	Translations$settings$station$models$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'FlexRadio (SmartSDR)'
	String get flexRadio => 'FlexRadio (SmartSDR)';

	/// en: 'Yaesu FT-891'
	String get ft891 => 'Yaesu FT-891';

	/// en: 'Yaesu FT-991/A'
	String get ft991a => 'Yaesu FT-991/A';

	/// en: 'Yaesu FT-710'
	String get ft710 => 'Yaesu FT-710';

	/// en: 'Yaesu FTDX10'
	String get ftdx10 => 'Yaesu FTDX10';

	/// en: 'Yaesu FTX-1'
	String get ftx1 => 'Yaesu FTX-1';

	/// en: 'Yaesu FT-817 / FT-818'
	String get ft817 => 'Yaesu FT-817 / FT-818';

	/// en: 'Yaesu FT-857'
	String get ft857 => 'Yaesu FT-857';

	/// en: 'Yaesu FT-897'
	String get ft897 => 'Yaesu FT-897';

	/// en: 'Yaesu FT-450 / FT-450D'
	String get ft450 => 'Yaesu FT-450 / FT-450D';

	/// en: 'Guohetec Q900'
	String get q900 => 'Guohetec Q900';

	/// en: 'Ten-Tec Eagle (599)'
	String get tenTecEagle => 'Ten-Tec Eagle (599)';

	/// en: 'Ten-Tec Orion (565)'
	String get tenTecOrion => 'Ten-Tec Orion (565)';

	/// en: 'Ten-Tec Orion II (566)'
	String get tenTecOrionII => 'Ten-Tec Orion II (566)';

	/// en: 'SOTAcat (Elecraft KX2/KX3)'
	String get sotacat => 'SOTAcat (Elecraft KX2/KX3)';

	/// en: 'Yaesu - Generic'
	String get yaesuGeneric => 'Yaesu - Generic';

	/// en: 'Icom - Generic'
	String get icomGeneric => 'Icom - Generic';

	/// en: 'Kenwood - Generic'
	String get kenwoodGeneric => 'Kenwood - Generic';

	/// en: 'Kenwood TS-590SG'
	String get ts590sg => 'Kenwood TS-590SG';

	/// en: 'Kenwood TS-480'
	String get ts480 => 'Kenwood TS-480';

	/// en: 'QRP Labs QMX'
	String get qmx => 'QRP Labs QMX';

	/// en: 'BG2FX FX-4CR'
	String get fx4cr => 'BG2FX FX-4CR';

	/// en: 'Lab599 TX-500'
	String get tx500 => 'Lab599 TX-500';

	/// en: 'Lab599 TX-500MP'
	String get tx500mp => 'Lab599 TX-500MP';

	/// en: 'QRP Labs QCX'
	String get qcx => 'QRP Labs QCX';

	/// en: 'Elecraft - Generic'
	String get elecraftGeneric => 'Elecraft - Generic';

	/// en: 'Elecraft KX2'
	String get kx2 => 'Elecraft KX2';

	/// en: 'Elecraft KX3'
	String get kx3 => 'Elecraft KX3';

	/// en: 'Elecraft K4'
	String get k4 => 'Elecraft K4';

	/// en: 'Icom IC-705'
	String get ic705 => 'Icom IC-705';

	/// en: 'Icom IC-7300'
	String get ic7300 => 'Icom IC-7300';

	/// en: 'Icom IC-7300 MK2'
	String get ic7300mk2 => 'Icom IC-7300 MK2';

	/// en: 'Icom IC-706MKIIG'
	String get ic706mkiig => 'Icom IC-706MKIIG';

	/// en: 'Icom IC-7100'
	String get ic7100 => 'Icom IC-7100';

	/// en: 'Icom IC-7610'
	String get ic7610 => 'Icom IC-7610';

	/// en: 'Icom IC-7760'
	String get ic7760 => 'Icom IC-7760';

	/// en: 'Icom IC-9700'
	String get ic9700 => 'Icom IC-9700';

	/// en: 'Icom IC-905'
	String get ic905 => 'Icom IC-905';

	/// en: 'Icom IC-7850'
	String get ic7850 => 'Icom IC-7850';

	/// en: 'Icom IC-7851'
	String get ic7851 => 'Icom IC-7851';

	/// en: 'Xiegu X6100'
	String get x6100 => 'Xiegu X6100';

	/// en: 'Xiegu G90'
	String get g90 => 'Xiegu G90';

	/// en: 'Radio controlled via rigctld'
	String get rigctld => 'Radio controlled via rigctld';

	/// en: 'My Radio (via rigctld)'
	String get rigctldNodeName => 'My Radio (via rigctld)';

	/// en: 'Radio controlled via flrig'
	String get flrig => 'Radio controlled via flrig';

	/// en: 'My Radio (via flrig)'
	String get flrigNodeName => 'My Radio (via flrig)';

	/// en: 'Radio controlled via Ham Radio Deluxe®'
	String get hrd => 'Radio controlled via Ham Radio Deluxe®';

	/// en: 'My Radio (via HRD)'
	String get hrdNodeName => 'My Radio (via HRD)';

	/// en: 'Radio controlled via N3FJP'
	String get n3fjp => 'Radio controlled via N3FJP';

	/// en: 'My Radio (via N3FJP)'
	String get n3fjpNodeName => 'My Radio (via N3FJP)';

	/// en: 'Radio controlled via DXLab Commander'
	String get commander => 'Radio controlled via DXLab Commander';

	/// en: 'My Radio (via Commander)'
	String get commanderNodeName => 'My Radio (via Commander)';

	/// en: 'Antenna'
	String get antenna => 'Antenna';

	/// en: 'CW Key'
	String get key => 'CW Key';

	/// en: 'WinKeyer'
	String get winkeyer => 'WinKeyer';

	/// en: 'Generic Radio (Placeholder)'
	String get placeholderRadio => 'Generic Radio (Placeholder)';

	/// en: 'My Radio'
	String get placeholderRadioNodeName => 'My Radio';

	/// en: '4O3A Antenna Genius'
	String get antennaGenius => '4O3A Antenna Genius';

	/// en: 'Sierra Radio CX-1 Coax Switch'
	String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';

	/// en: 'RTL-SDR'
	String get rtlSdr => 'RTL-SDR';

	/// en: 'Nooelec NESDR'
	String get nesdr => 'Nooelec NESDR';

	/// en: 'SDRplay RSP'
	String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class Translations$settings$station$transports$en {
	Translations$settings$station$transports$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Network/WiFi'
	String get network => 'Network/WiFi';

	/// en: 'Secure Network/WiFi'
	String get secureNetwork => 'Secure Network/WiFi';

	/// en: 'USB Serial'
	String get usbSerial => 'USB Serial';

	/// en: 'Network/WiFi'
	String get wifi => 'Network/WiFi';

	/// en: 'Bluetooth Serial'
	String get bluetoothSerial => 'Bluetooth Serial';

	/// en: 'Bluetooth LE'
	String get bleSerial => 'Bluetooth LE';

	/// en: 'Placeholder'
	String get placeholder => 'Placeholder';
}

// Path: settings.station.antennaTypes
class Translations$settings$station$antennaTypes$en {
	Translations$settings$station$antennaTypes$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Dipole'
	String get dipole => 'Dipole';

	/// en: 'Vertical'
	String get vertical => 'Vertical';

	/// en: 'Yagi / Beam'
	String get yagiBeam => 'Yagi / Beam';

	/// en: 'Loop'
	String get loop => 'Loop';

	/// en: 'Long Wire / EFHW'
	String get longWire => 'Long Wire / EFHW';

	/// en: 'Other'
	String get other => 'Other';
}

// Path: settings.station.keyTypes
class Translations$settings$station$keyTypes$en {
	Translations$settings$station$keyTypes$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Straight Key'
	String get straight => 'Straight Key';

	/// en: 'Sideswiper'
	String get sideswiper => 'Sideswiper';

	/// en: 'Bug (mechanical semi-automatic)'
	String get bug => 'Bug (mechanical semi-automatic)';

	/// en: 'Fully-automatic keyer'
	String get fullyAutomatic => 'Fully-automatic keyer';

	/// en: 'Single Paddle'
	String get singlePaddle => 'Single Paddle';

	/// en: 'Dual Paddle'
	String get dualPaddle => 'Dual Paddle';

	/// en: 'Computer Driven'
	String get computerDriven => 'Computer Driven';

	/// en: 'Other'
	String get other => 'Other';
}

// Path: operation.layout.panels.weatherConditions
class Translations$operation$layout$panels$weatherConditions$en {
	Translations$operation$layout$panels$weatherConditions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unknown'
	String get unknown => 'Unknown';

	/// en: 'Sunny'
	String get sunny => 'Sunny';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Mainly Sunny'
	String get mainlySunny => 'Mainly Sunny';

	/// en: 'Mainly Clear'
	String get mainlyClear => 'Mainly Clear';

	/// en: 'Partly Cloudy'
	String get partlyCloudy => 'Partly Cloudy';

	/// en: 'Cloudy'
	String get cloudy => 'Cloudy';

	/// en: 'Foggy'
	String get foggy => 'Foggy';

	/// en: 'Rime Fog'
	String get rimeFog => 'Rime Fog';

	/// en: 'Light Drizzle'
	String get lightDrizzle => 'Light Drizzle';

	/// en: 'Drizzle'
	String get drizzle => 'Drizzle';

	/// en: 'Heavy Drizzle'
	String get heavyDrizzle => 'Heavy Drizzle';

	/// en: 'Light Freezing Drizzle'
	String get lightFreezingDrizzle => 'Light Freezing Drizzle';

	/// en: 'Freezing Drizzle'
	String get freezingDrizzle => 'Freezing Drizzle';

	/// en: 'Light Rain'
	String get lightRain => 'Light Rain';

	/// en: 'Rain'
	String get rain => 'Rain';

	/// en: 'Heavy Rain'
	String get heavyRain => 'Heavy Rain';

	/// en: 'Light Freezing Rain'
	String get lightFreezingRain => 'Light Freezing Rain';

	/// en: 'Freezing Rain'
	String get freezingRain => 'Freezing Rain';

	/// en: 'Light Snow'
	String get lightSnow => 'Light Snow';

	/// en: 'Snow'
	String get snow => 'Snow';

	/// en: 'Heavy Snow'
	String get heavySnow => 'Heavy Snow';

	/// en: 'Snow Grains'
	String get snowGrains => 'Snow Grains';

	/// en: 'Light Showers'
	String get lightShowers => 'Light Showers';

	/// en: 'Showers'
	String get showers => 'Showers';

	/// en: 'Heavy Showers'
	String get heavyShowers => 'Heavy Showers';

	/// en: 'Light Snow Showers'
	String get lightSnowShowers => 'Light Snow Showers';

	/// en: 'Snow Showers'
	String get snowShowers => 'Snow Showers';

	/// en: 'Thunderstorm'
	String get thunderstorm => 'Thunderstorm';

	/// en: 'Light Thunderstorms With Hail'
	String get lightThunderstormsWithHail => 'Light Thunderstorms With Hail';

	/// en: 'Thunderstorm With Hail'
	String get thunderstormWithHail => 'Thunderstorm With Hail';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Save',
			'common.ok' => 'OK',
			'common.cancel' => 'Cancel',
			'common.delete' => 'Delete',
			'common.create' => 'Create',
			'common.error' => 'Error',
			'common.close' => 'Close',
			'common.done' => 'Done',
			'common.callsign' => 'Callsign',
			'common.clear' => 'Clear',
			'common.dismiss' => 'Dismiss',
			'common.expand' => 'Expand',
			'common.collapse' => 'Collapse',
			'onboarding.welcomeTitle' => 'Welcome to Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Welcome to Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'We have a few questions to help us better suit your needs.',
			'onboarding.skip' => 'Skip',
			'onboarding.kContinue' => 'Continue',
			'onboarding.back' => 'Back',
			'onboarding.next' => 'Next',
			'onboarding.done' => 'Done',
			'onboarding.callsignTitle' => 'What\'s your callsign?',
			'onboarding.callsignBody' => 'You need an Amateur Radio Operator License in order to find this app useful',
			'onboarding.callsignLabel' => 'Operator\'s Callsign',
			'onboarding.alreadyHaveAccount' => 'Already have an account?',
			'onboarding.foundSiblingTitle' => 'Link an existing account?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'We found ${app} on this device. Link this app to the same account and your callsign and logs come across.',
			'onboarding.foundPoloBody' => 'We found an older version of Ham2K Portable Logger on this device. Link this app to the same account and your callsign and logs come across.',
			'onboarding.foundSiblingsBody' => 'We found other Ham2K apps on this device. Link this app to one of their accounts and your callsign and logs come across.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Link with ${app}',
			'onboarding.linkWithPolo' => 'Link with account in older version',
			'onboarding.setUpFresh' => 'Set up fresh',
			'onboarding.activitiesTitle' => 'Favorite Activities',
			'onboarding.activitiesBody' => 'Are you interested in any of these popular activation programs?',
			'onboarding.activitiesFooter' => '(You can find more options in the Settings)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Data & Privacy',
			'onboarding.consentUsageBody' => 'To help us make the app better, we\'d like to collect performance, crash, and app usage data.',
			'onboarding.consentUsageLabel' => 'Share app usage data',
			'onboarding.consentOperationBody' => 'Some features might involve sharing your operation data with other users. You can opt-out at any time.',
			'onboarding.consentOperationLabel' => 'Share Operation Data',
			'onboarding.finishingSetup' => 'Finishing setup — downloading reference data…',
			'startScreen.credits' => 'by KI2D and friends',
			'testerOverlay.tape' => 'CAUTION: UNDER CONSTRUCTION',
			'testerOverlay.warningTitle' => 'This app is a work in progress',
			'testerOverlay.warningBody' => 'Most features have uneven surfaces and there are trip hazards all over. Please check for updates regularly.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'What\'s new in build ${build}',
			'testerOverlay.thanks' => 'Thank you for putting your log at risk in order to help us make this app better!',
			'extensionsPanel.categoryActivity' => 'Activities',
			'extensionsPanel.categoryAward' => 'Awards',
			'extensionsPanel.categoryContest' => 'Contests',
			'extensionsPanel.categoryLookup' => 'Callsign Lookups',
			'extensionsPanel.categorySpots' => 'Spot Sources',
			'extensionsPanel.categoryDashboard' => 'Dashboard Panels',
			'extensionsPanel.categoryOther' => 'Other Extensions',
			'extensionsPanel.searchHint' => 'Search extensions',
			'extensionsPanel.applying' => 'Activating extension changes, this may take a moment…',
			'extensionsPanel.noMatches' => 'No extensions match your search',
			'extensionsPanel.installFromFile' => 'Install from file…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Version ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Screenshot ${n} of ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Previous screenshot',
			'extensionsPanel.nextScreenshot' => 'Next screenshot',
			'extensionsPanel.screenshotUnavailable' => 'Screenshot unavailable',
			'extensionsPanel.canReach' => 'This extension can contact',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, over a live connection',
			'extensionsPanel.canHoldLocalConnection' => 'Devices on your local network, over a live connection',
			'extensionsPanel.canUseLocation' => 'Your location',
			'extensionsPanel.canReadRadio' => 'Your radio, to read its frequency and mode',
			'extensionsPanel.canControlRadio' => 'Your radio, to control it and to transmit with it — tuning, power, CW, voice memories and PTT',
			'extensionsPanel.canCommandRadioRaw' => 'Your radio, to send it any command in its own protocol — including ones that transmit or change its settings',
			'extensionsPanel.canReadCluster' => 'The DX cluster, logged in as you, to read what it sends',
			'extensionsPanel.canSpotCluster' => 'The DX cluster, logged in as you, to post spots in your name',
			'extensionsPanel.canCommandCluster' => 'The DX cluster, logged in as you, to send it any command in your name',
			'extensionsPanel.canSetUserAgent' => 'Identify itself to servers under its own name',
			'extensionsPanel.noCapabilities' => 'It asks for nothing outside the app.',
			'extensionsPanel.sandboxNote' => 'Extensions run sandboxed: no access to your files, and no network beyond what is listed here.',
			'extensionsPanel.installAction' => 'Install',
			'extensionsPanel.updateAction' => 'Update',
			'extensionsPanel.installFailed' => 'That extension could not be installed',
			'extensionsPanel.installedBadge' => 'Installed',
			'extensionsPanel.uninstallAction' => 'Remove',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Remove ${name}?',
			'extensionsPanel.uninstallBody' => 'This extension and its settings will be removed. Your logs will remain untouched.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'Installed ${name}',
			'extensionsPanel.installDownloading' => 'Downloading…',
			'extensionsPanel.installWaiting' => 'Waiting to install…',
			'extensionsPanel.installInstalling' => 'Installing…',
			'extensionsPanel.installAwaitingApproval' => 'Waiting for your approval…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} is already being installed.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Updated to ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Installing ${name} did not finish. It may need installing again.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Could not remove ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Downloaded from ${source}',
			'extensionsPanel.dropHint' => 'Drop a .h2kext extension to install it',
			'extensionsPanel.dropOneOnly' => 'Drop one extension at a time.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} returned ${status} for that extension.',
			'extensionsPanel.downloadTooLarge' => 'That download is far too large to be an extension.',
			'extensionsPanel.downloadNotSecure' => 'That download redirected somewhere insecure.',
			'extensionsPanel.catalogSection' => 'Catalog',
			'extensionsPanel.catalogLoading' => 'Loading the catalog…',
			'extensionsPanel.catalogUnreachable' => 'Catalog unreachable',
			'extensionsPanel.builtIn' => 'Built in',
			'extensionsPanel.updateAvailableBadge' => 'Update available',
			'extensionsPanel.updatesAvailableTitle' => 'Extension updates',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'An update is available for ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} and ${count} more need updating.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} need updating.',
			'extensionsPanel.pendingUpdatesSection' => 'Pending Updates',
			'extensionsPanel.updateAllAction' => 'Update all',
			'extensionsPanel.updatesUnderWay' => 'Those updates are already under way.',
			'extensionsPanel.updatesNothingLeft' => 'Your extensions are up to date.',
			'extensionsPanel.updatesNoticeAction' => 'More info',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Update ${count} extension?', other: 'Update ${count} extensions?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Your extensions are ready',
			'extensionsPanel.upgradeDoneBody' => 'They now come from the Ham2K extension catalog, so they can be updated without waiting for a new version of the app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Not upgraded: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Would not run: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'They are still installed and marked in Settings › Extensions — updating them there will bring them back.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'The catalog has no direct replacement for these, so look there for extensions that cover what you used.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'State Parks Events',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} of your extensions have not arrived yet. They will be downloaded the next time the extension catalog can be reached.',
			'extensionsPanel.runtimeDeadBody' => 'Your extensions would not start. Restarting the app should bring them back.',
			'extensionsPanel.refusedTitle' => 'Some extensions would not run',
			'extensionsPanel.upgradeBusyTitle' => 'Still setting up',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Your extensions are not running',
			'extensionsPanel.restoreTitle' => 'Some of your extensions are missing',
			'extensionsPanel.restoreBody' => 'These extensions you installed are not on this device. We can download them again from the Ham2K extension catalog:',
			'extensionsPanel.restoreFromFile' => 'Installed from a file. Install these again from their files, or forget them:',
			'extensionsPanel.restoreOtherCatalog' => 'Installed from a different extension catalog, so they are not available here:',
			'extensionsPanel.restoreForget' => 'Forget',
			'extensionsPanel.restoreInstall' => 'Install',
			'extensionsPanel.restoreLater' => 'Later',
			'extensionsPanel.restoreInstalling' => 'Installing your extensions…',
			'extensionsPanel.restoreDoneTitle' => 'Your extensions are back',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Installed again: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Some extensions could not be installed',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Could not install: ${names}. We will offer them again next time you open the app.',
			'extensionsPanel.restoreBusyBody' => 'The app is still setting your extensions up. We will offer these again next time you open the app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'We installed them again, but your extensions would not start. Restarting the app should bring them back.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} was withdrawn',
			'extensionsPanel.revokedBody' => 'The catalog withdrew this version, so it has been disabled.',
			'extensionsPanel.downloadHashMismatch' => 'That download is not the extension the catalog described.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'The catalog has no version ${version} of ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'That catalog link does not name an extension version.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'The catalog has no release of ${key} on that track.',
			'extensionsPanel.installFromLink' => 'Install from link',
			'extensionsPanel.unstableReleaseWarning' => 'This is an unstable release, which its publisher has not called finished. It may misbehave, and it will keep receiving unstable updates.',
			'extensionsPanel.bleedingReleaseWarning' => 'This is a bleeding-edge release: work in progress that may break or lose its settings. It will keep receiving bleeding-edge updates.',
			'extensionsPanel.channelUnstable' => 'Unstable',
			'extensionsPanel.channelBleeding' => 'Bleeding',
			'extensionsPanel.followsUnstable' => 'Receives unstable and stable releases',
			'extensionsPanel.followsBleeding' => 'Receives bleeding-edge, unstable and stable releases',
			'extensionsPanel.followStableAction' => 'Follow stable releases only',
			'extensionsPanel.revokedBadge' => 'Revoked',
			'extensionsPanel.refusedBadge' => 'Did not load',
			'extensionsPanel.downloadNotHttps' => 'That download is not over a secure connection.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} could not be reached for that extension.',
			'extensionsPanel.detailsAction' => 'Details',
			'extensionsPanel.installedFromFile' => 'Installed from a file',
			'extensionsPanel.detailsWhatItDoes' => 'Provides support for',
			'extensionsPanel.installedPreloaded' => 'Pre-installed',
			'extensionsPanel.hookAccount' => 'Account sign-in',
			'extensionsPanel.hookCallNotes' => 'Call notes',
			'extensionsPanel.hookDataFile' => 'Offline data',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Callsign lookups',
			'extensionsPanel.hookScoring' => 'Scoring',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Hunting ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Activating ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '… and ${count} other extension', other: '… and ${count} other extensions', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} extension available', other: '${count} extensions available', ), 
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'New operation',
			'home.stationCallsign' => 'Station callsign',
			'home.titleOptional' => 'Title (optional)',
			'home.emptyList' => 'No operations yet. Create one to start logging.',
			'home.quickLookup' => 'Quick Lookup',
			'home.nav.operations' => 'Operations',
			'home.nav.chase' => 'Chasing',
			'home.nav.logs' => 'Logs',
			'home.nav.maps' => 'Maps',
			'home.nav.settings' => 'Settings',
			'home.panels.operations' => 'Operation List',
			'home.panels.operationsDescription' => 'Your operations, most recent first.',
			'home.panels.version' => 'Current Version',
			'home.panels.versionDescription' => 'The Ham2K mark, this app’s name and which build you are running.',
			'home.toggleNav' => 'Show or hide the navigation labels',
			'home.logs.title' => 'Logs',
			'home.logs.titleFor' => 'Logs for',
			'home.logs.emptyCallsigns' => 'No QSOs logged yet',
			'home.logs.emptyQsos' => ({required Object call}) => 'No QSOs for ${call}',
			'home.logs.mapNoSelection' => 'Select a QSO to see it on the map',
			'home.logs.searchHint' => 'Search callsign or name',
			'home.logs.noSearchMatches' => 'No QSOs match your search',
			'home.logs.titleAll' => 'All Logs',
			'home.logs.allCallsigns' => 'All callsigns',
			'home.logs.noOperation' => 'Not part of an operation',
			'home.logs.unsavedTitle' => 'Unsaved changes',
			'home.logs.unsavedBody' => 'This QSO has changes you haven’t saved.',
			'home.logs.pendingDeleteBody' => 'This QSO is marked for deletion.',
			'home.logs.editGone' => 'Not saved: that QSO is no longer in this log.',
			'home.logs.discard' => 'Discard',
			'home.logs.sheet.callsigns' => 'Station Callsigns',
			'home.logs.sheet.groupBy' => 'Group By',
			'home.logs.sheet.period' => 'Time Period',
			'home.logs.groupBy.none' => 'Not grouped',
			'home.logs.groupBy.date' => 'Date',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Unknown continent',
			'home.logs.groupBy.unknownEntity' => 'Unknown entity',
			'home.logs.groupBy.unknownDate' => 'No date',
			'home.logs.period.thisMonth' => 'This month',
			'home.logs.period.last3Months' => 'Last 3 months',
			'home.logs.period.thisYear' => 'This year',
			'home.logs.period.lastYear' => 'Last year',
			'home.logs.period.allTime' => 'All time',
			'home.logs.period.custom' => 'Custom range',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'in ${span}',
			'home.logs.periodTitle.custom' => 'Custom Range',
			'home.logs.columns.date' => 'Date',
			'home.logs.columns.time' => 'Time',
			'home.logs.columns.freq' => 'Frequency',
			'home.logs.columns.mode' => 'Mode',
			'home.logs.columns.call' => 'Call',
			'home.logs.columns.name' => 'Name',
			'home.logs.columns.station' => 'Station',
			'home.logs.columns.band' => 'Band',
			'home.logs.columns.sent' => 'Sent',
			'home.logs.columns.rcvd' => 'Rcvd',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'State',
			'home.logs.columns.country' => 'Country',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'QSO Log',
			'home.logs.panels.qsosDescription' => 'The selected callsign\'s QSOs, across every operation.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Total QSO count, or the selected QSO\'s callsign lookup.',
			'home.logs.panels.map' => 'Map',
			'home.logs.panels.mapDescription' => 'The selected QSO\'s location.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Callsigns: ${calls}',
			'home.logs.import.skippedOne' => '1 record could not be read',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} records could not be read',
			'home.logs.import.readingTitle' => 'Reading ADIF file…',
			'home.logs.import.checkingTitle' => 'Checking for duplicates…',
			'home.logs.import.importingTitle' => 'Importing QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} of ${total} checked',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} imported, out of ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'chasing',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} & more',
			'chase.station.title' => 'Chasing Station',
			'chase.station.stationLabel' => 'Station: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'No location',
			'chase.periodInline.today' => 'today',
			'chase.periodInline.thisWeek' => 'this week',
			'chase.periodInline.last14Days' => 'in the last 14 days',
			'chase.periodInline.thisMonth' => 'this month',
			'chase.periodStats.today' => 'Stats for today',
			'chase.periodStats.thisWeek' => 'Stats for this week',
			'chase.periodStats.last14Days' => 'Stats for last 14 days',
			'chase.periodStats.thisMonth' => 'Stats for this month',
			'chase.period.today' => 'Today',
			'chase.period.thisWeek' => 'This Week',
			'chase.period.last14Days' => 'Last 14 Days',
			'chase.period.thisMonth' => 'This Month',
			'chase.goals.title' => 'Chasing Goals',
			'chase.goals.remove' => ({required Object name}) => 'Stop chasing ${name}',
			'chase.goals.extensionsTitle' => 'More chasing programs',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Logging controls above the QSOs chased in the period.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'The callsign being logged, or the period\'s stats.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Stations spotted on the air, ready to chase.',
			'chase.panels.map' => 'Map',
			'chase.panels.mapDescription' => 'The period\'s QSOs and the station being logged.',
			'chase.claims.checking' => 'Checking QSOs for chasing',
			'chase.claims.rebuilding' => ({required Object program}) => 'Checking the log for ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} of ${total} QSOs',
			'chase.notice.newRef' => ({required Object program}) => 'New ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Probably new ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'New ${program} band',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Probably new ${program} band',
			'chase.notice.newMode' => ({required Object program}) => 'New ${program} mode',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Probably new ${program} mode',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} unconfirmed',
			'chase.alerts.title' => 'Alerts',
			'chase.alerts.newRef' => 'New reference',
			'chase.alerts.newBand' => 'New band',
			'chase.alerts.newMode' => 'New mode',
			'chase.alerts.unconfirmed' => 'Unconfirmed',
			'chase.checklists' => 'Chasing Progress',
			'chase.imports.importFrom' => ({required Object label}) => 'Import ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Import ${file} as',
			'chase.imports.dropHint' => 'Drop a file to import it into a chasing program',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'Imported ${count} ${program} entries from ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'Imported ${count} ${program} entries from ${file}, skipped ${skipped} it could not read',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} has nothing ${program} can import',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} could not read ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} could not read any of the ${skipped} records in ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'No chasing program imports ${file}',
			'dialogs.operationDetails' => 'Operation details',
			'dialogs.activities' => 'Activities',
			'dialogs.stationCallsign' => 'Station Callsign',
			'dialogs.multiStationIdentifier' => 'Multi-station identifier (numbers only)',
			'dialogs.notes' => 'Notes',
			'dialogs.deleteOperationTitle' => 'Delete Operation',
			'dialogs.purgeTestsTitle' => 'Purge Test Operations',
			'dialogs.purgeTestsBody' => 'This permanently deletes these Test Operations and their QSOs. It cannot be undone.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Plus ${count} test contact that belongs to no operation.', other: 'Plus ${count} test contacts that belong to no operation.', ), 
			'dialogs.purgeTestsAction' => 'Purge',
			'dialogs.syncAllTitle' => 'Replace this device\'s log?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL backs up and clears ${qsos} from this device, then downloads the account\'s log again from the server. The backup stays in this device\'s database.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} QSO has not been synced yet — the server never received it, and it will NOT come back.', other: '${n} QSOs have not been synced yet — the server never received them, and they will NOT come back.', ), 
			'dialogs.syncAllAction' => 'Wipe and Resync',
			'dialogs.receivedPurgesTitle' => 'Test Operations Removed Elsewhere',
			'dialogs.receivedPurgesBody' => 'These were deleted as Test Operations on another device. Remove them here too? This permanently deletes them and their QSOs, and cannot be undone.',
			'dialogs.receivedPurgesAction' => 'Remove',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Invalid callsign: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Invalid callsigns: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} has operated so far. ${typed} will be recorded for new contacts.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'No operator recorded so far. ${typed} will be recorded for new contacts.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'This operation already has contacts by ${calls}. ${typed} will only be recorded for new ones.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Also record ${typed} as the operator of the contact already logged', other: 'Also record ${typed} as the operator of all ${count} contacts already logged', ), 
			'dialogs.callChange.operatorSeveralStations' => 'When using multiple stations over the air, there\'s no support for separate operators',
			'dialogs.callChange.contactsUnreadable' => 'This operation\'s contacts could not be read, so changing a callsign here won\'t offer to update them',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'The contacts already logged could not be updated, so no changes were made: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} of ${planned} contacts were updated — the rest are no longer in this operation',
			'operation.deletedReadOnly' => 'This operation is deleted. Undelete it to log or make changes.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Clock',
			'operation.tabs.weather' => 'Weather',
			'operation.tabs.website' => 'Web Site',
			'operation.tabs.remoteScreen' => 'Remote Screen',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Radio',
			'operation.tabs.summaries' => 'Operation Summaries',
			'operation.positions.nobodyYet' => 'No other operating positions are sharing this operation yet.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Another position',
			'operation.positions.thisDevice' => 'Our operating position',
			'operation.positions.nameIn' => ' in ',
			'operation.positions.panelTitle' => 'Positions',
			'operation.positions.panelDescription' => 'What every operating position sharing this operation is logging right now.',
			'operation.stationCallsignNone' => 'No station callsign',
			'operation.titleNone' => 'No title',
			'operation.deleteOperation' => 'Delete operation',
			'operation.loggingControlsStale' => 'Activity fields may be out of date — reopen the operation to refresh them',
			'operation.locationNone' => 'Not set',
			'operation.generalOperation' => 'General Operation',
			'operation.titleFor' => ({required Object value}) => 'for ${value}',
			'operation.titleAt' => ({required Object value}) => 'at ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Now ${description}',
			'operation.testOperationSuffix' => 'Testing',
			'operation.menu.showRstFields' => 'Show RST fields',
			'operation.menu.showStateField' => 'Show State field',
			'operation.menu.showGridField' => 'Show Grid field',
			'operation.menu.showDeletedQsos' => 'Show deleted QSOs',
			'operation.menu.showDeletedOps' => 'Show deleted operations',
			'operation.menu.showQsoNumbers' => 'Show QSO Numbers',
			'operation.menu.lookupAllQsos' => 'Lookup all QSOs',
			'operation.menu.loggingSettingsTitle' => 'Logging Settings',
			'operation.menu.mapSettingsTitle' => 'Map Settings',
			'operation.menu.actionsSection' => 'Actions',
			'operation.layout.title' => 'Add a Panel',
			'operation.layout.availableSection' => 'Available panels',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} settings',
			'operation.layout.panelSettingsAction' => 'Panel Settings',
			'operation.layout.viewName' => 'Operation View',
			'operation.layout.viewOptions' => 'View layout options',
			'operation.layout.viewTitleBuiltIn' => 'This view is built into the app, and so is its name',
			'operation.layout.resetOptions' => 'Restore Defaults',
			'operation.layout.removePane' => 'Remove',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Restore ${panel} to its defaults?',
			'operation.layout.resetPaneConfirmBody' => 'Its title, header and size go back to the defaults. The rest of the layout stays as it is.',
			'operation.layout.resetViewConfirm' => 'Restore this view to its default layout?',
			'operation.layout.resetViewConfirmBody' => 'The panels go back to their default arrangement, and the view\'s options and every panel\'s go back to the defaults.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} Layout Settings',
			'operation.layout.paneTitle' => 'Title',
			'operation.layout.paneShowHeader' => 'Show header',
			'operation.layout.paneShowHeaderTabset' => 'Always shown while this pane shares a group — the header is how the others are reached',
			'operation.layout.paneInherit' => 'Same as the app',
			'operation.layout.searchHint' => 'Search panels',
			'operation.layout.noPanelsMatch' => 'No panel matches your search.',
			'operation.layout.nothingToAdd' => 'This view already has all possible panels',
			'operation.layout.addPanel' => ({required Object panel}) => 'Add ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Preview ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Extension "${name}" is missing',
			'operation.layout.missingExtensionEnable' => 'Enable',
			'operation.layout.missingExtensionInstall' => 'Install…',
			'operation.layout.missingExtensionWontRun' => 'This version won’t run. Update it in Settings › Extensions.',
			'operation.layout.missingExtensionUnavailable' => 'Not available in this app',
			'operation.layout.missingExtensionNotInCatalog' => 'Not in the catalog',
			'operation.layout.missingExtensionCatalogUnreachable' => 'Couldn’t reach the catalog. Try again',
			'operation.layout.missingExtensionFailed' => 'That didn’t work. Try again',
			'operation.layout.previewUnavailable' => 'This panel\'s preview image could not be shown.',
			'operation.layout.nestedPaneTitle' => 'More',
			'operation.layout.layouts.defaultName' => 'Default',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Layout ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Layout: ${name}',
			'operation.layout.layouts.menuNew' => 'New…',
			'operation.layout.layouts.menuExport' => 'Export…',
			'operation.layout.layouts.menuImport' => 'Import…',
			'operation.layout.layouts.menuTitle' => 'Layouts',
			'operation.layout.layouts.newTitle' => 'New Layout',
			'operation.layout.layouts.editTitle' => 'Edit Layout',
			'operation.layout.layouts.edit' => 'Edit',
			'operation.layout.layouts.duplicateCurrent' => 'Duplicate current layout',
			'operation.layout.layouts.startFromDefault' => 'Start from the default layout',
			'operation.layout.layouts.nameLabel' => 'Name',
			'operation.layout.layouts.descriptionLabel' => 'Description',
			'operation.layout.layouts.create' => 'Create',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'Save changes to "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'This layout has changes you haven’t saved.',
			'operation.layout.layouts.discard' => 'Discard',
			'operation.layout.layouts.deleteTitle' => 'Delete this layout?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'Are you sure you want to delete this "${name}" Layout?',
			'operation.layout.layouts.exportTitle' => 'Export Layout',
			'operation.layout.layouts.exportPick' => 'Panels to export',
			'operation.layout.layouts.tabSet' => 'Tab Set',
			'operation.layout.layouts.exportAction' => 'Export',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Layout saved to ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'Couldn\'t export the layout: ${error}',
			'operation.layout.layouts.importTitle' => 'Import Layout',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Made for the ${view} view: panels only that view has are left out.',
			'operation.layout.layouts.viewHome' => 'Home',
			'operation.layout.layouts.viewOperation' => 'Operation',
			'operation.layout.layouts.viewLogs' => 'Logs',
			'operation.layout.layouts.viewChase' => 'Chasing',
			'operation.layout.layouts.importAsNew' => 'As a new layout',
			'operation.layout.layouts.importReplace' => 'In place of this layout',
			'operation.layout.layouts.importAdd' => 'Added to this layout',
			'operation.layout.layouts.importAddHint' => 'The panels arrive in a new column on the right.',
			'operation.layout.layouts.importPick' => 'Panels to import',
			'operation.layout.layouts.importReplaceSettings' => 'Replace the settings of panels already set up here',
			'operation.layout.layouts.importAction' => 'Import',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} isn\'t a layout this app can read: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'the text isn’t valid YAML (line ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'it isn’t a Ham2K layout file',
			'operation.layout.layouts.problemNewerVersion' => 'it was written by a newer version of the app',
			'operation.layout.layouts.problemNoArrangement' => 'it holds no arrangement',
			'operation.layout.layouts.problemMalformed' => 'part of it doesn’t follow the layout format',
			'operation.layout.layouts.problemTooLarge' => 'it is too large',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'Couldn\'t open the file: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'Couldn\'t import the layout: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'Couldn\'t copy the layout: ${error}',
			'operation.layout.layouts.importNothing' => 'No panel picked, so nothing was imported.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'Left out: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'Kept ${panels}: the small-screen arrangement can’t do without it.',
			'operation.layout.layouts.notOffered' => 'Not available in this view',
			'operation.layout.layouts.alreadyPlaced' => 'Already in this layout',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Needs ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'Layout names couldn’t be read',
			'operation.layout.layouts.listRecoveredBody' => 'This view’s list of layouts could not be read. Every layout is still here, numbered in place of its name.',
			'operation.layout.editLayout' => 'Edit Layout',
			'operation.layout.saveLayout' => 'Save Layout',
			'operation.layout.revertLayout' => 'Discard layout changes',
			'operation.layout.done' => 'Done',
			'operation.layout.layoutUnreadableTitle' => 'Layout couldn\'t be read',
			'operation.layout.layoutUnreadableBody' => 'Your saved layout could not be read, so the default arrangement is showing instead. It won\'t be saved over your original until you choose to keep it.',
			'operation.layout.layoutUnreadableAction' => 'Use this layout',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} could not be displayed',
			'operation.layout.panelRenderRetry' => 'Try again',
			'operation.layout.panelActionFailed' => 'That panel action failed. Try again.',
			'operation.layout.panels.loggingDescription' => 'The log and the entry fields',
			'operation.layout.panels.infoDescription' => 'What we know about the station being worked',
			'operation.layout.panels.spotsDescription' => 'Spots from the clusters and activity programs',
			'operation.layout.panels.mapDescription' => 'Where the contacts are',
			'operation.layout.panels.summariesDescription' => 'The operation\'s stats and scores, in the sections and order you pick',
			'operation.layout.panels.summariesSections' => 'Sections and Order',
			'operation.layout.panels.summariesDays' => 'Each day',
			'operation.layout.panels.summariesReset' => 'Show all',
			'operation.layout.panels.summariesAllHidden' => 'Every section is hidden. Pick the ones to show in this panel\'s settings.',
			'operation.layout.panels.clockDescription' => 'A clock face, in any time zone',
			'operation.layout.panels.clockFace' => 'Face',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analog',
			'operation.layout.panels.clockZone' => 'Time Zone',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'This device',
			'operation.layout.panels.clockShowSeconds' => 'Show seconds',
			'operation.layout.panels.weatherDescription' => 'Conditions now and for the next eight hours, where you\'re operating',
			'operation.layout.panels.weatherUseOperationLocation' => 'Use the operation\'s location',
			'operation.layout.panels.weatherLocation' => 'Location',
			'operation.layout.panels.weatherLocationDescription' => 'A grid square (FN31pr) or lat,lon. Ignored while \'Use the operation\'s location\' is checked.',
			'operation.layout.panels.weatherNoLocation' => 'No location set. Give this panel a location in its settings, or place it inside an operation that has one.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Couldn\'t read the location ${location}. Use a grid square like FN31pr, or 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Couldn\'t reach Open-Meteo — no network? Will try again shortly.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo responded, but not with anything readable. Will try again shortly.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'gusts ${speed}',
			'operation.layout.panels.panelAgeNow' => 'just now',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} min ago', other: '${count} min ago', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} hr ago', other: '${count} hrs ago', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Unknown',
			'operation.layout.panels.weatherConditions.sunny' => 'Sunny',
			'operation.layout.panels.weatherConditions.clear' => 'Clear',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Mainly Sunny',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Mainly Clear',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Partly Cloudy',
			'operation.layout.panels.weatherConditions.cloudy' => 'Cloudy',
			'operation.layout.panels.weatherConditions.foggy' => 'Foggy',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Rime Fog',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Light Drizzle',
			'operation.layout.panels.weatherConditions.drizzle' => 'Drizzle',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Heavy Drizzle',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Light Freezing Drizzle',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Freezing Drizzle',
			'operation.layout.panels.weatherConditions.lightRain' => 'Light Rain',
			'operation.layout.panels.weatherConditions.rain' => 'Rain',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Heavy Rain',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Light Freezing Rain',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Freezing Rain',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Light Snow',
			'operation.layout.panels.weatherConditions.snow' => 'Snow',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Heavy Snow',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Snow Grains',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Light Showers',
			'operation.layout.panels.weatherConditions.showers' => 'Showers',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Heavy Showers',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Light Snow Showers',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Snow Showers',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Thunderstorm',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Light Thunderstorms With Hail',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Thunderstorm With Hail',
			'operation.layout.panels.websiteDescription' => 'A web page of your choosing, in a pane',
			'operation.layout.panels.websiteUrl' => 'Address',
			'operation.layout.panels.websiteRefresh' => 'Refresh',
			'operation.layout.panels.websiteRefreshNever' => 'Never',
			'operation.layout.panels.websiteRefresh1' => 'Every minute',
			'operation.layout.panels.websiteRefresh5' => 'Every 5 minutes',
			'operation.layout.panels.websiteRefresh15' => 'Every 15 minutes',
			'operation.layout.panels.websiteTitle' => 'Panel Name',
			'operation.layout.panels.websiteRefreshNow' => 'Refresh Now',
			'operation.layout.panels.websiteNoUrl' => 'No address yet. Open this panel’s settings to choose a page.',
			'operation.layout.panels.websiteBadUrl' => 'That doesn’t look like a web address. It needs to start with https://',
			'operation.layout.panels.websiteNotHttps' => 'Only https:// addresses can be shown here.',
			'operation.layout.panels.websiteUnsupported' => 'Web pages can’t be shown in a panel on this system.',
			'operation.layout.panels.websiteOpenExternally' => 'Open in Browser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Couldn’t load the page: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'A screen, app or window shared by another of your devices.',
			'operation.layout.panels.remoteScreenTarget' => 'Screen',
			'operation.layout.panels.remoteScreenChoose' => 'Choose a screen…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Shared Screens',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'None of your devices is sharing a screen. Turn Share screens and windows on under Settings → Peer Devices, on the device you want to see.',
			'operation.layout.panels.remoteScreenUnset' => 'No screen chosen. Open this panel\'s settings to pick one your other devices are sharing.',
			'operation.layout.panels.remoteScreenConnecting' => 'Connecting…',
			'operation.layout.panels.remoteScreenPeerAway' => 'That device isn\'t connected right now.',
			'operation.layout.panels.remoteScreenNotOffered' => 'That device stopped sharing this screen.',
			'operation.layout.panels.remoteScreenNoListener' => 'That device can\'t accept connections — check its firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Screens are only shared over the local network, not Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'That device wouldn\'t share this screen.',
			'operation.layout.panels.remoteScreenSettings' => 'Panel settings',
			'operation.layout.panels.remoteScreenAdjust' => 'Adjust View',
			'operation.layout.panels.remoteScreenDetail' => 'Detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'High',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximum',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Zoom in',
			'operation.layout.panels.remoteScreenZoomOut' => 'Zoom out',
			'operation.layout.panels.remoteScreenStopped' => 'That screen or window is no longer being shown.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'That device couldn\'t capture that screen — it may need Screen Recording permission.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'That device didn\'t respond. It may not have screen sharing turned on.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Couldn\'t open a connection for the picture. Check the firewall on this device.',
			'operation.layout.panels.solarDescription' => 'Solar and geomagnetic conditions, with band-by-band propagation',
			'operation.layout.panels.solarUnreachable' => 'Couldn\'t reach hamqsl.com — no network? Will try again shortly.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com responded, but not with a reading we could use. Will try again shortly.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Day',
			'operation.layout.panels.solarBandNight' => 'Night',
			'operation.layout.panels.solarBandGood' => 'Good',
			'operation.layout.panels.solarBandFair' => 'Fair',
			'operation.layout.panels.solarBandPoor' => 'Poor',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Sources: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'The connection is struggling — skipping frames.',
			'operation.layout.panels.remoteScreenStalled' => 'Frames stopped getting through — this connection may be too slow.',
			'operation.layout.panels.radioDescription' => 'A radio\'s front panel — frequency, mode and power, under CAT control',
			'operation.layout.panels.radioStyle' => 'Style',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — no radio designated',
			'operation.layout.panels.radioNoRadio' => 'No radio to show. Pick one in this panel\'s settings, or add one under Station Configuration.',
			'operation.layout.panels.radioNotConfigured' => 'This radio is not configured yet. Choose its port or address under Station Configuration.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio not connected',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Connect this radio',
			'operation.layout.panels.radioDisconnect' => 'Disconnect this radio',
			'operation.layout.panels.radioStale' => 'NO DATA',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'high SWR',
			'operation.layout.htmlPanelUnsupported' => 'This panel needs a web view, which this platform does not provide',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'This panel needs a sandbox the web version cannot provide',
			'operation.export.title' => 'Operation Exports',
			'operation.export.syncedOperation' => 'Operation is synced',
			'operation.export.unsyncedOperation' => 'Operation has unsynced changes',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} QSO in this operation', other: '${count} QSOs in this operation', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'All ${total} QSOs are synced',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} of ${total} QSOs pending sync',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} event markers synced',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} of ${total} event markers pending',
			'operation.export.loading' => 'Loading export options…',
			'operation.export.noOptions' => 'No export formats available (extension runtime still starting?)',
			'operation.export.nothingLogged' => 'Nothing to export yet — this operation has no QSOs.',
			'operation.export.share' => 'Share',
			'operation.export.nothingSelected' => 'Nothing selected',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Save ${count} file', other: 'Save ${count} files', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Share ${count} file', other: 'Share ${count} files', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Export ${count} file', other: 'Export ${count} files', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Download ${count} file', other: 'Download ${count} files', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Save combined ${count} file', other: 'Save combined ${count} files', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Share combined ${count} file', other: 'Share combined ${count} files', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Export combined ${count} file', other: 'Export combined ${count} files', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Download combined ${count} file', other: 'Download combined ${count} files', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Save ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Share ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Export ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Download ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Stash ${count} file', other: 'Stash ${count} files', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Stash combined ${count} file', other: 'Stash combined ${count} files', ), 
			'operation.export.settingsButton' => 'Export settings',
			'operation.export.settingsTitle' => 'Export Settings',
			'operation.export.compactFileNames.title' => 'Use compact file names',
			'operation.export.compactFileNames.descriptionOn' => 'Short names built for uploaders, like N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Readable names, like 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Include private info',
			'operation.export.includePrivateData.descriptionOn' => 'Names, addresses, emails, gridsquares and notes are included',
			'operation.export.includePrivateData.descriptionOff' => 'Names, addresses, emails, gridsquares and notes are left out',
			'operation.export.includePrivateData.note' => 'The Full ADIF Export always includes everything',
			'operation.export.resultTitle' => 'Export complete',
			'operation.export.resultFailedTitle' => 'Export failed',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Exported ${count} file to ${path}', other: 'Exported ${count} files to ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Exported ${count} file: ${path}', other: 'Exported ${count} files: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Shared ${count} file', other: 'Shared ${count} files', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Downloaded ${count} file', other: 'Downloaded ${count} files', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export failed: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Add an email address first',
			'operation.export.stash.needsEmailBody' => 'Ham2K’s File Stash sends your files to the email address on your LoFi account, and you sign in with it at stash.ham2k.net. Your account doesn’t have a confirmed one yet — add it in Settings › Cloud Sync.',
			'operation.export.stash.openSyncSettings' => 'Open Cloud Sync',
			'operation.export.stash.replaceTitle' => 'Recent stash will be replaced',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'You sent “${name}” less than 6 hours ago and it hasn’t been downloaded yet. Free accounts keep one stash at a time, so sending now replaces it.',
			'operation.export.stash.replaceConfirm' => 'Send Anyway',
			'operation.export.stash.failedTitle' => 'Couldn’t send to Ham2K’s File Stash',
			'operation.export.stash.sentTitle' => 'Sent to Ham2K’s File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'You can retrieve this file by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.', other: 'You can retrieve these files by visiting **[stash.ham2k.net](https://stash.ham2k.net)** on any browser.', ), 
			'operation.export.stash.mayHaveArrived' => 'No answer from the stash — the file may have arrived anyway. Check stash.ham2k.net before sending again',
			'operation.export.stash.notSent' => 'not sent',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'This file didn’t arrive:', other: 'These ${count} files didn’t arrive:', ), 
			'operation.export.stash.emailOffer' => 'Or for your convenience, we can send you an email with a direct link.',
			'operation.export.stash.emailMe' => 'Email Me a Link',
			'operation.export.stash.emailSent' => 'We’ve emailed you a download link.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Couldn’t send the email: ${error}',
			'operation.export.stash.freeTier' => 'Free accounts can only keep one stash at a time. Subscribers can keep as many as they want.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Sent ${count} file to Ham2K’s File Stash (stash.ham2k.net)', other: 'Sent ${count} files to Ham2K’s File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'No spots match your filters',
			'operation.spots.error' => ({required Object error}) => 'Failed to load spots: ${error}',
			'operation.spots.unknownBand' => 'Other',
			'operation.spots.auto' => 'Automatic',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatic (Currently ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Any',
			'operation.spots.allBands' => 'All Bands',
			'operation.spots.allModes' => 'All Modes',
			'operation.spots.phoneAndCw' => 'Phone & CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Showing ${count} of ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutes',
			'operation.spots.callsOfNote' => 'Calls of Note',
			'operation.spots.yourSpots' => 'Your Spots',
			'operation.spots.allSpots' => 'All Spots',
			'operation.spots.continents.af' => 'Africa',
			'operation.spots.continents.as' => 'Asia',
			'operation.spots.continents.eu' => 'Europe',
			'operation.spots.continents.na' => 'North America',
			'operation.spots.continents.oc' => 'Oceania',
			'operation.spots.continents.sa' => 'South America',
			'operation.spots.continents.an' => 'Antarctica',
			'operation.spots.filters.title' => 'Filter Spots',
			'operation.spots.filters.band' => 'Band',
			'operation.spots.filters.mode' => 'Mode',
			'operation.spots.filters.age' => 'Age',
			'operation.spots.filters.sources' => 'Sources',
			'operation.spots.filters.continent' => 'Continent',
			'operation.spots.filters.sorting' => 'Sorting',
			'operation.spots.filters.sortByTime' => 'By Spot Time',
			'operation.spots.filters.sortByFrequency' => 'By Frequency',
			'operation.spots.filters.sortByWanted' => 'Most Wanted',
			'operation.spots.filters.groupByBand' => 'Group by Band',
			'operation.spots.filters.groupCallsWithNotes' => 'Group Calls with Notes',
			'operation.spots.filters.alertingOnly' => 'Only Spots with Alerts',
			'operation.spots.filters.sourceNoReply' => 'No reply',
			'operation.spots.filters.sourceError' => 'Error',
			'operation.spots.unavailableTitle' => 'Spots unavailable',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} did not respond.',
			'operation.spots.failedTitle' => 'Spot source error',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} returned an error.',
			'operation.spots.slideLogIt' => 'Log it',
			'operation.spots.slideIgnore' => 'Ignore',
			'operation.spots.slideRestore' => 'Restore',
			'operation.spots.logConflict.title' => 'Logging panel is busy',
			'operation.spots.logConflict.editingBody' => 'You\'re editing a logged contact. Log this spot instead, or go back and finish the edit?',
			'operation.spots.logConflict.composingBody' => 'You\'ve started entering a contact. Log this spot instead, or go back and finish what you were typing?',
			'operation.spots.logConflict.goBack' => 'Go back',
			'operation.spots.logConflict.clearAndLog' => 'Clear and log spot',
			'operation.import.title' => 'Import Data into Operation',
			'operation.import.importAdifAction' => 'Import QSOs from ADIF',
			'operation.import.settingsButton' => 'Listen settings',
			'operation.import.settingsTitle' => 'Listen for Other Apps',
			'operation.import.protocolAddressLabel' => 'Address',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Enter a port between 1 and 65535',
			'operation.import.protocolAddressInvalid' => 'Enter a valid IP address (e.g. 127.0.0.1 or 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Receiving data',
			'operation.import.protocolStatusNoData' => 'No data received recently',
			'operation.import.protocolBindError' => ({required Object error}) => 'Couldn\'t start listening: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Incoming QSOs could not be saved and are being retried: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Any (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Broadcast Data tab → check "Enable Broadcasts" for contact info. Set IP address to 127.0.0.1 if running on this same computer, or 255.255.255.255 to broadcast on the current local network.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reporting tab → UDP Server section → check "Accept UDP requests". Set UDP Server to 127.0.0.1 if running on this same computer, or a multicast address such as 239.239.0.2, and use the same address in the configuration above in this app.',
			'operation.import.listenTitle' => 'Listen for QSOs from other apps',
			'operation.import.listenDescriptionOnN1mm' => 'Listening for N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Listening for WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Listening for N1MM+ and WSJT-X',
			'operation.import.listenDescriptionOff' => 'Off',
			'operation.import.addToOperationTitle' => 'Add to this operation',
			'operation.import.addToOperationDescriptionOn' => 'Captured QSOs are added to this operation as they arrive',
			'operation.import.addToOperationDescriptionOff' => 'Captured QSOs are held until you turn this on',
			'operation.import.pendingSectionTitle' => 'Captured QSOs',
			'operation.import.pendingEmpty' => 'Nothing captured yet',
			'operation.import.stationMismatch' => ({required Object call}) => 'Logged as ${call}, not this operation\'s station',
			'operation.import.discardAction' => 'Discard',
			'operation.import.gapDialogTitle' => 'Include earlier captures?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} more QSOs were captured earlier, before a gap in the data. Include them too?',
			'operation.import.gapDialogRecentOnly' => 'Just the recent ones',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Include all ${count}',
			'map.outlineIssue.link' => 'Issues?',
			'map.outlineIssue.title' => 'Report an outline issue',
			'map.outlineIssue.reference' => 'Which outline',
			'map.outlineIssue.severity' => 'How bad is it?',
			'map.outlineIssue.minor' => 'Minor nit',
			'map.outlineIssue.major' => 'Big deal',
			'map.outlineIssue.explanation' => 'What\'s wrong with it?',
			'map.outlineIssue.explanationHint' => 'What the outline gets wrong, and where',
			'map.outlineIssue.send' => 'Send',
			'map.outlineIssue.sending' => 'Sending your report — thanks',
			'map.outlineIssue.copy' => 'Copy report',
			'map.outlineIssue.notSent' => 'Couldn\'t send the report',
			'map.outlineIssue.copied' => 'Report copied',
			'map.outlineIssue.notCopied' => 'Couldn\'t copy the report',
			'map.outlinesDisclaimer' => 'Outlines are for reference only. Do your own research!',
			'map.outlinesCredit' => ({required Object sources}) => 'Outlines: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Boundaries: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Facilities: ${sources}',
			'map.fullCredits' => 'Full dataset credits',
			'map.fewerCredits' => 'Fewer credits',
			'map.emptyState' => 'No QSO locations yet.\nQSOs with a grid square, state, or country will show up here.',
			'map.unavailable' => 'The map isn\'t available right now.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Flat',
			'map.globe' => 'Globe',
			'map.zoomIn' => 'Zoom in',
			'map.zoomOut' => 'Zoom out',
			'map.resetNorth' => 'Reset to north up',
			'map.postcard.button' => 'Operation Postcard',
			'map.postcard.title' => ({required Object title}) => 'Postcard for ${title}',
			'map.postcard.portrait' => 'Portrait',
			'map.postcard.landscape' => 'Landscape',
			'map.postcard.square' => 'Square',
			'map.postcard.save' => 'Save…',
			'map.postcard.download' => 'Download',
			'map.postcard.share' => 'Share',
			'map.postcard.copy' => 'Copy',
			'map.postcard.copied' => 'Copied to the clipboard',
			'map.postcard.saved' => ({required Object path}) => 'Saved to ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Downloaded ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Saved ${count} images to ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Saved ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} had already been saved',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Downloading ${count} images — allow them if the browser asks',
			'map.postcard.mapLeftOut' => 'The map didn\'t load, so it was left out',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — the map didn\'t load, so it was left out',
			'map.postcard.continued' => ({required Object title}) => '${title} (continued)',
			'map.postcard.previousPage' => 'Previous page',
			'map.postcard.nextPage' => 'Next page',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Page ${page} of ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} Q', other: '${count} Qs', ), 
			'map.postcard.options' => 'Postcard Options',
			'map.postcard.bandLegend' => 'Show band legend',
			'map.postcard.grayline' => 'Show grayline',
			'map.postcard.sectionsAndOrder' => 'Summary Sections and Ordering',
			'map.postcard.sectionDays' => 'Each day',
			'map.postcard.reset' => 'Reset',
			'map.postcard.failed' => ({required Object error}) => 'Could not make the postcard: ${error}',
			'map.postcard.mapNotReady' => 'The map didn\'t finish loading. Check the connection and try again.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Could not save the postcard: ${error}',
			'map.postcard.copyFailed' => 'The clipboard didn\'t take the image. Try again.',
			'map.postcard.shareFailed' => 'Could not share the postcard. Try again.',
			'map.postcard.fileName' => 'postcard',
			'mapsView.title' => 'Maps',
			'mapsView.searchHint' => 'Search parks, summits and more',
			'mapsView.activities' => 'Activities',
			'mapsView.layers' => 'Layers',
			'mapsView.baseMap' => 'Base map',
			'mapsView.satellite' => 'Satellite (Esri)',
			'mapsView.facilities' => 'Park facilities',
			'mapsView.boundaries' => 'Boundaries',
			'mapsView.currentLocation' => 'Current location',
			'mapsView.noMatches' => ({required Object text}) => 'Nothing matches “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} Reference at ${where}', other: '${count} References at ${where}', ), 
			'mapsView.startOperation' => 'Start an operation with these references',
			'activitiesView.title' => 'Activities',
			'activitiesView.activitiesCountZero' => 'No Activities Selected',
			'activitiesView.activitiesCountOne' => '1 Activity',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Activities',
			'activitiesView.empty' => 'No activities yet — use Suggestions & Search below to add one',
			'activitiesView.removeActivity' => 'Remove',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Open ${name}',
			'activitiesView.editActivity' => 'Edit activity',
			'activitiesView.manageExtensions' => 'Manage Extensions',
			'activitiesView.manage' => 'Manage',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Activity Types: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Activity Types: ${first} and ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Activity Types: ${first}, ${second} and ${more} more',
			'activitiesView.reference' => 'Reference',
			'activitiesView.invalidReference' => 'Not valid',
			'activitiesView.duplicateReference' => 'Already added',
			'activitiesView.searchHint' => 'Search by name, reference or anything else…',
			'activitiesView.noSuggestions' => 'No matches',
			'activitiesView.noSuggestionsHint' => 'Search by reference name or number above',
			'activitiesView.noSuggestionsExample' => '(for example \'trail\' or \'4556\')',
			'activitiesView.allOptions' => 'Activity Types',
			'activitiesView.determiningLocation' => 'Determining current location…\nWaiting for GPS fix to find nearby references',
			'activitiesView.locationUnavailableTitle' => 'Location data not available',
			'activitiesView.locationDeniedTitle' => 'Location permission denied',
			'activitiesView.locationBlockedTitle' => 'Location permission blocked',
			'activitiesView.noNearbyReason' => 'Cannot determine nearby references',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Tap ${icon} to manually enter your location,\nor just search for references by name',
			'activitiesView.locationGrantAction' => 'Allow location access',
			'activitiesView.locationSettingsAction' => 'Open Settings',
			'activitiesView.locationSettingsUnavailable' => 'Allow location access in your system settings',
			'activitiesView.locationGrantRefused' => 'Still no location — the system said no again',
			'activitiesView.searchUnavailableTitle' => 'Activity search unavailable',
			'activitiesView.searchUnavailableReason' => 'No activity extension could run the search. Try again in a moment.',
			'activitiesView.emptySheet' => 'Use suggestions & search below to add one',
			'activitiesView.exports' => 'Exports',
			'activitiesView.exportLogs' => 'Export Logs',
			'activitiesView.tools' => 'Tools',
			'activitiesView.toolsTitle' => 'Operation Tools',
			'activitiesView.operationDetails' => 'Operation Details',
			'activitiesView.share' => 'Share',
			'activitiesView.archive' => 'Archive',
			'activitiesView.deleteOperation' => 'Delete Operation',
			'activitiesView.undeleteOperation' => 'Undelete Operation',
			'activitiesView.alreadySelected' => 'Already selected',
			'activitiesView.selected' => 'Selected',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} of ${count}',
			'activitiesView.previousPick' => 'Previous match',
			'activitiesView.nextPick' => 'Next match',
			'activitiesView.retiredReference' => 'Retired',
			'activitiesView.enableExtension' => ({required Object name}) => 'Enable ${name}',
			'activitiesView.enableExtensionHint' => 'This extension matches your search, but it is not currently enabled',
			'activitiesView.enableExtensionForRefHint' => 'This extension handles one of this operation\'s references, but it is not currently enabled',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} is not running',
			'activitiesView.extensionNotRunningHint' => 'This extension has been disabled, open Extension Settings for more info',
			'activitiesView.installExtension' => ({required Object name}) => 'Install ${name}',
			'activitiesView.installExtensionHint' => 'This extension matches your search, but it is not installed',
			'activitiesView.onlyCatalogMatches' => 'No matches\nSome extensions in the catalog might have results.\nInstall them in Activity Types below.',
			'activitiesView.setupUnavailable' => 'Could not load this activity\'s setup — try again from Manage',
			'activitiesView.controlsUnavailableTitle' => 'Activity controls unavailable',
			'activitiesView.controlsUnavailableReason' => 'Your references are safe, but editing them is unavailable right now.',
			'activitiesView.controlsUnavailableRetry' => 'Retry',
			'activitiesView.onlyDisabledMatches' => 'No matches\nSome available extensions might have results.\nEnable them in Activity Types below.',
			'activitiesView.onlyNotRunningMatches' => 'No matches\nSome extensions that might have results are not running.\nSee Activity Types below.',
			'activitiesView.mapToggle' => 'Map',
			'activitiesView.searchToggle' => 'Search',
			'activitiesView.addToOperation' => 'Add to Operation',
			'activitiesView.addToOperationShort' => 'Add to Op.',
			'activitiesView.mapEmptyState' => 'No results to show on the map',
			'activitiesView.mapEmptyStateHint' => 'Switch back to the list, or search for something else',
			'activitiesView.imports' => 'Imports',
			'loggingControls.timeUtc' => 'Time (UTC)',
			'loggingControls.date' => 'Date',
			'loggingControls.now' => 'Now',
			'loggingControls.manualTimeSettings' => 'Manual Time',
			'loggingControls.manualTimeIncrement' => 'Increment per QSO',
			'loggingControls.manualTimeIncrementNone' => 'None',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} minute', other: '${count} minutes', ), 
			'loggingControls.frequency' => 'Frequency',
			'loggingControls.mode' => 'Mode',
			'loggingControls.theirCall' => 'Their call',
			'loggingControls.noteField' => 'Note',
			'loggingControls.todoField' => 'Todo',
			'loggingControls.sent' => 'Sent',
			'loggingControls.rcvd' => 'Rcvd',
			'loggingControls.more' => 'More',
			'loggingControls.revert' => 'Revert',
			'loggingControls.undoDelete' => 'Undo delete',
			'loggingControls.restore' => 'Restore',
			'loggingControls.wipe' => 'Wipe',
			'loggingControls.undo' => 'Undo',
			'loggingControls.pendingDeleteTapWarning' => 'Tap the trashcan one more time to delete this QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Click the trashcan one more time to delete this QSO',
			'loggingControls.deletedQsoWarning' => 'Deleted QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Tap the trashcan one more time to delete this ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Click the trashcan one more time to delete this ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Deleted ${kind}',
			'loggingControls.timeControl' => 'Time',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Power',
			'loggingControls.notesControl' => 'Notes',
			'loggingControls.power' => 'Power',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Logging Controls',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot at ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} at ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Too late to spot ${call}',
			'loggingControls.spotNoFreq' => 'First set a frequency to spot',
			'loggingControls.spotComment' => 'Comment',
			'loggingControls.spottingAutoControl' => 'Auto re-spot',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Re-spot every ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Auto in ${time}. Stop?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto in ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto in ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto in ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Auto re-spot not started: the spot did not go through',
			'loggingControls.spotAutoMoved' => 'Auto re-spot not started: the frequency changed while spotting',
			'loggingControls.spotAutoStopped' => 'Auto re-spot stopped',
			'loggingControls.spotAutoLeftFreq' => 'Auto re-spot stopped: the frequency changed',
			'loggingControls.spotAutoNoFreq' => 'Auto re-spot stopped: the radio reports no frequency',
			'loggingControls.spotBusy' => 'Another spot is still being sent',
			'loggingControls.bandOrFreqRequired' => 'Set a frequency or band before logging',
			'loggingControls.missingBand' => 'No Band',
			'loggingControls.missingMode' => 'No Mode',
			'loggingControls.saveFailed' => ({required Object error}) => 'Could not save: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Could not delete: ${error}',
			'loggingControls.info.noQsos' => 'No QSOs yet... let\'s get on the air!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} since last',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h for last 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h for last 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} to',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} away',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Dupe!',
			'loggingControls.info.noticeNewBand' => 'New Band',
			'loggingControls.info.noticeNewMode' => 'New Mode',
			'loggingControls.info.noticeNewDXCC' => 'New DXCC',
			'loggingControls.info.noticeNewState' => 'New State',
			'loggingControls.info.noticeNewProvince' => 'New Province',
			'loggingControls.info.noticeNewDay' => 'New Day',
			'loggingControls.info.noticeNewRef' => 'New Ref',
			'loggingControls.info.noticeNewMult' => 'New Mult',
			'loggingControls.info.noticeNewZone' => 'New Zone',
			'loggingControls.info.noticeInvalidMode' => 'Wrong Mode',
			'loggingControls.info.noticeInvalidBand' => 'Wrong Band',
			'loggingControls.info.noticeInvalidCategory' => 'Not Workable',
			'loggingControls.info.noticeOverTime' => 'Time Over',
			'loggingControls.info.noticeWorkedBefore' => 'Worked Before',
			'loggingControls.info.noticeNewPark' => 'New Park',
			'loggingControls.info.noticeNewSection' => 'New Section',
			'loggingControls.info.noticeBonusStation' => 'Bonus Station!',
			'loggingControls.info.noticeMissingExchange' => 'No Exchange',
			'loggingControls.info.noticeInvalidExchange' => 'Bad Exchange',
			'loggingControls.info.noticeUnknownEvent' => 'Unknown Event',
			'loggingControls.info.noticeIncompleteCall' => 'Incomplete Call — Not Scored',
			'loggingControls.info.noticeOurGrid' => 'Set Our Grid',
			'loggingControls.info.noticeRareCounty' => 'Rare County!',
			'loggingControls.info.noticeOurLocation' => 'Set Our County',
			'loggingControls.info.noticeShortGrid' => 'Grid Too Short',
			'formChrome.untitled' => '(untitled)',
			'formChrome.showMore' => 'Show more',
			'formChrome.showAll' => 'Show all',
			'formChrome.showFewer' => 'Show fewer',
			'formChrome.defaults' => 'Defaults',
			'formChrome.search' => 'Search',
			'formChrome.clear' => 'Clear',
			'formChrome.openPage' => 'Open page',
			'formChrome.connected' => 'Connected',
			'formChrome.notConnected' => 'Not Connected',
			'formChrome.manage' => 'Manage',
			'formChrome.connect' => 'Connect',
			'formChrome.formTitle' => 'Form',
			'formChrome.addItem' => ({required Object label}) => 'Add ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Edit ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Showing ${shown} of ${total} (${selected} selected)',
			'formChrome.validationError' => ({required Object error}) => 'Validation error: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Transformation error: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Error: ${error}',
			'formChrome.removeItem' => 'Delete',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'Delete ${name}?',
			'formChrome.storageUnavailable' => 'Logins unavailable',
			'qsoEditForm.title' => 'Edit QSO',
			_ => null,
		} ?? switch (path) {
			'qsoEditForm.operatorCall' => 'Operator',
			'qsoEditForm.position' => 'Position',
			'qsoEditForm.theirName' => 'Name',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'State',
			'qsoEditForm.band' => 'Band',
			'qsoEditForm.notes' => 'Notes',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Their info',
			'qsoEditForm.sectionOur' => 'Our info',
			'qsoEditForm.sectionNotes' => 'Notes',
			'qsoEditForm.theirCity' => 'City',
			'qsoEditForm.theirCounty' => 'County',
			'qsoEditForm.theirEntity' => 'Entity',
			'qsoEditForm.theirCqZone' => 'CQ Zone',
			'qsoEditForm.theirItuZone' => 'ITU Zone',
			'qsoEditForm.theirArrlSection' => 'ARRL Section',
			'qsoEditForm.theirLat' => 'Latitude',
			'qsoEditForm.theirLon' => 'Longitude',
			'qsoEditForm.theirPower' => 'Their power',
			'qsoList.empty' => 'No QSOs yet — work someone!',
			'qsoList.bandOrModeWarning' => 'Please make sure your band and mode are correct',
			'qsoList.today' => 'Today',
			'qsoList.yesterday' => 'Yesterday',
			'qsoList.tomorrow' => 'Tomorrow',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Find in Log (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Find in Log',
			'qsoList.find.hint' => 'QSO number or callsign',
			'qsoList.find.noMatches' => 'No match',
			'qsoList.find.noOperationQsos' => 'No QSOs in this operation',
			'qsoList.find.noPeriodQsos' => 'No QSOs in this period',
			'qsoList.find.outsideQsosOne' => '1 QSO outside of this operation',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSOs outside of this operation',
			'qsoList.find.pastQsosOne' => '1 past QSO',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} past QSOs',
			'loggingPanel.stats' => 'Operation Stats',
			'loggingPanel.scoring' => 'Scoring',
			'loggingPanel.dxccEntities' => 'DXCC entities',
			'loggingPanel.statesWorked' => 'States',
			'loggingPanel.provincesWorked' => 'Provinces',
			'loggingPanel.duplicates' => 'Duplicates',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Show Image',
			'callInfo.imageUnavailable' => 'Photo unavailable',
			'callInfo.photo' => 'Photo',
			'callInfo.notes' => 'Notes',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} to',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) to',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} away',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) away',
			'callInfo.thisOpCountOne' => '1 QSO in this operation',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs in this operation',
			'callInfo.otherOpsCountOne' => '1 QSO in other operations',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs in other operations',
			'callInfo.andMore' => ({required Object count}) => '… and ${count} more',
			'callInfo.withCall' => ({required Object call}) => 'with ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'from ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} in last 7 days',
			'callInfo.history.today' => ({required Object n}) => '${n} today',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Settings',
			'settings.language' => 'Language',
			'settings.languageSystem' => ({required Object language}) => 'Follow system settings (${language})',
			'settings.theme.title' => 'Theme Mode',
			'settings.theme.system' => 'Follow system settings',
			'settings.theme.light' => 'Light',
			'settings.theme.dark' => 'Dark',
			'settings.themeDescription.system' => 'Following system settings',
			'settings.themeDescription.light' => 'Always in Light Mode',
			'settings.themeDescription.dark' => 'Always in Dark Mode',
			'settings.fontScale' => 'Font Scale',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Smallest--',
			'settings.fontScaleOpts.smallestMinus' => 'Smallest-',
			'settings.fontScaleOpts.smallest' => 'Smallest',
			'settings.fontScaleOpts.smaller' => 'Smaller',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Larger',
			'settings.fontScaleOpts.largest' => 'Largest',
			'settings.fontScaleOpts.largestPlus' => 'Largest+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Largest++',
			'settings.keepDeviceAwake.title' => 'Keep Device Awake',
			'settings.keepDeviceAwake.descriptionOn' => 'Staying awake while you are on the logging view or a sync is in progress',
			'settings.keepDeviceAwake.descriptionOff' => 'Sleeping as usual',
			'settings.layoutDensity' => 'Layout Density',
			'settings.layoutDensityOpts.auto' => 'Automatic',
			'settings.layoutDensityOpts.densest' => 'Densest',
			'settings.layoutDensityOpts.dense' => 'Dense',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Sparse',
			'settings.layoutDensityOpts.sparsest' => 'Sparsest',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'the window is too short, using ${effective}',
			'settings.layoutDensityAtLimit' => 'as far as it goes',
			'settings.distanceUnits' => 'Distance Units',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometers',
			'settings.distanceUnitsOpts.miles' => 'Miles',
			'settings.userInterface' => 'User Interface',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Leftie Mode',
			'settings.logging.leftieMode.descriptionOn' => 'Using layout for left-handed users',
			'settings.logging.leftieMode.descriptionOff' => 'Using layout for right-handed users',
			'settings.logging.countryFlags.title' => 'Country Flags',
			'settings.logging.countryFlags.dx' => 'Show only for DX contacts',
			'settings.logging.countryFlags.all' => 'Show flags for all contacts',
			'settings.logging.countryFlags.none' => 'Don\'t show any flags',
			'settings.logging.countryFlagsDescription.dx' => 'Showing flags only for DX contacts',
			'settings.logging.countryFlagsDescription.all' => 'Showing flags for all contacts',
			'settings.logging.countryFlagsDescription.none' => 'Not showing any flags',
			'settings.logging.suggestDefaultOperator.title' => 'Suggest Operator',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Offering your callsign as the operator when an operation runs under a different station callsign',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Leaving the operator blank unless you fill it in',
			'settings.logging.showBearing.title' => 'Show Bearing',
			'settings.logging.showBearing.descriptionOn' => 'Showing estimated bearing to station',
			'settings.logging.showBearing.descriptionOff' => 'Not showing bearing information',
			'settings.logging.showReverseBearing.title' => 'Also show reverse bearing',
			'settings.logging.showReverseBearing.descriptionOn' => 'Showing the bearing from the station too, as "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Only showing the bearing to the station',
			'settings.logging.switchSentRcvd.title' => 'Switch signal report order',
			'settings.logging.switchSentRcvd.sentFirst' => 'Sent first, Rcvd second',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Rcvd first, Sent second',
			'settings.logging.jumpAfterRST.title' => 'Jump to next field on RST entry',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Jumping after RST is entered',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Not jumping automatically',
			'settings.logging.defaultReport.title' => 'Default report — Phone',
			'settings.logging.defaultReport.description' => 'Used when Sent or Rcvd is left empty on SSB, FM or AM',
			'settings.logging.defaultReportCW.title' => 'Default report — CW and data',
			'settings.logging.defaultReportCW.description' => 'Used when Sent or Rcvd is left empty on CW, RTTY and other data modes',
			'settings.logging.defaultReportFT8.title' => 'Default report — FT8 and FT4',
			'settings.logging.defaultReportFT8.description' => 'Used when Sent or Rcvd is left empty on the FT modes',
			'settings.logging.numbersRow.title' => 'Numbers Row',
			'settings.logging.numbersRow.description' => 'Show a row of number keys above the keyboard while logging',
			'settings.logging.numbersRowExtra.title' => 'Slash and period key',
			'settings.logging.numbersRowExtra.description' => 'Adds a contextual key: “/” for callsigns, “.” for numbers',
			'settings.logging.numbersRowVibrate.title' => 'Vibrate on key press',
			'settings.logging.numbersRowVibrate.description' => 'Haptic feedback when you tap a number key',
			'settings.logging.bands' => 'Preferred Bands',
			'settings.logging.modes' => 'Preferred Modes',
			'settings.catServer.title' => 'CAT Server',
			'settings.catServer.description' => 'Allow other apps (WSJT-X, loggers, etc) to control the radio through Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocol',
			'settings.catServer.protocolOpts.off' => 'Disabled',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Open access',
			'settings.catServer.openAccessOn' => 'Any computer on the local network can connect.',
			'settings.catServer.openAccessOff' => 'Only apps on this computer can connect.',
			'settings.catServer.off' => 'Off.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, starting…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} on port ${port}. Clients connected: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} on port ${port}, but no Main VFO radio is connected.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} cannot listen on port ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: another program is using it, often ${protocol} itself. Close that program or choose another port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} cannot listen on port ${port}: this computer does not allow it. Choose a port above 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} stopped listening on port ${port}. Trying again…',
			'settings.cluster.title' => 'DX Cluster',
			'settings.cluster.description' => 'The server extensions post spots to and read spots from, logged in as the operator.',
			'settings.cluster.server' => 'Cluster Server',
			'settings.cluster.selectServer' => 'Select Server',
			'settings.cluster.serverOther' => 'Other',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'No host entered yet, so spots go to ${node}',
			'settings.cluster.customHost' => 'Server',
			'settings.cluster.customPort' => 'Port',
			'settings.cluster.password' => 'Password',
			'settings.cluster.passwordDescription' => 'Only if needed',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Password on file for ${node}',
			'settings.cluster.scrollback' => 'Lines kept',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} lines',
			'settings.cluster.connection' => 'Connection',
			'settings.cluster.statusIdle' => 'Not connected. Connects when an extension needs it. Tap to test.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Connecting to ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Connected to ${node} as ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'Could not connect to ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'Not available in the web version.',
			'settings.cluster.errors.noCall' => 'no operator callsign to log in with',
			'settings.cluster.errors.connectFailed' => 'the node could not be reached',
			'settings.cluster.errors.needsPassword' => 'the node asks for a password, and none is stored',
			'settings.cluster.errors.loginFailed' => 'the node did not accept the login',
			'settings.cluster.errors.disconnected' => 'the node closed the connection',
			'settings.cluster.errors.timeout' => 'the node did not answer',
			'settings.spotting.title' => 'Spotting',
			'settings.spotting.respotInterval' => 'Auto re-spot every',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Auto re-spot by default',
			'settings.spotting.autoRespotByDefaultOn' => 'Enable auto re-spot after any spot is posted',
			'settings.spotting.autoRespotByDefaultOff' => 'Require user action to enable auto re-spotting',
			'settings.spotting.pulseBeforeRespot' => 'Pulse before each auto re-spot',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'The Spotting chip pulses blue for the ${seconds} seconds before each re-spot',
			'settings.spotting.pulseBeforeRespotOff' => 'No pulsing before an auto re-spot',
			'settings.radio.title' => 'CAT Control',
			'settings.radio.loggingAndCat' => 'Logging & CAT',
			'settings.radio.tuningSection' => 'Tuning',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Services',
			'settings.radio.stationConfigurationSection' => 'Station Configuration',
			'settings.radio.moreSettings' => 'More station configuration settings',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Control PTT with [\']',
			'settings.radio.pttKey.descriptionOn' => 'In Phone modes, [\'] keys the radio and [\'] again unkeys it. It unkeys by itself after a minute.',
			'settings.radio.pttKey.descriptionOff' => 'The [\'] key does not key the radio.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Transmitting',
			'settings.radio.smartVfoSnap.title' => 'Smart VFO Snap',
			'settings.radio.smartVfoSnap.descriptionOn' => 'After you stop turning the dial, rounding the frequency to a sensible step. Voice modes only.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Staying exactly where you tuned it.',
			'settings.radio.snapDebounce.title' => 'Smart Snap: Settle delay',
			'settings.radio.snapDebounce.description' => 'How long the dial has to stop before the frequency is rounded. Shorter feels immediate; longer leaves room for a slow move.',
			'settings.radio.snapLongMove.title' => 'Smart Snap: Long move',
			'settings.radio.snapLongMove.description' => 'Move at least this far and the frequency rounds to a whole kHz, however slowly you finished.',
			'settings.radio.snapMinMove.title' => 'Smart Snap: Smallest move',
			'settings.radio.snapMinMove.description' => 'Move less than this and the frequency is not rounded, so fine tuning is left alone.',
			'settings.radio.snapMinSpeed.title' => 'Smart Snap: Slowest move',
			'settings.radio.snapMinSpeed.description' => 'Turn the dial slower than this and the frequency is not rounded, unless it was a long move.',
			'settings.radio.enterSends.pillOff' => 'ESM Off',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter sends messages',
			'settings.radio.enterSends.off' => 'Off',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter Sends Messages: ${state}. Tap to change.',
			'settings.radio.keyerSpeed.title' => 'Keyer speed',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW Keyer Messages',
			'settings.radio.cwMessages.notSupported' => 'Current radio does not support CW keying',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Message (${n})',
			'settings.radio.cwMessages.labelField' => 'Label',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n} label',
			'settings.radio.cwMessages.details' => 'Details',
			'settings.radio.cwMessages.empty' => '(empty)',
			'settings.radio.cwMessages.sets' => 'Message Set',
			'settings.radio.cwMessages.newSet' => 'New Set',
			'settings.radio.cwMessages.renameSet' => 'Rename Set',
			'settings.radio.cwMessages.deleteSet' => 'Delete Set',
			'settings.radio.cwMessages.newSetName' => 'Name',
			'settings.radio.cwMessages.setDefault' => 'Default',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM Messages',
			'settings.radio.cwMessages.setSaved' => 'My Messages',
			'settings.radio.cwMessages.repeat' => 'Repeat Message #1',
			'settings.radio.cwMessages.repeatOff' => 'No',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'After ${n} seconds',
			'settings.radio.cwMessages.repeatWait' => 'Repeating',
			'settings.radio.cwMessages.keyboard' => 'Type to send',
			'settings.radio.cwMessages.keyboardField' => 'Type to send',
			'settings.radio.cwMessages.closeArea' => 'Close the keyer area',
			'settings.radio.cwMessages.help' => 'Help',
			'settings.radio.cwMessages.helpTitle' => 'Writing CW Messages',
			'settings.radio.cwMessages.helpIntro' => 'Messages can use templates with the following values:',
			'settings.radio.cwMessages.helpOpCall' => 'Your callsign',
			'settings.radio.cwMessages.helpQsoCall' => 'Their callsign — in a // stack, the call that will be logged',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Their callsign, if there is a valid call; blank for a partial',
			'settings.radio.cwMessages.helpQsoPartial' => 'A partial call; blank if there is a full valid call',
			'settings.radio.cwMessages.helpQsoNextCall' => 'In a // stack, the call that will be selected for logging next, if there is a valid full call',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'In a // stack, the next partial after logging the current contact',
			'settings.radio.cwMessages.helpQsoName' => 'Their first name, as typed or else from the lookup',
			'settings.radio.cwMessages.helpQsoState' => 'Their state, as typed or else from the lookup',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Message 1 as it would be sent, inside another message. Valid for messages 1 through 8',
			'settings.radio.cwMessages.helpQsoRst' => 'The report you are sending',
			'settings.radio.cwMessages.helpQsoSerial' => 'Your serial number, in a contest that sends one',
			'settings.radio.cwMessages.helpPad' => 'Pads with zeros to that many digits: 7 is sent as 007',
			'settings.radio.cwMessages.helpCut' => 'Cut numbers, T for 0 and N for 9: 599 is sent as 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Chooses the digits to cut, in quotes — 0 is T, 1 is A, 5 is E, 9 is N',
			'settings.radio.cwMessages.helpFullExample' => 'Full example:',
			'settings.radio.cwMessages.helpExample' => 'Sends W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'With Enter Sends Messages on, Enter keys messages by their function key, as N1MM does. The ESM Messages set starts with these:',
			'settings.radio.cwMessages.helpEsmCq' => 'Running, Enter with the call field empty calls CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Your exchange: after their call when running, after they answer in S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Thanks, once the contact has logged: its placeholders name the next contact, not this one',
			'settings.radio.cwMessages.helpEsmMyCall' => 'In S&P, your call to the station you are answering',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Running, their call ahead of your exchange',
			'settings.radio.cwMessages.helpEsmAgain' => 'Asks again when nothing of their exchange was copied',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Suggested F3 for // stacks: TU goes out after the contact logs, so it thanks, then calls the next stacked station and sends your exchange, or asks a partial back (TU KR?); with nothing left, just TU',
			'settings.radio.voiceMessages.title' => 'Phone Keyer Messages',
			'settings.radio.voiceMessages.notSupported' => 'Current radio does not support Phone messages',
			'settings.radio.voiceMessages.description' => 'This uses the radio\'s voice memories',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Voice memory (${n})',
			'settings.radio.voiceMessages.labelField' => 'Label',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Voice memory ${n} label',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Empty',
			'settings.radio.voiceMessages.notMeasured' => 'Unknown length',
			'settings.radio.voiceMessages.playButton' => 'Play',
			'settings.radio.voiceMessages.recordButton' => 'Record',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Repeat Message #1',
			'settings.radio.voiceMessages.repeatOff' => 'No',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'After ${n} seconds',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} Notes:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'These memories are in ${device}\'s radio. Their names and lengths belong to that device.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Saved in the radio, where its other clients see it too.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Wait for the [REC] indicator on the radio, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Wait for the [REC] indicator to blink at least four times, then hold the PTT button and record your message. End it by pressing the STOP button here in the app before releasing PTT to avoid unwanted clicks.',
			'settings.radio.voiceMessages.pill' => 'Voice',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Play memory ${n}',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Record memory ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Stop recording',
			'settings.radio.voiceMessages.playing' => 'Playing…',
			'settings.radio.voiceMessages.recording' => 'Recording…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Playing ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Recording ${label}',
			'settings.radio.voiceMessages.doubtful' => 'Did the radio play it? It said it was idle right away.',
			'settings.radio.voiceMessages.recordOnRadio' => 'You have to record the memories on the radio itself.',
			'settings.radio.avoidZeroBeat.title' => 'Avoid Zero-Beating on Spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'With a radio connected, tuning a few Hz off a CW spot, so everyone answering it isn’t calling on the same note.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Tuning exactly to the spotted frequency.',
			'settings.radio.zeroBeatRange.title' => 'Zero-Beat: Avoidance range',
			'settings.radio.zeroBeatRange.description' => 'How far off the spotted frequency to land, either side. The offset is never near zero — that would be a zero beat again.',
			'settings.help.title' => 'Help & Resources',
			'settings.help.description' => 'Community and support',
			'settings.help.forums' => 'Ham2K Forums',
			'settings.help.forumsDescription' => 'Find help, give feedback, discuss ideas…',
			'settings.help.chat' => 'Ham2K Chat',
			'settings.help.chatDescription' => 'The Discord server for our online community',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videos and live streams',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Because you cannot have too many photos…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Follow us for news and updates',
			'settings.help.contact' => 'Contact Us',
			'settings.help.contactDescription' => 'help@ham2k.com — but try the Forums or Chat first!',
			'settings.exports.title' => 'Exports',
			'settings.extensionSections.activities' => 'Activities',
			'settings.extensionSections.hunting' => 'Hunting',
			'settings.extensionSections.contests' => 'Contests',
			'settings.extensionSections.lookups' => 'Lookups',
			'settings.extensionSections.dashboard' => 'Dashboard',
			'settings.map.title' => 'Maps',
			'settings.map.style.title' => 'Map Style',
			'settings.map.showCallsigns.title' => 'Show Callsigns',
			'settings.map.showCallsigns.description' => 'Each contact is a pill with its callsign, in its band\'s color',
			'settings.map.showGrayline.title' => 'Show Grayline',
			'settings.map.showGrayline.description' => 'Shades the night side of the Earth, with twilight as a gradient',
			'settings.map.styleOpts.automatic' => 'Automatic',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacy',
			'settings.privacy.shareAppData.title' => 'Share app usage data',
			'settings.privacy.shareAppData.descriptionOn' => 'Helping us improve the app by sharing usage, configuration, crash and performance data',
			'settings.privacy.shareAppData.descriptionOff' => 'Keeping app usage data private.\nThe Ham2K team won\'t be able to detect crashes or other issues.',
			'settings.privacy.shareOpData.title' => 'Share operation data',
			'settings.privacy.shareOpData.descriptionOn' => 'Sharing some operation data publicly and with other users',
			'settings.privacy.shareOpData.descriptionOff' => 'Keeping operation data private',
			'settings.privacy.privacyPolicy' => 'Privacy Policy',
			'settings.privacy.termsOfService' => 'Terms of Service',
			'settings.operatorCall' => 'Operator Callsign',
			'settings.sync.title' => 'Cloud Sync',
			'settings.sync.moreSettings' => 'More sync settings',
			'settings.sync.enable' => 'Enable Sync',
			'settings.sync.deviceKey' => 'Device Key',
			'settings.peers.title' => 'Peer Devices',
			'settings.peers.enable' => 'Connect to other devices',
			'settings.peers.enableDescription' => 'Allow sharing operations, logging, CAT and GPS with other devices over the local network',
			'settings.peers.bleEnable' => 'Connect over Bluetooth',
			'settings.peers.bleDescription' => 'Use Bluetooth LE to connect even if there is no local network',
			'settings.peers.thisDevice' => 'This Device',
			'settings.peers.deviceName' => 'Name',
			'settings.peers.deviceNameHint' => 'How this device is seen by other devices',
			'settings.peers.pairedDevices' => 'Linked Devices',
			'settings.peers.noPairedDevices' => 'No devices linked yet. Turn this on, on another device on this network, to link them.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Can\'t read your linked devices: ${error}',
			'settings.peers.nearby' => 'Nearby',
			'settings.peers.connected' => 'Connected',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Connecting…',
			'settings.peers.syncing' => 'Syncing…',
			'settings.peers.waitingForThem' => 'Waiting for the other device',
			'settings.peers.notConnected' => 'Not connected',
			'settings.peers.wantsToPair' => 'wants to share this operation',
			'settings.peers.allow' => 'Allow',
			'settings.peers.link' => 'Link',
			'settings.peers.reject' => 'Reject',
			'settings.peers.forget' => 'Forget',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Forget ${name}?',
			'settings.peers.forgetBody' => 'It will stop syncing with this device. You can allow it again later, and contacts already logged are kept.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Link with ${name}',
			'settings.peers.pairBody' => 'This device is on your local network and wants to connect.',
			'settings.peers.pairBodyBle' => 'This device is nearby and wants to connect over Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'Device ID',
			'settings.peers.pairWarning' => 'Only link with devices you recognise. Any device on this network can send a request.',
			'settings.peers.pairWarningBle' => 'Only link with devices you recognise. Any nearby device can send a request.',
			'settings.peers.problem' => ({required Object error}) => 'Can\'t reach the local network: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Connected to ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Lost connection to ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Peer Devices: ${connected} of ${linked} connected',
			'settings.peers.screenEnable' => 'Share screens and windows',
			'settings.peers.screenDescription' => 'Allow other devices to show screens or windows from this computer',
			'settings.peers.screenSources' => 'Screens and Windows',
			'settings.peers.screenRefresh' => 'Refresh the list',
			'settings.peers.screenUnsupportedPlatform' => 'This device can\'t share its screen. macOS can; every device can show one shared by another.',
			'settings.peers.screenUnsupportedVersion' => 'Sharing a screen needs macOS 12.3 or later. This device can still show a screen shared by another.',
			'settings.peers.screenNeedsPermission' => 'macOS needs your permission to record the screen before this app can share one.',
			'settings.peers.screenGrantPermission' => 'Ask for permission',
			'settings.peers.screenRelaunchAfterGranting' => 'Allow it in System Settings under Privacy & Security → Screen Recording, then quit and reopen this app — macOS only tells an app about the change on its next launch.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Screen sharing: ${error}',
			'settings.peers.screenChooseTitle' => 'Choose What to Share',
			'settings.peers.screenChooseButton' => 'Choose what to share…',
			'settings.peers.screenTabScreens' => 'Screens',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Windows',
			'settings.peers.screenTabEmpty' => 'Nothing of this kind was found.',
			'settings.peers.screenSharedSummaryNone' => 'Nothing chosen yet.',
			'settings.peers.screenThisDevice' => 'This device',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Shown on ${devices}',
			'settings.peers.screenSharedToNobody' => 'Not being shown',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Stop sharing ${name}',
			'settings.developerMode' => 'Developer Mode',
			'settings.syncPanel.configuration' => 'Sync Configuration',
			'settings.syncPanel.enableTitle' => 'Sync with Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Backing up and syncing your log across devices',
			'settings.syncPanel.disabledDescription' => 'Off — staying on this device only',
			'settings.syncPanel.syncing' => 'Syncing',
			'settings.syncPanel.account' => 'Account',
			'settings.syncPanel.refresh' => 'Refresh',
			'settings.syncPanel.switchAccounts' => 'Switch Accounts',
			'settings.syncPanel.switchAccountsDescription' => 'Link this device to another account with a QR code or email',
			'settings.syncPanel.connectionRequests' => 'Connection Requests',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'A device is waiting to join this account', other: '${n} devices are waiting to join this account', ), 
			'settings.syncPanel.accountEmailTitle' => 'Account email',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmation sent to ${email}. Open the link there to finish the change.',
			'settings.syncPanel.resendConfirmation' => 'Resend Confirmation Email',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Waiting on ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Sent again to ${email}.',
			'settings.syncPanel.deviceLinked' => 'That device is now linked to this account.',
			'settings.syncPanel.checking' => 'Checking…',
			'settings.syncPanel.notLinked' => 'Not linked yet',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Replace local data?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} operation', other: '${n} operations', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Synced Data',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'This device: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Waiting to upload: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'This device: checking…',
			'settings.syncPanel.countsServerChecking' => 'Server: checking…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: not available',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'This backs up and clears ${operations} and ${qsos} from this device, then downloads the account\'s data instead. The backup stays in this device\'s database.',
			'settings.syncPanel.replace' => 'Replace',
			'settings.syncPanel.pendingBannerTitle' => 'New Ham2K Log Filer account detected',
			'settings.syncPanel.pendingBannerBody' => 'Keep this device\'s existing operations and QSOs and merge them into the account, or replace them with the account\'s data (a backup stays on this device either way).',
			'settings.syncPanel.combine' => 'Combine',
			'settings.syncPanel.authIssueTitle' => 'Sync can\'t connect',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer keeps rejecting this device. Check your callsign in Sync settings.',
			'settings.syncPanel.openSettings' => 'Open Sync settings',
			'settings.accounts.title' => 'Accounts, Services & Data Sources',
			'settings.accounts.none' => 'No active extensions with accounts',
			'settings.accounts.notConfigured' => 'Not configured',
			'settings.accounts.connected' => 'Connected',
			'settings.accounts.cancelLogin' => 'Cancel sign-in',
			'settings.accounts.openInBrowser' => 'Open in Browser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Logged in as ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Press Save to keep this account connected.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Connected to ${label}',
			'settings.accounts.connect' => 'Connect',
			'settings.accounts.disconnect' => 'Disconnect',
			'settings.accounts.connectedAs' => 'Connected as',
			'settings.accounts.test' => 'Test',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Save failed: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Login failed: ${error}',
			'settings.accounts.lookupFailed' => 'Accounts are unavailable right now — try again in a moment',
			'settings.accounts.browserLoginTitle' => 'Finish signing in with your web browser',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link (from the address bar, or from the error page the browser shows) and paste it here.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to (it starts with "${prefix}") and paste that here.',
			'settings.accounts.copyLoginLink' => 'Copy login link',
			'settings.accounts.pastedLinkLabel' => 'Paste the link here',
			'settings.accounts.finishLogin' => 'Finish Login',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'That is not the login link — it should start with "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'That link belongs to a different login attempt. Close this page and connect again.',
			'settings.accounts.pastedLinkNoCode' => 'That link has no login code. Finish signing in first, then copy the link it sends you to.',
			'settings.accounts.pastedLinkMalformed' => 'That link looks cut off. Copy the whole thing and paste it again.',
			'settings.accounts.relayLoginWaiting' => 'Waiting for you to finish signing in — this will continue automatically once you do.',
			'settings.accounts.loginNoResponse' => 'This device hasn\'t heard back from the sign-in yet. If you already finished in your browser, cancel and try connecting again.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.',
			'settings.accounts.relayLoginUnavailable' => 'Couldn\'t reach the sync server needed to complete this login. Check your connection and try again.',
			'settings.accounts.loginIncompleteResponse' => 'That login attempt didn\'t complete correctly. Please try connecting again.',
			'settings.accounts.noKeyringTitle' => 'Account logins can’t be saved',
			'settings.accounts.noKeyringText' => 'Ham2K Logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. Install and start **gnome-keyring**, **KWallet** or **KeePassXC**, or unlock the keyring you already have, then restart. Logging, exports and data files are unaffected; log sync stays off while this lasts.',
			'settings.accounts.noKeyringInline' => 'Logins can’t be saved: this computer’s keyring can’t be reached. Install and start gnome-keyring, KWallet or KeePassXC, or unlock the one you have.',
			'settings.accounts.noSecureStorageInline' => 'Logins can’t be saved: this computer’s secure storage can’t be reached.',
			'settings.station.title' => 'Station Configuration & CAT Control',
			'settings.station.none' => 'No equipment configured',
			'settings.station.add' => 'Add',
			'settings.station.addTitle' => 'Add equipment',
			'settings.station.searchHint' => 'Search equipment',
			'settings.station.noMatches' => 'No equipment matches',
			'settings.station.detectedEquipment' => 'Detected Equipment',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Can\'t listen for radios: ${error}',
			'settings.station.edit' => 'Edit equipment',
			'settings.station.name' => 'Name',
			'settings.station.nameDescription' => 'What you call it — "Left Radio". Optional.',
			'settings.station.transport' => 'Connection',
			'settings.station.host' => 'Address',
			'settings.station.hostDescription' => 'The radio\'s hostname or IP address on your network.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'An address is required',
			_ => null,
		} ?? switch (path) {
			'settings.station.portInvalid' => 'Port must be between 1 and 65535',
			'settings.station.connect' => 'Connect',
			'settings.station.disconnect' => 'Disconnect',
			'settings.station.remove' => 'Remove',
			'settings.station.removeTitle' => ({required Object name}) => 'Remove ${name}?',
			'settings.station.removeMessage' => 'This only removes it from the app. The equipment\'s settings stay as they are.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Unrecognized equipment type "${typeKey}"',
			'settings.station.report' => 'Report',
			'settings.station.reportTitle' => 'Report this radio',
			'settings.station.reportIntro' => 'Tell us what radio this really is and how it went. Your report becomes a card the Ham2K team reads, and what you write about getting it working may end up helping the next operator with the same rig.',
			'settings.station.reportManufacturer' => 'Manufacturer',
			'settings.station.reportManufacturerDescription' => 'Who makes it — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'A manufacturer is required',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'The model, as the radio itself calls it — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'A model is required',
			'settings.station.reportOutcome' => 'How did it go?',
			'settings.station.reportOutcomeWorks' => 'Worked well',
			'settings.station.reportOutcomeIssues' => 'Worked, with issues',
			'settings.station.reportOutcomeFails' => 'Didn\'t work at all',
			'settings.station.reportOutcomeRequired' => 'Please tell us how it went',
			'settings.station.reportComments' => 'Comments',
			'settings.station.reportCommentsPlaceholder' => 'What worked, what didn\'t, anything that surprised you.',
			'settings.station.reportHints' => 'Troubleshooting hints',
			'settings.station.reportHintsPlaceholder' => 'Want to suggest some troubleshooting hints for other users?',
			'settings.station.reportSend' => 'Send report',
			'settings.station.reportSending' => 'Sending your report…',
			'settings.station.reportSent' => ({required Object ref}) => 'Thanks — your report was filed as ${ref}.',
			'settings.station.reportSentNoRef' => 'Thanks — your report was sent.',
			'settings.station.reportFailed' => ({required Object error}) => 'The report wasn\'t sent: ${error}',
			'settings.station.troubleshootingNotes' => 'Troubleshooting Notes',
			'settings.station.mainVfo' => 'Main VFO',
			'settings.station.useAsMainVfo' => 'Use as Main VFO',
			'settings.station.serialPort' => 'Serial port',
			'settings.station.serialPortDescription' => 'The port the radio\'s CAT interface appears on.',
			'settings.station.serialPortNone' => 'No serial ports found',
			'settings.station.serialPortRequired' => 'Choose a serial port',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} of ${total}',
			'settings.station.serialPortSuggested' => 'suggested',
			'settings.station.serialPortJustNow' => 'Recently connected',
			'settings.station.serialDeviceRequest' => 'Add a USB device…',
			'settings.station.bleDevice' => 'Bluetooth LE device',
			'settings.station.bleDeviceDescription' => 'The serial bridge your radio is connected through, such as a LiNK500MP in its iOS mode or a BLE serial adapter.',
			'settings.station.bleScan' => 'Scan for Bluetooth LE devices…',
			'settings.station.bleScanNoneFound' => 'No Bluetooth LE devices found. Check that the bridge is on, nearby, and in its Bluetooth LE (iOS) mode.',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'The Bluetooth LE scan could not run: ${reason}',
			'settings.station.bleOff' => 'Bluetooth is turned off.',
			'settings.station.bleDenied' => 'Bluetooth permission was not granted. Allow it in system settings, then try again.',
			'settings.station.bleUnsupported' => 'This device has no Bluetooth LE.',
			'settings.station.bleStarting' => 'Bluetooth is still starting up. Try again in a moment.',
			'settings.station.bleConnectFailed' => 'Cannot reach the Bluetooth LE device. Check that it\'s on, nearby, and not connected to another app.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'This Bluetooth LE device has no serial service the app recognizes. Please report it with its services: ${services}',
			'settings.station.baudRate' => 'Speed (baud)',
			'settings.station.baudRateDescription' => 'Must match the radio\'s CAT menu. With a mismatch, the radio sends back garbage and no error.',
			'settings.station.serialRtsHigh' => 'Hold RTS high',
			'settings.station.serialRtsHighDescription' => 'Only for a radio that waits for RTS before responding, such as a Yaesu with CAT RTS turned on. On a Digirig, SignaLink and most home-made cables RTS is PTT, and holding it high transmits.',
			'settings.station.serialDtrHigh' => 'Hold DTR high',
			'settings.station.serialDtrHighDescription' => 'Only for a CAT interface that draws its power from DTR, such as some RS-232 cables for the FT-817. On many cables DTR keys CW or PTT, and holding it high transmits.',
			'settings.station.civAddress' => 'Radio CI-V address',
			'settings.station.civAddressDescription' => 'Hex, as shown in the radio\'s CI-V menu. The IC-705 ships as A4.',
			'settings.station.civAddressInvalid' => 'A CI-V address is two hex digits, 01 to FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Which of the radio\'s slices this connection reads from and tunes.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Pick one of the radio\'s slices, A through H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} is not in use on this radio — pick another slice, or create it in SmartSDR',
			'settings.station.channelNotInUse' => 'not in use',
			'settings.station.channelHeldByUnknown' => 'in use by another program',
			'settings.station.flexNoSlices' => 'This radio has not reported any slices — check that SmartSDR is running and that this client may subscribe',
			'settings.station.spectrumUnsupported' => 'This radio sends no spectrum over CAT',
			'settings.station.spectrumRequiresBaud' => 'Requires CAT at 115200 bps',
			'settings.station.spectrumNoRadio' => 'No radio connected',
			'settings.station.spectrumWaiting' => 'Waiting for the radio\'s spectrum…',
			'settings.station.spectrumUnavailable' => 'Spectrum display is not available',
			'settings.station.spectrumNoDaxChannel' => 'Every DAX IQ channel on this radio is in use',
			'settings.station.spectrumNoPanadapter' => 'This slice has no panadapter on the radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'The radio refused a DAX IQ stream (error ${code})',
			'settings.station.spectrumNoUdp' => 'The radio\'s spectrum data cannot reach this device',
			'settings.station.spectrumK4Unavailable' => 'Cannot receive the K4’s LAN spectrum. Retrying…',
			'settings.station.spectrumK4RemoteUnavailable' => 'Cannot receive the K4’s remote spectrum',
			'settings.station.spectrumScopeRefused' => 'The radio refused its scope commands',
			'settings.station.spectrumOutOfRange' => 'The radio\'s scope is set outside the range it can show',
			'settings.station.spectrumBandUnsupported' => 'The radio\'s scope cannot be shown on this band',
			'settings.station.spectrumSdrNoRadio' => 'Waiting for the linked radio\'s frequency…',
			'settings.station.spectrumSdrNotConnected' => 'The SDR is not connected',
			'settings.station.spectrumSdrNoIf' => 'Set the radio\'s IF frequency in this SDR\'s settings',
			'settings.station.sdrRadio' => 'Shows the spectrum for',
			'settings.station.sdrRadioDescription' => 'A spectrum display on this radio draws from this receiver instead of the radio\'s own scope.',
			'settings.station.sdrRadioMain' => 'The Main radio',
			'settings.station.sdrTuning' => 'Antenna input',
			'settings.station.sdrTuningDescription' => 'Where the receiver\'s signal comes from. On its own antenna it tunes itself to follow the radio; on the radio\'s IF output it stays on the IF.',
			'settings.station.sdrTuningIndependent' => 'Its own antenna',
			'settings.station.sdrTuningIfTap' => 'The radio\'s IF output',
			'settings.station.sdrIfHz' => 'IF frequency (Hz)',
			'settings.station.sdrIfHzDescription' => 'For an IF output only: the frequency the radio\'s dial sits at on its IF, such as 68330000 on an FT-817.',
			'settings.station.sdrIfInverted' => 'IF is inverted',
			'settings.station.sdrGainDb' => 'Gain (dB)',
			'settings.station.sdrGainDbDescription' => 'Leave blank for the receiver\'s automatic gain.',
			'settings.station.sdrOffsetHz' => 'Frequency offset (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'Added to every frequency sent to the receiver, for an upconverter: 125000000 for a Ham It Up.',
			'settings.station.sdrPpm' => 'Frequency correction (ppm)',
			'settings.station.rtlDirectSampling' => 'Direct sampling',
			'settings.station.rtlDirectSamplingDescription' => 'For HF on an RTL-SDR V3 without an upconverter. An RTL-SDR V4 reaches HF without it.',
			'settings.station.rtlDirectSamplingOff' => 'Off',
			'settings.station.rtlDirectSamplingI' => 'I branch',
			'settings.station.rtlDirectSamplingQ' => 'Q branch',
			'settings.station.rtlTcpNotAServer' => 'This is not an rtl_tcp server',
			'settings.station.rtlTcpNotes' => 'This connects to an **rtl_tcp server you run yourself** on the computer the dongle is plugged into.\n\n- **Start it** with `rtl_tcp -a 0.0.0.0` so other machines can reach it; on the same machine, `rtl_tcp` alone will do.\n- **Port** is 1234 unless you started it with `-p`.\n- **One program at a time:** rtl_tcp serves a single client. The app connects only while a spectrum display is showing, and lets go a few seconds after it closes.\n- **On Android**, the *SDR driver* app runs the same server on the phone.',
			'settings.station.rspTcpNotes' => 'This connects to an **rsp_tcp server you run yourself** on the computer the RSP is plugged into, with SDRplay\'s API installed there.\n\n- **Start it** with `rsp_tcp -a 0.0.0.0`.\n- **Port** is 1234 unless you started it with `-p`.\n- **One program at a time:** the server takes a single client. The app connects only while a spectrum display is showing.',
			'settings.station.n3fjpNoRig' => 'N3FJP has no radio interface set up, so this follows what is typed into N3FJP, not a radio',
			'settings.station.winkeyerKeyPort' => 'Key output',
			'settings.station.winkeyerKeyPortDescription' => 'Which of the keyer\'s two output jacks your radio is plugged into.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Use the keyer\'s PTT',
			'settings.station.winkeyerPttDescription' => 'Key the PTT line on the same jack, for an amplifier or a radio that needs it. Leave off for a radio keyed on its key jack.',
			'settings.station.winkeyerNoAnswer' => 'No WinKeyer responded on this port',
			'settings.station.winkeyerStoppedAnswering' => 'The WinKeyer stopped responding while sending; the message was dropped',
			'settings.station.icomControlPort' => 'Control port (UDP)',
			'settings.station.icomControlPortDescription' => 'The radio\'s Control Port (UDP) — 50001 unless changed in its network settings, or forwarded to another.',
			'settings.station.icomSerialPort' => 'Serial port (UDP)',
			'settings.station.icomSerialPortDescription' => 'The radio\'s Serial Port (UDP) — 50002 unless changed in its network settings, or forwarded to another.',
			'settings.station.icomPortsDiffer' => 'The control and serial ports must differ',
			'settings.station.radioUser' => 'Radio username',
			'settings.station.radioPass' => 'Radio password',
			'settings.station.radioLoginDescription' => 'The radio\'s Network → Remote login, not your WiFi password.',
			'settings.station.radioUserRequired' => 'The radio\'s remote-control username is required',
			'settings.station.connectFailedBusy' => 'Device is in use',
			'settings.station.connectFailedDenied' => 'Access denied',
			'settings.station.connectFailedDevice' => 'Device not found',
			'settings.station.connectFailedLines' => 'RTS/DTR could not be held as set, so the port was closed. Another program may have left hardware handshaking on — unplug and replug the cable.',
			'settings.station.connectFailedNetwork' => 'Cannot find the radio over the network. Check its address and that it\'s powered on and reachable.',
			'settings.station.connectFailedTimeout' => 'The radio didn\'t respond in time. Check it\'s powered on and reachable.',
			'settings.station.models.flexRadio' => 'FlexRadio (SmartSDR)',
			'settings.station.models.ft891' => 'Yaesu FT-891',
			'settings.station.models.ft991a' => 'Yaesu FT-991/A',
			'settings.station.models.ft710' => 'Yaesu FT-710',
			'settings.station.models.ftdx10' => 'Yaesu FTDX10',
			'settings.station.models.ftx1' => 'Yaesu FTX-1',
			'settings.station.models.ft817' => 'Yaesu FT-817 / FT-818',
			'settings.station.models.ft857' => 'Yaesu FT-857',
			'settings.station.models.ft897' => 'Yaesu FT-897',
			'settings.station.models.ft450' => 'Yaesu FT-450 / FT-450D',
			'settings.station.models.q900' => 'Guohetec Q900',
			'settings.station.models.tenTecEagle' => 'Ten-Tec Eagle (599)',
			'settings.station.models.tenTecOrion' => 'Ten-Tec Orion (565)',
			'settings.station.models.tenTecOrionII' => 'Ten-Tec Orion II (566)',
			'settings.station.models.sotacat' => 'SOTAcat (Elecraft KX2/KX3)',
			'settings.station.models.yaesuGeneric' => 'Yaesu - Generic',
			'settings.station.models.icomGeneric' => 'Icom - Generic',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Generic',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Generic',
			'settings.station.models.kx2' => 'Elecraft KX2',
			'settings.station.models.kx3' => 'Elecraft KX3',
			'settings.station.models.k4' => 'Elecraft K4',
			'settings.station.models.ic705' => 'Icom IC-705',
			'settings.station.models.ic7300' => 'Icom IC-7300',
			'settings.station.models.ic7300mk2' => 'Icom IC-7300 MK2',
			'settings.station.models.ic706mkiig' => 'Icom IC-706MKIIG',
			'settings.station.models.ic7100' => 'Icom IC-7100',
			'settings.station.models.ic7610' => 'Icom IC-7610',
			'settings.station.models.ic7760' => 'Icom IC-7760',
			'settings.station.models.ic9700' => 'Icom IC-9700',
			'settings.station.models.ic905' => 'Icom IC-905',
			'settings.station.models.ic7850' => 'Icom IC-7850',
			'settings.station.models.ic7851' => 'Icom IC-7851',
			'settings.station.models.x6100' => 'Xiegu X6100',
			'settings.station.models.g90' => 'Xiegu G90',
			'settings.station.models.rigctld' => 'Radio controlled via rigctld',
			'settings.station.models.rigctldNodeName' => 'My Radio (via rigctld)',
			'settings.station.models.flrig' => 'Radio controlled via flrig',
			'settings.station.models.flrigNodeName' => 'My Radio (via flrig)',
			'settings.station.models.hrd' => 'Radio controlled via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'My Radio (via HRD)',
			'settings.station.models.n3fjp' => 'Radio controlled via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'My Radio (via N3FJP)',
			'settings.station.models.commander' => 'Radio controlled via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'My Radio (via Commander)',
			'settings.station.models.antenna' => 'Antenna',
			'settings.station.models.key' => 'CW Key',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Generic Radio (Placeholder)',
			'settings.station.models.placeholderRadioNodeName' => 'My Radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Network/WiFi',
			'settings.station.transports.secureNetwork' => 'Secure Network/WiFi',
			'settings.station.transports.usbSerial' => 'USB Serial',
			'settings.station.transports.wifi' => 'Network/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth Serial',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Placeholder',
			'settings.station.troubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.ft891Troubleshooting' => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **CAT RTS off at the radio, or Hold RTS high on.** With **CAT RTS** on (FT-891 menu **05-08**), the radio stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio\'s own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead.\n- **Speed must match** the radio\'s CAT RATE (menu **05-06**). With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.yaesuBinaryTroubleshooting' => 'This radio speaks Yaesu\'s older five-byte CAT, and it does not respond at all when something is off. Almost always one of:\n\n- **The cable must convert levels.** The CAT jack on the back is not RS-232 and not USB; it needs a CT-62 or an equivalent adapter. A plain audio or data cable won\'t work for CAT.\n- **Speed must match** the radio\'s CAT RATE menu (**#14** on an FT-817, **#19** on an FT-857 or FT-897). With a mismatch, the radio sends nothing back, and never an error.\n- **Never let anything raise RTS or DTR on this port.** On most cables for these radios those lines are PTT and keying. An older interface powered from DTR is the exception: turn on **Hold DTR high** under Advanced Settings for that one.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis driver was written from Yaesu\'s published CAT chart and has not been run against one of these radios. If it half-works, that is worth reporting.',
			'settings.station.tenTecTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.tenTecEagleTroubleshooting' => '- **The USB-B port on the back is the CAT link.** The radio shows up as a USB serial port; on Windows it needs Ten-Tec\'s USB to UART driver, which appears in Device Manager as "USB to UART (COMx)".\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open, and so does Ten-Tec\'s firmware updater.\n- **Setting the filter width from the app takes it away from the BW knob** until the radio is switched off and on again. That is how the radio works.\n\nThis driver was written from Ten-Tec\'s programmer\'s reference guide. If it half-works, that is worth reporting, with the firmware version from the radio\'s menu.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Use a straight-through DB-9 serial cable** to the SERIAL DATA port, not a null-modem one.\n- **This entry holds RTS high**, because the Orion uses RTS and CTS as its handshake. On an interface that keys PTT from RTS, such as a Digirig, turn off Hold RTS high under Advanced Settings, or the radio transmits as soon as the app connects.\n- **CW from the app needs the radio\'s internal keyer on.** With it off, the radio ignores what the app sends.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis driver was written from Ten-Tec\'s programmer\'s reference guide and has not been run against an Orion. If it half-works, that is worth reporting, with the firmware version from the radio\'s menu.',
			'settings.station.tenTecNoCw' => 'This radio\'s firmware does not take CW from the app. Ten-Tec added it in Orion firmware 1.366.',
			'settings.station.tenTecKeyerOff' => 'The radio\'s internal keyer is off, so it ignores CW sent from the app. Turn the keyer on in the radio\'s menu.',
			'settings.station.guohetecTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.guohetecTroubleshooting' => 'The Q900 has two CAT protocols, and this entry uses its native one rather than the FT-817 imitation. Pick **Guohetec Q900** here, not an FT-817 — the imitation supports fewer commands, and the radio does not say which one it is using.\n\n- **The USB-C cable is the CAT link**, and it connects the sound card too. Speed does not matter on it; the port ignores whatever it is set to.\n- **Never let anything raise RTS or DTR on this port.** On a serial cable those lines are PTT and keying.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **A second-generation radio behaves differently** from a first. Long press Menu, then About: HW 2.0 is the second generation.\n\nThis driver was written from the manufacturer\'s published protocol and has not been run against one of these radios. If it half-works, that is worth reporting.',
			'settings.station.yaesuTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.yaesuTroubleshooting' => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low. On a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter. On the radio\'s own USB port, **Hold RTS high** under Advanced Settings is the alternative. Where that setting lives differs by model (menu **05-08** on an FT-891).\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **Modes follow the FT-891\'s table.** Most of the Yaesu line matches it, but a radio that numbers its modes differently will show and set the wrong one for those. The frequency is unaffected.',
			'settings.station.yaesuRs232Troubleshooting' => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **The CAT jack is RS-232.** It needs a USB-to-serial adapter and a straight-through DB-9 cable — a null-modem cable swaps the lines, and the radio never hears a thing.\n- **CAT RTS must be OFF at the radio.** With it on, the radio waits for a handshake line the app keeps low unless **Hold RTS high** is on under Advanced Settings.\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\nThis entry was written from published CAT documentation and has not been run against one of these radios. If it half-works, that is worth reporting.',
			'settings.station.yaesuUsbTroubleshooting' => 'The radio is receiving commands but not responding. Almost always one of:\n\n- **Use the first of the radio\'s two USB ports.** CAT is normally on the first (the **Enhanced** COM port on Windows); the second (**Standard**) is for PTT and keying. The picker points at the first wherever it can tell the two apart.\n- **CAT RTS off at the radio, or Hold RTS high on.** With the radio\'s **CAT RTS** menu on, it stays silent while RTS is low — it may answer once as the port opens, then nothing. Picking the radio\'s own USB port turns on **Hold RTS high** under Advanced Settings. On a Digirig, SignaLink or most home-brew cables RTS is PTT, and holding it high keys your transmitter: turn CAT RTS off at the radio instead.\n- **Speed must match** the radio\'s CAT RATE menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.',
			'settings.station.k4SerialNotes' => 'Connect the K4’s rear USB-B (PC) socket. Either USB-PC1 or USB-PC2 works for CAT; choose an unused port and match its Serial USB-PCn: Baud Rate setting on the radio. HaLo prefills 38400; change it if needed. Another application must use the other port or Ethernet.\n\nThis connection controls the radio and its keyers; it does not send audio to HaLo.',
			'settings.station.k4TcpNotes' => 'Connect the K4’s Ethernet socket to your local network. Enter its hostname or IP address and CAT port 9200. HaLo uses the same host on fixed port 9201 when a panadapter or waterfall is visible; changing the CAT port does not change the spectrum port.\n\nThe spectrum shows the main receiver. Its zoom, reference adjustment and speed controls affect only HaLo’s display. Audio streaming is not supported.',
			'settings.station.k4PowerTimeout' => 'K4 power was not changed because the radio did not confirm its output range. Try again.',
			'settings.station.k4RemoteNotes' => 'Enable remote access on your K4 and enter its network password. Main and Sub share one encrypted connection for radio control and spectrum. The default port is 9204; enter your forwarded port when connecting remotely.\n\nAudio playback and microphone streaming are not supported.',
			'settings.station.k4Receiver' => 'Receiver',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Choose Main or Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'That receiver is already configured for this K4',
			'settings.station.k4SubReceiverOff' => 'The K4 sub receiver is off',
			'settings.station.k4RemotePasswordRequired' => 'Enter the K4’s network password to connect securely.',
			'settings.station.k4RemoteHandshakeFailed' => 'The K4 could not establish a secure connection. Check its network password and remote access settings.',
			'settings.station.k4RemoteUnreachable' => 'The K4’s secure connection could not be reached. Check its address, port and remote access settings.',
			'settings.station.k4PowerRange' => 'K4 power must be 0.1–110 W, or 0.0001–0.01 W when the transverter milliwatt output is active.',
			'settings.station.elecraftTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.elecraftTroubleshooting' => 'Elecraft rigs speak Kenwood CAT, and a KX2 and a KX3 have both been run this way — VFO in both directions, mode switching and CW zero-beat all working.\n\nIf the radio does not respond, almost always one of:\n\n- **Speed must match** the rate set under **RS232** in the radio\'s menu. 38400 is what these ship on. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n\n**If the frequency is right but the mode is wrong**, tell us. The KX2 and KX3 entries read the mode from a position in the radio\'s status reply that we have pinned from the rigs we have seen, and a firmware that puts it elsewhere is something only a report reaches us as.\n\nThe K3 has not been reported either way, so please say what happens if you run one. A K4 has its own entry.',
			'settings.station.lab599TroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.lab599Troubleshooting' => 'The TX-500 line speaks Kenwood CAT. Written from published references rather than tested on the radio, so please report what happens either way.\n\n- **Speed must match** the radio\'s CAT setting, 9600 unless you changed it. With a mismatch the radio sends back garbage or nothing, and never an error.\n- **Pick the CAT protocol on the radio.** TS-2000 covers frequency and mode. LAB599 also lets the app switch the radio to DIG.\n- **Through a LiNK500MP**, press and hold the VFO knob for about three seconds to hand CAT control to the interface.\n- **Over Bluetooth on a computer**, the LiNK500MP pairs as two serial ports and only one carries CAT. If the radio stays silent, pick the other.\n- **Over Bluetooth LE**, as on an iPhone or iPad, switch the LiNK500MP to its iOS mode first. In its other modes it does not show up in a scan.',
			'settings.station.kenwoodTroubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.kenwoodTroubleshooting' => 'This driver is proven against Kenwood\'s TS-590SG and TS-480, QRP Labs\' QMX and QCX-mini, and Elecraft\'s KX2 and KX3. The rest of the line is written from published CAT references, so please report what happens either way.\n\nIf the radio does not respond, almost always one of:\n\n- **Speed must match** the radio\'s CAT menu. With a mismatch, the radio sends back garbage or nothing, and never an error.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.\n- **Some rigs need CAT enabled** in the menu before they respond at all.\n\n**Several SDR front-ends speak this same protocol**, so this entry is worth trying for those too; Elecraft rigs are listed separately, under Elecraft. If the frequency is right but the mode is wrong or missing, that is the one part that differs across the line — the app works it out from the radio and falls back to asking directly, so the mode may simply lag.',
			'settings.station.statusConnected' => 'Connected',
			'settings.station.statusLost' => 'Disconnected',
			'settings.station.notConfigured' => 'Not configured',
			'settings.station.currentConfiguration' => 'Current Configuration',
			'settings.station.currentTransceiver' => 'Current Transceiver',
			'settings.station.radioMode' => 'Radio Mode',
			'settings.station.keyerNotSupported' => 'Not supported by current radio',
			'settings.station.catControlPreferences' => 'CAT Control Preferences',
			'settings.station.chooseTransceiver' => 'Choose transceiver',
			'settings.station.configurationSection' => 'Configuration',
			'settings.station.noTransceiverSelected' => 'No transceiver selected',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Use ${name} for the Main VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, zero: 'No transceivers', one: '${count} transceiver', other: '${count} transceivers', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} antenna', other: '${count} antennas', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} other device', other: '${count} other devices', ), 
			'settings.station.equipmentInventory' => 'Equipment Inventory',
			'settings.station.equipmentInUse' => 'Transceiver Controls',
			'settings.station.noTransceiver' => 'None',
			'settings.station.peerRadioNotAvailable' => 'Not available',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'On ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} is on another device',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'This radio is connected to ${device}. Its connection and settings are configured on that device.',
			'settings.station.antennaInUse' => 'Antenna in Use',
			'settings.station.keyInUse' => 'Key in Use',
			'settings.station.noneSelected' => 'None',
			'settings.station.moreSettings' => 'More Settings',
			'settings.station.icomCivTroubleshootingTitle' => 'If two serial ports show up for the same radio',
			'settings.station.icomCivTroubleshooting' => 'Several Icom radios, the IC-705 among them, present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that: the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists, and where this app can tell the two ports apart it marks that one as suggested. If commands go out and the radio never responds, try the other port next.',
			'settings.station.civAddressTroubleshootingTitle' => 'If the radio never responds',
			'settings.station.civAddressTroubleshooting' => '- **The CI-V address must match** the radio\'s menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n- **Speed must match** the radio\'s CI-V BAUD RATE (on USB, CI-V USB Baud Rate). Set the radio to the same number shown here, **not Auto**. On Auto some radios, the IC-7300 among them, connect and then stop responding after a minute or so.\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **The CI-V address must match** the radio\'s menu. This entry prefills the address the model ships with, but a rig sharing a CI-V bus is exactly where that gets changed. A frame sent to the wrong address is ignored in silence, which looks exactly like a dead cable.\n${speed}\n- **Another app may hold the port**: WSJT-X, fldigi and rigctld all keep it open.',
			'settings.station.icomUsbSpeedFollows' => '- **There is no speed to set.** Over USB this radio talks at whatever speed the computer uses, and this entry always uses 115200, the speed the scope needs.',
			'settings.station.ic7610UsbSpeed' => '- **Set CI-V USB Baud Rate to 115200**, the speed this entry always uses, since the scope needs it — **not Auto**. A radio set to any other speed answers with silence.',
			'settings.station.ic7300Mk2Note' => '\n- The **IC-7300 MK2** ships on address `B6`, not the `94` prefilled here — pick the IC-7300 MK2 entry instead.',
			'settings.station.ic705PortNote' => '\n- The **IC-705** presents two USB serial ports, both named after the radio. CI-V is on the **first** of them, which the picker points at wherever it can tell the two apart.',
			'settings.station.ic7760PortNote' => '\n- The **IC-7760** speaks CI-V on **Port A** of the two USB serial ports it presents.',
			'settings.station.x6100PortNote' => '\n- The **X6100** speaks CI-V on its **DEV** port — the second of the two serial ports it presents, and the one the picker points at.',
			'settings.station.rigctldTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.rigctldTroubleshooting' => 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib\'s backend talks to the radio and supports hundreds of models.\n\n- **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio\'s model number with `rigctl -l`.\n- **From another machine**, start it with `-T 0.0.0.0`: by default rigctld only accepts connections from the machine it runs on.\n- **Port** is 4532 unless you started the daemon with `-t`.\n- Once connected, a missing frequency usually means the daemon itself cannot reach the radio. Test it with `rigctl -m 2 f` on the daemon\'s machine.',
			'settings.station.flrigTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.flrigTroubleshooting' => 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **Port** is 12345 unless you changed it in flrig\'s configuration (Config → Setup → Server).\n- **From another machine**, make sure flrig\'s server is reachable. It listens on all interfaces, but your firewall may not agree.\n- Once connected, a missing frequency usually means flrig itself cannot reach the radio. Check that flrig\'s display is following the dial.',
			'settings.station.hrdTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.hrdTroubleshooting' => 'This connects to **Ham Radio Deluxe\'s Rig Control, running on your computer**, not to the radio directly — HRD talks to the radio.\n\n- **Rig Control must already be running** and connected to the radio.\n- **Its IP server must be enabled.** Rig Control only talks to other programs through it.\n- **Port** is 7809 unless you changed it in the IP server\'s settings.\n- **From another machine**, make sure your firewall lets the connection through.\n\nThis entry was written from published descriptions of HRD\'s protocol and has not been run against HRD. If it half-works, that is worth reporting.',
			'settings.station.n3fjpTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.n3fjpTroubleshooting' => 'This connects to **an N3FJP logging program running on your computer**, not to the radio directly — N3FJP talks to the radio.\n\n- **The program\'s API must be on**: Settings → Application Program Interface, check **TCP API Enabled**.\n- **Port** is 1100 unless you changed it there.\n- **N3FJP must have a radio interface set up** to follow or tune the radio. Without one, it reports only what is typed into its entry window.\n- N3FJP reports band, mode and frequency only: no power, no transmit state.\n\nThis entry was written from N3FJP\'s published API and has not been run against N3FJP. If it half-works, that is worth reporting.',
			'settings.station.commanderTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.commanderTroubleshooting' => 'This connects to **DXLab Commander, running on your computer**, not to the radio directly — Commander talks to the radio.\n\n- **Commander must already be running** and connected to the radio.\n- **Its network service must be on**: the **Net Serv** button in the Radio panel of Commander\'s Configuration window.\n- **Port** is 52002, the third port of the block starting at Net Serv\'s **Base Port** (52000 unless you changed it).\n- **From another machine**, make sure your firewall lets the connection through.\n\nThis entry was written from Commander\'s published TCP messages and has not been run against Commander. If it half-works, that is worth reporting.',
			'settings.station.ic705TroubleshootingTitle' => 'If the radio never responds',
			'settings.station.ic705Troubleshooting' => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings.** WLAN must be on, the radio must be on the same network, and its remote-control (Network) function must be enabled.\n- **The ports must match** the radio\'s Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off.\n- **Power-cycle the radio\'s WLAN** if it stays stuck. That reliably clears a session stuck on the radio.\n\nA **wrong password is refused explicitly**, not met with silence. If you got here rather than a "rejected" message, the password is not the problem.',
			'settings.station.icomLanTroubleshooting' => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview, RS-BA1 or Icom\'s Remote Utility connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings.** Its LAN port must be connected to the same network as this device, its **Network Control** must be on, and the username and password must be set up as a network user on the radio.\n- **The ports must match** the radio\'s Control Port and Serial Port (UDP), or the ports forwarded to them. A wrong port is met with silence, the same as a radio that is off.\n- **If it connects but never answers**, the CI-V address here must match the radio\'s CI-V ADDRESS menu. This entry prefills the address the model ships with.\n- **Turn the radio off and on** if it stays stuck.',
			'settings.station.statusStale' => 'Not responding',
			'settings.station.statusDisconnected' => 'Not connected',
			'settings.station.statusConnecting' => 'Connecting…',
			'settings.station.statusDisconnecting' => 'Disconnecting…',
			'settings.station.statusError' => 'Connection failed',
			'settings.station.currentRadioSettings' => 'Current radio settings',
			'settings.station.notSupportedByThisRadio' => 'Not supported by this radio',
			'settings.station.keyerRowLabel' => 'Keyer',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Phone',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Voice keyer: ${count} memories in the radio',
			'settings.station.antennaBands' => 'Bands',
			'settings.station.antennaType' => 'Antenna type',
			'settings.station.antennaTypeRequired' => 'Choose an antenna type',
			'settings.station.antennaTypes.dipole' => 'Dipole',
			'settings.station.antennaTypes.vertical' => 'Vertical',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Long Wire / EFHW',
			'settings.station.antennaTypes.other' => 'Other',
			'settings.station.keyType' => 'Key type',
			'settings.station.keyTypeRequired' => 'Choose a key type',
			'settings.station.keyTypes.straight' => 'Straight Key',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mechanical semi-automatic)',
			'settings.station.keyTypes.fullyAutomatic' => 'Fully-automatic keyer',
			'settings.station.keyTypes.singlePaddle' => 'Single Paddle',
			'settings.station.keyTypes.dualPaddle' => 'Dual Paddle',
			'settings.station.keyTypes.computerDriven' => 'Computer Driven',
			'settings.station.keyTypes.other' => 'Other',
			'settings.station.softwareIntermediaries' => 'Software Intermediaries',
			'settings.station.otherBrands' => 'Other Brands',
			'settings.station.otherEquipment' => 'Other Equipment (Antennas, Keys, etc)',
			'settings.station.newAntenna' => 'New Antenna',
			'settings.station.newKey' => 'New Key',
			'settings.station.newKeyer' => 'WinKeyer (K1EL or compatible)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT Keyer in ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Key on ${device}',
			'settings.station.cwKeyerArea' => 'Keyer area',
			'settings.station.trackStationInfo' => 'Track Station Info for each QSO',
			'settings.station.includeStationInfoInAdif' => 'Include in ADIF exports',
			'settings.station.whatToTrack' => 'What to track?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Power',
			'settings.station.watts' => 'Watts',
			'settings.station.trackFieldAntenna' => 'Antenna',
			'settings.station.trackFieldKey' => 'CW Key',
			'settings.station.placeholderConnectDelay' => 'Connect delay (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'How long the simulated handshake takes. Blank or 0 connects instantly.',
			'settings.station.placeholderDropAfter' => 'Drop after (seconds)',
			'settings.station.placeholderDropAfterDescription' => 'Close the connection on its own, to exercise the reconnect path. Blank or 0 never drops.',
			'settings.station.placeholderFailConnect' => 'Always fail to connect',
			'settings.station.placeholderConnectFailure' => 'The placeholder radio was told to refuse this connection',
			'settings.station.placeholderFreq' => 'Frequency (kHz)',
			'settings.station.placeholderFreqDescription' => 'Where the placeholder radio starts. It reports back whatever the app tunes it to afterwards.',
			'settings.station.placeholderMode' => 'Mode',
			'settings.station.placeholderModeDescription' => 'The mode the placeholder radio starts on, e.g. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Power (watts)',
			'settings.station.placeholderPurpose' => 'Use this radio to keep track of which rig you\'re using for logging purposes',
			'settings.station.placeholderReplyDelay' => 'Reply delay (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'How long the placeholder radio takes to report a change back. Blank or 0 replies at once.',
			'settings.station.cwKeyerField' => 'CAT CW keyer',
			'settings.station.cwKeyerFieldDescription' => 'Whether this radio keys CW from text over CAT. Off for a rig the app does not know.',
			'settings.station.voiceMemories' => 'Voice memories',
			'settings.station.voiceMemoriesDescription' => 'How many voice memories the radio plays over CAT. 0 for none.',
			'settings.station.voiceMemoriesInvalid' => 'A whole number, 0 or more',
			'settings.station.yaesuMeterCapture' => 'Capture meter readings',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Reads the radio\'s power-output meter and high-SWR flag while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.',
			'settings.station.yaesuMeterCaptureDescription' => 'Reads the radio\'s PO, SWR and ALC meters while transmitting and prints the raw values to the log. For building the scale Yaesu does not publish — the values are not shown as meters.',
			'settings.station.telemetryInterval' => 'Meter reading interval (ms)',
			'settings.station.telemetryIntervalDescription' => 'How often to read the radio\'s meters while it is transmitting. Leave blank for the fastest this connection can handle, up to 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'A whole number of milliseconds, ${min} to ${max}',
			'settings.station.pollInterval' => 'Idle polling interval (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'How often to ask the radio for its frequency and mode while neither is changing. Leave blank for ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'A whole number of milliseconds, ${min} to ${max}',
			'settings.station.advancedSettings' => 'Advanced Settings',
			'settings.station.placeholderSwr' => 'SWR reading',
			'settings.station.placeholderSwrDescription' => 'What this radio reports on its SWR meter while transmitting. Above 1.8 the panel warns.',
			'settings.station.placeholderSwrInvalid' => 'A number, 1 or more',
			'settings.station.keyerNone' => 'None',
			'settings.station.cwDialect' => 'CW keying dialect',
			'settings.station.cwDialectDescription' => 'Which shape of the KY command this radio takes. None means no CW keying over CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, padded to 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY text)',
			'settings.station.voiceDialect' => 'Voice keyer dialect',
			'settings.station.voiceDialectDescription' => 'How this radio plays its voice memories over CAT. None means no voice memories over CAT. With a dialect and no count, the dialect\'s default count applies.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, TS-590 style)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB and DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (switch taps)',
			'settings.station.placeholderDiagnostic' => 'Simulated',
			'settings.station.placeholderWholeNumberInvalid' => 'Must be a whole number, 0 or more',
			'settings.station.placeholderFreqInvalid' => 'Must be a frequency in kHz, greater than zero',
			'settings.station.placeholderModeInvalid' => 'Must be a mode name, e.g. USB, CW, FT8',
			'settings.station.switchLayout' => 'Layout',
			'settings.station.switchLayoutDescription' => 'Which side of the switch your radios are plugged into.',
			'settings.station.switchLayoutRequired' => 'Choose how the switch is wired',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'The switch refused "${command}" (error ${code})',
			'settings.station.switchBusyTransmitting' => 'That port is transmitting — antenna not changed',
			'settings.station.switchNoAntenna' => 'None',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenna on port ${port}',
			'settings.station.switchAntennaForDescription' => 'Which of your antennas is connected to this port on the switch.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} Antennas, ${radios} Radios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} Antennas, 1 Radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 Antenna, ${radios} Radios',
			'settings.station.switchCommonPort' => 'Common',
			'settings.station.dcnAddress' => 'Device address',
			'settings.station.dcnAddressDescription' => 'The address set on the module\'s DIP switches. A coax relay module leaves the factory at 2.',
			'settings.station.dcnAddressRequired' => 'Must be a device address from 1 to 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'follows band data',
			'settings.station.switchPortTransmittingHint' => 'transmitting — cannot change now',
			'settings.station.switchCurrentStateHeader' => 'Current State',
			'settings.station.switchCurrentStateDescription' => 'Which antenna each radio port is on right now. Changes take effect immediately.',
			'settings.station.switchWiringHeader' => 'Wiring',
			'settings.station.switchPortInhibitedHint' => 'transmit inhibited',
			'settings.station.configUnreadable' => 'This radio\'s saved settings could not be read. Open its settings and enter them again, or remove it and add it back.',
			'settings.station.autoConnectHeld' => 'HaLo stopped responding the last time it connected to this radio, so it did not connect on its own this time. Press Connect to try again.',
			'settings.offlineData.title' => 'Offline Data',
			'settings.offlineData.noFiles' => 'No data files',
			'settings.offlineData.noFilesDescription' => 'Enable activity or lookup extensions to download their offline data here.',
			'settings.offlineData.refresh' => 'Refresh',
			'settings.offlineData.refreshing' => 'Refreshing…',
			'settings.offlineData.updateAll' => 'Update All',
			'settings.offlineData.updatingAll' => 'Updating all data files…',
			'settings.offlineData.neverDownloaded' => 'Never downloaded',
			'settings.offlineData.updatedJustNow' => 'Updated just now',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Updated ${days}d ago',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Updated ${days}d ${hours}h ago',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Updated ${hours}h ago',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Updated ${hours}h ${minutes}m ago',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Updated ${minutes}m ago',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'The last download had only ${imported} of ${existing} records and was not used. Refresh to accept it.',
			'settings.offlineData.extensionsSection' => 'Extensions',
			'settings.profiles.notSet' => 'Not set',
			'settings.profiles.personalInfo' => 'Personal Info',
			'settings.profiles.personalInfoNote' => 'This might be included in generated logs when relevant for submissions',
			'settings.profiles.name' => 'Name',
			'settings.profiles.email' => 'Email',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'ARRL Section',
			'settings.profiles.racSection' => 'RAC Section',
			'settings.profiles.section' => 'Section',
			'settings.search.clear' => 'Clear',
			'settings.search.hint' => 'Search preferences',
			'settings.developer.developerModeDescription' => 'Enable developer warnings, debug logs, and tools.',
			'settings.developer.experiments' => 'Experiments',
			'settings.developer.showIdleMetrics' => 'Show idle metrics',
			'settings.developer.showIdleMetricsDescription' => 'Show in the status bar how idle the extension engine has been over the last second. Tap it for the 10- and 60-second averages.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% idle',
			'settings.developer.idleMetricsAverages' => 'Idle avg:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} enabled', other: '${count} enabled', ), 
			'settings.developer.patchTrack' => 'Code Push Track',
			'settings.developer.patchTrackDescription' => 'Which over-the-air code push ring this device follows. More adventurous rings get fixes earlier, less tested. Code pushes apply on the next restart.',
			'settings.developer.trackStable' => 'Stable',
			'settings.developer.trackUnstable' => 'Unstable',
			'settings.developer.trackBleeding' => 'Bleeding',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Checking "${track}" for a code push…',
			'settings.developer.patchDownloaded' => 'Code push downloaded — restart the app to apply it.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'No new code push on "${track}".',
			'settings.developer.noPatchInstalled' => 'No code push installed — running the release binary.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Running code push #${patch}.',
			'settings.developer.deepLinks' => 'Deep links',
			'settings.developer.registerUrlSchemes' => 'Register URL schemes',
			'settings.developer.registerUrlSchemesDescription' => 'Let com.ham2k:// links open this copy of the app',
			'settings.developer.registerUrlSchemesDone' => 'This copy now opens com.ham2k:// links',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Could not register: ${error}',
			'settings.developer.systemInformation' => 'System Information',
			'settings.developer.appVersion' => 'App Version',
			'settings.developer.dataFolder' => 'Data Folder',
			'settings.developer.loading' => '(loading…)',
			'settings.developer.panelLoadFailed' => 'Could not load this settings panel.',
			'settings.developer.extDevServer' => 'Extension Dev Server',
			'settings.developer.extensionSettings' => 'Extension Settings',
			'settings.developer.extDevServerDescription' => 'Load extensions from a dev server on your network instead of the ones built into the app, and reload them as you save.',
			'settings.developer.extDevServerAddress' => 'Server address',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Connect',
			'settings.developer.extDevServerDisconnect' => 'Disconnect',
			'settings.developer.extDevServerConnecting' => 'Connecting…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Serving ${count} extension: ${keys}', other: 'Serving ${count} extensions: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Not connected',
			'settings.developer.extDevServerReconnect' => 'Reconnect at launch',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Last reload: ${key} at ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} extension failing to build', other: '${count} extensions failing to build', ), 
			'settings.developer.catalog' => 'Extension Catalog',
			'settings.developer.catalogDescription' => 'Read the catalog from another server — a local one while working on the catalog itself. Empty means catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Catalog address',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Catalog Search Tracks',
			'settings.developer.catalogSearchStable' => 'Only Stable',
			'settings.developer.catalogSearchUnstable' => 'Unstable or better',
			'settings.developer.catalogSearchBleeding' => 'Bleeding or better',
			'settings.about.notices' => 'Notices & Messages',
			'settings.about.noticesDescription' => 'Announcements and status messages',
			'settings.about.releaseNotes' => 'Release Notes',
			'settings.about.copiedVersion' => 'Copied version details to clipboard',
			'settings.panels.settings' => 'Application Preferences',
			'settings.panels.settingsDescription' => 'Make the app work how you want it',
			'settings.panels.commonSettings' => 'Common Preferences',
			'settings.panels.syncDescription' => 'Back up and sync your logs across devices',
			'settings.panels.accountsDescription' => 'Service credentials, offline data, and more',
			'settings.panels.extensions' => 'Extensions & Features',
			'settings.panels.extensionsDescription' => 'Activities, Contests, Dashboard Panels and more features',
			'settings.panels.profilesDescription' => 'Operator callsign and station profile',
			'settings.panels.stationProfiles' => 'Station Profiles',
			'settings.panels.developerSettings' => 'Developer Settings',
			'settings.panels.developerSettingsDescription' => 'Debugging and development tools',
			'settings.panels.about' => 'About',
			'settings.panels.aboutDescription' => 'Version, credits, and legal information',
			'settings.panels.unavailableTitle' => 'Some settings are unavailable',
			'settings.panels.unavailableText' => 'The extension runtime failed to start, so extension-contributed settings are missing.',
			'settings.panels.station' => 'Station Configuration',
			'settings.panels.stationDescription' => 'CAT control and more options',
			'settings.panels.peers' => 'Peer Devices',
			'settings.panels.peersDescription' => 'Connect to other devices nearby',
			'settings.showMoreSettings' => 'Show more settings',
			'settings.numberFormat' => 'Number Formatting',
			'settings.numberFormatOpts.locale' => 'Follow system settings',
			'settings.numberFormatOpts.period' => 'Always use period for decimals',
			'settings.numberFormatOpts.comma' => 'Always use comma for decimals',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => 'System settings (using ${separator} for decimals)',
			'settings.numberFormatDescription.period' => 'Always using period for decimals',
			'settings.numberFormatDescription.comma' => 'Always using comma for decimals',
			'settings.numberFormatSeparators.comma' => 'comma',
			'settings.numberFormatSeparators.period' => 'period',
			_ => null,
		} ?? switch (path) {
			'settings.gridPrecision' => 'Grid Precision',
			'settings.gridPrecisionOpts.six' => '6 digits (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 digits (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 digits',
			'settings.gridPrecisionDescription.eight' => '8 digits',
			'commands.enableSyncFirst' => 'Enable sync in Settings first.',
			'commands.fullResyncStarted' => 'Full resync started — local data was backed up first.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'No data files matched "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Reload failed: ${error}',
			'commands.reloadingAll' => 'Reloading all data files…',
			'commands.reloadingTarget' => ({required Object target}) => 'Reloading ${target} data files…',
			'commands.unknownExperiment' => ({required Object token}) => 'Unknown experiment "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} enabled',
			'commands.experimentDisabled' => ({required Object name}) => '${name} disabled',
			'commands.sentryTestSent' => 'Test error report sent to Sentry',
			'commands.idleMetricsEnabled' => 'Idle metrics enabled in the status bar',
			'commands.idleMetricsDisabled' => 'Idle metrics disabled',
			'commands.sentryTestLocalOnly' => 'Sentry is disabled in this build — test error logged locally only',
			'commands.noOperationOpen' => 'That command needs an open operation',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Don\'t know how to mark a \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} isn\'t turned on in this app',
			'commands.goUnknown' => ({required Object to}) => 'Don\'t know how to go to \'${to}\'',
			'commands.goBlocked' => 'Close the open dialog first',
			'commands.operationAlreadyStarted' => 'This operation already has a start marker',
			'commands.couldNotOpenLocation' => 'Added the break, but could not open the location screen',
			'commands.noTestOperations' => 'No Test Operations to purge',
			'commands.purgeTestsUnavailable' => 'PURGETESTS needs to show a confirmation dialog, which isn\'t available here',
			'commands.syncAllUnavailable' => 'SYNCALL needs to show a confirmation dialog, which isn\'t available here',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Purged ${count} Test Operation', other: 'Purged ${count} Test Operations', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Purged ${purged} of ${total} Test Operations — the rest failed; try PURGETESTS again',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Purged ${count} test contact with no operation', other: 'Purged ${count} test contacts with no operation', ), 
			'commands.purgeTestsContactsFailed' => 'Purged the Test Operations, but the test contacts with no operation failed; try PURGETESTS again',
			'commands.purgeTestsNothingToDo' => 'Nothing was purged',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Removed ${removed} of ${total} Test Operations — the rest failed; try Review again',
			'commands.receivedPurgesFailed' => 'Couldn\'t remove those Test Operations — try Review again',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} Test Operation was removed on another device', other: '${count} Test Operations were removed on another device', ), 
			'commands.receivedPurgesReview' => 'Review',
			'commands.settingOn' => 'On',
			'commands.settingOff' => 'Off',
			'commands.settingEmpty' => '(empty)',
			'commands.settingSecretSet' => '(set)',
			'commands.settingSecretUnset' => '(not set)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selected',
			'commands.settingExpectsOnOff' => 'on or off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'one of: ${choices}',
			'commands.settingExpectsNumber' => 'a number',
			'commands.settingVanished' => ({required Object label}) => '“${label}” is no longer available',
			'commands.noCwKeyer' => 'No connected radio can key CW',
			'commands.noKeyer' => 'No connected radio can key CW or play voice memories',
			'commands.keyerNeedsOperation' => 'Open an operation to use the CW keyer',
			'commands.keyerExperimentOff' => 'CW keying is off — turn it on with EXP KEYER',
			'commands.esmExperimentOff' => 'Enter Sends Messages is off — turn it on with EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Sending CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW message F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW message F${n} was not sent: the extensions are not ready',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” did not accept that value',
			'commandDialog.hint' => 'Search callsigns or type a command',
			'commandDialog.noResults' => ({required Object text}) => 'Nothing matches “${text}”',
			'commandDialog.sectionCommands' => 'Commands',
			'commandDialog.sectionGoTo' => 'Go to',
			'commandDialog.sectionOperations' => 'Operations',
			'commandDialog.goHome' => 'Home',
			'commandDialog.goSettings' => 'Settings',
			'commandDialog.goNewOperation' => 'New operation',
			'commandDialog.runTyped' => ({required Object text}) => 'Run “${text}”',
			'commandDialog.sectionSuggestions' => 'Try',
			'commandDialog.lookingUp' => 'Looking up callsign…',
			'commandDialog.blockedByPane' => 'Cannot use commands while a panel or dialog is open',
			'keyboardShortcuts.title' => 'Keyboard Shortcuts',
			'keyboardShortcuts.description' => 'Customize key mappings',
			'keyboardShortcuts.search' => 'Search commands and keys',
			'keyboardShortcuts.import' => 'Import…',
			'keyboardShortcuts.export' => 'Export…',
			'keyboardShortcuts.resetAll' => 'Reset All',
			'keyboardShortcuts.resetAllTitle' => 'Reset every shortcut?',
			'keyboardShortcuts.resetAllBody' => 'Every command goes back to its default keys, and the keys bound to typed commands are removed.',
			'keyboardShortcuts.reset' => 'Reset',
			'keyboardShortcuts.noKey' => 'No key',
			'keyboardShortcuts.changed' => 'Changed',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} is also bound to ${commands}',
			'keyboardShortcuts.groupApp' => 'App',
			'keyboardShortcuts.groupKeying' => 'Keying',
			'keyboardShortcuts.groupLogging' => 'Logging',
			'keyboardShortcuts.groupCommands' => 'Commands',
			'keyboardShortcuts.groupFixed' => 'Fixed Keys',
			'keyboardShortcuts.contextApp' => 'Anywhere',
			'keyboardShortcuts.contextLogView' => 'Operation, Chasing and Logs views',
			'keyboardShortcuts.contextOperation' => 'Operation view, keying a CAT radio',
			'keyboardShortcuts.contextLogging' => 'In the logging panel',
			'keyboardShortcuts.addCommand' => 'Add a Command…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Unknown command: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Open the command dialog',
			'keyboardShortcuts.command.toggleTheme' => 'Switch between light and dark',
			'keyboardShortcuts.command.toggleLanguage' => 'Switch between English and Spanish',
			'keyboardShortcuts.command.fontScaleUp' => 'Larger text',
			'keyboardShortcuts.command.fontScaleDown' => 'Smaller text',
			'keyboardShortcuts.command.fontScaleReset' => 'Normal text size',
			'keyboardShortcuts.command.densityLooser' => 'Roomier layout',
			'keyboardShortcuts.command.densityDenser' => 'Denser layout',
			'keyboardShortcuts.command.densityAuto' => 'Automatic layout density',
			'keyboardShortcuts.command.find' => 'Find in the log',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Send message ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Keyboard mode on or off',
			'keyboardShortcuts.command.ptt' => 'Push to talk',
			'keyboardShortcuts.command.wipe' => 'Clear the contact being logged',
			'keyboardShortcuts.fixed.callsign' => 'Typing callsigns',
			'keyboardShortcuts.fixed.escape' => 'Stop sending, back out one step, or close',
			'keyboardShortcuts.fixed.enter' => 'Log the contact',
			'keyboardShortcuts.fixed.space' => 'Next field',
			'keyboardShortcuts.fixed.tab' => 'Next or previous field',
			'keyboardShortcuts.fixed.arrows' => 'Move between fields, controls and the log',
			'keyboardShortcuts.fixed.walk' => 'Page through the log, or go to its ends',
			'keyboardShortcuts.fixed.undo' => 'Take back a wipe or a delete',
			'keyboardShortcuts.editor.addShortcut' => 'Add Shortcut',
			'keyboardShortcuts.editor.listening' => 'Press the keys for the shortcut…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc stops listening',
			'keyboardShortcuts.editor.add' => 'Add',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} belongs to the logging fields or a dialog, and can’t be changed.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} is how callsigns are typed. Hold Cmd, Ctrl or Alt with it.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'The system may take ${keys} before the app sees it.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} is already one of this command’s keys.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Take ${keys} from “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'Reset to Default',
			'keyboardShortcuts.editor.remove' => 'Remove',
			'keyboardShortcuts.editor.commandLabel' => 'Command',
			'keyboardShortcuts.editor.commandHint' => 'Enter any valid command, or multiple commands separated by ";"',
			'keyboardShortcuts.editor.removeCommand' => 'Remove Command',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'No command reads “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'No key yet',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Shortcuts saved to ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'Couldn’t export the shortcuts: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'Couldn’t open the file: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} isn’t a shortcuts file this app can read: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'the text isn’t valid YAML (line ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'it isn’t a Ham2K keyboard shortcuts file',
			'keyboardShortcuts.file.problemNewerVersion' => 'it was written by a newer version of the app',
			'keyboardShortcuts.file.problemMalformed' => 'part of it doesn’t follow the shortcuts format',
			'keyboardShortcuts.file.problemTooLarge' => 'it is too large',
			'keyboardShortcuts.file.importTitle' => 'Import Shortcuts',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Written on ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'The file doesn’t say which keyboard it was written on.',
			'keyboardShortcuts.file.translate' => 'What should each of these keys be on this keyboard?',
			'keyboardShortcuts.file.leaveOut' => 'Leave those shortcuts out',
			'keyboardShortcuts.file.replace' => 'Replace this device’s config',
			'keyboardShortcuts.file.replaceHint' => 'Every shortcut not in the file goes back to its default.',
			'keyboardShortcuts.file.merge' => 'Add to this device’s config',
			'keyboardShortcuts.file.mergeHint' => 'The file’s shortcuts replace this device’s for the same commands, and the rest stay.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'Not known in this version, so left out: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'Not shortcuts, so left out: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Keys the app keeps for itself, so left out: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Bound to more than one command after the import: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Import',
			'keyboardShortcuts.file.imported' => 'Shortcuts imported',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'This build has expired',
			'expiredBuild.body' => 'Please visit ham2k.com and get a newer version.',
			'expiredBuild.visit' => 'Visit ham2k.com',
			'expiredBuild.dismiss' => 'Continue anyway',
			'staleness.codePushFloorTitle' => 'An important update is waiting',
			'staleness.codePushFloorBody' => 'This version has a fix you don\'t have yet.',
			'staleness.restartToApply' => 'Restart the app to apply it.',
			'staleness.quitAndReopen' => 'Quit the app and open it again to apply it.',
			'staleness.reopenToApply' => 'Close the app and open it again to apply it.',
			'staleness.ignoreForNow' => 'Ignore for now',
			'spotting.noQsoYet' => 'No QSO logged yet to spot.',
			'spotting.setFrequencyFirst' => 'Set a frequency first.',
			'spotting.nothingToSpot' => 'Nothing to spot — no extension offers spotting here.',
			'spotting.incompleteCall' => 'Can\'t spot an incomplete call — finish the callsign first.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} failed: ${message}',
			'spotting.unknownError' => 'unknown error',
			'spotting.notSent' => 'Spot not sent.',
			'spotting.allSkipped' => 'Spot not sent: every spot source skipped it.',
			'spotting.notRefreshedOffline' => 'No connection — spots were not refreshed',
			'dataFiles.downloading' => 'Downloading…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Couldn\'t download ${name}',
			'dataFiles.downloadFailedWebHint' => 'This could be a network issue, or this link\'s host may not support direct downloads from a web browser. Try the desktop or mobile app, or a different hosting location.',
			'dataFiles.downloadTimedOut' => 'The server took too long to respond. Try again later.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} answered with an error (HTTP ${status}). Try again later.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} couldn\'t provide this file (HTTP ${status}). Check that its address is still right.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM has no call history file for ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'N1MM\'s call history download for ${stem} didn\'t work. Try again later.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Couldn\'t process ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'The download had only ${imported} of the ${existing} records on this device, so the ones it left out were kept. Refreshing it in Settings › Offline Data accepts it anyway.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Imported ${count} record for ${label}.', other: 'Imported ${count} records for ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Imported data for ${label}.',
			'dataFiles.cleanedUpTitle' => 'Cleaned up extension data',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Removed data for ${count} data file from disabled extensions.', other: 'Removed data for ${count} data files from disabled extensions.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} records',
			'dataFiles.definitionUnavailable' => 'The file\'s source didn\'t provide a definition — its extension may be mid-restart or misconfigured. Try again in a moment.',
			'updates.updateAvailable' => 'Update available',
			'updates.newVersionAvailable' => ({required Object version}) => 'A new version (${version}) is available.',
			'updates.getIt' => 'Get it',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Update ready',
			'updates.restartToApply' => 'An update has been downloaded. Restart to apply it.',
			'updates.appliesNextLaunch' => 'An update has been downloaded. It will apply the next time you open the app.',
			'updates.restartNow' => 'Restart now',
			'updates.reloadToUpdate' => 'A newer version of this page is available. Reload to get it.',
			'updates.reloadNow' => 'Reload now',
			'updates.checkForUpdates' => 'Check for Updates',
			'updates.checkingForUpdates' => 'Checking for updates…',
			'updates.upToDate' => 'Up to date',
			'updates.automaticChecks' => 'Check automatically',
			'updates.automaticChecksDescription' => 'Look for new versions in the background, from the next time you start the app',
			'extensionService.runtimeNotReady' => 'Extension runtime not ready.',
			'extensionService.testFailed' => ({required Object error}) => 'Test failed: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Connected as ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Invalid field configuration',
			'extensionService.invalidValue' => 'Invalid value',
			'extensionService.validationError' => ({required Object error}) => 'Validation error: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Action failed: ${error}',
			'extensionService.commandFailed' => 'The command failed to run',
			'extensionService.reportUnavailable' => 'Reports can\'t be sent right now',
			'extensionService.stashUnavailable' => 'Ham2K’s File Stash can’t be reached right now',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} spent too much time in its timers. They\'re stopped until the extensions restart.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name}\'s timers kept failing. They\'re stopped until the extensions restart.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} got stuck in a timer. Its timers are stopped until the extensions restart.',
			'operationLocationScreen.title' => 'Operation Location',
			'operationLocationScreen.selectedLocation' => 'Selected Location',
			'operationLocationScreen.gridSquare' => 'Maidenhead Grid Square Locator',
			'operationLocationScreen.gridInvalid' => 'Needs 4, 6, 8 or 10 characters, like FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Suggested Locations',
			'operationLocationScreen.deviceGps' => 'Device GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS from ${device}',
			'operationLocationScreen.locating' => 'Locating…',
			'operationLocationScreen.gpsUnavailable' => 'Location unavailable',
			'operationLocationScreen.permissionDenied' => 'Location permission denied',
			'operationLocationScreen.permissionBlocked' => 'Location permission blocked',
			'operationLocationScreen.moreDetails' => 'More Details',
			'operationLocationScreen.stateOrProvince' => 'State or Province (optional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Activity controls unavailable',
			'operationLocationScreen.controlsUnavailableReason' => 'These references are still usable; their activities just could not be reached.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Retry',
			'operationLocationScreen.county' => 'County (optional)',
			'versionLabel.version' => ({required Object version}) => 'Version ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'No notices yet',
			'notices.webStorageInMemory' => 'This browser could not provide persistent storage — the log lives in memory only and will be LOST when this tab closes. Use a current Chrome, Firefox, Safari or Edge.',
			'notices.webStorageUnreliable' => 'This browser is using fallback storage that is not safe with multiple tabs — keep a single tab open, and keep sync on.',
			'notices.logFromNewerBuildTitle' => 'This log needs a newer version',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Install the newer version again — or, if you meant to run this build, point it at a different data folder. The log is in ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Your log was written by a newer version of HaLo (storage version ${storage}; this one understands ${understood}), so it cannot be opened, and new contacts will not be saved. Open this log with that newer version instead.',
			'notices.preferencesRestoredTitle' => 'Settings restored from a backup',
			'notices.preferencesRestored' => 'The settings file could not be read, so HaLo restored the last good copy of it. Anything you changed in your previous session may need setting again. The unreadable file is kept alongside it, named shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Settings reset',
			'notices.preferencesReset' => 'The settings file could not be read and there was no backup to fall back on, so HaLo started with its defaults. The unreadable file is kept in the app\'s data folder, named shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} was not connected automatically',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo stopped responding the last time it started connecting to ${name}, so it left it alone this time rather than risk doing it again. Check that the radio is switched on and its cable is plugged in, then press Connect on it in Settings.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonymous Account (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (pending confirmation)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (pending confirmation - #${id})',
			'deepLink.needsAnOperation' => 'Start an operation first, then send that contact again',
			'deepLink.waitingInOperation' => 'That contact is waiting in the operation behind this screen',
			'deepLink.unknownActivities' => ({required Object refs}) => 'This device has no activity for ${refs}, so those references were left off',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Could not reach your activities, so ${refs} was left off — try that link again',
			'confirmDevice.title' => 'Confirm a Device',
			'confirmDevice.codePrompt' => 'Enter the code shown on the device that wants to join this account.',
			'confirmDevice.code' => 'Code',
			'confirmDevice.lookUp' => 'Look Up',
			'confirmDevice.codeNotFound' => 'No request matches that code. Codes expire after 10 minutes — ask the other device for a fresh one.',
			'confirmDevice.linkExpired' => 'That link has expired. Ask the other device to show a new QR code.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Link ${device} to this account?',
			'confirmDevice.unnamedDevice' => 'an unnamed device',
			'confirmDevice.grantWarning' => 'It will be able to read and change every operation and QSO in this account.',
			'confirmDevice.needsSyncTitle' => 'This device does not sync yet',
			'confirmDevice.needsSyncText' => 'Turn on Ham2K Log Filer sync and link this device to an account before it can admit another one.',
			'confirmDevice.malformedRequest' => 'The sync server sent a request this app could not read. Ask the other device to try again.',
			'confirmDevice.linkIt' => 'Link Device',
			'switchAccounts.noAccountDetails' => 'No account details yet',
			'switchAccounts.currentAccount' => 'Current account',
			'switchAccounts.otherAccounts' => 'Other accounts',
			'switchAccounts.linkToAnother' => 'Link to another account',
			'switchAccounts.linkWithSibling' => 'Link with other Ham2K App',
			'switchAccounts.linkWithPolo' => 'Link with account in older version',
			'switchAccounts.linkWithSiblingDescription' => 'You have another Ham2K app installed. Link with the account in use there.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Approve the request in ${app}, then come back here.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Open ${app} again',
			'switchAccounts.siblingNoGrant' => 'Didn\'t work? Open it again, or go back and link another way.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Could not open ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'The link expired and a new one is ready — open ${app} again.',
			'switchAccounts.tryAgain' => 'Try again',
			'switchAccounts.linkWithQr' => 'Link with a QR code',
			'switchAccounts.linkWithQrDescription' => 'Scan it from a device already using the account',
			'switchAccounts.linkWithEmail' => 'Link with an email address',
			'switchAccounts.linkWithEmailDescription' => 'Confirm with a code or an email link',
			'switchAccounts.enterEmailPrompt' => 'Enter the email address of the account you want this device to use.',
			'switchAccounts.emailAddress' => 'Email address',
			'switchAccounts.linkAccount' => 'Link account',
			'switchAccounts.copiedCode' => 'Copied code to clipboard',
			'switchAccounts.copyCode' => 'Copy code',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Open the Ham2K app on a device already linked with ${email} and enter this code to approve the request:',
			'switchAccounts.waitingForConfirmation' => 'Waiting for confirmation…',
			'switchAccounts.sendEmailInstead' => 'Send a confirmation email instead',
			'switchAccounts.emailSent' => ({required Object email}) => 'An email was sent to ${email}. Open it and confirm the request to link this device.',
			'switchAccounts.resendEmail' => 'Resend email',
			'switchAccounts.qrPrompt' => 'Scan this QR code from a device already linked to the account you want — for example with Ham2K Portable Logger on your phone.',
			'switchAccounts.serverUnreachable' => 'Could not reach the sync server. Try again later.',
			'switchAccounts.emailRequired' => 'Enter an email address to link.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'No account found for ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'The sync server rejected the request: ${error}',
			'switchAccounts.noLinkCode' => 'The sync server did not return a link code. Try again later.',
			'switchAccounts.noConfirmationCode' => 'The sync server did not send a confirmation code. Try again later.',
			'switchAccounts.switchNotAccepted' => 'That account did not accept the switch. Try linking it with an email address instead.',
			'switchAccounts.requestFailed' => 'Something went wrong talking to the sync server. Try again later.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} operation', other: '${count} operations', ), 
			'qsonImport.title' => 'Import QSON Operation',
			'qsonImport.description' => 'Create a new operation from a QSON file, as Developer Mode exports one here or in PoLo.',
			'qsonImport.dropHint' => 'Drop a QSON file to import it as a new operation',
			'qsonImport.importing' => ({required Object filename}) => 'Importing ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'Could not import ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'Could not open a file to import: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} is not UTF-8 text, so it is not a QSON file',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} is not a JSON file, so it is not a QSON file',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} does not hold a QSON operation',
			'qsonImport.busy' => 'An import is already running. Wait for it to finish before starting another.',
			'qsonImport.oneFileOnly' => 'Drop one QSON file at a time — each one opens as its own operation.',
			'adifImport.title' => 'Import QSOs from ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Reading ${filename}…',
			'adifImport.dropHint' => 'Drop an ADIF file to import',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} QSO in this file', other: '${formatted} QSOs in this file', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} already in your log', other: '${formatted} already in your log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} will be imported', other: '${formatted} will be imported', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} new contact', other: '${formatted} new contacts', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} will merge with an existing contact', other: '${formatted} will merge with existing contacts', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} cannot be imported (no callsign)', other: '${formatted} cannot be imported (no callsign)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} needs a closer look', other: '${formatted} need a closer look', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'References could not be recovered for ${count} contact', other: 'References could not be recovered for ${formatted} contacts', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${programs} references may be incomplete for ${count} contact', other: '${programs} references may be incomplete for ${formatted} contacts', ), 
			'adifImport.stackingTypesUnknown' => 'Combined contacts may lose a reference — the activities could not say which types stack. Cancel and retry to avoid this.',
			'adifImport.nothingToImport' => 'Nothing in this file can be imported',
			'adifImport.confirm' => 'Import',
			'adifImport.importing' => ({required Object filename}) => 'Importing ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Imported ${count} contact from ${filename}', other: 'Imported ${formatted} contacts from ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Could not import ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} does not look like an ADIF file',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Warning: this ADIF has QSOs from ${calls}, but they will be imported as ${station} if you continue.',
			'adifImport.stationCallJoin' => ' and ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} has no date and cannot be imported', other: '${formatted} have no date and cannot be imported', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'This file records an activation of ${refs}.',
			'adifImport.addActivation' => 'Add it to this operation',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Only ${written} of ${planned} could be applied — the log changed while you were deciding.',
			'adifImport.busy' => 'An import is already running. Wait for it to finish before starting another.',
			'adifImport.oneFileOnly' => 'Drop one ADIF file at a time — the order files are imported in decides which data wins.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} has more than ${limit} QSOs, the most an operation can import at a time.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: connected',
			'offline.noRoute' => 'No network connection at all.',
			'offline.unreachable' => 'The network is up, but no server is responding — often a sign-in page waiting in a browser.',
			'offline.reachable' => 'All services responding as expected.',
			'offline.whatStops' => 'Lookups, spots and data files are paused. Logging and nearby sync are not.',
			'offline.servicesTitle' => 'Services',
			'offline.noServices' => 'No service has reported in yet.',
			'offline.lastSuccess' => ({required Object when}) => 'Last responded ${when} ago',
			'offline.neverSucceeded' => 'Has not responded yet',
			'offline.nextAttempt' => ({required Object when}) => 'Next attempt in ${when}',
			'offline.nextAttemptNow' => 'Next attempt due',
			'offline.retry' => 'Retry now',
			'offline.retrying' => 'Trying…',
			'offline.retryReached' => 'Back online.',
			'offline.retryUnreachable' => 'Still no response.',
			'offline.retryNotAttempted' => 'Nothing to send right now.',
			'offline.retryThrottled' => 'Just tried — give it a moment.',
			'offline.retryDisabled' => 'Sync is switched off, so there is nothing to probe with.',
			'offline.syncService' => 'Ham2K LoFi sync',
			'offline.retryInFlight' => 'Already trying — hang on.',
			'exportSettings.defaultsDescription' => 'Base settings for all exports, with separate filename and title templates for reference activities and other activities. Each export type can provide its own defaults or custom settings.',
			'exportSettings.referenceActivities' => 'Reference Activities',
			'exportSettings.otherActivities' => 'Other Activities',
			'exportSettings.adifFields' => 'ADIF Fields',
			'exportSettings.loadFailed' => 'Export settings could not be loaded.',
			'exportSettings.retry' => 'Retry',
			'exportSettings.compactFileNamesDescriptionOn' => 'Compact filenames, such as N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Descriptive filenames, such as 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Including names, addresses, emails, notes and precise locations in ADIF files.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Omitting names, addresses, emails and notes; limiting locations to six-character grids.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Including information from callsign lookup services.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Omitting information from callsign lookup services; keeping manually entered values.',
			'exportSettings.customTemplatesDescriptionOn' => 'Your custom templates are active and can be edited below.',
			'exportSettings.customTemplatesDescriptionOff' => 'Default templates are active. Your custom templates are kept for later.',
			'exportSettings.type' => 'Export type',
			'exportSettings.defaults' => 'Defaults',
			'exportSettings.includeLookupData' => 'Include lookup data',
			'exportSettings.customTemplates' => 'Custom templates',
			'exportSettings.filenameTemplate' => 'File name template',
			'exportSettings.compactFilenameTemplate' => 'Compact file name template',
			'exportSettings.titleTemplate' => 'Title template',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO Notes',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO Comments',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL Message',
			'exportSettings.shared' => 'Settings apply to every extension using this export type.',
			'exportSettings.defaultTemplates' => 'Turn on Custom templates to edit this type’s templates.',
			'templateEditor.previewLabel' => 'Preview:',
			'templateEditor.reset' => 'Reset',
			'templateEditor.docs' => 'Templating Docs',
			'templateEditor.preview' => 'Sample preview',
			'templateEditor.reference' => 'Template reference',
			'templateEditor.attributes' => 'Available Attributes',
			'templateEditor.filters' => 'Filters',
			'templateEditor.flowControl' => 'Flow Control',
			'templateEditor.unavailable' => 'Preview is unavailable until extensions are ready.',
			'templateEditor.empty' => '(empty output)',
			_ => null,
		};
	}
}
