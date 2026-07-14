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
	late final Translations$home$en home = Translations$home$en.internal(_root);
	late final Translations$dialogs$en dialogs = Translations$dialogs$en.internal(_root);
	late final Translations$operation$en operation = Translations$operation$en.internal(_root);
	late final Translations$activitiesView$en activitiesView = Translations$activitiesView$en.internal(_root);
	late final Translations$loggingControls$en loggingControls = Translations$loggingControls$en.internal(_root);
	late final Translations$qsoEditForm$en qsoEditForm = Translations$qsoEditForm$en.internal(_root);
	late final Translations$qsoList$en qsoList = Translations$qsoList$en.internal(_root);
	late final Translations$loggingPanel$en loggingPanel = Translations$loggingPanel$en.internal(_root);
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

	/// en: '${label} — coming soon'
	String comingSoon({required Object label}) => '${label} — coming soon';

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

	/// en: 'DUPE'
	String get dupe => 'DUPE';

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

	/// en: 'Wipe'
	String get wipe => 'Wipe';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'QSO will be deleted when you save'
	String get pendingDeleteWarning => 'QSO will be deleted when you save';

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

	/// en: 'Scales the whole interface — text, controls, and spacing'
	String get fontScaleDescription => 'Scales the whole interface — text, controls, and spacing';

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
}

// Path: settings.sync
class Translations$settings$sync$en {
	Translations$settings$sync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sync Settings'
	String get title => 'Sync Settings';

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
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.tabs.operation' => 'OPERATION',
			'operation.comingSoon' => ({required Object label}) => '${label} — coming soon',
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
			'loggingControls.dupe' => 'DUPE',
			'loggingControls.theirCall' => 'Their call',
			'loggingControls.sent' => 'Sent',
			'loggingControls.rcvd' => 'Rcvd',
			'loggingControls.more' => 'More',
			'loggingControls.revert' => 'Revert',
			'loggingControls.undoDelete' => 'Undo delete',
			'loggingControls.wipe' => 'Wipe',
			'loggingControls.undo' => 'Undo',
			'loggingControls.pendingDeleteWarning' => 'QSO will be deleted when you save',
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
			'settings.fontScaleOpts.smallest' => 'Smallest',
			'settings.fontScaleOpts.smaller' => 'Smaller',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Larger',
			'settings.fontScaleOpts.largest' => 'Largest',
			'settings.fontScaleDescription' => 'Scales the whole interface — text, controls, and spacing',
			'settings.operatorCall' => 'Operator Callsign',
			'settings.sync.title' => 'Sync Settings',
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
