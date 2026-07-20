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
	late final Translations$qsoEditForm$en qsoEditForm = Translations$qsoEditForm$en.internal(_root);
	late final Translations$qsoList$en qsoList = Translations$qsoList$en.internal(_root);
	late final Translations$loggingPanel$en loggingPanel = Translations$loggingPanel$en.internal(_root);
	late final Translations$callInfo$en callInfo = Translations$callInfo$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
	late final Translations$operationLocationScreen$en operationLocationScreen = Translations$operationLocationScreen$en.internal(_root);
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

	/// en: 'Desktop Logger'
	String get titleDesktop => 'Desktop Logger';

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

	/// en: 'Delete operation "${title}"?'
	String deleteOperationConfirm({required Object title}) => 'Delete operation "${title}"?';

	/// en: 'Operation details'
	String get operationDetails => 'Operation details';

	/// en: 'Activities'
	String get activities => 'Activities';
}

// Path: operation
class Translations$operation$en {
	Translations$operation$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$operation$tabs$en tabs = Translations$operation$tabs$en.internal(_root);

	/// en: 'No activities available (extension runtime still starting?)'
	String get noActivities => 'No activities available (extension runtime still starting?)';

	late final Translations$operation$sections$en sections = Translations$operation$sections$en.internal(_root);

	/// en: 'No station callsign'
	String get stationCallsignNone => 'No station callsign';

	/// en: 'No title'
	String get titleNone => 'No title';

	/// en: 'None set'
	String get activitiesNone => 'None set';

	/// en: 'Delete operation'
	String get deleteOperation => 'Delete operation';

	/// en: 'Not set'
	String get locationNone => 'Not set';

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
}

// Path: activitiesView
class Translations$activitiesView$en {
	Translations$activitiesView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Activities'
	String get title => 'Activities';

	/// en: 'No Current Activities'
	String get activitiesCountZero => 'No Current Activities';

	/// en: 'One Current Activity'
	String get activitiesCountOne => 'One Current Activity';

	/// en: '${count} Current Activities'
	String activitiesCountOther({required Object count}) => '${count} Current Activities';

	/// en: 'No activities yet — use Suggestions & Search below to add one'
	String get empty => 'No activities yet — use Suggestions & Search below to add one';

	/// en: 'Add activity'
	String get addActivity => 'Add activity';

	/// en: 'Remove'
	String get removeActivity => 'Remove';

	/// en: 'Edit activity'
	String get editActivity => 'Edit activity';

	/// en: 'Reference'
	String get reference => 'Reference';

	/// en: 'Not a valid reference'
	String get invalidReference => 'Not a valid reference';

	/// en: 'Already added'
	String get duplicateReference => 'Already added';

	/// en: 'Search for a park, summit…'
	String get searchHint => 'Search for a park, summit…';

	/// en: 'Options'
	String get searchOptions => 'Options';

	/// en: 'No suggestions'
	String get noSuggestions => 'No suggestions';

	/// en: 'All Options'
	String get allOptions => 'All Options';

	/// en: 'Determining current location…'
	String get determiningLocation => 'Determining current location…';

	/// en: 'No nearby suggestions, current location not known'
	String get noNearbySuggestions => 'No nearby suggestions, current location not known';

	/// en: '${distance} km'
	String distanceKm({required Object distance}) => '${distance} km';
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

	late final Translations$loggingControls$info$en info = Translations$loggingControls$info$en.internal(_root);
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

	/// en: 'Station'
	String get station => 'Station';

	/// en: 'By band'
	String get byBand => 'By band';

	/// en: 'By mode'
	String get byMode => 'By mode';

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

	/// en: 'General Settings'
	String get general => 'General Settings';

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
	late final Translations$settings$privacy$en privacy = Translations$settings$privacy$en.internal(_root);

	/// en: 'Operator Callsign'
	String get operatorCall => 'Operator Callsign';

	late final Translations$settings$sync$en sync = Translations$settings$sync$en.internal(_root);
	late final Translations$settings$qrz$en qrz = Translations$settings$qrz$en.internal(_root);

	/// en: 'Developer Mode'
	String get developerMode => 'Developer Mode';
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

