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
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$onboarding$en onboarding = Translations$onboarding$en.internal(_root);
	late final Translations$startScreen$en startScreen = Translations$startScreen$en.internal(_root);
	late final Translations$extensionsPanel$en extensionsPanel = Translations$extensionsPanel$en.internal(_root);
	late final Translations$home$en home = Translations$home$en.internal(_root);
	late final Translations$dialogs$en dialogs = Translations$dialogs$en.internal(_root);
	late final Translations$operation$en operation = Translations$operation$en.internal(_root);
	late final Translations$map$en map = Translations$map$en.internal(_root);
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
	late final Translations$expiredBuild$en expiredBuild = Translations$expiredBuild$en.internal(_root);
	late final Translations$spotting$en spotting = Translations$spotting$en.internal(_root);
	late final Translations$dataFiles$en dataFiles = Translations$dataFiles$en.internal(_root);
	late final Translations$updates$en updates = Translations$updates$en.internal(_root);
	late final Translations$extensionService$en extensionService = Translations$extensionService$en.internal(_root);
	late final Translations$operationLocationScreen$en operationLocationScreen = Translations$operationLocationScreen$en.internal(_root);
	late final Translations$versionLabel$en versionLabel = Translations$versionLabel$en.internal(_root);
	late final Translations$notices$en notices = Translations$notices$en.internal(_root);
	late final Translations$syncAccount$en syncAccount = Translations$syncAccount$en.internal(_root);
	late final Translations$switchAccounts$en switchAccounts = Translations$switchAccounts$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Apply'
	String get apply => 'Apply';

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

	/// en: 'Welcome to Ham2K Logger!'
	String get welcomeTitleDesktop => 'Welcome to Ham2K Logger!';

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

	/// en: 'Share Usage Data'
	String get consentUsageLabel => 'Share Usage Data';

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

// Path: extensionsPanel
class Translations$extensionsPanel$en {
	Translations$extensionsPanel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get categoryActivity => 'Activities';

	/// en: 'Contests'
	String get categoryContest => 'Contests';

	/// en: 'Callsign Lookups'
	String get categoryLookup => 'Callsign Lookups';

	/// en: 'Other Extensions'
	String get categoryOther => 'Other Extensions';

	/// en: 'Search extensions'
	String get searchHint => 'Search extensions';

	/// en: 'Activating extension changes, this may take a moment…'
	String get applying => 'Activating extension changes, this may take a moment…';

	/// en: 'No extensions match your search'
	String get noMatches => 'No extensions match your search';
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

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'Delete Operation'
	String get deleteOperationTitle => 'Delete Operation';
}

// Path: operation
class Translations$operation$en {
	Translations$operation$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$operation$tabs$en tabs = Translations$operation$tabs$en.internal(_root);

	/// en: 'No station callsign'
	String get stationCallsignNone => 'No station callsign';

	/// en: 'No title'
	String get titleNone => 'No title';

	/// en: 'Delete operation'
	String get deleteOperation => 'Delete operation';

	/// en: 'Not set'
	String get locationNone => 'Not set';

	/// en: 'General Operation'
	String get generalOperation => 'General Operation';

	/// en: 'for ${value}'
	String titleFor({required Object value}) => 'for ${value}';

	/// en: 'at ${value}'
	String titleAt({required Object value}) => 'at ${value}';

	late final Translations$operation$menu$en menu = Translations$operation$menu$en.internal(_root);
	late final Translations$operation$export$en export = Translations$operation$export$en.internal(_root);
	late final Translations$operation$spots$en spots = Translations$operation$spots$en.internal(_root);
}

// Path: map
class Translations$map$en {
	Translations$map$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No QSO locations yet. QSOs with a grid square, state, or country will show up here.'
	String get emptyState => 'No QSO locations yet.\nQSOs with a grid square, state, or country will show up here.';

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
}

// Path: activitiesView
class Translations$activitiesView$en {
	Translations$activitiesView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get title => 'Activities';

	/// en: 'Operation Setup'
	String get sheetTitle => 'Operation Setup';

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

	/// en: 'Not a valid reference'
	String get invalidReference => 'Not a valid reference';

	/// en: 'Already added'
	String get duplicateReference => 'Already added';

	/// en: 'Search by name, reference or anything else…'
	String get searchHint => 'Search by name, reference or anything else…';

	/// en: 'No suggestions'
	String get noSuggestions => 'No suggestions';

	/// en: 'Activity Types'
	String get allOptions => 'Activity Types';

	/// en: 'Determining current location… Waiting for GPS fix to find nearby references'
	String get determiningLocation => 'Determining current location…\nWaiting for GPS fix to find nearby references';

	/// en: 'Location data not available So we cannot determine nearby references'
	String get noNearbySuggestions => 'Location data not available\nSo we cannot determine nearby references';

	/// en: 'Use suggestions & search below to add one'
	String get emptySheet => 'Use suggestions & search below to add one';

	/// en: 'Exports'
	String get exports => 'Exports';

	/// en: 'Options'
	String get options => 'Options';

	/// en: 'Operation Options'
	String get optionsTitle => 'Operation Options';

	/// en: 'Operation Details'
	String get operationDetails => 'Operation Details';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Delete Operation'
	String get deleteOperation => 'Delete Operation';

	/// en: 'Already selected'
	String get alreadySelected => 'Already selected';

	/// en: 'Enable ${name}'
	String enableExtension({required Object name}) => 'Enable ${name}';

	/// en: 'This extension matches your search, but it is not currently enabled'
	String get enableExtensionHint => 'This extension matches your search, but it is not currently enabled';
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

	/// en: 'Frequency'
	String get frequency => 'Frequency';

	/// en: 'Mode'
	String get mode => 'Mode';

	/// en: 'Their call'
	String get theirCall => 'Their call';

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

	/// en: 'QSO will be deleted when you save'
	String get pendingDeleteWarning => 'QSO will be deleted when you save';

	/// en: 'Deleted QSO'
	String get deletedQsoWarning => 'Deleted QSO';

	/// en: 'Time'
	String get timeControl => 'Time';

	/// en: 'Radio'
	String get radioControl => 'Radio';

	/// en: 'Logging Controls'
	String get controlSettings => 'Logging Controls';

	/// en: 'Expand'
	String get expandControls => 'Expand';

	/// en: 'Collapse'
	String get collapseControls => 'Collapse';

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

	/// en: 'Set a frequency or band before logging'
	String get bandOrFreqRequired => 'Set a frequency or band before logging';

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

	/// en: 'Remove'
	String get removeItem => 'Remove';

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

	/// en: 'Edit time'
	String get editEventTime => 'Edit time';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'Tomorrow'
	String get tomorrow => 'Tomorrow';

	/// en: 'Operation started'
	String get eventStarted => 'Operation started';

	/// en: 'Break'
	String get eventBreak => 'Break';

	/// en: 'Operation ended'
	String get eventEnded => 'Operation ended';
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

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: '${distance} to'
	String distanceTo({required Object distance}) => '${distance} to';

	/// en: '${distance} (${bearing}°) to'
	String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to';

	/// en: '${distance} away'
	String distanceAway({required Object distance}) => '${distance} away';

	/// en: '${distance} (${bearing}°) away'
	String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';

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

	late final Translations$settings$theme$en theme = Translations$settings$theme$en.internal(_root);
	late final Translations$settings$themeDescription$en themeDescription = Translations$settings$themeDescription$en.internal(_root);

	/// en: 'Font Scale'
	String get fontScale => 'Font Scale';

	late final Translations$settings$fontScaleOpts$en fontScaleOpts = Translations$settings$fontScaleOpts$en.internal(_root);

	/// en: 'Distance Units'
	String get distanceUnits => 'Distance Units';

	late final Translations$settings$distanceUnitsOpts$en distanceUnitsOpts = Translations$settings$distanceUnitsOpts$en.internal(_root);

	/// en: 'User Interface'
	String get userInterface => 'User Interface';

	late final Translations$settings$logging$en logging = Translations$settings$logging$en.internal(_root);
	late final Translations$settings$radio$en radio = Translations$settings$radio$en.internal(_root);
	late final Translations$settings$privacy$en privacy = Translations$settings$privacy$en.internal(_root);

	/// en: 'Operator Callsign'
	String get operatorCall => 'Operator Callsign';

	late final Translations$settings$sync$en sync = Translations$settings$sync$en.internal(_root);

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

	/// en: 'Sentry is disabled in this build — test error logged locally only'
	String get sentryTestLocalOnly => 'Sentry is disabled in this build — test error logged locally only';
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

