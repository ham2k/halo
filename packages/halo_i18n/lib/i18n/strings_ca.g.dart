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
class TranslationsCa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsCa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ca,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ca>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsCa _root = this; // ignore: unused_field

	@override 
	TranslationsCa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsCa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ca common = _Translations$common$ca._(_root);
	@override late final _Translations$onboarding$ca onboarding = _Translations$onboarding$ca._(_root);
	@override late final _Translations$startScreen$ca startScreen = _Translations$startScreen$ca._(_root);
	@override late final _Translations$testerOverlay$ca testerOverlay = _Translations$testerOverlay$ca._(_root);
	@override late final _Translations$extensionsPanel$ca extensionsPanel = _Translations$extensionsPanel$ca._(_root);
	@override late final _Translations$home$ca home = _Translations$home$ca._(_root);
	@override late final _Translations$chase$ca chase = _Translations$chase$ca._(_root);
	@override late final _Translations$dialogs$ca dialogs = _Translations$dialogs$ca._(_root);
	@override late final _Translations$operation$ca operation = _Translations$operation$ca._(_root);
	@override late final _Translations$map$ca map = _Translations$map$ca._(_root);
	@override late final _Translations$mapsView$ca mapsView = _Translations$mapsView$ca._(_root);
	@override late final _Translations$activitiesView$ca activitiesView = _Translations$activitiesView$ca._(_root);
	@override late final _Translations$loggingControls$ca loggingControls = _Translations$loggingControls$ca._(_root);
	@override late final _Translations$formChrome$ca formChrome = _Translations$formChrome$ca._(_root);
	@override late final _Translations$qsoEditForm$ca qsoEditForm = _Translations$qsoEditForm$ca._(_root);
	@override late final _Translations$qsoList$ca qsoList = _Translations$qsoList$ca._(_root);
	@override late final _Translations$loggingPanel$ca loggingPanel = _Translations$loggingPanel$ca._(_root);
	@override late final _Translations$callInfo$ca callInfo = _Translations$callInfo$ca._(_root);
	@override late final _Translations$settings$ca settings = _Translations$settings$ca._(_root);
	@override late final _Translations$commands$ca commands = _Translations$commands$ca._(_root);
	@override late final _Translations$commandDialog$ca commandDialog = _Translations$commandDialog$ca._(_root);
	@override late final _Translations$keyboardShortcuts$ca keyboardShortcuts = _Translations$keyboardShortcuts$ca._(_root);
	@override late final _Translations$expiredBuild$ca expiredBuild = _Translations$expiredBuild$ca._(_root);
	@override late final _Translations$staleness$ca staleness = _Translations$staleness$ca._(_root);
	@override late final _Translations$spotting$ca spotting = _Translations$spotting$ca._(_root);
	@override late final _Translations$dataFiles$ca dataFiles = _Translations$dataFiles$ca._(_root);
	@override late final _Translations$updates$ca updates = _Translations$updates$ca._(_root);
	@override late final _Translations$extensionService$ca extensionService = _Translations$extensionService$ca._(_root);
	@override late final _Translations$operationLocationScreen$ca operationLocationScreen = _Translations$operationLocationScreen$ca._(_root);
	@override late final _Translations$versionLabel$ca versionLabel = _Translations$versionLabel$ca._(_root);
	@override late final _Translations$notices$ca notices = _Translations$notices$ca._(_root);
	@override late final _Translations$syncAccount$ca syncAccount = _Translations$syncAccount$ca._(_root);
	@override late final _Translations$deepLink$ca deepLink = _Translations$deepLink$ca._(_root);
	@override late final _Translations$confirmDevice$ca confirmDevice = _Translations$confirmDevice$ca._(_root);
	@override late final _Translations$switchAccounts$ca switchAccounts = _Translations$switchAccounts$ca._(_root);
	@override late final _Translations$qsonImport$ca qsonImport = _Translations$qsonImport$ca._(_root);
	@override late final _Translations$adifImport$ca adifImport = _Translations$adifImport$ca._(_root);
	@override late final _Translations$offline$ca offline = _Translations$offline$ca._(_root);
	@override late final _Translations$exportSettings$ca exportSettings = _Translations$exportSettings$ca._(_root);
	@override late final _Translations$templateEditor$ca templateEditor = _Translations$templateEditor$ca._(_root);
}

// Path: common
class _Translations$common$ca extends Translations$common$en {
	_Translations$common$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get save => 'Desa';
	@override String get ok => 'D\'acord';
	@override String get cancel => 'Cancel·la';
	@override String get delete => 'Esborra';
	@override String get create => 'Crea';
	@override String get error => 'Error';
	@override String get close => 'Tanca';
	@override String get done => 'Fet';
	@override String get callsign => 'Indicatiu';
	@override String get clear => 'Neteja';
	@override String get dismiss => 'Descarta';
	@override String get copyDetails => 'Copia els detalls';
	@override String get expand => 'Desplega';
	@override String get collapse => 'Plega';
}

// Path: onboarding
class _Translations$onboarding$ca extends Translations$onboarding$en {
	_Translations$onboarding$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Et donem la benvinguda a Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Et donem la benvinguda a Ham2K Power Logger!';
	@override String get welcomeBody => 'Tenim unes quantes preguntes per adaptar-nos millor a les teves necessitats.';
	@override String get skip => 'Omet';
	@override String get kContinue => 'Continua';
	@override String get back => 'Enrere';
	@override String get next => 'Següent';
	@override String get done => 'Fet';
	@override String get callsignTitle => 'Quin és el teu indicatiu?';
	@override String get callsignBody => 'Necessites una llicència de radioaficionat perquè aquesta aplicació et sigui útil';
	@override String get callsignLabel => 'Indicatiu de l\'operador';
	@override String get alreadyHaveAccount => 'Ja tens un compte?';
	@override String get foundSiblingTitle => 'Vincular un compte existent?';
	@override String foundSiblingBody({required Object app}) => 'Hem trobat ${app} en aquest dispositiu. Vincula aquesta aplicació al mateix compte i hi arribaran el teu indicatiu i els teus registres.';
	@override String get foundPoloBody => 'Hem trobat una versió anterior de Ham2K Portable Logger en aquest dispositiu. Vincula aquesta aplicació al mateix compte i hi arribaran el teu indicatiu i els teus registres.';
	@override String get foundSiblingsBody => 'Hem trobat altres aplicacions de Ham2K en aquest dispositiu. Vincula aquesta aplicació al compte d\'una d\'elles i hi arribaran el teu indicatiu i els teus registres.';
	@override String linkWithApp({required Object app}) => 'Vincula amb ${app}';
	@override String get linkWithPolo => 'Vincula amb el compte de la versió anterior';
	@override String get setUpFresh => 'Configura de zero';
	@override String get activitiesTitle => 'Activitats preferides';
	@override String get activitiesBody => 'T\'interessa algun d\'aquests programes d\'activació populars?';
	@override String get activitiesFooter => '(Trobaràs més opcions a la Configuració)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'Sincronització al núvol';
	@override String get syncBody => 'Ham2K Log Filer guarda una còpia de seguretat dels teus registres al núvol i els sincronitza entre tots els dispositius on facis servir aplicacions de Ham2K.';
	@override String get syncPricing => 'És gratuït! Però amb una subscripció de pagament anirà més ràpid.';
	@override String get syncLabel => 'Activa la sincronització al núvol';
	@override String get syncOffWarning => 'ATENCIÓ: això augmenta el risc de perdre dades d\'operació, per exemple si el dispositiu falla o es perd.';
	@override String get notNow => 'Ara no';
	@override String get consentTitle => 'Dades i privacitat';
	@override String get consentUsageBody => 'Per ajudar-nos a millorar l\'aplicació, ens agradaria recollir dades de rendiment, fallades i ús de l\'aplicació.';
	@override String get consentUsageLabel => 'Comparteix dades d\'ús de l\'aplicació';
	@override String get consentOperationBody => 'Algunes funcions poden implicar compartir les teves dades d\'operació amb altres usuaris. Pots desactivar-ho en qualsevol moment.';
	@override String get consentOperationLabel => 'Comparteix dades d\'operació';
	@override String get finishingSetup => 'Acabant la configuració: descarregant dades de referència…';
}

// Path: startScreen
class _Translations$startScreen$ca extends Translations$startScreen$en {
	_Translations$startScreen$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get credits => 'per KI2D i amics';
}

// Path: testerOverlay
class _Translations$testerOverlay$ca extends Translations$testerOverlay$en {
	_Translations$testerOverlay$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get tape => 'ATENCIÓ: EN CONSTRUCCIÓ';
	@override String get warningTitle => 'Aquesta aplicació està en desenvolupament';
	@override String get warningBody => 'La majoria de funcions tenen el terra irregular i hi ha perill d\'ensopegar arreu. Comprova si hi ha actualitzacions regularment.';
	@override String whatsNew({required Object build}) => 'Novetats de la versió ${build}';
	@override String get thanks => 'Gràcies per arriscar el teu registre per ajudar-nos a millorar aquesta aplicació!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$ca extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Activitats';
	@override String get categoryAward => 'Diplomes';
	@override String get categoryContest => 'Concursos';
	@override String get categoryLookup => 'Consultes d\'indicatius';
	@override String get categorySpots => 'Fonts d\'anuncis';
	@override String get categoryDashboard => 'Panells del tauler';
	@override String get categoryOther => 'Altres extensions';
	@override String get searchHint => 'Cerca extensions';
	@override String get applying => 'Activant els canvis d\'extensions, això pot trigar un moment…';
	@override String get noMatches => 'Cap extensió coincideix amb la cerca';
	@override String get installFromFile => 'Instal·la des d\'un fitxer…';
	@override String installVersion({required Object version}) => 'Versió ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'Captura ${n} de ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'Captura anterior';
	@override String get nextScreenshot => 'Captura següent';
	@override String get screenshotUnavailable => 'Captura no disponible';
	@override String get canReach => 'Aquesta extensió pot contactar amb';
	@override String canHoldConnection({required Object host}) => '${host}, amb una connexió activa';
	@override String get canHoldLocalConnection => 'Dispositius de la teva xarxa local, amb una connexió activa';
	@override String get canUseLocation => 'La teva ubicació';
	@override String get canReadRadio => 'La teva ràdio, per llegir-ne la freqüència i el mode';
	@override String get canControlRadio => 'La teva ràdio, per controlar-la i transmetre-hi — sintonia, potència, CW, memòries de veu i PTT';
	@override String get canCommandRadioRaw => 'La teva ràdio, per enviar-li qualsevol ordre en el seu propi protocol — incloses les que transmeten o en canvien la configuració';
	@override String get canReadCluster => 'El clúster DX, amb la teva sessió iniciada, per llegir el que envia';
	@override String get canSpotCluster => 'El clúster DX, amb la teva sessió iniciada, per publicar anuncis en nom teu';
	@override String get canCommandCluster => 'El clúster DX, amb la teva sessió iniciada, per enviar-li qualsevol ordre en nom teu';
	@override String get canSetUserAgent => 'Identificar-se davant dels servidors amb el seu propi nom';
	@override String get canChangeSettings => 'La teva configuració, per canviar-la amb les seves ordres: qualsevol opció, el mode de desenvolupador i els experiments';
	@override String get noCapabilities => 'No demana res fora de l\'aplicació.';
	@override String get sandboxNote => 'Les extensions s\'executen aïllades: sense accés als teus fitxers i sense xarxa més enllà del que s\'indica aquí.';
	@override String get installAction => 'Instal·la';
	@override String get updateAction => 'Actualitza';
	@override String get installFailed => 'No s\'ha pogut instal·lar aquesta extensió';
	@override String get installedBadge => 'Instal·lada';
	@override String get uninstallAction => 'Elimina';
	@override String uninstallTitle({required Object name}) => 'Eliminar ${name}?';
	@override String get uninstallBody => 'S\'eliminaran aquesta extensió i la seva configuració. Els teus registres no es tocaran.';
	@override String installedMessage({required Object name}) => 'S\'ha instal·lat ${name}';
	@override String get installDownloading => 'Descarregant…';
	@override String get installWaiting => 'Esperant per instal·lar…';
	@override String get installInstalling => 'Instal·lant…';
	@override String get installAwaitingApproval => 'Esperant la teva aprovació…';
	@override String installAlreadyRunning({required Object name}) => '${name} ja s\'està instal·lant.';
	@override String updatedTo({required Object version}) => 'Actualitzada a ${version}';
	@override String installIncomplete({required Object name}) => 'La instal·lació de ${name} no ha acabat. Potser cal tornar-la a instal·lar.';
	@override String uninstallFailed({required Object name}) => 'No s\'ha pogut eliminar ${name}';
	@override String installedFrom({required Object source}) => 'Descarregada de ${source}';
	@override String get dropHint => 'Deixa anar una extensió .h2kext per instal·lar-la';
	@override String get dropOneOnly => 'Deixa anar les extensions d\'una en una.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} ha retornat ${status} per a aquesta extensió.';
	@override String get downloadTooLarge => 'Aquesta descàrrega és massa gran per ser una extensió.';
	@override String get downloadNotSecure => 'Aquesta descàrrega ha redirigit a un lloc insegur.';
	@override String get catalogSection => 'Catàleg';
	@override String get catalogLoading => 'Carregant el catàleg…';
	@override String get catalogUnreachable => 'Catàleg inaccessible';
	@override String get builtIn => 'Integrada';
	@override String get updateAvailableBadge => 'Actualització disponible';
	@override String get updatesAvailableTitle => 'Actualitzacions d\'extensions';
	@override String updateAvailableFor({required Object name}) => 'Hi ha una actualització disponible per a ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => 'Cal actualitzar ${names} i ${count} més.';
	@override String updatesAvailableFor({required Object names}) => 'Cal actualitzar ${names}.';
	@override String get pendingUpdatesSection => 'Actualitzacions pendents';
	@override String get updateAllAction => 'Actualitza-ho tot';
	@override String get updatesUnderWay => 'Aquestes actualitzacions ja estan en curs.';
	@override String get updatesNothingLeft => 'Les teves extensions estan al dia.';
	@override String get updatesNoticeAction => 'Més informació';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Actualitzar ${count} extensió?',
		other: 'Actualitzar ${count} extensions?',
	);
	@override String get upgradeDoneTitle => 'Les teves extensions estan a punt';
	@override String get upgradeDoneBody => 'Ara provenen del catàleg d\'extensions de Ham2K, de manera que es poden actualitzar sense esperar una nova versió de l\'aplicació.';
	@override String upgradeDoneUnserved({required Object names}) => 'No actualitzades: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'No s\'han executat: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Continuen instal·lades i marcades a Configuració › Extensions; si les actualitzes allà, tornaran a funcionar.';
	@override String get upgradeDoneUnservedHint => 'El catàleg no té cap substitut directe per a aquestes, així que busca-hi extensions que cobreixin el que feies servir.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Esdeveniments de parcs estatals';
	@override String upgradeDoneMissing({required Object count}) => '${count} de les teves extensions encara no han arribat. Es descarregaran la propera vegada que es pugui accedir al catàleg d\'extensions.';
	@override String get runtimeDeadBody => 'Les teves extensions no s\'han iniciat. Reiniciar l\'aplicació hauria de recuperar-les.';
	@override String get refusedTitle => 'Algunes extensions no s\'han executat';
	@override String get upgradeBusyTitle => 'Encara s\'està configurant';
	@override String get upgradeRuntimeDeadTitle => 'Les teves extensions no s\'estan executant';
	@override String get restoreTitle => 'Falten algunes de les teves extensions';
	@override String get restoreBody => 'Aquestes extensions que vas instal·lar no són en aquest dispositiu. Les podem tornar a descarregar del catàleg d\'extensions de Ham2K:';
	@override String get restoreFromFile => 'Instal·lades des d\'un fitxer. Torna-les a instal·lar des dels seus fitxers, o oblida-les:';
	@override String get restoreOtherCatalog => 'Instal·lades des d\'un altre catàleg d\'extensions, així que no estan disponibles aquí:';
	@override String get restoreForget => 'Oblida';
	@override String get restoreInstall => 'Instal·la';
	@override String get restoreLater => 'Més tard';
	@override String get restoreInstalling => 'Instal·lant les teves extensions…';
	@override String get restoreDoneTitle => 'Les teves extensions han tornat';
	@override String restoreDoneBody({required Object names}) => 'Instal·lades de nou: ${names}.';
	@override String get restorePartialTitle => 'No s\'han pogut instal·lar algunes extensions';
	@override String restoreFailed({required Object names}) => 'No s\'han pogut instal·lar: ${names}. Te les tornarem a oferir la propera vegada que obris l\'aplicació.';
	@override String get restoreBusyBody => 'L\'aplicació encara està configurant les teves extensions. Te les tornarem a oferir la propera vegada que obris l\'aplicació.';
	@override String get restoreRuntimeDeadBody => 'Les hem tornat a instal·lar, però les teves extensions no s\'han iniciat. Reiniciar l\'aplicació hauria de recuperar-les.';
	@override String revokedTitle({required Object name}) => '${name} s\'ha retirat';
	@override String get revokedBody => 'El catàleg ha retirat aquesta versió, així que s\'ha desactivat.';
	@override String forceDisabledTitle({required Object name}) => '${name} s\'ha desactivat';
	@override String get forceDisabledBody => 'Ham2K ha desactivat aquesta extensió de moment.';
	@override String replacedTitle({required Object name}) => '${name} s\'ha substituït';
	@override String replacedBody({required Object replacement}) => '${replacement} ocupa el seu lloc. Pots fer el canvi a Extensions.';
	@override String replacedBy({required Object name}) => 'Substituïda per ${name}';
	@override String replacedByInstalled({required Object name}) => 'Substituïda per ${name}, que ja tens';
	@override String get replaceAction => 'Substitueix';
	@override String replaceInstalledBody({required Object replacement}) => 'La seva configuració passa a ${replacement}, que ja tens. Els teus registres no es tocaran.';
	@override String get downloadHashMismatch => 'Aquesta descàrrega no és l\'extensió que descriu el catàleg.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'El catàleg no té la versió ${version} de ${key}.';
	@override String get catalogLinkUnknown => 'Aquest enllaç del catàleg no indica cap versió d\'extensió.';
	@override String catalogNoRelease({required Object key}) => 'El catàleg no té cap versió de ${key} en aquesta branca.';
	@override String get installFromLink => 'Instal·la des d\'un enllaç';
	@override String get unstableReleaseWarning => 'Aquesta és una versió inestable, que el seu editor no dona per acabada. Pot fallar i continuarà rebent actualitzacions inestables.';
	@override String get bleedingReleaseWarning => 'Aquesta és una versió experimental: feina en curs que pot trencar-se o perdre la configuració. Continuarà rebent actualitzacions experimentals.';
	@override String get channelUnstable => 'Inestable';
	@override String get channelBleeding => 'Experimental';
	@override String get followsUnstable => 'Rep versions inestables i estables';
	@override String get followsBleeding => 'Rep versions experimentals, inestables i estables';
	@override String get followStableAction => 'Segueix només les versions estables';
	@override String get revokedBadge => 'Retirada';
	@override String get forceDisabledBadge => 'Desactivada per Ham2K';
	@override String get refusedBadge => 'No s\'ha carregat';
	@override String get downloadNotHttps => 'Aquesta descàrrega no fa servir una connexió segura.';
	@override String downloadUnreachable({required Object source}) => 'No s\'ha pogut contactar amb ${source} per a aquesta extensió.';
	@override String get detailsAction => 'Detalls';
	@override String get installedFromFile => 'Instal·lada des d\'un fitxer';
	@override String get detailsWhatItDoes => 'Proporciona suport per a';
	@override String get installedPreloaded => 'Preinstal·lada';
	@override String get hookAccount => 'Inici de sessió de compte';
	@override String get hookCallNotes => 'Notes d\'indicatius';
	@override String get hookDataFile => 'Dades fora de línia';
	@override String get hookExport => 'Exportació';
	@override String get hookLookup => 'Consultes d\'indicatius';
	@override String get hookScoring => 'Puntuació';
	@override String get hookSpots => 'Anuncis';
	@override String hookHunting({required Object program}) => 'Caça de ${program}';
	@override String hookActivating({required Object program}) => 'Activació de ${program}';
	@override String get suggestedSection => 'Suggerides';
	@override String moreAvailableSection({required Object count}) => 'Més disponibles (${count})';
}

// Path: home
class _Translations$home$ca extends Translations$home$en {
	_Translations$home$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registrador Portàtil';
	@override String get newOperation => 'Nova operació';
	@override String get stationCallsign => 'Indicatiu d\'estació';
	@override String get titleOptional => 'Títol (opcional)';
	@override String get emptyList => 'Encara no hi ha operacions. Crea\'n una per començar a registrar.';
	@override String get quickLookup => 'Cerca ràpida';
	@override late final _Translations$home$nav$ca nav = _Translations$home$nav$ca._(_root);
	@override late final _Translations$home$panels$ca panels = _Translations$home$panels$ca._(_root);
	@override String get toggleNav => 'Mostra o amaga les etiquetes de navegació';
	@override late final _Translations$home$logs$ca logs = _Translations$home$logs$ca._(_root);
}

// Path: chase
class _Translations$chase$ca extends Translations$chase$en {
	_Translations$chase$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'caçant';
	@override String goalsTwo({required Object first, required Object second}) => '${first} i ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} i més';
	@override late final _Translations$chase$station$ca station = _Translations$chase$station$ca._(_root);
	@override late final _Translations$chase$periodInline$ca periodInline = _Translations$chase$periodInline$ca._(_root);
	@override late final _Translations$chase$periodStats$ca periodStats = _Translations$chase$periodStats$ca._(_root);
	@override late final _Translations$chase$period$ca period = _Translations$chase$period$ca._(_root);
	@override late final _Translations$chase$goals$ca goals = _Translations$chase$goals$ca._(_root);
	@override late final _Translations$chase$panels$ca panels = _Translations$chase$panels$ca._(_root);
	@override late final _Translations$chase$claims$ca claims = _Translations$chase$claims$ca._(_root);
	@override late final _Translations$chase$notice$ca notice = _Translations$chase$notice$ca._(_root);
	@override late final _Translations$chase$alerts$ca alerts = _Translations$chase$alerts$ca._(_root);
	@override String get checklists => 'Progrés de la caça';
	@override late final _Translations$chase$imports$ca imports = _Translations$chase$imports$ca._(_root);
}

// Path: dialogs
class _Translations$dialogs$ca extends Translations$dialogs$en {
	_Translations$dialogs$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Detalls de l\'operació';
	@override String get activities => 'Activitats';
	@override String get stationCallsign => 'Indicatiu d\'estació';
	@override String get advanced => 'Avançat';
	@override String get operatingPosition => 'Posició d\'operació (multiestació)';
	@override String get assistance => 'Assistència';
	@override String get assistanceDescription => 'Fes servir serveis d\'anuncis i altres fonts d\'informació';
	@override String get selfSpotting => 'Autoanunci';
	@override String get selfSpottingDescription => 'Permet les funcions que publiquen la teva pròpia freqüència';
	@override String disabledByRules({required Object rules}) => 'Desactivat per complir les normes de ${rules}';
	@override late final _Translations$dialogs$lookupDespiteAssistance$ca lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$ca._(_root);
	@override String get notes => 'Apunts';
	@override String get deleteOperationTitle => 'Esborra l\'operació';
	@override String get purgeTestsTitle => 'Purga les operacions de prova';
	@override String get purgeTestsBody => 'Això esborra permanentment aquestes operacions de prova i els seus QSOs. No es pot desfer.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'A més de ${count} contacte de prova que no pertany a cap operació.',
		other: 'A més de ${count} contactes de prova que no pertanyen a cap operació.',
	);
	@override String get purgeTestsAction => 'Purga';
	@override String get syncAllTitle => 'Substituir el registre d\'aquest dispositiu?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL fa una còpia de seguretat i esborra ${qsos} d\'aquest dispositiu, i després torna a descarregar el registre del compte des del servidor. La còpia de seguretat es queda a la base de dades d\'aquest dispositiu.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${n} QSO encara no s\'ha sincronitzat — el servidor no l\'ha rebut mai i NO es recuperarà.',
		other: '${n} QSOs encara no s\'han sincronitzat — el servidor no els ha rebut mai i NO es recuperaran.',
	);
	@override String get syncAllAction => 'Esborra i torna a sincronitzar';
	@override String get receivedPurgesTitle => 'Operacions de prova eliminades en un altre lloc';
	@override String get receivedPurgesBody => 'Aquestes s\'han esborrat com a operacions de prova en un altre dispositiu. Vols eliminar-les també aquí? Això les esborra permanentment juntament amb els seus QSOs, i no es pot desfer.';
	@override String get receivedPurgesAction => 'Elimina';
	@override late final _Translations$dialogs$callChange$ca callChange = _Translations$dialogs$callChange$ca._(_root);
}

// Path: operation
class _Translations$operation$ca extends Translations$operation$en {
	_Translations$operation$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Aquesta operació està esborrada. Restaura-la per registrar o fer canvis.';
	@override late final _Translations$operation$tabs$ca tabs = _Translations$operation$tabs$ca._(_root);
	@override late final _Translations$operation$positions$ca positions = _Translations$operation$positions$ca._(_root);
	@override String get stationCallsignNone => 'Sense indicatiu d\'estació';
	@override String get titleNone => 'Sense títol';
	@override String get deleteOperation => 'Esborra l\'operació';
	@override String get loggingControlsStale => 'Els camps d\'activitat poden estar desactualitzats — torna a obrir l\'operació per actualitzar-los';
	@override String get locationNone => 'Sense definir';
	@override String get generalOperation => 'Operació General';
	@override String titleFor({required Object value}) => 'per a ${value}';
	@override String titleAt({required Object value}) => 'a ${value}';
	@override String segmentNow({required Object description}) => 'Ara ${description}';
	@override String get testOperationSuffix => 'Prova';
	@override late final _Translations$operation$menu$ca menu = _Translations$operation$menu$ca._(_root);
	@override late final _Translations$operation$layout$ca layout = _Translations$operation$layout$ca._(_root);
	@override late final _Translations$operation$export$ca export = _Translations$operation$export$ca._(_root);
	@override late final _Translations$operation$spots$ca spots = _Translations$operation$spots$ca._(_root);
	@override late final _Translations$operation$import$ca import = _Translations$operation$import$ca._(_root);
}

// Path: map
class _Translations$map$ca extends Translations$map$en {
	_Translations$map$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$ca outlineIssue = _Translations$map$outlineIssue$ca._(_root);
	@override String get outlinesDisclaimer => 'Els contorns són només de referència. Fes la teva pròpia recerca!';
	@override String outlinesCredit({required Object sources}) => 'Contorns: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Límits: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Instal·lacions: ${sources}';
	@override String get fullCredits => 'Crèdits complets de les dades';
	@override String get fewerCredits => 'Menys crèdits';
	@override String get emptyState => 'Encara no hi ha ubicacions de QSOs.\nEls QSOs amb graella, estat o país apareixeran aquí.';
	@override String get unavailable => 'El mapa no està disponible ara mateix.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Pla';
	@override String get globe => 'Globus';
	@override String get zoomIn => 'Amplia';
	@override String get zoomOut => 'Redueix';
	@override String get resetNorth => 'Torna a orientar al nord';
	@override late final _Translations$map$postcard$ca postcard = _Translations$map$postcard$ca._(_root);
}

// Path: mapsView
class _Translations$mapsView$ca extends Translations$mapsView$en {
	_Translations$mapsView$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapes';
	@override String get searchHint => 'Cerca parcs, cims i més';
	@override String get activities => 'Activitats';
	@override String get layers => 'Capes';
	@override String get baseMap => 'Mapa base';
	@override String get satellite => 'Satèl·lit (Esri)';
	@override String get facilities => 'Instal·lacions dels parcs';
	@override String get boundaries => 'Límits';
	@override String get currentLocation => 'Ubicació actual';
	@override String noMatches({required Object text}) => 'Res coincideix amb “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} referència a ${where}',
		other: '${count} referències a ${where}',
	);
	@override String get startOperation => 'Inicia una operació amb aquestes referències';
}

// Path: activitiesView
class _Translations$activitiesView$ca extends Translations$activitiesView$en {
	_Translations$activitiesView$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activitats';
	@override String get activitiesCountZero => 'Cap activitat seleccionada';
	@override String get activitiesCountOne => '1 activitat';
	@override String activitiesCountOther({required Object count}) => '${count} activitats';
	@override String get empty => 'Encara no hi ha activitats — fes servir Suggeriments i cerca a sota per afegir-ne una';
	@override String get removeActivity => 'Elimina';
	@override String openReferenceLink({required Object name}) => 'Obre ${name}';
	@override String get editActivity => 'Edita l\'activitat';
	@override String get manageExtensions => 'Gestiona les extensions';
	@override String get manage => 'Gestiona';
	@override String activitiesTitle1({required Object first}) => 'Tipus d\'activitat: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipus d\'activitat: ${first} i ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipus d\'activitat: ${first}, ${second} i ${more} més';
	@override String get reference => 'Referència';
	@override String get invalidReference => 'No vàlida';
	@override String get duplicateReference => 'Ja afegida';
	@override String get searchHint => 'Cerca per nom, referència o qualsevol altra cosa…';
	@override String get noSuggestions => 'Cap coincidència';
	@override String get noSuggestionsHint => 'Cerca a dalt pel nom o el número de la referència';
	@override String get noSuggestionsExample => '(per exemple \'trail\' o \'4556\')';
	@override String get allOptions => 'Tipus d\'activitat';
	@override String get determiningLocation => 'Determinant la ubicació actual…\nEsperant la posició GPS per trobar referències properes';
	@override String get locationUnavailableTitle => 'Dades d\'ubicació no disponibles';
	@override String get locationDeniedTitle => 'Permís d\'ubicació denegat';
	@override String get locationBlockedTitle => 'Permís d\'ubicació bloquejat';
	@override String get noNearbyReason => 'No es poden determinar les referències properes';
	@override String locationManualHint({required Object icon}) => 'Toca ${icon} per introduir la teva ubicació manualment,\no simplement cerca referències pel nom';
	@override String get locationGrantAction => 'Permet l\'accés a la ubicació';
	@override String get locationSettingsAction => 'Obre la configuració';
	@override String get locationSettingsUnavailable => 'Permet l\'accés a la ubicació a la configuració del sistema';
	@override String get locationGrantRefused => 'Encara sense ubicació — el sistema ho ha tornat a denegar';
	@override String get searchUnavailableTitle => 'Cerca d\'activitats no disponible';
	@override String get searchUnavailableReason => 'Una extensió d\'activitat no ha pogut respondre la cerca. Torna-ho a provar d\'aquí a un moment.';
	@override String get emptySheet => 'Fes servir els suggeriments i la cerca a sota per afegir-ne una';
	@override String get exports => 'Exportacions';
	@override String get exportLogs => 'Exporta registres';
	@override String get tools => 'Eines';
	@override String get toolsTitle => 'Eines de l\'operació';
	@override String get operationDetails => 'Detalls de l\'operació';
	@override String get share => 'Comparteix';
	@override String get archive => 'Arxiva';
	@override String get deleteOperation => 'Esborra l\'operació';
	@override String get undeleteOperation => 'Restaura l\'operació';
	@override String get alreadySelected => 'Ja seleccionada';
	@override String get selected => 'Seleccionada';
	@override String pickPosition({required Object index, required Object count}) => '${index} de ${count}';
	@override String get previousPick => 'Coincidència anterior';
	@override String get nextPick => 'Coincidència següent';
	@override String get retiredReference => 'Retirada';
	@override String enableExtension({required Object name}) => 'Activa ${name}';
	@override String get enableExtensionHint => 'Aquesta extensió coincideix amb la cerca, però ara mateix no està activada';
	@override String get enableExtensionForRefHint => 'Aquesta extensió gestiona una de les referències d\'aquesta operació, però ara mateix no està activada';
	@override String extensionNotRunning({required Object name}) => '${name} no s\'està executant';
	@override String get extensionNotRunningHint => 'Aquesta extensió s\'ha desactivat; obre la configuració d\'extensions per a més informació';
	@override String installExtension({required Object name}) => 'Instal·la ${name}';
	@override String get installExtensionHint => 'Aquesta extensió coincideix amb la cerca, però no està instal·lada';
	@override String get onlyCatalogMatches => 'Cap coincidència\nAlgunes extensions del catàleg podrien tenir resultats.\nInstal·la-les a Tipus d\'activitat, a sota.';
	@override String get setupUnavailable => 'No s\'ha pogut carregar la configuració d\'aquesta activitat — torna-ho a provar des de Gestiona';
	@override String get controlsUnavailableTitle => 'Controls d\'activitat no disponibles';
	@override String get controlsUnavailableReason => 'Les teves referències estan segures, però ara mateix no es poden editar.';
	@override String get controlsUnavailableRetry => 'Torna-ho a provar';
	@override String get onlyDisabledMatches => 'Cap coincidència\nAlgunes extensions disponibles podrien tenir resultats.\nActiva-les a Tipus d\'activitat, a sota.';
	@override String get onlyNotRunningMatches => 'Cap coincidència\nAlgunes extensions que podrien tenir resultats no s\'estan executant.\nConsulta Tipus d\'activitat, a sota.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Cerca';
	@override String get addToOperation => 'Afegeix a l\'operació';
	@override String get addToOperationShort => 'Afegeix a l\'op.';
	@override String get mapEmptyState => 'No hi ha resultats per mostrar al mapa';
	@override String get mapEmptyStateHint => 'Torna a la llista, o cerca una altra cosa';
	@override String get imports => 'Importacions';
}

// Path: loggingControls
class _Translations$loggingControls$ca extends Translations$loggingControls$en {
	_Translations$loggingControls$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Data';
	@override String get now => 'Ara';
	@override String get manualTimeSettings => 'Hora manual';
	@override String get manualTimeIncrement => 'Increment per QSO';
	@override String get manualTimeIncrementNone => 'Cap';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} minut',
		other: '${count} minuts',
	);
	@override String get frequency => 'Freqüència';
	@override String get mode => 'Mode';
	@override String get theirCall => 'El seu indicatiu';
	@override String get noteField => 'Nota';
	@override String get todoField => 'Tasca';
	@override String get sent => 'Enviat';
	@override String get rcvd => 'Rebut';
	@override String get more => 'Més';
	@override String get revert => 'Desfés';
	@override String get undoDelete => 'Desfés l\'esborrat';
	@override String get restore => 'Restaura';
	@override String get wipe => 'Neteja';
	@override String get undo => 'Desfés';
	@override String get pendingDeleteTapWarning => 'Toca la paperera un cop més per esborrar aquest QSO';
	@override String get pendingDeleteClickWarning => 'Fes clic a la paperera un cop més per esborrar aquest QSO';
	@override String get deletedQsoWarning => 'QSO esborrat';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Toca la paperera un cop més per esborrar aquest ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Fes clic a la paperera un cop més per esborrar aquest ${kind}';
	@override String deletedEventWarning({required Object kind}) => '${kind} esborrat';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Ràdio';
	@override String get powerControl => 'Potència';
	@override String get notesControl => 'Apunts';
	@override String get power => 'Potència';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controls de registre';
	@override String get spottingControl => 'Anunci';
	@override String get spottingSelfControl => 'Autoanunci';
	@override String spotSelfAt({required Object freq}) => 'Autoanuncia\'t a ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Anuncia ${call} a ${freq}';
	@override String spotTooLate({required Object call}) => 'Massa tard per anunciar ${call}';
	@override String get spotNoFreq => 'Primer defineix una freqüència per anunciar';
	@override String get selfSpotDisabled => 'Autoanunci desactivat';
	@override String get spotComment => 'Comentari';
	@override String get spottingAutoControl => 'Re-anunci automàtic';
	@override String spotAutoEvery({required Object minutes}) => 'Torna a anunciar cada ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'Automàtic d\'aquí a ${time}. Aturar?';
	@override String spotAutoInMinutes({required Object minutes}) => 'Auto d\'aquí a ${minutes}m';
	@override String spotAutoInSeconds({required Object seconds}) => 'Auto d\'aquí a ${seconds}s';
	@override String spotAutoInCount({required Object seconds}) => 'Auto d\'aquí a ${seconds}';
	@override String get spotAutoNotStarted => 'Re-anunci automàtic no iniciat: l\'anunci no s\'ha enviat';
	@override String get spotAutoMoved => 'Re-anunci automàtic no iniciat: la freqüència ha canviat mentre s\'anunciava';
	@override String get spotAutoStopped => 'Re-anunci automàtic aturat';
	@override String get spotAutoLeftFreq => 'Re-anunci automàtic aturat: la freqüència ha canviat';
	@override String get spotAutoNoFreq => 'Re-anunci automàtic aturat: la ràdio no informa de cap freqüència';
	@override String get spotBusy => 'Encara s\'està enviant un altre anunci';
	@override String get bandOrFreqRequired => 'Defineix una freqüència o banda abans de registrar';
	@override String get missingBand => 'Sense banda';
	@override String get missingMode => 'Sense mode';
	@override String saveFailed({required Object error}) => 'No s\'ha pogut desar: ${error}';
	@override String deleteFailed({required Object error}) => 'No s\'ha pogut esborrar: ${error}';
	@override late final _Translations$loggingControls$info$ca info = _Translations$loggingControls$info$ca._(_root);
}

// Path: formChrome
class _Translations$formChrome$ca extends Translations$formChrome$en {
	_Translations$formChrome$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(sense títol)';
	@override String get showMore => 'Mostra\'n més';
	@override String get showAll => 'Mostra-ho tot';
	@override String get showFewer => 'Mostra\'n menys';
	@override String get defaults => 'Valors per defecte';
	@override String get search => 'Cerca';
	@override String get clear => 'Neteja';
	@override String get openPage => 'Obre la pàgina';
	@override String get connected => 'Connectat';
	@override String get notConnected => 'No connectat';
	@override String get manage => 'Gestiona';
	@override String get connect => 'Connecta';
	@override String get formTitle => 'Formulari';
	@override String addItem({required Object label}) => 'Afegeix ${label}';
	@override String editItem({required Object label}) => 'Edita ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Mostrant ${shown} de ${total} (${selected} seleccionats)';
	@override String validationError({required Object error}) => 'Error de validació: ${error}';
	@override String transformationError({required Object error}) => 'Error de transformació: ${error}';
	@override String actionError({required Object error}) => 'Error: ${error}';
	@override String get removeItem => 'Esborra';
	@override String deleteItemTitle({required Object name}) => 'Esborrar ${name}?';
	@override String get storageUnavailable => 'Inicis de sessió no disponibles';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$ca extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Edita el QSO';
	@override String get operatorCall => 'Operador';
	@override String get position => 'Posició';
	@override String get theirName => 'Nom';
	@override String get theirGrid => 'Graella';
	@override String get theirState => 'Estat';
	@override String get band => 'Banda';
	@override String get notes => 'Apunts';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'La seva informació';
	@override String get sectionOur => 'La nostra informació';
	@override String get sectionNotes => 'Apunts';
	@override String get theirCity => 'Ciutat';
	@override String get theirCounty => 'Comtat';
	@override String get theirEntity => 'Entitat';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Secció ARRL';
	@override String get theirLat => 'Latitud';
	@override String get theirLon => 'Longitud';
	@override String get theirPower => 'La seva potència';
}

// Path: qsoList
class _Translations$qsoList$ca extends Translations$qsoList$en {
	_Translations$qsoList$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Encara no hi ha QSOs — contacta amb algú!';
	@override String get bandOrModeWarning => 'Assegura\'t que la banda i el mode són correctes';
	@override String get today => 'Avui';
	@override String get yesterday => 'Ahir';
	@override String get tomorrow => 'Demà';
	@override late final _Translations$qsoList$find$ca find = _Translations$qsoList$find$ca._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$ca extends Translations$loggingPanel$en {
	_Translations$loggingPanel$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Estadístiques de l\'Operació';
	@override String get scoring => 'Puntuació';
	@override String get dxccEntities => 'Entitats DXCC';
	@override String get statesWorked => 'Estats';
	@override String get provincesWorked => 'Províncies';
	@override String get duplicates => 'Duplicats';
}

// Path: callInfo
class _Translations$callInfo$ca extends Translations$callInfo$en {
	_Translations$callInfo$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostra la imatge';
	@override String get imageUnavailable => 'Foto no disponible';
	@override String get photo => 'Foto';
	@override String get notes => 'Apunts';
	@override String distanceTo({required Object distance}) => '${distance} fins a';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) fins a';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) fins a';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)';
	@override String get thisOpCountOne => '1 QSO en aquesta operació';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs en aquesta operació';
	@override String get otherOpsCountOne => '1 QSO en altres operacions';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs en altres operacions';
	@override String andMore({required Object count}) => '… i ${count} més';
	@override String withCall({required Object call}) => 'amb ${call}';
	@override String fromOperation({required Object where}) => 'de ${where}';
	@override late final _Translations$callInfo$history$ca history = _Translations$callInfo$history$ca._(_root);
}

// Path: settings
class _Translations$settings$ca extends Translations$settings$en {
	_Translations$settings$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuració';
	@override String get language => 'Idioma';
	@override String languageSystem({required Object language}) => 'Segueix la configuració del sistema (${language})';
	@override late final _Translations$settings$theme$ca theme = _Translations$settings$theme$ca._(_root);
	@override late final _Translations$settings$themeDescription$ca themeDescription = _Translations$settings$themeDescription$ca._(_root);
	@override String get fontScale => 'Mida de la lletra';
	@override late final _Translations$settings$fontScaleOpts$ca fontScaleOpts = _Translations$settings$fontScaleOpts$ca._(_root);
	@override late final _Translations$settings$keepDeviceAwake$ca keepDeviceAwake = _Translations$settings$keepDeviceAwake$ca._(_root);
	@override String get layoutDensity => 'Densitat de la disposició';
	@override late final _Translations$settings$layoutDensityOpts$ca layoutDensityOpts = _Translations$settings$layoutDensityOpts$ca._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'la finestra és massa baixa; s\'utilitza ${effective}';
	@override String get layoutDensityAtLimit => 'al límit';
	@override String get distanceUnits => 'Unitats de distància';
	@override late final _Translations$settings$distanceUnitsOpts$ca distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$ca._(_root);
	@override String get userInterface => 'Interfície d\'usuari';
	@override late final _Translations$settings$logging$ca logging = _Translations$settings$logging$ca._(_root);
	@override late final _Translations$settings$catServer$ca catServer = _Translations$settings$catServer$ca._(_root);
	@override late final _Translations$settings$cluster$ca cluster = _Translations$settings$cluster$ca._(_root);
	@override late final _Translations$settings$spotting$ca spotting = _Translations$settings$spotting$ca._(_root);
	@override late final _Translations$settings$radio$ca radio = _Translations$settings$radio$ca._(_root);
	@override late final _Translations$settings$help$ca help = _Translations$settings$help$ca._(_root);
	@override late final _Translations$settings$exports$ca exports = _Translations$settings$exports$ca._(_root);
	@override late final _Translations$settings$extensionSections$ca extensionSections = _Translations$settings$extensionSections$ca._(_root);
	@override late final _Translations$settings$map$ca map = _Translations$settings$map$ca._(_root);
	@override late final _Translations$settings$privacy$ca privacy = _Translations$settings$privacy$ca._(_root);
	@override String get operatorCall => 'Indicatiu de l\'operador';
	@override late final _Translations$settings$sync$ca sync = _Translations$settings$sync$ca._(_root);
	@override late final _Translations$settings$peers$ca peers = _Translations$settings$peers$ca._(_root);
	@override String get developerMode => 'Mode de desenvolupador';
	@override late final _Translations$settings$syncPanel$ca syncPanel = _Translations$settings$syncPanel$ca._(_root);
	@override late final _Translations$settings$accounts$ca accounts = _Translations$settings$accounts$ca._(_root);
	@override late final _Translations$settings$station$ca station = _Translations$settings$station$ca._(_root);
	@override late final _Translations$settings$offlineData$ca offlineData = _Translations$settings$offlineData$ca._(_root);
	@override late final _Translations$settings$profiles$ca profiles = _Translations$settings$profiles$ca._(_root);
	@override late final _Translations$settings$search$ca search = _Translations$settings$search$ca._(_root);
	@override late final _Translations$settings$developer$ca developer = _Translations$settings$developer$ca._(_root);
	@override late final _Translations$settings$about$ca about = _Translations$settings$about$ca._(_root);
	@override late final _Translations$settings$panels$ca panels = _Translations$settings$panels$ca._(_root);
	@override String get showMoreSettings => 'Mostra més opcions';
	@override String get gridPrecision => 'Precisió de la graella';
	@override late final _Translations$settings$gridPrecisionOpts$ca gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$ca._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$ca gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$ca._(_root);
}

// Path: commands
class _Translations$commands$ca extends Translations$commands$en {
	_Translations$commands$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Activa primer la sincronització a la Configuració.';
	@override String get fullResyncStarted => 'S\'ha iniciat una resincronització completa — abans s\'ha fet una còpia de seguretat de les dades locals.';
	@override String noDataFilesMatched({required Object target}) => 'Cap fitxer de dades coincideix amb "${target}".';
	@override String reloadFailed({required Object error}) => 'La recàrrega ha fallat: ${error}';
	@override String get reloadingAll => 'Recarregant tots els fitxers de dades…';
	@override String reloadingTarget({required Object target}) => 'Recarregant els fitxers de dades de ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experiment desconegut "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} activat';
	@override String experimentDisabled({required Object name}) => '${name} desactivat';
	@override String get sentryTestSent => 'S\'ha enviat un informe d\'error de prova a Sentry';
	@override String get idleMetricsEnabled => 'Mètriques d\'inactivitat activades a la barra d\'estat';
	@override String get idleMetricsDisabled => 'Mètriques d\'inactivitat desactivades';
	@override String get sentryTestLocalOnly => 'Sentry està desactivat en aquesta versió — l\'error de prova només s\'ha registrat localment';
	@override String get noOperationOpen => 'Aquesta ordre necessita una operació oberta';
	@override String unknownSegmentKind({required Object kind}) => 'No se sap com marcar un \'${kind}\'';
	@override String goUnavailable({required Object place}) => '${place} no està activat en aquesta aplicació';
	@override String goUnknown({required Object to}) => 'No se sap com anar a \'${to}\'';
	@override String get goBlocked => 'Tanca primer el diàleg obert';
	@override String get operationAlreadyStarted => 'Aquesta operació ja té un marcador d\'inici';
	@override String get couldNotOpenLocation => 'S\'ha afegit la pausa, però no s\'ha pogut obrir la pantalla d\'ubicació';
	@override String get noTestOperations => 'No hi ha operacions de prova per purgar';
	@override String get purgeTestsUnavailable => 'PURGETESTS ha de mostrar un diàleg de confirmació, que aquí no està disponible';
	@override String get syncAllUnavailable => 'SYNCALL ha de mostrar un diàleg de confirmació, que aquí no està disponible';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha purgat ${count} operació de prova',
		other: 'S\'han purgat ${count} operacions de prova',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'S\'han purgat ${purged} de ${total} operacions de prova — la resta han fallat; torna a provar PURGETESTS';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha purgat ${count} contacte de prova sense operació',
		other: 'S\'han purgat ${count} contactes de prova sense operació',
	);
	@override String get purgeTestsContactsFailed => 'S\'han purgat les operacions de prova, però els contactes de prova sense operació han fallat. Torna a provar PURGETESTS';
	@override String get purgeTestsNothingToDo => 'No s\'ha purgat res';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'S\'han eliminat ${removed} de ${total} operacions de prova — la resta han fallat; torna a provar Revisa';
	@override String get receivedPurgesFailed => 'No s\'han pogut eliminar aquestes operacions de prova — torna a provar Revisa';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha eliminat ${count} operació de prova en un altre dispositiu',
		other: 'S\'han eliminat ${count} operacions de prova en un altre dispositiu',
	);
	@override String get receivedPurgesReview => 'Revisa';
	@override String get settingOn => 'Activat';
	@override String get settingOff => 'Desactivat';
	@override String get settingEmpty => '(buit)';
	@override String get settingSecretSet => '(definit)';
	@override String get settingSecretUnset => '(no definit)';
	@override String settingSelectedCount({required Object count}) => '${count} seleccionats';
	@override String get settingExpectsOnOff => 'on o off';
	@override String settingExpectsOneOf({required Object choices}) => 'un de: ${choices}';
	@override String get settingExpectsNumber => 'un número';
	@override String settingVanished({required Object label}) => '“${label}” ja no està disponible';
	@override String get noCwKeyer => 'Cap ràdio connectada pot manipular CW';
	@override String get noKeyer => 'Cap ràdio connectada pot manipular CW ni reproduir memòries de veu';
	@override String get keyerNeedsOperation => 'Obre una operació per utilitzar el manipulador CW';
	@override String get keyerExperimentOff => 'La manipulació CW està desactivada — activa-la amb EXP KEYER';
	@override String get esmExperimentOff => 'Enter envia missatges està desactivat — activa-ho amb EXP ESM';
	@override String cwSending({required Object text}) => 'Enviant CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Missatge CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'El missatge CW F${n} no s\'ha enviat: les extensions no estan a punt';
	@override String voiceMessageError({required Object n, required Object error}) => 'Missatge de fonia M${n}: ${error}';
	@override String get voiceMessageNotRendered => 'les extensions no estan a punt';
	@override String so2rRadioCannotKey({required Object radio}) => 'No s\'ha enviat res: la Ràdio ${radio} no pot manipular això';
	@override String get so2rNoRadioB => 'No s\'ha enviat res: tria una Ràdio B a Configuració de l\'estació per manipular des d\'aquest joc';
	@override String settingNotStored({required Object label}) => '“${label}” no ha acceptat aquest valor';
}

// Path: commandDialog
class _Translations$commandDialog$ca extends Translations$commandDialog$en {
	_Translations$commandDialog$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Cerca indicatius o escriu una ordre';
	@override String noResults({required Object text}) => 'Res coincideix amb “${text}”';
	@override String get sectionCommands => 'Ordres';
	@override String get sectionGoTo => 'Ves a';
	@override String get sectionOperations => 'Operacions';
	@override String get goHome => 'Inici';
	@override String get goSettings => 'Configuració';
	@override String get goNewOperation => 'Nova operació';
	@override String runTyped({required Object text}) => 'Executa “${text}”';
	@override String get sectionSuggestions => 'Prova';
	@override String get lookingUp => 'Consultant l\'indicatiu…';
	@override String get blockedByPane => 'No es poden utilitzar ordres mentre hi ha un panell o diàleg obert';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$ca extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dreceres de teclat';
	@override String get description => 'Personalitza les assignacions de tecles';
	@override String get search => 'Cerca ordres i tecles';
	@override String get import => 'Importa…';
	@override String get export => 'Exporta…';
	@override String get resetAll => 'Restableix-ho tot';
	@override String get resetAllTitle => 'Restablir totes les dreceres?';
	@override String get resetAllBody => 'Totes les ordres tornen a les seves tecles per defecte, i les tecles assignades a ordres escrites s\'eliminen.';
	@override String get reset => 'Restableix';
	@override String get noKey => 'Sense tecla';
	@override String get changed => 'Canviada';
	@override String conflict({required Object keys, required Object commands}) => '${keys} també està assignada a ${commands}';
	@override String get groupApp => 'Aplicació';
	@override String get groupKeying => 'Manipulació';
	@override String get groupLogging => 'Registre';
	@override String get groupCommands => 'Ordres';
	@override String get groupFixed => 'Tecles fixes';
	@override String get contextApp => 'A tot arreu';
	@override String get contextLogView => 'Vistes d\'operació, caça i registres';
	@override String get contextOperation => 'Vista d\'operació, manipulant una ràdio per CAT';
	@override String get contextLogging => 'Al panell de registre';
	@override String get addCommand => 'Afegeix una ordre…';
	@override String unknownCommand({required Object command}) => 'Ordre desconeguda: ${command}';
	@override late final _Translations$keyboardShortcuts$command$ca command = _Translations$keyboardShortcuts$command$ca._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$ca fixed = _Translations$keyboardShortcuts$fixed$ca._(_root);
	@override late final _Translations$keyboardShortcuts$editor$ca editor = _Translations$keyboardShortcuts$editor$ca._(_root);
	@override late final _Translations$keyboardShortcuts$file$ca file = _Translations$keyboardShortcuts$file$ca._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$ca modifier = _Translations$keyboardShortcuts$modifier$ca._(_root);
	@override late final _Translations$keyboardShortcuts$platform$ca platform = _Translations$keyboardShortcuts$platform$ca._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$ca extends Translations$expiredBuild$en {
	_Translations$expiredBuild$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aquesta versió ha caducat';
	@override String get body => 'Visita ham2k.com i aconsegueix una versió més nova.';
	@override String get visit => 'Visita ham2k.com';
	@override String get dismiss => 'Continua igualment';
}

// Path: staleness
class _Translations$staleness$ca extends Translations$staleness$en {
	_Translations$staleness$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Hi ha una actualització important pendent';
	@override String get codePushFloorBody => 'Aquesta versió té una correcció que encara no tens.';
	@override String get restartToApply => 'Reinicia l\'aplicació per aplicar-la.';
	@override String get quitAndReopen => 'Surt de l\'aplicació i torna-la a obrir per aplicar-la.';
	@override String get reopenToApply => 'Tanca l\'aplicació i torna-la a obrir per aplicar-la.';
	@override String get ignoreForNow => 'Ignora-ho de moment';
}

// Path: spotting
class _Translations$spotting$ca extends Translations$spotting$en {
	_Translations$spotting$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Encara no hi ha cap QSO registrat per anunciar.';
	@override String get setFrequencyFirst => 'Defineix primer una freqüència.';
	@override String get nothingToSpot => 'Res a anunciar — cap extensió ofereix anuncis aquí.';
	@override String get incompleteCall => 'No es pot anunciar un indicatiu incomplet — acaba\'l primer.';
	@override String spotFailed({required Object source, required Object message}) => '${source} ha fallat: ${message}';
	@override String get unknownError => 'error desconegut';
	@override String get notSent => 'Anunci no enviat.';
	@override String get allSkipped => 'Anunci no enviat: totes les fonts d\'anuncis l\'han omès.';
	@override String get notRefreshedOffline => 'Sense connexió — no s\'han refrescat els anuncis';
}

// Path: dataFiles
class _Translations$dataFiles$ca extends Translations$dataFiles$en {
	_Translations$dataFiles$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Descarregant…';
	@override String downloadFailedTitle({required Object name}) => 'No s\'ha pogut descarregar ${name}';
	@override String get downloadFailedWebHint => 'Pot ser un problema de xarxa, o potser el servidor d\'aquest enllaç no permet descàrregues directes des d\'un navegador web. Prova l\'aplicació d\'escriptori o mòbil, o una altra ubicació d\'allotjament.';
	@override String get downloadTimedOut => 'El servidor ha trigat massa a respondre. Torna-ho a provar més tard.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} ha respost amb un error (HTTP ${status}). Torna-ho a provar més tard.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} no ha pogut proporcionar aquest fitxer (HTTP ${status}). Comprova que l\'adreça encara sigui correcta.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM no té cap fitxer d\'historial d\'indicatius per a ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'La descàrrega de l\'historial d\'indicatius de N1MM per a ${stem} no ha funcionat. Torna-ho a provar més tard.';
	@override String processingFailedTitle({required Object name}) => 'No s\'ha pogut processar ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'La descàrrega només tenia ${imported} dels ${existing} registres d\'aquest dispositiu, així que s\'han conservat els que hi faltaven. Si la refresques a Configuració › Dades fora de línia, s\'acceptarà igualment.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha importat ${count} registre per a ${label}.',
		other: 'S\'han importat ${count} registres per a ${label}.',
	);
	@override String importedData({required Object label}) => 'S\'han importat dades per a ${label}.';
	@override String get cleanedUpTitle => 'S\'han netejat les dades d\'extensions';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'han eliminat les dades de ${count} fitxer de dades d\'extensions desactivades.',
		other: 'S\'han eliminat les dades de ${count} fitxers de dades d\'extensions desactivades.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} registres';
	@override String get definitionUnavailable => 'L\'origen del fitxer no n\'ha proporcionat la definició — potser la seva extensió s\'està reiniciant o està mal configurada. Torna-ho a provar d\'aquí a un moment.';
}

// Path: updates
class _Translations$updates$ca extends Translations$updates$en {
	_Translations$updates$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Actualització disponible';
	@override String newVersionAvailable({required Object version}) => 'Hi ha una versió nova (${version}) disponible.';
	@override String get getIt => 'Obtén-la';
	@override String get ok => 'D\'acord';
	@override String get updateReady => 'Actualització a punt';
	@override String get restartToApply => 'S\'ha descarregat una actualització. Reinicia per aplicar-la.';
	@override String get appliesNextLaunch => 'S\'ha descarregat una actualització. S\'aplicarà la propera vegada que obris l\'aplicació.';
	@override String get restartNow => 'Reinicia ara';
	@override String get reloadToUpdate => 'Hi ha una versió més nova d\'aquesta pàgina. Recarrega-la per obtenir-la.';
	@override String get reloadNow => 'Recarrega ara';
	@override String get checkForUpdates => 'Comprova les actualitzacions';
	@override String get checkingForUpdates => 'Comprovant si hi ha actualitzacions…';
	@override String get upToDate => 'Al dia';
	@override String get automaticChecks => 'Comprova automàticament';
	@override String get automaticChecksDescription => 'Busca versions noves en segon pla, a partir de la propera vegada que iniciïs l\'aplicació';
}

// Path: extensionService
class _Translations$extensionService$ca extends Translations$extensionService$en {
	_Translations$extensionService$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'L\'entorn d\'execució d\'extensions no està a punt.';
	@override String testFailed({required Object error}) => 'La prova ha fallat: ${error}';
	@override String connectedAs({required Object identity}) => 'Connectat com a ${identity}';
	@override String get invalidFieldConfiguration => 'Configuració de camp invàlida';
	@override String get invalidValue => 'Valor invàlid';
	@override String validationError({required Object error}) => 'Error de validació: ${error}';
	@override String actionFailed({required Object error}) => 'L\'acció ha fallat: ${error}';
	@override String get commandFailed => 'L\'ordre no s\'ha pogut executar';
	@override String commandMayNotChangeSettings({required Object name}) => '${name} no pot canviar la configuració: no ho va demanar en instal·lar-se';
	@override String commandMayNotControlRadio({required Object name}) => '${name} no pot controlar la ràdio: no ho va demanar en instal·lar-se';
	@override String commandDeveloperOnly({required Object name}) => '${name} no pot executar això: és una de les ordres de desenvolupador pròpies de l\'aplicació';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => 'Ara mateix no es poden enviar informes';
	@override String get stashUnavailable => 'Ara mateix no es pot accedir a Ham2K File Stash';
	@override String activitySearchSourcesFailed({required Object names}) => 'La cerca d\'activitats no ha rebut resposta de ${names}, així que pot ser que faltin alguns resultats.';
	@override String get activitySearchSomeSourcesFailed => 'Algunes extensions d\'activitat no han respost la cerca, així que pot ser que faltin alguns resultats.';
	@override String timersSuspendedBudget({required Object name}) => '${name} ha passat massa temps als seus temporitzadors. S\'han aturat fins que es reiniciïn les extensions.';
	@override String timersSuspendedFailures({required Object name}) => 'Els temporitzadors de ${name} continuaven fallant. S\'han aturat fins que es reiniciïn les extensions.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} s\'ha quedat encallat en un temporitzador. Els seus temporitzadors s\'han aturat fins que es reiniciïn les extensions.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$ca extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ubicació de l\'operació';
	@override String get selectedLocation => 'Ubicació seleccionada';
	@override String get gridSquare => 'Localitzador de graelles Maidenhead';
	@override String get gridInvalid => 'Ha de tenir 4, 6, 8 o 10 caràcters, com FN31pr';
	@override String get suggestedLocations => 'Ubicacions suggerides';
	@override String get deviceGps => 'GPS del dispositiu';
	@override String peerGps({required Object device}) => 'GPS de ${device}';
	@override String get locating => 'Localitzant…';
	@override String get gpsUnavailable => 'Ubicació no disponible';
	@override String get permissionDenied => 'Permís d\'ubicació denegat';
	@override String get permissionBlocked => 'Permís d\'ubicació bloquejat';
	@override String get moreDetails => 'Més detalls';
	@override String get stateOrProvince => 'Estat o província (opcional)';
	@override String get controlsUnavailableTitle => 'Controls d\'activitat no disponibles';
	@override String get controlsUnavailableReason => 'Aquestes referències encara es poden utilitzar; simplement no s\'ha pogut accedir a les seves activitats.';
	@override String get controlsUnavailableRetry => 'Torna-ho a provar';
	@override String get county => 'Comtat (opcional)';
}

// Path: versionLabel
class _Translations$versionLabel$ca extends Translations$versionLabel$en {
	_Translations$versionLabel$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versió ${version}';
	@override String patch({required Object patch}) => 'Pegat ${patch}';
	@override String build({required Object build}) => 'compilació ${build}';
}

// Path: notices
class _Translations$notices$ca extends Translations$notices$en {
	_Translations$notices$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Encara no hi ha avisos';
	@override String get webStorageInMemory => 'Aquest navegador no ha pogut oferir emmagatzematge persistent — el registre només és a la memòria i ES PERDRÀ quan es tanqui aquesta pestanya. Utilitza una versió actual de Chrome, Firefox, Safari o Edge.';
	@override String get webStorageUnreliable => 'Aquest navegador utilitza un emmagatzematge alternatiu que no és segur amb diverses pestanyes — mantén només una pestanya oberta i deixa la sincronització activada.';
	@override String get logFromNewerBuildTitle => 'Aquest registre necessita una versió més nova';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'El teu registre l\'ha escrit una versió més nova de HaLo (versió d\'emmagatzematge ${storage}; aquesta entén la ${understood}), així que no es pot obrir i els contactes nous no es desaran. Torna a instal·lar la versió més nova — o, si volies executar aquesta versió, apunta-la a una altra carpeta de dades. El registre és a ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'El teu registre l\'ha escrit una versió més nova de HaLo (versió d\'emmagatzematge ${storage}; aquesta entén la ${understood}), així que no es pot obrir i els contactes nous no es desaran. Obre aquest registre amb aquella versió més nova.';
	@override String get preferencesRestoredTitle => 'Configuració restaurada des d\'una còpia de seguretat';
	@override String get preferencesRestored => 'No s\'ha pogut llegir el fitxer de configuració, així que HaLo n\'ha restaurat l\'última còpia bona. Potser hauràs de tornar a configurar el que vas canviar a la sessió anterior. El fitxer il·legible es conserva al costat, amb el nom shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Configuració restablerta';
	@override String get preferencesReset => 'No s\'ha pogut llegir el fitxer de configuració i no hi havia cap còpia de seguretat a què recórrer, així que HaLo ha començat amb els valors per defecte. El fitxer il·legible es conserva a la carpeta de dades de l\'aplicació, amb el nom shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} no s\'ha connectat automàticament';
	@override String autoConnectHeld({required Object name}) => 'HaLo va deixar de respondre l\'última vegada que va començar a connectar-se a ${name}, així que aquesta vegada no ho ha intentat per no arriscar-se que torni a passar. Comprova que la ràdio estigui engegada i el cable connectat, i després prem Connecta a la Configuració.';
}

// Path: syncAccount
class _Translations$syncAccount$ca extends Translations$syncAccount$en {
	_Translations$syncAccount$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Compte anònim (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (pendent de confirmació)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (pendent de confirmació - #${id})';
}

// Path: deepLink
class _Translations$deepLink$ca extends Translations$deepLink$en {
	_Translations$deepLink$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Inicia primer una operació i després torna a enviar aquest contacte';
	@override String get waitingInOperation => 'Aquest contacte espera a l\'operació que hi ha darrere d\'aquesta pantalla';
	@override String unknownActivities({required Object refs}) => 'Aquest dispositiu no té cap activitat per a ${refs}, així que s\'han omès aquestes referències';
	@override String activitiesUnavailable({required Object refs}) => 'No s\'ha pogut accedir a les teves activitats, així que s\'ha omès ${refs} — torna a provar aquest enllaç';
}

// Path: confirmDevice
class _Translations$confirmDevice$ca extends Translations$confirmDevice$en {
	_Translations$confirmDevice$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirma un dispositiu';
	@override String get codePrompt => 'Introdueix el codi que es mostra al dispositiu que vol unir-se a aquest compte.';
	@override String get code => 'Codi';
	@override String get lookUp => 'Cerca';
	@override String get codeNotFound => 'Cap sol·licitud coincideix amb aquest codi. Els codis caduquen al cap de 10 minuts — demana\'n un de nou a l\'altre dispositiu.';
	@override String get linkExpired => 'Aquest enllaç ha caducat. Demana a l\'altre dispositiu que mostri un codi QR nou.';
	@override String areYouSure({required Object device}) => 'Vincular ${device} a aquest compte?';
	@override String get unnamedDevice => 'un dispositiu sense nom';
	@override String get grantWarning => 'Podrà llegir i modificar totes les operacions i QSOs d\'aquest compte.';
	@override String get needsSyncTitle => 'Aquest dispositiu encara no se sincronitza';
	@override String get needsSyncText => 'Activa la sincronització de Ham2K Log Filer i vincula aquest dispositiu a un compte abans que pugui admetre\'n un altre.';
	@override String get malformedRequest => 'El servidor de sincronització ha enviat una sol·licitud que aquesta aplicació no ha pogut llegir. Demana a l\'altre dispositiu que ho torni a provar.';
	@override String get linkIt => 'Vincula el dispositiu';
}

// Path: switchAccounts
class _Translations$switchAccounts$ca extends Translations$switchAccounts$en {
	_Translations$switchAccounts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Encara no hi ha detalls del compte';
	@override String get currentAccount => 'Compte actual';
	@override String get otherAccounts => 'Altres comptes';
	@override String get linkToAnother => 'Vincula amb un altre compte';
	@override String get linkWithSibling => 'Vincula amb una altra aplicació de Ham2K';
	@override String get linkWithPolo => 'Vincula amb el compte de la versió anterior';
	@override String get linkWithSiblingDescription => 'Tens una altra aplicació de Ham2K instal·lada. Vincula amb el compte que s\'hi fa servir.';
	@override String siblingPrompt({required Object app}) => 'Aprova la sol·licitud a ${app} i després torna aquí.';
	@override String openSiblingAgain({required Object app}) => 'Torna a obrir ${app}';
	@override String get siblingNoGrant => 'No ha funcionat? Torna-la a obrir, o torna enrere i vincula d\'una altra manera.';
	@override String siblingOpenFailed({required Object app}) => 'No s\'ha pogut obrir ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'L\'enllaç ha caducat i n\'hi ha un de nou a punt — torna a obrir ${app}.';
	@override String get tryAgain => 'Torna-ho a provar';
	@override String get linkWithQr => 'Vincula amb un codi QR';
	@override String get linkWithQrDescription => 'Escaneja\'l des d\'un dispositiu que ja utilitzi el compte';
	@override String get linkWithEmail => 'Vincula amb una adreça de correu electrònic';
	@override String get linkWithEmailDescription => 'Confirma amb un codi o un enllaç per correu electrònic';
	@override String get enterEmailPrompt => 'Introdueix l\'adreça de correu electrònic del compte que vols que utilitzi aquest dispositiu.';
	@override String get emailAddress => 'Adreça de correu electrònic';
	@override String get linkAccount => 'Vincula el compte';
	@override String get copiedCode => 'S\'ha copiat el codi al porta-retalls';
	@override String get copyCode => 'Copia el codi';
	@override String codePrompt({required Object email}) => 'Obre l\'aplicació de Ham2K en un dispositiu ja vinculat amb ${email} i introdueix aquest codi per aprovar la sol·licitud:';
	@override String get waitingForConfirmation => 'Esperant la confirmació…';
	@override String get sendEmailInstead => 'Envia un correu de confirmació';
	@override String emailSent({required Object email}) => 'S\'ha enviat un correu electrònic a ${email}. Obre\'l i confirma la sol·licitud per vincular aquest dispositiu.';
	@override String get resendEmail => 'Torna a enviar el correu';
	@override String get qrPrompt => 'Escaneja aquest codi QR des d\'un dispositiu ja vinculat al compte que vols — per exemple, amb Ham2K Portable Logger al telèfon.';
	@override String get serverUnreachable => 'No s\'ha pogut contactar amb el servidor de sincronització. Torna-ho a provar més tard.';
	@override String get emailRequired => 'Introdueix una adreça de correu electrònic per vincular.';
	@override String noAccountForEmail({required Object email}) => 'No s\'ha trobat cap compte per a ${email}.';
	@override String serverRejected({required Object error}) => 'El servidor de sincronització ha rebutjat la sol·licitud: ${error}';
	@override String get noLinkCode => 'El servidor de sincronització no ha retornat cap codi de vinculació. Torna-ho a provar més tard.';
	@override String get noConfirmationCode => 'El servidor de sincronització no ha enviat cap codi de confirmació. Torna-ho a provar més tard.';
	@override String get switchNotAccepted => 'Aquest compte no ha acceptat el canvi. Prova de vincular-lo amb una adreça de correu electrònic.';
	@override String get requestFailed => 'Alguna cosa ha anat malament en comunicar-se amb el servidor de sincronització. Torna-ho a provar més tard.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} operació',
		other: '${count} operacions',
	);
}

// Path: qsonImport
class _Translations$qsonImport$ca extends Translations$qsonImport$en {
	_Translations$qsonImport$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa una operació QSON';
	@override String get description => 'Crea una operació nova a partir d\'un fitxer QSON, com el que exporta el Mode de desenvolupador aquí o a PoLo.';
	@override String get dropHint => 'Deixa anar un fitxer QSON per importar-lo com a operació nova';
	@override String importing({required Object filename}) => 'Important ${filename}…';
	@override String failed({required Object filename, required Object error}) => 'No s\'ha pogut importar ${filename}: ${error}';
	@override String pickerFailed({required Object error}) => 'No s\'ha pogut obrir cap fitxer per importar: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} no és text UTF-8, així que no és un fitxer QSON';
	@override String notJson({required Object filename}) => '${filename} no és un fitxer JSON, així que no és un fitxer QSON';
	@override String notOperation({required Object filename}) => '${filename} no conté cap operació QSON';
	@override String get busy => 'Ja hi ha una importació en curs. Espera que acabi abans de començar-ne una altra.';
	@override String get oneFileOnly => 'Deixa anar els fitxers QSON d\'un en un — cadascun s\'obre com una operació pròpia.';
}

// Path: adifImport
class _Translations$adifImport$ca extends Translations$adifImport$en {
	_Translations$adifImport$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa QSOs des d\'ADIF';
	@override String reading({required Object filename}) => 'Llegint ${filename}…';
	@override String get dropHint => 'Deixa anar un fitxer ADIF per importar-lo';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} QSO en aquest fitxer',
		other: '${formatted} QSOs en aquest fitxer',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} ja és al teu registre',
		other: '${formatted} ja són al teu registre',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Se n\'importarà ${count}',
		other: 'Se n\'importaran ${formatted}',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} contacte nou',
		other: '${formatted} contactes nous',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} es combinarà amb un contacte existent',
		other: '${formatted} es combinaran amb contactes existents',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} no es pot importar (sense indicatiu)',
		other: '${formatted} no es poden importar (sense indicatiu)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} necessita una ullada més atenta',
		other: '${formatted} necessiten una ullada més atenta',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'No s\'han pogut recuperar les referències de ${count} contacte',
		other: 'No s\'han pogut recuperar les referències de ${formatted} contactes',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Les referències ${programs} poden estar incompletes per a ${count} contacte',
		other: 'Les referències ${programs} poden estar incompletes per a ${formatted} contactes',
	);
	@override String get stackingTypesUnknown => 'Els contactes combinats poden perdre una referència — les activitats no han pogut indicar quins tipus s\'acumulen. Cancel·la i torna-ho a provar per evitar-ho.';
	@override String get nothingToImport => 'No hi ha res en aquest fitxer que es pugui importar';
	@override String get confirm => 'Importa';
	@override String importing({required Object filename}) => 'Important ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha importat ${count} contacte de ${filename}',
		other: 'S\'han importat ${formatted} contactes de ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'No s\'ha pogut importar ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} no sembla un fitxer ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Avís: aquest ADIF té QSOs de ${calls}, però s\'importaran com a ${station} si continues.';
	@override String get stationCallJoin => ' i ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} no té data i no es pot importar',
		other: '${formatted} no tenen data i no es poden importar',
	);
	@override String activationFound({required Object refs}) => 'Aquest fitxer registra una activació de ${refs}.';
	@override String get addActivation => 'Afegeix-la a aquesta operació';
	@override String shortfall({required Object written, required Object planned}) => 'Només s\'han pogut aplicar ${written} de ${planned} — el registre ha canviat mentre decidies.';
	@override String get busy => 'Ja hi ha una importació en curs. Espera que acabi abans de començar-ne una altra.';
	@override String get oneFileOnly => 'Deixa anar els fitxers ADIF d\'un en un — l\'ordre en què s\'importen decideix quines dades prevalen.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} té més de ${limit} QSOs, el màxim que una operació pot importar alhora.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename} té més de ${limit} QSOs. Importar un ADIF a una operació serveix per afegir uns quants QSOs, no per carregar un registre gran — per a això, fes servir la vista Registres. El mode de desenvolupador et permet importar-lo igualment, si n\'estàs segur.';
	@override String get importAnyway => 'Importa igualment';
}

// Path: offline
class _Translations$offline$ca extends Translations$offline$en {
	_Translations$offline$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: SENSE CONNEXIÓ';
	@override String get statusOnline => 'Internet: connectat';
	@override String get noRoute => 'No hi ha cap connexió de xarxa.';
	@override String get unreachable => 'La xarxa funciona, però cap servidor respon — sovint és senyal que hi ha una pàgina d\'inici de sessió esperant en un navegador.';
	@override String get reachable => 'Tots els serveis responen amb normalitat.';
	@override String get whatStops => 'Les consultes, els anuncis i els fitxers de dades estan en pausa. El registre i la sincronització amb dispositius propers, no.';
	@override String get servicesTitle => 'Serveis';
	@override String get noServices => 'Encara no ha informat cap servei.';
	@override String lastSuccess({required Object when}) => 'Última resposta fa ${when}';
	@override String get neverSucceeded => 'Encara no ha respost';
	@override String nextAttempt({required Object when}) => 'Proper intent d\'aquí a ${when}';
	@override String get nextAttemptNow => 'Proper intent imminent';
	@override String get retry => 'Torna-ho a provar ara';
	@override String get retrying => 'Provant…';
	@override String get retryReached => 'Torna a haver-hi connexió.';
	@override String get retryUnreachable => 'Encara sense resposta.';
	@override String get retryNotAttempted => 'Ara mateix no hi ha res per enviar.';
	@override String get retryThrottled => 'S\'acaba de provar — espera un moment.';
	@override String get retryDisabled => 'La sincronització està desactivada, així que no hi ha res amb què comprovar-ho.';
	@override String get syncService => 'Sincronització LoFi de Ham2K';
	@override String get retryInFlight => 'Ja s\'està provant — espera.';
}

// Path: exportSettings
class _Translations$exportSettings$ca extends Translations$exportSettings$en {
	_Translations$exportSettings$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Configuració base per a totes les exportacions, amb plantilles de nom de fitxer i de títol separades per a activitats de referència i altres activitats. Cada tipus d\'exportació pot tenir els seus propis valors per defecte o una configuració personalitzada.';
	@override String get referenceActivities => 'Activitats de referència';
	@override String get otherActivities => 'Altres activitats';
	@override String get adifFields => 'Camps ADIF';
	@override String get loadFailed => 'No s\'ha pogut carregar la configuració d\'exportació.';
	@override String get retry => 'Torna-ho a provar';
	@override String get compactFileNamesDescriptionOn => 'Noms de fitxer compactes, com N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Noms de fitxer descriptius, com 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'S\'inclouen noms, adreces, correus electrònics, notes i ubicacions precises als fitxers ADIF.';
	@override String get includePrivateDataDescriptionOff => 'S\'ometen noms, adreces, correus electrònics i notes; les ubicacions es limiten a graelles de sis caràcters.';
	@override String get includeLookupDataDescriptionOn => 'S\'inclou la informació dels serveis de consulta d\'indicatius.';
	@override String get includeLookupDataDescriptionOff => 'S\'omet la informació dels serveis de consulta d\'indicatius; es conserven els valors introduïts manualment.';
	@override String get customTemplatesDescriptionOn => 'Les teves plantilles personalitzades estan actives i es poden editar a sota.';
	@override String get customTemplatesDescriptionOff => 'Les plantilles per defecte estan actives. Les teves plantilles personalitzades es conserven per a més endavant.';
	@override String get type => 'Tipus d\'exportació';
	@override String get defaults => 'Valors per defecte';
	@override String get includeLookupData => 'Inclou les dades de consulta';
	@override String get customTemplates => 'Plantilles personalitzades';
	@override String get filenameTemplate => 'Plantilla de nom de fitxer';
	@override String get compactFilenameTemplate => 'Plantilla de nom de fitxer compacte';
	@override String get titleTemplate => 'Plantilla de títol';
	@override String get adifNotesTemplate => 'Notes ADIF QSO';
	@override String get adifCommentTemplate => 'Comentaris ADIF QSO';
	@override String get adifQslMessageTemplate => 'Missatge ADIF QSL';
	@override String get shared => 'La configuració s\'aplica a totes les extensions que utilitzen aquest tipus d\'exportació.';
	@override String get defaultTemplates => 'Activa Plantilles personalitzades per editar les plantilles d\'aquest tipus.';
}

// Path: templateEditor
class _Translations$templateEditor$ca extends Translations$templateEditor$en {
	_Translations$templateEditor$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Previsualització:';
	@override String get reset => 'Restableix';
	@override String get docs => 'Documentació de plantilles';
	@override String get preview => 'Previsualització d\'exemple';
	@override String get reference => 'Referència de plantilles';
	@override String get attributes => 'Atributs disponibles';
	@override String get filters => 'Filtres';
	@override String get flowControl => 'Control de flux';
	@override String get unavailable => 'La previsualització no està disponible fins que les extensions estiguin a punt.';
	@override String get empty => '(sortida buida)';
}

// Path: home.nav
class _Translations$home$nav$ca extends Translations$home$nav$en {
	_Translations$home$nav$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operacions';
	@override String get chase => 'Caça';
	@override String get logs => 'Registres';
	@override String get maps => 'Mapes';
	@override String get settings => 'Configuració';
}

// Path: home.panels
class _Translations$home$panels$ca extends Translations$home$panels$en {
	_Translations$home$panels$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Llista d\'operacions';
	@override String get operationsDescription => 'Les teves operacions, les més recents primer.';
	@override String get version => 'Versió actual';
	@override String get versionDescription => 'El logotip de Ham2K, el nom d\'aquesta aplicació i la versió que estàs executant.';
}

// Path: home.logs
class _Translations$home$logs$ca extends Translations$home$logs$en {
	_Translations$home$logs$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registres';
	@override String get titleFor => 'Registres de';
	@override String get emptyCallsigns => 'Encara no hi ha QSOs registrats';
	@override String emptyQsos({required Object call}) => 'No hi ha QSOs per a ${call}';
	@override String get mapNoSelection => 'Selecciona un QSO per veure\'l al mapa';
	@override String get searchHint => 'Cerca indicatiu o nom';
	@override String get noSearchMatches => 'Cap QSO coincideix amb la cerca';
	@override String get titleAll => 'Tots els registres';
	@override String get allCallsigns => 'Tots els indicatius';
	@override String get noOperation => 'No forma part de cap operació';
	@override String get unsavedTitle => 'Canvis sense desar';
	@override String get unsavedBody => 'Aquest QSO té canvis que no has desat.';
	@override String get pendingDeleteBody => 'Aquest QSO està marcat per esborrar.';
	@override String get editGone => 'No desat: aquest QSO ja no és en aquest registre.';
	@override String get discard => 'Descarta';
	@override late final _Translations$home$logs$sheet$ca sheet = _Translations$home$logs$sheet$ca._(_root);
	@override late final _Translations$home$logs$groupBy$ca groupBy = _Translations$home$logs$groupBy$ca._(_root);
	@override late final _Translations$home$logs$period$ca period = _Translations$home$logs$period$ca._(_root);
	@override late final _Translations$home$logs$periodTitle$ca periodTitle = _Translations$home$logs$periodTitle$ca._(_root);
	@override late final _Translations$home$logs$columns$ca columns = _Translations$home$logs$columns$ca._(_root);
	@override late final _Translations$home$logs$panels$ca panels = _Translations$home$logs$panels$ca._(_root);
	@override late final _Translations$home$logs$import$ca import = _Translations$home$logs$import$ca._(_root);
}

// Path: chase.station
class _Translations$chase$station$ca extends Translations$chase$station$en {
	_Translations$chase$station$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estació de caça';
	@override String get stationLabel => 'Estació: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Sense ubicació';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$ca extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get today => 'avui';
	@override String get thisWeek => 'aquesta setmana';
	@override String get last14Days => 'en els darrers 14 dies';
	@override String get thisMonth => 'aquest mes';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$ca extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get today => 'Estadístiques d\'avui';
	@override String get thisWeek => 'Estadístiques d\'aquesta setmana';
	@override String get last14Days => 'Estadístiques dels darrers 14 dies';
	@override String get thisMonth => 'Estadístiques d\'aquest mes';
}

// Path: chase.period
class _Translations$chase$period$ca extends Translations$chase$period$en {
	_Translations$chase$period$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get today => 'Avui';
	@override String get thisWeek => 'Aquesta setmana';
	@override String get last14Days => 'Darrers 14 dies';
	@override String get thisMonth => 'Aquest mes';
}

// Path: chase.goals
class _Translations$chase$goals$ca extends Translations$chase$goals$en {
	_Translations$chase$goals$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Objectius de caça';
	@override String remove({required Object name}) => 'Deixa de caçar ${name}';
	@override String get extensionsTitle => 'Més programes de caça';
}

// Path: chase.panels
class _Translations$chase$panels$ca extends Translations$chase$panels$en {
	_Translations$chase$panels$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Controls de registre sobre els QSOs caçats en el període.';
	@override String get info => 'Informació';
	@override String get infoDescription => 'L\'indicatiu que s\'està registrant, o les estadístiques del període.';
	@override String get spots => 'Anuncis';
	@override String get spotsDescription => 'Estacions anunciades a l\'aire, a punt per caçar.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Els QSOs del període i l\'estació que s\'està registrant.';
}

// Path: chase.claims
class _Translations$chase$claims$ca extends Translations$chase$claims$en {
	_Translations$chase$claims$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get checking => 'Comprovant els QSOs per a la caça';
	@override String rebuilding({required Object program}) => 'Comprovant el registre per a ${program}';
	@override String progress({required Object done, required Object total}) => '${done} de ${total} QSOs';
}

// Path: chase.notice
class _Translations$chase$notice$ca extends Translations$chase$notice$en {
	_Translations$chase$notice$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'Nou ${program}';
	@override String newRefGuess({required Object program}) => 'Probablement nou ${program}';
	@override String newBand({required Object program}) => 'Banda nova per a ${program}';
	@override String newBandGuess({required Object program}) => 'Probablement banda nova per a ${program}';
	@override String newMode({required Object program}) => 'Mode nou per a ${program}';
	@override String newModeGuess({required Object program}) => 'Probablement mode nou per a ${program}';
	@override String unconfirmed({required Object program}) => '${program} sense confirmar';
	@override String programGuess({required Object notice}) => 'Probablement ${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$ca extends Translations$chase$alerts$en {
	_Translations$chase$alerts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Alertes';
	@override String get newRef => 'Referència Nova';
	@override String get newBand => 'Banda Nova';
	@override String get newMode => 'Mode Nou';
	@override String get unconfirmed => 'Sense confirmar';
}

// Path: chase.imports
class _Translations$chase$imports$ca extends Translations$chase$imports$en {
	_Translations$chase$imports$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'Importa ${label}';
	@override String pickTitle({required Object file}) => 'Importa ${file} com a';
	@override String get dropHint => 'Deixa anar un fitxer per importar-lo a un programa de caça';
	@override String done({required Object count, required Object program, required Object file}) => 'S\'han importat ${count} entrades de ${program} des de ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'S\'han importat ${count} entrades de ${program} des de ${file}; se n\'han omès ${skipped} que no s\'han pogut llegir';
	@override String nothing({required Object file, required Object program}) => '${file} no té res que ${program} pugui importar';
	@override String failed({required Object program, required Object file}) => '${program} no ha pogut llegir ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} no ha pogut llegir cap dels ${skipped} registres de ${file}';
	@override String noProgram({required Object file}) => 'Cap programa de caça importa ${file}';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$ca extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Consultar en línia?';
	@override String get body => 'L\'assistència està desactivada en aquesta operació. Consultar tots els QSOs farà servir serveis en línia com QRZ només aquesta vegada.';
	@override String bodyRules({required Object rules}) => 'L\'assistència està desactivada en aquesta operació per complir les normes de ${rules}. Consultar tots els QSOs farà servir serveis en línia com QRZ només aquesta vegada.';
	@override String get action => 'Consulta en línia';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$ca extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicatiu invàlid: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicatius invàlids: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} ha operat fins ara. Es registrarà ${typed} per als contactes nous.';
	@override String operatorNoneSoFar({required Object typed}) => 'No s\'ha registrat cap operador fins ara. Es registrarà ${typed} per als contactes nous.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Aquesta operació ja té contactes de ${calls}. ${typed} només es registrarà per als nous.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Registra també ${typed} com a operador del contacte ja registrat',
		other: 'Registra també ${typed} com a operador dels ${count} contactes ja registrats',
	);
	@override String get operatorSeveralStations => 'Quan s\'utilitzen diverses estacions a l\'aire, no es poden registrar operadors separats';
	@override String get contactsUnreadable => 'No s\'han pogut llegir els contactes d\'aquesta operació, així que canviar un indicatiu aquí no oferirà actualitzar-los';
	@override String restampFailed({required Object error}) => 'No s\'han pogut actualitzar els contactes ja registrats, així que no s\'ha fet cap canvi: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => 'S\'han actualitzat ${written} de ${planned} contactes — la resta ja no són en aquesta operació';
}

// Path: operation.tabs
class _Translations$operation$tabs$ca extends Translations$operation$tabs$en {
	_Translations$operation$tabs$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFO';
	@override String get spots => 'ANUNCIS';
	@override String get map => 'MAPA';
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Rellotge';
	@override String get weather => 'Temps';
	@override String get website => 'Lloc web';
	@override String get remoteScreen => 'Pantalla remota';
	@override String get solar => 'Solar';
	@override String get radio => 'Ràdio';
	@override String get rotator => 'Rotor';
	@override String get summaries => 'Resums de l\'operació';
}

// Path: operation.positions
class _Translations$operation$positions$ca extends Translations$operation$positions$en {
	_Translations$operation$positions$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Encara no hi ha cap altra posició d\'operació que comparteixi aquesta operació.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Una altra posició';
	@override String get thisDevice => 'La nostra posició d\'operació';
	@override String get nameIn => ' a ';
	@override String get panelTitle => 'Posicions';
	@override String get panelDescription => 'Què està registrant ara mateix cada posició d\'operació que comparteix aquesta operació.';
}

// Path: operation.menu
class _Translations$operation$menu$ca extends Translations$operation$menu$en {
	_Translations$operation$menu$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostra els camps RST';
	@override String get showStateField => 'Mostra el camp d\'estat';
	@override String get showGridField => 'Mostra el camp de graella';
	@override String get showDeletedQsos => 'Mostra els QSOs esborrats';
	@override String get showDeletedOps => 'Mostra les operacions esborrades';
	@override String get showQsoNumbers => 'Mostra els números de QSO';
	@override String get lookupAllQsos => 'Consulta tots els QSOs';
	@override String get loggingSettingsTitle => 'Configuració de registre';
	@override String get mapSettingsTitle => 'Configuració del mapa';
	@override String get actionsSection => 'Accions';
}

// Path: operation.layout
class _Translations$operation$layout$ca extends Translations$operation$layout$en {
	_Translations$operation$layout$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afegeix un panell';
	@override String get availableSection => 'Panells disponibles';
	@override String panelSettings({required Object panel}) => 'Configuració de ${panel}';
	@override String get panelSettingsAction => 'Configuració del panell';
	@override String get viewName => 'Vista d\'operació';
	@override String get viewOptions => 'Opcions de disposició de la vista';
	@override String get viewTitleBuiltIn => 'Aquesta vista està integrada a l\'aplicació, i el seu nom també';
	@override String get resetOptions => 'Restaura els valors per defecte';
	@override String get removePane => 'Elimina';
	@override String resetPaneConfirm({required Object panel}) => 'Restaurar ${panel} als valors per defecte?';
	@override String get resetPaneConfirmBody => 'El títol, la capçalera i la mida tornen als valors per defecte. La resta de la disposició es queda com està.';
	@override String get resetViewConfirm => 'Restaurar aquesta vista a la disposició per defecte?';
	@override String get resetViewConfirmBody => 'Els panells tornen a la seva disposició per defecte, i les opcions de la vista i de cada panell tornen als valors per defecte.';
	@override String paneOptionsTitle({required Object panel}) => 'Configuració de disposició de ${panel}';
	@override String get paneTitle => 'Títol';
	@override String get paneShowHeader => 'Mostra la capçalera';
	@override String get paneShowHeaderTabset => 'Sempre visible mentre aquest panell comparteix un grup — la capçalera és com s\'accedeix als altres';
	@override String get paneInherit => 'Igual que l\'aplicació';
	@override String get searchHint => 'Cerca panells';
	@override String get noPanelsMatch => 'Cap panell coincideix amb la cerca.';
	@override String get nothingToAdd => 'Aquesta vista ja té tots els panells possibles';
	@override String addPanel({required Object panel}) => 'Afegeix ${panel}';
	@override String showPreview({required Object panel}) => 'Previsualitza ${panel}';
	@override String missingExtension({required Object name}) => 'Falta l\'extensió "${name}"';
	@override String get missingExtensionEnable => 'Activa';
	@override String get missingExtensionInstall => 'Instal·la…';
	@override String get missingExtensionWontRun => 'Aquesta versió no s\'executarà. Actualitza-la a Configuració › Extensions.';
	@override String get missingExtensionUnavailable => 'No disponible en aquesta aplicació';
	@override String get missingExtensionNotInCatalog => 'No és al catàleg';
	@override String get missingExtensionCatalogUnreachable => 'No s\'ha pogut accedir al catàleg. Torna-ho a provar';
	@override String get missingExtensionFailed => 'No ha funcionat. Torna-ho a provar';
	@override String get previewUnavailable => 'No s\'ha pogut mostrar la imatge de previsualització d\'aquest panell.';
	@override String get nestedPaneTitle => 'Més';
	@override late final _Translations$operation$layout$layouts$ca layouts = _Translations$operation$layout$layouts$ca._(_root);
	@override String get editLayout => 'Edita la disposició';
	@override String get saveLayout => 'Desa la disposició';
	@override String get revertLayout => 'Descarta els canvis de disposició';
	@override String get done => 'Fet';
	@override String get layoutUnreadableTitle => 'No s\'ha pogut llegir la disposició';
	@override String get layoutUnreadableBody => 'No s\'ha pogut llegir la disposició desada, així que es mostra la disposició per defecte. No se sobreescriurà l\'original fins que decideixis quedar-te aquesta.';
	@override String get layoutUnreadableAction => 'Utilitza aquesta disposició';
	@override String panelRenderFailed({required Object panel}) => 'No s\'ha pogut mostrar ${panel}';
	@override String panelOverCharacters({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: ha enviat més de ${max} caràcters';
	@override String panelOverElements({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix té més de ${max} elements';
	@override String panelOverDepth({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix té més de ${max} nivells d\'imbricació';
	@override String panelNotArtwork({required Object panel}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix no és autocontingut';
	@override String panelOverLayers({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva escena té més de ${max} capes';
	@override String panelOverControls({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva escena té més de ${max} controls';
	@override String panelOverItems({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: una part de la seva escena té més de ${max} entrades';
	@override String panelOverStringLength({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: una cadena de l\'escena té més de ${max} caràcters';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva disposició té més de ${max} nivells d\'imbricació';
	@override String get panelRenderRetry => 'Torna-ho a provar';
	@override String get panelActionFailed => 'L\'acció del panell ha fallat. Torna-ho a provar.';
	@override late final _Translations$operation$layout$panels$ca panels = _Translations$operation$layout$panels$ca._(_root);
	@override String get htmlPanelUnsupported => 'Aquest panell necessita una vista web, que aquesta plataforma no ofereix';
	@override String get htmlPanelUnsupportedOnWeb => 'Aquest panell necessita un entorn aïllat que la versió web no pot oferir';
}

// Path: operation.export
class _Translations$operation$export$ca extends Translations$operation$export$en {
	_Translations$operation$export$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportacions de l\'operació';
	@override String get syncedOperation => 'L\'operació està sincronitzada';
	@override String get unsyncedOperation => 'L\'operació té canvis sense sincronitzar';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} QSO en aquesta operació',
		other: '${count} QSOs en aquesta operació',
	);
	@override String qsosSynced({required Object total}) => 'Els ${total} QSOs estan sincronitzats';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendents de sincronitzar';
	@override String eventsSynced({required Object total}) => '${total} marcadors d\'esdeveniment sincronitzats';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} de ${total} marcadors d\'esdeveniment pendents';
	@override String get loading => 'Carregant les opcions d\'exportació…';
	@override String get noOptions => 'No hi ha formats d\'exportació disponibles (les extensions encara s\'estan iniciant?)';
	@override String get nothingLogged => 'Encara no hi ha res per exportar — aquesta operació no té QSOs.';
	@override String get share => 'Comparteix';
	@override String get nothingSelected => 'No hi ha res seleccionat';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Desa ${count} fitxer',
		other: 'Desa ${count} fitxers',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Comparteix ${count} fitxer',
		other: 'Comparteix ${count} fitxers',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Exporta ${count} fitxer',
		other: 'Exporta ${count} fitxers',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Descarrega ${count} fitxer',
		other: 'Descarrega ${count} fitxers',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Desa ${count} fitxer combinat',
		other: 'Desa ${count} fitxers combinats',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Comparteix ${count} fitxer combinat',
		other: 'Comparteix ${count} fitxers combinats',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Exporta ${count} fitxer combinat',
		other: 'Exporta ${count} fitxers combinats',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Descarrega ${count} fitxer combinat',
		other: 'Descarrega ${count} fitxers combinats',
	);
	@override String saveOne({required Object name}) => 'Desa ${name}';
	@override String shareOne({required Object name}) => 'Comparteix ${name}';
	@override String exportOne({required Object name}) => 'Exporta ${name}';
	@override String downloadOne({required Object name}) => 'Descarrega ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Desa ${count} fitxer a l\'Stash',
		other: 'Desa ${count} fitxers a l\'Stash',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Desa ${count} fitxer combinat a l\'Stash',
		other: 'Desa ${count} fitxers combinats a l\'Stash',
	);
	@override String get settingsButton => 'Configuració d\'exportació';
	@override String get settingsTitle => 'Configuració d\'exportació';
	@override late final _Translations$operation$export$compactFileNames$ca compactFileNames = _Translations$operation$export$compactFileNames$ca._(_root);
	@override late final _Translations$operation$export$includePrivateData$ca includePrivateData = _Translations$operation$export$includePrivateData$ca._(_root);
	@override String get resultTitle => 'Exportació completada';
	@override String get resultFailedTitle => 'L\'exportació ha fallat';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha exportat ${count} fitxer a ${path}',
		other: 'S\'han exportat ${count} fitxers a ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha exportat ${count} fitxer: ${path}',
		other: 'S\'han exportat ${count} fitxers: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha compartit ${count} fitxer',
		other: 'S\'han compartit ${count} fitxers',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha descarregat ${count} fitxer',
		other: 'S\'han descarregat ${count} fitxers',
	);
	@override String exportFailed({required Object error}) => 'L\'exportació ha fallat: ${error}';
	@override late final _Translations$operation$export$stash$ca stash = _Translations$operation$export$stash$ca._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$ca extends Translations$operation$spots$en {
	_Translations$operation$spots$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Cap anunci coincideix amb els filtres';
	@override String error({required Object error}) => 'No s\'han pogut carregar els anuncis: ${error}';
	@override String get unknownBand => 'Altres';
	@override String get auto => 'Automàtic';
	@override String autoValue({required Object value}) => 'Automàtic (Actualment ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Qualsevol';
	@override String get allBands => 'Totes les bandes';
	@override String get allModes => 'Tots els modes';
	@override String get phoneAndCw => 'Fonia i CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} anunci',
		other: '${count} anuncis',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Mostrant ${count} de ${total} anuncis';
	@override String get spotsDisabled => 'Anuncis desactivats en aquesta operació';
	@override String ageMinutes({required Object minutes}) => '${minutes} minuts';
	@override String get callsOfNote => 'Indicatius destacats';
	@override String get yourSpots => 'Els teus anuncis';
	@override String get allSpots => 'Tots els anuncis';
	@override late final _Translations$operation$spots$continents$ca continents = _Translations$operation$spots$continents$ca._(_root);
	@override late final _Translations$operation$spots$filters$ca filters = _Translations$operation$spots$filters$ca._(_root);
	@override String get unavailableTitle => 'Anuncis no disponibles';
	@override String unavailableText({required Object sources}) => '${sources} no ha respost.';
	@override String get failedTitle => 'Error de la font d\'anuncis';
	@override String failedText({required Object sources}) => '${sources} ha retornat un error.';
	@override String get slideLogIt => 'Registra\'l';
	@override String get slideIgnore => 'Ignora';
	@override String get slideRestore => 'Restaura';
	@override late final _Translations$operation$spots$logConflict$ca logConflict = _Translations$operation$spots$logConflict$ca._(_root);
}

// Path: operation.import
class _Translations$operation$import$ca extends Translations$operation$import$en {
	_Translations$operation$import$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa dades a l\'operació';
	@override String get importAdifAction => 'Importa QSOs des d\'ADIF';
	@override String get settingsButton => 'Configuració d\'escolta';
	@override String get settingsTitle => 'Escolta altres aplicacions';
	@override String get protocolAddressLabel => 'Adreça';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Introdueix un port entre 1 i 65535';
	@override String get protocolAddressInvalid => 'Introdueix una adreça IP vàlida (p. ex. 127.0.0.1 o 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Rebent dades';
	@override String get protocolStatusNoData => 'No s\'han rebut dades recentment';
	@override String protocolBindError({required Object error}) => 'No s\'ha pogut començar a escoltar: ${error}';
	@override String captureFailed({required Object error}) => 'No s\'han pogut desar els QSOs entrants i s\'està tornant a provar: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Qualsevol (difusió)';
	@override String get wsjtxProtocolName => 'Servidor UDP de WSJT-X';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → pestanya Broadcast Data → marca "Enable Broadcasts" per a la informació de contacte. Posa l\'adreça IP 127.0.0.1 si s\'executa en aquest mateix ordinador, o 255.255.255.255 per difondre a la xarxa local actual.';
	@override String get helpWsjtxSetup => 'File → Settings → pestanya Reporting → secció UDP Server → marca "Accept UDP requests". Posa el servidor UDP a 127.0.0.1 si s\'executa en aquest mateix ordinador, o una adreça multicast com 239.239.0.2, i utilitza la mateixa adreça a la configuració de dalt d\'aquesta aplicació.';
	@override String get listenTitle => 'Escolta QSOs d\'altres aplicacions';
	@override String get listenDescriptionOnN1mm => 'Escoltant N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Escoltant WSJT-X';
	@override String get listenDescriptionOnBoth => 'Escoltant N1MM+ i WSJT-X';
	@override String get listenDescriptionOff => 'Desactivat';
	@override String get addToOperationTitle => 'Afegeix a aquesta operació';
	@override String get addToOperationDescriptionOn => 'Els QSOs capturats s\'afegeixen a aquesta operació a mesura que arriben';
	@override String get addToOperationDescriptionOff => 'Els QSOs capturats es retenen fins que activis això';
	@override String get pendingSectionTitle => 'QSOs capturats';
	@override String get pendingEmpty => 'Encara no s\'ha capturat res';
	@override String stationMismatch({required Object call}) => 'Registrat com a ${call}, no l\'estació d\'aquesta operació';
	@override String get discardAction => 'Descarta';
	@override String get gapDialogTitle => 'Incloure captures anteriors?';
	@override String gapDialogBody({required Object count}) => 'S\'han capturat ${count} QSOs més abans, abans d\'un buit en les dades. Vols incloure\'ls també?';
	@override String get gapDialogRecentOnly => 'Només els recents';
	@override String gapDialogIncludeAll({required Object count}) => 'Inclou-los tots (${count})';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$ca extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problemes?';
	@override String get title => 'Informa d\'un problema amb un contorn';
	@override String get reference => 'Quin contorn';
	@override String get severity => 'Com de greu és?';
	@override String get minor => 'Detall menor';
	@override String get major => 'Greu';
	@override String get explanation => 'Què hi ha de malament?';
	@override String get explanationHint => 'Què fa malament el contorn, i on';
	@override String get send => 'Envia';
	@override String get sending => 'Enviant el teu informe — gràcies';
	@override String get copy => 'Copia l\'informe';
	@override String get notSent => 'No s\'ha pogut enviar l\'informe';
	@override String get copied => 'Informe copiat';
	@override String get notCopied => 'No s\'ha pogut copiar l\'informe';
}

// Path: map.postcard
class _Translations$map$postcard$ca extends Translations$map$postcard$en {
	_Translations$map$postcard$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get button => 'Postal de l\'operació';
	@override String title({required Object title}) => 'Postal de ${title}';
	@override String get portrait => 'Vertical';
	@override String get landscape => 'Horitzontal';
	@override String get square => 'Quadrada';
	@override String get save => 'Desa…';
	@override String get download => 'Descarrega';
	@override String get share => 'Comparteix';
	@override String get copy => 'Copia';
	@override String get copied => 'Copiat al porta-retalls';
	@override String saved({required Object path}) => 'Desat a ${path}';
	@override String downloaded({required Object name}) => 'S\'ha descarregat ${name}';
	@override String savedMany({required Object count, required Object path}) => 'S\'han desat ${count} imatges a ${path}';
	@override String savedFiles({required Object names}) => 'S\'ha desat ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} ja s\'havia desat';
	@override String downloadedMany({required Object count}) => 'Descarregant ${count} imatges — permet-les si el navegador ho demana';
	@override String get mapLeftOut => 'El mapa no s\'ha carregat, així que s\'ha omès';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — el mapa no s\'ha carregat, així que s\'ha omès';
	@override String continued({required Object title}) => '${title} (continuació)';
	@override String get previousPage => 'Pàgina anterior';
	@override String get nextPage => 'Pàgina següent';
	@override String pageOf({required Object page, required Object count}) => 'Pàgina ${page} de ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} Q',
		other: '${count} Qs',
	);
	@override String get options => 'Opcions de la postal';
	@override String get bandLegend => 'Mostra la llegenda de bandes';
	@override String get grayline => 'Mostra la línia grisa';
	@override String get sectionsAndOrder => 'Seccions del resum i ordre';
	@override String get sectionDays => 'Cada dia';
	@override String get reset => 'Restableix';
	@override String failed({required Object error}) => 'No s\'ha pogut fer la postal: ${error}';
	@override String get mapNotReady => 'El mapa no ha acabat de carregar-se. Comprova la connexió i torna-ho a provar.';
	@override String saveFailed({required Object error}) => 'No s\'ha pogut desar la postal: ${error}';
	@override String get copyFailed => 'El porta-retalls no ha acceptat la imatge. Torna-ho a provar.';
	@override String get shareFailed => 'No s\'ha pogut compartir la postal. Torna-ho a provar.';
	@override String get fileName => 'postal';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$ca extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Cap QSO encara… Som-hi, sortim a l\'aire!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} en ${time}';
	@override String sinceLast({required Object time}) => '${time} des de l\'últim';
	@override String ratePer10({required Object rate}) => '${rate} Q/h per als últims 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h per als últims 100';
	@override String distanceTo({required Object distance}) => '${distance} fins a';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) fins a';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) fins a';
	@override String distanceAway({required Object distance}) => 'a ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplicat!';
	@override String get noticeNewBand => 'Banda Nova';
	@override String get noticeNewMode => 'Mode Nou';
	@override String get noticeNewDXCC => 'DXCC Nou';
	@override String get noticeNewState => 'Estat Nou';
	@override String get noticeNewProvince => 'Província Nova';
	@override String get noticeNewDay => 'Dia Nou';
	@override String get noticeNewRef => 'Ref. Nova';
	@override String get noticeNewMult => 'Nou Multiplicador';
	@override String get noticeNewZone => 'Zona Nova';
	@override String get noticeInvalidMode => 'Mode Incorrecte';
	@override String get noticeInvalidBand => 'Banda Incorrecta';
	@override String get noticeInvalidCategory => 'No Treballable';
	@override String get noticeOverTime => 'Fora de Temps';
	@override String get noticeWorkedBefore => 'Ja Treballat';
	@override String get noticeNewPark => 'Parc Nou';
	@override String get noticeNewSection => 'Secció Nova';
	@override String get noticeBonusStation => 'Estació Bonus!';
	@override String get noticeMissingExchange => 'Sense Intercanvi';
	@override String get noticeInvalidExchange => 'Intercanvi Erroni';
	@override String get noticeUnknownEvent => 'Esdeveniment Desconegut';
	@override String get noticeIncompleteCall => 'Indicatiu Incomplet — No Puntua';
	@override String get noticeOurGrid => 'Defineix la nostra graella';
	@override String get noticeRareCounty => 'Comtat rar!';
	@override String get noticeOurLocation => 'Defineix el nostre comtat';
	@override String get noticeShortGrid => 'Graella massa curta';
}

// Path: qsoList.find
class _Translations$qsoList$find$ca extends Translations$qsoList$find$en {
	_Translations$qsoList$find$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'Cerca al registre (${shortcut})';
	@override String get menuItemNoShortcut => 'Cerca al registre';
	@override String get hint => 'Número de QSO o indicatiu';
	@override String get noMatches => 'Cap coincidència';
	@override String get noOperationQsos => 'No hi ha QSOs en aquesta operació';
	@override String get noPeriodQsos => 'No hi ha QSOs en aquest període';
	@override String get outsideQsosOne => '1 QSO fora d\'aquesta operació';
	@override String outsideQsosOther({required Object count}) => '${count} QSOs fora d\'aquesta operació';
	@override String get pastQsosOne => '1 QSO anterior';
	@override String pastQsosOther({required Object count}) => '${count} QSOs anteriors';
}

// Path: callInfo.history
class _Translations$callInfo$history$ca extends Translations$callInfo$history$en {
	_Translations$callInfo$history$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} en els darrers 7 dies';
	@override String today({required Object n}) => '${n} avui';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class _Translations$settings$theme$ca extends Translations$settings$theme$en {
	_Translations$settings$theme$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mode del tema';
	@override String get system => 'Segueix la configuració del sistema';
	@override String get light => 'Clar';
	@override String get dark => 'Fosc';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$ca extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get system => 'Seguint la configuració del sistema';
	@override String get light => 'Sempre en mode clar';
	@override String get dark => 'Sempre en mode fosc';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$ca extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'La més petita--';
	@override String get smallestMinus => 'La més petita-';
	@override String get smallest => 'La més petita';
	@override String get smaller => 'Més petita';
	@override String get normal => 'Normal';
	@override String get larger => 'Més gran';
	@override String get largest => 'La més gran';
	@override String get largestPlus => 'La més gran+';
	@override String get largestPlusPlus => 'La més gran++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$ca extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mantén el dispositiu despert';
	@override String get descriptionOn => 'Es manté despert mentre ets a la vista de registre o hi ha una sincronització en curs';
	@override String get descriptionOff => 'Entra en repòs com sempre';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$ca extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automàtica';
	@override String get densest => 'Màxima';
	@override String get dense => 'Densa';
	@override String get normal => 'Normal';
	@override String get sparse => 'Espaiada';
	@override String get sparsest => 'Molt espaiada';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$ca extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Quilòmetres';
	@override String get miles => 'Milles';
}

// Path: settings.logging
class _Translations$settings$logging$ca extends Translations$settings$logging$en {
	_Translations$settings$logging$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registre';
	@override late final _Translations$settings$logging$leftieMode$ca leftieMode = _Translations$settings$logging$leftieMode$ca._(_root);
	@override late final _Translations$settings$logging$countryFlags$ca countryFlags = _Translations$settings$logging$countryFlags$ca._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$ca countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$ca._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$ca suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$ca._(_root);
	@override late final _Translations$settings$logging$showBearing$ca showBearing = _Translations$settings$logging$showBearing$ca._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$ca showReverseBearing = _Translations$settings$logging$showReverseBearing$ca._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$ca switchSentRcvd = _Translations$settings$logging$switchSentRcvd$ca._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$ca jumpAfterRST = _Translations$settings$logging$jumpAfterRST$ca._(_root);
	@override late final _Translations$settings$logging$defaultReport$ca defaultReport = _Translations$settings$logging$defaultReport$ca._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$ca defaultReportCW = _Translations$settings$logging$defaultReportCW$ca._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$ca defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$ca._(_root);
	@override late final _Translations$settings$logging$numbersRow$ca numbersRow = _Translations$settings$logging$numbersRow$ca._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$ca numbersRowExtra = _Translations$settings$logging$numbersRowExtra$ca._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$ca numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$ca._(_root);
	@override String get bands => 'Bandes preferides';
	@override String get modes => 'Modes preferits';
}

// Path: settings.catServer
class _Translations$settings$catServer$ca extends Translations$settings$catServer$en {
	_Translations$settings$catServer$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor CAT';
	@override String get description => 'Permet que altres aplicacions (WSJT-X, programes de registre, etc.) controlin la ràdio a través de Ham2K Logger.';
	@override String get protocol => 'Protocol';
	@override late final _Translations$settings$catServer$protocolOpts$ca protocolOpts = _Translations$settings$catServer$protocolOpts$ca._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Accés obert';
	@override String get openAccessOn => 'Qualsevol ordinador de la xarxa local es pot connectar.';
	@override String get openAccessOff => 'Només es poden connectar aplicacions d\'aquest ordinador.';
	@override String get allowTransmit => 'Permet que les aplicacions transmetin';
	@override String allowTransmitOn({required Object minutes}) => 'Les aplicacions poden activar el PTT de la ràdio, fins a ${minutes} minuts seguits.';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'Les aplicacions de qualsevol ordinador de la xarxa local poden activar el PTT de la ràdio, fins a ${minutes} minuts seguits.';
	@override String get allowTransmitOff => 'Les aplicacions no poden activar el PTT de la ràdio. Fes servir VOX o el seu propi sistema de PTT.';
	@override String get allowTransmitUnsupported => 'La ràdio del VFO principal no es pot posar en transmissió des de Ham2K Logger, així que les aplicacions no hi poden transmetre.';
	@override String get off => 'Desactivat.';
	@override String starting({required Object protocol}) => '${protocol}, iniciant…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} al port ${port}. Clients connectats: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} al port ${port}, però no hi ha cap ràdio de VFO principal connectada.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} no pot escoltar al port ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} no pot escoltar al port ${port}: un altre programa l\'està fent servir, sovint el mateix ${protocol}. Tanca aquest programa o tria un altre port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} no pot escoltar al port ${port}: aquest ordinador no ho permet. Tria un port per sobre de 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} ha deixat d\'escoltar al port ${port}. Tornant-ho a provar…';
}

// Path: settings.cluster
class _Translations$settings$cluster$ca extends Translations$settings$cluster$en {
	_Translations$settings$cluster$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Clúster DX';
	@override String get description => 'El servidor on les extensions publiquen i llegeixen anuncis, amb la sessió iniciada com a operador.';
	@override String get connect => 'Connecta al clúster';
	@override String get connectOn => 'Les extensions es connecten al clúster quan ho necessiten';
	@override String get connectOff => 'Res no es connecta al clúster';
	@override String get console => 'Mostra la consola';
	@override String get consoleDescription => 'El que envia el clúster, i un lloc per escriure ordres';
	@override String get consoleTitle => 'Consola del clúster';
	@override String get consoleConnect => 'Connecta';
	@override String get consoleDisconnect => 'Desconnecta';
	@override String get consoleCommand => 'Ordre';
	@override String get consoleEmpty => 'Encara no hi ha res. Connecta\'t, o espera que una extensió faci servir el clúster.';
	@override String consoleRetry({required Object command}) => 'Enviant de nou: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => 'No enviat: ${command} (${reason})';
	@override String get server => 'Servidor del clúster';
	@override String get selectServer => 'Selecciona el servidor';
	@override String get serverOther => 'Altres';
	@override String serverOtherIncomplete({required Object node}) => 'Encara no s\'ha introduït cap servidor, així que els anuncis van a ${node}';
	@override String get customHost => 'Servidor';
	@override String get customPort => 'Port';
	@override String get password => 'Contrasenya';
	@override String get passwordDescription => 'Només si cal';
	@override String passwordStored({required Object node}) => 'Contrasenya desada per a ${node}';
	@override String get scrollback => 'Línies conservades';
	@override String scrollbackOpt({required Object count}) => '${count} línies';
	@override String get connection => 'Connexió';
	@override String get statusIdle => 'No connectat. Es connecta quan una extensió ho necessita. Toca per provar.';
	@override String statusConnecting({required Object node}) => 'Connectant a ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'Connectat a ${node} com a ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'No s\'ha pogut connectar a ${node}: ${reason}';
	@override String get statusUnsupported => 'No disponible a la versió web.';
	@override String get statusOff => 'Desactivat. Activa Connecta al clúster per fer-lo servir.';
	@override late final _Translations$settings$cluster$errors$ca errors = _Translations$settings$cluster$errors$ca._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$ca extends Translations$settings$spotting$en {
	_Translations$settings$spotting$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Anuncis';
	@override String get respotInterval => 'Re-anunci automàtic cada';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'Re-anunci automàtic per defecte';
	@override String get autoRespotByDefaultOn => 'Activa el re-anunci automàtic després de publicar qualsevol anunci';
	@override String get autoRespotByDefaultOff => 'Cal una acció de l\'usuari per activar el re-anunci automàtic';
	@override String get pulseBeforeRespot => 'Pulsació abans de cada re-anunci automàtic';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'El xip d\'Anunci fa pulsacions blaves durant els ${seconds} segons previs a cada re-anunci';
	@override String get pulseBeforeRespotOff => 'Sense pulsacions abans d\'un re-anunci automàtic';
}

// Path: settings.radio
class _Translations$settings$radio$ca extends Translations$settings$radio$en {
	_Translations$settings$radio$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Control CAT';
	@override String get loggingAndCat => 'Registre i CAT';
	@override String get tuningSection => 'Sintonia';
	@override String get keyerSection => 'Manipulador';
	@override String get servicesSection => 'Serveis';
	@override String get stationConfigurationSection => 'Configuració de l\'estació';
	@override String get moreSettings => 'Més opcions de configuració de l\'estació';
	@override late final _Translations$settings$radio$units$ca units = _Translations$settings$radio$units$ca._(_root);
	@override late final _Translations$settings$radio$pttKey$ca pttKey = _Translations$settings$radio$pttKey$ca._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$ca smartVfoSnap = _Translations$settings$radio$smartVfoSnap$ca._(_root);
	@override late final _Translations$settings$radio$snapDebounce$ca snapDebounce = _Translations$settings$radio$snapDebounce$ca._(_root);
	@override late final _Translations$settings$radio$snapLongMove$ca snapLongMove = _Translations$settings$radio$snapLongMove$ca._(_root);
	@override late final _Translations$settings$radio$snapMinMove$ca snapMinMove = _Translations$settings$radio$snapMinMove$ca._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$ca snapMinSpeed = _Translations$settings$radio$snapMinSpeed$ca._(_root);
	@override late final _Translations$settings$radio$enterSends$ca enterSends = _Translations$settings$radio$enterSends$ca._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$ca keyerSpeed = _Translations$settings$radio$keyerSpeed$ca._(_root);
	@override late final _Translations$settings$radio$cwMessages$ca cwMessages = _Translations$settings$radio$cwMessages$ca._(_root);
	@override late final _Translations$settings$radio$keyerControl$ca keyerControl = _Translations$settings$radio$keyerControl$ca._(_root);
	@override late final _Translations$settings$radio$voiceMessages$ca voiceMessages = _Translations$settings$radio$voiceMessages$ca._(_root);
	@override late final _Translations$settings$radio$voiceWords$ca voiceWords = _Translations$settings$radio$voiceWords$ca._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$ca avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$ca._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$ca zeroBeatRange = _Translations$settings$radio$zeroBeatRange$ca._(_root);
}

// Path: settings.help
class _Translations$settings$help$ca extends Translations$settings$help$en {
	_Translations$settings$help$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuda i recursos';
	@override String get description => 'Comunitat i suport';
	@override String get forums => 'Fòrums Ham2K';
	@override String get forumsDescription => 'Troba ajuda, envia comentaris i discuteix idees…';
	@override String get chat => 'Xat Ham2K';
	@override String get chatDescription => 'El servidor de Discord per a la nostra comunitat en línia';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Vídeos i transmissions en directe';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Perquè mai tens massa fotos…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Segueix-nos per a notícies i actualitzacions';
	@override String get contact => 'Contacta amb nosaltres';
	@override String get contactDescription => 'help@ham2k.com — però prova primer els Fòrums o el Xat!';
}

// Path: settings.exports
class _Translations$settings$exports$ca extends Translations$settings$exports$en {
	_Translations$settings$exports$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportacions';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$ca extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get activities => 'Activitats';
	@override String get hunting => 'Caça';
	@override String get contests => 'Concursos';
	@override String get lookups => 'Consultes';
	@override String get dashboard => 'Tauler';
}

// Path: settings.map
class _Translations$settings$map$ca extends Translations$settings$map$en {
	_Translations$settings$map$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapes';
	@override late final _Translations$settings$map$style$ca style = _Translations$settings$map$style$ca._(_root);
	@override late final _Translations$settings$map$showCallsigns$ca showCallsigns = _Translations$settings$map$showCallsigns$ca._(_root);
	@override late final _Translations$settings$map$showGrayline$ca showGrayline = _Translations$settings$map$showGrayline$ca._(_root);
	@override late final _Translations$settings$map$styleOpts$ca styleOpts = _Translations$settings$map$styleOpts$ca._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$ca extends Translations$settings$privacy$en {
	_Translations$settings$privacy$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacitat';
	@override late final _Translations$settings$privacy$shareAppData$ca shareAppData = _Translations$settings$privacy$shareAppData$ca._(_root);
	@override late final _Translations$settings$privacy$shareOpData$ca shareOpData = _Translations$settings$privacy$shareOpData$ca._(_root);
	@override String get privacyPolicy => 'Política de privacitat';
	@override String get termsOfService => 'Condicions de servei';
}

// Path: settings.sync
class _Translations$settings$sync$ca extends Translations$settings$sync$en {
	_Translations$settings$sync$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronització al núvol';
	@override String get moreSettings => 'Més opcions de sincronització';
	@override String get enable => 'Activa la sincronització';
	@override String get deviceKey => 'Clau del dispositiu';
}

// Path: settings.peers
class _Translations$settings$peers$ca extends Translations$settings$peers$en {
	_Translations$settings$peers$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispositius associats';
	@override String get enable => 'Connecta amb altres dispositius';
	@override String get enableDescription => 'Permet compartir operacions, registre, CAT i GPS amb altres dispositius per la xarxa local';
	@override String get bleEnable => 'Connecta per Bluetooth';
	@override String get bleDescription => 'Utilitza Bluetooth LE per connectar encara que no hi hagi xarxa local';
	@override String get thisDevice => 'Aquest dispositiu';
	@override String get deviceName => 'Nom';
	@override String get deviceNameHint => 'Com veuen aquest dispositiu els altres dispositius';
	@override String get pairedDevices => 'Dispositius vinculats';
	@override String get noPairedDevices => 'Encara no hi ha dispositius vinculats. Activa això en un altre dispositiu d\'aquesta xarxa per vincular-los.';
	@override String deviceListProblem({required Object error}) => 'No es poden llegir els teus dispositius vinculats: ${error}';
	@override String get nearby => 'A prop';
	@override String get connected => 'Connectat';
	@override String get viaBluetooth => 'per Bluetooth';
	@override String get connecting => 'Connectant…';
	@override String get syncing => 'Sincronitzant…';
	@override String get waitingForThem => 'Esperant l\'altre dispositiu';
	@override String get notConnected => 'No connectat';
	@override String get wantsToPair => 'vol compartir aquesta operació';
	@override String get allow => 'Permet';
	@override String get link => 'Vincula';
	@override String get reject => 'Rebutja';
	@override String get forget => 'Oblida';
	@override String forgetTitle({required Object name}) => 'Oblidar ${name}?';
	@override String get forgetBody => 'Deixarà de sincronitzar-se amb aquest dispositiu. El pots tornar a permetre més endavant, i els contactes ja registrats es conserven.';
	@override String pairTitle({required Object name}) => 'Vincula amb ${name}';
	@override String get pairBody => 'Aquest dispositiu és a la teva xarxa local i vol connectar-se.';
	@override String get pairBodyBle => 'Aquest dispositiu és a prop i vol connectar-se per Bluetooth LE.';
	@override String get pairIdLabel => 'ID del dispositiu';
	@override String get pairWarning => 'Vincula només dispositius que reconeguis. Qualsevol dispositiu d\'aquesta xarxa pot enviar una sol·licitud.';
	@override String get pairWarningBle => 'Vincula només dispositius que reconeguis. Qualsevol dispositiu proper pot enviar una sol·licitud.';
	@override String problem({required Object error}) => 'No es pot accedir a la xarxa local: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Connectat a ${device}';
	@override String statusLost({required Object device}) => 'S\'ha perdut la connexió amb ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispositius associats: ${connected} de ${linked} connectats';
	@override String get screenEnable => 'Comparteix pantalles i finestres';
	@override String get screenDescription => 'Permet que altres dispositius mostrin pantalles o finestres d\'aquest ordinador';
	@override String get screenSources => 'Pantalles i finestres';
	@override String get screenRefresh => 'Actualitza la llista';
	@override String get screenUnsupportedPlatform => 'Aquest dispositiu no pot compartir la seva pantalla. macOS sí que pot; qualsevol dispositiu pot mostrar-ne una compartida per un altre.';
	@override String get screenUnsupportedVersion => 'Compartir una pantalla requereix macOS 12.3 o posterior. Aquest dispositiu encara pot mostrar una pantalla compartida per un altre.';
	@override String get screenNeedsPermission => 'macOS necessita el teu permís per gravar la pantalla abans que aquesta aplicació en pugui compartir una.';
	@override String get screenGrantPermission => 'Demana permís';
	@override String get screenRelaunchAfterGranting => 'Permet-ho a Configuració del Sistema, a Privacitat i seguretat → Gravació de pantalla, i després surt i torna a obrir aquesta aplicació: macOS només informa una aplicació del canvi en el següent inici.';
	@override String screenProblem({required Object error}) => 'Compartició de pantalla: ${error}';
	@override String get screenChooseTitle => 'Tria què vols compartir';
	@override String get screenChooseButton => 'Tria què vols compartir…';
	@override String get screenTabScreens => 'Pantalles';
	@override String get screenTabApps => 'Aplicacions';
	@override String get screenTabWindows => 'Finestres';
	@override String get screenTabEmpty => 'No s\'ha trobat res d\'aquest tipus.';
	@override String get screenSharedSummaryNone => 'Encara no s\'ha triat res.';
	@override String get screenThisDevice => 'Aquest dispositiu';
	@override String screenSharedTo({required Object devices}) => 'Es mostra a ${devices}';
	@override String get screenSharedToNobody => 'No es mostra enlloc';
	@override String screenStopSharing({required Object name}) => 'Deixa de compartir ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$ca extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuració de sincronització';
	@override String get enableTitle => 'Sincronitza amb Ham2K Log Filer';
	@override String get enabledDescription => 'Es fa còpia de seguretat del teu registre i se sincronitza entre dispositius';
	@override String get disabledDescription => 'Desactivat — només es queda en aquest dispositiu';
	@override String get syncing => 'Sincronitzant';
	@override String get account => 'Compte';
	@override String get refresh => 'Refresca';
	@override String get switchAccounts => 'Canvia de compte';
	@override String get switchAccountsDescription => 'Vincula aquest dispositiu a un altre compte amb un codi QR o correu electrònic';
	@override String get connectionRequests => 'Sol·licituds de connexió';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Un dispositiu espera unir-se a aquest compte',
		other: '${n} dispositius esperen unir-se a aquest compte',
	);
	@override String get accountEmailTitle => 'Correu electrònic del compte';
	@override String accountEmailSent({required Object email}) => 'S\'ha enviat la confirmació a ${email}. Obre-hi l\'enllaç per acabar el canvi.';
	@override String get resendConfirmation => 'Torna a enviar el correu de confirmació';
	@override String resendConfirmationDescription({required Object email}) => 'Esperant ${email}';
	@override String accountEmailResent({required Object email}) => 'S\'ha tornat a enviar a ${email}.';
	@override String get deviceLinked => 'Aquest dispositiu ara està vinculat a aquest compte.';
	@override String get checking => 'Comprovant…';
	@override String get notLinked => 'Encara no vinculat';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Substituir les dades locals?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${n} operació',
		other: '${n} operacions',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Dades sincronitzades';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Aquest dispositiu: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Pendent de pujar: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Aquest dispositiu: comprovant…';
	@override String get countsServerChecking => 'Servidor: comprovant…';
	@override String get countsServerUnavailable => 'Servidor: no disponible';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Això fa una còpia de seguretat i esborra ${operations} i ${qsos} d\'aquest dispositiu, i després descarrega les dades del compte. La còpia de seguretat es queda a la base de dades d\'aquest dispositiu.';
	@override String get replace => 'Substitueix';
	@override String get pendingBannerTitle => 'S\'ha detectat un compte nou de Ham2K Log Filer';
	@override String get pendingBannerBody => 'Conserva les operacions i QSOs existents d\'aquest dispositiu i combina\'ls amb el compte, o substitueix-los per les dades del compte (en tots dos casos es queda una còpia de seguretat en aquest dispositiu).';
	@override String get combine => 'Combina';
	@override String get authIssueTitle => 'La sincronització no es pot connectar';
	@override String get authIssueText => 'Ham2K Log Filer continua rebutjant aquest dispositiu. Comprova el teu indicatiu a la configuració de sincronització.';
	@override String get openSettings => 'Obre la configuració de sincronització';
}

// Path: settings.accounts
class _Translations$settings$accounts$ca extends Translations$settings$accounts$en {
	_Translations$settings$accounts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Comptes, serveis i fonts de dades';
	@override String get none => 'No hi ha extensions actives amb comptes';
	@override String get notConfigured => 'No configurat';
	@override String get connected => 'Connectat';
	@override String get cancelLogin => 'Cancel·la l\'inici de sessió';
	@override String get openInBrowser => 'Obre al navegador';
	@override String loggedInAs({required Object identity}) => 'Sessió iniciada com a ${identity}';
	@override String get pressSaveToKeep => 'Prem Desa per mantenir aquest compte connectat.';
	@override String connectedTo({required Object label}) => 'Connectat a ${label}';
	@override String get connect => 'Connecta';
	@override String get disconnect => 'Desconnecta';
	@override String get connectedAs => 'Connectat com a';
	@override String get test => 'Prova';
	@override String saveFailed({required Object error}) => 'No s\'ha pogut desar: ${error}';
	@override String loginFailed({required Object error}) => 'No s\'ha pogut iniciar la sessió: ${error}';
	@override String get lookupFailed => 'Els comptes no estan disponibles ara mateix — torna-ho a provar d\'aquí a un moment';
	@override String get browserLoginTitle => 'Acaba d\'iniciar la sessió al navegador web';
	@override String browserLoginSteps({required Object prefix}) => 'Quan acabis, el navegador intentarà obrir un enllaç que comença per "${prefix}". Probablement l\'escriptori no té res registrat per obrir-lo, així que copia aquest enllaç (de la barra d\'adreces, o de la pàgina d\'error que mostra el navegador) i enganxa\'l aquí.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger no ha pogut obrir el navegador. Copia l\'enllaç d\'inici de sessió de sota i obre\'l tu mateix, i després copia l\'enllaç al qual et porta (comença per "${prefix}") i enganxa\'l aquí.';
	@override String get copyLoginLink => 'Copia l\'enllaç d\'inici de sessió';
	@override String get pastedLinkLabel => 'Enganxa l\'enllaç aquí';
	@override String get finishLogin => 'Acaba l\'inici de sessió';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Aquest no és l\'enllaç d\'inici de sessió — hauria de començar per "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Aquest enllaç pertany a un altre intent d\'inici de sessió. Tanca aquesta pàgina i torna a connectar.';
	@override String get pastedLinkNoCode => 'Aquest enllaç no té cap codi d\'inici de sessió. Acaba primer d\'iniciar la sessió i després copia l\'enllaç al qual et porta.';
	@override String get pastedLinkMalformed => 'Sembla que aquest enllaç està tallat. Copia\'l sencer i torna\'l a enganxar.';
	@override String get relayLoginWaiting => 'Esperant que acabis d\'iniciar la sessió — continuarà automàticament quan ho facis.';
	@override String get loginNoResponse => 'Aquest dispositiu encara no ha rebut resposta de l\'inici de sessió. Si ja has acabat al navegador, cancel·la i torna a provar de connectar.';
	@override String get relayLoginNotOpened => 'Ham2K Logger no ha pogut obrir el navegador automàticament. Utilitza el botó de sota per obrir tu mateix la pàgina d\'inici de sessió.';
	@override String get relayLoginUnavailable => 'No s\'ha pogut contactar amb el servidor de sincronització necessari per completar aquest inici de sessió. Comprova la connexió i torna-ho a provar.';
	@override String get loginIncompleteResponse => 'Aquest intent d\'inici de sessió no s\'ha completat correctament. Torna a provar de connectar.';
	@override String get noKeyringTitle => 'No es poden desar els inicis de sessió dels comptes';
	@override String get noKeyringText => 'Ham2K Logger no pot accedir a cap servei de clauer en aquest ordinador, així que els inicis de sessió dels comptes no es poden desar ni llegir — connectar un compte fallarà fins que es resolgui. Instal·la i inicia **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloqueja el clauer que ja tens, i després reinicia. El registre, les exportacions i els fitxers de dades no es veuen afectats; la sincronització del registre es manté desactivada mentrestant.';
	@override String get noKeyringInline => 'No es poden desar els inicis de sessió: no es pot accedir al clauer d\'aquest ordinador. Instal·la i inicia gnome-keyring, KWallet o KeePassXC, o desbloqueja el que tens.';
	@override String get noSecureStorageInline => 'No es poden desar els inicis de sessió: no es pot accedir a l\'emmagatzematge segur d\'aquest ordinador.';
}

// Path: settings.station
class _Translations$settings$station$ca extends Translations$settings$station$en {
	_Translations$settings$station$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuració de l\'estació i control CAT';
	@override String get none => 'No hi ha cap equip configurat';
	@override String get add => 'Afegeix';
	@override String get addTitle => 'Afegeix equip';
	@override String get searchHint => 'Cerca equips';
	@override String get noMatches => 'Cap equip coincideix';
	@override String get detectedEquipment => 'Equips detectats';
	@override String discoveryUnavailable({required Object error}) => 'No es poden escoltar ràdios: ${error}';
	@override String get edit => 'Edita l\'equip';
	@override String get name => 'Nom';
	@override String get nameDescription => 'Com l\'anomenes — "Ràdio esquerra". Opcional.';
	@override String get transport => 'Connexió';
	@override String get host => 'Adreça';
	@override String get hostDescription => 'El nom de l\'amfitrió o l\'adreça IP de la ràdio a la teva xarxa.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Cal una adreça';
	@override String get portInvalid => 'El port ha d\'estar entre 1 i 65535';
	@override String get connect => 'Connecta';
	@override String get disconnect => 'Desconnecta';
	@override String get remove => 'Elimina';
	@override String removeTitle({required Object name}) => 'Eliminar ${name}?';
	@override String get removeMessage => 'Només l\'elimina de l\'aplicació. La configuració de l\'equip es queda com està.';
	@override String unknownType({required Object typeKey}) => 'Tipus d\'equip no reconegut "${typeKey}"';
	@override String get report => 'Informa';
	@override String get reportTitle => 'Informa sobre aquesta ràdio';
	@override String get reportIntro => 'Explica\'ns quina ràdio és realment i com ha anat. El teu informe es converteix en una fitxa que llegeix l\'equip de Ham2K, i el que escriguis sobre com la vas fer funcionar pot acabar ajudant el següent operador amb el mateix equip.';
	@override String get reportManufacturer => 'Fabricant';
	@override String get reportManufacturerDescription => 'Qui la fabrica — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Cal un fabricant';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'El model, tal com l\'anomena la mateixa ràdio — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'Cal un model';
	@override String get reportOutcome => 'Com ha anat?';
	@override String get reportOutcomeWorks => 'Ha funcionat bé';
	@override String get reportOutcomeIssues => 'Ha funcionat, amb problemes';
	@override String get reportOutcomeFails => 'No ha funcionat gens';
	@override String get reportOutcomeRequired => 'Explica\'ns com ha anat';
	@override String get reportComments => 'Comentaris';
	@override String get reportCommentsPlaceholder => 'Què ha funcionat, què no, qualsevol cosa que t\'hagi sorprès.';
	@override String get reportHints => 'Consells de resolució de problemes';
	@override String get reportHintsPlaceholder => 'Vols suggerir alguns consells de resolució de problemes per a altres usuaris?';
	@override String get reportSend => 'Envia l\'informe';
	@override String get reportSending => 'Enviant el teu informe…';
	@override String reportSent({required Object ref}) => 'Gràcies — el teu informe s\'ha registrat com a ${ref}.';
	@override String get reportSentNoRef => 'Gràcies — el teu informe s\'ha enviat.';
	@override String reportFailed({required Object error}) => 'L\'informe no s\'ha enviat: ${error}';
	@override String get troubleshootingNotes => 'Notes de resolució de problemes';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Utilitza com a VFO principal';
	@override String get serialPort => 'Port sèrie';
	@override String get serialPortDescription => 'El port on apareix la interfície CAT de la ràdio.';
	@override String get serialPortNone => 'No s\'ha trobat cap port sèrie';
	@override String get serialPortRequired => 'Tria un port sèrie';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} de ${total}';
	@override String get serialPortSuggested => 'suggerit';
	@override String get serialPortJustNow => 'Connectat fa poc';
	@override String get serialPortNoDriver => 'sense controlador';
	@override String get serialDeviceRequest => 'Afegeix un dispositiu USB…';
	@override String get bleDevice => 'Dispositiu Bluetooth LE';
	@override String get bleDeviceDescription => 'El pont sèrie a través del qual es connecta la teva ràdio, com un LiNK500MP en Mode 4 o un adaptador sèrie BLE.';
	@override String get bleScan => 'Cerca dispositius Bluetooth LE…';
	@override String get bleScanNoneFound => 'No s\'ha trobat cap dispositiu Bluetooth LE. Comprova que el pont està engegat, a prop, i en el seu mode Bluetooth LE (Mode 4 en un LiNK500MP).';
	@override String bleScanFailed({required Object reason}) => 'No s\'ha pogut fer la cerca Bluetooth LE: ${reason}';
	@override String get bleOff => 'El Bluetooth està desactivat.';
	@override String get bleDenied => 'No s\'ha concedit el permís de Bluetooth. Permet-lo a la configuració del sistema i torna-ho a provar.';
	@override String get bleUnsupported => 'Aquest dispositiu no té Bluetooth LE.';
	@override String get bleStarting => 'El Bluetooth encara s\'està iniciant. Torna-ho a provar d\'aquí a un moment.';
	@override String get bleConnectFailed => 'No es pot contactar amb el dispositiu Bluetooth LE. Comprova que està engegat, a prop, i que no està connectat a una altra aplicació.';
	@override String bleNoSerialService({required Object services}) => 'Aquest dispositiu Bluetooth LE no té cap servei sèrie que l\'aplicació reconegui. Informa\'n indicant els seus serveis: ${services}';
	@override String get baudRate => 'Velocitat (baud)';
	@override String get baudRateDescription => 'Ha de coincidir amb el menú CAT de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit i cap error.';
	@override String get serialRtsHigh => 'Mantén RTS alt';
	@override String get serialRtsHighDescription => 'Només per a una ràdio que espera RTS abans de respondre, com una Yaesu amb CAT RTS activat. En un Digirig, un SignaLink i la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt transmet.';
	@override String get serialDtrHigh => 'Mantén DTR alt';
	@override String get serialDtrHighDescription => 'Només per a una interfície CAT que s\'alimenta de DTR, com alguns cables RS-232 per a l\'FT-817. En molts cables DTR manipula el CW o el PTT, i mantenir-lo alt transmet.';
	@override String get serialUsbDriver => 'Controlador del xip USB';
	@override String get serialUsbDriverDescription => 'Automàtic reconeix la majoria d\'adaptadors. Tria el xip només per a un que la llista de ports digui que no té controlador — l\'embalatge o una llista de dispositius USB en diu el nom.';
	@override String get serialUsbDriverAuto => 'Automàtic';
	@override String get civAddress => 'Adreça CI-V de la ràdio';
	@override String get civAddressDescription => 'En hexadecimal, tal com es mostra al menú CI-V de la ràdio. L\'IC-705 ve amb A4.';
	@override String get civAddressInvalid => 'Una adreça CI-V té dos dígits hexadecimals, de 01 a FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'De quin slice de la ràdio llegeix i sintonitza aquesta connexió.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Tria un dels slices de la ràdio, de la A a la H';
	@override String flexSliceMissing({required Object letter}) => 'El slice ${letter} no s\'utilitza en aquesta ràdio — tria\'n un altre, o crea\'l a SmartSDR';
	@override String get channelNotInUse => 'no s\'utilitza';
	@override String get channelHeldByUnknown => 'en ús per un altre programa';
	@override String get flexNoSlices => 'Aquesta ràdio no ha informat de cap slice — comprova que SmartSDR s\'està executant i que aquest client s\'hi pot subscriure';
	@override String get spectrumUnsupported => 'Aquesta ràdio no envia l\'espectre per CAT';
	@override String get spectrumRequiresBaud => 'Requereix CAT a 115200 bps';
	@override String get spectrumNoRadio => 'No hi ha cap ràdio connectada';
	@override String get spectrumWaiting => 'Esperant l\'espectre de la ràdio…';
	@override String get spectrumUnavailable => 'La visualització de l\'espectre no està disponible';
	@override String get spectrumNoDaxChannel => 'Tots els canals DAX IQ d\'aquesta ràdio estan en ús';
	@override String get spectrumNoPanadapter => 'Aquest slice no té panadaptador a la ràdio';
	@override String spectrumStreamRefused({required Object code}) => 'La ràdio ha rebutjat un flux DAX IQ (error ${code})';
	@override String get spectrumNoUdp => 'Les dades d\'espectre de la ràdio no poden arribar a aquest dispositiu';
	@override String get spectrumK4Unavailable => 'No es pot rebre l\'espectre LAN de la K4. Tornant-ho a provar…';
	@override String get spectrumK4RemoteUnavailable => 'No es pot rebre l\'espectre remot de la K4';
	@override String get spectrumScopeRefused => 'La ràdio ha rebutjat les ordres de l\'espectroscopi';
	@override String get spectrumOutOfRange => 'L\'espectroscopi de la ràdio està configurat fora del rang que pot mostrar';
	@override String get spectrumBandUnsupported => 'L\'espectroscopi de la ràdio no es pot mostrar en aquesta banda';
	@override String get spectrumSdrNoRadio => 'Esperant la freqüència de la ràdio vinculada…';
	@override String get spectrumSdrNotConnected => 'L\'SDR no està connectat';
	@override String get spectrumSdrNoIf => 'Defineix la freqüència de FI de la ràdio a la configuració d\'aquest SDR';
	@override String get sdrRadio => 'Mostra l\'espectre de';
	@override String get sdrRadioDescription => 'Una visualització d\'espectre en aquesta ràdio es dibuixa a partir d\'aquest receptor en lloc de l\'espectroscopi de la mateixa ràdio.';
	@override String get sdrRadioMain => 'La ràdio principal';
	@override String get sdrTuning => 'Entrada d\'antena';
	@override String get sdrTuningDescription => 'D\'on ve el senyal del receptor. Amb la seva pròpia antena, se sintonitza sol per seguir la ràdio; a la sortida de FI de la ràdio, es queda a la FI.';
	@override String get sdrTuningIndependent => 'La seva pròpia antena';
	@override String get sdrTuningIfTap => 'La sortida de FI de la ràdio';
	@override String get sdrIfHz => 'Freqüència de FI (Hz)';
	@override String get sdrIfHzDescription => 'Només per a una sortida de FI: la freqüència on es troba el dial de la ràdio a la seva FI, com 68330000 en un FT-817.';
	@override String get sdrIfInverted => 'La FI està invertida';
	@override String get sdrGainDb => 'Guany (dB)';
	@override String get sdrGainDbDescription => 'Deixa-ho en blanc per al guany automàtic del receptor.';
	@override String get sdrOffsetHz => 'Desplaçament de freqüència (Hz)';
	@override String get sdrOffsetHzDescription => 'S\'afegeix a cada freqüència enviada al receptor, per a un convertidor ascendent: 125000000 per a un Ham It Up.';
	@override String get sdrPpm => 'Correcció de freqüència (ppm)';
	@override String get rtlDirectSampling => 'Mostreig directe';
	@override String get rtlDirectSamplingDescription => 'Per a HF en un RTL-SDR V3 sense convertidor ascendent. Un RTL-SDR V4 arriba a HF sense.';
	@override String get rtlDirectSamplingOff => 'Desactivat';
	@override String get rtlDirectSamplingI => 'Branca I';
	@override String get rtlDirectSamplingQ => 'Branca Q';
	@override String get rtlTcpNotAServer => 'Això no és un servidor rtl_tcp';
	@override String get rtlTcpNotes => 'Això es connecta a un **servidor rtl_tcp que executes tu mateix** a l\'ordinador on hi ha endollat el dongle.\n\n- **Inicia\'l** amb `rtl_tcp -a 0.0.0.0` perquè altres màquines hi puguin accedir; a la mateixa màquina, n\'hi ha prou amb `rtl_tcp`.\n- **El port** és el 1234 tret que l\'hagis iniciat amb `-p`.\n- **Un programa alhora:** rtl_tcp serveix un sol client. L\'aplicació només s\'hi connecta mentre es mostra una visualització d\'espectre, i el deixa anar uns segons després de tancar-la.\n- **A Android**, l\'aplicació *SDR driver* executa el mateix servidor al telèfon.';
	@override String get rspTcpNotes => 'Això es connecta a un **servidor rsp_tcp que executes tu mateix** a l\'ordinador on hi ha endollat l\'RSP, amb l\'API de SDRplay instal·lada.\n\n- **Inicia\'l** amb `rsp_tcp -a 0.0.0.0`.\n- **El port** és el 1234 tret que l\'hagis iniciat amb `-p`.\n- **Un programa alhora:** el servidor accepta un sol client. L\'aplicació només s\'hi connecta mentre es mostra una visualització d\'espectre.';
	@override String get n3fjpNoRig => 'N3FJP no té cap interfície de ràdio configurada, així que això segueix el que s\'escriu a N3FJP, no una ràdio';
	@override String get winkeyerKeyPort => 'Sortida de manipulació';
	@override String get winkeyerKeyPortDescription => 'A quina de les dues sortides del manipulador està connectada la ràdio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Utilitza el PTT del manipulador';
	@override String get winkeyerPttDescription => 'Activa la línia PTT a la mateixa sortida, per a un amplificador o una ràdio que ho necessiti. Deixa-ho desactivat per a una ràdio manipulada per la seva presa de manipulador.';
	@override String get winkeyerNoAnswer => 'Cap WinKeyer ha respost en aquest port';
	@override String get winkeyerStoppedAnswering => 'El WinKeyer ha deixat de respondre mentre enviava; el missatge s\'ha descartat';
	@override String get icomControlPort => 'Port de control (UDP)';
	@override String get icomControlPortDescription => 'El Control Port (UDP) de la ràdio — 50001 tret que s\'hagi canviat a la seva configuració de xarxa, o redirigit a un altre.';
	@override String get icomSerialPort => 'Port sèrie (UDP)';
	@override String get icomSerialPortDescription => 'El Serial Port (UDP) de la ràdio — 50002 tret que s\'hagi canviat a la seva configuració de xarxa, o redirigit a un altre.';
	@override String get icomPortsDiffer => 'Els ports de control i sèrie han de ser diferents';
	@override String get radioUser => 'Usuari de la ràdio';
	@override String get radioPass => 'Contrasenya de la ràdio';
	@override String get radioLoginDescription => 'L\'inici de sessió de Network → Remote de la ràdio, no la contrasenya de la WiFi.';
	@override String get radioUserRequired => 'Cal l\'usuari de control remot de la ràdio';
	@override String get connectFailedBusy => 'El dispositiu està en ús';
	@override String get connectFailedDenied => 'Accés denegat';
	@override String get connectFailedDevice => 'No s\'ha trobat el dispositiu';
	@override String get connectFailedUnsupported => 'Cap controlador reconeix el xip d\'aquest adaptador USB. Si saps quin xip és, tria\'l a Controlador del xip USB, a Configuració avançada.';
	@override String get connectFailedLines => 'No s\'han pogut mantenir RTS/DTR com estaven configurats, així que s\'ha tancat el port. Potser un altre programa ha deixat activat el control de flux per maquinari — desconnecta i torna a connectar el cable.';
	@override String get connectFailedNetwork => 'No es troba la ràdio a la xarxa. Comprova\'n l\'adreça i que estigui engegada i accessible.';
	@override String connectFailedReplyPort({required Object port}) => 'El port ${port} d\'aquest dispositiu ja està en ús, i les respostes arriben allà. Tanca qualsevol altra cosa que hi escolti — inclòs un altre node PstRotator — o canvia el port.';
	@override String get connectFailedTimeout => 'La ràdio no ha respost a temps. Comprova que estigui engegada i accessible.';
	@override late final _Translations$settings$station$models$ca models = _Translations$settings$station$models$ca._(_root);
	@override late final _Translations$settings$station$transports$ca transports = _Translations$settings$station$transports$ca._(_root);
	@override String get troubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get ft891Troubleshooting => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **CAT RTS desactivat a la ràdio, o Mantén RTS alt activat.** Amb **CAT RTS** activat (menú **05-08** de l\'FT-891), la ràdio es manté en silenci mentre RTS és baix — pot respondre una vegada quan s\'obre el port, i després res. Triar el port USB de la mateixa ràdio activa **Mantén RTS alt** a Configuració avançada. En un Digirig, un SignaLink o la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt posa el transmissor en transmissió: en comptes d\'això, desactiva CAT RTS a la ràdio.\n- **La velocitat ha de coincidir** amb el CAT RATE de la ràdio (menú **05-06**). Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get yaesuBinaryTroubleshooting => 'Aquesta ràdio parla l\'antic CAT de cinc bytes de Yaesu, i no respon gens quan alguna cosa no està bé. Gairebé sempre és per una d\'aquestes raons:\n\n- **El cable ha de convertir els nivells.** La presa CAT del darrere no és RS-232 ni USB; necessita un CT-62 o un adaptador equivalent. Un cable d\'àudio o de dades normal no funcionarà per a CAT.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio (**#14** en un FT-817, **#19** en un FT-857 o FT-897). Si no coincideix, la ràdio no retorna res, i mai un error.\n- **No deixis mai que res activi RTS o DTR en aquest port.** En la majoria de cables per a aquestes ràdios, aquestes línies són PTT i manipulació. L\'excepció és una interfície antiga alimentada per DTR: per a aquesta, activa **Mantén DTR alt** a Configuració avançada.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquest controlador s\'ha escrit a partir de la taula CAT publicada per Yaesu i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.';
	@override String get tenTecTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get tenTecEagleTroubleshooting => '- **El port USB-B del darrere és l\'enllaç CAT.** La ràdio apareix com un port sèrie USB; a Windows necessita el controlador USB to UART de Ten-Tec, que apareix al Gestor de dispositius com a "USB to UART (COMx)".\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert, i també l\'actualitzador de firmware de Ten-Tec.\n- **Definir l\'amplada del filtre des de l\'aplicació la treu del botó BW** fins que la ràdio s\'apaga i s\'engega de nou. Així és com funciona la ràdio.\n\nAquest controlador s\'ha escrit a partir de la guia de referència del programador de Ten-Tec. Si funciona a mitges, val la pena informar-ne, amb la versió del firmware del menú de la ràdio.';
	@override String get tenTecOrionTroubleshooting => '- **Fes servir un cable sèrie DB-9 directe** al port SERIAL DATA, no un null-modem.\n- **Aquesta entrada manté RTS alt**, perquè l\'Orion fa servir RTS i CTS com a control de flux. En una interfície que activa el PTT des de RTS, com un Digirig, desactiva Mantén RTS alt a Configuració avançada, o la ràdio transmetrà tan bon punt l\'aplicació es connecti.\n- **El CW des de l\'aplicació necessita el manipulador intern de la ràdio activat.** Amb el manipulador desactivat, la ràdio ignora el que envia l\'aplicació.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquest controlador s\'ha escrit a partir de la guia de referència del programador de Ten-Tec i no s\'ha provat amb cap Orion. Si funciona a mitges, val la pena informar-ne, amb la versió del firmware del menú de la ràdio.';
	@override String get tenTecNoCw => 'El firmware d\'aquesta ràdio no accepta CW des de l\'aplicació. Ten-Tec ho va afegir al firmware 1.366 de l\'Orion.';
	@override String get tenTecKeyerOff => 'El manipulador intern de la ràdio està desactivat, així que ignora el CW enviat des de l\'aplicació. Activa el manipulador al menú de la ràdio.';
	@override String get guohetecTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get guohetecTroubleshooting => 'La Q900 té dos protocols CAT, i aquesta entrada utilitza el nadiu en lloc de la imitació de l\'FT-817. Tria aquí **Guohetec Q900**, no un FT-817 — la imitació admet menys ordres, i la ràdio no diu quin està utilitzant.\n\n- **El cable USB-C és l\'enllaç CAT**, i també connecta la targeta de so. La velocitat no hi importa; el port ignora el valor que tingui configurat.\n- **No deixis mai que res activi RTS o DTR en aquest port.** En un cable sèrie, aquestes línies són PTT i manipulació.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Una ràdio de segona generació es comporta diferent** d\'una de primera. Mantén premut Menu i després About: HW 2.0 és la segona generació.\n\nAquest controlador s\'ha escrit a partir del protocol publicat pel fabricant i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.';
	@override String get yaesuTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get yaesuTroubleshooting => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **CAT RTS ha d\'estar en OFF a la ràdio.** Si està activat, la ràdio espera una línia de control que l\'aplicació manté baixa. En un Digirig, un SignaLink o la majoria de cables casolans, aquesta mateixa línia és el PTT, així que activar-la posaria el transmissor en transmissió. Al port USB de la mateixa ràdio, l\'alternativa és **Mantén RTS alt** a Configuració avançada. On és aquest ajust depèn del model (menú **05-08** en un FT-891).\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Els modes segueixen la taula de l\'FT-891.** La majoria de la gamma Yaesu hi coincideix, però una ràdio que numera els modes de manera diferent mostrarà i configurarà el mode equivocat en aquests casos. La freqüència no se\'n veu afectada.';
	@override String get ftdx3000Troubleshooting => '**El menú 037 CAT SELECT ha de ser USB** per a CAT pel port USB de la ràdio; amb RS232C, el CAT és a la presa del darrere.\n\nAquesta entrada s\'ha escrit a partir de la documentació CAT publicada i no s\'ha provat amb cap FTDX3000. Si funciona a mitges, val la pena informar-ne.';
	@override String get yaesuRs232Troubleshooting => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **La presa CAT és RS-232.** Necessita un adaptador USB-sèrie i un cable DB-9 directe — un cable null-modem creua les línies, i la ràdio no rep res.\n- **CAT RTS ha d\'estar en OFF a la ràdio.** Si està activat, la ràdio espera una línia de control que l\'aplicació manté baixa, tret que **Mantén RTS alt** estigui activat a Configuració avançada.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquesta entrada s\'ha escrit a partir de la documentació CAT publicada i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.';
	@override String get yaesuUsbTroubleshooting => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **Utilitza el primer dels dos ports USB de la ràdio.** El CAT normalment és al primer (el port COM **Enhanced** a Windows); el segon (**Standard**) és per a PTT i manipulació. El selector apunta al primer sempre que els pot distingir.\n- **CAT RTS desactivat a la ràdio, o Mantén RTS alt activat.** Amb el menú **CAT RTS** de la ràdio activat, es manté en silenci mentre RTS és baix — pot respondre una vegada quan s\'obre el port, i després res. Triar el port USB de la mateixa ràdio activa **Mantén RTS alt** a Configuració avançada. En un Digirig, un SignaLink o la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt posa el transmissor en transmissió: en comptes d\'això, desactiva CAT RTS a la ràdio.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.';
	@override String get k4SerialNotes => 'Connecta la presa USB-B (PC) del darrere de la K4. Tant USB-PC1 com USB-PC2 funcionen per a CAT; tria un port que no s\'utilitzi i fes coincidir el seu ajust Serial USB-PCn: Baud Rate a la ràdio. HaLo hi posa 38400 per defecte; canvia-ho si cal. Una altra aplicació ha d\'utilitzar l\'altre port o Ethernet.\n\nAquesta connexió controla la ràdio i els seus manipuladors; no envia àudio a HaLo.';
	@override String get k4TcpNotes => 'Connecta la presa Ethernet de la K4 a la teva xarxa local. Introdueix el nom de l\'amfitrió o l\'adreça IP i el port CAT 9200. HaLo fa servir el mateix amfitrió al port fix 9201 quan es mostra un panadaptador o una cascada; canviar el port CAT no canvia el port de l\'espectre.\n\nL\'espectre mostra el receptor principal. Els seus controls de zoom, ajust de referència i velocitat només afecten la visualització de HaLo. La transmissió d\'àudio no s\'admet.';
	@override String get k4PowerTimeout => 'No s\'ha canviat la potència de la K4 perquè la ràdio no ha confirmat el seu rang de sortida. Torna-ho a provar.';
	@override String get k4RemoteNotes => 'Activa l\'accés remot a la K4 i introdueix la seva contrasenya de xarxa. Main i Sub comparteixen una sola connexió xifrada per al control de la ràdio i l\'espectre. El port per defecte és el 9204; introdueix el teu port redirigit quan et connectis remotament.\n\nLa reproducció d\'àudio i la transmissió del micròfon no s\'admeten.';
	@override String get k4Receiver => 'Receptor';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'Tria Main o Sub';
	@override String get k4ReceiverAlreadyConfigured => 'Aquest receptor ja està configurat per a aquesta K4';
	@override String get k4SubReceiverOff => 'El receptor Sub de la K4 està apagat';
	@override String get k4RemotePasswordRequired => 'Introdueix la contrasenya de xarxa de la K4 per connectar-te de manera segura.';
	@override String get k4RemoteHandshakeFailed => 'La K4 no ha pogut establir una connexió segura. Comprova la seva contrasenya de xarxa i la configuració d\'accés remot.';
	@override String get k4RemoteUnreachable => 'No s\'ha pogut accedir a la connexió segura de la K4. Comprova l\'adreça, el port i la configuració d\'accés remot.';
	@override String get k4PowerRange => 'La potència de la K4 ha de ser de 0,1–110 W, o de 0,0001–0,01 W quan la sortida de mil·liwatts del transvertidor està activa.';
	@override String get elecraftTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get elecraftTroubleshooting => 'Les ràdios Elecraft parlen CAT de Kenwood, i una KX2 i una KX3 s\'han provat d\'aquesta manera — VFO en tots dos sentits, canvi de mode i batement zero en CW, tot funcionant.\n\nSi la ràdio no respon, gairebé sempre és per una d\'aquestes raons:\n\n- **La velocitat ha de coincidir** amb la configurada a **RS232** al menú de la ràdio. Venen amb 38400. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\n**Si la freqüència és correcta però el mode no**, explica-ho. Les entrades de la KX2 i la KX3 llegeixen el mode d\'una posició de la resposta d\'estat de la ràdio que hem fixat a partir de les ràdios que hem vist, i un firmware que el posi en un altre lloc només ens arriba a través d\'un informe.\n\nDe la K3 no n\'ha informat ningú, ni en un sentit ni en l\'altre, així que si en fas servir una, explica\'ns què passa. La K4 té la seva pròpia entrada.';
	@override String get lab599TroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get lab599Troubleshooting => 'La gamma TX-500 parla CAT de Kenwood. La freqüència i el mode s\'han provat a través d\'un LiNK500MP; la potència i els mesuradors s\'han escrit a partir de la referència CAT de Lab599, així que informa\'ns del que passi, tant si funciona com si no.\n\n- **La velocitat ha de coincidir** amb l\'ajust CAT de la ràdio, 9600 tret que l\'hagis canviat. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Tria el protocol CAT a la ràdio.** TS-2000 cobreix freqüència, mode i potència. LAB599 també permet que l\'aplicació passi la ràdio a DIG, la vegi transmetre en DIG i en llegeixi la tensió d\'alimentació.\n- **A través d\'un LiNK500MP**, mantén premut el botó del VFO uns tres segons per cedir el control CAT a la interfície.\n- **Posa el LiNK500MP en el mode de la connexió**: Mode 3 per a Bluetooth, Mode 4 per a Bluetooth LE. En qualsevol altre mode, una cerca Bluetooth LE no el troba.\n- **Per Bluetooth**, el LiNK500MP s\'aparella com dos ports sèrie i només un porta el CAT. Si la ràdio es manté en silenci, tria l\'altre.';
	@override String get lab599TroubleshootingIos => 'La gamma TX-500 parla CAT de Kenwood. La freqüència i el mode s\'han provat a través d\'un LiNK500MP; la potència i els mesuradors s\'han escrit a partir de la referència CAT de Lab599, així que informa\'ns del que passi, tant si funciona com si no.\n\n- **Posa el LiNK500MP en Mode 4**, el seu mode Bluetooth LE, abans de cercar-lo. En qualsevol altre mode, un iPhone o iPad no el pot trobar.\n- **Cedeix el control CAT al LiNK500MP**: mantén premut el botó del VFO de la ràdio uns tres segons.\n- **Tria el protocol CAT a la ràdio.** TS-2000 cobreix freqüència, mode i potència. LAB599 també permet que l\'aplicació passi la ràdio a DIG, la vegi transmetre en DIG i en llegeixi la tensió d\'alimentació.';
	@override String get kenwoodTroubleshootingTitle => 'Si la ràdio es connecta però no mostra cap freqüència';
	@override String get kenwoodTroubleshooting => 'Aquest controlador s\'ha provat amb les Kenwood TS-590SG i TS-480, les QRP Labs QMX i QCX-mini, i les Elecraft KX2 i KX3. La resta de la gamma s\'ha escrit a partir de referències CAT publicades, així que informa\'ns del que passi, tant si funciona com si no.\n\nSi la ràdio no respon, gairebé sempre és per una d\'aquestes raons:\n\n- **La velocitat ha de coincidir** amb el menú CAT de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Algunes ràdios necessiten el CAT activat** al menú abans de respondre.\n- **Les ràdios Kenwood esperen RTS**: el seu port CAT el fa servir com a control de flux, així que Mantén RTS alt (a Configuració avançada) ha d\'estar activat. Una connexió configurada abans que fos activat per defecte pot tenir-lo desactivat. En un Digirig o un altre cable que activa el PTT des de RTS, desactiva\'l, o la ràdio transmetrà.\n\n**Diversos front-ends SDR parlen aquest mateix protocol**, així que val la pena provar aquesta entrada també amb ells; les ràdios Elecraft tenen la seva pròpia entrada, a Elecraft. Si la freqüència és correcta però el mode és erroni o no apareix, aquesta és l\'única part que varia dins la gamma — l\'aplicació el dedueix de la ràdio i, si no, el demana directament, així que potser el mode simplement arriba amb retard.';
	@override String get statusConnected => 'Connectat';
	@override String get statusLost => 'Desconnectat';
	@override String get notConfigured => 'No configurat';
	@override String get currentConfiguration => 'Configuració actual';
	@override String get currentTransceiver => 'Transceptor actual';
	@override String get currentTransceivers => 'Transceptors actuals';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => 'Els missatges s\'encuen en lloc d\'interrompre';
	@override String get noRadioBSelected => 'No s\'ha seleccionat cap Ràdio B';
	@override String get radioMode => 'Mode de la ràdio';
	@override String get keyerNotSupported => 'La ràdio actual no ho admet';
	@override String get catControlPreferences => 'Preferències del control CAT';
	@override String get chooseTransceiver => 'Tria el transceptor';
	@override String get configurationSection => 'Configuració';
	@override String get noTransceiverSelected => 'No hi ha cap transceptor seleccionat';
	@override String makeMainVfo({required Object name}) => 'Utilitza ${name} per al VFO principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		zero: 'Cap transceptor',
		one: '${count} transceptor',
		other: '${count} transceptors',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} antena',
		other: '${count} antenes',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} altre dispositiu',
		other: '${count} altres dispositius',
	);
	@override String get equipmentInventory => 'Inventari d\'equips';
	@override String get equipmentInUse => 'Controls del transceptor';
	@override String get noTransceiver => 'Cap';
	@override String get peerRadioNotAvailable => 'No disponible';
	@override String peerRadioOnDevice({required Object device}) => 'A ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} és en un altre dispositiu';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Aquesta ràdio està connectada a ${device}. La seva connexió i configuració es gestionen en aquell dispositiu.';
	@override String get antennaInUse => 'Antena en ús';
	@override String get keyInUse => 'Manipulació CW';
	@override String get phoneKeying => 'Manipulació de fonia';
	@override String get phoneKeyingNone => 'Cap';
	@override String phoneKeyingRadio({required Object radio}) => 'Memòries de ${radio}';
	@override String get phoneKeyingComputer => 'Àudio d\'aquest ordinador';
	@override String get phoneKeyingOff => 'La manipulació de fonia està desactivada';
	@override String get computerVoiceSettings => 'Àudio de l\'ordinador';
	@override String get cwKeyingOptions => 'Opcions de manipulació CW';
	@override String get noneSelected => 'Cap';
	@override String get moreSettings => 'Més opcions';
	@override String get icomCivTroubleshootingTitle => 'Si apareixen dos ports sèrie per a la mateixa ràdio';
	@override String get icomCivTroubleshooting => 'Diverses ràdios Icom, entre elles l\'IC-705, presenten **dos** ports sèrie USB alhora (Icom els anomena Port A i Port B), tots dos configurats com a CI-V per defecte. Ni aquesta aplicació ni el sistema operatiu els poden distingir més enllà d\'això: el mateix identificador USB de fabricant/producte simplement apareix dues vegades, de vegades marcat aquí amb un sufix `#2`. **Normalment el correcte és el Port A** — sol ser el primer que mostra el sistema operatiu o el navegador, i quan aquesta aplicació pot distingir els dos ports, el marca com a suggerit. Si les ordres surten i la ràdio no respon mai, prova l\'altre port.';
	@override String get civAddressTroubleshootingTitle => 'Si la ràdio no respon mai';
	@override String get civAddressTroubleshooting => '- **L\'adreça CI-V ha de coincidir** amb el menú de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model, però una ràdio que comparteix un bus CI-V és precisament on es canvia. Una trama enviada a l\'adreça equivocada s\'ignora en silenci, cosa que sembla exactament un cable mort.\n- **La velocitat ha de coincidir** amb el CI-V BAUD RATE de la ràdio (per USB, CI-V USB Baud Rate). Configura la ràdio amb el mateix valor que es mostra aquí, **no Auto**. En Auto, algunes ràdios, entre elles l\'IC-7300, es connecten i deixen de respondre al cap d\'un minut més o menys.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **L\'adreça CI-V ha de coincidir** amb el menú de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model, però una ràdio que comparteix un bus CI-V és precisament on es canvia. Una trama enviada a l\'adreça equivocada s\'ignora en silenci, cosa que sembla exactament un cable mort.\n${speed}\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.';
	@override String get icomUsbSpeedFollows => '- **No hi ha cap velocitat per configurar.** Per USB, aquesta ràdio parla a la velocitat que faci servir l\'ordinador, i aquesta entrada sempre fa servir 115200, la velocitat que necessita l\'espectroscopi.';
	@override String get ic7610UsbSpeed => '- **Posa CI-V USB Baud Rate a 115200**, la velocitat que aquesta entrada sempre fa servir, perquè l\'espectroscopi la necessita — **no Auto**. Una ràdio configurada a qualsevol altra velocitat respon amb silenci.';
	@override String get civTransceiveTitle => 'Si l\'aplicació tarda a seguir la ràdio';
	@override String get civTransceive => 'Si l\'aplicació tarda uns quants segons a mostrar un canvi de freqüència o de mode fet a la ràdio, activa l\'ajust **CI-V Transceive** de la ràdio (a la majoria de models actuals, a SET > Connectors > CI-V). Amb aquest ajust activat, la ràdio informa de cada canvi en el moment en què es produeix. Desactivat, l\'aplicació només veu el canvi la propera vegada que ho pregunta, cada pocs segons.';
	@override String get ic7300Mk2Note => '\n- L\'**IC-7300 MK2** ve amb l\'adreça `B6`, no la `94` que hi ha aquí per defecte — tria l\'entrada IC-7300 MK2.';
	@override String get ic705PortNote => '\n- L\'**IC-705** presenta dos ports sèrie USB, tots dos amb el nom de la ràdio. El CI-V és al **primer**, al qual apunta el selector sempre que els pot distingir.';
	@override String get ic7760PortNote => '\n- L\'**IC-7760** parla CI-V al **Port A** dels dos ports sèrie USB que presenta.';
	@override String get x6100PortNote => '\n- L\'**X6100** parla CI-V al seu port **DEV** — el segon dels dos ports sèrie que presenta, i al qual apunta el selector.';
	@override String get rigctldTroubleshootingTitle => 'Si l\'aplicació no es pot connectar';
	@override String get rigctldTroubleshooting => 'Això es connecta a un **dimoni rigctld que executes tu mateix**, no directament a la ràdio — el backend de Hamlib parla amb la ràdio i admet centenars de models.\n\n- **El dimoni ja s\'ha d\'estar executant**, p. ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Troba el número de model de la teva ràdio amb `rigctl -l`.\n- **Des d\'una altra màquina**, inicia\'l amb `-T 0.0.0.0`: per defecte, rigctld només accepta connexions de la màquina on s\'executa.\n- **El port** és el 4532, tret que hagis iniciat el dimoni amb `-t`.\n- Un cop connectat, si no apareix la freqüència normalment és perquè el mateix dimoni no pot accedir a la ràdio. Prova-ho amb `rigctl -m 2 f` a la màquina del dimoni.';
	@override String get flrigTroubleshootingTitle => 'Si l\'aplicació no es pot connectar';
	@override String get flrigTroubleshooting => 'Això es connecta a un **programa flrig que executes tu mateix**, no directament a la ràdio — flrig parla amb la ràdio i admet la majoria de marques i models.\n\n- **flrig ja s\'ha d\'estar executant**, amb el transceptor configurat i connectat.\n- **El port** és el 12345, tret que l\'hagis canviat a la configuració de flrig (Config → Setup → Server).\n- **Des d\'una altra màquina**, assegura\'t que el servidor de flrig sigui accessible. Escolta a totes les interfícies, però potser el tallafoc no hi està d\'acord.\n- Un cop connectat, si no apareix la freqüència normalment és perquè el mateix flrig no pot accedir a la ràdio. Comprova que la pantalla de flrig segueix el dial.';
	@override String get hrdTroubleshootingTitle => 'Si l\'aplicació no es pot connectar';
	@override String get hrdTroubleshooting => 'Això es connecta al **Rig Control de Ham Radio Deluxe, que s\'executa al teu ordinador**, no directament a la ràdio — HRD parla amb la ràdio.\n\n- **Rig Control ja s\'ha d\'estar executant** i connectat a la ràdio.\n- **El seu servidor IP ha d\'estar activat.** Rig Control només parla amb altres programes a través d\'ell.\n- **El port** és el 7809, tret que l\'hagis canviat a la configuració del servidor IP.\n- **Des d\'una altra màquina**, assegura\'t que el tallafoc deixi passar la connexió.\n\nAquesta entrada s\'ha escrit a partir de descripcions publicades del protocol d\'HRD i no s\'ha provat amb HRD. Si funciona a mitges, val la pena informar-ne.';
	@override String get n3fjpTroubleshootingTitle => 'Si l\'aplicació no es pot connectar';
	@override String get n3fjpTroubleshooting => 'Això es connecta a **un programa de registre N3FJP que s\'executa al teu ordinador**, no directament a la ràdio — N3FJP parla amb la ràdio.\n\n- **L\'API del programa ha d\'estar activada**: Settings → Application Program Interface, marca **TCP API Enabled**.\n- **El port** és el 1100, tret que l\'hagis canviat allà.\n- **N3FJP ha de tenir configurada una interfície de ràdio** per seguir o sintonitzar la ràdio. Sense, només informa del que s\'escriu a la seva finestra d\'entrada.\n- N3FJP només informa de banda, mode i freqüència: ni potència ni estat de transmissió.\n\nAquesta entrada s\'ha escrit a partir de l\'API publicada d\'N3FJP i no s\'ha provat amb N3FJP. Si funciona a mitges, val la pena informar-ne.';
	@override String get commanderTroubleshootingTitle => 'Si l\'aplicació no es pot connectar';
	@override String get commanderTroubleshooting => 'Això es connecta a **DXLab Commander, que s\'executa al teu ordinador**, no directament a la ràdio — Commander parla amb la ràdio.\n\n- **Commander ja s\'ha d\'estar executant** i connectat a la ràdio.\n- **El seu servei de xarxa ha d\'estar activat**: el botó **Net Serv** al panell Radio de la finestra Configuration de Commander.\n- **El port** és el 52002, el tercer port del bloc que comença al **Base Port** de Net Serv (52000 tret que l\'hagis canviat).\n- **Des d\'una altra màquina**, assegura\'t que el tallafoc deixi passar la connexió.\n\nAquesta entrada s\'ha escrit a partir dels missatges TCP publicats de Commander i no s\'ha provat amb Commander. Si funciona a mitges, val la pena informar-ne.';
	@override String get ic705TroubleshootingTitle => 'Si la ràdio no respon mai';
	@override String get ic705Troubleshooting => 'La ràdio té una **única** sessió de control remot. Quan s\'ignora l\'inici de sessió, gairebé sempre és perquè alguna altra cosa l\'està fent servir.\n\n- **Tanca qualsevol altre client.** wfview o RS-BA1 connectats a la mateixa ràdio ocupen aquesta única sessió, i mentrestant l\'inici de sessió d\'aquí simplement s\'ignora.\n- **Comprova la configuració de xarxa de la ràdio.** La WLAN ha d\'estar activada, la ràdio ha de ser a la mateixa xarxa i la seva funció de control remot (Network) ha d\'estar activada.\n- **Els ports han de coincidir** amb el Control Port i el Serial Port (UDP) de la ràdio, o amb els ports que hi redirigeixen. Un port equivocat es troba amb silenci, igual que una ràdio apagada.\n- **Apaga i torna a encendre la WLAN de la ràdio** si continua bloquejada. Això allibera de manera fiable una sessió encallada a la ràdio.\n\nUna **contrasenya incorrecta es rebutja explícitament**, no amb silenci. Si has arribat aquí en lloc de rebre un missatge de "rebutjat", el problema no és la contrasenya.';
	@override String get icomLanTroubleshooting => 'La ràdio té una **única** sessió de control remot. Quan s\'ignora l\'inici de sessió, gairebé sempre és perquè alguna altra cosa l\'està fent servir.\n\n- **Tanca qualsevol altre client.** wfview, RS-BA1 o el Remote Utility d\'Icom connectats a la mateixa ràdio ocupen aquesta única sessió, i mentrestant l\'inici de sessió d\'aquí simplement s\'ignora.\n- **Comprova la configuració de xarxa de la ràdio.** El seu port LAN ha d\'estar connectat a la mateixa xarxa que aquest dispositiu, el seu **Network Control** ha d\'estar activat, i l\'usuari i la contrasenya han d\'estar configurats com a usuari de xarxa a la ràdio.\n- **Els ports han de coincidir** amb el Control Port i el Serial Port (UDP) de la ràdio, o amb els ports que hi redirigeixen. Un port equivocat es troba amb silenci, igual que una ràdio apagada.\n- **Si es connecta però no respon mai**, l\'adreça CI-V d\'aquí ha de coincidir amb el menú CI-V ADDRESS de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model.\n- **Apaga i torna a encendre la ràdio** si continua bloquejada.';
	@override String get statusStale => 'No respon';
	@override String get statusDisconnected => 'No connectat';
	@override String get statusConnecting => 'Connectant…';
	@override String get statusDisconnecting => 'Desconnectant…';
	@override String get statusError => 'La connexió ha fallat';
	@override String get currentRadioSettings => 'Configuració actual de la ràdio';
	@override String get notSupportedByThisRadio => 'Aquesta ràdio no ho admet';
	@override String get cwMessagesButton => 'Missatges CW';
	@override String get voiceMessagesButton => 'Missatges de fonia';
	@override String voiceKeyerAvailable({required Object count}) => 'Manipulador de veu: ${count} memòries a la ràdio';
	@override String get antennaBands => 'Bandes';
	@override String get antennaType => 'Tipus d\'antena';
	@override String get antennaTypeRequired => 'Tria un tipus d\'antena';
	@override late final _Translations$settings$station$antennaTypes$ca antennaTypes = _Translations$settings$station$antennaTypes$ca._(_root);
	@override String get keyType => 'Tipus de manipulador';
	@override String get keyTypeRequired => 'Tria un tipus de manipulador';
	@override late final _Translations$settings$station$keyTypes$ca keyTypes = _Translations$settings$station$keyTypes$ca._(_root);
	@override String get softwareIntermediaries => 'Programari intermediari';
	@override String get otherBrands => 'Altres marques';
	@override String get otherEquipment => 'Altres equips (antenes, manipuladors, etc.)';
	@override String get newAntenna => 'Antena nova';
	@override String get newKey => 'Manipulador nou';
	@override String get newKeyer => 'WinKeyer (K1EL o compatible)';
	@override String keyViaRadio({required Object radio}) => 'Manipulador CAT a ${radio}';
	@override String keyOnDevice({required Object device}) => 'Manipulador a ${device}';
	@override String get trackStationInfo => 'Registra la informació de l\'estació per a cada QSO';
	@override String get includeStationInfoInAdif => 'Inclou-la a les exportacions ADIF';
	@override String get whatToTrack => 'Què vols registrar?';
	@override String get trackFieldRig => 'Transceptor';
	@override String get trackFieldPower => 'Potència';
	@override String get watts => 'Watts';
	@override String get trackFieldAntenna => 'Antena';
	@override String get trackFieldKey => 'Manipulador CW';
	@override String get placeholderConnectDelay => 'Retard de connexió (ms)';
	@override String get placeholderConnectDelayDescription => 'Quant de temps triga la negociació simulada. En blanc o 0 connecta a l\'instant.';
	@override String get placeholderDropAfter => 'Desconnecta al cap de (segons)';
	@override String get placeholderDropAfterDescription => 'Tanca la connexió per si sola, per provar el camí de reconnexió. En blanc o 0 no es desconnecta mai.';
	@override String get placeholderFailConnect => 'Falla sempre en connectar';
	@override String get placeholderConnectFailure => 'S\'ha indicat a la ràdio provisional que rebutgi aquesta connexió';
	@override String get placeholderFreq => 'Freqüència (kHz)';
	@override String get placeholderFreqDescription => 'On comença la ràdio provisional. Després informa de qualsevol freqüència a la qual la sintonitzi l\'aplicació.';
	@override String get placeholderMode => 'Mode';
	@override String get placeholderModeDescription => 'El mode amb què comença la ràdio provisional, p. ex. USB, CW, FT8.';
	@override String get placeholderPower => 'Potència (watts)';
	@override String get placeholderPurpose => 'Utilitza aquesta ràdio per tenir constància de quin equip fas servir a efectes de registre';
	@override String get placeholderReplyDelay => 'Retard de resposta (ms)';
	@override String get placeholderReplyDelayDescription => 'Quant triga la ràdio provisional a informar d\'un canvi. En blanc o 0 respon a l\'instant.';
	@override String get cwKeyerField => 'Manipulador CW per CAT';
	@override String get cwKeyerFieldDescription => 'Si aquesta ràdio manipula CW a partir de text per CAT. Desactivat per a un equip que l\'aplicació no coneix.';
	@override String get voiceMemories => 'Memòries de veu';
	@override String get voiceMemoriesDescription => 'Quantes memòries de veu reprodueix la ràdio per CAT. 0 si no en té cap.';
	@override String get voiceMemoriesInvalid => 'Un nombre enter, 0 o més';
	@override String get yaesuMeterCapture => 'Captura les lectures dels mesuradors';
	@override String get yaesuBinaryMeterCaptureDescription => 'Llegeix el mesurador de potència de sortida i l\'indicador de ROE alta de la ràdio mentre transmet i escriu els valors en brut al registre. Serveix per construir l\'escala que Yaesu no publica — els valors no es mostren com a mesuradors.';
	@override String get yaesuMeterCaptureDescription => 'Llegeix els mesuradors PO, SWR i ALC de la ràdio mentre transmet i escriu els valors en brut al registre. Serveix per construir l\'escala que Yaesu no publica — els valors no es mostren com a mesuradors.';
	@override String get telemetryInterval => 'Interval de lectura dels mesuradors (ms)';
	@override String get telemetryIntervalDescription => 'Cada quant es llegeixen els mesuradors de la ràdio mentre transmet. Deixa-ho en blanc per al més ràpid que admeti aquesta connexió, fins a 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Un nombre enter de mil·lisegons, de ${min} a ${max}';
	@override String get pollInterval => 'Interval de consulta en repòs (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Cada quant es demana a la ràdio la freqüència i el mode mentre cap dels dos canvia. Deixa-ho en blanc per a ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Un nombre enter de mil·lisegons, de ${min} a ${max}';
	@override String get advancedSettings => 'Configuració avançada';
	@override String get placeholderSwr => 'Lectura de ROE';
	@override String get placeholderSwrDescription => 'El que indica el mesurador de ROE d\'aquesta ràdio mentre transmet. Per sobre d\'1,8 el panell avisa.';
	@override String get placeholderSwrInvalid => 'Un nombre, 1 o més';
	@override String get keyerNone => 'Cap';
	@override String get cwDialect => 'Dialecte de manipulació CW';
	@override String get cwDialectDescription => 'Quina forma de l\'ordre KY accepta aquesta ràdio. Cap vol dir sense manipulació CW per CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, omplert fins a 24)';
	@override String get cwDialectElecraft => 'Elecraft (text KY)';
	@override String get voiceDialect => 'Dialecte del manipulador de veu';
	@override String get voiceDialectDescription => 'Com reprodueix aquesta ràdio les seves memòries de veu per CAT. Cap vol dir sense memòries de veu per CAT. Amb un dialecte i sense nombre, s\'aplica el nombre per defecte del dialecte.';
	@override String get voiceDialectPb => 'Kenwood (PB, estil TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB i DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (polsacions de botó)';
	@override String get placeholderDiagnostic => 'Simulat';
	@override String get placeholderWholeNumberInvalid => 'Ha de ser un nombre enter, 0 o més';
	@override String get placeholderFreqInvalid => 'Ha de ser una freqüència en kHz, més gran que zero';
	@override String get placeholderModeInvalid => 'Ha de ser un nom de mode, p. ex. USB, CW, FT8';
	@override String get switchLayout => 'Disposició';
	@override String get switchLayoutDescription => 'A quin costat del commutador estan connectades les teves ràdios.';
	@override String get switchLayoutRequired => 'Tria com està cablejat el commutador';
	@override String switchCommandRefused({required Object command, required Object code}) => 'El commutador ha rebutjat "${command}" (error ${code})';
	@override String get switchBusyTransmitting => 'Aquest port està transmetent — no s\'ha canviat l\'antena';
	@override String get switchNoAntenna => 'Cap';
	@override String switchAntennaFor({required Object port}) => 'Antena al port ${port}';
	@override String get switchAntennaForDescription => 'Quina de les teves antenes està connectada a aquest port del commutador.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antenes, ${radios} ràdios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antenes, 1 ràdio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antena, ${radios} ràdios';
	@override String get switchCommonPort => 'Comú';
	@override String get dcnAddress => 'Adreça del dispositiu';
	@override String get dcnAddressDescription => 'L\'adreça configurada als interruptors DIP del mòdul. Un mòdul de relé coaxial surt de fàbrica amb el 2.';
	@override String get dcnAddressRequired => 'Ha de ser una adreça de dispositiu de l\'1 al 99';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'segueix les dades de banda';
	@override String get switchPortTransmittingHint => 'transmetent — ara no es pot canviar';
	@override String get switchCurrentStateHeader => 'Estat actual';
	@override String get switchCurrentStateDescription => 'En quina antena és ara mateix cada port de ràdio. Els canvis tenen efecte immediatament.';
	@override String get switchWiringHeader => 'Cablejat';
	@override String get switchPortInhibitedHint => 'transmissió inhibida';
	@override String get rotatorAxes => 'Eixos';
	@override String get rotatorAxesDescription => 'Si el rotor gira només en azimut, o també en elevació (un G-5500 o similar).';
	@override String get rotatorAxesAzimuth => 'Només azimut';
	@override String get rotatorAxesAzimuthElevation => 'Azimut i elevació';
	@override String get rotatorAzimuthOffset => 'Desplaçament d\'azimut';
	@override String get rotatorAzimuthOffsetDescription => 'Graus a afegir al que llegeix el controlador, quan el seu zero no és el nord geogràfic. Els girs es corregeixen en conseqüència.';
	@override String get rotatorElevationOffset => 'Desplaçament d\'elevació';
	@override String get rotatorAzimuthMin => 'Azimut mínim';
	@override String get rotatorAzimuthMax => 'Azimut màxim';
	@override String get rotatorAzimuthMaxDescription => 'En els graus del mateix controlador. Per sobre de 360 per a un rotor amb solapament, que llavors fa el gir més curt.';
	@override String get rotatorElevationMin => 'Elevació mínima';
	@override String get rotatorElevationMax => 'Elevació màxima';
	@override String get rotatorElevationMaxDescription => 'En els graus del mateix controlador. Per sobre de 90 per a un rotor que es capgira.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => 'Graus sencers, de ${min} a ${max}';
	@override String get rotatorLimitsInvalid => 'El límit inferior ha de ser menor que el superior';
	@override String get rotatorPollInterval => 'Interval de consulta (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'Cada quant es demana al rotor cap a on apunta. Deixa-ho en blanc per a ${fallback} ms.';
	@override String get rotatorAxesRequired => 'Tria en quins eixos gira el rotor';
	@override String get rotatorRefused => 'El controlador ha rebutjat una ordre. Comprova que està en mode GS-232.';
	@override String get pstRotatorTroubleshooting => 'PstRotator només respon un cop està configurat per fer-ho, i si no, no diu res:\n\n- **Activa UDP Control** al menú Setup de PstRotator.\n- **Fes coincidir el port**: Communication → UDP Control Port, 12000 tret que s\'hagi canviat. PstRotator respon pel port següent (12001), que ha d\'estar lliure en aquest dispositiu.\n- **Connecta PstRotator al seu controlador.** Fins que no ho estigui, no respon res per UDP.\n- **Permet-lo al tallafoc** del PC que executa PstRotator, i en aquest dispositiu, que escolta les respostes.\n- **En un Mac, iPhone o iPad**, Ham2K Logger necessita accés a la xarxa local (Configuració → Privacitat i seguretat → Xarxa local).';
	@override String rotatorCurrentStateHeader({required Object position}) => 'Estat actual: ${position}';
	@override String get rotatorDisconnected => 'desconnectat';
	@override String rotatorAzimuthReading({required Object degrees}) => '${degrees}° d\'azimut';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '${degrees}° az';
	@override String rotatorElevationReading({required Object degrees}) => '${degrees}° d\'elevació';
	@override String rotatorElevationReadingShort({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNoReading => 'Esperant que el controlador informi de la seva posició…';
	@override String get rotatorNotResponding => 'no respon';
	@override String rotatorHeldAtLimit({required Object heading}) => 'Girant cap a ${heading}, fins on ho permeten els límits d\'aquest rotor';
	@override String get rotatorTargetAzimuth => 'Gira a l\'azimut';
	@override String get rotatorTargetAzimuthShort => 'Gira a az';
	@override String get rotatorTargetElevation => 'Gira a l\'elevació';
	@override String get rotatorTargetElevationShort => 'Gira a el';
	@override String get rotatorAzimuthInvalid => 'Ha de ser de 0 a 360';
	@override String get rotatorElevationInvalid => 'Ha de ser de 0 a 180';
	@override String get rotatorTurn => 'Gira';
	@override String get rotatorStop => 'Atura';
	@override String get configUnreadable => 'No s\'ha pogut llegir la configuració desada d\'aquesta ràdio. Obre\'n la configuració i torna-la a introduir, o elimina-la i torna-la a afegir.';
	@override String get autoConnectHeld => 'HaLo va deixar de respondre l\'última vegada que es va connectar a aquesta ràdio, així que aquesta vegada no s\'hi ha connectat automàticament. Prem Connecta per tornar-ho a provar.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$ca extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dades fora de línia';
	@override String get noFiles => 'No hi ha fitxers de dades';
	@override String get noFilesDescription => 'Activa extensions d\'activitat o de consulta per descarregar aquí les seves dades fora de línia.';
	@override String get refresh => 'Refresca';
	@override String get refreshing => 'Refrescant…';
	@override String get updateAll => 'Actualitza-ho tot';
	@override String get updatingAll => 'Actualitzant tots els fitxers de dades…';
	@override String get neverDownloaded => 'Mai descarregat';
	@override String get updatedJustNow => 'Actualitzat ara mateix';
	@override String updatedDaysAgo({required Object days}) => 'Actualitzat fa ${days} d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Actualitzat fa ${days} d ${hours} h';
	@override String updatedHoursAgo({required Object hours}) => 'Actualitzat fa ${hours} h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Actualitzat fa ${hours} h ${minutes} min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Actualitzat fa ${minutes} min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'L\'última descàrrega només tenia ${imported} dels ${existing} registres i no s\'ha utilitzat. Refresca per acceptar-la.';
	@override String get extensionsSection => 'Extensions';
}

// Path: settings.profiles
class _Translations$settings$profiles$ca extends Translations$settings$profiles$en {
	_Translations$settings$profiles$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Sense definir';
	@override String get personalInfo => 'Informació personal';
	@override String get personalInfoNote => 'Es pot incloure als registres generats quan sigui rellevant per als enviaments';
	@override String get name => 'Nom';
	@override String get email => 'Correu electrònic';
	@override String get club => 'Club';
	@override String get arrlSection => 'Secció ARRL';
	@override String get racSection => 'Secció RAC';
	@override String get section => 'Secció';
}

// Path: settings.search
class _Translations$settings$search$ca extends Translations$settings$search$en {
	_Translations$settings$search$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Neteja';
	@override String get hint => 'Cerca preferències';
}

// Path: settings.developer
class _Translations$settings$developer$ca extends Translations$settings$developer$en {
	_Translations$settings$developer$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Activa els avisos per a desenvolupadors, els registres de depuració i les eines.';
	@override String get experiments => 'Experiments';
	@override String get showIdleMetrics => 'Mostra les mètriques d\'inactivitat';
	@override String get showIdleMetricsDescription => 'Mostra a la barra d\'estat quant de temps ha estat inactiu el motor d\'extensions durant l\'últim segon. Toca-ho per veure les mitjanes de 10 i 60 segons.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% inactiu';
	@override String get idleMetricsAverages => 'Mitjana d\'inactivitat:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} activat',
		other: '${count} activats',
	);
	@override String get patchTrack => 'Branca de pegats';
	@override String get patchTrackDescription => 'Quina branca de pegats remots segueix aquest dispositiu. Les branques més arriscades reben les correccions abans, menys provades. Els pegats s\'apliquen en el següent reinici.';
	@override String get trackStable => 'Estable';
	@override String get trackUnstable => 'Inestable';
	@override String get trackBleeding => 'Experimental';
	@override String checkingTrack({required Object track}) => 'Comprovant si hi ha pegats a "${track}"…';
	@override String get patchDownloaded => 'Pegat descarregat — reinicia l\'aplicació per aplicar-lo.';
	@override String noNewPatch({required Object track}) => 'No hi ha cap pegat nou a "${track}".';
	@override String get noPatchInstalled => 'No hi ha cap pegat instal·lat — s\'executa el binari de la versió.';
	@override String runningPatch({required Object patch}) => 'S\'executa el pegat núm. ${patch}.';
	@override String get deepLinks => 'Enllaços profunds';
	@override String get registerUrlSchemes => 'Registra els esquemes d\'URL';
	@override String get registerUrlSchemesDescription => 'Permet que els enllaços com.ham2k:// obrin aquesta còpia de l\'aplicació';
	@override String get registerUrlSchemesDone => 'Aquesta còpia ara obre els enllaços com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'No s\'ha pogut registrar: ${error}';
	@override String get systemInformation => 'Informació del sistema';
	@override String get appVersion => 'Versió de l\'aplicació';
	@override String get dataFolder => 'Carpeta de dades';
	@override String get loading => '(carregant…)';
	@override String get panelLoadFailed => 'No s\'ha pogut carregar aquest panell de configuració.';
	@override String get extDevServer => 'Servidor de desenvolupament d\'extensions';
	@override String get extensionSettings => 'Configuració d\'extensions';
	@override String get extDevServerDescription => 'Carrega extensions des d\'un servidor de desenvolupament de la teva xarxa en lloc de les integrades a l\'aplicació, i recarrega-les quan desis.';
	@override String get extDevServerAddress => 'Adreça del servidor';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Connecta';
	@override String get extDevServerDisconnect => 'Desconnecta';
	@override String get extDevServerConnecting => 'Connectant…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Servint ${count} extensió: ${keys}',
		other: 'Servint ${count} extensions: ${keys}',
	);
	@override String get extDevServerDisconnected => 'No connectat';
	@override String get extDevServerReconnect => 'Torna a connectar en iniciar';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Última recàrrega: ${key} a les ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: '${count} extensió no es pot compilar',
		other: '${count} extensions no es poden compilar',
	);
	@override String get catalog => 'Catàleg d\'extensions';
	@override String get catalogDescription => 'Llegeix el catàleg des d\'un altre servidor — un de local mentre es treballa en el mateix catàleg. Buit vol dir catalog.ham2k.net.';
	@override String get catalogAddress => 'Adreça del catàleg';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Branques de cerca del catàleg';
	@override String get catalogSearchStable => 'Només estables';
	@override String get catalogSearchUnstable => 'Inestables o millors';
	@override String get catalogSearchBleeding => 'Experimentals o millors';
}

// Path: settings.about
class _Translations$settings$about$ca extends Translations$settings$about$en {
	_Translations$settings$about$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Avisos i missatges';
	@override String get noticesDescription => 'Anuncis i missatges d\'estat';
	@override String get releaseNotes => 'Notes de la versió';
	@override String get copiedVersion => 'S\'han copiat els detalls de la versió al porta-retalls';
}

// Path: settings.panels
class _Translations$settings$panels$ca extends Translations$settings$panels$en {
	_Translations$settings$panels$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Preferències de l\'aplicació';
	@override String get settingsDescription => 'Fes que l\'aplicació funcioni com tu vulguis';
	@override String get commonSettings => 'Preferències comunes';
	@override String get syncDescription => 'Fes còpia de seguretat i sincronitza els teus registres entre dispositius';
	@override String get accountsDescription => 'Credencials de serveis, dades fora de línia i més';
	@override String get extensions => 'Extensions i funcions';
	@override String get extensionsDescription => 'Activitats, concursos, panells del tauler i més funcions';
	@override String get profilesDescription => 'Indicatiu de l\'operador i perfil de l\'estació';
	@override String get stationProfiles => 'Perfils d\'estació';
	@override String get developerSettings => 'Configuració de desenvolupador';
	@override String get developerSettingsDescription => 'Eines de depuració i desenvolupament';
	@override String get about => 'Quant a';
	@override String get aboutDescription => 'Versió, crèdits i informació legal';
	@override String get unavailableTitle => 'Algunes opcions no estan disponibles';
	@override String get unavailableText => 'L\'entorn d\'execució d\'extensions no s\'ha pogut iniciar, així que falten les opcions aportades per les extensions.';
	@override String get station => 'Configuració de l\'estació';
	@override String get stationDescription => 'Control CAT i més opcions';
	@override String get peers => 'Dispositius associats';
	@override String get peersDescription => 'Connecta amb altres dispositius propers';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$ca extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígits (FN31pr)';
	@override String get eight => '8 dígits (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$ca extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígits';
	@override String get eight => '8 dígits';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$ca extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'Obre el diàleg d\'ordres';
	@override String get toggleTheme => 'Canvia entre clar i fosc';
	@override String get toggleLanguage => 'Canvia entre anglès i espanyol';
	@override String get fontScaleUp => 'Text més gran';
	@override String get fontScaleDown => 'Text més petit';
	@override String get fontScaleReset => 'Mida de text normal';
	@override String get densityLooser => 'Disposició més espaiada';
	@override String get densityDenser => 'Disposició més densa';
	@override String get densityAuto => 'Densitat de disposició automàtica';
	@override String get find => 'Cerca al registre';
	@override String keyerMessage({required Object n}) => 'Envia el missatge ${n}';
	@override String get keyboardMode => 'Mode teclat activat o desactivat';
	@override String get ptt => 'Prem per parlar';
	@override String get wipe => 'Neteja el contacte que s\'està registrant';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$ca extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'Escriure indicatius';
	@override String get escape => 'Atura l\'enviament, fes un pas enrere o tanca';
	@override String get enter => 'Registra el contacte';
	@override String get space => 'Camp següent';
	@override String get tab => 'Camp següent o anterior';
	@override String get arrows => 'Mou-te entre camps, controls i el registre';
	@override String get walk => 'Avança pàgines del registre, o ves als seus extrems';
	@override String get undo => 'Desfés una neteja o un esborrat';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$ca extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'Afegeix una drecera';
	@override String get listening => 'Prem les tecles de la drecera…';
	@override String get listeningHint => 'Esc deixa d\'escoltar';
	@override String get add => 'Afegeix';
	@override String refusedFixed({required Object keys}) => '${keys} pertany als camps de registre o a un diàleg, i no es pot canviar.';
	@override String refusedCallsign({required Object keys}) => '${keys} és com s\'escriuen els indicatius. Mantén premut Cmd, Ctrl o Alt amb ella.';
	@override String reserved({required Object keys}) => 'El sistema pot capturar ${keys} abans que l\'aplicació la vegi.';
	@override String already({required Object keys}) => '${keys} ja és una de les tecles d\'aquesta ordre.';
	@override String takeIt({required Object keys, required Object command}) => 'Pren ${keys} de “${command}”';
	@override String get resetDefault => 'Restableix al valor per defecte';
	@override String get remove => 'Elimina';
	@override String get commandLabel => 'Ordre';
	@override String get commandHint => 'Introdueix qualsevol ordre vàlida, o diverses ordres separades per ";"';
	@override String get removeCommand => 'Elimina l\'ordre';
	@override String commandUnknown({required Object text}) => 'Cap ordre llegeix “${text}”';
	@override String get noShortcuts => 'Encara sense tecla';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$ca extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'Dreceres desades a ${location}';
	@override String exportFailed({required Object error}) => 'No s\'han pogut exportar les dreceres: ${error}';
	@override String importPickerFailed({required Object error}) => 'No s\'ha pogut obrir el fitxer: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} no és un fitxer de dreceres que aquesta aplicació pugui llegir: ${problem}';
	@override String problemNotYaml({required Object line}) => 'el text no és YAML vàlid (línia ${line})';
	@override String get problemNotKeysFile => 'no és un fitxer de dreceres de teclat de Ham2K';
	@override String get problemNewerVersion => 'l\'ha escrit una versió més nova de l\'aplicació';
	@override String get problemMalformed => 'una part no segueix el format de dreceres';
	@override String get problemTooLarge => 'és massa gran';
	@override String get importTitle => 'Importa les dreceres';
	@override String writtenOn({required Object platform}) => 'Escrit a ${platform}.';
	@override String get writtenOnUnknown => 'El fitxer no diu en quin teclat es va escriure.';
	@override String get translate => 'Què hauria de ser cada una d\'aquestes tecles en aquest teclat?';
	@override String get leaveOut => 'Deixa fora aquestes dreceres';
	@override String get replace => 'Substitueix la configuració d\'aquest dispositiu';
	@override String get replaceHint => 'Totes les dreceres que no són al fitxer tornen al valor per defecte.';
	@override String get merge => 'Afegeix a la configuració d\'aquest dispositiu';
	@override String get mergeHint => 'Les dreceres del fitxer substitueixen les d\'aquest dispositiu per a les mateixes ordres, i la resta es mantenen.';
	@override String unknown({required Object commands}) => 'No es coneixen en aquesta versió, així que s\'han deixat fora: ${commands}';
	@override String unreadableChords({required Object chords}) => 'No són dreceres, així que s\'han deixat fora: ${chords}';
	@override String refusedChords({required Object chords}) => 'Tecles que l\'aplicació es reserva, així que s\'han deixat fora: ${chords}';
	@override String conflicts({required Object keys}) => 'Assignades a més d\'una ordre després de la importació: ${keys}';
	@override String get importAction => 'Importa';
	@override String get imported => 'Dreceres importades';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$ca extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$ca extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$ca extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'Indicatius d\'estació';
	@override String get groupBy => 'Agrupa per';
	@override String get period => 'Període';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$ca extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get none => 'Sense agrupar';
	@override String get date => 'Data';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'Continent desconegut';
	@override String get unknownEntity => 'Entitat desconeguda';
	@override String get unknownDate => 'Sense data';
}

// Path: home.logs.period
class _Translations$home$logs$period$ca extends Translations$home$logs$period$en {
	_Translations$home$logs$period$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'Aquest mes';
	@override String get last3Months => 'Últims 3 mesos';
	@override String get thisYear => 'Aquest any';
	@override String get lastYear => 'L\'any passat';
	@override String get allTime => 'Des de sempre';
	@override String get custom => 'Interval personalitzat';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$ca extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => 'durant ${span}';
	@override String get custom => 'l\'interval triat';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$ca extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get date => 'Data';
	@override String get time => 'Hora';
	@override String get freq => 'Freqüència';
	@override String get mode => 'Mode';
	@override String get call => 'Indicatiu';
	@override String get name => 'Nom';
	@override String get station => 'Estació';
	@override String get band => 'Banda';
	@override String get sent => 'Enviat';
	@override String get rcvd => 'Rebut';
	@override String get grid => 'Graella';
	@override String get state => 'Estat';
	@override String get country => 'País';
	@override String get refs => 'Refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$ca extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Registre de QSOs';
	@override String get qsosDescription => 'Els QSOs de l\'indicatiu seleccionat, de totes les operacions.';
	@override String get info => 'Informació';
	@override String get infoDescription => 'Nombre total de QSOs, o la consulta de l\'indicatiu del QSO seleccionat.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'La ubicació del QSO seleccionat.';
}

// Path: home.logs.import
class _Translations$home$logs$import$ca extends Translations$home$logs$import$en {
	_Translations$home$logs$import$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicatius: ${calls}';
	@override String get skippedOne => 'No s\'ha pogut llegir 1 registre';
	@override String skippedOther({required Object count}) => 'No s\'han pogut llegir ${count} registres';
	@override String get readingTitle => 'Llegint el fitxer ADIF…';
	@override String get checkingTitle => 'Comprovant duplicats…';
	@override String get importingTitle => 'Important QSOs…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} de ${total} comprovats';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importats, de ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$ca extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'Per defecte';
	@override String untitledName({required Object number}) => 'Disposició ${number}';
	@override String switcherLabel({required Object name}) => 'Disposició: ${name}';
	@override String get menuNew => 'Nova…';
	@override String get menuExport => 'Exporta…';
	@override String get menuImport => 'Importa…';
	@override String get menuTitle => 'Disposicions';
	@override String get newTitle => 'Nova disposició';
	@override String get editTitle => 'Edita la disposició';
	@override String get edit => 'Edita';
	@override String get duplicateCurrent => 'Duplica la disposició actual';
	@override String get startFromDefault => 'Comença des de la disposició per defecte';
	@override String get nameLabel => 'Nom';
	@override String get descriptionLabel => 'Descripció';
	@override String get create => 'Crea';
	@override String leaveEditTitle({required Object name}) => 'Desar els canvis a "${name}"?';
	@override String get leaveEditBody => 'Aquesta disposició té canvis que no has desat.';
	@override String get discard => 'Descarta';
	@override String get deleteTitle => 'Esborrar aquesta disposició?';
	@override String deleteBody({required Object name}) => 'Segur que vols esborrar la disposició "${name}"?';
	@override String get exportTitle => 'Exporta la disposició';
	@override String get exportPick => 'Panells per exportar';
	@override String get tabSet => 'Grup de pestanyes';
	@override String get exportAction => 'Exporta';
	@override String exported({required Object location}) => 'Disposició desada a ${location}';
	@override String exportFailed({required Object error}) => 'No s\'ha pogut exportar la disposició: ${error}';
	@override String get importTitle => 'Importa la disposició';
	@override String importFromOtherView({required Object view}) => 'Feta per a la vista ${view}: els panells que només té aquella vista es deixen fora.';
	@override String get viewHome => 'Inici';
	@override String get viewOperation => 'Operació';
	@override String get viewLogs => 'Registres';
	@override String get viewChase => 'Caça';
	@override String get importAsNew => 'Com a disposició nova';
	@override String get importReplace => 'En lloc d\'aquesta disposició';
	@override String get importAdd => 'Afegits a aquesta disposició';
	@override String get importAddHint => 'Els panells arriben en una columna nova a la dreta.';
	@override String get importPick => 'Panells per importar';
	@override String get importReplaceSettings => 'Substitueix la configuració dels panells que ja hi ha aquí';
	@override String get importAction => 'Importa';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} no és una disposició que aquesta aplicació pugui llegir: ${problem}';
	@override String problemNotYaml({required Object line}) => 'el text no és YAML vàlid (línia ${line})';
	@override String get problemNotLayoutFile => 'no és un fitxer de disposició de Ham2K';
	@override String get problemNewerVersion => 'l\'ha escrit una versió més nova de l\'aplicació';
	@override String get problemNoArrangement => 'no conté cap distribució de panells';
	@override String get problemMalformed => 'una part no segueix el format de disposició';
	@override String get problemTooLarge => 'és massa gran';
	@override String importPickerFailed({required Object error}) => 'No s\'ha pogut obrir el fitxer: ${error}';
	@override String importFailed({required Object error}) => 'No s\'ha pogut importar la disposició: ${error}';
	@override String duplicateFailed({required Object error}) => 'No s\'ha pogut copiar la disposició: ${error}';
	@override String get importNothing => 'No s\'ha triat cap panell, així que no s\'ha importat res.';
	@override String importSkipped({required Object panels}) => 'S\'han deixat fora: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'S\'ha mantingut ${panels}: la distribució per a pantalles petites no en pot prescindir.';
	@override String get notOffered => 'No disponible en aquesta vista';
	@override String get alreadyPlaced => 'Ja és en aquesta disposició';
	@override String needsExtension({required Object name}) => 'Necessita ${name}';
	@override String get listRecoveredTitle => 'No s\'han pogut llegir els noms de les disposicions';
	@override String get listRecoveredBody => 'No s\'ha pogut llegir la llista de disposicions d\'aquesta vista. Totes les disposicions encara hi són, numerades en lloc del nom.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$ca extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'El registre i els camps d\'entrada';
	@override String get infoDescription => 'El que sabem de l\'estació amb qui contactem';
	@override String get spotsDescription => 'Anuncis dels clústers i dels programes d\'activitats';
	@override String get mapDescription => 'On són els contactes';
	@override String get summariesDescription => 'Les estadístiques i puntuacions de l\'operació, amb les seccions i l\'ordre que triïs';
	@override String get summariesSections => 'Seccions i ordre';
	@override String get summariesDays => 'Cada dia';
	@override String get summariesReset => 'Mostra-les totes';
	@override String get summariesAllHidden => 'Totes les seccions estan amagades. Tria les que vols mostrar a la configuració d\'aquest panell.';
	@override String get clockDescription => 'Un rellotge, en qualsevol fus horari';
	@override String get clockFace => 'Esfera';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analògic';
	@override String get clockZone => 'Fus horari';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Aquest dispositiu';
	@override String get clockShowSeconds => 'Mostra els segons';
	@override String get weatherDescription => 'Condicions actuals i de les properes vuit hores, allà on operes';
	@override String get weatherUseOperationLocation => 'Utilitza la ubicació de l\'operació';
	@override String get weatherLocation => 'Ubicació';
	@override String get weatherLocationDescription => 'Una graella (FN31pr) o lat,lon. S\'ignora mentre \'Utilitza la ubicació de l\'operació\' està marcat.';
	@override String get weatherNoLocation => 'No hi ha cap ubicació definida. Dona una ubicació a aquest panell a la seva configuració, o col·loca\'l dins d\'una operació que en tingui.';
	@override String weatherBadLocation({required Object location}) => 'No s\'ha pogut llegir la ubicació ${location}. Utilitza una graella com FN31pr, o 42.36,-71.06.';
	@override String get weatherUnreachable => 'No s\'ha pogut contactar amb Open-Meteo — sense xarxa? Es tornarà a provar d\'aquí a poc.';
	@override String get weatherUnreadable => 'Open-Meteo ha respost, però amb res llegible. Es tornarà a provar d\'aquí a poc.';
	@override String weatherGusts({required Object speed}) => 'ràfegues ${speed}';
	@override String get panelAgeNow => 'ara mateix';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'fa ${count} min',
		other: 'fa ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'fa ${count} h',
		other: 'fa ${count} h',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$ca weatherConditions = _Translations$operation$layout$panels$weatherConditions$ca._(_root);
	@override String get websiteDescription => 'Una pàgina web que triïs, en un panell';
	@override String get websiteUrl => 'Adreça';
	@override String get websiteRefresh => 'Refresca';
	@override String get websiteRefreshNever => 'Mai';
	@override String get websiteRefresh1 => 'Cada minut';
	@override String get websiteRefresh5 => 'Cada 5 minuts';
	@override String get websiteRefresh15 => 'Cada 15 minuts';
	@override String get websiteTitle => 'Nom del panell';
	@override String get websiteRefreshNow => 'Refresca ara';
	@override String get websiteNoUrl => 'Encara no hi ha cap adreça. Obre la configuració d\'aquest panell per triar una pàgina.';
	@override String get websiteBadUrl => 'Això no sembla una adreça web. Ha de començar per https://';
	@override String get websiteNotHttps => 'Només es poden mostrar adreces https:// en aquest panell.';
	@override String get websiteUnsupported => 'En aquest sistema no es poden mostrar pàgines web en un panell.';
	@override String get websiteOpenExternally => 'Obre al navegador';
	@override String websiteLoadFailed({required Object reason}) => 'No s\'ha pogut carregar la pàgina: ${reason}';
	@override String get remoteScreenDescription => 'Una pantalla, aplicació o finestra compartida per un altre dels teus dispositius.';
	@override String get remoteScreenTarget => 'Pantalla';
	@override String get remoteScreenChoose => 'Tria una pantalla…';
	@override String get remoteScreenPickerTitle => 'Pantalles compartides';
	@override String get remoteScreenPickerEmpty => 'Cap dels teus dispositius comparteix una pantalla. Activa Comparteix pantalles i finestres a Configuració → Dispositius associats, al dispositiu que vols veure.';
	@override String get remoteScreenUnset => 'No s\'ha triat cap pantalla. Obre la configuració d\'aquest panell per triar-ne una que comparteixin els teus altres dispositius.';
	@override String get remoteScreenConnecting => 'Connectant…';
	@override String get remoteScreenPeerAway => 'Aquest dispositiu no està connectat ara mateix.';
	@override String get remoteScreenNotOffered => 'Aquest dispositiu ha deixat de compartir aquesta pantalla.';
	@override String get remoteScreenNoListener => 'Aquest dispositiu no pot acceptar connexions — comprova\'n el tallafoc.';
	@override String get remoteScreenNoLan => 'Les pantalles només es comparteixen per la xarxa local, no per Bluetooth.';
	@override String get remoteScreenRefused => 'Aquest dispositiu no ha volgut compartir aquesta pantalla.';
	@override String get remoteScreenSettings => 'Configuració del panell';
	@override String get remoteScreenAdjust => 'Ajusta la vista';
	@override String get remoteScreenDetail => 'Detall';
	@override String get remoteScreenDetailStandard => 'Estàndard';
	@override String get remoteScreenDetailHigh => 'Alt';
	@override String get remoteScreenDetailMaximum => 'Màxim';
	@override String get remoteScreenAdjustDone => 'D\'acord';
	@override String get remoteScreenZoomIn => 'Amplia';
	@override String get remoteScreenZoomOut => 'Redueix';
	@override String get remoteScreenStopped => 'Aquesta pantalla o finestra ja no es mostra.';
	@override String get remoteScreenCaptureFailed => 'Aquest dispositiu no ha pogut capturar aquesta pantalla — potser necessita el permís de Gravació de pantalla.';
	@override String get remoteScreenNoAnswer => 'Aquest dispositiu no ha respost. Potser no té activada la compartició de pantalla.';
	@override String get remoteScreenNoMedia => 'No s\'ha pogut obrir una connexió per a la imatge. Comprova el tallafoc d\'aquest dispositiu.';
	@override String get solarDescription => 'Condicions solars i geomagnètiques, amb la propagació banda per banda';
	@override String get solarUnreachable => 'No s\'ha pogut contactar amb hamqsl.com — sense xarxa? Es tornarà a provar d\'aquí a poc.';
	@override String get solarUnreadable => 'hamqsl.com ha respost, però no amb una lectura que puguem fer servir. Es tornarà a provar d\'aquí a poc.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Dia';
	@override String get solarBandNight => 'Nit';
	@override String get solarBandGood => 'Bona';
	@override String get solarBandFair => 'Regular';
	@override String get solarBandPoor => 'Dolenta';
	@override String solarSources({required Object primary, required Object secondary}) => 'Fonts: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'La connexió té problemes — s\'estan saltant fotogrames.';
	@override String get remoteScreenStalled => 'Els fotogrames han deixat d\'arribar — potser aquesta connexió és massa lenta.';
	@override String get radioDescription => 'El panell frontal d\'una ràdio — freqüència, mode i potència, sota control CAT';
	@override String get radioStyle => 'Estil';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Modern';
	@override String get radioRadio => 'Ràdio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — cap ràdio designada';
	@override String get radioNoRadio => 'No hi ha cap ràdio per mostrar. Tria\'n una a la configuració d\'aquest panell, o afegeix-ne una a Configuració de l\'estació.';
	@override String get radioNotConfigured => 'Aquesta ràdio encara no està configurada. Tria\'n el port o l\'adreça a Configuració de l\'estació.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Ràdio no connectada';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Connecta aquesta ràdio';
	@override String get radioDisconnect => 'Desconnecta aquesta ràdio';
	@override String get radioStale => 'SENSE DADES';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'ROE';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'ROE alta';
	@override String get rotatorDescription => 'Cap a on apunta l\'antena, en un mapa centrat a l\'estació. Toca el mapa per girar-la.';
	@override String get rotatorRotator => 'Rotor';
	@override String rotatorAutoNamed({required Object name}) => 'Automàtic — ${name}';
	@override String get rotatorAutoNone => 'Automàtic — encara no hi ha cap rotor';
	@override String get rotatorBeamWidth => 'Amplada del feix';
	@override String get rotatorBeamWidthDescription => 'En graus, dibuixada al voltant del rumb. 0 no en dibuixa cap.';
	@override String get rotatorLocation => 'Ubicació';
	@override String get rotatorLocationDescription => 'Una graella, o una latitud i longitud, per centrar-hi el mapa. En blanc, es fa servir la ubicació de l\'operació.';
	@override String get rotatorTheme => 'Tema';
	@override String get rotatorThemeColor => 'Color';
	@override String get rotatorThemeGray => 'Gris';
	@override String get rotatorThemeMuted => 'Apagat';
	@override String get rotatorGrayline => 'Mostra la línia grisa';
	@override String get rotatorNoRotator => 'No hi ha cap rotor per mostrar. Tria\'n un a la configuració d\'aquest panell, o afegeix-ne un a Configuració de l\'estació.';
	@override String get rotatorNoLocation => 'No hi ha cap ubicació on centrar el mapa. Defineix-ne una a la configuració d\'aquest panell.';
	@override String get rotatorDisconnected => 'desconnectat';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => 'no respon';
	@override String get rotatorLocationInvalid => 'No es pot llegir la ubicació de la configuració d\'aquest panell. Fes servir una graella, o una latitud i longitud com 40.7, -74.0.';
	@override String rotatorElevation({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'O';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$ca extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Utilitza noms de fitxer compactes';
	@override String get descriptionOn => 'Noms curts pensats per als pujadors, com N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Noms llegibles, com 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$ca extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inclou informació privada';
	@override String get descriptionOn => 'S\'inclouen noms, adreces, correus electrònics, graelles i notes';
	@override String get descriptionOff => 'S\'exclouen noms, adreces, correus electrònics, graelles i notes';
	@override String get note => 'L\'exportació ADIF completa sempre ho inclou tot';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$ca extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Afegeix primer una adreça de correu electrònic';
	@override String get needsEmailBody => 'Ham2K File Stash envia els teus fitxers a l\'adreça de correu electrònic del teu compte LoFi, i hi inicies sessió amb ella a stash.ham2k.net. El teu compte encara no en té cap de confirmada — afegeix-la a Configuració › Sincronització al núvol.';
	@override String get openSyncSettings => 'Obre Sincronització al núvol';
	@override String get replaceTitle => 'L\'Stash recent se substituirà';
	@override String replaceBody({required Object name}) => 'Vas enviar “${name}” fa menys de 6 hores i encara no s\'ha descarregat. Els comptes gratuïts només conserven un element a l\'Stash alhora, així que si l\'envies ara el substituiràs.';
	@override String get replaceConfirm => 'Envia igualment';
	@override String get failedTitle => 'No s\'ha pogut enviar a Ham2K File Stash';
	@override String get sentTitle => 'S\'ha enviat a Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Pots recuperar aquest fitxer visitant **[stash.ham2k.net](https://stash.ham2k.net)** des de qualsevol navegador.',
		other: 'Pots recuperar aquests fitxers visitant **[stash.ham2k.net](https://stash.ham2k.net)** des de qualsevol navegador.',
	);
	@override String get mayHaveArrived => 'L\'Stash no ha respost — potser el fitxer ha arribat igualment. Comprova stash.ham2k.net abans de tornar-lo a enviar';
	@override String get notSent => 'no enviat';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'Aquest fitxer no ha arribat:',
		other: 'Aquests ${count} fitxers no han arribat:',
	);
	@override String get emailOffer => 'O, per a la teva comoditat, et podem enviar un correu electrònic amb un enllaç directe.';
	@override String get emailMe => 'Envia\'m un enllaç per correu electrònic';
	@override String get emailSent => 'T\'hem enviat un enllaç de descàrrega per correu electrònic.';
	@override String emailFailed({required Object error}) => 'No s\'ha pogut enviar el correu electrònic: ${error}';
	@override String get freeTier => 'Els comptes gratuïts només poden conservar un element a l\'Stash alhora. Els subscriptors en poden conservar tants com vulguin.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count,
		one: 'S\'ha enviat ${count} fitxer a Ham2K File Stash (stash.ham2k.net)',
		other: 'S\'han enviat ${count} fitxers a Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$ca extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get af => 'Àfrica';
	@override String get as => 'Àsia';
	@override String get eu => 'Europa';
	@override String get na => 'Amèrica del Nord';
	@override String get oc => 'Oceania';
	@override String get sa => 'Amèrica del Sud';
	@override String get an => 'Antàrtida';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$ca extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtra els anuncis';
	@override String get band => 'Banda';
	@override String get mode => 'Mode';
	@override String get age => 'Antiguitat';
	@override String get sources => 'Fonts';
	@override String get continent => 'Continent';
	@override String get sorting => 'Ordenació';
	@override String get sortByTime => 'Per hora de l\'anunci';
	@override String get sortByFrequency => 'Per freqüència';
	@override String get sortByWanted => 'Més buscats';
	@override String get groupByBand => 'Agrupa per banda';
	@override String get groupCallsWithNotes => 'Agrupa indicatius amb notes';
	@override String get alertingOnly => 'Només anuncis amb alertes';
	@override String get sourceNoReply => 'Sense resposta';
	@override String get sourceError => 'Error';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$ca extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'El panell de registre està ocupat';
	@override String get editingBody => 'Estàs editant un contacte registrat. Vols registrar aquest anunci, o tornar enrere i acabar l\'edició?';
	@override String get composingBody => 'Has començat a introduir un contacte. Vols registrar aquest anunci, o tornar enrere i acabar el que estaves escrivint?';
	@override String get goBack => 'Torna enrere';
	@override String get clearAndLog => 'Neteja i registra l\'anunci';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$ca extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mode esquerrà';
	@override String get descriptionOn => 'S\'utilitza la disposició per a esquerrans';
	@override String get descriptionOff => 'S\'utilitza la disposició per a dretans';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$ca extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Banderes del país';
	@override String get dx => 'Mostra-les només per als contactes DX';
	@override String get all => 'Mostra banderes per a tots els contactes';
	@override String get none => 'No mostris cap bandera';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$ca extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Es mostren banderes només per als contactes DX';
	@override String get all => 'Es mostren banderes per a tots els contactes';
	@override String get none => 'No es mostra cap bandera';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$ca extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Suggereix l\'operador';
	@override String get descriptionOn => 'S\'ofereix el teu indicatiu com a operador quan una operació fa servir un indicatiu d\'estació diferent';
	@override String get descriptionOff => 'L\'operador es deixa en blanc tret que l\'omplis tu';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$ca extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra el rumb';
	@override String get descriptionOn => 'Es mostra el rumb estimat cap a l\'estació';
	@override String get descriptionOff => 'No es mostra informació de rumb';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$ca extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra també el rumb invers';
	@override String get descriptionOn => 'Es mostra també el rumb des de l\'estació, com ara "45° / 225°"';
	@override String get descriptionOff => 'Es mostra només el rumb cap a l\'estació';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$ca extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Canvia l\'ordre dels informes de senyal';
	@override String get sentFirst => 'Enviat primer, Rebut segon';
	@override String get rcvdFirst => 'Rebut primer, Enviat segon';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$ca extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Salta al camp següent en introduir RST';
	@override String get descriptionOn => 'Es passa al camp següent després d\'introduir l\'RST';
	@override String get descriptionOff => 'No es passa automàticament al camp següent';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$ca extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Informe per defecte — Fonia';
	@override String get description => 'S\'utilitza quan Enviat o Rebut es deixen buits en SSB, FM o AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$ca extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Informe per defecte — CW i dades';
	@override String get description => 'S\'utilitza quan Enviat o Rebut es deixen buits en CW, RTTY i altres modes de dades';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$ca extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Informe per defecte — FT8 i FT4';
	@override String get description => 'S\'utilitza quan Enviat o Rebut es deixen buits en els modes FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$ca extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Fila de números';
	@override String get description => 'Mostra una fila de tecles numèriques sobre el teclat mentre registres';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$ca extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tecla de barra i punt';
	@override String get description => 'Afegeix una tecla contextual: “/” per als indicatius, “.” per als números';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$ca extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibra en prémer una tecla';
	@override String get description => 'Resposta hàptica quan toques una tecla numèrica';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$ca extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get off => 'Desactivat';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$ca extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'no hi ha cap indicatiu d\'operador per iniciar sessió';
	@override String get connectFailed => 'no s\'ha pogut contactar amb el node';
	@override String get needsPassword => 'el node demana una contrasenya, i no n\'hi ha cap de desada';
	@override String get loginFailed => 'el node no ha acceptat l\'inici de sessió';
	@override String get disconnected => 'el node ha tancat la connexió';
	@override String get timeout => 'el node no ha respost';
	@override String get off => 'Connecta al clúster està desactivat';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$ca extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$ca extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controla el PTT amb el teclat';
	@override late final _Translations$settings$radio$pttKey$modes$ca modes = _Translations$settings$radio$pttKey$modes$ca._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$ca descriptions = _Translations$settings$radio$pttKey$descriptions$ca._(_root);
	@override String get key => 'Tecla PTT';
	@override String get pill => 'TX';
	@override String get transmitting => 'Transmetent';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$ca extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajust intel·ligent del VFO';
	@override String get descriptionOn => 'Quan deixes de girar el dial, s\'arrodoneix la freqüència a un pas raonable. Només en modes de veu.';
	@override String get descriptionOff => 'Es queda exactament on l\'has sintonitzat.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$ca extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajust intel·ligent: retard d\'estabilització';
	@override String get description => 'Quant de temps s\'ha d\'aturar el dial abans d\'arrodonir la freqüència. Més curt sembla immediat; més llarg deixa marge per a un moviment lent.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$ca extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajust intel·ligent: moviment llarg';
	@override String get description => 'Si mous almenys aquesta distància, la freqüència s\'arrodoneix a un kHz sencer, per lentament que hagis acabat.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$ca extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajust intel·ligent: moviment mínim';
	@override String get description => 'Si mous menys d\'això, la freqüència no s\'arrodoneix, així la sintonia fina queda intacta.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$ca extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajust intel·ligent: moviment més lent';
	@override String get description => 'Si gires el dial més lentament que això, la freqüència no s\'arrodoneix, tret que sigui un moviment llarg.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$ca extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Desact.';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter envia missatges';
	@override String get off => 'Desactivat';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter envia missatges: ${state}. Toca per canviar.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$ca extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Velocitat del manipulador';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$ca extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Missatges del manipulador CW';
	@override String get notSupported => 'La ràdio actual no admet manipulació CW';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Missatge ${n}';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta F${n}';
	@override String get details => 'Detalls';
	@override String get empty => '(buit)';
	@override String get sets => 'Joc de missatges';
	@override String get newSet => 'Joc nou';
	@override String get renameSet => 'Canvia el nom del joc';
	@override String get deleteSet => 'Esborra el joc';
	@override String get newSetName => 'Nom';
	@override String get setDefault => 'Per defecte';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Missatges ESM';
	@override String get setSaved => 'Els meus missatges';
	@override String get repeat => 'Repeteix el missatge 1';
	@override String get repeatShort => 'Repeteix M1';
	@override String get cooldown => 'Pausa abans de repetir';
	@override String cooldownSeconds({required Object n}) => '${n} segons';
	@override String get repeatWait => 'Repetint';
	@override String get keyboard => 'Escriu per enviar';
	@override String get keyboardField => 'Escriu per enviar';
	@override String get help => 'Ajuda';
	@override String get helpTitle => 'Com escriure missatges CW';
	@override String get helpIntro => 'Els missatges poden fer servir plantilles amb els valors següents:';
	@override String get helpOpCall => 'El teu indicatiu';
	@override String get helpQsoCall => 'El seu indicatiu — en una pila //, l\'indicatiu que es registrarà';
	@override String get helpQsoFullCall => 'El seu indicatiu, si és un indicatiu vàlid; en blanc si és parcial';
	@override String get helpQsoPartial => 'Un indicatiu parcial; en blanc si hi ha un indicatiu complet vàlid';
	@override String get helpQsoNextCall => 'En una pila //, l\'indicatiu que se seleccionarà per registrar a continuació, si és un indicatiu complet vàlid';
	@override String get helpQsoNextPartial => 'En una pila //, el següent parcial després de registrar el contacte actual';
	@override String get helpQsoName => 'El seu nom, tal com s\'ha escrit o, si no, de la consulta';
	@override String get helpQsoState => 'El seu estat, tal com s\'ha escrit o, si no, de la consulta';
	@override String get helpKeyerMsg => 'El missatge 1 tal com s\'enviaria, dins d\'un altre missatge. Vàlid per als missatges de l\'1 al 8';
	@override String get helpQsoRst => 'L\'informe que envies';
	@override String get helpQsoSerial => 'El teu número de sèrie, en un concurs que n\'enviï';
	@override String get helpPad => 'Omple amb zeros fins a aquest nombre de dígits: 7 s\'envia com 007';
	@override String get helpCut => 'Números abreujats, T per 0 i N per 9: 599 s\'envia com 5NN';
	@override String get helpCutDigits => 'Tria els dígits a abreujar, entre cometes — 0 és T, 1 és A, 5 és E, 9 és N';
	@override String get helpFullExample => 'Exemple complet:';
	@override String get helpExample => 'Envia W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Amb Enter envia missatges activat, Enter envia els missatges per la seva tecla de funció, com fa N1MM. El joc Missatges ESM comença amb aquests:';
	@override String get helpEsmCq => 'En Run, Enter amb el camp d\'indicatiu buit crida CQ';
	@override String get helpEsmExchange => 'El teu intercanvi: després del seu indicatiu en Run, després que responguin en S&P';
	@override String get helpEsmThanks => 'Agraïment, un cop registrat el contacte: qso és el contacte tal com s\'ha registrat, next el que ve a continuació';
	@override String get helpEsmMyCall => 'En S&P, el teu indicatiu per a l\'estació a qui respons';
	@override String get helpEsmHisCall => 'En Run, el seu indicatiu abans del teu intercanvi';
	@override String get helpEsmAgain => 'Torna a demanar quan no s\'ha copiat res del seu intercanvi';
	@override String get helpEsmStackThanks => 'F3 suggerit per a piles //: agraeix, després crida la següent estació de la pila i envia el teu intercanvi, o torna a demanar un parcial (TU KR?); si no en queda cap, només TU';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$ca extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get label => 'Manipulador';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => 'Veu';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$ca extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Missatges del manipulador de fonia';
	@override String get notSupported => 'La ràdio actual no admet missatges de fonia';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memòria de veu ${n}';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta de la memòria de veu ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Buida';
	@override String get notMeasured => 'Durada desconeguda';
	@override String get playButton => 'Reprodueix';
	@override String get recordButton => 'Grava';
	@override String get stopButton => 'Atura';
	@override String get repeat => 'Repeteix el missatge 1';
	@override String recordHelpTitle({required Object model}) => 'Notes per a ${model}:';
	@override String namedOnDevice({required Object device}) => 'Aquestes memòries són a la ràdio de ${device}. Els seus noms i durades pertanyen a aquell dispositiu.';
	@override String get namedOnRadio => 'Desat a la ràdio, on també el veuen els seus altres clients.';
	@override String get recordHelpYaesuDvs => 'Espera l\'indicador [REC] a la ràdio, després mantén premut el botó PTT i grava el teu missatge. Acaba\'l prement el botó ATURA aquí a l\'aplicació abans de deixar anar el PTT per evitar clics no desitjats.';
	@override String get recordHelpFt891 => 'Espera que l\'indicador [REC] parpellegi almenys quatre vegades, després mantén premut el botó PTT i grava el teu missatge. Acaba\'l prement el botó ATURA aquí a l\'aplicació abans de deixar anar el PTT per evitar clics no desitjats.';
	@override String get pill => 'Veu';
	@override String play({required Object n}) => 'Reprodueix la memòria ${n}';
	@override String get stop => 'Atura';
	@override String record({required Object n}) => 'Grava la memòria ${n}';
	@override String get stopRecording => 'Atura la gravació';
	@override String get playing => 'Reproduint…';
	@override String get recording => 'Gravant…';
	@override String recordingMemory({required Object label}) => 'Gravant ${label}';
	@override String get doubtful => 'L\'ha reproduït la ràdio? Ha informat que estava inactiva immediatament.';
	@override String get recordOnRadio => 'Has de gravar les memòries a la mateixa ràdio.';
	@override String get sets => 'Joc de missatges';
	@override String get soundFilesSet => 'Fitxers de so d\'aquest ordinador';
	@override String get openFileButton => 'Obre un fitxer';
	@override String get newSet => 'Joc nou';
	@override String get renameSet => 'Canvia el nom del joc';
	@override String get deleteSet => 'Esborra el joc';
	@override String get newSetName => 'Nom';
	@override String deleteSetConfirm({required Object name}) => 'Esborrar ${name} i les seves gravacions? No es pot desfer.';
	@override String get output => 'Envia l\'àudio a';
	@override String get input => 'Grava des de';
	@override String get outputRadio => 'Envia a la ràdio per la xarxa';
	@override String get inputDefault => 'Per defecte del sistema';
	@override String get pickDevice => 'Tria un dispositiu de so';
	@override String deviceMissing({required Object name}) => '${name} (no connectat)';
	@override String get lead => 'Retard en activar el PTT';
	@override String get tail => 'Retard en desactivar el PTT';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => 'Escolta';
	@override String get notRecorded => 'Sense gravar';
	@override String get unplayable => 'No es pot reproduir aquest fitxer';
	@override String get problemNoOutput => 'Tria el dispositiu de so que alimenta la ràdio abans de reproduir un missatge.';
	@override String get problemOutputMissing => 'El dispositiu de so que alimenta la ràdio no està connectat.';
	@override String get problemInputMissing => 'El dispositiu de gravació no està connectat.';
	@override String get problemDeviceFailed => 'El dispositiu de so no s\'ha pogut obrir.';
	@override String get problemNotRecorded => 'Aquest missatge encara no té cap gravació.';
	@override String get problemRecordingSilent => 'No s\'ha sentit res del dispositiu de gravació, així que el missatge s\'ha deixat com estava. Comprova l\'entrada, i que l\'aplicació tingui permís per fer servir el micròfon.';
	@override String get problemRadioAudioUnavailable => 'La ràdio no està agafant l\'àudio de l\'aplicació ara mateix. Cal una connexió de xarxa amb la ràdio.';
	@override String get problemSourceRefused => 'La ràdio no ha volgut canviar el seu àudio de transmissió a l\'aplicació, així que el missatge s\'ha aturat. Configura la ràdio perquè transmeti l\'àudio de l\'aplicació.';
	@override String get problemCannotKey => 'Aquesta ràdio no es pot posar en transmissió per CAT, així que l\'ordinador no hi pot reproduir missatges.';
	@override String get problemUnplayable => 'El fitxer d\'aquest missatge no és un fitxer de so que l\'aplicació pugui reproduir. Fes servir un fitxer WAV, FLAC o MP3, o torna\'l a gravar.';
	@override String get problemRecordingFailed => 'La gravació s\'ha interromput, així que el missatge s\'ha deixat com estava. Comprova que el dispositiu de gravació continua connectat i que hi ha espai al disc.';
	@override String get problemFileFailed => 'La gravació no s\'ha pogut desar al lloc del missatge, així que el missatge s\'ha deixat com estava.';
	@override String problemWordsMissing({required Object words}) => 'Aquest missatge necessita paraules que no has gravat: ${words}.';
	@override String problemTemplateFailed({required Object error}) => 'La plantilla d\'aquest missatge té un problema: ${error}';
	@override String get problemNoOperation => 'Els missatges dits amb les teves paraules es reprodueixen dins d\'una operació, on hi ha un contacte per a qui dir-los.';
	@override String get problemNothingSaid => 'Aquest missatge no diu res per a aquest contacte.';
	@override String get templateField => 'Digues-ho amb les meves paraules';
	@override String get templateHelp => 'Deixa-ho buit per reproduir la gravació. Si no, el missatge es diu amb les paraules que has gravat, omplert per a cada contacte, amb aquests valors:';
	@override String get help => 'Ajuda';
	@override String get helpTitle => 'Dir missatges amb les teves paraules';
	@override String get helpFullExample => 'Un missatge complet:';
	@override String get helpExample => 'El seu indicatiu, el seu informe i la teva gravació de “QSL?”';
	@override String get playOnRadio => 'Reprodueix a la ràdio';
	@override String get templateHelpCall => 'El seu indicatiu';
	@override String get templateHelpReport => 'L\'informe que li dones';
	@override String get templateHelpMessage => 'La gravació del missatge 2, reproduïda tal com es va gravar';
	@override String get voiced => 'Dit amb les teves paraules';
	@override String willSay({required Object words}) => 'Diu: ${words}';
	@override String willSayMissing({required Object words}) => 'Encara no gravat: ${words}';
	@override String get previewNoOperation => 'Obre una operació per veure què dirà.';
	@override String get wordsDescription => 'Fes servir la teva pròpia veu per a indicatius, números i més.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$ca extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gravacions de paraules';
	@override String get callField => 'Paraules de l\'operador';
	@override String get intro => 'Grava cada paraula o número tres vegades, seguides i de pressa, tal com ho dius en un indicatiu. Les frases més llargues només es graven una vegada.';
	@override String get recordAll => 'Grava-ho tot';
	@override String get recordAllGuide => 'Llegeix cada paraula tres vegades, seguides, i una frase de diverses paraules una vegada, respirant entre línies. Prem Atura després de l\'última.';
	@override String recordingOne({required Object word}) => 'Digues “${word} ${word} ${word}” i després prem Atura.';
	@override String recordingOnce({required Object words}) => 'Digues “${words}” i després prem Atura.';
	@override String get recorded => 'Gravada';
	@override String get notRecorded => 'Sense gravar';
	@override String get addPhrase => 'Afegeix una frase';
	@override String get phraseField => 'Frase, tal com l\'escrius en un missatge';
	@override String get deletePhrase => 'Esborra la frase';
	@override String get tryField => 'Prova de dir';
	@override String get pauseLetters => 'Pausa entre lletres';
	@override String get pauseWords => 'Pausa entre paraules';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => 'Velocitat';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => 'Configuració avançada';
	@override String get splitSilent => 'No s\'ha sentit res a la gravació.';
	@override String get splitNotThreeTakes => 'No s\'han trobat tres preses. Digues la paraula tres vegades seguides i torna-ho a provar.';
	@override String get splitLineCount => 'No s\'han trobat totes les paraules a la lectura. Llegeix cada una tres vegades, respirant entre paraules.';
	@override String get splitLinesTooClose => 'No s\'han pogut distingir les paraules. Deixa una respiració més llarga entre paraules.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$ca extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evita el batement zero als anuncis';
	@override String get descriptionOn => 'Amb una ràdio connectada, es sintonitza uns quants Hz fora d\'un anunci CW, perquè tothom qui respon no cridi a la mateixa nota.';
	@override String get descriptionOff => 'Es sintonitza exactament a la freqüència anunciada.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$ca extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Batement zero: marge d\'evitació';
	@override String get description => 'Quant s\'allunya de la freqüència anunciada, a banda i banda. El desplaçament mai és proper a zero — tornaria a ser un batement zero.';
}

// Path: settings.map.style
class _Translations$settings$map$style$ca extends Translations$settings$map$style$en {
	_Translations$settings$map$style$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estil del mapa';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$ca extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra els indicatius';
	@override String get description => 'Cada contacte és una píndola amb el seu indicatiu, del color de la seva banda';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$ca extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra la línia grisa';
	@override String get description => 'Ombreja el costat nocturn de la Terra, amb el crepuscle com a degradat';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$ca extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automàtic';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$ca extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Comparteix dades d\'ús de l\'aplicació';
	@override String get descriptionOn => 'Ens ajudes a millorar l\'aplicació compartint dades d\'ús, configuració, fallades i rendiment';
	@override String get descriptionOff => 'Es mantenen privades les dades d\'ús de l\'aplicació.\nL\'equip de Ham2K no podrà detectar fallades ni altres incidències.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$ca extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Comparteix dades d\'operació';
	@override String get descriptionOn => 'Es comparteixen algunes dades d\'operació públicament i amb altres usuaris';
	@override String get descriptionOff => 'Es mantenen privades les dades d\'operació';
}

// Path: settings.station.models
class _Translations$settings$station$models$ca extends Translations$settings$station$models$en {
	_Translations$settings$station$models$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Genèric';
	@override String get icomGeneric => 'Icom - Genèric';
	@override String get kenwoodGeneric => 'Kenwood - Genèric';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Genèric';
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
	@override String get rigctld => 'Ràdio controlada via rigctld';
	@override String get rigctldNodeName => 'La meva ràdio (via rigctld)';
	@override String get flrig => 'Ràdio controlada via flrig';
	@override String get flrigNodeName => 'La meva ràdio (via flrig)';
	@override String get hrd => 'Ràdio controlada via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'La meva ràdio (via HRD)';
	@override String get n3fjp => 'Ràdio controlada via N3FJP';
	@override String get n3fjpNodeName => 'La meva ràdio (via N3FJP)';
	@override String get commander => 'Ràdio controlada via DXLab Commander';
	@override String get commanderNodeName => 'La meva ràdio (via Commander)';
	@override String get antenna => 'Antena';
	@override String get key => 'Manipulador CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Ràdio genèrica (provisional)';
	@override String get placeholderRadioNodeName => 'La meva ràdio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Commutador coaxial Sierra Radio CX-1';
	@override String get gs232a => 'Interfície de rotor Yaesu GS-232A';
	@override String get pstRotator => 'PstRotator (control UDP)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$ca extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get network => 'Xarxa/WiFi';
	@override String get secureNetwork => 'Xarxa/WiFi segura';
	@override String get usbSerial => 'Sèrie USB';
	@override String get wifi => 'Xarxa/WiFi';
	@override String get bluetoothSerial => 'Sèrie Bluetooth';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'Provisional';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$ca extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipol';
	@override String get vertical => 'Vertical';
	@override String get yagiBeam => 'Yagi / Directiva';
	@override String get loop => 'Llaç';
	@override String get longWire => 'Fil llarg / EFHW';
	@override String get other => 'Altres';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$ca extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Manipulador vertical';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semiautomàtic mecànic)';
	@override String get fullyAutomatic => 'Manipulador totalment automàtic';
	@override String get singlePaddle => 'Pala simple';
	@override String get dualPaddle => 'Pala doble';
	@override String get computerDriven => 'Controlat per ordinador';
	@override String get other => 'Altres';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$ca extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Desconegut';
	@override String get sunny => 'Assolellat';
	@override String get clear => 'Serè';
	@override String get mainlySunny => 'Majoritàriament assolellat';
	@override String get mainlyClear => 'Majoritàriament serè';
	@override String get partlyCloudy => 'Parcialment ennuvolat';
	@override String get cloudy => 'Ennuvolat';
	@override String get foggy => 'Boira';
	@override String get rimeFog => 'Boira gebradora';
	@override String get lightDrizzle => 'Plugim feble';
	@override String get drizzle => 'Plugim';
	@override String get heavyDrizzle => 'Plugim intens';
	@override String get lightFreezingDrizzle => 'Plugim gelant feble';
	@override String get freezingDrizzle => 'Plugim gelant';
	@override String get lightRain => 'Pluja feble';
	@override String get rain => 'Pluja';
	@override String get heavyRain => 'Pluja intensa';
	@override String get lightFreezingRain => 'Pluja gelant feble';
	@override String get freezingRain => 'Pluja gelant';
	@override String get lightSnow => 'Neu feble';
	@override String get snow => 'Neu';
	@override String get heavySnow => 'Neu intensa';
	@override String get snowGrains => 'Neu granulada';
	@override String get lightShowers => 'Ruixats febles';
	@override String get showers => 'Ruixats';
	@override String get heavyShowers => 'Ruixats intensos';
	@override String get lightSnowShowers => 'Ruixats de neu febles';
	@override String get snowShowers => 'Ruixats de neu';
	@override String get thunderstorm => 'Tempesta';
	@override String get lightThunderstormsWithHail => 'Tempestes febles amb calamarsa';
	@override String get thunderstormWithHail => 'Tempesta amb calamarsa';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$ca extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get off => 'No';
	@override String get toggle => 'Commuta';
	@override String get hold => 'Mantén';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$ca extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$ca._(TranslationsCa root) : this._root = root, super.internal(root);

	final TranslationsCa _root; // ignore: unused_field

	// Translations
	@override String get off => 'El teclat no posa la ràdio en transmissió.';
	@override String get toggle => 'En modes de fonia, la tecla PTT posa la ràdio en transmissió i tornar-la a prémer la treu. Es desactiva sola al cap d\'un minut.';
	@override String get hold => 'En modes de fonia, la ràdio transmet mentre la tecla PTT es manté premuda, fins a un minut.';
}

/// The flat map containing all translations for locale <ca>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsCa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Desa',
			'common.ok' => 'D\'acord',
			'common.cancel' => 'Cancel·la',
			'common.delete' => 'Esborra',
			'common.create' => 'Crea',
			'common.error' => 'Error',
			'common.close' => 'Tanca',
			'common.done' => 'Fet',
			'common.callsign' => 'Indicatiu',
			'common.clear' => 'Neteja',
			'common.dismiss' => 'Descarta',
			'common.copyDetails' => 'Copia els detalls',
			'common.expand' => 'Desplega',
			'common.collapse' => 'Plega',
			'onboarding.welcomeTitle' => 'Et donem la benvinguda a Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Et donem la benvinguda a Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Tenim unes quantes preguntes per adaptar-nos millor a les teves necessitats.',
			'onboarding.skip' => 'Omet',
			'onboarding.kContinue' => 'Continua',
			'onboarding.back' => 'Enrere',
			'onboarding.next' => 'Següent',
			'onboarding.done' => 'Fet',
			'onboarding.callsignTitle' => 'Quin és el teu indicatiu?',
			'onboarding.callsignBody' => 'Necessites una llicència de radioaficionat perquè aquesta aplicació et sigui útil',
			'onboarding.callsignLabel' => 'Indicatiu de l\'operador',
			'onboarding.alreadyHaveAccount' => 'Ja tens un compte?',
			'onboarding.foundSiblingTitle' => 'Vincular un compte existent?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Hem trobat ${app} en aquest dispositiu. Vincula aquesta aplicació al mateix compte i hi arribaran el teu indicatiu i els teus registres.',
			'onboarding.foundPoloBody' => 'Hem trobat una versió anterior de Ham2K Portable Logger en aquest dispositiu. Vincula aquesta aplicació al mateix compte i hi arribaran el teu indicatiu i els teus registres.',
			'onboarding.foundSiblingsBody' => 'Hem trobat altres aplicacions de Ham2K en aquest dispositiu. Vincula aquesta aplicació al compte d\'una d\'elles i hi arribaran el teu indicatiu i els teus registres.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Vincula amb ${app}',
			'onboarding.linkWithPolo' => 'Vincula amb el compte de la versió anterior',
			'onboarding.setUpFresh' => 'Configura de zero',
			'onboarding.activitiesTitle' => 'Activitats preferides',
			'onboarding.activitiesBody' => 'T\'interessa algun d\'aquests programes d\'activació populars?',
			'onboarding.activitiesFooter' => '(Trobaràs més opcions a la Configuració)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'Sincronització al núvol',
			'onboarding.syncBody' => 'Ham2K Log Filer guarda una còpia de seguretat dels teus registres al núvol i els sincronitza entre tots els dispositius on facis servir aplicacions de Ham2K.',
			'onboarding.syncPricing' => 'És gratuït! Però amb una subscripció de pagament anirà més ràpid.',
			'onboarding.syncLabel' => 'Activa la sincronització al núvol',
			'onboarding.syncOffWarning' => 'ATENCIÓ: això augmenta el risc de perdre dades d\'operació, per exemple si el dispositiu falla o es perd.',
			'onboarding.notNow' => 'Ara no',
			'onboarding.consentTitle' => 'Dades i privacitat',
			'onboarding.consentUsageBody' => 'Per ajudar-nos a millorar l\'aplicació, ens agradaria recollir dades de rendiment, fallades i ús de l\'aplicació.',
			'onboarding.consentUsageLabel' => 'Comparteix dades d\'ús de l\'aplicació',
			'onboarding.consentOperationBody' => 'Algunes funcions poden implicar compartir les teves dades d\'operació amb altres usuaris. Pots desactivar-ho en qualsevol moment.',
			'onboarding.consentOperationLabel' => 'Comparteix dades d\'operació',
			'onboarding.finishingSetup' => 'Acabant la configuració: descarregant dades de referència…',
			'startScreen.credits' => 'per KI2D i amics',
			'testerOverlay.tape' => 'ATENCIÓ: EN CONSTRUCCIÓ',
			'testerOverlay.warningTitle' => 'Aquesta aplicació està en desenvolupament',
			'testerOverlay.warningBody' => 'La majoria de funcions tenen el terra irregular i hi ha perill d\'ensopegar arreu. Comprova si hi ha actualitzacions regularment.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novetats de la versió ${build}',
			'testerOverlay.thanks' => 'Gràcies per arriscar el teu registre per ajudar-nos a millorar aquesta aplicació!',
			'extensionsPanel.categoryActivity' => 'Activitats',
			'extensionsPanel.categoryAward' => 'Diplomes',
			'extensionsPanel.categoryContest' => 'Concursos',
			'extensionsPanel.categoryLookup' => 'Consultes d\'indicatius',
			'extensionsPanel.categorySpots' => 'Fonts d\'anuncis',
			'extensionsPanel.categoryDashboard' => 'Panells del tauler',
			'extensionsPanel.categoryOther' => 'Altres extensions',
			'extensionsPanel.searchHint' => 'Cerca extensions',
			'extensionsPanel.applying' => 'Activant els canvis d\'extensions, això pot trigar un moment…',
			'extensionsPanel.noMatches' => 'Cap extensió coincideix amb la cerca',
			'extensionsPanel.installFromFile' => 'Instal·la des d\'un fitxer…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versió ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Captura ${n} de ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Captura anterior',
			'extensionsPanel.nextScreenshot' => 'Captura següent',
			'extensionsPanel.screenshotUnavailable' => 'Captura no disponible',
			'extensionsPanel.canReach' => 'Aquesta extensió pot contactar amb',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, amb una connexió activa',
			'extensionsPanel.canHoldLocalConnection' => 'Dispositius de la teva xarxa local, amb una connexió activa',
			'extensionsPanel.canUseLocation' => 'La teva ubicació',
			'extensionsPanel.canReadRadio' => 'La teva ràdio, per llegir-ne la freqüència i el mode',
			'extensionsPanel.canControlRadio' => 'La teva ràdio, per controlar-la i transmetre-hi — sintonia, potència, CW, memòries de veu i PTT',
			'extensionsPanel.canCommandRadioRaw' => 'La teva ràdio, per enviar-li qualsevol ordre en el seu propi protocol — incloses les que transmeten o en canvien la configuració',
			'extensionsPanel.canReadCluster' => 'El clúster DX, amb la teva sessió iniciada, per llegir el que envia',
			'extensionsPanel.canSpotCluster' => 'El clúster DX, amb la teva sessió iniciada, per publicar anuncis en nom teu',
			'extensionsPanel.canCommandCluster' => 'El clúster DX, amb la teva sessió iniciada, per enviar-li qualsevol ordre en nom teu',
			'extensionsPanel.canSetUserAgent' => 'Identificar-se davant dels servidors amb el seu propi nom',
			'extensionsPanel.canChangeSettings' => 'La teva configuració, per canviar-la amb les seves ordres: qualsevol opció, el mode de desenvolupador i els experiments',
			'extensionsPanel.noCapabilities' => 'No demana res fora de l\'aplicació.',
			'extensionsPanel.sandboxNote' => 'Les extensions s\'executen aïllades: sense accés als teus fitxers i sense xarxa més enllà del que s\'indica aquí.',
			'extensionsPanel.installAction' => 'Instal·la',
			'extensionsPanel.updateAction' => 'Actualitza',
			'extensionsPanel.installFailed' => 'No s\'ha pogut instal·lar aquesta extensió',
			'extensionsPanel.installedBadge' => 'Instal·lada',
			'extensionsPanel.uninstallAction' => 'Elimina',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Eliminar ${name}?',
			'extensionsPanel.uninstallBody' => 'S\'eliminaran aquesta extensió i la seva configuració. Els teus registres no es tocaran.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'S\'ha instal·lat ${name}',
			'extensionsPanel.installDownloading' => 'Descarregant…',
			'extensionsPanel.installWaiting' => 'Esperant per instal·lar…',
			'extensionsPanel.installInstalling' => 'Instal·lant…',
			'extensionsPanel.installAwaitingApproval' => 'Esperant la teva aprovació…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} ja s\'està instal·lant.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Actualitzada a ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'La instal·lació de ${name} no ha acabat. Potser cal tornar-la a instal·lar.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'No s\'ha pogut eliminar ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Descarregada de ${source}',
			'extensionsPanel.dropHint' => 'Deixa anar una extensió .h2kext per instal·lar-la',
			'extensionsPanel.dropOneOnly' => 'Deixa anar les extensions d\'una en una.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} ha retornat ${status} per a aquesta extensió.',
			'extensionsPanel.downloadTooLarge' => 'Aquesta descàrrega és massa gran per ser una extensió.',
			'extensionsPanel.downloadNotSecure' => 'Aquesta descàrrega ha redirigit a un lloc insegur.',
			'extensionsPanel.catalogSection' => 'Catàleg',
			'extensionsPanel.catalogLoading' => 'Carregant el catàleg…',
			'extensionsPanel.catalogUnreachable' => 'Catàleg inaccessible',
			'extensionsPanel.builtIn' => 'Integrada',
			'extensionsPanel.updateAvailableBadge' => 'Actualització disponible',
			'extensionsPanel.updatesAvailableTitle' => 'Actualitzacions d\'extensions',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Hi ha una actualització disponible per a ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => 'Cal actualitzar ${names} i ${count} més.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => 'Cal actualitzar ${names}.',
			'extensionsPanel.pendingUpdatesSection' => 'Actualitzacions pendents',
			'extensionsPanel.updateAllAction' => 'Actualitza-ho tot',
			'extensionsPanel.updatesUnderWay' => 'Aquestes actualitzacions ja estan en curs.',
			'extensionsPanel.updatesNothingLeft' => 'Les teves extensions estan al dia.',
			'extensionsPanel.updatesNoticeAction' => 'Més informació',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Actualitzar ${count} extensió?', other: 'Actualitzar ${count} extensions?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Les teves extensions estan a punt',
			'extensionsPanel.upgradeDoneBody' => 'Ara provenen del catàleg d\'extensions de Ham2K, de manera que es poden actualitzar sense esperar una nova versió de l\'aplicació.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'No actualitzades: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'No s\'han executat: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Continuen instal·lades i marcades a Configuració › Extensions; si les actualitzes allà, tornaran a funcionar.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'El catàleg no té cap substitut directe per a aquestes, així que busca-hi extensions que cobreixin el que feies servir.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Esdeveniments de parcs estatals',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} de les teves extensions encara no han arribat. Es descarregaran la propera vegada que es pugui accedir al catàleg d\'extensions.',
			'extensionsPanel.runtimeDeadBody' => 'Les teves extensions no s\'han iniciat. Reiniciar l\'aplicació hauria de recuperar-les.',
			'extensionsPanel.refusedTitle' => 'Algunes extensions no s\'han executat',
			'extensionsPanel.upgradeBusyTitle' => 'Encara s\'està configurant',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Les teves extensions no s\'estan executant',
			'extensionsPanel.restoreTitle' => 'Falten algunes de les teves extensions',
			'extensionsPanel.restoreBody' => 'Aquestes extensions que vas instal·lar no són en aquest dispositiu. Les podem tornar a descarregar del catàleg d\'extensions de Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Instal·lades des d\'un fitxer. Torna-les a instal·lar des dels seus fitxers, o oblida-les:',
			'extensionsPanel.restoreOtherCatalog' => 'Instal·lades des d\'un altre catàleg d\'extensions, així que no estan disponibles aquí:',
			'extensionsPanel.restoreForget' => 'Oblida',
			'extensionsPanel.restoreInstall' => 'Instal·la',
			'extensionsPanel.restoreLater' => 'Més tard',
			'extensionsPanel.restoreInstalling' => 'Instal·lant les teves extensions…',
			'extensionsPanel.restoreDoneTitle' => 'Les teves extensions han tornat',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Instal·lades de nou: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'No s\'han pogut instal·lar algunes extensions',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'No s\'han pogut instal·lar: ${names}. Te les tornarem a oferir la propera vegada que obris l\'aplicació.',
			'extensionsPanel.restoreBusyBody' => 'L\'aplicació encara està configurant les teves extensions. Te les tornarem a oferir la propera vegada que obris l\'aplicació.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Les hem tornat a instal·lar, però les teves extensions no s\'han iniciat. Reiniciar l\'aplicació hauria de recuperar-les.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} s\'ha retirat',
			'extensionsPanel.revokedBody' => 'El catàleg ha retirat aquesta versió, així que s\'ha desactivat.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => '${name} s\'ha desactivat',
			'extensionsPanel.forceDisabledBody' => 'Ham2K ha desactivat aquesta extensió de moment.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name} s\'ha substituït',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => '${replacement} ocupa el seu lloc. Pots fer el canvi a Extensions.',
			'extensionsPanel.replacedBy' => ({required Object name}) => 'Substituïda per ${name}',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'Substituïda per ${name}, que ja tens',
			'extensionsPanel.replaceAction' => 'Substitueix',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => 'La seva configuració passa a ${replacement}, que ja tens. Els teus registres no es tocaran.',
			'extensionsPanel.downloadHashMismatch' => 'Aquesta descàrrega no és l\'extensió que descriu el catàleg.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'El catàleg no té la versió ${version} de ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Aquest enllaç del catàleg no indica cap versió d\'extensió.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'El catàleg no té cap versió de ${key} en aquesta branca.',
			'extensionsPanel.installFromLink' => 'Instal·la des d\'un enllaç',
			'extensionsPanel.unstableReleaseWarning' => 'Aquesta és una versió inestable, que el seu editor no dona per acabada. Pot fallar i continuarà rebent actualitzacions inestables.',
			'extensionsPanel.bleedingReleaseWarning' => 'Aquesta és una versió experimental: feina en curs que pot trencar-se o perdre la configuració. Continuarà rebent actualitzacions experimentals.',
			'extensionsPanel.channelUnstable' => 'Inestable',
			'extensionsPanel.channelBleeding' => 'Experimental',
			'extensionsPanel.followsUnstable' => 'Rep versions inestables i estables',
			'extensionsPanel.followsBleeding' => 'Rep versions experimentals, inestables i estables',
			'extensionsPanel.followStableAction' => 'Segueix només les versions estables',
			'extensionsPanel.revokedBadge' => 'Retirada',
			'extensionsPanel.forceDisabledBadge' => 'Desactivada per Ham2K',
			'extensionsPanel.refusedBadge' => 'No s\'ha carregat',
			'extensionsPanel.downloadNotHttps' => 'Aquesta descàrrega no fa servir una connexió segura.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'No s\'ha pogut contactar amb ${source} per a aquesta extensió.',
			'extensionsPanel.detailsAction' => 'Detalls',
			'extensionsPanel.installedFromFile' => 'Instal·lada des d\'un fitxer',
			'extensionsPanel.detailsWhatItDoes' => 'Proporciona suport per a',
			'extensionsPanel.installedPreloaded' => 'Preinstal·lada',
			'extensionsPanel.hookAccount' => 'Inici de sessió de compte',
			'extensionsPanel.hookCallNotes' => 'Notes d\'indicatius',
			'extensionsPanel.hookDataFile' => 'Dades fora de línia',
			'extensionsPanel.hookExport' => 'Exportació',
			'extensionsPanel.hookLookup' => 'Consultes d\'indicatius',
			'extensionsPanel.hookScoring' => 'Puntuació',
			'extensionsPanel.hookSpots' => 'Anuncis',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Caça de ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Activació de ${program}',
			'extensionsPanel.suggestedSection' => 'Suggerides',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => 'Més disponibles (${count})',
			'home.title' => 'Registrador Portàtil',
			'home.newOperation' => 'Nova operació',
			'home.stationCallsign' => 'Indicatiu d\'estació',
			'home.titleOptional' => 'Títol (opcional)',
			'home.emptyList' => 'Encara no hi ha operacions. Crea\'n una per començar a registrar.',
			'home.quickLookup' => 'Cerca ràpida',
			'home.nav.operations' => 'Operacions',
			'home.nav.chase' => 'Caça',
			'home.nav.logs' => 'Registres',
			'home.nav.maps' => 'Mapes',
			'home.nav.settings' => 'Configuració',
			'home.panels.operations' => 'Llista d\'operacions',
			'home.panels.operationsDescription' => 'Les teves operacions, les més recents primer.',
			'home.panels.version' => 'Versió actual',
			'home.panels.versionDescription' => 'El logotip de Ham2K, el nom d\'aquesta aplicació i la versió que estàs executant.',
			'home.toggleNav' => 'Mostra o amaga les etiquetes de navegació',
			'home.logs.title' => 'Registres',
			'home.logs.titleFor' => 'Registres de',
			'home.logs.emptyCallsigns' => 'Encara no hi ha QSOs registrats',
			'home.logs.emptyQsos' => ({required Object call}) => 'No hi ha QSOs per a ${call}',
			'home.logs.mapNoSelection' => 'Selecciona un QSO per veure\'l al mapa',
			'home.logs.searchHint' => 'Cerca indicatiu o nom',
			'home.logs.noSearchMatches' => 'Cap QSO coincideix amb la cerca',
			'home.logs.titleAll' => 'Tots els registres',
			'home.logs.allCallsigns' => 'Tots els indicatius',
			'home.logs.noOperation' => 'No forma part de cap operació',
			'home.logs.unsavedTitle' => 'Canvis sense desar',
			'home.logs.unsavedBody' => 'Aquest QSO té canvis que no has desat.',
			'home.logs.pendingDeleteBody' => 'Aquest QSO està marcat per esborrar.',
			'home.logs.editGone' => 'No desat: aquest QSO ja no és en aquest registre.',
			'home.logs.discard' => 'Descarta',
			'home.logs.sheet.callsigns' => 'Indicatius d\'estació',
			'home.logs.sheet.groupBy' => 'Agrupa per',
			'home.logs.sheet.period' => 'Període',
			'home.logs.groupBy.none' => 'Sense agrupar',
			'home.logs.groupBy.date' => 'Data',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Continent desconegut',
			'home.logs.groupBy.unknownEntity' => 'Entitat desconeguda',
			'home.logs.groupBy.unknownDate' => 'Sense data',
			'home.logs.period.thisMonth' => 'Aquest mes',
			'home.logs.period.last3Months' => 'Últims 3 mesos',
			'home.logs.period.thisYear' => 'Aquest any',
			'home.logs.period.lastYear' => 'L\'any passat',
			'home.logs.period.allTime' => 'Des de sempre',
			'home.logs.period.custom' => 'Interval personalitzat',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'durant ${span}',
			'home.logs.periodTitle.custom' => 'l\'interval triat',
			'home.logs.columns.date' => 'Data',
			'home.logs.columns.time' => 'Hora',
			'home.logs.columns.freq' => 'Freqüència',
			'home.logs.columns.mode' => 'Mode',
			'home.logs.columns.call' => 'Indicatiu',
			'home.logs.columns.name' => 'Nom',
			'home.logs.columns.station' => 'Estació',
			'home.logs.columns.band' => 'Banda',
			'home.logs.columns.sent' => 'Enviat',
			'home.logs.columns.rcvd' => 'Rebut',
			'home.logs.columns.grid' => 'Graella',
			'home.logs.columns.state' => 'Estat',
			'home.logs.columns.country' => 'País',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'Registre de QSOs',
			'home.logs.panels.qsosDescription' => 'Els QSOs de l\'indicatiu seleccionat, de totes les operacions.',
			'home.logs.panels.info' => 'Informació',
			'home.logs.panels.infoDescription' => 'Nombre total de QSOs, o la consulta de l\'indicatiu del QSO seleccionat.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'La ubicació del QSO seleccionat.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicatius: ${calls}',
			'home.logs.import.skippedOne' => 'No s\'ha pogut llegir 1 registre',
			'home.logs.import.skippedOther' => ({required Object count}) => 'No s\'han pogut llegir ${count} registres',
			'home.logs.import.readingTitle' => 'Llegint el fitxer ADIF…',
			'home.logs.import.checkingTitle' => 'Comprovant duplicats…',
			'home.logs.import.importingTitle' => 'Important QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} de ${total} comprovats',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importats, de ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'caçant',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} i ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} i més',
			'chase.station.title' => 'Estació de caça',
			'chase.station.stationLabel' => 'Estació: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Sense ubicació',
			'chase.periodInline.today' => 'avui',
			'chase.periodInline.thisWeek' => 'aquesta setmana',
			'chase.periodInline.last14Days' => 'en els darrers 14 dies',
			'chase.periodInline.thisMonth' => 'aquest mes',
			'chase.periodStats.today' => 'Estadístiques d\'avui',
			'chase.periodStats.thisWeek' => 'Estadístiques d\'aquesta setmana',
			'chase.periodStats.last14Days' => 'Estadístiques dels darrers 14 dies',
			'chase.periodStats.thisMonth' => 'Estadístiques d\'aquest mes',
			'chase.period.today' => 'Avui',
			'chase.period.thisWeek' => 'Aquesta setmana',
			'chase.period.last14Days' => 'Darrers 14 dies',
			'chase.period.thisMonth' => 'Aquest mes',
			'chase.goals.title' => 'Objectius de caça',
			'chase.goals.remove' => ({required Object name}) => 'Deixa de caçar ${name}',
			'chase.goals.extensionsTitle' => 'Més programes de caça',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Controls de registre sobre els QSOs caçats en el període.',
			'chase.panels.info' => 'Informació',
			'chase.panels.infoDescription' => 'L\'indicatiu que s\'està registrant, o les estadístiques del període.',
			'chase.panels.spots' => 'Anuncis',
			'chase.panels.spotsDescription' => 'Estacions anunciades a l\'aire, a punt per caçar.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'Els QSOs del període i l\'estació que s\'està registrant.',
			'chase.claims.checking' => 'Comprovant els QSOs per a la caça',
			'chase.claims.rebuilding' => ({required Object program}) => 'Comprovant el registre per a ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} de ${total} QSOs',
			'chase.notice.newRef' => ({required Object program}) => 'Nou ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Probablement nou ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'Banda nova per a ${program}',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Probablement banda nova per a ${program}',
			'chase.notice.newMode' => ({required Object program}) => 'Mode nou per a ${program}',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Probablement mode nou per a ${program}',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} sense confirmar',
			'chase.notice.programGuess' => ({required Object notice}) => 'Probablement ${notice}',
			'chase.alerts.title' => 'Alertes',
			'chase.alerts.newRef' => 'Referència Nova',
			'chase.alerts.newBand' => 'Banda Nova',
			'chase.alerts.newMode' => 'Mode Nou',
			'chase.alerts.unconfirmed' => 'Sense confirmar',
			'chase.checklists' => 'Progrés de la caça',
			'chase.imports.importFrom' => ({required Object label}) => 'Importa ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Importa ${file} com a',
			'chase.imports.dropHint' => 'Deixa anar un fitxer per importar-lo a un programa de caça',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'S\'han importat ${count} entrades de ${program} des de ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'S\'han importat ${count} entrades de ${program} des de ${file}; se n\'han omès ${skipped} que no s\'han pogut llegir',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} no té res que ${program} pugui importar',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} no ha pogut llegir ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} no ha pogut llegir cap dels ${skipped} registres de ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'Cap programa de caça importa ${file}',
			'dialogs.operationDetails' => 'Detalls de l\'operació',
			'dialogs.activities' => 'Activitats',
			'dialogs.stationCallsign' => 'Indicatiu d\'estació',
			'dialogs.advanced' => 'Avançat',
			'dialogs.operatingPosition' => 'Posició d\'operació (multiestació)',
			'dialogs.assistance' => 'Assistència',
			'dialogs.assistanceDescription' => 'Fes servir serveis d\'anuncis i altres fonts d\'informació',
			'dialogs.selfSpotting' => 'Autoanunci',
			'dialogs.selfSpottingDescription' => 'Permet les funcions que publiquen la teva pròpia freqüència',
			'dialogs.disabledByRules' => ({required Object rules}) => 'Desactivat per complir les normes de ${rules}',
			'dialogs.lookupDespiteAssistance.title' => 'Consultar en línia?',
			'dialogs.lookupDespiteAssistance.body' => 'L\'assistència està desactivada en aquesta operació. Consultar tots els QSOs farà servir serveis en línia com QRZ només aquesta vegada.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'L\'assistència està desactivada en aquesta operació per complir les normes de ${rules}. Consultar tots els QSOs farà servir serveis en línia com QRZ només aquesta vegada.',
			'dialogs.lookupDespiteAssistance.action' => 'Consulta en línia',
			'dialogs.notes' => 'Apunts',
			'dialogs.deleteOperationTitle' => 'Esborra l\'operació',
			'dialogs.purgeTestsTitle' => 'Purga les operacions de prova',
			'dialogs.purgeTestsBody' => 'Això esborra permanentment aquestes operacions de prova i els seus QSOs. No es pot desfer.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'A més de ${count} contacte de prova que no pertany a cap operació.', other: 'A més de ${count} contactes de prova que no pertanyen a cap operació.', ), 
			'dialogs.purgeTestsAction' => 'Purga',
			'dialogs.syncAllTitle' => 'Substituir el registre d\'aquest dispositiu?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL fa una còpia de seguretat i esborra ${qsos} d\'aquest dispositiu, i després torna a descarregar el registre del compte des del servidor. La còpia de seguretat es queda a la base de dades d\'aquest dispositiu.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${n} QSO encara no s\'ha sincronitzat — el servidor no l\'ha rebut mai i NO es recuperarà.', other: '${n} QSOs encara no s\'han sincronitzat — el servidor no els ha rebut mai i NO es recuperaran.', ), 
			'dialogs.syncAllAction' => 'Esborra i torna a sincronitzar',
			'dialogs.receivedPurgesTitle' => 'Operacions de prova eliminades en un altre lloc',
			'dialogs.receivedPurgesBody' => 'Aquestes s\'han esborrat com a operacions de prova en un altre dispositiu. Vols eliminar-les també aquí? Això les esborra permanentment juntament amb els seus QSOs, i no es pot desfer.',
			'dialogs.receivedPurgesAction' => 'Elimina',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicatiu invàlid: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicatius invàlids: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} ha operat fins ara. Es registrarà ${typed} per als contactes nous.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'No s\'ha registrat cap operador fins ara. Es registrarà ${typed} per als contactes nous.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Aquesta operació ja té contactes de ${calls}. ${typed} només es registrarà per als nous.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Registra també ${typed} com a operador del contacte ja registrat', other: 'Registra també ${typed} com a operador dels ${count} contactes ja registrats', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Quan s\'utilitzen diverses estacions a l\'aire, no es poden registrar operadors separats',
			'dialogs.callChange.contactsUnreadable' => 'No s\'han pogut llegir els contactes d\'aquesta operació, així que canviar un indicatiu aquí no oferirà actualitzar-los',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'No s\'han pogut actualitzar els contactes ja registrats, així que no s\'ha fet cap canvi: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => 'S\'han actualitzat ${written} de ${planned} contactes — la resta ja no són en aquesta operació',
			'operation.deletedReadOnly' => 'Aquesta operació està esborrada. Restaura-la per registrar o fer canvis.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'ANUNCIS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Rellotge',
			'operation.tabs.weather' => 'Temps',
			'operation.tabs.website' => 'Lloc web',
			'operation.tabs.remoteScreen' => 'Pantalla remota',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Ràdio',
			'operation.tabs.rotator' => 'Rotor',
			'operation.tabs.summaries' => 'Resums de l\'operació',
			'operation.positions.nobodyYet' => 'Encara no hi ha cap altra posició d\'operació que comparteixi aquesta operació.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Una altra posició',
			'operation.positions.thisDevice' => 'La nostra posició d\'operació',
			'operation.positions.nameIn' => ' a ',
			'operation.positions.panelTitle' => 'Posicions',
			'operation.positions.panelDescription' => 'Què està registrant ara mateix cada posició d\'operació que comparteix aquesta operació.',
			'operation.stationCallsignNone' => 'Sense indicatiu d\'estació',
			'operation.titleNone' => 'Sense títol',
			'operation.deleteOperation' => 'Esborra l\'operació',
			'operation.loggingControlsStale' => 'Els camps d\'activitat poden estar desactualitzats — torna a obrir l\'operació per actualitzar-los',
			'operation.locationNone' => 'Sense definir',
			'operation.generalOperation' => 'Operació General',
			'operation.titleFor' => ({required Object value}) => 'per a ${value}',
			'operation.titleAt' => ({required Object value}) => 'a ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Ara ${description}',
			'operation.testOperationSuffix' => 'Prova',
			'operation.menu.showRstFields' => 'Mostra els camps RST',
			'operation.menu.showStateField' => 'Mostra el camp d\'estat',
			'operation.menu.showGridField' => 'Mostra el camp de graella',
			'operation.menu.showDeletedQsos' => 'Mostra els QSOs esborrats',
			'operation.menu.showDeletedOps' => 'Mostra les operacions esborrades',
			'operation.menu.showQsoNumbers' => 'Mostra els números de QSO',
			'operation.menu.lookupAllQsos' => 'Consulta tots els QSOs',
			'operation.menu.loggingSettingsTitle' => 'Configuració de registre',
			'operation.menu.mapSettingsTitle' => 'Configuració del mapa',
			'operation.menu.actionsSection' => 'Accions',
			'operation.layout.title' => 'Afegeix un panell',
			'operation.layout.availableSection' => 'Panells disponibles',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Configuració de ${panel}',
			'operation.layout.panelSettingsAction' => 'Configuració del panell',
			'operation.layout.viewName' => 'Vista d\'operació',
			'operation.layout.viewOptions' => 'Opcions de disposició de la vista',
			'operation.layout.viewTitleBuiltIn' => 'Aquesta vista està integrada a l\'aplicació, i el seu nom també',
			'operation.layout.resetOptions' => 'Restaura els valors per defecte',
			'operation.layout.removePane' => 'Elimina',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Restaurar ${panel} als valors per defecte?',
			'operation.layout.resetPaneConfirmBody' => 'El títol, la capçalera i la mida tornen als valors per defecte. La resta de la disposició es queda com està.',
			'operation.layout.resetViewConfirm' => 'Restaurar aquesta vista a la disposició per defecte?',
			'operation.layout.resetViewConfirmBody' => 'Els panells tornen a la seva disposició per defecte, i les opcions de la vista i de cada panell tornen als valors per defecte.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Configuració de disposició de ${panel}',
			'operation.layout.paneTitle' => 'Títol',
			'operation.layout.paneShowHeader' => 'Mostra la capçalera',
			'operation.layout.paneShowHeaderTabset' => 'Sempre visible mentre aquest panell comparteix un grup — la capçalera és com s\'accedeix als altres',
			'operation.layout.paneInherit' => 'Igual que l\'aplicació',
			'operation.layout.searchHint' => 'Cerca panells',
			'operation.layout.noPanelsMatch' => 'Cap panell coincideix amb la cerca.',
			'operation.layout.nothingToAdd' => 'Aquesta vista ja té tots els panells possibles',
			'operation.layout.addPanel' => ({required Object panel}) => 'Afegeix ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Previsualitza ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Falta l\'extensió "${name}"',
			'operation.layout.missingExtensionEnable' => 'Activa',
			'operation.layout.missingExtensionInstall' => 'Instal·la…',
			'operation.layout.missingExtensionWontRun' => 'Aquesta versió no s\'executarà. Actualitza-la a Configuració › Extensions.',
			'operation.layout.missingExtensionUnavailable' => 'No disponible en aquesta aplicació',
			'operation.layout.missingExtensionNotInCatalog' => 'No és al catàleg',
			'operation.layout.missingExtensionCatalogUnreachable' => 'No s\'ha pogut accedir al catàleg. Torna-ho a provar',
			'operation.layout.missingExtensionFailed' => 'No ha funcionat. Torna-ho a provar',
			'operation.layout.previewUnavailable' => 'No s\'ha pogut mostrar la imatge de previsualització d\'aquest panell.',
			'operation.layout.nestedPaneTitle' => 'Més',
			'operation.layout.layouts.defaultName' => 'Per defecte',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Disposició ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Disposició: ${name}',
			'operation.layout.layouts.menuNew' => 'Nova…',
			'operation.layout.layouts.menuExport' => 'Exporta…',
			'operation.layout.layouts.menuImport' => 'Importa…',
			'operation.layout.layouts.menuTitle' => 'Disposicions',
			'operation.layout.layouts.newTitle' => 'Nova disposició',
			'operation.layout.layouts.editTitle' => 'Edita la disposició',
			'operation.layout.layouts.edit' => 'Edita',
			'operation.layout.layouts.duplicateCurrent' => 'Duplica la disposició actual',
			'operation.layout.layouts.startFromDefault' => 'Comença des de la disposició per defecte',
			'operation.layout.layouts.nameLabel' => 'Nom',
			'operation.layout.layouts.descriptionLabel' => 'Descripció',
			'operation.layout.layouts.create' => 'Crea',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'Desar els canvis a "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'Aquesta disposició té canvis que no has desat.',
			'operation.layout.layouts.discard' => 'Descarta',
			'operation.layout.layouts.deleteTitle' => 'Esborrar aquesta disposició?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'Segur que vols esborrar la disposició "${name}"?',
			'operation.layout.layouts.exportTitle' => 'Exporta la disposició',
			'operation.layout.layouts.exportPick' => 'Panells per exportar',
			'operation.layout.layouts.tabSet' => 'Grup de pestanyes',
			'operation.layout.layouts.exportAction' => 'Exporta',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Disposició desada a ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'No s\'ha pogut exportar la disposició: ${error}',
			'operation.layout.layouts.importTitle' => 'Importa la disposició',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Feta per a la vista ${view}: els panells que només té aquella vista es deixen fora.',
			'operation.layout.layouts.viewHome' => 'Inici',
			'operation.layout.layouts.viewOperation' => 'Operació',
			'operation.layout.layouts.viewLogs' => 'Registres',
			'operation.layout.layouts.viewChase' => 'Caça',
			'operation.layout.layouts.importAsNew' => 'Com a disposició nova',
			'operation.layout.layouts.importReplace' => 'En lloc d\'aquesta disposició',
			'operation.layout.layouts.importAdd' => 'Afegits a aquesta disposició',
			'operation.layout.layouts.importAddHint' => 'Els panells arriben en una columna nova a la dreta.',
			'operation.layout.layouts.importPick' => 'Panells per importar',
			'operation.layout.layouts.importReplaceSettings' => 'Substitueix la configuració dels panells que ja hi ha aquí',
			'operation.layout.layouts.importAction' => 'Importa',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} no és una disposició que aquesta aplicació pugui llegir: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'el text no és YAML vàlid (línia ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'no és un fitxer de disposició de Ham2K',
			'operation.layout.layouts.problemNewerVersion' => 'l\'ha escrit una versió més nova de l\'aplicació',
			'operation.layout.layouts.problemNoArrangement' => 'no conté cap distribució de panells',
			'operation.layout.layouts.problemMalformed' => 'una part no segueix el format de disposició',
			'operation.layout.layouts.problemTooLarge' => 'és massa gran',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'No s\'ha pogut obrir el fitxer: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'No s\'ha pogut importar la disposició: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'No s\'ha pogut copiar la disposició: ${error}',
			'operation.layout.layouts.importNothing' => 'No s\'ha triat cap panell, així que no s\'ha importat res.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'S\'han deixat fora: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'S\'ha mantingut ${panels}: la distribució per a pantalles petites no en pot prescindir.',
			'operation.layout.layouts.notOffered' => 'No disponible en aquesta vista',
			'operation.layout.layouts.alreadyPlaced' => 'Ja és en aquesta disposició',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Necessita ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'No s\'han pogut llegir els noms de les disposicions',
			'operation.layout.layouts.listRecoveredBody' => 'No s\'ha pogut llegir la llista de disposicions d\'aquesta vista. Totes les disposicions encara hi són, numerades en lloc del nom.',
			'operation.layout.editLayout' => 'Edita la disposició',
			'operation.layout.saveLayout' => 'Desa la disposició',
			'operation.layout.revertLayout' => 'Descarta els canvis de disposició',
			'operation.layout.done' => 'Fet',
			'operation.layout.layoutUnreadableTitle' => 'No s\'ha pogut llegir la disposició',
			'operation.layout.layoutUnreadableBody' => 'No s\'ha pogut llegir la disposició desada, així que es mostra la disposició per defecte. No se sobreescriurà l\'original fins que decideixis quedar-te aquesta.',
			'operation.layout.layoutUnreadableAction' => 'Utilitza aquesta disposició',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => 'No s\'ha pogut mostrar ${panel}',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: ha enviat més de ${max} caràcters',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix té més de ${max} elements',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix té més de ${max} nivells d\'imbricació',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => 'No s\'ha pogut mostrar ${panel}: el seu dibuix no és autocontingut',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva escena té més de ${max} capes',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva escena té més de ${max} controls',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: una part de la seva escena té més de ${max} entrades',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: una cadena de l\'escena té més de ${max} caràcters',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => 'No s\'ha pogut mostrar ${panel}: la seva disposició té més de ${max} nivells d\'imbricació',
			'operation.layout.panelRenderRetry' => 'Torna-ho a provar',
			'operation.layout.panelActionFailed' => 'L\'acció del panell ha fallat. Torna-ho a provar.',
			'operation.layout.panels.loggingDescription' => 'El registre i els camps d\'entrada',
			'operation.layout.panels.infoDescription' => 'El que sabem de l\'estació amb qui contactem',
			'operation.layout.panels.spotsDescription' => 'Anuncis dels clústers i dels programes d\'activitats',
			'operation.layout.panels.mapDescription' => 'On són els contactes',
			'operation.layout.panels.summariesDescription' => 'Les estadístiques i puntuacions de l\'operació, amb les seccions i l\'ordre que triïs',
			'operation.layout.panels.summariesSections' => 'Seccions i ordre',
			'operation.layout.panels.summariesDays' => 'Cada dia',
			'operation.layout.panels.summariesReset' => 'Mostra-les totes',
			'operation.layout.panels.summariesAllHidden' => 'Totes les seccions estan amagades. Tria les que vols mostrar a la configuració d\'aquest panell.',
			'operation.layout.panels.clockDescription' => 'Un rellotge, en qualsevol fus horari',
			'operation.layout.panels.clockFace' => 'Esfera',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analògic',
			'operation.layout.panels.clockZone' => 'Fus horari',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Aquest dispositiu',
			'operation.layout.panels.clockShowSeconds' => 'Mostra els segons',
			'operation.layout.panels.weatherDescription' => 'Condicions actuals i de les properes vuit hores, allà on operes',
			'operation.layout.panels.weatherUseOperationLocation' => 'Utilitza la ubicació de l\'operació',
			'operation.layout.panels.weatherLocation' => 'Ubicació',
			'operation.layout.panels.weatherLocationDescription' => 'Una graella (FN31pr) o lat,lon. S\'ignora mentre \'Utilitza la ubicació de l\'operació\' està marcat.',
			'operation.layout.panels.weatherNoLocation' => 'No hi ha cap ubicació definida. Dona una ubicació a aquest panell a la seva configuració, o col·loca\'l dins d\'una operació que en tingui.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'No s\'ha pogut llegir la ubicació ${location}. Utilitza una graella com FN31pr, o 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'No s\'ha pogut contactar amb Open-Meteo — sense xarxa? Es tornarà a provar d\'aquí a poc.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo ha respost, però amb res llegible. Es tornarà a provar d\'aquí a poc.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'ràfegues ${speed}',
			'operation.layout.panels.panelAgeNow' => 'ara mateix',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'fa ${count} min', other: 'fa ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'fa ${count} h', other: 'fa ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Desconegut',
			'operation.layout.panels.weatherConditions.sunny' => 'Assolellat',
			'operation.layout.panels.weatherConditions.clear' => 'Serè',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Majoritàriament assolellat',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Majoritàriament serè',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parcialment ennuvolat',
			'operation.layout.panels.weatherConditions.cloudy' => 'Ennuvolat',
			'operation.layout.panels.weatherConditions.foggy' => 'Boira',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Boira gebradora',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Plugim feble',
			'operation.layout.panels.weatherConditions.drizzle' => 'Plugim',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Plugim intens',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Plugim gelant feble',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Plugim gelant',
			'operation.layout.panels.weatherConditions.lightRain' => 'Pluja feble',
			'operation.layout.panels.weatherConditions.rain' => 'Pluja',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Pluja intensa',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Pluja gelant feble',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Pluja gelant',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Neu feble',
			'operation.layout.panels.weatherConditions.snow' => 'Neu',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Neu intensa',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Neu granulada',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Ruixats febles',
			'operation.layout.panels.weatherConditions.showers' => 'Ruixats',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Ruixats intensos',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Ruixats de neu febles',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Ruixats de neu',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Tempesta',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Tempestes febles amb calamarsa',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Tempesta amb calamarsa',
			'operation.layout.panels.websiteDescription' => 'Una pàgina web que triïs, en un panell',
			'operation.layout.panels.websiteUrl' => 'Adreça',
			'operation.layout.panels.websiteRefresh' => 'Refresca',
			'operation.layout.panels.websiteRefreshNever' => 'Mai',
			'operation.layout.panels.websiteRefresh1' => 'Cada minut',
			'operation.layout.panels.websiteRefresh5' => 'Cada 5 minuts',
			'operation.layout.panels.websiteRefresh15' => 'Cada 15 minuts',
			'operation.layout.panels.websiteTitle' => 'Nom del panell',
			'operation.layout.panels.websiteRefreshNow' => 'Refresca ara',
			'operation.layout.panels.websiteNoUrl' => 'Encara no hi ha cap adreça. Obre la configuració d\'aquest panell per triar una pàgina.',
			'operation.layout.panels.websiteBadUrl' => 'Això no sembla una adreça web. Ha de començar per https://',
			'operation.layout.panels.websiteNotHttps' => 'Només es poden mostrar adreces https:// en aquest panell.',
			'operation.layout.panels.websiteUnsupported' => 'En aquest sistema no es poden mostrar pàgines web en un panell.',
			'operation.layout.panels.websiteOpenExternally' => 'Obre al navegador',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'No s\'ha pogut carregar la pàgina: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Una pantalla, aplicació o finestra compartida per un altre dels teus dispositius.',
			'operation.layout.panels.remoteScreenTarget' => 'Pantalla',
			'operation.layout.panels.remoteScreenChoose' => 'Tria una pantalla…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Pantalles compartides',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Cap dels teus dispositius comparteix una pantalla. Activa Comparteix pantalles i finestres a Configuració → Dispositius associats, al dispositiu que vols veure.',
			'operation.layout.panels.remoteScreenUnset' => 'No s\'ha triat cap pantalla. Obre la configuració d\'aquest panell per triar-ne una que comparteixin els teus altres dispositius.',
			'operation.layout.panels.remoteScreenConnecting' => 'Connectant…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Aquest dispositiu no està connectat ara mateix.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Aquest dispositiu ha deixat de compartir aquesta pantalla.',
			'operation.layout.panels.remoteScreenNoListener' => 'Aquest dispositiu no pot acceptar connexions — comprova\'n el tallafoc.',
			'operation.layout.panels.remoteScreenNoLan' => 'Les pantalles només es comparteixen per la xarxa local, no per Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Aquest dispositiu no ha volgut compartir aquesta pantalla.',
			'operation.layout.panels.remoteScreenSettings' => 'Configuració del panell',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajusta la vista',
			'operation.layout.panels.remoteScreenDetail' => 'Detall',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Estàndard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Alt',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Màxim',
			'operation.layout.panels.remoteScreenAdjustDone' => 'D\'acord',
			'operation.layout.panels.remoteScreenZoomIn' => 'Amplia',
			'operation.layout.panels.remoteScreenZoomOut' => 'Redueix',
			'operation.layout.panels.remoteScreenStopped' => 'Aquesta pantalla o finestra ja no es mostra.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Aquest dispositiu no ha pogut capturar aquesta pantalla — potser necessita el permís de Gravació de pantalla.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Aquest dispositiu no ha respost. Potser no té activada la compartició de pantalla.',
			'operation.layout.panels.remoteScreenNoMedia' => 'No s\'ha pogut obrir una connexió per a la imatge. Comprova el tallafoc d\'aquest dispositiu.',
			'operation.layout.panels.solarDescription' => 'Condicions solars i geomagnètiques, amb la propagació banda per banda',
			'operation.layout.panels.solarUnreachable' => 'No s\'ha pogut contactar amb hamqsl.com — sense xarxa? Es tornarà a provar d\'aquí a poc.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com ha respost, però no amb una lectura que puguem fer servir. Es tornarà a provar d\'aquí a poc.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Dia',
			'operation.layout.panels.solarBandNight' => 'Nit',
			'operation.layout.panels.solarBandGood' => 'Bona',
			'operation.layout.panels.solarBandFair' => 'Regular',
			'operation.layout.panels.solarBandPoor' => 'Dolenta',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Fonts: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'La connexió té problemes — s\'estan saltant fotogrames.',
			'operation.layout.panels.remoteScreenStalled' => 'Els fotogrames han deixat d\'arribar — potser aquesta connexió és massa lenta.',
			'operation.layout.panels.radioDescription' => 'El panell frontal d\'una ràdio — freqüència, mode i potència, sota control CAT',
			'operation.layout.panels.radioStyle' => 'Estil',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Ràdio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — cap ràdio designada',
			'operation.layout.panels.radioNoRadio' => 'No hi ha cap ràdio per mostrar. Tria\'n una a la configuració d\'aquest panell, o afegeix-ne una a Configuració de l\'estació.',
			'operation.layout.panels.radioNotConfigured' => 'Aquesta ràdio encara no està configurada. Tria\'n el port o l\'adreça a Configuració de l\'estació.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Ràdio no connectada',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Connecta aquesta ràdio',
			'operation.layout.panels.radioDisconnect' => 'Desconnecta aquesta ràdio',
			'operation.layout.panels.radioStale' => 'SENSE DADES',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'ROE',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'ROE alta',
			'operation.layout.panels.rotatorDescription' => 'Cap a on apunta l\'antena, en un mapa centrat a l\'estació. Toca el mapa per girar-la.',
			'operation.layout.panels.rotatorRotator' => 'Rotor',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => 'Automàtic — ${name}',
			'operation.layout.panels.rotatorAutoNone' => 'Automàtic — encara no hi ha cap rotor',
			'operation.layout.panels.rotatorBeamWidth' => 'Amplada del feix',
			'operation.layout.panels.rotatorBeamWidthDescription' => 'En graus, dibuixada al voltant del rumb. 0 no en dibuixa cap.',
			'operation.layout.panels.rotatorLocation' => 'Ubicació',
			'operation.layout.panels.rotatorLocationDescription' => 'Una graella, o una latitud i longitud, per centrar-hi el mapa. En blanc, es fa servir la ubicació de l\'operació.',
			'operation.layout.panels.rotatorTheme' => 'Tema',
			'operation.layout.panels.rotatorThemeColor' => 'Color',
			'operation.layout.panels.rotatorThemeGray' => 'Gris',
			'operation.layout.panels.rotatorThemeMuted' => 'Apagat',
			'operation.layout.panels.rotatorGrayline' => 'Mostra la línia grisa',
			'operation.layout.panels.rotatorNoRotator' => 'No hi ha cap rotor per mostrar. Tria\'n un a la configuració d\'aquest panell, o afegeix-ne un a Configuració de l\'estació.',
			'operation.layout.panels.rotatorNoLocation' => 'No hi ha cap ubicació on centrar el mapa. Defineix-ne una a la configuració d\'aquest panell.',
			'operation.layout.panels.rotatorDisconnected' => 'desconnectat',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => 'no respon',
			'operation.layout.panels.rotatorLocationInvalid' => 'No es pot llegir la ubicació de la configuració d\'aquest panell. Fes servir una graella, o una latitud i longitud com 40.7, -74.0.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '${degrees}° el',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'O',
			'operation.layout.htmlPanelUnsupported' => 'Aquest panell necessita una vista web, que aquesta plataforma no ofereix',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Aquest panell necessita un entorn aïllat que la versió web no pot oferir',
			'operation.export.title' => 'Exportacions de l\'operació',
			'operation.export.syncedOperation' => 'L\'operació està sincronitzada',
			'operation.export.unsyncedOperation' => 'L\'operació té canvis sense sincronitzar',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} QSO en aquesta operació', other: '${count} QSOs en aquesta operació', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Els ${total} QSOs estan sincronitzats',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} de ${total} QSOs pendents de sincronitzar',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcadors d\'esdeveniment sincronitzats',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} de ${total} marcadors d\'esdeveniment pendents',
			'operation.export.loading' => 'Carregant les opcions d\'exportació…',
			'operation.export.noOptions' => 'No hi ha formats d\'exportació disponibles (les extensions encara s\'estan iniciant?)',
			'operation.export.nothingLogged' => 'Encara no hi ha res per exportar — aquesta operació no té QSOs.',
			'operation.export.share' => 'Comparteix',
			'operation.export.nothingSelected' => 'No hi ha res seleccionat',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Desa ${count} fitxer', other: 'Desa ${count} fitxers', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Comparteix ${count} fitxer', other: 'Comparteix ${count} fitxers', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Exporta ${count} fitxer', other: 'Exporta ${count} fitxers', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Descarrega ${count} fitxer', other: 'Descarrega ${count} fitxers', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Desa ${count} fitxer combinat', other: 'Desa ${count} fitxers combinats', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Comparteix ${count} fitxer combinat', other: 'Comparteix ${count} fitxers combinats', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Exporta ${count} fitxer combinat', other: 'Exporta ${count} fitxers combinats', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Descarrega ${count} fitxer combinat', other: 'Descarrega ${count} fitxers combinats', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Desa ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Comparteix ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exporta ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Descarrega ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Desa ${count} fitxer a l\'Stash', other: 'Desa ${count} fitxers a l\'Stash', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Desa ${count} fitxer combinat a l\'Stash', other: 'Desa ${count} fitxers combinats a l\'Stash', ), 
			'operation.export.settingsButton' => 'Configuració d\'exportació',
			'operation.export.settingsTitle' => 'Configuració d\'exportació',
			'operation.export.compactFileNames.title' => 'Utilitza noms de fitxer compactes',
			'operation.export.compactFileNames.descriptionOn' => 'Noms curts pensats per als pujadors, com N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Noms llegibles, com 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Inclou informació privada',
			'operation.export.includePrivateData.descriptionOn' => 'S\'inclouen noms, adreces, correus electrònics, graelles i notes',
			'operation.export.includePrivateData.descriptionOff' => 'S\'exclouen noms, adreces, correus electrònics, graelles i notes',
			'operation.export.includePrivateData.note' => 'L\'exportació ADIF completa sempre ho inclou tot',
			'operation.export.resultTitle' => 'Exportació completada',
			'operation.export.resultFailedTitle' => 'L\'exportació ha fallat',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha exportat ${count} fitxer a ${path}', other: 'S\'han exportat ${count} fitxers a ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha exportat ${count} fitxer: ${path}', other: 'S\'han exportat ${count} fitxers: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha compartit ${count} fitxer', other: 'S\'han compartit ${count} fitxers', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha descarregat ${count} fitxer', other: 'S\'han descarregat ${count} fitxers', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'L\'exportació ha fallat: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Afegeix primer una adreça de correu electrònic',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash envia els teus fitxers a l\'adreça de correu electrònic del teu compte LoFi, i hi inicies sessió amb ella a stash.ham2k.net. El teu compte encara no en té cap de confirmada — afegeix-la a Configuració › Sincronització al núvol.',
			'operation.export.stash.openSyncSettings' => 'Obre Sincronització al núvol',
			'operation.export.stash.replaceTitle' => 'L\'Stash recent se substituirà',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Vas enviar “${name}” fa menys de 6 hores i encara no s\'ha descarregat. Els comptes gratuïts només conserven un element a l\'Stash alhora, així que si l\'envies ara el substituiràs.',
			'operation.export.stash.replaceConfirm' => 'Envia igualment',
			'operation.export.stash.failedTitle' => 'No s\'ha pogut enviar a Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'S\'ha enviat a Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Pots recuperar aquest fitxer visitant **[stash.ham2k.net](https://stash.ham2k.net)** des de qualsevol navegador.', other: 'Pots recuperar aquests fitxers visitant **[stash.ham2k.net](https://stash.ham2k.net)** des de qualsevol navegador.', ), 
			'operation.export.stash.mayHaveArrived' => 'L\'Stash no ha respost — potser el fitxer ha arribat igualment. Comprova stash.ham2k.net abans de tornar-lo a enviar',
			'operation.export.stash.notSent' => 'no enviat',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Aquest fitxer no ha arribat:', other: 'Aquests ${count} fitxers no han arribat:', ), 
			'operation.export.stash.emailOffer' => 'O, per a la teva comoditat, et podem enviar un correu electrònic amb un enllaç directe.',
			'operation.export.stash.emailMe' => 'Envia\'m un enllaç per correu electrònic',
			'operation.export.stash.emailSent' => 'T\'hem enviat un enllaç de descàrrega per correu electrònic.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'No s\'ha pogut enviar el correu electrònic: ${error}',
			'operation.export.stash.freeTier' => 'Els comptes gratuïts només poden conservar un element a l\'Stash alhora. Els subscriptors en poden conservar tants com vulguin.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha enviat ${count} fitxer a Ham2K File Stash (stash.ham2k.net)', other: 'S\'han enviat ${count} fitxers a Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Cap anunci coincideix amb els filtres',
			'operation.spots.error' => ({required Object error}) => 'No s\'han pogut carregar els anuncis: ${error}',
			'operation.spots.unknownBand' => 'Altres',
			'operation.spots.auto' => 'Automàtic',
			'operation.spots.autoValue' => ({required Object value}) => 'Automàtic (Actualment ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Qualsevol',
			'operation.spots.allBands' => 'Totes les bandes',
			'operation.spots.allModes' => 'Tots els modes',
			'operation.spots.phoneAndCw' => 'Fonia i CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} anunci', other: '${count} anuncis', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Mostrant ${count} de ${total} anuncis',
			'operation.spots.spotsDisabled' => 'Anuncis desactivats en aquesta operació',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minuts',
			'operation.spots.callsOfNote' => 'Indicatius destacats',
			'operation.spots.yourSpots' => 'Els teus anuncis',
			'operation.spots.allSpots' => 'Tots els anuncis',
			'operation.spots.continents.af' => 'Àfrica',
			'operation.spots.continents.as' => 'Àsia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Amèrica del Nord',
			'operation.spots.continents.oc' => 'Oceania',
			'operation.spots.continents.sa' => 'Amèrica del Sud',
			'operation.spots.continents.an' => 'Antàrtida',
			'operation.spots.filters.title' => 'Filtra els anuncis',
			'operation.spots.filters.band' => 'Banda',
			'operation.spots.filters.mode' => 'Mode',
			'operation.spots.filters.age' => 'Antiguitat',
			'operation.spots.filters.sources' => 'Fonts',
			'operation.spots.filters.continent' => 'Continent',
			'operation.spots.filters.sorting' => 'Ordenació',
			'operation.spots.filters.sortByTime' => 'Per hora de l\'anunci',
			'operation.spots.filters.sortByFrequency' => 'Per freqüència',
			'operation.spots.filters.sortByWanted' => 'Més buscats',
			'operation.spots.filters.groupByBand' => 'Agrupa per banda',
			'operation.spots.filters.groupCallsWithNotes' => 'Agrupa indicatius amb notes',
			'operation.spots.filters.alertingOnly' => 'Només anuncis amb alertes',
			'operation.spots.filters.sourceNoReply' => 'Sense resposta',
			'operation.spots.filters.sourceError' => 'Error',
			'operation.spots.unavailableTitle' => 'Anuncis no disponibles',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} no ha respost.',
			'operation.spots.failedTitle' => 'Error de la font d\'anuncis',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} ha retornat un error.',
			'operation.spots.slideLogIt' => 'Registra\'l',
			'operation.spots.slideIgnore' => 'Ignora',
			'operation.spots.slideRestore' => 'Restaura',
			'operation.spots.logConflict.title' => 'El panell de registre està ocupat',
			'operation.spots.logConflict.editingBody' => 'Estàs editant un contacte registrat. Vols registrar aquest anunci, o tornar enrere i acabar l\'edició?',
			'operation.spots.logConflict.composingBody' => 'Has començat a introduir un contacte. Vols registrar aquest anunci, o tornar enrere i acabar el que estaves escrivint?',
			'operation.spots.logConflict.goBack' => 'Torna enrere',
			'operation.spots.logConflict.clearAndLog' => 'Neteja i registra l\'anunci',
			'operation.import.title' => 'Importa dades a l\'operació',
			'operation.import.importAdifAction' => 'Importa QSOs des d\'ADIF',
			'operation.import.settingsButton' => 'Configuració d\'escolta',
			'operation.import.settingsTitle' => 'Escolta altres aplicacions',
			'operation.import.protocolAddressLabel' => 'Adreça',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Introdueix un port entre 1 i 65535',
			'operation.import.protocolAddressInvalid' => 'Introdueix una adreça IP vàlida (p. ex. 127.0.0.1 o 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Rebent dades',
			'operation.import.protocolStatusNoData' => 'No s\'han rebut dades recentment',
			'operation.import.protocolBindError' => ({required Object error}) => 'No s\'ha pogut començar a escoltar: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'No s\'han pogut desar els QSOs entrants i s\'està tornant a provar: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Qualsevol (difusió)',
			'operation.import.wsjtxProtocolName' => 'Servidor UDP de WSJT-X',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → pestanya Broadcast Data → marca "Enable Broadcasts" per a la informació de contacte. Posa l\'adreça IP 127.0.0.1 si s\'executa en aquest mateix ordinador, o 255.255.255.255 per difondre a la xarxa local actual.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → pestanya Reporting → secció UDP Server → marca "Accept UDP requests". Posa el servidor UDP a 127.0.0.1 si s\'executa en aquest mateix ordinador, o una adreça multicast com 239.239.0.2, i utilitza la mateixa adreça a la configuració de dalt d\'aquesta aplicació.',
			'operation.import.listenTitle' => 'Escolta QSOs d\'altres aplicacions',
			'operation.import.listenDescriptionOnN1mm' => 'Escoltant N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Escoltant WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Escoltant N1MM+ i WSJT-X',
			'operation.import.listenDescriptionOff' => 'Desactivat',
			'operation.import.addToOperationTitle' => 'Afegeix a aquesta operació',
			'operation.import.addToOperationDescriptionOn' => 'Els QSOs capturats s\'afegeixen a aquesta operació a mesura que arriben',
			'operation.import.addToOperationDescriptionOff' => 'Els QSOs capturats es retenen fins que activis això',
			'operation.import.pendingSectionTitle' => 'QSOs capturats',
			'operation.import.pendingEmpty' => 'Encara no s\'ha capturat res',
			'operation.import.stationMismatch' => ({required Object call}) => 'Registrat com a ${call}, no l\'estació d\'aquesta operació',
			'operation.import.discardAction' => 'Descarta',
			'operation.import.gapDialogTitle' => 'Incloure captures anteriors?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'S\'han capturat ${count} QSOs més abans, abans d\'un buit en les dades. Vols incloure\'ls també?',
			'operation.import.gapDialogRecentOnly' => 'Només els recents',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Inclou-los tots (${count})',
			'map.outlineIssue.link' => 'Problemes?',
			'map.outlineIssue.title' => 'Informa d\'un problema amb un contorn',
			'map.outlineIssue.reference' => 'Quin contorn',
			'map.outlineIssue.severity' => 'Com de greu és?',
			'map.outlineIssue.minor' => 'Detall menor',
			'map.outlineIssue.major' => 'Greu',
			'map.outlineIssue.explanation' => 'Què hi ha de malament?',
			'map.outlineIssue.explanationHint' => 'Què fa malament el contorn, i on',
			'map.outlineIssue.send' => 'Envia',
			'map.outlineIssue.sending' => 'Enviant el teu informe — gràcies',
			'map.outlineIssue.copy' => 'Copia l\'informe',
			'map.outlineIssue.notSent' => 'No s\'ha pogut enviar l\'informe',
			'map.outlineIssue.copied' => 'Informe copiat',
			'map.outlineIssue.notCopied' => 'No s\'ha pogut copiar l\'informe',
			'map.outlinesDisclaimer' => 'Els contorns són només de referència. Fes la teva pròpia recerca!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contorns: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Límits: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Instal·lacions: ${sources}',
			'map.fullCredits' => 'Crèdits complets de les dades',
			'map.fewerCredits' => 'Menys crèdits',
			'map.emptyState' => 'Encara no hi ha ubicacions de QSOs.\nEls QSOs amb graella, estat o país apareixeran aquí.',
			'map.unavailable' => 'El mapa no està disponible ara mateix.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Pla',
			'map.globe' => 'Globus',
			'map.zoomIn' => 'Amplia',
			'map.zoomOut' => 'Redueix',
			'map.resetNorth' => 'Torna a orientar al nord',
			'map.postcard.button' => 'Postal de l\'operació',
			'map.postcard.title' => ({required Object title}) => 'Postal de ${title}',
			'map.postcard.portrait' => 'Vertical',
			'map.postcard.landscape' => 'Horitzontal',
			'map.postcard.square' => 'Quadrada',
			'map.postcard.save' => 'Desa…',
			'map.postcard.download' => 'Descarrega',
			'map.postcard.share' => 'Comparteix',
			'map.postcard.copy' => 'Copia',
			'map.postcard.copied' => 'Copiat al porta-retalls',
			'map.postcard.saved' => ({required Object path}) => 'Desat a ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'S\'ha descarregat ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'S\'han desat ${count} imatges a ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'S\'ha desat ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} ja s\'havia desat',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Descarregant ${count} imatges — permet-les si el navegador ho demana',
			'map.postcard.mapLeftOut' => 'El mapa no s\'ha carregat, així que s\'ha omès',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — el mapa no s\'ha carregat, així que s\'ha omès',
			'map.postcard.continued' => ({required Object title}) => '${title} (continuació)',
			'map.postcard.previousPage' => 'Pàgina anterior',
			'map.postcard.nextPage' => 'Pàgina següent',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Pàgina ${page} de ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} Q', other: '${count} Qs', ), 
			'map.postcard.options' => 'Opcions de la postal',
			'map.postcard.bandLegend' => 'Mostra la llegenda de bandes',
			'map.postcard.grayline' => 'Mostra la línia grisa',
			'map.postcard.sectionsAndOrder' => 'Seccions del resum i ordre',
			'map.postcard.sectionDays' => 'Cada dia',
			'map.postcard.reset' => 'Restableix',
			'map.postcard.failed' => ({required Object error}) => 'No s\'ha pogut fer la postal: ${error}',
			'map.postcard.mapNotReady' => 'El mapa no ha acabat de carregar-se. Comprova la connexió i torna-ho a provar.',
			'map.postcard.saveFailed' => ({required Object error}) => 'No s\'ha pogut desar la postal: ${error}',
			'map.postcard.copyFailed' => 'El porta-retalls no ha acceptat la imatge. Torna-ho a provar.',
			'map.postcard.shareFailed' => 'No s\'ha pogut compartir la postal. Torna-ho a provar.',
			'map.postcard.fileName' => 'postal',
			'mapsView.title' => 'Mapes',
			'mapsView.searchHint' => 'Cerca parcs, cims i més',
			'mapsView.activities' => 'Activitats',
			'mapsView.layers' => 'Capes',
			'mapsView.baseMap' => 'Mapa base',
			'mapsView.satellite' => 'Satèl·lit (Esri)',
			'mapsView.facilities' => 'Instal·lacions dels parcs',
			'mapsView.boundaries' => 'Límits',
			'mapsView.currentLocation' => 'Ubicació actual',
			'mapsView.noMatches' => ({required Object text}) => 'Res coincideix amb “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} referència a ${where}', other: '${count} referències a ${where}', ), 
			'mapsView.startOperation' => 'Inicia una operació amb aquestes referències',
			'activitiesView.title' => 'Activitats',
			'activitiesView.activitiesCountZero' => 'Cap activitat seleccionada',
			'activitiesView.activitiesCountOne' => '1 activitat',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} activitats',
			'activitiesView.empty' => 'Encara no hi ha activitats — fes servir Suggeriments i cerca a sota per afegir-ne una',
			'activitiesView.removeActivity' => 'Elimina',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Obre ${name}',
			'activitiesView.editActivity' => 'Edita l\'activitat',
			'activitiesView.manageExtensions' => 'Gestiona les extensions',
			'activitiesView.manage' => 'Gestiona',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipus d\'activitat: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipus d\'activitat: ${first} i ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipus d\'activitat: ${first}, ${second} i ${more} més',
			'activitiesView.reference' => 'Referència',
			'activitiesView.invalidReference' => 'No vàlida',
			'activitiesView.duplicateReference' => 'Ja afegida',
			'activitiesView.searchHint' => 'Cerca per nom, referència o qualsevol altra cosa…',
			'activitiesView.noSuggestions' => 'Cap coincidència',
			'activitiesView.noSuggestionsHint' => 'Cerca a dalt pel nom o el número de la referència',
			'activitiesView.noSuggestionsExample' => '(per exemple \'trail\' o \'4556\')',
			'activitiesView.allOptions' => 'Tipus d\'activitat',
			'activitiesView.determiningLocation' => 'Determinant la ubicació actual…\nEsperant la posició GPS per trobar referències properes',
			'activitiesView.locationUnavailableTitle' => 'Dades d\'ubicació no disponibles',
			'activitiesView.locationDeniedTitle' => 'Permís d\'ubicació denegat',
			'activitiesView.locationBlockedTitle' => 'Permís d\'ubicació bloquejat',
			'activitiesView.noNearbyReason' => 'No es poden determinar les referències properes',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Toca ${icon} per introduir la teva ubicació manualment,\no simplement cerca referències pel nom',
			'activitiesView.locationGrantAction' => 'Permet l\'accés a la ubicació',
			'activitiesView.locationSettingsAction' => 'Obre la configuració',
			'activitiesView.locationSettingsUnavailable' => 'Permet l\'accés a la ubicació a la configuració del sistema',
			'activitiesView.locationGrantRefused' => 'Encara sense ubicació — el sistema ho ha tornat a denegar',
			'activitiesView.searchUnavailableTitle' => 'Cerca d\'activitats no disponible',
			'activitiesView.searchUnavailableReason' => 'Una extensió d\'activitat no ha pogut respondre la cerca. Torna-ho a provar d\'aquí a un moment.',
			'activitiesView.emptySheet' => 'Fes servir els suggeriments i la cerca a sota per afegir-ne una',
			'activitiesView.exports' => 'Exportacions',
			'activitiesView.exportLogs' => 'Exporta registres',
			'activitiesView.tools' => 'Eines',
			'activitiesView.toolsTitle' => 'Eines de l\'operació',
			'activitiesView.operationDetails' => 'Detalls de l\'operació',
			'activitiesView.share' => 'Comparteix',
			'activitiesView.archive' => 'Arxiva',
			'activitiesView.deleteOperation' => 'Esborra l\'operació',
			'activitiesView.undeleteOperation' => 'Restaura l\'operació',
			'activitiesView.alreadySelected' => 'Ja seleccionada',
			'activitiesView.selected' => 'Seleccionada',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} de ${count}',
			'activitiesView.previousPick' => 'Coincidència anterior',
			'activitiesView.nextPick' => 'Coincidència següent',
			'activitiesView.retiredReference' => 'Retirada',
			'activitiesView.enableExtension' => ({required Object name}) => 'Activa ${name}',
			'activitiesView.enableExtensionHint' => 'Aquesta extensió coincideix amb la cerca, però ara mateix no està activada',
			'activitiesView.enableExtensionForRefHint' => 'Aquesta extensió gestiona una de les referències d\'aquesta operació, però ara mateix no està activada',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} no s\'està executant',
			'activitiesView.extensionNotRunningHint' => 'Aquesta extensió s\'ha desactivat; obre la configuració d\'extensions per a més informació',
			'activitiesView.installExtension' => ({required Object name}) => 'Instal·la ${name}',
			'activitiesView.installExtensionHint' => 'Aquesta extensió coincideix amb la cerca, però no està instal·lada',
			'activitiesView.onlyCatalogMatches' => 'Cap coincidència\nAlgunes extensions del catàleg podrien tenir resultats.\nInstal·la-les a Tipus d\'activitat, a sota.',
			'activitiesView.setupUnavailable' => 'No s\'ha pogut carregar la configuració d\'aquesta activitat — torna-ho a provar des de Gestiona',
			'activitiesView.controlsUnavailableTitle' => 'Controls d\'activitat no disponibles',
			'activitiesView.controlsUnavailableReason' => 'Les teves referències estan segures, però ara mateix no es poden editar.',
			'activitiesView.controlsUnavailableRetry' => 'Torna-ho a provar',
			'activitiesView.onlyDisabledMatches' => 'Cap coincidència\nAlgunes extensions disponibles podrien tenir resultats.\nActiva-les a Tipus d\'activitat, a sota.',
			'activitiesView.onlyNotRunningMatches' => 'Cap coincidència\nAlgunes extensions que podrien tenir resultats no s\'estan executant.\nConsulta Tipus d\'activitat, a sota.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Cerca',
			'activitiesView.addToOperation' => 'Afegeix a l\'operació',
			'activitiesView.addToOperationShort' => 'Afegeix a l\'op.',
			'activitiesView.mapEmptyState' => 'No hi ha resultats per mostrar al mapa',
			'activitiesView.mapEmptyStateHint' => 'Torna a la llista, o cerca una altra cosa',
			'activitiesView.imports' => 'Importacions',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Data',
			'loggingControls.now' => 'Ara',
			'loggingControls.manualTimeSettings' => 'Hora manual',
			'loggingControls.manualTimeIncrement' => 'Increment per QSO',
			'loggingControls.manualTimeIncrementNone' => 'Cap',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} minut', other: '${count} minuts', ), 
			'loggingControls.frequency' => 'Freqüència',
			'loggingControls.mode' => 'Mode',
			'loggingControls.theirCall' => 'El seu indicatiu',
			'loggingControls.noteField' => 'Nota',
			'loggingControls.todoField' => 'Tasca',
			'loggingControls.sent' => 'Enviat',
			'loggingControls.rcvd' => 'Rebut',
			'loggingControls.more' => 'Més',
			'loggingControls.revert' => 'Desfés',
			'loggingControls.undoDelete' => 'Desfés l\'esborrat',
			'loggingControls.restore' => 'Restaura',
			'loggingControls.wipe' => 'Neteja',
			'loggingControls.undo' => 'Desfés',
			'loggingControls.pendingDeleteTapWarning' => 'Toca la paperera un cop més per esborrar aquest QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Fes clic a la paperera un cop més per esborrar aquest QSO',
			'loggingControls.deletedQsoWarning' => 'QSO esborrat',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Toca la paperera un cop més per esborrar aquest ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Fes clic a la paperera un cop més per esborrar aquest ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} esborrat',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Ràdio',
			'loggingControls.powerControl' => 'Potència',
			'loggingControls.notesControl' => 'Apunts',
			'loggingControls.power' => 'Potència',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controls de registre',
			'loggingControls.spottingControl' => 'Anunci',
			'loggingControls.spottingSelfControl' => 'Autoanunci',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Autoanuncia\'t a ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Anuncia ${call} a ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Massa tard per anunciar ${call}',
			'loggingControls.spotNoFreq' => 'Primer defineix una freqüència per anunciar',
			'loggingControls.selfSpotDisabled' => 'Autoanunci desactivat',
			'loggingControls.spotComment' => 'Comentari',
			'loggingControls.spottingAutoControl' => 'Re-anunci automàtic',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Torna a anunciar cada ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Automàtic d\'aquí a ${time}. Aturar?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto d\'aquí a ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto d\'aquí a ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto d\'aquí a ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Re-anunci automàtic no iniciat: l\'anunci no s\'ha enviat',
			'loggingControls.spotAutoMoved' => 'Re-anunci automàtic no iniciat: la freqüència ha canviat mentre s\'anunciava',
			'loggingControls.spotAutoStopped' => 'Re-anunci automàtic aturat',
			'loggingControls.spotAutoLeftFreq' => 'Re-anunci automàtic aturat: la freqüència ha canviat',
			'loggingControls.spotAutoNoFreq' => 'Re-anunci automàtic aturat: la ràdio no informa de cap freqüència',
			'loggingControls.spotBusy' => 'Encara s\'està enviant un altre anunci',
			'loggingControls.bandOrFreqRequired' => 'Defineix una freqüència o banda abans de registrar',
			'loggingControls.missingBand' => 'Sense banda',
			'loggingControls.missingMode' => 'Sense mode',
			'loggingControls.saveFailed' => ({required Object error}) => 'No s\'ha pogut desar: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => 'No s\'ha pogut esborrar: ${error}',
			'loggingControls.info.noQsos' => 'Cap QSO encara… Som-hi, sortim a l\'aire!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} en ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} des de l\'últim',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h per als últims 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h per als últims 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} fins a',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) fins a',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) fins a',
			'loggingControls.info.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplicat!',
			'loggingControls.info.noticeNewBand' => 'Banda Nova',
			'loggingControls.info.noticeNewMode' => 'Mode Nou',
			'loggingControls.info.noticeNewDXCC' => 'DXCC Nou',
			'loggingControls.info.noticeNewState' => 'Estat Nou',
			'loggingControls.info.noticeNewProvince' => 'Província Nova',
			'loggingControls.info.noticeNewDay' => 'Dia Nou',
			'loggingControls.info.noticeNewRef' => 'Ref. Nova',
			'loggingControls.info.noticeNewMult' => 'Nou Multiplicador',
			'loggingControls.info.noticeNewZone' => 'Zona Nova',
			'loggingControls.info.noticeInvalidMode' => 'Mode Incorrecte',
			'loggingControls.info.noticeInvalidBand' => 'Banda Incorrecta',
			'loggingControls.info.noticeInvalidCategory' => 'No Treballable',
			'loggingControls.info.noticeOverTime' => 'Fora de Temps',
			'loggingControls.info.noticeWorkedBefore' => 'Ja Treballat',
			'loggingControls.info.noticeNewPark' => 'Parc Nou',
			'loggingControls.info.noticeNewSection' => 'Secció Nova',
			'loggingControls.info.noticeBonusStation' => 'Estació Bonus!',
			'loggingControls.info.noticeMissingExchange' => 'Sense Intercanvi',
			'loggingControls.info.noticeInvalidExchange' => 'Intercanvi Erroni',
			'loggingControls.info.noticeUnknownEvent' => 'Esdeveniment Desconegut',
			'loggingControls.info.noticeIncompleteCall' => 'Indicatiu Incomplet — No Puntua',
			'loggingControls.info.noticeOurGrid' => 'Defineix la nostra graella',
			'loggingControls.info.noticeRareCounty' => 'Comtat rar!',
			'loggingControls.info.noticeOurLocation' => 'Defineix el nostre comtat',
			'loggingControls.info.noticeShortGrid' => 'Graella massa curta',
			'formChrome.untitled' => '(sense títol)',
			'formChrome.showMore' => 'Mostra\'n més',
			'formChrome.showAll' => 'Mostra-ho tot',
			'formChrome.showFewer' => 'Mostra\'n menys',
			'formChrome.defaults' => 'Valors per defecte',
			'formChrome.search' => 'Cerca',
			'formChrome.clear' => 'Neteja',
			'formChrome.openPage' => 'Obre la pàgina',
			'formChrome.connected' => 'Connectat',
			'formChrome.notConnected' => 'No connectat',
			'formChrome.manage' => 'Gestiona',
			'formChrome.connect' => 'Connecta',
			'formChrome.formTitle' => 'Formulari',
			'formChrome.addItem' => ({required Object label}) => 'Afegeix ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Edita ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Mostrant ${shown} de ${total} (${selected} seleccionats)',
			'formChrome.validationError' => ({required Object error}) => 'Error de validació: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Error de transformació: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Error: ${error}',
			'formChrome.removeItem' => 'Esborra',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'Esborrar ${name}?',
			'formChrome.storageUnavailable' => 'Inicis de sessió no disponibles',
			'qsoEditForm.title' => 'Edita el QSO',
			'qsoEditForm.operatorCall' => 'Operador',
			'qsoEditForm.position' => 'Posició',
			'qsoEditForm.theirName' => 'Nom',
			'qsoEditForm.theirGrid' => 'Graella',
			'qsoEditForm.theirState' => 'Estat',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Apunts',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'La seva informació',
			'qsoEditForm.sectionOur' => 'La nostra informació',
			'qsoEditForm.sectionNotes' => 'Apunts',
			'qsoEditForm.theirCity' => 'Ciutat',
			'qsoEditForm.theirCounty' => 'Comtat',
			'qsoEditForm.theirEntity' => 'Entitat',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Secció ARRL',
			'qsoEditForm.theirLat' => 'Latitud',
			'qsoEditForm.theirLon' => 'Longitud',
			'qsoEditForm.theirPower' => 'La seva potència',
			'qsoList.empty' => 'Encara no hi ha QSOs — contacta amb algú!',
			'qsoList.bandOrModeWarning' => 'Assegura\'t que la banda i el mode són correctes',
			'qsoList.today' => 'Avui',
			'qsoList.yesterday' => 'Ahir',
			'qsoList.tomorrow' => 'Demà',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Cerca al registre (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Cerca al registre',
			'qsoList.find.hint' => 'Número de QSO o indicatiu',
			'qsoList.find.noMatches' => 'Cap coincidència',
			'qsoList.find.noOperationQsos' => 'No hi ha QSOs en aquesta operació',
			'qsoList.find.noPeriodQsos' => 'No hi ha QSOs en aquest període',
			'qsoList.find.outsideQsosOne' => '1 QSO fora d\'aquesta operació',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSOs fora d\'aquesta operació',
			'qsoList.find.pastQsosOne' => '1 QSO anterior',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} QSOs anteriors',
			'loggingPanel.stats' => 'Estadístiques de l\'Operació',
			'loggingPanel.scoring' => 'Puntuació',
			'loggingPanel.dxccEntities' => 'Entitats DXCC',
			'loggingPanel.statesWorked' => 'Estats',
			'loggingPanel.provincesWorked' => 'Províncies',
			'loggingPanel.duplicates' => 'Duplicats',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostra la imatge',
			'callInfo.imageUnavailable' => 'Foto no disponible',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Apunts',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} fins a',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) fins a',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) fins a',
			'callInfo.distanceAway' => ({required Object distance}) => 'a ${distance}',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'a ${distance} (${bearing}°)',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'a ${distance} (${bearing}° / ${reverse}°)',
			'callInfo.thisOpCountOne' => '1 QSO en aquesta operació',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs en aquesta operació',
			'callInfo.otherOpsCountOne' => '1 QSO en altres operacions',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs en altres operacions',
			'callInfo.andMore' => ({required Object count}) => '… i ${count} més',
			'callInfo.withCall' => ({required Object call}) => 'amb ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'de ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} en els darrers 7 dies',
			'callInfo.history.today' => ({required Object n}) => '${n} avui',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Configuració',
			'settings.language' => 'Idioma',
			'settings.languageSystem' => ({required Object language}) => 'Segueix la configuració del sistema (${language})',
			'settings.theme.title' => 'Mode del tema',
			'settings.theme.system' => 'Segueix la configuració del sistema',
			'settings.theme.light' => 'Clar',
			'settings.theme.dark' => 'Fosc',
			'settings.themeDescription.system' => 'Seguint la configuració del sistema',
			'settings.themeDescription.light' => 'Sempre en mode clar',
			'settings.themeDescription.dark' => 'Sempre en mode fosc',
			'settings.fontScale' => 'Mida de la lletra',
			'settings.fontScaleOpts.smallestMinusMinus' => 'La més petita--',
			'settings.fontScaleOpts.smallestMinus' => 'La més petita-',
			'settings.fontScaleOpts.smallest' => 'La més petita',
			'settings.fontScaleOpts.smaller' => 'Més petita',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Més gran',
			'settings.fontScaleOpts.largest' => 'La més gran',
			'settings.fontScaleOpts.largestPlus' => 'La més gran+',
			'settings.fontScaleOpts.largestPlusPlus' => 'La més gran++',
			'settings.keepDeviceAwake.title' => 'Mantén el dispositiu despert',
			'settings.keepDeviceAwake.descriptionOn' => 'Es manté despert mentre ets a la vista de registre o hi ha una sincronització en curs',
			'settings.keepDeviceAwake.descriptionOff' => 'Entra en repòs com sempre',
			'settings.layoutDensity' => 'Densitat de la disposició',
			'settings.layoutDensityOpts.auto' => 'Automàtica',
			'settings.layoutDensityOpts.densest' => 'Màxima',
			'settings.layoutDensityOpts.dense' => 'Densa',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Espaiada',
			'settings.layoutDensityOpts.sparsest' => 'Molt espaiada',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'la finestra és massa baixa; s\'utilitza ${effective}',
			'settings.layoutDensityAtLimit' => 'al límit',
			'settings.distanceUnits' => 'Unitats de distància',
			'settings.distanceUnitsOpts.kilometers' => 'Quilòmetres',
			'settings.distanceUnitsOpts.miles' => 'Milles',
			'settings.userInterface' => 'Interfície d\'usuari',
			'settings.logging.title' => 'Registre',
			'settings.logging.leftieMode.title' => 'Mode esquerrà',
			'settings.logging.leftieMode.descriptionOn' => 'S\'utilitza la disposició per a esquerrans',
			'settings.logging.leftieMode.descriptionOff' => 'S\'utilitza la disposició per a dretans',
			'settings.logging.countryFlags.title' => 'Banderes del país',
			'settings.logging.countryFlags.dx' => 'Mostra-les només per als contactes DX',
			'settings.logging.countryFlags.all' => 'Mostra banderes per a tots els contactes',
			'settings.logging.countryFlags.none' => 'No mostris cap bandera',
			'settings.logging.countryFlagsDescription.dx' => 'Es mostren banderes només per als contactes DX',
			'settings.logging.countryFlagsDescription.all' => 'Es mostren banderes per a tots els contactes',
			'settings.logging.countryFlagsDescription.none' => 'No es mostra cap bandera',
			'settings.logging.suggestDefaultOperator.title' => 'Suggereix l\'operador',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'S\'ofereix el teu indicatiu com a operador quan una operació fa servir un indicatiu d\'estació diferent',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'L\'operador es deixa en blanc tret que l\'omplis tu',
			'settings.logging.showBearing.title' => 'Mostra el rumb',
			'settings.logging.showBearing.descriptionOn' => 'Es mostra el rumb estimat cap a l\'estació',
			'settings.logging.showBearing.descriptionOff' => 'No es mostra informació de rumb',
			'settings.logging.showReverseBearing.title' => 'Mostra també el rumb invers',
			'settings.logging.showReverseBearing.descriptionOn' => 'Es mostra també el rumb des de l\'estació, com ara "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Es mostra només el rumb cap a l\'estació',
			'settings.logging.switchSentRcvd.title' => 'Canvia l\'ordre dels informes de senyal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Enviat primer, Rebut segon',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Rebut primer, Enviat segon',
			'settings.logging.jumpAfterRST.title' => 'Salta al camp següent en introduir RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Es passa al camp següent després d\'introduir l\'RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'No es passa automàticament al camp següent',
			'settings.logging.defaultReport.title' => 'Informe per defecte — Fonia',
			'settings.logging.defaultReport.description' => 'S\'utilitza quan Enviat o Rebut es deixen buits en SSB, FM o AM',
			'settings.logging.defaultReportCW.title' => 'Informe per defecte — CW i dades',
			'settings.logging.defaultReportCW.description' => 'S\'utilitza quan Enviat o Rebut es deixen buits en CW, RTTY i altres modes de dades',
			'settings.logging.defaultReportFT8.title' => 'Informe per defecte — FT8 i FT4',
			'settings.logging.defaultReportFT8.description' => 'S\'utilitza quan Enviat o Rebut es deixen buits en els modes FT',
			'settings.logging.numbersRow.title' => 'Fila de números',
			'settings.logging.numbersRow.description' => 'Mostra una fila de tecles numèriques sobre el teclat mentre registres',
			'settings.logging.numbersRowExtra.title' => 'Tecla de barra i punt',
			'settings.logging.numbersRowExtra.description' => 'Afegeix una tecla contextual: “/” per als indicatius, “.” per als números',
			'settings.logging.numbersRowVibrate.title' => 'Vibra en prémer una tecla',
			'settings.logging.numbersRowVibrate.description' => 'Resposta hàptica quan toques una tecla numèrica',
			'settings.logging.bands' => 'Bandes preferides',
			'settings.logging.modes' => 'Modes preferits',
			'settings.catServer.title' => 'Servidor CAT',
			'settings.catServer.description' => 'Permet que altres aplicacions (WSJT-X, programes de registre, etc.) controlin la ràdio a través de Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocol',
			'settings.catServer.protocolOpts.off' => 'Desactivat',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Accés obert',
			'settings.catServer.openAccessOn' => 'Qualsevol ordinador de la xarxa local es pot connectar.',
			'settings.catServer.openAccessOff' => 'Només es poden connectar aplicacions d\'aquest ordinador.',
			'settings.catServer.allowTransmit' => 'Permet que les aplicacions transmetin',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'Les aplicacions poden activar el PTT de la ràdio, fins a ${minutes} minuts seguits.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'Les aplicacions de qualsevol ordinador de la xarxa local poden activar el PTT de la ràdio, fins a ${minutes} minuts seguits.',
			'settings.catServer.allowTransmitOff' => 'Les aplicacions no poden activar el PTT de la ràdio. Fes servir VOX o el seu propi sistema de PTT.',
			'settings.catServer.allowTransmitUnsupported' => 'La ràdio del VFO principal no es pot posar en transmissió des de Ham2K Logger, així que les aplicacions no hi poden transmetre.',
			'settings.catServer.off' => 'Desactivat.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, iniciant…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} al port ${port}. Clients connectats: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} al port ${port}, però no hi ha cap ràdio de VFO principal connectada.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} no pot escoltar al port ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} no pot escoltar al port ${port}: un altre programa l\'està fent servir, sovint el mateix ${protocol}. Tanca aquest programa o tria un altre port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} no pot escoltar al port ${port}: aquest ordinador no ho permet. Tria un port per sobre de 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} ha deixat d\'escoltar al port ${port}. Tornant-ho a provar…',
			'settings.cluster.title' => 'Clúster DX',
			'settings.cluster.description' => 'El servidor on les extensions publiquen i llegeixen anuncis, amb la sessió iniciada com a operador.',
			'settings.cluster.connect' => 'Connecta al clúster',
			'settings.cluster.connectOn' => 'Les extensions es connecten al clúster quan ho necessiten',
			'settings.cluster.connectOff' => 'Res no es connecta al clúster',
			'settings.cluster.console' => 'Mostra la consola',
			'settings.cluster.consoleDescription' => 'El que envia el clúster, i un lloc per escriure ordres',
			'settings.cluster.consoleTitle' => 'Consola del clúster',
			'settings.cluster.consoleConnect' => 'Connecta',
			'settings.cluster.consoleDisconnect' => 'Desconnecta',
			'settings.cluster.consoleCommand' => 'Ordre',
			'settings.cluster.consoleEmpty' => 'Encara no hi ha res. Connecta\'t, o espera que una extensió faci servir el clúster.',
			'settings.cluster.consoleRetry' => ({required Object command}) => 'Enviant de nou: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => 'No enviat: ${command} (${reason})',
			'settings.cluster.server' => 'Servidor del clúster',
			'settings.cluster.selectServer' => 'Selecciona el servidor',
			'settings.cluster.serverOther' => 'Altres',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'Encara no s\'ha introduït cap servidor, així que els anuncis van a ${node}',
			'settings.cluster.customHost' => 'Servidor',
			'settings.cluster.customPort' => 'Port',
			'settings.cluster.password' => 'Contrasenya',
			'settings.cluster.passwordDescription' => 'Només si cal',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Contrasenya desada per a ${node}',
			'settings.cluster.scrollback' => 'Línies conservades',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} línies',
			'settings.cluster.connection' => 'Connexió',
			'settings.cluster.statusIdle' => 'No connectat. Es connecta quan una extensió ho necessita. Toca per provar.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Connectant a ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Connectat a ${node} com a ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'No s\'ha pogut connectar a ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'No disponible a la versió web.',
			'settings.cluster.statusOff' => 'Desactivat. Activa Connecta al clúster per fer-lo servir.',
			'settings.cluster.errors.noCall' => 'no hi ha cap indicatiu d\'operador per iniciar sessió',
			'settings.cluster.errors.connectFailed' => 'no s\'ha pogut contactar amb el node',
			'settings.cluster.errors.needsPassword' => 'el node demana una contrasenya, i no n\'hi ha cap de desada',
			'settings.cluster.errors.loginFailed' => 'el node no ha acceptat l\'inici de sessió',
			'settings.cluster.errors.disconnected' => 'el node ha tancat la connexió',
			'settings.cluster.errors.timeout' => 'el node no ha respost',
			'settings.cluster.errors.off' => 'Connecta al clúster està desactivat',
			'settings.spotting.title' => 'Anuncis',
			'settings.spotting.respotInterval' => 'Re-anunci automàtic cada',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Re-anunci automàtic per defecte',
			'settings.spotting.autoRespotByDefaultOn' => 'Activa el re-anunci automàtic després de publicar qualsevol anunci',
			'settings.spotting.autoRespotByDefaultOff' => 'Cal una acció de l\'usuari per activar el re-anunci automàtic',
			'settings.spotting.pulseBeforeRespot' => 'Pulsació abans de cada re-anunci automàtic',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'El xip d\'Anunci fa pulsacions blaves durant els ${seconds} segons previs a cada re-anunci',
			'settings.spotting.pulseBeforeRespotOff' => 'Sense pulsacions abans d\'un re-anunci automàtic',
			'settings.radio.title' => 'Control CAT',
			'settings.radio.loggingAndCat' => 'Registre i CAT',
			'settings.radio.tuningSection' => 'Sintonia',
			'settings.radio.keyerSection' => 'Manipulador',
			'settings.radio.servicesSection' => 'Serveis',
			'settings.radio.stationConfigurationSection' => 'Configuració de l\'estació',
			'settings.radio.moreSettings' => 'Més opcions de configuració de l\'estació',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controla el PTT amb el teclat',
			'settings.radio.pttKey.modes.off' => 'No',
			'settings.radio.pttKey.modes.toggle' => 'Commuta',
			'settings.radio.pttKey.modes.hold' => 'Mantén',
			'settings.radio.pttKey.descriptions.off' => 'El teclat no posa la ràdio en transmissió.',
			'settings.radio.pttKey.descriptions.toggle' => 'En modes de fonia, la tecla PTT posa la ràdio en transmissió i tornar-la a prémer la treu. Es desactiva sola al cap d\'un minut.',
			'settings.radio.pttKey.descriptions.hold' => 'En modes de fonia, la ràdio transmet mentre la tecla PTT es manté premuda, fins a un minut.',
			'settings.radio.pttKey.key' => 'Tecla PTT',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Transmetent',
			'settings.radio.smartVfoSnap.title' => 'Ajust intel·ligent del VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Quan deixes de girar el dial, s\'arrodoneix la freqüència a un pas raonable. Només en modes de veu.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Es queda exactament on l\'has sintonitzat.',
			'settings.radio.snapDebounce.title' => 'Ajust intel·ligent: retard d\'estabilització',
			'settings.radio.snapDebounce.description' => 'Quant de temps s\'ha d\'aturar el dial abans d\'arrodonir la freqüència. Més curt sembla immediat; més llarg deixa marge per a un moviment lent.',
			'settings.radio.snapLongMove.title' => 'Ajust intel·ligent: moviment llarg',
			'settings.radio.snapLongMove.description' => 'Si mous almenys aquesta distància, la freqüència s\'arrodoneix a un kHz sencer, per lentament que hagis acabat.',
			'settings.radio.snapMinMove.title' => 'Ajust intel·ligent: moviment mínim',
			'settings.radio.snapMinMove.description' => 'Si mous menys d\'això, la freqüència no s\'arrodoneix, així la sintonia fina queda intacta.',
			'settings.radio.snapMinSpeed.title' => 'Ajust intel·ligent: moviment més lent',
			'settings.radio.snapMinSpeed.description' => 'Si gires el dial més lentament que això, la freqüència no s\'arrodoneix, tret que sigui un moviment llarg.',
			'settings.radio.enterSends.pillOff' => 'ESM Desact.',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter envia missatges',
			'settings.radio.enterSends.off' => 'Desactivat',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter envia missatges: ${state}. Toca per canviar.',
			'settings.radio.keyerSpeed.title' => 'Velocitat del manipulador',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Missatges del manipulador CW',
			'settings.radio.cwMessages.notSupported' => 'La ràdio actual no admet manipulació CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Missatge ${n}',
			'settings.radio.cwMessages.labelField' => 'Etiqueta',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Etiqueta F${n}',
			'settings.radio.cwMessages.details' => 'Detalls',
			'settings.radio.cwMessages.empty' => '(buit)',
			'settings.radio.cwMessages.sets' => 'Joc de missatges',
			'settings.radio.cwMessages.newSet' => 'Joc nou',
			'settings.radio.cwMessages.renameSet' => 'Canvia el nom del joc',
			'settings.radio.cwMessages.deleteSet' => 'Esborra el joc',
			'settings.radio.cwMessages.newSetName' => 'Nom',
			'settings.radio.cwMessages.setDefault' => 'Per defecte',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Missatges ESM',
			'settings.radio.cwMessages.setSaved' => 'Els meus missatges',
			'settings.radio.cwMessages.repeat' => 'Repeteix el missatge 1',
			'settings.radio.cwMessages.repeatShort' => 'Repeteix M1',
			'settings.radio.cwMessages.cooldown' => 'Pausa abans de repetir',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n} segons',
			'settings.radio.cwMessages.repeatWait' => 'Repetint',
			'settings.radio.cwMessages.keyboard' => 'Escriu per enviar',
			'settings.radio.cwMessages.keyboardField' => 'Escriu per enviar',
			'settings.radio.cwMessages.help' => 'Ajuda',
			'settings.radio.cwMessages.helpTitle' => 'Com escriure missatges CW',
			'settings.radio.cwMessages.helpIntro' => 'Els missatges poden fer servir plantilles amb els valors següents:',
			'settings.radio.cwMessages.helpOpCall' => 'El teu indicatiu',
			'settings.radio.cwMessages.helpQsoCall' => 'El seu indicatiu — en una pila //, l\'indicatiu que es registrarà',
			'settings.radio.cwMessages.helpQsoFullCall' => 'El seu indicatiu, si és un indicatiu vàlid; en blanc si és parcial',
			'settings.radio.cwMessages.helpQsoPartial' => 'Un indicatiu parcial; en blanc si hi ha un indicatiu complet vàlid',
			'settings.radio.cwMessages.helpQsoNextCall' => 'En una pila //, l\'indicatiu que se seleccionarà per registrar a continuació, si és un indicatiu complet vàlid',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'En una pila //, el següent parcial després de registrar el contacte actual',
			'settings.radio.cwMessages.helpQsoName' => 'El seu nom, tal com s\'ha escrit o, si no, de la consulta',
			'settings.radio.cwMessages.helpQsoState' => 'El seu estat, tal com s\'ha escrit o, si no, de la consulta',
			'settings.radio.cwMessages.helpKeyerMsg' => 'El missatge 1 tal com s\'enviaria, dins d\'un altre missatge. Vàlid per als missatges de l\'1 al 8',
			'settings.radio.cwMessages.helpQsoRst' => 'L\'informe que envies',
			'settings.radio.cwMessages.helpQsoSerial' => 'El teu número de sèrie, en un concurs que n\'enviï',
			'settings.radio.cwMessages.helpPad' => 'Omple amb zeros fins a aquest nombre de dígits: 7 s\'envia com 007',
			'settings.radio.cwMessages.helpCut' => 'Números abreujats, T per 0 i N per 9: 599 s\'envia com 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Tria els dígits a abreujar, entre cometes — 0 és T, 1 és A, 5 és E, 9 és N',
			'settings.radio.cwMessages.helpFullExample' => 'Exemple complet:',
			'settings.radio.cwMessages.helpExample' => 'Envia W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Amb Enter envia missatges activat, Enter envia els missatges per la seva tecla de funció, com fa N1MM. El joc Missatges ESM comença amb aquests:',
			'settings.radio.cwMessages.helpEsmCq' => 'En Run, Enter amb el camp d\'indicatiu buit crida CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'El teu intercanvi: després del seu indicatiu en Run, després que responguin en S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Agraïment, un cop registrat el contacte: qso és el contacte tal com s\'ha registrat, next el que ve a continuació',
			'settings.radio.cwMessages.helpEsmMyCall' => 'En S&P, el teu indicatiu per a l\'estació a qui respons',
			'settings.radio.cwMessages.helpEsmHisCall' => 'En Run, el seu indicatiu abans del teu intercanvi',
			'settings.radio.cwMessages.helpEsmAgain' => 'Torna a demanar quan no s\'ha copiat res del seu intercanvi',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 suggerit per a piles //: agraeix, després crida la següent estació de la pila i envia el teu intercanvi, o torna a demanar un parcial (TU KR?); si no en queda cap, només TU',
			'settings.radio.keyerControl.label' => 'Manipulador',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => 'Veu',
			'settings.radio.voiceMessages.title' => 'Missatges del manipulador de fonia',
			'settings.radio.voiceMessages.notSupported' => 'La ràdio actual no admet missatges de fonia',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memòria de veu ${n}',
			'settings.radio.voiceMessages.labelField' => 'Etiqueta',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Etiqueta de la memòria de veu ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Buida',
			'settings.radio.voiceMessages.notMeasured' => 'Durada desconeguda',
			'settings.radio.voiceMessages.playButton' => 'Reprodueix',
			'settings.radio.voiceMessages.recordButton' => 'Grava',
			'settings.radio.voiceMessages.stopButton' => 'Atura',
			'settings.radio.voiceMessages.repeat' => 'Repeteix el missatge 1',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Notes per a ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Aquestes memòries són a la ràdio de ${device}. Els seus noms i durades pertanyen a aquell dispositiu.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Desat a la ràdio, on també el veuen els seus altres clients.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Espera l\'indicador [REC] a la ràdio, després mantén premut el botó PTT i grava el teu missatge. Acaba\'l prement el botó ATURA aquí a l\'aplicació abans de deixar anar el PTT per evitar clics no desitjats.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Espera que l\'indicador [REC] parpellegi almenys quatre vegades, després mantén premut el botó PTT i grava el teu missatge. Acaba\'l prement el botó ATURA aquí a l\'aplicació abans de deixar anar el PTT per evitar clics no desitjats.',
			'settings.radio.voiceMessages.pill' => 'Veu',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Reprodueix la memòria ${n}',
			'settings.radio.voiceMessages.stop' => 'Atura',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Grava la memòria ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Atura la gravació',
			'settings.radio.voiceMessages.playing' => 'Reproduint…',
			'settings.radio.voiceMessages.recording' => 'Gravant…',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Gravant ${label}',
			'settings.radio.voiceMessages.doubtful' => 'L\'ha reproduït la ràdio? Ha informat que estava inactiva immediatament.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Has de gravar les memòries a la mateixa ràdio.',
			'settings.radio.voiceMessages.sets' => 'Joc de missatges',
			'settings.radio.voiceMessages.soundFilesSet' => 'Fitxers de so d\'aquest ordinador',
			'settings.radio.voiceMessages.openFileButton' => 'Obre un fitxer',
			'settings.radio.voiceMessages.newSet' => 'Joc nou',
			'settings.radio.voiceMessages.renameSet' => 'Canvia el nom del joc',
			'settings.radio.voiceMessages.deleteSet' => 'Esborra el joc',
			'settings.radio.voiceMessages.newSetName' => 'Nom',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => 'Esborrar ${name} i les seves gravacions? No es pot desfer.',
			'settings.radio.voiceMessages.output' => 'Envia l\'àudio a',
			'settings.radio.voiceMessages.input' => 'Grava des de',
			'settings.radio.voiceMessages.outputRadio' => 'Envia a la ràdio per la xarxa',
			'settings.radio.voiceMessages.inputDefault' => 'Per defecte del sistema',
			'settings.radio.voiceMessages.pickDevice' => 'Tria un dispositiu de so',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (no connectat)',
			'settings.radio.voiceMessages.lead' => 'Retard en activar el PTT',
			'settings.radio.voiceMessages.tail' => 'Retard en desactivar el PTT',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => 'Escolta',
			'settings.radio.voiceMessages.notRecorded' => 'Sense gravar',
			'settings.radio.voiceMessages.unplayable' => 'No es pot reproduir aquest fitxer',
			'settings.radio.voiceMessages.problemNoOutput' => 'Tria el dispositiu de so que alimenta la ràdio abans de reproduir un missatge.',
			'settings.radio.voiceMessages.problemOutputMissing' => 'El dispositiu de so que alimenta la ràdio no està connectat.',
			'settings.radio.voiceMessages.problemInputMissing' => 'El dispositiu de gravació no està connectat.',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'El dispositiu de so no s\'ha pogut obrir.',
			'settings.radio.voiceMessages.problemNotRecorded' => 'Aquest missatge encara no té cap gravació.',
			'settings.radio.voiceMessages.problemRecordingSilent' => 'No s\'ha sentit res del dispositiu de gravació, així que el missatge s\'ha deixat com estava. Comprova l\'entrada, i que l\'aplicació tingui permís per fer servir el micròfon.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => 'La ràdio no està agafant l\'àudio de l\'aplicació ara mateix. Cal una connexió de xarxa amb la ràdio.',
			'settings.radio.voiceMessages.problemSourceRefused' => 'La ràdio no ha volgut canviar el seu àudio de transmissió a l\'aplicació, així que el missatge s\'ha aturat. Configura la ràdio perquè transmeti l\'àudio de l\'aplicació.',
			'settings.radio.voiceMessages.problemCannotKey' => 'Aquesta ràdio no es pot posar en transmissió per CAT, així que l\'ordinador no hi pot reproduir missatges.',
			'settings.radio.voiceMessages.problemUnplayable' => 'El fitxer d\'aquest missatge no és un fitxer de so que l\'aplicació pugui reproduir. Fes servir un fitxer WAV, FLAC o MP3, o torna\'l a gravar.',
			'settings.radio.voiceMessages.problemRecordingFailed' => 'La gravació s\'ha interromput, així que el missatge s\'ha deixat com estava. Comprova que el dispositiu de gravació continua connectat i que hi ha espai al disc.',
			'settings.radio.voiceMessages.problemFileFailed' => 'La gravació no s\'ha pogut desar al lloc del missatge, així que el missatge s\'ha deixat com estava.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'Aquest missatge necessita paraules que no has gravat: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'La plantilla d\'aquest missatge té un problema: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => 'Els missatges dits amb les teves paraules es reprodueixen dins d\'una operació, on hi ha un contacte per a qui dir-los.',
			'settings.radio.voiceMessages.problemNothingSaid' => 'Aquest missatge no diu res per a aquest contacte.',
			'settings.radio.voiceMessages.templateField' => 'Digues-ho amb les meves paraules',
			'settings.radio.voiceMessages.templateHelp' => 'Deixa-ho buit per reproduir la gravació. Si no, el missatge es diu amb les paraules que has gravat, omplert per a cada contacte, amb aquests valors:',
			'settings.radio.voiceMessages.help' => 'Ajuda',
			'settings.radio.voiceMessages.helpTitle' => 'Dir missatges amb les teves paraules',
			'settings.radio.voiceMessages.helpFullExample' => 'Un missatge complet:',
			'settings.radio.voiceMessages.helpExample' => 'El seu indicatiu, el seu informe i la teva gravació de “QSL?”',
			'settings.radio.voiceMessages.playOnRadio' => 'Reprodueix a la ràdio',
			'settings.radio.voiceMessages.templateHelpCall' => 'El seu indicatiu',
			'settings.radio.voiceMessages.templateHelpReport' => 'L\'informe que li dones',
			'settings.radio.voiceMessages.templateHelpMessage' => 'La gravació del missatge 2, reproduïda tal com es va gravar',
			'settings.radio.voiceMessages.voiced' => 'Dit amb les teves paraules',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => 'Diu: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => 'Encara no gravat: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => 'Obre una operació per veure què dirà.',
			'settings.radio.voiceMessages.wordsDescription' => 'Fes servir la teva pròpia veu per a indicatius, números i més.',
			'settings.radio.voiceWords.title' => 'Gravacions de paraules',
			'settings.radio.voiceWords.callField' => 'Paraules de l\'operador',
			'settings.radio.voiceWords.intro' => 'Grava cada paraula o número tres vegades, seguides i de pressa, tal com ho dius en un indicatiu. Les frases més llargues només es graven una vegada.',
			'settings.radio.voiceWords.recordAll' => 'Grava-ho tot',
			'settings.radio.voiceWords.recordAllGuide' => 'Llegeix cada paraula tres vegades, seguides, i una frase de diverses paraules una vegada, respirant entre línies. Prem Atura després de l\'última.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => 'Digues “${word} ${word} ${word}” i després prem Atura.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => 'Digues “${words}” i després prem Atura.',
			'settings.radio.voiceWords.recorded' => 'Gravada',
			'settings.radio.voiceWords.notRecorded' => 'Sense gravar',
			'settings.radio.voiceWords.addPhrase' => 'Afegeix una frase',
			'settings.radio.voiceWords.phraseField' => 'Frase, tal com l\'escrius en un missatge',
			'settings.radio.voiceWords.deletePhrase' => 'Esborra la frase',
			'settings.radio.voiceWords.tryField' => 'Prova de dir',
			'settings.radio.voiceWords.pauseLetters' => 'Pausa entre lletres',
			'settings.radio.voiceWords.pauseWords' => 'Pausa entre paraules',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => 'Velocitat',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => 'Configuració avançada',
			'settings.radio.voiceWords.splitSilent' => 'No s\'ha sentit res a la gravació.',
			'settings.radio.voiceWords.splitNotThreeTakes' => 'No s\'han trobat tres preses. Digues la paraula tres vegades seguides i torna-ho a provar.',
			'settings.radio.voiceWords.splitLineCount' => 'No s\'han trobat totes les paraules a la lectura. Llegeix cada una tres vegades, respirant entre paraules.',
			'settings.radio.voiceWords.splitLinesTooClose' => 'No s\'han pogut distingir les paraules. Deixa una respiració més llarga entre paraules.',
			'settings.radio.avoidZeroBeat.title' => 'Evita el batement zero als anuncis',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Amb una ràdio connectada, es sintonitza uns quants Hz fora d\'un anunci CW, perquè tothom qui respon no cridi a la mateixa nota.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Es sintonitza exactament a la freqüència anunciada.',
			'settings.radio.zeroBeatRange.title' => 'Batement zero: marge d\'evitació',
			'settings.radio.zeroBeatRange.description' => 'Quant s\'allunya de la freqüència anunciada, a banda i banda. El desplaçament mai és proper a zero — tornaria a ser un batement zero.',
			'settings.help.title' => 'Ajuda i recursos',
			'settings.help.description' => 'Comunitat i suport',
			'settings.help.forums' => 'Fòrums Ham2K',
			'settings.help.forumsDescription' => 'Troba ajuda, envia comentaris i discuteix idees…',
			'settings.help.chat' => 'Xat Ham2K',
			'settings.help.chatDescription' => 'El servidor de Discord per a la nostra comunitat en línia',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Vídeos i transmissions en directe',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Perquè mai tens massa fotos…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Segueix-nos per a notícies i actualitzacions',
			'settings.help.contact' => 'Contacta amb nosaltres',
			'settings.help.contactDescription' => 'help@ham2k.com — però prova primer els Fòrums o el Xat!',
			'settings.exports.title' => 'Exportacions',
			'settings.extensionSections.activities' => 'Activitats',
			'settings.extensionSections.hunting' => 'Caça',
			'settings.extensionSections.contests' => 'Concursos',
			'settings.extensionSections.lookups' => 'Consultes',
			'settings.extensionSections.dashboard' => 'Tauler',
			'settings.map.title' => 'Mapes',
			'settings.map.style.title' => 'Estil del mapa',
			'settings.map.showCallsigns.title' => 'Mostra els indicatius',
			'settings.map.showCallsigns.description' => 'Cada contacte és una píndola amb el seu indicatiu, del color de la seva banda',
			'settings.map.showGrayline.title' => 'Mostra la línia grisa',
			'settings.map.showGrayline.description' => 'Ombreja el costat nocturn de la Terra, amb el crepuscle com a degradat',
			'settings.map.styleOpts.automatic' => 'Automàtic',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacitat',
			'settings.privacy.shareAppData.title' => 'Comparteix dades d\'ús de l\'aplicació',
			'settings.privacy.shareAppData.descriptionOn' => 'Ens ajudes a millorar l\'aplicació compartint dades d\'ús, configuració, fallades i rendiment',
			'settings.privacy.shareAppData.descriptionOff' => 'Es mantenen privades les dades d\'ús de l\'aplicació.\nL\'equip de Ham2K no podrà detectar fallades ni altres incidències.',
			'settings.privacy.shareOpData.title' => 'Comparteix dades d\'operació',
			'settings.privacy.shareOpData.descriptionOn' => 'Es comparteixen algunes dades d\'operació públicament i amb altres usuaris',
			'settings.privacy.shareOpData.descriptionOff' => 'Es mantenen privades les dades d\'operació',
			'settings.privacy.privacyPolicy' => 'Política de privacitat',
			'settings.privacy.termsOfService' => 'Condicions de servei',
			'settings.operatorCall' => 'Indicatiu de l\'operador',
			'settings.sync.title' => 'Sincronització al núvol',
			'settings.sync.moreSettings' => 'Més opcions de sincronització',
			'settings.sync.enable' => 'Activa la sincronització',
			'settings.sync.deviceKey' => 'Clau del dispositiu',
			'settings.peers.title' => 'Dispositius associats',
			'settings.peers.enable' => 'Connecta amb altres dispositius',
			'settings.peers.enableDescription' => 'Permet compartir operacions, registre, CAT i GPS amb altres dispositius per la xarxa local',
			'settings.peers.bleEnable' => 'Connecta per Bluetooth',
			'settings.peers.bleDescription' => 'Utilitza Bluetooth LE per connectar encara que no hi hagi xarxa local',
			'settings.peers.thisDevice' => 'Aquest dispositiu',
			'settings.peers.deviceName' => 'Nom',
			'settings.peers.deviceNameHint' => 'Com veuen aquest dispositiu els altres dispositius',
			'settings.peers.pairedDevices' => 'Dispositius vinculats',
			'settings.peers.noPairedDevices' => 'Encara no hi ha dispositius vinculats. Activa això en un altre dispositiu d\'aquesta xarxa per vincular-los.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'No es poden llegir els teus dispositius vinculats: ${error}',
			'settings.peers.nearby' => 'A prop',
			'settings.peers.connected' => 'Connectat',
			'settings.peers.viaBluetooth' => 'per Bluetooth',
			'settings.peers.connecting' => 'Connectant…',
			'settings.peers.syncing' => 'Sincronitzant…',
			'settings.peers.waitingForThem' => 'Esperant l\'altre dispositiu',
			'settings.peers.notConnected' => 'No connectat',
			'settings.peers.wantsToPair' => 'vol compartir aquesta operació',
			'settings.peers.allow' => 'Permet',
			'settings.peers.link' => 'Vincula',
			'settings.peers.reject' => 'Rebutja',
			'settings.peers.forget' => 'Oblida',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Oblidar ${name}?',
			'settings.peers.forgetBody' => 'Deixarà de sincronitzar-se amb aquest dispositiu. El pots tornar a permetre més endavant, i els contactes ja registrats es conserven.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Vincula amb ${name}',
			'settings.peers.pairBody' => 'Aquest dispositiu és a la teva xarxa local i vol connectar-se.',
			'settings.peers.pairBodyBle' => 'Aquest dispositiu és a prop i vol connectar-se per Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID del dispositiu',
			'settings.peers.pairWarning' => 'Vincula només dispositius que reconeguis. Qualsevol dispositiu d\'aquesta xarxa pot enviar una sol·licitud.',
			'settings.peers.pairWarningBle' => 'Vincula només dispositius que reconeguis. Qualsevol dispositiu proper pot enviar una sol·licitud.',
			'settings.peers.problem' => ({required Object error}) => 'No es pot accedir a la xarxa local: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Connectat a ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'S\'ha perdut la connexió amb ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispositius associats: ${connected} de ${linked} connectats',
			'settings.peers.screenEnable' => 'Comparteix pantalles i finestres',
			'settings.peers.screenDescription' => 'Permet que altres dispositius mostrin pantalles o finestres d\'aquest ordinador',
			'settings.peers.screenSources' => 'Pantalles i finestres',
			'settings.peers.screenRefresh' => 'Actualitza la llista',
			'settings.peers.screenUnsupportedPlatform' => 'Aquest dispositiu no pot compartir la seva pantalla. macOS sí que pot; qualsevol dispositiu pot mostrar-ne una compartida per un altre.',
			'settings.peers.screenUnsupportedVersion' => 'Compartir una pantalla requereix macOS 12.3 o posterior. Aquest dispositiu encara pot mostrar una pantalla compartida per un altre.',
			'settings.peers.screenNeedsPermission' => 'macOS necessita el teu permís per gravar la pantalla abans que aquesta aplicació en pugui compartir una.',
			'settings.peers.screenGrantPermission' => 'Demana permís',
			'settings.peers.screenRelaunchAfterGranting' => 'Permet-ho a Configuració del Sistema, a Privacitat i seguretat → Gravació de pantalla, i després surt i torna a obrir aquesta aplicació: macOS només informa una aplicació del canvi en el següent inici.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Compartició de pantalla: ${error}',
			'settings.peers.screenChooseTitle' => 'Tria què vols compartir',
			'settings.peers.screenChooseButton' => 'Tria què vols compartir…',
			'settings.peers.screenTabScreens' => 'Pantalles',
			'settings.peers.screenTabApps' => 'Aplicacions',
			'settings.peers.screenTabWindows' => 'Finestres',
			'settings.peers.screenTabEmpty' => 'No s\'ha trobat res d\'aquest tipus.',
			'settings.peers.screenSharedSummaryNone' => 'Encara no s\'ha triat res.',
			'settings.peers.screenThisDevice' => 'Aquest dispositiu',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Es mostra a ${devices}',
			'settings.peers.screenSharedToNobody' => 'No es mostra enlloc',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Deixa de compartir ${name}',
			'settings.developerMode' => 'Mode de desenvolupador',
			'settings.syncPanel.configuration' => 'Configuració de sincronització',
			'settings.syncPanel.enableTitle' => 'Sincronitza amb Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Es fa còpia de seguretat del teu registre i se sincronitza entre dispositius',
			'settings.syncPanel.disabledDescription' => 'Desactivat — només es queda en aquest dispositiu',
			'settings.syncPanel.syncing' => 'Sincronitzant',
			'settings.syncPanel.account' => 'Compte',
			'settings.syncPanel.refresh' => 'Refresca',
			'settings.syncPanel.switchAccounts' => 'Canvia de compte',
			'settings.syncPanel.switchAccountsDescription' => 'Vincula aquest dispositiu a un altre compte amb un codi QR o correu electrònic',
			'settings.syncPanel.connectionRequests' => 'Sol·licituds de connexió',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Un dispositiu espera unir-se a aquest compte', other: '${n} dispositius esperen unir-se a aquest compte', ), 
			'settings.syncPanel.accountEmailTitle' => 'Correu electrònic del compte',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'S\'ha enviat la confirmació a ${email}. Obre-hi l\'enllaç per acabar el canvi.',
			'settings.syncPanel.resendConfirmation' => 'Torna a enviar el correu de confirmació',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Esperant ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'S\'ha tornat a enviar a ${email}.',
			'settings.syncPanel.deviceLinked' => 'Aquest dispositiu ara està vinculat a aquest compte.',
			'settings.syncPanel.checking' => 'Comprovant…',
			'settings.syncPanel.notLinked' => 'Encara no vinculat',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Substituir les dades locals?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${n} operació', other: '${n} operacions', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Dades sincronitzades',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Aquest dispositiu: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Pendent de pujar: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Aquest dispositiu: comprovant…',
			'settings.syncPanel.countsServerChecking' => 'Servidor: comprovant…',
			'settings.syncPanel.countsServerUnavailable' => 'Servidor: no disponible',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Això fa una còpia de seguretat i esborra ${operations} i ${qsos} d\'aquest dispositiu, i després descarrega les dades del compte. La còpia de seguretat es queda a la base de dades d\'aquest dispositiu.',
			'settings.syncPanel.replace' => 'Substitueix',
			'settings.syncPanel.pendingBannerTitle' => 'S\'ha detectat un compte nou de Ham2K Log Filer',
			'settings.syncPanel.pendingBannerBody' => 'Conserva les operacions i QSOs existents d\'aquest dispositiu i combina\'ls amb el compte, o substitueix-los per les dades del compte (en tots dos casos es queda una còpia de seguretat en aquest dispositiu).',
			'settings.syncPanel.combine' => 'Combina',
			'settings.syncPanel.authIssueTitle' => 'La sincronització no es pot connectar',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer continua rebutjant aquest dispositiu. Comprova el teu indicatiu a la configuració de sincronització.',
			'settings.syncPanel.openSettings' => 'Obre la configuració de sincronització',
			'settings.accounts.title' => 'Comptes, serveis i fonts de dades',
			'settings.accounts.none' => 'No hi ha extensions actives amb comptes',
			'settings.accounts.notConfigured' => 'No configurat',
			'settings.accounts.connected' => 'Connectat',
			'settings.accounts.cancelLogin' => 'Cancel·la l\'inici de sessió',
			'settings.accounts.openInBrowser' => 'Obre al navegador',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Sessió iniciada com a ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Prem Desa per mantenir aquest compte connectat.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Connectat a ${label}',
			'settings.accounts.connect' => 'Connecta',
			'settings.accounts.disconnect' => 'Desconnecta',
			'settings.accounts.connectedAs' => 'Connectat com a',
			'settings.accounts.test' => 'Prova',
			'settings.accounts.saveFailed' => ({required Object error}) => 'No s\'ha pogut desar: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'No s\'ha pogut iniciar la sessió: ${error}',
			'settings.accounts.lookupFailed' => 'Els comptes no estan disponibles ara mateix — torna-ho a provar d\'aquí a un moment',
			'settings.accounts.browserLoginTitle' => 'Acaba d\'iniciar la sessió al navegador web',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Quan acabis, el navegador intentarà obrir un enllaç que comença per "${prefix}". Probablement l\'escriptori no té res registrat per obrir-lo, així que copia aquest enllaç (de la barra d\'adreces, o de la pàgina d\'error que mostra el navegador) i enganxa\'l aquí.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger no ha pogut obrir el navegador. Copia l\'enllaç d\'inici de sessió de sota i obre\'l tu mateix, i després copia l\'enllaç al qual et porta (comença per "${prefix}") i enganxa\'l aquí.',
			'settings.accounts.copyLoginLink' => 'Copia l\'enllaç d\'inici de sessió',
			'settings.accounts.pastedLinkLabel' => 'Enganxa l\'enllaç aquí',
			'settings.accounts.finishLogin' => 'Acaba l\'inici de sessió',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Aquest no és l\'enllaç d\'inici de sessió — hauria de començar per "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Aquest enllaç pertany a un altre intent d\'inici de sessió. Tanca aquesta pàgina i torna a connectar.',
			'settings.accounts.pastedLinkNoCode' => 'Aquest enllaç no té cap codi d\'inici de sessió. Acaba primer d\'iniciar la sessió i després copia l\'enllaç al qual et porta.',
			'settings.accounts.pastedLinkMalformed' => 'Sembla que aquest enllaç està tallat. Copia\'l sencer i torna\'l a enganxar.',
			'settings.accounts.relayLoginWaiting' => 'Esperant que acabis d\'iniciar la sessió — continuarà automàticament quan ho facis.',
			'settings.accounts.loginNoResponse' => 'Aquest dispositiu encara no ha rebut resposta de l\'inici de sessió. Si ja has acabat al navegador, cancel·la i torna a provar de connectar.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger no ha pogut obrir el navegador automàticament. Utilitza el botó de sota per obrir tu mateix la pàgina d\'inici de sessió.',
			'settings.accounts.relayLoginUnavailable' => 'No s\'ha pogut contactar amb el servidor de sincronització necessari per completar aquest inici de sessió. Comprova la connexió i torna-ho a provar.',
			'settings.accounts.loginIncompleteResponse' => 'Aquest intent d\'inici de sessió no s\'ha completat correctament. Torna a provar de connectar.',
			'settings.accounts.noKeyringTitle' => 'No es poden desar els inicis de sessió dels comptes',
			'settings.accounts.noKeyringText' => 'Ham2K Logger no pot accedir a cap servei de clauer en aquest ordinador, així que els inicis de sessió dels comptes no es poden desar ni llegir — connectar un compte fallarà fins que es resolgui. Instal·la i inicia **gnome-keyring**, **KWallet** o **KeePassXC**, o desbloqueja el clauer que ja tens, i després reinicia. El registre, les exportacions i els fitxers de dades no es veuen afectats; la sincronització del registre es manté desactivada mentrestant.',
			'settings.accounts.noKeyringInline' => 'No es poden desar els inicis de sessió: no es pot accedir al clauer d\'aquest ordinador. Instal·la i inicia gnome-keyring, KWallet o KeePassXC, o desbloqueja el que tens.',
			'settings.accounts.noSecureStorageInline' => 'No es poden desar els inicis de sessió: no es pot accedir a l\'emmagatzematge segur d\'aquest ordinador.',
			'settings.station.title' => 'Configuració de l\'estació i control CAT',
			'settings.station.none' => 'No hi ha cap equip configurat',
			'settings.station.add' => 'Afegeix',
			'settings.station.addTitle' => 'Afegeix equip',
			'settings.station.searchHint' => 'Cerca equips',
			'settings.station.noMatches' => 'Cap equip coincideix',
			'settings.station.detectedEquipment' => 'Equips detectats',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'No es poden escoltar ràdios: ${error}',
			'settings.station.edit' => 'Edita l\'equip',
			'settings.station.name' => 'Nom',
			'settings.station.nameDescription' => 'Com l\'anomenes — "Ràdio esquerra". Opcional.',
			'settings.station.transport' => 'Connexió',
			'settings.station.host' => 'Adreça',
			'settings.station.hostDescription' => 'El nom de l\'amfitrió o l\'adreça IP de la ràdio a la teva xarxa.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Cal una adreça',
			'settings.station.portInvalid' => 'El port ha d\'estar entre 1 i 65535',
			'settings.station.connect' => 'Connecta',
			'settings.station.disconnect' => 'Desconnecta',
			'settings.station.remove' => 'Elimina',
			'settings.station.removeTitle' => ({required Object name}) => 'Eliminar ${name}?',
			'settings.station.removeMessage' => 'Només l\'elimina de l\'aplicació. La configuració de l\'equip es queda com està.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipus d\'equip no reconegut "${typeKey}"',
			'settings.station.report' => 'Informa',
			'settings.station.reportTitle' => 'Informa sobre aquesta ràdio',
			'settings.station.reportIntro' => 'Explica\'ns quina ràdio és realment i com ha anat. El teu informe es converteix en una fitxa que llegeix l\'equip de Ham2K, i el que escriguis sobre com la vas fer funcionar pot acabar ajudant el següent operador amb el mateix equip.',
			'settings.station.reportManufacturer' => 'Fabricant',
			'settings.station.reportManufacturerDescription' => 'Qui la fabrica — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Cal un fabricant',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'El model, tal com l\'anomena la mateixa ràdio — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'Cal un model',
			'settings.station.reportOutcome' => 'Com ha anat?',
			'settings.station.reportOutcomeWorks' => 'Ha funcionat bé',
			'settings.station.reportOutcomeIssues' => 'Ha funcionat, amb problemes',
			'settings.station.reportOutcomeFails' => 'No ha funcionat gens',
			'settings.station.reportOutcomeRequired' => 'Explica\'ns com ha anat',
			'settings.station.reportComments' => 'Comentaris',
			'settings.station.reportCommentsPlaceholder' => 'Què ha funcionat, què no, qualsevol cosa que t\'hagi sorprès.',
			'settings.station.reportHints' => 'Consells de resolució de problemes',
			'settings.station.reportHintsPlaceholder' => 'Vols suggerir alguns consells de resolució de problemes per a altres usuaris?',
			'settings.station.reportSend' => 'Envia l\'informe',
			'settings.station.reportSending' => 'Enviant el teu informe…',
			'settings.station.reportSent' => ({required Object ref}) => 'Gràcies — el teu informe s\'ha registrat com a ${ref}.',
			'settings.station.reportSentNoRef' => 'Gràcies — el teu informe s\'ha enviat.',
			'settings.station.reportFailed' => ({required Object error}) => 'L\'informe no s\'ha enviat: ${error}',
			'settings.station.troubleshootingNotes' => 'Notes de resolució de problemes',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Utilitza com a VFO principal',
			'settings.station.serialPort' => 'Port sèrie',
			'settings.station.serialPortDescription' => 'El port on apareix la interfície CAT de la ràdio.',
			'settings.station.serialPortNone' => 'No s\'ha trobat cap port sèrie',
			'settings.station.serialPortRequired' => 'Tria un port sèrie',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} de ${total}',
			'settings.station.serialPortSuggested' => 'suggerit',
			'settings.station.serialPortJustNow' => 'Connectat fa poc',
			'settings.station.serialPortNoDriver' => 'sense controlador',
			'settings.station.serialDeviceRequest' => 'Afegeix un dispositiu USB…',
			'settings.station.bleDevice' => 'Dispositiu Bluetooth LE',
			'settings.station.bleDeviceDescription' => 'El pont sèrie a través del qual es connecta la teva ràdio, com un LiNK500MP en Mode 4 o un adaptador sèrie BLE.',
			'settings.station.bleScan' => 'Cerca dispositius Bluetooth LE…',
			'settings.station.bleScanNoneFound' => 'No s\'ha trobat cap dispositiu Bluetooth LE. Comprova que el pont està engegat, a prop, i en el seu mode Bluetooth LE (Mode 4 en un LiNK500MP).',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'No s\'ha pogut fer la cerca Bluetooth LE: ${reason}',
			'settings.station.bleOff' => 'El Bluetooth està desactivat.',
			'settings.station.bleDenied' => 'No s\'ha concedit el permís de Bluetooth. Permet-lo a la configuració del sistema i torna-ho a provar.',
			'settings.station.bleUnsupported' => 'Aquest dispositiu no té Bluetooth LE.',
			'settings.station.bleStarting' => 'El Bluetooth encara s\'està iniciant. Torna-ho a provar d\'aquí a un moment.',
			'settings.station.bleConnectFailed' => 'No es pot contactar amb el dispositiu Bluetooth LE. Comprova que està engegat, a prop, i que no està connectat a una altra aplicació.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'Aquest dispositiu Bluetooth LE no té cap servei sèrie que l\'aplicació reconegui. Informa\'n indicant els seus serveis: ${services}',
			'settings.station.baudRate' => 'Velocitat (baud)',
			'settings.station.baudRateDescription' => 'Ha de coincidir amb el menú CAT de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit i cap error.',
			'settings.station.serialRtsHigh' => 'Mantén RTS alt',
			'settings.station.serialRtsHighDescription' => 'Només per a una ràdio que espera RTS abans de respondre, com una Yaesu amb CAT RTS activat. En un Digirig, un SignaLink i la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt transmet.',
			'settings.station.serialDtrHigh' => 'Mantén DTR alt',
			'settings.station.serialDtrHighDescription' => 'Només per a una interfície CAT que s\'alimenta de DTR, com alguns cables RS-232 per a l\'FT-817. En molts cables DTR manipula el CW o el PTT, i mantenir-lo alt transmet.',
			'settings.station.serialUsbDriver' => 'Controlador del xip USB',
			'settings.station.serialUsbDriverDescription' => 'Automàtic reconeix la majoria d\'adaptadors. Tria el xip només per a un que la llista de ports digui que no té controlador — l\'embalatge o una llista de dispositius USB en diu el nom.',
			'settings.station.serialUsbDriverAuto' => 'Automàtic',
			'settings.station.civAddress' => 'Adreça CI-V de la ràdio',
			'settings.station.civAddressDescription' => 'En hexadecimal, tal com es mostra al menú CI-V de la ràdio. L\'IC-705 ve amb A4.',
			'settings.station.civAddressInvalid' => 'Una adreça CI-V té dos dígits hexadecimals, de 01 a FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'De quin slice de la ràdio llegeix i sintonitza aquesta connexió.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Tria un dels slices de la ràdio, de la A a la H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'El slice ${letter} no s\'utilitza en aquesta ràdio — tria\'n un altre, o crea\'l a SmartSDR',
			'settings.station.channelNotInUse' => 'no s\'utilitza',
			'settings.station.channelHeldByUnknown' => 'en ús per un altre programa',
			'settings.station.flexNoSlices' => 'Aquesta ràdio no ha informat de cap slice — comprova que SmartSDR s\'està executant i que aquest client s\'hi pot subscriure',
			'settings.station.spectrumUnsupported' => 'Aquesta ràdio no envia l\'espectre per CAT',
			'settings.station.spectrumRequiresBaud' => 'Requereix CAT a 115200 bps',
			'settings.station.spectrumNoRadio' => 'No hi ha cap ràdio connectada',
			'settings.station.spectrumWaiting' => 'Esperant l\'espectre de la ràdio…',
			'settings.station.spectrumUnavailable' => 'La visualització de l\'espectre no està disponible',
			'settings.station.spectrumNoDaxChannel' => 'Tots els canals DAX IQ d\'aquesta ràdio estan en ús',
			'settings.station.spectrumNoPanadapter' => 'Aquest slice no té panadaptador a la ràdio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'La ràdio ha rebutjat un flux DAX IQ (error ${code})',
			'settings.station.spectrumNoUdp' => 'Les dades d\'espectre de la ràdio no poden arribar a aquest dispositiu',
			'settings.station.spectrumK4Unavailable' => 'No es pot rebre l\'espectre LAN de la K4. Tornant-ho a provar…',
			'settings.station.spectrumK4RemoteUnavailable' => 'No es pot rebre l\'espectre remot de la K4',
			'settings.station.spectrumScopeRefused' => 'La ràdio ha rebutjat les ordres de l\'espectroscopi',
			'settings.station.spectrumOutOfRange' => 'L\'espectroscopi de la ràdio està configurat fora del rang que pot mostrar',
			'settings.station.spectrumBandUnsupported' => 'L\'espectroscopi de la ràdio no es pot mostrar en aquesta banda',
			'settings.station.spectrumSdrNoRadio' => 'Esperant la freqüència de la ràdio vinculada…',
			'settings.station.spectrumSdrNotConnected' => 'L\'SDR no està connectat',
			'settings.station.spectrumSdrNoIf' => 'Defineix la freqüència de FI de la ràdio a la configuració d\'aquest SDR',
			'settings.station.sdrRadio' => 'Mostra l\'espectre de',
			'settings.station.sdrRadioDescription' => 'Una visualització d\'espectre en aquesta ràdio es dibuixa a partir d\'aquest receptor en lloc de l\'espectroscopi de la mateixa ràdio.',
			'settings.station.sdrRadioMain' => 'La ràdio principal',
			'settings.station.sdrTuning' => 'Entrada d\'antena',
			'settings.station.sdrTuningDescription' => 'D\'on ve el senyal del receptor. Amb la seva pròpia antena, se sintonitza sol per seguir la ràdio; a la sortida de FI de la ràdio, es queda a la FI.',
			'settings.station.sdrTuningIndependent' => 'La seva pròpia antena',
			'settings.station.sdrTuningIfTap' => 'La sortida de FI de la ràdio',
			'settings.station.sdrIfHz' => 'Freqüència de FI (Hz)',
			'settings.station.sdrIfHzDescription' => 'Només per a una sortida de FI: la freqüència on es troba el dial de la ràdio a la seva FI, com 68330000 en un FT-817.',
			'settings.station.sdrIfInverted' => 'La FI està invertida',
			'settings.station.sdrGainDb' => 'Guany (dB)',
			'settings.station.sdrGainDbDescription' => 'Deixa-ho en blanc per al guany automàtic del receptor.',
			'settings.station.sdrOffsetHz' => 'Desplaçament de freqüència (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'S\'afegeix a cada freqüència enviada al receptor, per a un convertidor ascendent: 125000000 per a un Ham It Up.',
			'settings.station.sdrPpm' => 'Correcció de freqüència (ppm)',
			'settings.station.rtlDirectSampling' => 'Mostreig directe',
			'settings.station.rtlDirectSamplingDescription' => 'Per a HF en un RTL-SDR V3 sense convertidor ascendent. Un RTL-SDR V4 arriba a HF sense.',
			'settings.station.rtlDirectSamplingOff' => 'Desactivat',
			'settings.station.rtlDirectSamplingI' => 'Branca I',
			'settings.station.rtlDirectSamplingQ' => 'Branca Q',
			'settings.station.rtlTcpNotAServer' => 'Això no és un servidor rtl_tcp',
			'settings.station.rtlTcpNotes' => 'Això es connecta a un **servidor rtl_tcp que executes tu mateix** a l\'ordinador on hi ha endollat el dongle.\n\n- **Inicia\'l** amb `rtl_tcp -a 0.0.0.0` perquè altres màquines hi puguin accedir; a la mateixa màquina, n\'hi ha prou amb `rtl_tcp`.\n- **El port** és el 1234 tret que l\'hagis iniciat amb `-p`.\n- **Un programa alhora:** rtl_tcp serveix un sol client. L\'aplicació només s\'hi connecta mentre es mostra una visualització d\'espectre, i el deixa anar uns segons després de tancar-la.\n- **A Android**, l\'aplicació *SDR driver* executa el mateix servidor al telèfon.',
			'settings.station.rspTcpNotes' => 'Això es connecta a un **servidor rsp_tcp que executes tu mateix** a l\'ordinador on hi ha endollat l\'RSP, amb l\'API de SDRplay instal·lada.\n\n- **Inicia\'l** amb `rsp_tcp -a 0.0.0.0`.\n- **El port** és el 1234 tret que l\'hagis iniciat amb `-p`.\n- **Un programa alhora:** el servidor accepta un sol client. L\'aplicació només s\'hi connecta mentre es mostra una visualització d\'espectre.',
			'settings.station.n3fjpNoRig' => 'N3FJP no té cap interfície de ràdio configurada, així que això segueix el que s\'escriu a N3FJP, no una ràdio',
			'settings.station.winkeyerKeyPort' => 'Sortida de manipulació',
			'settings.station.winkeyerKeyPortDescription' => 'A quina de les dues sortides del manipulador està connectada la ràdio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Utilitza el PTT del manipulador',
			'settings.station.winkeyerPttDescription' => 'Activa la línia PTT a la mateixa sortida, per a un amplificador o una ràdio que ho necessiti. Deixa-ho desactivat per a una ràdio manipulada per la seva presa de manipulador.',
			'settings.station.winkeyerNoAnswer' => 'Cap WinKeyer ha respost en aquest port',
			'settings.station.winkeyerStoppedAnswering' => 'El WinKeyer ha deixat de respondre mentre enviava; el missatge s\'ha descartat',
			'settings.station.icomControlPort' => 'Port de control (UDP)',
			'settings.station.icomControlPortDescription' => 'El Control Port (UDP) de la ràdio — 50001 tret que s\'hagi canviat a la seva configuració de xarxa, o redirigit a un altre.',
			'settings.station.icomSerialPort' => 'Port sèrie (UDP)',
			'settings.station.icomSerialPortDescription' => 'El Serial Port (UDP) de la ràdio — 50002 tret que s\'hagi canviat a la seva configuració de xarxa, o redirigit a un altre.',
			'settings.station.icomPortsDiffer' => 'Els ports de control i sèrie han de ser diferents',
			'settings.station.radioUser' => 'Usuari de la ràdio',
			'settings.station.radioPass' => 'Contrasenya de la ràdio',
			'settings.station.radioLoginDescription' => 'L\'inici de sessió de Network → Remote de la ràdio, no la contrasenya de la WiFi.',
			'settings.station.radioUserRequired' => 'Cal l\'usuari de control remot de la ràdio',
			'settings.station.connectFailedBusy' => 'El dispositiu està en ús',
			'settings.station.connectFailedDenied' => 'Accés denegat',
			'settings.station.connectFailedDevice' => 'No s\'ha trobat el dispositiu',
			'settings.station.connectFailedUnsupported' => 'Cap controlador reconeix el xip d\'aquest adaptador USB. Si saps quin xip és, tria\'l a Controlador del xip USB, a Configuració avançada.',
			'settings.station.connectFailedLines' => 'No s\'han pogut mantenir RTS/DTR com estaven configurats, així que s\'ha tancat el port. Potser un altre programa ha deixat activat el control de flux per maquinari — desconnecta i torna a connectar el cable.',
			'settings.station.connectFailedNetwork' => 'No es troba la ràdio a la xarxa. Comprova\'n l\'adreça i que estigui engegada i accessible.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'El port ${port} d\'aquest dispositiu ja està en ús, i les respostes arriben allà. Tanca qualsevol altra cosa que hi escolti — inclòs un altre node PstRotator — o canvia el port.',
			'settings.station.connectFailedTimeout' => 'La ràdio no ha respost a temps. Comprova que estigui engegada i accessible.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Genèric',
			'settings.station.models.icomGeneric' => 'Icom - Genèric',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Genèric',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Genèric',
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
			'settings.station.models.rigctld' => 'Ràdio controlada via rigctld',
			'settings.station.models.rigctldNodeName' => 'La meva ràdio (via rigctld)',
			'settings.station.models.flrig' => 'Ràdio controlada via flrig',
			'settings.station.models.flrigNodeName' => 'La meva ràdio (via flrig)',
			'settings.station.models.hrd' => 'Ràdio controlada via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'La meva ràdio (via HRD)',
			'settings.station.models.n3fjp' => 'Ràdio controlada via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'La meva ràdio (via N3FJP)',
			'settings.station.models.commander' => 'Ràdio controlada via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'La meva ràdio (via Commander)',
			'settings.station.models.antenna' => 'Antena',
			'settings.station.models.key' => 'Manipulador CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Ràdio genèrica (provisional)',
			'settings.station.models.placeholderRadioNodeName' => 'La meva ràdio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Commutador coaxial Sierra Radio CX-1',
			'settings.station.models.gs232a' => 'Interfície de rotor Yaesu GS-232A',
			'settings.station.models.pstRotator' => 'PstRotator (control UDP)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Xarxa/WiFi',
			'settings.station.transports.secureNetwork' => 'Xarxa/WiFi segura',
			'settings.station.transports.usbSerial' => 'Sèrie USB',
			'settings.station.transports.wifi' => 'Xarxa/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Sèrie Bluetooth',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Provisional',
			'settings.station.troubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.ft891Troubleshooting' => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **CAT RTS desactivat a la ràdio, o Mantén RTS alt activat.** Amb **CAT RTS** activat (menú **05-08** de l\'FT-891), la ràdio es manté en silenci mentre RTS és baix — pot respondre una vegada quan s\'obre el port, i després res. Triar el port USB de la mateixa ràdio activa **Mantén RTS alt** a Configuració avançada. En un Digirig, un SignaLink o la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt posa el transmissor en transmissió: en comptes d\'això, desactiva CAT RTS a la ràdio.\n- **La velocitat ha de coincidir** amb el CAT RATE de la ràdio (menú **05-06**). Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.yaesuBinaryTroubleshooting' => 'Aquesta ràdio parla l\'antic CAT de cinc bytes de Yaesu, i no respon gens quan alguna cosa no està bé. Gairebé sempre és per una d\'aquestes raons:\n\n- **El cable ha de convertir els nivells.** La presa CAT del darrere no és RS-232 ni USB; necessita un CT-62 o un adaptador equivalent. Un cable d\'àudio o de dades normal no funcionarà per a CAT.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio (**#14** en un FT-817, **#19** en un FT-857 o FT-897). Si no coincideix, la ràdio no retorna res, i mai un error.\n- **No deixis mai que res activi RTS o DTR en aquest port.** En la majoria de cables per a aquestes ràdios, aquestes línies són PTT i manipulació. L\'excepció és una interfície antiga alimentada per DTR: per a aquesta, activa **Mantén DTR alt** a Configuració avançada.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquest controlador s\'ha escrit a partir de la taula CAT publicada per Yaesu i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.tenTecTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.tenTecEagleTroubleshooting' => '- **El port USB-B del darrere és l\'enllaç CAT.** La ràdio apareix com un port sèrie USB; a Windows necessita el controlador USB to UART de Ten-Tec, que apareix al Gestor de dispositius com a "USB to UART (COMx)".\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert, i també l\'actualitzador de firmware de Ten-Tec.\n- **Definir l\'amplada del filtre des de l\'aplicació la treu del botó BW** fins que la ràdio s\'apaga i s\'engega de nou. Així és com funciona la ràdio.\n\nAquest controlador s\'ha escrit a partir de la guia de referència del programador de Ten-Tec. Si funciona a mitges, val la pena informar-ne, amb la versió del firmware del menú de la ràdio.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Fes servir un cable sèrie DB-9 directe** al port SERIAL DATA, no un null-modem.\n- **Aquesta entrada manté RTS alt**, perquè l\'Orion fa servir RTS i CTS com a control de flux. En una interfície que activa el PTT des de RTS, com un Digirig, desactiva Mantén RTS alt a Configuració avançada, o la ràdio transmetrà tan bon punt l\'aplicació es connecti.\n- **El CW des de l\'aplicació necessita el manipulador intern de la ràdio activat.** Amb el manipulador desactivat, la ràdio ignora el que envia l\'aplicació.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquest controlador s\'ha escrit a partir de la guia de referència del programador de Ten-Tec i no s\'ha provat amb cap Orion. Si funciona a mitges, val la pena informar-ne, amb la versió del firmware del menú de la ràdio.',
			'settings.station.tenTecNoCw' => 'El firmware d\'aquesta ràdio no accepta CW des de l\'aplicació. Ten-Tec ho va afegir al firmware 1.366 de l\'Orion.',
			'settings.station.tenTecKeyerOff' => 'El manipulador intern de la ràdio està desactivat, així que ignora el CW enviat des de l\'aplicació. Activa el manipulador al menú de la ràdio.',
			'settings.station.guohetecTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.guohetecTroubleshooting' => 'La Q900 té dos protocols CAT, i aquesta entrada utilitza el nadiu en lloc de la imitació de l\'FT-817. Tria aquí **Guohetec Q900**, no un FT-817 — la imitació admet menys ordres, i la ràdio no diu quin està utilitzant.\n\n- **El cable USB-C és l\'enllaç CAT**, i també connecta la targeta de so. La velocitat no hi importa; el port ignora el valor que tingui configurat.\n- **No deixis mai que res activi RTS o DTR en aquest port.** En un cable sèrie, aquestes línies són PTT i manipulació.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Una ràdio de segona generació es comporta diferent** d\'una de primera. Mantén premut Menu i després About: HW 2.0 és la segona generació.\n\nAquest controlador s\'ha escrit a partir del protocol publicat pel fabricant i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.yaesuTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.yaesuTroubleshooting' => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **CAT RTS ha d\'estar en OFF a la ràdio.** Si està activat, la ràdio espera una línia de control que l\'aplicació manté baixa. En un Digirig, un SignaLink o la majoria de cables casolans, aquesta mateixa línia és el PTT, així que activar-la posaria el transmissor en transmissió. Al port USB de la mateixa ràdio, l\'alternativa és **Mantén RTS alt** a Configuració avançada. On és aquest ajust depèn del model (menú **05-08** en un FT-891).\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Els modes segueixen la taula de l\'FT-891.** La majoria de la gamma Yaesu hi coincideix, però una ràdio que numera els modes de manera diferent mostrarà i configurarà el mode equivocat en aquests casos. La freqüència no se\'n veu afectada.',
			'settings.station.ftdx3000Troubleshooting' => '**El menú 037 CAT SELECT ha de ser USB** per a CAT pel port USB de la ràdio; amb RS232C, el CAT és a la presa del darrere.\n\nAquesta entrada s\'ha escrit a partir de la documentació CAT publicada i no s\'ha provat amb cap FTDX3000. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.yaesuRs232Troubleshooting' => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **La presa CAT és RS-232.** Necessita un adaptador USB-sèrie i un cable DB-9 directe — un cable null-modem creua les línies, i la ràdio no rep res.\n- **CAT RTS ha d\'estar en OFF a la ràdio.** Si està activat, la ràdio espera una línia de control que l\'aplicació manté baixa, tret que **Mantén RTS alt** estigui activat a Configuració avançada.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\nAquesta entrada s\'ha escrit a partir de la documentació CAT publicada i no s\'ha provat amb cap d\'aquestes ràdios. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.yaesuUsbTroubleshooting' => 'La ràdio rep ordres però no respon. Gairebé sempre és per una d\'aquestes raons:\n\n- **Utilitza el primer dels dos ports USB de la ràdio.** El CAT normalment és al primer (el port COM **Enhanced** a Windows); el segon (**Standard**) és per a PTT i manipulació. El selector apunta al primer sempre que els pot distingir.\n- **CAT RTS desactivat a la ràdio, o Mantén RTS alt activat.** Amb el menú **CAT RTS** de la ràdio activat, es manté en silenci mentre RTS és baix — pot respondre una vegada quan s\'obre el port, i després res. Triar el port USB de la mateixa ràdio activa **Mantén RTS alt** a Configuració avançada. En un Digirig, un SignaLink o la majoria de cables casolans, RTS és el PTT, i mantenir-lo alt posa el transmissor en transmissió: en comptes d\'això, desactiva CAT RTS a la ràdio.\n- **La velocitat ha de coincidir** amb el menú CAT RATE de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.',
			'settings.station.k4SerialNotes' => 'Connecta la presa USB-B (PC) del darrere de la K4. Tant USB-PC1 com USB-PC2 funcionen per a CAT; tria un port que no s\'utilitzi i fes coincidir el seu ajust Serial USB-PCn: Baud Rate a la ràdio. HaLo hi posa 38400 per defecte; canvia-ho si cal. Una altra aplicació ha d\'utilitzar l\'altre port o Ethernet.\n\nAquesta connexió controla la ràdio i els seus manipuladors; no envia àudio a HaLo.',
			'settings.station.k4TcpNotes' => 'Connecta la presa Ethernet de la K4 a la teva xarxa local. Introdueix el nom de l\'amfitrió o l\'adreça IP i el port CAT 9200. HaLo fa servir el mateix amfitrió al port fix 9201 quan es mostra un panadaptador o una cascada; canviar el port CAT no canvia el port de l\'espectre.\n\nL\'espectre mostra el receptor principal. Els seus controls de zoom, ajust de referència i velocitat només afecten la visualització de HaLo. La transmissió d\'àudio no s\'admet.',
			'settings.station.k4PowerTimeout' => 'No s\'ha canviat la potència de la K4 perquè la ràdio no ha confirmat el seu rang de sortida. Torna-ho a provar.',
			'settings.station.k4RemoteNotes' => 'Activa l\'accés remot a la K4 i introdueix la seva contrasenya de xarxa. Main i Sub comparteixen una sola connexió xifrada per al control de la ràdio i l\'espectre. El port per defecte és el 9204; introdueix el teu port redirigit quan et connectis remotament.\n\nLa reproducció d\'àudio i la transmissió del micròfon no s\'admeten.',
			'settings.station.k4Receiver' => 'Receptor',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Tria Main o Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'Aquest receptor ja està configurat per a aquesta K4',
			'settings.station.k4SubReceiverOff' => 'El receptor Sub de la K4 està apagat',
			'settings.station.k4RemotePasswordRequired' => 'Introdueix la contrasenya de xarxa de la K4 per connectar-te de manera segura.',
			'settings.station.k4RemoteHandshakeFailed' => 'La K4 no ha pogut establir una connexió segura. Comprova la seva contrasenya de xarxa i la configuració d\'accés remot.',
			'settings.station.k4RemoteUnreachable' => 'No s\'ha pogut accedir a la connexió segura de la K4. Comprova l\'adreça, el port i la configuració d\'accés remot.',
			'settings.station.k4PowerRange' => 'La potència de la K4 ha de ser de 0,1–110 W, o de 0,0001–0,01 W quan la sortida de mil·liwatts del transvertidor està activa.',
			'settings.station.elecraftTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.elecraftTroubleshooting' => 'Les ràdios Elecraft parlen CAT de Kenwood, i una KX2 i una KX3 s\'han provat d\'aquesta manera — VFO en tots dos sentits, canvi de mode i batement zero en CW, tot funcionant.\n\nSi la ràdio no respon, gairebé sempre és per una d\'aquestes raons:\n\n- **La velocitat ha de coincidir** amb la configurada a **RS232** al menú de la ràdio. Venen amb 38400. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n\n**Si la freqüència és correcta però el mode no**, explica-ho. Les entrades de la KX2 i la KX3 llegeixen el mode d\'una posició de la resposta d\'estat de la ràdio que hem fixat a partir de les ràdios que hem vist, i un firmware que el posi en un altre lloc només ens arriba a través d\'un informe.\n\nDe la K3 no n\'ha informat ningú, ni en un sentit ni en l\'altre, així que si en fas servir una, explica\'ns què passa. La K4 té la seva pròpia entrada.',
			'settings.station.lab599TroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.lab599Troubleshooting' => 'La gamma TX-500 parla CAT de Kenwood. La freqüència i el mode s\'han provat a través d\'un LiNK500MP; la potència i els mesuradors s\'han escrit a partir de la referència CAT de Lab599, així que informa\'ns del que passi, tant si funciona com si no.\n\n- **La velocitat ha de coincidir** amb l\'ajust CAT de la ràdio, 9600 tret que l\'hagis canviat. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Tria el protocol CAT a la ràdio.** TS-2000 cobreix freqüència, mode i potència. LAB599 també permet que l\'aplicació passi la ràdio a DIG, la vegi transmetre en DIG i en llegeixi la tensió d\'alimentació.\n- **A través d\'un LiNK500MP**, mantén premut el botó del VFO uns tres segons per cedir el control CAT a la interfície.\n- **Posa el LiNK500MP en el mode de la connexió**: Mode 3 per a Bluetooth, Mode 4 per a Bluetooth LE. En qualsevol altre mode, una cerca Bluetooth LE no el troba.\n- **Per Bluetooth**, el LiNK500MP s\'aparella com dos ports sèrie i només un porta el CAT. Si la ràdio es manté en silenci, tria l\'altre.',
			'settings.station.lab599TroubleshootingIos' => 'La gamma TX-500 parla CAT de Kenwood. La freqüència i el mode s\'han provat a través d\'un LiNK500MP; la potència i els mesuradors s\'han escrit a partir de la referència CAT de Lab599, així que informa\'ns del que passi, tant si funciona com si no.\n\n- **Posa el LiNK500MP en Mode 4**, el seu mode Bluetooth LE, abans de cercar-lo. En qualsevol altre mode, un iPhone o iPad no el pot trobar.\n- **Cedeix el control CAT al LiNK500MP**: mantén premut el botó del VFO de la ràdio uns tres segons.\n- **Tria el protocol CAT a la ràdio.** TS-2000 cobreix freqüència, mode i potència. LAB599 també permet que l\'aplicació passi la ràdio a DIG, la vegi transmetre en DIG i en llegeixi la tensió d\'alimentació.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Si la ràdio es connecta però no mostra cap freqüència',
			'settings.station.kenwoodTroubleshooting' => 'Aquest controlador s\'ha provat amb les Kenwood TS-590SG i TS-480, les QRP Labs QMX i QCX-mini, i les Elecraft KX2 i KX3. La resta de la gamma s\'ha escrit a partir de referències CAT publicades, així que informa\'ns del que passi, tant si funciona com si no.\n\nSi la ràdio no respon, gairebé sempre és per una d\'aquestes raons:\n\n- **La velocitat ha de coincidir** amb el menú CAT de la ràdio. Si no coincideix, la ràdio retorna dades sense sentit o res, i mai un error.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.\n- **Algunes ràdios necessiten el CAT activat** al menú abans de respondre.\n- **Les ràdios Kenwood esperen RTS**: el seu port CAT el fa servir com a control de flux, així que Mantén RTS alt (a Configuració avançada) ha d\'estar activat. Una connexió configurada abans que fos activat per defecte pot tenir-lo desactivat. En un Digirig o un altre cable que activa el PTT des de RTS, desactiva\'l, o la ràdio transmetrà.\n\n**Diversos front-ends SDR parlen aquest mateix protocol**, així que val la pena provar aquesta entrada també amb ells; les ràdios Elecraft tenen la seva pròpia entrada, a Elecraft. Si la freqüència és correcta però el mode és erroni o no apareix, aquesta és l\'única part que varia dins la gamma — l\'aplicació el dedueix de la ràdio i, si no, el demana directament, així que potser el mode simplement arriba amb retard.',
			'settings.station.statusConnected' => 'Connectat',
			'settings.station.statusLost' => 'Desconnectat',
			'settings.station.notConfigured' => 'No configurat',
			'settings.station.currentConfiguration' => 'Configuració actual',
			'settings.station.currentTransceiver' => 'Transceptor actual',
			'settings.station.currentTransceivers' => 'Transceptors actuals',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => 'Els missatges s\'encuen en lloc d\'interrompre',
			'settings.station.noRadioBSelected' => 'No s\'ha seleccionat cap Ràdio B',
			'settings.station.radioMode' => 'Mode de la ràdio',
			'settings.station.keyerNotSupported' => 'La ràdio actual no ho admet',
			'settings.station.catControlPreferences' => 'Preferències del control CAT',
			'settings.station.chooseTransceiver' => 'Tria el transceptor',
			'settings.station.configurationSection' => 'Configuració',
			'settings.station.noTransceiverSelected' => 'No hi ha cap transceptor seleccionat',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Utilitza ${name} per al VFO principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, zero: 'Cap transceptor', one: '${count} transceptor', other: '${count} transceptors', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} antena', other: '${count} antenes', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} altre dispositiu', other: '${count} altres dispositius', ), 
			'settings.station.equipmentInventory' => 'Inventari d\'equips',
			'settings.station.equipmentInUse' => 'Controls del transceptor',
			'settings.station.noTransceiver' => 'Cap',
			'settings.station.peerRadioNotAvailable' => 'No disponible',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'A ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} és en un altre dispositiu',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Aquesta ràdio està connectada a ${device}. La seva connexió i configuració es gestionen en aquell dispositiu.',
			'settings.station.antennaInUse' => 'Antena en ús',
			'settings.station.keyInUse' => 'Manipulació CW',
			'settings.station.phoneKeying' => 'Manipulació de fonia',
			'settings.station.phoneKeyingNone' => 'Cap',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => 'Memòries de ${radio}',
			'settings.station.phoneKeyingComputer' => 'Àudio d\'aquest ordinador',
			'settings.station.phoneKeyingOff' => 'La manipulació de fonia està desactivada',
			'settings.station.computerVoiceSettings' => 'Àudio de l\'ordinador',
			'settings.station.cwKeyingOptions' => 'Opcions de manipulació CW',
			'settings.station.noneSelected' => 'Cap',
			'settings.station.moreSettings' => 'Més opcions',
			'settings.station.icomCivTroubleshootingTitle' => 'Si apareixen dos ports sèrie per a la mateixa ràdio',
			'settings.station.icomCivTroubleshooting' => 'Diverses ràdios Icom, entre elles l\'IC-705, presenten **dos** ports sèrie USB alhora (Icom els anomena Port A i Port B), tots dos configurats com a CI-V per defecte. Ni aquesta aplicació ni el sistema operatiu els poden distingir més enllà d\'això: el mateix identificador USB de fabricant/producte simplement apareix dues vegades, de vegades marcat aquí amb un sufix `#2`. **Normalment el correcte és el Port A** — sol ser el primer que mostra el sistema operatiu o el navegador, i quan aquesta aplicació pot distingir els dos ports, el marca com a suggerit. Si les ordres surten i la ràdio no respon mai, prova l\'altre port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Si la ràdio no respon mai',
			'settings.station.civAddressTroubleshooting' => '- **L\'adreça CI-V ha de coincidir** amb el menú de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model, però una ràdio que comparteix un bus CI-V és precisament on es canvia. Una trama enviada a l\'adreça equivocada s\'ignora en silenci, cosa que sembla exactament un cable mort.\n- **La velocitat ha de coincidir** amb el CI-V BAUD RATE de la ràdio (per USB, CI-V USB Baud Rate). Configura la ràdio amb el mateix valor que es mostra aquí, **no Auto**. En Auto, algunes ràdios, entre elles l\'IC-7300, es connecten i deixen de respondre al cap d\'un minut més o menys.\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **L\'adreça CI-V ha de coincidir** amb el menú de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model, però una ràdio que comparteix un bus CI-V és precisament on es canvia. Una trama enviada a l\'adreça equivocada s\'ignora en silenci, cosa que sembla exactament un cable mort.\n${speed}\n- **Potser una altra aplicació té el port ocupat**: WSJT-X, fldigi i rigctld el mantenen obert.',
			'settings.station.icomUsbSpeedFollows' => '- **No hi ha cap velocitat per configurar.** Per USB, aquesta ràdio parla a la velocitat que faci servir l\'ordinador, i aquesta entrada sempre fa servir 115200, la velocitat que necessita l\'espectroscopi.',
			'settings.station.ic7610UsbSpeed' => '- **Posa CI-V USB Baud Rate a 115200**, la velocitat que aquesta entrada sempre fa servir, perquè l\'espectroscopi la necessita — **no Auto**. Una ràdio configurada a qualsevol altra velocitat respon amb silenci.',
			'settings.station.civTransceiveTitle' => 'Si l\'aplicació tarda a seguir la ràdio',
			'settings.station.civTransceive' => 'Si l\'aplicació tarda uns quants segons a mostrar un canvi de freqüència o de mode fet a la ràdio, activa l\'ajust **CI-V Transceive** de la ràdio (a la majoria de models actuals, a SET > Connectors > CI-V). Amb aquest ajust activat, la ràdio informa de cada canvi en el moment en què es produeix. Desactivat, l\'aplicació només veu el canvi la propera vegada que ho pregunta, cada pocs segons.',
			'settings.station.ic7300Mk2Note' => '\n- L\'**IC-7300 MK2** ve amb l\'adreça `B6`, no la `94` que hi ha aquí per defecte — tria l\'entrada IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- L\'**IC-705** presenta dos ports sèrie USB, tots dos amb el nom de la ràdio. El CI-V és al **primer**, al qual apunta el selector sempre que els pot distingir.',
			'settings.station.ic7760PortNote' => '\n- L\'**IC-7760** parla CI-V al **Port A** dels dos ports sèrie USB que presenta.',
			'settings.station.x6100PortNote' => '\n- L\'**X6100** parla CI-V al seu port **DEV** — el segon dels dos ports sèrie que presenta, i al qual apunta el selector.',
			'settings.station.rigctldTroubleshootingTitle' => 'Si l\'aplicació no es pot connectar',
			'settings.station.rigctldTroubleshooting' => 'Això es connecta a un **dimoni rigctld que executes tu mateix**, no directament a la ràdio — el backend de Hamlib parla amb la ràdio i admet centenars de models.\n\n- **El dimoni ja s\'ha d\'estar executant**, p. ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Troba el número de model de la teva ràdio amb `rigctl -l`.\n- **Des d\'una altra màquina**, inicia\'l amb `-T 0.0.0.0`: per defecte, rigctld només accepta connexions de la màquina on s\'executa.\n- **El port** és el 4532, tret que hagis iniciat el dimoni amb `-t`.\n- Un cop connectat, si no apareix la freqüència normalment és perquè el mateix dimoni no pot accedir a la ràdio. Prova-ho amb `rigctl -m 2 f` a la màquina del dimoni.',
			'settings.station.flrigTroubleshootingTitle' => 'Si l\'aplicació no es pot connectar',
			'settings.station.flrigTroubleshooting' => 'Això es connecta a un **programa flrig que executes tu mateix**, no directament a la ràdio — flrig parla amb la ràdio i admet la majoria de marques i models.\n\n- **flrig ja s\'ha d\'estar executant**, amb el transceptor configurat i connectat.\n- **El port** és el 12345, tret que l\'hagis canviat a la configuració de flrig (Config → Setup → Server).\n- **Des d\'una altra màquina**, assegura\'t que el servidor de flrig sigui accessible. Escolta a totes les interfícies, però potser el tallafoc no hi està d\'acord.\n- Un cop connectat, si no apareix la freqüència normalment és perquè el mateix flrig no pot accedir a la ràdio. Comprova que la pantalla de flrig segueix el dial.',
			'settings.station.hrdTroubleshootingTitle' => 'Si l\'aplicació no es pot connectar',
			'settings.station.hrdTroubleshooting' => 'Això es connecta al **Rig Control de Ham Radio Deluxe, que s\'executa al teu ordinador**, no directament a la ràdio — HRD parla amb la ràdio.\n\n- **Rig Control ja s\'ha d\'estar executant** i connectat a la ràdio.\n- **El seu servidor IP ha d\'estar activat.** Rig Control només parla amb altres programes a través d\'ell.\n- **El port** és el 7809, tret que l\'hagis canviat a la configuració del servidor IP.\n- **Des d\'una altra màquina**, assegura\'t que el tallafoc deixi passar la connexió.\n\nAquesta entrada s\'ha escrit a partir de descripcions publicades del protocol d\'HRD i no s\'ha provat amb HRD. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Si l\'aplicació no es pot connectar',
			'settings.station.n3fjpTroubleshooting' => 'Això es connecta a **un programa de registre N3FJP que s\'executa al teu ordinador**, no directament a la ràdio — N3FJP parla amb la ràdio.\n\n- **L\'API del programa ha d\'estar activada**: Settings → Application Program Interface, marca **TCP API Enabled**.\n- **El port** és el 1100, tret que l\'hagis canviat allà.\n- **N3FJP ha de tenir configurada una interfície de ràdio** per seguir o sintonitzar la ràdio. Sense, només informa del que s\'escriu a la seva finestra d\'entrada.\n- N3FJP només informa de banda, mode i freqüència: ni potència ni estat de transmissió.\n\nAquesta entrada s\'ha escrit a partir de l\'API publicada d\'N3FJP i no s\'ha provat amb N3FJP. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.commanderTroubleshootingTitle' => 'Si l\'aplicació no es pot connectar',
			'settings.station.commanderTroubleshooting' => 'Això es connecta a **DXLab Commander, que s\'executa al teu ordinador**, no directament a la ràdio — Commander parla amb la ràdio.\n\n- **Commander ja s\'ha d\'estar executant** i connectat a la ràdio.\n- **El seu servei de xarxa ha d\'estar activat**: el botó **Net Serv** al panell Radio de la finestra Configuration de Commander.\n- **El port** és el 52002, el tercer port del bloc que comença al **Base Port** de Net Serv (52000 tret que l\'hagis canviat).\n- **Des d\'una altra màquina**, assegura\'t que el tallafoc deixi passar la connexió.\n\nAquesta entrada s\'ha escrit a partir dels missatges TCP publicats de Commander i no s\'ha provat amb Commander. Si funciona a mitges, val la pena informar-ne.',
			'settings.station.ic705TroubleshootingTitle' => 'Si la ràdio no respon mai',
			'settings.station.ic705Troubleshooting' => 'La ràdio té una **única** sessió de control remot. Quan s\'ignora l\'inici de sessió, gairebé sempre és perquè alguna altra cosa l\'està fent servir.\n\n- **Tanca qualsevol altre client.** wfview o RS-BA1 connectats a la mateixa ràdio ocupen aquesta única sessió, i mentrestant l\'inici de sessió d\'aquí simplement s\'ignora.\n- **Comprova la configuració de xarxa de la ràdio.** La WLAN ha d\'estar activada, la ràdio ha de ser a la mateixa xarxa i la seva funció de control remot (Network) ha d\'estar activada.\n- **Els ports han de coincidir** amb el Control Port i el Serial Port (UDP) de la ràdio, o amb els ports que hi redirigeixen. Un port equivocat es troba amb silenci, igual que una ràdio apagada.\n- **Apaga i torna a encendre la WLAN de la ràdio** si continua bloquejada. Això allibera de manera fiable una sessió encallada a la ràdio.\n\nUna **contrasenya incorrecta es rebutja explícitament**, no amb silenci. Si has arribat aquí en lloc de rebre un missatge de "rebutjat", el problema no és la contrasenya.',
			'settings.station.icomLanTroubleshooting' => 'La ràdio té una **única** sessió de control remot. Quan s\'ignora l\'inici de sessió, gairebé sempre és perquè alguna altra cosa l\'està fent servir.\n\n- **Tanca qualsevol altre client.** wfview, RS-BA1 o el Remote Utility d\'Icom connectats a la mateixa ràdio ocupen aquesta única sessió, i mentrestant l\'inici de sessió d\'aquí simplement s\'ignora.\n- **Comprova la configuració de xarxa de la ràdio.** El seu port LAN ha d\'estar connectat a la mateixa xarxa que aquest dispositiu, el seu **Network Control** ha d\'estar activat, i l\'usuari i la contrasenya han d\'estar configurats com a usuari de xarxa a la ràdio.\n- **Els ports han de coincidir** amb el Control Port i el Serial Port (UDP) de la ràdio, o amb els ports que hi redirigeixen. Un port equivocat es troba amb silenci, igual que una ràdio apagada.\n- **Si es connecta però no respon mai**, l\'adreça CI-V d\'aquí ha de coincidir amb el menú CI-V ADDRESS de la ràdio. Aquesta entrada hi posa l\'adreça amb què ve el model.\n- **Apaga i torna a encendre la ràdio** si continua bloquejada.',
			'settings.station.statusStale' => 'No respon',
			'settings.station.statusDisconnected' => 'No connectat',
			'settings.station.statusConnecting' => 'Connectant…',
			'settings.station.statusDisconnecting' => 'Desconnectant…',
			'settings.station.statusError' => 'La connexió ha fallat',
			'settings.station.currentRadioSettings' => 'Configuració actual de la ràdio',
			'settings.station.notSupportedByThisRadio' => 'Aquesta ràdio no ho admet',
			'settings.station.cwMessagesButton' => 'Missatges CW',
			'settings.station.voiceMessagesButton' => 'Missatges de fonia',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Manipulador de veu: ${count} memòries a la ràdio',
			'settings.station.antennaBands' => 'Bandes',
			'settings.station.antennaType' => 'Tipus d\'antena',
			'settings.station.antennaTypeRequired' => 'Tria un tipus d\'antena',
			'settings.station.antennaTypes.dipole' => 'Dipol',
			'settings.station.antennaTypes.vertical' => 'Vertical',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Directiva',
			'settings.station.antennaTypes.loop' => 'Llaç',
			'settings.station.antennaTypes.longWire' => 'Fil llarg / EFHW',
			'settings.station.antennaTypes.other' => 'Altres',
			'settings.station.keyType' => 'Tipus de manipulador',
			'settings.station.keyTypeRequired' => 'Tria un tipus de manipulador',
			'settings.station.keyTypes.straight' => 'Manipulador vertical',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semiautomàtic mecànic)',
			'settings.station.keyTypes.fullyAutomatic' => 'Manipulador totalment automàtic',
			'settings.station.keyTypes.singlePaddle' => 'Pala simple',
			'settings.station.keyTypes.dualPaddle' => 'Pala doble',
			'settings.station.keyTypes.computerDriven' => 'Controlat per ordinador',
			'settings.station.keyTypes.other' => 'Altres',
			'settings.station.softwareIntermediaries' => 'Programari intermediari',
			'settings.station.otherBrands' => 'Altres marques',
			'settings.station.otherEquipment' => 'Altres equips (antenes, manipuladors, etc.)',
			'settings.station.newAntenna' => 'Antena nova',
			'settings.station.newKey' => 'Manipulador nou',
			'settings.station.newKeyer' => 'WinKeyer (K1EL o compatible)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Manipulador CAT a ${radio}',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyOnDevice' => ({required Object device}) => 'Manipulador a ${device}',
			'settings.station.trackStationInfo' => 'Registra la informació de l\'estació per a cada QSO',
			'settings.station.includeStationInfoInAdif' => 'Inclou-la a les exportacions ADIF',
			'settings.station.whatToTrack' => 'Què vols registrar?',
			'settings.station.trackFieldRig' => 'Transceptor',
			'settings.station.trackFieldPower' => 'Potència',
			'settings.station.watts' => 'Watts',
			'settings.station.trackFieldAntenna' => 'Antena',
			'settings.station.trackFieldKey' => 'Manipulador CW',
			'settings.station.placeholderConnectDelay' => 'Retard de connexió (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Quant de temps triga la negociació simulada. En blanc o 0 connecta a l\'instant.',
			'settings.station.placeholderDropAfter' => 'Desconnecta al cap de (segons)',
			'settings.station.placeholderDropAfterDescription' => 'Tanca la connexió per si sola, per provar el camí de reconnexió. En blanc o 0 no es desconnecta mai.',
			'settings.station.placeholderFailConnect' => 'Falla sempre en connectar',
			'settings.station.placeholderConnectFailure' => 'S\'ha indicat a la ràdio provisional que rebutgi aquesta connexió',
			'settings.station.placeholderFreq' => 'Freqüència (kHz)',
			'settings.station.placeholderFreqDescription' => 'On comença la ràdio provisional. Després informa de qualsevol freqüència a la qual la sintonitzi l\'aplicació.',
			'settings.station.placeholderMode' => 'Mode',
			'settings.station.placeholderModeDescription' => 'El mode amb què comença la ràdio provisional, p. ex. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Potència (watts)',
			'settings.station.placeholderPurpose' => 'Utilitza aquesta ràdio per tenir constància de quin equip fas servir a efectes de registre',
			'settings.station.placeholderReplyDelay' => 'Retard de resposta (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Quant triga la ràdio provisional a informar d\'un canvi. En blanc o 0 respon a l\'instant.',
			'settings.station.cwKeyerField' => 'Manipulador CW per CAT',
			'settings.station.cwKeyerFieldDescription' => 'Si aquesta ràdio manipula CW a partir de text per CAT. Desactivat per a un equip que l\'aplicació no coneix.',
			'settings.station.voiceMemories' => 'Memòries de veu',
			'settings.station.voiceMemoriesDescription' => 'Quantes memòries de veu reprodueix la ràdio per CAT. 0 si no en té cap.',
			'settings.station.voiceMemoriesInvalid' => 'Un nombre enter, 0 o més',
			'settings.station.yaesuMeterCapture' => 'Captura les lectures dels mesuradors',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Llegeix el mesurador de potència de sortida i l\'indicador de ROE alta de la ràdio mentre transmet i escriu els valors en brut al registre. Serveix per construir l\'escala que Yaesu no publica — els valors no es mostren com a mesuradors.',
			'settings.station.yaesuMeterCaptureDescription' => 'Llegeix els mesuradors PO, SWR i ALC de la ràdio mentre transmet i escriu els valors en brut al registre. Serveix per construir l\'escala que Yaesu no publica — els valors no es mostren com a mesuradors.',
			'settings.station.telemetryInterval' => 'Interval de lectura dels mesuradors (ms)',
			'settings.station.telemetryIntervalDescription' => 'Cada quant es llegeixen els mesuradors de la ràdio mentre transmet. Deixa-ho en blanc per al més ràpid que admeti aquesta connexió, fins a 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Un nombre enter de mil·lisegons, de ${min} a ${max}',
			'settings.station.pollInterval' => 'Interval de consulta en repòs (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Cada quant es demana a la ràdio la freqüència i el mode mentre cap dels dos canvia. Deixa-ho en blanc per a ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Un nombre enter de mil·lisegons, de ${min} a ${max}',
			'settings.station.advancedSettings' => 'Configuració avançada',
			'settings.station.placeholderSwr' => 'Lectura de ROE',
			'settings.station.placeholderSwrDescription' => 'El que indica el mesurador de ROE d\'aquesta ràdio mentre transmet. Per sobre d\'1,8 el panell avisa.',
			'settings.station.placeholderSwrInvalid' => 'Un nombre, 1 o més',
			'settings.station.keyerNone' => 'Cap',
			'settings.station.cwDialect' => 'Dialecte de manipulació CW',
			'settings.station.cwDialectDescription' => 'Quina forma de l\'ordre KY accepta aquesta ràdio. Cap vol dir sense manipulació CW per CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, omplert fins a 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (text KY)',
			'settings.station.voiceDialect' => 'Dialecte del manipulador de veu',
			'settings.station.voiceDialectDescription' => 'Com reprodueix aquesta ràdio les seves memòries de veu per CAT. Cap vol dir sense memòries de veu per CAT. Amb un dialecte i sense nombre, s\'aplica el nombre per defecte del dialecte.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, estil TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB i DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (polsacions de botó)',
			'settings.station.placeholderDiagnostic' => 'Simulat',
			'settings.station.placeholderWholeNumberInvalid' => 'Ha de ser un nombre enter, 0 o més',
			'settings.station.placeholderFreqInvalid' => 'Ha de ser una freqüència en kHz, més gran que zero',
			'settings.station.placeholderModeInvalid' => 'Ha de ser un nom de mode, p. ex. USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposició',
			'settings.station.switchLayoutDescription' => 'A quin costat del commutador estan connectades les teves ràdios.',
			'settings.station.switchLayoutRequired' => 'Tria com està cablejat el commutador',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'El commutador ha rebutjat "${command}" (error ${code})',
			'settings.station.switchBusyTransmitting' => 'Aquest port està transmetent — no s\'ha canviat l\'antena',
			'settings.station.switchNoAntenna' => 'Cap',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antena al port ${port}',
			'settings.station.switchAntennaForDescription' => 'Quina de les teves antenes està connectada a aquest port del commutador.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antenes, ${radios} ràdios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antenes, 1 ràdio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antena, ${radios} ràdios',
			'settings.station.switchCommonPort' => 'Comú',
			'settings.station.dcnAddress' => 'Adreça del dispositiu',
			'settings.station.dcnAddressDescription' => 'L\'adreça configurada als interruptors DIP del mòdul. Un mòdul de relé coaxial surt de fàbrica amb el 2.',
			'settings.station.dcnAddressRequired' => 'Ha de ser una adreça de dispositiu de l\'1 al 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'segueix les dades de banda',
			'settings.station.switchPortTransmittingHint' => 'transmetent — ara no es pot canviar',
			'settings.station.switchCurrentStateHeader' => 'Estat actual',
			'settings.station.switchCurrentStateDescription' => 'En quina antena és ara mateix cada port de ràdio. Els canvis tenen efecte immediatament.',
			'settings.station.switchWiringHeader' => 'Cablejat',
			'settings.station.switchPortInhibitedHint' => 'transmissió inhibida',
			'settings.station.rotatorAxes' => 'Eixos',
			'settings.station.rotatorAxesDescription' => 'Si el rotor gira només en azimut, o també en elevació (un G-5500 o similar).',
			'settings.station.rotatorAxesAzimuth' => 'Només azimut',
			'settings.station.rotatorAxesAzimuthElevation' => 'Azimut i elevació',
			'settings.station.rotatorAzimuthOffset' => 'Desplaçament d\'azimut',
			'settings.station.rotatorAzimuthOffsetDescription' => 'Graus a afegir al que llegeix el controlador, quan el seu zero no és el nord geogràfic. Els girs es corregeixen en conseqüència.',
			'settings.station.rotatorElevationOffset' => 'Desplaçament d\'elevació',
			'settings.station.rotatorAzimuthMin' => 'Azimut mínim',
			'settings.station.rotatorAzimuthMax' => 'Azimut màxim',
			'settings.station.rotatorAzimuthMaxDescription' => 'En els graus del mateix controlador. Per sobre de 360 per a un rotor amb solapament, que llavors fa el gir més curt.',
			'settings.station.rotatorElevationMin' => 'Elevació mínima',
			'settings.station.rotatorElevationMax' => 'Elevació màxima',
			'settings.station.rotatorElevationMaxDescription' => 'En els graus del mateix controlador. Per sobre de 90 per a un rotor que es capgira.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => 'Graus sencers, de ${min} a ${max}',
			'settings.station.rotatorLimitsInvalid' => 'El límit inferior ha de ser menor que el superior',
			'settings.station.rotatorPollInterval' => 'Interval de consulta (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'Cada quant es demana al rotor cap a on apunta. Deixa-ho en blanc per a ${fallback} ms.',
			'settings.station.rotatorAxesRequired' => 'Tria en quins eixos gira el rotor',
			'settings.station.rotatorRefused' => 'El controlador ha rebutjat una ordre. Comprova que està en mode GS-232.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator només respon un cop està configurat per fer-ho, i si no, no diu res:\n\n- **Activa UDP Control** al menú Setup de PstRotator.\n- **Fes coincidir el port**: Communication → UDP Control Port, 12000 tret que s\'hagi canviat. PstRotator respon pel port següent (12001), que ha d\'estar lliure en aquest dispositiu.\n- **Connecta PstRotator al seu controlador.** Fins que no ho estigui, no respon res per UDP.\n- **Permet-lo al tallafoc** del PC que executa PstRotator, i en aquest dispositiu, que escolta les respostes.\n- **En un Mac, iPhone o iPad**, Ham2K Logger necessita accés a la xarxa local (Configuració → Privacitat i seguretat → Xarxa local).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => 'Estat actual: ${position}',
			'settings.station.rotatorDisconnected' => 'desconnectat',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '${degrees}° d\'azimut',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '${degrees}° az',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '${degrees}° d\'elevació',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '${degrees}° el',
			'settings.station.rotatorNoReading' => 'Esperant que el controlador informi de la seva posició…',
			'settings.station.rotatorNotResponding' => 'no respon',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => 'Girant cap a ${heading}, fins on ho permeten els límits d\'aquest rotor',
			'settings.station.rotatorTargetAzimuth' => 'Gira a l\'azimut',
			'settings.station.rotatorTargetAzimuthShort' => 'Gira a az',
			'settings.station.rotatorTargetElevation' => 'Gira a l\'elevació',
			'settings.station.rotatorTargetElevationShort' => 'Gira a el',
			'settings.station.rotatorAzimuthInvalid' => 'Ha de ser de 0 a 360',
			'settings.station.rotatorElevationInvalid' => 'Ha de ser de 0 a 180',
			'settings.station.rotatorTurn' => 'Gira',
			'settings.station.rotatorStop' => 'Atura',
			'settings.station.configUnreadable' => 'No s\'ha pogut llegir la configuració desada d\'aquesta ràdio. Obre\'n la configuració i torna-la a introduir, o elimina-la i torna-la a afegir.',
			'settings.station.autoConnectHeld' => 'HaLo va deixar de respondre l\'última vegada que es va connectar a aquesta ràdio, així que aquesta vegada no s\'hi ha connectat automàticament. Prem Connecta per tornar-ho a provar.',
			'settings.offlineData.title' => 'Dades fora de línia',
			'settings.offlineData.noFiles' => 'No hi ha fitxers de dades',
			'settings.offlineData.noFilesDescription' => 'Activa extensions d\'activitat o de consulta per descarregar aquí les seves dades fora de línia.',
			'settings.offlineData.refresh' => 'Refresca',
			'settings.offlineData.refreshing' => 'Refrescant…',
			'settings.offlineData.updateAll' => 'Actualitza-ho tot',
			'settings.offlineData.updatingAll' => 'Actualitzant tots els fitxers de dades…',
			'settings.offlineData.neverDownloaded' => 'Mai descarregat',
			'settings.offlineData.updatedJustNow' => 'Actualitzat ara mateix',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Actualitzat fa ${days} d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Actualitzat fa ${days} d ${hours} h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Actualitzat fa ${hours} h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Actualitzat fa ${hours} h ${minutes} min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Actualitzat fa ${minutes} min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'L\'última descàrrega només tenia ${imported} dels ${existing} registres i no s\'ha utilitzat. Refresca per acceptar-la.',
			'settings.offlineData.extensionsSection' => 'Extensions',
			'settings.profiles.notSet' => 'Sense definir',
			'settings.profiles.personalInfo' => 'Informació personal',
			'settings.profiles.personalInfoNote' => 'Es pot incloure als registres generats quan sigui rellevant per als enviaments',
			'settings.profiles.name' => 'Nom',
			'settings.profiles.email' => 'Correu electrònic',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'Secció ARRL',
			'settings.profiles.racSection' => 'Secció RAC',
			'settings.profiles.section' => 'Secció',
			'settings.search.clear' => 'Neteja',
			'settings.search.hint' => 'Cerca preferències',
			'settings.developer.developerModeDescription' => 'Activa els avisos per a desenvolupadors, els registres de depuració i les eines.',
			'settings.developer.experiments' => 'Experiments',
			'settings.developer.showIdleMetrics' => 'Mostra les mètriques d\'inactivitat',
			'settings.developer.showIdleMetricsDescription' => 'Mostra a la barra d\'estat quant de temps ha estat inactiu el motor d\'extensions durant l\'últim segon. Toca-ho per veure les mitjanes de 10 i 60 segons.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% inactiu',
			'settings.developer.idleMetricsAverages' => 'Mitjana d\'inactivitat:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} activat', other: '${count} activats', ), 
			'settings.developer.patchTrack' => 'Branca de pegats',
			'settings.developer.patchTrackDescription' => 'Quina branca de pegats remots segueix aquest dispositiu. Les branques més arriscades reben les correccions abans, menys provades. Els pegats s\'apliquen en el següent reinici.',
			'settings.developer.trackStable' => 'Estable',
			'settings.developer.trackUnstable' => 'Inestable',
			'settings.developer.trackBleeding' => 'Experimental',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Comprovant si hi ha pegats a "${track}"…',
			'settings.developer.patchDownloaded' => 'Pegat descarregat — reinicia l\'aplicació per aplicar-lo.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'No hi ha cap pegat nou a "${track}".',
			'settings.developer.noPatchInstalled' => 'No hi ha cap pegat instal·lat — s\'executa el binari de la versió.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'S\'executa el pegat núm. ${patch}.',
			'settings.developer.deepLinks' => 'Enllaços profunds',
			'settings.developer.registerUrlSchemes' => 'Registra els esquemes d\'URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permet que els enllaços com.ham2k:// obrin aquesta còpia de l\'aplicació',
			'settings.developer.registerUrlSchemesDone' => 'Aquesta còpia ara obre els enllaços com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'No s\'ha pogut registrar: ${error}',
			'settings.developer.systemInformation' => 'Informació del sistema',
			'settings.developer.appVersion' => 'Versió de l\'aplicació',
			'settings.developer.dataFolder' => 'Carpeta de dades',
			'settings.developer.loading' => '(carregant…)',
			'settings.developer.panelLoadFailed' => 'No s\'ha pogut carregar aquest panell de configuració.',
			'settings.developer.extDevServer' => 'Servidor de desenvolupament d\'extensions',
			'settings.developer.extensionSettings' => 'Configuració d\'extensions',
			'settings.developer.extDevServerDescription' => 'Carrega extensions des d\'un servidor de desenvolupament de la teva xarxa en lloc de les integrades a l\'aplicació, i recarrega-les quan desis.',
			'settings.developer.extDevServerAddress' => 'Adreça del servidor',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Connecta',
			'settings.developer.extDevServerDisconnect' => 'Desconnecta',
			'settings.developer.extDevServerConnecting' => 'Connectant…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Servint ${count} extensió: ${keys}', other: 'Servint ${count} extensions: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'No connectat',
			'settings.developer.extDevServerReconnect' => 'Torna a connectar en iniciar',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Última recàrrega: ${key} a les ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} extensió no es pot compilar', other: '${count} extensions no es poden compilar', ), 
			'settings.developer.catalog' => 'Catàleg d\'extensions',
			'settings.developer.catalogDescription' => 'Llegeix el catàleg des d\'un altre servidor — un de local mentre es treballa en el mateix catàleg. Buit vol dir catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Adreça del catàleg',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Branques de cerca del catàleg',
			'settings.developer.catalogSearchStable' => 'Només estables',
			'settings.developer.catalogSearchUnstable' => 'Inestables o millors',
			'settings.developer.catalogSearchBleeding' => 'Experimentals o millors',
			'settings.about.notices' => 'Avisos i missatges',
			'settings.about.noticesDescription' => 'Anuncis i missatges d\'estat',
			'settings.about.releaseNotes' => 'Notes de la versió',
			'settings.about.copiedVersion' => 'S\'han copiat els detalls de la versió al porta-retalls',
			'settings.panels.settings' => 'Preferències de l\'aplicació',
			'settings.panels.settingsDescription' => 'Fes que l\'aplicació funcioni com tu vulguis',
			'settings.panels.commonSettings' => 'Preferències comunes',
			'settings.panels.syncDescription' => 'Fes còpia de seguretat i sincronitza els teus registres entre dispositius',
			'settings.panels.accountsDescription' => 'Credencials de serveis, dades fora de línia i més',
			'settings.panels.extensions' => 'Extensions i funcions',
			'settings.panels.extensionsDescription' => 'Activitats, concursos, panells del tauler i més funcions',
			'settings.panels.profilesDescription' => 'Indicatiu de l\'operador i perfil de l\'estació',
			'settings.panels.stationProfiles' => 'Perfils d\'estació',
			'settings.panels.developerSettings' => 'Configuració de desenvolupador',
			'settings.panels.developerSettingsDescription' => 'Eines de depuració i desenvolupament',
			'settings.panels.about' => 'Quant a',
			'settings.panels.aboutDescription' => 'Versió, crèdits i informació legal',
			'settings.panels.unavailableTitle' => 'Algunes opcions no estan disponibles',
			'settings.panels.unavailableText' => 'L\'entorn d\'execució d\'extensions no s\'ha pogut iniciar, així que falten les opcions aportades per les extensions.',
			'settings.panels.station' => 'Configuració de l\'estació',
			'settings.panels.stationDescription' => 'Control CAT i més opcions',
			'settings.panels.peers' => 'Dispositius associats',
			'settings.panels.peersDescription' => 'Connecta amb altres dispositius propers',
			'settings.showMoreSettings' => 'Mostra més opcions',
			'settings.gridPrecision' => 'Precisió de la graella',
			'settings.gridPrecisionOpts.six' => '6 dígits (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 dígits (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 dígits',
			'settings.gridPrecisionDescription.eight' => '8 dígits',
			'commands.enableSyncFirst' => 'Activa primer la sincronització a la Configuració.',
			'commands.fullResyncStarted' => 'S\'ha iniciat una resincronització completa — abans s\'ha fet una còpia de seguretat de les dades locals.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Cap fitxer de dades coincideix amb "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'La recàrrega ha fallat: ${error}',
			'commands.reloadingAll' => 'Recarregant tots els fitxers de dades…',
			'commands.reloadingTarget' => ({required Object target}) => 'Recarregant els fitxers de dades de ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experiment desconegut "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} activat',
			'commands.experimentDisabled' => ({required Object name}) => '${name} desactivat',
			'commands.sentryTestSent' => 'S\'ha enviat un informe d\'error de prova a Sentry',
			'commands.idleMetricsEnabled' => 'Mètriques d\'inactivitat activades a la barra d\'estat',
			'commands.idleMetricsDisabled' => 'Mètriques d\'inactivitat desactivades',
			'commands.sentryTestLocalOnly' => 'Sentry està desactivat en aquesta versió — l\'error de prova només s\'ha registrat localment',
			'commands.noOperationOpen' => 'Aquesta ordre necessita una operació oberta',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'No se sap com marcar un \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} no està activat en aquesta aplicació',
			'commands.goUnknown' => ({required Object to}) => 'No se sap com anar a \'${to}\'',
			'commands.goBlocked' => 'Tanca primer el diàleg obert',
			'commands.operationAlreadyStarted' => 'Aquesta operació ja té un marcador d\'inici',
			'commands.couldNotOpenLocation' => 'S\'ha afegit la pausa, però no s\'ha pogut obrir la pantalla d\'ubicació',
			'commands.noTestOperations' => 'No hi ha operacions de prova per purgar',
			'commands.purgeTestsUnavailable' => 'PURGETESTS ha de mostrar un diàleg de confirmació, que aquí no està disponible',
			'commands.syncAllUnavailable' => 'SYNCALL ha de mostrar un diàleg de confirmació, que aquí no està disponible',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha purgat ${count} operació de prova', other: 'S\'han purgat ${count} operacions de prova', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'S\'han purgat ${purged} de ${total} operacions de prova — la resta han fallat; torna a provar PURGETESTS',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha purgat ${count} contacte de prova sense operació', other: 'S\'han purgat ${count} contactes de prova sense operació', ), 
			'commands.purgeTestsContactsFailed' => 'S\'han purgat les operacions de prova, però els contactes de prova sense operació han fallat. Torna a provar PURGETESTS',
			'commands.purgeTestsNothingToDo' => 'No s\'ha purgat res',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'S\'han eliminat ${removed} de ${total} operacions de prova — la resta han fallat; torna a provar Revisa',
			'commands.receivedPurgesFailed' => 'No s\'han pogut eliminar aquestes operacions de prova — torna a provar Revisa',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha eliminat ${count} operació de prova en un altre dispositiu', other: 'S\'han eliminat ${count} operacions de prova en un altre dispositiu', ), 
			'commands.receivedPurgesReview' => 'Revisa',
			'commands.settingOn' => 'Activat',
			'commands.settingOff' => 'Desactivat',
			'commands.settingEmpty' => '(buit)',
			'commands.settingSecretSet' => '(definit)',
			'commands.settingSecretUnset' => '(no definit)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} seleccionats',
			'commands.settingExpectsOnOff' => 'on o off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'un de: ${choices}',
			'commands.settingExpectsNumber' => 'un número',
			'commands.settingVanished' => ({required Object label}) => '“${label}” ja no està disponible',
			'commands.noCwKeyer' => 'Cap ràdio connectada pot manipular CW',
			'commands.noKeyer' => 'Cap ràdio connectada pot manipular CW ni reproduir memòries de veu',
			'commands.keyerNeedsOperation' => 'Obre una operació per utilitzar el manipulador CW',
			'commands.keyerExperimentOff' => 'La manipulació CW està desactivada — activa-la amb EXP KEYER',
			'commands.esmExperimentOff' => 'Enter envia missatges està desactivat — activa-ho amb EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Enviant CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Missatge CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'El missatge CW F${n} no s\'ha enviat: les extensions no estan a punt',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => 'Missatge de fonia M${n}: ${error}',
			'commands.voiceMessageNotRendered' => 'les extensions no estan a punt',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => 'No s\'ha enviat res: la Ràdio ${radio} no pot manipular això',
			'commands.so2rNoRadioB' => 'No s\'ha enviat res: tria una Ràdio B a Configuració de l\'estació per manipular des d\'aquest joc',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” no ha acceptat aquest valor',
			'commandDialog.hint' => 'Cerca indicatius o escriu una ordre',
			'commandDialog.noResults' => ({required Object text}) => 'Res coincideix amb “${text}”',
			'commandDialog.sectionCommands' => 'Ordres',
			'commandDialog.sectionGoTo' => 'Ves a',
			'commandDialog.sectionOperations' => 'Operacions',
			'commandDialog.goHome' => 'Inici',
			'commandDialog.goSettings' => 'Configuració',
			'commandDialog.goNewOperation' => 'Nova operació',
			'commandDialog.runTyped' => ({required Object text}) => 'Executa “${text}”',
			'commandDialog.sectionSuggestions' => 'Prova',
			'commandDialog.lookingUp' => 'Consultant l\'indicatiu…',
			'commandDialog.blockedByPane' => 'No es poden utilitzar ordres mentre hi ha un panell o diàleg obert',
			'keyboardShortcuts.title' => 'Dreceres de teclat',
			'keyboardShortcuts.description' => 'Personalitza les assignacions de tecles',
			'keyboardShortcuts.search' => 'Cerca ordres i tecles',
			'keyboardShortcuts.import' => 'Importa…',
			'keyboardShortcuts.export' => 'Exporta…',
			'keyboardShortcuts.resetAll' => 'Restableix-ho tot',
			'keyboardShortcuts.resetAllTitle' => 'Restablir totes les dreceres?',
			'keyboardShortcuts.resetAllBody' => 'Totes les ordres tornen a les seves tecles per defecte, i les tecles assignades a ordres escrites s\'eliminen.',
			'keyboardShortcuts.reset' => 'Restableix',
			'keyboardShortcuts.noKey' => 'Sense tecla',
			'keyboardShortcuts.changed' => 'Canviada',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} també està assignada a ${commands}',
			'keyboardShortcuts.groupApp' => 'Aplicació',
			'keyboardShortcuts.groupKeying' => 'Manipulació',
			'keyboardShortcuts.groupLogging' => 'Registre',
			'keyboardShortcuts.groupCommands' => 'Ordres',
			'keyboardShortcuts.groupFixed' => 'Tecles fixes',
			'keyboardShortcuts.contextApp' => 'A tot arreu',
			'keyboardShortcuts.contextLogView' => 'Vistes d\'operació, caça i registres',
			'keyboardShortcuts.contextOperation' => 'Vista d\'operació, manipulant una ràdio per CAT',
			'keyboardShortcuts.contextLogging' => 'Al panell de registre',
			'keyboardShortcuts.addCommand' => 'Afegeix una ordre…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Ordre desconeguda: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Obre el diàleg d\'ordres',
			'keyboardShortcuts.command.toggleTheme' => 'Canvia entre clar i fosc',
			'keyboardShortcuts.command.toggleLanguage' => 'Canvia entre anglès i espanyol',
			'keyboardShortcuts.command.fontScaleUp' => 'Text més gran',
			'keyboardShortcuts.command.fontScaleDown' => 'Text més petit',
			'keyboardShortcuts.command.fontScaleReset' => 'Mida de text normal',
			'keyboardShortcuts.command.densityLooser' => 'Disposició més espaiada',
			'keyboardShortcuts.command.densityDenser' => 'Disposició més densa',
			'keyboardShortcuts.command.densityAuto' => 'Densitat de disposició automàtica',
			'keyboardShortcuts.command.find' => 'Cerca al registre',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Envia el missatge ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Mode teclat activat o desactivat',
			'keyboardShortcuts.command.ptt' => 'Prem per parlar',
			'keyboardShortcuts.command.wipe' => 'Neteja el contacte que s\'està registrant',
			'keyboardShortcuts.fixed.callsign' => 'Escriure indicatius',
			'keyboardShortcuts.fixed.escape' => 'Atura l\'enviament, fes un pas enrere o tanca',
			'keyboardShortcuts.fixed.enter' => 'Registra el contacte',
			'keyboardShortcuts.fixed.space' => 'Camp següent',
			'keyboardShortcuts.fixed.tab' => 'Camp següent o anterior',
			'keyboardShortcuts.fixed.arrows' => 'Mou-te entre camps, controls i el registre',
			'keyboardShortcuts.fixed.walk' => 'Avança pàgines del registre, o ves als seus extrems',
			'keyboardShortcuts.fixed.undo' => 'Desfés una neteja o un esborrat',
			'keyboardShortcuts.editor.addShortcut' => 'Afegeix una drecera',
			'keyboardShortcuts.editor.listening' => 'Prem les tecles de la drecera…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc deixa d\'escoltar',
			'keyboardShortcuts.editor.add' => 'Afegeix',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} pertany als camps de registre o a un diàleg, i no es pot canviar.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} és com s\'escriuen els indicatius. Mantén premut Cmd, Ctrl o Alt amb ella.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'El sistema pot capturar ${keys} abans que l\'aplicació la vegi.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} ja és una de les tecles d\'aquesta ordre.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Pren ${keys} de “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'Restableix al valor per defecte',
			'keyboardShortcuts.editor.remove' => 'Elimina',
			'keyboardShortcuts.editor.commandLabel' => 'Ordre',
			'keyboardShortcuts.editor.commandHint' => 'Introdueix qualsevol ordre vàlida, o diverses ordres separades per ";"',
			'keyboardShortcuts.editor.removeCommand' => 'Elimina l\'ordre',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'Cap ordre llegeix “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'Encara sense tecla',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Dreceres desades a ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'No s\'han pogut exportar les dreceres: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'No s\'ha pogut obrir el fitxer: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} no és un fitxer de dreceres que aquesta aplicació pugui llegir: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'el text no és YAML vàlid (línia ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'no és un fitxer de dreceres de teclat de Ham2K',
			'keyboardShortcuts.file.problemNewerVersion' => 'l\'ha escrit una versió més nova de l\'aplicació',
			'keyboardShortcuts.file.problemMalformed' => 'una part no segueix el format de dreceres',
			'keyboardShortcuts.file.problemTooLarge' => 'és massa gran',
			'keyboardShortcuts.file.importTitle' => 'Importa les dreceres',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Escrit a ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'El fitxer no diu en quin teclat es va escriure.',
			'keyboardShortcuts.file.translate' => 'Què hauria de ser cada una d\'aquestes tecles en aquest teclat?',
			'keyboardShortcuts.file.leaveOut' => 'Deixa fora aquestes dreceres',
			'keyboardShortcuts.file.replace' => 'Substitueix la configuració d\'aquest dispositiu',
			'keyboardShortcuts.file.replaceHint' => 'Totes les dreceres que no són al fitxer tornen al valor per defecte.',
			'keyboardShortcuts.file.merge' => 'Afegeix a la configuració d\'aquest dispositiu',
			'keyboardShortcuts.file.mergeHint' => 'Les dreceres del fitxer substitueixen les d\'aquest dispositiu per a les mateixes ordres, i la resta es mantenen.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'No es coneixen en aquesta versió, així que s\'han deixat fora: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'No són dreceres, així que s\'han deixat fora: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Tecles que l\'aplicació es reserva, així que s\'han deixat fora: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Assignades a més d\'una ordre després de la importació: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Importa',
			'keyboardShortcuts.file.imported' => 'Dreceres importades',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'Aquesta versió ha caducat',
			'expiredBuild.body' => 'Visita ham2k.com i aconsegueix una versió més nova.',
			'expiredBuild.visit' => 'Visita ham2k.com',
			'expiredBuild.dismiss' => 'Continua igualment',
			'staleness.codePushFloorTitle' => 'Hi ha una actualització important pendent',
			'staleness.codePushFloorBody' => 'Aquesta versió té una correcció que encara no tens.',
			'staleness.restartToApply' => 'Reinicia l\'aplicació per aplicar-la.',
			'staleness.quitAndReopen' => 'Surt de l\'aplicació i torna-la a obrir per aplicar-la.',
			'staleness.reopenToApply' => 'Tanca l\'aplicació i torna-la a obrir per aplicar-la.',
			'staleness.ignoreForNow' => 'Ignora-ho de moment',
			'spotting.noQsoYet' => 'Encara no hi ha cap QSO registrat per anunciar.',
			'spotting.setFrequencyFirst' => 'Defineix primer una freqüència.',
			'spotting.nothingToSpot' => 'Res a anunciar — cap extensió ofereix anuncis aquí.',
			'spotting.incompleteCall' => 'No es pot anunciar un indicatiu incomplet — acaba\'l primer.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} ha fallat: ${message}',
			'spotting.unknownError' => 'error desconegut',
			'spotting.notSent' => 'Anunci no enviat.',
			'spotting.allSkipped' => 'Anunci no enviat: totes les fonts d\'anuncis l\'han omès.',
			'spotting.notRefreshedOffline' => 'Sense connexió — no s\'han refrescat els anuncis',
			'dataFiles.downloading' => 'Descarregant…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'No s\'ha pogut descarregar ${name}',
			'dataFiles.downloadFailedWebHint' => 'Pot ser un problema de xarxa, o potser el servidor d\'aquest enllaç no permet descàrregues directes des d\'un navegador web. Prova l\'aplicació d\'escriptori o mòbil, o una altra ubicació d\'allotjament.',
			'dataFiles.downloadTimedOut' => 'El servidor ha trigat massa a respondre. Torna-ho a provar més tard.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} ha respost amb un error (HTTP ${status}). Torna-ho a provar més tard.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} no ha pogut proporcionar aquest fitxer (HTTP ${status}). Comprova que l\'adreça encara sigui correcta.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM no té cap fitxer d\'historial d\'indicatius per a ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'La descàrrega de l\'historial d\'indicatius de N1MM per a ${stem} no ha funcionat. Torna-ho a provar més tard.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'No s\'ha pogut processar ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'La descàrrega només tenia ${imported} dels ${existing} registres d\'aquest dispositiu, així que s\'han conservat els que hi faltaven. Si la refresques a Configuració › Dades fora de línia, s\'acceptarà igualment.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha importat ${count} registre per a ${label}.', other: 'S\'han importat ${count} registres per a ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'S\'han importat dades per a ${label}.',
			'dataFiles.cleanedUpTitle' => 'S\'han netejat les dades d\'extensions',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'han eliminat les dades de ${count} fitxer de dades d\'extensions desactivades.', other: 'S\'han eliminat les dades de ${count} fitxers de dades d\'extensions desactivades.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} registres',
			'dataFiles.definitionUnavailable' => 'L\'origen del fitxer no n\'ha proporcionat la definició — potser la seva extensió s\'està reiniciant o està mal configurada. Torna-ho a provar d\'aquí a un moment.',
			'updates.updateAvailable' => 'Actualització disponible',
			'updates.newVersionAvailable' => ({required Object version}) => 'Hi ha una versió nova (${version}) disponible.',
			'updates.getIt' => 'Obtén-la',
			'updates.ok' => 'D\'acord',
			'updates.updateReady' => 'Actualització a punt',
			'updates.restartToApply' => 'S\'ha descarregat una actualització. Reinicia per aplicar-la.',
			'updates.appliesNextLaunch' => 'S\'ha descarregat una actualització. S\'aplicarà la propera vegada que obris l\'aplicació.',
			'updates.restartNow' => 'Reinicia ara',
			'updates.reloadToUpdate' => 'Hi ha una versió més nova d\'aquesta pàgina. Recarrega-la per obtenir-la.',
			'updates.reloadNow' => 'Recarrega ara',
			'updates.checkForUpdates' => 'Comprova les actualitzacions',
			'updates.checkingForUpdates' => 'Comprovant si hi ha actualitzacions…',
			'updates.upToDate' => 'Al dia',
			'updates.automaticChecks' => 'Comprova automàticament',
			'updates.automaticChecksDescription' => 'Busca versions noves en segon pla, a partir de la propera vegada que iniciïs l\'aplicació',
			'extensionService.runtimeNotReady' => 'L\'entorn d\'execució d\'extensions no està a punt.',
			'extensionService.testFailed' => ({required Object error}) => 'La prova ha fallat: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Connectat com a ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuració de camp invàlida',
			'extensionService.invalidValue' => 'Valor invàlid',
			'extensionService.validationError' => ({required Object error}) => 'Error de validació: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'L\'acció ha fallat: ${error}',
			'extensionService.commandFailed' => 'L\'ordre no s\'ha pogut executar',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name} no pot canviar la configuració: no ho va demanar en instal·lar-se',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name} no pot controlar la ràdio: no ho va demanar en instal·lar-se',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name} no pot executar això: és una de les ordres de desenvolupador pròpies de l\'aplicació',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => 'Ara mateix no es poden enviar informes',
			'extensionService.stashUnavailable' => 'Ara mateix no es pot accedir a Ham2K File Stash',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => 'La cerca d\'activitats no ha rebut resposta de ${names}, així que pot ser que faltin alguns resultats.',
			'extensionService.activitySearchSomeSourcesFailed' => 'Algunes extensions d\'activitat no han respost la cerca, així que pot ser que faltin alguns resultats.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} ha passat massa temps als seus temporitzadors. S\'han aturat fins que es reiniciïn les extensions.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Els temporitzadors de ${name} continuaven fallant. S\'han aturat fins que es reiniciïn les extensions.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} s\'ha quedat encallat en un temporitzador. Els seus temporitzadors s\'han aturat fins que es reiniciïn les extensions.',
			'operationLocationScreen.title' => 'Ubicació de l\'operació',
			'operationLocationScreen.selectedLocation' => 'Ubicació seleccionada',
			'operationLocationScreen.gridSquare' => 'Localitzador de graelles Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Ha de tenir 4, 6, 8 o 10 caràcters, com FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Ubicacions suggerides',
			'operationLocationScreen.deviceGps' => 'GPS del dispositiu',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de ${device}',
			'operationLocationScreen.locating' => 'Localitzant…',
			'operationLocationScreen.gpsUnavailable' => 'Ubicació no disponible',
			'operationLocationScreen.permissionDenied' => 'Permís d\'ubicació denegat',
			'operationLocationScreen.permissionBlocked' => 'Permís d\'ubicació bloquejat',
			'operationLocationScreen.moreDetails' => 'Més detalls',
			'operationLocationScreen.stateOrProvince' => 'Estat o província (opcional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controls d\'activitat no disponibles',
			'operationLocationScreen.controlsUnavailableReason' => 'Aquestes referències encara es poden utilitzar; simplement no s\'ha pogut accedir a les seves activitats.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Torna-ho a provar',
			'operationLocationScreen.county' => 'Comtat (opcional)',
			'versionLabel.version' => ({required Object version}) => 'Versió ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Pegat ${patch}',
			'versionLabel.build' => ({required Object build}) => 'compilació ${build}',
			'notices.emptyHistory' => 'Encara no hi ha avisos',
			'notices.webStorageInMemory' => 'Aquest navegador no ha pogut oferir emmagatzematge persistent — el registre només és a la memòria i ES PERDRÀ quan es tanqui aquesta pestanya. Utilitza una versió actual de Chrome, Firefox, Safari o Edge.',
			'notices.webStorageUnreliable' => 'Aquest navegador utilitza un emmagatzematge alternatiu que no és segur amb diverses pestanyes — mantén només una pestanya oberta i deixa la sincronització activada.',
			'notices.logFromNewerBuildTitle' => 'Aquest registre necessita una versió més nova',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'El teu registre l\'ha escrit una versió més nova de HaLo (versió d\'emmagatzematge ${storage}; aquesta entén la ${understood}), així que no es pot obrir i els contactes nous no es desaran. Torna a instal·lar la versió més nova — o, si volies executar aquesta versió, apunta-la a una altra carpeta de dades. El registre és a ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'El teu registre l\'ha escrit una versió més nova de HaLo (versió d\'emmagatzematge ${storage}; aquesta entén la ${understood}), així que no es pot obrir i els contactes nous no es desaran. Obre aquest registre amb aquella versió més nova.',
			'notices.preferencesRestoredTitle' => 'Configuració restaurada des d\'una còpia de seguretat',
			'notices.preferencesRestored' => 'No s\'ha pogut llegir el fitxer de configuració, així que HaLo n\'ha restaurat l\'última còpia bona. Potser hauràs de tornar a configurar el que vas canviar a la sessió anterior. El fitxer il·legible es conserva al costat, amb el nom shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Configuració restablerta',
			'notices.preferencesReset' => 'No s\'ha pogut llegir el fitxer de configuració i no hi havia cap còpia de seguretat a què recórrer, així que HaLo ha començat amb els valors per defecte. El fitxer il·legible es conserva a la carpeta de dades de l\'aplicació, amb el nom shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} no s\'ha connectat automàticament',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo va deixar de respondre l\'última vegada que va començar a connectar-se a ${name}, així que aquesta vegada no ho ha intentat per no arriscar-se que torni a passar. Comprova que la ràdio estigui engegada i el cable connectat, i després prem Connecta a la Configuració.',
			'syncAccount.anonymous' => ({required Object id}) => 'Compte anònim (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (pendent de confirmació)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (pendent de confirmació - #${id})',
			'deepLink.needsAnOperation' => 'Inicia primer una operació i després torna a enviar aquest contacte',
			'deepLink.waitingInOperation' => 'Aquest contacte espera a l\'operació que hi ha darrere d\'aquesta pantalla',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Aquest dispositiu no té cap activitat per a ${refs}, així que s\'han omès aquestes referències',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'No s\'ha pogut accedir a les teves activitats, així que s\'ha omès ${refs} — torna a provar aquest enllaç',
			'confirmDevice.title' => 'Confirma un dispositiu',
			'confirmDevice.codePrompt' => 'Introdueix el codi que es mostra al dispositiu que vol unir-se a aquest compte.',
			'confirmDevice.code' => 'Codi',
			'confirmDevice.lookUp' => 'Cerca',
			'confirmDevice.codeNotFound' => 'Cap sol·licitud coincideix amb aquest codi. Els codis caduquen al cap de 10 minuts — demana\'n un de nou a l\'altre dispositiu.',
			'confirmDevice.linkExpired' => 'Aquest enllaç ha caducat. Demana a l\'altre dispositiu que mostri un codi QR nou.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Vincular ${device} a aquest compte?',
			'confirmDevice.unnamedDevice' => 'un dispositiu sense nom',
			'confirmDevice.grantWarning' => 'Podrà llegir i modificar totes les operacions i QSOs d\'aquest compte.',
			'confirmDevice.needsSyncTitle' => 'Aquest dispositiu encara no se sincronitza',
			'confirmDevice.needsSyncText' => 'Activa la sincronització de Ham2K Log Filer i vincula aquest dispositiu a un compte abans que pugui admetre\'n un altre.',
			'confirmDevice.malformedRequest' => 'El servidor de sincronització ha enviat una sol·licitud que aquesta aplicació no ha pogut llegir. Demana a l\'altre dispositiu que ho torni a provar.',
			'confirmDevice.linkIt' => 'Vincula el dispositiu',
			'switchAccounts.noAccountDetails' => 'Encara no hi ha detalls del compte',
			'switchAccounts.currentAccount' => 'Compte actual',
			'switchAccounts.otherAccounts' => 'Altres comptes',
			'switchAccounts.linkToAnother' => 'Vincula amb un altre compte',
			'switchAccounts.linkWithSibling' => 'Vincula amb una altra aplicació de Ham2K',
			'switchAccounts.linkWithPolo' => 'Vincula amb el compte de la versió anterior',
			'switchAccounts.linkWithSiblingDescription' => 'Tens una altra aplicació de Ham2K instal·lada. Vincula amb el compte que s\'hi fa servir.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Aprova la sol·licitud a ${app} i després torna aquí.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Torna a obrir ${app}',
			'switchAccounts.siblingNoGrant' => 'No ha funcionat? Torna-la a obrir, o torna enrere i vincula d\'una altra manera.',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'No s\'ha pogut obrir ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'L\'enllaç ha caducat i n\'hi ha un de nou a punt — torna a obrir ${app}.',
			'switchAccounts.tryAgain' => 'Torna-ho a provar',
			'switchAccounts.linkWithQr' => 'Vincula amb un codi QR',
			'switchAccounts.linkWithQrDescription' => 'Escaneja\'l des d\'un dispositiu que ja utilitzi el compte',
			'switchAccounts.linkWithEmail' => 'Vincula amb una adreça de correu electrònic',
			'switchAccounts.linkWithEmailDescription' => 'Confirma amb un codi o un enllaç per correu electrònic',
			'switchAccounts.enterEmailPrompt' => 'Introdueix l\'adreça de correu electrònic del compte que vols que utilitzi aquest dispositiu.',
			'switchAccounts.emailAddress' => 'Adreça de correu electrònic',
			'switchAccounts.linkAccount' => 'Vincula el compte',
			'switchAccounts.copiedCode' => 'S\'ha copiat el codi al porta-retalls',
			'switchAccounts.copyCode' => 'Copia el codi',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Obre l\'aplicació de Ham2K en un dispositiu ja vinculat amb ${email} i introdueix aquest codi per aprovar la sol·licitud:',
			'switchAccounts.waitingForConfirmation' => 'Esperant la confirmació…',
			'switchAccounts.sendEmailInstead' => 'Envia un correu de confirmació',
			'switchAccounts.emailSent' => ({required Object email}) => 'S\'ha enviat un correu electrònic a ${email}. Obre\'l i confirma la sol·licitud per vincular aquest dispositiu.',
			'switchAccounts.resendEmail' => 'Torna a enviar el correu',
			'switchAccounts.qrPrompt' => 'Escaneja aquest codi QR des d\'un dispositiu ja vinculat al compte que vols — per exemple, amb Ham2K Portable Logger al telèfon.',
			'switchAccounts.serverUnreachable' => 'No s\'ha pogut contactar amb el servidor de sincronització. Torna-ho a provar més tard.',
			'switchAccounts.emailRequired' => 'Introdueix una adreça de correu electrònic per vincular.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'No s\'ha trobat cap compte per a ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'El servidor de sincronització ha rebutjat la sol·licitud: ${error}',
			'switchAccounts.noLinkCode' => 'El servidor de sincronització no ha retornat cap codi de vinculació. Torna-ho a provar més tard.',
			'switchAccounts.noConfirmationCode' => 'El servidor de sincronització no ha enviat cap codi de confirmació. Torna-ho a provar més tard.',
			'switchAccounts.switchNotAccepted' => 'Aquest compte no ha acceptat el canvi. Prova de vincular-lo amb una adreça de correu electrònic.',
			'switchAccounts.requestFailed' => 'Alguna cosa ha anat malament en comunicar-se amb el servidor de sincronització. Torna-ho a provar més tard.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} operació', other: '${count} operacions', ), 
			'qsonImport.title' => 'Importa una operació QSON',
			'qsonImport.description' => 'Crea una operació nova a partir d\'un fitxer QSON, com el que exporta el Mode de desenvolupador aquí o a PoLo.',
			'qsonImport.dropHint' => 'Deixa anar un fitxer QSON per importar-lo com a operació nova',
			'qsonImport.importing' => ({required Object filename}) => 'Important ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'No s\'ha pogut importar ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'No s\'ha pogut obrir cap fitxer per importar: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} no és text UTF-8, així que no és un fitxer QSON',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} no és un fitxer JSON, així que no és un fitxer QSON',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} no conté cap operació QSON',
			'qsonImport.busy' => 'Ja hi ha una importació en curs. Espera que acabi abans de començar-ne una altra.',
			'qsonImport.oneFileOnly' => 'Deixa anar els fitxers QSON d\'un en un — cadascun s\'obre com una operació pròpia.',
			'adifImport.title' => 'Importa QSOs des d\'ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Llegint ${filename}…',
			'adifImport.dropHint' => 'Deixa anar un fitxer ADIF per importar-lo',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} QSO en aquest fitxer', other: '${formatted} QSOs en aquest fitxer', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} ja és al teu registre', other: '${formatted} ja són al teu registre', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Se n\'importarà ${count}', other: 'Se n\'importaran ${formatted}', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} contacte nou', other: '${formatted} contactes nous', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} es combinarà amb un contacte existent', other: '${formatted} es combinaran amb contactes existents', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} no es pot importar (sense indicatiu)', other: '${formatted} no es poden importar (sense indicatiu)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} necessita una ullada més atenta', other: '${formatted} necessiten una ullada més atenta', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'No s\'han pogut recuperar les referències de ${count} contacte', other: 'No s\'han pogut recuperar les referències de ${formatted} contactes', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'Les referències ${programs} poden estar incompletes per a ${count} contacte', other: 'Les referències ${programs} poden estar incompletes per a ${formatted} contactes', ), 
			'adifImport.stackingTypesUnknown' => 'Els contactes combinats poden perdre una referència — les activitats no han pogut indicar quins tipus s\'acumulen. Cancel·la i torna-ho a provar per evitar-ho.',
			'adifImport.nothingToImport' => 'No hi ha res en aquest fitxer que es pugui importar',
			'adifImport.confirm' => 'Importa',
			'adifImport.importing' => ({required Object filename}) => 'Important ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: 'S\'ha importat ${count} contacte de ${filename}', other: 'S\'han importat ${formatted} contactes de ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'No s\'ha pogut importar ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} no sembla un fitxer ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Avís: aquest ADIF té QSOs de ${calls}, però s\'importaran com a ${station} si continues.',
			'adifImport.stationCallJoin' => ' i ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ca'))(count, one: '${count} no té data i no es pot importar', other: '${formatted} no tenen data i no es poden importar', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Aquest fitxer registra una activació de ${refs}.',
			'adifImport.addActivation' => 'Afegeix-la a aquesta operació',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Només s\'han pogut aplicar ${written} de ${planned} — el registre ha canviat mentre decidies.',
			'adifImport.busy' => 'Ja hi ha una importació en curs. Espera que acabi abans de començar-ne una altra.',
			'adifImport.oneFileOnly' => 'Deixa anar els fitxers ADIF d\'un en un — l\'ordre en què s\'importen decideix quines dades prevalen.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} té més de ${limit} QSOs, el màxim que una operació pot importar alhora.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename} té més de ${limit} QSOs. Importar un ADIF a una operació serveix per afegir uns quants QSOs, no per carregar un registre gran — per a això, fes servir la vista Registres. El mode de desenvolupador et permet importar-lo igualment, si n\'estàs segur.',
			'adifImport.importAnyway' => 'Importa igualment',
			'offline.statusOffline' => 'Internet: SENSE CONNEXIÓ',
			'offline.statusOnline' => 'Internet: connectat',
			'offline.noRoute' => 'No hi ha cap connexió de xarxa.',
			'offline.unreachable' => 'La xarxa funciona, però cap servidor respon — sovint és senyal que hi ha una pàgina d\'inici de sessió esperant en un navegador.',
			'offline.reachable' => 'Tots els serveis responen amb normalitat.',
			'offline.whatStops' => 'Les consultes, els anuncis i els fitxers de dades estan en pausa. El registre i la sincronització amb dispositius propers, no.',
			'offline.servicesTitle' => 'Serveis',
			'offline.noServices' => 'Encara no ha informat cap servei.',
			'offline.lastSuccess' => ({required Object when}) => 'Última resposta fa ${when}',
			'offline.neverSucceeded' => 'Encara no ha respost',
			'offline.nextAttempt' => ({required Object when}) => 'Proper intent d\'aquí a ${when}',
			'offline.nextAttemptNow' => 'Proper intent imminent',
			'offline.retry' => 'Torna-ho a provar ara',
			'offline.retrying' => 'Provant…',
			'offline.retryReached' => 'Torna a haver-hi connexió.',
			'offline.retryUnreachable' => 'Encara sense resposta.',
			'offline.retryNotAttempted' => 'Ara mateix no hi ha res per enviar.',
			'offline.retryThrottled' => 'S\'acaba de provar — espera un moment.',
			'offline.retryDisabled' => 'La sincronització està desactivada, així que no hi ha res amb què comprovar-ho.',
			'offline.syncService' => 'Sincronització LoFi de Ham2K',
			'offline.retryInFlight' => 'Ja s\'està provant — espera.',
			'exportSettings.defaultsDescription' => 'Configuració base per a totes les exportacions, amb plantilles de nom de fitxer i de títol separades per a activitats de referència i altres activitats. Cada tipus d\'exportació pot tenir els seus propis valors per defecte o una configuració personalitzada.',
			'exportSettings.referenceActivities' => 'Activitats de referència',
			'exportSettings.otherActivities' => 'Altres activitats',
			'exportSettings.adifFields' => 'Camps ADIF',
			'exportSettings.loadFailed' => 'No s\'ha pogut carregar la configuració d\'exportació.',
			'exportSettings.retry' => 'Torna-ho a provar',
			'exportSettings.compactFileNamesDescriptionOn' => 'Noms de fitxer compactes, com N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Noms de fitxer descriptius, com 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'S\'inclouen noms, adreces, correus electrònics, notes i ubicacions precises als fitxers ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'S\'ometen noms, adreces, correus electrònics i notes; les ubicacions es limiten a graelles de sis caràcters.',
			'exportSettings.includeLookupDataDescriptionOn' => 'S\'inclou la informació dels serveis de consulta d\'indicatius.',
			'exportSettings.includeLookupDataDescriptionOff' => 'S\'omet la informació dels serveis de consulta d\'indicatius; es conserven els valors introduïts manualment.',
			'exportSettings.customTemplatesDescriptionOn' => 'Les teves plantilles personalitzades estan actives i es poden editar a sota.',
			'exportSettings.customTemplatesDescriptionOff' => 'Les plantilles per defecte estan actives. Les teves plantilles personalitzades es conserven per a més endavant.',
			'exportSettings.type' => 'Tipus d\'exportació',
			'exportSettings.defaults' => 'Valors per defecte',
			'exportSettings.includeLookupData' => 'Inclou les dades de consulta',
			'exportSettings.customTemplates' => 'Plantilles personalitzades',
			'exportSettings.filenameTemplate' => 'Plantilla de nom de fitxer',
			'exportSettings.compactFilenameTemplate' => 'Plantilla de nom de fitxer compacte',
			'exportSettings.titleTemplate' => 'Plantilla de títol',
			'exportSettings.adifNotesTemplate' => 'Notes ADIF QSO',
			'exportSettings.adifCommentTemplate' => 'Comentaris ADIF QSO',
			'exportSettings.adifQslMessageTemplate' => 'Missatge ADIF QSL',
			'exportSettings.shared' => 'La configuració s\'aplica a totes les extensions que utilitzen aquest tipus d\'exportació.',
			'exportSettings.defaultTemplates' => 'Activa Plantilles personalitzades per editar les plantilles d\'aquest tipus.',
			'templateEditor.previewLabel' => 'Previsualització:',
			'templateEditor.reset' => 'Restableix',
			'templateEditor.docs' => 'Documentació de plantilles',
			'templateEditor.preview' => 'Previsualització d\'exemple',
			'templateEditor.reference' => 'Referència de plantilles',
			'templateEditor.attributes' => 'Atributs disponibles',
			'templateEditor.filters' => 'Filtres',
			'templateEditor.flowControl' => 'Control de flux',
			'templateEditor.unavailable' => 'La previsualització no està disponible fins que les extensions estiguin a punt.',
			'templateEditor.empty' => '(sortida buida)',
			_ => null,
		};
	}
}
