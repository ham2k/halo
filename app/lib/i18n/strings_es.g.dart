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
	@override late final _Translations$formChrome$es formChrome = _Translations$formChrome$es._(_root);
	@override late final _Translations$qsoEditForm$es qsoEditForm = _Translations$qsoEditForm$es._(_root);
	@override late final _Translations$qsoList$es qsoList = _Translations$qsoList$es._(_root);
	@override late final _Translations$loggingPanel$es loggingPanel = _Translations$loggingPanel$es._(_root);
	@override late final _Translations$callInfo$es callInfo = _Translations$callInfo$es._(_root);
	@override late final _Translations$settings$es settings = _Translations$settings$es._(_root);
	@override late final _Translations$commands$es commands = _Translations$commands$es._(_root);
	@override late final _Translations$commandDialog$es commandDialog = _Translations$commandDialog$es._(_root);
	@override late final _Translations$expiredBuild$es expiredBuild = _Translations$expiredBuild$es._(_root);
	@override late final _Translations$spotting$es spotting = _Translations$spotting$es._(_root);
	@override late final _Translations$dataFiles$es dataFiles = _Translations$dataFiles$es._(_root);
	@override late final _Translations$updates$es updates = _Translations$updates$es._(_root);
	@override late final _Translations$extensionService$es extensionService = _Translations$extensionService$es._(_root);
	@override late final _Translations$operationLocationScreen$es operationLocationScreen = _Translations$operationLocationScreen$es._(_root);
	@override late final _Translations$versionLabel$es versionLabel = _Translations$versionLabel$es._(_root);
	@override late final _Translations$notices$es notices = _Translations$notices$es._(_root);
	@override late final _Translations$switchAccounts$es switchAccounts = _Translations$switchAccounts$es._(_root);
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
	@override String get clear => 'Limpiar';
	@override String get dismiss => 'Descartar';
	@override String get expand => 'Expandir';
	@override String get collapse => 'Contraer';
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
	@override String get finishingSetup => 'Terminando la configuración — descargando datos de referencia…';
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
	@override String get categoryContest => 'Concursos';
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
	@override String get operationDetails => 'Detalles de la operación';
	@override String get activities => 'Actividades';
	@override String get stationCallsign => 'Indicativo de la estación';
	@override String get notes => 'Notas';
	@override String get deleteOperationTitle => 'Borrar operación';
}

// Path: operation
class _Translations$operation$es extends Translations$operation$en {
	_Translations$operation$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$operation$tabs$es tabs = _Translations$operation$tabs$es._(_root);
	@override String get stationCallsignNone => 'Sin indicativo de estación';
	@override String get titleNone => 'Sin título';
	@override String get deleteOperation => 'Eliminar operación';
	@override String get locationNone => 'Sin definir';
	@override String get generalOperation => 'Operación general';
	@override String titleFor({required Object value}) => 'para ${value}';
	@override String titleAt({required Object value}) => 'en ${value}';
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
	@override String get emptySheet => 'Usa las sugerencias y la búsqueda abajo para añadir una';
	@override String get exports => 'Exportar';
	@override String get options => 'Opciones';
	@override String get optionsTitle => 'Opciones de la operación';
	@override String get share => 'Compartir';
	@override String get archive => 'Archivar';
	@override String get deleteOperation => 'Borrar operación';
	@override String get alreadySelected => 'Ya seleccionada';
	@override String enableExtension({required Object name}) => 'Activar ${name}';
	@override String get enableExtensionHint => 'Esta extensión coincide con tu búsqueda, pero no está activada';
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
	@override String get expandControls => 'Expandir';
	@override String get collapseControls => 'Contraer';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Auto-spot';
	@override String spotSelfAt({required Object freq}) => 'Auto-spot en ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot a ${call} en ${freq}';
	@override String spotTooLate({required Object call}) => 'Demasiado tarde para spotear a ${call}';
	@override String get spotNoFreq => 'Primero define una frecuencia para spotear';
	@override String get spotComment => 'Comentario';
	@override String get bandOrFreqRequired => 'Define una frecuencia o banda antes de registrar';
	@override late final _Translations$loggingControls$info$es info = _Translations$loggingControls$info$es._(_root);
}

// Path: formChrome
class _Translations$formChrome$es extends Translations$formChrome$en {
	_Translations$formChrome$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(sin título)';
	@override String get showMore => 'Mostrar más';
	@override String get showAll => 'Mostrar todo';
	@override String get showFewer => 'Mostrar menos';
	@override String get defaults => 'Predeterminados';
	@override String get search => 'Buscar';
	@override String get clear => 'Limpiar';
	@override String get openPage => 'Abrir página';
	@override String get connected => 'Conectado';
	@override String get notConnected => 'No conectado';
	@override String get manage => 'Administrar';
	@override String get connect => 'Conectar';
	@override String get formTitle => 'Formulario';
	@override String addItem({required Object label}) => 'Añadir ${label}';
	@override String editItem({required Object label}) => 'Editar ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} seleccionados)';
	@override String validationError({required Object error}) => 'Error de validación: ${error}';
	@override String transformationError({required Object error}) => 'Error de transformación: ${error}';
	@override String actionError({required Object error}) => 'Error: ${error}';
	@override String get removeItem => 'Quitar';
	@override String get storageUnavailable => 'Cuentas no disponibles';
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
	@override String get bandOrModeWarning => 'Verifica que tu banda y modo sean correctos';
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
	@override String get stats => 'Estadísticas de la Operación';
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
	@override late final _Translations$settings$syncPanel$es syncPanel = _Translations$settings$syncPanel$es._(_root);
	@override late final _Translations$settings$accounts$es accounts = _Translations$settings$accounts$es._(_root);
	@override late final _Translations$settings$station$es station = _Translations$settings$station$es._(_root);
	@override late final _Translations$settings$offlineData$es offlineData = _Translations$settings$offlineData$es._(_root);
	@override late final _Translations$settings$profiles$es profiles = _Translations$settings$profiles$es._(_root);
	@override late final _Translations$settings$search$es search = _Translations$settings$search$es._(_root);
	@override late final _Translations$settings$developer$es developer = _Translations$settings$developer$es._(_root);
	@override late final _Translations$settings$about$es about = _Translations$settings$about$es._(_root);
	@override late final _Translations$settings$panels$es panels = _Translations$settings$panels$es._(_root);
}

// Path: commands
class _Translations$commands$es extends Translations$commands$en {
	_Translations$commands$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Primero habilita la sincronización en la Configuración.';
	@override String get fullResyncStarted => 'Resincronización completa iniciada — los datos locales se respaldaron primero.';
	@override String noDataFilesMatched({required Object target}) => 'Ningún archivo de datos coincide con «${target}».';
	@override String reloadFailed({required Object error}) => 'Error al recargar: ${error}';
	@override String get reloadingAll => 'Recargando todos los archivos de datos…';
	@override String reloadingTarget({required Object target}) => 'Recargando archivos de datos de ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experimento desconocido «${token}»';
	@override String experimentEnabled({required Object name}) => '${name} habilitado';
	@override String experimentDisabled({required Object name}) => '${name} deshabilitado';
	@override String get sentryTestSent => 'Reporte de error de prueba enviado a Sentry';
	@override String get sentryTestLocalOnly => 'Sentry está deshabilitado en esta compilación — el error de prueba solo se registró localmente';
}

