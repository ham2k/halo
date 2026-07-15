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
	@override late final _Translations$map$es map = _Translations$map$es._(_root);
	@override late final _Translations$activitiesView$es activitiesView = _Translations$activitiesView$es._(_root);
	@override late final _Translations$loggingControls$es loggingControls = _Translations$loggingControls$es._(_root);
	@override late final _Translations$qsoEditForm$es qsoEditForm = _Translations$qsoEditForm$es._(_root);
	@override late final _Translations$qsoList$es qsoList = _Translations$qsoList$es._(_root);
	@override late final _Translations$loggingPanel$es loggingPanel = _Translations$loggingPanel$es._(_root);
	@override late final _Translations$settings$es settings = _Translations$settings$es._(_root);
	@override late final _Translations$operationLocationScreen$es operationLocationScreen = _Translations$operationLocationScreen$es._(_root);
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
	@override String get apply => 'Aplicar';
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
	@override String get noActivities => 'No hay actividades disponibles (¿el motor de extensiones aún está iniciando?)';
	@override late final _Translations$operation$sections$es sections = _Translations$operation$sections$es._(_root);
	@override String get stationCallsignNone => 'Sin indicativo de estación';
	@override String get titleNone => 'Sin título';
	@override String get activitiesNone => 'Ninguna seleccionada';
	@override String get deleteOperation => 'Eliminar operación';
	@override String get locationNone => 'Sin definir';
	@override late final _Translations$operation$menu$es menu = _Translations$operation$menu$es._(_root);
	@override late final _Translations$operation$export$es export = _Translations$operation$export$es._(_root);
	@override late final _Translations$operation$spots$es spots = _Translations$operation$spots$es._(_root);
}

// Path: map
class _Translations$map$es extends Translations$map$en {
	_Translations$map$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get emptyState => 'Aún no hay ubicaciones de QSO.\nLos QSOs con cuadrícula, estado o país aparecerán aquí.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
}

// Path: activitiesView
class _Translations$activitiesView$es extends Translations$activitiesView$en {
	_Translations$activitiesView$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Actividades';
	@override String get activitiesCountZero => 'Sin actividades actuales';
	@override String get activitiesCountOne => 'Una actividad actual';
	@override String activitiesCountOther({required Object count}) => '${count} actividades actuales';
	@override String get empty => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para añadir una';
	@override String get addActivity => 'Añadir actividad';
	@override String get removeActivity => 'Quitar';
	@override String get editActivity => 'Editar actividad';
	@override String get reference => 'Referencia';
	@override String get invalidReference => 'Referencia no válida';
	@override String get duplicateReference => 'Ya añadida';
	@override String get searchHint => 'Busca un parque, cumbre…';
	@override String get searchOptions => 'Opciones';
	@override String get noSuggestions => 'Sin sugerencias';
	@override String get allOptions => 'Todas las opciones';
	@override String get determiningLocation => 'Determinando ubicación actual…';
	@override String get noNearbySuggestions => 'Sin sugerencias cercanas, ubicación actual desconocida';
	@override String distanceKm({required Object distance}) => '${distance} km';
}

// Path: loggingControls
class _Translations$loggingControls$es extends Translations$loggingControls$en {
	_Translations$loggingControls$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Fecha';
	@override String get now => 'Ahora';
	@override String get frequency => 'Frecuencia';
	@override String get mode => 'Modo';
	@override String get dupe => 'DUPE';
	@override String get theirCall => 'Su indicativo';
	@override String get sent => 'Enviado';
	@override String get rcvd => 'Recibido';
	@override String get more => 'Más';
	@override String get revert => 'Revertir';
	@override String get undoDelete => 'Deshacer eliminación';
	@override String get restore => 'Restaurar';
	@override String get wipe => 'Borrar';
	@override String get undo => 'Deshacer';
	@override String get pendingDeleteWarning => 'El QSO se eliminará al guardar';
	@override String get deletedQsoWarning => 'QSO eliminado';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Radio';
	@override String get controlSettings => 'Controles de registro';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Auto-spot';
	@override String spotSelfAt({required Object freq}) => 'Auto-spot en ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot a ${call} en ${freq}';
	@override String spotTooLate({required Object call}) => 'Demasiado tarde para spotear a ${call}';
	@override String get spotNoFreq => 'Primero define una frecuencia para spotear';
	@override String get spotComment => 'Comentario';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$es extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editar QSO';
	@override String get theirName => 'Nombre';
	@override String get theirGrid => 'Locador';
	@override String get theirState => 'Estado/Provincia';
	@override String get band => 'Banda';
	@override String get notes => 'Notas';
}