	/// en: 'OPERATION'
	String get operation => 'OPERATION';
}

// Path: operation.sections
class Translations$operation$sections$en {
	Translations$operation$sections$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Station & operator'
	String get stationOperator => 'Station & operator';

	/// en: 'Activities'
	String get activities => 'Activities';

	/// en: 'Operation data'
	String get operationData => 'Operation data';

	/// en: 'Danger zone'
	String get dangerZone => 'Danger zone';

	/// en: 'Location'
	String get location => 'Location';
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

	/// en: 'Saved to ${path}'
	String saveSuccess({required Object path}) => 'Saved to ${path}';

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

	/// en: 'Not digital'
	String get notDigital => 'Not digital';

	/// en: '${count} spots'
	String spotsCount({required Object count}) => '${count} spots';

	/// en: 'Showing ${count} of ${total} spots'
	String spotsCountFiltered({required Object count, required Object total}) => 'Showing ${count} of ${total} spots';

	/// en: '${minutes} minutes'
	String ageMinutes({required Object minutes}) => '${minutes} minutes';

	/// en: 'Most Recent Spots'
	String get mostRecentSpots => 'Most Recent Spots';

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

// Path: settings.qrz
class Translations$settings$qrz$en {
	Translations$settings$qrz$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'QRZ.com Credentials'
	String get title => 'QRZ.com Credentials';

	/// en: 'Username'
	String get username => 'Username';

