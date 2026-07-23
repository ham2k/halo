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
	@override late final _Translations$onboarding$es onboarding = _Translations$onboarding$es._(_root);
	@override late final _Translations$startScreen$es startScreen = _Translations$startScreen$es._(_root);
	@override late final _Translations$extensionsPanel$es extensionsPanel = _Translations$extensionsPanel$es._(_root);
	@override late final _Translations$home$es home = _Translations$home$es._(_root);
	@override late final _Translations$dialogs$es dialogs = _Translations$dialogs$es._(_root);
	@override late final _Translations$operation$es operation = _Translations$operation$es._(_root);
	@override late final _Translations$map$es map = _Translations$map$es._(_root);
	@override late final _Translations$activitiesView$es activitiesView = _Translations$activitiesView$es._(_root);
	@override late final _Translations$loggingControls$es loggingControls = _Translations$loggingControls$es._(_root);
	@override late final _Translations$qsoEditForm$es qsoEditForm = _Translations$qsoEditForm$es._(_root);
	@override late final _Translations$qsoList$es qsoList = _Translations$qsoList$es._(_root);
	@override late final _Translations$loggingPanel$es loggingPanel = _Translations$loggingPanel$es._(_root);
	@override late final _Translations$callInfo$es callInfo = _Translations$callInfo$es._(_root);
	@override late final _Translations$settings$es settings = _Translations$settings$es._(_root);
	@override late final _Translations$operationLocationScreen$es operationLocationScreen = _Translations$operationLocationScreen$es._(_root);
	@override late final _Translations$versionLabel$es versionLabel = _Translations$versionLabel$es._(_root);
	@override late final _Translations$notices$es notices = _Translations$notices$es._(_root);
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
	@override String get close => 'Cerrar';
	@override String get done => 'Listo';
	@override String get callsign => 'Indicativo';
}

// Path: onboarding
class _Translations$onboarding$es extends Translations$onboarding$en {
	_Translations$onboarding$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => '¡Bienvenido a Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => '¡Bienvenido a Ham2K Logger!';
	@override String get welcomeBody => 'Tenemos algunas preguntas para ayudarnos a servirte mejor.';
	@override String get skip => 'Omitir';
	@override String get kContinue => 'Continuar';
	@override String get back => 'Atrás';
	@override String get next => 'Siguiente';
	@override String get done => 'Listo';
	@override String get callsignTitle => '¿Cuál es tu indicativo?';
	@override String get callsignBody => 'Necesitas una licencia de radioaficionado para que esta app te resulte útil';
	@override String get callsignLabel => 'Indicativo del operador';
	@override String get alreadyHaveAccount => '¿Ya tienes una cuenta?';
	@override String get activitiesTitle => 'Actividades favoritas';
	@override String get activitiesBody => '¿Te interesa alguno de estos populares programas de activación?';
	@override String get activitiesFooter => '(Encontrarás más opciones en la Configuración)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get consentTitle => 'Datos y Privacidad';
	@override String get consentUsageBody => 'Para ayudarnos a mejorar la app, nos gustaría recopilar datos de rendimiento, fallos y uso.';
	@override String get consentUsageLabel => 'Compartir datos de uso';
	@override String get consentOperationBody => 'Algunas funciones pueden implicar compartir datos de tus operaciones con otros usuarios. Puedes desactivarlo en cualquier momento.';
	@override String get consentOperationLabel => 'Compartir datos de operaciones';
}

// Path: startScreen
class _Translations$startScreen$es extends Translations$startScreen$en {
	_Translations$startScreen$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get credits => 'por KI2D y amigos';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$es extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Actividades';
	@override String get categoryLookup => 'Búsqueda de indicativos';
	@override String get categoryOther => 'Otras extensiones';
	@override String get searchHint => 'Buscar extensiones';
	@override String get applying => 'Activando cambios de extensiones, esto puede tardar un momento…';
	@override String get noMatches => 'Ninguna extensión coincide con tu búsqueda';
}

// Path: home
class _Translations$home$es extends Translations$home$en {
	_Translations$home$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registrador Portátil';
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
	@override String get stationCallsign => 'Indicativo de la estación';
	@override String get notes => 'Notas';
}