	/// en: 'Spotted on ${source}'
	String spottedOn({required Object source}) => 'Spotted on ${source}';

	/// en: '${source} failed: ${message}'
	String spotFailed({required Object source, required Object message}) => '${source} failed: ${message}';

	/// en: 'unknown error'
	String get unknownError => 'unknown error';

	/// en: 'Spot not sent.'
	String get notSent => 'Spot not sent.';
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

	/// en: 'Couldn't process ${name}'
	String processingFailedTitle({required Object name}) => 'Couldn\'t process ${name}';

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

	/// en: 'Suggested Locations'
	String get suggestedLocations => 'Suggested Locations';

	/// en: 'Device GPS'
	String get deviceGps => 'Device GPS';

	/// en: 'Locating…'
	String get locating => 'Locating…';

	/// en: 'Location unavailable'
	String get gpsUnavailable => 'Location unavailable';

	/// en: 'Location permission denied'
	String get permissionDenied => 'Location permission denied';

	/// en: 'More Details'
	String get moreDetails => 'More Details';

	/// en: 'State or Province (optional)'
	String get stateOrProvince => 'State or Province (optional)';

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

	/// en: 'Version ${version} - Build ${build}'
	String versionBuild({required Object version, required Object build}) => 'Version ${version} - Build ${build}';
}

// Path: notices
class Translations$notices$en {
	Translations$notices$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No notices yet'
	String get emptyHistory => 'No notices yet';
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

	/// en: 'Show QSO Numbers'
	String get showQsoNumbers => 'Show QSO Numbers';

	/// en: 'Lookup all QSOs'
	String get lookupAllQsos => 'Lookup all QSOs';

	/// en: 'Logging Settings'
	String get loggingSettingsTitle => 'Logging Settings';

	/// en: 'Actions'
	String get actionsSection => 'Actions';

	/// en: 'Relevant Settings'
	String get relevantSettingsSection => 'Relevant Settings';
}

// Path: operation.export
class Translations$operation$export$en {
	Translations$operation$export$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Export'
	String get title => 'Export';

	/// en: 'Operation is synced'
	String get syncedOperation => 'Operation is synced';

	/// en: 'Operation has unsynced changes'
	String get unsyncedOperation => 'Operation has unsynced changes';

	/// en: 'All ${total} QSOs are synced'
	String qsosSynced({required Object total}) => 'All ${total} QSOs are synced';

	/// en: '${pending} of ${total} QSOs pending sync'
	String qsosPending({required Object pending, required Object total}) => '${pending} of ${total} QSOs pending sync';

	/// en: 'All ${total} event markers are synced'
	String eventsSynced({required Object total}) => 'All ${total} event markers are synced';

	/// en: '${pending} of ${total} event markers pending sync'
	String eventsPending({required Object pending, required Object total}) => '${pending} of ${total} event markers pending sync';

	/// en: 'Loading export options…'
	String get loading => 'Loading export options…';

	/// en: 'No export formats available (extension runtime still starting?)'
	String get noOptions => 'No export formats available (extension runtime still starting?)';

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

	/// en: 'Export settings'
	String get settingsButton => 'Export settings';

	/// en: 'Export Settings'
	String get settingsTitle => 'Export Settings';

	late final Translations$operation$export$compactFileNames$en compactFileNames = Translations$operation$export$compactFileNames$en.internal(_root);
	late final Translations$operation$export$includePrivateData$en includePrivateData = Translations$operation$export$includePrivateData$en.internal(_root);

	/// en: 'Saved to ${path}'
	String saveSuccess({required Object path}) => 'Saved to ${path}';

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

	/// en: 'Auto'
	String get auto => 'Auto';

	/// en: 'Auto (${value})'
	String autoValue({required Object value}) => 'Auto (${value})';

	/// en: 'Any'
	String get any => 'Any';

	/// en: 'All Bands'
	String get allBands => 'All Bands';

	/// en: 'All Modes'
	String get allModes => 'All Modes';

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

	late final Translations$operation$spots$continents$en continents = Translations$operation$spots$continents$en.internal(_root);
	late final Translations$operation$spots$filters$en filters = Translations$operation$spots$filters$en.internal(_root);
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

	/// en: '${distance} away'
	String distanceAway({required Object distance}) => '${distance} away';

	/// en: '${distance} (${bearing}°) away'
	String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away';

	/// en: 'Dupe!'
	String get noticeDupe => 'Dupe!';

	/// en: 'New Band'
	String get noticeNewBand => 'New Band';

	/// en: 'New Mode'
	String get noticeNewMode => 'New Mode';

	/// en: 'New DXCC'
	String get noticeNewDXCC => 'New DXCC';

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
}

// Path: settings.theme
class Translations$settings$theme$en {
	Translations$settings$theme$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Theme Mode'
	String get title => 'Theme Mode';

	/// en: 'System'
	String get system => 'System';

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

	/// en: 'Follows system setting'
	String get system => 'Follows system setting';

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
	late final Translations$settings$logging$fieldsOnTop$en fieldsOnTop = Translations$settings$logging$fieldsOnTop$en.internal(_root);
	late final Translations$settings$logging$countryFlags$en countryFlags = Translations$settings$logging$countryFlags$en.internal(_root);
	late final Translations$settings$logging$showBearing$en showBearing = Translations$settings$logging$showBearing$en.internal(_root);
	late final Translations$settings$logging$switchSentRcvd$en switchSentRcvd = Translations$settings$logging$switchSentRcvd$en.internal(_root);
	late final Translations$settings$logging$jumpAfterRST$en jumpAfterRST = Translations$settings$logging$jumpAfterRST$en.internal(_root);
	late final Translations$settings$logging$numbersRow$en numbersRow = Translations$settings$logging$numbersRow$en.internal(_root);
	late final Translations$settings$logging$numbersRowExtra$en numbersRowExtra = Translations$settings$logging$numbersRowExtra$en.internal(_root);
	late final Translations$settings$logging$numbersRowVibrate$en numbersRowVibrate = Translations$settings$logging$numbersRowVibrate$en.internal(_root);

	/// en: 'Bands'
	String get bands => 'Bands';

	/// en: 'Modes'
	String get modes => 'Modes';
}

// Path: settings.radio
class Translations$settings$radio$en {
	Translations$settings$radio$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Radio'
	String get title => 'Radio';

	late final Translations$settings$radio$units$en units = Translations$settings$radio$units$en.internal(_root);
	late final Translations$settings$radio$smartVfoSnap$en smartVfoSnap = Translations$settings$radio$smartVfoSnap$en.internal(_root);
	late final Translations$settings$radio$snapDebounce$en snapDebounce = Translations$settings$radio$snapDebounce$en.internal(_root);
	late final Translations$settings$radio$snapLongMove$en snapLongMove = Translations$settings$radio$snapLongMove$en.internal(_root);
	late final Translations$settings$radio$snapMinMove$en snapMinMove = Translations$settings$radio$snapMinMove$en.internal(_root);
	late final Translations$settings$radio$snapMinSpeed$en snapMinSpeed = Translations$settings$radio$snapMinSpeed$en.internal(_root);
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

	/// en: 'LoFi Cloud Sync'
	String get title => 'LoFi Cloud Sync';

	/// en: 'Enable Sync'
	String get enable => 'Enable Sync';

	/// en: 'Device Key'
	String get deviceKey => 'Device Key';
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

	/// en: 'Backs up and syncs your log across devices'
	String get enabledDescription => 'Backs up and syncs your log across devices';

	/// en: 'Off — your log stays on this device only'
	String get disabledDescription => 'Off — your log stays on this device only';

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

	/// en: 'Checking…'
	String get checking => 'Checking…';

	/// en: 'Not linked yet'
	String get notLinked => 'Not linked yet';

	/// en: 'Linked as ${account}'
	String linkedAs({required Object account}) => 'Linked as ${account}';

	/// en: 'Replace local data?'
	String get replaceDialogTitle => 'Replace local data?';

