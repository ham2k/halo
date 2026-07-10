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
	late final Translations$loggingControls$en loggingControls = Translations$loggingControls$en.internal(_root);
	late final Translations$qsoList$en qsoList = Translations$qsoList$en.internal(_root);
	late final Translations$loggingPanel$en loggingPanel = Translations$loggingPanel$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
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

	/// en: 'Delete QSO with ${call}?'
	String deleteQsoConfirm({required Object call}) => 'Delete QSO with ${call}?';
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

	/// en: 'Exported to ${path}'
	String exportSuccess({required Object path}) => 'Exported to ${path}';

	/// en: 'Export failed: ${error}'
	String exportFailed({required Object error}) => 'Export failed: ${error}';

	late final Translations$operation$sections$en sections = Translations$operation$sections$en.internal(_root);

	/// en: 'No station callsign'
	String get stationCallsignNone => 'No station callsign';

	/// en: 'No title'
	String get titleNone => 'No title';

	/// en: 'None set'
	String get activitiesNone => 'None set';

	/// en: 'Export ADIF'
	String get exportAdif => 'Export ADIF';

	/// en: 'Delete operation'
	String get deleteOperation => 'Delete operation';
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

	/// en: 'Freq kHz'
	String get freqKHz => 'Freq kHz';

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
}

// Path: qsoList
class Translations$qsoList$en {
	Translations$qsoList$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No QSOs yet — work someone!'
	String get empty => 'No QSOs yet — work someone!';

	/// en: 'Duplicate — same call, band and mode already logged'
	String get duplicate => 'Duplicate — same call, band and mode already logged';

	/// en: 'New DXCC entity'
	String get newEntity => 'New DXCC entity';

	/// en: 'New band or mode for this callsign'
	String get newBandOrMode => 'New band or mode for this callsign';
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

	/// en: 'Font Scale'
	String get fontScale => 'Font Scale';

	late final Translations$settings$fontScaleOpts$en fontScaleOpts = Translations$settings$fontScaleOpts$en.internal(_root);

	/// en: 'Operator Callsign'
	String get operatorCall => 'Operator Callsign';

	late final Translations$settings$sync$en sync = Translations$settings$sync$en.internal(_root);
	late final Translations$settings$qrz$en qrz = Translations$settings$qrz$en.internal(_root);

	/// en: 'Developer Mode'
	String get developerMode => 'Developer Mode';
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
			'dialogs.deleteQsoConfirm' => ({required Object call}) => 'Delete QSO with ${call}?',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAP',
			'operation.tabs.operation' => 'OPERATION',
			'operation.comingSoon' => ({required Object label}) => '${label} — coming soon',
			'operation.noActivities' => 'No activities available (extension runtime still starting?)',
			'operation.exportSuccess' => ({required Object path}) => 'Exported to ${path}',
			'operation.exportFailed' => ({required Object error}) => 'Export failed: ${error}',
			'operation.sections.stationOperator' => 'Station & operator',
			'operation.sections.activities' => 'Activities',
			'operation.sections.operationData' => 'Operation data',
			'operation.sections.dangerZone' => 'Danger zone',
			'operation.stationCallsignNone' => 'No station callsign',
			'operation.titleNone' => 'No title',
			'operation.activitiesNone' => 'None set',
			'operation.exportAdif' => 'Export ADIF',
			'operation.deleteOperation' => 'Delete operation',
			'loggingControls.timeUtc' => 'Time (UTC)',
			'loggingControls.date' => 'Date',
			'loggingControls.now' => 'Now',
			'loggingControls.freqKHz' => 'Freq kHz',
			'loggingControls.mode' => 'Mode',
			'loggingControls.dupe' => 'DUPE',
			'loggingControls.theirCall' => 'Their call',
			'loggingControls.sent' => 'Sent',
			'loggingControls.rcvd' => 'Rcvd',
			'qsoList.empty' => 'No QSOs yet — work someone!',
			'qsoList.duplicate' => 'Duplicate — same call, band and mode already logged',
			'qsoList.newEntity' => 'New DXCC entity',
			'qsoList.newBandOrMode' => 'New band or mode for this callsign',
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
			'settings.fontScale' => 'Font Scale',
			'settings.fontScaleOpts.smallest' => 'Smallest',
			'settings.fontScaleOpts.smaller' => 'Smaller',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Larger',
			'settings.fontScaleOpts.largest' => 'Largest',
			'settings.operatorCall' => 'Operator Callsign',
			'settings.sync.title' => 'Sync Settings',
			'settings.sync.enable' => 'Enable Sync',
			'settings.sync.deviceKey' => 'Device Key',
			'settings.qrz.title' => 'QRZ.com Credentials',
			'settings.qrz.username' => 'Username',
			'settings.qrz.password' => 'Password',
			'settings.developerMode' => 'Developer Mode',
			_ => null,
		};
	}
}