// Path: commandDialog
class _Translations$commandDialog$es extends Translations$commandDialog$en {
	_Translations$commandDialog$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Busca indicativos o escribe un comando';
	@override String noResults({required Object text}) => 'Nada coincide con «${text}»';
	@override String get sectionCommands => 'Comandos';
	@override String get sectionGoTo => 'Ir a';
	@override String get sectionOperations => 'Operaciones';
	@override String get goHome => 'Inicio';
	@override String get goSettings => 'Ajustes';
	@override String get goNewOperation => 'Nueva operación';
	@override String runTyped({required Object text}) => 'Ejecutar «${text}»';
	@override String get sectionSuggestions => 'Prueba';
	@override String get lookingUp => 'Buscando indicativo…';
}

// Path: expiredBuild
class _Translations$expiredBuild$es extends Translations$expiredBuild$en {
	_Translations$expiredBuild$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta versión ha expirado';
	@override String get body => 'Por favor visita ham2k.com para obtener una versión más reciente.';
	@override String get visit => 'Visitar ham2k.com';
	@override String get dismiss => 'Continuar de todos modos';
}

// Path: spotting
class _Translations$spotting$es extends Translations$spotting$en {
	_Translations$spotting$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Aún no hay QSO registrado para spotear.';
	@override String get setFrequencyFirst => 'Primero define una frecuencia.';
	@override String get nothingToSpot => 'Nada que spotear — ninguna extensión ofrece spotting aquí.';
	@override String spottedOn({required Object source}) => 'Spot enviado a ${source}';
	@override String spotFailed({required Object source, required Object message}) => '${source} falló: ${message}';
	@override String get unknownError => 'error desconocido';
	@override String get notSent => 'Spot no enviado.';
}

// Path: dataFiles
class _Translations$dataFiles$es extends Translations$dataFiles$en {
	_Translations$dataFiles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Descargando…';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se importó ${count} registro de ${label}.',
		other: 'Se importaron ${count} registros de ${label}.',
	);
	@override String importedData({required Object label}) => 'Se importaron datos de ${label}.';
	@override String get cleanedUpTitle => 'Datos de extensiones limpiados';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se eliminaron los datos de ${count} archivo de datos de extensiones deshabilitadas.',
		other: 'Se eliminaron los datos de ${count} archivos de datos de extensiones deshabilitadas.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} registros';
}

// Path: updates
class _Translations$updates$es extends Translations$updates$en {
	_Translations$updates$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Actualización disponible';
	@override String newVersionAvailable({required Object version}) => 'Hay una nueva versión (${version}) disponible.';
	@override String get getIt => 'Obtener';
	@override String get ok => 'OK';
	@override String get updateReady => 'Actualización lista';
	@override String get restartToApply => 'Se descargó una actualización. Reinicia para aplicarla.';
	@override String get appliesNextLaunch => 'Se descargó una actualización. Se aplicará la próxima vez que abras la app.';
	@override String get restartNow => 'Reiniciar ahora';
	@override String get reloadToUpdate => 'Hay una versión más reciente de esta página disponible. Recarga para obtenerla.';
	@override String get reloadNow => 'Recargar ahora';
	@override String get checkForUpdates => 'Buscar actualizaciones';
	@override String get checkingForUpdates => 'Buscando actualizaciones…';
	@override String get upToDate => 'Actualizado';
}

// Path: extensionService
class _Translations$extensionService$es extends Translations$extensionService$en {
	_Translations$extensionService$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'El motor de extensiones aún no está listo.';
	@override String testFailed({required Object error}) => 'Prueba fallida: ${error}';
	@override String connectedAs({required Object identity}) => 'Conectado como ${identity}';
	@override String get invalidFieldConfiguration => 'Configuración de campo no válida';
	@override String get invalidValue => 'Valor no válido';
	@override String validationError({required Object error}) => 'Error de validación: ${error}';
	@override String actionFailed({required Object error}) => 'Acción fallida: ${error}';
	@override String get commandFailed => 'El comando no se pudo ejecutar';
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

// Path: switchAccounts
class _Translations$switchAccounts$es extends Translations$switchAccounts$en {
	_Translations$switchAccounts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noCallsignOrEmail => 'Aún sin indicativo ni email';
	@override String get currentAccount => 'Cuenta actual';
	@override String get otherAccounts => 'Otras cuentas';
	@override String get linkToAnother => 'Vincular a otra cuenta';
	@override String get linkWithQr => 'Vincular con un código QR';
	@override String get linkWithQrDescription => 'Escanéalo desde un dispositivo que ya use la cuenta';
	@override String get linkWithEmail => 'Vincular con una dirección de email';
	@override String get linkWithEmailDescription => 'Confirma con un código o un enlace por email';
	@override String get enterEmailPrompt => 'Escribe la dirección de email de la cuenta que quieres usar en este dispositivo.';
	@override String get emailAddress => 'Dirección de email';
	@override String get linkAccount => 'Vincular cuenta';
	@override String get copiedCode => 'Código copiado al portapapeles';
	@override String get copyCode => 'Copiar código';
	@override String codePrompt({required Object email}) => 'Abre la app Ham2K en un dispositivo ya vinculado con ${email} e introduce este código para aprobar la solicitud:';
	@override String get waitingForConfirmation => 'Esperando confirmación…';
	@override String get sendEmailInstead => 'Enviar un email de confirmación en su lugar';
	@override String emailSent({required Object email}) => 'Se envió un email a ${email}. Ábrelo y confirma la solicitud para vincular este dispositivo.';
	@override String get resendEmail => 'Reenviar email';
	@override String get qrPrompt => 'Escanea este código QR desde un dispositivo ya vinculado a la cuenta que quieres — por ejemplo, con Ham2K Portable Logger en tu teléfono.';
	@override String get serverUnreachable => 'No se pudo contactar el servidor de sincronización. Inténtalo más tarde.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} operación',
		other: '${count} operaciones',
	);
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
	@override String get nothingSelected => 'Nada seleccionado';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Guardar ${count} archivo',
		other: 'Guardar ${count} archivos',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Compartir ${count} archivo',
		other: 'Compartir ${count} archivos',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Exportar ${count} archivo',
		other: 'Exportar ${count} archivos',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Descargar ${count} archivo',
		other: 'Descargar ${count} archivos',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Guardar ${count} archivo combinado',
		other: 'Guardar ${count} archivos combinados',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Compartir ${count} archivo combinado',
		other: 'Compartir ${count} archivos combinados',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Exportar ${count} archivo combinado',
		other: 'Exportar ${count} archivos combinados',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Descargar ${count} archivo combinado',
		other: 'Descargar ${count} archivos combinados',
	);
	@override String saveOne({required Object name}) => 'Guardar ${name}';
	@override String shareOne({required Object name}) => 'Compartir ${name}';
	@override String exportOne({required Object name}) => 'Exportar ${name}';
	@override String downloadOne({required Object name}) => 'Descargar ${name}';
	@override String get settingsButton => 'Ajustes de exportación';
	@override String get settingsTitle => 'Ajustes de Exportación';
	@override late final _Translations$operation$export$compactFileNames$es compactFileNames = _Translations$operation$export$compactFileNames$es._(_root);
	@override late final _Translations$operation$export$includePrivateData$es includePrivateData = _Translations$operation$export$includePrivateData$es._(_root);
	@override String saveSuccess({required Object path}) => 'Guardado en ${path}';
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se compartió ${count} archivo',
		other: 'Se compartieron ${count} archivos',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se descargó ${count} archivo',
		other: 'Se descargaron ${count} archivos',
	);
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
	@override String get noticeNewDay => 'Nuevo Día';
	@override String get noticeNewRef => 'Nueva Ref';
	@override String get noticeNewMult => 'Nuevo Mult';
	@override String get noticeNewZone => 'Nueva Zona';
	@override String get noticeInvalidMode => 'Modo Incorrecto';
	@override String get noticeInvalidBand => 'Banda Incorrecta';
	@override String get noticeInvalidCategory => 'No Contactable';
	@override String get noticeWorkedBefore => 'Ya Trabajado';
	@override String get noticeNewPark => 'Parque Nuevo';
	@override String get noticeNewSection => 'Nueva Sección';
	@override String get noticeBonusStation => '¡Estación Bonus!';
	@override String get noticeMissingExchange => 'Sin Intercambio';
	@override String get noticeInvalidExchange => 'Intercambio Inválido';
	@override String get noticeUnknownEvent => 'Evento Desconocido';
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