	/// en: 'Password'
	String get password => 'Password';
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
			'onboarding.activitiesTitle' => 'Favorite Activities',
			'onboarding.activitiesBody' => 'Are you interested in any of these popular activation programs?',
			'onboarding.activitiesFooter' => '(You can find more options in the Settings)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.consentTitle' => 'Data & Privacy',
			'onboarding.consentUsageBody' => 'To help us make the app better, we\'d like to collect performance, crash, and app usage data.',
			'onboarding.consentUsageLabel' => 'Share Usage Data',
			'onboarding.consentOperationBody' => 'Some features might involve sharing your operation data with other users. You can opt-out at any time.',
			'onboarding.consentOperationLabel' => 'Share Operation Data',
			'startScreen.credits' => 'by KI2D and friends',
			'extensionsPanel.categoryActivity' => 'Activities',
			'extensionsPanel.categoryLookup' => 'Callsign Lookups',
			'extensionsPanel.categoryOther' => 'Other Extensions',
			'extensionsPanel.searchHint' => 'Search extensions',
			'extensionsPanel.applying' => 'Activating extension changes, this may take a moment…',
			'extensionsPanel.noMatches' => 'No extensions match your search',
			'home.title' => 'Portable Logger',
			'home.titleDesktop' => 'Desktop Logger',
			'home.newOperation' => 'New operation',
			'home.stationCallsign' => 'Station callsign',
			'home.titleOptional' => 'Title (optional)',
			'home.emptyList' => 'No operations yet. Create one to start logging.',
			'home.quickLookup' => 'Quick Lookup',
			'dialogs.deleteOperationConfirm' => ({required Object title}) => 'Delete operation "${title}"?',
			'dialogs.operationDetails' => 'Operation details',
			'dialogs.activities' => 'Activities',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.tabs.operation' => 'OPERATION',
			'operation.noActivities' => 'No activities available (extension runtime still starting?)',
			'operation.sections.stationOperator' => 'Station & operator',
			'operation.sections.activities' => 'Activities',
			'operation.sections.operationData' => 'Operation data',
			'operation.sections.dangerZone' => 'Danger zone',
			'operation.sections.location' => 'Location',
			'operation.stationCallsignNone' => 'No station callsign',
			'operation.titleNone' => 'No title',
			'operation.activitiesNone' => 'None set',
			'operation.deleteOperation' => 'Delete operation',
			'operation.locationNone' => 'Not set',
			'operation.menu.showRstFields' => 'Show RST fields',
			'operation.menu.showStateField' => 'Show State field',
			'operation.menu.showGridField' => 'Show Grid field',
			'operation.menu.showDeletedQsos' => 'Show deleted QSOs',
			'operation.menu.showQsoNumbers' => 'Show QSO Numbers',
			'operation.menu.lookupAllQsos' => 'Lookup all QSOs',
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
			'operation.export.saveSuccess' => ({required Object path}) => 'Saved to ${path}',
			'operation.export.exportFailed' => ({required Object error}) => 'Export failed: ${error}',
			'operation.spots.empty' => 'No spots match your filters',
			'operation.spots.error' => ({required Object error}) => 'Failed to load spots: ${error}',
			'operation.spots.unknownBand' => 'Other',
			'operation.spots.auto' => 'Auto',
			'operation.spots.autoValue' => ({required Object value}) => 'Auto (${value})',
			'operation.spots.any' => 'Any',
			'operation.spots.allBands' => 'All Bands',
			'operation.spots.allModes' => 'All Modes',
			'operation.spots.notDigital' => 'Not digital',
			'operation.spots.spotsCount' => ({required Object count}) => '${count} spots',
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Showing ${count} of ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutes',
			'operation.spots.mostRecentSpots' => 'Most Recent Spots',
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
			'activitiesView.title' => 'Activities',
			'activitiesView.activitiesCountZero' => 'No Current Activities',
			'activitiesView.activitiesCountOne' => 'One Current Activity',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Current Activities',
			'activitiesView.empty' => 'No activities yet — use Suggestions & Search below to add one',
			'activitiesView.addActivity' => 'Add activity',
			'activitiesView.removeActivity' => 'Remove',
			'activitiesView.editActivity' => 'Edit activity',
			'activitiesView.reference' => 'Reference',
			'activitiesView.invalidReference' => 'Not a valid reference',
			'activitiesView.duplicateReference' => 'Already added',
			'activitiesView.searchHint' => 'Search for a park, summit…',
			'activitiesView.searchOptions' => 'Options',
			'activitiesView.noSuggestions' => 'No suggestions',
			'activitiesView.allOptions' => 'All Options',
			'activitiesView.determiningLocation' => 'Determining current location…',
			'activitiesView.noNearbySuggestions' => 'No nearby suggestions, current location not known',
			'activitiesView.distanceKm' => ({required Object distance}) => '${distance} km',
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
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot at ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} at ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Too late to spot ${call}',
			'loggingControls.spotNoFreq' => 'First set a frequency to spot',
			'loggingControls.spotComment' => 'Comment',
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
			'qsoEditForm.title' => 'Edit QSO',
			'qsoEditForm.theirName' => 'Name',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'State',
			'qsoEditForm.band' => 'Band',
			'qsoEditForm.notes' => 'Notes',
			'qsoList.empty' => 'No QSOs yet — work someone!',
			'qsoList.editEventTime' => 'Edit time',
			'qsoList.today' => 'Today',
			'qsoList.yesterday' => 'Yesterday',
			'qsoList.tomorrow' => 'Tomorrow',
			'qsoList.eventStarted' => 'Operation started',
			'qsoList.eventBreak' => 'Break',
			'qsoList.eventEnded' => 'Operation ended',
			'loggingPanel.station' => 'Station',
			'loggingPanel.byBand' => 'By band',
			'loggingPanel.byMode' => 'By mode',
			'loggingPanel.scoring' => 'Scoring',
			'loggingPanel.dxccEntities' => 'DXCC entities',
			'loggingPanel.duplicates' => 'Duplicates',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Show Image',
			'callInfo.notes' => 'Notes',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} away',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) away',
			'callInfo.thisOpCountOne' => '1 QSO in this operation',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs in this operation',
			'callInfo.otherOpsCountOne' => '1 QSO in other operations',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs in other operations',
			'callInfo.andMore' => ({required Object count}) => '… and ${count} more',
			'callInfo.withCall' => ({required Object call}) => 'with ${call}',
			'settings.title' => 'Settings',
			'settings.general' => 'General Settings',
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
			'settings.qrz.title' => 'QRZ.com Credentials',
			'settings.qrz.username' => 'Username',
			'settings.qrz.password' => 'Password',
			'settings.developerMode' => 'Developer Mode',
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
			_ => null,
		};
	}
}