	/// en: '(one) {${n} operation} (other) {${n} operations}'
	String replaceDialogOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} operation',
		other: '${n} operations',
	);

	/// en: '(one) {${n} QSO} (other) {${n} QSOs}'
	String replaceDialogQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);

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

	/// en: 'Accounts & Services'
	String get title => 'Accounts & Services';

	/// en: 'No active extensions with accounts'
	String get none => 'No active extensions with accounts';

	/// en: 'Not configured'
	String get notConfigured => 'Not configured';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'Connect to ${label}'
	String connectTo({required Object label}) => 'Connect to ${label}';

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

	/// en: 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link — from the address bar, or from the error page the browser shows — and paste it here.'
	String browserLoginSteps({required Object prefix}) => 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link — from the address bar, or from the error page the browser shows — and paste it here.';

	/// en: 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to — it starts with "${prefix}" — and paste that here.'
	String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to — it starts with "${prefix}" — and paste that here.';

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

	/// en: 'That link carries no login code. Finish signing in first, then copy the link it sends you to.'
	String get pastedLinkNoCode => 'That link carries no login code. Finish signing in first, then copy the link it sends you to.';

	/// en: 'That link looks cut off. Copy the whole thing and paste it again.'
	String get pastedLinkMalformed => 'That link looks cut off. Copy the whole thing and paste it again.';

	/// en: 'Waiting for you to finish signing in — this page will continue automatically once you do.'
	String get relayLoginWaiting => 'Waiting for you to finish signing in — this page will continue automatically once you do.';

	/// en: 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.'
	String get relayLoginNotOpened => 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.';

	/// en: 'Couldn't reach the sync server needed to complete this login. Check your connection and try again.'
	String get relayLoginUnavailable => 'Couldn\'t reach the sync server needed to complete this login. Check your connection and try again.';

	/// en: 'That login attempt didn't complete correctly. Please try connecting again.'
	String get relayLoginMalformedEvent => 'That login attempt didn\'t complete correctly. Please try connecting again.';

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

	/// en: 'Station Configuration'
	String get title => 'Station Configuration';

	/// en: 'No equipment configured'
	String get none => 'No equipment configured';

	/// en: 'Add equipment'
	String get add => 'Add equipment';

	/// en: 'Add equipment'
	String get addTitle => 'Add equipment';

	/// en: 'Looking for radios on your network…'
	String get searching => 'Looking for radios on your network…';

	/// en: 'Found'
	String get found => 'Found';

	/// en: 'Add by address'
	String get addManually => 'Add by address';

	/// en: 'Can't listen for radios: ${error}'
	String discoveryUnavailable({required Object error}) => 'Can\'t listen for radios: ${error}';

	/// en: 'Edit equipment'
	String get edit => 'Edit equipment';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'What you call it — "Left Radio". Optional.'
	String get nameDescription => 'What you call it — "Left Radio". Optional.';

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

	/// en: 'This only removes it from the app. Nothing on the equipment changes.'
	String get removeMessage => 'This only removes it from the app. Nothing on the equipment changes.';

	/// en: 'Unrecognized equipment type "${typeKey}"'
	String unknownType({required Object typeKey}) => 'Unrecognized equipment type "${typeKey}"';

	/// en: 'Not tested against this hardware'
	String get unverified => 'Not tested against this hardware';

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

	/// en: 'Add a USB device…'
	String get serialDeviceRequest => 'Add a USB device…';

	/// en: 'Speed (baud)'
	String get baudRate => 'Speed (baud)';

	/// en: 'Must match the radio's own CAT menu — a mismatch answers with garbage and no error.'
	String get baudRateDescription => 'Must match the radio\'s own CAT menu — a mismatch answers with garbage and no error.';

	/// en: 'Radio CI-V address'
	String get civAddress => 'Radio CI-V address';

	/// en: 'Hex, as shown in the radio's CI-V menu. The IC-705 ships as A4.'
	String get civAddressDescription => 'Hex, as shown in the radio\'s CI-V menu. The IC-705 ships as A4.';

	/// en: 'A CI-V address is two hex digits, 01 to FF'
	String get civAddressInvalid => 'A CI-V address is two hex digits, 01 to FF';

	/// en: 'Radio username'
	String get radioUser => 'Radio username';

	/// en: 'Radio password'
	String get radioPass => 'Radio password';

	/// en: 'The radio's own Network → Remote login, not your WiFi password.'
	String get radioLoginDescription => 'The radio\'s own Network → Remote login, not your WiFi password.';

	/// en: 'The radio's remote-control username is required'
	String get radioUserRequired => 'The radio\'s remote-control username is required';

	late final Translations$settings$station$types$en types = Translations$settings$station$types$en.internal(_root);

	/// en: 'If the radio connects but shows no frequency'
	String get troubleshootingTitle => 'If the radio connects but shows no frequency';

	/// en: 'The radio is receiving commands but answering nothing. Almost always one of: - **CAT RTS must be OFF at the radio** (FT-891 menu **05-08**). With it on, the radio waits for a handshake line the app deliberately never raises — on a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter. - **Speed must match** the radio's CAT RATE (menu **05-06**). A mismatch answers with garbage, or nothing, and never with an error. - **Another app may hold the port** — WSJT-X, fldigi and rigctld all keep it open.'
	String get ft891Troubleshooting => 'The radio is receiving commands but answering nothing. Almost always one of:\n\n- **CAT RTS must be OFF at the radio** (FT-891 menu **05-08**). With it on, the radio waits for a handshake line the app deliberately never raises — on a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter.\n- **Speed must match** the radio\'s CAT RATE (menu **05-06**). A mismatch answers with garbage, or nothing, and never with an error.\n- **Another app may hold the port** — WSJT-X, fldigi and rigctld all keep it open.';

	/// en: 'Connected'
	String get statusConnected => 'Connected';

	/// en: 'Current Configuration'
	String get currentConfiguration => 'Current Configuration';

	/// en: 'Transceiver for Main VFO'
	String get transceiverForMainVfo => 'Transceiver for Main VFO';

	/// en: 'Equipment Inventory'
	String get equipmentInventory => 'Equipment Inventory';

	/// en: 'None'
	String get noTransceiver => 'None';

	/// en: 'If two serial ports show up for the same radio'
	String get icomCivTroubleshootingTitle => 'If two serial ports show up for the same radio';

	/// en: 'Several Icom radios — the IC-705 among them — present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that — the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists. If commands go out and the radio never answers, try the other port next.'
	String get icomCivTroubleshooting => 'Several Icom radios — the IC-705 among them — present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that — the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists. If commands go out and the radio never answers, try the other port next.';

	/// en: 'If the app cannot connect'
	String get rigctldTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib's own backend talks to the radio and supports hundreds of models. - **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio's model number with `rigctl -l`. - **From another machine**, start it with `-T 0.0.0.0` — by default rigctld only accepts connections from the machine it runs on. - **Port** is 4532 unless you started the daemon with `-t`. - Once connected, a missing frequency usually means the daemon itself cannot reach the radio — test it with `rigctl -m 2 f` on the daemon's machine.'
	String get rigctldTroubleshooting => 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib\'s own backend talks to the radio and supports hundreds of models.\n\n- **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio\'s model number with `rigctl -l`.\n- **From another machine**, start it with `-T 0.0.0.0` — by default rigctld only accepts connections from the machine it runs on.\n- **Port** is 4532 unless you started the daemon with `-t`.\n- Once connected, a missing frequency usually means the daemon itself cannot reach the radio — test it with `rigctl -m 2 f` on the daemon\'s machine.';

	/// en: 'If the app cannot connect'
	String get flrigTroubleshootingTitle => 'If the app cannot connect';

	/// en: 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models. - **flrig must already be running**, with its transceiver configured and connected. - **Port** is 12345 unless you changed it in flrig's configuration (Config → Setup → Server). - **From another machine**, make sure flrig's server is reachable — it listens on all interfaces, but your firewall may not agree. - Once connected, a missing frequency usually means flrig itself cannot reach the radio — check that flrig's own display is following the dial.'
	String get flrigTroubleshooting => 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **Port** is 12345 unless you changed it in flrig\'s configuration (Config → Setup → Server).\n- **From another machine**, make sure flrig\'s server is reachable — it listens on all interfaces, but your firewall may not agree.\n- Once connected, a missing frequency usually means flrig itself cannot reach the radio — check that flrig\'s own display is following the dial.';

	/// en: 'If the radio never answers'
	String get ic705TroubleshootingTitle => 'If the radio never answers';

	/// en: 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it. - **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does. - **Check the radio's network settings** — that WLAN is on, it is on the same network, and its remote-control (Network) function is enabled. - **Power-cycle the radio's WLAN** if it stays stuck. That reliably clears a session the radio is genuinely holding. A **wrong password is refused explicitly**, not met with silence — so if you got here rather than a "rejected" message, the password is not the problem.'
	String get ic705Troubleshooting => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings** — that WLAN is on, it is on the same network, and its remote-control (Network) function is enabled.\n- **Power-cycle the radio\'s WLAN** if it stays stuck. That reliably clears a session the radio is genuinely holding.\n\nA **wrong password is refused explicitly**, not met with silence — so if you got here rather than a "rejected" message, the password is not the problem.';

	/// en: 'Not responding'
	String get statusStale => 'Not responding';

	/// en: 'Current radio settings'
	String get currentRadioSettings => 'Current radio settings';
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
}