// Path: settings.syncPanel
class _Translations$settings$syncPanel$es extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuración de sincronización';
	@override String get enableTitle => 'Sincronizar con Ham2K Log Filer';
	@override String get enabledDescription => 'Respalda y sincroniza tu registro entre dispositivos';
	@override String get disabledDescription => 'Desactivado — tu registro se queda solo en este dispositivo';
	@override String get syncing => 'Sincronizando';
	@override String get account => 'Cuenta';
	@override String get refresh => 'Actualizar';
	@override String get switchAccounts => 'Cambiar de cuenta';
	@override String get switchAccountsDescription => 'Vincula este dispositivo a otra cuenta con un código QR o por email';
	@override String get checking => 'Comprobando…';
	@override String get notLinked => 'Aún no vinculado';
	@override String linkedAs({required Object call}) => 'Vinculado como ${call}';
	@override String linkedAsWithEmail({required Object call, required Object email}) => 'Vinculado como ${call} (${email})';
	@override String get replaceDialogTitle => '¿Reemplazar los datos locales?';
	@override String replaceDialogOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} operación',
		other: '${n} operaciones',
	);
	@override String replaceDialogQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Esto respalda y borra ${operations} y ${qsos} de este dispositivo, y luego descarga los datos de la cuenta en su lugar. El respaldo se conserva en la base de datos de este dispositivo.';
	@override String get replace => 'Reemplazar';
	@override String get pendingBannerTitle => 'Nueva cuenta de Ham2K Log Filer detectada';
	@override String get pendingBannerBody => 'Conserva las operaciones y QSOs existentes en este dispositivo y combínalos con la cuenta, o reemplázalos con los datos de la cuenta (en ambos casos queda un respaldo en este dispositivo).';
	@override String get combine => 'Combinar';
	@override String get authIssueTitle => 'Sync no puede conectarse';
	@override String get authIssueText => 'Ham2K Log Filer sigue rechazando este dispositivo. Revisa tu indicativo en la configuración de Sync.';
	@override String get openSettings => 'Abrir configuración de Sync';
}

// Path: settings.accounts
class _Translations$settings$accounts$es extends Translations$settings$accounts$en {
	_Translations$settings$accounts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cuentas y servicios';
	@override String get none => 'No hay extensiones activas con cuentas';
	@override String get notConfigured => 'Sin configurar';
	@override String get connected => 'Conectado';
	@override String connectTo({required Object label}) => 'Conectar con ${label}';
	@override String get openInBrowser => 'Abrir en el navegador';
	@override String loggedInAs({required Object identity}) => 'Sesión iniciada como ${identity}';
	@override String get pressSaveToKeep => 'Pulsa Guardar para mantener esta cuenta conectada.';
	@override String connectedTo({required Object label}) => 'Conectado a ${label}';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
	@override String get connectedAs => 'Conectado como';
	@override String get test => 'Probar';
	@override String saveFailed({required Object error}) => 'Error al guardar: ${error}';
	@override String loginFailed({required Object error}) => 'Error al iniciar sesión: ${error}';
	@override String get lookupFailed => 'Las cuentas no están disponibles ahora mismo; inténtalo de nuevo en un momento';
	@override String get browserLoginTitle => 'Termina de iniciar sesión con tu navegador';
	@override String browserLoginSteps({required Object prefix}) => 'Cuando termines, el navegador intentará abrir un enlace que empieza con "${prefix}". Es muy probable que tu escritorio no tenga nada registrado para abrirlo, así que copia ese enlace — de la barra de direcciones o de la página de error del navegador — y pégalo aquí.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger no pudo abrir tu navegador. Copia el enlace de inicio de sesión y ábrelo tú mismo; luego copia el enlace al que te envíe — empieza con "${prefix}" — y pégalo aquí.';
	@override String get copyLoginLink => 'Copiar enlace de inicio de sesión';
	@override String get pastedLinkLabel => 'Pega el enlace aquí';
	@override String get finishLogin => 'Terminar inicio de sesión';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Ese no es el enlace de inicio de sesión — debe empezar con "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Ese enlace pertenece a otro intento de inicio de sesión. Cierra esta página y conéctate de nuevo.';
	@override String get pastedLinkNoCode => 'Ese enlace no lleva ningún código de inicio de sesión. Termina de iniciar sesión y luego copia el enlace al que te envíe.';
	@override String get pastedLinkMalformed => 'Ese enlace parece estar incompleto. Cópialo por completo y pégalo de nuevo.';
	@override String get noKeyringTitle => 'No se pueden guardar las cuentas';
	@override String get noKeyringText => 'Ham2K Logger no puede acceder a un servicio de llavero en esta computadora, así que no puede guardar ni leer las cuentas — conectar una cuenta fallará hasta que lo resuelvas. Instala y arranca **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloquea el llavero que ya tengas, y reinicia. El registro, las exportaciones y los archivos de datos no se ven afectados; la sincronización queda desactivada mientras tanto.';
	@override String get noKeyringInline => 'Las cuentas no se pueden guardar: no se puede acceder al llavero de esta computadora. Instala y arranca gnome-keyring, KWallet o KeePassXC, o desbloquea el que ya tengas.';
	@override String get noSecureStorageInline => 'Las cuentas no se pueden guardar: no se puede acceder al almacenamiento seguro de esta computadora.';
}