// Path: operation
class _Translations$operation$es extends Translations$operation$en {
	_Translations$operation$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$operation$tabs$es tabs = _Translations$operation$tabs$es._(_root);
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
	@override String get flat => 'Plano';
	@override String get globe => 'Globo';
}

// Path: activitiesView
class _Translations$activitiesView$es extends Translations$activitiesView$en {
	_Translations$activitiesView$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Actividades';
	@override String get activitiesCountZero => 'Sin actividades seleccionadas';
	@override String get activitiesCountOne => '1 actividad';
	@override String activitiesCountOther({required Object count}) => '${count} actividades';
	@override String get empty => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para añadir una';
	@override String get addActivity => 'Añadir actividad';
	@override String get removeActivity => 'Quitar';
	@override String get editActivity => 'Editar actividad';
	@override String get manageExtensions => 'Administrar extensiones';
	@override String get manage => 'Administrar';
	@override String activitiesTitle1({required Object first}) => 'Tipos de actividad: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipos de actividad: ${first} y ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipos de actividad: ${first}, ${second} y ${more} más';
	@override String get reference => 'Referencia';
	@override String get invalidReference => 'Referencia no válida';
	@override String get duplicateReference => 'Ya añadida';
	@override String get searchHint => 'Busca por nombre, referencia o cualquier otra cosa…';
	@override String get noSuggestions => 'Sin sugerencias';
	@override String get allOptions => 'Tipos de actividad';
	@override String get determiningLocation => 'Determinando ubicación actual…\nEsperando señal de GPS para encontrar referencias cercanas';
	@override String get noNearbySuggestions => 'Datos de ubicación no disponibles\nPor lo tanto, no podemos determinar referencias cercanas';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String get emptySheet => 'Usa las sugerencias y la búsqueda abajo para añadir una';
	@override String activeCount({required Object count}) => '${count} activas';
	@override String get exports => 'Exportar';
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
	@override late final _Translations$loggingControls$info$es info = _Translations$loggingControls$info$es._(_root);
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

// Path: callInfo
class _Translations$callInfo$es extends Translations$callInfo$en {
	_Translations$callInfo$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostrar imagen';
	@override String get notes => 'Notas';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String get thisOpCountOne => '1 QSO en esta operación';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs en esta operación';
	@override String get otherOpsCountOne => '1 QSO en otras operaciones';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs en otras operaciones';
	@override String andMore({required Object count}) => '… y ${count} más';
	@override String withCall({required Object call}) => 'con ${call}';
}

// Path: settings
class _Translations$settings$es extends Translations$settings$en {
	_Translations$settings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración';
	@override String get language => 'Idioma';
	@override late final _Translations$settings$theme$es theme = _Translations$settings$theme$es._(_root);
	@override late final _Translations$settings$themeDescription$es themeDescription = _Translations$settings$themeDescription$es._(_root);
	@override String get fontScale => 'Tamaño de Letra';
	@override late final _Translations$settings$fontScaleOpts$es fontScaleOpts = _Translations$settings$fontScaleOpts$es._(_root);
	@override String get distanceUnits => 'Unidades de distancia';
	@override late final _Translations$settings$distanceUnitsOpts$es distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$es._(_root);
	@override String get userInterface => 'Interfaz de Usuario';
	@override late final _Translations$settings$logging$es logging = _Translations$settings$logging$es._(_root);
	@override late final _Translations$settings$privacy$es privacy = _Translations$settings$privacy$es._(_root);
	@override String get operatorCall => 'Indicativo del Operador';
	@override late final _Translations$settings$sync$es sync = _Translations$settings$sync$es._(_root);
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

// Path: versionLabel
class _Translations$versionLabel$es extends Translations$versionLabel$en {
	_Translations$versionLabel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versión ${version}';
	@override String versionBuild({required Object version, required Object build}) => 'Versión ${version} - Build ${build}';
}

// Path: notices
class _Translations$notices$es extends Translations$notices$en {
	_Translations$notices$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Aún no hay avisos';
}

// Path: operation.tabs
class _Translations$operation$tabs$es extends Translations$operation$tabs$en {
	_Translations$operation$tabs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFO';
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
	@override String get lookupAllQsos => 'Buscar datos de todos los QSOs';
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
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutos';
	@override String get callsOfNote => 'Indicativos destacados';
	@override late final _Translations$operation$spots$continents$es continents = _Translations$operation$spots$continents$es._(_root);
	@override late final _Translations$operation$spots$filters$es filters = _Translations$operation$spots$filters$es._(_root);
}

// Path: loggingControls.info
class _Translations$loggingControls$info$es extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Aún no hay QSOs... ¡a la carga!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} en ${time}';
	@override String sinceLast({required Object time}) => '${time} desde el último';
	@override String ratePer10({required Object rate}) => '${rate} Q/h en los últimos 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h en los últimos 100';
	@override String distanceTo({required Object distance}) => '${distance} a';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String get noticeDupe => '¡Dupe!';
	@override String get noticeNewBand => 'Nueva Banda';
	@override String get noticeNewMode => 'Nuevo Modo';
	@override String get noticeNewDXCC => 'Nuevo DXCC';
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
	@override String get smallestMinusMinus => 'Más pequeña--';
	@override String get smallestMinus => 'Más pequeña-';
	@override String get smallest => 'Más pequeña';
	@override String get smaller => 'Pequeña';
	@override String get normal => 'Normal';
	@override String get larger => 'Grande';
	@override String get largest => 'Más grande';
	@override String get largestPlus => 'Más grande+';
	@override String get largestPlusPlus => 'Más grande++';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$es extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilómetros';
	@override String get miles => 'Millas';
}