// Path: settings.search
class Translations$settings$search$en {
	Translations$settings$search$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Search settings'
	String get hint => 'Search settings';
}

// Path: settings.developer
class Translations$settings$developer$en {
	Translations$settings$developer$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Developer Options'
	String get options => 'Developer Options';

	/// en: 'Enable developer warnings, debug logs, and tools.'
	String get developerModeDescription => 'Enable developer warnings, debug logs, and tools.';

	/// en: 'Experiments'
	String get experiments => 'Experiments';

	/// en: '(one) {${count} enabled} (other) {${count} enabled}'
	String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} enabled',
		other: '${count} enabled',
	);

	/// en: 'Patch Track'
	String get patchTrack => 'Patch Track';

	/// en: 'Which over-the-air patch ring this device follows. More adventurous rings get fixes earlier, less tested. Patches apply on the next restart.'
	String get patchTrackDescription => 'Which over-the-air patch ring this device follows. More adventurous rings get fixes earlier, less tested. Patches apply on the next restart.';

	/// en: 'Stable'
	String get trackStable => 'Stable';

	/// en: 'Unstable'
	String get trackUnstable => 'Unstable';

	/// en: 'Bleeding'
	String get trackBleeding => 'Bleeding';

	/// en: 'Checking "${track}" for a patch…'
	String checkingTrack({required Object track}) => 'Checking "${track}" for a patch…';

	/// en: 'Patch downloaded — restart the app to apply it.'
	String get patchDownloaded => 'Patch downloaded — restart the app to apply it.';

	/// en: 'No new patch on "${track}".'
	String noNewPatch({required Object track}) => 'No new patch on "${track}".';

	/// en: 'No patch installed — running the release binary.'
	String get noPatchInstalled => 'No patch installed — running the release binary.';

	/// en: 'Running patch #${patch}.'
	String runningPatch({required Object patch}) => 'Running patch #${patch}.';

	/// en: 'System Information'
	String get systemInformation => 'System Information';

	/// en: 'Active Extensions'
	String get activeExtensions => 'Active Extensions';

	/// en: 'App Version'
	String get appVersion => 'App Version';

	/// en: 'Data Folder'
	String get dataFolder => 'Data Folder';

	/// en: '(loading…)'
	String get loading => '(loading…)';

	/// en: 'Extension runtime not available.'
	String get runtimeNotAvailable => 'Extension runtime not available.';

	/// en: 'Could not load this settings panel.'
	String get panelLoadFailed => 'Could not load this settings panel.';

	/// en: 'Core & Runtime'
	String get categoryCore => 'Core & Runtime';
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

	/// en: 'Common Preferences'
	String get commonPreferences => 'Common Preferences';

	/// en: 'Appearance, language, and everyday settings'
	String get commonPreferencesDescription => 'Appearance, language, and everyday settings';

	/// en: 'All Settings'
	String get allSettings => 'All Settings';

	/// en: 'Every available setting in one place'
	String get allSettingsDescription => 'Every available setting in one place';

	/// en: 'Back up and sync your logs across devices'
	String get syncDescription => 'Back up and sync your logs across devices';

	/// en: 'Sign in to online services and lookups'
	String get accountsDescription => 'Sign in to online services and lookups';

	/// en: 'Features & Extensions'
	String get extensions => 'Features & Extensions';

	/// en: 'Turn optional features on or off'
	String get extensionsDescription => 'Turn optional features on or off';

	/// en: 'Operator callsign and station profile'
	String get profilesDescription => 'Operator callsign and station profile';

	/// en: 'Station Profiles'
	String get stationProfiles => 'Station Profiles';

	/// en: 'Data Files'
	String get dataFiles => 'Data Files';

	/// en: 'Manage cached data sources'
	String get dataFilesDescription => 'Manage cached data sources';

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

	/// en: 'Radios and other equipment'
	String get stationDescription => 'Radios and other equipment';
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

	/// en: 'Names, towns, gridsquares and notes are included'
	String get descriptionOn => 'Names, towns, gridsquares and notes are included';

	/// en: 'Names, towns, gridsquares and notes are left out'
	String get descriptionOff => 'Names, towns, gridsquares and notes are left out';

	/// en: 'The Full ADIF Export always includes everything'
	String get note => 'The Full ADIF Export always includes everything';
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

	/// en: 'Group Calls with Notes'
	String get groupCallsWithNotes => 'Group Calls with Notes';
}

// Path: settings.logging.leftieMode
class Translations$settings$logging$leftieMode$en {
	Translations$settings$logging$leftieMode$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Leftie Mode'
	String get title => 'Leftie Mode';

	/// en: 'Use layout for left-handed users'
	String get descriptionOn => 'Use layout for left-handed users';

	/// en: 'Use layout for right-handed users'
	String get descriptionOff => 'Use layout for right-handed users';
}

// Path: settings.logging.fieldsOnTop
class Translations$settings$logging$fieldsOnTop$en {
	Translations$settings$logging$fieldsOnTop$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fields on top'
	String get title => 'Fields on top';

	/// en: 'Logging fields above the QSO list, most recent first'
	String get descriptionOn => 'Logging fields above the QSO list, most recent first';

	/// en: 'Logging fields below the QSO list'
	String get descriptionOff => 'Logging fields below the QSO list';
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

// Path: settings.logging.showBearing
class Translations$settings$logging$showBearing$en {
	Translations$settings$logging$showBearing$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show Bearing'
	String get title => 'Show Bearing';

	/// en: 'Show estimated bearing to station'
	String get descriptionOn => 'Show estimated bearing to station';

	/// en: 'Don't show bearing information'
	String get descriptionOff => 'Don\'t show bearing information';
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

	/// en: 'Jump after RST is entered'
	String get descriptionOn => 'Jump after RST is entered';

	/// en: 'Don't jump automatically'
	String get descriptionOff => 'Don\'t jump automatically';
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
}

// Path: settings.radio.smartVfoSnap
class Translations$settings$radio$smartVfoSnap$en {
	Translations$settings$radio$smartVfoSnap$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart VFO Snap'
	String get title => 'Smart VFO Snap';

	/// en: 'After you stop turning the dial, round the frequency to a sensible step. Voice modes only.'
	String get descriptionOn => 'After you stop turning the dial, round the frequency to a sensible step. Voice modes only.';

	/// en: 'The radio stays exactly where you tuned it.'
	String get descriptionOff => 'The radio stays exactly where you tuned it.';
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

	/// en: 'Move less than this and nothing is rounded — fine tuning is left alone.'
	String get description => 'Move less than this and nothing is rounded — fine tuning is left alone.';
}

// Path: settings.radio.snapMinSpeed
class Translations$settings$radio$snapMinSpeed$en {
	Translations$settings$radio$snapMinSpeed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smart Snap: Slowest move'
	String get title => 'Smart Snap: Slowest move';

	/// en: 'Turn the dial slower than this and nothing is rounded, unless it was a long move.'
	String get description => 'Turn the dial slower than this and nothing is rounded, unless it was a long move.';
}

// Path: settings.privacy.shareAppData
class Translations$settings$privacy$shareAppData$en {
	Translations$settings$privacy$shareAppData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share app usage data'
	String get title => 'Share app usage data';

	/// en: 'Help us improve the app by sharing usage, crash and performance data'
	String get descriptionOn => 'Help us improve the app by sharing usage, crash and performance data';

	/// en: 'Keep app usage data private. The Ham2K team won't be able to detect crashes or other issues.'
	String get descriptionOff => 'Keep app usage data private.\nThe Ham2K team won\'t be able to detect crashes or other issues.';
}

// Path: settings.privacy.shareOpData
class Translations$settings$privacy$shareOpData$en {
	Translations$settings$privacy$shareOpData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share operation data'
	String get title => 'Share operation data';

	/// en: 'Share some operation data publicly and with other users'
	String get descriptionOn => 'Share some operation data publicly and with other users';

	/// en: 'Keep operation data private'
	String get descriptionOff => 'Keep operation data private';
}

// Path: settings.station.types
class Translations$settings$station$types$en {
	Translations$settings$station$types$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'FlexRadio (SmartSDR) — Network'
	String get flexRadioTcp => 'FlexRadio (SmartSDR) — Network';

	/// en: 'Yaesu FT-891 — USB serial'
	String get ft891Serial => 'Yaesu FT-891 — USB serial';