// Path: settings.station
class _Translations$settings$station$es extends Translations$settings$station$en {
	_Translations$settings$station$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración de Estación';
	@override String get none => 'No hay equipo configurado';
	@override String get add => 'Agregar equipo';
	@override String get addTitle => 'Agregar equipo';
	@override String get searching => 'Buscando radios en tu red…';
	@override String get found => 'Encontradas';
	@override String get addManually => 'Agregar por dirección';
	@override String discoveryUnavailable({required Object error}) => 'No se puede buscar radios: ${error}';
	@override String get edit => 'Editar equipo';
	@override String get name => 'Nombre';
	@override String get nameDescription => 'Cómo lo llamas — «Radio Izquierda». Opcional.';
	@override String get host => 'Dirección';
	@override String get hostDescription => 'El nombre de host o la dirección IP de la radio en tu red.';
	@override String get port => 'Puerto';
	@override String get hostRequired => 'Se requiere una dirección';
	@override String get portInvalid => 'El puerto debe estar entre 1 y 65535';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
	@override String get remove => 'Eliminar';
	@override String removeTitle({required Object name}) => '¿Eliminar ${name}?';
	@override String get removeMessage => 'Esto solo lo elimina de la aplicación. Nada cambia en el equipo.';
	@override String unknownType({required Object typeKey}) => 'Tipo de equipo no reconocido «${typeKey}»';
	@override String get unverified => 'No probado con este hardware';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Usar como VFO principal';
	@override String get serialPort => 'Puerto serie';
	@override String get serialPortDescription => 'El puerto donde aparece la interfaz CAT de la radio.';
	@override String get serialPortNone => 'No se encontraron puertos serie';
	@override String get serialPortRequired => 'Elige un puerto serie';
	@override String get baudRate => 'Velocidad (baudios)';
	@override String get baudRateDescription => 'Debe coincidir con el menú CAT de la radio — si no, responde con datos ilegibles y sin error.';
	@override String get civAddress => 'Dirección CI-V de la radio';
	@override String get civAddressDescription => 'Hexadecimal, como aparece en el menú CI-V de la radio. El IC-705 viene con A4.';
	@override String get civAddressInvalid => 'Una dirección CI-V son dos dígitos hexadecimales, de 01 a FF';
	@override String get radioUser => 'Usuario de la radio';
	@override String get radioPass => 'Contraseña de la radio';
	@override String get radioLoginDescription => 'El inicio de sesión Red → Remoto de la radio, no la contraseña del WiFi.';
	@override String get radioUserRequired => 'Se requiere el usuario de control remoto de la radio';
	@override late final _Translations$settings$station$types$es types = _Translations$settings$station$types$es._(_root);
	@override String get troubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get ft891Troubleshooting => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS debe estar en OFF en la radio** (FT-891 menú **05-08**). Si está activado, la radio espera una línea de control que la app nunca activa a propósito: en un Digirig, SignaLink o la mayoría de cables caseros esa misma línea es el PTT, así que activarla pondría tu equipo en transmisión.\n- **La velocidad debe coincidir** con el CAT RATE de la radio (menú **05-06**). Si no coincide, responde con datos ilegibles, o con nada, y nunca con un error.\n- **Otra aplicación puede tener el puerto** — WSJT-X, fldigi y rigctld lo mantienen abierto.';
	@override String get statusConnected => 'Conectado';
	@override String get currentConfiguration => 'Configuración actual';
	@override String get transceiverForMainVfo => 'Transceptor para el VFO principal';
	@override String get equipmentInventory => 'Inventario de equipos';
	@override String get noTransceiver => 'Ninguno';
	@override String get ic705TroubleshootingTitle => 'Si la radio nunca responde';
	@override String get ic705Troubleshooting => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview o RS-BA1 conectado a la misma radio ocupa esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio** — que la WLAN esté encendida, que esté en la misma red y que su función de control remoto (Network) esté activada.\n- **Reinicia la WLAN de la radio** si sigue atascada. Eso libera de forma fiable una sesión que la radio realmente esté reteniendo.\n\nUna **contraseña incorrecta se rechaza explícitamente**, no con silencio — así que si llegaste aquí en lugar de ver un mensaje de "rechazada", la contraseña no es el problema.';
	@override String get statusStale => 'Sin respuesta';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$es extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Datos sin conexión';
	@override String get noFiles => 'No hay archivos de datos';
	@override String get noFilesDescription => 'Habilita extensiones de actividades o búsquedas para descargar aquí sus datos sin conexión.';
	@override String get refresh => 'Actualizar';
	@override String get refreshing => 'Actualizando…';
	@override String refreshFailed({required Object name, required Object error}) => 'No se pudo actualizar ${name}: ${error}';
	@override String get neverDownloaded => 'Nunca descargado';
	@override String get updatedJustNow => 'Actualizado hace un momento';
	@override String updatedDaysAgo({required Object days}) => 'Actualizado hace ${days}d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Actualizado hace ${days}d ${hours}h';
	@override String updatedHoursAgo({required Object hours}) => 'Actualizado hace ${hours}h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Actualizado hace ${hours}h ${minutes}m';
	@override String updatedMinutesAgo({required Object minutes}) => 'Actualizado hace ${minutes}m';
}

// Path: settings.profiles
class _Translations$settings$profiles$es extends Translations$settings$profiles$en {
	_Translations$settings$profiles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Sin definir';
}

// Path: settings.search
class _Translations$settings$search$es extends Translations$settings$search$en {
	_Translations$settings$search$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Borrar';
	@override String get hint => 'Buscar en la configuración';
}

// Path: settings.developer
class _Translations$settings$developer$es extends Translations$settings$developer$en {
	_Translations$settings$developer$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get options => 'Opciones de desarrollador';
	@override String get developerModeDescription => 'Habilita avisos de desarrollador, registros de depuración y herramientas.';
	@override String get experiments => 'Experimentos';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} habilitado',
		other: '${count} habilitados',
	);
	@override String get patchTrack => 'Canal de parches';
	@override String get patchTrackDescription => 'Qué canal de parches over-the-air sigue este dispositivo. Los canales más aventureros reciben correcciones antes, menos probadas. Los parches se aplican en el próximo reinicio.';
	@override String get trackStable => 'Estable';
	@override String get trackUnstable => 'Inestable';
	@override String get trackBleeding => 'Vanguardia';
	@override String checkingTrack({required Object track}) => 'Buscando un parche en «${track}»…';
	@override String get patchDownloaded => 'Parche descargado — reinicia la app para aplicarlo.';
	@override String noNewPatch({required Object track}) => 'No hay parches nuevos en «${track}».';
	@override String get noPatchInstalled => 'No hay parche instalado — ejecutando el binario de la versión.';
	@override String runningPatch({required Object patch}) => 'Ejecutando el parche #${patch}.';
	@override String get systemInformation => 'Información del sistema';
	@override String get activeExtensions => 'Extensiones activas';
	@override String get appVersion => 'Versión de la app';
	@override String get loading => '(cargando…)';
	@override String get runtimeNotAvailable => 'El motor de extensiones no está disponible.';
	@override String get panelLoadFailed => 'No se pudo cargar este panel de configuración.';
	@override String get categoryCore => 'Núcleo y motor';
}

// Path: settings.about
class _Translations$settings$about$es extends Translations$settings$about$en {
	_Translations$settings$about$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Avisos y mensajes';
	@override String get noticesDescription => 'Anuncios y mensajes de estado';
	@override String get releaseNotes => 'Notas de la versión';
	@override String get copiedVersion => 'Detalles de versión copiados al portapapeles';
}

