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
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$es common = _Translations$common$es._(_root);
	@override late final _Translations$onboarding$es onboarding = _Translations$onboarding$es._(_root);
	@override late final _Translations$startScreen$es startScreen = _Translations$startScreen$es._(_root);
	@override late final _Translations$testerOverlay$es testerOverlay = _Translations$testerOverlay$es._(_root);
	@override late final _Translations$extensionsPanel$es extensionsPanel = _Translations$extensionsPanel$es._(_root);
	@override late final _Translations$home$es home = _Translations$home$es._(_root);
	@override late final _Translations$chase$es chase = _Translations$chase$es._(_root);
	@override late final _Translations$dialogs$es dialogs = _Translations$dialogs$es._(_root);
	@override late final _Translations$operation$es operation = _Translations$operation$es._(_root);
	@override late final _Translations$map$es map = _Translations$map$es._(_root);
	@override late final _Translations$mapsView$es mapsView = _Translations$mapsView$es._(_root);
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
	@override late final _Translations$keyboardShortcuts$es keyboardShortcuts = _Translations$keyboardShortcuts$es._(_root);
	@override late final _Translations$expiredBuild$es expiredBuild = _Translations$expiredBuild$es._(_root);
	@override late final _Translations$staleness$es staleness = _Translations$staleness$es._(_root);
	@override late final _Translations$spotting$es spotting = _Translations$spotting$es._(_root);
	@override late final _Translations$dataFiles$es dataFiles = _Translations$dataFiles$es._(_root);
	@override late final _Translations$updates$es updates = _Translations$updates$es._(_root);
	@override late final _Translations$extensionService$es extensionService = _Translations$extensionService$es._(_root);
	@override late final _Translations$operationLocationScreen$es operationLocationScreen = _Translations$operationLocationScreen$es._(_root);
	@override late final _Translations$versionLabel$es versionLabel = _Translations$versionLabel$es._(_root);
	@override late final _Translations$notices$es notices = _Translations$notices$es._(_root);
	@override late final _Translations$syncAccount$es syncAccount = _Translations$syncAccount$es._(_root);
	@override late final _Translations$deepLink$es deepLink = _Translations$deepLink$es._(_root);
	@override late final _Translations$confirmDevice$es confirmDevice = _Translations$confirmDevice$es._(_root);
	@override late final _Translations$switchAccounts$es switchAccounts = _Translations$switchAccounts$es._(_root);
	@override late final _Translations$qsonImport$es qsonImport = _Translations$qsonImport$es._(_root);
	@override late final _Translations$adifImport$es adifImport = _Translations$adifImport$es._(_root);
	@override late final _Translations$offline$es offline = _Translations$offline$es._(_root);
	@override late final _Translations$exportSettings$es exportSettings = _Translations$exportSettings$es._(_root);
	@override late final _Translations$templateEditor$es templateEditor = _Translations$templateEditor$es._(_root);
}

// Path: common
class _Translations$common$es extends Translations$common$en {
	_Translations$common$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get save => 'Guardar';
	@override String get ok => 'OK';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Eliminar';
	@override String get create => 'Crear';
	@override String get error => 'Error';
	@override String get close => 'Cerrar';
	@override String get done => 'Listo';
	@override String get callsign => 'Indicativo';
	@override String get clear => 'Borrar';
	@override String get dismiss => 'Descartar';
	@override String get copyDetails => 'Copiar detalles';
	@override String get expand => 'Expandir';
	@override String get collapse => 'Contraer';
}

// Path: onboarding
class _Translations$onboarding$es extends Translations$onboarding$en {
	_Translations$onboarding$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => '¡Bienvenido a Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => '¡Bienvenido a Ham2K Power Logger!';
	@override String get welcomeBody => 'Tenemos algunas preguntas para adaptar mejor la app a lo que necesitas.';
	@override String get skip => 'Omitir';
	@override String get kContinue => 'Continuar';
	@override String get back => 'Atrás';
	@override String get next => 'Siguiente';
	@override String get done => 'Listo';
	@override String get callsignTitle => '¿Cuál es tu indicativo?';
	@override String get callsignBody => 'Necesitas una licencia de radioaficionado para que esta app te resulte útil';
	@override String get callsignLabel => 'Indicativo del Operador';
	@override String get alreadyHaveAccount => '¿Ya tienes una cuenta?';
	@override String get foundSiblingTitle => '¿Vincular una cuenta existente?';
	@override String foundSiblingBody({required Object app}) => 'Encontramos ${app} en este dispositivo. Vincula esta app a la misma cuenta y traerás tu indicativo y tus logs.';
	@override String get foundPoloBody => 'Encontramos una versión anterior de Ham2K Portable Logger en este dispositivo. Vincula esta app a la misma cuenta y traerás tu indicativo y tus logs.';
	@override String get foundSiblingsBody => 'Encontramos otras apps de Ham2K en este dispositivo. Vincula esta app a una de sus cuentas y traerás tu indicativo y tus logs.';
	@override String linkWithApp({required Object app}) => 'Vincular con ${app}';
	@override String get linkWithPolo => 'Vincular con la cuenta de la versión anterior';
	@override String get setUpFresh => 'Empezar de cero';
	@override String get activitiesTitle => 'Actividades favoritas';
	@override String get activitiesBody => '¿Te interesa alguno de estos populares programas de activación?';
	@override String get activitiesFooter => '(Encontrarás más opciones en la Configuración)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'Sincronización en la nube';
	@override String get syncBody => 'Ham2K Log Filer guarda un respaldo de tus logs en la nube y los sincroniza entre todos los dispositivos donde uses apps de Ham2K.';
	@override String get syncPricing => '¡Es gratis! Pero con una suscripción de pago será más rápido.';
	@override String get syncLabel => 'Habilitar sincronización en la nube';
	@override String get syncOffWarning => 'ADVERTENCIA: esto aumenta el riesgo de perder los datos de tus operaciones, por ejemplo si tu dispositivo falla o se pierde.';
	@override String get notNow => 'Ahora no';
	@override String get consentTitle => 'Datos y privacidad';
	@override String get consentUsageBody => 'Para ayudarnos a mejorar la app, nos gustaría recopilar datos de rendimiento, fallos y uso.';
	@override String get consentUsageLabel => 'Compartir datos de uso de la aplicación';
	@override String get consentOperationBody => 'Algunas funciones pueden implicar compartir datos de tus operaciones con otros usuarios. Puedes desactivarlo en cualquier momento.';
	@override String get consentOperationLabel => 'Compartir datos de operación';
	@override String get finishingSetup => 'Terminando la configuración — descargando datos de referencia…';
}

// Path: startScreen
class _Translations$startScreen$es extends Translations$startScreen$en {
	_Translations$startScreen$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get credits => 'por KI2D y sus amigos';
}

// Path: testerOverlay
class _Translations$testerOverlay$es extends Translations$testerOverlay$en {
	_Translations$testerOverlay$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get tape => 'PRECAUCIÓN: EN CONSTRUCCIÓN';
	@override String get warningTitle => 'Esta app todavía está en obras';
	@override String get warningBody => 'La mayoría de las funciones tienen superficies irregulares y hay riesgo de tropezar por todas partes. Busca actualizaciones con frecuencia.';
	@override String whatsNew({required Object build}) => 'Novedades del build ${build}';
	@override String get thanks => '¡Gracias por poner tu log en riesgo para ayudarnos a mejorar esta app!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$es extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Actividades';
	@override String get categoryAward => 'Diplomas';
	@override String get categoryContest => 'Concursos';
	@override String get categoryLookup => 'Búsquedas de indicativo';
	@override String get categorySpots => 'Fuentes de Spots';
	@override String get categoryDashboard => 'Paneles del tablero';
	@override String get categoryOther => 'Otras extensiones';
	@override String get searchHint => 'Buscar extensiones';
	@override String get applying => 'Activando cambios de extensiones, esto puede tardar un momento…';
	@override String get noMatches => 'Ninguna extensión coincide con tu búsqueda';
	@override String get installFromFile => 'Instalar desde archivo…';
	@override String installVersion({required Object version}) => 'Versión ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'Captura ${n} de ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'Captura anterior';
	@override String get nextScreenshot => 'Captura siguiente';
	@override String get screenshotUnavailable => 'Captura no disponible';
	@override String get canReach => 'Esta extensión puede acceder a';
	@override String canHoldConnection({required Object host}) => '${host}, mediante una conexión en vivo';
	@override String get canHoldLocalConnection => 'Dispositivos de tu red local, mediante una conexión en vivo';
	@override String get canUseLocation => 'Tu ubicación';
	@override String get canReadRadio => 'Tu radio, para leer su frecuencia y modo';
	@override String get canControlRadio => 'Tu radio, para controlarla y transmitir con ella — sintonía, potencia, CW, memorias de voz y PTT';
	@override String get canCommandRadioRaw => 'Tu radio, para enviarle cualquier comando en su propio protocolo — incluidos los que transmiten o cambian su configuración';
	@override String get canReadCluster => 'El clúster DX, conectado como tú, para leer lo que envía';
	@override String get canSpotCluster => 'El clúster DX, conectado como tú, para publicar spots en tu nombre';
	@override String get canCommandCluster => 'El clúster DX, conectado como tú, para enviarle cualquier comando en tu nombre';
	@override String get canSetUserAgent => 'Identificarse ante los servidores con su propio nombre';
	@override String get canChangeSettings => 'Tu configuración, para cambiarla mediante sus comandos: cualquier opción, el modo desarrollador y los experimentos';
	@override String get noCapabilities => 'No pide nada fuera de la app.';
	@override String get sandboxNote => 'Las extensiones se ejecutan aisladas: sin acceso a tus archivos y sin más red que la indicada aquí.';
	@override String get installAction => 'Instalar';
	@override String get updateAction => 'Actualizar';
	@override String get installFailed => 'No se pudo instalar esa extensión';
	@override String get installedBadge => 'Instalada';
	@override String get uninstallAction => 'Quitar';
	@override String uninstallTitle({required Object name}) => '¿Quitar ${name}?';
	@override String get uninstallBody => 'Se quitará esta extensión junto con su configuración. Tus logs quedarán intactos.';
	@override String installedMessage({required Object name}) => 'Se instaló ${name}';
	@override String get installDownloading => 'Descargando…';
	@override String get installWaiting => 'Esperando para instalar…';
	@override String get installInstalling => 'Instalando…';
	@override String get installAwaitingApproval => 'Esperando tu aprobación…';
	@override String installAlreadyRunning({required Object name}) => 'Ya se está instalando ${name}.';
	@override String updatedTo({required Object version}) => 'Actualizada a ${version}';
	@override String installIncomplete({required Object name}) => 'La instalación de ${name} no se completó. Puede que haya que instalarla de nuevo.';
	@override String uninstallFailed({required Object name}) => 'No se pudo quitar ${name}';
	@override String installedFrom({required Object source}) => 'Descargada desde ${source}';
	@override String get dropHint => 'Suelta una extensión .h2kext para instalarla';
	@override String get dropOneOnly => 'Suelta una extensión a la vez.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} respondió ${status} para esa extensión.';
	@override String get downloadTooLarge => 'Esa descarga es demasiado grande para ser una extensión.';
	@override String get downloadNotSecure => 'Esa descarga redirigió a un sitio no seguro.';
	@override String get catalogSection => 'Catálogo';
	@override String get catalogLoading => 'Cargando el catálogo…';
	@override String get catalogUnreachable => 'Catálogo inaccesible';
	@override String get builtIn => 'Incorporada';
	@override String get updateAvailableBadge => 'Actualización disponible';
	@override String get updatesAvailableTitle => 'Actualizaciones de extensiones';
	@override String updateAvailableFor({required Object name}) => 'Hay una actualización disponible para ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} y ${count} más necesitan actualizarse.';
	@override String updatesAvailableFor({required Object names}) => '${names} necesitan actualizarse.';
	@override String get pendingUpdatesSection => 'Actualizaciones pendientes';
	@override String get updateAllAction => 'Actualizar todas';
	@override String get updatesUnderWay => 'Esas actualizaciones ya están en curso.';
	@override String get updatesNothingLeft => 'Tus extensiones están al día.';
	@override String get updatesNoticeAction => 'Más información';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '¿Actualizar ${count} extensión?',
		other: '¿Actualizar ${count} extensiones?',
	);
	@override String get upgradeDoneTitle => 'Tus extensiones están listas';
	@override String get upgradeDoneBody => 'Ahora vienen del catálogo de extensiones de Ham2K, así que pueden actualizarse sin esperar una nueva versión de la app.';
	@override String upgradeDoneUnserved({required Object names}) => 'No se actualizaron: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'No pudieron ejecutarse: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Siguen instaladas y marcadas en Configuración › Extensiones — actualizarlas allí las recuperará.';
	@override String get upgradeDoneUnservedHint => 'El catálogo no tiene un reemplazo directo para estas, así que busca allí extensiones que cubran lo que usabas.';
	@override String get retiredQp => 'Concursos Estatales';
	@override String get retiredStateparks => 'Eventos de parques estatales';
	@override String upgradeDoneMissing({required Object count}) => '${count} de tus extensiones aún no han llegado. Se descargarán la próxima vez que se pueda acceder al catálogo de extensiones.';
	@override String get runtimeDeadBody => 'Tus extensiones no arrancaron. Reiniciar la app debería recuperarlas.';
	@override String get refusedTitle => 'Algunas extensiones no pudieron ejecutarse';
	@override String get upgradeBusyTitle => 'Todavía en preparación';
	@override String get upgradeRuntimeDeadTitle => 'Tus extensiones no están funcionando';
	@override String get restoreTitle => 'Faltan algunas de tus extensiones';
	@override String get restoreBody => 'Estas extensiones que instalaste no están en este dispositivo. Podemos descargarlas de nuevo del catálogo de extensiones de Ham2K:';
	@override String get restoreFromFile => 'Instaladas desde un archivo. Instálalas de nuevo desde sus archivos, u olvídalas:';
	@override String get restoreOtherCatalog => 'Instaladas desde otro catálogo de extensiones, así que no están disponibles aquí:';
	@override String get restoreForget => 'Olvidar';
	@override String get restoreInstall => 'Instalar';
	@override String get restoreLater => 'Más tarde';
	@override String get restoreInstalling => 'Instalando tus extensiones…';
	@override String get restoreDoneTitle => 'Tus extensiones están de vuelta';
	@override String restoreDoneBody({required Object names}) => 'Instaladas de nuevo: ${names}.';
	@override String get restorePartialTitle => 'Algunas extensiones no se pudieron instalar';
	@override String restoreFailed({required Object names}) => 'No se pudieron instalar: ${names}. Te las ofreceremos de nuevo la próxima vez que abras la app.';
	@override String get restoreBusyBody => 'La app todavía está preparando tus extensiones. Te las ofreceremos de nuevo la próxima vez que abras la app.';
	@override String get restoreRuntimeDeadBody => 'Las instalamos de nuevo, pero tus extensiones no arrancaron. Reiniciar la app debería recuperarlas.';
	@override String revokedTitle({required Object name}) => 'Se retiró ${name}';
	@override String get revokedBody => 'El catálogo retiró esta versión, así que fue deshabilitada.';
	@override String forceDisabledTitle({required Object name}) => 'Se deshabilitó ${name}';
	@override String get forceDisabledBody => 'Ham2K ha deshabilitado esta extensión por ahora.';
	@override String replacedTitle({required Object name}) => '${name} fue reemplazada';
	@override String replacedBody({required Object replacement}) => '${replacement} ocupa su lugar. Puedes cambiar a ella en Extensiones.';
	@override String replacedBy({required Object name}) => 'Reemplazada por ${name}';
	@override String replacedByInstalled({required Object name}) => 'Reemplazada por ${name}, que ya tienes';
	@override String get replaceAction => 'Reemplazar';
	@override String replaceInstalledBody({required Object replacement}) => 'Su configuración pasa a ${replacement}, que ya tienes. Tus logs quedarán intactos.';
	@override String get downloadHashMismatch => 'Esa descarga no es la extensión que describe el catálogo.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'El catálogo no tiene la versión ${version} de ${key}.';
	@override String get catalogLinkUnknown => 'Ese enlace del catálogo no indica una versión de extensión.';
	@override String catalogNoRelease({required Object key}) => 'El catálogo no tiene ninguna versión de ${key} en ese canal.';
	@override String get installFromLink => 'Instalar desde enlace';
	@override String get unstableReleaseWarning => 'Esta es una versión inestable, que quien la publica no da por terminada. Puede fallar y seguirá recibiendo actualizaciones inestables.';
	@override String get bleedingReleaseWarning => 'Esta es una versión "Bleeding Edge": trabajo en curso que puede romperse o perder su configuración. Seguirá recibiendo actualizaciones "Bleeding Edge".';
	@override String get channelUnstable => 'Inestable';
	@override String get channelBleeding => 'Bleeding Edge';
	@override String get followsUnstable => 'Recibe versiones inestables y estables';
	@override String get followsBleeding => 'Recibe versiones "Bleeding Edge", inestables y estables';
	@override String get followStableAction => 'Seguir solo versiones estables';
	@override String get revokedBadge => 'Retirada';
	@override String get forceDisabledBadge => 'Deshabilitada por Ham2K';
	@override String get refusedBadge => 'No se cargó';
	@override String get downloadNotHttps => 'Esa descarga no usa una conexión segura.';
	@override String downloadUnreachable({required Object source}) => 'No se pudo contactar a ${source} para esa extensión.';
	@override String get detailsAction => 'Detalles';
	@override String get installedFromFile => 'Instalada desde un archivo';
	@override String get detailsWhatItDoes => 'Ofrece soporte para';
	@override String get installedPreloaded => 'Preinstalada';
	@override String get hookAccount => 'Inicio de sesión en cuenta';
	@override String get hookCallNotes => 'Notas de indicativo';
	@override String get hookDataFile => 'Datos sin conexión';
	@override String get hookExport => 'Exportar';
	@override String get hookLookup => 'Búsquedas de indicativo';
	@override String get hookScoring => 'Puntuación';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => 'Cazando ${program}';
	@override String hookActivating({required Object program}) => 'Activando ${program}';
	@override String get suggestedSection => 'Sugeridas';
	@override String moreAvailableSection({required Object count}) => 'Más disponibles (${count})';
}

// Path: home
class _Translations$home$es extends Translations$home$en {
	_Translations$home$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Libro de Guardia Portátil';
	@override String get newOperation => 'Nueva operación';
	@override String get stationCallsign => 'Indicativo de estación';
	@override String get titleOptional => 'Título (opcional)';
	@override String get emptyList => 'Aún no hay operaciones. Crea una para empezar a registrar QSOs.';
	@override String get quickLookup => 'Búsqueda rápida';
	@override late final _Translations$home$nav$es nav = _Translations$home$nav$es._(_root);
	@override late final _Translations$home$panels$es panels = _Translations$home$panels$es._(_root);
	@override String get toggleNav => 'Mostrar u ocultar las etiquetas de navegación';
	@override late final _Translations$home$logs$es logs = _Translations$home$logs$es._(_root);
}

// Path: chase
class _Translations$chase$es extends Translations$chase$en {
	_Translations$chase$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'cazando';
	@override String goalsTwo({required Object first, required Object second}) => '${first} y ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} y más';
	@override late final _Translations$chase$station$es station = _Translations$chase$station$es._(_root);
	@override late final _Translations$chase$periodInline$es periodInline = _Translations$chase$periodInline$es._(_root);
	@override late final _Translations$chase$periodStats$es periodStats = _Translations$chase$periodStats$es._(_root);
	@override late final _Translations$chase$period$es period = _Translations$chase$period$es._(_root);
	@override late final _Translations$chase$goals$es goals = _Translations$chase$goals$es._(_root);
	@override late final _Translations$chase$panels$es panels = _Translations$chase$panels$es._(_root);
	@override late final _Translations$chase$claims$es claims = _Translations$chase$claims$es._(_root);
	@override late final _Translations$chase$notice$es notice = _Translations$chase$notice$es._(_root);
	@override late final _Translations$chase$alerts$es alerts = _Translations$chase$alerts$es._(_root);
	@override String get checklists => 'Progreso de cacería';
	@override late final _Translations$chase$imports$es imports = _Translations$chase$imports$es._(_root);
}

// Path: dialogs
class _Translations$dialogs$es extends Translations$dialogs$en {
	_Translations$dialogs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Detalles de la operación';
	@override String get activities => 'Actividades';
	@override String get stationCallsign => 'Indicativo de Estación';
	@override String get advanced => 'Avanzado';
	@override String get operatingPosition => 'Posición de operación (multiestación)';
	@override String get assistance => 'Asistencia';
	@override String get assistanceDescription => 'Usar servicios de spots y otras fuentes de información';
	@override String get selfSpotting => 'Self-spotting';
	@override String get selfSpottingDescription => 'Permitir funciones que reporten tu propia frecuencia';
	@override String disabledByRules({required Object rules}) => 'Deshabilitado para cumplir las reglas de ${rules}';
	@override late final _Translations$dialogs$lookupDespiteAssistance$es lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$es._(_root);
	@override String get notes => 'Notas';
	@override String get deleteOperationTitle => 'Eliminar Operación';
	@override String get purgeTestsTitle => 'Purgar operaciones de prueba';
	@override String get purgeTestsBody => 'Esto elimina permanentemente estas operaciones de prueba y sus QSOs. No se puede deshacer.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Más ${count} contacto de prueba que no pertenece a ninguna operación.',
		other: 'Más ${count} contactos de prueba que no pertenecen a ninguna operación.',
	);
	@override String get purgeTestsAction => 'Purgar';
	@override String get syncAllTitle => '¿Reemplazar el log de este dispositivo?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL respalda y borra ${qsos} de este dispositivo, y luego vuelve a descargar el log de la cuenta desde el servidor. El respaldo queda en la base de datos de este dispositivo.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} QSO aún no se ha sincronizado — el servidor nunca lo recibió y NO va a volver.',
		other: '${n} QSOs aún no se han sincronizado — el servidor nunca los recibió y NO van a volver.',
	);
	@override String get syncAllAction => 'Borrar y resincronizar';
	@override String get receivedPurgesTitle => 'Operaciones de prueba eliminadas en otro dispositivo';
	@override String get receivedPurgesBody => 'Estas se eliminaron como operaciones de prueba en otro dispositivo. ¿Quitarlas aquí también? Esto las elimina permanentemente junto con sus QSOs y no se puede deshacer.';
	@override String get receivedPurgesAction => 'Quitar';
	@override late final _Translations$dialogs$callChange$es callChange = _Translations$dialogs$callChange$es._(_root);
}

// Path: operation
class _Translations$operation$es extends Translations$operation$en {
	_Translations$operation$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Esta operación está eliminada. Restáurala para registrar contactos o hacer cambios.';
	@override late final _Translations$operation$tabs$es tabs = _Translations$operation$tabs$es._(_root);
	@override late final _Translations$operation$positions$es positions = _Translations$operation$positions$es._(_root);
	@override String get stationCallsignNone => 'Sin indicativo de estación';
	@override String get titleNone => 'Sin título';
	@override String get deleteOperation => 'Eliminar operación';
	@override String get loggingControlsStale => 'Los campos de actividad podrían estar desactualizados — reabre la operación para actualizarlos';
	@override String get locationNone => 'Sin establecer';
	@override String get generalOperation => 'Operación General';
	@override String titleFor({required Object value}) => 'para ${value}';
	@override String titleAt({required Object value}) => 'en ${value}';
	@override String segmentNow({required Object description}) => 'Ahora ${description}';
	@override String get testOperationSuffix => 'Prueba';
	@override late final _Translations$operation$menu$es menu = _Translations$operation$menu$es._(_root);
	@override late final _Translations$operation$layout$es layout = _Translations$operation$layout$es._(_root);
	@override late final _Translations$operation$export$es export = _Translations$operation$export$es._(_root);
	@override late final _Translations$operation$spots$es spots = _Translations$operation$spots$es._(_root);
	@override late final _Translations$operation$import$es import = _Translations$operation$import$es._(_root);
}

// Path: map
class _Translations$map$es extends Translations$map$en {
	_Translations$map$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$es outlineIssue = _Translations$map$outlineIssue$es._(_root);
	@override String get outlinesDisclaimer => 'Los contornos son solo orientativos. ¡Investiga por tu cuenta!';
	@override String outlinesCredit({required Object sources}) => 'Contornos: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Límites: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Instalaciones: ${sources}';
	@override String get fullCredits => 'Créditos completos de los datos';
	@override String get fewerCredits => 'Menos créditos';
	@override String get emptyState => 'Aún no hay ubicaciones de QSO.\nLos QSOs con grilla, estado o país aparecerán aquí.';
	@override String get unavailable => 'El mapa no está disponible en este momento.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plano';
	@override String get globe => 'Globo';
	@override String get zoomIn => 'Acercar';
	@override String get zoomOut => 'Alejar';
	@override String get resetNorth => 'Orientar al norte';
	@override late final _Translations$map$postcard$es postcard = _Translations$map$postcard$es._(_root);
}

// Path: mapsView
class _Translations$mapsView$es extends Translations$mapsView$en {
	_Translations$mapsView$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override String get searchHint => 'Buscar parques, cumbres y más';
	@override String get activities => 'Actividades';
	@override String get layers => 'Capas';
	@override String get baseMap => 'Mapa base';
	@override String get satellite => 'Satélite (Esri)';
	@override String get facilities => 'Instalaciones de parques';
	@override String get boundaries => 'Límites';
	@override String get currentLocation => 'Ubicación actual';
	@override String noMatches({required Object text}) => 'Nada coincide con “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} referencia en ${where}',
		other: '${count} referencias en ${where}',
	);
	@override String get startOperation => 'Iniciar una operación con estas referencias';
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
	@override String get empty => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para agregar una';
	@override String get removeActivity => 'Quitar';
	@override String openReferenceLink({required Object name}) => 'Abrir ${name}';
	@override String get editActivity => 'Editar actividad';
	@override String get manageExtensions => 'Gestionar extensiones';
	@override String get manage => 'Gestionar';
	@override String activitiesTitle1({required Object first}) => 'Tipos de actividad: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipos de actividad: ${first} y ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipos de actividad: ${first}, ${second} y ${more} más';
	@override String get reference => 'Referencia';
	@override String get invalidReference => 'No válida';
	@override String get duplicateReference => 'Ya agregada';
	@override String get searchHint => 'Busca por nombre, referencia o cualquier otra cosa…';
	@override String get noSuggestions => 'Sin coincidencias';
	@override String get noSuggestionsHint => 'Busca por nombre o número de referencia arriba';
	@override String get noSuggestionsExample => '(por ejemplo \'trail\' o \'4556\')';
	@override String get allOptions => 'Tipos de actividad';
	@override String get determiningLocation => 'Determinando ubicación actual…\nEsperando señal de GPS para encontrar referencias cercanas';
	@override String get locationUnavailableTitle => 'Datos de ubicación no disponibles';
	@override String get locationDeniedTitle => 'Permiso de ubicación denegado';
	@override String get locationBlockedTitle => 'Permiso de ubicación bloqueado';
	@override String get noNearbyReason => 'No se pueden determinar referencias cercanas';
	@override String locationManualHint({required Object icon}) => 'Toca ${icon} para introducir tu ubicación manualmente,\no simplemente busca referencias por nombre';
	@override String get locationGrantAction => 'Permitir acceso a la ubicación';
	@override String get locationSettingsAction => 'Abrir Configuración';
	@override String get locationSettingsUnavailable => 'Permite el acceso a la ubicación en la configuración del sistema';
	@override String get locationGrantRefused => 'Sigue sin ubicación — el sistema volvió a negarlo';
	@override String get searchUnavailableTitle => 'Búsqueda de actividades no disponible';
	@override String get searchUnavailableReason => 'Una extensión de actividades no pudo responder a la búsqueda. Inténtalo de nuevo en un momento.';
	@override String get emptySheet => 'Usa las sugerencias y la búsqueda abajo para agregar una';
	@override String get exports => 'Exportaciones';
	@override String get exportLogs => 'Exportar logs';
	@override String get tools => 'Herramientas';
	@override String get toolsTitle => 'Herramientas de la operación';
	@override String get operationDetails => 'Detalles de la Operación';
	@override String get share => 'Compartir';
	@override String get archive => 'Archivar';
	@override String get deleteOperation => 'Eliminar Operación';
	@override String get undeleteOperation => 'Restaurar Operación';
	@override String get alreadySelected => 'Ya seleccionada';
	@override String get selected => 'Seleccionada';
	@override String pickPosition({required Object index, required Object count}) => '${index} de ${count}';
	@override String get previousPick => 'Coincidencia anterior';
	@override String get nextPick => 'Siguiente coincidencia';
	@override String get retiredReference => 'Retirada';
	@override String enableExtension({required Object name}) => 'Habilitar ${name}';
	@override String get enableExtensionHint => 'Esta extensión coincide con tu búsqueda, pero no está habilitada';
	@override String get enableExtensionForRefHint => 'Esta extensión maneja una de las referencias de esta operación, pero no está habilitada';
	@override String extensionNotRunning({required Object name}) => '${name} no está funcionando';
	@override String get extensionNotRunningHint => 'Esta extensión ha sido deshabilitada; abre la configuración de extensiones para más información';
	@override String installExtension({required Object name}) => 'Instalar ${name}';
	@override String get installExtensionHint => 'Esta extensión coincide con tu búsqueda, pero no está instalada';
	@override String get onlyCatalogMatches => 'Sin coincidencias\nAlgunas extensiones del catálogo podrían tener resultados.\nInstálalas en Tipos de actividad, más abajo.';
	@override String get setupUnavailable => 'No se pudo cargar la configuración de esta actividad; inténtalo desde Gestionar';
	@override String get controlsUnavailableTitle => 'Controles de actividad no disponibles';
	@override String get controlsUnavailableReason => 'Tus referencias están a salvo, pero ahora mismo no se pueden editar.';
	@override String get controlsUnavailableRetry => 'Reintentar';
	@override String get onlyDisabledMatches => 'Sin coincidencias\nAlgunas extensiones disponibles podrían tener resultados.\nHabilítalas en Tipos de actividad, más abajo.';
	@override String get onlyNotRunningMatches => 'Sin coincidencias\nAlgunas extensiones que podrían tener resultados no están funcionando.\nMira en Tipos de actividad, más abajo.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Buscar';
	@override String get addToOperation => 'Agregar a la operación';
	@override String get addToOperationShort => 'Agregar a op.';
	@override String get mapEmptyState => 'No hay resultados que mostrar en el mapa';
	@override String get mapEmptyStateHint => 'Vuelve a la lista o busca otra cosa';
	@override String get imports => 'Importaciones';
}

// Path: loggingControls
class _Translations$loggingControls$es extends Translations$loggingControls$en {
	_Translations$loggingControls$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Fecha';
	@override String get now => 'Ahora';
	@override String get manualTimeSettings => 'Hora manual';
	@override String get manualTimeIncrement => 'Incremento por QSO';
	@override String get manualTimeIncrementNone => 'Ninguno';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} minuto',
		other: '${count} minutos',
	);
	@override String get frequency => 'Frecuencia';
	@override String get mode => 'Modo';
	@override String get theirCall => 'Indicativo';
	@override String get noteField => 'Nota';
	@override String get todoField => 'Tarea';
	@override String get sent => 'Env.';
	@override String get rcvd => 'Recib.';
	@override String get more => 'Más';
	@override String get revert => 'Revertir';
	@override String get undoDelete => 'Deshacer eliminación';
	@override String get restore => 'Restaurar';
	@override String get wipe => 'Borrar';
	@override String get undo => 'Deshacer';
	@override String get pendingDeleteTapWarning => 'Toca la papelera una vez más para eliminar este QSO';
	@override String get pendingDeleteClickWarning => 'Haz clic en la papelera una vez más para eliminar este QSO';
	@override String get deletedQsoWarning => 'QSO eliminado';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Toca la papelera una vez más para eliminar este ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Haz clic en la papelera una vez más para eliminar este ${kind}';
	@override String deletedEventWarning({required Object kind}) => '${kind} eliminado';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Potencia';
	@override String get notesControl => 'Notas';
	@override String get power => 'Potencia';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controles de logging';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Self-spotting';
	@override String spotSelfAt({required Object freq}) => 'Self-spot en ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} en ${freq}';
	@override String spotTooLate({required Object call}) => 'Demasiado tarde para hacer spot de ${call}';
	@override String get spotNoFreq => 'Primero establece una frecuencia para hacer spot';
	@override String get selfSpotDisabled => 'Self-spot deshabilitado';
	@override String get spotComment => 'Comentario';
	@override String get spottingAutoControl => 'Auto re-spot';
	@override String spotAutoEvery({required Object minutes}) => 'Re-spot cada ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'Auto en ${time}. ¿Detener?';
	@override String spotAutoInMinutes({required Object minutes}) => 'Auto en ${minutes}m';
	@override String spotAutoInSeconds({required Object seconds}) => 'Auto en ${seconds}s';
	@override String spotAutoInCount({required Object seconds}) => 'Auto en ${seconds}';
	@override String get spotAutoNotStarted => 'Auto re-spot no iniciado: el spot no se envió';
	@override String get spotAutoMoved => 'Auto re-spot no iniciado: la frecuencia cambió durante el spot';
	@override String get spotAutoStopped => 'Auto re-spot detenido';
	@override String get spotAutoLeftFreq => 'Auto re-spot detenido: cambió la frecuencia';
	@override String get spotAutoNoFreq => 'Auto re-spot detenido: la radio no reporta frecuencia';
	@override String get spotBusy => 'Todavía se está enviando otro spot';
	@override String get bandOrFreqRequired => 'Establece una frecuencia o banda antes de registrar';
	@override String get missingBand => 'Sin Banda';
	@override String get missingMode => 'Sin Modo';
	@override String saveFailed({required Object error}) => 'No se pudo guardar: ${error}';
	@override String deleteFailed({required Object error}) => 'No se pudo eliminar: ${error}';
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
	@override String get defaults => 'Por defecto';
	@override String get search => 'Buscar';
	@override String get clear => 'Borrar';
	@override String get openPage => 'Abrir página';
	@override String get connected => 'Conectado';
	@override String get notConnected => 'No conectado';
	@override String get manage => 'Gestionar';
	@override String get connect => 'Conectar';
	@override String get formTitle => 'Formulario';
	@override String addItem({required Object label}) => 'Agregar ${label}';
	@override String editItem({required Object label}) => 'Editar ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} seleccionados)';
	@override String validationError({required Object error}) => 'Error de validación: ${error}';
	@override String transformationError({required Object error}) => 'Error de transformación: ${error}';
	@override String actionError({required Object error}) => 'Error: ${error}';
	@override String get removeItem => 'Eliminar';
	@override String deleteItemTitle({required Object name}) => '¿Eliminar ${name}?';
	@override String get storageUnavailable => 'Credenciales no disponibles';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$es extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editar QSO';
	@override String get operatorCall => 'Operador';
	@override String get position => 'Posición';
	@override String get theirName => 'Nombre';
	@override String get theirGrid => 'Grilla';
	@override String get theirState => 'Estado';
	@override String get band => 'Banda';
	@override String get notes => 'Notas';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Su Información';
	@override String get sectionOur => 'Nuestra Información';
	@override String get sectionNotes => 'Notas';
	@override String get theirCity => 'Ciudad';
	@override String get theirCounty => 'Condado';
	@override String get theirEntity => 'Entidad';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Sección ARRL';
	@override String get theirLat => 'Latitud';
	@override String get theirLon => 'Longitud';
	@override String get theirPower => 'Su potencia';
}

// Path: qsoList
class _Translations$qsoList$es extends Translations$qsoList$en {
	_Translations$qsoList$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Aún no hay QSOs — ¡haz un contacto!';
	@override String get bandOrModeWarning => 'Verifica que tu banda y modo sean correctos';
	@override String get today => 'Hoy';
	@override String get yesterday => 'Ayer';
	@override String get tomorrow => 'Mañana';
	@override late final _Translations$qsoList$find$es find = _Translations$qsoList$find$es._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$es extends Translations$loggingPanel$en {
	_Translations$loggingPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Estadísticas de la Operación';
	@override String get scoring => 'Puntuación';
	@override String get dxccEntities => 'Entidades DXCC';
	@override String get statesWorked => 'Estados';
	@override String get provincesWorked => 'Provincias';
	@override String get duplicates => 'Duplicados';
}

// Path: callInfo
class _Translations$callInfo$es extends Translations$callInfo$en {
	_Translations$callInfo$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostrar Imagen';
	@override String get imageUnavailable => 'Foto no disponible';
	@override String get photo => 'Foto';
	@override String get notes => 'Notas';
	@override String distanceTo({required Object distance}) => '${distance} a';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) a';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)';
	@override String get thisOpCountOne => '1 QSO en esta operación';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs en esta operación';
	@override String get otherOpsCountOne => '1 QSO en otras operaciones';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs en otras operaciones';
	@override String andMore({required Object count}) => '… y ${count} más';
	@override String withCall({required Object call}) => 'con ${call}';
	@override String fromOperation({required Object where}) => 'desde ${where}';
	@override late final _Translations$callInfo$history$es history = _Translations$callInfo$history$es._(_root);
}

// Path: settings
class _Translations$settings$es extends Translations$settings$en {
	_Translations$settings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración';
	@override String get language => 'Idioma';
	@override String languageSystem({required Object language}) => 'Seguir la configuración del sistema (${language})';
	@override late final _Translations$settings$theme$es theme = _Translations$settings$theme$es._(_root);
	@override late final _Translations$settings$themeDescription$es themeDescription = _Translations$settings$themeDescription$es._(_root);
	@override String get fontScale => 'Tamaño de Textos';
	@override late final _Translations$settings$fontScaleOpts$es fontScaleOpts = _Translations$settings$fontScaleOpts$es._(_root);
	@override late final _Translations$settings$keepDeviceAwake$es keepDeviceAwake = _Translations$settings$keepDeviceAwake$es._(_root);
	@override String get layoutDensity => 'Densidad de la interfaz';
	@override late final _Translations$settings$layoutDensityOpts$es layoutDensityOpts = _Translations$settings$layoutDensityOpts$es._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'la ventana es demasiado baja, usando ${effective}';
	@override String get layoutDensityAtLimit => 'al límite';
	@override String get distanceUnits => 'Unidades de distancia';
	@override late final _Translations$settings$distanceUnitsOpts$es distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$es._(_root);
	@override String get userInterface => 'Interfaz de usuario';
	@override late final _Translations$settings$logging$es logging = _Translations$settings$logging$es._(_root);
	@override late final _Translations$settings$catServer$es catServer = _Translations$settings$catServer$es._(_root);
	@override late final _Translations$settings$cluster$es cluster = _Translations$settings$cluster$es._(_root);
	@override late final _Translations$settings$spotting$es spotting = _Translations$settings$spotting$es._(_root);
	@override late final _Translations$settings$radio$es radio = _Translations$settings$radio$es._(_root);
	@override late final _Translations$settings$help$es help = _Translations$settings$help$es._(_root);
	@override late final _Translations$settings$exports$es exports = _Translations$settings$exports$es._(_root);
	@override late final _Translations$settings$extensionSections$es extensionSections = _Translations$settings$extensionSections$es._(_root);
	@override late final _Translations$settings$map$es map = _Translations$settings$map$es._(_root);
	@override late final _Translations$settings$privacy$es privacy = _Translations$settings$privacy$es._(_root);
	@override String get operatorCall => 'Indicativo del Operador';
	@override late final _Translations$settings$sync$es sync = _Translations$settings$sync$es._(_root);
	@override late final _Translations$settings$peers$es peers = _Translations$settings$peers$es._(_root);
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
	@override String get showMoreSettings => 'Mostrar más opciones';
	@override String get gridPrecision => 'Precisión de la grilla';
	@override late final _Translations$settings$gridPrecisionOpts$es gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$es._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$es gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$es._(_root);
}

// Path: commands
class _Translations$commands$es extends Translations$commands$en {
	_Translations$commands$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Primero habilita la sincronización en la Configuración.';
	@override String get fullResyncStarted => 'Resincronización completa iniciada — los datos locales se respaldaron primero.';
	@override String noDataFilesMatched({required Object target}) => 'Ningún archivo de datos coincide con "${target}".';
	@override String reloadFailed({required Object error}) => 'Error al recargar: ${error}';
	@override String get reloadingAll => 'Recargando todos los archivos de datos…';
	@override String reloadingTarget({required Object target}) => 'Recargando archivos de datos de ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experimento desconocido "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} habilitado';
	@override String experimentDisabled({required Object name}) => '${name} deshabilitado';
	@override String get sentryTestSent => 'Reporte de error de prueba enviado a Sentry';
	@override String get idleMetricsEnabled => 'Métricas de inactividad habilitadas en la barra de estado';
	@override String get idleMetricsDisabled => 'Métricas de inactividad deshabilitadas';
	@override String get sentryTestLocalOnly => 'Sentry está deshabilitado en este build — el error de prueba solo se registró localmente';
	@override String get noOperationOpen => 'Ese comando necesita una operación abierta';
	@override String unknownSegmentKind({required Object kind}) => 'No sé cómo marcar un \'${kind}\'';
	@override String goUnavailable({required Object place}) => '${place} no está activado en esta app';
	@override String goUnknown({required Object to}) => 'No sé cómo ir a \'${to}\'';
	@override String get goBlocked => 'Cierra primero el diálogo abierto';
	@override String get operationAlreadyStarted => 'Esta operación ya tiene una marca de inicio';
	@override String get couldNotOpenLocation => 'Se agregó la pausa, pero no se pudo abrir la pantalla de ubicación';
	@override String get noTestOperations => 'No hay operaciones de prueba que purgar';
	@override String get purgeTestsUnavailable => 'PURGETESTS necesita mostrar un diálogo de confirmación, que no está disponible aquí';
	@override String get syncAllUnavailable => 'SYNCALL necesita mostrar un diálogo de confirmación, que no está disponible aquí';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se purgó ${count} operación de prueba',
		other: 'Se purgaron ${count} operaciones de prueba',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Se purgaron ${purged} de ${total} operaciones de prueba — el resto falló; prueba PURGETESTS de nuevo';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se purgó ${count} contacto de prueba sin operación',
		other: 'Se purgaron ${count} contactos de prueba sin operación',
	);
	@override String get purgeTestsContactsFailed => 'Se purgaron las operaciones de prueba, pero los contactos de prueba sin operación fallaron; prueba PURGETESTS de nuevo';
	@override String get purgeTestsNothingToDo => 'No se purgó nada';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Se eliminaron ${removed} de ${total} operaciones de prueba — el resto falló; prueba Revisar de nuevo';
	@override String get receivedPurgesFailed => 'No se pudieron eliminar esas operaciones de prueba — prueba Revisar de nuevo';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} operación de prueba se eliminó en otro dispositivo',
		other: '${count} operaciones de prueba se eliminaron en otro dispositivo',
	);
	@override String get receivedPurgesReview => 'Revisar';
	@override String get settingOn => 'Activado';
	@override String get settingOff => 'Desactivado';
	@override String get settingEmpty => '(vacío)';
	@override String get settingSecretSet => '(establecido)';
	@override String get settingSecretUnset => '(sin establecer)';
	@override String settingSelectedCount({required Object count}) => '${count} seleccionados';
	@override String get settingExpectsOnOff => 'activado o desactivado';
	@override String settingExpectsOneOf({required Object choices}) => 'uno de: ${choices}';
	@override String get settingExpectsNumber => 'un número';
	@override String settingVanished({required Object label}) => '“${label}” ya no está disponible';
	@override String get noCwKeyer => 'Ninguna radio conectada puede manipular CW';
	@override String get noKeyer => 'Ninguna radio conectada puede manipular CW ni reproducir memorias de voz';
	@override String get keyerNeedsOperation => 'Abre una operación para usar el manipulador de CW';
	@override String get keyerExperimentOff => 'La manipulación de CW está apagada — enciéndela con EXP KEYER';
	@override String get esmExperimentOff => 'Enter envía mensajes está apagado — enciéndelo con EXP ESM';
	@override String cwSending({required Object text}) => 'Enviando CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Mensaje de CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'El mensaje de CW F${n} no se envió: las extensiones no están listas';
	@override String voiceMessageError({required Object n, required Object error}) => 'Mensaje de fonía M${n}: ${error}';
	@override String get voiceMessageNotRendered => 'las extensiones no están listas';
	@override String so2rRadioCannotKey({required Object radio}) => 'No se envió nada: la Radio ${radio} no puede emitir eso';
	@override String get so2rNoRadioB => 'No se envió nada: elige una Radio B en Configuración de Estación para emitir desde este juego';
	@override String settingNotStored({required Object label}) => '“${label}” no aceptó ese valor';
}

// Path: commandDialog
class _Translations$commandDialog$es extends Translations$commandDialog$en {
	_Translations$commandDialog$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Busca indicativos o escribe un comando';
	@override String noResults({required Object text}) => 'Nada coincide con “${text}”';
	@override String get sectionCommands => 'Comandos';
	@override String get sectionGoTo => 'Ir a';
	@override String get sectionOperations => 'Operaciones';
	@override String get goHome => 'Inicio';
	@override String get goSettings => 'Configuración';
	@override String get goNewOperation => 'Nueva operación';
	@override String runTyped({required Object text}) => 'Ejecutar “${text}”';
	@override String get sectionSuggestions => 'Prueba';
	@override String get lookingUp => 'Buscando indicativo…';
	@override String get blockedByPane => 'No se pueden usar los comandos mientras haya un panel o un diálogo abierto';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$es extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Atajos de teclado';
	@override String get description => 'Personaliza las combinaciones de teclas';
	@override String get search => 'Buscar comandos y teclas';
	@override String get import => 'Importar…';
	@override String get export => 'Exportar…';
	@override String get resetAll => 'Restablecer todo';
	@override String get resetAllTitle => '¿Restablecer todos los atajos?';
	@override String get resetAllBody => 'Cada comando vuelve a sus teclas por defecto, y se quitan las teclas asignadas a comandos escritos.';
	@override String get reset => 'Restablecer';
	@override String get noKey => 'Sin tecla';
	@override String get changed => 'Modificado';
	@override String conflict({required Object keys, required Object commands}) => '${keys} también está asignado a ${commands}';
	@override String get groupApp => 'App';
	@override String get groupKeying => 'Manipulación';
	@override String get groupLogging => 'Logging';
	@override String get groupCommands => 'Comandos';
	@override String get groupFixed => 'Teclas fijas';
	@override String get contextApp => 'En cualquier lugar';
	@override String get contextLogView => 'Vistas de Operación, Cacería y Logs';
	@override String get contextOperation => 'Vista de operación, manipulando una radio CAT';
	@override String get contextLogging => 'En el panel de logging';
	@override String get addCommand => 'Agregar un comando…';
	@override String unknownCommand({required Object command}) => 'Comando desconocido: ${command}';
	@override late final _Translations$keyboardShortcuts$command$es command = _Translations$keyboardShortcuts$command$es._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$es fixed = _Translations$keyboardShortcuts$fixed$es._(_root);
	@override late final _Translations$keyboardShortcuts$editor$es editor = _Translations$keyboardShortcuts$editor$es._(_root);
	@override late final _Translations$keyboardShortcuts$file$es file = _Translations$keyboardShortcuts$file$es._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$es modifier = _Translations$keyboardShortcuts$modifier$es._(_root);
	@override late final _Translations$keyboardShortcuts$platform$es platform = _Translations$keyboardShortcuts$platform$es._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$es extends Translations$expiredBuild$en {
	_Translations$expiredBuild$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Este build ha expirado';
	@override String get body => 'Visita ham2k.com y consigue una versión más reciente.';
	@override String get visit => 'Visitar ham2k.com';
	@override String get dismiss => 'Continuar de todos modos';
}

// Path: staleness
class _Translations$staleness$es extends Translations$staleness$en {
	_Translations$staleness$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Hay una actualización importante';
	@override String get codePushFloorBody => 'Esta versión tiene una corrección que todavía no tienes.';
	@override String get restartToApply => 'Reinicia la app para aplicarla.';
	@override String get quitAndReopen => 'Cierra la app y vuelve a abrirla para aplicarla.';
	@override String get reopenToApply => 'Cierra la app y vuelve a abrirla para aplicarla.';
	@override String get ignoreForNow => 'Ignorar por ahora';
}

// Path: spotting
class _Translations$spotting$es extends Translations$spotting$en {
	_Translations$spotting$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Aún no hay ningún QSO registrado para hacer spot.';
	@override String get setFrequencyFirst => 'Primero establece una frecuencia.';
	@override String get nothingToSpot => 'Nada para hacer spot — ninguna extensión ofrece spotting aquí.';
	@override String get incompleteCall => 'No se puede hacer spot de un indicativo incompleto — termina el indicativo primero.';
	@override String spotFailed({required Object source, required Object message}) => '${source} falló: ${message}';
	@override String get unknownError => 'error desconocido';
	@override String get notSent => 'Spot no enviado.';
	@override String get allSkipped => 'Spot no enviado: todas las fuentes de spots lo omitieron.';
	@override String get notRefreshedOffline => 'Sin conexión — los spots no se actualizaron';
}

// Path: dataFiles
class _Translations$dataFiles$es extends Translations$dataFiles$en {
	_Translations$dataFiles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Descargando…';
	@override String downloadFailedTitle({required Object name}) => 'No se pudo descargar ${name}';
	@override String get downloadFailedWebHint => 'Esto podría ser un problema de red, o puede que el sitio de este enlace no permita descargas directas desde un navegador web. Prueba la app de escritorio o móvil, o un lugar de alojamiento diferente.';
	@override String get downloadTimedOut => 'El servidor tardó demasiado en responder. Vuelve a intentarlo más tarde.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} respondió con un error (HTTP ${status}). Vuelve a intentarlo más tarde.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} no pudo entregar este archivo (HTTP ${status}). Comprueba que su dirección siga siendo correcta.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM no tiene un archivo de historial de indicativos para ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'La descarga del historial de indicativos de N1MM para ${stem} no funcionó. Inténtalo de nuevo más tarde.';
	@override String processingFailedTitle({required Object name}) => 'No se pudo procesar ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'La descarga traía solo ${imported} de los ${existing} registros de este dispositivo, así que se conservaron los que faltaban. Actualizarla en Configuración › Datos sin conexión la acepta de todos modos.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se importó ${count} registro de ${label}.',
		other: 'Se importaron ${count} registros de ${label}.',
	);
	@override String importedData({required Object label}) => 'Se importaron datos de ${label}.';
	@override String get cleanedUpTitle => 'Se limpiaron datos de extensiones';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se eliminaron los datos de ${count} archivo de datos de extensiones deshabilitadas.',
		other: 'Se eliminaron los datos de ${count} archivos de datos de extensiones deshabilitadas.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} registros';
	@override String get definitionUnavailable => 'La fuente del archivo no proporcionó una definición — su extensión puede estar reiniciándose o mal configurada. Inténtalo de nuevo en un momento.';
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
	@override String get automaticChecks => 'Buscar automáticamente';
	@override String get automaticChecksDescription => 'Buscar nuevas versiones en segundo plano, a partir del próximo inicio';
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
	@override String commandMayNotChangeSettings({required Object name}) => '${name} no puede cambiar la configuración: no lo pidió al instalarse';
	@override String commandMayNotControlRadio({required Object name}) => '${name} no puede controlar la radio: no lo pidió al instalarse';
	@override String commandDeveloperOnly({required Object name}) => '${name} no puede ejecutar eso: es uno de los comandos de desarrollador propios de la app';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => 'Ahora mismo no se pueden enviar informes';
	@override String get stashUnavailable => 'No se puede acceder al File Stash de Ham2K en este momento';
	@override String activitySearchSourcesFailed({required Object names}) => 'Sin respuesta de ${names} a la búsqueda de actividades, así que pueden faltar algunos resultados.';
	@override String get activitySearchSomeSourcesFailed => 'Algunas extensiones de actividades no respondieron a la búsqueda, así que pueden faltar algunos resultados.';
	@override String timersSuspendedBudget({required Object name}) => '${name} pasó demasiado tiempo en sus temporizadores. Quedan detenidos hasta que se reinicien las extensiones.';
	@override String timersSuspendedFailures({required Object name}) => 'Los temporizadores de ${name} fallaban una y otra vez. Quedan detenidos hasta que se reinicien las extensiones.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} se trabó en un temporizador. Sus temporizadores quedan detenidos hasta que se reinicien las extensiones.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$es extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ubicación de la Operación';
	@override String get selectedLocation => 'Ubicación seleccionada';
	@override String get gridSquare => 'Grilla de Maidenhead';
	@override String get gridInvalid => 'Necesita 4, 6, 8 o 10 caracteres, como FN31pr';
	@override String get suggestedLocations => 'Ubicaciones sugeridas';
	@override String get deviceGps => 'GPS del dispositivo';
	@override String peerGps({required Object device}) => 'GPS de ${device}';
	@override String get locating => 'Localizando…';
	@override String get gpsUnavailable => 'Ubicación no disponible';
	@override String get permissionDenied => 'Permiso de ubicación denegado';
	@override String get permissionBlocked => 'Permiso de ubicación bloqueado';
	@override String get moreDetails => 'Más detalles';
	@override String get stateOrProvince => 'Estado o Provincia (opcional)';
	@override String get controlsUnavailableTitle => 'Controles de actividad no disponibles';
	@override String get controlsUnavailableReason => 'Estas referencias se pueden seguir usando; solo que no se pudo acceder a sus actividades.';
	@override String get controlsUnavailableRetry => 'Reintentar';
	@override String get county => 'Condado (opcional)';
}

// Path: versionLabel
class _Translations$versionLabel$es extends Translations$versionLabel$en {
	_Translations$versionLabel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versión ${version}';
	@override String patch({required Object patch}) => 'Parche ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$es extends Translations$notices$en {
	_Translations$notices$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Aún no hay avisos';
	@override String get webStorageInMemory => 'Este navegador no pudo ofrecer almacenamiento persistente — el log vive solo en memoria y se PERDERÁ al cerrar esta pestaña. Usa un Chrome, Firefox, Safari o Edge actual.';
	@override String get webStorageUnreliable => 'Este navegador está usando un almacenamiento de respaldo que no es seguro con varias pestañas — mantén una sola pestaña abierta, y la sincronización activada.';
	@override String get logFromNewerBuildTitle => 'Este log necesita una versión más nueva';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Tu log lo escribió una versión más nueva de HaLo (versión de almacenamiento ${storage}; esta entiende la ${understood}), así que no se puede abrir y los contactos nuevos no se guardarán. Vuelve a instalar la versión más nueva o, si querías usar este build, apúntalo a otra carpeta de datos. El log está en ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Tu log lo escribió una versión más nueva de HaLo (versión de almacenamiento ${storage}; esta entiende la ${understood}), así que no se puede abrir y los contactos nuevos no se guardarán. Ábrelo con esa versión más nueva.';
	@override String get preferencesRestoredTitle => 'Configuración restaurada desde un respaldo';
	@override String get preferencesRestored => 'No se pudo leer el archivo de configuración, así que HaLo restauró la última copia buena. Puede que tengas que volver a configurar lo que cambiaste en la sesión anterior. El archivo ilegible se conserva junto a ella, con el nombre shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Configuración restablecida';
	@override String get preferencesReset => 'No se pudo leer el archivo de configuración y no había ningún respaldo al que recurrir, así que HaLo empezó con sus valores por defecto. El archivo ilegible se conserva en la carpeta de datos de la app, con el nombre shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} no se conectó automáticamente';
	@override String autoConnectHeld({required Object name}) => 'HaLo dejó de responder la última vez que empezó a conectarse a ${name}, así que esta vez no lo intentó para no repetirlo. Comprueba que la radio esté encendida y su cable conectado, y luego pulsa Conectar en ella dentro de Configuración.';
}

// Path: syncAccount
class _Translations$syncAccount$es extends Translations$syncAccount$en {
	_Translations$syncAccount$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Cuenta Anónima (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (pendiente de confirmación)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (pendiente de confirmación - #${id})';
}

// Path: deepLink
class _Translations$deepLink$es extends Translations$deepLink$en {
	_Translations$deepLink$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Inicia una operación primero, y vuelve a enviar ese contacto';
	@override String get waitingInOperation => 'Ese contacto está esperando en la operación detrás de esta pantalla';
	@override String unknownActivities({required Object refs}) => 'Este dispositivo no tiene la actividad ${refs}, así que esas referencias quedaron fuera';
	@override String activitiesUnavailable({required Object refs}) => 'No se pudo consultar tus actividades, así que ${refs} quedó fuera — reintenta ese enlace';
}

// Path: confirmDevice
class _Translations$confirmDevice$es extends Translations$confirmDevice$en {
	_Translations$confirmDevice$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirmar un dispositivo';
	@override String get codePrompt => 'Ingresa el código que muestra el dispositivo que quiere unirse a esta cuenta.';
	@override String get code => 'Código';
	@override String get lookUp => 'Buscar';
	@override String get codeNotFound => 'Ninguna solicitud coincide con ese código. Los códigos caducan a los 10 minutos — pide uno nuevo en el otro dispositivo.';
	@override String get linkExpired => 'Ese enlace ha caducado. Pide al otro dispositivo que muestre un código QR nuevo.';
	@override String areYouSure({required Object device}) => '¿Vincular ${device} a esta cuenta?';
	@override String get unnamedDevice => 'un dispositivo sin nombre';
	@override String get grantWarning => 'Podrá leer y modificar todas las operaciones y QSOs de esta cuenta.';
	@override String get needsSyncTitle => 'Este dispositivo aún no sincroniza';
	@override String get needsSyncText => 'Activa la sincronización con Ham2K Log Filer y vincula este dispositivo a una cuenta antes de que pueda admitir a otro.';
	@override String get malformedRequest => 'El servidor envió una solicitud que esta app no pudo leer. Pide al otro dispositivo que lo intente de nuevo.';
	@override String get linkIt => 'Vincular dispositivo';
}

// Path: switchAccounts
class _Translations$switchAccounts$es extends Translations$switchAccounts$en {
	_Translations$switchAccounts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Aún sin detalles de la cuenta';
	@override String get currentAccount => 'Cuenta actual';
	@override String get otherAccounts => 'Otras cuentas';
	@override String get linkToAnother => 'Vincular a otra cuenta';
	@override String get linkWithSibling => 'Vincular con otra app de Ham2K';
	@override String get linkWithPolo => 'Vincular con la cuenta de la versión anterior';
	@override String get linkWithSiblingDescription => 'Tienes otra app de Ham2K instalada. Vincula con la cuenta en uso allí.';
	@override String siblingPrompt({required Object app}) => 'Aprueba la solicitud en ${app} y luego vuelve aquí.';
	@override String openSiblingAgain({required Object app}) => 'Abrir ${app} de nuevo';
	@override String get siblingNoGrant => '¿No funcionó? Ábrela de nuevo, o vuelve atrás y vincula de otra manera.';
	@override String siblingOpenFailed({required Object app}) => 'No se pudo abrir ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'El enlace caducó y hay uno nuevo — abre ${app} de nuevo.';
	@override String get tryAgain => 'Intentar de nuevo';
	@override String get linkWithQr => 'Vincular con un código QR';
	@override String get linkWithQrDescription => 'Escanéalo desde un dispositivo que ya use la cuenta';
	@override String get linkWithEmail => 'Vincular con una dirección de correo electrónico';
	@override String get linkWithEmailDescription => 'Confirma con un código o un enlace por correo electrónico';
	@override String get enterEmailPrompt => 'Ingresa la dirección de correo electrónico de la cuenta que quieres usar en este dispositivo.';
	@override String get emailAddress => 'Dirección de correo electrónico';
	@override String get linkAccount => 'Vincular cuenta';
	@override String get copiedCode => 'Código copiado al portapapeles';
	@override String get copyCode => 'Copiar código';
	@override String codePrompt({required Object email}) => 'Abre la app de Ham2K en un dispositivo ya vinculado con ${email} e ingresa este código para aprobar la solicitud:';
	@override String get waitingForConfirmation => 'Esperando confirmación…';
	@override String get sendEmailInstead => 'Enviar un correo de confirmación en su lugar';
	@override String emailSent({required Object email}) => 'Se envió un correo a ${email}. Ábrelo y confirma la solicitud para vincular este dispositivo.';
	@override String get resendEmail => 'Reenviar correo';
	@override String get qrPrompt => 'Escanea este código QR desde un dispositivo ya vinculado a la cuenta que quieres — por ejemplo, con Ham2K Portable Logger en tu teléfono.';
	@override String get serverUnreachable => 'No se pudo acceder al servidor de sincronización. Inténtalo más tarde.';
	@override String get emailRequired => 'Ingresa una dirección de correo electrónico para vincular.';
	@override String noAccountForEmail({required Object email}) => 'No se encontró ninguna cuenta para ${email}.';
	@override String serverRejected({required Object error}) => 'El servidor de sincronización rechazó la solicitud: ${error}';
	@override String get noLinkCode => 'El servidor de sincronización no devolvió un código de vinculación. Inténtalo más tarde.';
	@override String get noConfirmationCode => 'El servidor de sincronización no envió un código de confirmación. Inténtalo más tarde.';
	@override String get switchNotAccepted => 'Esa cuenta no aceptó el cambio. Prueba a vincularla con una dirección de correo electrónico.';
	@override String get requestFailed => 'Algo salió mal al comunicarse con el servidor de sincronización. Inténtalo más tarde.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} operación',
		other: '${count} operaciones',
	);
}

// Path: qsonImport
class _Translations$qsonImport$es extends Translations$qsonImport$en {
	_Translations$qsonImport$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar operación QSON';
	@override String get description => 'Crea una nueva operación a partir de un archivo QSON, como los que exporta el Modo Desarrollador aquí o en PoLo.';
	@override String get dropHint => 'Suelta un archivo QSON para importarlo como una nueva operación';
	@override String importing({required Object filename}) => 'Importando ${filename}…';
	@override String failed({required Object filename, required Object error}) => 'No se pudo importar ${filename}: ${error}';
	@override String pickerFailed({required Object error}) => 'No se pudo abrir un archivo para importar: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} no es texto UTF-8, así que no es un archivo QSON';
	@override String notJson({required Object filename}) => '${filename} no es un archivo JSON, así que no es un archivo QSON';
	@override String notOperation({required Object filename}) => '${filename} no contiene una operación QSON';
	@override String get busy => 'Ya hay una importación en curso. Espera a que termine antes de empezar otra.';
	@override String get oneFileOnly => 'Suelta un archivo QSON a la vez — cada uno se abre como su propia operación.';
}

// Path: adifImport
class _Translations$adifImport$es extends Translations$adifImport$en {
	_Translations$adifImport$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar QSOs desde ADIF';
	@override String reading({required Object filename}) => 'Leyendo ${filename}…';
	@override String get dropHint => 'Suelta un archivo ADIF para importarlo';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} QSO en este archivo',
		other: '${formatted} QSOs en este archivo',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} ya está en tu log',
		other: '${formatted} ya están en tu log',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} se importará',
		other: '${formatted} se importarán',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} contacto nuevo',
		other: '${formatted} contactos nuevos',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} se combinará con un contacto existente',
		other: '${formatted} se combinarán con contactos existentes',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} no se puede importar (sin indicativo)',
		other: '${formatted} no se pueden importar (sin indicativo)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} requiere revisión',
		other: '${formatted} requieren revisión',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'No se pudieron recuperar las referencias de ${count} contacto',
		other: 'No se pudieron recuperar las referencias de ${formatted} contactos',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Las referencias de ${programs} pueden estar incompletas en ${count} contacto',
		other: 'Las referencias de ${programs} pueden estar incompletas en ${formatted} contactos',
	);
	@override String get stackingTypesUnknown => 'Los contactos combinados podrían perder una referencia: las actividades no pudieron indicar qué tipos se acumulan. Cancela y reinténtalo para evitarlo.';
	@override String get nothingToImport => 'No hay nada importable en este archivo';
	@override String get confirm => 'Importar';
	@override String importing({required Object filename}) => 'Importando ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se importó ${count} contacto desde ${filename}',
		other: 'Se importaron ${formatted} contactos desde ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'No se pudo importar ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} no parece un archivo ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Atención: este ADIF tiene QSOs de ${calls}, pero se importarán como ${station} si continúas.';
	@override String get stationCallJoin => ' y ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} no tiene fecha y no se puede importar',
		other: '${formatted} no tienen fecha y no se pueden importar',
	);
	@override String activationFound({required Object refs}) => 'Este archivo registra una activación de ${refs}.';
	@override String get addActivation => 'Agregarla a esta operación';
	@override String shortfall({required Object written, required Object planned}) => 'Solo se aplicaron ${written} de ${planned} — el log cambió mientras decidías.';
	@override String get busy => 'Ya hay una importación en curso. Espera a que termine antes de empezar otra.';
	@override String get oneFileOnly => 'Suelta un archivo ADIF a la vez — el orden en que se importan decide qué datos prevalecen.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} tiene más de ${limit} QSOs, el máximo que una operación puede importar a la vez.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename} tiene más de ${limit} QSOs. Importar un ADIF en una operación está pensado para agregar unos pocos QSOs, no para traer un log grande — usa la vista de Logs para eso. El modo desarrollador te permite importarlo de todos modos, si estás seguro.';
	@override String get importAnyway => 'Importar de todos modos';
}

// Path: offline
class _Translations$offline$es extends Translations$offline$en {
	_Translations$offline$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: SIN CONEXIÓN';
	@override String get statusOnline => 'Internet: conectado';
	@override String get noRoute => 'No hay ninguna conexión de red.';
	@override String get unreachable => 'La red está activa, pero ningún servidor responde — a menudo es una página de inicio de sesión esperando en un navegador.';
	@override String get reachable => 'Todos los servicios responden con normalidad.';
	@override String get whatStops => 'Las búsquedas, los spots y los archivos de datos están en pausa. El logging y la sincronización cercana, no.';
	@override String get servicesTitle => 'Servicios';
	@override String get noServices => 'Todavía no ha respondido ningún servicio.';
	@override String lastSuccess({required Object when}) => 'Respondió por última vez hace ${when}';
	@override String get neverSucceeded => 'Todavía no ha respondido';
	@override String nextAttempt({required Object when}) => 'Próximo intento en ${when}';
	@override String get nextAttemptNow => 'Próximo intento pendiente';
	@override String get retry => 'Reintentar ahora';
	@override String get retrying => 'Intentando…';
	@override String get retryReached => 'Conexión restablecida.';
	@override String get retryUnreachable => 'Sigue sin responder.';
	@override String get retryNotAttempted => 'No hay nada que enviar ahora mismo.';
	@override String get retryThrottled => 'Acabas de intentarlo — espera un momento.';
	@override String get retryDisabled => 'La sincronización está apagada, así que no hay con qué sondear.';
	@override String get syncService => 'Sincronización Ham2K LoFi';
	@override String get retryInFlight => 'Ya se está intentando — un momento.';
}

// Path: exportSettings
class _Translations$exportSettings$es extends Translations$exportSettings$en {
	_Translations$exportSettings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Configuración base para todas las exportaciones, con plantillas de nombre de archivo y título separadas para actividades de referencia y otras actividades. Cada tipo de exportación puede proporcionar sus propios valores por defecto o configuración personalizada.';
	@override String get referenceActivities => 'Actividades de Referencia';
	@override String get otherActivities => 'Otras Actividades';
	@override String get adifFields => 'Campos ADIF';
	@override String get loadFailed => 'No se pudo cargar la configuración de exportación.';
	@override String get retry => 'Reintentar';
	@override String get compactFileNamesDescriptionOn => 'Nombres compactos, como N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Nombres descriptivos, como 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Incluyendo nombres, direcciones, correos, notas y ubicaciones precisas en los archivos ADIF.';
	@override String get includePrivateDataDescriptionOff => 'Omitiendo nombres, direcciones, correos y notas; limitando las ubicaciones a grillas de seis caracteres.';
	@override String get includeLookupDataDescriptionOn => 'Incluyendo la información de los servicios de búsqueda de indicativos.';
	@override String get includeLookupDataDescriptionOff => 'Omitiendo la información de los servicios de búsqueda de indicativos; conservando los valores ingresados manualmente.';
	@override String get customTemplatesDescriptionOn => 'Tus plantillas personalizadas están activas y se pueden editar a continuación.';
	@override String get customTemplatesDescriptionOff => 'Se usan las plantillas por defecto. Tus plantillas personalizadas se conservan para más adelante.';
	@override String get type => 'Tipo de exportación';
	@override String get defaults => 'Por defecto';
	@override String get includeLookupData => 'Incluir datos de búsqueda';
	@override String get customTemplates => 'Plantillas personalizadas';
	@override String get filenameTemplate => 'Plantilla de Nombre de Archivo';
	@override String get compactFilenameTemplate => 'Plantilla de nombre de archivo compacto';
	@override String get titleTemplate => 'Plantilla de Título';
	@override String get adifNotesTemplate => 'Notas de QSO en ADIF';
	@override String get adifCommentTemplate => 'Comentarios de QSO en ADIF';
	@override String get adifQslMessageTemplate => 'Mensaje de QSL en ADIF';
	@override String get shared => 'La configuración se aplica a todas las extensiones que usan este tipo de exportación.';
	@override String get defaultTemplates => 'Activa Plantillas personalizadas para editar las plantillas de este tipo.';
}

// Path: templateEditor
class _Translations$templateEditor$es extends Translations$templateEditor$en {
	_Translations$templateEditor$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Vista previa:';
	@override String get reset => 'Restablecer';
	@override String get docs => 'Documentación de plantillas';
	@override String get preview => 'Vista previa de ejemplo';
	@override String get reference => 'Referencia de plantillas';
	@override String get attributes => 'Atributos disponibles';
	@override String get filters => 'Filtros';
	@override String get flowControl => 'Control de flujo';
	@override String get unavailable => 'La vista previa no está disponible hasta que las extensiones estén listas.';
	@override String get empty => '(resultado vacío)';
}

// Path: home.nav
class _Translations$home$nav$es extends Translations$home$nav$en {
	_Translations$home$nav$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operaciones';
	@override String get chase => 'Cacería';
	@override String get logs => 'Logs';
	@override String get maps => 'Mapas';
	@override String get settings => 'Configuración';
}

// Path: home.panels
class _Translations$home$panels$es extends Translations$home$panels$en {
	_Translations$home$panels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Lista de Operaciones';
	@override String get operationsDescription => 'Tus operaciones, la más reciente primero.';
	@override String get version => 'Versión actual';
	@override String get versionDescription => 'La marca Ham2K, el nombre de esta app y qué build estás usando.';
}

// Path: home.logs
class _Translations$home$logs$es extends Translations$home$logs$en {
	_Translations$home$logs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logs';
	@override String get titleFor => 'Logs de';
	@override String get emptyCallsigns => 'Aún no hay QSOs registrados';
	@override String emptyQsos({required Object call}) => 'No hay QSOs para ${call}';
	@override String get mapNoSelection => 'Selecciona un QSO para verlo en el mapa';
	@override String get searchHint => 'Buscar indicativo o nombre';
	@override String get noSearchMatches => 'Ningún QSO coincide con tu búsqueda';
	@override String get titleAll => 'Todos los logs';
	@override String get allCallsigns => 'Todos los indicativos';
	@override String get noOperation => 'No forma parte de ninguna operación';
	@override String get unsavedTitle => 'Cambios sin guardar';
	@override String get unsavedBody => 'Este QSO tiene cambios que no has guardado.';
	@override String get pendingDeleteBody => 'Este QSO está marcado para eliminarse.';
	@override String get editGone => 'No se guardó: ese QSO ya no está en este log.';
	@override String get discard => 'Descartar';
	@override late final _Translations$home$logs$sheet$es sheet = _Translations$home$logs$sheet$es._(_root);
	@override late final _Translations$home$logs$groupBy$es groupBy = _Translations$home$logs$groupBy$es._(_root);
	@override late final _Translations$home$logs$period$es period = _Translations$home$logs$period$es._(_root);
	@override late final _Translations$home$logs$periodTitle$es periodTitle = _Translations$home$logs$periodTitle$es._(_root);
	@override late final _Translations$home$logs$columns$es columns = _Translations$home$logs$columns$es._(_root);
	@override late final _Translations$home$logs$panels$es panels = _Translations$home$logs$panels$es._(_root);
	@override late final _Translations$home$logs$import$es import = _Translations$home$logs$import$es._(_root);
}

// Path: chase.station
class _Translations$chase$station$es extends Translations$chase$station$en {
	_Translations$chase$station$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estación cazadora';
	@override String get stationLabel => 'Estación: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Sin ubicación';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$es extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get today => 'hoy';
	@override String get thisWeek => 'esta semana';
	@override String get last14Days => 'en los últimos 14 días';
	@override String get thisMonth => 'este mes';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$es extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get today => 'Estadísticas de hoy';
	@override String get thisWeek => 'Estadísticas de esta semana';
	@override String get last14Days => 'Estadísticas de los últimos 14 días';
	@override String get thisMonth => 'Estadísticas de este mes';
}

// Path: chase.period
class _Translations$chase$period$es extends Translations$chase$period$en {
	_Translations$chase$period$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get today => 'Hoy';
	@override String get thisWeek => 'Esta semana';
	@override String get last14Days => 'Últimos 14 días';
	@override String get thisMonth => 'Este mes';
}

// Path: chase.goals
class _Translations$chase$goals$es extends Translations$chase$goals$en {
	_Translations$chase$goals$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Objetivos de cacería';
	@override String remove({required Object name}) => 'Dejar de cazar ${name}';
	@override String get extensionsTitle => 'Más programas de cacería';
}

// Path: chase.panels
class _Translations$chase$panels$es extends Translations$chase$panels$en {
	_Translations$chase$panels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Controles de logging sobre los QSOs cazados en el período.';
	@override String get info => 'Info';
	@override String get infoDescription => 'El indicativo que se está registrando, o las estadísticas del período.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Estaciones con spots en el aire, listas para cazar.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Los QSOs del período y la estación que se está registrando.';
}

// Path: chase.claims
class _Translations$chase$claims$es extends Translations$chase$claims$en {
	_Translations$chase$claims$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get checking => 'Revisando QSOs para cacería';
	@override String rebuilding({required Object program}) => 'Revisando el log para ${program}';
	@override String progress({required Object done, required Object total}) => '${done} de ${total} QSOs';
}

// Path: chase.notice
class _Translations$chase$notice$es extends Translations$chase$notice$en {
	_Translations$chase$notice$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'Nuevo ${program}';
	@override String newRefGuess({required Object program}) => 'Probablemente nuevo ${program}';
	@override String newBand({required Object program}) => 'Nueva banda ${program}';
	@override String newBandGuess({required Object program}) => 'Probablemente nueva banda ${program}';
	@override String newMode({required Object program}) => 'Nuevo modo ${program}';
	@override String newModeGuess({required Object program}) => 'Probablemente nuevo modo ${program}';
	@override String unconfirmed({required Object program}) => '${program} sin confirmar';
	@override String programGuess({required Object notice}) => 'Probablemente ${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$es extends Translations$chase$alerts$en {
	_Translations$chase$alerts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Alertas';
	@override String get newRef => 'Nueva referencia';
	@override String get newBand => 'Nueva banda';
	@override String get newMode => 'Nuevo modo';
	@override String get unconfirmed => 'Sin confirmar';
}

// Path: chase.imports
class _Translations$chase$imports$es extends Translations$chase$imports$en {
	_Translations$chase$imports$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'Importar ${label}';
	@override String pickTitle({required Object file}) => 'Importar ${file} como';
	@override String get dropHint => 'Suelta un archivo para importarlo en un programa de cacería';
	@override String done({required Object count, required Object program, required Object file}) => 'Se importaron ${count} entradas de ${program} desde ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'Se importaron ${count} entradas de ${program} desde ${file}; se omitieron ${skipped} que no pudo leer';
	@override String nothing({required Object file, required Object program}) => '${file} no tiene nada que ${program} pueda importar';
	@override String failed({required Object program, required Object file}) => '${program} no pudo leer ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} no pudo leer ninguno de los ${skipped} registros de ${file}';
	@override String noProgram({required Object file}) => 'Ningún programa de cacería importa ${file}';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$es extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => '¿Buscar en línea?';
	@override String get body => 'La asistencia está deshabilitada para esta operación. Buscar los datos de todos los QSOs usará servicios en línea como QRZ solo por esta vez.';
	@override String bodyRules({required Object rules}) => 'La asistencia está deshabilitada para esta operación para cumplir las reglas de ${rules}. Buscar los datos de todos los QSOs usará servicios en línea como QRZ solo por esta vez.';
	@override String get action => 'Buscar en línea';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$es extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicativo inválido: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicativos inválidos: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} ha operado hasta ahora. ${typed} se registrará en los nuevos contactos.';
	@override String operatorNoneSoFar({required Object typed}) => 'Ningún operador registrado hasta ahora. ${typed} se registrará en los nuevos contactos.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Esta operación ya tiene contactos de ${calls}. ${typed} solo se registrará en los nuevos.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Registrar también a ${typed} como operador del contacto ya registrado',
		other: 'Registrar también a ${typed} como operador de los ${count} contactos ya registrados',
	);
	@override String get operatorSeveralStations => 'Cuando se usan varias estaciones al aire, no hay soporte para operadores separados';
	@override String get contactsUnreadable => 'No se pudieron leer los contactos de esta operación, así que cambiar un indicativo aquí no ofrecerá actualizarlos';
	@override String restampFailed({required Object error}) => 'No se pudieron actualizar los contactos ya registrados, así que no se cambió nada: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => 'Se actualizaron ${written} de ${planned} contactos — el resto ya no está en esta operación';
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
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Reloj';
	@override String get weather => 'Clima';
	@override String get website => 'Sitio web';
	@override String get remoteScreen => 'Pantalla remota';
	@override String get solar => 'Solar';
	@override String get radio => 'Radio';
	@override String get rotator => 'Rotor';
	@override String get summaries => 'Resúmenes de la operación';
}

// Path: operation.positions
class _Translations$operation$positions$es extends Translations$operation$positions$en {
	_Translations$operation$positions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Ninguna otra posición de operación comparte esta operación todavía.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Otra posición';
	@override String get thisDevice => 'Nuestra posición de operación';
	@override String get nameIn => ' en ';
	@override String get panelTitle => 'Posiciones';
	@override String get panelDescription => 'Lo que cada posición de operación que comparte esta operación está registrando ahora mismo.';
}

// Path: operation.menu
class _Translations$operation$menu$es extends Translations$operation$menu$en {
	_Translations$operation$menu$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostrar campos RST';
	@override String get showStateField => 'Mostrar campo de estado';
	@override String get showGridField => 'Mostrar campo de grilla';
	@override String get showDeletedQsos => 'Mostrar QSOs eliminados';
	@override String get showDeletedOps => 'Mostrar operaciones eliminadas';
	@override String get showQsoNumbers => 'Mostrar números de QSO';
	@override String get lookupAllQsos => 'Buscar datos de todos los QSOs';
	@override String get loggingSettingsTitle => 'Configuración de Logging';
	@override String get mapSettingsTitle => 'Configuración del mapa';
	@override String get actionsSection => 'Acciones';
}

// Path: operation.layout
class _Translations$operation$layout$es extends Translations$operation$layout$en {
	_Translations$operation$layout$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Agregar un panel';
	@override String get availableSection => 'Paneles disponibles';
	@override String panelSettings({required Object panel}) => 'Configuración de ${panel}';
	@override String get panelSettingsAction => 'Configuración del panel';
	@override String get viewName => 'Vista de operación';
	@override String get viewOptions => 'Opciones de disposición de la vista';
	@override String get viewTitleBuiltIn => 'Esta vista viene integrada en la app, y su nombre también';
	@override String get resetOptions => 'Restaurar valores por defecto';
	@override String get removePane => 'Quitar';
	@override String resetPaneConfirm({required Object panel}) => '¿Restaurar ${panel} a sus valores por defecto?';
	@override String get resetPaneConfirmBody => 'Su título, encabezado y tamaño vuelven a los valores por defecto. El resto de la disposición no cambia.';
	@override String get resetViewConfirm => '¿Restaurar la disposición por defecto de esta vista?';
	@override String get resetViewConfirmBody => 'Los paneles vuelven a su disposición por defecto, y las opciones de la vista y las de cada panel vuelven a sus valores por defecto.';
	@override String paneOptionsTitle({required Object panel}) => 'Configuración de disposición de ${panel}';
	@override String get paneTitle => 'Título';
	@override String get paneShowHeader => 'Mostrar encabezado';
	@override String get paneShowHeaderTabset => 'Siempre visible mientras este panel comparte un grupo — el encabezado es cómo se llega a los demás';
	@override String get paneInherit => 'Igual que la app';
	@override String get searchHint => 'Buscar paneles';
	@override String get noPanelsMatch => 'Ningún panel coincide con tu búsqueda.';
	@override String get nothingToAdd => 'Esta vista ya tiene todos los paneles posibles';
	@override String addPanel({required Object panel}) => 'Agregar ${panel}';
	@override String showPreview({required Object panel}) => 'Vista previa de ${panel}';
	@override String missingExtension({required Object name}) => 'Falta la extensión "${name}"';
	@override String get missingExtensionEnable => 'Habilitar';
	@override String get missingExtensionInstall => 'Instalar…';
	@override String get missingExtensionWontRun => 'Esta versión no funcionará. Actualízala en Configuración › Extensiones.';
	@override String get missingExtensionUnavailable => 'No disponible en esta app';
	@override String get missingExtensionNotInCatalog => 'No está en el catálogo';
	@override String get missingExtensionCatalogUnreachable => 'No se pudo acceder al catálogo. Inténtalo de nuevo';
	@override String get missingExtensionFailed => 'Eso no funcionó. Inténtalo de nuevo';
	@override String get previewUnavailable => 'No se pudo mostrar la imagen de vista previa de este panel.';
	@override String get nestedPaneTitle => 'Más';
	@override late final _Translations$operation$layout$layouts$es layouts = _Translations$operation$layout$layouts$es._(_root);
	@override String get editLayout => 'Editar disposición';
	@override String get saveLayout => 'Guardar disposición';
	@override String get revertLayout => 'Descartar los cambios de disposición';
	@override String get done => 'Listo';
	@override String get layoutUnreadableTitle => 'No se pudo leer la disposición';
	@override String get layoutUnreadableBody => 'No se pudo leer tu disposición guardada, así que se muestra la disposición por defecto. No se guardará sobre la original hasta que elijas conservarla.';
	@override String get layoutUnreadableAction => 'Usar esta disposición';
	@override String panelRenderFailed({required Object panel}) => 'No se pudo mostrar ${panel}';
	@override String panelOverCharacters({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: envió más de ${max} caracteres';
	@override String panelOverElements({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su gráfico tiene más de ${max} elementos';
	@override String panelOverDepth({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su gráfico anida más de ${max} niveles';
	@override String panelNotArtwork({required Object panel}) => 'No se pudo mostrar ${panel}: su gráfico no es autocontenido';
	@override String panelOverLayers({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su escena tiene más de ${max} capas';
	@override String panelOverControls({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su escena tiene más de ${max} controles';
	@override String panelOverItems({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: parte de su escena tiene más de ${max} entradas';
	@override String panelOverStringLength({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: una cadena de la escena supera los ${max} caracteres';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su disposición anida más de ${max} niveles';
	@override String get panelRenderRetry => 'Reintentar';
	@override String get panelActionFailed => 'Esa acción del panel falló. Inténtalo de nuevo.';
	@override late final _Translations$operation$layout$panels$es panels = _Translations$operation$layout$panels$es._(_root);
	@override String get htmlPanelUnsupported => 'Este panel necesita un visor web, que esta plataforma no ofrece';
	@override String get htmlPanelUnsupportedOnWeb => 'Este panel necesita un entorno aislado que la versión web no puede ofrecer';
}

// Path: operation.export
class _Translations$operation$export$es extends Translations$operation$export$en {
	_Translations$operation$export$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportaciones de la operación';
	@override String get syncedOperation => 'La operación está sincronizada';
	@override String get unsyncedOperation => 'La operación tiene cambios sin sincronizar';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} QSO en esta operación',
		other: '${count} QSOs en esta operación',
	);
	@override String qsosSynced({required Object total}) => 'Los ${total} QSOs están sincronizados';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendientes de sincronizar';
	@override String eventsSynced({required Object total}) => '${total} marcadores de evento sincronizados';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendientes';
	@override String get loading => 'Cargando opciones de exportación…';
	@override String get noOptions => 'No hay formatos de exportación disponibles (¿el motor de extensiones aún está iniciando?)';
	@override String get nothingLogged => 'Nada que exportar todavía — esta operación no tiene QSOs.';
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
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Almacenar ${count} archivo',
		other: 'Almacenar ${count} archivos',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Almacenar ${count} archivo combinado',
		other: 'Almacenar ${count} archivos combinados',
	);
	@override String get settingsButton => 'Configuración de exportación';
	@override String get settingsTitle => 'Configuración de Exportación';
	@override late final _Translations$operation$export$compactFileNames$es compactFileNames = _Translations$operation$export$compactFileNames$es._(_root);
	@override late final _Translations$operation$export$includePrivateData$es includePrivateData = _Translations$operation$export$includePrivateData$es._(_root);
	@override String get resultTitle => 'Exportación completa';
	@override String get resultFailedTitle => 'Exportación fallida';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se exportó ${count} archivo a ${path}',
		other: 'Se exportaron ${count} archivos a ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se exportó ${count} archivo: ${path}',
		other: 'Se exportaron ${count} archivos: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se compartió ${count} archivo',
		other: 'Se compartieron ${count} archivos',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se descargó ${count} archivo',
		other: 'Se descargaron ${count} archivos',
	);
	@override String exportFailed({required Object error}) => 'Exportación fallida: ${error}';
	@override late final _Translations$operation$export$stash$es stash = _Translations$operation$export$stash$es._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$es extends Translations$operation$spots$en {
	_Translations$operation$spots$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ningún spot coincide con tus filtros';
	@override String error({required Object error}) => 'No se pudieron cargar los spots: ${error}';
	@override String get unknownBand => 'Otra';
	@override String get auto => 'Automático';
	@override String autoValue({required Object value}) => 'Automático (Actualmente ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Cualquiera';
	@override String get allBands => 'Todas las Bandas';
	@override String get allModes => 'Todos los Modos';
	@override String get phoneAndCw => 'Fonía y CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots';
	@override String get spotsDisabled => 'Spots deshabilitados para esta operación';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutos';
	@override String get callsOfNote => 'Indicativos con Notas';
	@override String get yourSpots => 'Tus Spots';
	@override String get allSpots => 'Todos los Spots';
	@override late final _Translations$operation$spots$continents$es continents = _Translations$operation$spots$continents$es._(_root);
	@override late final _Translations$operation$spots$filters$es filters = _Translations$operation$spots$filters$es._(_root);
	@override String get unavailableTitle => 'Spots no disponibles';
	@override String unavailableText({required Object sources}) => '${sources} no respondieron.';
	@override String get failedTitle => 'Error en fuente de spots';
	@override String failedText({required Object sources}) => '${sources} devolvieron un error.';
	@override String get slideLogIt => 'Registrar';
	@override String get slideIgnore => 'Ignorar';
	@override String get slideRestore => 'Restaurar';
	@override late final _Translations$operation$spots$logConflict$es logConflict = _Translations$operation$spots$logConflict$es._(_root);
}

// Path: operation.import
class _Translations$operation$import$es extends Translations$operation$import$en {
	_Translations$operation$import$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar datos a la operación';
	@override String get importAdifAction => 'Importar QSOs desde ADIF';
	@override String get settingsButton => 'Configuración de escucha';
	@override String get settingsTitle => 'Escuchar otras apps';
	@override String get protocolAddressLabel => 'Dirección';
	@override String get protocolPortLabel => 'Puerto';
	@override String get protocolPortInvalid => 'Introduce un puerto entre 1 y 65535';
	@override String get protocolAddressInvalid => 'Introduce una dirección IP válida (p. ej. 127.0.0.1 o 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Recibiendo datos';
	@override String get protocolStatusNoData => 'No se han recibido datos recientemente';
	@override String protocolBindError({required Object error}) => 'No se pudo empezar a escuchar: ${error}';
	@override String captureFailed({required Object error}) => 'Los QSOs entrantes no se pudieron guardar y se están reintentando: ${error}';
	@override String get n1mmProtocolName => 'Difusión de contactos de N1MM+';
	@override String get n1mmAddressValue => 'Cualquiera (difusión)';
	@override String get wsjtxProtocolName => 'Servidor UDP de WSJT-X';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → pestaña Broadcast Data → marca "Enable Broadcasts" para la información de contactos. Pon la dirección IP en 127.0.0.1 si se ejecuta en esta misma computadora, o 255.255.255.255 para difundir en la red local actual.';
	@override String get helpWsjtxSetup => 'File → Settings → pestaña Reporting → sección UDP Server → marca "Accept UDP requests". Pon UDP Server en 127.0.0.1 si se ejecuta en esta misma computadora, o una dirección multicast como 239.239.0.2, y usa esa misma dirección en la configuración de arriba en esta app.';
	@override String get listenTitle => 'Escuchar QSOs de otras apps';
	@override String get listenDescriptionOnN1mm => 'Escuchando a N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Escuchando a WSJT-X';
	@override String get listenDescriptionOnBoth => 'Escuchando a N1MM+ y WSJT-X';
	@override String get listenDescriptionOff => 'Desactivado';
	@override String get addToOperationTitle => 'Agregar a esta operación';
	@override String get addToOperationDescriptionOn => 'Los QSOs capturados se agregan a esta operación según llegan';
	@override String get addToOperationDescriptionOff => 'Los QSOs capturados se retienen hasta que actives esto';
	@override String get pendingSectionTitle => 'QSOs capturados';
	@override String get pendingEmpty => 'Nada capturado todavía';
	@override String stationMismatch({required Object call}) => 'Registrado con ${call}, que no es la estación de esta operación';
	@override String get discardAction => 'Descartar';
	@override String get gapDialogTitle => '¿Incluir capturas anteriores?';
	@override String gapDialogBody({required Object count}) => 'Antes se capturaron ${count} QSOs más, previos a un salto en los datos. ¿Incluirlos también?';
	@override String get gapDialogRecentOnly => 'Solo los recientes';
	@override String gapDialogIncludeAll({required Object count}) => 'Incluir los ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$es extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get link => '¿Problemas?';
	@override String get title => 'Informar un problema con un contorno';
	@override String get reference => 'Qué contorno';
	@override String get severity => '¿Qué tan grave es?';
	@override String get minor => 'Detalle menor';
	@override String get major => 'Algo serio';
	@override String get explanation => '¿Qué está mal?';
	@override String get explanationHint => 'Qué tiene mal el contorno, y dónde';
	@override String get send => 'Enviar';
	@override String get sending => 'Enviando tu informe — gracias';
	@override String get copy => 'Copiar informe';
	@override String get notSent => 'No se pudo enviar el informe';
	@override String get copied => 'Informe copiado';
	@override String get notCopied => 'No se pudo copiar el informe';
}

// Path: map.postcard
class _Translations$map$postcard$es extends Translations$map$postcard$en {
	_Translations$map$postcard$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get button => 'Postal de la operación';
	@override String title({required Object title}) => 'Postal de ${title}';
	@override String get portrait => 'Vertical';
	@override String get landscape => 'Horizontal';
	@override String get square => 'Cuadrada';
	@override String get save => 'Guardar…';
	@override String get download => 'Descargar';
	@override String get share => 'Compartir';
	@override String get copy => 'Copiar';
	@override String get copied => 'Copiada al portapapeles';
	@override String saved({required Object path}) => 'Guardada en ${path}';
	@override String downloaded({required Object name}) => 'Se descargó ${name}';
	@override String savedMany({required Object count, required Object path}) => 'Se guardaron ${count} imágenes en ${path}';
	@override String savedFiles({required Object names}) => 'Se guardaron ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ya se habían guardado ${names}';
	@override String downloadedMany({required Object count}) => 'Descargando ${count} imágenes — permítelas si el navegador pregunta';
	@override String get mapLeftOut => 'El mapa no cargó, así que quedó fuera';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — el mapa no cargó, así que quedó fuera';
	@override String continued({required Object title}) => '${title} (continuación)';
	@override String get previousPage => 'Página anterior';
	@override String get nextPage => 'Página siguiente';
	@override String pageOf({required Object page, required Object count}) => 'Página ${page} de ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} Q',
		other: '${count} Qs',
	);
	@override String get options => 'Opciones de la postal';
	@override String get bandLegend => 'Mostrar leyenda de bandas';
	@override String get grayline => 'Mostrar línea gris';
	@override String get sectionsAndOrder => 'Secciones del resumen y orden';
	@override String get sectionDays => 'Cada día';
	@override String get reset => 'Restablecer';
	@override String failed({required Object error}) => 'No se pudo crear la postal: ${error}';
	@override String get mapNotReady => 'El mapa no terminó de cargar. Revisa la conexión y vuelve a intentarlo.';
	@override String saveFailed({required Object error}) => 'No se pudo guardar la postal: ${error}';
	@override String get copyFailed => 'El portapapeles no aceptó la imagen. Vuelve a intentarlo.';
	@override String get shareFailed => 'No se pudo compartir la postal. Vuelve a intentarlo.';
	@override String get fileName => 'postal';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$es extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Aún no hay QSOs... ¡Vamos al aire!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} en ${time}';
	@override String sinceLast({required Object time}) => '${time} desde el último';
	@override String ratePer10({required Object rate}) => '${rate} Q/h en los últimos 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h en los últimos 100';
	@override String distanceTo({required Object distance}) => '${distance} a';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) a';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => '¡Dup!';
	@override String get noticeNewBand => 'Nueva Banda';
	@override String get noticeNewMode => 'Nuevo Modo';
	@override String get noticeNewDXCC => 'Nuevo DXCC';
	@override String get noticeNewState => 'Nuevo Estado';
	@override String get noticeNewProvince => 'Nueva Provincia';
	@override String get noticeNewDay => 'Nuevo Día';
	@override String get noticeNewRef => 'Nueva Ref';
	@override String get noticeNewMult => 'Nuevo Mult';
	@override String get noticeNewZone => 'Nueva Zona';
	@override String get noticeInvalidMode => 'Modo Incorrecto';
	@override String get noticeInvalidBand => 'Banda Incorrecta';
	@override String get noticeInvalidCategory => 'No Contactable';
	@override String get noticeOverTime => 'Fuera de Tiempo';
	@override String get noticeWorkedBefore => 'Ya Trabajado';
	@override String get noticeNewPark => 'Nuevo Parque';
	@override String get noticeNewSection => 'Nueva Sección';
	@override String get noticeBonusStation => '¡Estación Bonus!';
	@override String get noticeMissingExchange => 'Sin Intercambio';
	@override String get noticeInvalidExchange => 'Intercambio Inválido';
	@override String get noticeUnknownEvent => 'Evento Desconocido';
	@override String get noticeIncompleteCall => 'Indicativo Incompleto — No Puntúa';
	@override String get noticeOurGrid => 'Falta Nuestra Grilla';
	@override String get noticeRareCounty => '¡Condado Raro!';
	@override String get noticeOurLocation => 'Falta Nuestro Condado';
	@override String get noticeShortGrid => 'Grilla Muy Corta';
}

// Path: qsoList.find
class _Translations$qsoList$find$es extends Translations$qsoList$find$en {
	_Translations$qsoList$find$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'Buscar en el log (${shortcut})';
	@override String get menuItemNoShortcut => 'Buscar en el log';
	@override String get hint => 'Número de QSO o indicativo';
	@override String get noMatches => 'Sin coincidencias';
	@override String get noOperationQsos => 'No hay QSOs en esta operación';
	@override String get noPeriodQsos => 'No hay QSOs en este período';
	@override String get outsideQsosOne => '1 QSO fuera de esta operación';
	@override String outsideQsosOther({required Object count}) => '${count} QSOs fuera de esta operación';
	@override String get pastQsosOne => '1 QSO anterior';
	@override String pastQsosOther({required Object count}) => '${count} QSOs anteriores';
}

// Path: callInfo.history
class _Translations$callInfo$history$es extends Translations$callInfo$history$en {
	_Translations$callInfo$history$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} en los últimos 7 días';
	@override String today({required Object n}) => '${n} hoy';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class _Translations$settings$theme$es extends Translations$settings$theme$en {
	_Translations$settings$theme$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tema';
	@override String get system => 'Seguir la configuración del sistema';
	@override String get light => 'Claro';
	@override String get dark => 'Oscuro';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$es extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Siguiendo la configuración del sistema';
	@override String get light => 'Siempre en Modo Claro';
	@override String get dark => 'Siempre en Modo Oscuro';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$es extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Más pequeño--';
	@override String get smallestMinus => 'Más pequeño-';
	@override String get smallest => 'Más pequeño';
	@override String get smaller => 'Pequeño';
	@override String get normal => 'Normal';
	@override String get larger => 'Grande';
	@override String get largest => 'Más grande';
	@override String get largestPlus => 'Más grande+';
	@override String get largestPlusPlus => 'Más grande++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$es extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mantener dispositivo encendido';
	@override String get descriptionOn => 'Pantalla encendida mientras estás en la vista de logging o hay una sincronización en curso';
	@override String get descriptionOff => 'Permitiendo que la pantalla se bloquee como siempre';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$es extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automática';
	@override String get densest => 'Muy compacta';
	@override String get dense => 'Compacta';
	@override String get normal => 'Normal';
	@override String get sparse => 'Amplia';
	@override String get sparsest => 'Muy amplia';
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
	@override String get title => 'Logging';
	@override late final _Translations$settings$logging$leftieMode$es leftieMode = _Translations$settings$logging$leftieMode$es._(_root);
	@override late final _Translations$settings$logging$countryFlags$es countryFlags = _Translations$settings$logging$countryFlags$es._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$es countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$es._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$es suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$es._(_root);
	@override late final _Translations$settings$logging$showBearing$es showBearing = _Translations$settings$logging$showBearing$es._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$es showReverseBearing = _Translations$settings$logging$showReverseBearing$es._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$es switchSentRcvd = _Translations$settings$logging$switchSentRcvd$es._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$es jumpAfterRST = _Translations$settings$logging$jumpAfterRST$es._(_root);
	@override late final _Translations$settings$logging$defaultReport$es defaultReport = _Translations$settings$logging$defaultReport$es._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$es defaultReportCW = _Translations$settings$logging$defaultReportCW$es._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$es defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$es._(_root);
	@override late final _Translations$settings$logging$numbersRow$es numbersRow = _Translations$settings$logging$numbersRow$es._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$es numbersRowExtra = _Translations$settings$logging$numbersRowExtra$es._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$es numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$es._(_root);
	@override String get bands => 'Bandas preferidas';
	@override String get modes => 'Modos preferidos';
}

// Path: settings.catServer
class _Translations$settings$catServer$es extends Translations$settings$catServer$en {
	_Translations$settings$catServer$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor CAT';
	@override String get description => 'Permite que otras apps (WSJT-X, programas de log, etc.) controlen la radio a través de Ham2K Logger.';
	@override String get protocol => 'Protocolo';
	@override late final _Translations$settings$catServer$protocolOpts$es protocolOpts = _Translations$settings$catServer$protocolOpts$es._(_root);
	@override String get port => 'Puerto';
	@override String get openAccess => 'Acceso abierto';
	@override String get openAccessOn => 'Cualquier computadora de la red local puede conectarse.';
	@override String get openAccessOff => 'Solo las apps de esta computadora pueden conectarse.';
	@override String get allowTransmit => 'Permitir que las apps transmitan';
	@override String allowTransmitOn({required Object minutes}) => 'Las apps pueden activar el PTT de la radio, hasta ${minutes} minutos seguidos.';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'Las apps de cualquier computadora de la red local pueden activar el PTT de la radio, hasta ${minutes} minutos seguidos.';
	@override String get allowTransmitOff => 'Las apps no pueden activar el PTT de la radio. Usa VOX o su propia configuración de PTT.';
	@override String get allowTransmitUnsupported => 'La radio del VFO principal no puede ponerse en transmisión desde Ham2K Logger, así que las apps no pueden transmitir a través de ella.';
	@override String get off => 'Apagado.';
	@override String starting({required Object protocol}) => '${protocol}, iniciando…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} en el puerto ${port}. Clientes conectados: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} en el puerto ${port}, pero no hay una radio del VFO principal conectada.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} no puede escuchar en el puerto ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} no puede escuchar en el puerto ${port}: otro programa lo está usando, a menudo el propio ${protocol}. Cierra ese programa o elige otro puerto.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} no puede escuchar en el puerto ${port}: esta computadora no lo permite. Elige un puerto por encima de 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} dejó de escuchar en el puerto ${port}. Reintentando…';
}

// Path: settings.cluster
class _Translations$settings$cluster$es extends Translations$settings$cluster$en {
	_Translations$settings$cluster$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Clúster DX';
	@override String get description => 'El servidor donde las extensiones publican y leen spots, con sesión iniciada como el operador.';
	@override String get connect => 'Conectar al clúster';
	@override String get connectOn => 'Las extensiones se conectan al clúster cuando lo necesitan';
	@override String get connectOff => 'Nada se conecta al clúster';
	@override String get console => 'Mostrar consola';
	@override String get consoleDescription => 'Lo que envía el clúster, y un lugar para escribir comandos';
	@override String get consoleTitle => 'Consola del clúster';
	@override String get consoleConnect => 'Conectar';
	@override String get consoleDisconnect => 'Desconectar';
	@override String get consoleCommand => 'Comando';
	@override String get consoleEmpty => 'Nada todavía. Conéctate, o espera a que una extensión use el clúster.';
	@override String consoleRetry({required Object command}) => 'Enviando de nuevo: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => 'No enviado: ${command} (${reason})';
	@override String get server => 'Servidor del clúster';
	@override String get selectServer => 'Seleccionar servidor';
	@override String get serverOther => 'Otro';
	@override String serverOtherIncomplete({required Object node}) => 'Aún no hay servidor ingresado, así que los spots van a ${node}';
	@override String get customHost => 'Servidor';
	@override String get customPort => 'Puerto';
	@override String get password => 'Contraseña';
	@override String get passwordDescription => 'Solo si hace falta';
	@override String passwordStored({required Object node}) => 'Contraseña guardada para ${node}';
	@override String get scrollback => 'Líneas conservadas';
	@override String scrollbackOpt({required Object count}) => '${count} líneas';
	@override String get connection => 'Conexión';
	@override String get statusIdle => 'No conectado. Se conecta cuando una extensión lo necesita. Toca para probar.';
	@override String statusConnecting({required Object node}) => 'Conectando a ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'Conectado a ${node} como ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'No se pudo conectar a ${node}: ${reason}';
	@override String get statusUnsupported => 'No disponible en la versión web.';
	@override String get statusOff => 'Apagado. Activa Conectar al clúster para usarlo.';
	@override late final _Translations$settings$cluster$errors$es errors = _Translations$settings$cluster$errors$es._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$es extends Translations$settings$spotting$en {
	_Translations$settings$spotting$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotting';
	@override String get respotInterval => 'Auto re-spot cada';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'Auto re-spot por defecto';
	@override String get autoRespotByDefaultOn => 'Habilitar el auto re-spot después de publicar cualquier spot';
	@override String get autoRespotByDefaultOff => 'Requiere una acción del usuario para habilitar el auto re-spot';
	@override String get pulseBeforeRespot => 'Pulso antes de cada auto re-spot';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'El chip de Spotting parpadea en azul durante los ${seconds} segundos previos a cada re-spot';
	@override String get pulseBeforeRespotOff => 'Sin parpadeo antes de un auto re-spot';
}

// Path: settings.radio
class _Translations$settings$radio$es extends Translations$settings$radio$en {
	_Translations$settings$radio$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Control CAT';
	@override String get loggingAndCat => 'Logging y CAT';
	@override String get tuningSection => 'Sintonía';
	@override String get keyerSection => 'Manipulador';
	@override String get servicesSection => 'Servicios';
	@override String get stationConfigurationSection => 'Configuración de Estación';
	@override String get moreSettings => 'Más opciones de configuración de la estación';
	@override late final _Translations$settings$radio$units$es units = _Translations$settings$radio$units$es._(_root);
	@override late final _Translations$settings$radio$pttKey$es pttKey = _Translations$settings$radio$pttKey$es._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$es smartVfoSnap = _Translations$settings$radio$smartVfoSnap$es._(_root);
	@override late final _Translations$settings$radio$snapDebounce$es snapDebounce = _Translations$settings$radio$snapDebounce$es._(_root);
	@override late final _Translations$settings$radio$snapLongMove$es snapLongMove = _Translations$settings$radio$snapLongMove$es._(_root);
	@override late final _Translations$settings$radio$snapMinMove$es snapMinMove = _Translations$settings$radio$snapMinMove$es._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$es snapMinSpeed = _Translations$settings$radio$snapMinSpeed$es._(_root);
	@override late final _Translations$settings$radio$enterSends$es enterSends = _Translations$settings$radio$enterSends$es._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$es keyerSpeed = _Translations$settings$radio$keyerSpeed$es._(_root);
	@override late final _Translations$settings$radio$cwMessages$es cwMessages = _Translations$settings$radio$cwMessages$es._(_root);
	@override late final _Translations$settings$radio$keyerControl$es keyerControl = _Translations$settings$radio$keyerControl$es._(_root);
	@override late final _Translations$settings$radio$voiceMessages$es voiceMessages = _Translations$settings$radio$voiceMessages$es._(_root);
	@override late final _Translations$settings$radio$voiceWords$es voiceWords = _Translations$settings$radio$voiceWords$es._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$es avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$es._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$es zeroBeatRange = _Translations$settings$radio$zeroBeatRange$es._(_root);
}

// Path: settings.help
class _Translations$settings$help$es extends Translations$settings$help$en {
	_Translations$settings$help$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ayuda y Recursos';
	@override String get description => 'Comunidad y soporte';
	@override String get forums => 'Foros de Ham2K';
	@override String get forumsDescription => 'Encuentra ayuda, danos tu opinión, comparte ideas…';
	@override String get chat => 'Chat de Ham2K';
	@override String get chatDescription => 'El servidor de Discord para nuestra comunidad en línea';
	@override String get youtube => 'Ham2K en YouTube';
	@override String get youtubeDescription => 'Videos y transmisiones en vivo';
	@override String get instagram => 'Ham2K en Instagram';
	@override String get instagramDescription => 'Porque nunca tienes demasiadas fotos…';
	@override String get bluesky => 'Ham2K en BlueSky';
	@override String get blueskyDescription => 'Síguenos para noticias y actualizaciones';
	@override String get contact => 'Contáctanos';
	@override String get contactDescription => 'help@ham2k.com — ¡pero prueba primero los Foros o el Chat!';
}

// Path: settings.exports
class _Translations$settings$exports$es extends Translations$settings$exports$en {
	_Translations$settings$exports$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportaciones';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$es extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get activities => 'Actividades';
	@override String get hunting => 'Cacería';
	@override String get contests => 'Concursos';
	@override String get lookups => 'Búsquedas';
	@override String get dashboard => 'Tablero';
}

// Path: settings.map
class _Translations$settings$map$es extends Translations$settings$map$en {
	_Translations$settings$map$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override late final _Translations$settings$map$style$es style = _Translations$settings$map$style$es._(_root);
	@override late final _Translations$settings$map$showCallsigns$es showCallsigns = _Translations$settings$map$showCallsigns$es._(_root);
	@override late final _Translations$settings$map$showGrayline$es showGrayline = _Translations$settings$map$showGrayline$es._(_root);
	@override late final _Translations$settings$map$styleOpts$es styleOpts = _Translations$settings$map$styleOpts$es._(_root);
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
	@override String get title => 'Sincronización en la nube';
	@override String get moreSettings => 'Más opciones de sincronización';
	@override String get enable => 'Habilitar sincronización';
	@override String get deviceKey => 'Clave del dispositivo';
}

// Path: settings.peers
class _Translations$settings$peers$es extends Translations$settings$peers$en {
	_Translations$settings$peers$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispositivos cercanos';
	@override String get enable => 'Conectar con otros dispositivos';
	@override String get enableDescription => 'Permite compartir operaciones, logging, CAT y GPS con otros dispositivos por la red local';
	@override String get bleEnable => 'Conectar por Bluetooth';
	@override String get bleDescription => 'Usa Bluetooth LE para conectar aunque no haya red local';
	@override String get thisDevice => 'Este Dispositivo';
	@override String get deviceName => 'Nombre';
	@override String get deviceNameHint => 'Cómo ven este dispositivo los demás';
	@override String get pairedDevices => 'Dispositivos vinculados';
	@override String get noPairedDevices => 'Todavía no hay dispositivos vinculados. Activa esto en otro dispositivo de esta red para vincularlos.';
	@override String deviceListProblem({required Object error}) => 'No se pueden leer tus dispositivos vinculados: ${error}';
	@override String get nearby => 'Cercano';
	@override String get connected => 'Conectado';
	@override String get viaBluetooth => 'vía Bluetooth';
	@override String get connecting => 'Conectando…';
	@override String get syncing => 'Sincronizando…';
	@override String get waitingForThem => 'Esperando al otro dispositivo';
	@override String get notConnected => 'No conectado';
	@override String get wantsToPair => 'quiere compartir esta operación';
	@override String get allow => 'Permitir';
	@override String get link => 'Vincular';
	@override String get reject => 'Rechazar';
	@override String get forget => 'Olvidar';
	@override String forgetTitle({required Object name}) => '¿Olvidar ${name}?';
	@override String get forgetBody => 'Dejará de sincronizarse con este dispositivo. Puedes autorizarlo de nuevo más tarde, y los contactos ya registrados se conservan.';
	@override String pairTitle({required Object name}) => 'Vincular con ${name}';
	@override String get pairBody => 'Este dispositivo está en tu red local y quiere conectarse.';
	@override String get pairBodyBle => 'Este dispositivo está cerca y quiere conectarse por Bluetooth LE.';
	@override String get pairIdLabel => 'ID del dispositivo';
	@override String get pairWarning => 'Vincula solo dispositivos que reconozcas. Cualquier dispositivo de esta red puede enviar una solicitud.';
	@override String get pairWarningBle => 'Vincula solo dispositivos que reconozcas. Cualquier dispositivo cercano puede enviar una solicitud.';
	@override String problem({required Object error}) => 'No se puede acceder a la red local: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Conectado a ${device}';
	@override String statusLost({required Object device}) => 'Se perdió la conexión con ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispositivos cercanos: ${connected} de ${linked} conectados';
	@override String get screenEnable => 'Compartir pantallas y ventanas';
	@override String get screenDescription => 'Permite que otros dispositivos muestren pantallas o ventanas de esta computadora';
	@override String get screenSources => 'Pantallas y ventanas';
	@override String get screenRefresh => 'Actualizar la lista';
	@override String get screenUnsupportedPlatform => 'Este dispositivo no puede compartir su pantalla. macOS sí puede; cualquier dispositivo puede mostrar una pantalla compartida por otro.';
	@override String get screenUnsupportedVersion => 'Compartir la pantalla necesita macOS 12.3 o posterior. Este dispositivo sí puede mostrar una pantalla compartida por otro.';
	@override String get screenNeedsPermission => 'macOS necesita tu permiso para grabar la pantalla antes de que esta app pueda compartir una.';
	@override String get screenGrantPermission => 'Pedir permiso';
	@override String get screenRelaunchAfterGranting => 'Permítelo en Configuración del Sistema, en Privacidad y seguridad → Grabación de pantalla, y luego cierra y vuelve a abrir esta app — macOS solo le avisa a la app del cambio en el siguiente arranque.';
	@override String screenProblem({required Object error}) => 'Compartir pantalla: ${error}';
	@override String get screenChooseTitle => 'Elegir qué compartir';
	@override String get screenChooseButton => 'Elegir qué compartir…';
	@override String get screenTabScreens => 'Pantallas';
	@override String get screenTabApps => 'Apps';
	@override String get screenTabWindows => 'Ventanas';
	@override String get screenTabEmpty => 'No se encontró nada de este tipo.';
	@override String get screenSharedSummaryNone => 'No has elegido nada todavía.';
	@override String get screenThisDevice => 'Este dispositivo';
	@override String screenSharedTo({required Object devices}) => 'Se muestra en ${devices}';
	@override String get screenSharedToNobody => 'No se está mostrando';
	@override String screenStopSharing({required Object name}) => 'Dejar de compartir ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$es extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuración de sincronización';
	@override String get enableTitle => 'Sincronizar con Ham2K Log Filer';
	@override String get enabledDescription => 'Respaldando y sincronizando tu log entre dispositivos';
	@override String get disabledDescription => 'Apagado — se queda solo en este dispositivo';
	@override String get syncing => 'Sincronizando';
	@override String get account => 'Cuenta';
	@override String get refresh => 'Actualizar';
	@override String get switchAccounts => 'Cambiar de cuenta';
	@override String get switchAccountsDescription => 'Vincula este dispositivo a otra cuenta con un código QR o por correo electrónico';
	@override String get connectionRequests => 'Solicitudes de conexión';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Un dispositivo espera unirse a esta cuenta',
		other: '${n} dispositivos esperan unirse a esta cuenta',
	);
	@override String get accountEmailTitle => 'Correo electrónico de la cuenta';
	@override String accountEmailSent({required Object email}) => 'Confirmación enviada a ${email}. Abre el enlace allí para completar el cambio.';
	@override String get resendConfirmation => 'Reenviar correo de confirmación';
	@override String resendConfirmationDescription({required Object email}) => 'Esperando a ${email}';
	@override String accountEmailResent({required Object email}) => 'Enviado de nuevo a ${email}.';
	@override String get deviceLinked => 'Ese dispositivo ya está vinculado a esta cuenta.';
	@override String get checking => 'Comprobando…';
	@override String get notLinked => 'Aún no vinculado';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => '¿Reemplazar los datos locales?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} operación',
		other: '${n} operaciones',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Datos sincronizados';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Pendiente de subir: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Este dispositivo: comprobando…';
	@override String get countsServerChecking => 'Servidor: comprobando…';
	@override String get countsServerUnavailable => 'Servidor: no disponible';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Esto respalda y borra ${operations} y ${qsos} de este dispositivo, y luego descarga los datos de la cuenta en su lugar. El respaldo se conserva en la base de datos de este dispositivo.';
	@override String get replace => 'Reemplazar';
	@override String get pendingBannerTitle => 'Nueva cuenta de Ham2K Log Filer detectada';
	@override String get pendingBannerBody => 'Conserva las operaciones y QSOs existentes en este dispositivo y combínalos con la cuenta, o reemplázalos con los datos de la cuenta (en ambos casos queda un respaldo en este dispositivo).';
	@override String get combine => 'Combinar';
	@override String get authIssueTitle => 'La sincronización no puede conectarse';
	@override String get authIssueText => 'Ham2K Log Filer sigue rechazando este dispositivo. Revisa tu indicativo en la configuración de sincronización.';
	@override String get openSettings => 'Abrir configuración de sincronización';
}

// Path: settings.accounts
class _Translations$settings$accounts$es extends Translations$settings$accounts$en {
	_Translations$settings$accounts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cuentas, Servicios y Fuentes de Datos';
	@override String get none => 'No hay extensiones activas con cuentas';
	@override String get notConfigured => 'Sin configurar';
	@override String get connected => 'Conectado';
	@override String get cancelLogin => 'Cancelar el inicio de sesión';
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
	@override String get lookupFailed => 'Las cuentas no están disponibles ahora mismo — inténtalo de nuevo en un momento';
	@override String get browserLoginTitle => 'Termina de iniciar sesión con tu navegador';
	@override String browserLoginSteps({required Object prefix}) => 'Cuando termines, el navegador intentará abrir un enlace que empieza con "${prefix}". Es muy probable que tu escritorio no tenga nada registrado para abrirlo, así que copia ese enlace (de la barra de direcciones o de la página de error del navegador) y pégalo aquí.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger no pudo abrir tu navegador. Copia el enlace de inicio de sesión y ábrelo tú mismo; luego copia el enlace al que te envíe (empieza con "${prefix}") y pégalo aquí.';
	@override String get copyLoginLink => 'Copiar enlace de inicio de sesión';
	@override String get pastedLinkLabel => 'Pega el enlace aquí';
	@override String get finishLogin => 'Terminar inicio de sesión';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Ese no es el enlace de inicio de sesión — debe empezar con "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Ese enlace pertenece a otro intento de inicio de sesión. Cierra esta página y conéctate de nuevo.';
	@override String get pastedLinkNoCode => 'Ese enlace no tiene ningún código de inicio de sesión. Termina de iniciar sesión y luego copia el enlace al que te envíe.';
	@override String get pastedLinkMalformed => 'Ese enlace parece estar incompleto. Cópialo por completo y pégalo de nuevo.';
	@override String get relayLoginWaiting => 'Esperando a que termines de iniciar sesión — esto continuará automáticamente en cuanto lo hagas.';
	@override String get loginNoResponse => 'Este dispositivo aún no ha recibido respuesta del inicio de sesión. Si ya terminaste en tu navegador, cancela e intenta conectarte de nuevo.';
	@override String get relayLoginNotOpened => 'Ham2K Logger no pudo abrir tu navegador automáticamente. Usa el botón de abajo para abrir la página de inicio de sesión tú mismo.';
	@override String get relayLoginUnavailable => 'No se pudo conectar con el servidor de sincronización necesario para completar este inicio de sesión. Revisa tu conexión e inténtalo de nuevo.';
	@override String get loginIncompleteResponse => 'Ese intento de inicio de sesión no se completó correctamente. Vuelve a intentar conectarte.';
	@override String get noKeyringTitle => 'No se pueden guardar las credenciales de las cuentas';
	@override String get noKeyringText => 'Ham2K Logger no puede acceder a un servicio de llavero en esta computadora, así que no puede guardar ni leer las credenciales de las cuentas — conectar una cuenta fallará hasta que lo resuelvas. Instala y arranca **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloquea el llavero que ya tengas, y reinicia. El logging, las exportaciones y los archivos de datos no se ven afectados; la sincronización del log queda apagada mientras tanto.';
	@override String get noKeyringInline => 'Las credenciales no se pueden guardar: no se puede acceder al llavero de esta computadora. Instala y arranca gnome-keyring, KWallet o KeePassXC, o desbloquea el que ya tengas.';
	@override String get noSecureStorageInline => 'Las credenciales no se pueden guardar: no se puede acceder al almacenamiento seguro de esta computadora.';
}

// Path: settings.station
class _Translations$settings$station$es extends Translations$settings$station$en {
	_Translations$settings$station$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuración de Estación y Control CAT';
	@override String get none => 'No hay equipo configurado';
	@override String get add => 'Agregar';
	@override String get addTitle => 'Agregar equipo';
	@override String get searchHint => 'Buscar equipos';
	@override String get noMatches => 'Ningún equipo coincide';
	@override String get detectedEquipment => 'Equipos detectados';
	@override String discoveryUnavailable({required Object error}) => 'No se puede buscar radios: ${error}';
	@override String get edit => 'Editar equipo';
	@override String get name => 'Nombre';
	@override String get nameDescription => 'Cómo lo llamas — "Radio Izquierda". Opcional.';
	@override String get transport => 'Conexión';
	@override String get host => 'Dirección';
	@override String get hostDescription => 'El nombre de host o la dirección IP de la radio en tu red.';
	@override String get port => 'Puerto';
	@override String get hostRequired => 'Se requiere una dirección';
	@override String get portInvalid => 'El puerto debe estar entre 1 y 65535';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
	@override String get remove => 'Quitar';
	@override String removeTitle({required Object name}) => '¿Quitar ${name}?';
	@override String get removeMessage => 'Esto solo lo quita de la app. La configuración del equipo no cambia.';
	@override String unknownType({required Object typeKey}) => 'Tipo de equipo no reconocido "${typeKey}"';
	@override String get report => 'Informar';
	@override String get reportTitle => 'Informar sobre esta radio';
	@override String get reportIntro => 'Cuéntanos qué radio es realmente y qué tal fue. Tu informe se convierte en una ficha que lee el equipo de Ham2K, y lo que escribas sobre cómo hacerla funcionar puede acabar ayudando al siguiente operador con la misma radio.';
	@override String get reportManufacturer => 'Fabricante';
	@override String get reportManufacturerDescription => 'Quién la fabrica — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Hace falta un fabricante';
	@override String get reportModel => 'Modelo';
	@override String get reportModelDescription => 'El modelo, tal como lo llama la propia radio — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'Hace falta un modelo';
	@override String get reportOutcome => '¿Qué tal fue?';
	@override String get reportOutcomeWorks => 'Funcionó bien';
	@override String get reportOutcomeIssues => 'Funcionó, con problemas';
	@override String get reportOutcomeFails => 'No funcionó en absoluto';
	@override String get reportOutcomeRequired => 'Cuéntanos qué tal fue';
	@override String get reportComments => 'Comentarios';
	@override String get reportCommentsPlaceholder => 'Qué funcionó, qué no, y cualquier cosa que te sorprendiera.';
	@override String get reportHints => 'Consejos para solucionar problemas';
	@override String get reportHintsPlaceholder => '¿Quieres sugerir consejos para que otros usuarios solucionen problemas?';
	@override String get reportSend => 'Enviar informe';
	@override String get reportSending => 'Enviando tu informe…';
	@override String reportSent({required Object ref}) => 'Gracias — tu informe se archivó como ${ref}.';
	@override String get reportSentNoRef => 'Gracias — tu informe se envió.';
	@override String reportFailed({required Object error}) => 'El informe no se envió: ${error}';
	@override String get troubleshootingNotes => 'Notas de resolución de problemas';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Usar como VFO principal';
	@override String get serialPort => 'Puerto serie';
	@override String get serialPortDescription => 'El puerto donde aparece la interfaz CAT de la radio.';
	@override String get serialPortNone => 'No se encontraron puertos serie';
	@override String get serialPortRequired => 'Elige un puerto serie';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'puerto ${n} de ${total}';
	@override String get serialPortSuggested => 'sugerido';
	@override String get serialPortJustNow => 'Conectado recientemente';
	@override String get serialPortNoDriver => 'sin controlador';
	@override String get serialDeviceRequest => 'Agregar un dispositivo USB…';
	@override String get bleDevice => 'Dispositivo Bluetooth LE';
	@override String get bleDeviceDescription => 'El puente serie a través del cual se conecta tu radio, como un LiNK500MP en Modo 4 o un adaptador serie BLE.';
	@override String get bleScan => 'Buscar dispositivos Bluetooth LE…';
	@override String get bleScanNoneFound => 'No se encontraron dispositivos Bluetooth LE. Comprueba que el puente esté encendido, cerca y en su modo Bluetooth LE (Modo 4 en un LiNK500MP).';
	@override String bleScanFailed({required Object reason}) => 'No se pudo ejecutar la búsqueda Bluetooth LE: ${reason}';
	@override String get bleOff => 'El Bluetooth está apagado.';
	@override String get bleDenied => 'No se concedió el permiso de Bluetooth. Permítelo en la configuración del sistema e inténtalo de nuevo.';
	@override String get bleUnsupported => 'Este dispositivo no tiene Bluetooth LE.';
	@override String get bleStarting => 'El Bluetooth todavía está iniciándose. Inténtalo de nuevo en un momento.';
	@override String get bleConnectFailed => 'No se puede acceder al dispositivo Bluetooth LE. Comprueba que esté encendido, cerca y no conectado a otra app.';
	@override String bleNoSerialService({required Object services}) => 'Este dispositivo Bluetooth LE no tiene ningún servicio serie que la app reconozca. Por favor, repórtalo con sus servicios: ${services}';
	@override String get baudRate => 'Velocidad (baudios)';
	@override String get baudRateDescription => 'Debe coincidir con el menú CAT de la radio. Si no, la radio devuelve datos ilegibles y ningún error.';
	@override String get serialRtsHigh => 'Mantener RTS en alto';
	@override String get serialRtsHighDescription => 'Solo para una radio que espera RTS antes de responder, como una Yaesu con CAT RTS activado. En un Digirig, un SignaLink y la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto transmite.';
	@override String get serialDtrHigh => 'Mantener DTR en alto';
	@override String get serialDtrHighDescription => 'Solo para una interfaz CAT que se alimenta de DTR, como algunos cables RS-232 para el FT-817. En muchos cables DTR manipula CW o PTT, y mantenerlo en alto transmite.';
	@override String get serialUsbDriver => 'Controlador del chip USB';
	@override String get serialUsbDriverDescription => 'Automático reconoce la mayoría de los adaptadores. Elige el chip solo para uno que la lista de puertos indique sin controlador — su empaque o una lista de dispositivos USB lo nombra.';
	@override String get serialUsbDriverAuto => 'Automático';
	@override String get civAddress => 'Dirección CI-V de la radio';
	@override String get civAddressDescription => 'Hexadecimal, como aparece en el menú CI-V de la radio. El IC-705 viene con A4.';
	@override String get civAddressInvalid => 'Una dirección CI-V son dos dígitos hexadecimales, de 01 a FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Cuál de los slices de la radio lee y sintoniza esta conexión.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Elige uno de los slices de la radio, de la A a la H';
	@override String flexSliceMissing({required Object letter}) => 'El slice ${letter} no está en uso en esta radio — elige otro, o créalo en SmartSDR';
	@override String get channelNotInUse => 'sin usar';
	@override String get channelHeldByUnknown => 'en uso por otro programa';
	@override String get flexNoSlices => 'Esta radio no ha informado de ningún slice — comprueba que SmartSDR esté activo y que este cliente pueda suscribirse';
	@override String get spectrumUnsupported => 'Esta radio no envía su espectro por CAT';
	@override String get spectrumRequiresBaud => 'Requiere CAT a 115200 bps';
	@override String get spectrumNoRadio => 'No hay ninguna radio conectada';
	@override String get spectrumWaiting => 'Esperando el espectro de la radio…';
	@override String get spectrumUnavailable => 'La visualización del espectro no está disponible';
	@override String get spectrumNoDaxChannel => 'Todos los canales DAX IQ de esta radio están en uso';
	@override String get spectrumNoPanadapter => 'Este slice no tiene panadaptador en la radio';
	@override String spectrumStreamRefused({required Object code}) => 'La radio rechazó un flujo DAX IQ (error ${code})';
	@override String get spectrumNoUdp => 'Los datos del espectro de la radio no llegan a este dispositivo';
	@override String get spectrumK4Unavailable => 'No se puede recibir el espectro LAN del K4. Reintentando…';
	@override String get spectrumK4RemoteUnavailable => 'No se puede recibir el espectro remoto del K4';
	@override String get spectrumScopeRefused => 'La radio rechazó los comandos de su espectro';
	@override String get spectrumOutOfRange => 'El espectro de la radio está fuera del rango que puede mostrar';
	@override String get spectrumBandUnsupported => 'El espectro de la radio no se puede mostrar en esta banda';
	@override String get spectrumSdrNoRadio => 'Esperando la frecuencia de la radio vinculada…';
	@override String get spectrumSdrNotConnected => 'El SDR no está conectado';
	@override String get spectrumSdrNoIf => 'Establece la frecuencia de FI de la radio en la configuración de este SDR';
	@override String get sdrRadio => 'Muestra el espectro de';
	@override String get sdrRadioDescription => 'Una visualización de espectro en esta radio toma los datos de este receptor en lugar del espectro propio de la radio.';
	@override String get sdrRadioMain => 'La radio principal';
	@override String get sdrTuning => 'Entrada de antena';
	@override String get sdrTuningDescription => 'De dónde viene la señal del receptor. Con su propia antena se sintoniza solo para seguir a la radio; en la salida de FI de la radio se queda en la FI.';
	@override String get sdrTuningIndependent => 'Su propia antena';
	@override String get sdrTuningIfTap => 'La salida de FI de la radio';
	@override String get sdrIfHz => 'Frecuencia de FI (Hz)';
	@override String get sdrIfHzDescription => 'Solo para una salida de FI: la frecuencia a la que queda el dial de la radio en su FI, como 68330000 en un FT-817.';
	@override String get sdrIfInverted => 'La FI está invertida';
	@override String get sdrGainDb => 'Ganancia (dB)';
	@override String get sdrGainDbDescription => 'Déjalo en blanco para la ganancia automática del receptor.';
	@override String get sdrOffsetHz => 'Desplazamiento de frecuencia (Hz)';
	@override String get sdrOffsetHzDescription => 'Se suma a cada frecuencia enviada al receptor, para un upconverter: 125000000 para un Ham It Up.';
	@override String get sdrPpm => 'Corrección de frecuencia (ppm)';
	@override String get rtlDirectSampling => 'Muestreo directo';
	@override String get rtlDirectSamplingDescription => 'Para HF en un RTL-SDR V3 sin upconverter. Un RTL-SDR V4 llega a HF sin él.';
	@override String get rtlDirectSamplingOff => 'Apagado';
	@override String get rtlDirectSamplingI => 'Rama I';
	@override String get rtlDirectSamplingQ => 'Rama Q';
	@override String get rtlTcpNotAServer => 'Esto no es un servidor rtl_tcp';
	@override String get rtlTcpNotes => 'Esto se conecta a un **servidor rtl_tcp que ejecutas tú mismo** en la computadora donde está enchufado el dongle.\n\n- **Inícialo** con `rtl_tcp -a 0.0.0.0` para que otras máquinas puedan acceder; en la misma máquina basta con `rtl_tcp`.\n- **El puerto** es 1234 salvo que lo hayas iniciado con `-p`.\n- **Un programa a la vez:** rtl_tcp atiende a un solo cliente. La app se conecta solo mientras se muestra una visualización de espectro, y lo suelta unos segundos después de cerrarla.\n- **En Android**, la app *SDR driver* ejecuta el mismo servidor en el teléfono.';
	@override String get rspTcpNotes => 'Esto se conecta a un **servidor rsp_tcp que ejecutas tú mismo** en la computadora donde está enchufado el RSP, con la API de SDRplay instalada allí.\n\n- **Inícialo** con `rsp_tcp -a 0.0.0.0`.\n- **El puerto** es 1234 salvo que lo hayas iniciado con `-p`.\n- **Un programa a la vez:** el servidor acepta un solo cliente. La app se conecta solo mientras se muestra una visualización de espectro.';
	@override String get n3fjpNoRig => 'N3FJP no tiene configurada una interfaz de radio, así que esto sigue lo que se escribe en N3FJP, no una radio';
	@override String get winkeyerKeyPort => 'Salida de manipulación';
	@override String get winkeyerKeyPortDescription => 'En cuál de los dos conectores de salida del manipulador está enchufada tu radio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Puerto ${n}';
	@override String get winkeyerPtt => 'Usar el PTT del manipulador';
	@override String get winkeyerPttDescription => 'Activa la línea PTT del mismo conector, para un amplificador o una radio que lo necesite. Déjalo desactivado para una radio manipulada por su conector de manipulación.';
	@override String get winkeyerNoAnswer => 'Ningún WinKeyer respondió en este puerto';
	@override String get winkeyerStoppedAnswering => 'El WinKeyer dejó de responder mientras enviaba; el mensaje se descartó';
	@override String get icomControlPort => 'Puerto de control (UDP)';
	@override String get icomControlPortDescription => 'El Control Port (UDP) de la radio — 50001 salvo que lo hayas cambiado en su configuración de red, o redirigido a otro.';
	@override String get icomSerialPort => 'Puerto serie (UDP)';
	@override String get icomSerialPortDescription => 'El Serial Port (UDP) de la radio — 50002 salvo que lo hayas cambiado en su configuración de red, o redirigido a otro.';
	@override String get icomPortsDiffer => 'Los puertos de control y serie deben ser distintos';
	@override String get radioUser => 'Usuario de la radio';
	@override String get radioPass => 'Contraseña de la radio';
	@override String get radioLoginDescription => 'El inicio de sesión Red → Remoto de la radio, no la contraseña del WiFi.';
	@override String get radioUserRequired => 'Se requiere el usuario de control remoto de la radio';
	@override String get connectFailedBusy => 'Dispositivo en uso';
	@override String get connectFailedDenied => 'Acceso denegado';
	@override String get connectFailedDevice => 'Dispositivo no encontrado';
	@override String get connectFailedUnsupported => 'Ningún controlador reconoce el chip de este adaptador USB. Si sabes cuál es, elígelo en Controlador del chip USB, en Configuración avanzada.';
	@override String get connectFailedLines => 'No se pudieron mantener RTS/DTR como están configurados, así que se cerró el puerto. Puede que otro programa haya dejado activado el handshake por hardware — desconecta y vuelve a conectar el cable.';
	@override String get connectFailedNetwork => 'No se encuentra la radio en la red. Comprueba su dirección y que esté encendida y accesible.';
	@override String connectFailedReplyPort({required Object port}) => 'El puerto ${port} de este dispositivo ya está en uso, y las respuestas llegan ahí. Cierra lo que esté escuchando en él — incluido otro nodo de PstRotator — o cambia el puerto.';
	@override String get connectFailedTimeout => 'La radio no respondió a tiempo. Comprueba que esté encendida y accesible.';
	@override late final _Translations$settings$station$models$es models = _Translations$settings$station$models$es._(_root);
	@override late final _Translations$settings$station$transports$es transports = _Translations$settings$station$transports$es._(_root);
	@override String get troubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get ft891Troubleshooting => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS apagado en la radio, o Mantener RTS en alto activado.** Con **CAT RTS** activado (menú **05-08** del FT-891), la radio se queda en silencio mientras RTS está bajo — puede responder una vez al abrirse el puerto, y luego nada. Al elegir el puerto USB propio de la radio se activa **Mantener RTS en alto** en Configuración avanzada. En un Digirig, un SignaLink o la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto pone tu transmisor en el aire: en ese caso, apaga CAT RTS en la radio.\n- **La velocidad debe coincidir** con el CAT RATE de la radio (menú **05-06**). Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get yaesuBinaryTroubleshooting => 'Esta radio habla el CAT antiguo de Yaesu, de cinco bytes, y no responde en absoluto cuando algo no encaja. Casi siempre es una de estas:\n\n- **El cable tiene que convertir niveles.** El conector CAT de la parte trasera no es RS-232 ni USB: necesita un CT-62 o un adaptador equivalente. Un cable de audio o de datos común no sirve para CAT.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio (**#14** en un FT-817, **#19** en un FT-857 o un FT-897). Si no coincide, la radio no devuelve nada, y nunca un error.\n- **Nunca dejes que nada active RTS ni DTR en este puerto.** En la mayoría de los cables para estas radios esas líneas son el PTT y la manipulación. La excepción es una interfaz antigua alimentada por DTR: para esa, activa **Mantener DTR en alto** en Configuración avanzada.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEste controlador se escribió a partir de la tabla CAT publicada por Yaesu y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.';
	@override String get tenTecTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get tenTecEagleTroubleshooting => '- **El puerto USB-B de la parte trasera es el enlace CAT.** La radio aparece como un puerto serie USB; en Windows necesita el controlador USB a UART de Ten-Tec, que aparece en el Administrador de dispositivos como "USB to UART (COMx)".\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto, y también el actualizador de firmware de Ten-Tec.\n- **Ajustar el ancho del filtro desde la app se lo quita a la perilla BW** hasta apagar y encender la radio. Así funciona la radio.\n\nEste controlador se escribió a partir de la guía de referencia del programador de Ten-Tec. Si funciona a medias, vale la pena reportarlo, con la versión de firmware del menú de la radio.';
	@override String get tenTecOrionTroubleshooting => '- **Usa un cable serie DB-9 directo** al puerto SERIAL DATA, no uno null-modem.\n- **Esta entrada mantiene RTS en alto**, porque el Orion usa RTS y CTS como handshake. En una interfaz que activa el PTT desde RTS, como un Digirig, desactiva Mantener RTS en alto en Configuración avanzada, o la radio transmitirá en cuanto la app se conecte.\n- **El CW desde la app necesita el manipulador interno de la radio encendido.** Con él apagado, la radio ignora lo que envía la app.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEste controlador se escribió a partir de la guía de referencia del programador de Ten-Tec y no se ha probado con un Orion. Si funciona a medias, vale la pena reportarlo, con la versión de firmware del menú de la radio.';
	@override String get tenTecNoCw => 'El firmware de esta radio no acepta CW desde la app. Ten-Tec lo agregó en el firmware 1.366 del Orion.';
	@override String get tenTecKeyerOff => 'El manipulador interno de la radio está apagado, así que ignora el CW enviado desde la app. Enciende el manipulador en el menú de la radio.';
	@override String get guohetecTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get guohetecTroubleshooting => 'El Q900 tiene dos protocolos CAT, y esta entrada usa el nativo en lugar de la imitación del FT-817. Elige **Guohetec Q900** aquí, no un FT-817 — la imitación admite menos comandos, y la radio no dice cuál de los dos está usando.\n\n- **El cable USB-C es el enlace CAT**, y también conecta la tarjeta de sonido. La velocidad no importa en él; el puerto ignora la que se le configure.\n- **Nunca dejes que nada active RTS ni DTR en este puerto.** En un cable serie esas líneas son el PTT y la manipulación.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Una radio de segunda generación se comporta distinto** de una de primera. Mantén pulsado Menu y luego About: HW 2.0 es la segunda generación.\n\nEste controlador se escribió a partir del protocolo publicado por el fabricante y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.';
	@override String get yaesuTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get yaesuTroubleshooting => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS debe estar en OFF en la radio.** Con esa opción activada, la radio espera una línea de handshake que la app mantiene baja. En un Digirig, un SignaLink o la mayoría de los cables caseros esa misma línea es el PTT, así que activarla pondría tu transmisor en el aire. En el puerto USB propio de la radio, **Mantener RTS en alto** en Configuración avanzada es la alternativa. Dónde está esa opción depende del modelo (menú **05-08** en un FT-891).\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Los modos siguen la tabla del FT-891.** Casi toda la línea Yaesu coincide, pero una radio que numere sus modos de otra forma mostrará y ajustará el modo equivocado en esos casos. La frecuencia no se ve afectada.';
	@override String get ftdx3000Troubleshooting => '**El menú 037 CAT SELECT debe estar en USB** para CAT por el puerto USB de la radio; en RS232C, el CAT está en el conector de la parte trasera.\n\nEsta entrada se escribió a partir de la documentación CAT publicada y no se ha probado con un FTDX3000. Si funciona a medias, vale la pena reportarlo.';
	@override String get yaesuRs232Troubleshooting => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **El conector CAT es RS-232.** Necesita un adaptador USB a serie y un cable DB-9 directo — un cable null-modem cruza las líneas y la radio no oye nada.\n- **CAT RTS debe estar en OFF en la radio.** Con esa opción activada, la radio espera una línea de handshake que la app mantiene baja, salvo que **Mantener RTS en alto** esté activado en Configuración avanzada.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEsta entrada se escribió a partir de la documentación CAT publicada y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.';
	@override String get yaesuUsbTroubleshooting => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **Usa el primero de los dos puertos USB de la radio.** El CAT suele estar en el primero (el puerto COM **Enhanced** en Windows); el segundo (**Standard**) es para PTT y manipulación. El selector señala el primero siempre que puede distinguirlos.\n- **CAT RTS apagado en la radio, o Mantener RTS en alto activado.** Con el menú **CAT RTS** de la radio activado, se queda en silencio mientras RTS está bajo — puede responder una vez al abrirse el puerto, y luego nada. Al elegir el puerto USB propio de la radio se activa **Mantener RTS en alto** en Configuración avanzada. En un Digirig, un SignaLink o la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto pone tu transmisor en el aire: en ese caso, apaga CAT RTS en la radio.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.';
	@override String get k4SerialNotes => 'Conecta el puerto USB-B (PC) trasero del K4. Tanto USB-PC1 como USB-PC2 sirven para CAT; elige un puerto libre e iguala su ajuste Serial USB-PCn: Baud Rate en la radio. HaLo propone 38400; cámbialo si hace falta. Otra app debe usar el otro puerto o Ethernet.\n\nEsta conexión controla la radio y sus manipuladores; no envía audio a HaLo.';
	@override String get k4TcpNotes => 'Conecta el puerto Ethernet del K4 a tu red local. Ingresa su nombre de host o dirección IP y el puerto CAT 9200. HaLo usa el mismo host en el puerto fijo 9201 cuando hay un panadaptador o una cascada visible; cambiar el puerto CAT no cambia el puerto del espectro.\n\nEl espectro muestra el receptor principal. Sus controles de zoom, ajuste de referencia y velocidad afectan solo a la visualización de HaLo. La transmisión de audio no está soportada.';
	@override String get k4PowerTimeout => 'No se cambió la potencia del K4 porque la radio no confirmó su rango de salida. Inténtalo de nuevo.';
	@override String get k4RemoteNotes => 'Habilita el acceso remoto en tu K4 e ingresa su contraseña de red. Main y Sub comparten una sola conexión cifrada para el control de la radio y el espectro. El puerto por defecto es 9204; ingresa tu puerto redirigido al conectarte de forma remota.\n\nLa reproducción de audio y la transmisión del micrófono no están soportadas.';
	@override String get k4Receiver => 'Receptor';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'Elige Main o Sub';
	@override String get k4ReceiverAlreadyConfigured => 'Ese receptor ya está configurado para este K4';
	@override String get k4SubReceiverOff => 'El receptor Sub del K4 está apagado';
	@override String get k4RemotePasswordRequired => 'Ingresa la contraseña de red del K4 para conectarte de forma segura.';
	@override String get k4RemoteHandshakeFailed => 'El K4 no pudo establecer una conexión segura. Revisa su contraseña de red y la configuración de acceso remoto.';
	@override String get k4RemoteUnreachable => 'No se pudo acceder a la conexión segura del K4. Revisa su dirección, puerto y configuración de acceso remoto.';
	@override String get k4PowerRange => 'La potencia del K4 debe ser de 0.1–110 W, o de 0.0001–0.01 W cuando está activa la salida de miliwatts del transversor.';
	@override String get elecraftTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get elecraftTroubleshooting => 'Las radios Elecraft hablan CAT de Kenwood, y tanto una KX2 como una KX3 se han usado así — VFO en ambos sentidos, cambio de modo y batido cero en CW, todo funcionando.\n\nSi la radio no responde, casi siempre es una de estas:\n\n- **La velocidad debe coincidir** con la configurada en **RS232** en el menú de la radio. 38400 es la de fábrica. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\n**Si la frecuencia es correcta pero el modo no**, cuéntanoslo. Las entradas de la KX2 y la KX3 leen el modo de una posición en la respuesta de estado de la radio que hemos fijado según las radios que hemos visto, y un firmware que lo ponga en otro lugar solo nos llega a través de un reporte.\n\nNadie ha reportado nada sobre la K3, así que cuéntanos qué pasa si usas una. La K4 tiene su propia entrada.';
	@override String get lab599TroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get lab599Troubleshooting => 'La línea TX-500 habla CAT de Kenwood. Frecuencia y modo se han probado a través de un LiNK500MP; potencia y medidores están escritos a partir de la referencia CAT de Lab599, así que por favor reporta qué pasa, funcione o no.\n\n- **La velocidad debe coincidir** con el ajuste CAT de la radio, 9600 salvo que lo hayas cambiado. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Elige el protocolo CAT en la radio.** TS-2000 cubre frecuencia, modo y potencia. LAB599 además permite que la app cambie la radio a DIG, la vea transmitir en DIG y lea su voltaje de alimentación.\n- **A través de un LiNK500MP**, mantén pulsada la perilla del VFO unos tres segundos para pasar el control CAT a la interfaz.\n- **Configura el modo del LiNK500MP según la conexión**: Modo 3 para Bluetooth, Modo 4 para Bluetooth LE. En cualquier otro modo, una búsqueda Bluetooth LE no lo encuentra.\n- **Por Bluetooth**, el LiNK500MP se empareja como dos puertos serie y solo uno lleva el CAT. Si la radio se queda en silencio, elige el otro.';
	@override String get lab599TroubleshootingIos => 'La línea TX-500 habla CAT de Kenwood. Frecuencia y modo se han probado a través de un LiNK500MP; potencia y medidores están escritos a partir de la referencia CAT de Lab599, así que por favor reporta qué pasa, funcione o no.\n\n- **Pon el LiNK500MP en Modo 4**, su modo Bluetooth LE, antes de buscarlo. En cualquier otro modo, un iPhone o iPad no puede encontrarlo.\n- **Pasa el control CAT al LiNK500MP**: mantén pulsada la perilla del VFO de la radio unos tres segundos.\n- **Elige el protocolo CAT en la radio.** TS-2000 cubre frecuencia, modo y potencia. LAB599 además permite que la app cambie la radio a DIG, la vea transmitir en DIG y lea su voltaje de alimentación.';
	@override String get kenwoodTroubleshootingTitle => 'Si la radio conecta pero no muestra frecuencia';
	@override String get kenwoodTroubleshooting => 'Este controlador está probado con las Kenwood TS-590SG y TS-480, las QRP Labs QMX y QCX-mini, y las Elecraft KX2 y KX3. El resto de la línea está escrito a partir de referencias CAT publicadas, así que por favor reporta qué pasa, funcione o no.\n\nSi la radio no responde, casi siempre es una de estas:\n\n- **La velocidad debe coincidir** con el menú CAT de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Algunas radios necesitan CAT habilitado** en el menú antes de responder.\n- **Las radios Kenwood esperan RTS**: su puerto CAT lo usa como handshake, así que Mantener RTS en alto (en Configuración avanzada) debe estar activado. Una conexión creada antes de que viniera activado por defecto puede tenerlo desactivado. En un Digirig u otro cable que active el PTT desde RTS, desactívalo, o la radio transmitirá.\n\n**Varios front-ends SDR hablan este mismo protocolo**, así que vale la pena probar esta entrada también con ellos; las radios Elecraft aparecen aparte, bajo Elecraft. Si la frecuencia es correcta pero el modo no, o falta, esa es justamente la parte que varía en la línea — la app lo deduce de la radio y, si no, lo pregunta directamente, así que el modo puede simplemente tardar un poco.';
	@override String get statusConnected => 'Conectado';
	@override String get statusLost => 'Desconectada';
	@override String get notConfigured => 'Sin configurar';
	@override String get currentConfiguration => 'Configuración actual';
	@override String get currentTransceiver => 'Radio actual';
	@override String get currentTransceivers => 'Radios actuales';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => 'Los mensajes se encolan en lugar de interrumpir';
	@override String get noRadioBSelected => 'Ninguna Radio B seleccionada';
	@override String get radioMode => 'Modo de la radio';
	@override String get keyerNotSupported => 'No compatible con la radio actual';
	@override String get catControlPreferences => 'Preferencias de control CAT';
	@override String get chooseTransceiver => 'Elegir radio';
	@override String get configurationSection => 'Configuración';
	@override String get noTransceiverSelected => 'Ninguna radio seleccionada';
	@override String makeMainVfo({required Object name}) => 'Usar ${name} para el VFO principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		zero: 'Ninguna radio',
		one: '${count} radio',
		other: '${count} radios',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} antena',
		other: '${count} antenas',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} otro equipo',
		other: '${count} otros equipos',
	);
	@override String get equipmentInventory => 'Inventario de equipos';
	@override String get equipmentInUse => 'Controles de la radio';
	@override String get noTransceiver => 'Ninguno';
	@override String get peerRadioNotAvailable => 'No disponible';
	@override String peerRadioOnDevice({required Object device}) => 'En ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} está en otro dispositivo';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Esta radio está conectada a ${device}. Su conexión y sus opciones se configuran en ese dispositivo.';
	@override String get antennaInUse => 'Antena en uso';
	@override String get keyInUse => 'Manipulación CW';
	@override String get phoneKeying => 'Fonía grabada';
	@override String get phoneKeyingNone => 'Ninguna';
	@override String phoneKeyingRadio({required Object radio}) => 'Memorias en ${radio}';
	@override String get phoneKeyingComputer => 'Audio en esta computadora';
	@override String get phoneKeyingOff => 'La fonía grabada está apagada';
	@override String get computerVoiceSettings => 'Audio de la computadora';
	@override String get cwKeyingOptions => 'Opciones de manipulación CW';
	@override String get noneSelected => 'Ninguno';
	@override String get moreSettings => 'Más opciones';
	@override String get icomCivTroubleshootingTitle => 'Si aparecen dos puertos serie para la misma radio';
	@override String get icomCivTroubleshooting => 'Varias radios Icom, entre ellas la IC-705, presentan **dos** puertos serie USB a la vez (Icom los llama Puerto A y Puerto B), ambos configurados en CI-V por defecto. Ni esta app ni tu sistema operativo pueden distinguirlos más allá de eso: el mismo identificador de fabricante/producto USB aparece dos veces, a veces marcado aquí con un sufijo `#2`. **El Puerto A suele ser el correcto** — normalmente el primero que lista tu sistema operativo o navegador, y cuando esta app puede distinguir los dos puertos marca ese como sugerido. Si los comandos salen y la radio nunca responde, prueba el otro puerto.';
	@override String get civAddressTroubleshootingTitle => 'Si la radio nunca responde';
	@override String get civAddressTroubleshooting => '- **La dirección CI-V debe coincidir** con el menú de la radio. Esta entrada rellena la dirección de fábrica del modelo, pero un equipo que comparte un bus CI-V es justo donde eso se cambia. Una trama enviada a la dirección equivocada se ignora en silencio, lo que se ve exactamente igual que un cable muerto.\n- **La velocidad debe coincidir** con el CI-V BAUD RATE de la radio (por USB, CI-V USB Baud Rate). Pon en la radio el mismo número que aquí, **no Auto**. En Auto algunas radios, entre ellas la IC-7300, conectan y dejan de responder al cabo de un minuto más o menos.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **La dirección CI-V debe coincidir** con el menú de la radio. Esta entrada rellena la dirección de fábrica del modelo, pero un equipo que comparte un bus CI-V es justo donde eso se cambia. Una trama enviada a la dirección equivocada se ignora en silencio, lo que se ve exactamente igual que un cable muerto.\n${speed}\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.';
	@override String get icomUsbSpeedFollows => '- **No hay velocidad que configurar.** Por USB esta radio habla a la velocidad que use la computadora, y esta entrada siempre usa 115200, la velocidad que necesita el espectro.';
	@override String get ic7610UsbSpeed => '- **Pon CI-V USB Baud Rate en 115200**, la velocidad que esta entrada siempre usa, porque el espectro la necesita — **no Auto**. Una radio en cualquier otra velocidad responde con silencio.';
	@override String get civTransceiveTitle => 'Si la app tarda en seguir a la radio';
	@override String get civTransceive => 'Si la app tarda varios segundos en mostrar un cambio de frecuencia o modo hecho en la radio, activa el ajuste **CI-V Transceive** de la radio (en la mayoría de los modelos actuales, en SET > Connectors > CI-V). Con él activado, la radio reporta cada cambio en el momento en que ocurre. Con él desactivado, la app solo ve un cambio la próxima vez que pregunta, cada pocos segundos.';
	@override String get ic7300Mk2Note => '\n- El **IC-7300 MK2** viene con la dirección `B6`, no con el `94` que se rellena aquí: elige la entrada IC-7300 MK2.';
	@override String get ic705PortNote => '\n- El **IC-705** presenta dos puertos serie USB, ambos con el nombre de la radio. CI-V está en el **primero**, que el selector señala cuando puede distinguirlos.';
	@override String get ic7760PortNote => '\n- El **IC-7760** usa CI-V en el **Puerto A** de los dos puertos serie USB que presenta.';
	@override String get x6100PortNote => '\n- El **X6100** usa CI-V en su puerto **DEV**, el segundo de los dos puertos serie que presenta, y el que el selector señala.';
	@override String get rigctldTroubleshootingTitle => 'Si la app no puede conectar';
	@override String get rigctldTroubleshooting => 'Esto se conecta a un **daemon rigctld que ejecutas tú mismo**, no directamente a la radio — el backend de Hamlib es quien habla con la radio y soporta cientos de modelos.\n\n- **El daemon ya debe estar en ejecución**, p. ej. `rigctld -m 1035 -r /dev/ttyUSB0`. Encuentra el número de modelo de tu radio con `rigctl -l`.\n- **Desde otra máquina**, inícialo con `-T 0.0.0.0`: por defecto rigctld solo acepta conexiones desde la máquina donde corre.\n- **El puerto** es 4532 salvo que hayas iniciado el daemon con `-t`.\n- Una vez conectado, si falta la frecuencia normalmente es que el daemon mismo no puede comunicarse con la radio. Pruébalo con `rigctl -m 2 f` en la máquina del daemon.';
	@override String get flrigTroubleshootingTitle => 'Si la app no puede conectar';
	@override String get flrigTroubleshooting => 'Esto se conecta a un **programa flrig que ejecutas tú mismo**, no directamente a la radio — flrig habla con la radio y soporta la mayoría de marcas y modelos.\n\n- **flrig ya debe estar en ejecución**, con su radio configurada y conectada.\n- **El puerto** es 12345 salvo que lo hayas cambiado en la configuración de flrig (Config → Setup → Server).\n- **Desde otra máquina**, asegúrate de que el servidor de flrig sea accesible. Escucha en todas las interfaces, pero tu firewall puede no estar de acuerdo.\n- Una vez conectado, si falta la frecuencia normalmente es que flrig mismo no puede comunicarse con la radio. Verifica que la pantalla de flrig siga el dial.';
	@override String get hrdTroubleshootingTitle => 'Si la app no puede conectar';
	@override String get hrdTroubleshooting => 'Esto se conecta al **Rig Control de Ham Radio Deluxe, que se ejecuta en tu computadora**, no directamente a la radio — HRD habla con la radio.\n\n- **Rig Control ya debe estar en ejecución** y conectado a la radio.\n- **Su servidor IP debe estar habilitado.** Rig Control solo se comunica con otros programas a través de él.\n- **El puerto** es 7809 salvo que lo hayas cambiado en la configuración del servidor IP.\n- **Desde otra máquina**, asegúrate de que tu firewall deje pasar la conexión.\n\nEsta entrada se escribió a partir de descripciones publicadas del protocolo de HRD y no se ha probado con HRD. Si funciona a medias, vale la pena reportarlo.';
	@override String get n3fjpTroubleshootingTitle => 'Si la app no puede conectar';
	@override String get n3fjpTroubleshooting => 'Esto se conecta a **un programa de log N3FJP que se ejecuta en tu computadora**, no directamente a la radio — N3FJP habla con la radio.\n\n- **La API del programa debe estar activada**: Settings → Application Program Interface, marca **TCP API Enabled**.\n- **El puerto** es 1100 salvo que lo hayas cambiado ahí.\n- **N3FJP debe tener configurada una interfaz de radio** para seguir o sintonizar la radio. Sin ella, solo reporta lo que se escribe en su ventana de entrada.\n- N3FJP reporta solo banda, modo y frecuencia: ni potencia ni estado de transmisión.\n\nEsta entrada se escribió a partir de la API publicada de N3FJP y no se ha probado con N3FJP. Si funciona a medias, vale la pena reportarlo.';
	@override String get commanderTroubleshootingTitle => 'Si la app no puede conectar';
	@override String get commanderTroubleshooting => 'Esto se conecta a **DXLab Commander, que se ejecuta en tu computadora**, no directamente a la radio — Commander habla con la radio.\n\n- **Commander ya debe estar en ejecución** y conectado a la radio.\n- **Su servicio de red debe estar activado**: el botón **Net Serv** del panel Radio en la ventana de configuración de Commander.\n- **El puerto** es 52002, el tercero del bloque que empieza en el **Base Port** de Net Serv (52000 salvo que lo hayas cambiado).\n- **Desde otra máquina**, asegúrate de que tu firewall deje pasar la conexión.\n\nEsta entrada se escribió a partir de los mensajes TCP publicados de Commander y no se ha probado con Commander. Si funciona a medias, vale la pena reportarlo.';
	@override String get ic705TroubleshootingTitle => 'Si la radio nunca responde';
	@override String get ic705Troubleshooting => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview o RS-BA1 conectado a la misma radio ocupa esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio.** La WLAN debe estar encendida, la radio en la misma red y su función de control remoto (Network) habilitada.\n- **Los puertos deben coincidir** con el Control Port y el Serial Port (UDP) de la radio, o con los puertos redirigidos a ellos. Un puerto equivocado se encuentra con silencio, igual que una radio apagada.\n- **Reinicia la WLAN de la radio** si sigue atascada. Eso libera de forma confiable una sesión atascada en la radio.\n\nUna **contraseña incorrecta se rechaza explícitamente**, no con silencio. Si llegaste aquí en lugar de ver un mensaje de "rechazada", la contraseña no es el problema.';
	@override String get icomLanTroubleshooting => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview, RS-BA1 o el Remote Utility de Icom conectados a la misma radio ocupan esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio.** Su puerto LAN debe estar conectado a la misma red que este dispositivo, su **Network Control** debe estar activado, y el usuario y la contraseña deben estar configurados como usuario de red en la radio.\n- **Los puertos deben coincidir** con el Control Port y el Serial Port (UDP) de la radio, o con los puertos redirigidos a ellos. Un puerto equivocado se encuentra con silencio, igual que una radio apagada.\n- **Si conecta pero nunca responde**, la dirección CI-V de aquí debe coincidir con el menú CI-V ADDRESS de la radio. Esta entrada rellena la dirección de fábrica del modelo.\n- **Apaga y enciende la radio** si sigue atascada.';
	@override String get statusStale => 'Sin respuesta';
	@override String get statusDisconnected => 'No conectada';
	@override String get statusConnecting => 'Conectando…';
	@override String get statusDisconnecting => 'Desconectando…';
	@override String get statusError => 'Fallo de conexión';
	@override String get currentRadioSettings => 'Configuración de la radio actual';
	@override String get notSupportedByThisRadio => 'No compatible con esta radio';
	@override String get cwMessagesButton => 'Mensajes de CW';
	@override String get voiceMessagesButton => 'Mensajes de fonía';
	@override String voiceKeyerAvailable({required Object count}) => 'Manipulador de voz: ${count} memorias en la radio';
	@override String get antennaBands => 'Bandas';
	@override String get antennaType => 'Tipo de antena';
	@override String get antennaTypeRequired => 'Elige un tipo de antena';
	@override late final _Translations$settings$station$antennaTypes$es antennaTypes = _Translations$settings$station$antennaTypes$es._(_root);
	@override String get keyType => 'Tipo de manipulador';
	@override String get keyTypeRequired => 'Elige un tipo de manipulador';
	@override late final _Translations$settings$station$keyTypes$es keyTypes = _Translations$settings$station$keyTypes$es._(_root);
	@override String get softwareIntermediaries => 'Intermediarios de software';
	@override String get otherBrands => 'Otras marcas';
	@override String get otherEquipment => 'Otros equipos (antenas, manipuladores, etc.)';
	@override String get newAntenna => 'Nueva antena';
	@override String get newKey => 'Nuevo manipulador';
	@override String get newKeyer => 'WinKeyer (K1EL o compatible)';
	@override String keyViaRadio({required Object radio}) => 'Manipulador CAT en ${radio}';
	@override String keyOnDevice({required Object device}) => 'Manipulador en ${device}';
	@override String get trackStationInfo => 'Registrar datos de la estación en cada QSO';
	@override String get includeStationInfoInAdif => 'Incluir en las exportaciones ADIF';
	@override String get whatToTrack => '¿Qué registrar?';
	@override String get trackFieldRig => 'Radio';
	@override String get trackFieldPower => 'Potencia';
	@override String get watts => 'Vatios';
	@override String get trackFieldAntenna => 'Antena';
	@override String get trackFieldKey => 'Manipulador';
	@override String get placeholderConnectDelay => 'Retraso de conexión (ms)';
	@override String get placeholderConnectDelayDescription => 'Cuánto tarda el handshake simulado. En blanco o 0 conecta al instante.';
	@override String get placeholderDropAfter => 'Desconectar tras (segundos)';
	@override String get placeholderDropAfterDescription => 'Cierra la conexión por su cuenta, para probar la reconexión. En blanco o 0 nunca desconecta.';
	@override String get placeholderFailConnect => 'Fallar siempre al conectar';
	@override String get placeholderConnectFailure => 'Se le indicó a la radio simulada que rechazara esta conexión';
	@override String get placeholderFreq => 'Frecuencia (kHz)';
	@override String get placeholderFreqDescription => 'Dónde arranca la radio simulada. Después reporta la frecuencia a la que la app la sintonice.';
	@override String get placeholderMode => 'Modo';
	@override String get placeholderModeDescription => 'El modo con el que arranca la radio simulada, por ejemplo USB, CW, FT8.';
	@override String get placeholderPower => 'Potencia (vatios)';
	@override String get placeholderPurpose => 'Usa esta radio para registrar con qué equipo estás operando';
	@override String get placeholderReplyDelay => 'Retraso de respuesta (ms)';
	@override String get placeholderReplyDelayDescription => 'Cuánto tarda la radio simulada en reportar un cambio. En blanco o 0 responde de inmediato.';
	@override String get cwKeyerField => 'Manipulador de CW por CAT';
	@override String get cwKeyerFieldDescription => 'Si esta radio manipula CW desde texto por CAT. Apagado para una radio que la app no conoce.';
	@override String get voiceMemories => 'Memorias de voz';
	@override String get voiceMemoriesDescription => 'Cuántas memorias de voz reproduce la radio por CAT. 0 si ninguna.';
	@override String get voiceMemoriesInvalid => 'Un número entero, 0 o más';
	@override String get yaesuMeterCapture => 'Capturar lecturas de medidores';
	@override String get yaesuBinaryMeterCaptureDescription => 'Lee el medidor de potencia de salida y el indicador de ROE alta de la radio mientras transmite y escribe los valores en bruto en el log. Sirve para construir la escala que Yaesu no publica — los valores no se muestran como medidores.';
	@override String get yaesuMeterCaptureDescription => 'Lee los medidores PO, ROE y ALC de la radio mientras transmite y escribe los valores en bruto en el log. Sirve para construir la escala que Yaesu no publica — los valores no se muestran como medidores.';
	@override String get telemetryInterval => 'Intervalo de lectura de medidores (ms)';
	@override String get telemetryIntervalDescription => 'Cada cuánto se leen los medidores de la radio mientras transmite. Déjalo en blanco para lo más rápido que admita esta conexión, hasta 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Un número entero de milisegundos, de ${min} a ${max}';
	@override String get pollInterval => 'Intervalo de consulta en reposo (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Cada cuánto se pide a la radio su frecuencia y modo mientras no cambian. Déjalo en blanco para ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Un número entero de milisegundos, de ${min} a ${max}';
	@override String get advancedSettings => 'Configuración avanzada';
	@override String get placeholderSwr => 'Lectura de ROE';
	@override String get placeholderSwrDescription => 'Qué ROE indica esta radio mientras transmite. Por encima de 1,8 el panel avisa.';
	@override String get placeholderSwrInvalid => 'Un número, 1 o más';
	@override String get keyerNone => 'Ninguno';
	@override String get cwDialect => 'Dialecto de manipulación de CW';
	@override String get cwDialectDescription => 'Qué forma del comando KY acepta esta radio. Ninguno significa sin manipulación CW por CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, rellenado a 24)';
	@override String get cwDialectElecraft => 'Elecraft (KY texto)';
	@override String get voiceDialect => 'Dialecto del manipulador de voz';
	@override String get voiceDialectDescription => 'Cómo reproduce esta radio sus memorias de voz por CAT. Ninguno significa sin memorias de voz por CAT. Con dialecto y sin cantidad, se aplica la cantidad por defecto del dialecto.';
	@override String get voiceDialectPb => 'Kenwood (PB, estilo TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB y DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (pulsaciones de teclas)';
	@override String get placeholderDiagnostic => 'Simulada';
	@override String get placeholderWholeNumberInvalid => 'Debe ser un número entero, 0 o más';
	@override String get placeholderFreqInvalid => 'Debe ser una frecuencia en kHz, mayor que cero';
	@override String get placeholderModeInvalid => 'Debe ser un nombre de modo, por ejemplo USB, CW, FT8';
	@override String get switchLayout => 'Disposición';
	@override String get switchLayoutDescription => 'En qué lado del conmutador están conectadas tus radios.';
	@override String get switchLayoutRequired => 'Elige cómo está cableado el conmutador';
	@override String switchCommandRefused({required Object command, required Object code}) => 'El conmutador rechazó "${command}" (error ${code})';
	@override String get switchBusyTransmitting => 'Ese puerto está transmitiendo — la antena no se cambió';
	@override String get switchNoAntenna => 'Ninguna';
	@override String switchAntennaFor({required Object port}) => 'Antena en el puerto ${port}';
	@override String get switchAntennaForDescription => 'Cuál de tus antenas está conectada a este puerto del conmutador.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antenas, ${radios} radios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antenas, 1 radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antena, ${radios} radios';
	@override String get switchCommonPort => 'Común';
	@override String get dcnAddress => 'Dirección del dispositivo';
	@override String get dcnAddressDescription => 'La dirección configurada en los interruptores DIP del módulo. Un módulo de relés coaxiales sale de fábrica con la 2.';
	@override String get dcnAddressRequired => 'Debe ser una dirección de dispositivo del 1 al 99';
	@override String switchPortLabel({required Object port}) => 'Puerto ${port}';
	@override String get switchPortAutoHint => 'sigue los datos de banda';
	@override String get switchPortTransmittingHint => 'transmitiendo — no se puede cambiar ahora';
	@override String get switchCurrentStateHeader => 'Estado actual';
	@override String get switchCurrentStateDescription => 'En qué antena está ahora mismo cada puerto de radio. Los cambios surten efecto de inmediato.';
	@override String get switchWiringHeader => 'Cableado';
	@override String get switchPortInhibitedHint => 'transmisión inhibida';
	@override String get rotatorAxes => 'Ejes';
	@override String get rotatorAxesDescription => 'Si el rotor gira solo en azimut, o también en elevación (un G-5500 o similar).';
	@override String get rotatorAxesAzimuth => 'Solo azimut';
	@override String get rotatorAxesAzimuthElevation => 'Azimut y elevación';
	@override String get rotatorAzimuthOffset => 'Desplazamiento de azimut';
	@override String get rotatorAzimuthOffsetDescription => 'Grados que se suman a lo que lee el controlador, cuando su cero no es el norte verdadero. Los giros se corrigen en consecuencia.';
	@override String get rotatorElevationOffset => 'Desplazamiento de elevación';
	@override String get rotatorAzimuthMin => 'Azimut mínimo';
	@override String get rotatorAzimuthMax => 'Azimut máximo';
	@override String get rotatorAzimuthMaxDescription => 'En los grados propios del controlador. Más de 360 para un rotor con solapamiento, que entonces toma el giro más corto.';
	@override String get rotatorElevationMin => 'Elevación mínima';
	@override String get rotatorElevationMax => 'Elevación máxima';
	@override String get rotatorElevationMaxDescription => 'En los grados propios del controlador. Más de 90 para un rotor que se da la vuelta.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => 'Grados enteros, de ${min} a ${max}';
	@override String get rotatorLimitsInvalid => 'El límite inferior tiene que ser menor que el superior';
	@override String get rotatorPollInterval => 'Intervalo de consulta (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'Cada cuánto se le pregunta al rotor hacia dónde apunta. Déjalo en blanco para ${fallback} ms.';
	@override String get rotatorAxesRequired => 'Elige en qué ejes gira el rotor';
	@override String get rotatorRefused => 'El controlador rechazó un comando. Comprueba que esté en modo GS-232.';
	@override String get pstRotatorTroubleshooting => 'PstRotator responde solo una vez que está configurado para ello, y si no, no dice absolutamente nada:\n\n- **Activa UDP Control** en el menú Setup de PstRotator.\n- **Iguala el puerto**: Communication → UDP Control Port, 12000 salvo que lo hayas cambiado. PstRotator responde en el puerto siguiente (12001), que tiene que estar libre en este dispositivo.\n- **Conecta PstRotator a su controlador.** Hasta que lo esté, no responde nada por UDP.\n- **Permítelo en el firewall** del PC donde corre PstRotator, y en este dispositivo, que escucha las respuestas.\n- **En un Mac, iPhone o iPad**, Ham2K Logger necesita acceso a la red local (Configuración → Privacidad y seguridad → Red local).';
	@override String rotatorCurrentStateHeader({required Object position}) => 'Estado actual: ${position}';
	@override String get rotatorDisconnected => 'desconectado';
	@override String rotatorAzimuthReading({required Object degrees}) => '${degrees}° de azimut';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '${degrees}° az';
	@override String rotatorElevationReading({required Object degrees}) => '${degrees}° de elevación';
	@override String rotatorElevationReadingShort({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNoReading => 'Esperando a que el controlador reporte su posición…';
	@override String get rotatorNotResponding => 'no responde';
	@override String rotatorHeldAtLimit({required Object heading}) => 'Girando hacia ${heading}, hasta donde permiten los límites de este rotor';
	@override String get rotatorTargetAzimuth => 'Girar a azimut';
	@override String get rotatorTargetAzimuthShort => 'Girar a az';
	@override String get rotatorTargetElevation => 'Girar a elevación';
	@override String get rotatorTargetElevationShort => 'Girar a el';
	@override String get rotatorAzimuthInvalid => 'Debe ser de 0 a 360';
	@override String get rotatorElevationInvalid => 'Debe ser de 0 a 180';
	@override String get rotatorTurn => 'Girar';
	@override String get rotatorStop => 'Detener';
	@override String get configUnreadable => 'No se pudo leer la configuración guardada de esta radio. Abre su configuración y vuelve a ingresarla, o quítala y agrégala de nuevo.';
	@override String get autoConnectHeld => 'HaLo dejó de responder la última vez que se conectó a esta radio, así que esta vez no se conectó por su cuenta. Pulsa Conectar para intentarlo de nuevo.';
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
	@override String get updateAll => 'Actualizar todo';
	@override String get updatingAll => 'Actualizando todos los archivos de datos…';
	@override String get neverDownloaded => 'Nunca descargado';
	@override String get updatedJustNow => 'Actualizado hace un momento';
	@override String updatedDaysAgo({required Object days}) => 'Actualizado hace ${days}d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Actualizado hace ${days}d ${hours}h';
	@override String updatedHoursAgo({required Object hours}) => 'Actualizado hace ${hours}h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Actualizado hace ${hours}h ${minutes}m';
	@override String updatedMinutesAgo({required Object minutes}) => 'Actualizado hace ${minutes}m';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'La última descarga traía solo ${imported} de ${existing} registros y no se usó. Actualiza para aceptarla.';
	@override String get extensionsSection => 'Extensiones';
}

// Path: settings.profiles
class _Translations$settings$profiles$es extends Translations$settings$profiles$en {
	_Translations$settings$profiles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Sin establecer';
	@override String get personalInfo => 'Datos personales';
	@override String get personalInfoNote => 'Esto puede incluirse en los logs generados cuando sea relevante para los envíos';
	@override String get name => 'Nombre';
	@override String get email => 'Correo electrónico';
	@override String get club => 'Club';
	@override String get arrlSection => 'Sección ARRL';
	@override String get racSection => 'Sección RAC';
	@override String get section => 'Sección';
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
	@override String get developerModeDescription => 'Habilita avisos de desarrollador, logs de depuración y herramientas.';
	@override String get experiments => 'Experimentos';
	@override String get showIdleMetrics => 'Mostrar métricas de inactividad';
	@override String get showIdleMetricsDescription => 'Muestra en la barra de estado qué tan inactivo estuvo el motor de extensiones durante el último segundo. Tócalo para ver los promedios de 10 y 60 segundos.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% inactivo';
	@override String get idleMetricsAverages => 'Prom. inactivo:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} habilitado',
		other: '${count} habilitados',
	);
	@override String get patchTrack => 'Canal de code push';
	@override String get patchTrackDescription => 'Qué canal de code push over-the-air sigue este dispositivo. Los canales más aventureros reciben correcciones antes, menos probadas. Los code push se aplican en el próximo reinicio.';
	@override String get trackStable => 'Estable';
	@override String get trackUnstable => 'Inestable';
	@override String get trackBleeding => 'Bleeding Edge';
	@override String checkingTrack({required Object track}) => 'Buscando un code push en "${track}"…';
	@override String get patchDownloaded => 'Code push descargado — reinicia la app para aplicarlo.';
	@override String noNewPatch({required Object track}) => 'No hay code push nuevo en "${track}".';
	@override String get noPatchInstalled => 'No hay code push instalado — ejecutando el binario de la versión.';
	@override String runningPatch({required Object patch}) => 'Ejecutando el code push #${patch}.';
	@override String get deepLinks => 'Enlaces profundos';
	@override String get registerUrlSchemes => 'Registrar esquemas de URL';
	@override String get registerUrlSchemesDescription => 'Permite que los enlaces com.ham2k:// abran esta copia de la app';
	@override String get registerUrlSchemesDone => 'Esta copia ahora abre los enlaces com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'No se pudo registrar: ${error}';
	@override String get systemInformation => 'Información del sistema';
	@override String get appVersion => 'Versión de la app';
	@override String get dataFolder => 'Carpeta de datos';
	@override String get loading => '(cargando…)';
	@override String get panelLoadFailed => 'No se pudo cargar este panel de configuración.';
	@override String get extDevServer => 'Servidor de desarrollo de extensiones';
	@override String get extensionSettings => 'Configuración de extensiones';
	@override String get extDevServerDescription => 'Carga extensiones desde un servidor de desarrollo en tu red en lugar de las incluidas en la app, y las recarga al guardar.';
	@override String get extDevServerAddress => 'Dirección del servidor';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Conectar';
	@override String get extDevServerDisconnect => 'Desconectar';
	@override String get extDevServerConnecting => 'Conectando…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Sirviendo ${count} extensión: ${keys}',
		other: 'Sirviendo ${count} extensiones: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Sin conexión';
	@override String get extDevServerReconnect => 'Reconectar al iniciar';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Última recarga: ${key} a las ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: '${count} extensión con errores de compilación',
		other: '${count} extensiones con errores de compilación',
	);
	@override String get catalog => 'Catálogo de extensiones';
	@override String get catalogDescription => 'Leer el catálogo desde otro servidor — uno local mientras se trabaja en el catálogo mismo. Vacío significa catalog.ham2k.net.';
	@override String get catalogAddress => 'Dirección del catálogo';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Canales de búsqueda del catálogo';
	@override String get catalogSearchStable => 'Solo estables';
	@override String get catalogSearchUnstable => 'Inestables o mejores';
	@override String get catalogSearchBleeding => 'Bleeding Edge o mejores';
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
	@override String get settings => 'Preferencias de la aplicación';
	@override String get settingsDescription => 'Haz que la app funcione como quieras';
	@override String get commonSettings => 'Preferencias comunes';
	@override String get syncDescription => 'Respalda y sincroniza tus logs entre dispositivos';
	@override String get accountsDescription => 'Credenciales de servicios, datos sin conexión y más';
	@override String get extensions => 'Extensiones y funciones';
	@override String get extensionsDescription => 'Actividades, concursos, paneles del tablero y más funciones';
	@override String get profilesDescription => 'Indicativo del operador y perfil de la estación';
	@override String get stationProfiles => 'Perfiles de estación';
	@override String get developerSettings => 'Configuración de desarrollador';
	@override String get developerSettingsDescription => 'Herramientas de depuración y desarrollo';
	@override String get about => 'Acerca de';
	@override String get aboutDescription => 'Versión, créditos e información legal';
	@override String get unavailableTitle => 'Algunas opciones no están disponibles';
	@override String get unavailableText => 'El motor de extensiones no pudo iniciarse, así que faltan las opciones aportadas por extensiones.';
	@override String get station => 'Configuración de Estación';
	@override String get stationDescription => 'Control CAT y más opciones';
	@override String get peers => 'Dispositivos cercanos';
	@override String get peersDescription => 'Conéctate con otros dispositivos cercanos';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$es extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos (FN31pr)';
	@override String get eight => '8 dígitos (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$es extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos';
	@override String get eight => '8 dígitos';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$es extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'Abrir el diálogo de comandos';
	@override String get toggleTheme => 'Cambiar entre claro y oscuro';
	@override String get toggleLanguage => 'Cambiar entre inglés y español';
	@override String get fontScaleUp => 'Texto más grande';
	@override String get fontScaleDown => 'Texto más pequeño';
	@override String get fontScaleReset => 'Tamaño de texto normal';
	@override String get densityLooser => 'Interfaz más amplia';
	@override String get densityDenser => 'Interfaz más compacta';
	@override String get densityAuto => 'Densidad de interfaz automática';
	@override String get find => 'Buscar en el log';
	@override String keyerMessage({required Object n}) => 'Enviar mensaje ${n}';
	@override String get keyboardMode => 'Modo teclado activado o desactivado';
	@override String get ptt => 'Pulsar para hablar (PTT)';
	@override String get wipe => 'Borrar el contacto que se está registrando';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$es extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'Escribir indicativos';
	@override String get escape => 'Detener el envío, retroceder un paso o cerrar';
	@override String get enter => 'Registrar el contacto';
	@override String get space => 'Siguiente campo';
	@override String get tab => 'Campo siguiente o anterior';
	@override String get arrows => 'Moverse entre campos, controles y el log';
	@override String get walk => 'Avanzar por páginas en el log, o ir a sus extremos';
	@override String get undo => 'Deshacer un borrado o una eliminación';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$es extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'Agregar atajo';
	@override String get listening => 'Pulsa las teclas del atajo…';
	@override String get listeningHint => 'Esc deja de escuchar';
	@override String get add => 'Agregar';
	@override String refusedFixed({required Object keys}) => '${keys} pertenece a los campos de logging o a un diálogo, y no se puede cambiar.';
	@override String refusedCallsign({required Object keys}) => '${keys} es como se escriben los indicativos. Mantén Cmd, Ctrl o Alt junto con ella.';
	@override String reserved({required Object keys}) => 'El sistema puede tomar ${keys} antes de que la app la vea.';
	@override String already({required Object keys}) => '${keys} ya es una de las teclas de este comando.';
	@override String takeIt({required Object keys, required Object command}) => 'Quitar ${keys} de “${command}”';
	@override String get resetDefault => 'Restablecer por defecto';
	@override String get remove => 'Quitar';
	@override String get commandLabel => 'Comando';
	@override String get commandHint => 'Ingresa cualquier comando válido, o varios comandos separados por ";"';
	@override String get removeCommand => 'Quitar comando';
	@override String commandUnknown({required Object text}) => 'Ningún comando lee “${text}”';
	@override String get noShortcuts => 'Sin tecla todavía';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$es extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'Atajos guardados en ${location}';
	@override String exportFailed({required Object error}) => 'No se pudieron exportar los atajos: ${error}';
	@override String importPickerFailed({required Object error}) => 'No se pudo abrir el archivo: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} no es un archivo de atajos que esta app pueda leer: ${problem}';
	@override String problemNotYaml({required Object line}) => 'el texto no es YAML válido (línea ${line})';
	@override String get problemNotKeysFile => 'no es un archivo de atajos de teclado de Ham2K';
	@override String get problemNewerVersion => 'fue escrito por una versión más nueva de la app';
	@override String get problemMalformed => 'parte de él no sigue el formato de atajos';
	@override String get problemTooLarge => 'es demasiado grande';
	@override String get importTitle => 'Importar atajos';
	@override String writtenOn({required Object platform}) => 'Escrito en ${platform}.';
	@override String get writtenOnUnknown => 'El archivo no dice en qué teclado fue escrito.';
	@override String get translate => '¿Qué debería ser cada una de estas teclas en este teclado?';
	@override String get leaveOut => 'Omitir esos atajos';
	@override String get replace => 'Reemplazar la configuración de este dispositivo';
	@override String get replaceHint => 'Cada atajo que no esté en el archivo vuelve a su valor por defecto.';
	@override String get merge => 'Agregar a la configuración de este dispositivo';
	@override String get mergeHint => 'Los atajos del archivo reemplazan a los de este dispositivo para los mismos comandos, y el resto se conserva.';
	@override String unknown({required Object commands}) => 'Desconocidos en esta versión, así que se omiten: ${commands}';
	@override String unreadableChords({required Object chords}) => 'No son atajos, así que se omiten: ${chords}';
	@override String refusedChords({required Object chords}) => 'Teclas que la app se reserva, así que se omiten: ${chords}';
	@override String conflicts({required Object keys}) => 'Asignadas a más de un comando tras la importación: ${keys}';
	@override String get importAction => 'Importar';
	@override String get imported => 'Atajos importados';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$es extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Comando';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$es extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$es extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'Indicativos de estación';
	@override String get groupBy => 'Agrupar por';
	@override String get period => 'Período';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$es extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get none => 'Sin agrupar';
	@override String get date => 'Fecha';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'Continente desconocido';
	@override String get unknownEntity => 'Entidad desconocida';
	@override String get unknownDate => 'Sin fecha';
}

// Path: home.logs.period
class _Translations$home$logs$period$es extends Translations$home$logs$period$en {
	_Translations$home$logs$period$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'Este mes';
	@override String get last3Months => 'Últimos 3 meses';
	@override String get thisYear => 'Este año';
	@override String get lastYear => 'Año pasado';
	@override String get allTime => 'Desde siempre';
	@override String get custom => 'Rango personalizado';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$es extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => 'en ${span}';
	@override String get custom => 'Rango personalizado';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$es extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get date => 'Fecha';
	@override String get time => 'Hora';
	@override String get freq => 'Frecuencia';
	@override String get mode => 'Modo';
	@override String get call => 'Indicativo';
	@override String get name => 'Nombre';
	@override String get station => 'Estación';
	@override String get band => 'Banda';
	@override String get sent => 'Env.';
	@override String get rcvd => 'Recib.';
	@override String get grid => 'Grilla';
	@override String get state => 'Estado';
	@override String get country => 'País';
	@override String get refs => 'Refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$es extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Log de QSOs';
	@override String get qsosDescription => 'Los QSOs del indicativo seleccionado, en todas las operaciones.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Total de QSOs, o la búsqueda de indicativo del QSO seleccionado.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'La ubicación del QSO seleccionado.';
}

// Path: home.logs.import
class _Translations$home$logs$import$es extends Translations$home$logs$import$en {
	_Translations$home$logs$import$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicativos: ${calls}';
	@override String get skippedOne => '1 registro no se pudo leer';
	@override String skippedOther({required Object count}) => '${count} registros no se pudieron leer';
	@override String get readingTitle => 'Leyendo archivo ADIF…';
	@override String get checkingTitle => 'Buscando duplicados…';
	@override String get importingTitle => 'Importando QSOs…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} de ${total} verificados';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importados, de ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$es extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'Por defecto';
	@override String untitledName({required Object number}) => 'Disposición ${number}';
	@override String switcherLabel({required Object name}) => 'Disposición: ${name}';
	@override String get menuNew => 'Nueva…';
	@override String get menuExport => 'Exportar…';
	@override String get menuImport => 'Importar…';
	@override String get menuTitle => 'Disposiciones';
	@override String get newTitle => 'Nueva disposición';
	@override String get editTitle => 'Editar disposición';
	@override String get edit => 'Editar';
	@override String get duplicateCurrent => 'Duplicar la disposición actual';
	@override String get startFromDefault => 'Empezar desde la disposición por defecto';
	@override String get nameLabel => 'Nombre';
	@override String get descriptionLabel => 'Descripción';
	@override String get create => 'Crear';
	@override String leaveEditTitle({required Object name}) => '¿Guardar los cambios en "${name}"?';
	@override String get leaveEditBody => 'Esta disposición tiene cambios que no has guardado.';
	@override String get discard => 'Descartar';
	@override String get deleteTitle => '¿Eliminar esta disposición?';
	@override String deleteBody({required Object name}) => '¿Seguro que quieres eliminar la disposición "${name}"?';
	@override String get exportTitle => 'Exportar disposición';
	@override String get exportPick => 'Paneles a exportar';
	@override String get tabSet => 'Grupo de pestañas';
	@override String get exportAction => 'Exportar';
	@override String exported({required Object location}) => 'Disposición guardada en ${location}';
	@override String exportFailed({required Object error}) => 'No se pudo exportar la disposición: ${error}';
	@override String get importTitle => 'Importar disposición';
	@override String importFromOtherView({required Object view}) => 'Hecha para la vista ${view}: se omiten los paneles que solo tiene esa vista.';
	@override String get viewHome => 'Inicio';
	@override String get viewOperation => 'Operación';
	@override String get viewLogs => 'Logs';
	@override String get viewChase => 'Cacería';
	@override String get importAsNew => 'Como una disposición nueva';
	@override String get importReplace => 'En lugar de esta disposición';
	@override String get importAdd => 'Agregada a esta disposición';
	@override String get importAddHint => 'Los paneles llegan en una nueva columna a la derecha.';
	@override String get importPick => 'Paneles a importar';
	@override String get importReplaceSettings => 'Reemplazar la configuración de los paneles que ya están aquí';
	@override String get importAction => 'Importar';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} no es una disposición que esta app pueda leer: ${problem}';
	@override String problemNotYaml({required Object line}) => 'el texto no es YAML válido (línea ${line})';
	@override String get problemNotLayoutFile => 'no es un archivo de disposición de Ham2K';
	@override String get problemNewerVersion => 'fue escrito por una versión más nueva de la app';
	@override String get problemNoArrangement => 'no contiene ninguna distribución de paneles';
	@override String get problemMalformed => 'parte de él no sigue el formato de disposición';
	@override String get problemTooLarge => 'es demasiado grande';
	@override String importPickerFailed({required Object error}) => 'No se pudo abrir el archivo: ${error}';
	@override String importFailed({required Object error}) => 'No se pudo importar la disposición: ${error}';
	@override String duplicateFailed({required Object error}) => 'No se pudo copiar la disposición: ${error}';
	@override String get importNothing => 'No se eligió ningún panel, así que no se importó nada.';
	@override String importSkipped({required Object panels}) => 'Omitidos: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'Se conservó ${panels}: la distribución para pantallas pequeñas no puede prescindir de él.';
	@override String get notOffered => 'No disponible en esta vista';
	@override String get alreadyPlaced => 'Ya está en esta disposición';
	@override String needsExtension({required Object name}) => 'Necesita ${name}';
	@override String get listRecoveredTitle => 'No se pudieron leer los nombres de las disposiciones';
	@override String get listRecoveredBody => 'No se pudo leer la lista de disposiciones de esta vista. Todas las disposiciones siguen aquí, numeradas en lugar de su nombre.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$es extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'El log y los campos de entrada';
	@override String get infoDescription => 'Lo que sabemos de la estación contactada';
	@override String get spotsDescription => 'Spots de los clústeres y programas de actividad';
	@override String get mapDescription => 'Dónde están los contactos';
	@override String get summariesDescription => 'Las estadísticas y puntuaciones de la operación, en las secciones y el orden que elijas';
	@override String get summariesSections => 'Secciones y orden';
	@override String get summariesDays => 'Cada día';
	@override String get summariesReset => 'Mostrar todo';
	@override String get summariesAllHidden => 'Todas las secciones están ocultas. Elige cuáles mostrar en la configuración de este panel.';
	@override String get clockDescription => 'Una esfera de reloj, en cualquier zona horaria';
	@override String get clockFace => 'Esfera';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analógica';
	@override String get clockZone => 'Zona horaria';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Este dispositivo';
	@override String get clockShowSeconds => 'Mostrar segundos';
	@override String get weatherDescription => 'El clima ahora y durante las próximas ocho horas, donde estás operando';
	@override String get weatherUseOperationLocation => 'Usar la ubicación de la operación';
	@override String get weatherLocation => 'Ubicación';
	@override String get weatherLocationDescription => 'Una grilla (FN31pr) o lat,lon. Se ignora mientras esté marcada \'Usar la ubicación de la operación\'.';
	@override String get weatherNoLocation => 'No hay ubicación establecida. Dale una a este panel en su configuración, o colócalo dentro de una operación que tenga una.';
	@override String weatherBadLocation({required Object location}) => 'No se pudo leer la ubicación ${location}. Usa una grilla como FN31pr, o 42.36,-71.06.';
	@override String get weatherUnreachable => 'No se pudo conectar con Open-Meteo — ¿sin red? Se intentará de nuevo en breve.';
	@override String get weatherUnreadable => 'Open-Meteo respondió, pero con algo ilegible. Se intentará de nuevo en breve.';
	@override String weatherGusts({required Object speed}) => 'ráfagas ${speed}';
	@override String get panelAgeNow => 'ahora mismo';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'hace ${count} min',
		other: 'hace ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'hace ${count} h',
		other: 'hace ${count} h',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$es weatherConditions = _Translations$operation$layout$panels$weatherConditions$es._(_root);
	@override String get websiteDescription => 'Una página web de tu elección, en un panel';
	@override String get websiteUrl => 'Dirección';
	@override String get websiteRefresh => 'Actualizar';
	@override String get websiteRefreshNever => 'Nunca';
	@override String get websiteRefresh1 => 'Cada minuto';
	@override String get websiteRefresh5 => 'Cada 5 minutos';
	@override String get websiteRefresh15 => 'Cada 15 minutos';
	@override String get websiteTitle => 'Nombre del panel';
	@override String get websiteRefreshNow => 'Actualizar ahora';
	@override String get websiteNoUrl => 'Aún no hay dirección. Abre la configuración de este panel para elegir una página.';
	@override String get websiteBadUrl => 'Eso no parece una dirección web. Debe empezar con https://';
	@override String get websiteNotHttps => 'Aquí solo se pueden mostrar direcciones https://.';
	@override String get websiteUnsupported => 'En este sistema no se pueden mostrar páginas web en un panel.';
	@override String get websiteOpenExternally => 'Abrir en el navegador';
	@override String websiteLoadFailed({required Object reason}) => 'No se pudo cargar la página: ${reason}';
	@override String get remoteScreenDescription => 'Una pantalla, app o ventana compartida por otro de tus dispositivos.';
	@override String get remoteScreenTarget => 'Pantalla';
	@override String get remoteScreenChoose => 'Elegir una pantalla…';
	@override String get remoteScreenPickerTitle => 'Pantallas compartidas';
	@override String get remoteScreenPickerEmpty => 'Ninguno de tus dispositivos está compartiendo una pantalla. Activa Compartir pantallas y ventanas en Configuración → Dispositivos cercanos, en el dispositivo que quieras ver.';
	@override String get remoteScreenUnset => 'No has elegido una pantalla. Abre la configuración de este panel para elegir una de las que comparten tus otros dispositivos.';
	@override String get remoteScreenConnecting => 'Conectando…';
	@override String get remoteScreenPeerAway => 'Ese dispositivo no está conectado ahora mismo.';
	@override String get remoteScreenNotOffered => 'Ese dispositivo dejó de compartir esta pantalla.';
	@override String get remoteScreenNoListener => 'Ese dispositivo no puede aceptar conexiones — revisa su firewall.';
	@override String get remoteScreenNoLan => 'Las pantallas solo se comparten por la red local, no por Bluetooth.';
	@override String get remoteScreenRefused => 'Ese dispositivo no quiso compartir esta pantalla.';
	@override String get remoteScreenSettings => 'Configuración del panel';
	@override String get remoteScreenAdjust => 'Ajustar vista';
	@override String get remoteScreenDetail => 'Detalle';
	@override String get remoteScreenDetailStandard => 'Estándar';
	@override String get remoteScreenDetailHigh => 'Alto';
	@override String get remoteScreenDetailMaximum => 'Máximo';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Acercar';
	@override String get remoteScreenZoomOut => 'Alejar';
	@override String get remoteScreenStopped => 'Esa pantalla o ventana ya no se está mostrando.';
	@override String get remoteScreenCaptureFailed => 'Ese dispositivo no pudo capturar esa pantalla — puede que necesite permiso de grabación de pantalla.';
	@override String get remoteScreenNoAnswer => 'Ese dispositivo no respondió. Puede que no tenga activado compartir pantalla.';
	@override String get remoteScreenNoMedia => 'No se pudo abrir una conexión para la imagen. Revisa el firewall de este dispositivo.';
	@override String get solarDescription => 'Condiciones solares y geomagnéticas, con propagación banda por banda';
	@override String get solarUnreachable => 'No se pudo conectar con hamqsl.com — ¿sin red? Se intentará de nuevo en breve.';
	@override String get solarUnreadable => 'hamqsl.com respondió, pero no con datos que podamos usar. Se intentará de nuevo en breve.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Día';
	@override String get solarBandNight => 'Noche';
	@override String get solarBandGood => 'Buena';
	@override String get solarBandFair => 'Regular';
	@override String get solarBandPoor => 'Mala';
	@override String solarSources({required Object primary, required Object secondary}) => 'Fuentes: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'La conexión tiene dificultades — se están omitiendo cuadros.';
	@override String get remoteScreenStalled => 'Los cuadros dejaron de llegar — puede que esta conexión sea demasiado lenta.';
	@override String get radioDescription => 'El panel frontal de una radio — frecuencia, modo y potencia, bajo control CAT';
	@override String get radioStyle => 'Estilo';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderno';
	@override String get radioRadio => 'Radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — ninguna radio designada';
	@override String get radioNoRadio => 'No hay radio que mostrar. Elige una en la configuración de este panel, o agrega una en Configuración de Estación.';
	@override String get radioNotConfigured => 'Esta radio aún no está configurada. Elige su puerto o dirección en Configuración de Estación.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radio no conectada';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Conectar esta radio';
	@override String get radioDisconnect => 'Desconectar esta radio';
	@override String get radioStale => 'SIN DATOS';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'ROE';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'ROE alta';
	@override String get rotatorDescription => 'Hacia dónde apunta la antena, en un mapa centrado en la estación. Toca el mapa para girarla.';
	@override String get rotatorRotator => 'Rotor';
	@override String rotatorAutoNamed({required Object name}) => 'Automático — ${name}';
	@override String get rotatorAutoNone => 'Automático — todavía sin rotor';
	@override String get rotatorBeamWidth => 'Ancho del haz';
	@override String get rotatorBeamWidthDescription => 'En grados, dibujado alrededor del rumbo. 0 no dibuja nada.';
	@override String get rotatorLocation => 'Ubicación';
	@override String get rotatorLocationDescription => 'Una grilla, o una latitud y longitud, para centrar el mapa. En blanco usa la ubicación de la operación.';
	@override String get rotatorTheme => 'Tema';
	@override String get rotatorThemeColor => 'Color';
	@override String get rotatorThemeGray => 'Gris';
	@override String get rotatorThemeMuted => 'Apagado';
	@override String get rotatorGrayline => 'Mostrar la línea gris';
	@override String get rotatorNoRotator => 'No hay rotor que mostrar. Elige uno en la configuración de este panel, o agrega uno en Configuración de Estación.';
	@override String get rotatorNoLocation => 'No hay ubicación para centrar el mapa. Establece una en la configuración de este panel.';
	@override String get rotatorDisconnected => 'desconectado';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => 'no responde';
	@override String get rotatorLocationInvalid => 'No se puede leer la ubicación en la configuración de este panel. Usa una grilla, o una latitud y longitud como 40.7, -74.0.';
	@override String rotatorElevation({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'O';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$es extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usar nombres de archivo compactos';
	@override String get descriptionOn => 'Nombres cortos pensados para los sitios de carga, como N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nombres legibles, como 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$es extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Incluir información privada';
	@override String get descriptionOn => 'Se incluyen nombres, direcciones, correos, grillas y notas';
	@override String get descriptionOff => 'Se omiten nombres, direcciones, correos, grillas y notas';
	@override String get note => 'La Exportación ADIF Completa siempre incluye todo';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$es extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Primero agrega un correo electrónico';
	@override String get needsEmailBody => 'El File Stash de Ham2K envía tus archivos al correo electrónico de tu cuenta LoFi, y con él inicias sesión en stash.ham2k.net. Tu cuenta aún no tiene uno confirmado — agrégalo en Configuración › Sincronización en la nube.';
	@override String get openSyncSettings => 'Abrir Sincronización en la nube';
	@override String get replaceTitle => 'Se reemplazará el envío reciente';
	@override String replaceBody({required Object name}) => 'Enviaste “${name}” hace menos de 6 horas y todavía no se ha descargado. Las cuentas gratuitas guardan un solo envío a la vez, así que enviar ahora lo reemplaza.';
	@override String get replaceConfirm => 'Enviar de todas formas';
	@override String get failedTitle => 'No se pudo enviar al File Stash de Ham2K';
	@override String get sentTitle => 'Enviado al File Stash de Ham2K';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Puedes recuperar este archivo visitando **[stash.ham2k.net](https://stash.ham2k.net)** desde cualquier navegador.',
		other: 'Puedes recuperar estos archivos visitando **[stash.ham2k.net](https://stash.ham2k.net)** desde cualquier navegador.',
	);
	@override String get mayHaveArrived => 'El File Stash no respondió — puede que el archivo haya llegado de todos modos. Revisa stash.ham2k.net antes de volver a enviarlo';
	@override String get notSent => 'no enviado';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Este archivo no llegó:',
		other: 'Estos ${count} archivos no llegaron:',
	);
	@override String get emailOffer => 'O, para tu comodidad, podemos enviarte un correo electrónico con un enlace directo.';
	@override String get emailMe => 'Enlace por email';
	@override String get emailSent => 'Te enviamos un enlace de descarga por correo electrónico.';
	@override String emailFailed({required Object error}) => 'No se pudo enviar el correo electrónico: ${error}';
	@override String get freeTier => 'Las cuentas gratuitas solo guardan un envío a la vez. Los suscriptores pueden guardar todos los que quieran.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count,
		one: 'Se envió ${count} archivo al File Stash de Ham2K (stash.ham2k.net)',
		other: 'Se enviaron ${count} archivos al File Stash de Ham2K (stash.ham2k.net)',
	);
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
	@override String get sorting => 'Ordenar por';
	@override String get sortByTime => 'Por hora del spot';
	@override String get sortByFrequency => 'Por frecuencia';
	@override String get sortByWanted => 'Más buscados';
	@override String get groupByBand => 'Agrupar por banda';
	@override String get groupCallsWithNotes => 'Agrupar Indicativos con Notas';
	@override String get alertingOnly => 'Solo spots con alertas';
	@override String get sourceNoReply => 'Sin respuesta';
	@override String get sourceError => 'Error';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$es extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'El panel de logging está ocupado';
	@override String get editingBody => 'Estás editando un contacto registrado. ¿Registrar este spot, o volver y terminar la edición?';
	@override String get composingBody => 'Empezaste a ingresar un contacto. ¿Registrar este spot, o volver y terminar lo que escribías?';
	@override String get goBack => 'Volver';
	@override String get clearAndLog => 'Borrar y registrar spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$es extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo para zurdos';
	@override String get descriptionOn => 'Usando el diseño para zurdos';
	@override String get descriptionOff => 'Usando el diseño para diestros';
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

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$es extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Mostrando banderas solo para contactos DX';
	@override String get all => 'Mostrando banderas para todos los contactos';
	@override String get none => 'Sin mostrar banderas';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$es extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sugerir operador';
	@override String get descriptionOn => 'Ofreciendo tu indicativo como operador cuando la operación usa otro indicativo de estación';
	@override String get descriptionOff => 'Dejando el operador en blanco salvo que lo completes';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$es extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar rumbo';
	@override String get descriptionOn => 'Mostrando el rumbo estimado hacia la estación';
	@override String get descriptionOff => 'Sin mostrar información de rumbo';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$es extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar también el rumbo inverso';
	@override String get descriptionOn => 'Mostrando también el rumbo desde la estación, como "45° / 225°"';
	@override String get descriptionOff => 'Mostrando solo el rumbo hacia la estación';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$es extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Intercambiar el orden de los reportes de señal';
	@override String get sentFirst => 'Primero el reporte enviado, luego el recibido';
	@override String get rcvdFirst => 'Primero el reporte recibido, luego el enviado';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$es extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Saltar al siguiente campo al ingresar RST';
	@override String get descriptionOn => 'Saltando al siguiente campo después del RST';
	@override String get descriptionOff => 'Sin saltar automáticamente';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$es extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte por defecto — Fonía';
	@override String get description => 'Se usa cuando Enviado o Recibido quedan vacíos en SSB, FM o AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$es extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte por defecto — CW y datos';
	@override String get description => 'Se usa cuando Enviado o Recibido quedan vacíos en CW, RTTY y otros modos digitales';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$es extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte por defecto — FT8 y FT4';
	@override String get description => 'Se usa cuando Enviado o Recibido quedan vacíos en los modos FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$es extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Teclas de Números';
	@override String get description => 'Muestra una fila de teclas numéricas sobre el teclado mientras registras';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$es extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tecla de barra y punto';
	@override String get description => 'Agrega una tecla contextual: “/” para indicativos, “.” para números';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$es extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrar al pulsar';
	@override String get description => 'Respuesta háptica al pulsar una tecla numérica';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$es extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get off => 'Deshabilitado';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$es extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'no hay indicativo de operador con el que iniciar sesión';
	@override String get connectFailed => 'no se pudo acceder al nodo';
	@override String get needsPassword => 'el nodo pide una contraseña y no hay ninguna guardada';
	@override String get loginFailed => 'el nodo no aceptó el inicio de sesión';
	@override String get disconnected => 'el nodo cerró la conexión';
	@override String get timeout => 'el nodo no respondió';
	@override String get off => 'Conectar al clúster está apagado';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$es extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$es extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlar el PTT con el teclado';
	@override late final _Translations$settings$radio$pttKey$modes$es modes = _Translations$settings$radio$pttKey$modes$es._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$es descriptions = _Translations$settings$radio$pttKey$descriptions$es._(_root);
	@override String get key => 'Tecla PTT';
	@override String get pill => 'TX';
	@override String get transmitting => 'Transmitiendo';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$es extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente del VFO';
	@override String get descriptionOn => 'Al dejar de girar el dial, redondeando la frecuencia a un paso razonable. Solo en modos de voz.';
	@override String get descriptionOff => 'Quedándose exactamente donde la sintonizaste.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$es extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: retardo de reposo';
	@override String get description => 'Cuánto debe detenerse el dial antes de redondear la frecuencia. Menos se siente inmediato; más deja margen para un giro lento.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$es extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: giro largo';
	@override String get description => 'Si te mueves al menos esto, la frecuencia se redondea a un kHz entero, por lento que hayas terminado.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$es extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: giro mínimo';
	@override String get description => 'Si te mueves menos que esto no se redondea la frecuencia, así que el ajuste fino se respeta.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$es extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: velocidad mínima';
	@override String get description => 'Si giras el dial más despacio que esto no se redondea la frecuencia, salvo que haya sido un giro largo.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$es extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM apagado';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter envía mensajes';
	@override String get off => 'Apagado';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter envía mensajes: ${state}. Toca para cambiar.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$es extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Velocidad del manipulador';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$es extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensajes de CW';
	@override String get notSupported => 'La radio actual no admite manipulación de CW';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Mensaje ${n}';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta de F${n}';
	@override String get details => 'Detalles';
	@override String get empty => '(vacío)';
	@override String get sets => 'Juego de mensajes';
	@override String get newSet => 'Nuevo juego';
	@override String get renameSet => 'Renombrar juego';
	@override String get deleteSet => 'Eliminar juego';
	@override String get newSetName => 'Nombre';
	@override String get setDefault => 'Por defecto';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Mensajes ESM';
	@override String get setSaved => 'Mis mensajes';
	@override String get repeat => 'Repetir mensaje 1';
	@override String get repeatShort => 'Repetir M1';
	@override String get cooldown => 'Pausa antes de repetir';
	@override String cooldownSeconds({required Object n}) => '${n} segundos';
	@override String get repeatWait => 'Repitiendo';
	@override String get keyboard => 'Escribir para transmitir';
	@override String get keyboardField => 'Escribe para transmitir';
	@override String get help => 'Ayuda';
	@override String get helpTitle => 'Cómo escribir mensajes de CW';
	@override String get helpIntro => 'Los mensajes pueden usar plantillas con los siguientes valores:';
	@override String get helpOpCall => 'Tu indicativo';
	@override String get helpQsoCall => 'Su indicativo — en una pila //, el indicativo que se registrará';
	@override String get helpQsoFullCall => 'Su indicativo, si hay un indicativo válido; vacío si es parcial';
	@override String get helpQsoPartial => 'Un indicativo parcial; vacío si hay un indicativo completo válido';
	@override String get helpQsoNextCall => 'En una pila //, el indicativo que se seleccionará para registrar a continuación, si hay un indicativo completo válido';
	@override String get helpQsoNextPartial => 'En una pila //, el siguiente parcial después de registrar el contacto actual';
	@override String get helpQsoName => 'Su nombre de pila: el que escribiste o, si no, el de la búsqueda';
	@override String get helpQsoState => 'Su estado: el que escribiste o, si no, el de la búsqueda';
	@override String get helpKeyerMsg => 'El mensaje 1 tal como se enviaría, dentro de otro mensaje. Válido para los mensajes 1 a 8';
	@override String get helpQsoRst => 'El reporte que envías';
	@override String get helpQsoSerial => 'Tu número de serie, en un concurso que lo envía';
	@override String get helpPad => 'Rellena con ceros hasta esa cantidad de dígitos: 7 se envía como 007';
	@override String get helpCut => 'Números abreviados, T por 0 y N por 9: 599 se envía como 5NN';
	@override String get helpCutDigits => 'Elige qué dígitos abreviar, entre comillas — 0 es T, 1 es A, 5 es E, 9 es N';
	@override String get helpFullExample => 'Ejemplo completo:';
	@override String get helpExample => 'Envía W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Con Enter envía mensajes activado, Enter envía los mensajes según su tecla de función, como hace N1MM. El juego Mensajes ESM empieza con estos:';
	@override String get helpEsmCq => 'En Run, Enter con el indicativo vacío llama CQ';
	@override String get helpEsmExchange => 'Tu intercambio: tras su indicativo en Run, tras su respuesta en S&P';
	@override String get helpEsmThanks => 'Las gracias, una vez registrado el contacto: qso es el contacto tal como se registró, next el que sigue';
	@override String get helpEsmMyCall => 'En S&P, tu indicativo a la estación que contestas';
	@override String get helpEsmHisCall => 'En Run, su indicativo antes de tu intercambio';
	@override String get helpEsmAgain => 'Pide repetir cuando no se copió nada de su intercambio';
	@override String get helpEsmStackThanks => 'F3 sugerido para pilas //: da las gracias, luego llama a la siguiente estación de la pila y envía tu intercambio, o pide repetir un parcial (TU KR?); si no queda nada, solo TU';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$es extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Manipulador';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => 'Voz';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$es extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensajes de fonía';
	@override String get notSupported => 'La radio actual no admite mensajes de fonía';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memoria de voz ${n}';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta de la memoria de voz ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Vacía';
	@override String get notMeasured => 'Duración desconocida';
	@override String get playButton => 'Reproducir';
	@override String get recordButton => 'Grabar';
	@override String get stopButton => 'Detener';
	@override String get repeat => 'Repetir mensaje 1';
	@override String recordHelpTitle({required Object model}) => 'Notas para ${model}:';
	@override String namedOnDevice({required Object device}) => 'Estas memorias están en la radio de ${device}. Sus nombres y duraciones pertenecen a ese dispositivo.';
	@override String get namedOnRadio => 'Se guarda en la radio, donde también lo ven sus otros clientes.';
	@override String get recordHelpYaesuDvs => 'Espera al indicador [REC] en la radio, luego mantén pulsado el PTT y graba tu mensaje. Termínalo pulsando el botón Detener aquí en la app antes de soltar el PTT para evitar clics indeseados.';
	@override String get recordHelpFt891 => 'Espera a que el indicador [REC] parpadee al menos cuatro veces, luego mantén pulsado el PTT y graba tu mensaje. Termínalo pulsando el botón Detener aquí en la app antes de soltar el PTT para evitar clics indeseados.';
	@override String get pill => 'Voz';
	@override String play({required Object n}) => 'Reproducir la memoria ${n}';
	@override String get stop => 'Detener';
	@override String record({required Object n}) => 'Grabar la memoria ${n}';
	@override String get stopRecording => 'Detener la grabación';
	@override String get playing => 'Reproduciendo…';
	@override String get recording => 'Grabando…';
	@override String playingMemory({required Object label}) => 'Reproduciendo ${label}';
	@override String recordingMemory({required Object label}) => 'Grabando ${label}';
	@override String get doubtful => '¿La radio lo reprodujo? Dijo estar en reposo de inmediato.';
	@override String get recordOnRadio => 'Tienes que grabar las memorias en la propia radio.';
	@override String get sets => 'Juego de mensajes';
	@override String get soundFilesSet => 'Archivos de sonido en esta computadora';
	@override String get openFileButton => 'Abrir archivo';
	@override String get newSet => 'Nuevo juego';
	@override String get renameSet => 'Renombrar juego';
	@override String get deleteSet => 'Eliminar juego';
	@override String get newSetName => 'Nombre';
	@override String deleteSetConfirm({required Object name}) => '¿Eliminar ${name} y sus grabaciones? No se puede deshacer.';
	@override String get output => 'Enviar audio a';
	@override String get input => 'Grabar desde';
	@override String get outputRadio => 'Enviar a la radio por red';
	@override String get inputDefault => 'Predeterminado del sistema';
	@override String get pickDevice => 'Elegir un dispositivo de sonido';
	@override String deviceMissing({required Object name}) => '${name} (no conectado)';
	@override String get lead => 'Retardo al pasar a TX';
	@override String get tail => 'Retardo al volver a RX';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => 'Escuchar';
	@override String get notRecorded => 'Sin grabar';
	@override String get unplayable => 'No se puede reproducir este archivo';
	@override String get problemNoOutput => 'Elige el dispositivo de sonido que alimenta la radio antes de reproducir un mensaje.';
	@override String get problemOutputMissing => 'El dispositivo de sonido que alimenta la radio no está conectado.';
	@override String get problemInputMissing => 'El dispositivo de grabación no está conectado.';
	@override String get problemDeviceFailed => 'El dispositivo de sonido no se pudo abrir.';
	@override String get problemNotRecorded => 'Ese mensaje aún no tiene grabación.';
	@override String get problemRecordingSilent => 'No se escuchó nada desde el dispositivo de grabación, así que el mensaje quedó como estaba. Revisa la entrada y que la app tenga permiso para usar el micrófono.';
	@override String get problemRadioAudioUnavailable => 'La radio no está tomando audio de la app en este momento. Necesita una conexión de red con la radio.';
	@override String get problemSourceRefused => 'La radio no cambió su audio de transmisión a la app, así que el mensaje se detuvo. Configura la radio para transmitir el audio de la app.';
	@override String get problemCannotKey => 'Esta radio no puede ponerse en transmisión por CAT, así que la computadora no puede reproducir mensajes a través de ella.';
	@override String get problemUnplayable => 'El archivo de ese mensaje no es un archivo de sonido que la app pueda reproducir. Usa un archivo WAV, FLAC o MP3, o grábalo de nuevo.';
	@override String get problemRecordingFailed => 'La grabación se cortó, así que el mensaje quedó como estaba. Revisa que el dispositivo de grabación siga conectado y que haya espacio en el disco.';
	@override String get problemFileFailed => 'La grabación no se pudo guardar en el lugar del mensaje, así que el mensaje quedó como estaba.';
	@override String problemWordsMissing({required Object words}) => 'Ese mensaje necesita palabras que no has grabado: ${words}.';
	@override String problemTemplateFailed({required Object error}) => 'La plantilla de ese mensaje tiene un problema: ${error}';
	@override String get problemNoOperation => 'Los mensajes dichos con tus palabras se reproducen dentro de una operación, donde hay un contacto para el que decirlos.';
	@override String get problemNothingSaid => 'Ese mensaje no dice nada para este contacto.';
	@override String get templateField => 'Decir con mis palabras';
	@override String get templateHelp => 'Déjalo vacío para reproducir la grabación. Si no, el mensaje se dice con las palabras que grabaste, completadas para cada contacto, usando estos valores:';
	@override String get help => 'Ayuda';
	@override String get helpTitle => 'Decir mensajes con tus palabras';
	@override String get helpFullExample => 'Un mensaje completo:';
	@override String get helpExample => 'Su indicativo, su reporte y tu grabación de “QSL?”';
	@override String get playOnRadio => 'Reproducir en la radio';
	@override String get templateHelpCall => 'Su indicativo';
	@override String get templateHelpReport => 'El reporte que le das';
	@override String get templateHelpMessage => 'La grabación del mensaje 2, reproducida tal como se grabó';
	@override String get voiced => 'Dicho con tus palabras';
	@override String willSay({required Object words}) => 'Dice: ${words}';
	@override String willSayMissing({required Object words}) => 'Sin grabar todavía: ${words}';
	@override String get previewNoOperation => 'Abre una operación para ver qué dirá.';
	@override String get wordsDescription => 'Usa tu propia voz para indicativos, números y más.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$es extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Grabaciones de palabras';
	@override String get callField => 'Palabras para el operador';
	@override String get intro => 'Graba cada palabra o número tres veces, seguidas y rápido, como lo dices en un indicativo. Las frases más largas se graban una sola vez.';
	@override String get recordAll => 'Grabar todo';
	@override String get recordAllGuide => 'Lee cada palabra tres veces, seguidas, y una frase de varias palabras una sola vez, con una respiración entre líneas. Pulsa Detener después de la última.';
	@override String recordingOne({required Object word}) => 'Di “${word} ${word} ${word}” y luego pulsa Detener.';
	@override String recordingOnce({required Object words}) => 'Di “${words}” y luego pulsa Detener.';
	@override String get recorded => 'Grabada';
	@override String get notRecorded => 'Sin grabar';
	@override String get addPhrase => 'Agregar frase';
	@override String get phraseField => 'Frase, tal como la escribes en un mensaje';
	@override String get deletePhrase => 'Eliminar frase';
	@override String get tryField => 'Prueba decir';
	@override String get pauseLetters => 'Pausa entre letras';
	@override String get pauseWords => 'Pausa entre palabras';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => 'Velocidad';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => 'Configuración avanzada';
	@override String get splitSilent => 'No se escuchó nada en la grabación.';
	@override String get splitNotThreeTakes => 'No se encontraron tres tomas. Di la palabra tres veces, seguidas, e inténtalo de nuevo.';
	@override String get splitLineCount => 'No se encontraron todas las palabras en la lectura. Lee cada una tres veces, con una respiración entre palabras.';
	@override String get splitLinesTooClose => 'No se pudieron distinguir las palabras. Deja una respiración más larga entre palabras.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$es extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evitar batido cero en los spots';
	@override String get descriptionOn => 'Con una radio conectada, sintonizando unos pocos Hz fuera de un spot de CW, para que no todos los que respondan llamen en la misma nota.';
	@override String get descriptionOff => 'Sintonizando exactamente la frecuencia del spot.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$es extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Batido cero: margen de separación';
	@override String get description => 'A qué distancia de la frecuencia del spot situarse, a cada lado. El desplazamiento nunca es cercano a cero — eso sería un batido cero otra vez.';
}

// Path: settings.map.style
class _Translations$settings$map$style$es extends Translations$settings$map$style$en {
	_Translations$settings$map$style$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estilo del mapa';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$es extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar indicativos';
	@override String get description => 'Cada contacto es una píldora con su indicativo, en el color de su banda';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$es extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar línea gris';
	@override String get description => 'Sombrea el lado nocturno de la Tierra, con el crepúsculo como degradado';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$es extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automático';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$es extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartir datos de uso de la aplicación';
	@override String get descriptionOn => 'Ayudándonos a mejorar la app compartiendo datos de uso, configuración, fallos y rendimiento';
	@override String get descriptionOff => 'Manteniendo privados los datos de uso de la aplicación.\nEl equipo de Ham2K no podrá detectar fallos u otros problemas.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$es extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartir datos de operación';
	@override String get descriptionOn => 'Compartiendo algunos datos de operación de forma pública y con otros usuarios';
	@override String get descriptionOff => 'Manteniendo privados los datos de operación';
}

// Path: settings.station.models
class _Translations$settings$station$models$es extends Translations$settings$station$models$en {
	_Translations$settings$station$models$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get flexRadio => 'FlexRadio (SmartSDR)';
	@override String get ft891 => 'Yaesu FT-891';
	@override String get ft991a => 'Yaesu FT-991/A';
	@override String get ft710 => 'Yaesu FT-710';
	@override String get ftdx10 => 'Yaesu FTDX10';
	@override String get ftx1 => 'Yaesu FTX-1';
	@override String get ft817 => 'Yaesu FT-817 / FT-818';
	@override String get ft857 => 'Yaesu FT-857';
	@override String get ft897 => 'Yaesu FT-897';
	@override String get ft450 => 'Yaesu FT-450 / FT-450D';
	@override String get ftdx3000 => 'Yaesu FTDX3000';
	@override String get ft950 => 'Yaesu FT-950';
	@override String get ftdx1200 => 'Yaesu FTDX1200';
	@override String get ft2000 => 'Yaesu FT-2000 / FT-2000D';
	@override String get ftdx5000 => 'Yaesu FTDX5000';
	@override String get q900 => 'Guohetec Q900';
	@override String get tenTecEagle => 'Ten-Tec Eagle (599)';
	@override String get tenTecOrion => 'Ten-Tec Orion (565)';
	@override String get tenTecOrionII => 'Ten-Tec Orion II (566)';
	@override String get sotacat => 'SOTAcat (Elecraft KX2/KX3)';
	@override String get yaesuGeneric => 'Yaesu - Genérico';
	@override String get icomGeneric => 'Icom - Genérico';
	@override String get kenwoodGeneric => 'Kenwood - Genérico';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Genérico';
	@override String get kx2 => 'Elecraft KX2';
	@override String get kx3 => 'Elecraft KX3';
	@override String get k4 => 'Elecraft K4';
	@override String get ic705 => 'Icom IC-705';
	@override String get ic7300 => 'Icom IC-7300';
	@override String get ic7300mk2 => 'Icom IC-7300 MK2';
	@override String get ic706mkiig => 'Icom IC-706MKIIG';
	@override String get ic7100 => 'Icom IC-7100';
	@override String get ic7610 => 'Icom IC-7610';
	@override String get ic7760 => 'Icom IC-7760';
	@override String get ic9700 => 'Icom IC-9700';
	@override String get ic905 => 'Icom IC-905';
	@override String get ic7850 => 'Icom IC-7850';
	@override String get ic7851 => 'Icom IC-7851';
	@override String get x6100 => 'Xiegu X6100';
	@override String get g90 => 'Xiegu G90';
	@override String get rigctld => 'Radio controlada vía rigctld';
	@override String get rigctldNodeName => 'Mi radio (vía rigctld)';
	@override String get flrig => 'Radio controlada vía flrig';
	@override String get flrigNodeName => 'Mi radio (vía flrig)';
	@override String get hrd => 'Radio controlada vía Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Mi radio (vía HRD)';
	@override String get n3fjp => 'Radio controlada vía N3FJP';
	@override String get n3fjpNodeName => 'Mi radio (vía N3FJP)';
	@override String get commander => 'Radio controlada vía DXLab Commander';
	@override String get commanderNodeName => 'Mi radio (vía Commander)';
	@override String get antenna => 'Antena';
	@override String get key => 'Manipulador';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Radio genérica (provisional)';
	@override String get placeholderRadioNodeName => 'Mi radio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Conmutador coaxial Sierra Radio CX-1';
	@override String get gs232a => 'Interfaz de rotor Yaesu GS-232A';
	@override String get pstRotator => 'PstRotator (control UDP)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$es extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get network => 'Red/WiFi';
	@override String get secureNetwork => 'Red/WiFi segura';
	@override String get usbSerial => 'Serie USB';
	@override String get wifi => 'Red/WiFi';
	@override String get bluetoothSerial => 'Serie Bluetooth';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'Provisional';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$es extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipolo';
	@override String get vertical => 'Vertical';
	@override String get yagiBeam => 'Yagi / Directiva';
	@override String get loop => 'Loop';
	@override String get longWire => 'Hilo largo / EFHW';
	@override String get other => 'Otra';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$es extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Manipulador recto';
	@override String get sideswiper => 'Manipulador lateral (sideswiper)';
	@override String get bug => 'Bug (semiautomático mecánico)';
	@override String get fullyAutomatic => 'Manipulador electrónico automático';
	@override String get singlePaddle => 'Paleta simple';
	@override String get dualPaddle => 'Paleta doble';
	@override String get computerDriven => 'Controlado por computadora';
	@override String get other => 'Otro';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$es extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Desconocido';
	@override String get sunny => 'Soleado';
	@override String get clear => 'Despejado';
	@override String get mainlySunny => 'Mayormente soleado';
	@override String get mainlyClear => 'Mayormente despejado';
	@override String get partlyCloudy => 'Parcialmente nublado';
	@override String get cloudy => 'Nublado';
	@override String get foggy => 'Niebla';
	@override String get rimeFog => 'Niebla helada';
	@override String get lightDrizzle => 'Llovizna ligera';
	@override String get drizzle => 'Llovizna';
	@override String get heavyDrizzle => 'Llovizna intensa';
	@override String get lightFreezingDrizzle => 'Llovizna helada ligera';
	@override String get freezingDrizzle => 'Llovizna helada';
	@override String get lightRain => 'Lluvia ligera';
	@override String get rain => 'Lluvia';
	@override String get heavyRain => 'Lluvia intensa';
	@override String get lightFreezingRain => 'Lluvia helada ligera';
	@override String get freezingRain => 'Lluvia helada';
	@override String get lightSnow => 'Nieve ligera';
	@override String get snow => 'Nieve';
	@override String get heavySnow => 'Nieve intensa';
	@override String get snowGrains => 'Granos de nieve';
	@override String get lightShowers => 'Chubascos ligeros';
	@override String get showers => 'Chubascos';
	@override String get heavyShowers => 'Chubascos intensos';
	@override String get lightSnowShowers => 'Chubascos de nieve ligeros';
	@override String get snowShowers => 'Chubascos de nieve';
	@override String get thunderstorm => 'Tormenta';
	@override String get lightThunderstormsWithHail => 'Tormentas ligeras con granizo';
	@override String get thunderstormWithHail => 'Tormenta con granizo';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$es extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get off => 'No';
	@override String get toggle => 'Alternar';
	@override String get hold => 'Mantener';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$es extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get off => 'El teclado no activa el PTT de la radio.';
	@override String get toggle => 'En modos de fonía, la tecla PTT pone la radio en transmisión y al pulsarla de nuevo la devuelve a recepción. Vuelve a recepción por sí sola después de un minuto.';
	@override String get hold => 'En modos de fonía, la radio transmite mientras la tecla PTT esté pulsada, hasta un minuto.';
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
			'common.ok' => 'OK',
			'common.cancel' => 'Cancelar',
			'common.delete' => 'Eliminar',
			'common.create' => 'Crear',
			'common.error' => 'Error',
			'common.close' => 'Cerrar',
			'common.done' => 'Listo',
			'common.callsign' => 'Indicativo',
			'common.clear' => 'Borrar',
			'common.dismiss' => 'Descartar',
			'common.copyDetails' => 'Copiar detalles',
			'common.expand' => 'Expandir',
			'common.collapse' => 'Contraer',
			'onboarding.welcomeTitle' => '¡Bienvenido a Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => '¡Bienvenido a Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Tenemos algunas preguntas para adaptar mejor la app a lo que necesitas.',
			'onboarding.skip' => 'Omitir',
			'onboarding.kContinue' => 'Continuar',
			'onboarding.back' => 'Atrás',
			'onboarding.next' => 'Siguiente',
			'onboarding.done' => 'Listo',
			'onboarding.callsignTitle' => '¿Cuál es tu indicativo?',
			'onboarding.callsignBody' => 'Necesitas una licencia de radioaficionado para que esta app te resulte útil',
			'onboarding.callsignLabel' => 'Indicativo del Operador',
			'onboarding.alreadyHaveAccount' => '¿Ya tienes una cuenta?',
			'onboarding.foundSiblingTitle' => '¿Vincular una cuenta existente?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Encontramos ${app} en este dispositivo. Vincula esta app a la misma cuenta y traerás tu indicativo y tus logs.',
			'onboarding.foundPoloBody' => 'Encontramos una versión anterior de Ham2K Portable Logger en este dispositivo. Vincula esta app a la misma cuenta y traerás tu indicativo y tus logs.',
			'onboarding.foundSiblingsBody' => 'Encontramos otras apps de Ham2K en este dispositivo. Vincula esta app a una de sus cuentas y traerás tu indicativo y tus logs.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Vincular con ${app}',
			'onboarding.linkWithPolo' => 'Vincular con la cuenta de la versión anterior',
			'onboarding.setUpFresh' => 'Empezar de cero',
			'onboarding.activitiesTitle' => 'Actividades favoritas',
			'onboarding.activitiesBody' => '¿Te interesa alguno de estos populares programas de activación?',
			'onboarding.activitiesFooter' => '(Encontrarás más opciones en la Configuración)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'Sincronización en la nube',
			'onboarding.syncBody' => 'Ham2K Log Filer guarda un respaldo de tus logs en la nube y los sincroniza entre todos los dispositivos donde uses apps de Ham2K.',
			'onboarding.syncPricing' => '¡Es gratis! Pero con una suscripción de pago será más rápido.',
			'onboarding.syncLabel' => 'Habilitar sincronización en la nube',
			'onboarding.syncOffWarning' => 'ADVERTENCIA: esto aumenta el riesgo de perder los datos de tus operaciones, por ejemplo si tu dispositivo falla o se pierde.',
			'onboarding.notNow' => 'Ahora no',
			'onboarding.consentTitle' => 'Datos y privacidad',
			'onboarding.consentUsageBody' => 'Para ayudarnos a mejorar la app, nos gustaría recopilar datos de rendimiento, fallos y uso.',
			'onboarding.consentUsageLabel' => 'Compartir datos de uso de la aplicación',
			'onboarding.consentOperationBody' => 'Algunas funciones pueden implicar compartir datos de tus operaciones con otros usuarios. Puedes desactivarlo en cualquier momento.',
			'onboarding.consentOperationLabel' => 'Compartir datos de operación',
			'onboarding.finishingSetup' => 'Terminando la configuración — descargando datos de referencia…',
			'startScreen.credits' => 'por KI2D y sus amigos',
			'testerOverlay.tape' => 'PRECAUCIÓN: EN CONSTRUCCIÓN',
			'testerOverlay.warningTitle' => 'Esta app todavía está en obras',
			'testerOverlay.warningBody' => 'La mayoría de las funciones tienen superficies irregulares y hay riesgo de tropezar por todas partes. Busca actualizaciones con frecuencia.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novedades del build ${build}',
			'testerOverlay.thanks' => '¡Gracias por poner tu log en riesgo para ayudarnos a mejorar esta app!',
			'extensionsPanel.categoryActivity' => 'Actividades',
			'extensionsPanel.categoryAward' => 'Diplomas',
			'extensionsPanel.categoryContest' => 'Concursos',
			'extensionsPanel.categoryLookup' => 'Búsquedas de indicativo',
			'extensionsPanel.categorySpots' => 'Fuentes de Spots',
			'extensionsPanel.categoryDashboard' => 'Paneles del tablero',
			'extensionsPanel.categoryOther' => 'Otras extensiones',
			'extensionsPanel.searchHint' => 'Buscar extensiones',
			'extensionsPanel.applying' => 'Activando cambios de extensiones, esto puede tardar un momento…',
			'extensionsPanel.noMatches' => 'Ninguna extensión coincide con tu búsqueda',
			'extensionsPanel.installFromFile' => 'Instalar desde archivo…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versión ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Captura ${n} de ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Captura anterior',
			'extensionsPanel.nextScreenshot' => 'Captura siguiente',
			'extensionsPanel.screenshotUnavailable' => 'Captura no disponible',
			'extensionsPanel.canReach' => 'Esta extensión puede acceder a',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, mediante una conexión en vivo',
			'extensionsPanel.canHoldLocalConnection' => 'Dispositivos de tu red local, mediante una conexión en vivo',
			'extensionsPanel.canUseLocation' => 'Tu ubicación',
			'extensionsPanel.canReadRadio' => 'Tu radio, para leer su frecuencia y modo',
			'extensionsPanel.canControlRadio' => 'Tu radio, para controlarla y transmitir con ella — sintonía, potencia, CW, memorias de voz y PTT',
			'extensionsPanel.canCommandRadioRaw' => 'Tu radio, para enviarle cualquier comando en su propio protocolo — incluidos los que transmiten o cambian su configuración',
			'extensionsPanel.canReadCluster' => 'El clúster DX, conectado como tú, para leer lo que envía',
			'extensionsPanel.canSpotCluster' => 'El clúster DX, conectado como tú, para publicar spots en tu nombre',
			'extensionsPanel.canCommandCluster' => 'El clúster DX, conectado como tú, para enviarle cualquier comando en tu nombre',
			'extensionsPanel.canSetUserAgent' => 'Identificarse ante los servidores con su propio nombre',
			'extensionsPanel.canChangeSettings' => 'Tu configuración, para cambiarla mediante sus comandos: cualquier opción, el modo desarrollador y los experimentos',
			'extensionsPanel.noCapabilities' => 'No pide nada fuera de la app.',
			'extensionsPanel.sandboxNote' => 'Las extensiones se ejecutan aisladas: sin acceso a tus archivos y sin más red que la indicada aquí.',
			'extensionsPanel.installAction' => 'Instalar',
			'extensionsPanel.updateAction' => 'Actualizar',
			'extensionsPanel.installFailed' => 'No se pudo instalar esa extensión',
			'extensionsPanel.installedBadge' => 'Instalada',
			'extensionsPanel.uninstallAction' => 'Quitar',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '¿Quitar ${name}?',
			'extensionsPanel.uninstallBody' => 'Se quitará esta extensión junto con su configuración. Tus logs quedarán intactos.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'Se instaló ${name}',
			'extensionsPanel.installDownloading' => 'Descargando…',
			'extensionsPanel.installWaiting' => 'Esperando para instalar…',
			'extensionsPanel.installInstalling' => 'Instalando…',
			'extensionsPanel.installAwaitingApproval' => 'Esperando tu aprobación…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => 'Ya se está instalando ${name}.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Actualizada a ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'La instalación de ${name} no se completó. Puede que haya que instalarla de nuevo.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'No se pudo quitar ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Descargada desde ${source}',
			'extensionsPanel.dropHint' => 'Suelta una extensión .h2kext para instalarla',
			'extensionsPanel.dropOneOnly' => 'Suelta una extensión a la vez.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} respondió ${status} para esa extensión.',
			'extensionsPanel.downloadTooLarge' => 'Esa descarga es demasiado grande para ser una extensión.',
			'extensionsPanel.downloadNotSecure' => 'Esa descarga redirigió a un sitio no seguro.',
			'extensionsPanel.catalogSection' => 'Catálogo',
			'extensionsPanel.catalogLoading' => 'Cargando el catálogo…',
			'extensionsPanel.catalogUnreachable' => 'Catálogo inaccesible',
			'extensionsPanel.builtIn' => 'Incorporada',
			'extensionsPanel.updateAvailableBadge' => 'Actualización disponible',
			'extensionsPanel.updatesAvailableTitle' => 'Actualizaciones de extensiones',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Hay una actualización disponible para ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} y ${count} más necesitan actualizarse.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} necesitan actualizarse.',
			'extensionsPanel.pendingUpdatesSection' => 'Actualizaciones pendientes',
			'extensionsPanel.updateAllAction' => 'Actualizar todas',
			'extensionsPanel.updatesUnderWay' => 'Esas actualizaciones ya están en curso.',
			'extensionsPanel.updatesNothingLeft' => 'Tus extensiones están al día.',
			'extensionsPanel.updatesNoticeAction' => 'Más información',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '¿Actualizar ${count} extensión?', other: '¿Actualizar ${count} extensiones?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Tus extensiones están listas',
			'extensionsPanel.upgradeDoneBody' => 'Ahora vienen del catálogo de extensiones de Ham2K, así que pueden actualizarse sin esperar una nueva versión de la app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'No se actualizaron: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'No pudieron ejecutarse: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Siguen instaladas y marcadas en Configuración › Extensiones — actualizarlas allí las recuperará.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'El catálogo no tiene un reemplazo directo para estas, así que busca allí extensiones que cubran lo que usabas.',
			'extensionsPanel.retiredQp' => 'Concursos Estatales',
			'extensionsPanel.retiredStateparks' => 'Eventos de parques estatales',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} de tus extensiones aún no han llegado. Se descargarán la próxima vez que se pueda acceder al catálogo de extensiones.',
			'extensionsPanel.runtimeDeadBody' => 'Tus extensiones no arrancaron. Reiniciar la app debería recuperarlas.',
			'extensionsPanel.refusedTitle' => 'Algunas extensiones no pudieron ejecutarse',
			'extensionsPanel.upgradeBusyTitle' => 'Todavía en preparación',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Tus extensiones no están funcionando',
			'extensionsPanel.restoreTitle' => 'Faltan algunas de tus extensiones',
			'extensionsPanel.restoreBody' => 'Estas extensiones que instalaste no están en este dispositivo. Podemos descargarlas de nuevo del catálogo de extensiones de Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Instaladas desde un archivo. Instálalas de nuevo desde sus archivos, u olvídalas:',
			'extensionsPanel.restoreOtherCatalog' => 'Instaladas desde otro catálogo de extensiones, así que no están disponibles aquí:',
			'extensionsPanel.restoreForget' => 'Olvidar',
			'extensionsPanel.restoreInstall' => 'Instalar',
			'extensionsPanel.restoreLater' => 'Más tarde',
			'extensionsPanel.restoreInstalling' => 'Instalando tus extensiones…',
			'extensionsPanel.restoreDoneTitle' => 'Tus extensiones están de vuelta',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Instaladas de nuevo: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Algunas extensiones no se pudieron instalar',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'No se pudieron instalar: ${names}. Te las ofreceremos de nuevo la próxima vez que abras la app.',
			'extensionsPanel.restoreBusyBody' => 'La app todavía está preparando tus extensiones. Te las ofreceremos de nuevo la próxima vez que abras la app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Las instalamos de nuevo, pero tus extensiones no arrancaron. Reiniciar la app debería recuperarlas.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => 'Se retiró ${name}',
			'extensionsPanel.revokedBody' => 'El catálogo retiró esta versión, así que fue deshabilitada.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => 'Se deshabilitó ${name}',
			'extensionsPanel.forceDisabledBody' => 'Ham2K ha deshabilitado esta extensión por ahora.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name} fue reemplazada',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => '${replacement} ocupa su lugar. Puedes cambiar a ella en Extensiones.',
			'extensionsPanel.replacedBy' => ({required Object name}) => 'Reemplazada por ${name}',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'Reemplazada por ${name}, que ya tienes',
			'extensionsPanel.replaceAction' => 'Reemplazar',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => 'Su configuración pasa a ${replacement}, que ya tienes. Tus logs quedarán intactos.',
			'extensionsPanel.downloadHashMismatch' => 'Esa descarga no es la extensión que describe el catálogo.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'El catálogo no tiene la versión ${version} de ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Ese enlace del catálogo no indica una versión de extensión.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'El catálogo no tiene ninguna versión de ${key} en ese canal.',
			'extensionsPanel.installFromLink' => 'Instalar desde enlace',
			'extensionsPanel.unstableReleaseWarning' => 'Esta es una versión inestable, que quien la publica no da por terminada. Puede fallar y seguirá recibiendo actualizaciones inestables.',
			'extensionsPanel.bleedingReleaseWarning' => 'Esta es una versión "Bleeding Edge": trabajo en curso que puede romperse o perder su configuración. Seguirá recibiendo actualizaciones "Bleeding Edge".',
			'extensionsPanel.channelUnstable' => 'Inestable',
			'extensionsPanel.channelBleeding' => 'Bleeding Edge',
			'extensionsPanel.followsUnstable' => 'Recibe versiones inestables y estables',
			'extensionsPanel.followsBleeding' => 'Recibe versiones "Bleeding Edge", inestables y estables',
			'extensionsPanel.followStableAction' => 'Seguir solo versiones estables',
			'extensionsPanel.revokedBadge' => 'Retirada',
			'extensionsPanel.forceDisabledBadge' => 'Deshabilitada por Ham2K',
			'extensionsPanel.refusedBadge' => 'No se cargó',
			'extensionsPanel.downloadNotHttps' => 'Esa descarga no usa una conexión segura.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'No se pudo contactar a ${source} para esa extensión.',
			'extensionsPanel.detailsAction' => 'Detalles',
			'extensionsPanel.installedFromFile' => 'Instalada desde un archivo',
			'extensionsPanel.detailsWhatItDoes' => 'Ofrece soporte para',
			'extensionsPanel.installedPreloaded' => 'Preinstalada',
			'extensionsPanel.hookAccount' => 'Inicio de sesión en cuenta',
			'extensionsPanel.hookCallNotes' => 'Notas de indicativo',
			'extensionsPanel.hookDataFile' => 'Datos sin conexión',
			'extensionsPanel.hookExport' => 'Exportar',
			'extensionsPanel.hookLookup' => 'Búsquedas de indicativo',
			'extensionsPanel.hookScoring' => 'Puntuación',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Cazando ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Activando ${program}',
			'extensionsPanel.suggestedSection' => 'Sugeridas',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => 'Más disponibles (${count})',
			'home.title' => 'Libro de Guardia Portátil',
			'home.newOperation' => 'Nueva operación',
			'home.stationCallsign' => 'Indicativo de estación',
			'home.titleOptional' => 'Título (opcional)',
			'home.emptyList' => 'Aún no hay operaciones. Crea una para empezar a registrar QSOs.',
			'home.quickLookup' => 'Búsqueda rápida',
			'home.nav.operations' => 'Operaciones',
			'home.nav.chase' => 'Cacería',
			'home.nav.logs' => 'Logs',
			'home.nav.maps' => 'Mapas',
			'home.nav.settings' => 'Configuración',
			'home.panels.operations' => 'Lista de Operaciones',
			'home.panels.operationsDescription' => 'Tus operaciones, la más reciente primero.',
			'home.panels.version' => 'Versión actual',
			'home.panels.versionDescription' => 'La marca Ham2K, el nombre de esta app y qué build estás usando.',
			'home.toggleNav' => 'Mostrar u ocultar las etiquetas de navegación',
			'home.logs.title' => 'Logs',
			'home.logs.titleFor' => 'Logs de',
			'home.logs.emptyCallsigns' => 'Aún no hay QSOs registrados',
			'home.logs.emptyQsos' => ({required Object call}) => 'No hay QSOs para ${call}',
			'home.logs.mapNoSelection' => 'Selecciona un QSO para verlo en el mapa',
			'home.logs.searchHint' => 'Buscar indicativo o nombre',
			'home.logs.noSearchMatches' => 'Ningún QSO coincide con tu búsqueda',
			'home.logs.titleAll' => 'Todos los logs',
			'home.logs.allCallsigns' => 'Todos los indicativos',
			'home.logs.noOperation' => 'No forma parte de ninguna operación',
			'home.logs.unsavedTitle' => 'Cambios sin guardar',
			'home.logs.unsavedBody' => 'Este QSO tiene cambios que no has guardado.',
			'home.logs.pendingDeleteBody' => 'Este QSO está marcado para eliminarse.',
			'home.logs.editGone' => 'No se guardó: ese QSO ya no está en este log.',
			'home.logs.discard' => 'Descartar',
			'home.logs.sheet.callsigns' => 'Indicativos de estación',
			'home.logs.sheet.groupBy' => 'Agrupar por',
			'home.logs.sheet.period' => 'Período',
			'home.logs.groupBy.none' => 'Sin agrupar',
			'home.logs.groupBy.date' => 'Fecha',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Continente desconocido',
			'home.logs.groupBy.unknownEntity' => 'Entidad desconocida',
			'home.logs.groupBy.unknownDate' => 'Sin fecha',
			'home.logs.period.thisMonth' => 'Este mes',
			'home.logs.period.last3Months' => 'Últimos 3 meses',
			'home.logs.period.thisYear' => 'Este año',
			'home.logs.period.lastYear' => 'Año pasado',
			'home.logs.period.allTime' => 'Desde siempre',
			'home.logs.period.custom' => 'Rango personalizado',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'en ${span}',
			'home.logs.periodTitle.custom' => 'Rango personalizado',
			'home.logs.columns.date' => 'Fecha',
			'home.logs.columns.time' => 'Hora',
			'home.logs.columns.freq' => 'Frecuencia',
			'home.logs.columns.mode' => 'Modo',
			'home.logs.columns.call' => 'Indicativo',
			'home.logs.columns.name' => 'Nombre',
			'home.logs.columns.station' => 'Estación',
			'home.logs.columns.band' => 'Banda',
			'home.logs.columns.sent' => 'Env.',
			'home.logs.columns.rcvd' => 'Recib.',
			'home.logs.columns.grid' => 'Grilla',
			'home.logs.columns.state' => 'Estado',
			'home.logs.columns.country' => 'País',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'Log de QSOs',
			'home.logs.panels.qsosDescription' => 'Los QSOs del indicativo seleccionado, en todas las operaciones.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Total de QSOs, o la búsqueda de indicativo del QSO seleccionado.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'La ubicación del QSO seleccionado.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicativos: ${calls}',
			'home.logs.import.skippedOne' => '1 registro no se pudo leer',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} registros no se pudieron leer',
			'home.logs.import.readingTitle' => 'Leyendo archivo ADIF…',
			'home.logs.import.checkingTitle' => 'Buscando duplicados…',
			'home.logs.import.importingTitle' => 'Importando QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} de ${total} verificados',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importados, de ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'cazando',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} y ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} y más',
			'chase.station.title' => 'Estación cazadora',
			'chase.station.stationLabel' => 'Estación: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Sin ubicación',
			'chase.periodInline.today' => 'hoy',
			'chase.periodInline.thisWeek' => 'esta semana',
			'chase.periodInline.last14Days' => 'en los últimos 14 días',
			'chase.periodInline.thisMonth' => 'este mes',
			'chase.periodStats.today' => 'Estadísticas de hoy',
			'chase.periodStats.thisWeek' => 'Estadísticas de esta semana',
			'chase.periodStats.last14Days' => 'Estadísticas de los últimos 14 días',
			'chase.periodStats.thisMonth' => 'Estadísticas de este mes',
			'chase.period.today' => 'Hoy',
			'chase.period.thisWeek' => 'Esta semana',
			'chase.period.last14Days' => 'Últimos 14 días',
			'chase.period.thisMonth' => 'Este mes',
			'chase.goals.title' => 'Objetivos de cacería',
			'chase.goals.remove' => ({required Object name}) => 'Dejar de cazar ${name}',
			'chase.goals.extensionsTitle' => 'Más programas de cacería',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Controles de logging sobre los QSOs cazados en el período.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'El indicativo que se está registrando, o las estadísticas del período.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Estaciones con spots en el aire, listas para cazar.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'Los QSOs del período y la estación que se está registrando.',
			'chase.claims.checking' => 'Revisando QSOs para cacería',
			'chase.claims.rebuilding' => ({required Object program}) => 'Revisando el log para ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} de ${total} QSOs',
			'chase.notice.newRef' => ({required Object program}) => 'Nuevo ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Probablemente nuevo ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'Nueva banda ${program}',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Probablemente nueva banda ${program}',
			'chase.notice.newMode' => ({required Object program}) => 'Nuevo modo ${program}',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Probablemente nuevo modo ${program}',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} sin confirmar',
			'chase.notice.programGuess' => ({required Object notice}) => 'Probablemente ${notice}',
			'chase.alerts.title' => 'Alertas',
			'chase.alerts.newRef' => 'Nueva referencia',
			'chase.alerts.newBand' => 'Nueva banda',
			'chase.alerts.newMode' => 'Nuevo modo',
			'chase.alerts.unconfirmed' => 'Sin confirmar',
			'chase.checklists' => 'Progreso de cacería',
			'chase.imports.importFrom' => ({required Object label}) => 'Importar ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Importar ${file} como',
			'chase.imports.dropHint' => 'Suelta un archivo para importarlo en un programa de cacería',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'Se importaron ${count} entradas de ${program} desde ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'Se importaron ${count} entradas de ${program} desde ${file}; se omitieron ${skipped} que no pudo leer',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} no tiene nada que ${program} pueda importar',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} no pudo leer ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} no pudo leer ninguno de los ${skipped} registros de ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'Ningún programa de cacería importa ${file}',
			'dialogs.operationDetails' => 'Detalles de la operación',
			'dialogs.activities' => 'Actividades',
			'dialogs.stationCallsign' => 'Indicativo de Estación',
			'dialogs.advanced' => 'Avanzado',
			'dialogs.operatingPosition' => 'Posición de operación (multiestación)',
			'dialogs.assistance' => 'Asistencia',
			'dialogs.assistanceDescription' => 'Usar servicios de spots y otras fuentes de información',
			'dialogs.selfSpotting' => 'Self-spotting',
			'dialogs.selfSpottingDescription' => 'Permitir funciones que reporten tu propia frecuencia',
			'dialogs.disabledByRules' => ({required Object rules}) => 'Deshabilitado para cumplir las reglas de ${rules}',
			'dialogs.lookupDespiteAssistance.title' => '¿Buscar en línea?',
			'dialogs.lookupDespiteAssistance.body' => 'La asistencia está deshabilitada para esta operación. Buscar los datos de todos los QSOs usará servicios en línea como QRZ solo por esta vez.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'La asistencia está deshabilitada para esta operación para cumplir las reglas de ${rules}. Buscar los datos de todos los QSOs usará servicios en línea como QRZ solo por esta vez.',
			'dialogs.lookupDespiteAssistance.action' => 'Buscar en línea',
			'dialogs.notes' => 'Notas',
			'dialogs.deleteOperationTitle' => 'Eliminar Operación',
			'dialogs.purgeTestsTitle' => 'Purgar operaciones de prueba',
			'dialogs.purgeTestsBody' => 'Esto elimina permanentemente estas operaciones de prueba y sus QSOs. No se puede deshacer.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Más ${count} contacto de prueba que no pertenece a ninguna operación.', other: 'Más ${count} contactos de prueba que no pertenecen a ninguna operación.', ), 
			'dialogs.purgeTestsAction' => 'Purgar',
			'dialogs.syncAllTitle' => '¿Reemplazar el log de este dispositivo?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL respalda y borra ${qsos} de este dispositivo, y luego vuelve a descargar el log de la cuenta desde el servidor. El respaldo queda en la base de datos de este dispositivo.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} QSO aún no se ha sincronizado — el servidor nunca lo recibió y NO va a volver.', other: '${n} QSOs aún no se han sincronizado — el servidor nunca los recibió y NO van a volver.', ), 
			'dialogs.syncAllAction' => 'Borrar y resincronizar',
			'dialogs.receivedPurgesTitle' => 'Operaciones de prueba eliminadas en otro dispositivo',
			'dialogs.receivedPurgesBody' => 'Estas se eliminaron como operaciones de prueba en otro dispositivo. ¿Quitarlas aquí también? Esto las elimina permanentemente junto con sus QSOs y no se puede deshacer.',
			'dialogs.receivedPurgesAction' => 'Quitar',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicativo inválido: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicativos inválidos: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} ha operado hasta ahora. ${typed} se registrará en los nuevos contactos.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Ningún operador registrado hasta ahora. ${typed} se registrará en los nuevos contactos.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Esta operación ya tiene contactos de ${calls}. ${typed} solo se registrará en los nuevos.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Registrar también a ${typed} como operador del contacto ya registrado', other: 'Registrar también a ${typed} como operador de los ${count} contactos ya registrados', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Cuando se usan varias estaciones al aire, no hay soporte para operadores separados',
			'dialogs.callChange.contactsUnreadable' => 'No se pudieron leer los contactos de esta operación, así que cambiar un indicativo aquí no ofrecerá actualizarlos',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'No se pudieron actualizar los contactos ya registrados, así que no se cambió nada: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => 'Se actualizaron ${written} de ${planned} contactos — el resto ya no está en esta operación',
			'operation.deletedReadOnly' => 'Esta operación está eliminada. Restáurala para registrar contactos o hacer cambios.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Reloj',
			'operation.tabs.weather' => 'Clima',
			'operation.tabs.website' => 'Sitio web',
			'operation.tabs.remoteScreen' => 'Pantalla remota',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Radio',
			'operation.tabs.rotator' => 'Rotor',
			'operation.tabs.summaries' => 'Resúmenes de la operación',
			'operation.positions.nobodyYet' => 'Ninguna otra posición de operación comparte esta operación todavía.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Otra posición',
			'operation.positions.thisDevice' => 'Nuestra posición de operación',
			'operation.positions.nameIn' => ' en ',
			'operation.positions.panelTitle' => 'Posiciones',
			'operation.positions.panelDescription' => 'Lo que cada posición de operación que comparte esta operación está registrando ahora mismo.',
			'operation.stationCallsignNone' => 'Sin indicativo de estación',
			'operation.titleNone' => 'Sin título',
			'operation.deleteOperation' => 'Eliminar operación',
			'operation.loggingControlsStale' => 'Los campos de actividad podrían estar desactualizados — reabre la operación para actualizarlos',
			'operation.locationNone' => 'Sin establecer',
			'operation.generalOperation' => 'Operación General',
			'operation.titleFor' => ({required Object value}) => 'para ${value}',
			'operation.titleAt' => ({required Object value}) => 'en ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Ahora ${description}',
			'operation.testOperationSuffix' => 'Prueba',
			'operation.menu.showRstFields' => 'Mostrar campos RST',
			'operation.menu.showStateField' => 'Mostrar campo de estado',
			'operation.menu.showGridField' => 'Mostrar campo de grilla',
			'operation.menu.showDeletedQsos' => 'Mostrar QSOs eliminados',
			'operation.menu.showDeletedOps' => 'Mostrar operaciones eliminadas',
			'operation.menu.showQsoNumbers' => 'Mostrar números de QSO',
			'operation.menu.lookupAllQsos' => 'Buscar datos de todos los QSOs',
			'operation.menu.loggingSettingsTitle' => 'Configuración de Logging',
			'operation.menu.mapSettingsTitle' => 'Configuración del mapa',
			'operation.menu.actionsSection' => 'Acciones',
			'operation.layout.title' => 'Agregar un panel',
			'operation.layout.availableSection' => 'Paneles disponibles',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Configuración de ${panel}',
			'operation.layout.panelSettingsAction' => 'Configuración del panel',
			'operation.layout.viewName' => 'Vista de operación',
			'operation.layout.viewOptions' => 'Opciones de disposición de la vista',
			'operation.layout.viewTitleBuiltIn' => 'Esta vista viene integrada en la app, y su nombre también',
			'operation.layout.resetOptions' => 'Restaurar valores por defecto',
			'operation.layout.removePane' => 'Quitar',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '¿Restaurar ${panel} a sus valores por defecto?',
			'operation.layout.resetPaneConfirmBody' => 'Su título, encabezado y tamaño vuelven a los valores por defecto. El resto de la disposición no cambia.',
			'operation.layout.resetViewConfirm' => '¿Restaurar la disposición por defecto de esta vista?',
			'operation.layout.resetViewConfirmBody' => 'Los paneles vuelven a su disposición por defecto, y las opciones de la vista y las de cada panel vuelven a sus valores por defecto.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Configuración de disposición de ${panel}',
			'operation.layout.paneTitle' => 'Título',
			'operation.layout.paneShowHeader' => 'Mostrar encabezado',
			'operation.layout.paneShowHeaderTabset' => 'Siempre visible mientras este panel comparte un grupo — el encabezado es cómo se llega a los demás',
			'operation.layout.paneInherit' => 'Igual que la app',
			'operation.layout.searchHint' => 'Buscar paneles',
			'operation.layout.noPanelsMatch' => 'Ningún panel coincide con tu búsqueda.',
			'operation.layout.nothingToAdd' => 'Esta vista ya tiene todos los paneles posibles',
			'operation.layout.addPanel' => ({required Object panel}) => 'Agregar ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Vista previa de ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Falta la extensión "${name}"',
			'operation.layout.missingExtensionEnable' => 'Habilitar',
			'operation.layout.missingExtensionInstall' => 'Instalar…',
			'operation.layout.missingExtensionWontRun' => 'Esta versión no funcionará. Actualízala en Configuración › Extensiones.',
			'operation.layout.missingExtensionUnavailable' => 'No disponible en esta app',
			'operation.layout.missingExtensionNotInCatalog' => 'No está en el catálogo',
			'operation.layout.missingExtensionCatalogUnreachable' => 'No se pudo acceder al catálogo. Inténtalo de nuevo',
			'operation.layout.missingExtensionFailed' => 'Eso no funcionó. Inténtalo de nuevo',
			'operation.layout.previewUnavailable' => 'No se pudo mostrar la imagen de vista previa de este panel.',
			'operation.layout.nestedPaneTitle' => 'Más',
			'operation.layout.layouts.defaultName' => 'Por defecto',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Disposición ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Disposición: ${name}',
			'operation.layout.layouts.menuNew' => 'Nueva…',
			'operation.layout.layouts.menuExport' => 'Exportar…',
			'operation.layout.layouts.menuImport' => 'Importar…',
			'operation.layout.layouts.menuTitle' => 'Disposiciones',
			'operation.layout.layouts.newTitle' => 'Nueva disposición',
			'operation.layout.layouts.editTitle' => 'Editar disposición',
			'operation.layout.layouts.edit' => 'Editar',
			'operation.layout.layouts.duplicateCurrent' => 'Duplicar la disposición actual',
			'operation.layout.layouts.startFromDefault' => 'Empezar desde la disposición por defecto',
			'operation.layout.layouts.nameLabel' => 'Nombre',
			'operation.layout.layouts.descriptionLabel' => 'Descripción',
			'operation.layout.layouts.create' => 'Crear',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => '¿Guardar los cambios en "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'Esta disposición tiene cambios que no has guardado.',
			'operation.layout.layouts.discard' => 'Descartar',
			'operation.layout.layouts.deleteTitle' => '¿Eliminar esta disposición?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => '¿Seguro que quieres eliminar la disposición "${name}"?',
			'operation.layout.layouts.exportTitle' => 'Exportar disposición',
			'operation.layout.layouts.exportPick' => 'Paneles a exportar',
			'operation.layout.layouts.tabSet' => 'Grupo de pestañas',
			'operation.layout.layouts.exportAction' => 'Exportar',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Disposición guardada en ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'No se pudo exportar la disposición: ${error}',
			'operation.layout.layouts.importTitle' => 'Importar disposición',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Hecha para la vista ${view}: se omiten los paneles que solo tiene esa vista.',
			'operation.layout.layouts.viewHome' => 'Inicio',
			'operation.layout.layouts.viewOperation' => 'Operación',
			'operation.layout.layouts.viewLogs' => 'Logs',
			'operation.layout.layouts.viewChase' => 'Cacería',
			'operation.layout.layouts.importAsNew' => 'Como una disposición nueva',
			'operation.layout.layouts.importReplace' => 'En lugar de esta disposición',
			'operation.layout.layouts.importAdd' => 'Agregada a esta disposición',
			'operation.layout.layouts.importAddHint' => 'Los paneles llegan en una nueva columna a la derecha.',
			'operation.layout.layouts.importPick' => 'Paneles a importar',
			'operation.layout.layouts.importReplaceSettings' => 'Reemplazar la configuración de los paneles que ya están aquí',
			'operation.layout.layouts.importAction' => 'Importar',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} no es una disposición que esta app pueda leer: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'el texto no es YAML válido (línea ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'no es un archivo de disposición de Ham2K',
			'operation.layout.layouts.problemNewerVersion' => 'fue escrito por una versión más nueva de la app',
			'operation.layout.layouts.problemNoArrangement' => 'no contiene ninguna distribución de paneles',
			'operation.layout.layouts.problemMalformed' => 'parte de él no sigue el formato de disposición',
			'operation.layout.layouts.problemTooLarge' => 'es demasiado grande',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'No se pudo abrir el archivo: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'No se pudo importar la disposición: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'No se pudo copiar la disposición: ${error}',
			'operation.layout.layouts.importNothing' => 'No se eligió ningún panel, así que no se importó nada.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'Omitidos: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'Se conservó ${panels}: la distribución para pantallas pequeñas no puede prescindir de él.',
			'operation.layout.layouts.notOffered' => 'No disponible en esta vista',
			'operation.layout.layouts.alreadyPlaced' => 'Ya está en esta disposición',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Necesita ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'No se pudieron leer los nombres de las disposiciones',
			'operation.layout.layouts.listRecoveredBody' => 'No se pudo leer la lista de disposiciones de esta vista. Todas las disposiciones siguen aquí, numeradas en lugar de su nombre.',
			'operation.layout.editLayout' => 'Editar disposición',
			'operation.layout.saveLayout' => 'Guardar disposición',
			'operation.layout.revertLayout' => 'Descartar los cambios de disposición',
			'operation.layout.done' => 'Listo',
			'operation.layout.layoutUnreadableTitle' => 'No se pudo leer la disposición',
			'operation.layout.layoutUnreadableBody' => 'No se pudo leer tu disposición guardada, así que se muestra la disposición por defecto. No se guardará sobre la original hasta que elijas conservarla.',
			'operation.layout.layoutUnreadableAction' => 'Usar esta disposición',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => 'No se pudo mostrar ${panel}',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: envió más de ${max} caracteres',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su gráfico tiene más de ${max} elementos',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su gráfico anida más de ${max} niveles',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => 'No se pudo mostrar ${panel}: su gráfico no es autocontenido',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su escena tiene más de ${max} capas',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su escena tiene más de ${max} controles',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: parte de su escena tiene más de ${max} entradas',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: una cadena de la escena supera los ${max} caracteres',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => 'No se pudo mostrar ${panel}: su disposición anida más de ${max} niveles',
			'operation.layout.panelRenderRetry' => 'Reintentar',
			'operation.layout.panelActionFailed' => 'Esa acción del panel falló. Inténtalo de nuevo.',
			'operation.layout.panels.loggingDescription' => 'El log y los campos de entrada',
			'operation.layout.panels.infoDescription' => 'Lo que sabemos de la estación contactada',
			'operation.layout.panels.spotsDescription' => 'Spots de los clústeres y programas de actividad',
			'operation.layout.panels.mapDescription' => 'Dónde están los contactos',
			'operation.layout.panels.summariesDescription' => 'Las estadísticas y puntuaciones de la operación, en las secciones y el orden que elijas',
			'operation.layout.panels.summariesSections' => 'Secciones y orden',
			'operation.layout.panels.summariesDays' => 'Cada día',
			'operation.layout.panels.summariesReset' => 'Mostrar todo',
			'operation.layout.panels.summariesAllHidden' => 'Todas las secciones están ocultas. Elige cuáles mostrar en la configuración de este panel.',
			'operation.layout.panels.clockDescription' => 'Una esfera de reloj, en cualquier zona horaria',
			'operation.layout.panels.clockFace' => 'Esfera',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analógica',
			'operation.layout.panels.clockZone' => 'Zona horaria',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Este dispositivo',
			'operation.layout.panels.clockShowSeconds' => 'Mostrar segundos',
			'operation.layout.panels.weatherDescription' => 'El clima ahora y durante las próximas ocho horas, donde estás operando',
			'operation.layout.panels.weatherUseOperationLocation' => 'Usar la ubicación de la operación',
			'operation.layout.panels.weatherLocation' => 'Ubicación',
			'operation.layout.panels.weatherLocationDescription' => 'Una grilla (FN31pr) o lat,lon. Se ignora mientras esté marcada \'Usar la ubicación de la operación\'.',
			'operation.layout.panels.weatherNoLocation' => 'No hay ubicación establecida. Dale una a este panel en su configuración, o colócalo dentro de una operación que tenga una.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'No se pudo leer la ubicación ${location}. Usa una grilla como FN31pr, o 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'No se pudo conectar con Open-Meteo — ¿sin red? Se intentará de nuevo en breve.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo respondió, pero con algo ilegible. Se intentará de nuevo en breve.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'ráfagas ${speed}',
			'operation.layout.panels.panelAgeNow' => 'ahora mismo',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'hace ${count} min', other: 'hace ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'hace ${count} h', other: 'hace ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Desconocido',
			'operation.layout.panels.weatherConditions.sunny' => 'Soleado',
			'operation.layout.panels.weatherConditions.clear' => 'Despejado',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Mayormente soleado',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Mayormente despejado',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parcialmente nublado',
			'operation.layout.panels.weatherConditions.cloudy' => 'Nublado',
			'operation.layout.panels.weatherConditions.foggy' => 'Niebla',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Niebla helada',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Llovizna ligera',
			'operation.layout.panels.weatherConditions.drizzle' => 'Llovizna',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Llovizna intensa',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Llovizna helada ligera',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Llovizna helada',
			'operation.layout.panels.weatherConditions.lightRain' => 'Lluvia ligera',
			'operation.layout.panels.weatherConditions.rain' => 'Lluvia',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Lluvia intensa',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Lluvia helada ligera',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Lluvia helada',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Nieve ligera',
			'operation.layout.panels.weatherConditions.snow' => 'Nieve',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Nieve intensa',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Granos de nieve',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Chubascos ligeros',
			'operation.layout.panels.weatherConditions.showers' => 'Chubascos',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Chubascos intensos',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Chubascos de nieve ligeros',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Chubascos de nieve',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Tormenta',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Tormentas ligeras con granizo',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Tormenta con granizo',
			'operation.layout.panels.websiteDescription' => 'Una página web de tu elección, en un panel',
			'operation.layout.panels.websiteUrl' => 'Dirección',
			'operation.layout.panels.websiteRefresh' => 'Actualizar',
			'operation.layout.panels.websiteRefreshNever' => 'Nunca',
			'operation.layout.panels.websiteRefresh1' => 'Cada minuto',
			'operation.layout.panels.websiteRefresh5' => 'Cada 5 minutos',
			'operation.layout.panels.websiteRefresh15' => 'Cada 15 minutos',
			'operation.layout.panels.websiteTitle' => 'Nombre del panel',
			'operation.layout.panels.websiteRefreshNow' => 'Actualizar ahora',
			'operation.layout.panels.websiteNoUrl' => 'Aún no hay dirección. Abre la configuración de este panel para elegir una página.',
			'operation.layout.panels.websiteBadUrl' => 'Eso no parece una dirección web. Debe empezar con https://',
			'operation.layout.panels.websiteNotHttps' => 'Aquí solo se pueden mostrar direcciones https://.',
			'operation.layout.panels.websiteUnsupported' => 'En este sistema no se pueden mostrar páginas web en un panel.',
			'operation.layout.panels.websiteOpenExternally' => 'Abrir en el navegador',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'No se pudo cargar la página: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Una pantalla, app o ventana compartida por otro de tus dispositivos.',
			'operation.layout.panels.remoteScreenTarget' => 'Pantalla',
			'operation.layout.panels.remoteScreenChoose' => 'Elegir una pantalla…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Pantallas compartidas',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Ninguno de tus dispositivos está compartiendo una pantalla. Activa Compartir pantallas y ventanas en Configuración → Dispositivos cercanos, en el dispositivo que quieras ver.',
			'operation.layout.panels.remoteScreenUnset' => 'No has elegido una pantalla. Abre la configuración de este panel para elegir una de las que comparten tus otros dispositivos.',
			'operation.layout.panels.remoteScreenConnecting' => 'Conectando…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Ese dispositivo no está conectado ahora mismo.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Ese dispositivo dejó de compartir esta pantalla.',
			'operation.layout.panels.remoteScreenNoListener' => 'Ese dispositivo no puede aceptar conexiones — revisa su firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Las pantallas solo se comparten por la red local, no por Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Ese dispositivo no quiso compartir esta pantalla.',
			'operation.layout.panels.remoteScreenSettings' => 'Configuración del panel',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajustar vista',
			'operation.layout.panels.remoteScreenDetail' => 'Detalle',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Estándar',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Alto',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Máximo',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Acercar',
			'operation.layout.panels.remoteScreenZoomOut' => 'Alejar',
			'operation.layout.panels.remoteScreenStopped' => 'Esa pantalla o ventana ya no se está mostrando.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Ese dispositivo no pudo capturar esa pantalla — puede que necesite permiso de grabación de pantalla.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Ese dispositivo no respondió. Puede que no tenga activado compartir pantalla.',
			'operation.layout.panels.remoteScreenNoMedia' => 'No se pudo abrir una conexión para la imagen. Revisa el firewall de este dispositivo.',
			'operation.layout.panels.solarDescription' => 'Condiciones solares y geomagnéticas, con propagación banda por banda',
			'operation.layout.panels.solarUnreachable' => 'No se pudo conectar con hamqsl.com — ¿sin red? Se intentará de nuevo en breve.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com respondió, pero no con datos que podamos usar. Se intentará de nuevo en breve.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Día',
			'operation.layout.panels.solarBandNight' => 'Noche',
			'operation.layout.panels.solarBandGood' => 'Buena',
			'operation.layout.panels.solarBandFair' => 'Regular',
			'operation.layout.panels.solarBandPoor' => 'Mala',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Fuentes: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'La conexión tiene dificultades — se están omitiendo cuadros.',
			'operation.layout.panels.remoteScreenStalled' => 'Los cuadros dejaron de llegar — puede que esta conexión sea demasiado lenta.',
			'operation.layout.panels.radioDescription' => 'El panel frontal de una radio — frecuencia, modo y potencia, bajo control CAT',
			'operation.layout.panels.radioStyle' => 'Estilo',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderno',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — ninguna radio designada',
			'operation.layout.panels.radioNoRadio' => 'No hay radio que mostrar. Elige una en la configuración de este panel, o agrega una en Configuración de Estación.',
			'operation.layout.panels.radioNotConfigured' => 'Esta radio aún no está configurada. Elige su puerto o dirección en Configuración de Estación.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio no conectada',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Conectar esta radio',
			'operation.layout.panels.radioDisconnect' => 'Desconectar esta radio',
			'operation.layout.panels.radioStale' => 'SIN DATOS',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'ROE',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'ROE alta',
			'operation.layout.panels.rotatorDescription' => 'Hacia dónde apunta la antena, en un mapa centrado en la estación. Toca el mapa para girarla.',
			'operation.layout.panels.rotatorRotator' => 'Rotor',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => 'Automático — ${name}',
			'operation.layout.panels.rotatorAutoNone' => 'Automático — todavía sin rotor',
			'operation.layout.panels.rotatorBeamWidth' => 'Ancho del haz',
			'operation.layout.panels.rotatorBeamWidthDescription' => 'En grados, dibujado alrededor del rumbo. 0 no dibuja nada.',
			'operation.layout.panels.rotatorLocation' => 'Ubicación',
			'operation.layout.panels.rotatorLocationDescription' => 'Una grilla, o una latitud y longitud, para centrar el mapa. En blanco usa la ubicación de la operación.',
			'operation.layout.panels.rotatorTheme' => 'Tema',
			'operation.layout.panels.rotatorThemeColor' => 'Color',
			'operation.layout.panels.rotatorThemeGray' => 'Gris',
			'operation.layout.panels.rotatorThemeMuted' => 'Apagado',
			'operation.layout.panels.rotatorGrayline' => 'Mostrar la línea gris',
			'operation.layout.panels.rotatorNoRotator' => 'No hay rotor que mostrar. Elige uno en la configuración de este panel, o agrega uno en Configuración de Estación.',
			'operation.layout.panels.rotatorNoLocation' => 'No hay ubicación para centrar el mapa. Establece una en la configuración de este panel.',
			'operation.layout.panels.rotatorDisconnected' => 'desconectado',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => 'no responde',
			'operation.layout.panels.rotatorLocationInvalid' => 'No se puede leer la ubicación en la configuración de este panel. Usa una grilla, o una latitud y longitud como 40.7, -74.0.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '${degrees}° el',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'O',
			'operation.layout.htmlPanelUnsupported' => 'Este panel necesita un visor web, que esta plataforma no ofrece',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Este panel necesita un entorno aislado que la versión web no puede ofrecer',
			'operation.export.title' => 'Exportaciones de la operación',
			'operation.export.syncedOperation' => 'La operación está sincronizada',
			'operation.export.unsyncedOperation' => 'La operación tiene cambios sin sincronizar',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} QSO en esta operación', other: '${count} QSOs en esta operación', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Los ${total} QSOs están sincronizados',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendientes de sincronizar',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcadores de evento sincronizados',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendientes',
			'operation.export.loading' => 'Cargando opciones de exportación…',
			'operation.export.noOptions' => 'No hay formatos de exportación disponibles (¿el motor de extensiones aún está iniciando?)',
			'operation.export.nothingLogged' => 'Nada que exportar todavía — esta operación no tiene QSOs.',
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
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Almacenar ${count} archivo', other: 'Almacenar ${count} archivos', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Almacenar ${count} archivo combinado', other: 'Almacenar ${count} archivos combinados', ), 
			'operation.export.settingsButton' => 'Configuración de exportación',
			'operation.export.settingsTitle' => 'Configuración de Exportación',
			'operation.export.compactFileNames.title' => 'Usar nombres de archivo compactos',
			'operation.export.compactFileNames.descriptionOn' => 'Nombres cortos pensados para los sitios de carga, como N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nombres legibles, como 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Incluir información privada',
			'operation.export.includePrivateData.descriptionOn' => 'Se incluyen nombres, direcciones, correos, grillas y notas',
			'operation.export.includePrivateData.descriptionOff' => 'Se omiten nombres, direcciones, correos, grillas y notas',
			'operation.export.includePrivateData.note' => 'La Exportación ADIF Completa siempre incluye todo',
			'operation.export.resultTitle' => 'Exportación completa',
			'operation.export.resultFailedTitle' => 'Exportación fallida',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se exportó ${count} archivo a ${path}', other: 'Se exportaron ${count} archivos a ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se exportó ${count} archivo: ${path}', other: 'Se exportaron ${count} archivos: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se compartió ${count} archivo', other: 'Se compartieron ${count} archivos', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se descargó ${count} archivo', other: 'Se descargaron ${count} archivos', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Exportación fallida: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Primero agrega un correo electrónico',
			'operation.export.stash.needsEmailBody' => 'El File Stash de Ham2K envía tus archivos al correo electrónico de tu cuenta LoFi, y con él inicias sesión en stash.ham2k.net. Tu cuenta aún no tiene uno confirmado — agrégalo en Configuración › Sincronización en la nube.',
			'operation.export.stash.openSyncSettings' => 'Abrir Sincronización en la nube',
			'operation.export.stash.replaceTitle' => 'Se reemplazará el envío reciente',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Enviaste “${name}” hace menos de 6 horas y todavía no se ha descargado. Las cuentas gratuitas guardan un solo envío a la vez, así que enviar ahora lo reemplaza.',
			'operation.export.stash.replaceConfirm' => 'Enviar de todas formas',
			'operation.export.stash.failedTitle' => 'No se pudo enviar al File Stash de Ham2K',
			'operation.export.stash.sentTitle' => 'Enviado al File Stash de Ham2K',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Puedes recuperar este archivo visitando **[stash.ham2k.net](https://stash.ham2k.net)** desde cualquier navegador.', other: 'Puedes recuperar estos archivos visitando **[stash.ham2k.net](https://stash.ham2k.net)** desde cualquier navegador.', ), 
			'operation.export.stash.mayHaveArrived' => 'El File Stash no respondió — puede que el archivo haya llegado de todos modos. Revisa stash.ham2k.net antes de volver a enviarlo',
			'operation.export.stash.notSent' => 'no enviado',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Este archivo no llegó:', other: 'Estos ${count} archivos no llegaron:', ), 
			'operation.export.stash.emailOffer' => 'O, para tu comodidad, podemos enviarte un correo electrónico con un enlace directo.',
			'operation.export.stash.emailMe' => 'Enlace por email',
			'operation.export.stash.emailSent' => 'Te enviamos un enlace de descarga por correo electrónico.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'No se pudo enviar el correo electrónico: ${error}',
			'operation.export.stash.freeTier' => 'Las cuentas gratuitas solo guardan un envío a la vez. Los suscriptores pueden guardar todos los que quieran.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se envió ${count} archivo al File Stash de Ham2K (stash.ham2k.net)', other: 'Se enviaron ${count} archivos al File Stash de Ham2K (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Ningún spot coincide con tus filtros',
			'operation.spots.error' => ({required Object error}) => 'No se pudieron cargar los spots: ${error}',
			'operation.spots.unknownBand' => 'Otra',
			'operation.spots.auto' => 'Automático',
			'operation.spots.autoValue' => ({required Object value}) => 'Automático (Actualmente ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Cualquiera',
			'operation.spots.allBands' => 'Todas las Bandas',
			'operation.spots.allModes' => 'Todos los Modos',
			'operation.spots.phoneAndCw' => 'Fonía y CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots',
			'operation.spots.spotsDisabled' => 'Spots deshabilitados para esta operación',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutos',
			'operation.spots.callsOfNote' => 'Indicativos con Notas',
			'operation.spots.yourSpots' => 'Tus Spots',
			'operation.spots.allSpots' => 'Todos los Spots',
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
			'operation.spots.filters.sorting' => 'Ordenar por',
			'operation.spots.filters.sortByTime' => 'Por hora del spot',
			'operation.spots.filters.sortByFrequency' => 'Por frecuencia',
			'operation.spots.filters.sortByWanted' => 'Más buscados',
			'operation.spots.filters.groupByBand' => 'Agrupar por banda',
			'operation.spots.filters.groupCallsWithNotes' => 'Agrupar Indicativos con Notas',
			'operation.spots.filters.alertingOnly' => 'Solo spots con alertas',
			'operation.spots.filters.sourceNoReply' => 'Sin respuesta',
			'operation.spots.filters.sourceError' => 'Error',
			'operation.spots.unavailableTitle' => 'Spots no disponibles',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} no respondieron.',
			'operation.spots.failedTitle' => 'Error en fuente de spots',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} devolvieron un error.',
			'operation.spots.slideLogIt' => 'Registrar',
			'operation.spots.slideIgnore' => 'Ignorar',
			'operation.spots.slideRestore' => 'Restaurar',
			'operation.spots.logConflict.title' => 'El panel de logging está ocupado',
			'operation.spots.logConflict.editingBody' => 'Estás editando un contacto registrado. ¿Registrar este spot, o volver y terminar la edición?',
			'operation.spots.logConflict.composingBody' => 'Empezaste a ingresar un contacto. ¿Registrar este spot, o volver y terminar lo que escribías?',
			'operation.spots.logConflict.goBack' => 'Volver',
			'operation.spots.logConflict.clearAndLog' => 'Borrar y registrar spot',
			'operation.import.title' => 'Importar datos a la operación',
			'operation.import.importAdifAction' => 'Importar QSOs desde ADIF',
			'operation.import.settingsButton' => 'Configuración de escucha',
			'operation.import.settingsTitle' => 'Escuchar otras apps',
			'operation.import.protocolAddressLabel' => 'Dirección',
			'operation.import.protocolPortLabel' => 'Puerto',
			'operation.import.protocolPortInvalid' => 'Introduce un puerto entre 1 y 65535',
			'operation.import.protocolAddressInvalid' => 'Introduce una dirección IP válida (p. ej. 127.0.0.1 o 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Recibiendo datos',
			'operation.import.protocolStatusNoData' => 'No se han recibido datos recientemente',
			'operation.import.protocolBindError' => ({required Object error}) => 'No se pudo empezar a escuchar: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Los QSOs entrantes no se pudieron guardar y se están reintentando: ${error}',
			'operation.import.n1mmProtocolName' => 'Difusión de contactos de N1MM+',
			'operation.import.n1mmAddressValue' => 'Cualquiera (difusión)',
			'operation.import.wsjtxProtocolName' => 'Servidor UDP de WSJT-X',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → pestaña Broadcast Data → marca "Enable Broadcasts" para la información de contactos. Pon la dirección IP en 127.0.0.1 si se ejecuta en esta misma computadora, o 255.255.255.255 para difundir en la red local actual.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → pestaña Reporting → sección UDP Server → marca "Accept UDP requests". Pon UDP Server en 127.0.0.1 si se ejecuta en esta misma computadora, o una dirección multicast como 239.239.0.2, y usa esa misma dirección en la configuración de arriba en esta app.',
			'operation.import.listenTitle' => 'Escuchar QSOs de otras apps',
			'operation.import.listenDescriptionOnN1mm' => 'Escuchando a N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Escuchando a WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Escuchando a N1MM+ y WSJT-X',
			'operation.import.listenDescriptionOff' => 'Desactivado',
			'operation.import.addToOperationTitle' => 'Agregar a esta operación',
			'operation.import.addToOperationDescriptionOn' => 'Los QSOs capturados se agregan a esta operación según llegan',
			'operation.import.addToOperationDescriptionOff' => 'Los QSOs capturados se retienen hasta que actives esto',
			'operation.import.pendingSectionTitle' => 'QSOs capturados',
			'operation.import.pendingEmpty' => 'Nada capturado todavía',
			'operation.import.stationMismatch' => ({required Object call}) => 'Registrado con ${call}, que no es la estación de esta operación',
			'operation.import.discardAction' => 'Descartar',
			'operation.import.gapDialogTitle' => '¿Incluir capturas anteriores?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Antes se capturaron ${count} QSOs más, previos a un salto en los datos. ¿Incluirlos también?',
			'operation.import.gapDialogRecentOnly' => 'Solo los recientes',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Incluir los ${count}',
			'map.outlineIssue.link' => '¿Problemas?',
			'map.outlineIssue.title' => 'Informar un problema con un contorno',
			'map.outlineIssue.reference' => 'Qué contorno',
			'map.outlineIssue.severity' => '¿Qué tan grave es?',
			'map.outlineIssue.minor' => 'Detalle menor',
			'map.outlineIssue.major' => 'Algo serio',
			'map.outlineIssue.explanation' => '¿Qué está mal?',
			'map.outlineIssue.explanationHint' => 'Qué tiene mal el contorno, y dónde',
			'map.outlineIssue.send' => 'Enviar',
			'map.outlineIssue.sending' => 'Enviando tu informe — gracias',
			'map.outlineIssue.copy' => 'Copiar informe',
			'map.outlineIssue.notSent' => 'No se pudo enviar el informe',
			'map.outlineIssue.copied' => 'Informe copiado',
			'map.outlineIssue.notCopied' => 'No se pudo copiar el informe',
			'map.outlinesDisclaimer' => 'Los contornos son solo orientativos. ¡Investiga por tu cuenta!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contornos: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Límites: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Instalaciones: ${sources}',
			'map.fullCredits' => 'Créditos completos de los datos',
			'map.fewerCredits' => 'Menos créditos',
			'map.emptyState' => 'Aún no hay ubicaciones de QSO.\nLos QSOs con grilla, estado o país aparecerán aquí.',
			'map.unavailable' => 'El mapa no está disponible en este momento.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plano',
			'map.globe' => 'Globo',
			'map.zoomIn' => 'Acercar',
			'map.zoomOut' => 'Alejar',
			'map.resetNorth' => 'Orientar al norte',
			'map.postcard.button' => 'Postal de la operación',
			'map.postcard.title' => ({required Object title}) => 'Postal de ${title}',
			'map.postcard.portrait' => 'Vertical',
			'map.postcard.landscape' => 'Horizontal',
			'map.postcard.square' => 'Cuadrada',
			'map.postcard.save' => 'Guardar…',
			'map.postcard.download' => 'Descargar',
			'map.postcard.share' => 'Compartir',
			'map.postcard.copy' => 'Copiar',
			'map.postcard.copied' => 'Copiada al portapapeles',
			'map.postcard.saved' => ({required Object path}) => 'Guardada en ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Se descargó ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Se guardaron ${count} imágenes en ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Se guardaron ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ya se habían guardado ${names}',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Descargando ${count} imágenes — permítelas si el navegador pregunta',
			'map.postcard.mapLeftOut' => 'El mapa no cargó, así que quedó fuera',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — el mapa no cargó, así que quedó fuera',
			'map.postcard.continued' => ({required Object title}) => '${title} (continuación)',
			'map.postcard.previousPage' => 'Página anterior',
			'map.postcard.nextPage' => 'Página siguiente',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Página ${page} de ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} Q', other: '${count} Qs', ), 
			'map.postcard.options' => 'Opciones de la postal',
			'map.postcard.bandLegend' => 'Mostrar leyenda de bandas',
			'map.postcard.grayline' => 'Mostrar línea gris',
			'map.postcard.sectionsAndOrder' => 'Secciones del resumen y orden',
			'map.postcard.sectionDays' => 'Cada día',
			'map.postcard.reset' => 'Restablecer',
			'map.postcard.failed' => ({required Object error}) => 'No se pudo crear la postal: ${error}',
			'map.postcard.mapNotReady' => 'El mapa no terminó de cargar. Revisa la conexión y vuelve a intentarlo.',
			'map.postcard.saveFailed' => ({required Object error}) => 'No se pudo guardar la postal: ${error}',
			'map.postcard.copyFailed' => 'El portapapeles no aceptó la imagen. Vuelve a intentarlo.',
			'map.postcard.shareFailed' => 'No se pudo compartir la postal. Vuelve a intentarlo.',
			'map.postcard.fileName' => 'postal',
			'mapsView.title' => 'Mapas',
			'mapsView.searchHint' => 'Buscar parques, cumbres y más',
			'mapsView.activities' => 'Actividades',
			'mapsView.layers' => 'Capas',
			'mapsView.baseMap' => 'Mapa base',
			'mapsView.satellite' => 'Satélite (Esri)',
			'mapsView.facilities' => 'Instalaciones de parques',
			'mapsView.boundaries' => 'Límites',
			'mapsView.currentLocation' => 'Ubicación actual',
			'mapsView.noMatches' => ({required Object text}) => 'Nada coincide con “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} referencia en ${where}', other: '${count} referencias en ${where}', ), 
			'mapsView.startOperation' => 'Iniciar una operación con estas referencias',
			'activitiesView.title' => 'Actividades',
			'activitiesView.activitiesCountZero' => 'Sin actividades seleccionadas',
			'activitiesView.activitiesCountOne' => '1 actividad',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} actividades',
			'activitiesView.empty' => 'Aún no hay actividades — usa Sugerencias y Búsqueda abajo para agregar una',
			'activitiesView.removeActivity' => 'Quitar',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Abrir ${name}',
			'activitiesView.editActivity' => 'Editar actividad',
			'activitiesView.manageExtensions' => 'Gestionar extensiones',
			'activitiesView.manage' => 'Gestionar',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipos de actividad: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipos de actividad: ${first} y ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipos de actividad: ${first}, ${second} y ${more} más',
			'activitiesView.reference' => 'Referencia',
			'activitiesView.invalidReference' => 'No válida',
			'activitiesView.duplicateReference' => 'Ya agregada',
			'activitiesView.searchHint' => 'Busca por nombre, referencia o cualquier otra cosa…',
			'activitiesView.noSuggestions' => 'Sin coincidencias',
			'activitiesView.noSuggestionsHint' => 'Busca por nombre o número de referencia arriba',
			'activitiesView.noSuggestionsExample' => '(por ejemplo \'trail\' o \'4556\')',
			'activitiesView.allOptions' => 'Tipos de actividad',
			'activitiesView.determiningLocation' => 'Determinando ubicación actual…\nEsperando señal de GPS para encontrar referencias cercanas',
			'activitiesView.locationUnavailableTitle' => 'Datos de ubicación no disponibles',
			'activitiesView.locationDeniedTitle' => 'Permiso de ubicación denegado',
			'activitiesView.locationBlockedTitle' => 'Permiso de ubicación bloqueado',
			'activitiesView.noNearbyReason' => 'No se pueden determinar referencias cercanas',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Toca ${icon} para introducir tu ubicación manualmente,\no simplemente busca referencias por nombre',
			'activitiesView.locationGrantAction' => 'Permitir acceso a la ubicación',
			'activitiesView.locationSettingsAction' => 'Abrir Configuración',
			'activitiesView.locationSettingsUnavailable' => 'Permite el acceso a la ubicación en la configuración del sistema',
			'activitiesView.locationGrantRefused' => 'Sigue sin ubicación — el sistema volvió a negarlo',
			'activitiesView.searchUnavailableTitle' => 'Búsqueda de actividades no disponible',
			'activitiesView.searchUnavailableReason' => 'Una extensión de actividades no pudo responder a la búsqueda. Inténtalo de nuevo en un momento.',
			'activitiesView.emptySheet' => 'Usa las sugerencias y la búsqueda abajo para agregar una',
			'activitiesView.exports' => 'Exportaciones',
			'activitiesView.exportLogs' => 'Exportar logs',
			'activitiesView.tools' => 'Herramientas',
			'activitiesView.toolsTitle' => 'Herramientas de la operación',
			'activitiesView.operationDetails' => 'Detalles de la Operación',
			'activitiesView.share' => 'Compartir',
			'activitiesView.archive' => 'Archivar',
			'activitiesView.deleteOperation' => 'Eliminar Operación',
			'activitiesView.undeleteOperation' => 'Restaurar Operación',
			'activitiesView.alreadySelected' => 'Ya seleccionada',
			'activitiesView.selected' => 'Seleccionada',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} de ${count}',
			'activitiesView.previousPick' => 'Coincidencia anterior',
			'activitiesView.nextPick' => 'Siguiente coincidencia',
			'activitiesView.retiredReference' => 'Retirada',
			'activitiesView.enableExtension' => ({required Object name}) => 'Habilitar ${name}',
			'activitiesView.enableExtensionHint' => 'Esta extensión coincide con tu búsqueda, pero no está habilitada',
			'activitiesView.enableExtensionForRefHint' => 'Esta extensión maneja una de las referencias de esta operación, pero no está habilitada',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} no está funcionando',
			'activitiesView.extensionNotRunningHint' => 'Esta extensión ha sido deshabilitada; abre la configuración de extensiones para más información',
			'activitiesView.installExtension' => ({required Object name}) => 'Instalar ${name}',
			'activitiesView.installExtensionHint' => 'Esta extensión coincide con tu búsqueda, pero no está instalada',
			'activitiesView.onlyCatalogMatches' => 'Sin coincidencias\nAlgunas extensiones del catálogo podrían tener resultados.\nInstálalas en Tipos de actividad, más abajo.',
			'activitiesView.setupUnavailable' => 'No se pudo cargar la configuración de esta actividad; inténtalo desde Gestionar',
			'activitiesView.controlsUnavailableTitle' => 'Controles de actividad no disponibles',
			'activitiesView.controlsUnavailableReason' => 'Tus referencias están a salvo, pero ahora mismo no se pueden editar.',
			'activitiesView.controlsUnavailableRetry' => 'Reintentar',
			'activitiesView.onlyDisabledMatches' => 'Sin coincidencias\nAlgunas extensiones disponibles podrían tener resultados.\nHabilítalas en Tipos de actividad, más abajo.',
			'activitiesView.onlyNotRunningMatches' => 'Sin coincidencias\nAlgunas extensiones que podrían tener resultados no están funcionando.\nMira en Tipos de actividad, más abajo.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Buscar',
			'activitiesView.addToOperation' => 'Agregar a la operación',
			'activitiesView.addToOperationShort' => 'Agregar a op.',
			'activitiesView.mapEmptyState' => 'No hay resultados que mostrar en el mapa',
			'activitiesView.mapEmptyStateHint' => 'Vuelve a la lista o busca otra cosa',
			'activitiesView.imports' => 'Importaciones',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Fecha',
			'loggingControls.now' => 'Ahora',
			'loggingControls.manualTimeSettings' => 'Hora manual',
			'loggingControls.manualTimeIncrement' => 'Incremento por QSO',
			'loggingControls.manualTimeIncrementNone' => 'Ninguno',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} minuto', other: '${count} minutos', ), 
			'loggingControls.frequency' => 'Frecuencia',
			'loggingControls.mode' => 'Modo',
			'loggingControls.theirCall' => 'Indicativo',
			'loggingControls.noteField' => 'Nota',
			'loggingControls.todoField' => 'Tarea',
			'loggingControls.sent' => 'Env.',
			'loggingControls.rcvd' => 'Recib.',
			'loggingControls.more' => 'Más',
			'loggingControls.revert' => 'Revertir',
			'loggingControls.undoDelete' => 'Deshacer eliminación',
			'loggingControls.restore' => 'Restaurar',
			'loggingControls.wipe' => 'Borrar',
			'loggingControls.undo' => 'Deshacer',
			'loggingControls.pendingDeleteTapWarning' => 'Toca la papelera una vez más para eliminar este QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Haz clic en la papelera una vez más para eliminar este QSO',
			'loggingControls.deletedQsoWarning' => 'QSO eliminado',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Toca la papelera una vez más para eliminar este ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Haz clic en la papelera una vez más para eliminar este ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} eliminado',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Potencia',
			'loggingControls.notesControl' => 'Notas',
			'loggingControls.power' => 'Potencia',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controles de logging',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot en ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} en ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Demasiado tarde para hacer spot de ${call}',
			'loggingControls.spotNoFreq' => 'Primero establece una frecuencia para hacer spot',
			'loggingControls.selfSpotDisabled' => 'Self-spot deshabilitado',
			'loggingControls.spotComment' => 'Comentario',
			'loggingControls.spottingAutoControl' => 'Auto re-spot',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Re-spot cada ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Auto en ${time}. ¿Detener?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto en ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto en ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto en ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Auto re-spot no iniciado: el spot no se envió',
			'loggingControls.spotAutoMoved' => 'Auto re-spot no iniciado: la frecuencia cambió durante el spot',
			'loggingControls.spotAutoStopped' => 'Auto re-spot detenido',
			'loggingControls.spotAutoLeftFreq' => 'Auto re-spot detenido: cambió la frecuencia',
			'loggingControls.spotAutoNoFreq' => 'Auto re-spot detenido: la radio no reporta frecuencia',
			'loggingControls.spotBusy' => 'Todavía se está enviando otro spot',
			'loggingControls.bandOrFreqRequired' => 'Establece una frecuencia o banda antes de registrar',
			'loggingControls.missingBand' => 'Sin Banda',
			'loggingControls.missingMode' => 'Sin Modo',
			'loggingControls.saveFailed' => ({required Object error}) => 'No se pudo guardar: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => 'No se pudo eliminar: ${error}',
			'loggingControls.info.noQsos' => 'Aún no hay QSOs... ¡Vamos al aire!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} en ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} desde el último',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h en los últimos 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h en los últimos 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} a',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) a',
			'loggingControls.info.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => '¡Dup!',
			'loggingControls.info.noticeNewBand' => 'Nueva Banda',
			'loggingControls.info.noticeNewMode' => 'Nuevo Modo',
			'loggingControls.info.noticeNewDXCC' => 'Nuevo DXCC',
			'loggingControls.info.noticeNewState' => 'Nuevo Estado',
			'loggingControls.info.noticeNewProvince' => 'Nueva Provincia',
			'loggingControls.info.noticeNewDay' => 'Nuevo Día',
			'loggingControls.info.noticeNewRef' => 'Nueva Ref',
			'loggingControls.info.noticeNewMult' => 'Nuevo Mult',
			'loggingControls.info.noticeNewZone' => 'Nueva Zona',
			'loggingControls.info.noticeInvalidMode' => 'Modo Incorrecto',
			'loggingControls.info.noticeInvalidBand' => 'Banda Incorrecta',
			'loggingControls.info.noticeInvalidCategory' => 'No Contactable',
			'loggingControls.info.noticeOverTime' => 'Fuera de Tiempo',
			'loggingControls.info.noticeWorkedBefore' => 'Ya Trabajado',
			'loggingControls.info.noticeNewPark' => 'Nuevo Parque',
			'loggingControls.info.noticeNewSection' => 'Nueva Sección',
			'loggingControls.info.noticeBonusStation' => '¡Estación Bonus!',
			'loggingControls.info.noticeMissingExchange' => 'Sin Intercambio',
			'loggingControls.info.noticeInvalidExchange' => 'Intercambio Inválido',
			'loggingControls.info.noticeUnknownEvent' => 'Evento Desconocido',
			'loggingControls.info.noticeIncompleteCall' => 'Indicativo Incompleto — No Puntúa',
			'loggingControls.info.noticeOurGrid' => 'Falta Nuestra Grilla',
			'loggingControls.info.noticeRareCounty' => '¡Condado Raro!',
			'loggingControls.info.noticeOurLocation' => 'Falta Nuestro Condado',
			'loggingControls.info.noticeShortGrid' => 'Grilla Muy Corta',
			'formChrome.untitled' => '(sin título)',
			'formChrome.showMore' => 'Mostrar más',
			'formChrome.showAll' => 'Mostrar todo',
			'formChrome.showFewer' => 'Mostrar menos',
			'formChrome.defaults' => 'Por defecto',
			'formChrome.search' => 'Buscar',
			'formChrome.clear' => 'Borrar',
			'formChrome.openPage' => 'Abrir página',
			'formChrome.connected' => 'Conectado',
			'formChrome.notConnected' => 'No conectado',
			'formChrome.manage' => 'Gestionar',
			'formChrome.connect' => 'Conectar',
			'formChrome.formTitle' => 'Formulario',
			'formChrome.addItem' => ({required Object label}) => 'Agregar ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Editar ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} seleccionados)',
			'formChrome.validationError' => ({required Object error}) => 'Error de validación: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Error de transformación: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Error: ${error}',
			'formChrome.removeItem' => 'Eliminar',
			'formChrome.deleteItemTitle' => ({required Object name}) => '¿Eliminar ${name}?',
			'formChrome.storageUnavailable' => 'Credenciales no disponibles',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.operatorCall' => 'Operador',
			'qsoEditForm.position' => 'Posición',
			'qsoEditForm.theirName' => 'Nombre',
			'qsoEditForm.theirGrid' => 'Grilla',
			'qsoEditForm.theirState' => 'Estado',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Su Información',
			'qsoEditForm.sectionOur' => 'Nuestra Información',
			'qsoEditForm.sectionNotes' => 'Notas',
			'qsoEditForm.theirCity' => 'Ciudad',
			'qsoEditForm.theirCounty' => 'Condado',
			'qsoEditForm.theirEntity' => 'Entidad',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Sección ARRL',
			'qsoEditForm.theirLat' => 'Latitud',
			'qsoEditForm.theirLon' => 'Longitud',
			'qsoEditForm.theirPower' => 'Su potencia',
			'qsoList.empty' => 'Aún no hay QSOs — ¡haz un contacto!',
			'qsoList.bandOrModeWarning' => 'Verifica que tu banda y modo sean correctos',
			'qsoList.today' => 'Hoy',
			'qsoList.yesterday' => 'Ayer',
			'qsoList.tomorrow' => 'Mañana',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Buscar en el log (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Buscar en el log',
			'qsoList.find.hint' => 'Número de QSO o indicativo',
			'qsoList.find.noMatches' => 'Sin coincidencias',
			'qsoList.find.noOperationQsos' => 'No hay QSOs en esta operación',
			'qsoList.find.noPeriodQsos' => 'No hay QSOs en este período',
			'qsoList.find.outsideQsosOne' => '1 QSO fuera de esta operación',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSOs fuera de esta operación',
			'qsoList.find.pastQsosOne' => '1 QSO anterior',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} QSOs anteriores',
			'loggingPanel.stats' => 'Estadísticas de la Operación',
			'loggingPanel.scoring' => 'Puntuación',
			'loggingPanel.dxccEntities' => 'Entidades DXCC',
			'loggingPanel.statesWorked' => 'Estados',
			'loggingPanel.provincesWorked' => 'Provincias',
			'loggingPanel.duplicates' => 'Duplicados',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostrar Imagen',
			'callInfo.imageUnavailable' => 'Foto no disponible',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Notas',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} a',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) a',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) a',
			'callInfo.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)',
			'callInfo.thisOpCountOne' => '1 QSO en esta operación',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs en esta operación',
			'callInfo.otherOpsCountOne' => '1 QSO en otras operaciones',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs en otras operaciones',
			'callInfo.andMore' => ({required Object count}) => '… y ${count} más',
			'callInfo.withCall' => ({required Object call}) => 'con ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'desde ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} en los últimos 7 días',
			'callInfo.history.today' => ({required Object n}) => '${n} hoy',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Configuración',
			'settings.language' => 'Idioma',
			'settings.languageSystem' => ({required Object language}) => 'Seguir la configuración del sistema (${language})',
			'settings.theme.title' => 'Tema',
			'settings.theme.system' => 'Seguir la configuración del sistema',
			'settings.theme.light' => 'Claro',
			'settings.theme.dark' => 'Oscuro',
			'settings.themeDescription.system' => 'Siguiendo la configuración del sistema',
			'settings.themeDescription.light' => 'Siempre en Modo Claro',
			'settings.themeDescription.dark' => 'Siempre en Modo Oscuro',
			'settings.fontScale' => 'Tamaño de Textos',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Más pequeño--',
			'settings.fontScaleOpts.smallestMinus' => 'Más pequeño-',
			'settings.fontScaleOpts.smallest' => 'Más pequeño',
			'settings.fontScaleOpts.smaller' => 'Pequeño',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Grande',
			'settings.fontScaleOpts.largest' => 'Más grande',
			'settings.fontScaleOpts.largestPlus' => 'Más grande+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Más grande++',
			'settings.keepDeviceAwake.title' => 'Mantener dispositivo encendido',
			'settings.keepDeviceAwake.descriptionOn' => 'Pantalla encendida mientras estás en la vista de logging o hay una sincronización en curso',
			'settings.keepDeviceAwake.descriptionOff' => 'Permitiendo que la pantalla se bloquee como siempre',
			'settings.layoutDensity' => 'Densidad de la interfaz',
			'settings.layoutDensityOpts.auto' => 'Automática',
			'settings.layoutDensityOpts.densest' => 'Muy compacta',
			'settings.layoutDensityOpts.dense' => 'Compacta',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Amplia',
			'settings.layoutDensityOpts.sparsest' => 'Muy amplia',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'la ventana es demasiado baja, usando ${effective}',
			'settings.layoutDensityAtLimit' => 'al límite',
			'settings.distanceUnits' => 'Unidades de distancia',
			'settings.distanceUnitsOpts.kilometers' => 'Kilómetros',
			'settings.distanceUnitsOpts.miles' => 'Millas',
			'settings.userInterface' => 'Interfaz de usuario',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Modo para zurdos',
			'settings.logging.leftieMode.descriptionOn' => 'Usando el diseño para zurdos',
			'settings.logging.leftieMode.descriptionOff' => 'Usando el diseño para diestros',
			'settings.logging.countryFlags.title' => 'Banderas de País',
			'settings.logging.countryFlags.dx' => 'Mostrar solo para contactos DX',
			'settings.logging.countryFlags.all' => 'Mostrar banderas para todos los contactos',
			'settings.logging.countryFlags.none' => 'No mostrar banderas',
			'settings.logging.countryFlagsDescription.dx' => 'Mostrando banderas solo para contactos DX',
			'settings.logging.countryFlagsDescription.all' => 'Mostrando banderas para todos los contactos',
			'settings.logging.countryFlagsDescription.none' => 'Sin mostrar banderas',
			'settings.logging.suggestDefaultOperator.title' => 'Sugerir operador',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Ofreciendo tu indicativo como operador cuando la operación usa otro indicativo de estación',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Dejando el operador en blanco salvo que lo completes',
			'settings.logging.showBearing.title' => 'Mostrar rumbo',
			'settings.logging.showBearing.descriptionOn' => 'Mostrando el rumbo estimado hacia la estación',
			'settings.logging.showBearing.descriptionOff' => 'Sin mostrar información de rumbo',
			'settings.logging.showReverseBearing.title' => 'Mostrar también el rumbo inverso',
			'settings.logging.showReverseBearing.descriptionOn' => 'Mostrando también el rumbo desde la estación, como "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Mostrando solo el rumbo hacia la estación',
			'settings.logging.switchSentRcvd.title' => 'Intercambiar el orden de los reportes de señal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Primero el reporte enviado, luego el recibido',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Primero el reporte recibido, luego el enviado',
			'settings.logging.jumpAfterRST.title' => 'Saltar al siguiente campo al ingresar RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Saltando al siguiente campo después del RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Sin saltar automáticamente',
			'settings.logging.defaultReport.title' => 'Reporte por defecto — Fonía',
			'settings.logging.defaultReport.description' => 'Se usa cuando Enviado o Recibido quedan vacíos en SSB, FM o AM',
			'settings.logging.defaultReportCW.title' => 'Reporte por defecto — CW y datos',
			'settings.logging.defaultReportCW.description' => 'Se usa cuando Enviado o Recibido quedan vacíos en CW, RTTY y otros modos digitales',
			'settings.logging.defaultReportFT8.title' => 'Reporte por defecto — FT8 y FT4',
			'settings.logging.defaultReportFT8.description' => 'Se usa cuando Enviado o Recibido quedan vacíos en los modos FT',
			'settings.logging.numbersRow.title' => 'Teclas de Números',
			'settings.logging.numbersRow.description' => 'Muestra una fila de teclas numéricas sobre el teclado mientras registras',
			'settings.logging.numbersRowExtra.title' => 'Tecla de barra y punto',
			'settings.logging.numbersRowExtra.description' => 'Agrega una tecla contextual: “/” para indicativos, “.” para números',
			'settings.logging.numbersRowVibrate.title' => 'Vibrar al pulsar',
			'settings.logging.numbersRowVibrate.description' => 'Respuesta háptica al pulsar una tecla numérica',
			'settings.logging.bands' => 'Bandas preferidas',
			'settings.logging.modes' => 'Modos preferidos',
			'settings.catServer.title' => 'Servidor CAT',
			'settings.catServer.description' => 'Permite que otras apps (WSJT-X, programas de log, etc.) controlen la radio a través de Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocolo',
			'settings.catServer.protocolOpts.off' => 'Deshabilitado',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Puerto',
			'settings.catServer.openAccess' => 'Acceso abierto',
			'settings.catServer.openAccessOn' => 'Cualquier computadora de la red local puede conectarse.',
			'settings.catServer.openAccessOff' => 'Solo las apps de esta computadora pueden conectarse.',
			'settings.catServer.allowTransmit' => 'Permitir que las apps transmitan',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'Las apps pueden activar el PTT de la radio, hasta ${minutes} minutos seguidos.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'Las apps de cualquier computadora de la red local pueden activar el PTT de la radio, hasta ${minutes} minutos seguidos.',
			'settings.catServer.allowTransmitOff' => 'Las apps no pueden activar el PTT de la radio. Usa VOX o su propia configuración de PTT.',
			'settings.catServer.allowTransmitUnsupported' => 'La radio del VFO principal no puede ponerse en transmisión desde Ham2K Logger, así que las apps no pueden transmitir a través de ella.',
			'settings.catServer.off' => 'Apagado.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, iniciando…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} en el puerto ${port}. Clientes conectados: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} en el puerto ${port}, pero no hay una radio del VFO principal conectada.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} no puede escuchar en el puerto ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} no puede escuchar en el puerto ${port}: otro programa lo está usando, a menudo el propio ${protocol}. Cierra ese programa o elige otro puerto.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} no puede escuchar en el puerto ${port}: esta computadora no lo permite. Elige un puerto por encima de 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} dejó de escuchar en el puerto ${port}. Reintentando…',
			'settings.cluster.title' => 'Clúster DX',
			'settings.cluster.description' => 'El servidor donde las extensiones publican y leen spots, con sesión iniciada como el operador.',
			'settings.cluster.connect' => 'Conectar al clúster',
			'settings.cluster.connectOn' => 'Las extensiones se conectan al clúster cuando lo necesitan',
			'settings.cluster.connectOff' => 'Nada se conecta al clúster',
			'settings.cluster.console' => 'Mostrar consola',
			'settings.cluster.consoleDescription' => 'Lo que envía el clúster, y un lugar para escribir comandos',
			'settings.cluster.consoleTitle' => 'Consola del clúster',
			'settings.cluster.consoleConnect' => 'Conectar',
			'settings.cluster.consoleDisconnect' => 'Desconectar',
			'settings.cluster.consoleCommand' => 'Comando',
			'settings.cluster.consoleEmpty' => 'Nada todavía. Conéctate, o espera a que una extensión use el clúster.',
			'settings.cluster.consoleRetry' => ({required Object command}) => 'Enviando de nuevo: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => 'No enviado: ${command} (${reason})',
			'settings.cluster.server' => 'Servidor del clúster',
			'settings.cluster.selectServer' => 'Seleccionar servidor',
			'settings.cluster.serverOther' => 'Otro',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'Aún no hay servidor ingresado, así que los spots van a ${node}',
			'settings.cluster.customHost' => 'Servidor',
			'settings.cluster.customPort' => 'Puerto',
			'settings.cluster.password' => 'Contraseña',
			'settings.cluster.passwordDescription' => 'Solo si hace falta',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Contraseña guardada para ${node}',
			'settings.cluster.scrollback' => 'Líneas conservadas',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} líneas',
			'settings.cluster.connection' => 'Conexión',
			'settings.cluster.statusIdle' => 'No conectado. Se conecta cuando una extensión lo necesita. Toca para probar.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Conectando a ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Conectado a ${node} como ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'No se pudo conectar a ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'No disponible en la versión web.',
			'settings.cluster.statusOff' => 'Apagado. Activa Conectar al clúster para usarlo.',
			'settings.cluster.errors.noCall' => 'no hay indicativo de operador con el que iniciar sesión',
			'settings.cluster.errors.connectFailed' => 'no se pudo acceder al nodo',
			'settings.cluster.errors.needsPassword' => 'el nodo pide una contraseña y no hay ninguna guardada',
			'settings.cluster.errors.loginFailed' => 'el nodo no aceptó el inicio de sesión',
			'settings.cluster.errors.disconnected' => 'el nodo cerró la conexión',
			'settings.cluster.errors.timeout' => 'el nodo no respondió',
			'settings.cluster.errors.off' => 'Conectar al clúster está apagado',
			'settings.spotting.title' => 'Spotting',
			'settings.spotting.respotInterval' => 'Auto re-spot cada',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Auto re-spot por defecto',
			'settings.spotting.autoRespotByDefaultOn' => 'Habilitar el auto re-spot después de publicar cualquier spot',
			'settings.spotting.autoRespotByDefaultOff' => 'Requiere una acción del usuario para habilitar el auto re-spot',
			'settings.spotting.pulseBeforeRespot' => 'Pulso antes de cada auto re-spot',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'El chip de Spotting parpadea en azul durante los ${seconds} segundos previos a cada re-spot',
			'settings.spotting.pulseBeforeRespotOff' => 'Sin parpadeo antes de un auto re-spot',
			'settings.radio.title' => 'Control CAT',
			'settings.radio.loggingAndCat' => 'Logging y CAT',
			'settings.radio.tuningSection' => 'Sintonía',
			'settings.radio.keyerSection' => 'Manipulador',
			'settings.radio.servicesSection' => 'Servicios',
			'settings.radio.stationConfigurationSection' => 'Configuración de Estación',
			'settings.radio.moreSettings' => 'Más opciones de configuración de la estación',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controlar el PTT con el teclado',
			'settings.radio.pttKey.modes.off' => 'No',
			'settings.radio.pttKey.modes.toggle' => 'Alternar',
			'settings.radio.pttKey.modes.hold' => 'Mantener',
			'settings.radio.pttKey.descriptions.off' => 'El teclado no activa el PTT de la radio.',
			'settings.radio.pttKey.descriptions.toggle' => 'En modos de fonía, la tecla PTT pone la radio en transmisión y al pulsarla de nuevo la devuelve a recepción. Vuelve a recepción por sí sola después de un minuto.',
			'settings.radio.pttKey.descriptions.hold' => 'En modos de fonía, la radio transmite mientras la tecla PTT esté pulsada, hasta un minuto.',
			'settings.radio.pttKey.key' => 'Tecla PTT',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Transmitiendo',
			'settings.radio.smartVfoSnap.title' => 'Ajuste inteligente del VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Al dejar de girar el dial, redondeando la frecuencia a un paso razonable. Solo en modos de voz.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Quedándose exactamente donde la sintonizaste.',
			'settings.radio.snapDebounce.title' => 'Ajuste inteligente: retardo de reposo',
			'settings.radio.snapDebounce.description' => 'Cuánto debe detenerse el dial antes de redondear la frecuencia. Menos se siente inmediato; más deja margen para un giro lento.',
			'settings.radio.snapLongMove.title' => 'Ajuste inteligente: giro largo',
			'settings.radio.snapLongMove.description' => 'Si te mueves al menos esto, la frecuencia se redondea a un kHz entero, por lento que hayas terminado.',
			'settings.radio.snapMinMove.title' => 'Ajuste inteligente: giro mínimo',
			'settings.radio.snapMinMove.description' => 'Si te mueves menos que esto no se redondea la frecuencia, así que el ajuste fino se respeta.',
			'settings.radio.snapMinSpeed.title' => 'Ajuste inteligente: velocidad mínima',
			'settings.radio.snapMinSpeed.description' => 'Si giras el dial más despacio que esto no se redondea la frecuencia, salvo que haya sido un giro largo.',
			'settings.radio.enterSends.pillOff' => 'ESM apagado',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter envía mensajes',
			'settings.radio.enterSends.off' => 'Apagado',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter envía mensajes: ${state}. Toca para cambiar.',
			'settings.radio.keyerSpeed.title' => 'Velocidad del manipulador',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Mensajes de CW',
			'settings.radio.cwMessages.notSupported' => 'La radio actual no admite manipulación de CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Mensaje ${n}',
			'settings.radio.cwMessages.labelField' => 'Etiqueta',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Etiqueta de F${n}',
			'settings.radio.cwMessages.details' => 'Detalles',
			'settings.radio.cwMessages.empty' => '(vacío)',
			'settings.radio.cwMessages.sets' => 'Juego de mensajes',
			'settings.radio.cwMessages.newSet' => 'Nuevo juego',
			'settings.radio.cwMessages.renameSet' => 'Renombrar juego',
			'settings.radio.cwMessages.deleteSet' => 'Eliminar juego',
			'settings.radio.cwMessages.newSetName' => 'Nombre',
			'settings.radio.cwMessages.setDefault' => 'Por defecto',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Mensajes ESM',
			'settings.radio.cwMessages.setSaved' => 'Mis mensajes',
			'settings.radio.cwMessages.repeat' => 'Repetir mensaje 1',
			'settings.radio.cwMessages.repeatShort' => 'Repetir M1',
			'settings.radio.cwMessages.cooldown' => 'Pausa antes de repetir',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n} segundos',
			'settings.radio.cwMessages.repeatWait' => 'Repitiendo',
			'settings.radio.cwMessages.keyboard' => 'Escribir para transmitir',
			'settings.radio.cwMessages.keyboardField' => 'Escribe para transmitir',
			'settings.radio.cwMessages.help' => 'Ayuda',
			'settings.radio.cwMessages.helpTitle' => 'Cómo escribir mensajes de CW',
			'settings.radio.cwMessages.helpIntro' => 'Los mensajes pueden usar plantillas con los siguientes valores:',
			'settings.radio.cwMessages.helpOpCall' => 'Tu indicativo',
			'settings.radio.cwMessages.helpQsoCall' => 'Su indicativo — en una pila //, el indicativo que se registrará',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Su indicativo, si hay un indicativo válido; vacío si es parcial',
			'settings.radio.cwMessages.helpQsoPartial' => 'Un indicativo parcial; vacío si hay un indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextCall' => 'En una pila //, el indicativo que se seleccionará para registrar a continuación, si hay un indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'En una pila //, el siguiente parcial después de registrar el contacto actual',
			'settings.radio.cwMessages.helpQsoName' => 'Su nombre de pila: el que escribiste o, si no, el de la búsqueda',
			'settings.radio.cwMessages.helpQsoState' => 'Su estado: el que escribiste o, si no, el de la búsqueda',
			'settings.radio.cwMessages.helpKeyerMsg' => 'El mensaje 1 tal como se enviaría, dentro de otro mensaje. Válido para los mensajes 1 a 8',
			'settings.radio.cwMessages.helpQsoRst' => 'El reporte que envías',
			'settings.radio.cwMessages.helpQsoSerial' => 'Tu número de serie, en un concurso que lo envía',
			'settings.radio.cwMessages.helpPad' => 'Rellena con ceros hasta esa cantidad de dígitos: 7 se envía como 007',
			'settings.radio.cwMessages.helpCut' => 'Números abreviados, T por 0 y N por 9: 599 se envía como 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Elige qué dígitos abreviar, entre comillas — 0 es T, 1 es A, 5 es E, 9 es N',
			'settings.radio.cwMessages.helpFullExample' => 'Ejemplo completo:',
			'settings.radio.cwMessages.helpExample' => 'Envía W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Con Enter envía mensajes activado, Enter envía los mensajes según su tecla de función, como hace N1MM. El juego Mensajes ESM empieza con estos:',
			'settings.radio.cwMessages.helpEsmCq' => 'En Run, Enter con el indicativo vacío llama CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Tu intercambio: tras su indicativo en Run, tras su respuesta en S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Las gracias, una vez registrado el contacto: qso es el contacto tal como se registró, next el que sigue',
			'settings.radio.cwMessages.helpEsmMyCall' => 'En S&P, tu indicativo a la estación que contestas',
			'settings.radio.cwMessages.helpEsmHisCall' => 'En Run, su indicativo antes de tu intercambio',
			'settings.radio.cwMessages.helpEsmAgain' => 'Pide repetir cuando no se copió nada de su intercambio',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 sugerido para pilas //: da las gracias, luego llama a la siguiente estación de la pila y envía tu intercambio, o pide repetir un parcial (TU KR?); si no queda nada, solo TU',
			'settings.radio.keyerControl.label' => 'Manipulador',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => 'Voz',
			'settings.radio.voiceMessages.title' => 'Mensajes de fonía',
			'settings.radio.voiceMessages.notSupported' => 'La radio actual no admite mensajes de fonía',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memoria de voz ${n}',
			'settings.radio.voiceMessages.labelField' => 'Etiqueta',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Etiqueta de la memoria de voz ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Vacía',
			'settings.radio.voiceMessages.notMeasured' => 'Duración desconocida',
			'settings.radio.voiceMessages.playButton' => 'Reproducir',
			'settings.radio.voiceMessages.recordButton' => 'Grabar',
			'settings.radio.voiceMessages.stopButton' => 'Detener',
			'settings.radio.voiceMessages.repeat' => 'Repetir mensaje 1',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Notas para ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Estas memorias están en la radio de ${device}. Sus nombres y duraciones pertenecen a ese dispositivo.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Se guarda en la radio, donde también lo ven sus otros clientes.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Espera al indicador [REC] en la radio, luego mantén pulsado el PTT y graba tu mensaje. Termínalo pulsando el botón Detener aquí en la app antes de soltar el PTT para evitar clics indeseados.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Espera a que el indicador [REC] parpadee al menos cuatro veces, luego mantén pulsado el PTT y graba tu mensaje. Termínalo pulsando el botón Detener aquí en la app antes de soltar el PTT para evitar clics indeseados.',
			'settings.radio.voiceMessages.pill' => 'Voz',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Reproducir la memoria ${n}',
			'settings.radio.voiceMessages.stop' => 'Detener',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Grabar la memoria ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Detener la grabación',
			'settings.radio.voiceMessages.playing' => 'Reproduciendo…',
			'settings.radio.voiceMessages.recording' => 'Grabando…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Reproduciendo ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Grabando ${label}',
			'settings.radio.voiceMessages.doubtful' => '¿La radio lo reprodujo? Dijo estar en reposo de inmediato.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Tienes que grabar las memorias en la propia radio.',
			'settings.radio.voiceMessages.sets' => 'Juego de mensajes',
			'settings.radio.voiceMessages.soundFilesSet' => 'Archivos de sonido en esta computadora',
			'settings.radio.voiceMessages.openFileButton' => 'Abrir archivo',
			'settings.radio.voiceMessages.newSet' => 'Nuevo juego',
			'settings.radio.voiceMessages.renameSet' => 'Renombrar juego',
			'settings.radio.voiceMessages.deleteSet' => 'Eliminar juego',
			'settings.radio.voiceMessages.newSetName' => 'Nombre',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => '¿Eliminar ${name} y sus grabaciones? No se puede deshacer.',
			'settings.radio.voiceMessages.output' => 'Enviar audio a',
			'settings.radio.voiceMessages.input' => 'Grabar desde',
			'settings.radio.voiceMessages.outputRadio' => 'Enviar a la radio por red',
			'settings.radio.voiceMessages.inputDefault' => 'Predeterminado del sistema',
			'settings.radio.voiceMessages.pickDevice' => 'Elegir un dispositivo de sonido',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (no conectado)',
			'settings.radio.voiceMessages.lead' => 'Retardo al pasar a TX',
			'settings.radio.voiceMessages.tail' => 'Retardo al volver a RX',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => 'Escuchar',
			'settings.radio.voiceMessages.notRecorded' => 'Sin grabar',
			'settings.radio.voiceMessages.unplayable' => 'No se puede reproducir este archivo',
			'settings.radio.voiceMessages.problemNoOutput' => 'Elige el dispositivo de sonido que alimenta la radio antes de reproducir un mensaje.',
			'settings.radio.voiceMessages.problemOutputMissing' => 'El dispositivo de sonido que alimenta la radio no está conectado.',
			'settings.radio.voiceMessages.problemInputMissing' => 'El dispositivo de grabación no está conectado.',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'El dispositivo de sonido no se pudo abrir.',
			'settings.radio.voiceMessages.problemNotRecorded' => 'Ese mensaje aún no tiene grabación.',
			'settings.radio.voiceMessages.problemRecordingSilent' => 'No se escuchó nada desde el dispositivo de grabación, así que el mensaje quedó como estaba. Revisa la entrada y que la app tenga permiso para usar el micrófono.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => 'La radio no está tomando audio de la app en este momento. Necesita una conexión de red con la radio.',
			'settings.radio.voiceMessages.problemSourceRefused' => 'La radio no cambió su audio de transmisión a la app, así que el mensaje se detuvo. Configura la radio para transmitir el audio de la app.',
			'settings.radio.voiceMessages.problemCannotKey' => 'Esta radio no puede ponerse en transmisión por CAT, así que la computadora no puede reproducir mensajes a través de ella.',
			'settings.radio.voiceMessages.problemUnplayable' => 'El archivo de ese mensaje no es un archivo de sonido que la app pueda reproducir. Usa un archivo WAV, FLAC o MP3, o grábalo de nuevo.',
			'settings.radio.voiceMessages.problemRecordingFailed' => 'La grabación se cortó, así que el mensaje quedó como estaba. Revisa que el dispositivo de grabación siga conectado y que haya espacio en el disco.',
			'settings.radio.voiceMessages.problemFileFailed' => 'La grabación no se pudo guardar en el lugar del mensaje, así que el mensaje quedó como estaba.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'Ese mensaje necesita palabras que no has grabado: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'La plantilla de ese mensaje tiene un problema: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => 'Los mensajes dichos con tus palabras se reproducen dentro de una operación, donde hay un contacto para el que decirlos.',
			'settings.radio.voiceMessages.problemNothingSaid' => 'Ese mensaje no dice nada para este contacto.',
			'settings.radio.voiceMessages.templateField' => 'Decir con mis palabras',
			'settings.radio.voiceMessages.templateHelp' => 'Déjalo vacío para reproducir la grabación. Si no, el mensaje se dice con las palabras que grabaste, completadas para cada contacto, usando estos valores:',
			'settings.radio.voiceMessages.help' => 'Ayuda',
			'settings.radio.voiceMessages.helpTitle' => 'Decir mensajes con tus palabras',
			'settings.radio.voiceMessages.helpFullExample' => 'Un mensaje completo:',
			'settings.radio.voiceMessages.helpExample' => 'Su indicativo, su reporte y tu grabación de “QSL?”',
			'settings.radio.voiceMessages.playOnRadio' => 'Reproducir en la radio',
			'settings.radio.voiceMessages.templateHelpCall' => 'Su indicativo',
			'settings.radio.voiceMessages.templateHelpReport' => 'El reporte que le das',
			'settings.radio.voiceMessages.templateHelpMessage' => 'La grabación del mensaje 2, reproducida tal como se grabó',
			'settings.radio.voiceMessages.voiced' => 'Dicho con tus palabras',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => 'Dice: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => 'Sin grabar todavía: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => 'Abre una operación para ver qué dirá.',
			'settings.radio.voiceMessages.wordsDescription' => 'Usa tu propia voz para indicativos, números y más.',
			'settings.radio.voiceWords.title' => 'Grabaciones de palabras',
			'settings.radio.voiceWords.callField' => 'Palabras para el operador',
			'settings.radio.voiceWords.intro' => 'Graba cada palabra o número tres veces, seguidas y rápido, como lo dices en un indicativo. Las frases más largas se graban una sola vez.',
			'settings.radio.voiceWords.recordAll' => 'Grabar todo',
			'settings.radio.voiceWords.recordAllGuide' => 'Lee cada palabra tres veces, seguidas, y una frase de varias palabras una sola vez, con una respiración entre líneas. Pulsa Detener después de la última.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => 'Di “${word} ${word} ${word}” y luego pulsa Detener.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => 'Di “${words}” y luego pulsa Detener.',
			'settings.radio.voiceWords.recorded' => 'Grabada',
			'settings.radio.voiceWords.notRecorded' => 'Sin grabar',
			'settings.radio.voiceWords.addPhrase' => 'Agregar frase',
			'settings.radio.voiceWords.phraseField' => 'Frase, tal como la escribes en un mensaje',
			'settings.radio.voiceWords.deletePhrase' => 'Eliminar frase',
			'settings.radio.voiceWords.tryField' => 'Prueba decir',
			'settings.radio.voiceWords.pauseLetters' => 'Pausa entre letras',
			'settings.radio.voiceWords.pauseWords' => 'Pausa entre palabras',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => 'Velocidad',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => 'Configuración avanzada',
			'settings.radio.voiceWords.splitSilent' => 'No se escuchó nada en la grabación.',
			'settings.radio.voiceWords.splitNotThreeTakes' => 'No se encontraron tres tomas. Di la palabra tres veces, seguidas, e inténtalo de nuevo.',
			'settings.radio.voiceWords.splitLineCount' => 'No se encontraron todas las palabras en la lectura. Lee cada una tres veces, con una respiración entre palabras.',
			'settings.radio.voiceWords.splitLinesTooClose' => 'No se pudieron distinguir las palabras. Deja una respiración más larga entre palabras.',
			'settings.radio.avoidZeroBeat.title' => 'Evitar batido cero en los spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Con una radio conectada, sintonizando unos pocos Hz fuera de un spot de CW, para que no todos los que respondan llamen en la misma nota.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Sintonizando exactamente la frecuencia del spot.',
			'settings.radio.zeroBeatRange.title' => 'Batido cero: margen de separación',
			'settings.radio.zeroBeatRange.description' => 'A qué distancia de la frecuencia del spot situarse, a cada lado. El desplazamiento nunca es cercano a cero — eso sería un batido cero otra vez.',
			'settings.help.title' => 'Ayuda y Recursos',
			'settings.help.description' => 'Comunidad y soporte',
			'settings.help.forums' => 'Foros de Ham2K',
			'settings.help.forumsDescription' => 'Encuentra ayuda, danos tu opinión, comparte ideas…',
			'settings.help.chat' => 'Chat de Ham2K',
			'settings.help.chatDescription' => 'El servidor de Discord para nuestra comunidad en línea',
			'settings.help.youtube' => 'Ham2K en YouTube',
			'settings.help.youtubeDescription' => 'Videos y transmisiones en vivo',
			'settings.help.instagram' => 'Ham2K en Instagram',
			'settings.help.instagramDescription' => 'Porque nunca tienes demasiadas fotos…',
			'settings.help.bluesky' => 'Ham2K en BlueSky',
			'settings.help.blueskyDescription' => 'Síguenos para noticias y actualizaciones',
			'settings.help.contact' => 'Contáctanos',
			'settings.help.contactDescription' => 'help@ham2k.com — ¡pero prueba primero los Foros o el Chat!',
			'settings.exports.title' => 'Exportaciones',
			'settings.extensionSections.activities' => 'Actividades',
			'settings.extensionSections.hunting' => 'Cacería',
			'settings.extensionSections.contests' => 'Concursos',
			'settings.extensionSections.lookups' => 'Búsquedas',
			'settings.extensionSections.dashboard' => 'Tablero',
			'settings.map.title' => 'Mapas',
			'settings.map.style.title' => 'Estilo del mapa',
			'settings.map.showCallsigns.title' => 'Mostrar indicativos',
			'settings.map.showCallsigns.description' => 'Cada contacto es una píldora con su indicativo, en el color de su banda',
			'settings.map.showGrayline.title' => 'Mostrar línea gris',
			'settings.map.showGrayline.description' => 'Sombrea el lado nocturno de la Tierra, con el crepúsculo como degradado',
			'settings.map.styleOpts.automatic' => 'Automático',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacidad',
			'settings.privacy.shareAppData.title' => 'Compartir datos de uso de la aplicación',
			'settings.privacy.shareAppData.descriptionOn' => 'Ayudándonos a mejorar la app compartiendo datos de uso, configuración, fallos y rendimiento',
			'settings.privacy.shareAppData.descriptionOff' => 'Manteniendo privados los datos de uso de la aplicación.\nEl equipo de Ham2K no podrá detectar fallos u otros problemas.',
			'settings.privacy.shareOpData.title' => 'Compartir datos de operación',
			'settings.privacy.shareOpData.descriptionOn' => 'Compartiendo algunos datos de operación de forma pública y con otros usuarios',
			'settings.privacy.shareOpData.descriptionOff' => 'Manteniendo privados los datos de operación',
			'settings.privacy.privacyPolicy' => 'Política de Privacidad',
			'settings.privacy.termsOfService' => 'Términos de Servicio',
			'settings.operatorCall' => 'Indicativo del Operador',
			'settings.sync.title' => 'Sincronización en la nube',
			'settings.sync.moreSettings' => 'Más opciones de sincronización',
			'settings.sync.enable' => 'Habilitar sincronización',
			'settings.sync.deviceKey' => 'Clave del dispositivo',
			'settings.peers.title' => 'Dispositivos cercanos',
			'settings.peers.enable' => 'Conectar con otros dispositivos',
			'settings.peers.enableDescription' => 'Permite compartir operaciones, logging, CAT y GPS con otros dispositivos por la red local',
			'settings.peers.bleEnable' => 'Conectar por Bluetooth',
			'settings.peers.bleDescription' => 'Usa Bluetooth LE para conectar aunque no haya red local',
			'settings.peers.thisDevice' => 'Este Dispositivo',
			'settings.peers.deviceName' => 'Nombre',
			'settings.peers.deviceNameHint' => 'Cómo ven este dispositivo los demás',
			'settings.peers.pairedDevices' => 'Dispositivos vinculados',
			'settings.peers.noPairedDevices' => 'Todavía no hay dispositivos vinculados. Activa esto en otro dispositivo de esta red para vincularlos.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'No se pueden leer tus dispositivos vinculados: ${error}',
			'settings.peers.nearby' => 'Cercano',
			'settings.peers.connected' => 'Conectado',
			'settings.peers.viaBluetooth' => 'vía Bluetooth',
			'settings.peers.connecting' => 'Conectando…',
			'settings.peers.syncing' => 'Sincronizando…',
			'settings.peers.waitingForThem' => 'Esperando al otro dispositivo',
			'settings.peers.notConnected' => 'No conectado',
			'settings.peers.wantsToPair' => 'quiere compartir esta operación',
			'settings.peers.allow' => 'Permitir',
			'settings.peers.link' => 'Vincular',
			'settings.peers.reject' => 'Rechazar',
			'settings.peers.forget' => 'Olvidar',
			'settings.peers.forgetTitle' => ({required Object name}) => '¿Olvidar ${name}?',
			'settings.peers.forgetBody' => 'Dejará de sincronizarse con este dispositivo. Puedes autorizarlo de nuevo más tarde, y los contactos ya registrados se conservan.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Vincular con ${name}',
			'settings.peers.pairBody' => 'Este dispositivo está en tu red local y quiere conectarse.',
			'settings.peers.pairBodyBle' => 'Este dispositivo está cerca y quiere conectarse por Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID del dispositivo',
			'settings.peers.pairWarning' => 'Vincula solo dispositivos que reconozcas. Cualquier dispositivo de esta red puede enviar una solicitud.',
			'settings.peers.pairWarningBle' => 'Vincula solo dispositivos que reconozcas. Cualquier dispositivo cercano puede enviar una solicitud.',
			'settings.peers.problem' => ({required Object error}) => 'No se puede acceder a la red local: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Conectado a ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Se perdió la conexión con ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispositivos cercanos: ${connected} de ${linked} conectados',
			'settings.peers.screenEnable' => 'Compartir pantallas y ventanas',
			'settings.peers.screenDescription' => 'Permite que otros dispositivos muestren pantallas o ventanas de esta computadora',
			'settings.peers.screenSources' => 'Pantallas y ventanas',
			'settings.peers.screenRefresh' => 'Actualizar la lista',
			'settings.peers.screenUnsupportedPlatform' => 'Este dispositivo no puede compartir su pantalla. macOS sí puede; cualquier dispositivo puede mostrar una pantalla compartida por otro.',
			'settings.peers.screenUnsupportedVersion' => 'Compartir la pantalla necesita macOS 12.3 o posterior. Este dispositivo sí puede mostrar una pantalla compartida por otro.',
			'settings.peers.screenNeedsPermission' => 'macOS necesita tu permiso para grabar la pantalla antes de que esta app pueda compartir una.',
			'settings.peers.screenGrantPermission' => 'Pedir permiso',
			'settings.peers.screenRelaunchAfterGranting' => 'Permítelo en Configuración del Sistema, en Privacidad y seguridad → Grabación de pantalla, y luego cierra y vuelve a abrir esta app — macOS solo le avisa a la app del cambio en el siguiente arranque.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Compartir pantalla: ${error}',
			'settings.peers.screenChooseTitle' => 'Elegir qué compartir',
			'settings.peers.screenChooseButton' => 'Elegir qué compartir…',
			'settings.peers.screenTabScreens' => 'Pantallas',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Ventanas',
			'settings.peers.screenTabEmpty' => 'No se encontró nada de este tipo.',
			'settings.peers.screenSharedSummaryNone' => 'No has elegido nada todavía.',
			'settings.peers.screenThisDevice' => 'Este dispositivo',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Se muestra en ${devices}',
			'settings.peers.screenSharedToNobody' => 'No se está mostrando',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Dejar de compartir ${name}',
			'settings.developerMode' => 'Modo Desarrollador',
			'settings.syncPanel.configuration' => 'Configuración de sincronización',
			'settings.syncPanel.enableTitle' => 'Sincronizar con Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Respaldando y sincronizando tu log entre dispositivos',
			'settings.syncPanel.disabledDescription' => 'Apagado — se queda solo en este dispositivo',
			'settings.syncPanel.syncing' => 'Sincronizando',
			'settings.syncPanel.account' => 'Cuenta',
			'settings.syncPanel.refresh' => 'Actualizar',
			'settings.syncPanel.switchAccounts' => 'Cambiar de cuenta',
			'settings.syncPanel.switchAccountsDescription' => 'Vincula este dispositivo a otra cuenta con un código QR o por correo electrónico',
			'settings.syncPanel.connectionRequests' => 'Solicitudes de conexión',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Un dispositivo espera unirse a esta cuenta', other: '${n} dispositivos esperan unirse a esta cuenta', ), 
			'settings.syncPanel.accountEmailTitle' => 'Correo electrónico de la cuenta',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmación enviada a ${email}. Abre el enlace allí para completar el cambio.',
			'settings.syncPanel.resendConfirmation' => 'Reenviar correo de confirmación',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Esperando a ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Enviado de nuevo a ${email}.',
			'settings.syncPanel.deviceLinked' => 'Ese dispositivo ya está vinculado a esta cuenta.',
			'settings.syncPanel.checking' => 'Comprobando…',
			'settings.syncPanel.notLinked' => 'Aún no vinculado',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => '¿Reemplazar los datos locales?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} operación', other: '${n} operaciones', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Datos sincronizados',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Pendiente de subir: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Este dispositivo: comprobando…',
			'settings.syncPanel.countsServerChecking' => 'Servidor: comprobando…',
			'settings.syncPanel.countsServerUnavailable' => 'Servidor: no disponible',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Esto respalda y borra ${operations} y ${qsos} de este dispositivo, y luego descarga los datos de la cuenta en su lugar. El respaldo se conserva en la base de datos de este dispositivo.',
			'settings.syncPanel.replace' => 'Reemplazar',
			'settings.syncPanel.pendingBannerTitle' => 'Nueva cuenta de Ham2K Log Filer detectada',
			'settings.syncPanel.pendingBannerBody' => 'Conserva las operaciones y QSOs existentes en este dispositivo y combínalos con la cuenta, o reemplázalos con los datos de la cuenta (en ambos casos queda un respaldo en este dispositivo).',
			'settings.syncPanel.combine' => 'Combinar',
			'settings.syncPanel.authIssueTitle' => 'La sincronización no puede conectarse',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer sigue rechazando este dispositivo. Revisa tu indicativo en la configuración de sincronización.',
			'settings.syncPanel.openSettings' => 'Abrir configuración de sincronización',
			'settings.accounts.title' => 'Cuentas, Servicios y Fuentes de Datos',
			'settings.accounts.none' => 'No hay extensiones activas con cuentas',
			'settings.accounts.notConfigured' => 'Sin configurar',
			'settings.accounts.connected' => 'Conectado',
			'settings.accounts.cancelLogin' => 'Cancelar el inicio de sesión',
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
			'settings.accounts.lookupFailed' => 'Las cuentas no están disponibles ahora mismo — inténtalo de nuevo en un momento',
			'settings.accounts.browserLoginTitle' => 'Termina de iniciar sesión con tu navegador',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Cuando termines, el navegador intentará abrir un enlace que empieza con "${prefix}". Es muy probable que tu escritorio no tenga nada registrado para abrirlo, así que copia ese enlace (de la barra de direcciones o de la página de error del navegador) y pégalo aquí.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger no pudo abrir tu navegador. Copia el enlace de inicio de sesión y ábrelo tú mismo; luego copia el enlace al que te envíe (empieza con "${prefix}") y pégalo aquí.',
			'settings.accounts.copyLoginLink' => 'Copiar enlace de inicio de sesión',
			'settings.accounts.pastedLinkLabel' => 'Pega el enlace aquí',
			'settings.accounts.finishLogin' => 'Terminar inicio de sesión',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Ese no es el enlace de inicio de sesión — debe empezar con "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Ese enlace pertenece a otro intento de inicio de sesión. Cierra esta página y conéctate de nuevo.',
			'settings.accounts.pastedLinkNoCode' => 'Ese enlace no tiene ningún código de inicio de sesión. Termina de iniciar sesión y luego copia el enlace al que te envíe.',
			'settings.accounts.pastedLinkMalformed' => 'Ese enlace parece estar incompleto. Cópialo por completo y pégalo de nuevo.',
			'settings.accounts.relayLoginWaiting' => 'Esperando a que termines de iniciar sesión — esto continuará automáticamente en cuanto lo hagas.',
			'settings.accounts.loginNoResponse' => 'Este dispositivo aún no ha recibido respuesta del inicio de sesión. Si ya terminaste en tu navegador, cancela e intenta conectarte de nuevo.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger no pudo abrir tu navegador automáticamente. Usa el botón de abajo para abrir la página de inicio de sesión tú mismo.',
			'settings.accounts.relayLoginUnavailable' => 'No se pudo conectar con el servidor de sincronización necesario para completar este inicio de sesión. Revisa tu conexión e inténtalo de nuevo.',
			'settings.accounts.loginIncompleteResponse' => 'Ese intento de inicio de sesión no se completó correctamente. Vuelve a intentar conectarte.',
			'settings.accounts.noKeyringTitle' => 'No se pueden guardar las credenciales de las cuentas',
			'settings.accounts.noKeyringText' => 'Ham2K Logger no puede acceder a un servicio de llavero en esta computadora, así que no puede guardar ni leer las credenciales de las cuentas — conectar una cuenta fallará hasta que lo resuelvas. Instala y arranca **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloquea el llavero que ya tengas, y reinicia. El logging, las exportaciones y los archivos de datos no se ven afectados; la sincronización del log queda apagada mientras tanto.',
			'settings.accounts.noKeyringInline' => 'Las credenciales no se pueden guardar: no se puede acceder al llavero de esta computadora. Instala y arranca gnome-keyring, KWallet o KeePassXC, o desbloquea el que ya tengas.',
			'settings.accounts.noSecureStorageInline' => 'Las credenciales no se pueden guardar: no se puede acceder al almacenamiento seguro de esta computadora.',
			'settings.station.title' => 'Configuración de Estación y Control CAT',
			'settings.station.none' => 'No hay equipo configurado',
			'settings.station.add' => 'Agregar',
			'settings.station.addTitle' => 'Agregar equipo',
			'settings.station.searchHint' => 'Buscar equipos',
			'settings.station.noMatches' => 'Ningún equipo coincide',
			'settings.station.detectedEquipment' => 'Equipos detectados',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'No se puede buscar radios: ${error}',
			'settings.station.edit' => 'Editar equipo',
			'settings.station.name' => 'Nombre',
			'settings.station.nameDescription' => 'Cómo lo llamas — "Radio Izquierda". Opcional.',
			'settings.station.transport' => 'Conexión',
			'settings.station.host' => 'Dirección',
			'settings.station.hostDescription' => 'El nombre de host o la dirección IP de la radio en tu red.',
			'settings.station.port' => 'Puerto',
			'settings.station.hostRequired' => 'Se requiere una dirección',
			'settings.station.portInvalid' => 'El puerto debe estar entre 1 y 65535',
			'settings.station.connect' => 'Conectar',
			'settings.station.disconnect' => 'Desconectar',
			'settings.station.remove' => 'Quitar',
			'settings.station.removeTitle' => ({required Object name}) => '¿Quitar ${name}?',
			'settings.station.removeMessage' => 'Esto solo lo quita de la app. La configuración del equipo no cambia.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipo de equipo no reconocido "${typeKey}"',
			'settings.station.report' => 'Informar',
			'settings.station.reportTitle' => 'Informar sobre esta radio',
			'settings.station.reportIntro' => 'Cuéntanos qué radio es realmente y qué tal fue. Tu informe se convierte en una ficha que lee el equipo de Ham2K, y lo que escribas sobre cómo hacerla funcionar puede acabar ayudando al siguiente operador con la misma radio.',
			'settings.station.reportManufacturer' => 'Fabricante',
			'settings.station.reportManufacturerDescription' => 'Quién la fabrica — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Hace falta un fabricante',
			'settings.station.reportModel' => 'Modelo',
			'settings.station.reportModelDescription' => 'El modelo, tal como lo llama la propia radio — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'Hace falta un modelo',
			'settings.station.reportOutcome' => '¿Qué tal fue?',
			'settings.station.reportOutcomeWorks' => 'Funcionó bien',
			'settings.station.reportOutcomeIssues' => 'Funcionó, con problemas',
			'settings.station.reportOutcomeFails' => 'No funcionó en absoluto',
			'settings.station.reportOutcomeRequired' => 'Cuéntanos qué tal fue',
			'settings.station.reportComments' => 'Comentarios',
			'settings.station.reportCommentsPlaceholder' => 'Qué funcionó, qué no, y cualquier cosa que te sorprendiera.',
			'settings.station.reportHints' => 'Consejos para solucionar problemas',
			'settings.station.reportHintsPlaceholder' => '¿Quieres sugerir consejos para que otros usuarios solucionen problemas?',
			'settings.station.reportSend' => 'Enviar informe',
			'settings.station.reportSending' => 'Enviando tu informe…',
			'settings.station.reportSent' => ({required Object ref}) => 'Gracias — tu informe se archivó como ${ref}.',
			'settings.station.reportSentNoRef' => 'Gracias — tu informe se envió.',
			'settings.station.reportFailed' => ({required Object error}) => 'El informe no se envió: ${error}',
			'settings.station.troubleshootingNotes' => 'Notas de resolución de problemas',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Usar como VFO principal',
			'settings.station.serialPort' => 'Puerto serie',
			'settings.station.serialPortDescription' => 'El puerto donde aparece la interfaz CAT de la radio.',
			'settings.station.serialPortNone' => 'No se encontraron puertos serie',
			'settings.station.serialPortRequired' => 'Elige un puerto serie',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'puerto ${n} de ${total}',
			'settings.station.serialPortSuggested' => 'sugerido',
			'settings.station.serialPortJustNow' => 'Conectado recientemente',
			'settings.station.serialPortNoDriver' => 'sin controlador',
			'settings.station.serialDeviceRequest' => 'Agregar un dispositivo USB…',
			'settings.station.bleDevice' => 'Dispositivo Bluetooth LE',
			'settings.station.bleDeviceDescription' => 'El puente serie a través del cual se conecta tu radio, como un LiNK500MP en Modo 4 o un adaptador serie BLE.',
			'settings.station.bleScan' => 'Buscar dispositivos Bluetooth LE…',
			'settings.station.bleScanNoneFound' => 'No se encontraron dispositivos Bluetooth LE. Comprueba que el puente esté encendido, cerca y en su modo Bluetooth LE (Modo 4 en un LiNK500MP).',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'No se pudo ejecutar la búsqueda Bluetooth LE: ${reason}',
			'settings.station.bleOff' => 'El Bluetooth está apagado.',
			'settings.station.bleDenied' => 'No se concedió el permiso de Bluetooth. Permítelo en la configuración del sistema e inténtalo de nuevo.',
			'settings.station.bleUnsupported' => 'Este dispositivo no tiene Bluetooth LE.',
			'settings.station.bleStarting' => 'El Bluetooth todavía está iniciándose. Inténtalo de nuevo en un momento.',
			'settings.station.bleConnectFailed' => 'No se puede acceder al dispositivo Bluetooth LE. Comprueba que esté encendido, cerca y no conectado a otra app.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'Este dispositivo Bluetooth LE no tiene ningún servicio serie que la app reconozca. Por favor, repórtalo con sus servicios: ${services}',
			'settings.station.baudRate' => 'Velocidad (baudios)',
			'settings.station.baudRateDescription' => 'Debe coincidir con el menú CAT de la radio. Si no, la radio devuelve datos ilegibles y ningún error.',
			'settings.station.serialRtsHigh' => 'Mantener RTS en alto',
			'settings.station.serialRtsHighDescription' => 'Solo para una radio que espera RTS antes de responder, como una Yaesu con CAT RTS activado. En un Digirig, un SignaLink y la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto transmite.',
			'settings.station.serialDtrHigh' => 'Mantener DTR en alto',
			'settings.station.serialDtrHighDescription' => 'Solo para una interfaz CAT que se alimenta de DTR, como algunos cables RS-232 para el FT-817. En muchos cables DTR manipula CW o PTT, y mantenerlo en alto transmite.',
			'settings.station.serialUsbDriver' => 'Controlador del chip USB',
			'settings.station.serialUsbDriverDescription' => 'Automático reconoce la mayoría de los adaptadores. Elige el chip solo para uno que la lista de puertos indique sin controlador — su empaque o una lista de dispositivos USB lo nombra.',
			'settings.station.serialUsbDriverAuto' => 'Automático',
			'settings.station.civAddress' => 'Dirección CI-V de la radio',
			'settings.station.civAddressDescription' => 'Hexadecimal, como aparece en el menú CI-V de la radio. El IC-705 viene con A4.',
			'settings.station.civAddressInvalid' => 'Una dirección CI-V son dos dígitos hexadecimales, de 01 a FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Cuál de los slices de la radio lee y sintoniza esta conexión.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Elige uno de los slices de la radio, de la A a la H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'El slice ${letter} no está en uso en esta radio — elige otro, o créalo en SmartSDR',
			'settings.station.channelNotInUse' => 'sin usar',
			'settings.station.channelHeldByUnknown' => 'en uso por otro programa',
			'settings.station.flexNoSlices' => 'Esta radio no ha informado de ningún slice — comprueba que SmartSDR esté activo y que este cliente pueda suscribirse',
			'settings.station.spectrumUnsupported' => 'Esta radio no envía su espectro por CAT',
			'settings.station.spectrumRequiresBaud' => 'Requiere CAT a 115200 bps',
			'settings.station.spectrumNoRadio' => 'No hay ninguna radio conectada',
			'settings.station.spectrumWaiting' => 'Esperando el espectro de la radio…',
			'settings.station.spectrumUnavailable' => 'La visualización del espectro no está disponible',
			'settings.station.spectrumNoDaxChannel' => 'Todos los canales DAX IQ de esta radio están en uso',
			'settings.station.spectrumNoPanadapter' => 'Este slice no tiene panadaptador en la radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'La radio rechazó un flujo DAX IQ (error ${code})',
			'settings.station.spectrumNoUdp' => 'Los datos del espectro de la radio no llegan a este dispositivo',
			'settings.station.spectrumK4Unavailable' => 'No se puede recibir el espectro LAN del K4. Reintentando…',
			'settings.station.spectrumK4RemoteUnavailable' => 'No se puede recibir el espectro remoto del K4',
			'settings.station.spectrumScopeRefused' => 'La radio rechazó los comandos de su espectro',
			'settings.station.spectrumOutOfRange' => 'El espectro de la radio está fuera del rango que puede mostrar',
			'settings.station.spectrumBandUnsupported' => 'El espectro de la radio no se puede mostrar en esta banda',
			'settings.station.spectrumSdrNoRadio' => 'Esperando la frecuencia de la radio vinculada…',
			'settings.station.spectrumSdrNotConnected' => 'El SDR no está conectado',
			'settings.station.spectrumSdrNoIf' => 'Establece la frecuencia de FI de la radio en la configuración de este SDR',
			'settings.station.sdrRadio' => 'Muestra el espectro de',
			'settings.station.sdrRadioDescription' => 'Una visualización de espectro en esta radio toma los datos de este receptor en lugar del espectro propio de la radio.',
			'settings.station.sdrRadioMain' => 'La radio principal',
			'settings.station.sdrTuning' => 'Entrada de antena',
			'settings.station.sdrTuningDescription' => 'De dónde viene la señal del receptor. Con su propia antena se sintoniza solo para seguir a la radio; en la salida de FI de la radio se queda en la FI.',
			'settings.station.sdrTuningIndependent' => 'Su propia antena',
			'settings.station.sdrTuningIfTap' => 'La salida de FI de la radio',
			'settings.station.sdrIfHz' => 'Frecuencia de FI (Hz)',
			'settings.station.sdrIfHzDescription' => 'Solo para una salida de FI: la frecuencia a la que queda el dial de la radio en su FI, como 68330000 en un FT-817.',
			'settings.station.sdrIfInverted' => 'La FI está invertida',
			'settings.station.sdrGainDb' => 'Ganancia (dB)',
			'settings.station.sdrGainDbDescription' => 'Déjalo en blanco para la ganancia automática del receptor.',
			'settings.station.sdrOffsetHz' => 'Desplazamiento de frecuencia (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'Se suma a cada frecuencia enviada al receptor, para un upconverter: 125000000 para un Ham It Up.',
			'settings.station.sdrPpm' => 'Corrección de frecuencia (ppm)',
			'settings.station.rtlDirectSampling' => 'Muestreo directo',
			'settings.station.rtlDirectSamplingDescription' => 'Para HF en un RTL-SDR V3 sin upconverter. Un RTL-SDR V4 llega a HF sin él.',
			'settings.station.rtlDirectSamplingOff' => 'Apagado',
			'settings.station.rtlDirectSamplingI' => 'Rama I',
			'settings.station.rtlDirectSamplingQ' => 'Rama Q',
			'settings.station.rtlTcpNotAServer' => 'Esto no es un servidor rtl_tcp',
			'settings.station.rtlTcpNotes' => 'Esto se conecta a un **servidor rtl_tcp que ejecutas tú mismo** en la computadora donde está enchufado el dongle.\n\n- **Inícialo** con `rtl_tcp -a 0.0.0.0` para que otras máquinas puedan acceder; en la misma máquina basta con `rtl_tcp`.\n- **El puerto** es 1234 salvo que lo hayas iniciado con `-p`.\n- **Un programa a la vez:** rtl_tcp atiende a un solo cliente. La app se conecta solo mientras se muestra una visualización de espectro, y lo suelta unos segundos después de cerrarla.\n- **En Android**, la app *SDR driver* ejecuta el mismo servidor en el teléfono.',
			'settings.station.rspTcpNotes' => 'Esto se conecta a un **servidor rsp_tcp que ejecutas tú mismo** en la computadora donde está enchufado el RSP, con la API de SDRplay instalada allí.\n\n- **Inícialo** con `rsp_tcp -a 0.0.0.0`.\n- **El puerto** es 1234 salvo que lo hayas iniciado con `-p`.\n- **Un programa a la vez:** el servidor acepta un solo cliente. La app se conecta solo mientras se muestra una visualización de espectro.',
			'settings.station.n3fjpNoRig' => 'N3FJP no tiene configurada una interfaz de radio, así que esto sigue lo que se escribe en N3FJP, no una radio',
			'settings.station.winkeyerKeyPort' => 'Salida de manipulación',
			'settings.station.winkeyerKeyPortDescription' => 'En cuál de los dos conectores de salida del manipulador está enchufada tu radio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Puerto ${n}',
			'settings.station.winkeyerPtt' => 'Usar el PTT del manipulador',
			'settings.station.winkeyerPttDescription' => 'Activa la línea PTT del mismo conector, para un amplificador o una radio que lo necesite. Déjalo desactivado para una radio manipulada por su conector de manipulación.',
			'settings.station.winkeyerNoAnswer' => 'Ningún WinKeyer respondió en este puerto',
			'settings.station.winkeyerStoppedAnswering' => 'El WinKeyer dejó de responder mientras enviaba; el mensaje se descartó',
			'settings.station.icomControlPort' => 'Puerto de control (UDP)',
			'settings.station.icomControlPortDescription' => 'El Control Port (UDP) de la radio — 50001 salvo que lo hayas cambiado en su configuración de red, o redirigido a otro.',
			'settings.station.icomSerialPort' => 'Puerto serie (UDP)',
			'settings.station.icomSerialPortDescription' => 'El Serial Port (UDP) de la radio — 50002 salvo que lo hayas cambiado en su configuración de red, o redirigido a otro.',
			'settings.station.icomPortsDiffer' => 'Los puertos de control y serie deben ser distintos',
			'settings.station.radioUser' => 'Usuario de la radio',
			'settings.station.radioPass' => 'Contraseña de la radio',
			'settings.station.radioLoginDescription' => 'El inicio de sesión Red → Remoto de la radio, no la contraseña del WiFi.',
			'settings.station.radioUserRequired' => 'Se requiere el usuario de control remoto de la radio',
			'settings.station.connectFailedBusy' => 'Dispositivo en uso',
			'settings.station.connectFailedDenied' => 'Acceso denegado',
			'settings.station.connectFailedDevice' => 'Dispositivo no encontrado',
			'settings.station.connectFailedUnsupported' => 'Ningún controlador reconoce el chip de este adaptador USB. Si sabes cuál es, elígelo en Controlador del chip USB, en Configuración avanzada.',
			'settings.station.connectFailedLines' => 'No se pudieron mantener RTS/DTR como están configurados, así que se cerró el puerto. Puede que otro programa haya dejado activado el handshake por hardware — desconecta y vuelve a conectar el cable.',
			'settings.station.connectFailedNetwork' => 'No se encuentra la radio en la red. Comprueba su dirección y que esté encendida y accesible.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'El puerto ${port} de este dispositivo ya está en uso, y las respuestas llegan ahí. Cierra lo que esté escuchando en él — incluido otro nodo de PstRotator — o cambia el puerto.',
			'settings.station.connectFailedTimeout' => 'La radio no respondió a tiempo. Comprueba que esté encendida y accesible.',
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
			'settings.station.models.ftdx3000' => 'Yaesu FTDX3000',
			'settings.station.models.ft950' => 'Yaesu FT-950',
			'settings.station.models.ftdx1200' => 'Yaesu FTDX1200',
			'settings.station.models.ft2000' => 'Yaesu FT-2000 / FT-2000D',
			'settings.station.models.ftdx5000' => 'Yaesu FTDX5000',
			'settings.station.models.q900' => 'Guohetec Q900',
			'settings.station.models.tenTecEagle' => 'Ten-Tec Eagle (599)',
			'settings.station.models.tenTecOrion' => 'Ten-Tec Orion (565)',
			'settings.station.models.tenTecOrionII' => 'Ten-Tec Orion II (566)',
			'settings.station.models.sotacat' => 'SOTAcat (Elecraft KX2/KX3)',
			'settings.station.models.yaesuGeneric' => 'Yaesu - Genérico',
			'settings.station.models.icomGeneric' => 'Icom - Genérico',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Genérico',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Genérico',
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
			'settings.station.models.rigctld' => 'Radio controlada vía rigctld',
			'settings.station.models.rigctldNodeName' => 'Mi radio (vía rigctld)',
			'settings.station.models.flrig' => 'Radio controlada vía flrig',
			'settings.station.models.flrigNodeName' => 'Mi radio (vía flrig)',
			'settings.station.models.hrd' => 'Radio controlada vía Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Mi radio (vía HRD)',
			'settings.station.models.n3fjp' => 'Radio controlada vía N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Mi radio (vía N3FJP)',
			'settings.station.models.commander' => 'Radio controlada vía DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Mi radio (vía Commander)',
			'settings.station.models.antenna' => 'Antena',
			'settings.station.models.key' => 'Manipulador',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Radio genérica (provisional)',
			'settings.station.models.placeholderRadioNodeName' => 'Mi radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Conmutador coaxial Sierra Radio CX-1',
			'settings.station.models.gs232a' => 'Interfaz de rotor Yaesu GS-232A',
			'settings.station.models.pstRotator' => 'PstRotator (control UDP)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Red/WiFi',
			'settings.station.transports.secureNetwork' => 'Red/WiFi segura',
			'settings.station.transports.usbSerial' => 'Serie USB',
			'settings.station.transports.wifi' => 'Red/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Serie Bluetooth',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Provisional',
			'settings.station.troubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.ft891Troubleshooting' => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS apagado en la radio, o Mantener RTS en alto activado.** Con **CAT RTS** activado (menú **05-08** del FT-891), la radio se queda en silencio mientras RTS está bajo — puede responder una vez al abrirse el puerto, y luego nada. Al elegir el puerto USB propio de la radio se activa **Mantener RTS en alto** en Configuración avanzada. En un Digirig, un SignaLink o la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto pone tu transmisor en el aire: en ese caso, apaga CAT RTS en la radio.\n- **La velocidad debe coincidir** con el CAT RATE de la radio (menú **05-06**). Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.yaesuBinaryTroubleshooting' => 'Esta radio habla el CAT antiguo de Yaesu, de cinco bytes, y no responde en absoluto cuando algo no encaja. Casi siempre es una de estas:\n\n- **El cable tiene que convertir niveles.** El conector CAT de la parte trasera no es RS-232 ni USB: necesita un CT-62 o un adaptador equivalente. Un cable de audio o de datos común no sirve para CAT.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio (**#14** en un FT-817, **#19** en un FT-857 o un FT-897). Si no coincide, la radio no devuelve nada, y nunca un error.\n- **Nunca dejes que nada active RTS ni DTR en este puerto.** En la mayoría de los cables para estas radios esas líneas son el PTT y la manipulación. La excepción es una interfaz antigua alimentada por DTR: para esa, activa **Mantener DTR en alto** en Configuración avanzada.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEste controlador se escribió a partir de la tabla CAT publicada por Yaesu y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.tenTecTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.tenTecEagleTroubleshooting' => '- **El puerto USB-B de la parte trasera es el enlace CAT.** La radio aparece como un puerto serie USB; en Windows necesita el controlador USB a UART de Ten-Tec, que aparece en el Administrador de dispositivos como "USB to UART (COMx)".\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto, y también el actualizador de firmware de Ten-Tec.\n- **Ajustar el ancho del filtro desde la app se lo quita a la perilla BW** hasta apagar y encender la radio. Así funciona la radio.\n\nEste controlador se escribió a partir de la guía de referencia del programador de Ten-Tec. Si funciona a medias, vale la pena reportarlo, con la versión de firmware del menú de la radio.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Usa un cable serie DB-9 directo** al puerto SERIAL DATA, no uno null-modem.\n- **Esta entrada mantiene RTS en alto**, porque el Orion usa RTS y CTS como handshake. En una interfaz que activa el PTT desde RTS, como un Digirig, desactiva Mantener RTS en alto en Configuración avanzada, o la radio transmitirá en cuanto la app se conecte.\n- **El CW desde la app necesita el manipulador interno de la radio encendido.** Con él apagado, la radio ignora lo que envía la app.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEste controlador se escribió a partir de la guía de referencia del programador de Ten-Tec y no se ha probado con un Orion. Si funciona a medias, vale la pena reportarlo, con la versión de firmware del menú de la radio.',
			'settings.station.tenTecNoCw' => 'El firmware de esta radio no acepta CW desde la app. Ten-Tec lo agregó en el firmware 1.366 del Orion.',
			'settings.station.tenTecKeyerOff' => 'El manipulador interno de la radio está apagado, así que ignora el CW enviado desde la app. Enciende el manipulador en el menú de la radio.',
			'settings.station.guohetecTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.guohetecTroubleshooting' => 'El Q900 tiene dos protocolos CAT, y esta entrada usa el nativo en lugar de la imitación del FT-817. Elige **Guohetec Q900** aquí, no un FT-817 — la imitación admite menos comandos, y la radio no dice cuál de los dos está usando.\n\n- **El cable USB-C es el enlace CAT**, y también conecta la tarjeta de sonido. La velocidad no importa en él; el puerto ignora la que se le configure.\n- **Nunca dejes que nada active RTS ni DTR en este puerto.** En un cable serie esas líneas son el PTT y la manipulación.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Una radio de segunda generación se comporta distinto** de una de primera. Mantén pulsado Menu y luego About: HW 2.0 es la segunda generación.\n\nEste controlador se escribió a partir del protocolo publicado por el fabricante y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.yaesuTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.yaesuTroubleshooting' => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **CAT RTS debe estar en OFF en la radio.** Con esa opción activada, la radio espera una línea de handshake que la app mantiene baja. En un Digirig, un SignaLink o la mayoría de los cables caseros esa misma línea es el PTT, así que activarla pondría tu transmisor en el aire. En el puerto USB propio de la radio, **Mantener RTS en alto** en Configuración avanzada es la alternativa. Dónde está esa opción depende del modelo (menú **05-08** en un FT-891).\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Los modos siguen la tabla del FT-891.** Casi toda la línea Yaesu coincide, pero una radio que numere sus modos de otra forma mostrará y ajustará el modo equivocado en esos casos. La frecuencia no se ve afectada.',
			'settings.station.ftdx3000Troubleshooting' => '**El menú 037 CAT SELECT debe estar en USB** para CAT por el puerto USB de la radio; en RS232C, el CAT está en el conector de la parte trasera.\n\nEsta entrada se escribió a partir de la documentación CAT publicada y no se ha probado con un FTDX3000. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.yaesuRs232Troubleshooting' => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **El conector CAT es RS-232.** Necesita un adaptador USB a serie y un cable DB-9 directo — un cable null-modem cruza las líneas y la radio no oye nada.\n- **CAT RTS debe estar en OFF en la radio.** Con esa opción activada, la radio espera una línea de handshake que la app mantiene baja, salvo que **Mantener RTS en alto** esté activado en Configuración avanzada.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\nEsta entrada se escribió a partir de la documentación CAT publicada y no se ha probado con una de estas radios. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.yaesuUsbTroubleshooting' => 'La radio recibe los comandos pero no responde. Casi siempre es una de estas:\n\n- **Usa el primero de los dos puertos USB de la radio.** El CAT suele estar en el primero (el puerto COM **Enhanced** en Windows); el segundo (**Standard**) es para PTT y manipulación. El selector señala el primero siempre que puede distinguirlos.\n- **CAT RTS apagado en la radio, o Mantener RTS en alto activado.** Con el menú **CAT RTS** de la radio activado, se queda en silencio mientras RTS está bajo — puede responder una vez al abrirse el puerto, y luego nada. Al elegir el puerto USB propio de la radio se activa **Mantener RTS en alto** en Configuración avanzada. En un Digirig, un SignaLink o la mayoría de los cables caseros RTS es el PTT, y mantenerlo en alto pone tu transmisor en el aire: en ese caso, apaga CAT RTS en la radio.\n- **La velocidad debe coincidir** con el menú CAT RATE de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.',
			'settings.station.k4SerialNotes' => 'Conecta el puerto USB-B (PC) trasero del K4. Tanto USB-PC1 como USB-PC2 sirven para CAT; elige un puerto libre e iguala su ajuste Serial USB-PCn: Baud Rate en la radio. HaLo propone 38400; cámbialo si hace falta. Otra app debe usar el otro puerto o Ethernet.\n\nEsta conexión controla la radio y sus manipuladores; no envía audio a HaLo.',
			'settings.station.k4TcpNotes' => 'Conecta el puerto Ethernet del K4 a tu red local. Ingresa su nombre de host o dirección IP y el puerto CAT 9200. HaLo usa el mismo host en el puerto fijo 9201 cuando hay un panadaptador o una cascada visible; cambiar el puerto CAT no cambia el puerto del espectro.\n\nEl espectro muestra el receptor principal. Sus controles de zoom, ajuste de referencia y velocidad afectan solo a la visualización de HaLo. La transmisión de audio no está soportada.',
			'settings.station.k4PowerTimeout' => 'No se cambió la potencia del K4 porque la radio no confirmó su rango de salida. Inténtalo de nuevo.',
			'settings.station.k4RemoteNotes' => 'Habilita el acceso remoto en tu K4 e ingresa su contraseña de red. Main y Sub comparten una sola conexión cifrada para el control de la radio y el espectro. El puerto por defecto es 9204; ingresa tu puerto redirigido al conectarte de forma remota.\n\nLa reproducción de audio y la transmisión del micrófono no están soportadas.',
			'settings.station.k4Receiver' => 'Receptor',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Elige Main o Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'Ese receptor ya está configurado para este K4',
			'settings.station.k4SubReceiverOff' => 'El receptor Sub del K4 está apagado',
			'settings.station.k4RemotePasswordRequired' => 'Ingresa la contraseña de red del K4 para conectarte de forma segura.',
			'settings.station.k4RemoteHandshakeFailed' => 'El K4 no pudo establecer una conexión segura. Revisa su contraseña de red y la configuración de acceso remoto.',
			'settings.station.k4RemoteUnreachable' => 'No se pudo acceder a la conexión segura del K4. Revisa su dirección, puerto y configuración de acceso remoto.',
			'settings.station.k4PowerRange' => 'La potencia del K4 debe ser de 0.1–110 W, o de 0.0001–0.01 W cuando está activa la salida de miliwatts del transversor.',
			'settings.station.elecraftTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.elecraftTroubleshooting' => 'Las radios Elecraft hablan CAT de Kenwood, y tanto una KX2 como una KX3 se han usado así — VFO en ambos sentidos, cambio de modo y batido cero en CW, todo funcionando.\n\nSi la radio no responde, casi siempre es una de estas:\n\n- **La velocidad debe coincidir** con la configurada en **RS232** en el menú de la radio. 38400 es la de fábrica. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n\n**Si la frecuencia es correcta pero el modo no**, cuéntanoslo. Las entradas de la KX2 y la KX3 leen el modo de una posición en la respuesta de estado de la radio que hemos fijado según las radios que hemos visto, y un firmware que lo ponga en otro lugar solo nos llega a través de un reporte.\n\nNadie ha reportado nada sobre la K3, así que cuéntanos qué pasa si usas una. La K4 tiene su propia entrada.',
			'settings.station.lab599TroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.lab599Troubleshooting' => 'La línea TX-500 habla CAT de Kenwood. Frecuencia y modo se han probado a través de un LiNK500MP; potencia y medidores están escritos a partir de la referencia CAT de Lab599, así que por favor reporta qué pasa, funcione o no.\n\n- **La velocidad debe coincidir** con el ajuste CAT de la radio, 9600 salvo que lo hayas cambiado. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Elige el protocolo CAT en la radio.** TS-2000 cubre frecuencia, modo y potencia. LAB599 además permite que la app cambie la radio a DIG, la vea transmitir en DIG y lea su voltaje de alimentación.\n- **A través de un LiNK500MP**, mantén pulsada la perilla del VFO unos tres segundos para pasar el control CAT a la interfaz.\n- **Configura el modo del LiNK500MP según la conexión**: Modo 3 para Bluetooth, Modo 4 para Bluetooth LE. En cualquier otro modo, una búsqueda Bluetooth LE no lo encuentra.\n- **Por Bluetooth**, el LiNK500MP se empareja como dos puertos serie y solo uno lleva el CAT. Si la radio se queda en silencio, elige el otro.',
			'settings.station.lab599TroubleshootingIos' => 'La línea TX-500 habla CAT de Kenwood. Frecuencia y modo se han probado a través de un LiNK500MP; potencia y medidores están escritos a partir de la referencia CAT de Lab599, así que por favor reporta qué pasa, funcione o no.\n\n- **Pon el LiNK500MP en Modo 4**, su modo Bluetooth LE, antes de buscarlo. En cualquier otro modo, un iPhone o iPad no puede encontrarlo.\n- **Pasa el control CAT al LiNK500MP**: mantén pulsada la perilla del VFO de la radio unos tres segundos.\n- **Elige el protocolo CAT en la radio.** TS-2000 cubre frecuencia, modo y potencia. LAB599 además permite que la app cambie la radio a DIG, la vea transmitir en DIG y lea su voltaje de alimentación.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Si la radio conecta pero no muestra frecuencia',
			'settings.station.kenwoodTroubleshooting' => 'Este controlador está probado con las Kenwood TS-590SG y TS-480, las QRP Labs QMX y QCX-mini, y las Elecraft KX2 y KX3. El resto de la línea está escrito a partir de referencias CAT publicadas, así que por favor reporta qué pasa, funcione o no.\n\nSi la radio no responde, casi siempre es una de estas:\n\n- **La velocidad debe coincidir** con el menú CAT de la radio. Si no coincide, la radio devuelve datos ilegibles o nada, y nunca un error.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.\n- **Algunas radios necesitan CAT habilitado** en el menú antes de responder.\n- **Las radios Kenwood esperan RTS**: su puerto CAT lo usa como handshake, así que Mantener RTS en alto (en Configuración avanzada) debe estar activado. Una conexión creada antes de que viniera activado por defecto puede tenerlo desactivado. En un Digirig u otro cable que active el PTT desde RTS, desactívalo, o la radio transmitirá.\n\n**Varios front-ends SDR hablan este mismo protocolo**, así que vale la pena probar esta entrada también con ellos; las radios Elecraft aparecen aparte, bajo Elecraft. Si la frecuencia es correcta pero el modo no, o falta, esa es justamente la parte que varía en la línea — la app lo deduce de la radio y, si no, lo pregunta directamente, así que el modo puede simplemente tardar un poco.',
			'settings.station.statusConnected' => 'Conectado',
			'settings.station.statusLost' => 'Desconectada',
			'settings.station.notConfigured' => 'Sin configurar',
			'settings.station.currentConfiguration' => 'Configuración actual',
			'settings.station.currentTransceiver' => 'Radio actual',
			'settings.station.currentTransceivers' => 'Radios actuales',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => 'Los mensajes se encolan en lugar de interrumpir',
			'settings.station.noRadioBSelected' => 'Ninguna Radio B seleccionada',
			'settings.station.radioMode' => 'Modo de la radio',
			'settings.station.keyerNotSupported' => 'No compatible con la radio actual',
			'settings.station.catControlPreferences' => 'Preferencias de control CAT',
			'settings.station.chooseTransceiver' => 'Elegir radio',
			'settings.station.configurationSection' => 'Configuración',
			'settings.station.noTransceiverSelected' => 'Ninguna radio seleccionada',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Usar ${name} para el VFO principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, zero: 'Ninguna radio', one: '${count} radio', other: '${count} radios', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} antena', other: '${count} antenas', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} otro equipo', other: '${count} otros equipos', ), 
			'settings.station.equipmentInventory' => 'Inventario de equipos',
			'settings.station.equipmentInUse' => 'Controles de la radio',
			'settings.station.noTransceiver' => 'Ninguno',
			'settings.station.peerRadioNotAvailable' => 'No disponible',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'En ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} está en otro dispositivo',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Esta radio está conectada a ${device}. Su conexión y sus opciones se configuran en ese dispositivo.',
			'settings.station.antennaInUse' => 'Antena en uso',
			'settings.station.keyInUse' => 'Manipulación CW',
			'settings.station.phoneKeying' => 'Fonía grabada',
			'settings.station.phoneKeyingNone' => 'Ninguna',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => 'Memorias en ${radio}',
			'settings.station.phoneKeyingComputer' => 'Audio en esta computadora',
			'settings.station.phoneKeyingOff' => 'La fonía grabada está apagada',
			'settings.station.computerVoiceSettings' => 'Audio de la computadora',
			'settings.station.cwKeyingOptions' => 'Opciones de manipulación CW',
			'settings.station.noneSelected' => 'Ninguno',
			'settings.station.moreSettings' => 'Más opciones',
			'settings.station.icomCivTroubleshootingTitle' => 'Si aparecen dos puertos serie para la misma radio',
			'settings.station.icomCivTroubleshooting' => 'Varias radios Icom, entre ellas la IC-705, presentan **dos** puertos serie USB a la vez (Icom los llama Puerto A y Puerto B), ambos configurados en CI-V por defecto. Ni esta app ni tu sistema operativo pueden distinguirlos más allá de eso: el mismo identificador de fabricante/producto USB aparece dos veces, a veces marcado aquí con un sufijo `#2`. **El Puerto A suele ser el correcto** — normalmente el primero que lista tu sistema operativo o navegador, y cuando esta app puede distinguir los dos puertos marca ese como sugerido. Si los comandos salen y la radio nunca responde, prueba el otro puerto.',
			'settings.station.civAddressTroubleshootingTitle' => 'Si la radio nunca responde',
			'settings.station.civAddressTroubleshooting' => '- **La dirección CI-V debe coincidir** con el menú de la radio. Esta entrada rellena la dirección de fábrica del modelo, pero un equipo que comparte un bus CI-V es justo donde eso se cambia. Una trama enviada a la dirección equivocada se ignora en silencio, lo que se ve exactamente igual que un cable muerto.\n- **La velocidad debe coincidir** con el CI-V BAUD RATE de la radio (por USB, CI-V USB Baud Rate). Pon en la radio el mismo número que aquí, **no Auto**. En Auto algunas radios, entre ellas la IC-7300, conectan y dejan de responder al cabo de un minuto más o menos.\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **La dirección CI-V debe coincidir** con el menú de la radio. Esta entrada rellena la dirección de fábrica del modelo, pero un equipo que comparte un bus CI-V es justo donde eso se cambia. Una trama enviada a la dirección equivocada se ignora en silencio, lo que se ve exactamente igual que un cable muerto.\n${speed}\n- **Otra app puede tener el puerto**: WSJT-X, fldigi y rigctld lo mantienen abierto.',
			'settings.station.icomUsbSpeedFollows' => '- **No hay velocidad que configurar.** Por USB esta radio habla a la velocidad que use la computadora, y esta entrada siempre usa 115200, la velocidad que necesita el espectro.',
			'settings.station.ic7610UsbSpeed' => '- **Pon CI-V USB Baud Rate en 115200**, la velocidad que esta entrada siempre usa, porque el espectro la necesita — **no Auto**. Una radio en cualquier otra velocidad responde con silencio.',
			'settings.station.civTransceiveTitle' => 'Si la app tarda en seguir a la radio',
			'settings.station.civTransceive' => 'Si la app tarda varios segundos en mostrar un cambio de frecuencia o modo hecho en la radio, activa el ajuste **CI-V Transceive** de la radio (en la mayoría de los modelos actuales, en SET > Connectors > CI-V). Con él activado, la radio reporta cada cambio en el momento en que ocurre. Con él desactivado, la app solo ve un cambio la próxima vez que pregunta, cada pocos segundos.',
			'settings.station.ic7300Mk2Note' => '\n- El **IC-7300 MK2** viene con la dirección `B6`, no con el `94` que se rellena aquí: elige la entrada IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- El **IC-705** presenta dos puertos serie USB, ambos con el nombre de la radio. CI-V está en el **primero**, que el selector señala cuando puede distinguirlos.',
			'settings.station.ic7760PortNote' => '\n- El **IC-7760** usa CI-V en el **Puerto A** de los dos puertos serie USB que presenta.',
			'settings.station.x6100PortNote' => '\n- El **X6100** usa CI-V en su puerto **DEV**, el segundo de los dos puertos serie que presenta, y el que el selector señala.',
			'settings.station.rigctldTroubleshootingTitle' => 'Si la app no puede conectar',
			'settings.station.rigctldTroubleshooting' => 'Esto se conecta a un **daemon rigctld que ejecutas tú mismo**, no directamente a la radio — el backend de Hamlib es quien habla con la radio y soporta cientos de modelos.\n\n- **El daemon ya debe estar en ejecución**, p. ej. `rigctld -m 1035 -r /dev/ttyUSB0`. Encuentra el número de modelo de tu radio con `rigctl -l`.\n- **Desde otra máquina**, inícialo con `-T 0.0.0.0`: por defecto rigctld solo acepta conexiones desde la máquina donde corre.\n- **El puerto** es 4532 salvo que hayas iniciado el daemon con `-t`.\n- Una vez conectado, si falta la frecuencia normalmente es que el daemon mismo no puede comunicarse con la radio. Pruébalo con `rigctl -m 2 f` en la máquina del daemon.',
			'settings.station.flrigTroubleshootingTitle' => 'Si la app no puede conectar',
			'settings.station.flrigTroubleshooting' => 'Esto se conecta a un **programa flrig que ejecutas tú mismo**, no directamente a la radio — flrig habla con la radio y soporta la mayoría de marcas y modelos.\n\n- **flrig ya debe estar en ejecución**, con su radio configurada y conectada.\n- **El puerto** es 12345 salvo que lo hayas cambiado en la configuración de flrig (Config → Setup → Server).\n- **Desde otra máquina**, asegúrate de que el servidor de flrig sea accesible. Escucha en todas las interfaces, pero tu firewall puede no estar de acuerdo.\n- Una vez conectado, si falta la frecuencia normalmente es que flrig mismo no puede comunicarse con la radio. Verifica que la pantalla de flrig siga el dial.',
			'settings.station.hrdTroubleshootingTitle' => 'Si la app no puede conectar',
			'settings.station.hrdTroubleshooting' => 'Esto se conecta al **Rig Control de Ham Radio Deluxe, que se ejecuta en tu computadora**, no directamente a la radio — HRD habla con la radio.\n\n- **Rig Control ya debe estar en ejecución** y conectado a la radio.\n- **Su servidor IP debe estar habilitado.** Rig Control solo se comunica con otros programas a través de él.\n- **El puerto** es 7809 salvo que lo hayas cambiado en la configuración del servidor IP.\n- **Desde otra máquina**, asegúrate de que tu firewall deje pasar la conexión.\n\nEsta entrada se escribió a partir de descripciones publicadas del protocolo de HRD y no se ha probado con HRD. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Si la app no puede conectar',
			'settings.station.n3fjpTroubleshooting' => 'Esto se conecta a **un programa de log N3FJP que se ejecuta en tu computadora**, no directamente a la radio — N3FJP habla con la radio.\n\n- **La API del programa debe estar activada**: Settings → Application Program Interface, marca **TCP API Enabled**.\n- **El puerto** es 1100 salvo que lo hayas cambiado ahí.\n- **N3FJP debe tener configurada una interfaz de radio** para seguir o sintonizar la radio. Sin ella, solo reporta lo que se escribe en su ventana de entrada.\n- N3FJP reporta solo banda, modo y frecuencia: ni potencia ni estado de transmisión.\n\nEsta entrada se escribió a partir de la API publicada de N3FJP y no se ha probado con N3FJP. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.commanderTroubleshootingTitle' => 'Si la app no puede conectar',
			'settings.station.commanderTroubleshooting' => 'Esto se conecta a **DXLab Commander, que se ejecuta en tu computadora**, no directamente a la radio — Commander habla con la radio.\n\n- **Commander ya debe estar en ejecución** y conectado a la radio.\n- **Su servicio de red debe estar activado**: el botón **Net Serv** del panel Radio en la ventana de configuración de Commander.\n- **El puerto** es 52002, el tercero del bloque que empieza en el **Base Port** de Net Serv (52000 salvo que lo hayas cambiado).\n- **Desde otra máquina**, asegúrate de que tu firewall deje pasar la conexión.\n\nEsta entrada se escribió a partir de los mensajes TCP publicados de Commander y no se ha probado con Commander. Si funciona a medias, vale la pena reportarlo.',
			'settings.station.ic705TroubleshootingTitle' => 'Si la radio nunca responde',
			'settings.station.ic705Troubleshooting' => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview o RS-BA1 conectado a la misma radio ocupa esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio.** La WLAN debe estar encendida, la radio en la misma red y su función de control remoto (Network) habilitada.\n- **Los puertos deben coincidir** con el Control Port y el Serial Port (UDP) de la radio, o con los puertos redirigidos a ellos. Un puerto equivocado se encuentra con silencio, igual que una radio apagada.\n- **Reinicia la WLAN de la radio** si sigue atascada. Eso libera de forma confiable una sesión atascada en la radio.\n\nUna **contraseña incorrecta se rechaza explícitamente**, no con silencio. Si llegaste aquí en lugar de ver un mensaje de "rechazada", la contraseña no es el problema.',
			'settings.station.icomLanTroubleshooting' => 'La radio tiene una **única** sesión de control remoto. Cuando el inicio de sesión se ignora, casi siempre hay algo más usándola.\n\n- **Cierra cualquier otro cliente.** wfview, RS-BA1 o el Remote Utility de Icom conectados a la misma radio ocupan esa única sesión, y mientras tanto el inicio de sesión aquí simplemente se ignora.\n- **Revisa la configuración de red de la radio.** Su puerto LAN debe estar conectado a la misma red que este dispositivo, su **Network Control** debe estar activado, y el usuario y la contraseña deben estar configurados como usuario de red en la radio.\n- **Los puertos deben coincidir** con el Control Port y el Serial Port (UDP) de la radio, o con los puertos redirigidos a ellos. Un puerto equivocado se encuentra con silencio, igual que una radio apagada.\n- **Si conecta pero nunca responde**, la dirección CI-V de aquí debe coincidir con el menú CI-V ADDRESS de la radio. Esta entrada rellena la dirección de fábrica del modelo.\n- **Apaga y enciende la radio** si sigue atascada.',
			'settings.station.statusStale' => 'Sin respuesta',
			'settings.station.statusDisconnected' => 'No conectada',
			'settings.station.statusConnecting' => 'Conectando…',
			'settings.station.statusDisconnecting' => 'Desconectando…',
			'settings.station.statusError' => 'Fallo de conexión',
			'settings.station.currentRadioSettings' => 'Configuración de la radio actual',
			'settings.station.notSupportedByThisRadio' => 'No compatible con esta radio',
			'settings.station.cwMessagesButton' => 'Mensajes de CW',
			'settings.station.voiceMessagesButton' => 'Mensajes de fonía',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Manipulador de voz: ${count} memorias en la radio',
			'settings.station.antennaBands' => 'Bandas',
			'settings.station.antennaType' => 'Tipo de antena',
			'settings.station.antennaTypeRequired' => 'Elige un tipo de antena',
			'settings.station.antennaTypes.dipole' => 'Dipolo',
			'settings.station.antennaTypes.vertical' => 'Vertical',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Directiva',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Hilo largo / EFHW',
			'settings.station.antennaTypes.other' => 'Otra',
			'settings.station.keyType' => 'Tipo de manipulador',
			'settings.station.keyTypeRequired' => 'Elige un tipo de manipulador',
			'settings.station.keyTypes.straight' => 'Manipulador recto',
			'settings.station.keyTypes.sideswiper' => 'Manipulador lateral (sideswiper)',
			'settings.station.keyTypes.bug' => 'Bug (semiautomático mecánico)',
			'settings.station.keyTypes.fullyAutomatic' => 'Manipulador electrónico automático',
			'settings.station.keyTypes.singlePaddle' => 'Paleta simple',
			'settings.station.keyTypes.dualPaddle' => 'Paleta doble',
			'settings.station.keyTypes.computerDriven' => 'Controlado por computadora',
			'settings.station.keyTypes.other' => 'Otro',
			'settings.station.softwareIntermediaries' => 'Intermediarios de software',
			'settings.station.otherBrands' => 'Otras marcas',
			'settings.station.otherEquipment' => 'Otros equipos (antenas, manipuladores, etc.)',
			'settings.station.newAntenna' => 'Nueva antena',
			'settings.station.newKey' => 'Nuevo manipulador',
			'settings.station.newKeyer' => 'WinKeyer (K1EL o compatible)',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Manipulador CAT en ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Manipulador en ${device}',
			'settings.station.trackStationInfo' => 'Registrar datos de la estación en cada QSO',
			'settings.station.includeStationInfoInAdif' => 'Incluir en las exportaciones ADIF',
			'settings.station.whatToTrack' => '¿Qué registrar?',
			'settings.station.trackFieldRig' => 'Radio',
			'settings.station.trackFieldPower' => 'Potencia',
			'settings.station.watts' => 'Vatios',
			'settings.station.trackFieldAntenna' => 'Antena',
			'settings.station.trackFieldKey' => 'Manipulador',
			'settings.station.placeholderConnectDelay' => 'Retraso de conexión (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Cuánto tarda el handshake simulado. En blanco o 0 conecta al instante.',
			'settings.station.placeholderDropAfter' => 'Desconectar tras (segundos)',
			'settings.station.placeholderDropAfterDescription' => 'Cierra la conexión por su cuenta, para probar la reconexión. En blanco o 0 nunca desconecta.',
			'settings.station.placeholderFailConnect' => 'Fallar siempre al conectar',
			'settings.station.placeholderConnectFailure' => 'Se le indicó a la radio simulada que rechazara esta conexión',
			'settings.station.placeholderFreq' => 'Frecuencia (kHz)',
			'settings.station.placeholderFreqDescription' => 'Dónde arranca la radio simulada. Después reporta la frecuencia a la que la app la sintonice.',
			'settings.station.placeholderMode' => 'Modo',
			'settings.station.placeholderModeDescription' => 'El modo con el que arranca la radio simulada, por ejemplo USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Potencia (vatios)',
			'settings.station.placeholderPurpose' => 'Usa esta radio para registrar con qué equipo estás operando',
			'settings.station.placeholderReplyDelay' => 'Retraso de respuesta (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Cuánto tarda la radio simulada en reportar un cambio. En blanco o 0 responde de inmediato.',
			'settings.station.cwKeyerField' => 'Manipulador de CW por CAT',
			'settings.station.cwKeyerFieldDescription' => 'Si esta radio manipula CW desde texto por CAT. Apagado para una radio que la app no conoce.',
			'settings.station.voiceMemories' => 'Memorias de voz',
			'settings.station.voiceMemoriesDescription' => 'Cuántas memorias de voz reproduce la radio por CAT. 0 si ninguna.',
			'settings.station.voiceMemoriesInvalid' => 'Un número entero, 0 o más',
			'settings.station.yaesuMeterCapture' => 'Capturar lecturas de medidores',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Lee el medidor de potencia de salida y el indicador de ROE alta de la radio mientras transmite y escribe los valores en bruto en el log. Sirve para construir la escala que Yaesu no publica — los valores no se muestran como medidores.',
			'settings.station.yaesuMeterCaptureDescription' => 'Lee los medidores PO, ROE y ALC de la radio mientras transmite y escribe los valores en bruto en el log. Sirve para construir la escala que Yaesu no publica — los valores no se muestran como medidores.',
			'settings.station.telemetryInterval' => 'Intervalo de lectura de medidores (ms)',
			'settings.station.telemetryIntervalDescription' => 'Cada cuánto se leen los medidores de la radio mientras transmite. Déjalo en blanco para lo más rápido que admita esta conexión, hasta 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Un número entero de milisegundos, de ${min} a ${max}',
			'settings.station.pollInterval' => 'Intervalo de consulta en reposo (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Cada cuánto se pide a la radio su frecuencia y modo mientras no cambian. Déjalo en blanco para ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Un número entero de milisegundos, de ${min} a ${max}',
			'settings.station.advancedSettings' => 'Configuración avanzada',
			'settings.station.placeholderSwr' => 'Lectura de ROE',
			'settings.station.placeholderSwrDescription' => 'Qué ROE indica esta radio mientras transmite. Por encima de 1,8 el panel avisa.',
			'settings.station.placeholderSwrInvalid' => 'Un número, 1 o más',
			'settings.station.keyerNone' => 'Ninguno',
			'settings.station.cwDialect' => 'Dialecto de manipulación de CW',
			'settings.station.cwDialectDescription' => 'Qué forma del comando KY acepta esta radio. Ninguno significa sin manipulación CW por CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, rellenado a 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY texto)',
			'settings.station.voiceDialect' => 'Dialecto del manipulador de voz',
			'settings.station.voiceDialectDescription' => 'Cómo reproduce esta radio sus memorias de voz por CAT. Ninguno significa sin memorias de voz por CAT. Con dialecto y sin cantidad, se aplica la cantidad por defecto del dialecto.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, estilo TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB y DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (pulsaciones de teclas)',
			'settings.station.placeholderDiagnostic' => 'Simulada',
			'settings.station.placeholderWholeNumberInvalid' => 'Debe ser un número entero, 0 o más',
			'settings.station.placeholderFreqInvalid' => 'Debe ser una frecuencia en kHz, mayor que cero',
			'settings.station.placeholderModeInvalid' => 'Debe ser un nombre de modo, por ejemplo USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposición',
			'settings.station.switchLayoutDescription' => 'En qué lado del conmutador están conectadas tus radios.',
			'settings.station.switchLayoutRequired' => 'Elige cómo está cableado el conmutador',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'El conmutador rechazó "${command}" (error ${code})',
			'settings.station.switchBusyTransmitting' => 'Ese puerto está transmitiendo — la antena no se cambió',
			'settings.station.switchNoAntenna' => 'Ninguna',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antena en el puerto ${port}',
			'settings.station.switchAntennaForDescription' => 'Cuál de tus antenas está conectada a este puerto del conmutador.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antenas, ${radios} radios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antenas, 1 radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antena, ${radios} radios',
			'settings.station.switchCommonPort' => 'Común',
			'settings.station.dcnAddress' => 'Dirección del dispositivo',
			'settings.station.dcnAddressDescription' => 'La dirección configurada en los interruptores DIP del módulo. Un módulo de relés coaxiales sale de fábrica con la 2.',
			'settings.station.dcnAddressRequired' => 'Debe ser una dirección de dispositivo del 1 al 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Puerto ${port}',
			'settings.station.switchPortAutoHint' => 'sigue los datos de banda',
			'settings.station.switchPortTransmittingHint' => 'transmitiendo — no se puede cambiar ahora',
			'settings.station.switchCurrentStateHeader' => 'Estado actual',
			'settings.station.switchCurrentStateDescription' => 'En qué antena está ahora mismo cada puerto de radio. Los cambios surten efecto de inmediato.',
			'settings.station.switchWiringHeader' => 'Cableado',
			'settings.station.switchPortInhibitedHint' => 'transmisión inhibida',
			'settings.station.rotatorAxes' => 'Ejes',
			'settings.station.rotatorAxesDescription' => 'Si el rotor gira solo en azimut, o también en elevación (un G-5500 o similar).',
			'settings.station.rotatorAxesAzimuth' => 'Solo azimut',
			'settings.station.rotatorAxesAzimuthElevation' => 'Azimut y elevación',
			'settings.station.rotatorAzimuthOffset' => 'Desplazamiento de azimut',
			'settings.station.rotatorAzimuthOffsetDescription' => 'Grados que se suman a lo que lee el controlador, cuando su cero no es el norte verdadero. Los giros se corrigen en consecuencia.',
			'settings.station.rotatorElevationOffset' => 'Desplazamiento de elevación',
			'settings.station.rotatorAzimuthMin' => 'Azimut mínimo',
			'settings.station.rotatorAzimuthMax' => 'Azimut máximo',
			'settings.station.rotatorAzimuthMaxDescription' => 'En los grados propios del controlador. Más de 360 para un rotor con solapamiento, que entonces toma el giro más corto.',
			'settings.station.rotatorElevationMin' => 'Elevación mínima',
			'settings.station.rotatorElevationMax' => 'Elevación máxima',
			'settings.station.rotatorElevationMaxDescription' => 'En los grados propios del controlador. Más de 90 para un rotor que se da la vuelta.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => 'Grados enteros, de ${min} a ${max}',
			'settings.station.rotatorLimitsInvalid' => 'El límite inferior tiene que ser menor que el superior',
			'settings.station.rotatorPollInterval' => 'Intervalo de consulta (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'Cada cuánto se le pregunta al rotor hacia dónde apunta. Déjalo en blanco para ${fallback} ms.',
			'settings.station.rotatorAxesRequired' => 'Elige en qué ejes gira el rotor',
			'settings.station.rotatorRefused' => 'El controlador rechazó un comando. Comprueba que esté en modo GS-232.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator responde solo una vez que está configurado para ello, y si no, no dice absolutamente nada:\n\n- **Activa UDP Control** en el menú Setup de PstRotator.\n- **Iguala el puerto**: Communication → UDP Control Port, 12000 salvo que lo hayas cambiado. PstRotator responde en el puerto siguiente (12001), que tiene que estar libre en este dispositivo.\n- **Conecta PstRotator a su controlador.** Hasta que lo esté, no responde nada por UDP.\n- **Permítelo en el firewall** del PC donde corre PstRotator, y en este dispositivo, que escucha las respuestas.\n- **En un Mac, iPhone o iPad**, Ham2K Logger necesita acceso a la red local (Configuración → Privacidad y seguridad → Red local).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => 'Estado actual: ${position}',
			'settings.station.rotatorDisconnected' => 'desconectado',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '${degrees}° de azimut',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '${degrees}° az',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '${degrees}° de elevación',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '${degrees}° el',
			'settings.station.rotatorNoReading' => 'Esperando a que el controlador reporte su posición…',
			'settings.station.rotatorNotResponding' => 'no responde',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => 'Girando hacia ${heading}, hasta donde permiten los límites de este rotor',
			'settings.station.rotatorTargetAzimuth' => 'Girar a azimut',
			'settings.station.rotatorTargetAzimuthShort' => 'Girar a az',
			'settings.station.rotatorTargetElevation' => 'Girar a elevación',
			'settings.station.rotatorTargetElevationShort' => 'Girar a el',
			'settings.station.rotatorAzimuthInvalid' => 'Debe ser de 0 a 360',
			'settings.station.rotatorElevationInvalid' => 'Debe ser de 0 a 180',
			'settings.station.rotatorTurn' => 'Girar',
			'settings.station.rotatorStop' => 'Detener',
			'settings.station.configUnreadable' => 'No se pudo leer la configuración guardada de esta radio. Abre su configuración y vuelve a ingresarla, o quítala y agrégala de nuevo.',
			'settings.station.autoConnectHeld' => 'HaLo dejó de responder la última vez que se conectó a esta radio, así que esta vez no se conectó por su cuenta. Pulsa Conectar para intentarlo de nuevo.',
			'settings.offlineData.title' => 'Datos sin conexión',
			'settings.offlineData.noFiles' => 'No hay archivos de datos',
			'settings.offlineData.noFilesDescription' => 'Habilita extensiones de actividades o búsquedas para descargar aquí sus datos sin conexión.',
			'settings.offlineData.refresh' => 'Actualizar',
			'settings.offlineData.refreshing' => 'Actualizando…',
			'settings.offlineData.updateAll' => 'Actualizar todo',
			'settings.offlineData.updatingAll' => 'Actualizando todos los archivos de datos…',
			'settings.offlineData.neverDownloaded' => 'Nunca descargado',
			'settings.offlineData.updatedJustNow' => 'Actualizado hace un momento',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Actualizado hace ${days}d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Actualizado hace ${days}d ${hours}h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Actualizado hace ${hours}h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Actualizado hace ${hours}h ${minutes}m',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Actualizado hace ${minutes}m',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'La última descarga traía solo ${imported} de ${existing} registros y no se usó. Actualiza para aceptarla.',
			'settings.offlineData.extensionsSection' => 'Extensiones',
			'settings.profiles.notSet' => 'Sin establecer',
			'settings.profiles.personalInfo' => 'Datos personales',
			'settings.profiles.personalInfoNote' => 'Esto puede incluirse en los logs generados cuando sea relevante para los envíos',
			'settings.profiles.name' => 'Nombre',
			'settings.profiles.email' => 'Correo electrónico',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'Sección ARRL',
			'settings.profiles.racSection' => 'Sección RAC',
			'settings.profiles.section' => 'Sección',
			'settings.search.clear' => 'Borrar',
			'settings.search.hint' => 'Buscar en la configuración',
			'settings.developer.developerModeDescription' => 'Habilita avisos de desarrollador, logs de depuración y herramientas.',
			'settings.developer.experiments' => 'Experimentos',
			'settings.developer.showIdleMetrics' => 'Mostrar métricas de inactividad',
			'settings.developer.showIdleMetricsDescription' => 'Muestra en la barra de estado qué tan inactivo estuvo el motor de extensiones durante el último segundo. Tócalo para ver los promedios de 10 y 60 segundos.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% inactivo',
			'settings.developer.idleMetricsAverages' => 'Prom. inactivo:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} habilitado', other: '${count} habilitados', ), 
			'settings.developer.patchTrack' => 'Canal de code push',
			'settings.developer.patchTrackDescription' => 'Qué canal de code push over-the-air sigue este dispositivo. Los canales más aventureros reciben correcciones antes, menos probadas. Los code push se aplican en el próximo reinicio.',
			'settings.developer.trackStable' => 'Estable',
			'settings.developer.trackUnstable' => 'Inestable',
			'settings.developer.trackBleeding' => 'Bleeding Edge',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Buscando un code push en "${track}"…',
			'settings.developer.patchDownloaded' => 'Code push descargado — reinicia la app para aplicarlo.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'No hay code push nuevo en "${track}".',
			'settings.developer.noPatchInstalled' => 'No hay code push instalado — ejecutando el binario de la versión.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Ejecutando el code push #${patch}.',
			'settings.developer.deepLinks' => 'Enlaces profundos',
			'settings.developer.registerUrlSchemes' => 'Registrar esquemas de URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permite que los enlaces com.ham2k:// abran esta copia de la app',
			'settings.developer.registerUrlSchemesDone' => 'Esta copia ahora abre los enlaces com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'No se pudo registrar: ${error}',
			'settings.developer.systemInformation' => 'Información del sistema',
			'settings.developer.appVersion' => 'Versión de la app',
			'settings.developer.dataFolder' => 'Carpeta de datos',
			'settings.developer.loading' => '(cargando…)',
			'settings.developer.panelLoadFailed' => 'No se pudo cargar este panel de configuración.',
			'settings.developer.extDevServer' => 'Servidor de desarrollo de extensiones',
			'settings.developer.extensionSettings' => 'Configuración de extensiones',
			'settings.developer.extDevServerDescription' => 'Carga extensiones desde un servidor de desarrollo en tu red en lugar de las incluidas en la app, y las recarga al guardar.',
			'settings.developer.extDevServerAddress' => 'Dirección del servidor',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Conectar',
			'settings.developer.extDevServerDisconnect' => 'Desconectar',
			'settings.developer.extDevServerConnecting' => 'Conectando…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Sirviendo ${count} extensión: ${keys}', other: 'Sirviendo ${count} extensiones: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Sin conexión',
			'settings.developer.extDevServerReconnect' => 'Reconectar al iniciar',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Última recarga: ${key} a las ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} extensión con errores de compilación', other: '${count} extensiones con errores de compilación', ), 
			'settings.developer.catalog' => 'Catálogo de extensiones',
			'settings.developer.catalogDescription' => 'Leer el catálogo desde otro servidor — uno local mientras se trabaja en el catálogo mismo. Vacío significa catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Dirección del catálogo',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Canales de búsqueda del catálogo',
			'settings.developer.catalogSearchStable' => 'Solo estables',
			'settings.developer.catalogSearchUnstable' => 'Inestables o mejores',
			'settings.developer.catalogSearchBleeding' => 'Bleeding Edge o mejores',
			'settings.about.notices' => 'Avisos y mensajes',
			'settings.about.noticesDescription' => 'Anuncios y mensajes de estado',
			'settings.about.releaseNotes' => 'Notas de la versión',
			'settings.about.copiedVersion' => 'Detalles de versión copiados al portapapeles',
			'settings.panels.settings' => 'Preferencias de la aplicación',
			'settings.panels.settingsDescription' => 'Haz que la app funcione como quieras',
			'settings.panels.commonSettings' => 'Preferencias comunes',
			'settings.panels.syncDescription' => 'Respalda y sincroniza tus logs entre dispositivos',
			'settings.panels.accountsDescription' => 'Credenciales de servicios, datos sin conexión y más',
			'settings.panels.extensions' => 'Extensiones y funciones',
			'settings.panels.extensionsDescription' => 'Actividades, concursos, paneles del tablero y más funciones',
			'settings.panels.profilesDescription' => 'Indicativo del operador y perfil de la estación',
			'settings.panels.stationProfiles' => 'Perfiles de estación',
			'settings.panels.developerSettings' => 'Configuración de desarrollador',
			'settings.panels.developerSettingsDescription' => 'Herramientas de depuración y desarrollo',
			'settings.panels.about' => 'Acerca de',
			'settings.panels.aboutDescription' => 'Versión, créditos e información legal',
			'settings.panels.unavailableTitle' => 'Algunas opciones no están disponibles',
			'settings.panels.unavailableText' => 'El motor de extensiones no pudo iniciarse, así que faltan las opciones aportadas por extensiones.',
			'settings.panels.station' => 'Configuración de Estación',
			'settings.panels.stationDescription' => 'Control CAT y más opciones',
			'settings.panels.peers' => 'Dispositivos cercanos',
			'settings.panels.peersDescription' => 'Conéctate con otros dispositivos cercanos',
			'settings.showMoreSettings' => 'Mostrar más opciones',
			'settings.gridPrecision' => 'Precisión de la grilla',
			'settings.gridPrecisionOpts.six' => '6 dígitos (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 dígitos (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 dígitos',
			'settings.gridPrecisionDescription.eight' => '8 dígitos',
			'commands.enableSyncFirst' => 'Primero habilita la sincronización en la Configuración.',
			'commands.fullResyncStarted' => 'Resincronización completa iniciada — los datos locales se respaldaron primero.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Ningún archivo de datos coincide con "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Error al recargar: ${error}',
			'commands.reloadingAll' => 'Recargando todos los archivos de datos…',
			'commands.reloadingTarget' => ({required Object target}) => 'Recargando archivos de datos de ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experimento desconocido "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} habilitado',
			'commands.experimentDisabled' => ({required Object name}) => '${name} deshabilitado',
			'commands.sentryTestSent' => 'Reporte de error de prueba enviado a Sentry',
			'commands.idleMetricsEnabled' => 'Métricas de inactividad habilitadas en la barra de estado',
			'commands.idleMetricsDisabled' => 'Métricas de inactividad deshabilitadas',
			'commands.sentryTestLocalOnly' => 'Sentry está deshabilitado en este build — el error de prueba solo se registró localmente',
			'commands.noOperationOpen' => 'Ese comando necesita una operación abierta',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'No sé cómo marcar un \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} no está activado en esta app',
			'commands.goUnknown' => ({required Object to}) => 'No sé cómo ir a \'${to}\'',
			'commands.goBlocked' => 'Cierra primero el diálogo abierto',
			'commands.operationAlreadyStarted' => 'Esta operación ya tiene una marca de inicio',
			'commands.couldNotOpenLocation' => 'Se agregó la pausa, pero no se pudo abrir la pantalla de ubicación',
			'commands.noTestOperations' => 'No hay operaciones de prueba que purgar',
			'commands.purgeTestsUnavailable' => 'PURGETESTS necesita mostrar un diálogo de confirmación, que no está disponible aquí',
			'commands.syncAllUnavailable' => 'SYNCALL necesita mostrar un diálogo de confirmación, que no está disponible aquí',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se purgó ${count} operación de prueba', other: 'Se purgaron ${count} operaciones de prueba', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Se purgaron ${purged} de ${total} operaciones de prueba — el resto falló; prueba PURGETESTS de nuevo',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se purgó ${count} contacto de prueba sin operación', other: 'Se purgaron ${count} contactos de prueba sin operación', ), 
			'commands.purgeTestsContactsFailed' => 'Se purgaron las operaciones de prueba, pero los contactos de prueba sin operación fallaron; prueba PURGETESTS de nuevo',
			'commands.purgeTestsNothingToDo' => 'No se purgó nada',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Se eliminaron ${removed} de ${total} operaciones de prueba — el resto falló; prueba Revisar de nuevo',
			'commands.receivedPurgesFailed' => 'No se pudieron eliminar esas operaciones de prueba — prueba Revisar de nuevo',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} operación de prueba se eliminó en otro dispositivo', other: '${count} operaciones de prueba se eliminaron en otro dispositivo', ), 
			'commands.receivedPurgesReview' => 'Revisar',
			'commands.settingOn' => 'Activado',
			'commands.settingOff' => 'Desactivado',
			'commands.settingEmpty' => '(vacío)',
			'commands.settingSecretSet' => '(establecido)',
			'commands.settingSecretUnset' => '(sin establecer)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} seleccionados',
			'commands.settingExpectsOnOff' => 'activado o desactivado',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'uno de: ${choices}',
			'commands.settingExpectsNumber' => 'un número',
			'commands.settingVanished' => ({required Object label}) => '“${label}” ya no está disponible',
			'commands.noCwKeyer' => 'Ninguna radio conectada puede manipular CW',
			'commands.noKeyer' => 'Ninguna radio conectada puede manipular CW ni reproducir memorias de voz',
			'commands.keyerNeedsOperation' => 'Abre una operación para usar el manipulador de CW',
			'commands.keyerExperimentOff' => 'La manipulación de CW está apagada — enciéndela con EXP KEYER',
			'commands.esmExperimentOff' => 'Enter envía mensajes está apagado — enciéndelo con EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Enviando CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Mensaje de CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'El mensaje de CW F${n} no se envió: las extensiones no están listas',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => 'Mensaje de fonía M${n}: ${error}',
			'commands.voiceMessageNotRendered' => 'las extensiones no están listas',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => 'No se envió nada: la Radio ${radio} no puede emitir eso',
			'commands.so2rNoRadioB' => 'No se envió nada: elige una Radio B en Configuración de Estación para emitir desde este juego',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” no aceptó ese valor',
			'commandDialog.hint' => 'Busca indicativos o escribe un comando',
			'commandDialog.noResults' => ({required Object text}) => 'Nada coincide con “${text}”',
			'commandDialog.sectionCommands' => 'Comandos',
			'commandDialog.sectionGoTo' => 'Ir a',
			'commandDialog.sectionOperations' => 'Operaciones',
			'commandDialog.goHome' => 'Inicio',
			'commandDialog.goSettings' => 'Configuración',
			'commandDialog.goNewOperation' => 'Nueva operación',
			'commandDialog.runTyped' => ({required Object text}) => 'Ejecutar “${text}”',
			'commandDialog.sectionSuggestions' => 'Prueba',
			'commandDialog.lookingUp' => 'Buscando indicativo…',
			'commandDialog.blockedByPane' => 'No se pueden usar los comandos mientras haya un panel o un diálogo abierto',
			'keyboardShortcuts.title' => 'Atajos de teclado',
			'keyboardShortcuts.description' => 'Personaliza las combinaciones de teclas',
			'keyboardShortcuts.search' => 'Buscar comandos y teclas',
			'keyboardShortcuts.import' => 'Importar…',
			'keyboardShortcuts.export' => 'Exportar…',
			'keyboardShortcuts.resetAll' => 'Restablecer todo',
			'keyboardShortcuts.resetAllTitle' => '¿Restablecer todos los atajos?',
			'keyboardShortcuts.resetAllBody' => 'Cada comando vuelve a sus teclas por defecto, y se quitan las teclas asignadas a comandos escritos.',
			'keyboardShortcuts.reset' => 'Restablecer',
			'keyboardShortcuts.noKey' => 'Sin tecla',
			'keyboardShortcuts.changed' => 'Modificado',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} también está asignado a ${commands}',
			'keyboardShortcuts.groupApp' => 'App',
			'keyboardShortcuts.groupKeying' => 'Manipulación',
			'keyboardShortcuts.groupLogging' => 'Logging',
			'keyboardShortcuts.groupCommands' => 'Comandos',
			'keyboardShortcuts.groupFixed' => 'Teclas fijas',
			'keyboardShortcuts.contextApp' => 'En cualquier lugar',
			'keyboardShortcuts.contextLogView' => 'Vistas de Operación, Cacería y Logs',
			'keyboardShortcuts.contextOperation' => 'Vista de operación, manipulando una radio CAT',
			'keyboardShortcuts.contextLogging' => 'En el panel de logging',
			'keyboardShortcuts.addCommand' => 'Agregar un comando…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Comando desconocido: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Abrir el diálogo de comandos',
			'keyboardShortcuts.command.toggleTheme' => 'Cambiar entre claro y oscuro',
			'keyboardShortcuts.command.toggleLanguage' => 'Cambiar entre inglés y español',
			'keyboardShortcuts.command.fontScaleUp' => 'Texto más grande',
			'keyboardShortcuts.command.fontScaleDown' => 'Texto más pequeño',
			'keyboardShortcuts.command.fontScaleReset' => 'Tamaño de texto normal',
			'keyboardShortcuts.command.densityLooser' => 'Interfaz más amplia',
			'keyboardShortcuts.command.densityDenser' => 'Interfaz más compacta',
			'keyboardShortcuts.command.densityAuto' => 'Densidad de interfaz automática',
			'keyboardShortcuts.command.find' => 'Buscar en el log',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Enviar mensaje ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Modo teclado activado o desactivado',
			'keyboardShortcuts.command.ptt' => 'Pulsar para hablar (PTT)',
			'keyboardShortcuts.command.wipe' => 'Borrar el contacto que se está registrando',
			'keyboardShortcuts.fixed.callsign' => 'Escribir indicativos',
			'keyboardShortcuts.fixed.escape' => 'Detener el envío, retroceder un paso o cerrar',
			'keyboardShortcuts.fixed.enter' => 'Registrar el contacto',
			'keyboardShortcuts.fixed.space' => 'Siguiente campo',
			'keyboardShortcuts.fixed.tab' => 'Campo siguiente o anterior',
			'keyboardShortcuts.fixed.arrows' => 'Moverse entre campos, controles y el log',
			'keyboardShortcuts.fixed.walk' => 'Avanzar por páginas en el log, o ir a sus extremos',
			'keyboardShortcuts.fixed.undo' => 'Deshacer un borrado o una eliminación',
			'keyboardShortcuts.editor.addShortcut' => 'Agregar atajo',
			'keyboardShortcuts.editor.listening' => 'Pulsa las teclas del atajo…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc deja de escuchar',
			'keyboardShortcuts.editor.add' => 'Agregar',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} pertenece a los campos de logging o a un diálogo, y no se puede cambiar.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} es como se escriben los indicativos. Mantén Cmd, Ctrl o Alt junto con ella.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'El sistema puede tomar ${keys} antes de que la app la vea.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} ya es una de las teclas de este comando.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Quitar ${keys} de “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'Restablecer por defecto',
			'keyboardShortcuts.editor.remove' => 'Quitar',
			'keyboardShortcuts.editor.commandLabel' => 'Comando',
			'keyboardShortcuts.editor.commandHint' => 'Ingresa cualquier comando válido, o varios comandos separados por ";"',
			'keyboardShortcuts.editor.removeCommand' => 'Quitar comando',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'Ningún comando lee “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'Sin tecla todavía',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Atajos guardados en ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'No se pudieron exportar los atajos: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'No se pudo abrir el archivo: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} no es un archivo de atajos que esta app pueda leer: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'el texto no es YAML válido (línea ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'no es un archivo de atajos de teclado de Ham2K',
			'keyboardShortcuts.file.problemNewerVersion' => 'fue escrito por una versión más nueva de la app',
			'keyboardShortcuts.file.problemMalformed' => 'parte de él no sigue el formato de atajos',
			'keyboardShortcuts.file.problemTooLarge' => 'es demasiado grande',
			'keyboardShortcuts.file.importTitle' => 'Importar atajos',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Escrito en ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'El archivo no dice en qué teclado fue escrito.',
			'keyboardShortcuts.file.translate' => '¿Qué debería ser cada una de estas teclas en este teclado?',
			'keyboardShortcuts.file.leaveOut' => 'Omitir esos atajos',
			'keyboardShortcuts.file.replace' => 'Reemplazar la configuración de este dispositivo',
			'keyboardShortcuts.file.replaceHint' => 'Cada atajo que no esté en el archivo vuelve a su valor por defecto.',
			'keyboardShortcuts.file.merge' => 'Agregar a la configuración de este dispositivo',
			'keyboardShortcuts.file.mergeHint' => 'Los atajos del archivo reemplazan a los de este dispositivo para los mismos comandos, y el resto se conserva.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'Desconocidos en esta versión, así que se omiten: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'No son atajos, así que se omiten: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Teclas que la app se reserva, así que se omiten: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Asignadas a más de un comando tras la importación: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Importar',
			'keyboardShortcuts.file.imported' => 'Atajos importados',
			'keyboardShortcuts.modifier.cmd' => '⌘ Comando',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'Este build ha expirado',
			'expiredBuild.body' => 'Visita ham2k.com y consigue una versión más reciente.',
			'expiredBuild.visit' => 'Visitar ham2k.com',
			'expiredBuild.dismiss' => 'Continuar de todos modos',
			'staleness.codePushFloorTitle' => 'Hay una actualización importante',
			'staleness.codePushFloorBody' => 'Esta versión tiene una corrección que todavía no tienes.',
			'staleness.restartToApply' => 'Reinicia la app para aplicarla.',
			'staleness.quitAndReopen' => 'Cierra la app y vuelve a abrirla para aplicarla.',
			'staleness.reopenToApply' => 'Cierra la app y vuelve a abrirla para aplicarla.',
			'staleness.ignoreForNow' => 'Ignorar por ahora',
			'spotting.noQsoYet' => 'Aún no hay ningún QSO registrado para hacer spot.',
			'spotting.setFrequencyFirst' => 'Primero establece una frecuencia.',
			'spotting.nothingToSpot' => 'Nada para hacer spot — ninguna extensión ofrece spotting aquí.',
			'spotting.incompleteCall' => 'No se puede hacer spot de un indicativo incompleto — termina el indicativo primero.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} falló: ${message}',
			'spotting.unknownError' => 'error desconocido',
			'spotting.notSent' => 'Spot no enviado.',
			'spotting.allSkipped' => 'Spot no enviado: todas las fuentes de spots lo omitieron.',
			'spotting.notRefreshedOffline' => 'Sin conexión — los spots no se actualizaron',
			'dataFiles.downloading' => 'Descargando…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'No se pudo descargar ${name}',
			'dataFiles.downloadFailedWebHint' => 'Esto podría ser un problema de red, o puede que el sitio de este enlace no permita descargas directas desde un navegador web. Prueba la app de escritorio o móvil, o un lugar de alojamiento diferente.',
			'dataFiles.downloadTimedOut' => 'El servidor tardó demasiado en responder. Vuelve a intentarlo más tarde.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} respondió con un error (HTTP ${status}). Vuelve a intentarlo más tarde.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} no pudo entregar este archivo (HTTP ${status}). Comprueba que su dirección siga siendo correcta.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM no tiene un archivo de historial de indicativos para ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'La descarga del historial de indicativos de N1MM para ${stem} no funcionó. Inténtalo de nuevo más tarde.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'No se pudo procesar ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'La descarga traía solo ${imported} de los ${existing} registros de este dispositivo, así que se conservaron los que faltaban. Actualizarla en Configuración › Datos sin conexión la acepta de todos modos.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se importó ${count} registro de ${label}.', other: 'Se importaron ${count} registros de ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Se importaron datos de ${label}.',
			'dataFiles.cleanedUpTitle' => 'Se limpiaron datos de extensiones',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se eliminaron los datos de ${count} archivo de datos de extensiones deshabilitadas.', other: 'Se eliminaron los datos de ${count} archivos de datos de extensiones deshabilitadas.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} registros',
			'dataFiles.definitionUnavailable' => 'La fuente del archivo no proporcionó una definición — su extensión puede estar reiniciándose o mal configurada. Inténtalo de nuevo en un momento.',
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
			'updates.automaticChecks' => 'Buscar automáticamente',
			'updates.automaticChecksDescription' => 'Buscar nuevas versiones en segundo plano, a partir del próximo inicio',
			'extensionService.runtimeNotReady' => 'El motor de extensiones aún no está listo.',
			'extensionService.testFailed' => ({required Object error}) => 'Prueba fallida: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Conectado como ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuración de campo no válida',
			'extensionService.invalidValue' => 'Valor no válido',
			'extensionService.validationError' => ({required Object error}) => 'Error de validación: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Acción fallida: ${error}',
			'extensionService.commandFailed' => 'El comando no se pudo ejecutar',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name} no puede cambiar la configuración: no lo pidió al instalarse',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name} no puede controlar la radio: no lo pidió al instalarse',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name} no puede ejecutar eso: es uno de los comandos de desarrollador propios de la app',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => 'Ahora mismo no se pueden enviar informes',
			'extensionService.stashUnavailable' => 'No se puede acceder al File Stash de Ham2K en este momento',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => 'Sin respuesta de ${names} a la búsqueda de actividades, así que pueden faltar algunos resultados.',
			'extensionService.activitySearchSomeSourcesFailed' => 'Algunas extensiones de actividades no respondieron a la búsqueda, así que pueden faltar algunos resultados.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} pasó demasiado tiempo en sus temporizadores. Quedan detenidos hasta que se reinicien las extensiones.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Los temporizadores de ${name} fallaban una y otra vez. Quedan detenidos hasta que se reinicien las extensiones.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} se trabó en un temporizador. Sus temporizadores quedan detenidos hasta que se reinicien las extensiones.',
			'operationLocationScreen.title' => 'Ubicación de la Operación',
			'operationLocationScreen.selectedLocation' => 'Ubicación seleccionada',
			'operationLocationScreen.gridSquare' => 'Grilla de Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Necesita 4, 6, 8 o 10 caracteres, como FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Ubicaciones sugeridas',
			'operationLocationScreen.deviceGps' => 'GPS del dispositivo',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de ${device}',
			'operationLocationScreen.locating' => 'Localizando…',
			'operationLocationScreen.gpsUnavailable' => 'Ubicación no disponible',
			'operationLocationScreen.permissionDenied' => 'Permiso de ubicación denegado',
			'operationLocationScreen.permissionBlocked' => 'Permiso de ubicación bloqueado',
			'operationLocationScreen.moreDetails' => 'Más detalles',
			'operationLocationScreen.stateOrProvince' => 'Estado o Provincia (opcional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controles de actividad no disponibles',
			'operationLocationScreen.controlsUnavailableReason' => 'Estas referencias se pueden seguir usando; solo que no se pudo acceder a sus actividades.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Reintentar',
			'operationLocationScreen.county' => 'Condado (opcional)',
			'versionLabel.version' => ({required Object version}) => 'Versión ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Parche ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Aún no hay avisos',
			'notices.webStorageInMemory' => 'Este navegador no pudo ofrecer almacenamiento persistente — el log vive solo en memoria y se PERDERÁ al cerrar esta pestaña. Usa un Chrome, Firefox, Safari o Edge actual.',
			'notices.webStorageUnreliable' => 'Este navegador está usando un almacenamiento de respaldo que no es seguro con varias pestañas — mantén una sola pestaña abierta, y la sincronización activada.',
			'notices.logFromNewerBuildTitle' => 'Este log necesita una versión más nueva',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Tu log lo escribió una versión más nueva de HaLo (versión de almacenamiento ${storage}; esta entiende la ${understood}), así que no se puede abrir y los contactos nuevos no se guardarán. Vuelve a instalar la versión más nueva o, si querías usar este build, apúntalo a otra carpeta de datos. El log está en ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Tu log lo escribió una versión más nueva de HaLo (versión de almacenamiento ${storage}; esta entiende la ${understood}), así que no se puede abrir y los contactos nuevos no se guardarán. Ábrelo con esa versión más nueva.',
			'notices.preferencesRestoredTitle' => 'Configuración restaurada desde un respaldo',
			'notices.preferencesRestored' => 'No se pudo leer el archivo de configuración, así que HaLo restauró la última copia buena. Puede que tengas que volver a configurar lo que cambiaste en la sesión anterior. El archivo ilegible se conserva junto a ella, con el nombre shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Configuración restablecida',
			'notices.preferencesReset' => 'No se pudo leer el archivo de configuración y no había ningún respaldo al que recurrir, así que HaLo empezó con sus valores por defecto. El archivo ilegible se conserva en la carpeta de datos de la app, con el nombre shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} no se conectó automáticamente',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo dejó de responder la última vez que empezó a conectarse a ${name}, así que esta vez no lo intentó para no repetirlo. Comprueba que la radio esté encendida y su cable conectado, y luego pulsa Conectar en ella dentro de Configuración.',
			'syncAccount.anonymous' => ({required Object id}) => 'Cuenta Anónima (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (pendiente de confirmación)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (pendiente de confirmación - #${id})',
			'deepLink.needsAnOperation' => 'Inicia una operación primero, y vuelve a enviar ese contacto',
			'deepLink.waitingInOperation' => 'Ese contacto está esperando en la operación detrás de esta pantalla',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Este dispositivo no tiene la actividad ${refs}, así que esas referencias quedaron fuera',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'No se pudo consultar tus actividades, así que ${refs} quedó fuera — reintenta ese enlace',
			'confirmDevice.title' => 'Confirmar un dispositivo',
			'confirmDevice.codePrompt' => 'Ingresa el código que muestra el dispositivo que quiere unirse a esta cuenta.',
			'confirmDevice.code' => 'Código',
			'confirmDevice.lookUp' => 'Buscar',
			'confirmDevice.codeNotFound' => 'Ninguna solicitud coincide con ese código. Los códigos caducan a los 10 minutos — pide uno nuevo en el otro dispositivo.',
			'confirmDevice.linkExpired' => 'Ese enlace ha caducado. Pide al otro dispositivo que muestre un código QR nuevo.',
			'confirmDevice.areYouSure' => ({required Object device}) => '¿Vincular ${device} a esta cuenta?',
			'confirmDevice.unnamedDevice' => 'un dispositivo sin nombre',
			'confirmDevice.grantWarning' => 'Podrá leer y modificar todas las operaciones y QSOs de esta cuenta.',
			'confirmDevice.needsSyncTitle' => 'Este dispositivo aún no sincroniza',
			'confirmDevice.needsSyncText' => 'Activa la sincronización con Ham2K Log Filer y vincula este dispositivo a una cuenta antes de que pueda admitir a otro.',
			'confirmDevice.malformedRequest' => 'El servidor envió una solicitud que esta app no pudo leer. Pide al otro dispositivo que lo intente de nuevo.',
			'confirmDevice.linkIt' => 'Vincular dispositivo',
			'switchAccounts.noAccountDetails' => 'Aún sin detalles de la cuenta',
			'switchAccounts.currentAccount' => 'Cuenta actual',
			'switchAccounts.otherAccounts' => 'Otras cuentas',
			'switchAccounts.linkToAnother' => 'Vincular a otra cuenta',
			'switchAccounts.linkWithSibling' => 'Vincular con otra app de Ham2K',
			'switchAccounts.linkWithPolo' => 'Vincular con la cuenta de la versión anterior',
			'switchAccounts.linkWithSiblingDescription' => 'Tienes otra app de Ham2K instalada. Vincula con la cuenta en uso allí.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Aprueba la solicitud en ${app} y luego vuelve aquí.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Abrir ${app} de nuevo',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingNoGrant' => '¿No funcionó? Ábrela de nuevo, o vuelve atrás y vincula de otra manera.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'No se pudo abrir ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'El enlace caducó y hay uno nuevo — abre ${app} de nuevo.',
			'switchAccounts.tryAgain' => 'Intentar de nuevo',
			'switchAccounts.linkWithQr' => 'Vincular con un código QR',
			'switchAccounts.linkWithQrDescription' => 'Escanéalo desde un dispositivo que ya use la cuenta',
			'switchAccounts.linkWithEmail' => 'Vincular con una dirección de correo electrónico',
			'switchAccounts.linkWithEmailDescription' => 'Confirma con un código o un enlace por correo electrónico',
			'switchAccounts.enterEmailPrompt' => 'Ingresa la dirección de correo electrónico de la cuenta que quieres usar en este dispositivo.',
			'switchAccounts.emailAddress' => 'Dirección de correo electrónico',
			'switchAccounts.linkAccount' => 'Vincular cuenta',
			'switchAccounts.copiedCode' => 'Código copiado al portapapeles',
			'switchAccounts.copyCode' => 'Copiar código',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Abre la app de Ham2K en un dispositivo ya vinculado con ${email} e ingresa este código para aprobar la solicitud:',
			'switchAccounts.waitingForConfirmation' => 'Esperando confirmación…',
			'switchAccounts.sendEmailInstead' => 'Enviar un correo de confirmación en su lugar',
			'switchAccounts.emailSent' => ({required Object email}) => 'Se envió un correo a ${email}. Ábrelo y confirma la solicitud para vincular este dispositivo.',
			'switchAccounts.resendEmail' => 'Reenviar correo',
			'switchAccounts.qrPrompt' => 'Escanea este código QR desde un dispositivo ya vinculado a la cuenta que quieres — por ejemplo, con Ham2K Portable Logger en tu teléfono.',
			'switchAccounts.serverUnreachable' => 'No se pudo acceder al servidor de sincronización. Inténtalo más tarde.',
			'switchAccounts.emailRequired' => 'Ingresa una dirección de correo electrónico para vincular.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'No se encontró ninguna cuenta para ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'El servidor de sincronización rechazó la solicitud: ${error}',
			'switchAccounts.noLinkCode' => 'El servidor de sincronización no devolvió un código de vinculación. Inténtalo más tarde.',
			'switchAccounts.noConfirmationCode' => 'El servidor de sincronización no envió un código de confirmación. Inténtalo más tarde.',
			'switchAccounts.switchNotAccepted' => 'Esa cuenta no aceptó el cambio. Prueba a vincularla con una dirección de correo electrónico.',
			'switchAccounts.requestFailed' => 'Algo salió mal al comunicarse con el servidor de sincronización. Inténtalo más tarde.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} operación', other: '${count} operaciones', ), 
			'qsonImport.title' => 'Importar operación QSON',
			'qsonImport.description' => 'Crea una nueva operación a partir de un archivo QSON, como los que exporta el Modo Desarrollador aquí o en PoLo.',
			'qsonImport.dropHint' => 'Suelta un archivo QSON para importarlo como una nueva operación',
			'qsonImport.importing' => ({required Object filename}) => 'Importando ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'No se pudo importar ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'No se pudo abrir un archivo para importar: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} no es texto UTF-8, así que no es un archivo QSON',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} no es un archivo JSON, así que no es un archivo QSON',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} no contiene una operación QSON',
			'qsonImport.busy' => 'Ya hay una importación en curso. Espera a que termine antes de empezar otra.',
			'qsonImport.oneFileOnly' => 'Suelta un archivo QSON a la vez — cada uno se abre como su propia operación.',
			'adifImport.title' => 'Importar QSOs desde ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Leyendo ${filename}…',
			'adifImport.dropHint' => 'Suelta un archivo ADIF para importarlo',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} QSO en este archivo', other: '${formatted} QSOs en este archivo', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} ya está en tu log', other: '${formatted} ya están en tu log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} se importará', other: '${formatted} se importarán', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} contacto nuevo', other: '${formatted} contactos nuevos', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} se combinará con un contacto existente', other: '${formatted} se combinarán con contactos existentes', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} no se puede importar (sin indicativo)', other: '${formatted} no se pueden importar (sin indicativo)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} requiere revisión', other: '${formatted} requieren revisión', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'No se pudieron recuperar las referencias de ${count} contacto', other: 'No se pudieron recuperar las referencias de ${formatted} contactos', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Las referencias de ${programs} pueden estar incompletas en ${count} contacto', other: 'Las referencias de ${programs} pueden estar incompletas en ${formatted} contactos', ), 
			'adifImport.stackingTypesUnknown' => 'Los contactos combinados podrían perder una referencia: las actividades no pudieron indicar qué tipos se acumulan. Cancela y reinténtalo para evitarlo.',
			'adifImport.nothingToImport' => 'No hay nada importable en este archivo',
			'adifImport.confirm' => 'Importar',
			'adifImport.importing' => ({required Object filename}) => 'Importando ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: 'Se importó ${count} contacto desde ${filename}', other: 'Se importaron ${formatted} contactos desde ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'No se pudo importar ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} no parece un archivo ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Atención: este ADIF tiene QSOs de ${calls}, pero se importarán como ${station} si continúas.',
			'adifImport.stationCallJoin' => ' y ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(count, one: '${count} no tiene fecha y no se puede importar', other: '${formatted} no tienen fecha y no se pueden importar', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Este archivo registra una activación de ${refs}.',
			'adifImport.addActivation' => 'Agregarla a esta operación',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Solo se aplicaron ${written} de ${planned} — el log cambió mientras decidías.',
			'adifImport.busy' => 'Ya hay una importación en curso. Espera a que termine antes de empezar otra.',
			'adifImport.oneFileOnly' => 'Suelta un archivo ADIF a la vez — el orden en que se importan decide qué datos prevalecen.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} tiene más de ${limit} QSOs, el máximo que una operación puede importar a la vez.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename} tiene más de ${limit} QSOs. Importar un ADIF en una operación está pensado para agregar unos pocos QSOs, no para traer un log grande — usa la vista de Logs para eso. El modo desarrollador te permite importarlo de todos modos, si estás seguro.',
			'adifImport.importAnyway' => 'Importar de todos modos',
			'offline.statusOffline' => 'Internet: SIN CONEXIÓN',
			'offline.statusOnline' => 'Internet: conectado',
			'offline.noRoute' => 'No hay ninguna conexión de red.',
			'offline.unreachable' => 'La red está activa, pero ningún servidor responde — a menudo es una página de inicio de sesión esperando en un navegador.',
			'offline.reachable' => 'Todos los servicios responden con normalidad.',
			'offline.whatStops' => 'Las búsquedas, los spots y los archivos de datos están en pausa. El logging y la sincronización cercana, no.',
			'offline.servicesTitle' => 'Servicios',
			'offline.noServices' => 'Todavía no ha respondido ningún servicio.',
			'offline.lastSuccess' => ({required Object when}) => 'Respondió por última vez hace ${when}',
			'offline.neverSucceeded' => 'Todavía no ha respondido',
			'offline.nextAttempt' => ({required Object when}) => 'Próximo intento en ${when}',
			'offline.nextAttemptNow' => 'Próximo intento pendiente',
			'offline.retry' => 'Reintentar ahora',
			'offline.retrying' => 'Intentando…',
			'offline.retryReached' => 'Conexión restablecida.',
			'offline.retryUnreachable' => 'Sigue sin responder.',
			'offline.retryNotAttempted' => 'No hay nada que enviar ahora mismo.',
			'offline.retryThrottled' => 'Acabas de intentarlo — espera un momento.',
			'offline.retryDisabled' => 'La sincronización está apagada, así que no hay con qué sondear.',
			'offline.syncService' => 'Sincronización Ham2K LoFi',
			'offline.retryInFlight' => 'Ya se está intentando — un momento.',
			'exportSettings.defaultsDescription' => 'Configuración base para todas las exportaciones, con plantillas de nombre de archivo y título separadas para actividades de referencia y otras actividades. Cada tipo de exportación puede proporcionar sus propios valores por defecto o configuración personalizada.',
			'exportSettings.referenceActivities' => 'Actividades de Referencia',
			'exportSettings.otherActivities' => 'Otras Actividades',
			'exportSettings.adifFields' => 'Campos ADIF',
			'exportSettings.loadFailed' => 'No se pudo cargar la configuración de exportación.',
			'exportSettings.retry' => 'Reintentar',
			'exportSettings.compactFileNamesDescriptionOn' => 'Nombres compactos, como N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Nombres descriptivos, como 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Incluyendo nombres, direcciones, correos, notas y ubicaciones precisas en los archivos ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Omitiendo nombres, direcciones, correos y notas; limitando las ubicaciones a grillas de seis caracteres.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Incluyendo la información de los servicios de búsqueda de indicativos.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Omitiendo la información de los servicios de búsqueda de indicativos; conservando los valores ingresados manualmente.',
			'exportSettings.customTemplatesDescriptionOn' => 'Tus plantillas personalizadas están activas y se pueden editar a continuación.',
			'exportSettings.customTemplatesDescriptionOff' => 'Se usan las plantillas por defecto. Tus plantillas personalizadas se conservan para más adelante.',
			'exportSettings.type' => 'Tipo de exportación',
			'exportSettings.defaults' => 'Por defecto',
			'exportSettings.includeLookupData' => 'Incluir datos de búsqueda',
			'exportSettings.customTemplates' => 'Plantillas personalizadas',
			'exportSettings.filenameTemplate' => 'Plantilla de Nombre de Archivo',
			'exportSettings.compactFilenameTemplate' => 'Plantilla de nombre de archivo compacto',
			'exportSettings.titleTemplate' => 'Plantilla de Título',
			'exportSettings.adifNotesTemplate' => 'Notas de QSO en ADIF',
			'exportSettings.adifCommentTemplate' => 'Comentarios de QSO en ADIF',
			'exportSettings.adifQslMessageTemplate' => 'Mensaje de QSL en ADIF',
			'exportSettings.shared' => 'La configuración se aplica a todas las extensiones que usan este tipo de exportación.',
			'exportSettings.defaultTemplates' => 'Activa Plantillas personalizadas para editar las plantillas de este tipo.',
			'templateEditor.previewLabel' => 'Vista previa:',
			'templateEditor.reset' => 'Restablecer',
			'templateEditor.docs' => 'Documentación de plantillas',
			'templateEditor.preview' => 'Vista previa de ejemplo',
			'templateEditor.reference' => 'Referencia de plantillas',
			'templateEditor.attributes' => 'Atributos disponibles',
			'templateEditor.filters' => 'Filtros',
			'templateEditor.flowControl' => 'Control de flujo',
			'templateEditor.unavailable' => 'La vista previa no está disponible hasta que las extensiones estén listas.',
			'templateEditor.empty' => '(resultado vacío)',
			_ => null,
		};
	}
}