	/// en: 'Icom (CI-V) — USB serial'
	String get icomCivSerial => 'Icom (CI-V) — USB serial';

	/// en: 'Icom IC-705 — WiFi'
	String get ic705Network => 'Icom IC-705 — WiFi';

	/// en: 'Hamlib rigctld — Network'
	String get rigctldTcp => 'Hamlib rigctld — Network';

	/// en: 'flrig — Network'
	String get flrigTcp => 'flrig — Network';
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
			'common.cancel' => 'Cancel',
			'common.delete' => 'Delete',
			'common.create' => 'Create',
			'common.error' => 'Error',
			'common.apply' => 'Apply',
			'common.close' => 'Close',
			'common.done' => 'Done',
			'common.callsign' => 'Callsign',
			'common.clear' => 'Clear',
			'common.dismiss' => 'Dismiss',
			'common.expand' => 'Expand',
			'common.collapse' => 'Collapse',
			'onboarding.welcomeTitle' => 'Welcome to Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Welcome to Ham2K Logger!',
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
			'onboarding.activitiesTitle' => 'Favorite Activities',
			'onboarding.activitiesBody' => 'Are you interested in any of these popular activation programs?',
			'onboarding.activitiesFooter' => '(You can find more options in the Settings)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Data & Privacy',
			'onboarding.consentUsageBody' => 'To help us make the app better, we\'d like to collect performance, crash, and app usage data.',
			'onboarding.consentUsageLabel' => 'Share Usage Data',
			'onboarding.consentOperationBody' => 'Some features might involve sharing your operation data with other users. You can opt-out at any time.',
			'onboarding.consentOperationLabel' => 'Share Operation Data',
			'onboarding.finishingSetup' => 'Finishing setup — downloading reference data…',
			'startScreen.credits' => 'by KI2D and friends',
			'extensionsPanel.categoryActivity' => 'Activities',
			'extensionsPanel.categoryContest' => 'Contests',
			'extensionsPanel.categoryLookup' => 'Callsign Lookups',
			'extensionsPanel.categoryOther' => 'Other Extensions',
			'extensionsPanel.searchHint' => 'Search extensions',
			'extensionsPanel.applying' => 'Activating extension changes, this may take a moment…',
			'extensionsPanel.noMatches' => 'No extensions match your search',
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'New operation',
			'home.stationCallsign' => 'Station callsign',
			'home.titleOptional' => 'Title (optional)',
			'home.emptyList' => 'No operations yet. Create one to start logging.',
			'home.quickLookup' => 'Quick Lookup',
			'dialogs.operationDetails' => 'Operation details',
			'dialogs.activities' => 'Activities',
			'dialogs.stationCallsign' => 'Station Callsign',
			'dialogs.notes' => 'Notes',
			'dialogs.deleteOperationTitle' => 'Delete Operation',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.stationCallsignNone' => 'No station callsign',
			'operation.titleNone' => 'No title',
			'operation.deleteOperation' => 'Delete operation',
			'operation.locationNone' => 'Not set',
			'operation.generalOperation' => 'General Operation',
			'operation.titleFor' => ({required Object value}) => 'for ${value}',
			'operation.titleAt' => ({required Object value}) => 'at ${value}',
			'operation.menu.showRstFields' => 'Show RST fields',
			'operation.menu.showStateField' => 'Show State field',
			'operation.menu.showGridField' => 'Show Grid field',
			'operation.menu.showDeletedQsos' => 'Show deleted QSOs',
			'operation.menu.showQsoNumbers' => 'Show QSO Numbers',
			'operation.menu.lookupAllQsos' => 'Lookup all QSOs',
			'operation.menu.loggingSettingsTitle' => 'Logging Settings',
			'operation.menu.actionsSection' => 'Actions',
			'operation.menu.relevantSettingsSection' => 'Relevant Settings',
			'operation.export.title' => 'Export',
			'operation.export.syncedOperation' => 'Operation is synced',
			'operation.export.unsyncedOperation' => 'Operation has unsynced changes',
			'operation.export.qsosSynced' => ({required Object total}) => 'All ${total} QSOs are synced',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} of ${total} QSOs pending sync',
			'operation.export.eventsSynced' => ({required Object total}) => 'All ${total} event markers are synced',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} of ${total} event markers pending sync',
			'operation.export.loading' => 'Loading export options…',
			'operation.export.noOptions' => 'No export formats available (extension runtime still starting?)',
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
			'operation.export.settingsButton' => 'Export settings',
			'operation.export.settingsTitle' => 'Export Settings',
			'operation.export.compactFileNames.title' => 'Use compact file names',
			'operation.export.compactFileNames.descriptionOn' => 'Short names built for uploaders, like N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Readable names, like 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Include private info',
			'operation.export.includePrivateData.descriptionOn' => 'Names, towns, gridsquares and notes are included',
			'operation.export.includePrivateData.descriptionOff' => 'Names, towns, gridsquares and notes are left out',
			'operation.export.includePrivateData.note' => 'The Full ADIF Export always includes everything',
			'operation.export.saveSuccess' => ({required Object path}) => 'Saved to ${path}',
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Shared ${count} file', other: 'Shared ${count} files', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: 'Downloaded ${count} file', other: 'Downloaded ${count} files', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export failed: ${error}',
			'operation.spots.empty' => 'No spots match your filters',
			'operation.spots.error' => ({required Object error}) => 'Failed to load spots: ${error}',
			'operation.spots.unknownBand' => 'Other',
			'operation.spots.auto' => 'Auto',
			'operation.spots.autoValue' => ({required Object value}) => 'Auto (${value})',
			'operation.spots.any' => 'Any',
			'operation.spots.allBands' => 'All Bands',
			'operation.spots.allModes' => 'All Modes',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Showing ${count} of ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutes',
			'operation.spots.callsOfNote' => 'Calls of Note',
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
			'operation.spots.filters.groupCallsWithNotes' => 'Group Calls with Notes',
			'map.emptyState' => 'No QSO locations yet.\nQSOs with a grid square, state, or country will show up here.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Flat',
			'map.globe' => 'Globe',
			'activitiesView.title' => 'Activities',
			'activitiesView.sheetTitle' => 'Operation Setup',
			'activitiesView.activitiesCountZero' => 'No Activities Selected',
			'activitiesView.activitiesCountOne' => '1 Activity',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Activities',
			'activitiesView.empty' => 'No activities yet — use Suggestions & Search below to add one',
			'activitiesView.removeActivity' => 'Remove',
			'activitiesView.editActivity' => 'Edit activity',
			'activitiesView.manageExtensions' => 'Manage Extensions',
			'activitiesView.manage' => 'Manage',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Activity Types: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Activity Types: ${first} and ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Activity Types: ${first}, ${second} and ${more} more',
			'activitiesView.reference' => 'Reference',
			'activitiesView.invalidReference' => 'Not a valid reference',
			'activitiesView.duplicateReference' => 'Already added',
			'activitiesView.searchHint' => 'Search by name, reference or anything else…',
			'activitiesView.noSuggestions' => 'No suggestions',
			'activitiesView.allOptions' => 'Activity Types',
			'activitiesView.determiningLocation' => 'Determining current location…\nWaiting for GPS fix to find nearby references',
			'activitiesView.noNearbySuggestions' => 'Location data not available\nSo we cannot determine nearby references',
			'activitiesView.emptySheet' => 'Use suggestions & search below to add one',
			'activitiesView.exports' => 'Exports',
			'activitiesView.options' => 'Options',
			'activitiesView.optionsTitle' => 'Operation Options',
			'activitiesView.operationDetails' => 'Operation Details',
			'activitiesView.share' => 'Share',
			'activitiesView.archive' => 'Archive',
			'activitiesView.deleteOperation' => 'Delete Operation',
			'activitiesView.alreadySelected' => 'Already selected',
			'activitiesView.enableExtension' => ({required Object name}) => 'Enable ${name}',
			'activitiesView.enableExtensionHint' => 'This extension matches your search, but it is not currently enabled',
			'loggingControls.timeUtc' => 'Time (UTC)',
			'loggingControls.date' => 'Date',
			'loggingControls.now' => 'Now',
			'loggingControls.frequency' => 'Frequency',
			'loggingControls.mode' => 'Mode',
			'loggingControls.theirCall' => 'Their call',
			'loggingControls.sent' => 'Sent',
			'loggingControls.rcvd' => 'Rcvd',
			'loggingControls.more' => 'More',
			'loggingControls.revert' => 'Revert',
			'loggingControls.undoDelete' => 'Undo delete',
			'loggingControls.restore' => 'Restore',
			'loggingControls.wipe' => 'Wipe',
			'loggingControls.undo' => 'Undo',
			'loggingControls.pendingDeleteWarning' => 'QSO will be deleted when you save',
			'loggingControls.deletedQsoWarning' => 'Deleted QSO',
			'loggingControls.timeControl' => 'Time',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.controlSettings' => 'Logging Controls',
			'loggingControls.expandControls' => 'Expand',
			'loggingControls.collapseControls' => 'Collapse',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot at ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} at ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Too late to spot ${call}',
			'loggingControls.spotNoFreq' => 'First set a frequency to spot',
			'loggingControls.spotComment' => 'Comment',
			'loggingControls.bandOrFreqRequired' => 'Set a frequency or band before logging',
			'loggingControls.info.noQsos' => 'No QSOs yet... let\'s get on the air!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} since last',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h for last 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h for last 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} to',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} away',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'loggingControls.info.noticeDupe' => 'Dupe!',
			'loggingControls.info.noticeNewBand' => 'New Band',
			'loggingControls.info.noticeNewMode' => 'New Mode',
			'loggingControls.info.noticeNewDXCC' => 'New DXCC',
			'loggingControls.info.noticeNewDay' => 'New Day',
			'loggingControls.info.noticeNewRef' => 'New Ref',
			'loggingControls.info.noticeNewMult' => 'New Mult',
			'loggingControls.info.noticeNewZone' => 'New Zone',
			'loggingControls.info.noticeInvalidMode' => 'Wrong Mode',
			'loggingControls.info.noticeInvalidBand' => 'Wrong Band',
			'loggingControls.info.noticeInvalidCategory' => 'Not Workable',
			'loggingControls.info.noticeWorkedBefore' => 'Worked Before',
			'loggingControls.info.noticeNewPark' => 'New Park',
			'loggingControls.info.noticeNewSection' => 'New Section',
			'loggingControls.info.noticeBonusStation' => 'Bonus Station!',
			'loggingControls.info.noticeMissingExchange' => 'No Exchange',
			'loggingControls.info.noticeInvalidExchange' => 'Bad Exchange',
			'loggingControls.info.noticeUnknownEvent' => 'Unknown Event',
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
			'formChrome.removeItem' => 'Remove',
			'formChrome.storageUnavailable' => 'Logins unavailable',
			'qsoEditForm.title' => 'Edit QSO',
			'qsoEditForm.theirName' => 'Name',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'State',
			'qsoEditForm.band' => 'Band',
			'qsoEditForm.notes' => 'Notes',
			'qsoList.empty' => 'No QSOs yet — work someone!',
			'qsoList.bandOrModeWarning' => 'Please make sure your band and mode are correct',
			'qsoList.editEventTime' => 'Edit time',
			'qsoList.today' => 'Today',
			'qsoList.yesterday' => 'Yesterday',
			'qsoList.tomorrow' => 'Tomorrow',
			'qsoList.eventStarted' => 'Operation started',
			'qsoList.eventBreak' => 'Break',
			'qsoList.eventEnded' => 'Operation ended',
			'loggingPanel.stats' => 'Operation Stats',
			'loggingPanel.scoring' => 'Scoring',
			'loggingPanel.dxccEntities' => 'DXCC entities',
			'loggingPanel.duplicates' => 'Duplicates',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Show Image',
			'callInfo.notes' => 'Notes',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} to',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) to',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} away',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'callInfo.thisOpCountOne' => '1 QSO in this operation',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs in this operation',
			'callInfo.otherOpsCountOne' => '1 QSO in other operations',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs in other operations',
			'callInfo.andMore' => ({required Object count}) => '… and ${count} more',
			'callInfo.withCall' => ({required Object call}) => 'with ${call}',
			'settings.title' => 'Settings',
			'settings.language' => 'Language',
			'settings.theme.title' => 'Theme Mode',
			'settings.theme.system' => 'System',
			'settings.theme.light' => 'Light',
			'settings.theme.dark' => 'Dark',
			'settings.themeDescription.system' => 'Follows system setting',
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
			'settings.distanceUnits' => 'Distance Units',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometers',
			'settings.distanceUnitsOpts.miles' => 'Miles',
			'settings.userInterface' => 'User Interface',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Leftie Mode',
			'settings.logging.leftieMode.descriptionOn' => 'Use layout for left-handed users',
			'settings.logging.leftieMode.descriptionOff' => 'Use layout for right-handed users',
			'settings.logging.fieldsOnTop.title' => 'Fields on top',
			'settings.logging.fieldsOnTop.descriptionOn' => 'Logging fields above the QSO list, most recent first',
			'settings.logging.fieldsOnTop.descriptionOff' => 'Logging fields below the QSO list',
			'settings.logging.countryFlags.title' => 'Country Flags',
			'settings.logging.countryFlags.dx' => 'Show only for DX contacts',
			'settings.logging.countryFlags.all' => 'Show flags for all contacts',
			'settings.logging.countryFlags.none' => 'Don\'t show any flags',
			'settings.logging.showBearing.title' => 'Show Bearing',
			'settings.logging.showBearing.descriptionOn' => 'Show estimated bearing to station',
			'settings.logging.showBearing.descriptionOff' => 'Don\'t show bearing information',
			'settings.logging.switchSentRcvd.title' => 'Switch signal report order',
			'settings.logging.switchSentRcvd.sentFirst' => 'Sent first, Rcvd second',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Rcvd first, Sent second',
			'settings.logging.jumpAfterRST.title' => 'Jump to next field on RST entry',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Jump after RST is entered',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Don\'t jump automatically',
			'settings.logging.numbersRow.title' => 'Numbers Row',
			'settings.logging.numbersRow.description' => 'Show a row of number keys above the keyboard while logging',
			'settings.logging.numbersRowExtra.title' => 'Slash and period key',
			'settings.logging.numbersRowExtra.description' => 'Adds a contextual key: “/” for callsigns, “.” for numbers',
			'settings.logging.numbersRowVibrate.title' => 'Vibrate on key press',
			'settings.logging.numbersRowVibrate.description' => 'Haptic feedback when you tap a number key',
			'settings.logging.bands' => 'Bands',
			'settings.logging.modes' => 'Modes',
			'settings.radio.title' => 'Radio',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.smartVfoSnap.title' => 'Smart VFO Snap',
			'settings.radio.smartVfoSnap.descriptionOn' => 'After you stop turning the dial, round the frequency to a sensible step. Voice modes only.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'The radio stays exactly where you tuned it.',
			'settings.radio.snapDebounce.title' => 'Smart Snap: Settle delay',
			'settings.radio.snapDebounce.description' => 'How long the dial has to stop before the frequency is rounded. Shorter feels immediate; longer leaves room for a slow move.',
			'settings.radio.snapLongMove.title' => 'Smart Snap: Long move',
			'settings.radio.snapLongMove.description' => 'Move at least this far and the frequency rounds to a whole kHz, however slowly you finished.',
			'settings.radio.snapMinMove.title' => 'Smart Snap: Smallest move',
			'settings.radio.snapMinMove.description' => 'Move less than this and nothing is rounded — fine tuning is left alone.',
			'settings.radio.snapMinSpeed.title' => 'Smart Snap: Slowest move',
			'settings.radio.snapMinSpeed.description' => 'Turn the dial slower than this and nothing is rounded, unless it was a long move.',
			'settings.privacy.title' => 'Privacy',
			'settings.privacy.shareAppData.title' => 'Share app usage data',
			'settings.privacy.shareAppData.descriptionOn' => 'Help us improve the app by sharing usage, crash and performance data',
			'settings.privacy.shareAppData.descriptionOff' => 'Keep app usage data private.\nThe Ham2K team won\'t be able to detect crashes or other issues.',
			'settings.privacy.shareOpData.title' => 'Share operation data',
			'settings.privacy.shareOpData.descriptionOn' => 'Share some operation data publicly and with other users',
			'settings.privacy.shareOpData.descriptionOff' => 'Keep operation data private',
			'settings.privacy.privacyPolicy' => 'Privacy Policy',
			'settings.privacy.termsOfService' => 'Terms of Service',
			'settings.operatorCall' => 'Operator Callsign',
			'settings.sync.title' => 'LoFi Cloud Sync',
			'settings.sync.enable' => 'Enable Sync',
			'settings.sync.deviceKey' => 'Device Key',
			'settings.developerMode' => 'Developer Mode',
			'settings.syncPanel.configuration' => 'Sync Configuration',
			'settings.syncPanel.enableTitle' => 'Sync with Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Backs up and syncs your log across devices',
			'settings.syncPanel.disabledDescription' => 'Off — your log stays on this device only',
			'settings.syncPanel.syncing' => 'Syncing',
			'settings.syncPanel.account' => 'Account',
			'settings.syncPanel.refresh' => 'Refresh',
			'settings.syncPanel.switchAccounts' => 'Switch Accounts',
			'settings.syncPanel.switchAccountsDescription' => 'Link this device to another account with a QR code or email',
			'settings.syncPanel.checking' => 'Checking…',
			'settings.syncPanel.notLinked' => 'Not linked yet',
			'settings.syncPanel.linkedAs' => ({required Object account}) => 'Linked as ${account}',
			'settings.syncPanel.replaceDialogTitle' => 'Replace local data?',
			'settings.syncPanel.replaceDialogOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} operation', other: '${n} operations', ), 
			'settings.syncPanel.replaceDialogQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'This backs up and clears ${operations} and ${qsos} from this device, then downloads the account\'s data instead. The backup stays in this device\'s database.',
			'settings.syncPanel.replace' => 'Replace',
			'settings.syncPanel.pendingBannerTitle' => 'New Ham2K Log Filer account detected',
			'settings.syncPanel.pendingBannerBody' => 'Keep this device\'s existing operations and QSOs and merge them into the account, or replace them with the account\'s data (a backup stays on this device either way).',
			'settings.syncPanel.combine' => 'Combine',
			'settings.syncPanel.authIssueTitle' => 'Sync can\'t connect',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer keeps rejecting this device. Check your callsign in Sync settings.',
			'settings.syncPanel.openSettings' => 'Open Sync settings',
			'settings.accounts.title' => 'Accounts & Services',
			'settings.accounts.none' => 'No active extensions with accounts',
			'settings.accounts.notConfigured' => 'Not configured',
			'settings.accounts.connected' => 'Connected',
			'settings.accounts.connectTo' => ({required Object label}) => 'Connect to ${label}',
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
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'When you are done, the browser will try to open a link starting with "${prefix}". Your desktop most likely has nothing registered to open it, so copy that link — from the address bar, or from the error page the browser shows — and paste it here.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger could not open your browser. Copy the login link below and open it yourself, then copy the link it sends you to — it starts with "${prefix}" — and paste that here.',
			'settings.accounts.copyLoginLink' => 'Copy login link',
			'settings.accounts.pastedLinkLabel' => 'Paste the link here',
			'settings.accounts.finishLogin' => 'Finish Login',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'That is not the login link — it should start with "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'That link belongs to a different login attempt. Close this page and connect again.',
			'settings.accounts.pastedLinkNoCode' => 'That link carries no login code. Finish signing in first, then copy the link it sends you to.',
			'settings.accounts.pastedLinkMalformed' => 'That link looks cut off. Copy the whole thing and paste it again.',
			'settings.accounts.relayLoginWaiting' => 'Waiting for you to finish signing in — this page will continue automatically once you do.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger could not open your browser automatically. Use the button below to open the login page yourself.',
			'settings.accounts.relayLoginUnavailable' => 'Couldn\'t reach the sync server needed to complete this login. Check your connection and try again.',
			'settings.accounts.relayLoginMalformedEvent' => 'That login attempt didn\'t complete correctly. Please try connecting again.',
			'settings.accounts.noKeyringTitle' => 'Account logins can’t be saved',
			'settings.accounts.noKeyringText' => 'Ham2K Logger can’t reach a keyring service on this computer, so account logins can’t be stored or read — connecting an account will fail until this is sorted. Install and start **gnome-keyring**, **KWallet** or **KeePassXC**, or unlock the keyring you already have, then restart. Logging, exports and data files are unaffected; log sync stays off while this lasts.',
			'settings.accounts.noKeyringInline' => 'Logins can’t be saved: this computer’s keyring can’t be reached. Install and start gnome-keyring, KWallet or KeePassXC, or unlock the one you have.',
			'settings.accounts.noSecureStorageInline' => 'Logins can’t be saved: this computer’s secure storage can’t be reached.',
			'settings.station.title' => 'Station Configuration',
			'settings.station.none' => 'No equipment configured',
			'settings.station.add' => 'Add equipment',
			'settings.station.addTitle' => 'Add equipment',
			'settings.station.searching' => 'Looking for radios on your network…',
			'settings.station.found' => 'Found',
			'settings.station.addManually' => 'Add by address',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Can\'t listen for radios: ${error}',
			'settings.station.edit' => 'Edit equipment',
			'settings.station.name' => 'Name',
			'settings.station.nameDescription' => 'What you call it — "Left Radio". Optional.',
			'settings.station.host' => 'Address',
			'settings.station.hostDescription' => 'The radio\'s hostname or IP address on your network.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'An address is required',
			'settings.station.portInvalid' => 'Port must be between 1 and 65535',
			'settings.station.connect' => 'Connect',
			'settings.station.disconnect' => 'Disconnect',
			'settings.station.remove' => 'Remove',
			'settings.station.removeTitle' => ({required Object name}) => 'Remove ${name}?',
			'settings.station.removeMessage' => 'This only removes it from the app. Nothing on the equipment changes.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Unrecognized equipment type "${typeKey}"',
			'settings.station.unverified' => 'Not tested against this hardware',
			'settings.station.mainVfo' => 'Main VFO',
			'settings.station.useAsMainVfo' => 'Use as Main VFO',
			'settings.station.serialPort' => 'Serial port',
			'settings.station.serialPortDescription' => 'The port the radio\'s CAT interface appears on.',
			'settings.station.serialPortNone' => 'No serial ports found',
			'settings.station.serialPortRequired' => 'Choose a serial port',
			'settings.station.serialDeviceRequest' => 'Add a USB device…',
			'settings.station.baudRate' => 'Speed (baud)',
			'settings.station.baudRateDescription' => 'Must match the radio\'s own CAT menu — a mismatch answers with garbage and no error.',
			'settings.station.civAddress' => 'Radio CI-V address',
			'settings.station.civAddressDescription' => 'Hex, as shown in the radio\'s CI-V menu. The IC-705 ships as A4.',
			'settings.station.civAddressInvalid' => 'A CI-V address is two hex digits, 01 to FF',
			'settings.station.radioUser' => 'Radio username',
			'settings.station.radioPass' => 'Radio password',
			'settings.station.radioLoginDescription' => 'The radio\'s own Network → Remote login, not your WiFi password.',
			'settings.station.radioUserRequired' => 'The radio\'s remote-control username is required',
			'settings.station.types.flexRadioTcp' => 'FlexRadio (SmartSDR) — Network',
			'settings.station.types.ft891Serial' => 'Yaesu FT-891 — USB serial',
			'settings.station.types.icomCivSerial' => 'Icom (CI-V) — USB serial',
			'settings.station.types.ic705Network' => 'Icom IC-705 — WiFi',
			'settings.station.types.rigctldTcp' => 'Hamlib rigctld — Network',
			'settings.station.types.flrigTcp' => 'flrig — Network',
			'settings.station.troubleshootingTitle' => 'If the radio connects but shows no frequency',
			'settings.station.ft891Troubleshooting' => 'The radio is receiving commands but answering nothing. Almost always one of:\n\n- **CAT RTS must be OFF at the radio** (FT-891 menu **05-08**). With it on, the radio waits for a handshake line the app deliberately never raises — on a Digirig, SignaLink or most home-brew cables that same line is PTT, so raising it would key your transmitter.\n- **Speed must match** the radio\'s CAT RATE (menu **05-06**). A mismatch answers with garbage, or nothing, and never with an error.\n- **Another app may hold the port** — WSJT-X, fldigi and rigctld all keep it open.',
			'settings.station.statusConnected' => 'Connected',
			'settings.station.currentConfiguration' => 'Current Configuration',
			'settings.station.transceiverForMainVfo' => 'Transceiver for Main VFO',
			'settings.station.equipmentInventory' => 'Equipment Inventory',
			'settings.station.noTransceiver' => 'None',
			'settings.station.icomCivTroubleshootingTitle' => 'If two serial ports show up for the same radio',
			'settings.station.icomCivTroubleshooting' => 'Several Icom radios — the IC-705 among them — present **two** USB serial ports at once (Icom calls them Port A and Port B), both set to CI-V by default. Neither this app nor your OS can tell them apart beyond that — the same USB vendor/product ID just shows up twice, sometimes marked with a `#2` suffix here. **Port A is usually the right one** — normally the first one your OS or browser lists. If commands go out and the radio never answers, try the other port next.',
			'settings.station.rigctldTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.rigctldTroubleshooting' => 'This connects to a **rigctld daemon you run yourself**, not to the radio directly — Hamlib\'s own backend talks to the radio and supports hundreds of models.\n\n- **The daemon must already be running**, e.g. `rigctld -m 1035 -r /dev/ttyUSB0`. Find your radio\'s model number with `rigctl -l`.\n- **From another machine**, start it with `-T 0.0.0.0` — by default rigctld only accepts connections from the machine it runs on.\n- **Port** is 4532 unless you started the daemon with `-t`.\n- Once connected, a missing frequency usually means the daemon itself cannot reach the radio — test it with `rigctl -m 2 f` on the daemon\'s machine.',
			'settings.station.flrigTroubleshootingTitle' => 'If the app cannot connect',
			'settings.station.flrigTroubleshooting' => 'This connects to an **flrig program you run yourself**, not to the radio directly — flrig talks to the radio and supports most makes and models.\n\n- **flrig must already be running**, with its transceiver configured and connected.\n- **Port** is 12345 unless you changed it in flrig\'s configuration (Config → Setup → Server).\n- **From another machine**, make sure flrig\'s server is reachable — it listens on all interfaces, but your firewall may not agree.\n- Once connected, a missing frequency usually means flrig itself cannot reach the radio — check that flrig\'s own display is following the dial.',
			'settings.station.ic705TroubleshootingTitle' => 'If the radio never answers',
			'settings.station.ic705Troubleshooting' => 'The radio has a **single** remote-control session. When the login is ignored, something else is almost always using it.\n\n- **Close any other client.** wfview or RS-BA1 connected to the same radio holds that one session, and the login here is simply ignored while it does.\n- **Check the radio\'s network settings** — that WLAN is on, it is on the same network, and its remote-control (Network) function is enabled.\n- **Power-cycle the radio\'s WLAN** if it stays stuck. That reliably clears a session the radio is genuinely holding.\n\nA **wrong password is refused explicitly**, not met with silence — so if you got here rather than a "rejected" message, the password is not the problem.',
			'settings.station.statusStale' => 'Not responding',
			'settings.station.currentRadioSettings' => 'Current radio settings',
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
			'settings.offlineData.extensionsSection' => 'Extensions',
			'settings.profiles.notSet' => 'Not set',
			'settings.search.clear' => 'Clear',
			'settings.search.hint' => 'Search settings',
			'settings.developer.options' => 'Developer Options',
			'settings.developer.developerModeDescription' => 'Enable developer warnings, debug logs, and tools.',
			'settings.developer.experiments' => 'Experiments',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} enabled', other: '${count} enabled', ), 
			'settings.developer.patchTrack' => 'Patch Track',
			_ => null,
		} ?? switch (path) {
			'settings.developer.patchTrackDescription' => 'Which over-the-air patch ring this device follows. More adventurous rings get fixes earlier, less tested. Patches apply on the next restart.',
			'settings.developer.trackStable' => 'Stable',
			'settings.developer.trackUnstable' => 'Unstable',
			'settings.developer.trackBleeding' => 'Bleeding',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Checking "${track}" for a patch…',
			'settings.developer.patchDownloaded' => 'Patch downloaded — restart the app to apply it.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'No new patch on "${track}".',
			'settings.developer.noPatchInstalled' => 'No patch installed — running the release binary.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Running patch #${patch}.',
			'settings.developer.systemInformation' => 'System Information',
			'settings.developer.activeExtensions' => 'Active Extensions',
			'settings.developer.appVersion' => 'App Version',
			'settings.developer.dataFolder' => 'Data Folder',
			'settings.developer.loading' => '(loading…)',
			'settings.developer.runtimeNotAvailable' => 'Extension runtime not available.',
			'settings.developer.panelLoadFailed' => 'Could not load this settings panel.',
			'settings.developer.categoryCore' => 'Core & Runtime',
			'settings.about.notices' => 'Notices & Messages',
			'settings.about.noticesDescription' => 'Announcements and status messages',
			'settings.about.releaseNotes' => 'Release Notes',
			'settings.about.copiedVersion' => 'Copied version details to clipboard',
			'settings.panels.commonPreferences' => 'Common Preferences',
			'settings.panels.commonPreferencesDescription' => 'Appearance, language, and everyday settings',
			'settings.panels.allSettings' => 'All Settings',
			'settings.panels.allSettingsDescription' => 'Every available setting in one place',
			'settings.panels.syncDescription' => 'Back up and sync your logs across devices',
			'settings.panels.accountsDescription' => 'Sign in to online services and lookups',
			'settings.panels.extensions' => 'Features & Extensions',
			'settings.panels.extensionsDescription' => 'Turn optional features on or off',
			'settings.panels.profilesDescription' => 'Operator callsign and station profile',
			'settings.panels.stationProfiles' => 'Station Profiles',
			'settings.panels.dataFiles' => 'Data Files',
			'settings.panels.dataFilesDescription' => 'Manage cached data sources',
			'settings.panels.developerSettings' => 'Developer Settings',
			'settings.panels.developerSettingsDescription' => 'Debugging and development tools',
			'settings.panels.about' => 'About',
			'settings.panels.aboutDescription' => 'Version, credits, and legal information',
			'settings.panels.unavailableTitle' => 'Some settings are unavailable',
			'settings.panels.unavailableText' => 'The extension runtime failed to start, so extension-contributed settings are missing.',
			'settings.panels.station' => 'Station Configuration',
			'settings.panels.stationDescription' => 'Radios and other equipment',
			'settings.showMoreSettings' => 'Show more settings',
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
			'commands.sentryTestLocalOnly' => 'Sentry is disabled in this build — test error logged locally only',
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
			'expiredBuild.title' => 'This build has expired',
			'expiredBuild.body' => 'Please visit ham2k.com and get a newer version.',
			'expiredBuild.visit' => 'Visit ham2k.com',
			'expiredBuild.dismiss' => 'Continue anyway',
			'spotting.noQsoYet' => 'No QSO logged yet to spot.',
			'spotting.setFrequencyFirst' => 'Set a frequency first.',
			'spotting.nothingToSpot' => 'Nothing to spot — no extension offers spotting here.',
			'spotting.spottedOn' => ({required Object source}) => 'Spotted on ${source}',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} failed: ${message}',
			'spotting.unknownError' => 'unknown error',
			'spotting.notSent' => 'Spot not sent.',
			'dataFiles.downloading' => 'Downloading…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Couldn\'t download ${name}',
			'dataFiles.downloadFailedWebHint' => 'This could be a network issue, or this link\'s host may not support direct downloads from a web browser. Try the desktop or mobile app, or a different hosting location.',
			'dataFiles.downloadTimedOut' => 'The server took too long to respond. Try again later.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Couldn\'t process ${name}',
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
			'extensionService.runtimeNotReady' => 'Extension runtime not ready.',
			'extensionService.testFailed' => ({required Object error}) => 'Test failed: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Connected as ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Invalid field configuration',
			'extensionService.invalidValue' => 'Invalid value',
			'extensionService.validationError' => ({required Object error}) => 'Validation error: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Action failed: ${error}',
			'extensionService.commandFailed' => 'The command failed to run',
			'operationLocationScreen.title' => 'Operation Location',
			'operationLocationScreen.selectedLocation' => 'Selected Location',
			'operationLocationScreen.gridSquare' => 'Maidenhead Grid Square Locator',
			'operationLocationScreen.suggestedLocations' => 'Suggested Locations',
			'operationLocationScreen.deviceGps' => 'Device GPS',
			'operationLocationScreen.locating' => 'Locating…',
			'operationLocationScreen.gpsUnavailable' => 'Location unavailable',
			'operationLocationScreen.permissionDenied' => 'Location permission denied',
			'operationLocationScreen.moreDetails' => 'More Details',
			'operationLocationScreen.stateOrProvince' => 'State or Province (optional)',
			'operationLocationScreen.county' => 'County (optional)',
			'versionLabel.version' => ({required Object version}) => 'Version ${version}',
			'versionLabel.versionBuild' => ({required Object version, required Object build}) => 'Version ${version} - Build ${build}',
			'notices.emptyHistory' => 'No notices yet',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonymous Account (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (pending confirmation)',
			'switchAccounts.noAccountDetails' => 'No account details yet',
			'switchAccounts.currentAccount' => 'Current account',
			'switchAccounts.otherAccounts' => 'Other accounts',
			'switchAccounts.linkToAnother' => 'Link to another account',
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
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count, one: '${count} operation', other: '${count} operations', ), 
			_ => null,
		};
	}
}