// Path: settings.logging
class _Translations$settings$logging$es extends Translations$settings$logging$en {
	_Translations$settings$logging$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registro';
	@override late final _Translations$settings$logging$leftieMode$es leftieMode = _Translations$settings$logging$leftieMode$es._(_root);
	@override late final _Translations$settings$logging$fieldsOnTop$es fieldsOnTop = _Translations$settings$logging$fieldsOnTop$es._(_root);
	@override late final _Translations$settings$logging$countryFlags$es countryFlags = _Translations$settings$logging$countryFlags$es._(_root);
	@override late final _Translations$settings$logging$showBearing$es showBearing = _Translations$settings$logging$showBearing$es._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$es switchSentRcvd = _Translations$settings$logging$switchSentRcvd$es._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$es jumpAfterRST = _Translations$settings$logging$jumpAfterRST$es._(_root);
	@override late final _Translations$settings$logging$numbersRow$es numbersRow = _Translations$settings$logging$numbersRow$es._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$es numbersRowExtra = _Translations$settings$logging$numbersRowExtra$es._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$es numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$es._(_root);
	@override String get bands => 'Bandas';
	@override String get modes => 'Modos';
}

// Path: settings.privacy
class _Translations$settings$privacy$es extends Translations$settings$privacy$en {
	_Translations$settings$privacy$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacidad';
	@override late final _Translations$settings$privacy$shareAppData$es shareAppData = _Translations$settings$privacy$shareAppData$es._(_root);
	@override late final _Translations$settings$privacy$shareOpData$es shareOpData = _Translations$settings$privacy$shareOpData$es._(_root);
	@override String get privacyPolicy => 'Política de Privacidad';
	@override String get termsOfService => 'Términos de Servicio';
}

// Path: settings.sync
class _Translations$settings$sync$es extends Translations$settings$sync$en {
	_Translations$settings$sync$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'LoFi Cloud Sync';
	@override String get enable => 'Habilitar Sincronización';
	@override String get deviceKey => 'Clave del Dispositivo';
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

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$es extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo Zurdo';
	@override String get descriptionOn => 'Usar diseño para zurdos';
	@override String get descriptionOff => 'Usar diseño para diestros';
}