// Path: settings.panels
class _Translations$settings$panels$es extends Translations$settings$panels$en {
	_Translations$settings$panels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get commonPreferences => 'Preferencias comunes';
	@override String get commonPreferencesDescription => 'Apariencia, idioma y ajustes cotidianos';
	@override String get allSettings => 'Todos los ajustes';
	@override String get allSettingsDescription => 'Todos los ajustes disponibles en un solo lugar';
	@override String get syncDescription => 'Respalda y sincroniza tus registros entre dispositivos';
	@override String get accountsDescription => 'Inicia sesión en servicios y búsquedas en línea';
	@override String get extensions => 'Funciones y extensiones';
	@override String get extensionsDescription => 'Activa o desactiva funciones opcionales';
	@override String get profilesDescription => 'Indicativo del operador y perfil de la estación';
	@override String get stationProfiles => 'Perfiles de estación';
	@override String get dataFiles => 'Archivos de datos';
	@override String get dataFilesDescription => 'Administra las fuentes de datos en caché';
	@override String get developerSettings => 'Ajustes de desarrollador';
	@override String get developerSettingsDescription => 'Herramientas de depuración y desarrollo';
	@override String get about => 'Acerca de';
	@override String get aboutDescription => 'Versión, créditos e información legal';
	@override String get unavailableTitle => 'Algunos ajustes no están disponibles';
	@override String get unavailableText => 'El motor de extensiones no pudo iniciarse, así que faltan los ajustes aportados por extensiones.';
	@override String get station => 'Configuración de Estación';
	@override String get stationDescription => 'Radios y otros equipos';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$es extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usar nombres de archivo compactos';
	@override String get descriptionOn => 'Nombres cortos pensados para los cargadores, como N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nombres legibles, como 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$es extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Incluir información privada';
	@override String get descriptionOn => 'Se incluyen nombres, ciudades, cuadrículas y notas';
	@override String get descriptionOff => 'Se omiten nombres, ciudades, cuadrículas y notas';
	@override String get note => 'La Exportación ADIF Completa siempre incluye todo';
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

// Path: settings.station.types
class _Translations$settings$station$types$es extends Translations$settings$station$types$en {
	_Translations$settings$station$types$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get flexRadioTcp => 'FlexRadio (SmartSDR) — Red';
	@override String get ft891Serial => 'Yaesu FT-891 — USB serie';
	@override String get icomCivSerial => 'Icom (CI-V) — USB serie';
	@override String get ic705Network => 'Icom IC-705 — WiFi';
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
			'common.clear' => 'Limpiar',
			'common.dismiss' => 'Descartar',
			'common.expand' => 'Expandir',
			'common.collapse' => 'Contraer',
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
			'onboarding.finishingSetup' => 'Terminando la configuración — descargando datos de referencia…',
			'startScreen.credits' => 'por KI2D y amigos',
			'extensionsPanel.categoryActivity' => 'Actividades',
			'extensionsPanel.categoryContest' => 'Concursos',
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
			'dialogs.operationDetails' => 'Detalles de la operación',
			'dialogs.activities' => 'Actividades',
			'dialogs.stationCallsign' => 'Indicativo de la estación',
			'dialogs.notes' => 'Notas',
			'dialogs.deleteOperationTitle' => 'Borrar operación',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.stationCallsignNone' => 'Sin indicativo de estación',
			'operation.titleNone' => 'Sin título',
			'operation.deleteOperation' => 'Eliminar operación',
			'operation.locationNone' => 'Sin definir',
			'operation.generalOperation' => 'Operación general',
			'operation.titleFor' => ({required Object value}) => 'para ${value}',
			'operation.titleAt' => ({required Object value}) => 'en ${value}',
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
			'operation.export.nothingSelected' => 'Nada seleccionado',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Guardar ${count} archivo', other: 'Guardar ${count} archivos', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Compartir ${count} archivo', other: 'Compartir ${count} archivos', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Exportar ${count} archivo', other: 'Exportar ${count} archivos', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Descargar ${count} archivo', other: 'Descargar ${count} archivos', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Guardar ${count} archivo combinado', other: 'Guardar ${count} archivos combinados', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Compartir ${count} archivo combinado', other: 'Compartir ${count} archivos combinados', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Exportar ${count} archivo combinado', other: 'Exportar ${count} archivos combinados', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Descargar ${count} archivo combinado', other: 'Descargar ${count} archivos combinados', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Guardar ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Compartir ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportar ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Descargar ${name}',
			'operation.export.settingsButton' => 'Ajustes de exportación',
			'operation.export.settingsTitle' => 'Ajustes de Exportación',
			'operation.export.compactFileNames.title' => 'Usar nombres de archivo compactos',
			'operation.export.compactFileNames.descriptionOn' => 'Nombres cortos pensados para los cargadores, como N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nombres legibles, como 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Incluir información privada',
			'operation.export.includePrivateData.descriptionOn' => 'Se incluyen nombres, ciudades, cuadrículas y notas',
			'operation.export.includePrivateData.descriptionOff' => 'Se omiten nombres, ciudades, cuadrículas y notas',
			'operation.export.includePrivateData.note' => 'La Exportación ADIF Completa siempre incluye todo',
			'operation.export.saveSuccess' => ({required Object path}) => 'Guardado en ${path}',
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se compartió ${count} archivo', other: 'Se compartieron ${count} archivos', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se descargó ${count} archivo', other: 'Se descargaron ${count} archivos', ), 
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
			'activitiesView.emptySheet' => 'Usa las sugerencias y la búsqueda abajo para añadir una',
			'activitiesView.exports' => 'Exportar',
			'activitiesView.options' => 'Opciones',
			'activitiesView.optionsTitle' => 'Opciones de la operación',
			'activitiesView.share' => 'Compartir',
			'activitiesView.archive' => 'Archivar',
			'activitiesView.deleteOperation' => 'Borrar operación',
			'activitiesView.alreadySelected' => 'Ya seleccionada',
			'activitiesView.enableExtension' => ({required Object name}) => 'Activar ${name}',
			'activitiesView.enableExtensionHint' => 'Esta extensión coincide con tu búsqueda, pero no está activada',
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
			'loggingControls.expandControls' => 'Expandir',
			'loggingControls.collapseControls' => 'Contraer',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Auto-spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Auto-spot en ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot a ${call} en ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Demasiado tarde para spotear a ${call}',
			'loggingControls.spotNoFreq' => 'Primero define una frecuencia para spotear',
			'loggingControls.spotComment' => 'Comentario',
			'loggingControls.bandOrFreqRequired' => 'Define una frecuencia o banda antes de registrar',
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
			'loggingControls.info.noticeNewDay' => 'Nuevo Día',
			'loggingControls.info.noticeNewRef' => 'Nueva Ref',
			'loggingControls.info.noticeNewMult' => 'Nuevo Mult',
			'loggingControls.info.noticeNewZone' => 'Nueva Zona',
			'loggingControls.info.noticeInvalidMode' => 'Modo Incorrecto',
			'loggingControls.info.noticeInvalidBand' => 'Banda Incorrecta',
			'loggingControls.info.noticeInvalidCategory' => 'No Contactable',
			'loggingControls.info.noticeWorkedBefore' => 'Ya Trabajado',
			'loggingControls.info.noticeNewPark' => 'Parque Nuevo',
			'loggingControls.info.noticeNewSection' => 'Nueva Sección',
			'loggingControls.info.noticeBonusStation' => '¡Estación Bonus!',
			'loggingControls.info.noticeMissingExchange' => 'Sin Intercambio',
			'loggingControls.info.noticeInvalidExchange' => 'Intercambio Inválido',
			'loggingControls.info.noticeUnknownEvent' => 'Evento Desconocido',
			'formChrome.untitled' => '(sin título)',
			'formChrome.showMore' => 'Mostrar más',
			'formChrome.showAll' => 'Mostrar todo',
			'formChrome.showFewer' => 'Mostrar menos',
			'formChrome.defaults' => 'Predeterminados',
			'formChrome.search' => 'Buscar',
			'formChrome.clear' => 'Limpiar',
			'formChrome.openPage' => 'Abrir página',
			'formChrome.connected' => 'Conectado',
			'formChrome.notConnected' => 'No conectado',
			'formChrome.manage' => 'Administrar',
			'formChrome.connect' => 'Conectar',
			'formChrome.formTitle' => 'Formulario',
			'formChrome.addItem' => ({required Object label}) => 'Añadir ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Editar ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} seleccionados)',
			'formChrome.validationError' => ({required Object error}) => 'Error de validación: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Error de transformación: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Error: ${error}',
			'formChrome.removeItem' => 'Quitar',
			'formChrome.storageUnavailable' => 'Cuentas no disponibles',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.theirName' => 'Nombre',
			'qsoEditForm.theirGrid' => 'Locador',
			'qsoEditForm.theirState' => 'Estado/Provincia',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoList.empty' => 'Aún no hay QSOs — ¡haz un contacto!',
			'qsoList.bandOrModeWarning' => 'Verifica que tu banda y modo sean correctos',
			'qsoList.editEventTime' => 'Editar hora',
			'qsoList.today' => 'Hoy',
			'qsoList.yesterday' => 'Ayer',
			'qsoList.tomorrow' => 'Mañana',
			'qsoList.eventStarted' => 'Operación iniciada',
			'qsoList.eventBreak' => 'Descanso',
			'qsoList.eventEnded' => 'Operación finalizada',
			'loggingPanel.stats' => 'Estadísticas de la Operación',
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
			'settings.syncPanel.configuration' => 'Configuración de sincronización',
			'settings.syncPanel.enableTitle' => 'Sincronizar con Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Respalda y sincroniza tu registro entre dispositivos',
			'settings.syncPanel.disabledDescription' => 'Desactivado — tu registro se queda solo en este dispositivo',
			'settings.syncPanel.syncing' => 'Sincronizando',
			'settings.syncPanel.account' => 'Cuenta',
			'settings.syncPanel.refresh' => 'Actualizar',
			'settings.syncPanel.switchAccounts' => 'Cambiar de cuenta',
			'settings.syncPanel.switchAccountsDescription' => 'Vincula este dispositivo a otra cuenta con un código QR o por email',
			'settings.syncPanel.checking' => 'Comprobando…',
			'settings.syncPanel.notLinked' => 'Aún no vinculado',
			'settings.syncPanel.linkedAs' => ({required Object call}) => 'Vinculado como ${call}',
			'settings.syncPanel.linkedAsWithEmail' => ({required Object call, required Object email}) => 'Vinculado como ${call} (${email})',
			'settings.syncPanel.replaceDialogTitle' => '¿Reemplazar los datos locales?',
			'settings.syncPanel.replaceDialogOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} operación', other: '${n} operaciones', ), 
			'settings.syncPanel.replaceDialogQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Esto respalda y borra ${operations} y ${qsos} de este dispositivo, y luego descarga los datos de la cuenta en su lugar. El respaldo se conserva en la base de datos de este dispositivo.',
			'settings.syncPanel.replace' => 'Reemplazar',
			'settings.syncPanel.pendingBannerTitle' => 'Nueva cuenta de Ham2K Log Filer detectada',
			'settings.syncPanel.pendingBannerBody' => 'Conserva las operaciones y QSOs existentes en este dispositivo y combínalos con la cuenta, o reemplázalos con los datos de la cuenta (en ambos casos queda un respaldo en este dispositivo).',
			'settings.syncPanel.combine' => 'Combinar',
			'settings.syncPanel.authIssueTitle' => 'Sync no puede conectarse',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer sigue rechazando este dispositivo. Revisa tu indicativo en la configuración de Sync.',
			'settings.syncPanel.openSettings' => 'Abrir configuración de Sync',
			'settings.accounts.title' => 'Cuentas y servicios',
			'settings.accounts.none' => 'No hay extensiones activas con cuentas',
			'settings.accounts.notConfigured' => 'Sin configurar',
			'settings.accounts.connected' => 'Conectado',
			'settings.accounts.connectTo' => ({required Object label}) => 'Conectar con ${label}',
			'settings.accounts.openInBrowser' => 'Abrir en el navegador',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Sesión iniciada como ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Pulsa Guardar para mantener esta cuenta conectada.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Conectado a ${label}',
			'settings.accounts.connect' => 'Conectar',
			'settings.accounts.disconnect' => 'Desconectar',
			'settings.accounts.connectedAs' => 'Conectado como',
			'settings.accounts.test' => 'Probar',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Error al guardar: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Error al iniciar sesión: ${error}',
			'settings.accounts.lookupFailed' => 'Las cuentas no están disponibles ahora mismo; inténtalo de nuevo en un momento',
			'settings.accounts.browserLoginTitle' => 'Termina de iniciar sesión con tu navegador',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Cuando termines, el navegador intentará abrir un enlace que empieza con "${prefix}". Es muy probable que tu escritorio no tenga nada registrado para abrirlo, así que copia ese enlace — de la barra de direcciones o de la página de error del navegador — y pégalo aquí.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger no pudo abrir tu navegador. Copia el enlace de inicio de sesión y ábrelo tú mismo; luego copia el enlace al que te envíe — empieza con "${prefix}" — y pégalo aquí.',
			'settings.accounts.copyLoginLink' => 'Copiar enlace de inicio de sesión',
			'settings.accounts.pastedLinkLabel' => 'Pega el enlace aquí',
			'settings.accounts.finishLogin' => 'Terminar inicio de sesión',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Ese no es el enlace de inicio de sesión — debe empezar con "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Ese enlace pertenece a otro intento de inicio de sesión. Cierra esta página y conéctate de nuevo.',
			'settings.accounts.pastedLinkNoCode' => 'Ese enlace no lleva ningún código de inicio de sesión. Termina de iniciar sesión y luego copia el enlace al que te envíe.',
			'settings.accounts.pastedLinkMalformed' => 'Ese enlace parece estar incompleto. Cópialo por completo y pégalo de nuevo.',
			'settings.accounts.noKeyringTitle' => 'No se pueden guardar las cuentas',
			'settings.accounts.noKeyringText' => 'Ham2K Logger no puede acceder a un servicio de llavero en esta computadora, así que no puede guardar ni leer las cuentas — conectar una cuenta fallará hasta que lo resuelvas. Instala y arranca **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloquea el llavero que ya tengas, y reinicia. El registro, las exportaciones y los archivos de datos no se ven afectados; la sincronización queda desactivada mientras tanto.',
			'settings.accounts.noKeyringInline' => 'Las cuentas no se pueden guardar: no se puede acceder al llavero de esta computadora. Instala y arranca gnome-keyring, KWallet o KeePassXC, o desbloquea el que ya tengas.',
			'settings.accounts.noSecureStorageInline' => 'Las cuentas no se pueden guardar: no se puede acceder al almacenamiento seguro de esta computadora.',
			'settings.station.title' => 'Configuración de Estación',
			'settings.station.none' => 'No hay equipo configurado',
			'settings.station.add' => 'Agregar equipo',
			'settings.station.addTitle' => 'Agregar equipo',
			'settings.station.searching' => 'Buscando radios en tu red…',
			'settings.station.found' => 'Encontradas',
			'settings.station.addManually' => 'Agregar por dirección',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'No se puede buscar radios: ${error}',
			'settings.station.edit' => 'Editar equipo',
			'settings.station.name' => 'Nombre',
			'settings.station.nameDescription' => 'Cómo lo llamas — «Radio Izquierda». Opcional.',
			'settings.station.host' => 'Dirección',
			'settings.station.hostDescription' => 'El nombre de host o la dirección IP de la radio en tu red.',
			'settings.station.port' => 'Puerto',
			'settings.station.hostRequired' => 'Se requiere una dirección',
			'settings.station.portInvalid' => 'El puerto debe estar entre 1 y 65535',
			'settings.station.connect' => 'Conectar',
			'settings.station.disconnect' => 'Desconectar',
			'settings.station.remove' => 'Eliminar',
			'settings.station.removeTitle' => ({required Object name}) => '¿Eliminar ${name}?',
			'settings.station.removeMessage' => 'Esto solo lo elimina de la aplicación. Nada cambia en el equipo.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipo de equipo no reconocido «${typeKey}»',
			'settings.station.unverified' => 'No probado con este hardware',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Usar como VFO principal',
			'settings.station.serialPort' => 'Puerto serie',
			'settings.station.serialPortDescription' => 'El puerto donde aparece la interfaz CAT de la radio.',
			'settings.station.serialPortNone' => 'No se encontraron puertos serie',
			'settings.station.serialPortRequired' => 'Elige un puerto serie',
			'settings.station.baudRate' => 'Velocidad (baudios)',
			'settings.station.baudRateDescription' => 'Debe coincidir con el menú CAT de la radio — si no, responde con datos ilegibles y sin error.',
			'settings.station.civAddress' => 'Dirección CI-V de la radio',
			'settings.station.civAddressDescription' => 'Hexadecimal, como aparece en el menú CI-V de la radio. El IC-705 viene con A4.',
			'settings.station.civAddressInvalid' => 'Una dirección CI-V son dos dígitos hexadecimales, de 01 a FF',
			'settings.station.radioUser' => 'Usuario de la radio',
			'settings.station.radioPass' => 'Contraseña de la radio',
			'settings.station.radioLoginDescription' => 'El inicio de sesión Red → Remoto de la radio, no la contraseña del WiFi.',
			'settings.station.radioUserRequired' => 'Se requiere el usuario de control remoto de la radio',
			'settings.station.types.flexRadioTcp' => 'FlexRadio (SmartSDR) — Red',
			'settings.station.types.ft891Serial' => 'Yaesu FT-891 — USB serie',
			'settings.station.types.icomCivSerial' => 'Icom (CI-V) — USB serie',
			'settings.station.types.ic705Network' => 'Icom IC-705 — WiFi',
			'settings.station.troubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.ft891Troubleshooting' => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS debe estar en OFF en la radio** (FT-891 menú **05-08**). Si está activado, la radio espera una línea de control que la app nunca activa a propósito: en un Digirig, SignaLink o la mayoría de cables caseros esa misma línea es el PTT, así que activarla pondría tu equipo en transmisión.\n- **La velocidad debe coincidir** con el CAT RATE de la radio (menú **05-06**). Si no coincide, responde con datos ilegibles, o con nada, y nunca con un error.\n- **Otra aplicación puede tener el puerto** — WSJT-X, fldigi y rigctld lo mantienen abierto.',
			'settings.station.statusConnected' => 'Conectado',
			'settings.station.currentConfiguration' => 'Configuración actual',
			'settings.station.transceiverForMainVfo' => 'Transceptor para el VFO principal',
			'settings.station.equipmentInventory' => 'Inventario de equipos',
			'settings.station.noTransceiver' => 'Ninguno',
			'settings.station.ic705TroubleshootingTitle' => 'Si la radio nunca responde',
			'settings.station.ic705Troubleshooting' => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview o RS-BA1 conectado a la misma radio ocupa esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio** — que la WLAN esté encendida, que esté en la misma red y que su función de control remoto (Network) esté activada.\n- **Reinicia la WLAN de la radio** si sigue atascada. Eso libera de forma fiable una sesión que la radio realmente esté reteniendo.\n\nUna **contraseña incorrecta se rechaza explícitamente**, no con silencio — así que si llegaste aquí en lugar de ver un mensaje de "rechazada", la contraseña no es el problema.',
			'settings.station.statusStale' => 'Sin respuesta',
			'settings.offlineData.title' => 'Datos sin conexión',
			'settings.offlineData.noFiles' => 'No hay archivos de datos',
			'settings.offlineData.noFilesDescription' => 'Habilita extensiones de actividades o búsquedas para descargar aquí sus datos sin conexión.',
			'settings.offlineData.refresh' => 'Actualizar',
			'settings.offlineData.refreshing' => 'Actualizando…',
			'settings.offlineData.refreshFailed' => ({required Object name, required Object error}) => 'No se pudo actualizar ${name}: ${error}',
			'settings.offlineData.neverDownloaded' => 'Nunca descargado',
			'settings.offlineData.updatedJustNow' => 'Actualizado hace un momento',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Actualizado hace ${days}d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Actualizado hace ${days}d ${hours}h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Actualizado hace ${hours}h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Actualizado hace ${hours}h ${minutes}m',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Actualizado hace ${minutes}m',
			'settings.profiles.notSet' => 'Sin definir',
			'settings.search.clear' => 'Borrar',
			'settings.search.hint' => 'Buscar en la configuración',
			'settings.developer.options' => 'Opciones de desarrollador',
			'settings.developer.developerModeDescription' => 'Habilita avisos de desarrollador, registros de depuración y herramientas.',
			'settings.developer.experiments' => 'Experimentos',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} habilitado', other: '${count} habilitados', ), 
			'settings.developer.patchTrack' => 'Canal de parches',
			'settings.developer.patchTrackDescription' => 'Qué canal de parches over-the-air sigue este dispositivo. Los canales más aventureros reciben correcciones antes, menos probadas. Los parches se aplican en el próximo reinicio.',
			'settings.developer.trackStable' => 'Estable',
			'settings.developer.trackUnstable' => 'Inestable',
			'settings.developer.trackBleeding' => 'Vanguardia',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Buscando un parche en «${track}»…',
			'settings.developer.patchDownloaded' => 'Parche descargado — reinicia la app para aplicarlo.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'No hay parches nuevos en «${track}».',
			'settings.developer.noPatchInstalled' => 'No hay parche instalado — ejecutando el binario de la versión.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Ejecutando el parche #${patch}.',
			'settings.developer.systemInformation' => 'Información del sistema',
			'settings.developer.activeExtensions' => 'Extensiones activas',
			'settings.developer.appVersion' => 'Versión de la app',
			'settings.developer.loading' => '(cargando…)',
			'settings.developer.runtimeNotAvailable' => 'El motor de extensiones no está disponible.',
			'settings.developer.panelLoadFailed' => 'No se pudo cargar este panel de configuración.',
			'settings.developer.categoryCore' => 'Núcleo y motor',
			'settings.about.notices' => 'Avisos y mensajes',
			'settings.about.noticesDescription' => 'Anuncios y mensajes de estado',
			'settings.about.releaseNotes' => 'Notas de la versión',
			'settings.about.copiedVersion' => 'Detalles de versión copiados al portapapeles',
			'settings.panels.commonPreferences' => 'Preferencias comunes',
			'settings.panels.commonPreferencesDescription' => 'Apariencia, idioma y ajustes cotidianos',
			'settings.panels.allSettings' => 'Todos los ajustes',
			'settings.panels.allSettingsDescription' => 'Todos los ajustes disponibles en un solo lugar',
			'settings.panels.syncDescription' => 'Respalda y sincroniza tus registros entre dispositivos',
			'settings.panels.accountsDescription' => 'Inicia sesión en servicios y búsquedas en línea',
			'settings.panels.extensions' => 'Funciones y extensiones',
			'settings.panels.extensionsDescription' => 'Activa o desactiva funciones opcionales',
			'settings.panels.profilesDescription' => 'Indicativo del operador y perfil de la estación',
			'settings.panels.stationProfiles' => 'Perfiles de estación',
			'settings.panels.dataFiles' => 'Archivos de datos',
			'settings.panels.dataFilesDescription' => 'Administra las fuentes de datos en caché',
			'settings.panels.developerSettings' => 'Ajustes de desarrollador',
			'settings.panels.developerSettingsDescription' => 'Herramientas de depuración y desarrollo',
			'settings.panels.about' => 'Acerca de',
			'settings.panels.aboutDescription' => 'Versión, créditos e información legal',
			'settings.panels.unavailableTitle' => 'Algunos ajustes no están disponibles',
			'settings.panels.unavailableText' => 'El motor de extensiones no pudo iniciarse, así que faltan los ajustes aportados por extensiones.',
			_ => null,
		} ?? switch (path) {
			'settings.panels.station' => 'Configuración de Estación',
			'settings.panels.stationDescription' => 'Radios y otros equipos',
			'commands.enableSyncFirst' => 'Primero habilita la sincronización en la Configuración.',
			'commands.fullResyncStarted' => 'Resincronización completa iniciada — los datos locales se respaldaron primero.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Ningún archivo de datos coincide con «${target}».',
			'commands.reloadFailed' => ({required Object error}) => 'Error al recargar: ${error}',
			'commands.reloadingAll' => 'Recargando todos los archivos de datos…',
			'commands.reloadingTarget' => ({required Object target}) => 'Recargando archivos de datos de ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experimento desconocido «${token}»',
			'commands.experimentEnabled' => ({required Object name}) => '${name} habilitado',
			'commands.experimentDisabled' => ({required Object name}) => '${name} deshabilitado',
			'commands.sentryTestSent' => 'Reporte de error de prueba enviado a Sentry',
			'commands.sentryTestLocalOnly' => 'Sentry está deshabilitado en esta compilación — el error de prueba solo se registró localmente',
			'commandDialog.hint' => 'Busca indicativos o escribe un comando',
			'commandDialog.noResults' => ({required Object text}) => 'Nada coincide con «${text}»',
			'commandDialog.sectionCommands' => 'Comandos',
			'commandDialog.sectionGoTo' => 'Ir a',
			'commandDialog.sectionOperations' => 'Operaciones',
			'commandDialog.goHome' => 'Inicio',
			'commandDialog.goSettings' => 'Ajustes',
			'commandDialog.goNewOperation' => 'Nueva operación',
			'commandDialog.runTyped' => ({required Object text}) => 'Ejecutar «${text}»',
			'commandDialog.sectionSuggestions' => 'Prueba',
			'commandDialog.lookingUp' => 'Buscando indicativo…',
			'expiredBuild.title' => 'Esta versión ha expirado',
			'expiredBuild.body' => 'Por favor visita ham2k.com para obtener una versión más reciente.',
			'expiredBuild.visit' => 'Visitar ham2k.com',
			'expiredBuild.dismiss' => 'Continuar de todos modos',
			'spotting.noQsoYet' => 'Aún no hay QSO registrado para spotear.',
			'spotting.setFrequencyFirst' => 'Primero define una frecuencia.',
			'spotting.nothingToSpot' => 'Nada que spotear — ninguna extensión ofrece spotting aquí.',
			'spotting.spottedOn' => ({required Object source}) => 'Spot enviado a ${source}',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} falló: ${message}',
			'spotting.unknownError' => 'error desconocido',
			'spotting.notSent' => 'Spot no enviado.',
			'dataFiles.downloading' => 'Descargando…',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se importó ${count} registro de ${label}.', other: 'Se importaron ${count} registros de ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Se importaron datos de ${label}.',
			'dataFiles.cleanedUpTitle' => 'Datos de extensiones limpiados',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se eliminaron los datos de ${count} archivo de datos de extensiones deshabilitadas.', other: 'Se eliminaron los datos de ${count} archivos de datos de extensiones deshabilitadas.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} registros',
			'updates.updateAvailable' => 'Actualización disponible',
			'updates.newVersionAvailable' => ({required Object version}) => 'Hay una nueva versión (${version}) disponible.',
			'updates.getIt' => 'Obtener',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Actualización lista',
			'updates.restartToApply' => 'Se descargó una actualización. Reinicia para aplicarla.',
			'updates.appliesNextLaunch' => 'Se descargó una actualización. Se aplicará la próxima vez que abras la app.',
			'updates.restartNow' => 'Reiniciar ahora',
			'updates.reloadToUpdate' => 'Hay una versión más reciente de esta página disponible. Recarga para obtenerla.',
			'updates.reloadNow' => 'Recargar ahora',
			'updates.checkForUpdates' => 'Buscar actualizaciones',
			'updates.checkingForUpdates' => 'Buscando actualizaciones…',
			'updates.upToDate' => 'Actualizado',
			'extensionService.runtimeNotReady' => 'El motor de extensiones aún no está listo.',
			'extensionService.testFailed' => ({required Object error}) => 'Prueba fallida: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Conectado como ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuración de campo no válida',
			'extensionService.invalidValue' => 'Valor no válido',
			'extensionService.validationError' => ({required Object error}) => 'Error de validación: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Acción fallida: ${error}',
			'extensionService.commandFailed' => 'El comando no se pudo ejecutar',
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
			'switchAccounts.noCallsignOrEmail' => 'Aún sin indicativo ni email',
			'switchAccounts.currentAccount' => 'Cuenta actual',
			'switchAccounts.otherAccounts' => 'Otras cuentas',
			'switchAccounts.linkToAnother' => 'Vincular a otra cuenta',
			'switchAccounts.linkWithQr' => 'Vincular con un código QR',
			'switchAccounts.linkWithQrDescription' => 'Escanéalo desde un dispositivo que ya use la cuenta',
			'switchAccounts.linkWithEmail' => 'Vincular con una dirección de email',
			'switchAccounts.linkWithEmailDescription' => 'Confirma con un código o un enlace por email',
			'switchAccounts.enterEmailPrompt' => 'Escribe la dirección de email de la cuenta que quieres usar en este dispositivo.',
			'switchAccounts.emailAddress' => 'Dirección de email',
			'switchAccounts.linkAccount' => 'Vincular cuenta',
			'switchAccounts.copiedCode' => 'Código copiado al portapapeles',
			'switchAccounts.copyCode' => 'Copiar código',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Abre la app Ham2K en un dispositivo ya vinculado con ${email} e introduce este código para aprobar la solicitud:',
			'switchAccounts.waitingForConfirmation' => 'Esperando confirmación…',
			'switchAccounts.sendEmailInstead' => 'Enviar un email de confirmación en su lugar',
			'switchAccounts.emailSent' => ({required Object email}) => 'Se envió un email a ${email}. Ábrelo y confirma la solicitud para vincular este dispositivo.',
			'switchAccounts.resendEmail' => 'Reenviar email',
			'switchAccounts.qrPrompt' => 'Escanea este código QR desde un dispositivo ya vinculado a la cuenta que quieres — por ejemplo, con Ham2K Portable Logger en tu teléfono.',
			'switchAccounts.serverUnreachable' => 'No se pudo contactar el servidor de sincronización. Inténtalo más tarde.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} operación', other: '${count} operaciones', ), 
			_ => null,
		};
	}
}
