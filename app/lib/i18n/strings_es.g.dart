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
class TranslationsEs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$es common = _Translations$common$es._(_root);
	@override late final _Translations$home$es home = _Translations$home$es._(_root);
	@override late final _Translations$dialogs$es dialogs = _Translations$dialogs$es._(_root);
	@override late final _Translations$operation$es operation = _Translations$operation$es._(_root);
	@override late final _Translations$loggingControls$es loggingControls = _Translations$loggingControls$es._(_root);
	@override late final _Translations$qsoEditForm$es qsoEditForm = _Translations$qsoEditForm$es._(_root);
	@override late final _Translations$qsoList$es qsoList = _Translations$qsoList$es._(_root);
	@override late final _Translations$loggingPanel$es loggingPanel = _Translations$loggingPanel$es._(_root);
	@override late final _Translations$settings$es settings = _Translations$settings$es._(_root);
}

// Path: common
class _Translations$common$es extends Translations$common$en {
	_Translations$common$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get save => 'Guardar';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Eliminar';
	@override String get create => 'Crear';
	@override String get error => 'Error';
}

// Path: home
class _Translations$home$es extends Translations$home$en {
	_Translations$home$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registrador Portátil';
	@override String get titleDesktop => 'Registrador de Escritorio';
	@override String get newOperation => 'Nueva operación';
	@override String get stationCallsign => 'Indicativo de la estación';
	@override String get titleOptional => 'Título (opcional)';
	@override String get emptyList => 'Aún no hay operaciones. Crea una para comenzar a registrar.';
	@override String get quickLookup => 'Búsqueda Rápida';
}

// Path: dialogs
class _Translations$dialogs$es extends Translations$dialogs$en {
	_Translations$dialogs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String deleteOperationConfirm({required Object title}) => '¿Eliminar operación "${title}"?';
	@override String get operationDetails => 'Detalles de la operación';
	@override String get activities => 'Actividades';
}

// Path: operation
class _Translations$operation$es extends Translations$operation$en {
	_Translations$operation$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$operation$tabs$es tabs = _Translations$operation$tabs$es._(_root);
	@override String comingSoon({required Object label}) => '${label} — próximamente';
	@override String get noActivities => 'No hay actividades disponibles (¿el motor de extensiones aún está iniciando?)';
	@override String exportSuccess({required Object path}) => 'Exportado a ${path}';
	@override String exportFailed({required Object error}) => 'Exportación fallida: ${error}';
	@override late final _Translations$operation$sections$es sections = _Translations$operation$sections$es._(_root);
	@override String get stationCallsignNone => 'Sin indicativo de estación';
	@override String get titleNone => 'Sin título';
	@override String get activitiesNone => 'Ninguna seleccionada';
	@override String get exportAdif => 'Exportar ADIF';
	@override String get deleteOperation => 'Eliminar operación';
}

// Path: loggingControls
class _Translations$loggingControls$es extends Translations$loggingControls$en {
	_Translations$loggingControls$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Fecha';
	@override String get now => 'Ahora';
	@override String get freqKHz => 'Frec kHz';
	@override String get mode => 'Modo';
	@override String get dupe => 'DUPE';
	@override String get theirCall => 'Su indicativo';
	@override String get sent => 'Enviado';
	@override String get rcvd => 'Recibido';
	@override String get more => 'Más';
	@override String get revert => 'Revertir';
	@override String get undoDelete => 'Deshacer eliminación';
	@override String get wipe => 'Borrar';
	@override String get undo => 'Deshacer';
	@override String get pendingDeleteWarning => 'El QSO se eliminará al guardar';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Radio';
	@override String get controlSettings => 'Controles de registro';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$es extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editar QSO';
	@override String get theirName => 'Nombre';
	@override String get theirGrid => 'Locador';
	@override String get band => 'Banda';
	@override String get notes => 'Notas';
}

// Path: qsoList
class _Translations$qsoList$es extends Translations$qsoList$en {
	_Translations$qsoList$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Aún no hay QSOs — ¡haz un contacto!';
	@override String get duplicate => 'Duplicado — mismo indicativo, banda y modo ya registrados';
	@override String get newEntity => 'Nueva entidad DXCC';
	@override String get newBandOrMode => 'Nueva banda o modo para este indicativo';
}

// Path: loggingPanel
class _Translations$loggingPanel$es extends Translations$loggingPanel$en {
	_Translations$loggingPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get station => 'Estación';
	@override String get byBand => 'Por banda';
	@override String get byMode => 'Por modo';
	@override String get scoring => 'Puntuación';
	@override String get dxccEntities => 'Entidades DXCC';
	@override String get duplicates => 'Duplicados';
}

// Path: settings
class _Translations$settings$es extends Translations$settings$en {
	_Translations$settings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración';
	@override String get general => 'Configuración General';
	@override String get language => 'Idioma';
	@override late final _Translations$settings$theme$es theme = _Translations$settings$theme$es._(_root);
	@override String get fontScale => 'Tamaño de Letra';
	@override late final _Translations$settings$fontScaleOpts$es fontScaleOpts = _Translations$settings$fontScaleOpts$es._(_root);
	@override String get operatorCall => 'Indicativo del Operador';
	@override late final _Translations$settings$sync$es sync = _Translations$settings$sync$es._(_root);
	@override late final _Translations$settings$qrz$es qrz = _Translations$settings$qrz$es._(_root);
	@override String get developerMode => 'Modo Desarrollador';
}

// Path: operation.tabs
class _Translations$operation$tabs$es extends Translations$operation$tabs$en {
	_Translations$operation$tabs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get spots => 'SPOTS';
	@override String get map => 'MAPA';
	@override String get operation => 'OPERACIÓN';
}