// Path: settings.logging.fieldsOnTop
class _Translations$settings$logging$fieldsOnTop$es extends Translations$settings$logging$fieldsOnTop$en {
	_Translations$settings$logging$fieldsOnTop$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Campos arriba';
	@override String get descriptionOn => 'Campos de registro encima de la lista de QSOs, más recientes primero';
	@override String get descriptionOff => 'Campos de registro debajo de la lista de QSOs';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$es extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Banderas de País';
	@override String get dx => 'Mostrar solo para contactos DX';
	@override String get all => 'Mostrar banderas para todos los contactos';
	@override String get none => 'No mostrar banderas';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$es extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar Rumbo';
	@override String get descriptionOn => 'Mostrar rumbo estimado a la estación';
	@override String get descriptionOff => 'No mostrar información de rumbo';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$es extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cambiar orden de reportes de señal';
	@override String get sentFirst => 'Enviado primero, Recibido después';
	@override String get rcvdFirst => 'Recibido primero, Enviado después';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$es extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Saltar al siguiente campo al ingresar RST';
	@override String get descriptionOn => 'Saltar después de ingresar el RST';
	@override String get descriptionOff => 'No saltar automáticamente';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$es extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Fila de Números';
	@override String get description => 'Muestra una fila de teclas numéricas sobre el teclado al registrar';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$es extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tecla de barra y punto';
	@override String get description => 'Añade una tecla contextual: «/» para indicativos, «.» para números';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$es extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrar al pulsar';
	@override String get description => 'Respuesta háptica al pulsar una tecla numérica';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$es extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartir datos de uso';
	@override String get descriptionOn => 'Ayúdanos a mejorar la app compartiendo datos de uso, fallos y rendimiento';
	@override String get descriptionOff => 'Mantener privados los datos de uso.\nEl equipo de Ham2K no podrá detectar fallos u otros problemas.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$es extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartir datos de operaciones';
	@override String get descriptionOn => 'Compartir algunos datos de operaciones públicamente y con otros usuarios';
	@override String get descriptionOff => 'Mantener privados los datos de operaciones';
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
			'common.close' => 'Cerrar',
			'common.done' => 'Listo',
			'common.callsign' => 'Indicativo',
			'onboarding.welcomeTitle' => '¡Bienvenido a Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => '¡Bienvenido a Ham2K Logger!',
			'onboarding.welcomeBody' => 'Tenemos algunas preguntas para ayudarnos a servirte mejor.',
			'onboarding.skip' => 'Omitir',
			'onboarding.kContinue' => 'Continuar',
			'onboarding.back' => 'Atrás',
			'onboarding.next' => 'Siguiente',
			'onboarding.done' => 'Listo',
			'onboarding.callsignTitle' => '¿Cuál es tu indicativo?',
			'onboarding.callsignBody' => 'Necesitas una licencia de radioaficionado para que esta app te resulte útil',
			'onboarding.callsignLabel' => 'Indicativo del operador',
			'onboarding.alreadyHaveAccount' => '¿Ya tienes una cuenta?',
			'onboarding.activitiesTitle' => 'Actividades favoritas',
			'onboarding.activitiesBody' => '¿Te interesa alguno de estos populares programas de activación?',
			'onboarding.activitiesFooter' => '(Encontrarás más opciones en la Configuración)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.consentTitle' => 'Datos y Privacidad',
			'onboarding.consentUsageBody' => 'Para ayudarnos a mejorar la app, nos gustaría recopilar datos de rendimiento, fallos y uso.',
			'onboarding.consentUsageLabel' => 'Compartir datos de uso',
			'onboarding.consentOperationBody' => 'Algunas funciones pueden implicar compartir datos de tus operaciones con otros usuarios. Puedes desactivarlo en cualquier momento.',
			'onboarding.consentOperationLabel' => 'Compartir datos de operaciones',
			'startScreen.credits' => 'por KI2D y amigos',
			'extensionsPanel.categoryActivity' => 'Actividades',
			'extensionsPanel.categoryLookup' => 'Búsqueda de indicativos',
			'extensionsPanel.categoryOther' => 'Otras extensiones',
			'extensionsPanel.searchHint' => 'Buscar extensiones',
			'extensionsPanel.applying' => 'Activando cambios de extensiones, esto puede tardar un momento…',
			'extensionsPanel.noMatches' => 'Ninguna extensión coincide con tu búsqueda',
			'home.title' => 'Registrador Portátil',
			'home.newOperation' => 'Nueva operación',
			'home.stationCallsign' => 'Indicativo de la estación',
			'home.titleOptional' => 'Título (opcional)',
			'home.emptyList' => 'Aún no hay operaciones. Crea una para comenzar a registrar.',
			'home.quickLookup' => 'Búsqueda Rápida',
			'dialogs.deleteOperationConfirm' => ({required Object title}) => '¿Eliminar operación "${title}"?',
			'dialogs.operationDetails' => 'Detalles de la operación',
			'dialogs.activities' => 'Actividades',
			'dialogs.stationCallsign' => 'Indicativo de la estación',
			'dialogs.notes' => 'Notas',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.operation' => 'OPERACIÓN',
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
			'operation.menu.lookupAllQsos' => 'Buscar datos de todos los QSOs',
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
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutos',
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
			'map.flat' => 'Plano',
			'map.globe' => 'Globo',
			'activitiesView.title' => 'Actividades',
			'activitiesView.activitiesCountZero' => 'Sin actividades seleccionadas',
			'activitiesView.activitiesCountOne' => '1 actividad',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} actividades',
			'activitiesView.empty' => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para añadir una',
			'activitiesView.addActivity' => 'Añadir actividad',
			'activitiesView.removeActivity' => 'Quitar',
			'activitiesView.editActivity' => 'Editar actividad',
			'activitiesView.manageExtensions' => 'Administrar extensiones',
			'activitiesView.manage' => 'Administrar',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipos de actividad: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipos de actividad: ${first} y ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipos de actividad: ${first}, ${second} y ${more} más',
			'activitiesView.reference' => 'Referencia',
			'activitiesView.invalidReference' => 'Referencia no válida',
			'activitiesView.duplicateReference' => 'Ya añadida',
			'activitiesView.searchHint' => 'Busca por nombre, referencia o cualquier otra cosa…',
			'activitiesView.noSuggestions' => 'Sin sugerencias',
			'activitiesView.allOptions' => 'Tipos de actividad',
			'activitiesView.determiningLocation' => 'Determinando ubicación actual…\nEsperando señal de GPS para encontrar referencias cercanas',
			'activitiesView.noNearbySuggestions' => 'Datos de ubicación no disponibles\nPor lo tanto, no podemos determinar referencias cercanas',
			'activitiesView.distanceKm' => ({required Object distance}) => '${distance} km',
			'activitiesView.emptySheet' => 'Usa las sugerencias y la búsqueda abajo para añadir una',
			'activitiesView.activeCount' => ({required Object count}) => '${count} activas',
			'activitiesView.exports' => 'Exportar',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Fecha',
			'loggingControls.now' => 'Ahora',
			'loggingControls.frequency' => 'Frecuencia',
			'loggingControls.mode' => 'Modo',
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
			'loggingControls.info.noQsos' => 'Aún no hay QSOs... ¡a la carga!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} en ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} desde el último',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h en los últimos 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h en los últimos 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} a',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a',
			'loggingControls.info.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'loggingControls.info.noticeDupe' => '¡Dupe!',
			'loggingControls.info.noticeNewBand' => 'Nueva Banda',
			'loggingControls.info.noticeNewMode' => 'Nuevo Modo',
			'loggingControls.info.noticeNewDXCC' => 'Nuevo DXCC',
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
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostrar imagen',
			'callInfo.notes' => 'Notas',
			'callInfo.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'callInfo.thisOpCountOne' => '1 QSO en esta operación',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs en esta operación',
			'callInfo.otherOpsCountOne' => '1 QSO en otras operaciones',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs en otras operaciones',
			'callInfo.andMore' => ({required Object count}) => '… y ${count} más',
			'callInfo.withCall' => ({required Object call}) => 'con ${call}',
			'settings.title' => 'Configuración',
			'settings.language' => 'Idioma',
			'settings.theme.title' => 'Modo de Tema',
			'settings.theme.system' => 'Sistema',
			'settings.theme.light' => 'Claro',
			'settings.theme.dark' => 'Oscuro',
			'settings.themeDescription.system' => 'Sigue la configuración del sistema',
			'settings.themeDescription.light' => 'Siempre en Modo Claro',
			'settings.themeDescription.dark' => 'Siempre en Modo Oscuro',
			'settings.fontScale' => 'Tamaño de Letra',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Más pequeña--',
			'settings.fontScaleOpts.smallestMinus' => 'Más pequeña-',
			'settings.fontScaleOpts.smallest' => 'Más pequeña',
			'settings.fontScaleOpts.smaller' => 'Pequeña',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Grande',
			'settings.fontScaleOpts.largest' => 'Más grande',
			'settings.fontScaleOpts.largestPlus' => 'Más grande+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Más grande++',
			'settings.distanceUnits' => 'Unidades de distancia',
			'settings.distanceUnitsOpts.kilometers' => 'Kilómetros',
			'settings.distanceUnitsOpts.miles' => 'Millas',
			'settings.userInterface' => 'Interfaz de Usuario',
			'settings.logging.title' => 'Registro',
			'settings.logging.leftieMode.title' => 'Modo Zurdo',
			'settings.logging.leftieMode.descriptionOn' => 'Usar diseño para zurdos',
			'settings.logging.leftieMode.descriptionOff' => 'Usar diseño para diestros',
			'settings.logging.fieldsOnTop.title' => 'Campos arriba',
			'settings.logging.fieldsOnTop.descriptionOn' => 'Campos de registro encima de la lista de QSOs, más recientes primero',
			'settings.logging.fieldsOnTop.descriptionOff' => 'Campos de registro debajo de la lista de QSOs',
			'settings.logging.countryFlags.title' => 'Banderas de País',
			'settings.logging.countryFlags.dx' => 'Mostrar solo para contactos DX',
			'settings.logging.countryFlags.all' => 'Mostrar banderas para todos los contactos',
			'settings.logging.countryFlags.none' => 'No mostrar banderas',
			'settings.logging.showBearing.title' => 'Mostrar Rumbo',
			'settings.logging.showBearing.descriptionOn' => 'Mostrar rumbo estimado a la estación',
			'settings.logging.showBearing.descriptionOff' => 'No mostrar información de rumbo',
			'settings.logging.switchSentRcvd.title' => 'Cambiar orden de reportes de señal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Enviado primero, Recibido después',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Recibido primero, Enviado después',
			'settings.logging.jumpAfterRST.title' => 'Saltar al siguiente campo al ingresar RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Saltar después de ingresar el RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'No saltar automáticamente',
			'settings.logging.numbersRow.title' => 'Fila de Números',
			'settings.logging.numbersRow.description' => 'Muestra una fila de teclas numéricas sobre el teclado al registrar',
			'settings.logging.numbersRowExtra.title' => 'Tecla de barra y punto',
			'settings.logging.numbersRowExtra.description' => 'Añade una tecla contextual: «/» para indicativos, «.» para números',
			'settings.logging.numbersRowVibrate.title' => 'Vibrar al pulsar',
			'settings.logging.numbersRowVibrate.description' => 'Respuesta háptica al pulsar una tecla numérica',
			'settings.logging.bands' => 'Bandas',
			'settings.logging.modes' => 'Modos',
			'settings.privacy.title' => 'Privacidad',
			'settings.privacy.shareAppData.title' => 'Compartir datos de uso',
			'settings.privacy.shareAppData.descriptionOn' => 'Ayúdanos a mejorar la app compartiendo datos de uso, fallos y rendimiento',
			'settings.privacy.shareAppData.descriptionOff' => 'Mantener privados los datos de uso.\nEl equipo de Ham2K no podrá detectar fallos u otros problemas.',
			'settings.privacy.shareOpData.title' => 'Compartir datos de operaciones',
			'settings.privacy.shareOpData.descriptionOn' => 'Compartir algunos datos de operaciones públicamente y con otros usuarios',
			'settings.privacy.shareOpData.descriptionOff' => 'Mantener privados los datos de operaciones',
			'settings.privacy.privacyPolicy' => 'Política de Privacidad',
			'settings.privacy.termsOfService' => 'Términos de Servicio',
			'settings.operatorCall' => 'Indicativo del Operador',
			'settings.sync.title' => 'LoFi Cloud Sync',
			'settings.sync.enable' => 'Habilitar Sincronización',
			'settings.sync.deviceKey' => 'Clave del Dispositivo',
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
			'versionLabel.version' => ({required Object version}) => 'Versión ${version}',
			'versionLabel.versionBuild' => ({required Object version, required Object build}) => 'Versión ${version} - Build ${build}',
			'notices.emptyHistory' => 'Aún no hay avisos',
			_ => null,
		};
	}
}