// Path: qsoList
class _Translations$qsoList$es extends Translations$qsoList$en {
	_Translations$qsoList$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Aún no hay QSOs — ¡haz un contacto!';
	@override String get editEventTime => 'Editar hora';
	@override String get today => 'Hoy';
	@override String get yesterday => 'Ayer';
	@override String get tomorrow => 'Mañana';
	@override String get eventStarted => 'Operación iniciada';
	@override String get eventBreak => 'Descanso';
	@override String get eventEnded => 'Operación finalizada';
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
	@override late final _Translations$settings$themeDescription$es themeDescription = _Translations$settings$themeDescription$es._(_root);
	@override String get fontScale => 'Tamaño de Letra';
	@override late final _Translations$settings$fontScaleOpts$es fontScaleOpts = _Translations$settings$fontScaleOpts$es._(_root);
	@override String get fontScaleDescription => 'Escala toda la interfaz: texto, controles y espaciado';
	@override String get distanceUnits => 'Unidades de distancia';
	@override late final _Translations$settings$distanceUnitsOpts$es distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$es._(_root);
	@override String get distanceUnitsDescription => 'Para las distancias mostradas en el mapa';
	@override String get operatorCall => 'Indicativo del Operador';
	@override late final _Translations$settings$sync$es sync = _Translations$settings$sync$es._(_root);
	@override late final _Translations$settings$qrz$es qrz = _Translations$settings$qrz$es._(_root);
	@override String get developerMode => 'Modo Desarrollador';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$es extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ubicación de la operación';
	@override String get selectedLocation => 'Ubicación seleccionada';
	@override String get gridSquare => 'Locator de cuadrícula Maidenhead';
	@override String get suggestedLocations => 'Ubicaciones sugeridas';
	@override String get deviceGps => 'GPS del dispositivo';
	@override String get locating => 'Localizando…';
	@override String get gpsUnavailable => 'Ubicación no disponible';
	@override String get permissionDenied => 'Permiso de ubicación denegado';
	@override String get moreDetails => 'Más detalles';
	@override String get stateOrProvince => 'Estado o provincia (opcional)';
	@override String get county => 'Condado (opcional)';
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
	@override String get location => 'Ubicación';
}

// Path: operation.menu
class _Translations$operation$menu$es extends Translations$operation$menu$en {
	_Translations$operation$menu$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostrar campos RST';
	@override String get showStateField => 'Mostrar campo Estado/Provincia';
	@override String get showGridField => 'Mostrar campo Locador';
	@override String get showDeletedQsos => 'Mostrar QSOs eliminados';
	@override String get showQsoNumbers => 'Mostrar números de QSO';
}

// Path: operation.export
class _Translations$operation$export$es extends Translations$operation$export$en {
	_Translations$operation$export$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportar';
	@override String get syncedOperation => 'La operación está sincronizada';
	@override String get unsyncedOperation => 'La operación tiene cambios sin sincronizar';
	@override String qsosSynced({required Object total}) => 'Los ${total} QSOs están sincronizados';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendientes de sincronizar';
	@override String eventsSynced({required Object total}) => 'Los ${total} marcadores de evento están sincronizados';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendientes de sincronizar';
	@override String get loading => 'Cargando opciones de exportación…';
	@override String get noOptions => 'No hay formatos de exportación disponibles (¿el motor de extensiones aún está iniciando?)';
	@override String get share => 'Compartir';
	@override String saveSuccess({required Object path}) => 'Guardado en ${path}';
	@override String exportFailed({required Object error}) => 'Exportación fallida: ${error}';
}