// Path: operation.sections
class _Translations$operation$sections$es extends Translations$operation$sections$en {
	_Translations$operation$sections$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get stationOperator => 'Estación y operador';
	@override String get activities => 'Actividades';
	@override String get operationData => 'Datos de operación';
	@override String get dangerZone => 'Zona de peligro';
}

// Path: settings.theme
class _Translations$settings$theme$es extends Translations$settings$theme$en {
	_Translations$settings$theme$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo de Tema';
	@override String get system => 'Sistema';
	@override String get light => 'Claro';
	@override String get dark => 'Oscuro';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$es extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get smallest => 'Más pequeña';
	@override String get smaller => 'Pequeña';
	@override String get normal => 'Normal';
	@override String get larger => 'Grande';
	@override String get largest => 'Más grande';
}

// Path: settings.sync
class _Translations$settings$sync$es extends Translations$settings$sync$en {
	_Translations$settings$sync$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración de Sincronización';
	@override String get enable => 'Habilitar Sincronización';
	@override String get deviceKey => 'Clave del Dispositivo';
}

// Path: settings.qrz
class _Translations$settings$qrz$es extends Translations$settings$qrz$en {
	_Translations$settings$qrz$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Credenciales de QRZ.com';
	@override String get username => 'Usuario';
	@override String get password => 'Contraseña';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Guardar',
			'common.cancel' => 'Cancelar',
			'common.delete' => 'Eliminar',
			'common.create' => 'Crear',
			'common.error' => 'Error',
			'home.title' => 'Registrador Portátil',
			'home.titleDesktop' => 'Registrador de Escritorio',
			'home.newOperation' => 'Nueva operación',
			'home.stationCallsign' => 'Indicativo de la estación',
			'home.titleOptional' => 'Título (opcional)',
			'home.emptyList' => 'Aún no hay operaciones. Crea una para comenzar a registrar.',
			'home.quickLookup' => 'Búsqueda Rápida',
			'dialogs.deleteOperationConfirm' => ({required Object title}) => '¿Eliminar operación "${title}"?',
			'dialogs.operationDetails' => 'Detalles de la operación',
			'dialogs.activities' => 'Actividades',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.operation' => 'OPERACIÓN',
			'operation.comingSoon' => ({required Object label}) => '${label} — próximamente',
			'operation.noActivities' => 'No hay actividades disponibles (¿el motor de extensiones aún está iniciando?)',
			'operation.exportSuccess' => ({required Object path}) => 'Exportado a ${path}',
			'operation.exportFailed' => ({required Object error}) => 'Exportación fallida: ${error}',
			'operation.sections.stationOperator' => 'Estación y operador',
			'operation.sections.activities' => 'Actividades',
			'operation.sections.operationData' => 'Datos de operación',
			'operation.sections.dangerZone' => 'Zona de peligro',
			'operation.stationCallsignNone' => 'Sin indicativo de estación',
			'operation.titleNone' => 'Sin título',
			'operation.activitiesNone' => 'Ninguna seleccionada',
			'operation.exportAdif' => 'Exportar ADIF',
			'operation.deleteOperation' => 'Eliminar operación',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Fecha',
			'loggingControls.now' => 'Ahora',
			'loggingControls.freqKHz' => 'Frec kHz',
			'loggingControls.mode' => 'Modo',
			'loggingControls.dupe' => 'DUPE',
			'loggingControls.theirCall' => 'Su indicativo',
			'loggingControls.sent' => 'Enviado',
			'loggingControls.rcvd' => 'Recibido',
			'loggingControls.more' => 'Más',
			'loggingControls.revert' => 'Revertir',
			'loggingControls.undoDelete' => 'Deshacer eliminación',
			'loggingControls.wipe' => 'Borrar',
			'loggingControls.undo' => 'Deshacer',
			'loggingControls.pendingDeleteWarning' => 'El QSO se eliminará al guardar',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.controlSettings' => 'Controles de registro',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.theirName' => 'Nombre',
			'qsoEditForm.theirGrid' => 'Locador',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoList.empty' => 'Aún no hay QSOs — ¡haz un contacto!',
			'qsoList.duplicate' => 'Duplicado — mismo indicativo, banda y modo ya registrados',
			'qsoList.newEntity' => 'Nueva entidad DXCC',
			'qsoList.newBandOrMode' => 'Nueva banda o modo para este indicativo',
			'loggingPanel.station' => 'Estación',
			'loggingPanel.byBand' => 'Por banda',
			'loggingPanel.byMode' => 'Por modo',
			'loggingPanel.scoring' => 'Puntuación',
			'loggingPanel.dxccEntities' => 'Entidades DXCC',
			'loggingPanel.duplicates' => 'Duplicados',
			'settings.title' => 'Configuración',
			'settings.general' => 'Configuración General',
			'settings.language' => 'Idioma',
			'settings.theme.title' => 'Modo de Tema',
			'settings.theme.system' => 'Sistema',
			'settings.theme.light' => 'Claro',
			'settings.theme.dark' => 'Oscuro',
			'settings.fontScale' => 'Tamaño de Letra',
			'settings.fontScaleOpts.smallest' => 'Más pequeña',
			'settings.fontScaleOpts.smaller' => 'Pequeña',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Grande',
			'settings.fontScaleOpts.largest' => 'Más grande',
			'settings.operatorCall' => 'Indicativo del Operador',
			'settings.sync.title' => 'Configuración de Sincronización',
			'settings.sync.enable' => 'Habilitar Sincronización',
			'settings.sync.deviceKey' => 'Clave del Dispositivo',
			'settings.qrz.title' => 'Credenciales de QRZ.com',
			'settings.qrz.username' => 'Usuario',
			'settings.qrz.password' => 'Contraseña',
			'settings.developerMode' => 'Modo Desarrollador',
			_ => null,
		};
	}
}