// Path: operation.spots
class _Translations$operation$spots$es extends Translations$operation$spots$en {
	_Translations$operation$spots$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ningún spot coincide con tus filtros';
	@override String error({required Object error}) => 'No se pudieron cargar los spots: ${error}';
	@override String get unknownBand => 'Otras';
	@override String get auto => 'Auto';
	@override String autoValue({required Object value}) => 'Auto (${value})';
	@override String get any => 'Cualquiera';
	@override String get allBands => 'Todas las bandas';
	@override String get allModes => 'Todos los modos';
	@override String get notDigital => 'No digital';
	@override String spotsCount({required Object count}) => '${count} spots';
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutos';
	@override String get mostRecentSpots => 'Spots más recientes';
	@override String get callsOfNote => 'Indicativos destacados';
	@override late final _Translations$operation$spots$continents$es continents = _Translations$operation$spots$continents$es._(_root);
	@override late final _Translations$operation$spots$filters$es filters = _Translations$operation$spots$filters$es._(_root);
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

// Path: settings.themeDescription
class _Translations$settings$themeDescription$es extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sigue la configuración del sistema';
	@override String get light => 'Siempre en Modo Claro';
	@override String get dark => 'Siempre en Modo Oscuro';
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

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$es extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilómetros';
	@override String get miles => 'Millas';
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

// Path: operation.spots.continents
class _Translations$operation$spots$continents$es extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get af => 'África';
	@override String get as => 'Asia';
	@override String get eu => 'Europa';
	@override String get na => 'Norteamérica';
	@override String get oc => 'Oceanía';
	@override String get sa => 'Sudamérica';
	@override String get an => 'Antártida';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$es extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrar spots';
	@override String get band => 'Banda';
	@override String get mode => 'Modo';
	@override String get age => 'Antigüedad';
	@override String get sources => 'Fuentes';
	@override String get continent => 'Continente';
	@override String get sorting => 'Orden';
	@override String get sortByTime => 'Por hora del spot';
	@override String get sortByFrequency => 'Por frecuencia';
	@override String get groupCallsWithNotes => 'Agrupar indicativos destacados';
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
			'common.apply' => 'Aplicar',
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
			'operation.noActivities' => 'No hay actividades disponibles (¿el motor de extensiones aún está iniciando?)',
			'operation.sections.stationOperator' => 'Estación y operador',
			'operation.sections.activities' => 'Actividades',
			'operation.sections.operationData' => 'Datos de operación',
			'operation.sections.dangerZone' => 'Zona de peligro',
			'operation.sections.location' => 'Ubicación',
			'operation.stationCallsignNone' => 'Sin indicativo de estación',
			'operation.titleNone' => 'Sin título',
			'operation.activitiesNone' => 'Ninguna seleccionada',
			'operation.deleteOperation' => 'Eliminar operación',
			'operation.locationNone' => 'Sin definir',
			'operation.menu.showRstFields' => 'Mostrar campos RST',
			'operation.menu.showStateField' => 'Mostrar campo Estado/Provincia',
			'operation.menu.showGridField' => 'Mostrar campo Locador',
			'operation.menu.showDeletedQsos' => 'Mostrar QSOs eliminados',
			'operation.menu.showQsoNumbers' => 'Mostrar números de QSO',
			'operation.export.title' => 'Exportar',
			'operation.export.syncedOperation' => 'La operación está sincronizada',
			'operation.export.unsyncedOperation' => 'La operación tiene cambios sin sincronizar',
			'operation.export.qsosSynced' => ({required Object total}) => 'Los ${total} QSOs están sincronizados',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendientes de sincronizar',
			'operation.export.eventsSynced' => ({required Object total}) => 'Los ${total} marcadores de evento están sincronizados',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendientes de sincronizar',
			'operation.export.loading' => 'Cargando opciones de exportación…',
			'operation.export.noOptions' => 'No hay formatos de exportación disponibles (¿el motor de extensiones aún está iniciando?)',
			'operation.export.share' => 'Compartir',
			'operation.export.saveSuccess' => ({required Object path}) => 'Guardado en ${path}',
			'operation.export.exportFailed' => ({required Object error}) => 'Exportación fallida: ${error}',
			'operation.spots.empty' => 'Ningún spot coincide con tus filtros',
			'operation.spots.error' => ({required Object error}) => 'No se pudieron cargar los spots: ${error}',
			'operation.spots.unknownBand' => 'Otras',
			'operation.spots.auto' => 'Auto',
			'operation.spots.autoValue' => ({required Object value}) => 'Auto (${value})',
			'operation.spots.any' => 'Cualquiera',
			'operation.spots.allBands' => 'Todas las bandas',
			'operation.spots.allModes' => 'Todos los modos',
			'operation.spots.notDigital' => 'No digital',
			'operation.spots.spotsCount' => ({required Object count}) => '${count} spots',
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutos',
			'operation.spots.mostRecentSpots' => 'Spots más recientes',
			'operation.spots.callsOfNote' => 'Indicativos destacados',
			'operation.spots.continents.af' => 'África',
			'operation.spots.continents.as' => 'Asia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Norteamérica',
			'operation.spots.continents.oc' => 'Oceanía',
			'operation.spots.continents.sa' => 'Sudamérica',
			'operation.spots.continents.an' => 'Antártida',
			'operation.spots.filters.title' => 'Filtrar spots',
			'operation.spots.filters.band' => 'Banda',
			'operation.spots.filters.mode' => 'Modo',
			'operation.spots.filters.age' => 'Antigüedad',
			'operation.spots.filters.sources' => 'Fuentes',
			'operation.spots.filters.continent' => 'Continente',
			'operation.spots.filters.sorting' => 'Orden',
			'operation.spots.filters.sortByTime' => 'Por hora del spot',
			'operation.spots.filters.sortByFrequency' => 'Por frecuencia',
			'operation.spots.filters.groupCallsWithNotes' => 'Agrupar indicativos destacados',
			'map.emptyState' => 'Aún no hay ubicaciones de QSO.\nLos QSOs con cuadrícula, estado o país aparecerán aquí.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'activitiesView.title' => 'Actividades',
			'activitiesView.activitiesCountZero' => 'Sin actividades actuales',
			'activitiesView.activitiesCountOne' => 'Una actividad actual',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} actividades actuales',
			'activitiesView.empty' => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para añadir una',
			'activitiesView.addActivity' => 'Añadir actividad',
			'activitiesView.removeActivity' => 'Quitar',
			'activitiesView.editActivity' => 'Editar actividad',
			'activitiesView.reference' => 'Referencia',
			'activitiesView.invalidReference' => 'Referencia no válida',
			'activitiesView.duplicateReference' => 'Ya añadida',
			'activitiesView.searchHint' => 'Busca un parque, cumbre…',
			'activitiesView.searchOptions' => 'Opciones',
			'activitiesView.noSuggestions' => 'Sin sugerencias',
			'activitiesView.allOptions' => 'Todas las opciones',
			'activitiesView.determiningLocation' => 'Determinando ubicación actual…',
			'activitiesView.noNearbySuggestions' => 'Sin sugerencias cercanas, ubicación actual desconocida',
			'activitiesView.distanceKm' => ({required Object distance}) => '${distance} km',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Fecha',
			'loggingControls.now' => 'Ahora',
			'loggingControls.frequency' => 'Frecuencia',
			'loggingControls.mode' => 'Modo',
			'loggingControls.dupe' => 'DUPE',
			'loggingControls.theirCall' => 'Su indicativo',
			'loggingControls.sent' => 'Enviado',
			'loggingControls.rcvd' => 'Recibido',
			'loggingControls.more' => 'Más',
			'loggingControls.revert' => 'Revertir',
			'loggingControls.undoDelete' => 'Deshacer eliminación',
			'loggingControls.restore' => 'Restaurar',
			'loggingControls.wipe' => 'Borrar',
			'loggingControls.undo' => 'Deshacer',
			'loggingControls.pendingDeleteWarning' => 'El QSO se eliminará al guardar',
			'loggingControls.deletedQsoWarning' => 'QSO eliminado',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.controlSettings' => 'Controles de registro',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Auto-spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Auto-spot en ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot a ${call} en ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Demasiado tarde para spotear a ${call}',
			'loggingControls.spotNoFreq' => 'Primero define una frecuencia para spotear',
			'loggingControls.spotComment' => 'Comentario',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.theirName' => 'Nombre',
			'qsoEditForm.theirGrid' => 'Locador',
			'qsoEditForm.theirState' => 'Estado/Provincia',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoList.empty' => 'Aún no hay QSOs — ¡haz un contacto!',
			'qsoList.editEventTime' => 'Editar hora',
			'qsoList.today' => 'Hoy',
			'qsoList.yesterday' => 'Ayer',
			'qsoList.tomorrow' => 'Mañana',
			'qsoList.eventStarted' => 'Operación iniciada',
			'qsoList.eventBreak' => 'Descanso',
			'qsoList.eventEnded' => 'Operación finalizada',
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
			'settings.themeDescription.system' => 'Sigue la configuración del sistema',
			'settings.themeDescription.light' => 'Siempre en Modo Claro',
			'settings.themeDescription.dark' => 'Siempre en Modo Oscuro',
			'settings.fontScale' => 'Tamaño de Letra',
			'settings.fontScaleOpts.smallest' => 'Más pequeña',
			'settings.fontScaleOpts.smaller' => 'Pequeña',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Grande',
			'settings.fontScaleOpts.largest' => 'Más grande',
			'settings.fontScaleDescription' => 'Escala toda la interfaz: texto, controles y espaciado',
			'settings.distanceUnits' => 'Unidades de distancia',
			'settings.distanceUnitsOpts.kilometers' => 'Kilómetros',
			'settings.distanceUnitsOpts.miles' => 'Millas',
			'settings.distanceUnitsDescription' => 'Para las distancias mostradas en el mapa',
			'settings.operatorCall' => 'Indicativo del Operador',
			'settings.sync.title' => 'Configuración de Sincronización',
			'settings.sync.enable' => 'Habilitar Sincronización',
			'settings.sync.deviceKey' => 'Clave del Dispositivo',
			'settings.qrz.title' => 'Credenciales de QRZ.com',
			'settings.qrz.username' => 'Usuario',
			'settings.qrz.password' => 'Contraseña',
			'settings.developerMode' => 'Modo Desarrollador',
			'operationLocationScreen.title' => 'Ubicación de la operación',
			'operationLocationScreen.selectedLocation' => 'Ubicación seleccionada',
			'operationLocationScreen.gridSquare' => 'Locator de cuadrícula Maidenhead',
			'operationLocationScreen.suggestedLocations' => 'Ubicaciones sugeridas',
			'operationLocationScreen.deviceGps' => 'GPS del dispositivo',
			'operationLocationScreen.locating' => 'Localizando…',
			'operationLocationScreen.gpsUnavailable' => 'Ubicación no disponible',
			'operationLocationScreen.permissionDenied' => 'Permiso de ubicación denegado',
			'operationLocationScreen.moreDetails' => 'Más detalles',
			'operationLocationScreen.stateOrProvince' => 'Estado o provincia (opcional)',
			'operationLocationScreen.county' => 'Condado (opcional)',
			_ => null,
		};
	}
}
